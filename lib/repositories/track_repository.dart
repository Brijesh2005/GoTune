import '../models/track.dart';
import '../services/audius_api_service.dart';
import '../services/local_storage_service.dart';
import '../services/saavn_api_service.dart';
import '../services/youtube_api_service.dart';

/// Repository that orchestrates data flow between music providers (Audius, JioSaavn, YouTube) and local storage.
class TrackRepository {
  final AudiusApiService _audiusService;
  final SaavnApiService _saavnService;
  final YouTubeApiService _youtubeService;
  final LocalStorageService _storageService;

  // In-memory cache to avoid redundant API hits during active session
  final Map<String, Track> _trackCache = {};

  TrackRepository({
    required AudiusApiService apiService,
    SaavnApiService? saavnService,
    YouTubeApiService? youtubeService,
    required LocalStorageService storageService,
  })  : _audiusService = apiService,
        _saavnService = saavnService ?? SaavnApiService(),
        _youtubeService = youtubeService ?? YouTubeApiService(),
        _storageService = storageService;

  AudiusApiService get apiService => _audiusService;
  AudiusApiService get audiusService => _audiusService;
  SaavnApiService get saavnService => _saavnService;
  YouTubeApiService get youtubeService => _youtubeService;
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
  /// [provider] can be 'all', 'saavn', 'youtube', or 'audius'.
  Future<List<Track>> searchTracks(
    String query, {
    int limit = 25,
    String provider = 'all',
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    if (provider == 'youtube') {
      final tracks = await _youtubeService.searchTracks(trimmed, limit: limit);
      for (final track in tracks) {
        _trackCache[track.id] = track;
      }
      return tracks;
    }

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

    // Unified: Query JioSaavn, YouTube, and Audius simultaneously
    try {
      final results = await Future.wait([
        _saavnService.searchTracks(trimmed, limit: limit).catchError((_) => <Track>[]),
        _youtubeService.searchTracks(trimmed, limit: limit).catchError((_) => <Track>[]),
        _audiusService.searchTracks(query: trimmed, limit: limit).catchError((_) => <Track>[]),
      ]);
      final saavnTracks = results[0];
      final youtubeTracks = results[1];
      final audiusTracks = results[2];

      final queryLower = trimmed.toLowerCase();

      // Check if YouTube has an exact or primary artist match while Saavn only has covers
      final saavnHasArtist = saavnTracks.isNotEmpty &&
          saavnTracks.take(3).any((t) =>
              queryLower.contains(t.artist.toLowerCase()) ||
              t.artist.toLowerCase().contains(queryLower));

      final ytHasArtist = youtubeTracks.isNotEmpty &&
          youtubeTracks.take(3).any((t) =>
              queryLower.contains(t.artist.toLowerCase()) ||
              t.artist.toLowerCase().contains(queryLower));

      final List<Track> combined;
      if (!saavnHasArtist && ytHasArtist) {
        // YouTube has the official artist match (e.g. Adele's Lovesong), so lead with YouTube!
        combined = _mergeAndDeduplicate(youtubeTracks, saavnTracks, audiusTracks);
      } else {
        // Interleave Saavn and YouTube, providing high-bitrate Saavn along with YouTube universality
        combined = _mergeAndDeduplicate(saavnTracks, youtubeTracks, audiusTracks);
      }

      for (final track in combined) {
        _trackCache[track.id] = track;
      }
      return combined;
    } catch (_) {
      final tracks = await _youtubeService.searchTracks(trimmed, limit: limit);
      for (final track in tracks) {
        _trackCache[track.id] = track;
      }
      return tracks;
    }
  }

  /// Merges and deduplicates tracks across providers by normalized artist & title.
  List<Track> _mergeAndDeduplicate(
    List<Track> primary,
    List<Track> secondary,
    List<Track> tertiary,
  ) {
    final seen = <String>{};
    final result = <Track>[];

    String normKey(Track t) {
      final a = t.artist.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final title = t.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      return '$a::$title';
    }

    final maxLen = primary.length > secondary.length ? primary.length : secondary.length;
    for (int i = 0; i < maxLen; i++) {
      if (i < primary.length) {
        final t = primary[i];
        final k = normKey(t);
        if (k.length > 3 && seen.add(k)) {
          result.add(t);
        } else if (k.length <= 3) {
          result.add(t);
        }
      }
      if (i < secondary.length) {
        final t = secondary[i];
        final k = normKey(t);
        if (k.length > 3 && seen.add(k)) {
          result.add(t);
        } else if (k.length <= 3) {
          result.add(t);
        }
      }
    }

    for (final t in tertiary) {
      final k = normKey(t);
      if (k.length > 3 && seen.add(k)) {
        result.add(t);
      } else if (k.length <= 3) {
        result.add(t);
      }
    }

    return result;
  }

  /// Retrieves track by ID from cache or API.
  Future<Track> getTrackById(String trackId) async {
    if (_trackCache.containsKey(trackId)) {
      return _trackCache[trackId]!;
    }

    // Try YouTube if ID starts with yt_
    if (trackId.startsWith('yt_')) {
      final ytTrack = await _youtubeService.getTrackById(trackId);
      if (ytTrack != null) {
        _trackCache[ytTrack.id] = ytTrack;
        return ytTrack;
      }
    }

    // Try Saavn first
    final saavnTrack = await _saavnService.getTrackById(trackId);
    if (saavnTrack != null) {
      _trackCache[saavnTrack.id] = saavnTrack;
      return saavnTrack;
    }

    // Try Audius
    try {
      final track = await _audiusService.getTrackById(trackId);
      _trackCache[track.id] = track;
      return track;
    } catch (_) {}

    // Fallback to YouTube
    final ytTrack = await _youtubeService.getTrackById(trackId);
    if (ytTrack != null) {
      _trackCache[ytTrack.id] = ytTrack;
      return ytTrack;
    }

    throw Exception('Track not found: $trackId');
  }

  /// Resolves the playable streaming URL for a track.
  Future<String> resolveTrackStreamUrl(Track track) async {
    // 1. If provider is YouTube, resolve fresh stream URL from YouTube
    if (track.provider == 'youtube' || track.id.startsWith('yt_')) {
      final ytUrl = await _youtubeService.resolveStreamUrl(track.id);
      if (ytUrl != null && ytUrl.isNotEmpty) {
        return ytUrl;
      }
    }

    // 2. If direct stream URL already exists, return immediately
    if (track.streamInfo.directStreamUrl != null &&
        track.streamInfo.directStreamUrl!.isNotEmpty) {
      return track.streamInfo.directStreamUrl!;
    }

    // 3. If provider is Saavn, re-fetch and decrypt
    if (track.provider == 'saavn') {
      final saavnTrack = await _saavnService.getTrackById(track.id);
      if (saavnTrack?.streamInfo.directStreamUrl != null &&
          saavnTrack!.streamInfo.directStreamUrl!.isNotEmpty) {
        return saavnTrack.streamInfo.directStreamUrl!;
      }
    }

    // 4. Fallback to Audius redirect
    if (track.provider == 'audius') {
      final resolvedUrl = await _audiusService.resolveStreamUrl(track.id);
      if (resolvedUrl.isNotEmpty) {
        return resolvedUrl;
      }
    }

    // 5. Automatic YouTube Audio Fallback:
    // If a track from Saavn or Audius has no playable stream, automatically
    // find the matching audio on YouTube and resolve its stream!
    final fallbackUrl = await _youtubeService.resolveFallbackStreamUrl(
      title: track.title,
      artist: track.artist,
    );
    if (fallbackUrl != null && fallbackUrl.isNotEmpty) {
      return fallbackUrl;
    }

    // 6. Fallback to canonical URL
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
