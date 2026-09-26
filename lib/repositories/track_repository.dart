import '../models/track.dart';
import '../services/audius_api_service.dart';
import '../services/local_storage_service.dart';
import '../services/saavn_api_service.dart';

/// Repository that orchestrates data flow between music providers (Audius, JioSaavn) and local storage.
class TrackRepository {
  final AudiusApiService _audiusService;
  final SaavnApiService _saavnService;
  final LocalStorageService _storageService;

  // In-memory cache to avoid redundant API hits during active session
  final Map<String, Track> _trackCache = {};

  TrackRepository({
    required AudiusApiService apiService,
    SaavnApiService? saavnService,
    required LocalStorageService storageService,
  })  : _audiusService = apiService,
        _saavnService = saavnService ?? SaavnApiService(),
        _storageService = storageService;

  AudiusApiService get apiService => _audiusService;
  AudiusApiService get audiusService => _audiusService;
  SaavnApiService get saavnService => _saavnService;
  LocalStorageService get storageService => _storageService;

  /// Fetches trending tracks, supporting 'all', 'saavn', or 'audius'.
  Future<List<Track>> getTrendingTracks({
    String? genre,
    int limit = 20,
    String provider = 'all',
  }) async {
    if (provider == 'saavn') {
      final category = (genre != null && genre != 'All') ? genre : 'Hindi';
      final tracks = await _saavnService.getTrendingTracks(category: category, limit: limit);
      for (final track in tracks) {
        _trackCache[track.id] = track;
      }
      return tracks;
    }

    if (provider == 'audius') {
      final tracks = await _audiusService.getTrendingTracks(genre: genre, limit: limit);
      for (final track in tracks) {
        _trackCache[track.id] = track;
      }
      return tracks;
    }

    // Unified trending: Fetch both and merge
    try {
      final category = (genre != null && genre != 'All') ? genre : 'Hindi';
      final halfLimit = (limit / 2).ceil();
      final results = await Future.wait([
        _saavnService.getTrendingTracks(category: category, limit: halfLimit).catchError((_) => <Track>[]),
        _audiusService.getTrendingTracks(genre: genre, limit: halfLimit).catchError((_) => <Track>[]),
      ]);
      final combined = <Track>[...results[0], ...results[1]];
      for (final track in combined) {
        _trackCache[track.id] = track;
      }
      return combined.isNotEmpty
          ? combined
          : await _audiusService.getTrendingTracks(genre: genre, limit: limit);
    } catch (_) {
      return _audiusService.getTrendingTracks(genre: genre, limit: limit);
    }
  }

  /// Fetches popular / discovery tracks.
  Future<List<Track>> getPopularDiscoveryTracks({int limit = 20, String provider = 'all'}) async {
    return getTrendingTracks(genre: 'All', limit: limit, provider: provider);
  }

  /// Searches tracks matching [query].
  /// [provider] can be 'all', 'saavn', or 'audius'.
  Future<List<Track>> searchTracks(
    String query, {
    int limit = 25,
    String provider = 'all',
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    if (provider == 'saavn') {
      final tracks = await _saavnService.searchTracks(trimmed, limit: limit);
      for (final track in tracks) {
        _trackCache[track.id] = track;
      }
      return tracks;
    }

    if (provider == 'audius') {
      final tracks = await _audiusService.searchTracks(query: trimmed, limit: limit);
      for (final track in tracks) {
        _trackCache[track.id] = track;
      }
      return tracks;
    }

    // Unified: Query both simultaneously
    try {
      final results = await Future.wait([
        _saavnService.searchTracks(trimmed, limit: limit).catchError((_) => <Track>[]),
        _audiusService.searchTracks(query: trimmed, limit: limit).catchError((_) => <Track>[]),
      ]);
      final saavnTracks = results[0];
      final audiusTracks = results[1];

      // Merge results with Saavn leading for Bollywood / mainstream relevance
      final combined = <Track>[...saavnTracks, ...audiusTracks];
      for (final track in combined) {
        _trackCache[track.id] = track;
      }
      return combined;
    } catch (_) {
      final tracks = await _saavnService.searchTracks(trimmed, limit: limit);
      for (final track in tracks) {
        _trackCache[track.id] = track;
      }
      return tracks;
    }
  }

  /// Retrieves track by ID from cache or API.
  Future<Track> getTrackById(String trackId) async {
    if (_trackCache.containsKey(trackId)) {
      return _trackCache[trackId]!;
    }

    // Try Saavn first
    final saavnTrack = await _saavnService.getTrackById(trackId);
    if (saavnTrack != null) {
      _trackCache[saavnTrack.id] = saavnTrack;
      return saavnTrack;
    }

    final track = await _audiusService.getTrackById(trackId);
    _trackCache[track.id] = track;
    return track;
  }

  /// Resolves the playable streaming URL for a track.
  Future<String> resolveTrackStreamUrl(Track track) async {
    // 1. If direct stream URL already exists, return immediately
    if (track.streamInfo.directStreamUrl != null &&
        track.streamInfo.directStreamUrl!.isNotEmpty) {
      return track.streamInfo.directStreamUrl!;
    }

    // 2. If provider is Saavn, re-fetch and decrypt
    if (track.provider == 'saavn') {
      final saavnTrack = await _saavnService.getTrackById(track.id);
      if (saavnTrack?.streamInfo.directStreamUrl != null &&
          saavnTrack!.streamInfo.directStreamUrl!.isNotEmpty) {
        return saavnTrack.streamInfo.directStreamUrl!;
      }
    }

    // 3. Fallback to Audius redirect
    final resolvedUrl = await _audiusService.resolveStreamUrl(track.id);
    if (resolvedUrl.isNotEmpty) {
      return resolvedUrl;
    }

    // Fallback to canonical URL
    return track.streamInfo.getEffectiveStreamUrl(
      trackId: track.id,
      baseUrl: _audiusService.baseUrl,
      appName: _audiusService.appName,
      apiKey: _audiusService.apiKey,
    );
  }

  // --- Persistence Wrappers ---

  List<Track> getFavorites() => _storageService.getFavorites();

  bool isFavorite(String trackId) => _storageService.isFavorite(trackId);

  Future<bool> toggleFavorite(Track track) async {
    return _storageService.toggleFavorite(track);
  }

  List<Track> getRecentlyPlayed() =>
      _storageService.getRecentlyPlayed().map((item) => item.track).toList();

  Future<bool> addToRecentlyPlayed(Track track) async {
    _trackCache[track.id] = track;
    return _storageService.recordPlayedTrack(track);
  }

  Future<bool> clearRecentlyPlayed() => _storageService.clearRecentlyPlayed();

  // --- Search History Wrappers ---

  List<String> getSearchHistory() => _storageService.getSearchHistory();

  Future<bool> addSearchQuery(String query) => _storageService.addSearchQuery(query);

  Future<bool> removeSearchQuery(String query) => _storageService.removeSearchQuery(query);

  Future<bool> clearSearchHistory() => _storageService.clearSearchHistory();
}
