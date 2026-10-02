import 'dart:async';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/track.dart';
import '../services/local_storage_service.dart';
import '../services/music_cache_service.dart';
import '../services/music_catalog_aggregator.dart';
import '../services/music_catalog_provider.dart';
import '../services/youtube_api_service.dart';

/// Central repository managing YouTube music catalog discovery and caching.
/// Pure YouTube architecture: search/discovery returns YouTube tracks with
/// YouTube Video IDs for playback in the embedded YouTube IFrame Player.
class TrackRepository {
  final YouTubeCatalogProvider _youtubeProvider;
  final MusicCatalogAggregator _catalogAggregator;
  final MusicCacheService _cacheService;
  final LocalStorageService _storageService;

  // In-memory short-term track cache
  final Map<String, Track> _trackCache = {};

  TrackRepository({
    YouTubeApiService? youtubeService,
    YouTubeCatalogProvider? youtubeProvider,
    MusicCatalogAggregator? catalogAggregator,
    MusicCacheService? cacheService,
    required LocalStorageService storageService,
  })  : _youtubeProvider = youtubeProvider ??
            YouTubeCatalogProvider(service: youtubeService ?? YouTubeApiService()),
        _cacheService = cacheService ?? MusicCacheService(),
        _catalogAggregator = catalogAggregator ??
            MusicCatalogAggregator(
              youtubeProvider: youtubeProvider ??
                  YouTubeCatalogProvider(service: youtubeService ?? YouTubeApiService()),
              cacheService: cacheService,
            ),
        _storageService = storageService;

  YouTubeApiService get youtubeService => _youtubeProvider.service;
  YouTubeCatalogProvider get youtubeProvider => _youtubeProvider;
  MusicCatalogAggregator get catalogAggregator => _catalogAggregator;
  MusicCacheService get cacheService => _cacheService;
  LocalStorageService get storageService => _storageService;

  /// Fetches trending tracks from YouTube.
  Future<List<Track>> getTrendingTracks({
    String? genre,
    int limit = 15,
    String provider = 'youtube',
  }) async {
    final tracks = await _catalogAggregator.getTrendingTracks(
      genre: genre,
      limit: limit,
      providerFilter: 'youtube',
    );
    _cacheTracks(tracks);
    return tracks;
  }

  /// Fetches popular / discovery tracks from YouTube.
  Future<List<Track>> getPopularDiscoveryTracks({int limit = 15, String provider = 'youtube'}) async {
    return getTrendingTracks(genre: 'All', limit: limit, provider: provider);
  }

  /// Searches tracks on YouTube matching [query].
  Future<List<Track>> searchTracks(
    String query, {
    int limit = 25,
    String provider = 'youtube',
  }) async {
    final tracks = await _catalogAggregator.searchTracks(
      query,
      limit: limit,
      providerFilter: 'youtube',
    );
    _cacheTracks(tracks);
    return tracks;
  }

  /// Searches artists in the YouTube catalog.
  Future<List<Artist>> searchArtists(String query, {int limit = 15}) async {
    return _catalogAggregator.searchArtists(query, limit: limit);
  }

  /// Searches albums in the YouTube catalog.
  Future<List<Album>> searchAlbums(String query, {int limit = 15}) async {
    return _catalogAggregator.searchAlbums(query, limit: limit);
  }

  /// Fetches artist details by [artistId].
  Future<Artist?> getArtistDetails(String artistId) async {
    final artist = await _catalogAggregator.getArtist(artistId);
    if (artist != null) {
      _cacheTracks(artist.popularTracks);
    }
    return artist;
  }

  /// Fetches album details by [albumId].
  Future<Album?> getAlbumDetails(String albumId) async {
    final album = await _catalogAggregator.getAlbum(albumId);
    if (album != null) {
      _cacheTracks(album.tracks);
    }
    return album;
  }

  /// Fetches related tracks for [track] on YouTube.
  Future<List<Track>> getRelatedTracks(Track track, {int limit = 15}) async {
    final related = await _catalogAggregator.getRelatedTracks(track, limit: limit);
    _cacheTracks(related);
    return related;
  }

  /// Fetches tracks by an artist from YouTube.
  Future<List<Track>> getArtistTracks(String artistIdOrName, {int limit = 20}) async {
    final tracks = await _catalogAggregator.getArtistTracks(artistIdOrName, limit: limit);
    _cacheTracks(tracks);
    return tracks;
  }

  /// Retrieves a single track by [id], checking memory cache first.
  Future<Track?> getTrackById(String id) async {
    if (_trackCache.containsKey(id)) {
      return _trackCache[id];
    }

    try {
      final track = await _youtubeProvider.getTrackById(id);
      if (track != null) {
        _trackCache[id] = track;
      }
      return track;
    } catch (_) {
      return null;
    }
  }

  void _cacheTracks(List<Track> tracks) {
    for (final track in tracks) {
      _trackCache[track.id] = track;
    }
  }

  void clearCache() {
    _trackCache.clear();
    _cacheService.clear();
  }

  // --- Search History Delegates ---
  List<String> getSearchHistory() => _storageService.getSearchHistory();
  Future<bool> addSearchQuery(String query) => _storageService.addSearchQuery(query);
  Future<bool> removeSearchQuery(String query) => _storageService.removeSearchQuery(query);
  Future<bool> clearSearchHistory() => _storageService.clearSearchHistory();

  // --- Library / Favorites / Recents Delegates ---
  List<Track> getFavorites() => _storageService.getFavorites();
  Future<bool> toggleFavorite(Track track) => _storageService.toggleFavorite(track);
  List<Track> getRecentlyPlayed() => _storageService.getRecentlyPlayed().map((item) => item.track).toList();
  Future<bool> addToRecentlyPlayed(Track track) => _storageService.recordPlayedTrack(track);
  Future<bool> clearRecentlyPlayed() => _storageService.clearRecentlyPlayed();
}

