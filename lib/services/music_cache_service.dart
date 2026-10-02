/// Centralized bounded in-memory cache service inspired by YouTube-clone's memCache.
/// Provides deterministic TTL caching, LRU-style eviction, and key-prefix invalidation
/// across search, home feeds, trending charts, artist/album metadata, and related audio.
class CacheEntry<T> {
  final String key;
  final T data;
  final DateTime createdAt;
  final DateTime expiresAt;

  CacheEntry({
    required this.key,
    required this.data,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class MusicCacheService {
  static final MusicCacheService _instance = MusicCacheService._internal();
  factory MusicCacheService() => _instance;
  MusicCacheService._internal();

  // Bounded store
  final Map<String, CacheEntry<dynamic>> _store = {};
  static const int maxEntries = 500;
  static const int evictionBatch = 100;

  // Standard TTL defaults inspired by the YouTube-clone reference architecture
  static const Duration ttlSearch = Duration(minutes: 10);
  static const Duration ttlTrending = Duration(minutes: 15);
  static const Duration ttlHomeFeed = Duration(minutes: 15);
  static const Duration ttlRelated = Duration(minutes: 20);
  static const Duration ttlArtist = Duration(minutes: 30);
  static const Duration ttlAlbum = Duration(minutes: 30);
  static const Duration ttlPlaylist = Duration(minutes: 20);
  static const Duration ttlAudioSource = Duration(minutes: 15);
  static const Duration ttlGenres = Duration(hours: 6);
  static const Duration ttlRadio = Duration(minutes: 10);
  static const Duration ttlSongDetail = Duration(minutes: 20);

  // Cache key namespaces. Centralizing them keeps prefix invalidation
  // (e.g. after a settings change) correct and greppable.
  static const String nsSearch = 'search';
  static const String nsAggregatedSearch = 'agg_search';
  static const String nsTrending = 'agg_trending';
  static const String nsRelated = 'agg_related';
  static const String nsArtist = 'agg_artist';
  static const String nsAlbum = 'agg_album';
  static const String nsPlaylist = 'agg_playlist';
  static const String nsTrack = 'agg_track';
  static const String nsSongDetail = 'song_detail';
  static const String nsRadio = 'radio';
  static const String nsGenres = 'genres';
  static const String nsMoods = 'moods';
  static const String nsHomeFeed = 'home_feed';
  static const String nsArtwork = 'artwork';

  /// Retrieves cached item if present and unexpired.
  ///
  /// An expired entry is **not** removed here on purpose: it is the input to
  /// the stale-while-error fallback ([getStale]). Expired entries are purged
  /// during capacity enforcement instead, so a temporarily offline app can
  /// still serve the last known good result.
  T? get<T>(String key) {
    final entry = _store[key];
    if (entry == null) return null;
    if (entry.isExpired) return null;
    return entry.data as T?;
  }

  /// Sets or updates a cache entry with specified TTL.
  void set<T>(String key, T data, {Duration ttl = const Duration(minutes: 15)}) {
    _ensureCapacity();
    final now = DateTime.now();
    _store[key] = CacheEntry<T>(
      key: key,
      data: data,
      createdAt: now,
      expiresAt: now.add(ttl),
    );
  }

  /// Helper for retrieving cached audio source URL
  String? getCachedAudioSource(String trackId) {
    return get<String>('audio_source::$trackId');
  }

  /// Helper for caching audio source URL
  void cacheAudioSource(String trackId, String url, {Duration ttl = ttlAudioSource}) {
    set<String>('audio_source::$trackId', url, ttl: ttl);
  }

  /// Checks whether a valid unexpired entry exists for [key].
  bool has(String key) {
    final entry = _store[key];
    if (entry == null) return false;
    if (entry.isExpired) return false;
    return true;
  }

  /// Retrieves an entry even if it has passed its TTL.
  ///
  /// This is the terminal fallback of the discovery pipeline: when every
  /// catalog provider fails (offline, outage, rate limit), the aggregator
  /// serves the last known good result instead of showing an error. Mirrors
  /// the reference project's `stale-while-revalidate` response headers.
  T? getStale<T>(String key) {
    final entry = _store[key];
    if (entry == null) return null;
    return entry.data as T?;
  }

  /// Removes a specific cache entry.
  void invalidate(String key) {
    _store.remove(key);
  }

  /// Removes all entries matching a prefix (e.g. 'search:', 'artist:').
  void invalidatePrefix(String prefix) {
    _store.removeWhere((key, _) => key.startsWith(prefix));
  }

  /// Clears the entire cache.
  void clear() {
    _store.clear();
  }

  int get size => _store.length;

  void _ensureCapacity() {
    if (_store.length >= maxEntries) {
      // First purge all expired items
      _store.removeWhere((_, entry) => entry.isExpired);

      // If still above threshold, evict oldest entries
      if (_store.length >= maxEntries) {
        final sortedKeys = _store.entries.toList()
          ..sort((a, b) => a.value.createdAt.compareTo(b.value.createdAt));
        final toEvict = sortedKeys.take(evictionBatch);
        for (final item in toEvict) {
          _store.remove(item.key);
        }
      }
    }
  }
}
