import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import '../models/track.dart';
import '../repositories/recently_played_repository.dart';
import '../repositories/track_repository.dart';
import '../services/audio_handler.dart';
import '../services/music_algorithm_service.dart';

/// Comprehensive provider managing active audio playback, interactive queue manipulation,
/// live seek scrubbing, and playback failure resilience.
class AudioPlayerProvider extends ChangeNotifier {
  final GoTuneAudioHandler _audioHandler;
  final TrackRepository _repository;
  final RecentlyPlayedRepository? _recentlyPlayedRepository;
  late final MusicAlgorithmService _algorithmService;

  Track? _currentTrack;
  List<Track> _queue = [];
  int _currentIndex = -1;

  bool _isPlaying = false;
  bool _isBuffering = false;
  String? _errorMessage;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _bufferedPosition = Duration.zero;

  bool _isShuffle = false;
  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;
  List<Track> _unshuffledQueue = [];

  // Algorithm & Smart Radio States
  bool _isGeneratingRadio = false;
  bool _autoPlayRadio = true;
  String? _radioSeedArtist;

  // Sleep Timer
  Timer? _sleepTimer;
  Timer? _sleepCountdownTimer;
  Duration? _sleepTimerRemaining;

  StreamSubscription? _playbackStateSub;
  StreamSubscription? _mediaItemSub;
  StreamSubscription? _queueSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _bufferedPositionSub;

  AudioPlayerProvider({
    required GoTuneAudioHandler audioHandler,
    required TrackRepository repository,
    RecentlyPlayedRepository? recentlyPlayedRepository,
    MusicAlgorithmService? algorithmService,
  })  : _audioHandler = audioHandler,
        _repository = repository,
        _recentlyPlayedRepository = recentlyPlayedRepository,
        _algorithmService = algorithmService ?? MusicAlgorithmService(repository: repository) {
    _bindStreams();
    _setupAudioHandlerCallbacks();
  }

  // --- Getters ---
  Track? get currentTrack => _currentTrack;
  List<Track> get queue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  bool get hasActiveTrack => _currentTrack != null;

  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  bool get isPaused => !_isPlaying && !_isBuffering && hasActiveTrack;
  bool get hasError => _errorMessage != null;
  String? get errorMessage => _errorMessage;

  Duration get position => _position;
  Duration get duration => _duration;
  Duration get bufferedPosition => _bufferedPosition;

  bool get isShuffle => _isShuffle;
  AudioServiceRepeatMode get repeatMode => _repeatMode;

  // Smart Radio Getters
  bool get isGeneratingRadio => _isGeneratingRadio;
  bool get autoPlayRadio => _autoPlayRadio;
  String? get radioSeedArtist => _radioSeedArtist;

  void toggleAutoPlayRadio() {
    _autoPlayRadio = !_autoPlayRadio;
    notifyListeners();
  }

  void _setupAudioHandlerCallbacks() {
    _audioHandler.onResolveStreamUrl = (MediaItem item) async {
      final track = _queue.firstWhere(
        (t) => t.id == item.id,
        orElse: () => _createTrackFromMediaItem(item),
      );
      return await _repository.resolveTrackStreamUrl(track);
    };

    _audioHandler.onQueueNearEnd = () {
      if (_autoPlayRadio && !_isGeneratingRadio && _currentTrack != null) {
        _populateSmartRadio(_currentTrack!, appendOnly: true);
      }
    };
  }

