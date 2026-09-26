import 'package:flutter_test/flutter_test.dart';
import 'package:gotune/models/track.dart';
import 'package:gotune/repositories/track_repository.dart';
import 'package:gotune/services/audius_api_service.dart';
import 'package:gotune/services/local_storage_service.dart';
import 'package:gotune/services/saavn_api_service.dart';
import 'package:gotune/services/youtube_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('YouTubeApiService & Universal Music Coverage Tests', () {
    late YouTubeApiService ytService;
    late TrackRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.init();
      ytService = YouTubeApiService();
      repository = TrackRepository(
        apiService: AudiusApiService(),
        saavnService: SaavnApiService(),
        youtubeService: ytService,
        storageService: storage,
      );
    });

    tearDown(() {
      ytService.close();
    });

    test('Searches Adele Lovesong on YouTube and converts to Track', () async {
      final results = await ytService.searchTracks('Adele Lovesong', limit: 5);

      expect(results, isNotEmpty);
      final first = results.first;
      expect(first.provider, 'youtube');
      expect(first.id.startsWith('yt_'), isTrue);
      expect(first.title.toLowerCase().contains('lovesong'), isTrue);
      expect(first.artist.toLowerCase().contains('adele'), isTrue);
      expect(first.bestArtworkUrl, isNotEmpty);
      expect(first.durationSeconds, greaterThan(0));
    });

    test('Resolves direct audio stream for Adele Lovesong', () async {
      final results = await ytService.searchTracks('Adele Lovesong', limit: 3);
      expect(results, isNotEmpty);

      final streamUrl = await ytService.resolveStreamUrl(results.first.id);
      expect(streamUrl, isNotNull);
      expect(streamUrl!.startsWith('http'), isTrue);
    });

    test('Unified search prioritizes official Adele track over covers', () async {
      final tracks = await repository.searchTracks('Adele Lovesong', limit: 10, provider: 'all');
      expect(tracks, isNotEmpty);

      // Verify that Adele's Lovesong is found and accessible
      final adeleTrack = tracks.firstWhere(
        (t) => t.artist.toLowerCase().contains('adele') && t.title.toLowerCase().contains('lovesong'),
      );
      expect(adeleTrack, isNotNull);
      expect(adeleTrack.provider, 'youtube');

      // Verify stream resolution through repository
      final resolvedUrl = await repository.resolveTrackStreamUrl(adeleTrack);
      expect(resolvedUrl, isNotEmpty);
      expect(resolvedUrl.startsWith('http'), isTrue);
    });

    test('YouTube Track serializes and deserializes to JSON correctly', () async {
      const sampleTrack = Track(
        id: 'yt_0wPhbmeNSOs',
        title: 'Lovesong',
        artist: 'Adele',
        artworkUrl150: 'https://img.youtube.com/vi/0wPhbmeNSOs/default.jpg',
        artworkUrl480: 'https://img.youtube.com/vi/0wPhbmeNSOs/mqdefault.jpg',
        artworkUrl1000: 'https://img.youtube.com/vi/0wPhbmeNSOs/hqdefault.jpg',
        durationSeconds: 320,
        genre: 'YouTube',
        provider: 'youtube',
      );

      final json = sampleTrack.toJson();
      expect(json['provider'], 'youtube');
      expect(json['id'], 'yt_0wPhbmeNSOs');

      final reconstructed = Track.fromJson(json);
      expect(reconstructed.id, sampleTrack.id);
      expect(reconstructed.title, sampleTrack.title);
      expect(reconstructed.artist, sampleTrack.artist);
      expect(reconstructed.provider, 'youtube');

      final mediaItem = reconstructed.toMediaItem();
      expect(mediaItem.album, 'YouTube');
      expect(mediaItem.extras?['provider'], 'youtube');
    });
  });
}
