import 'package:flutter_test/flutter_test.dart';
import 'package:gotune/models/track.dart';
import 'package:gotune/repositories/track_repository.dart';
import 'package:gotune/services/audius_api_service.dart';
import 'package:gotune/services/local_storage_service.dart';
import 'package:gotune/services/music_algorithm_service.dart';
import 'package:gotune/services/saavn_api_service.dart';
import 'package:gotune/services/youtube_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MusicAlgorithmService Tests', () {
    test('Cleans artist collaborations and featured tags properly', () {
      expect(MusicAlgorithmService.cleanArtist('Adele feat. John Legend'), 'Adele');
      expect(MusicAlgorithmService.cleanArtist('Arijit Singh, Shreya Ghoshal'), 'Arijit Singh');
      expect(MusicAlgorithmService.cleanArtist('Sidhu Moose Wala ft. Divine'), 'Sidhu Moose Wala');
      expect(MusicAlgorithmService.cleanArtist('The Weeknd with Daft Punk'), 'The Weeknd');
    });

    test('Cleans title metadata and parenthetical tags', () {
      expect(MusicAlgorithmService.cleanTitle('Lovesong (Official Music Video)'), 'Lovesong');
      expect(MusicAlgorithmService.cleanTitle('Tum Hi Ho [Remix]'), 'Tum Hi Ho');
      expect(MusicAlgorithmService.cleanTitle('Starboy (Live)'), 'Starboy');
      expect(MusicAlgorithmService.cleanTitle('Blinding Lights (Acoustic)'), 'Blinding Lights');
    });

    test('Finds genre & sibling artists correctly', () {
      final adeleSiblings = MusicAlgorithmService.getSiblingArtists('Adele', 'Pop');
      expect(adeleSiblings.contains('Sam Smith') || adeleSiblings.contains('Amy Winehouse'), isTrue);

      final arijitSiblings = MusicAlgorithmService.getSiblingArtists('Arijit Singh', 'Bollywood');
      expect(arijitSiblings.contains('Atif Aslam') || arijitSiblings.contains('Mohit Chauhan'), isTrue);

      final sidhuSiblings = MusicAlgorithmService.getSiblingArtists('Sidhu Moose Wala', 'Punjabi');
      expect(sidhuSiblings.contains('Karan Aujla') || sidhuSiblings.contains('Diljit Dosanjh'), isTrue);
    });

    test('Generates smart radio queue for Adele Lovesong without title duplicates', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.init();
      final repo = TrackRepository(
        apiService: AudiusApiService(),
        saavnService: SaavnApiService(),
        youtubeService: YouTubeApiService(),
        storageService: storage,
      );

      final algorithm = MusicAlgorithmService(repository: repo);
      final seed = Track(
        id: 'yt_seed_1',
        title: 'Lovesong',
        artist: 'Adele',
        genre: 'Pop / Soul',
        durationSeconds: 240,
        provider: 'youtube',
      );

      final queue = await algorithm.generateRadioQueue(seed, targetCount: 10);
      expect(queue, isNotEmpty);

      // Verify strict anti-duplicate rule: No track in the recommended queue should have "Lovesong" as its title!
      for (final track in queue) {
        expect(
          track.title.toLowerCase().trim() == 'lovesong',
          isFalse,
          reason: 'Algorithm must not return duplicates of the searched song title: ${track.title}',
        );
      }

      // Verify that there is artist variety and not just 10 tracks by the same artist
      final uniqueArtists = queue.map((t) => MusicAlgorithmService.cleanArtist(t.artist).toLowerCase()).toSet();
      expect(uniqueArtists.length, greaterThan(1), reason: 'Queue should have diverse related artists');
    });
  });
}
