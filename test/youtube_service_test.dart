import 'package:flutter_test/flutter_test.dart';
import 'package:gotune/models/playback_type.dart';
import 'package:gotune/models/track.dart';
import 'package:gotune/repositories/track_repository.dart';
import 'package:gotune/services/local_storage_service.dart';
import 'package:gotune/services/youtube_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('YouTubeApiService & Safe Metadata Tests', () {
    late YouTubeApiService ytService;
    late TrackRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.init();
      ytService = YouTubeApiService();
      repository = TrackRepository(
        youtubeService: ytService,
        storageService: storage,
      );
    });

    tearDown(() {
      ytService.close();
    });

    test('Searches YouTube tracks cleanly with video IDs for IFrame player', () async {
      final results = await ytService.searchTracks('Adele Lovesong', limit: 5);

      expect(results, isNotEmpty);
      final first = results.first;
      expect(first.source, 'youtube');
      expect(first.isYouTubeIframe, isTrue);
      expect(first.playbackType, PlaybackType.youtubeIframe);
      expect(first.isPlayable, isTrue);
    });

    test('Track with YouTube fields serializes and deserializes correctly', () async {
      const sampleTrack = Track(
        id: 'yt_waAlgFq9Xq8',
        youtubeVideoId: 'waAlgFq9Xq8',
        album: '21',
        title: 'Lovesong',
        artist: 'Adele',
        artworkUrl150: 'https://example.com/art150.jpg',
        artworkUrl480: 'https://example.com/art500.jpg',
        durationSeconds: 320,
        genre: 'Pop',
        source: 'youtube',
      );

      final json = sampleTrack.toJson();
      expect(json['id'], 'yt_waAlgFq9Xq8');
      expect(json['youtubeVideoId'], 'waAlgFq9Xq8');
      expect(json['album'], '21');
      expect(json['source'], 'youtube');

      final reconstructed = Track.fromJson(json);
      expect(reconstructed.id, sampleTrack.id);
      expect(reconstructed.resolvedYoutubeVideoId, 'waAlgFq9Xq8');
      expect(reconstructed.album, sampleTrack.album);
      expect(reconstructed.artist, sampleTrack.artist);
      expect(reconstructed.source, 'youtube');
      expect(reconstructed.isLocal, isFalse);
      expect(reconstructed.isPlayable, isTrue);
    });

    test('YouTube video ID resolver handles both bare IDs and prefixed IDs', () {
      const bareTrack = Track(
        id: 'waAlgFq9Xq8',
        title: 'Song 1',
        artist: 'Artist 1',
      );
      expect(bareTrack.resolvedYoutubeVideoId, 'waAlgFq9Xq8');

      const prefixedTrack = Track(
        id: 'yt_waAlgFq9Xq8',
        title: 'Song 2',
        artist: 'Artist 2',
      );
      expect(prefixedTrack.resolvedYoutubeVideoId, 'waAlgFq9Xq8');

      const explicitVideoIdTrack = Track(
        id: 'custom_id',
        youtubeVideoId: 'waAlgFq9Xq8',
        title: 'Song 3',
        artist: 'Artist 3',
      );
      expect(explicitVideoIdTrack.resolvedYoutubeVideoId, 'waAlgFq9Xq8');
    });

    test('TrackRepository delegates catalog discovery to YouTube aggregator', () async {
      expect(repository.catalogAggregator, isNotNull);
      expect(repository.youtubeProvider, isNotNull);
    });
  });
}
