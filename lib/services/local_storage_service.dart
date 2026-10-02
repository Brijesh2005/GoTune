import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';
import '../models/interaction_event.dart';
import '../models/playlist.dart';
import '../models/recently_played_item.dart';
import '../models/track.dart';

/// Central local persistence service using [SharedPreferences].
/// Safely stores and manages Favorites, Playlists, and Recently Played listening history.
class LocalStorageService {
  final SharedPreferences _prefs;

  static const String keyFavoritesV2 = 'gotune_favorites_v2';
  static const String keyPlaylistsV2 = 'gotune_playlists_v2';
  static const String keyRecentlyPlayedV2 = 'gotune_recently_played_v2';

  LocalStorageService(this._prefs) {
    _migrateOldDataIfNeeded();
  }

  static Future<LocalStorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStorageService(prefs);
  }

  /// Automatically migrates simple Phase 1 storage data to structured Phase 3 models.
  void _migrateOldDataIfNeeded() {
    try {
      // 1. Migrate favorites if needed
      if (!_prefs.containsKey(keyFavoritesV2) && _prefs.containsKey(AppConstants.keyFavorites)) {
        final oldFavs = _prefs.getStringList(AppConstants.keyFavorites);
        if (oldFavs != null && oldFavs.isNotEmpty) {
          _prefs.setStringList(keyFavoritesV2, oldFavs);
        }
      }

      // 2. Migrate recently played if needed
      if (!_prefs.containsKey(keyRecentlyPlayedV2) && _prefs.containsKey(AppConstants.keyRecentTracks)) {
        final oldRecents = _prefs.getStringList(AppConstants.keyRecentTracks);
        if (oldRecents != null && oldRecents.isNotEmpty) {
          final migrated = <String>[];
          DateTime timeCursor = DateTime.now();
          for (final raw in oldRecents) {
            try {
              final map = jsonDecode(raw) as Map<String, dynamic>;
              final track = Track.fromJson(map);
              final item = RecentlyPlayedItem(track: track, playedAt: timeCursor);
              migrated.add(jsonEncode(item.toJson()));
              timeCursor = timeCursor.subtract(const Duration(minutes: 5));
            } catch (_) {}
          }
          _prefs.setStringList(keyRecentlyPlayedV2, migrated);
        }
      }
    } catch (e) {
      debugPrint('[LocalStorageService] Data migration note: $e');
    }
  }

  // ==========================================
  // FAVORITES PERSISTENCE
  // ==========================================

  List<Track> getFavorites() {
    final rawList = _prefs.getStringList(keyFavoritesV2) ?? [];
    final tracks = <Track>[];
    for (final raw in rawList) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        tracks.add(Track.fromJson(map));
      } catch (_) {}
    }
    return tracks;
  }

  Future<bool> saveFavorites(List<Track> favorites) async {
    final rawList = favorites.map((t) => jsonEncode(t.toJson())).toList();
    return _prefs.setStringList(keyFavoritesV2, rawList);
  }

  bool isFavorite(String trackId) {
    return getFavorites().any((t) => t.id == trackId);
  }

  Future<bool> addFavorite(Track track) async {
    final favorites = getFavorites();
    // Prevent duplicate favorites
    if (favorites.any((t) => t.id == track.id)) {
      return true;
    }
    favorites.insert(0, track);
    return saveFavorites(favorites);
  }

  Future<bool> removeFavorite(String trackId) async {
    final favorites = getFavorites();
    favorites.removeWhere((t) => t.id == trackId);
    return saveFavorites(favorites);
  }

  Future<bool> toggleFavorite(Track track) async {
    if (isFavorite(track.id)) {
      return removeFavorite(track.id);
    } else {
      return addFavorite(track);
    }
  }

  // ==========================================
  // PLAYLISTS PERSISTENCE
  // ==========================================

  List<Playlist> getPlaylists() {
    final rawList = _prefs.getStringList(keyPlaylistsV2) ?? [];
    final playlists = <Playlist>[];
    for (final raw in rawList) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        playlists.add(Playlist.fromJson(map));
      } catch (_) {}
    }
    return playlists;
  }

  Future<bool> savePlaylists(List<Playlist> playlists) async {
    final rawList = playlists.map((p) => jsonEncode(p.toJson())).toList();
    return _prefs.setStringList(keyPlaylistsV2, rawList);
  }

  Future<Playlist> createPlaylist(String name, {String description = ''}) async {
    final playlists = getPlaylists();
    final newPlaylist = Playlist(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim().isNotEmpty ? name.trim() : 'New Playlist',
      description: description.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      tracks: const [],
    );
    playlists.insert(0, newPlaylist);
    await savePlaylists(playlists);
    return newPlaylist;
  }

  Future<bool> renamePlaylist(String id, String newName, {String? newDescription}) async {
    final playlists = getPlaylists();
    final index = playlists.indexWhere((p) => p.id == id);
    if (index < 0) return false;

    final existing = playlists[index];
    playlists[index] = existing.copyWith(
      name: newName.trim().isNotEmpty ? newName.trim() : existing.name,
      description: newDescription ?? existing.description,
      updatedAt: DateTime.now(),
    );
    return savePlaylists(playlists);
  }

  Future<bool> deletePlaylist(String id) async {
    final playlists = getPlaylists();
    playlists.removeWhere((p) => p.id == id);
    return savePlaylists(playlists);
  }

  Future<bool> addTrackToPlaylist(String playlistId, Track track) async {
    final playlists = getPlaylists();
    final index = playlists.indexWhere((p) => p.id == playlistId);
    if (index < 0) return false;

    final existing = playlists[index];
    // Prevent duplicate tracks inside the playlist
    if (existing.containsTrack(track.id)) {
      return false; // already in playlist
    }

    final updatedTracks = List<Track>.from(existing.tracks)..add(track);
    playlists[index] = existing.copyWith(
      tracks: updatedTracks,
      updatedAt: DateTime.now(),
    );
    return savePlaylists(playlists);
  }

  Future<bool> removeTrackFromPlaylist(String playlistId, String trackId) async {
    final playlists = getPlaylists();
    final index = playlists.indexWhere((p) => p.id == playlistId);
    if (index < 0) return false;

    final existing = playlists[index];
    final updatedTracks = List<Track>.from(existing.tracks)
      ..removeWhere((t) => t.id == trackId);

    playlists[index] = existing.copyWith(
      tracks: updatedTracks,
      updatedAt: DateTime.now(),
    );
    return savePlaylists(playlists);
  }

  Future<bool> reorderPlaylistTracks(String playlistId, int oldIndex, int newIndex) async {
    final playlists = getPlaylists();
    final index = playlists.indexWhere((p) => p.id == playlistId);
    if (index < 0) return false;

    final existing = playlists[index];
    final tracks = List<Track>.from(existing.tracks);
    if (oldIndex < 0 || oldIndex >= tracks.length) return false;
    if (newIndex < 0 || newIndex > tracks.length) return false;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = tracks.removeAt(oldIndex);
    tracks.insert(newIndex, item);

    playlists[index] = existing.copyWith(
      tracks: tracks,
      updatedAt: DateTime.now(),
    );
    return savePlaylists(playlists);
  }

  // ==========================================
  // RECENTLY PLAYED PERSISTENCE
  // ==========================================

  List<RecentlyPlayedItem> getRecentlyPlayed() {
    final rawList = _prefs.getStringList(keyRecentlyPlayedV2) ?? [];
    final items = <RecentlyPlayedItem>[];
    for (final raw in rawList) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        items.add(RecentlyPlayedItem.fromJson(map));
      } catch (_) {}
    }
    return items;
  }

  Future<bool> recordPlayedTrack(Track track) async {
    final items = getRecentlyPlayed();
    // Remove if already present so it doesn't duplicate and jumps to front
    items.removeWhere((i) => i.track.id == track.id);
    // Add to top with current timestamp (newest first)
    items.insert(0, RecentlyPlayedItem(track: track, playedAt: DateTime.now()));

    // Cap at 50 tracks to keep persistence fast and lightweight
    if (items.length > 50) {
      items.removeRange(50, items.length);
    }

    final rawList = items.map((i) => jsonEncode(i.toJson())).toList();
    return _prefs.setStringList(keyRecentlyPlayedV2, rawList);
  }

  Future<bool> clearRecentlyPlayed() async {
    return _prefs.remove(keyRecentlyPlayedV2);
  }

  // ==========================================
  // SEARCH HISTORY PERSISTENCE
  // ==========================================

  static const String keySearchHistory = 'gotune_search_history_v1';

  List<String> getSearchHistory() {
    return _prefs.getStringList(keySearchHistory) ?? [];
  }

  Future<bool> addSearchQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return false;

    final history = getSearchHistory();
    history.removeWhere((q) => q.toLowerCase() == trimmed.toLowerCase());
    history.insert(0, trimmed);

    if (history.length > 20) {
      history.removeRange(20, history.length);
    }
    return _prefs.setStringList(keySearchHistory, history);
  }

  Future<bool> removeSearchQuery(String query) async {
    final history = getSearchHistory();
    history.removeWhere((q) => q.toLowerCase() == query.trim().toLowerCase());
    return _prefs.setStringList(keySearchHistory, history);
  }

  Future<bool> clearSearchHistory() async {
    return _prefs.remove(keySearchHistory);
  }

  // ==========================================
  // APP CONFIGURATION & SETTINGS
  // ==========================================

  String getAppName() {
    return _prefs.getString(AppConstants.keyAppName) ?? AppConstants.appName;
  }

  Future<bool> setAppName(String name) async {
    return _prefs.setString(AppConstants.keyAppName, name.trim());
  }

  String? getApiKey() {
    return _prefs.getString(AppConstants.keyApiKey);
  }

  Future<bool> setApiKey(String? key) async {
    if (key == null || key.trim().isEmpty) {
      return _prefs.remove(AppConstants.keyApiKey);
    }
    return _prefs.setString(AppConstants.keyApiKey, key.trim());
  }

  String? getCustomBaseUrl() {
    return _prefs.getString(AppConstants.keyCustomBaseUrl);
  }

  Future<bool> setCustomBaseUrl(String? url) async {
    if (url == null || url.trim().isEmpty) {
      return _prefs.remove(AppConstants.keyCustomBaseUrl);
    }
    return _prefs.setString(AppConstants.keyCustomBaseUrl, url.trim());
  }

  String getAudioQuality() {
    return _prefs.getString(AppConstants.keyAudioQuality) ?? 'Auto (High)';
  }

  Future<bool> setAudioQuality(String quality) async {
    return _prefs.setString(AppConstants.keyAudioQuality, quality);
  }

  // ==========================================
  // RECOMMENDATION & INTERACTION EVENTS PERSISTENCE
  // ==========================================

  static const String keyInteractionStats = 'gotune_interaction_stats_v1';

  UserInteractionStats getInteractionStats() {
    final raw = _prefs.getString(keyInteractionStats);
    if (raw == null || raw.isEmpty) return const UserInteractionStats();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return UserInteractionStats.fromJson(map);
    } catch (_) {
      return const UserInteractionStats();
    }
  }

  Future<bool> saveInteractionStats(UserInteractionStats stats) async {
    return _prefs.setString(keyInteractionStats, jsonEncode(stats.toJson()));
  }

  Future<void> recordInteractionEvent(
    InteractionEventType type, {
    Track? track,
    String? artist,
    String? genre,
    String? query,
  }) async {
    final current = getInteractionStats();

    final songPlays = Map<String, int>.from(current.songPlayCounts);
    final songCompletions = Map<String, int>.from(current.songCompletionCounts);
    final songSkips = Map<String, int>.from(current.songSkipCounts);
    final songLastPlayed = Map<String, DateTime>.from(current.songLastPlayed);
    final artistPlays = Map<String, int>.from(current.artistPlayCounts);
    final artistSkips = Map<String, int>.from(current.artistSkipCounts);
    final genrePlays = Map<String, int>.from(current.genrePlayCounts);
    final recentSkips = List<String>.from(current.recentSkippedTrackIds);

    final trackId = track?.id ?? '';
    final trackArtist = artist ?? track?.artist ?? '';
    final trackGenre = genre ?? track?.genre ?? '';

    switch (type) {
      case InteractionEventType.songStarted:
      case InteractionEventType.songReplayed:
        if (trackId.isNotEmpty) {
          songPlays[trackId] = (songPlays[trackId] ?? 0) + 1;
          songLastPlayed[trackId] = DateTime.now();
        }
        if (trackArtist.isNotEmpty) {
          artistPlays[trackArtist] = (artistPlays[trackArtist] ?? 0) + 1;
        }
        if (trackGenre.isNotEmpty) {
          genrePlays[trackGenre] = (genrePlays[trackGenre] ?? 0) + 1;
        }
        break;

      case InteractionEventType.songCompleted:
        if (trackId.isNotEmpty) {
          songCompletions[trackId] = (songCompletions[trackId] ?? 0) + 1;
        }
        break;

      case InteractionEventType.songSkipped:
        if (trackId.isNotEmpty) {
          songSkips[trackId] = (songSkips[trackId] ?? 0) + 1;
          recentSkips.remove(trackId);
          recentSkips.insert(0, trackId);
          if (recentSkips.length > 25) {
            recentSkips.removeRange(25, recentSkips.length);
          }
        }
        if (trackArtist.isNotEmpty) {
          artistSkips[trackArtist] = (artistSkips[trackArtist] ?? 0) + 1;
        }
        break;

      case InteractionEventType.songPartiallyPlayed:
        if (trackId.isNotEmpty) {
          songPlays[trackId] = (songPlays[trackId] ?? 0) + 1;
        }
        break;

      case InteractionEventType.artistPlayed:
        if (trackArtist.isNotEmpty) {
          artistPlays[trackArtist] = (artistPlays[trackArtist] ?? 0) + 1;
        }
        break;

      case InteractionEventType.genrePlayed:
        if (trackGenre.isNotEmpty) {
          genrePlays[trackGenre] = (genrePlays[trackGenre] ?? 0) + 1;
        }
        break;

      case InteractionEventType.searchPerformed:
        if (query != null && query.isNotEmpty) {
          addSearchQuery(query);
        }
        break;

      default:
        break;
    }

    final updated = UserInteractionStats(
      songPlayCounts: songPlays,
      songCompletionCounts: songCompletions,
      songSkipCounts: songSkips,
      songLastPlayed: songLastPlayed,
      artistPlayCounts: artistPlays,
      artistSkipCounts: artistSkips,
      genrePlayCounts: genrePlays,
      recentSkippedTrackIds: recentSkips,
    );

    await saveInteractionStats(updated);
  }
}
