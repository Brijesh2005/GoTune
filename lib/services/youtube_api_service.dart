import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/track.dart';

/// Comprehensive YouTube Music discovery and metadata service.
/// Uses resilient multi-instance fallback (Invidious, Piped, Official API, SuggestQueries).
/// STRICTLY METADATA & DISCOVERY ONLY — NO STREAM EXTRACTION, NO DRM CIRCUMVENTION.
class YouTubeApiService {
  final http.Client _client;
  final String? _apiKey;

  // Curated list of public Invidious instances with automatic failover
  static const List<String> _invidiousInstances = [
    'https://inv.tux.pizza',
    'https://invidious.nerdvpn.de',
    'https://vid.priv.au',
    'https://invidious.projectsegfau.lt',
    'https://invidious.slipfox.xyz',
  ];

  // Curated list of public Piped instances
  static const List<String> _pipedInstances = [
    'https://pipedapi.kavin.rocks',
    'https://piped-api.lunar.icu',
    'https://api.piped.privacydev.net',
  ];

  int _invidiousIndex = 0;
  int _pipedIndex = 0;

  // In-memory cache for search & discovery with 10-minute TTL
  final Map<String, ({List<Track> tracks, DateTime expiresAt})> _cache = {};

  YouTubeApiService({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _apiKey = apiKey;

  /// Returns Google search query auto-completions for music.
  Future<List<String>> getSearchSuggestions(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    try {
      final uri = Uri.parse(
        'https://suggestqueries.google.com/complete/search?client=firefox&ds=yt&q=${Uri.encodeComponent(trimmed)}',
      );
      final response = await _client.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List && decoded.length > 1 && decoded[1] is List) {
          return (decoded[1] as List).map((e) => e.toString()).toList();
        }
      }
    } catch (e) {
      debugPrint('[YouTubeApiService] Suggestions error: $e');
    }
    return [];
  }

  /// Searches tracks across YouTube discovery providers with automated fallback.
  Future<List<Track>> searchTracks(String query, {int limit = 20}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final cacheKey = 'yt_search::${trimmed.toLowerCase()}::$limit';
    final cached = _cache[cacheKey];
    if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
      return cached.tracks;
    }

    List<Track> results = [];

    // 1. Try InnerTube (keyless public web endpoint from reference architecture)
    results = await _searchWithInnerTube(trimmed, limit: limit);

    // 2. Try Official YouTube Data API if configured
    if (results.isEmpty && _apiKey != null && _apiKey!.isNotEmpty) {
      results = await _searchWithOfficialApi(trimmed, limit: limit);
    }

    // 3. Try Invidious instances with failover
    if (results.isEmpty) {
      results = await _searchWithInvidious(trimmed, limit: limit);
    }

    // 4. Try Piped instances with failover
    if (results.isEmpty) {
      results = await _searchWithPiped(trimmed, limit: limit);
    }

    // 5. Safe fallback: generate metadata tracks from Google search suggestions
    if (results.isEmpty) {
      results = await _searchWithSuggestionsFallback(trimmed, limit: limit);
    }

    if (results.isNotEmpty) {
      _cache[cacheKey] = (
        tracks: results,
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      );
    }

