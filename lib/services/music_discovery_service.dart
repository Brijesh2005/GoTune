import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_constants.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/home_feed.dart';
import '../models/music_content.dart';
import '../models/playlist.dart';
import '../models/search_discovery_result.dart';
import '../models/track.dart';
import 'local_storage_service.dart';
import 'music_algorithm_service.dart';
import 'music_cache_service.dart';
import 'music_catalog_aggregator.dart';

/// Everything a song page needs, resolved in one pass.
///
/// This is the audio analogue of the reference project's
/// `getYouTubeVideo → { video, related }` contract: the detail experience
/// consumes a single unified object instead of issuing its own provider calls.
class SongDetail {
  final Track song;
  final RelatedContent related;
  final Artist? artist;
  final Album? album;

  const SongDetail({
    required this.song,
    this.related = const RelatedContent(seed: _emptySeed),
    this.artist,
    this.album,
  });

  List<Track> get relatedTracks => related.tracks;
  List<Artist> get relatedArtists => related.artists;
  List<Album> get similarAlbums => related.albums;
  bool get hasPlayableSource => song.isPlayable;
}

// Placeholder seed for the `const` default above.
const Track _emptySeed = Track(id: '', title: '', artist: '');

/// Radio candidates plus the provenance of each contributing signal.
class RadioCandidateSet {
  final List<Track> candidates;

  /// How many candidates each discovery signal contributed, for diagnostics and
  /// for verifying that radio is genuinely multi-signal.
  final Map<String, int> signalContributions;

  const RadioCandidateSet({
    this.candidates = const [],
    this.signalContributions = const {},
  });

  int get signalCount => signalContributions.length;
  bool get isEmpty => candidates.isEmpty;
}

/// Centralized music discovery layer — the single door between the UI and the
/// catalog.
///
/// Responsibilities:
/// * exposes one typed facade over the whole [MusicCatalogAggregator],
/// * composes multi-signal discovery (related, artist, genre, trending) rather
///   than issuing single ad-hoc provider calls,
/// * feeds candidates to [MusicAlgorithmService], which only *ranks* them,
/// * enforces caching and graceful degradation.
///
/// The UI never sees a provider, a cache key or an HTTP error.
class MusicDiscoveryService {
  final MusicCatalogAggregator _aggregator;
  final MusicAlgorithmService _algorithmService;
  final LocalStorageService _storageService;
  final MusicCacheService _cache;

  MusicDiscoveryService({
    required MusicCatalogAggregator aggregator,
    required MusicAlgorithmService algorithmService,
    required LocalStorageService storageService,
    MusicCacheService? cache,
  })  : _aggregator = aggregator,
        _algorithmService = algorithmService,
        _storageService = storageService,
        _cache = cache ?? MusicCacheService();

  MusicCatalogAggregator get aggregator => _aggregator;
  MusicAlgorithmService get algorithmService => _algorithmService;
  LocalStorageService get storageService => _storageService;
  MusicCacheService get cache => _cache;

  // ==========================================================
  // HOME FEED
  // ==========================================================