  // Sleep Timer Getters
  bool get isSleepTimerActive => _sleepTimer != null && _sleepTimer!.isActive;
  Duration? get sleepTimerRemaining => _sleepTimerRemaining;
  String get formattedSleepTimerRemaining {
    if (_sleepTimerRemaining == null) return '';
    final totalSeconds = _sleepTimerRemaining!.inSeconds;
    if (totalSeconds <= 0) return '00:00';
    final minutes = _sleepTimerRemaining!.inMinutes;
    final seconds = totalSeconds % 60;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remMinutes = minutes % 60;
      return '${hours}h ${remMinutes}m';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _bindStreams() {
    // 1. Playback state updates
    _playbackStateSub = _audioHandler.playbackState.listen((PlaybackState state) {
      _isPlaying = state.playing;
      _isBuffering = state.processingState == AudioProcessingState.buffering ||
          state.processingState == AudioProcessingState.loading;
      _position = state.position;
      _bufferedPosition = state.bufferedPosition;
      _repeatMode = state.repeatMode;
      _isShuffle = state.shuffleMode != AudioServiceShuffleMode.none;

      if (state.processingState == AudioProcessingState.error) {
        _errorMessage = state.errorMessage ?? 'Playback error occurred.';
      } else {
        _errorMessage = null;
      }

      if (state.queueIndex != null && state.queueIndex! >= 0 && state.queueIndex! < _queue.length) {
        _currentIndex = state.queueIndex!;
        _currentTrack = _queue[_currentIndex];
      }

      notifyListeners();
    });

    // 2. MediaItem updates
    _mediaItemSub = _audioHandler.mediaItem.listen((MediaItem? item) {
      if (item != null) {
        if (_currentTrack == null || _currentTrack!.id != item.id) {
          final foundTrack = _queue.firstWhere(
            (t) => t.id == item.id,
            orElse: () => _createTrackFromMediaItem(item),
          );
          _currentTrack = foundTrack;
          _repository.addToRecentlyPlayed(foundTrack);
          _recentlyPlayedRepository?.recordTrack(foundTrack);
        }
        if (item.duration != null && item.duration! > Duration.zero) {
          _duration = item.duration!;
        }
        notifyListeners();
      }
    });

    // 3. AudioService queue updates
    _queueSub = _audioHandler.queue.listen((List<MediaItem>? mediaItems) {
      if (mediaItems != null) {
        // Sync queue items while retaining full track data if present
        final updatedQueue = <Track>[];
        for (final item in mediaItems) {
          final existing = _queue.firstWhere(
            (t) => t.id == item.id,
            orElse: () => _createTrackFromMediaItem(item),
          );
          updatedQueue.add(existing);
        }
        _queue = updatedQueue;
        notifyListeners();
      }
    });

    // 4. Just_audio live high-precision streams
    _positionSub = _audioHandler.player.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    _durationSub = _audioHandler.player.durationStream.listen((dur) {
      if (dur != null && dur > Duration.zero) {
        _duration = dur;
        notifyListeners();
      }
    });

    _bufferedPositionSub = _audioHandler.player.bufferedPositionStream.listen((buf) {
      _bufferedPosition = buf;
      notifyListeners();
    });
  }

  Track _createTrackFromMediaItem(MediaItem item) {
    return Track(
      id: item.id,
      title: item.title,
      artist: item.artist ?? 'Audius Artist',
      genre: item.album ?? 'Music',
      artworkUrl480: item.artUri?.toString(),
      durationSeconds: item.duration?.inSeconds ?? 0,
    );
  }

  // --- PLAYBACK ACTIONS ---

  /// Plays a track, optionally setting up a surrounding playlist queue.
  /// If [playlist] is null or [startSmartRadio] is true, uses the Instagram/YouTube Music algorithm
  /// to generate a dynamic, non-duplicate, genre/artist related radio queue.
  Future<void> playTrack(
    Track track, {
    List<Track>? playlist,
    int? initialIndex,
    bool startSmartRadio = false,
  }) async {
    try {
      _isBuffering = true;
      _errorMessage = null;
      _currentTrack = track;
      notifyListeners();

      final bool isExplicitPlaylist = playlist != null && playlist.isNotEmpty && !startSmartRadio;

      if (isExplicitPlaylist) {
        _queue = List.from(playlist);
        _radioSeedArtist = null;
      } else {
        _queue = [track];
        _radioSeedArtist = track.artist;
      }

      if (initialIndex != null && initialIndex >= 0 && initialIndex < _queue.length) {
        _currentIndex = initialIndex;
      } else {
        _currentIndex = _queue.indexWhere((t) => t.id == track.id);
        if (_currentIndex < 0) {
          _queue.insert(0, track);
          _currentIndex = 0;
        }
      }

      // Resolve stream URL for current track immediately
      final streamUrl = await _repository.resolveTrackStreamUrl(track);

      // Convert full queue to MediaItems
      final mediaItems = _queue.map((t) {
        final isCurrent = t.id == track.id;
        return t.toMediaItem(
          resolvedStreamUrl: isCurrent ? streamUrl : null,
        );
      }).toList();

      await _audioHandler.setQueueAndPlay(mediaItems, _currentIndex);
      await _repository.addToRecentlyPlayed(track);
      _recentlyPlayedRepository?.recordTrack(track);

      // If smart radio mode, populate related diverse tracks in the background
      if (!isExplicitPlaylist) {
        unawaited(_populateSmartRadio(track));
      }
    } catch (e) {
      _isBuffering = false;
      _errorMessage = 'Could not play track: $e';
      notifyListeners();
    }
  }

  /// Explicitly plays a track and generates a smart, dynamic radio queue of related artists & genres.
  Future<void> playWithSmartRadio(Track track) async {
    await playTrack(track, startSmartRadio: true);
  }

  /// Manually triggers reshuffling / refreshing the radio recommendations.
  Future<void> refreshSmartRadio() async {
    if (_currentTrack == null) return;
    await _populateSmartRadio(_currentTrack!, replaceUpcoming: true);
  }

  Future<void> _populateSmartRadio(
    Track seedTrack, {
    bool appendOnly = false,
    bool replaceUpcoming = false,
  }) async {
    if (_isGeneratingRadio) return;
    _isGeneratingRadio = true;
    notifyListeners();

    try {
      final existingIds = _queue.map((t) => t.id).toSet();
      final radioTracks = await _algorithmService.generateRadioQueue(
        seedTrack,
        targetCount: 14,
        excludedTrackIds: existingIds,
      );

      if (radioTracks.isNotEmpty && _currentTrack?.id == seedTrack.id) {
        if (replaceUpcoming && _currentIndex >= 0 && _currentIndex < _queue.length) {
          // Keep history up to current track, replace upcoming
          _queue = _queue.sublist(0, _currentIndex + 1);
          _queue.addAll(radioTracks);
          final mediaItems = _queue.map((t) => t.toMediaItem()).toList();
          await _audioHandler.updateQueue(mediaItems);
        } else {
          _queue.addAll(radioTracks);
          final mediaItems = radioTracks.map((t) => t.toMediaItem()).toList();
          await _audioHandler.addQueueItems(mediaItems);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AudioPlayerProvider] _populateSmartRadio error: $e');
    } finally {
      _isGeneratingRadio = false;
      notifyListeners();
    }
  }

  /// Toggles between play and pause.
  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await _audioHandler.pause();
    } else {
      await _audioHandler.play();
    }
  }

