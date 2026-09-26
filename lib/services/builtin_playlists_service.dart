import '../models/playlist.dart';
import '../models/track.dart';
import '../models/track_stream_info.dart';

/// Provides curated built-in playlists that are immediately playable,
/// featuring rich covers and instant streaming across YouTube and JioSaavn.
class BuiltinPlaylistsService {
  static final List<Playlist> _builtinPlaylists = [
    // 1. Featured Daily Mix: After Dark
    Playlist(
      id: 'builtin_after_dark',
      name: 'After Dark',
      description: 'Electronic focus & synthwave for late nights',
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime.now(),
      tracks: [
        const Track(
          id: 'yt_waAlgFq9Xq8',
          title: 'After Dark',
          artist: 'Mr.Kitty',
          artworkUrl150: 'https://img.youtube.com/vi/waAlgFq9Xq8/default.jpg',
          artworkUrl480: 'https://img.youtube.com/vi/waAlgFq9Xq8/mqdefault.jpg',
          artworkUrl1000: 'https://img.youtube.com/vi/waAlgFq9Xq8/hqdefault.jpg',
          durationSeconds: 259,
          genre: 'Electronic',
          provider: 'youtube',
          streamInfo: TrackStreamInfo(isStreamable: true),
        ),
        const Track(
          id: 'yt_8GW6sLrK40k',
          title: 'Resonance',
          artist: 'HOME',
          artworkUrl150: 'https://img.youtube.com/vi/8GW6sLrK40k/default.jpg',
          artworkUrl480: 'https://img.youtube.com/vi/8GW6sLrK40k/mqdefault.jpg',
          artworkUrl1000: 'https://img.youtube.com/vi/8GW6sLrK40k/hqdefault.jpg',
          durationSeconds: 212,
          genre: 'Electronic',
          provider: 'youtube',
          streamInfo: TrackStreamInfo(isStreamable: true),
        ),
        const Track(
          id: 'yt_MV_3Dpw-BRY',
          title: 'Nightcall',
          artist: 'Kavinsky',
          artworkUrl150: 'https://img.youtube.com/vi/MV_3Dpw-BRY/default.jpg',
          artworkUrl480: 'https://img.youtube.com/vi/MV_3Dpw-BRY/mqdefault.jpg',
          artworkUrl1000: 'https://img.youtube.com/vi/MV_3Dpw-BRY/hqdefault.jpg',
          durationSeconds: 259,
          genre: 'Electronic',
          provider: 'youtube',
          streamInfo: TrackStreamInfo(isStreamable: true),
        ),
        const Track(
          id: 'yt_34Na4j8AVgA',
          title: 'Starboy',
          artist: 'The Weeknd ft. Daft Punk',
          artworkUrl150: 'https://img.youtube.com/vi/34Na4j8AVgA/default.jpg',
          artworkUrl480: 'https://img.youtube.com/vi/34Na4j8AVgA/mqdefault.jpg',
          artworkUrl1000: 'https://img.youtube.com/vi/34Na4j8AVgA/hqdefault.jpg',
          durationSeconds: 230,
          genre: 'Electronic',
          provider: 'youtube',
          streamInfo: TrackStreamInfo(isStreamable: true),
        ),
      ],
    ),

    // 2. Global Pop Essentials (featuring Adele, Taylor Swift, The Weeknd)
    Playlist(
      id: 'builtin_global_pop',
      name: 'Global Pop Essentials',
      description: 'The world\'s biggest hits & timeless vocal anthems',
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime.now(),
      tracks: [
        const Track(
          id: 'yt_0wPhbmeNSOs',
          title: 'Lovesong',
          artist: 'Adele',
          artworkUrl150: 'https://img.youtube.com/vi/0wPhbmeNSOs/default.jpg',
          artworkUrl480: 'https://img.youtube.com/vi/0wPhbmeNSOs/mqdefault.jpg',
          artworkUrl1000: 'https://img.youtube.com/vi/0wPhbmeNSOs/hqdefault.jpg',
          durationSeconds: 320,
          genre: 'Pop',
          provider: 'youtube',
          streamInfo: TrackStreamInfo(isStreamable: true),
        ),
        const Track(
          id: 'yt_U3ASj1L6_sY',
          title: 'Easy On Me',
          artist: 'Adele',
          artworkUrl150: 'https://img.youtube.com/vi/U3ASj1L6_sY/default.jpg',
          artworkUrl480: 'https://img.youtube.com/vi/U3ASj1L6_sY/mqdefault.jpg',
          artworkUrl1000: 'https://img.youtube.com/vi/U3ASj1L6_sY/hqdefault.jpg',
          durationSeconds: 224,
          genre: 'Pop',
          provider: 'youtube',
          streamInfo: TrackStreamInfo(isStreamable: true),
        ),
        const Track(
          id: 'yt_4NRXx6U8ABQ',
          title: 'Blinding Lights',
          artist: 'The Weeknd',
          artworkUrl150: 'https://img.youtube.com/vi/4NRXx6U8ABQ/default.jpg',
          artworkUrl480: 'https://img.youtube.com/vi/4NRXx6U8ABQ/mqdefault.jpg',
          artworkUrl1000: 'https://img.youtube.com/vi/4NRXx6U8ABQ/hqdefault.jpg',
          durationSeconds: 200,
          genre: 'Pop',
          provider: 'youtube',
          streamInfo: TrackStreamInfo(isStreamable: true),
        ),
        const Track(
          id: 'yt_ic8j13piAhQ',
          title: 'Cruel Summer',
          artist: 'Taylor Swift',
          artworkUrl150: 'https://img.youtube.com/vi/ic8j13piAhQ/default.jpg',
          artworkUrl480: 'https://img.youtube.com/vi/ic8j13piAhQ/mqdefault.jpg',
          artworkUrl1000: 'https://img.youtube.com/vi/ic8j13piAhQ/hqdefault.jpg',
          durationSeconds: 178,
          genre: 'Pop',
          provider: 'youtube',
          streamInfo: TrackStreamInfo(isStreamable: true),
        ),
      ],
    ),

    // 3. Bollywood Essentials
    Playlist(
      id: 'builtin_bollywood',
      name: 'Bollywood Top Hits',
      description: 'Soulful melodies and romantic chartbusters in 320kbps',
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime.now(),
      tracks: [
        const Track(
          id: 'yt_BddP6PYo2gs',
          title: 'Kesariya',
          artist: 'Arijit Singh, Pritam',
          artworkUrl150: 'https://img.youtube.com/vi/BddP6PYo2gs/default.jpg',
          artworkUrl480: 'https://img.youtube.com/vi/BddP6PYo2gs/mqdefault.jpg',
          artworkUrl1000: 'https://img.youtube.com/vi/BddP6PYo2gs/hqdefault.jpg',
          durationSeconds: 268,
          genre: 'Bollywood',
          provider: 'youtube',
          streamInfo: TrackStreamInfo(isStreamable: true),
        ),
        const Track(
          id: 'yt_IJq0yyWug1k',
          title: 'Tum Hi Ho',
          artist: 'Arijit Singh, Mithoon',
          artworkUrl150: 'https://img.youtube.com/vi/IJq0yyWug1k/default.jpg',
          artworkUrl480: 'https://img.youtube.com/vi/IJq0yyWug1k/mqdefault.jpg',
          artworkUrl1000: 'https://img.youtube.com/vi/IJq0yyWug1k/hqdefault.jpg',
          durationSeconds: 262,
          genre: 'Bollywood',
          provider: 'youtube',
          streamInfo: TrackStreamInfo(isStreamable: true),
        ),
        const Track(
          id: 'yt_V1Z5W5k9P7g',
          title: 'Chaleya',
          artist: 'Arijit Singh, Shilpa Rao',
          artworkUrl150: 'https://img.youtube.com/vi/V1Z5W5k9P7g/default.jpg',
          artworkUrl480: 'https://img.youtube.com/vi/V1Z5W5k9P7g/mqdefault.jpg',
          artworkUrl1000: 'https://img.youtube.com/vi/V1Z5W5k9P7g/hqdefault.jpg',
          durationSeconds: 200,
          genre: 'Bollywood',
          provider: 'youtube',
          streamInfo: TrackStreamInfo(isStreamable: true),
        ),
      ],
    ),

    // 4. Focus Flow
    Playlist(
      id: 'builtin_focus_flow',
      name: 'Focus Flow',
      description: 'Pulse playlist · Deep study beats & ambient relaxation',
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime.now(),
      tracks: [
        const Track(
          id: 'yt_jfKfPfyJRdk',
          title: 'Lofi Hip Hop Chill Study Beat',
          artist: 'Lofi Girl',
          artworkUrl150: 'https://img.youtube.com/vi/jfKfPfyJRdk/default.jpg',
          artworkUrl480: 'https://img.youtube.com/vi/jfKfPfyJRdk/mqdefault.jpg',
          artworkUrl1000: 'https://img.youtube.com/vi/jfKfPfyJRdk/hqdefault.jpg',
          durationSeconds: 180,
          genre: 'Focus',
          provider: 'youtube',
          streamInfo: TrackStreamInfo(isStreamable: true),
        ),
        const Track(
          id: 'yt_2atQnvunGCo',
          title: 'Weightless',
          artist: 'Marconi Union',
          artworkUrl150: 'https://img.youtube.com/vi/2atQnvunGCo/default.jpg',
          artworkUrl480: 'https://img.youtube.com/vi/2atQnvunGCo/mqdefault.jpg',
          artworkUrl1000: 'https://img.youtube.com/vi/2atQnvunGCo/hqdefault.jpg',
          durationSeconds: 485,
          genre: 'Focus',
          provider: 'youtube',
          streamInfo: TrackStreamInfo(isStreamable: true),
        ),
      ],
    ),
  ];

  /// Returns all available built-in playlists.
  static List<Playlist> getBuiltinPlaylists() => List.unmodifiable(_builtinPlaylists);

  /// Returns the featured playlist for the Home screen banner.
  static Playlist getFeaturedPlaylist() => _builtinPlaylists.first;

  /// Retrieves a built-in playlist by its ID.
  static Playlist? getPlaylistById(String id) {
    try {
      return _builtinPlaylists.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}