  /// Builds the unified [HomeFeed] consumed by the home screen.
  ///
  /// Every shelf originates from the discovery layer; the screen renders the
  /// result and never asks which catalog produced a section.
  Future<HomeFeed> getHomeFeed({bool forceRefresh = false}) async {
    const cacheKey = '${MusicCacheService.nsHomeFeed}::unified';
    if (!forceRefresh) {
      final cached = _cache.get<HomeFeed>(cacheKey);
      if (cached != null) return cached;
    }

    final history = _storageService.getRecentlyPlayed().map((item) => item.track).toList();
    final favorites = _storageService.getFavorites();

    try {
      // All independent discovery signals are requested concurrently.
      final results = await Future.wait([
        getTrending(limit: 25),
        getPopular(limit: 20),
        getNewReleases(limit: 20),
        getGenres(),
        getMoods(),
      ]);

      final trending = results[0] as List<Track>;
      final popular = results[1] as List<Track>;
      final newReleases = results[2] as List<Track>;
      final genres = results[3] as List<MusicGenre>;
      final moods = results[4] as List<MusicMood>;

      final pool = Track.deduplicate([...trending, ...popular, ...newReleases]);

      final quickPicks = _algorithmService.getQuickPicks(
        history: history,
        favorites: favorites,
        limit: 10,
      );

      final recommendedSongs = await _algorithmService.getRecommendedForYou(
        history: history,
        favorites: favorites,
        catalogPool: pool,
        limit: 15,
      );

      final personalizedMixes = await _algorithmService.generatePersonalizedMixes(
        history: history,
        favorites: favorites,
        catalogPool: pool,
      );

      // "Because you listened" needs real related content, not a static list.
      List<Track> becauseYouListened = const [];
      String? becauseSeed;
      if (history.isNotEmpty) {
        final seed = history.first;
        becauseSeed = seed.artist;
        becauseYouListened = (await getRelated(seed, limit: 12))
            .where((t) => t.id != seed.id)
            .toList();
      }

      final feed = HomeFeed(
        quickPicks: quickPicks,
        recommendedSongs: recommendedSongs,
        trendingTracks: trending,
        popularNow: popular,
        newReleases: newReleases,
        recentlyPlayed: history.take(15).toList(),
        becauseYouListened: becauseYouListened,
        becauseYouListenedSeed: becauseSeed,
        mostPlayed: _algorithmService.getMostPlayed(
          history: history,
          favorites: favorites,
          limit: 12,
        ),
        onRepeat: _algorithmService.getOnRepeat(history: history, limit: 12),
        rediscover: _algorithmService.getRediscover(
          history: history,
          favorites: favorites,
          limit: 12,
        ),
        favoriteArtists: _algorithmService.getRecommendedArtistNames(
          history: history,
          favorites: favorites,
          limit: 8,
        ),
        genres: genres,
        moods: moods,
        personalizedMixes: personalizedMixes,
        updatedAt: DateTime.now(),
      );

      if (feed.hasContent) {
        _cache.set(cacheKey, feed, ttl: MusicCacheService.ttlHomeFeed);
      }
      return feed;
    } catch (error, stack) {
      debugPrint('[MusicDiscoveryService] getHomeFeed failed: $error\n$stack');
      final stale = _cache.getStale<HomeFeed>(cacheKey);
      if (stale != null) {
        _aggregator.diagnostics.totalStaleCacheServes++;
        return stale;
      }
      return HomeFeed(
        updatedAt: DateTime.now(),
        errorMessage: 'Unable to load the discovery feed. Check your connection.',
      );
    }
  }

  // ==========================================================
  // SEARCH
  // ==========================================================

  /// Centralized cross-catalog search.
  ///
  /// Returns normalized, deduplicated, provider-agnostic results. Each hit
  /// carries enough metadata (via [MusicContent.contentKey] and the typed
  /// lists) for the UI to navigate to the matching detail page.
  Future<SearchDiscoveryResult> search(
    String query, {
    String category = 'all',
    String providerFilter = 'all',
    int limit = 25,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return SearchDiscoveryResult(query: '', timestamp: DateTime.now());
    }

    final cacheKey = '${MusicCacheService.nsSearch}::discovery::'
        '${trimmed.toLowerCase()}::$category::$providerFilter::$limit';
    final cached = _cache.get<SearchDiscoveryResult>(cacheKey);
    if (cached != null) return cached;

    bool wants(String name) => category == 'all' || category == name;

    // Songs, artists, albums, genres and moods are independent, so they are
    // requested concurrently; playlists come from local persistence.
    final futures = <Future<dynamic>>[
      if (wants('songs')) _aggregator.searchTracks(trimmed, limit: limit, providerFilter: providerFilter),
      if (wants('artists')) _aggregator.searchArtists(trimmed, limit: 12),
      if (wants('albums')) _aggregator.searchAlbums(trimmed, limit: 12),
    ];

    final dynamicResults = await Future.wait(futures);
    var index = 0;

    final songs = wants('songs') ? dynamicResults[index++] as List<Track> : const <Track>[];
    final artists = wants('artists') ? dynamicResults[index++] as List<Artist> : const <Artist>[];
    final albums = wants('albums') ? dynamicResults[index++] as List<Album> : const <Album>[];

    final playlists = wants('playlists')
        ? _searchLocalPlaylists(trimmed)
        : const <Playlist>[];

    final genres = wants('genres')
        ? _matchGenres(await getGenres(), trimmed)
        : const <MusicGenre>[];

    final moods = wants('genres')
        ? _matchMoods(await getMoods(), trimmed)
        : const <MusicMood>[];

    final result = SearchDiscoveryResult(
      query: trimmed,
      songs: songs,
      artists: artists,
      albums: albums,
      playlists: playlists,
      genres: genres,
      moods: moods,
      timestamp: DateTime.now(),
    );

    if (result.hasResults) {
      _cache.set(cacheKey, result, ttl: MusicCacheService.ttlSearch);
      return result;
    }
    return _cache.getStale<SearchDiscoveryResult>(cacheKey) ?? result;
  }

  List<Playlist> _searchLocalPlaylists(String query) {
    final needle = query.toLowerCase();
    return _storageService
        .getPlaylists()
        .where((p) => p.name.toLowerCase().contains(needle))
        .toList();
  }

  List<MusicGenre> _matchGenres(List<MusicGenre> all, String query) {
    final needle = query.toLowerCase();
    return all.where((g) => g.title.toLowerCase().contains(needle)).toList();
  }

