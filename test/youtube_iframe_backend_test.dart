import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gotune/models/playback_type.dart';
import 'package:gotune/models/track.dart';
import 'package:gotune/services/playback/playback_backend.dart';
import 'package:gotune/services/youtube/youtube_player_channel.dart';
import 'package:gotune/services/youtube/youtube_player_event.dart';
import 'package:gotune/services/youtube/youtube_player_service.dart';
import 'package:gotune/services/playback/youtube_iframe_backend.dart';

/// In-memory channel so backend behaviour can be asserted without a WebView.
class FakeChannel implements YouTubePlayerChannel {
  final StreamController<YouTubePlayerEvent> _events =
      StreamController<YouTubePlayerEvent>.broadcast();

  final List<String> commands = [];
  String? videoId;

  @override
  bool get isReady => true;

  @override
  String? get currentVideoId => videoId;

  @override
  Stream<YouTubePlayerEvent> get events => _events.stream;

  @override
  Future<void> loadVideo(String id, {bool autoplay = true}) async {
    commands.add('load:$id:$autoplay');
    videoId = id;
  }

  @override
  Future<void> loadAndPlayVideo(String id) async {
    commands.add('loadAndPlay:$id');
    videoId = id;
  }

  @override
  Future<void> play() async => commands.add('play');

  @override
  Future<void> pause() async => commands.add('pause');

  @override
  Future<void> seekTo(Duration position) async => commands.add('seek');

  @override
  Future<void> stop() async => commands.add('stop');

  @override
  Future<void> setVolume(int v) async => commands.add('volume');

  @override
  Future<double?> currentTimeSeconds() async => 5;

  @override
  Future<double?> durationSeconds() async => 100;

  void emit(YouTubePlayerEvent e) => _events.add(e);

  Future<void> close() => _events.close();
}

Track yt({String id = 'yt_a', String videoId = 'vid_a'}) {
  return Track(
    id: id,
    youtubeVideoId: videoId,
    title: 'YT',
    artist: 'YT Artist',
    durationSeconds: 100,
    source: 'youtube',
  );
}

