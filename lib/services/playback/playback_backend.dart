import 'dart:async';

import '../../models/playback_type.dart';
import '../../models/track.dart';
import 'youtube_iframe_backend.dart' show YouTubeIframeBackend;

/// Repeat mode for playback queue.
enum PlaybackRepeatMode {
  none,
  all,
  one,
}

/// Engine-neutral processing state.
enum PlaybackProcessingState {
  idle,
  loading,
  buffering,
  ready,
  completed,
  error,
}

/// Snapshot of everything the UI observes about playback.
class UnifiedPlaybackState {
  final Track? currentTrack;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;
  final PlaybackProcessingState processingState;

  /// Id of the backend currently driving the sound (e.g. `youtube_iframe`),
  /// or null when nothing is loaded.
  final String? backendId;

  final String? errorMessage;

  const UnifiedPlaybackState({
    this.currentTrack,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.processingState = PlaybackProcessingState.idle,
    this.backendId,
    this.errorMessage,
  });

  const UnifiedPlaybackState.initial() : this();

  bool get isBuffering =>
      processingState == PlaybackProcessingState.buffering ||
      processingState == PlaybackProcessingState.loading;

  bool get hasError => processingState == PlaybackProcessingState.error;

  /// True when the sound comes from the embedded YouTube player.
  bool get isYouTubeIframe =>
      backendId == YouTubeIframeBackend.id ||
      currentTrack?.playbackType == PlaybackType.youtubeIframe ||
      currentTrack != null;

  UnifiedPlaybackState copyWith({
    Track? currentTrack,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    Duration? bufferedPosition,
    PlaybackProcessingState? processingState,
    String? backendId,
    String? errorMessage,
    bool clearError = false,
    bool clearTrack = false,
  }) {
    return UnifiedPlaybackState(
      currentTrack: clearTrack ? null : (currentTrack ?? this.currentTrack),
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      processingState: processingState ?? this.processingState,
      backendId: backendId ?? this.backendId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  String toString() =>
      'UnifiedPlaybackState(${currentTrack?.title ?? '-'}, playing: $isPlaying, '
      'backend: $backendId, ${position.inSeconds}/${duration.inSeconds}s, '
      'processing: ${processingState.name}, error: $errorMessage)';
}

/// Things a backend tells the coordinator about, independent of position polling.
enum PlaybackBackendEventType {
  completed,
  error,
  autoplayBlocked,
  playing,
  paused,
  buffering,
  ready,
}

class PlaybackBackendEvent {
  final PlaybackBackendEventType type;
  final String? message;
  final int? errorCode;

  const PlaybackBackendEvent({
    required this.type,
    this.message,
    this.errorCode,
  });

  @override
  String toString() =>
      'PlaybackBackendEvent(${type.name}, code: $errorCode, message: $message)';
}

/// One playback engine behind a single contract.
abstract class PlaybackBackend {
  String get backendId;

  Set<PlaybackType> get supportedPlaybackTypes;

  bool get supportsBackgroundPlayback;

  bool get isReady;

  bool get isPlaying;

  Duration get position;

  Duration get duration;

  Duration get bufferedPosition;

  PlaybackProcessingState get processingState;

  Stream<PlaybackBackendEvent> get events;

  Future<void> load(Track track);

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  Future<void> stop();

  Future<void> setVolume(int volume);

  Future<void> dispose();
}