  List<MusicMood> _matchMoods(List<MusicMood> all, String query) {
    final needle = query.toLowerCase();
    return all.where((m) => m.title.toLowerCase().contains(needle)).toList();
  }

  // ==========================================================
  // DISCOVERY SHELVES
  // ==========================================================

  /// Trending tracks, optionally scoped to a genre.
  Future<List<Track>> getTrending({String? genre, int limit = 25}) {
    return _aggregator.getTrendingTracks(genre: genre, limit: limit);
  }

  /// Broad popular shelf, independent of the trending cache entry.
  Future<List<Track>> getPopular({int limit = 25}) {
    return _aggregator.getPopularTracks(limit: limit);
  }

  /// Recently released tracks.
  Future<List<Track>> getNewReleases({int limit = 20}) {
    return _aggregator.getNewReleases(limit: limit);
  }

  /// Genre facets available for browsing.
  Future<List<MusicGenre>> getGenres() async {
    final cached = _cache.get<List<MusicGenre>>('${MusicCacheService.nsGenres}::all');
    if (cached != null) return cached;

    final genres = <MusicGenre>[
      for (final name in AppConstants.discoveryGenres)
        if (name != 'All')
          MusicGenre(title: name, providerId: name.toLowerCase().replaceAll(' ', '-')),
    ];
    _cache.set(
      '${MusicCacheService.nsGenres}::all',
      genres,
      ttl: MusicCacheService.ttlGenres,
    );
    return genres;
  }

  /// Mood facets available for browsing and mood radio.
  Future<List<MusicMood>> getMoods() async {
    final cached = _cache.get<List<MusicMood>>('${MusicCacheService.nsMoods}::all');
    if (cached != null) return cached;

    final moods = <MusicMood>[
      for (final name in AppConstants.discoveryMoods)
        MusicMood(title: name, providerId: name.toLowerCase().replaceAll(' ', '-')),
    ];
    _cache.set('${MusicCacheService.nsMoods}::all', moods, ttl: MusicCacheService.ttlGenres);
    return moods;
  }

  /// Personalized recommendations ranked from user history.
  Future<List<Track>> getRecommendations({int limit = 20}) async {
    final history = _storageService.getRecentlyPlayed().map((item) => item.track).toList();
    final favorites = _storageService.getFavorites();

    final pool = await Future.wait([
      getTrending(limit: 25),
      getNewReleases(limit: 15),
    ]).then((lists) => Track.deduplicate([...lists[0], ...lists[1]]));

    return _algorithmService.getRecommendedForYou(
      history: history,
      favorites: favorites,
      catalogPool: pool,
      limit: limit,
    );
  }

  // ==========================================================
  // RELATED CONTENT
  // ==========================================================

  /// Related songs for a seed track, provider-agnostic.
  Future<List<Track>> getRelated(Track track, {int limit = 15}) {
    return _aggregator.getRelatedTracks(track, limit: limit);
  }

  /// Full related shelf for a seed: related songs, related artists and similar
  /// albums in one call.
  Future<RelatedContent> getRelatedContent(Track track, {int limit = 15}) {
    return _aggregator.getRelatedContent(track, limit: limit);
  }

  /// Content-detail bundle for a song page.
  Future<SongDetail> getSongDetail(Track track, {int limit = 15}) async {
    final cacheKey = '${MusicCacheService.nsSongDetail}::'
        '${track.normalizedFingerprint}::$limit';
    final cached = _cache.get<SongDetail>(cacheKey);
    if (cached != null) return cached;

    final related = await getRelatedContent(track, limit: limit);

    // Fill in artist/album from the related pass first, then fall back to a
    // direct lookup so the page is never missing its credits.
    final artist = related.artists.firstOrNull ??
        (track.artistId != null && track.artistId!.isNotEmpty
            ? await getArtist(track.artistId!)
            : null);
    final album = related.albums.firstOrNull ??
        (track.albumId != null && track.albumId!.isNotEmpty
            ? await getAlbum(track.albumId!)
            : null);

    final detail = SongDetail(
      song: track,
      related: related,
      artist: artist,
      album: album,
    );
    _cache.set(cacheKey, detail, ttl: MusicCacheService.ttlSongDetail);
    return detail;
  }

  /// Unified artist details with catalog fallback and artist tracks.
  Future<Artist?> getArtist(String idOrName, {bool withTracks = true}) {
    return _aggregator.getArtist(idOrName, withTracks: withTracks);
  }

  /// Unified album details with catalog fallback.
  Future<Album?> getAlbum(String id) {
    return _aggregator.getAlbum(id);
  }

  /// A user playlist by id, resolved from local persistence.
  Future<Playlist?> getPlaylist(String id) async {
    for (final playlist in _storageService.getPlaylists()) {
      if (playlist.id == id) return playlist;
    }
    return null;
  }

