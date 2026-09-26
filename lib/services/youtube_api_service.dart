import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/track.dart';

/// Service providing music search and high-bitrate audio stream extraction
/// via YouTube and YouTube Music. Gives GoTune access to virtually any song worldwide.
class YouTubeApiService {
  final YoutubeExplode _yt;

  // Stream URL cache: videoId -> (url, expiry)
  // YouTube URLs usually expire after 6 hours; we cache for 4 hours.
  final Map<String, ({String url, DateTime expiresAt})> _streamCache = {};

  YouTubeApiService({YoutubeExplode? client}) : _yt = client ?? YoutubeExplode();

  /// Searches YouTube for tracks matching [query].
  /// Filters out long podcasts/videos and converts results to [Track] models.
  Future<List<Track>> searchTracks(
    String query, {
    int limit = 25,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    int attempts = 0;
    while (attempts < 3) {
      attempts++;
      try {
        final searchResults = await _yt.search.search(trimmed);
        final tracks = <Track>[];

        for (final video in searchResults) {
          // Skip live streams or empty durations
          if (video.duration == null || video.duration == Duration.zero) continue;
          // Skip excessively long media (e.g. 1-hour compilations/podcasts, keep <= 20 mins)
          if (video.duration!.inMinutes > 20) continue;

          final track = Track.fromYoutubeVideo(video);
          tracks.add(track);

          if (tracks.length >= limit) break;
        }

        return tracks;
      } catch (e) {
        debugPrint('[YouTubeApiService] searchTracks attempt $attempts error: $e');
        if (attempts >= 3) break;
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    return [];
  }

  /// Resolves the highest bitrate direct audio stream URL for a given YouTube [videoIdOrTrackId].
  /// Checks cache first before requesting manifests from YouTube.
  Future<String?> resolveStreamUrl(String videoIdOrTrackId) async {
    final cleanId = videoIdOrTrackId.startsWith('yt_')
        ? videoIdOrTrackId.substring(3)
        : videoIdOrTrackId;

    if (cleanId.trim().isEmpty) return null;

    // Check cache
    final cached = _streamCache[cleanId];
    if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
      return cached.url;
    }

    try {
      final manifest = await _yt.videos.streamsClient.getManifest(cleanId);
      final audioStreams = manifest.audioOnly;
      if (audioStreams.isEmpty) return null;

      final bestAudio = audioStreams.withHighestBitrate();
      final streamUrl = bestAudio.url.toString();

      // Cache for 4 hours
      _streamCache[cleanId] = (
        url: streamUrl,
        expiresAt: DateTime.now().add(const Duration(hours: 4)),
      );

      return streamUrl;
    } catch (e) {
      debugPrint('[YouTubeApiService] resolveStreamUrl error for $cleanId: $e');
      return null;
    }
  }

  /// Resolves a fallback audio stream on YouTube by searching for [title] and [artist].
  /// Used when another provider's stream URL fails or is unavailable.
  Future<String?> resolveFallbackStreamUrl({
    required String title,
    required String artist,
  }) async {
    try {
      final query = '$artist - $title audio';
      final tracks = await searchTracks(query, limit: 3);

      for (final track in tracks) {
        if (track.durationSeconds > 15 * 60) continue;

        final url = await resolveStreamUrl(track.id);
        if (url != null && url.isNotEmpty) {
          debugPrint('[YouTubeApiService] Successfully resolved fallback audio from YouTube: "${track.title}"');
          return url;
        }
      }
      return null;
    } catch (e) {
      debugPrint('[YouTubeApiService] resolveFallbackStreamUrl error: $e');
      return null;
    }
  }

  /// Fetches track metadata by [trackId].
  Future<Track?> getTrackById(String trackId) async {
    final cleanId = trackId.startsWith('yt_') ? trackId.substring(3) : trackId;
    try {
      final video = await _yt.videos.get(cleanId);
      final streamUrl = await resolveStreamUrl(cleanId);
      return Track.fromYoutubeVideo(video, resolvedStreamUrl: streamUrl);
    } catch (e) {
      debugPrint('[YouTubeApiService] getTrackById error for $cleanId: $e');
      return null;
    }
  }

  /// Closes the underlying HTTP client.
  void close() {
    _yt.close();
  }
}