  Future<void> play() => _audioHandler.play();
  Future<void> pause() => _audioHandler.pause();

  /// Seeks to a specific timestamp in the current track.
  Future<void> seek(Duration targetPosition) async {
    await _audioHandler.seek(targetPosition);
  }

  /// Skips to the next track in the queue.
  Future<void> next() async {
    if (_queue.isEmpty) return;
    final nextIdx = (_currentIndex + 1) % _queue.length;
    await skipToQueueIndex(nextIdx);
  }

  /// Skips to the previous track or restarts the song if played > 3s.
  Future<void> previous() async {
    if (_queue.isEmpty) return;
    if (_position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    final prevIdx = (_currentIndex - 1 + _queue.length) % _queue.length;
    await skipToQueueIndex(prevIdx);
  }

  /// Stops audio playback and resets active track.
  Future<void> stop() async {
    await _audioHandler.stop();
    _currentTrack = null;
    _currentIndex = -1;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // --- QUEUE ACTIONS ---

  /// Adds a single track to the end of the current queue.
  Future<void> addToQueue(Track track) async {
    _queue.add(track);
    notifyListeners();

    final streamUrl = await _repository.resolveTrackStreamUrl(track);
    final mediaItem = track.toMediaItem(resolvedStreamUrl: streamUrl);
    await _audioHandler.addQueueItem(mediaItem);
  }

  /// Adds an entire list of tracks to the queue.
  Future<void> addPlaylistToQueue(List<Track> tracks) async {
    if (tracks.isEmpty) return;
    _queue.addAll(tracks);
    notifyListeners();

    final mediaItems = tracks.map((t) => t.toMediaItem()).toList();
    await _audioHandler.addQueueItems(mediaItems);
  }

  /// Inserts a track directly after the currently playing song so it plays next.
  Future<void> playNext(Track track) async {
    final insertIndex = (_currentIndex >= 0 && _currentIndex < _queue.length)
        ? _currentIndex + 1
        : _queue.length;

    _queue.insert(insertIndex, track);
    notifyListeners();

    final streamUrl = await _repository.resolveTrackStreamUrl(track);
    final mediaItem = track.toMediaItem(resolvedStreamUrl: streamUrl);
    await _audioHandler.insertQueueItem(insertIndex, mediaItem);
  }

  /// Removes track at [index] from the queue.
  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _queue.length) return;

    _queue.removeAt(index);
    if (index < _currentIndex) {
      _currentIndex--;
    }
    notifyListeners();

    await _audioHandler.removeQueueItemAt(index);
  }

  /// Clears upcoming queue tracks or the entire queue if nothing is active.
  Future<void> clearQueue() async {
    if (_currentIndex >= 0 && _currentIndex < _queue.length) {
      final current = _queue[_currentIndex];
      _queue = [current];
      _currentIndex = 0;
      notifyListeners();
      await _audioHandler.clearUpcomingQueue();
    } else {
      _queue.clear();
      _currentIndex = -1;
      notifyListeners();
      await _audioHandler.clearAllQueue();
    }
  }

  /// Reorders items in the queue (e.g. from Drag & Drop in UI).
  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (newIndex < 0 || newIndex > _queue.length) return;

