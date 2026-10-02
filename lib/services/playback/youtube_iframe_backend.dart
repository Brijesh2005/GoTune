import 'dart:async';

import '../../models/playback_type.dart';
import '../../models/track.dart';
import '../youtube/youtube_player_event.dart';
import '../youtube/youtube_player_service.dart';
import 'playback_backend.dart';

/// YouTube IFrame player backend.
///
/// Owns nothing except the mapping between `YT.Player` state and the neutral
/// [PlaybackBackend] contract. It is a *real* playback engine — the sound comes
/// from the official embedded player — with one deliberate limitation surfaced
/// through [supportsBackgroundPlayback]: a WebView-hosted iframe cannot keep
/// playing once the app is backgrounded, and GoTune does not extract its audio
/// to work around that.
class YouTubeIframeBackend implements PlaybackBackend {
  static const String id = 'youtube_iframe';

  final YouTubePlayerService _service;

  final StreamController<PlaybackBackendEvent> _events =
      StreamController<PlaybackBackendEvent>.broadcast();

  StreamSubscription<YouTubePlayerEvent>? _sub;

  PlaybackProcessingState _processingState = PlaybackProcessingState.idle;
  bool _isPlaying = false;
  bool _autoplayBlocked = false;
  String? _videoId;
  Duration _duration = Duration.zero;

  YouTubeIframeBackend({required YouTubePlayerService service})
      : _service = service {
    _sub = _service.events.listen(_onPlayerEvent);
  }

  @override
  String get backendId => id;

  @override
  Set<PlaybackType> get supportedPlaybackTypes => const {
        PlaybackType.youtubeIframe,
      };

  /// Always false: the embedded player needs a live WebView.
  @override
  bool get supportsBackgroundPlayback => false;

  @override
  bool get isReady => _service.isReady;

  @override
  bool get isPlaying => _isPlaying;

  @override
  Duration get position => _service.position;

  @override
  Duration get duration =>
      _service.duration > Duration.zero ? _service.duration : _duration;

  /// The IFrame API exposes no buffered-range information, so this reports
  /// "unknown" (zero) rather than inventing a value that a seek bar would
  /// render as a real buffer.
  @override
  Duration get bufferedPosition => Duration.zero;

  @override
  PlaybackProcessingState get processingState => _processingState;

  @override
  Stream<PlaybackBackendEvent> get events => _events.stream;

  /// True when the browser blocked autoplay and a user tap is required.
  bool get autoplayBlocked => _autoplayBlocked;

  /// Video currently loaded in the player.
  String? get videoId => _videoId ?? _service.currentVideoId;

  void _onPlayerEvent(YouTubePlayerEvent event) {
    if (event.videoId != null && event.videoId!.isNotEmpty) {
      _videoId = event.videoId;
    }
    if (event.duration > Duration.zero) _duration = event.duration;

    switch (event.type) {
      case YouTubePlayerEventType.ready:
        _processingState = PlaybackProcessingState.ready;
        _emit(const PlaybackBackendEvent(type: PlaybackBackendEventType.ready));
        break;
      case YouTubePlayerEventType.unstarted:
        _processingState = PlaybackProcessingState.idle;
        _isPlaying = false;
        break;
      case YouTubePlayerEventType.cued:
        _processingState = PlaybackProcessingState.ready;
        _isPlaying = false;
        break;
      case YouTubePlayerEventType.buffering:
        _processingState = PlaybackProcessingState.buffering;
        _emit(const PlaybackBackendEvent(type: PlaybackBackendEventType.buffering));
        break;
      case YouTubePlayerEventType.playing:
        _processingState = PlaybackProcessingState.ready;
        _isPlaying = true;
        _autoplayBlocked = false;
        // Transport state is pushed, not polled, so the UI stays in step with
        // the real player instead of waiting for the next position tick.
        _emit(const PlaybackBackendEvent(type: PlaybackBackendEventType.playing));
        break;
      case YouTubePlayerEventType.paused:
        _processingState = PlaybackProcessingState.ready;
        _isPlaying = false;
        _emit(const PlaybackBackendEvent(type: PlaybackBackendEventType.paused));
        break;
      case YouTubePlayerEventType.ended:
        _processingState = PlaybackProcessingState.completed;
        _isPlaying = false;
        _emit(const PlaybackBackendEvent(type: PlaybackBackendEventType.completed));
        break;
      case YouTubePlayerEventType.autoplayBlocked:
        _processingState = PlaybackProcessingState.ready;
        _isPlaying = false;
        _autoplayBlocked = true;
        _emit(
          const PlaybackBackendEvent(
            type: PlaybackBackendEventType.autoplayBlocked,
            message: 'Tap play to start this YouTube video.',
          ),
        );
        break;
      case YouTubePlayerEventType.error:
        _processingState = PlaybackProcessingState.error;
        _isPlaying = false;
        _emit(
          PlaybackBackendEvent(
            type: PlaybackBackendEventType.error,
            errorCode: event.errorCode,
            message: event.message ??
                'This YouTube video cannot be played here.',
          ),
        );
        break;
      case YouTubePlayerEventType.timeUpdate:
        break;
    }
  }

  void _emit(PlaybackBackendEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  /// Loads a video by ID into the existing player.
  ///
  /// When [autoplay] is false the video is only cued, which is what the
  /// coordinator uses when it detects an autoplay block and needs the listener
  /// to press play themselves.
  @override
  Future<void> load(Track track, {bool autoplay = true}) async {
    final videoId = track.resolvedYoutubeVideoId;
    if (videoId == null || videoId.isEmpty) {
      _processingState = PlaybackProcessingState.error;
      _emit(
        const PlaybackBackendEvent(
          type: PlaybackBackendEventType.error,
          message: 'This track has no YouTube video to play.',
        ),
      );
      return;
    }

    _videoId = videoId;
    _processingState = PlaybackProcessingState.loading;
    _autoplayBlocked = false;

    await _service.loadVideo(videoId, autoplay: autoplay);
  }

  /// Restarts the loaded video in response to an explicit user tap.
  ///
  /// Browsers always honour play() inside a real gesture, so this is the
  /// supported recovery for an autoplay block. The [autoplayBlocked] flag is
  /// cleared only when the player reports playback, so the UI prompt persists
  /// until audio is genuinely running.
  Future<void> retryPlayback() async {
    final id = videoId;
    if (id == null) return;
    // Re-load as well as play: an autoplay-blocked video is often only cued, so
    // a bare play() would resume nothing.
    await _service.loadAndPlayVideo(id);
  }

  @override
  Future<void> play() => _service.play();

  @override
  Future<void> pause() => _service.pause();

  @override
  Future<void> seek(Duration position) => _service.seekTo(position);

  @override
  Future<void> stop() async {
    await _service.stop();
    _isPlaying = false;
    _processingState = PlaybackProcessingState.idle;
  }

  @override
  Future<void> setVolume(int volume) => _service.setVolume(volume);

  @override
  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    await _events.close();
  }
}