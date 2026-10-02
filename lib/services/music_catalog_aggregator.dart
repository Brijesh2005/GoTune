import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/album.dart';
import '../models/artist.dart';
import '../models/track.dart';
import 'music_cache_service.dart';
import 'music_catalog_provider.dart';
import 'provider_execution.dart';

/// Related content discovered for a single seed track.
class RelatedContent {
  final Track seed;
  final List<Track> tracks;
  final List<Artist> artists;
  final List<Album> albums;

  const RelatedContent({
    required this.seed,
    this.tracks = const [],
    this.artists = const [],
    this.albums = const [],
  });

  bool get isEmpty => tracks.isEmpty && artists.isEmpty && albums.isEmpty;
  bool get isNotEmpty => !isEmpty;
  int get totalCount => tracks.length + artists.length + albums.length;
}

/// Centralized multi-source catalog aggregator.
///
/// This is the GoTune analogue of the reference project's `youtube.functions.ts`
/// source tiering. Where the reference walks Piped → Invidious → YouTube Data
/// API → InnerTube → HTML scrape and returns the first non-empty tier, GoTune
/// fans out **concurrently** across every registered [MusicCatalogProvider] and
/// merges the results, because for a music catalog a partial result from every
/// provider is strictly better than a full result from one.
///
/// Responsibilities:
/// * concurrent fan-out with per-provider [ProviderInvoker] isolation,
/// * normalization + cross-provider source consolidation + deduplication,
/// * bounded TTL caching with a stale-while-error terminal fallback,
/// * per-provider health accounting via [MusicDiagnostics].
class MusicCatalogAggregator {
  /// The application's live aggregator.
  ///
  /// GoTune creates exactly one aggregator in `main()` and shares it through
  /// the singleton providers, so registering it here lets non-catalog UI
  /// (Settings) reach cache invalidation without importing a catalog service.
  static MusicCatalogAggregator? _active;

  static MusicCatalogAggregator? get active => _active;

  final List<MusicCatalogProvider> _adapters;
  final MusicCacheService _cache;
  final ProviderInvoker _invoker;

  MusicCatalogAggregator({
    List<MusicCatalogProvider>? adapters,
    YouTubeCatalogProvider? youtubeProvider,
    MusicCacheService? cache,
    MusicCacheService? cacheService,
    ProviderInvoker? invoker,
  })  : _cache = cache ?? cacheService ?? MusicCacheService(),
        _invoker = invoker ?? ProviderInvoker(),
        _adapters = adapters ??
            [
              youtubeProvider ?? YouTubeCatalogProvider(),
            ] {
    _active = this;
  }

  List<MusicCatalogProvider> get adapters => List.unmodifiable(_adapters);

  MusicCacheService get cache => _cache;

  MusicDiagnostics get diagnostics => _invoker.diagnostics;

  /// Returns the adapter owning [providerId], or `null`.
  MusicCatalogProvider? getAdapter(String providerId) {
    for (final adapter in _adapters) {
      if (adapter.providerId == providerId) return adapter;
    }
    return null;
  }

  /// Resolves the set of adapters a call should fan out to.
  ///
  /// An explicit `providerFilter` narrows the fan-out. Degraded providers are
  /// never skipped: a provider that is merely struggling should still be given
  /// the chance to contribute, which is exactly the isolation guarantee the
  /// reference architecture relies on.
  List<MusicCatalogProvider> _targets(String providerFilter) {
    if (providerFilter == 'all') return _adapters;
    final match = getAdapter(providerFilter);
    if (match != null) return [match];
    debugPrint('[MusicCatalogAggregator] unknown provider filter "$providerFilter"');
    return _adapters;
  }

