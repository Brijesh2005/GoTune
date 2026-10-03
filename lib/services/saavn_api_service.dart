import 'dart:convert';
import 'package:dart_des/dart_des.dart';
import 'package:flutter/foundation.dart';
import 'package:saavn_play/saavn_play.dart';
import '../models/track.dart';

/// Service providing music search, trending charts, and direct 320kbps streaming
/// via the JioSaavn music catalog.
class SaavnApiService {
  final SaavnPlayClient _client;
  static const String _desKey = '38346591';

  SaavnApiService({SaavnPlayClient? client})
      : _client = client ?? SaavnPlayClient();

  /// Decrypts a JioSaavn encrypted media URL into a direct playable stream URL.
  /// Supports [quality] options: '320' (320kbps), '160' (160kbps), or '96' (96kbps).
  String? decryptMediaUrl(String? encryptedMediaUrl, {String quality = '320'}) {
    if (encryptedMediaUrl == null || encryptedMediaUrl.trim().isEmpty) {
      return null;
    }

    try {
      final key = utf8.encode(_desKey);
      final des = DES(key: key, mode: DESMode.ECB, paddingType: DESPaddingType.PKCS7);
      final encryptedBytes = base64.decode(encryptedMediaUrl.trim());
      final decryptedBytes = des.decrypt(encryptedBytes);
      final rawUrl = utf8.decode(decryptedBytes).trim();

      if (rawUrl.isEmpty) return null;

      // Upgrade default 96kbps bitrate to requested quality
      if (quality == '320') {
        return rawUrl.replaceAll('_96.mp4', '_320.mp4');
      } else if (quality == '160') {
        return rawUrl.replaceAll('_96.mp4', '_160.mp4');
      }
      return rawUrl;
    } catch (e) {
      debugPrint('[SaavnApiService] Decryption error: $e');
      return null;
    }
  }

  /// Searches for tracks matching [query].
  /// Directly decrypts stream URLs so the returned [Track] models are immediately playable.
  Future<List<Track>> searchTracks(
    String query, {
    int page = 1,
    int limit = 25,
    String quality = '320',
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    try {
      final response = await _client.search.songs(trimmed, page: page, limit: limit);
      final results = (response['results'] as List<dynamic>?) ?? [];

      final tracks = <Track>[];
      for (final item in results) {
        if (item is Map<String, dynamic>) {
          final moreInfo = item['more_info'] as Map<String, dynamic>?;
          final encrypted = moreInfo?['encrypted_media_url']?.toString();
          final streamUrl = decryptMediaUrl(encrypted, quality: quality);

          final track = Track.fromSaavnJson(
            item,
            decryptedStreamUrl: streamUrl,
          );
          if (track.id.isNotEmpty && track.title.isNotEmpty) {
            tracks.add(track);
          }
        }
      }
      return tracks;
    } catch (e) {
      debugPrint('[SaavnApiService] searchTracks error: $e');
      return [];
    }
  }

  /// Resolves a direct playable stream URL for a given title and artist.
  /// Used for seamlessly matching YouTube songs with high-bitrate, background-playable audio.
  Future<Track?> resolveTrackStream(String title, String artist, {String quality = '320'}) async {
    try {
      final cleanTitle = Track.normalizeTitle(title);
      final cleanArtist = Track.normalizeArtist(artist);
      final query = '$cleanTitle $cleanArtist'.trim();

      var matches = await searchTracks(query, limit: 5, quality: quality);
      if (matches.isEmpty && cleanTitle.isNotEmpty) {
        matches = await searchTracks(cleanTitle, limit: 5, quality: quality);
      }

      for (final candidate in matches) {
        if (candidate.streamUrl != null && candidate.streamUrl!.isNotEmpty) {
          return candidate;
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SaavnApiService] resolveTrackStream error: $e');
      return null;
    }
  }

  /// Fetches trending / top songs for the given language or category.
  Future<List<Track>> getTrendingTracks({
    String category = 'Hindi',
    int page = 1,
    int limit = 25,
    String quality = '320',
  }) async {
    final searchQuery = 'Top $category Hits';
    return searchTracks(searchQuery, page: page, limit: limit, quality: quality);
  }

  /// Fetches track details by ID and resolves the direct stream URL.
  Future<Track?> getTrackById(String id, {String quality = '320'}) async {
    try {
      final response = await _client.songs.detailsById([id]);
      final songsList = (response['songs'] as List<dynamic>?) ?? [];
      if (songsList.isEmpty) return null;

      final item = songsList.first as Map<String, dynamic>;
      final moreInfo = item['more_info'] as Map<String, dynamic>?;
      final encrypted = moreInfo?['encrypted_media_url']?.toString();
      final streamUrl = decryptMediaUrl(encrypted, quality: quality);

      return Track.fromSaavnJson(item, decryptedStreamUrl: streamUrl);
    } catch (e) {
      debugPrint('[SaavnApiService] getTrackById error: $e');
      return null;
    }
  }
}
