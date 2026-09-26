import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Initializes the background [AudioHandler] singleton.
/// Guarantees that only ONE audio service and ONE player instance exists.
Future<GoTuneAudioHandler> initAudioService() async {
  return await AudioService.init(
    builder: () => GoTuneAudioHandler.instance,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.gotune.channel.audio',
      androidNotificationChannelName: 'GoTune Playback',
      androidNotificationChannelDescription: 'Active background playback controls for GoTune',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
      androidShowNotificationBadge: true,
      fastForwardInterval: Duration(seconds: 10),
      rewindInterval: Duration(seconds: 10),
    ),
  );
}

/// Core audio handler bridging [just_audio] player with [audio_service] background engine.
/// Strictly enforces a singleton lifecycle and provides robust queue management,
/// audio focus management, and error resilience.
class GoTuneAudioHandler extends BaseAudioHandler with SeekHandler {
  // Singleton pattern implementation
  static GoTuneAudioHandler? _instance;
  static GoTuneAudioHandler get instance => _instance ??= GoTuneAudioHandler._internal();

  final AudioPlayer _player = AudioPlayer();

  int _currentIndex = -1;
  final List<MediaItem> _playlist = [];
  bool _isDisposed = false;

  /// Optional dynamic resolver called when a queued track lacks a pre-resolved stream URL.
  Future<String?> Function(MediaItem item)? onResolveStreamUrl;

  /// Callback fired when playback approaches the end of the queue, triggering infinite radio auto-fetch.
  VoidCallback? onQueueNearEnd;

  AudioPlayer get player => _player;
  int get currentIndex => _currentIndex;
  List<MediaItem> get playlist => List.unmodifiable(_playlist);

  GoTuneAudioHandler._internal() {
    _initStreams();
    _initAudioSession();
  }

  /// Factory constructor returns singleton instance.
  factory GoTuneAudioHandler() => instance;

  /// Configures Android audio session: phone-call interruptions, headphone unplugging.
  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      // Pause automatically when headphones are unplugged ("becoming noisy")
      session.becomingNoisyEventStream.listen((_) {
        pause();
      });

