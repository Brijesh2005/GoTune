import '../models/recently_played_item.dart';
import '../models/track.dart';
import '../services/local_storage_service.dart';

/// Repository managing listening history with timestamps and duplicate suppression.
class RecentlyPlayedRepository {
  final LocalStorageService _storage;

  RecentlyPlayedRepository(this._storage);

  List<RecentlyPlayedItem> getRecentlyPlayed() => _storage.getRecentlyPlayed();

  Future<bool> recordTrack(Track track) => _storage.recordPlayedTrack(track);

  Future<bool> clearHistory() => _storage.clearRecentlyPlayed();
}