  /// Serves [cacheKey] from cache when fresh, otherwise computes, caches and
  /// finally falls back to a stale entry if every provider failed.
  Future<List<Track>> _fanOutTracks({
    required String cacheKey,
    required Duration ttl,
    required List<MusicCatalogProvider> targets,
    required Future<List<Track>> Function(MusicCatalogProvider adapter) call,
    int limit = 25,
    String? excludeTrackId,
  }) async {
    final cached = _cache.get<List<Track>>(cacheKey);
    if (cached != null) return cached;

    // Concurrent fan-out: one slow or dead provider cannot hold up the others.
    final results = await Future.wait(
      targets.map(
        (adapter) => _invoker.invokeList<Track>(
          adapter.providerId,
          adapter.displayName,
          () => call(adapter),
          policy: ProviderExecutionPolicy.discovery,
        ),
      ),
    );

    final combined = <Track>[
      for (final list in results)
        ...list,
    ];

    if (excludeTrackId != null) {
      combined.removeWhere((t) => t.id == excludeTrackId);
    }

    // Deduplicate consolidates cross-provider duplicates into a single Track
    // whose `sources` list holds one AudioSourceCandidate per provider.
    final merged = Track.deduplicate(combined);
    final limited = merged.length > limit ? merged.sublist(0, limit) : merged;

    if (limited.isNotEmpty) {
      _cache.set(cacheKey, limited, ttl: ttl);
      return limited;
    }

    // Terminal fallback: every provider failed or returned nothing. Serve the
    // last known good result rather than surfacing an error to the user.
    final stale = _cache.getStale<List<Track>>(cacheKey);
    if (stale != null && stale.isNotEmpty) {
      _invoker.diagnostics.totalStaleCacheServes++;
      debugPrint('[MusicCatalogAggregator] serving stale cache for $cacheKey');
      return stale;
    }
    return const [];
  }

  /// Searches tracks across every targeted catalog provider.
  Future<List<Track>> searchTracks(
    String query, {
    int limit = 25,
    String providerFilter = 'all',
  }) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return Future.value(const <Track>[]);