    return results;
  }

  /// Fetches trending music tracks from discovery endpoints with failover.
  Future<List<Track>> getTrendingMusic({int limit = 20}) async {
    const cacheKey = 'yt_trending';
    final cached = _cache[cacheKey];
    if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
      return cached.tracks;
    }

    List<Track> results = [];

    // Try Invidious music trending
    for (int i = 0; i < 2; i++) {
      final base = _getNextInvidious();
      try {
        final uri = Uri.parse('$base/api/v1/trending?type=music');
        final response = await _client.get(uri).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is List) {
            results = decoded
                .take(limit)
                .whereType<Map<String, dynamic>>()
                .map((json) => Track.fromYouTubeJson(json))
                .toList();
            if (results.isNotEmpty) break;
          }
        }
      } catch (_) {}
    }

    // Fallback to Piped trending
    if (results.isEmpty) {
      for (int i = 0; i < 2; i++) {
        final base = _getNextPiped();
        try {
          final uri = Uri.parse('$base/trending?region=US');
          final response = await _client.get(uri).timeout(const Duration(seconds: 4));
          if (response.statusCode == 200) {
            final decoded = jsonDecode(response.body);
            if (decoded is List) {
              results = decoded
                  .take(limit)
                  .whereType<Map<String, dynamic>>()
                  .map((json) => _trackFromPipedJson(json))
                  .toList();
              if (results.isNotEmpty) break;
            }
          }
        } catch (_) {}
      }
    }

    if (results.isNotEmpty) {
      _cache[cacheKey] = (
        tracks: results,
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      );
    }

    return results;
  }

  // --- Internal Failover Helpers ---

  Future<List<Track>> _searchWithInvidious(String query, {int limit = 20}) async {
    for (int attempts = 0; attempts < 3; attempts++) {
      final base = _getNextInvidious();
      try {
        final uri = Uri.parse(
          '$base/api/v1/search?q=${Uri.encodeComponent(query)}&type=video',
        );
        final res = await _client.get(uri).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body);
          if (decoded is List) {
            final tracks = decoded
                .take(limit)
                .whereType<Map<String, dynamic>>()
                .map((json) => Track.fromYouTubeJson(json))
                .toList();
            if (tracks.isNotEmpty) return tracks;
          }
        }
      } catch (e) {
        debugPrint('[YouTubeApiService] Invidious instance ($base) failed: $e');
      }
    }
    return [];
  }

  Future<List<Track>> _searchWithPiped(String query, {int limit = 20}) async {
    for (int attempts = 0; attempts < 2; attempts++) {
      final base = _getNextPiped();
      try {
        final uri = Uri.parse(
          '$base/search?q=${Uri.encodeComponent(query)}&filter=music_songs',
        );
        final res = await _client.get(uri).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body);
          if (decoded is Map && decoded['items'] is List) {
            final items = decoded['items'] as List;
            final tracks = items
                .take(limit)
                .whereType<Map<String, dynamic>>()
                .map((json) => _trackFromPipedJson(json))
                .toList();
            if (tracks.isNotEmpty) return tracks;
          }
        }
      } catch (e) {
        debugPrint('[YouTubeApiService] Piped instance ($base) failed: $e');
      }
    }
    return [];
  }

  Future<List<Track>> _searchWithOfficialApi(String query, {int limit = 20}) async {
    try {
      final uri = Uri.parse(
        'https://www.googleapis.com/youtube/v3/search?part=snippet&type=video&videoCategoryId=10&q=${Uri.encodeComponent(query)}&maxResults=$limit&key=$_apiKey',
      );
      final res = await _client.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['items'] is List) {
          final items = decoded['items'] as List;
          return items.whereType<Map<String, dynamic>>().map((item) {
            final snippet = item['snippet'] as Map<String, dynamic>? ?? {};
            final idObj = item['id'] as Map<String, dynamic>? ?? {};
            final videoId = idObj['videoId']?.toString() ?? '';
            final thumbs = snippet['thumbnails'] as Map<String, dynamic>?;
            final highThumb = thumbs?['high']?['url']?.toString();
            final defThumb = thumbs?['default']?['url']?.toString();

            return Track.fromMetadata(
              id: 'yt_$videoId',
              title: snippet['title']?.toString() ?? 'Untitled Track',
              artist: snippet['channelTitle']?.toString() ?? 'YouTube Artist',
              artworkUrl: highThumb ?? defThumb,
              provider: 'youtube',
              sourceType: 'metadata',
            );
          }).toList();
        }
      }
    } catch (e) {
      debugPrint('[YouTubeApiService] Official API search error: $e');
    }
    return [];
  }

  Future<List<Track>> _searchWithSuggestionsFallback(String query, {int limit = 20}) async {
    final suggestions = await getSearchSuggestions(query);
    final results = <Track>[];
    for (int i = 0; i < suggestions.length && results.length < limit; i++) {
      final title = suggestions[i];
      results.add(
        Track.fromMetadata(
          id: 'yt_meta_${title.hashCode}',
          title: title,
          artist: 'Universal Search',
          genre: 'Music',
          provider: 'youtube_meta',
          sourceType: 'metadata',
        ),
      );
    }
    return results;
  }

  Track _trackFromPipedJson(Map<String, dynamic> json) {
    final url = json['url']?.toString() ?? '';
    final videoId = url.contains('v=') ? url.split('v=').last : (json['id']?.toString() ?? '');
    final durationSec = (json['duration'] as num?)?.toInt() ?? 0;
    final thumb = json['thumbnail']?.toString();

    return Track(
      id: 'yt_$videoId',
      youtubeVideoId: videoId,
      title: json['title']?.toString() ?? 'Untitled Track',
      artist: json['uploaderName']?.toString() ?? 'YouTube Artist',
      artworkUrl150: thumb,
      artworkUrl480: thumb,
      durationSeconds: durationSec,
      genre: 'Music',
      source: 'youtube',
    );
  }

  String _getNextInvidious() {
    final instance = _invidiousInstances[_invidiousIndex % _invidiousInstances.length];
    _invidiousIndex++;
    return instance;
  }

  String _getNextPiped() {
    final instance = _pipedInstances[_pipedIndex % _pipedInstances.length];
    _pipedIndex++;
    return instance;
  }

  static const String _innerTubeKey = 'AIzaSyAO_FL9IsIrOS3wgxHhpkGkY74dxHb0X8Y';

  Future<List<Track>> _searchWithInnerTube(String query, {int limit = 20}) async {
    try {
      final uri = Uri.parse(
        'https://www.youtube.com/youtubei/v1/search?key=$_innerTubeKey&prettyPrint=false',
      );
      final body = jsonEncode({
        'context': {
          'client': {
            'clientName': 'WEB',
            'clientVersion': '2.20240726.00.00',
            'hl': 'en',
            'gl': 'US',
          }
        },
        'query': query,
      });

      final res = await _client.post(
        uri,
        headers: {
          'content-type': 'application/json',
          'x-youtube-client-name': '1',
          'x-youtube-client-version': '2.20240726.00.00',
          'user-agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0 Safari/537.36',
        },
        body: body,
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        return _extractInnerTubeVideos(decoded, limit: limit);
      }
    } catch (e) {
      debugPrint('[YouTubeApiService] InnerTube search fallback note: $e');
    }
    return [];
  }

  /// Discovers related tracks using InnerTube "next" watch recommendations or search fallback.
  Future<List<Track>> getRelatedTracks(Track track, {int limit = 15}) async {
    final videoId = track.providerTrackId ?? (track.id.startsWith('yt_') ? track.id.substring(3) : null);
    if (videoId != null && videoId.isNotEmpty) {
      try {
        final uri = Uri.parse(
          'https://www.youtube.com/youtubei/v1/next?key=$_innerTubeKey&prettyPrint=false',
        );
        final res = await _client.post(
          uri,
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'context': {
              'client': {'clientName': 'WEB', 'clientVersion': '2.20240726.00.00'}
            },
            'videoId': videoId,
          }),
        ).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body);
          final related = _extractInnerTubeVideos(decoded, limit: limit);
          if (related.isNotEmpty) return related;
        }
      } catch (e) {
        debugPrint('[YouTubeApiService] Related videos fallback note: $e');
      }
    }

    // Fallback: search by title + artist
    final q = '${track.title} ${track.artist}'.trim();
    return searchTracks(q, limit: limit);
  }

  List<Track> _extractInnerTubeVideos(dynamic json, {int limit = 20}) {
    final results = <Track>[];
    void walk(dynamic node) {
      if (node == null || results.length >= limit) return;
      if (node is List) {
        for (final item in node) {
          walk(item);
          if (results.length >= limit) return;
        }
      } else if (node is Map) {
        final renderer = node['videoRenderer'] ?? node['compactVideoRenderer'];
        if (renderer is Map) {
          final videoId = renderer['videoId']?.toString() ?? '';
          if (videoId.isNotEmpty) {
            String title = '';
            final titleObj = renderer['title'];
            if (titleObj is Map) {
              if (titleObj['simpleText'] != null) {
                title = titleObj['simpleText'].toString();
              } else if (titleObj['runs'] is List && (titleObj['runs'] as List).isNotEmpty) {
                title = (titleObj['runs'] as List).map((r) => r['text'] ?? '').join('');
              }
            }

            String author = 'YouTube Artist';
            final byline = renderer['longBylineText'] ?? renderer['shortBylineText'];
            if (byline is Map && byline['runs'] is List && (byline['runs'] as List).isNotEmpty) {
              author = (byline['runs'] as List).map((r) => r['text'] ?? '').join('');
            }

            String thumb = 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
            final thumbs = renderer['thumbnail']?['thumbnails'];
            if (thumbs is List && thumbs.isNotEmpty) {
              thumb = thumbs.last['url']?.toString() ?? thumb;
            }

            if (title.isNotEmpty) {
              results.add(
                Track.fromMetadata(
                  id: 'yt_$videoId',
                  title: title,
                  artist: author,
                  artworkUrl: thumb,
                  provider: 'youtube',
                  sourceType: 'metadata',
                ),
              );
            }
          }
        }
        node.forEach((_, v) => walk(v));
      }
    }

    walk(json);
    return results;
  }

  void close() {
    _client.close();
  }
}
