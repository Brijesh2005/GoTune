import 'album.dart';
import 'artist.dart';
import 'music_content.dart';
import 'playlist.dart';
import 'track.dart';

/// Unified search discovery result across all catalog categories.
class SearchDiscoveryResult {
  final String query;
  final List<Track> songs;
  final List<Artist> artists;
  final List<Album> albums;
  final List<Playlist> playlists;
  final List<MusicGenre> genres;
  final List<MusicMood> moods;
  final DateTime timestamp;

  const SearchDiscoveryResult({
    required this.query,
    this.songs = const [],
    this.artists = const [],
    this.albums = const [],
    this.playlists = const [],
    this.genres = const [],
    this.moods = const [],
    required this.timestamp,
  });

  /// Every hit flattened into the unified [MusicContent] abstraction, so a
  /// result row can navigate to its detail page without knowing its type.
  List<MusicContent> get allContent => [
        ...songs,
        ...artists,
        ...albums,
        ...playlists,
        ...genres,
        ...moods,
      ];

  bool get isEmpty =>
      songs.isEmpty &&
      artists.isEmpty &&
      albums.isEmpty &&
      playlists.isEmpty &&
      genres.isEmpty &&
      moods.isEmpty;

  bool get isNotEmpty => !isEmpty;
  bool get hasResults => totalCount > 0;

  int get totalCount =>
      songs.length +
      artists.length +
      albums.length +
      playlists.length +
      genres.length +
      moods.length;
}
