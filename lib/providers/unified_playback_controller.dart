import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/playback_type.dart';
import '../models/track.dart';
import '../repositories/recently_played_repository.dart';
import '../repositories/track_repository.dart';
import '../services/audio_handler.dart';
import '../services/music_algorithm_service.dart';
import '../services/music_discovery_service.dart';
import '../services/playback/direct_audio_backend.dart';
import '../services/playback/playback_backend.dart';
import '../services/playback/youtube_iframe_backend.dart';
import '../services/saavn_api_service.dart';
import '../services/youtube/youtube_player_service.dart';

/// Single source of truth for playback in GoTune.
/// Dual-Engine architecture:
/// 1. DirectAudioBackend (via just_audio & audio_service):
///    320kbps streams, 100% playable songs, lockscreen controls, and true background play.
/// 2. YouTubeIframeBackend (via WebView official YT IFrame Player API):
///    Embedded YouTube video when user selects "Video" mode.
class UnifiedPlaybackController extends ChangeNotifier {
  final TrackRepository _repository;
  final RecentlyPlayedRepository? _recentlyPlayedRepository;
  late final MusicDiscoveryService _discoveryService;
  late final MusicAlgorithmService _algorithmService;
  final YouTubeIframeBackend _youtubeBackend;
  final YouTubePlayerService _youtubePlayerService;
  final DirectAudioBackend _directBackend;
  final GoTuneAudioHandler _audioHandler;
  final SaavnApiService _saavnService;

  // --- Queue ---
  final List<Track> _queue = [];
  int _currentIndex = -1;
  List<Track> _unshuffledQueue = [];
  bool _isShuffle = false;
  PlaybackRepeatMode _repeatMode = PlaybackRepeatMode.none;

  // --- Playback state ---
  UnifiedPlaybackState _state = const UnifiedPlaybackState.initial();
  Track? _currentTrack;
  bool _isVideoMode = false;

  // High-frequency scrubbers
  final ValueNotifier<Duration> positionNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> bufferedNotifier = ValueNotifier(Duration.zero);

  // --- Radio ---
  bool _isGeneratingRadio = false;
  bool _autoPlayRadio = true;
  String? _radioSeedArtist;
  String _radioVariety = 'Medium';
  String _radioSongSelection = 'Discover';
  List<String> _radioFilters = ['Popular'];
  List<String> _tunedArtists = ['Lil Nas X', 'Doja Cat', 'Billie Eilish'];
  String? _activeRadioTitle;

  String get radioVariety => _radioVariety;
  String get radioSongSelection => _radioSongSelection;
  List<String> get radioFilters => List.unmodifiable(_radioFilters);
  List<String> get tunedArtists => List.unmodifiable(_tunedArtists);
  String? get activeRadioTitle => _activeRadioTitle;

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
  StreamSubscription<PlaybackBackendEvent>? _directEvents;
  StreamSubscription<Duration>? _playerPosSub;
  StreamSubscription<Duration?>? _playerDurSub;
  StreamSubscription<Duration>? _playerBufSub;
  Timer? _positionTicker;

