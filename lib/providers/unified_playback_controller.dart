import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/track.dart';
import '../repositories/recently_played_repository.dart';
import '../repositories/track_repository.dart';
import '../services/music_algorithm_service.dart';
import '../services/music_discovery_service.dart';
import '../services/playback/playback_backend.dart';
import '../services/playback/youtube_iframe_backend.dart';
import '../services/youtube/youtube_player_service.dart';

/// Single source of truth for playback in GoTune.
/// Coordinates playback through the official embedded YouTube IFrame Player.
class UnifiedPlaybackController extends ChangeNotifier {
  final TrackRepository _repository;
  final RecentlyPlayedRepository? _recentlyPlayedRepository;
  late final MusicDiscoveryService _discoveryService;
  late final MusicAlgorithmService _algorithmService;
  final YouTubeIframeBackend _youtubeBackend;
  final YouTubePlayerService _youtubePlayerService;

  // --- Queue ---
  final List<Track> _queue = [];
  int _currentIndex = -1;
  List<Track> _unshuffledQueue = [];
  bool _isShuffle = false;
  PlaybackRepeatMode _repeatMode = PlaybackRepeatMode.none;

  // --- Playback state ---
  UnifiedPlaybackState _state = const UnifiedPlaybackState.initial();
  Track? _currentTrack;

  // High-frequency scrubbers
  final ValueNotifier<Duration> positionNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> bufferedNotifier = ValueNotifier(Duration.zero);

  // --- Radio ---
  bool _isGeneratingRadio = false;
  bool _autoPlayRadio = true;
  String? _radioSeedArtist;

  void toggleAutoPlayRadio() {
    _autoPlayRadio = !_autoPlayRadio;
    notifyListeners();
  }

  Future<void> refreshSmartRadio() async {
    if (_currentTrack != null) {
      await startSongRadio(_currentTrack!);
    }
  }

  // --- Sleep timer ---
  Timer? _sleepTimer;
  Timer? _sleepCountdownTimer;
  Duration? _sleepTimerRemaining;

  // --- Subscriptions ---
  StreamSubscription<PlaybackBackendEvent>? _youtubeEvents;
  Timer? _positionTicker;

  UnifiedPlaybackController({
    required TrackRepository repository,
    required YouTubePlayerService youtubePlayerService,
    YouTubeIframeBackend? youtubeBackend,
    RecentlyPlayedRepository? recentlyPlayedRepository,
    MusicAlgorithmService? algorithmService,
    MusicDiscoveryService? discoveryService,
    dynamic audioHandler,
    dynamic directBackend,
    dynamic audioSourceResolver,
  })  : _repository = repository,
        _youtubePlayerService = youtubePlayerService,
        _youtubeBackend = youtubeBackend ?? YouTubeIframeBackend(service: youtubePlayerService),
        _recentlyPlayedRepository = recentlyPlayedRepository {
    _algorithmService = algorithmService ?? MusicAlgorithmService(repository: repository);
    _discoveryService = discoveryService ??
        MusicDiscoveryService(
          aggregator: repository.catalogAggregator,
          algorithmService: _algorithmService,
          storageService: repository.storageService,
          cache: repository.cacheService,
        );

    _bindBackend();
  }

  // ==========================================
  // PUBLIC STATE
  // ==========================================

  UnifiedPlaybackState get state => _state;
  Track? get currentTrack => _currentTrack;
  List<Track> get queue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  bool get hasActiveTrack => _currentTrack != null;

  bool get isPlaying => _state.isPlaying;
  PlaybackProcessingState get processingState => _state.processingState;
  bool get isBuffering => _state.isBuffering;
  bool get isPaused => !_state.isPlaying && !_state.isBuffering && hasActiveTrack;
  bool get hasError => _state.hasError;
  String? get errorMessage => _state.errorMessage;

  Duration get position => _state.position;
  Duration get duration => _state.duration;
  Duration get bufferedPosition => _state.bufferedPosition;

  bool get isYouTubeIframePlayback => true;
  String? get currentYoutubeVideoId => _youtubeBackend.videoId;

  bool get isAutoplayBlocked =>
      _youtubeBackend.autoplayBlocked || _youtubePlayerService.autoplayBlocked;
  bool get youtubeAutoplayBlocked => isAutoplayBlocked;

  Future<void> retryYouTubeAutoplay() async {
    await _youtubeBackend.retryPlayback();
  }

  bool get activeBackendRequiresForegroundView => true;
  int? get youtubeErrorCode => _youtubePlayerService.lastErrorCode;

  bool get isShuffle => _isShuffle;
  PlaybackRepeatMode get repeatMode => _repeatMode;

  bool get isGeneratingRadio => _isGeneratingRadio;
  bool get autoPlayRadio => _autoPlayRadio;
  String? get radioSeedArtist => _radioSeedArtist;

