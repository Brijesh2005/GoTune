import 'package:flutter/foundation.dart';
import '../models/playlist.dart';
import '../models/recently_played_item.dart';
import '../models/track.dart';
import '../repositories/favorites_repository.dart';
import '../repositories/playlist_repository.dart';
import '../repositories/recently_played_repository.dart';

/// Provider managing personal music library state: Favorites, Playlists,
/// and Recently Played listening history.
class LibraryProvider extends ChangeNotifier {
  final FavoritesRepository _favoritesRepo;
  final PlaylistRepository _playlistRepo;
  final RecentlyPlayedRepository _recentsRepo;

  List<Track> _favorites = [];
  List<Playlist> _playlists = [];
  List<RecentlyPlayedItem> _recentlyPlayed = [];

  bool _isLoading = false;
  String? _errorMessage;

  LibraryProvider({
    required FavoritesRepository favoritesRepository,
    required PlaylistRepository playlistRepository,
    required RecentlyPlayedRepository recentlyPlayedRepository,
  })  : _favoritesRepo = favoritesRepository,
        _playlistRepo = playlistRepository,
        _recentsRepo = recentlyPlayedRepository {
    loadLibrary();
  }

  List<Track> get favorites => List.unmodifiable(_favorites);
  List<Playlist> get playlists => List.unmodifiable(_playlists);
  List<RecentlyPlayedItem> get recentlyPlayed => List.unmodifiable(_recentlyPlayed);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Loads/refreshes all library collections from persistence.
  void loadLibrary() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _favorites = _favoritesRepo.getFavorites();
      _playlists = _playlistRepo.getPlaylists();
      _recentlyPlayed = _recentsRepo.getRecentlyPlayed();
      _isLoading = false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load library data: $e';
    }
    notifyListeners();
  }

  // ==========================================
  // FAVORITES
  // ==========================================

  bool isFavorite(String trackId) {
    return _favorites.any((t) => t.id == trackId);
  }

  Future<void> toggleFavorite(Track track) async {
    await _favoritesRepo.toggleFavorite(track);
    _favorites = _favoritesRepo.getFavorites();
    notifyListeners();
  }

  Future<void> addFavorite(Track track) async {
    await _favoritesRepo.addFavorite(track);
    _favorites = _favoritesRepo.getFavorites();
    notifyListeners();
  }

  Future<void> removeFavorite(String trackId) async {
    await _favoritesRepo.removeFavorite(trackId);
    _favorites = _favoritesRepo.getFavorites();
    notifyListeners();
  }

  // ==========================================
  // PLAYLISTS
  // ==========================================

  Playlist? getPlaylist(String id) {
    try {
      return _playlists.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<Playlist> createPlaylist(String name, {String description = ''}) async {
    final playlist = await _playlistRepo.createPlaylist(name, description: description);
    _playlists = _playlistRepo.getPlaylists();
    notifyListeners();
    return playlist;
  }

  Future<bool> renamePlaylist(String id, String newName, {String? newDescription}) async {
    final success = await _playlistRepo.renamePlaylist(id, newName, newDescription: newDescription);
    if (success) {
      _playlists = _playlistRepo.getPlaylists();
      notifyListeners();
    }
    return success;
  }

  Future<bool> deletePlaylist(String id) async {
    final success = await _playlistRepo.deletePlaylist(id);
    if (success) {
      _playlists = _playlistRepo.getPlaylists();
      notifyListeners();
    }
    return success;
  }

  /// Adds a track to a playlist, preventing duplicates.
  /// Returns `true` if added successfully, `false` if track was already in playlist.
  Future<bool> addTrackToPlaylist(String playlistId, Track track) async {
    final playlist = getPlaylist(playlistId);
    if (playlist == null) return false;

    // Prevent duplicate tracks
    if (playlist.containsTrack(track.id)) {
      return false;
    }

    final success = await _playlistRepo.addTrackToPlaylist(playlistId, track);
    if (success) {
      _playlists = _playlistRepo.getPlaylists();
      notifyListeners();
    }
    return success;
  }

  Future<bool> removeTrackFromPlaylist(String playlistId, String trackId) async {
    final success = await _playlistRepo.removeTrackFromPlaylist(playlistId, trackId);
    if (success) {
      _playlists = _playlistRepo.getPlaylists();
      notifyListeners();
    }
    return success;
  }

  Future<bool> reorderPlaylistTracks(String playlistId, int oldIndex, int newIndex) async {
    final success = await _playlistRepo.reorderPlaylistTracks(playlistId, oldIndex, newIndex);
    if (success) {
      _playlists = _playlistRepo.getPlaylists();
      notifyListeners();
    }
    return success;
  }

  // ==========================================
  // RECENTLY PLAYED
  // ==========================================

  Future<void> recordTrackPlayed(Track track) async {
    await _recentsRepo.recordTrack(track);
    _recentlyPlayed = _recentsRepo.getRecentlyPlayed();
    notifyListeners();
  }

  Future<void> clearRecentlyPlayed() async {
    await _recentsRepo.clearHistory();
    _recentlyPlayed = [];
    notifyListeners();
  }
}
