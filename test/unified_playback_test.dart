import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gotune/models/playback_type.dart';
import 'package:gotune/models/track.dart';
import 'package:gotune/services/youtube/youtube_player_channel.dart';
import 'package:gotune/services/youtube/youtube_player_event.dart';

/// Builds a pure YouTube track: video ID for IFrame player.
Track youtubeTrack({
  String id = 'yt_abc',
  String title = 'YouTube Song',
  String videoId = 'abc123XYZ_-',
}) {
  return Track(
    id: id,
    youtubeVideoId: videoId,
    title: title,
    artist: 'YT Artist',
    durationSeconds: 180,
    source: 'youtube',
  );
}

/// In-memory [YouTubePlayerChannel] used to drive the backend without a WebView.
class FakeYouTubeChannel implements YouTubePlayerChannel {
  final StreamController<YouTubePlayerEvent> _events =
      StreamController<YouTubePlayerEvent>.broadcast();

  bool _ready = false;
  String? _videoId;

  final List<String> commands = [];
  final List<String> loadedVideoIds = [];
  final List<bool> autoplayFlags = [];

  @override
  bool get isReady => _ready;

  @override
  String? get currentVideoId => _videoId;

  @override
  Stream<YouTubePlayerEvent> get events => _events.stream;

  void markReady() => _ready = true;

  @override
  Future<void> loadVideo(String videoId, {bool autoplay = true}) async {
    commands.add('load:$videoId:$autoplay');
    loadedVideoIds.add(videoId);
    autoplayFlags.add(autoplay);
    _videoId = videoId;
  }

  @override
  Future<void> loadAndPlayVideo(String videoId) async {
    commands.add('loadAndPlay:$videoId');
    loadedVideoIds.add(videoId);
    autoplayFlags.add(true);
    _videoId = videoId;
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
  Future<void> setVolume(int volume) async => commands.add('volume:$volume');

  @override
  Future<double?> currentTimeSeconds() async => 12.5;

  @override
  Future<double?> durationSeconds() async => 180.0;

  void emit(YouTubePlayerEvent event) => _events.add(event);

  Future<void> close() => _events.close();
}

void main() {
  group('Track playback classification', () {
    test('all YouTube tracks route to the iframe player', () {
      final track = youtubeTrack();
      expect(track.playbackType, PlaybackType.youtubeIframe);
      expect(track.isYouTubeIframe, isTrue);
      expect(track.isPlayable, isTrue);
    });

    test('YouTube video id resolves from an explicit field', () {
      expect(youtubeTrack(videoId: 'vid123XYZ_-').resolvedYoutubeVideoId, 'vid123XYZ_-');
    });

    test('YouTube video id derives from a yt_ prefixed track id', () {
      const track = Track(
        id: 'yt_zzz09876543',
        title: 'T',
        artist: 'A',
        source: 'youtube',
      );
      expect(track.resolvedYoutubeVideoId, 'zzz09876543');
    });
  });

  group('FakeYouTubeChannel commands', () {
    test('records load, play, pause, seek, stop commands correctly', () async {
      final channel = FakeYouTubeChannel();
      await channel.loadVideo('abc123XYZ_-');
      await channel.play();
      await channel.pause();
      await channel.seekTo(const Duration(seconds: 45));
      await channel.stop();

      expect(channel.commands, [
        'load:abc123XYZ_-:true',
        'play',
        'pause',
        'seek',
        'stop',
      ]);
      expect(channel.currentVideoId, 'abc123XYZ_-');
      await channel.close();
    });
  });
}