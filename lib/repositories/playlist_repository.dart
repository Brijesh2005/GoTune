import '../models/playlist.dart';
import '../models/track.dart';
import '../services/builtin_playlists_service.dart';
import '../services/local_storage_service.dart';

/// Repository managing both curated built-in playlists and custom user playlists.
class PlaylistRepository {
  final LocalStorageService _storage;

  PlaylistRepository(this._storage);

  /// Returns user-created playlists from local storage.
  List<Playlist> getPlaylists() => _storage.getPlaylists();

  /// Returns curated built-in playlists ready to stream.
  List<Playlist> getBuiltinPlaylists() => BuiltinPlaylistsService.getBuiltinPlaylists();

  /// Returns the featured daily playlist for the home screen banner.
  Playlist getFeaturedPlaylist() => BuiltinPlaylistsService.getFeaturedPlaylist();

  Playlist? getPlaylistById(String id) {
    try {
      return _storage.getPlaylists().firstWhere((p) => p.id == id);
    } catch (_) {
      return BuiltinPlaylistsService.getPlaylistById(id);
    }
  }

  Future<Playlist> createPlaylist(String name, {String description = ''}) =>
      _storage.createPlaylist(name, description: description);

  Future<bool> renamePlaylist(String id, String newName, {String? newDescription}) =>
      _storage.renamePlaylist(id, newName, newDescription: newDescription);

  Future<bool> deletePlaylist(String id) => _storage.deletePlaylist(id);

  Future<bool> addTrackToPlaylist(String playlistId, Track track) =>
      _storage.addTrackToPlaylist(playlistId, track);

  Future<bool> removeTrackFromPlaylist(String playlistId, String trackId) =>
      _storage.removeTrackFromPlaylist(playlistId, trackId);

  Future<bool> reorderPlaylistTracks(String playlistId, int oldIndex, int newIndex) =>
      _storage.reorderPlaylistTracks(playlistId, oldIndex, newIndex);
}
