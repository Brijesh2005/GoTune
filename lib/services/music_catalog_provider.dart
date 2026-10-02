import '../models/album.dart';
import '../models/artist.dart';
import '../models/track.dart';
import 'youtube_api_service.dart';

/// Lightweight provider abstraction representing a music catalog source.
/// Responsible for search, metadata, artists, albums, discovery, and trending.
abstract class MusicCatalogProvider {
  String get providerId;
  String get displayName;

  /// Whether this provider can supply a direct playable audio stream.
  bool get isPlayable;

  /// Searches tracks matching [query].
  Future<List<Track>> searchTracks(String query, {int limit = 20, int page = 1});

  /// Fetches trending or discovery tracks.
  Future<List<Track>> getTrendingTracks({String? genre, int limit = 20, int page = 1});

  /// Broad "popular right now" shelf.
  Future<List<Track>> getPopularTracks({int limit = 20}) async =>
      getTrendingTracks(limit: limit);

  /// Recently released tracks.
  Future<List<Track>> getNewReleases({int limit = 20}) async => getTrendingTracks(limit: limit);

  /// Retrieves track metadata by [id].
  Future<Track?> getTrackById(String id);

  /// Optional catalog operations
  Future<List<Artist>> searchArtists(String query, {int limit = 15}) async => [];
  Future<List<Album>> searchAlbums(String query, {int limit = 15}) async => [];
  Future<Artist?> getArtistDetails(String artistId) async => null;
  Future<Album?> getAlbumDetails(String albumId) async => null;
  Future<List<Track>> getArtistTracks(String artistIdOrName, {int limit = 20}) async => [];
  Future<List<Track>> getRelatedTracks(Track track, {int limit = 15}) async => [];
}

/// Official YouTube Music catalog provider for global discovery and metadata.
/// Strictly metadata & IFrame ID discovery — no stream extraction or DRM bypass.
class YouTubeCatalogProvider extends MusicCatalogProvider {
  final YouTubeApiService _service;

  YouTubeCatalogProvider({YouTubeApiService? service})
      : _service = service ?? YouTubeApiService();

  YouTubeApiService get service => _service;

  @override
  String get providerId => 'youtube';

  @override
  String get displayName => 'YouTube Music';

  @override
  bool get isPlayable => true;

  @override
  Future<List<Track>> searchTracks(String query, {int limit = 20, int page = 1}) {
    return _service.searchTracks(query, limit: limit);
  }

  @override
  Future<List<Track>> getTrendingTracks({String? genre, int limit = 20, int page = 1}) {
    return _service.getTrendingMusic(limit: limit);
  }

  @override
  Future<List<Track>> getPopularTracks({int limit = 20}) {
    return _service.getTrendingMusic(limit: limit);
  }

  @override
  Future<List<Track>> getNewReleases({int limit = 20}) {
    return _service.getTrendingMusic(limit: limit);
  }

  @override
  Future<Track?> getTrackById(String id) async {
    // When an ID is passed, search or resolve through YouTube
    final cleanId = id.startsWith('yt_') ? id.substring(3) : id;
    final results = await _service.searchTracks(cleanId, limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  @override
  Future<List<Track>> getRelatedTracks(Track track, {int limit = 15}) {
    return _service.getRelatedTracks(track, limit: limit);
  }

  @override
  Future<List<Track>> getArtistTracks(String artistIdOrName, {int limit = 20}) {
    if (artistIdOrName.trim().isEmpty) return Future.value(const <Track>[]);
    return _service.searchTracks(artistIdOrName, limit: limit);
  }

  @override
  Future<List<Artist>> searchArtists(String query, {int limit = 15}) async {
    final tracks = await _service.searchTracks('$query music artist', limit: limit);
    final seen = <String>{};
    final artists = <Artist>[];
    for (final t in tracks) {
      if (t.artist.isNotEmpty && seen.add(t.artist.toLowerCase())) {
        artists.add(
          Artist(
            id: 'yt_art_${t.artist.hashCode.abs()}',
            name: t.artist,
            artworkUrl: t.thumbnailArtworkUrl,
            provider: 'youtube',
          ),
        );
      }
    }
    return artists;
  }

  @override
  Future<List<Album>> searchAlbums(String query, {int limit = 15}) async {
    final tracks = await _service.searchTracks('$query full album', limit: limit);
    final seen = <String>{};
    final albums = <Album>[];
    for (final t in tracks) {
      final name = t.album ?? t.title;
      if (name.isNotEmpty && seen.add(name.toLowerCase())) {
        albums.add(
          Album(
            id: 'yt_alb_${name.hashCode.abs()}',
            name: name,
            artist: t.artist,
            artworkUrl: t.thumbnailArtworkUrl,
            provider: 'youtube',
          ),
        );
      }
    }
    return albums;
  }
}