  UnifiedPlaybackController({
    required TrackRepository repository,
    required YouTubePlayerService youtubePlayerService,
    YouTubeIframeBackend? youtubeBackend,
    DirectAudioBackend? directBackend,
    GoTuneAudioHandler? audioHandler,
    SaavnApiService? saavnService,
    RecentlyPlayedRepository? recentlyPlayedRepository,
    MusicAlgorithmService? algorithmService,
    MusicDiscoveryService? discoveryService,
    dynamic audioSourceResolver,
  })  : _repository = repository,
        _youtubePlayerService = youtubePlayerService,
        _youtubeBackend = youtubeBackend ?? YouTubeIframeBackend(service: youtubePlayerService),
        _audioHandler = audioHandler ?? GoTuneAudioHandler.instance,
        _directBackend = directBackend ?? DirectAudioBackend(audioHandler: audioHandler ?? GoTuneAudioHandler.instance),
        _saavnService = saavnService ?? SaavnApiService(),
        _recentlyPlayedRepository = recentlyPlayedRepository {
    _algorithmService = algorithmService ?? MusicAlgorithmService(repository: repository);
    _discoveryService = discoveryService ??
        MusicDiscoveryService(
          aggregator: repository.catalogAggregator,
          algorithmService: _algorithmService,
          storageService: repository.storageService,
          cache: repository.cacheService,
        );

    _bindBackends();
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

  bool get isVideoMode => _isVideoMode;
  bool get isYouTubeIframePlayback => _isVideoMode || _state.backendId == YouTubeIframeBackend.id;
  bool get supportsBackgroundPlayback => _state.backendId == DirectAudioBackend.id;
  String? get currentYoutubeVideoId => _youtubeBackend.videoId ?? _currentTrack?.resolvedYoutubeVideoId;

  bool get isAutoplayBlocked =>
      _youtubeBackend.autoplayBlocked || _youtubePlayerService.autoplayBlocked;
  bool get youtubeAutoplayBlocked => isAutoplayBlocked;

  Future<void> retryYouTubeAutoplay() async {
    await _youtubeBackend.retryPlayback();
  }

  bool get activeBackendRequiresForegroundView => _isVideoMode;
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
  DirectAudioBackend get directBackend => _directBackend;
  GoTuneAudioHandler get audioHandler => _audioHandler;

  PlaybackBackend get _activeBackend =>
      (_state.backendId == DirectAudioBackend.id) ? _directBackend : _youtubeBackend;

  // ==========================================
  // WIRING
  // ==========================================

  void _bindBackends() {
    _youtubeEvents = _youtubeBackend.events.listen(_onYouTubeEvent);
    _directEvents = _directBackend.events.listen(_onDirectEvent);

    // Direct audio player high-frequency streams
    _playerPosSub = _audioHandler.player.positionStream.listen((pos) {
      if (!_isVideoMode && _state.backendId == DirectAudioBackend.id) {
        positionNotifier.value = pos;
        _state = _state.copyWith(position: pos);
      }
    });

    _playerDurSub = _audioHandler.player.durationStream.listen((dur) {
      if (!_isVideoMode && _state.backendId == DirectAudioBackend.id && dur != null) {
        _state = _state.copyWith(duration: dur);
      }
    });

    _playerBufSub = _audioHandler.player.bufferedPositionStream.listen((buf) {
      if (!_isVideoMode && _state.backendId == DirectAudioBackend.id) {
        bufferedNotifier.value = buf;
        _state = _state.copyWith(bufferedPosition: buf);
      }
    });

    // Auto-fetch more songs when queue nears end
    _audioHandler.onQueueNearEnd = () {
      if (_autoPlayRadio && _currentTrack != null) {
        _populateSmartRadio(_currentTrack!);
      }
    };
  }

  void _onDirectEvent(PlaybackBackendEvent event) {
    if (_isVideoMode) return;
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
          backendId: DirectAudioBackend.id,
          clearError: true,
        );
        break;
      case PlaybackBackendEventType.paused:
        _state = _state.copyWith(
          isPlaying: false,
          processingState: PlaybackProcessingState.ready,
        );
        break;
      case PlaybackBackendEventType.completed:
        _state = _state.copyWith(
          isPlaying: false,
          processingState: PlaybackProcessingState.completed,
        );
        _onTrackCompleted();
        break;
      case PlaybackBackendEventType.error:
        _state = _state.copyWith(
          isPlaying: false,
          processingState: PlaybackProcessingState.error,
          errorMessage: event.message ?? 'Direct audio playback error.',
        );
        break;
      default:
        break;
    }
    notifyListeners();
  }

  void _onYouTubeEvent(PlaybackBackendEvent event) {
    if (!_isVideoMode && _state.backendId == DirectAudioBackend.id) return;

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
          backendId: YouTubeIframeBackend.id,
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
        debugPrint('[UnifiedPlaybackController] YouTube error (${event.errorCode}): ${event.message}');
        // If YouTube throws Error 150/101 (embed blocked by record label), automatically fallback to Direct Audio!
        if (_currentTrack != null) {
          _fallbackToDirectAudio(_currentTrack!);
        } else {
          _state = _state.copyWith(
            isPlaying: false,
            processingState: PlaybackProcessingState.error,
            errorMessage: event.message ?? 'Unable to play this YouTube video.',
          );
          _stopPositionTicker();
          notifyListeners();
        }
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

    var trackToPlay = track;

    // 1. Direct stream available: play immediately via DirectAudioBackend (instant start)
    if (!_isVideoMode && trackToPlay.streamUrl != null && trackToPlay.streamUrl!.isNotEmpty) {
      await _youtubeBackend.stop();
      _stopPositionTicker();
      _state = _state.copyWith(backendId: DirectAudioBackend.id);
      try {
        await _directBackend.load(trackToPlay);
        await _directBackend.play();
        return;
      } catch (e) {
        debugPrint('[UnifiedPlaybackController] Direct audio load error: $e, falling back to YouTube');
      }
    }

    // 2. YouTube-backed track: stream immediately via YouTube IFrame (instant start for curated tracks)
    if (_isVideoMode || (trackToPlay.resolvedYoutubeVideoId != null && trackToPlay.resolvedYoutubeVideoId!.isNotEmpty)) {
      await _directBackend.stop();
      _state = _state.copyWith(backendId: YouTubeIframeBackend.id);
      try {
        await _youtubeBackend.load(trackToPlay, autoplay: true);
        return;
      } catch (e) {
        debugPrint('[UnifiedPlaybackController] YouTube playback error: $e, falling back to direct resolution');
      }
    }

    // 3. Unresolved track: attempt fast direct audio stream resolution
    if (!_isVideoMode && (trackToPlay.streamUrl == null || trackToPlay.streamUrl!.isEmpty)) {
      try {
        final resolved = await _saavnService
            .resolveTrackStream(trackToPlay.title, trackToPlay.artist)
            .timeout(const Duration(milliseconds: 1500), onTimeout: () => null);
        if (resolved != null && resolved.streamUrl != null && resolved.streamUrl!.isNotEmpty) {
          trackToPlay = trackToPlay.copyWith(
            streamUrl: resolved.streamUrl,
            sourceType: PlaybackType.directStream,
            thumbnailUrl: (trackToPlay.thumbnailUrl == null || trackToPlay.thumbnailUrl!.isEmpty)
                ? resolved.thumbnailUrl
                : trackToPlay.thumbnailUrl,
          );
          _queue[_currentIndex] = trackToPlay;
          _currentTrack = trackToPlay;

          await _youtubeBackend.stop();
          _stopPositionTicker();
          _state = _state.copyWith(backendId: DirectAudioBackend.id);
          try {
            await _directBackend.load(trackToPlay);
            await _directBackend.play();
            return;
          } catch (e) {
            debugPrint('[UnifiedPlaybackController] Direct audio load error: $e');
          }
        }
      } catch (e) {
        debugPrint('[UnifiedPlaybackController] Saavn resolution error: $e');
      }
    }

    // 4. Resolve YouTube Video ID with timeout
    if (trackToPlay.resolvedYoutubeVideoId == null || trackToPlay.resolvedYoutubeVideoId!.isEmpty) {
      try {
        final query = '${trackToPlay.title} ${trackToPlay.artist}'.trim();
        final searchResults = await _repository
            .searchTracks(query, limit: 1)
            .timeout(const Duration(milliseconds: 2000), onTimeout: () => []);
        if (searchResults.isNotEmpty && searchResults.first.resolvedYoutubeVideoId != null) {
          trackToPlay = trackToPlay.copyWith(
            youtubeVideoId: searchResults.first.resolvedYoutubeVideoId,
          );
          _queue[_currentIndex] = trackToPlay;
          _currentTrack = trackToPlay;
        }
      } catch (e) {
        debugPrint('[UnifiedPlaybackController] Failed to resolve YouTube ID for track: $e');
      }
    }

    // 5. Final attempt via YouTube backend
    await _directBackend.stop();
    _state = _state.copyWith(backendId: YouTubeIframeBackend.id);
    try {
      await _youtubeBackend.load(trackToPlay, autoplay: true);
    } catch (e) {
      debugPrint('[UnifiedPlaybackController] YouTube playback error: $e');
      _state = _state.copyWith(
        processingState: PlaybackProcessingState.error,
        errorMessage: 'Unable to stream this track: $e',
      );
      notifyListeners();
    }
  }

  Future<void> _fallbackToDirectAudio(Track track) async {
    try {
      _isVideoMode = false;
      _stopPositionTicker();
      await _youtubeBackend.stop();

      var trackToPlay = track;
      if (trackToPlay.streamUrl == null || trackToPlay.streamUrl!.isEmpty) {
        final resolved = await _saavnService.resolveTrackStream(track.title, track.artist);
        if (resolved != null && resolved.streamUrl != null) {
          trackToPlay = trackToPlay.copyWith(
            streamUrl: resolved.streamUrl,
            sourceType: PlaybackType.directStream,
          );
          if (_currentIndex >= 0 && _currentIndex < _queue.length) {
            _queue[_currentIndex] = trackToPlay;
          }
          _currentTrack = trackToPlay;
        }
      }

      if (trackToPlay.streamUrl != null && trackToPlay.streamUrl!.isNotEmpty) {
        _state = _state.copyWith(
          currentTrack: trackToPlay,
          backendId: DirectAudioBackend.id,
          processingState: PlaybackProcessingState.loading,
          clearError: true,
        );
        notifyListeners();
        await _directBackend.load(trackToPlay);
        await _directBackend.play();
        return;
      }
    } catch (e) {
      debugPrint('[UnifiedPlaybackController] Fallback error: $e');
    }

    _state = _state.copyWith(
      isPlaying: false,
      processingState: PlaybackProcessingState.error,
      errorMessage: 'This song is blocked for embedding and no alternate audio stream was found.',
    );
    notifyListeners();
  }

  // --- Song | Video Mode Switching ---

  Future<void> setVideoMode(bool isVideo) async {
    if (_isVideoMode == isVideo) return;
    _isVideoMode = isVideo;
    notifyListeners();

    if (_currentTrack == null) return;

    final currentPos = position;
    if (_isVideoMode) {
      // Switching from Song to Video
      await _directBackend.pause();
      _state = _state.copyWith(backendId: YouTubeIframeBackend.id);
      notifyListeners();

      var trackToPlay = _currentTrack!;
      if (trackToPlay.resolvedYoutubeVideoId == null || trackToPlay.resolvedYoutubeVideoId!.isEmpty) {
        try {
          final query = '${trackToPlay.title} ${trackToPlay.artist}'.trim();
          final searchResults = await _repository
              .searchTracks(query, limit: 1)
              .timeout(const Duration(milliseconds: 2000), onTimeout: () => []);
          if (searchResults.isNotEmpty && searchResults.first.resolvedYoutubeVideoId != null) {
            trackToPlay = trackToPlay.copyWith(
              youtubeVideoId: searchResults.first.resolvedYoutubeVideoId,
            );
            if (_currentIndex >= 0 && _currentIndex < _queue.length) {
              _queue[_currentIndex] = trackToPlay;
            }
            _currentTrack = trackToPlay;
          }
        } catch (e) {
          debugPrint('[UnifiedPlaybackController] Video resolve error: $e');
        }
      }

      await _youtubeBackend.load(trackToPlay, autoplay: true);
      if (currentPos > Duration.zero) {
        await _youtubeBackend.seek(currentPos);
      }
    } else {
      // Switching from Video to Song
      await _youtubeBackend.pause();
      _stopPositionTicker();
      _state = _state.copyWith(backendId: DirectAudioBackend.id);
      notifyListeners();

      var trackToPlay = _currentTrack!;
      if (trackToPlay.streamUrl == null || trackToPlay.streamUrl!.isEmpty) {
        final resolved = await _saavnService.resolveTrackStream(trackToPlay.title, trackToPlay.artist);
        if (resolved != null && resolved.streamUrl != null) {
          trackToPlay = trackToPlay.copyWith(
            streamUrl: resolved.streamUrl,
            sourceType: PlaybackType.directStream,
          );
          if (_currentIndex >= 0 && _currentIndex < _queue.length) {
            _queue[_currentIndex] = trackToPlay;
          }
          _currentTrack = trackToPlay;
        }
      }

      if (trackToPlay.streamUrl != null && trackToPlay.streamUrl!.isNotEmpty) {
        await _directBackend.load(trackToPlay);
        if (currentPos > Duration.zero) {
          await _directBackend.seek(currentPos);
        }
        await _directBackend.play();
      } else {
        // Direct stream unavailable, continue with YouTube audio
        _isVideoMode = true;
        await _youtubeBackend.play();
      }
    }
    notifyListeners();
  }

  Future<void> toggleVideoMode() => setVideoMode(!_isVideoMode);

  // --- Transport controls ---

  Future<void> play() async {
    if (_currentTrack == null && _queue.isNotEmpty) {
      _currentIndex = 0;
      await _loadAndPlayCurrent();
      return;
    }
    await _activeBackend.play();
  }

  Future<void> pause() async {
    await _activeBackend.pause();
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
    await _activeBackend.seek(position);
  }

  Future<void> stop() async {
    _stopPositionTicker();
    await _directBackend.stop();
    await _youtubeBackend.stop();
    _state = const UnifiedPlaybackState.initial();
    positionNotifier.value = Duration.zero;
    notifyListeners();
  }

  Future<void> setVolume(int volume) async {
    await _directBackend.setVolume(volume);
    await _youtubeBackend.setVolume(volume);
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
    notifyListeners();
  }

  Future<void> skipToQueueItem(int index) => skipToQueueIndex(index);

  Future<void> addPlaylistToQueue(
    List<Track> tracks, {
    int startIndex = 0,
    bool isExplicitYoutubeSelection = false,
  }) async {
    if (tracks.isEmpty) return;

    _queue.clear();
    _queue.addAll(tracks);
    _unshuffledQueue = List.from(_queue);
    _currentIndex = startIndex.clamp(0, _queue.length - 1);

    if (_isShuffle) {
      _applyShuffleKeepingCurrent();
    }

    await _loadAndPlayCurrent();
    notifyListeners();
  }

  void addToQueue(Track track) {
    _queue.add(track);
    _unshuffledQueue.add(track);
    notifyListeners();
  }

  void addTrackToQueue(Track track) => addToQueue(track);

  void playNext(Track track) {
    final insertIndex = (_currentIndex + 1).clamp(0, _queue.length);
    _queue.insert(insertIndex, track);
    _unshuffledQueue.insert(insertIndex, track);
    notifyListeners();
  }

  void insertNextInQueue(Track track) => playNext(track);

  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length) return;

    final removedTrack = _queue.removeAt(index);
    _unshuffledQueue.remove(removedTrack);

    if (index < _currentIndex) {
      _currentIndex--;
    } else if (index == _currentIndex) {
      if (_queue.isEmpty) {
        stop();
        return;
      }
      if (_currentIndex >= _queue.length) {
        _currentIndex = _queue.length - 1;
      }
      _loadAndPlayCurrent();
    }
    notifyListeners();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (newIndex < 0 || newIndex > _queue.length) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final currentTrackBefore = _currentTrack;
    final track = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, track);

    if (currentTrackBefore != null) {
      _currentIndex = _queue.indexOf(currentTrackBefore);
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

  void clearUpcomingQueue() {
    if (_currentIndex >= 0 && _currentIndex < _queue.length) {
      final current = _queue[_currentIndex];
      _queue.clear();
      _queue.add(current);
      _unshuffledQueue = [current];
      _currentIndex = 0;
      notifyListeners();
    }
  }

  // --- Shuffle & Repeat ---

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    if (_isShuffle) {
      _applyShuffleKeepingCurrent();
    } else {
      final current = _currentTrack;
      _queue.clear();
      _queue.addAll(_unshuffledQueue);
      if (current != null) {
        _currentIndex = _queue.indexOf(current);
      }
    }
    notifyListeners();
  }

  void _applyShuffleKeepingCurrent() {
    if (_queue.isEmpty) return;
    final current = _currentTrack;
    final others = _queue.where((t) => t.id != current?.id).toList();
    others.shuffle(Random());

    _queue.clear();
    if (current != null) {
      _queue.add(current);
      _queue.addAll(others);
      _currentIndex = 0;
    } else {
      _queue.addAll(others);
    }
  }

  void toggleRepeatMode() {
    switch (_repeatMode) {
      case PlaybackRepeatMode.none:
        _repeatMode = PlaybackRepeatMode.all;
        break;
      case PlaybackRepeatMode.all:
        _repeatMode = PlaybackRepeatMode.one;
        break;
      case PlaybackRepeatMode.one:
        _repeatMode = PlaybackRepeatMode.none;
        break;
    }
    notifyListeners();
  }

  // ==========================================
  // COMPLETION & RADIO
  // ==========================================

  Future<void> _onTrackCompleted() async {
    if (_repeatMode == PlaybackRepeatMode.one) {
      await seekTo(Duration.zero);
      await play();
      return;
    }
    await skipToNext();
  }

  Future<void> startSongRadio(Track seed) async {
    _isGeneratingRadio = true;
    _radioSeedArtist = seed.artist;
    notifyListeners();

    try {
      final radioSet = await _discoveryService.getRadioCandidates(seed, limit: 20);
      final tracks = await _algorithmService.rankCandidates(
        candidates: radioSet.candidates,
        seed: seed,
        limit: 20,
      );
      if (tracks.isNotEmpty) {
        await addPlaylistToQueue([seed, ...tracks], startIndex: 0);
      } else {
        await playTrack(seed);
      }
    } catch (e) {
      debugPrint('[UnifiedPlaybackController] startSongRadio error: $e');
      await playTrack(seed);
    } finally {
      _isGeneratingRadio = false;
      notifyListeners();
    }
  }

  Future<void> startArtistRadio(String artistName, {Track? seedTrack}) async {
    _isGeneratingRadio = true;
    _radioSeedArtist = artistName;
    notifyListeners();

    try {
      if (seedTrack != null) {
        await startSongRadio(seedTrack);
      } else {
        final artistResults = await _repository.searchTracks(artistName, limit: 20);
        if (artistResults.isNotEmpty) {
          await addPlaylistToQueue(artistResults, startIndex: 0);
        }
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
      final genreResults = await _repository.searchTracks('$genre hits', limit: 20);
      if (genreResults.isNotEmpty) {
        await addPlaylistToQueue(genreResults, startIndex: 0);
      }
    } catch (e) {
      debugPrint('[UnifiedPlaybackController] startGenreRadio error: $e');
    } finally {
      _isGeneratingRadio = false;
      notifyListeners();
    }
  }

  Future<void> startTunedRadio({
    required List<String> seedArtists,
    required String variety,
    required String songSelection,
    required List<String> filters,
  }) async {
    _isGeneratingRadio = true;
    _tunedArtists = List.from(seedArtists);
    _radioVariety = variety;
    _radioSongSelection = songSelection;
    _radioFilters = List.from(filters);
    _activeRadioTitle = '${seedArtists.join(', ')} Radio • $songSelection';
    notifyListeners();

    try {
      final List<Track> collectedTracks = [];
      final int perArtistLimit = variety == 'Low' ? 15 : (variety == 'High' ? 6 : 10);
      for (final artist in seedArtists) {
        final query = filters.isNotEmpty
            ? '$artist ${filters.first}'
            : (songSelection == 'Discover' ? '$artist hits' : artist);
        final results = await _repository.searchTracks(query, limit: perArtistLimit);
        collectedTracks.addAll(results);
      }

      final Set<String> seen = {};
      final List<Track> uniqueTracks = [];
      for (final t in collectedTracks) {
        if (!seen.contains(t.id)) {
          seen.add(t.id);
          uniqueTracks.add(t);
        }
      }

      if (songSelection == 'Discover' || songSelection == 'Blend') {
        uniqueTracks.shuffle();
      }

      if (uniqueTracks.isNotEmpty) {
        await addPlaylistToQueue(uniqueTracks, startIndex: 0);
      }
    } catch (e) {
      debugPrint('[UnifiedPlaybackController] startTunedRadio error: $e');
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
    _directEvents?.cancel();
    _playerPosSub?.cancel();
    _playerDurSub?.cancel();
    _playerBufSub?.cancel();
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