  bool get isSleepTimerActive => _sleepTimer != null && _sleepTimer!.isActive;
  Duration? get sleepTimerRemaining => _sleepTimerRemaining;

  String get formattedSleepTimerRemaining {
    final totalSeconds = _sleepTimerRemaining?.inSeconds ?? 0;
    if (totalSeconds <= 0) return '00:00';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  MusicDiscoveryService get discoveryService => _discoveryService;
  YouTubeIframeBackend get youtubeBackend => _youtubeBackend;
  YouTubePlayerService get youtubePlayerService => _youtubePlayerService;

  // ==========================================
  // WIRING
  // ==========================================

  void _bindBackend() {
    _youtubeEvents = _youtubeBackend.events.listen(_onYouTubeEvent);
  }

  void _onYouTubeEvent(PlaybackBackendEvent event) {
    switch (event.type) {
      case PlaybackBackendEventType.ready:
        _state = _state.copyWith(
          processingState: PlaybackProcessingState.ready,
          clearError: true,
        );
        break;
      case PlaybackBackendEventType.buffering:
        _state = _state.copyWith(
          processingState: PlaybackProcessingState.buffering,
        );
        break;
      case PlaybackBackendEventType.playing:
        _state = _state.copyWith(
          isPlaying: true,
          processingState: PlaybackProcessingState.ready,
          clearError: true,
        );
        _startPositionTicker();
        break;
      case PlaybackBackendEventType.paused:
        _state = _state.copyWith(
          isPlaying: false,
          processingState: PlaybackProcessingState.ready,
        );
        _stopPositionTicker();
        break;
      case PlaybackBackendEventType.completed:
        _state = _state.copyWith(
          isPlaying: false,
          processingState: PlaybackProcessingState.completed,
        );
        _stopPositionTicker();
        _onTrackCompleted();
        break;
      case PlaybackBackendEventType.autoplayBlocked:
        _state = _state.copyWith(
          isPlaying: false,
          processingState: PlaybackProcessingState.ready,
        );
        _stopPositionTicker();
        break;
      case PlaybackBackendEventType.error:
        _state = _state.copyWith(
          isPlaying: false,
          processingState: PlaybackProcessingState.error,
          errorMessage: event.message ?? 'Unable to play this YouTube video.',
        );
        _stopPositionTicker();
        break;
    }
    notifyListeners();
  }

  // ==========================================
  // PLAYBACK CONTROL
  // ==========================================

  Future<void> playTrack(
    Track track, {
    List<Track>? playlist,
    int? initialIndex,
    bool isExplicitYoutubeSelection = false,
  }) async {
    if (playlist != null && playlist.isNotEmpty) {
      await addPlaylistToQueue(
        playlist,
        startIndex: initialIndex ?? playlist.indexWhere((t) => t.id == track.id),
      );
      return;
    }

    final existingIndex = _queue.indexWhere((t) => t.id == track.id);
    if (existingIndex != -1) {
      await skipToQueueIndex(existingIndex);
      return;
    }

    _queue.insert(0, track);
    _currentIndex = 0;
    _unshuffledQueue = List.from(_queue);

    await _loadAndPlayCurrent();
    notifyListeners();
  }

  Future<void> loadTrack(Track track) async {
    _currentTrack = track;
    _state = _state.copyWith(
      currentTrack: track,
      processingState: PlaybackProcessingState.loading,
      clearError: true,
    );
    notifyListeners();

    try {
      await _youtubeBackend.load(track, autoplay: false);
    } catch (e) {
      _state = _state.copyWith(
        processingState: PlaybackProcessingState.error,
        errorMessage: 'Unable to load video: $e',
      );
      notifyListeners();
    }
  }

  Future<void> _loadAndPlayCurrent() async {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return;
    final track = _queue[_currentIndex];
    _currentTrack = track;

    _state = _state.copyWith(
      currentTrack: track,
      position: Duration.zero,
      duration: track.duration ?? Duration(seconds: track.durationSeconds),
      processingState: PlaybackProcessingState.loading,
      clearError: true,
    );
    positionNotifier.value = Duration.zero;
    notifyListeners();

    // Record listening history & interaction stats
    _recentlyPlayedRepository?.recordTrack(track);

    try {
      await _youtubeBackend.load(track, autoplay: true);
    } catch (e) {
      _state = _state.copyWith(
        processingState: PlaybackProcessingState.error,
        errorMessage: 'Failed to play YouTube track: $e',
      );
      notifyListeners();
    }
  }

  Future<void> play() async {
    if (_currentTrack == null && _queue.isNotEmpty) {
      _currentIndex = 0;
      await _loadAndPlayCurrent();
      return;
    }
    await _youtubeBackend.play();
  }

  Future<void> pause() async {
    await _youtubeBackend.pause();
  }

  Future<void> togglePlayPause() async {
    if (isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seekTo(Duration position) async {
    positionNotifier.value = position;
    _state = _state.copyWith(position: position);
    await _youtubeBackend.seek(position);
  }

  Future<void> stop() async {
    _stopPositionTicker();
    await _youtubeBackend.stop();
    _state = const UnifiedPlaybackState.initial();
    positionNotifier.value = Duration.zero;
    notifyListeners();
  }

  // ==========================================
  // QUEUE MANAGEMENT
  // ==========================================

  Future<void> skipToNext() async {
    if (_queue.isEmpty) return;

    if (_repeatMode == PlaybackRepeatMode.one) {
      await seekTo(Duration.zero);
      await play();
      return;
    }

    int nextIndex = _currentIndex + 1;
    if (nextIndex >= _queue.length) {
      if (_repeatMode == PlaybackRepeatMode.all) {
        nextIndex = 0;
      } else {
        if (_autoPlayRadio && _currentTrack != null) {
          await _populateSmartRadio(_currentTrack!);
          if (_currentIndex + 1 < _queue.length) {
            nextIndex = _currentIndex + 1;
          } else {
            return;
          }
        } else {
          return;
        }
      }
    }

    await skipToQueueIndex(nextIndex);
  }

  Future<void> next() => skipToNext();
  Future<void> previous() => skipToPrevious();
  void toggleRepeat() => toggleRepeatMode();
  Future<void> seek(Duration pos) => seekTo(pos);

  Future<void> skipToPrevious() async {
    if (_queue.isEmpty) return;

    if (position.inSeconds > 3) {
      await seekTo(Duration.zero);
      return;
    }

    int prevIndex = _currentIndex - 1;
    if (prevIndex < 0) {
      if (_repeatMode == PlaybackRepeatMode.all) {
        prevIndex = _queue.length - 1;
      } else {
        prevIndex = 0;
      }
    }

    await skipToQueueIndex(prevIndex);
  }

  Future<void> skipToQueueIndex(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    await _loadAndPlayCurrent();
  }

  void addToQueue(Track track) {
    if (_queue.any((t) => t.id == track.id)) return;
    _queue.add(track);
    _unshuffledQueue.add(track);
    if (_currentTrack == null) {
      _currentIndex = 0;
      _currentTrack = track;
    }
    notifyListeners();
  }

  void playNext(Track track) {
    if (_queue.isEmpty) {
      playTrack(track);
      return;
    }
    _queue.removeWhere((t) => t.id == track.id);
    _unshuffledQueue.removeWhere((t) => t.id == track.id);
    _queue.insert(_currentIndex + 1, track);
    _unshuffledQueue.insert(_currentIndex + 1, track);
    notifyListeners();
  }

  Future<void> addPlaylistToQueue(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    _queue.clear();
    _queue.addAll(tracks);
    _unshuffledQueue = List.from(_queue);
    _currentIndex = startIndex.clamp(0, _queue.length - 1);
    await _loadAndPlayCurrent();
    notifyListeners();
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length) return;
    final removingCurrent = index == _currentIndex;
    final track = _queue.removeAt(index);
    _unshuffledQueue.remove(track);

    if (removingCurrent) {
      if (_queue.isEmpty) {
        stop();
      } else {
        _currentIndex = _currentIndex.clamp(0, _queue.length - 1);
        _loadAndPlayCurrent();
      }
    } else if (index < _currentIndex) {
      _currentIndex--;
    }
    notifyListeners();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (newIndex < 0 || newIndex > _queue.length) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, item);

    if (_currentIndex == oldIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex++;
    }

    notifyListeners();
  }

  void clearQueue() {
    _queue.clear();
    _unshuffledQueue.clear();
    _currentIndex = -1;
    stop();
    notifyListeners();
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    if (_isShuffle) {
      if (_queue.isNotEmpty) {
        final current = _currentTrack;
        final others = _queue.where((t) => t.id != current?.id).toList();
        others.shuffle(Random());
        _queue.clear();
        if (current != null) _queue.add(current);
        _queue.addAll(others);
        _currentIndex = current != null ? 0 : -1;
      }
    } else {
      if (_unshuffledQueue.isNotEmpty) {
        final current = _currentTrack;
        _queue.clear();
        _queue.addAll(_unshuffledQueue);
        _currentIndex = current != null ? _queue.indexWhere((t) => t.id == current.id) : -1;
      }
    }
    notifyListeners();
  }

  void toggleRepeatMode() {
    _repeatMode = switch (_repeatMode) {
      PlaybackRepeatMode.none => PlaybackRepeatMode.all,
      PlaybackRepeatMode.all => PlaybackRepeatMode.one,
      PlaybackRepeatMode.one => PlaybackRepeatMode.none,
    };
    notifyListeners();
  }

  void _onTrackCompleted() {
    skipToNext();
  }

  // ==========================================
  // SMART RADIO (AUTOPLAY)
  // ==========================================

  Future<void> startSongRadio(Track seed) async {
    _isGeneratingRadio = true;
    _radioSeedArtist = seed.artist;
    notifyListeners();

    try {
      final related = await _repository.getRelatedTracks(seed, limit: 15);
      final ranked = await _algorithmService.rankCandidates(
        candidates: related,
        seed: seed,
        limit: 12,
      );

      _queue.clear();
      _queue.add(seed);
      _queue.addAll(ranked);
      _unshuffledQueue = List.from(_queue);
      _currentIndex = 0;
      await _loadAndPlayCurrent();
    } catch (e) {
      debugPrint('[UnifiedPlaybackController] startSongRadio error: $e');
    } finally {
      _isGeneratingRadio = false;
      notifyListeners();
    }
  }

  Future<void> startArtistRadio(String artist, {Track? seedTrack}) async {
    _isGeneratingRadio = true;
    _radioSeedArtist = artist;
    notifyListeners();

    try {
      var tracks = await _repository.getArtistTracks(artist, limit: 15);
      if (seedTrack != null) {
        tracks = [seedTrack, ...tracks.where((t) => t.id != seedTrack.id)];
      }
      if (tracks.isNotEmpty) {
        _queue.clear();
        _queue.addAll(tracks);
        _unshuffledQueue = List.from(_queue);
        _currentIndex = 0;
        await _loadAndPlayCurrent();
      }
    } catch (e) {
      debugPrint('[UnifiedPlaybackController] startArtistRadio error: $e');
    } finally {
      _isGeneratingRadio = false;
      notifyListeners();
    }
  }

  Future<void> startGenreRadio(String genre) async {
    _isGeneratingRadio = true;
    notifyListeners();

    try {
      final tracks = await _repository.getTrendingTracks(genre: genre, limit: 20);
      if (tracks.isNotEmpty) {
        _queue.clear();
        _queue.addAll(tracks);
        _unshuffledQueue = List.from(_queue);
        _currentIndex = 0;
        await _loadAndPlayCurrent();
      }
    } catch (e) {
      debugPrint('[UnifiedPlaybackController] startGenreRadio error: $e');
    } finally {
      _isGeneratingRadio = false;
      notifyListeners();
    }
  }

  Future<void> playWithSmartRadio(
    Track seed, {
    bool isExplicitYoutubeSelection = false,
  }) => startSongRadio(seed);

  Future<void> _populateSmartRadio(Track seed) async {
    try {
      final related = await _repository.getRelatedTracks(seed, limit: 10);
      final existingIds = _queue.map((t) => t.id).toSet();
      final newTracks = related.where((t) => !existingIds.contains(t.id)).toList();
      _queue.addAll(newTracks);
      _unshuffledQueue.addAll(newTracks);
      notifyListeners();
    } catch (e) {
      debugPrint('[UnifiedPlaybackController] _populateSmartRadio error: $e');
    }
  }

  // ==========================================
  // POSITION POLLING (YouTube IFrame API)
  // ==========================================

  void _startPositionTicker() {
    _positionTicker?.cancel();
    _positionTicker = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (!_state.isPlaying) return;

      final pos = await _youtubePlayerService.getCurrentTime();
      final dur = await _youtubePlayerService.getDuration();
      positionNotifier.value = pos;
      _state = _state.copyWith(
        position: pos,
        duration: dur > Duration.zero ? dur : _state.duration,
      );
    });
  }

  void _stopPositionTicker() {
    _positionTicker?.cancel();
    _positionTicker = null;
  }

  // ==========================================
  // SLEEP TIMER
  // ==========================================

  void setSleepTimer(Duration duration) {
    cancelSleepTimer();
    _sleepTimerRemaining = duration;
    notifyListeners();

    _sleepCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = _sleepTimerRemaining;
      if (remaining != null && remaining.inSeconds > 0) {
        _sleepTimerRemaining = Duration(seconds: remaining.inSeconds - 1);
        notifyListeners();
      } else {
        timer.cancel();
      }
    });

    _sleepTimer = Timer(duration, () {
      pause();
      cancelSleepTimer();
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepCountdownTimer?.cancel();
    _sleepTimer = null;
    _sleepCountdownTimer = null;
    _sleepTimerRemaining = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _youtubeEvents?.cancel();
    _positionTicker?.cancel();
    _sleepTimer?.cancel();
    _sleepCountdownTimer?.cancel();
    positionNotifier.dispose();
    bufferedNotifier.dispose();
    super.dispose();
  }
}

/// Type aliases so callers can use either name.
typedef PlaybackProvider = UnifiedPlaybackController;
typedef YouTubePlayerProvider = UnifiedPlaybackController;