  /// Batch track resolution with per-item isolation.
  Future<Map<String, Track>> getTracksByIds(List<String> ids) {
    return _aggregator.getTracksByIds(ids);
  }

  // ==========================================================
  // RADIO
  // ==========================================================

  /// Gathers radio candidates by fanning out every discovery signal that can
  /// relate to [seed]: provider related endpoints, the seed's artist, the
  /// seed's genre, and the trending shelf as a filler.
  ///
  /// This layer only *finds* candidates. Ranking and diversity filtering are a
  /// separate stage owned by [MusicAlgorithmService].
  Future<RadioCandidateSet> getRadioCandidates(Track seed, {int limit = 12}) async {
    final cacheKey = '${MusicCacheService.nsRadio}::candidates::'
        '${seed.normalizedFingerprint}::$limit';
    final cached = _cache.get<RadioCandidateSet>(cacheKey);
    if (cached != null) return cached;

    final genre = seed.genre;

    final signals = <String, Future<List<Track>>>{
      'related': getRelated(seed, limit: limit * 2),
      'artist': seed.artist.trim().isEmpty
          ? Future.value(const <Track>[])
          : _aggregator.getArtistTracks(seed.artist, limit: limit),
      'genre': (genre.isEmpty || genre == 'Music')
          ? Future.value(const <Track>[])
          : _aggregator.getGenreTracks(genre, limit: limit),
      'trending': getTrending(limit: limit),
    };

    final keys = signals.keys.toList();
    final results = await Future.wait(signals.values);

    final contributions = <String, int>{};
    final merged = <Track>[];
    for (var i = 0; i < results.length; i++) {
      contributions[keys[i]] = results[i].length;
      merged.addAll(results[i]);
    }

    final candidates = Track.deduplicate(
      merged.where((t) => t.id != seed.id).toList(),
    );

    final set = RadioCandidateSet(
      candidates: candidates,
      signalContributions: contributions,
    );
    if (!set.isEmpty) {
      _cache.set(cacheKey, set, ttl: MusicCacheService.ttlRadio);
    }
    return set;
  }

  /// Builds a smart radio queue: discovery supplies candidates, the
  /// recommendation engine ranks and diversifies them.
  Future<List<Track>> getDynamicRadio(Track seedTrack, {int limit = 12}) async {
    final history = _storageService.getRecentlyPlayed().map((item) => item.track).toList();
    final favorites = _storageService.getFavorites();

    final discovered = await getRadioCandidates(seedTrack, limit: limit);
    if (discovered.isEmpty) return const [];

    return _algorithmService.rankCandidates(
      candidates: discovered.candidates,
      seed: seedTrack,
      history: history,
      favorites: favorites,
      limit: limit,
      maxPerArtist: 2,
      excludedIds: {seedTrack.id},
    );
  }

  /// Artist radio: plays the artist's top track and queues related material.
  Future<List<Track>> getArtistRadio(Artist artist, {int limit = 12}) async {
    final history = _storageService.getRecentlyPlayed().map((item) => item.track).toList();
    final favorites = _storageService.getFavorites();

    final artistTracks = artist.popularTracks.isNotEmpty
        ? artist.popularTracks
        : await _aggregator.getArtistTracks(
            artist.id.isNotEmpty ? artist.id : artist.name,
            limit: limit * 2,
          );

    if (artistTracks.isEmpty) return const [];

    // Broaden with related content of the artist's strongest track so the
    // queue is not limited to one provider's catalogue.
    final seed = artistTracks.first;
    final related = await getRelated(seed, limit: limit);
    final candidates = Track.deduplicate([...related, ...artistTracks]);

    return _algorithmService.rankCandidates(
      candidates: candidates,
      seed: seed,
      history: history,
      favorites: favorites,
      limit: limit,
      maxPerArtist: 3,
      excludedIds: const {},
      pinned: artistTracks.take(2).toList(),
    );
  }

  /// Genre/mood radio built from genre-scoped discovery plus artist affinity.
  Future<List<Track>> getGenreRadio(String genre, {int limit = 12}) async {
    final history = _storageService.getRecentlyPlayed().map((item) => item.track).toList();
    final favorites = _storageService.getFavorites();

    final genreTracks = await _aggregator.getGenreTracks(genre, limit: limit * 2);
    if (genreTracks.isEmpty) return const [];

    final seed = genreTracks.first;
    final related = await getRelated(seed, limit: limit);
    final candidates = Track.deduplicate([...genreTracks, ...related]);

    return _algorithmService.rankCandidates(
      candidates: candidates,
      seed: seed,
      history: history,
      favorites: favorites,
      limit: limit,
      maxPerArtist: 2,
      excludedIds: const {},
      pinned: genreTracks.take(3).toList(),
    );
  }
}
