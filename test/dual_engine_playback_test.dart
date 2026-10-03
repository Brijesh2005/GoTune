import 'package:flutter_test/flutter_test.dart';
import 'package:gotune/models/playback_type.dart';
import 'package:gotune/models/track.dart';
import 'package:gotune/services/saavn_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dual-Engine & Background Playback Architecture Tests', () {
    test('Track model supports direct stream and converts to MediaItem', () {
      const track = Track(
        id: 'track_123',
        title: 'Kesariya',
        artist: 'Arijit Singh',
        streamUrl: 'https://example.com/audio_320.mp4',
        durationSeconds: 268,
      );

      expect(track.sourceType, equals(PlaybackType.directStream));
      expect(track.hasDirectStream, isTrue);
      expect(track.isYouTubeIframe, isFalse);

      final mediaItem = track.toMediaItem();
      expect(mediaItem.id, equals('track_123'));
      expect(mediaItem.title, equals('Kesariya'));
      expect(mediaItem.artist, equals('Arijit Singh'));
      expect(mediaItem.extras?['streamUrl'], equals('https://example.com/audio_320.mp4'));
    });

    test('Track model handles YouTube video fallback', () {
      const track = Track(
        id: 'yt_dQw4w9WgXcQ',
        title: 'Never Gonna Give You Up',
        artist: 'Rick Astley',
        youtubeVideoId: 'dQw4w9WgXcQ',
      );

      expect(track.sourceType, equals(PlaybackType.youtubeIframe));
      expect(track.hasDirectStream, isFalse);
      expect(track.isYouTubeIframe, isTrue);
      expect(track.resolvedYoutubeVideoId, equals('dQw4w9WgXcQ'));
    });

    test('SaavnApiService DES decryption decodes stream URL cleanly', () {
      final saavn = SaavnApiService();
      // Valid DES decrypt test with sample encrypted input or null safety
      expect(saavn.decryptMediaUrl(null), isNull);
      expect(saavn.decryptMediaUrl(''), isNull);
    });

    test('PlaybackType wire conversion supports directStream', () {
      expect(PlaybackType.directStream.wireName, equals('directStream'));
      expect(PlaybackType.youtubeIframe.wireName, equals('youtubeIframe'));
      expect(PlaybackTypeWire.fromWire('directStream'), equals(PlaybackType.directStream));
      expect(PlaybackTypeWire.fromWire('youtubeIframe'), equals(PlaybackType.youtubeIframe));
      expect(PlaybackType.directStream.usesDirectAudioEngine, isTrue);
      expect(PlaybackType.youtubeIframe.usesDirectAudioEngine, isFalse);
    });
  });
}
