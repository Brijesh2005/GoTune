import 'package:flutter_test/flutter_test.dart';
import 'package:gotune/repositories/playlist_repository.dart';
import 'package:gotune/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Built-in Playlists Tests', () {
    late PlaylistRepository playlistRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.init();
      playlistRepo = PlaylistRepository(storage);
    });

    test('Loads built-in playlists successfully', () {
      final playlists = playlistRepo.getBuiltinPlaylists();
      expect(playlists, isNotEmpty);
      expect(playlists.any((p) => p.name == 'After Dark'), isTrue);
      expect(playlists.any((p) => p.name == 'Global Pop Essentials'), isTrue);
      expect(playlists.any((p) => p.name == 'Bollywood Top Hits'), isTrue);
      expect(playlists.any((p) => p.name == 'Focus Flow'), isTrue);
    });

    test('Featured playlist has playable tracks', () {
      final featured = playlistRepo.getFeaturedPlaylist();
      expect(featured.id, 'builtin_after_dark');
      expect(featured.tracks, isNotEmpty);
      expect(featured.tracks.first.title, 'After Dark');
      expect(featured.tracks.first.resolvedYoutubeVideoId, isNotNull);
      expect(featured.tracks.first.isPlayable, isTrue);
    });

    test('Global Pop Essentials contains Adele Lovesong', () {
      final popPlaylist = playlistRepo.getPlaylistById('builtin_global_pop');
      expect(popPlaylist, isNotNull);
      final hasAdeleLovesong = popPlaylist!.tracks.any(
        (t) => t.artist.toLowerCase().contains('adele') && t.title.toLowerCase().contains('lovesong'),
      );
      expect(hasAdeleLovesong, isTrue);
    });
  });
}
