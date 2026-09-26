import '../models/track.dart';
import '../services/local_storage_service.dart';

/// Repository managing user's favorited tracks with persistence and duplicate prevention.
class FavoritesRepository {
  final LocalStorageService _storage;

  FavoritesRepository(this._storage);

  List<Track> getFavorites() => _storage.getFavorites();

  bool isFavorite(String trackId) => _storage.isFavorite(trackId);

  Future<bool> addFavorite(Track track) => _storage.addFavorite(track);

  Future<bool> removeFavorite(String trackId) => _storage.removeFavorite(trackId);

  Future<bool> toggleFavorite(Track track) => _storage.toggleFavorite(track);
}