    final currentItem = _currentIndex >= 0 && _currentIndex < _queue.length
        ? _queue[_currentIndex]
        : null;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final item = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, item);

    if (currentItem != null) {
      _currentIndex = _queue.indexOf(currentItem);
    }
    notifyListeners();

    await _audioHandler.reorderQueue(oldIndex, newIndex);
  }

  /// Skips directly to a specific track in the queue by [index].
  Future<void> skipToQueueIndex(int index) async {
    if (index < 0 || index >= _queue.length) return;

    final track = _queue[index];
    _currentIndex = index;
    _currentTrack = track;
    _isBuffering = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final streamUrl = await _repository.resolveTrackStreamUrl(track);
      final mediaItem = track.toMediaItem(resolvedStreamUrl: streamUrl);

      // Update current mediaItem in queue
      final updatedMediaQueue = List<MediaItem>.from(_audioHandler.playlist);
      if (index < updatedMediaQueue.length) {
        updatedMediaQueue[index] = mediaItem;
      }
      await _audioHandler.setQueueAndPlay(updatedMediaQueue, index);
      await _repository.addToRecentlyPlayed(track);
      _recentlyPlayedRepository?.recordTrack(track);
    } catch (e) {
      _isBuffering = false;
      _errorMessage = 'Failed to skip to track: $e';
      notifyListeners();
    }
  }

  // --- SLEEP TIMER ---

  /// Sets a countdown sleep timer for [duration].
  /// When the timer expires, playback is cleanly paused.
  void setSleepTimer(Duration duration) {
    cancelSleepTimer();
    _sleepTimerRemaining = duration;
    notifyListeners();

    _sleepCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_sleepTimerRemaining != null && _sleepTimerRemaining!.inSeconds > 0) {
        _sleepTimerRemaining = Duration(seconds: _sleepTimerRemaining!.inSeconds - 1);
        notifyListeners();
      } else {
        timer.cancel();
      }
    });

    _sleepTimer = Timer(duration, () async {
      await pause();
      cancelSleepTimer();
    });
  }

  /// Cancels any currently running sleep timer and resets countdown state.
  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepCountdownTimer?.cancel();
    _sleepCountdownTimer = null;
    _sleepTimerRemaining = null;
    notifyListeners();
  }

  // --- SHUFFLE & REPEAT ---

  /// Toggles shuffle mode with smart deduplication and queue preservation.
  /// When enabled: keeps the active track playing and randomizes upcoming tracks
  /// so the current track is not immediately repeated.
  /// When disabled: restores the original un-shuffled track sequence.
  Future<void> toggleShuffle() async {
    final willEnable = !_isShuffle;
    if (willEnable) {
      _unshuffledQueue = List<Track>.from(_queue);
      if (_queue.length > 1 && _currentIndex >= 0 && _currentIndex < _queue.length) {
        final current = _queue[_currentIndex];
        final upcoming = List<Track>.from(_queue)..removeAt(_currentIndex);
        upcoming.shuffle();
        _queue = [current, ...upcoming];
        _currentIndex = 0;
      } else {
        _queue.shuffle();
      }
      final mediaItems = _queue.map((t) => t.toMediaItem()).toList();
      await _audioHandler.updateQueue(mediaItems);
      await _audioHandler.setShuffleMode(AudioServiceShuffleMode.all);
    } else {
      if (_unshuffledQueue.isNotEmpty) {
        final current = (_currentIndex >= 0 && _currentIndex < _queue.length)
            ? _queue[_currentIndex]
            : null;
        _queue = List<Track>.from(_unshuffledQueue);
        if (current != null) {
          final foundIdx = _queue.indexWhere((t) => t.id == current.id);
          _currentIndex = foundIdx >= 0 ? foundIdx : 0;
        }
        final mediaItems = _queue.map((t) => t.toMediaItem()).toList();
        await _audioHandler.updateQueue(mediaItems);
      }
      await _audioHandler.setShuffleMode(AudioServiceShuffleMode.none);
    }
    notifyListeners();
  }

  /// Cycles repeat mode: none (repeat off) -> one (repeat current song) -> all (repeat queue) -> none.
  Future<void> toggleRepeat() async {
    AudioServiceRepeatMode nextMode;
    switch (_repeatMode) {
      case AudioServiceRepeatMode.none:
        nextMode = AudioServiceRepeatMode.one;
        break;
      case AudioServiceRepeatMode.one:
        nextMode = AudioServiceRepeatMode.all;
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        nextMode = AudioServiceRepeatMode.none;
        break;
    }
    await _audioHandler.setRepeatMode(nextMode);
  }

  @override
  void dispose() {
    cancelSleepTimer();
    _playbackStateSub?.cancel();
    _mediaItemSub?.cancel();
    _queueSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _bufferedPositionSub?.cancel();
    super.dispose();
  }
}