    return _fanOutTracks(
      cacheKey: '${MusicCacheService.nsAggregatedSearch}::${trimmed.toLowerCase()}::'
          '$providerFilter::$limit',
      ttl: MusicCacheService.ttlSearch,
      targets: _targets(providerFilter),
      limit: limit,
      call: (adapter) => adapter.searchTracks(trimmed, limit: limit),
    );
  }

  /// Fetches trending / discovery tracks across every targeted provider.
  Future<List<Track>> getTrendingTracks({
    String? genre,
    int limit = 25,
    String providerFilter = 'all',
  }) {
    return _fanOutTracks(
      cacheKey: '${MusicCacheService.nsTrending}::${genre ?? 'all'}::'
          '$providerFilter::$limit',
      ttl: MusicCacheService.ttlTrending,
      targets: _targets(providerFilter),
      limit: limit,
      call: (adapter) => adapter.getTrendingTracks(genre: genre, limit: limit),
    );
  }

  /// Popular tracks. Distinct from [getTrendingTracks] so the home feed can
  /// populate an independent "Popular" shelf with its own cache entry.
  Future<List<Track>> getPopularTracks({int limit = 25, String providerFilter = 'all'}) {
    return _fanOutTracks(
      cacheKey: '${MusicCacheService.nsTrending}::popular::$providerFilter::$limit',
      ttl: MusicCacheService.ttlTrending,
      targets: _targets(providerFilter),
      limit: limit,
      call: (adapter) => adapter.getPopularTracks(limit: limit),
    );
  }

  /// Recently released tracks, sourced from provider discovery then filtered
  /// by release date. Providers without release metadata are skipped.
  Future<List<Track>> getNewReleases({int limit = 20, String providerFilter = 'all'}) async {
    final cacheKey = '${MusicCacheService.nsTrending}::new_releases::$providerFilter::$limit';
    final cached = _cache.get<List<Track>>(cacheKey);
    if (cached != null) return cached;

    final pool = await _fanOutTracks(
      cacheKey: '${MusicCacheService.nsTrending}::release_pool::$providerFilter::${limit * 3}',
      ttl: MusicCacheService.ttlTrending,
      targets: _targets(providerFilter),
      limit: limit * 3,
      call: (adapter) => adapter.getNewReleases(limit: limit * 3),
    );

    final now = DateTime.now();
    final dated = pool.where((t) => t.releaseDate != null).toList()
      ..sort((a, b) => b.releaseDate!.compareTo(a.releaseDate!));

    final recent = dated
        .where((t) => now.difference(t.releaseDate!).inDays.abs() <= 400)
        .take(limit)
        .toList();

    if (recent.isNotEmpty) {
      _cache.set(cacheKey, recent, ttl: MusicCacheService.ttlTrending);
      return recent;
    }
    return pool.take(limit).toList();
  }

  /// Discovers related content for a seed song.
  ///
  /// Fans out three independent signals concurrently, mirroring the way the
  /// reference `watch` page pairs a primary rendition with a "Up next" shelf:
  /// 1. every provider's own related track endpoint,
  /// 2. the seed's artist (for a follow-up artist shelf),
  /// 3. the seed's album (for a similar-albums shelf).
  Future<RelatedContent> getRelatedContent(Track seed, {int limit = 15}) async {
    final cacheKey = '${MusicCacheService.nsRelated}::rich::'
        '${seed.normalizedFingerprint}::$limit';
    final cached = _cache.get<RelatedContent>(cacheKey);
    if (cached != null) return cached;

    final relatedFuture = getRelatedTracks(seed, limit: limit);
    final artistFuture = seed.artistId != null && seed.artistId!.isNotEmpty
        ? getArtist(seed.artistId!, withTracks: false)
        : Future<Artist?>.value(null);
    final albumFuture = seed.albumId != null && seed.albumId!.isNotEmpty
        ? getAlbum(seed.albumId!)
        : Future<Album?>.value(null);

    final results = await Future.wait([relatedFuture, artistFuture, albumFuture]);

    final content = RelatedContent(
      seed: seed,
      tracks: results[0] as List<Track>,
      artists: [if (results[1] != null) results[1] as Artist],
      albums: [if (results[2] != null) results[2] as Album],
    );

    if (content.isNotEmpty) {
      _cache.set(cacheKey, content, ttl: MusicCacheService.ttlRelated);
    }
    return content;
  }

  /// Discovers related tracks for a song across every provider.
  Future<List<Track>> getRelatedTracks(Track track, {int limit = 15}) {
    return _fanOutTracks(
      cacheKey: '${MusicCacheService.nsRelated}::${track.normalizedFingerprint}::$limit',
      ttl: MusicCacheService.ttlRelated,
      targets: _targets('all'),
      limit: limit,
      excludeTrackId: track.id,
      call: (adapter) => adapter.getRelatedTracks(track, limit: limit),
    );
  }

  /// Tracks by the same artist — the artist-page and radio artist signal.
  Future<List<Track>> getArtistTracks(
    String artistIdOrName, {
    int limit = 20,
  }) {
    return _fanOutTracks(
      cacheKey: '${MusicCacheService.nsRelated}::artist_tracks::'
          '${artistIdOrName.toLowerCase()}::$limit',
      ttl: MusicCacheService.ttlArtist,
      targets: _targets('all'),
      limit: limit,
      call: (adapter) => adapter.getArtistTracks(artistIdOrName, limit: limit),
    );
  }

  /// Tracks sharing the seed's genre — the radio genre signal.
  Future<List<Track>> getGenreTracks(String genre, {int limit = 20}) {
    return _fanOutTracks(
      cacheKey: '${MusicCacheService.nsRelated}::genre_tracks::'
          '${genre.toLowerCase()}::$limit',
      ttl: MusicCacheService.ttlTrending,
      targets: _targets('all'),
      limit: limit,
      call: (adapter) => adapter.getTrendingTracks(genre: genre, limit: limit),
    );
  }

  /// Resolves unified artist details by trying each provider in order.
  ///
  /// A single-item lookup must not merge, so this keeps the reference
  /// project's ordered fallback: first provider that yields a usable artist
  /// wins, and a failure simply advances to the next provider.
  Future<Artist?> getArtist(String artistIdOrName, {bool withTracks = true}) async {
    if (artistIdOrName.trim().isEmpty) return null;
    final cacheKey = '${MusicCacheService.nsArtist}::$artistIdOrName::$withTracks';
    final cached = _cache.get<Artist>(cacheKey);
    if (cached != null) return cached;

    for (final adapter in _targets('all')) {
      final artist = await _invoker.invokeFirstSuccessful<Artist>(
        adapter.providerId,
        adapter.displayName,
        () => adapter.getArtistDetails(artistIdOrName),
        policy: ProviderExecutionPolicy.detail,
        isUsable: (value) => value.id.isNotEmpty,
      );
      if (artist != null) {
        final resolved = (artist.popularTracks.isEmpty && withTracks)
            ? artist.copyWithTracks(
                await getArtistTracks(artist.id.isNotEmpty ? artist.id : artist.name),
              )
            : artist;
        _cache.set(cacheKey, resolved, ttl: MusicCacheService.ttlArtist);
        return resolved;
      }
    }

    final stale = _cache.getStale<Artist>(cacheKey);
    if (stale != null) {
      _invoker.diagnostics.totalStaleCacheServes++;
      return stale;
    }
    return null;
  }

  /// Resolves unified album details by trying each provider in order.
  Future<Album?> getAlbum(String albumId) async {
    if (albumId.trim().isEmpty) return null;
    final cacheKey = '${MusicCacheService.nsAlbum}::$albumId';
    final cached = _cache.get<Album>(cacheKey);
    if (cached != null) return cached;

    for (final adapter in _targets('all')) {
      final album = await _invoker.invokeFirstSuccessful<Album>(
        adapter.providerId,
        adapter.displayName,
        () => adapter.getAlbumDetails(albumId),
        policy: ProviderExecutionPolicy.detail,
        isUsable: (value) => value.id.isNotEmpty,
      );
      if (album != null) {
        _cache.set(cacheKey, album, ttl: MusicCacheService.ttlAlbum);
        return album;
      }
    }

    final stale = _cache.getStale<Album>(cacheKey);
    if (stale != null) {
      _invoker.diagnostics.totalStaleCacheServes++;
      return stale;
    }
    return null;
  }

  /// Searches artists across every provider and merges the results.
  ///
  /// Unlike a naive "first non-empty provider wins", this returns the union so
  /// the search page shows artists the user can actually open regardless of
  /// which catalog surfaced them.
  Future<List<Artist>> searchArtists(String query, {int limit = 15}) async {
    if (query.trim().isEmpty) return const [];
    final cacheKey = '${MusicCacheService.nsSearch}::artists::'
        '${query.trim().toLowerCase()}::$limit';
    final cached = _cache.get<List<Artist>>(cacheKey);
    if (cached != null) return cached;

    final results = await Future.wait(
      _targets('all').map(
        (adapter) => _invoker.invokeList<Artist>(
          adapter.providerId,
          adapter.displayName,
          () => adapter.searchArtists(query, limit: limit),
          policy: ProviderExecutionPolicy.discovery,
        ),
      ),
    );

    final merged = _mergeEntities<Artist>(
      [for (final list in results) ...list],
      (a) => a.contentKey,
      (a) => a.name.toLowerCase(),
    );
    final limited = merged.length > limit ? merged.sublist(0, limit) : merged;

    if (limited.isNotEmpty) {
      _cache.set(cacheKey, limited, ttl: MusicCacheService.ttlSearch);
      return limited;
    }
    return _cache.getStale<List<Artist>>(cacheKey) ?? const [];
  }

  /// Searches albums across every provider and merges the results.
  Future<List<Album>> searchAlbums(String query, {int limit = 15}) async {
    if (query.trim().isEmpty) return const [];
    final cacheKey = '${MusicCacheService.nsSearch}::albums::'
        '${query.trim().toLowerCase()}::$limit';
    final cached = _cache.get<List<Album>>(cacheKey);
    if (cached != null) return cached;

    final results = await Future.wait(
      _targets('all').map(
        (adapter) => _invoker.invokeList<Album>(
          adapter.providerId,
          adapter.displayName,
          () => adapter.searchAlbums(query, limit: limit),
          policy: ProviderExecutionPolicy.discovery,
        ),
      ),
    );

    final merged = _mergeEntities<Album>(
      [for (final list in results) ...list],
      (a) => a.contentKey,
      (a) => a.name.toLowerCase(),
    );
    final limited = merged.length > limit ? merged.sublist(0, limit) : merged;

    if (limited.isNotEmpty) {
      _cache.set(cacheKey, limited, ttl: MusicCacheService.ttlSearch);
      return limited;
    }
    return _cache.getStale<List<Album>>(cacheKey) ?? const [];
  }

  /// Resolves a batch of tracks by id with per-item isolation.
  ///
  /// The audio analogue of the reference project's `getVideosByIds`: ids are
  /// resolved concurrently, a failing id never fails the batch, and ids that no
  /// provider recognises are simply omitted.
  Future<Map<String, Track>> getTracksByIds(List<String> ids) async {
    if (ids.isEmpty) return const {};
    final resolved = <String, Track>{};
    final pending = <String>[];

    for (final id in ids) {
      if (id.isEmpty) continue;
      final cached = _cache.get<Track>('${MusicCacheService.nsTrack}::$id');
      if (cached != null) {
        resolved[id] = cached;
      } else {
        pending.add(id);
      }
    }

    final fetched = await Future.wait(pending.map(_resolveTrackById));
    for (var i = 0; i < pending.length; i++) {
      final track = fetched[i];
      if (track != null) {
        resolved[pending[i]] = track;
        _cache.set(
          '${MusicCacheService.nsTrack}::${pending[i]}',
          track,
          ttl: MusicCacheService.ttlAlbum,
        );
      }
    }
    return resolved;
  }

  Future<Track?> _resolveTrackById(String id) async {
    // A provider-prefixed id short-circuits straight to its owning catalog.
    final separator = id.indexOf(':');
    if (separator > 0) {
      final scoped = _targets(id.substring(0, separator));
      if (scoped.length == 1) {
        final adapter = scoped.first;
        return _invoker.invokeFirstSuccessful<Track>(
          adapter.providerId,
          adapter.displayName,
          () => adapter.getTrackById(id.substring(separator + 1)),
          policy: ProviderExecutionPolicy.detail,
          isUsable: (value) => value.id.isNotEmpty,
        );
      }
    }

    for (final adapter in _targets('all')) {
      final track = await _invoker.invokeFirstSuccessful<Track>(
        adapter.providerId,
        adapter.displayName,
        () => adapter.getTrackById(id),
        policy: ProviderExecutionPolicy.detail,
        isUsable: (value) => value.id.isNotEmpty,
      );
      if (track != null) return track;
    }
    return null;
  }

  /// Order-preserving merge that drops duplicates by [keyOf], keeping the first
  /// occurrence and enriching later matches that lack metadata.
  static List<T> _mergeEntities<T>(
    List<T> items,
    String Function(T) keyOf,
    String Function(T) labelOf,
  ) {
    final byKey = <String, T>{};
    final byLabel = <String, T>{};
    final order = <String>[];

    for (final item in items) {
      final key = keyOf(item);
      final label = labelOf(item);
      if (label.isEmpty) continue;

      final existingByKey = byKey[key];
      if (existingByKey != null) {
        byKey[key] = _enrich(existingByKey, item);
        continue;
      }
      final existingByLabel = byLabel[label];
      if (existingByLabel != null) {
        // Same entity surfaced by two catalogs: keep both identities reachable
        // by merging under the first key, but do not duplicate the row.
        final merged = _enrich(existingByLabel, item);
        byKey[key] = merged;
        byLabel[label] = merged;
        continue;
      }
      byKey[key] = item;
      byLabel[label] = item;
      order.add(key);
    }

    return [for (final key in order) if (byKey[key] != null) byKey[key] as T];
  }

  static T _enrich<T>(T existing, T incoming) {
    if (existing is Artist && incoming is Artist) {
      final merged = existing;
      if (merged.artworkUrl == null || merged.artworkUrl!.isEmpty) {
        if (incoming.artworkUrl != null && incoming.artworkUrl!.isNotEmpty) {
          return merged.copyWith(
            artworkUrl: incoming.artworkUrl,
            followersCount: merged.followersCount > 0
                ? merged.followersCount
                : incoming.followersCount,
            bio: merged.bio ?? incoming.bio,
            popularTracks: merged.popularTracks.isNotEmpty
                ? merged.popularTracks
                : incoming.popularTracks,
          ) as T;
        }
      }
      if (merged.popularTracks.isEmpty && incoming.popularTracks.isNotEmpty) {
        return merged.copyWith(popularTracks: incoming.popularTracks) as T;
      }
      return merged;
    }
    if (existing is Album && incoming is Album) {
      final merged = existing;
      if (merged.artworkUrl == null || merged.artworkUrl!.isEmpty) {
        if (incoming.artworkUrl != null && incoming.artworkUrl!.isNotEmpty) {
          return merged.copyWith(artworkUrl: incoming.artworkUrl) as T;
        }
      }
      if (merged.tracks.isEmpty && incoming.tracks.isNotEmpty) {
        return merged.copyWith(tracks: incoming.tracks) as T;
      }
      return merged;
    }
    return existing;
  }

  /// Clears every catalog-derived cache entry.
  void invalidateCatalogCaches() {
    for (final ns in [
      MusicCacheService.nsAggregatedSearch,
      MusicCacheService.nsTrending,
      MusicCacheService.nsRelated,
      MusicCacheService.nsArtist,
      MusicCacheService.nsAlbum,
      MusicCacheService.nsTrack,
      MusicCacheService.nsSearch,
    ]) {
      _cache.invalidatePrefix(ns);
    }
  }
}
