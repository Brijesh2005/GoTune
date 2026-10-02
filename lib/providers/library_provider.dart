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
  List<Playlist> get builtinPlaylists => _playlistRepo.getBuiltinPlaylists();
  List<RecentlyPlayedItem> get recentlyPlayed => List.unmodifiable(_recentlyPlayed);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Loads/refreshes all library collections from local persistence.
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

  Future<Playlist> createPlaylist(String name, {String description = ''}) async {
    final playlist = await _playlistRepo.createPlaylist(name, description: description);
    _playlists = _playlistRepo.getPlaylists();
    notifyListeners();
    return playlist;
  }

  Future<void> renamePlaylist(String id, String newName, {String? newDescription}) async {
    await _playlistRepo.renamePlaylist(id, newName, newDescription: newDescription);
    _playlists = _playlistRepo.getPlaylists();
    notifyListeners();
  }

  Future<void> deletePlaylist(String id) async {
    await _playlistRepo.deletePlaylist(id);
    _playlists = _playlistRepo.getPlaylists();
    notifyListeners();
  }

  Future<void> addTrackToPlaylist(String playlistId, Track track) async {
    await _playlistRepo.addTrackToPlaylist(playlistId, track);
    _playlists = _playlistRepo.getPlaylists();
    notifyListeners();
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    await _playlistRepo.removeTrackFromPlaylist(playlistId, trackId);
    _playlists = _playlistRepo.getPlaylists();
    notifyListeners();
  }

  Playlist? getPlaylist(String id) {
    try {
      return _playlists.firstWhere((p) => p.id == id);
    } catch (_) {
      return _playlistRepo.getPlaylistById(id);
    }
  }

  Future<void> reorderPlaylistTracks(String playlistId, int oldIndex, int newIndex) async {
    await _playlistRepo.reorderPlaylistTracks(playlistId, oldIndex, newIndex);
    _playlists = _playlistRepo.getPlaylists();
    notifyListeners();
  }

  // ==========================================
  // RECENTLY PLAYED
  // ==========================================

  Future<void> recordPlayedTrack(Track track) async {
    await _recentsRepo.recordTrack(track);
    _recentlyPlayed = _recentsRepo.getRecentlyPlayed();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await _recentsRepo.clearHistory();
    _recentlyPlayed = [];
    notifyListeners();
  }

  Future<void> clearRecentlyPlayed() => clearHistory();
}