void main() {
  late FakeChannel channel;
  late YouTubePlayerService service;
  late YouTubeIframeBackend backend;

  setUp(() {
    channel = FakeChannel();
    service = YouTubePlayerService(channel: channel);
    backend = YouTubeIframeBackend(service: service);
  });

  tearDown(() async {
    await backend.dispose();
    await service.dispose();
    await channel.close();
  });

  group('YouTubeIframeBackend identity', () {
    test('advertises itself as the iframe engine only', () {
      expect(backend.backendId, 'youtube_iframe');
      expect(backend.supportedPlaybackTypes, {PlaybackType.youtubeIframe});
      expect(backend.supportsBackgroundPlayback, isFalse);
    });

    test('never claims a buffered position the API never reported', () {
      // The IFrame API exposes no buffered ranges; reporting position here would
      // draw a fake buffer bar.
      expect(backend.bufferedPosition, Duration.zero);
    });
  });

  group('loading', () {
    test('loads a video id and requests autoplay', () async {
      await backend.load(yt(videoId: 'abc123'));
      expect(channel.commands, ['load:abc123:true']);
      expect(backend.videoId, 'abc123');
    });

    test('cues without playing when autoplay is not wanted', () async {
      await backend.load(yt(videoId: 'abc123'), autoplay: false);
      expect(channel.commands, ['load:abc123:false']);
    });

    test('a track without a video id fails loudly', () async {
      final events = <PlaybackBackendEvent>[];
      backend.events.listen(events.add);

      // No providerTrackId and no explicit id: nothing to hand the player.
      const broken = Track(
        id: 'x',
        title: 'T',
        artist: 'A',
        source: 'youtube',
      );

      await backend.load(broken);

      expect(channel.commands, isEmpty);
      expect(backend.processingState, PlaybackProcessingState.error);
      expect(events.single.type, PlaybackBackendEventType.error);
    });
  });

  group('event translation', () {
    test('playing updates state and notifies the coordinator', () async {
      final events = <PlaybackBackendEvent>[];
      backend.events.listen(events.add);

      channel.emit(const YouTubePlayerEvent(
        type: YouTubePlayerEventType.playing,
        position: Duration(seconds: 12),
        duration: Duration(seconds: 100),
        videoId: 'vid_a',
      ));
      await Future<void>.delayed(Duration.zero);

      expect(backend.isPlaying, isTrue);
      expect(backend.processingState, PlaybackProcessingState.ready);
      expect(events.map((e) => e.type), contains(PlaybackBackendEventType.playing));
    });

    test('paused clears playing and notifies', () async {
      final events = <PlaybackBackendEvent>[];
      backend.events.listen(events.add);

      channel.emit(const YouTubePlayerEvent(type: YouTubePlayerEventType.playing));
      await Future<void>.delayed(Duration.zero);
      channel.emit(const YouTubePlayerEvent(type: YouTubePlayerEventType.paused));
      await Future<void>.delayed(Duration.zero);

      expect(backend.isPlaying, isFalse);
      expect(events.map((e) => e.type), contains(PlaybackBackendEventType.paused));
    });

    test('buffering is surfaced rather than silently ignored', () async {
      final events = <PlaybackBackendEvent>[];
      backend.events.listen(events.add);

      channel.emit(const YouTubePlayerEvent(type: YouTubePlayerEventType.buffering));
      await Future<void>.delayed(Duration.zero);

      expect(backend.processingState, PlaybackProcessingState.buffering);
      expect(events.map((e) => e.type), contains(PlaybackBackendEventType.buffering));
    });

    test('completion is reported once, with its code-free event', () async {
      final events = <PlaybackBackendEvent>[];
      backend.events.listen(events.add);

      channel.emit(const YouTubePlayerEvent(type: YouTubePlayerEventType.ended));
      await Future<void>.delayed(Duration.zero);

      expect(backend.processingState, PlaybackProcessingState.completed);
      expect(events.single.type, PlaybackBackendEventType.completed);
      expect(backend.isPlaying, isFalse);
    });

    test('an error carries the code and a user-facing message', () async {
      final events = <PlaybackBackendEvent>[];
      backend.events.listen(events.add);

      channel.emit(const YouTubePlayerEvent(
        type: YouTubePlayerEventType.error,
        errorCode: 153,
      ));
      await Future<void>.delayed(Duration.zero);

      expect(backend.processingState, PlaybackProcessingState.error);
      final error = events.firstWhere(
        (e) => e.type == PlaybackBackendEventType.error,
      );
      expect(error.errorCode, 153);
      expect(error.message, isNotEmpty);
    });
  });

  group('autoplay blocking', () {
    test('a block is reported and flagged for a user gesture', () async {
      final events = <PlaybackBackendEvent>[];
      backend.events.listen(events.add);

      channel.emit(const YouTubePlayerEvent(
        type: YouTubePlayerEventType.autoplayBlocked,
      ));
      await Future<void>.delayed(Duration.zero);

      expect(backend.autoplayBlocked, isTrue);
      expect(backend.isPlaying, isFalse);
      expect(
        events.map((e) => e.type),
        contains(PlaybackBackendEventType.autoplayBlocked),
      );
    });

    test('actual playback clears the block', () async {
      channel.emit(const YouTubePlayerEvent(
        type: YouTubePlayerEventType.autoplayBlocked,
      ));
      await Future<void>.delayed(Duration.zero);
      expect(backend.autoplayBlocked, isTrue);

      channel.emit(const YouTubePlayerEvent(type: YouTubePlayerEventType.playing));
      await Future<void>.delayed(Duration.zero);

      // The prompt must not linger once sound is genuinely running.
      expect(backend.autoplayBlocked, isFalse);
    });

    test('recovery loads and plays in one gesture-bound call', () async {
      await backend.load(yt(videoId: 'recover1'));
      channel.commands.clear();

      await backend.retryPlayback();

      // Two round trips would lose the gesture the browser needs.
      expect(channel.commands, ['loadAndPlay:recover1']);
    });

    test('recovery with nothing loaded is a no-op', () async {
      await backend.retryPlayback();
      expect(channel.commands, isEmpty);
    });
  });

  group('transport commands', () {
    test('seek, volume and stop forward to the player', () async {
      await backend.seek(const Duration(seconds: 30));
      await backend.setVolume(80);
      await backend.stop();

      expect(channel.commands, ['seek', 'volume', 'stop']);
      expect(backend.processingState, PlaybackProcessingState.idle);
    });
  });

  group('service state', () {
    test('a load resets error and autoplay state for the new video', () async {
      channel.emit(const YouTubePlayerEvent(
        type: YouTubePlayerEventType.error,
        errorCode: 150,
      ));
      await Future<void>.delayed(Duration.zero);
      expect(service.lastErrorCode, 150);

      await service.loadVideo('fresh1');

      expect(service.lastErrorCode, isNull);
      expect(service.lastErrorMessage, isNull);
      expect(service.autoplayBlocked, isFalse);
      expect(service.currentVideoId, 'fresh1');
    });

    test('an empty video id is rejected before it reaches the WebView', () async {
      expect(() => service.loadVideo('   '), throwsArgumentError);
      expect(channel.commands, isEmpty);
    });

    test('duration falls back to the last reported value', () async {
      expect(service.duration, Duration.zero);
      channel.emit(const YouTubePlayerEvent(
        type: YouTubePlayerEventType.ready,
        duration: Duration(seconds: 100),
      ));
      await Future<void>.delayed(Duration.zero);

      expect(service.duration, const Duration(seconds: 100));
    });
  });
}