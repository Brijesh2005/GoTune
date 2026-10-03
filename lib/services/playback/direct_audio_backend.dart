import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../models/playback_type.dart';
import '../../models/track.dart';
import '../audio_handler.dart';
import 'playback_backend.dart';

/// Direct audio playback engine powered by [just_audio] and [audio_service].
/// Provides 320kbps pristine audio, full Android background playback,
/// system notification controls, and lock screen media integration.
class DirectAudioBackend implements PlaybackBackend {
  static const String id = 'direct_audio';

  final GoTuneAudioHandler _audioHandler;
  final StreamController<PlaybackBackendEvent> _eventController =
      StreamController<PlaybackBackendEvent>.broadcast();

  StreamSubscription<PlaybackEvent>? _playbackEventSub;
  StreamSubscription<PlayerState>? _playerStateSub;
  bool _isDisposed = false;

  DirectAudioBackend({GoTuneAudioHandler? audioHandler})
      : _audioHandler = audioHandler ?? GoTuneAudioHandler.instance {
    _initListeners();
  }

  void _initListeners() {
    _playerStateSub = _audioHandler.player.playerStateStream.listen((state) {
      if (_isDisposed) return;
      if (state.playing) {
        _eventController.add(
          const PlaybackBackendEvent(type: PlaybackBackendEventType.playing),
        );
      } else if (state.processingState != ProcessingState.completed) {
        _eventController.add(
          const PlaybackBackendEvent(type: PlaybackBackendEventType.paused),
        );
      }

      switch (state.processingState) {
        case ProcessingState.buffering:
          _eventController.add(
            const PlaybackBackendEvent(type: PlaybackBackendEventType.buffering),
          );
          break;
        case ProcessingState.ready:
          _eventController.add(
            const PlaybackBackendEvent(type: PlaybackBackendEventType.ready),
          );
          break;
        case ProcessingState.completed:
          _eventController.add(
            const PlaybackBackendEvent(type: PlaybackBackendEventType.completed),
          );
          break;
        case ProcessingState.idle:
        case ProcessingState.loading:
          break;
      }
    });

    _playbackEventSub = _audioHandler.player.playbackEventStream.listen(
      (_) {},
      onError: (Object e) {
        if (_isDisposed) return;
        debugPrint('[DirectAudioBackend] Error: $e');
        _eventController.add(
          PlaybackBackendEvent(
            type: PlaybackBackendEventType.error,
            message: e.toString(),
          ),
        );
      },
    );
  }

  @override
  String get backendId => id;

  @override
  Set<PlaybackType> get supportedPlaybackTypes => const {
        PlaybackType.directStream,
        PlaybackType.youtubeIframe,
      };

  @override
  bool get supportsBackgroundPlayback => true;

  @override
  bool get isReady => true;

  @override
  bool get isPlaying => _audioHandler.player.playing;

  @override
  Duration get position => _audioHandler.player.position;

  @override
  Duration get duration => _audioHandler.player.duration ?? Duration.zero;

  @override
  Duration get bufferedPosition => _audioHandler.player.bufferedPosition;

  @override
  PlaybackProcessingState get processingState {
    switch (_audioHandler.player.processingState) {
      case ProcessingState.idle:
        return PlaybackProcessingState.idle;
      case ProcessingState.loading:
        return PlaybackProcessingState.loading;
      case ProcessingState.buffering:
        return PlaybackProcessingState.buffering;
      case ProcessingState.ready:
        return PlaybackProcessingState.ready;
      case ProcessingState.completed:
        return PlaybackProcessingState.completed;
    }
  }

  @override
  Stream<PlaybackBackendEvent> get events => _eventController.stream;

  @override
  Future<void> load(Track track) async {
    final mediaItem = track.toMediaItem();
    await _audioHandler.playMediaItem(mediaItem);
  }

  @override
  Future<void> play() => _audioHandler.play();

  @override
  Future<void> pause() => _audioHandler.pause();

  @override
  Future<void> seek(Duration position) => _audioHandler.seek(position);

  @override
  Future<void> stop() => _audioHandler.stop();

  @override
  Future<void> setVolume(int volume) async {
    final vol = (volume / 100.0).clamp(0.0, 1.0);
    await _audioHandler.player.setVolume(vol);
  }

  @override
  Future<void> dispose() async {
    _isDisposed = true;
    await _playerStateSub?.cancel();
    await _playbackEventSub?.cancel();
    await _eventController.close();
  }
}