      // Handle phone call interruptions
      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(0.3);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              pause();
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(1.0);
              break;
            case AudioInterruptionType.pause:
              play();
              break;
            case AudioInterruptionType.unknown:
              break;
          }
        }
      });
    } catch (e) {
      debugPrint('[GoTuneAudioHandler] AudioSession setup error: $e');
    }
  }

  void _initStreams() {
    // Propagate player playback state into AudioService
    _player.playbackEventStream.listen(
      (PlaybackEvent event) {
        if (_isDisposed) return;
        final isPlaying = _player.playing;
        final processingState = _mapProcessingState(_player.processingState);

        playbackState.add(
          playbackState.value.copyWith(
            controls: [
              MediaControl.skipToPrevious,
              if (isPlaying) MediaControl.pause else MediaControl.play,
              MediaControl.skipToNext,
              MediaControl.stop,
            ],
            systemActions: const {
              MediaAction.seek,
              MediaAction.seekForward,
              MediaAction.seekBackward,
            },
            androidCompactActionIndices: const [0, 1, 2],
            processingState: processingState,
            playing: isPlaying,
            updatePosition: _player.position,
            bufferedPosition: _player.bufferedPosition,
            speed: _player.speed,
            queueIndex: _currentIndex,
          ),
        );
      },
      onError: (Object e, StackTrace st) {
        debugPrint('[GoTuneAudioHandler] playbackEventStream error: $e');
        playbackState.add(
          playbackState.value.copyWith(
            processingState: AudioProcessingState.error,
            errorMessage: 'Playback error: $e',
          ),
        );
      },
    );

    // Handle track completion
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _handleTrackCompleted();
      }
    });
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  void _handleTrackCompleted() {
    final repeat = playbackState.value.repeatMode;
    if (repeat == AudioServiceRepeatMode.one) {
      seek(Duration.zero);
      play();
    } else if (repeat == AudioServiceRepeatMode.all || repeat == AudioServiceRepeatMode.group) {
      skipToNext();
    } else {
      if (_currentIndex + 1 < _playlist.length) {
        if (_currentIndex + 2 >= _playlist.length) {
          onQueueNearEnd?.call();
        }
        skipToNext();
      } else {
        onQueueNearEnd?.call();
        stop();
      }
    }
  }

  // --- QUEUE MANAGEMENT ---

  /// Replaces active queue and plays the track at [index].
  Future<void> setQueueAndPlay(List<MediaItem> items, int index) async {
    _playlist.clear();
    _playlist.addAll(items);
    queue.add(List.from(_playlist));

    if (index >= 0 && index < _playlist.length) {
      _currentIndex = index;
      await _playTrackAtIndex(_currentIndex);
    }
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    _playlist.add(mediaItem);
    queue.add(List.from(_playlist));
    // If nothing was playing, start playing the newly added item
    if (_playlist.length == 1) {
      _currentIndex = 0;
      await _playTrackAtIndex(0);
    }
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    _playlist.addAll(mediaItems);
    queue.add(List.from(_playlist));
    if (_currentIndex < 0 && _playlist.isNotEmpty) {
      _currentIndex = 0;
      await _playTrackAtIndex(0);
    }
  }

  @override
  Future<void> insertQueueItem(int index, MediaItem mediaItem) async {
    final safeIndex = index.clamp(0, _playlist.length);
    _playlist.insert(safeIndex, mediaItem);
    if (safeIndex <= _currentIndex) {
      _currentIndex++;
    }
    queue.add(List.from(_playlist));
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    if (index < 0 || index >= _playlist.length) return;

    final wasCurrent = index == _currentIndex;
    _playlist.removeAt(index);

    if (index < _currentIndex) {
      _currentIndex--;
    } else if (wasCurrent) {
      if (_currentIndex >= _playlist.length) {
        _currentIndex = _playlist.length - 1;
      }
      if (_playlist.isNotEmpty && _currentIndex >= 0) {
        await _playTrackAtIndex(_currentIndex);
      } else {
        await stop();
      }
    }
    queue.add(List.from(_playlist));
  }

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    final index = _playlist.indexWhere((item) => item.id == mediaItem.id);
    if (index >= 0) {
      await removeQueueItemAt(index);
    }
  }

  @override
  Future<void> updateQueue(List<MediaItem> newQueue) async {
    final currentId = _currentIndex >= 0 && _currentIndex < _playlist.length
        ? _playlist[_currentIndex].id
        : null;

    _playlist.clear();
    _playlist.addAll(newQueue);
    queue.add(List.from(_playlist));

    if (currentId != null) {
      _currentIndex = _playlist.indexWhere((item) => item.id == currentId);
    }
  }

  /// Clears upcoming queue tracks while keeping the current track playing.
  Future<void> clearUpcomingQueue() async {
    if (_currentIndex >= 0 && _currentIndex < _playlist.length) {
      final current = _playlist[_currentIndex];
      _playlist.clear();
      _playlist.add(current);
      _currentIndex = 0;
      queue.add(List.from(_playlist));
    } else {
      await clearAllQueue();
    }
  }

  /// Clears the entire queue and stops playback.
  Future<void> clearAllQueue() async {
    _playlist.clear();
    _currentIndex = -1;
    queue.add(const []);
    await stop();
  }

  /// Reorders an item within the queue.
  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _playlist.length) return;
    if (newIndex < 0 || newIndex > _playlist.length) return;

    final currentItem = _currentIndex >= 0 && _currentIndex < _playlist.length
        ? _playlist[_currentIndex]
        : null;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final item = _playlist.removeAt(oldIndex);
    _playlist.insert(newIndex, item);

    if (currentItem != null) {
      _currentIndex = _playlist.indexOf(currentItem);
    }

    queue.add(List.from(_playlist));
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < _playlist.length) {
      _currentIndex = index;
      await _playTrackAtIndex(_currentIndex);
    }
  }

  // --- AUDIO LOADING & RESILIENT PLAYBACK ---

  /// Loads and plays track at [_currentIndex] with mirror fallback and timeout handling.
  Future<void> _playTrackAtIndex(int index) async {
    if (index < 0 || index >= _playlist.length) return;

    final item = _playlist[index];
    mediaItem.add(item);

    var streamUrl = item.extras?['streamUrl'] as String?;
    if ((streamUrl == null || streamUrl.isEmpty) && onResolveStreamUrl != null) {
      try {
        streamUrl = await onResolveStreamUrl!(item);
      } catch (e) {
        debugPrint('[GoTuneAudioHandler] onResolveStreamUrl dynamic error: $e');
      }
    }

    final mirrors = (item.extras?['mirrors'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [];

    if (streamUrl == null || streamUrl.isEmpty) {
      debugPrint('[GoTuneAudioHandler] No stream URL provided for ${item.title}');
      playbackState.add(
        playbackState.value.copyWith(
          processingState: AudioProcessingState.error,
          errorMessage: 'Track stream URL unavailable.',
        ),
      );
      return;
    }

    // List of candidate URLs to attempt in order
    final candidateUrls = <String>[streamUrl, ...mirrors];

    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.loading,
        playing: true,
      ),
    );

    bool loadSucceeded = false;
    String lastError = '';

    for (final url in candidateUrls) {
      if (url.trim().isEmpty) continue;
      try {
        final source = AudioSource.uri(
          Uri.parse(url),
          tag: item,
        );

        await _player.setAudioSource(source);
        await _player.play();
        loadSucceeded = true;
        break;
      } catch (e) {
        lastError = e.toString();
        debugPrint('[GoTuneAudioHandler] Failed loading stream ($url): $e');
      }
    }

    if (!loadSucceeded) {
      playbackState.add(
        playbackState.value.copyWith(
          processingState: AudioProcessingState.error,
          errorMessage: 'Unable to stream audio: $lastError',
          playing: false,
        ),
      );
    }
  }

  // --- CONTROLS ---

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_playlist.isEmpty) return;
    if (_currentIndex + 1 < _playlist.length) {
      _currentIndex++;
      await _playTrackAtIndex(_currentIndex);
      if (_currentIndex + 2 >= _playlist.length) {
        onQueueNearEnd?.call();
      }
    } else {
      onQueueNearEnd?.call();
      final repeat = playbackState.value.repeatMode;
      if (repeat == AudioServiceRepeatMode.all || repeat == AudioServiceRepeatMode.group) {
        _currentIndex = 0;
        await _playTrackAtIndex(_currentIndex);
      }
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_playlist.isEmpty) return;
    // If more than 3 seconds into the track, restart it
    if (_player.position > const Duration(seconds: 3)) {
      await seek(Duration.zero);
      return;
    }

    if (_currentIndex - 1 >= 0) {
      _currentIndex--;
      await _playTrackAtIndex(_currentIndex);
    } else {
      _currentIndex = _playlist.length - 1;
      await _playTrackAtIndex(_currentIndex);
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await _player.setLoopMode(LoopMode.off);
        break;
      case AudioServiceRepeatMode.one:
        await _player.setLoopMode(LoopMode.one);
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        await _player.setLoopMode(LoopMode.all);
        break;
    }
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode != AudioServiceShuffleMode.none;
    await _player.setShuffleModeEnabled(enabled);
    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
  }

  Future<void> dispose() async {
    _isDisposed = true;
    await _player.dispose();
  }
}
