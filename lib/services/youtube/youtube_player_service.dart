import 'dart:async';

import 'package:flutter/foundation.dart';

import 'youtube_player_channel.dart';
import 'youtube_player_event.dart';

/// Owns every interaction with the embedded YouTube player.
///
/// Responsibilities are deliberately narrow: translate typed Dart calls into
/// channel commands, and translate raw bridge payloads into
/// [YouTubePlayerEvent]s. It owns no UI and no queue — the playback
/// coordinator decides *when* to load or play; this service only knows *how*
/// to talk to `YT.Player`.
///
/// The underlying [YouTubePlayerChannel] is injected, so the whole class is
/// testable without a WebView and the platform implementation can be swapped
/// without touching callers.
class YouTubePlayerService {
  YouTubePlayerChannel? _channel;
  final StreamController<YouTubePlayerEvent> _outgoing =
      StreamController<YouTubePlayerEvent>.broadcast();

  StreamSubscription<YouTubePlayerEvent>? _sub;

  String? _currentVideoId;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _autoplayBlocked = false;
  int? _lastErrorCode;
  String? _lastErrorMessage;

  YouTubePlayerService({YouTubePlayerChannel? channel}) {
    attachChannel(channel);
  }

  // --- Channel wiring ---------------------------------------------------------

  /// Binds a live channel (the WebView host) to this service.
  ///
  /// The service outlives the WebView so that playback state, the current
  /// video and queued commands survive route changes; the host attaches itself
  /// once and is only swapped if it is ever recreated.
  void attachChannel(YouTubePlayerChannel? channel) {
    if (identical(_channel, channel)) return;

    _sub?.cancel();
    _sub = null;
    _channel = channel;
    if (channel != null) {
      _sub = channel.events.listen(_onEvent);
    }
  }

  /// Unbinds [channel] if it is the active one, so a disposed WebView can never
  /// keep feeding events into the coordinator.
  void detachChannel(YouTubePlayerChannel channel) {
    if (identical(_channel, channel)) attachChannel(null);
  }

  /// True when a host is bound, i.e. commands can actually reach the player.
  bool get hasChannel => _channel != null;

  // --- Exposed state ----------------------------------------------------------

  /// True once the IFrame API booted and a player exists.
  bool get isReady => _channel?.isReady ?? false;

  /// Video currently loaded in the player.
  String? get currentVideoId => _currentVideoId ?? _channel?.currentVideoId;

  /// Last reported playhead position.
  Duration get position => _position;

  /// Last reported media duration.
  Duration get duration => _duration;

  /// True when the browser blocked programmatic playback and an explicit user
  /// gesture is required.
  bool get autoplayBlocked => _autoplayBlocked;

  /// Last `onError` code, if the player errored.
  int? get lastErrorCode => _lastErrorCode;

  /// Last mapped error message, ready to show to a listener.
  String? get lastErrorMessage => _lastErrorMessage;

  /// Player events, forwarded from the channel.
  Stream<YouTubePlayerEvent> get events => _outgoing.stream;

  // --- Commands ---------------------------------------------------------------

  /// Loads a YouTube video into the existing player instance.
  ///
  /// Reuses the same `YT.Player` (the host decides whether to `loadVideoById`
  /// or `cueVideoById`) so switching tracks never recreates the WebView or the
  /// iframe — the reference project's "same player, new video" behaviour.
  Future<void> loadVideo(String videoId, {bool autoplay = true}) async {
    final id = videoId.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(videoId, 'videoId', 'must not be empty');
    }
    _currentVideoId = id;
    _position = Duration.zero;
    _duration = Duration.zero;
    _autoplayBlocked = false;
    _lastErrorCode = null;
    _lastErrorMessage = null;
    await _requireChannel().loadVideo(id, autoplay: autoplay);
  }

  /// Loads [videoId] and starts playback in one gesture-bound operation.
  ///
  /// Used to recover from an autoplay block, where the video is usually only
  /// cued. Resets the same per-video state as [loadVideo].
  Future<void> loadAndPlayVideo(String videoId) async {
    final id = videoId.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(videoId, 'videoId', 'must not be empty');
    }
    _currentVideoId = id;
    _position = Duration.zero;
    _autoplayBlocked = false;
    _lastErrorCode = null;
    _lastErrorMessage = null;
    await _requireChannel().loadAndPlayVideo(id);
  }

  Future<void> play() => _requireChannel().play();

  Future<void> pause() => _requireChannel().pause();

  Future<void> seekTo(Duration position) => _requireChannel().seekTo(position);

  Future<void> stop() async {
    await _requireChannel().stop();
    _position = Duration.zero;
  }

  Future<void> setVolume(int volume) =>
      _requireChannel().setVolume(volume.clamp(0, 100));

  /// Current playhead, preferring the player's own answer over the last event
  /// so callers seeking immediately after a scrub get accurate feedback.
  Future<Duration> getCurrentTime() async {
    final channel = _channel;
    if (channel == null) return _position;
    final seconds = await channel.currentTimeSeconds();
    if (seconds == null) return _position;
    _position = Duration(milliseconds: (seconds * 1000).round());
    return _position;
  }

  /// Media duration, preferring the player's own answer.
  Future<Duration> getDuration() async {
    final channel = _channel;
    if (channel == null) return _duration;
    final seconds = await channel.durationSeconds();
    if (seconds == null || seconds <= 0) return _duration;
    _duration = Duration(milliseconds: (seconds * 1000).round());
    return _duration;
  }

  YouTubePlayerChannel _requireChannel() {
    final channel = _channel;
    if (channel == null) {
      throw StateError(
        'YouTubePlayerService has no channel attached. The WebView host must '
        'be mounted before YouTube playback can be commanded.',
      );
    }
    return channel;
  }

  // --- Internals --------------------------------------------------------------

  void _onEvent(YouTubePlayerEvent event) {
    if (event.position > Duration.zero) _position = event.position;
    if (event.duration > Duration.zero) _duration = event.duration;
    if (event.videoId != null && event.videoId!.isNotEmpty) {
      _currentVideoId = event.videoId;
    }

    switch (event.type) {
      case YouTubePlayerEventType.error:
        _lastErrorCode = event.errorCode;
        _lastErrorMessage = event.message;
        break;
      case YouTubePlayerEventType.autoplayBlocked:
        _autoplayBlocked = true;
        break;
      case YouTubePlayerEventType.playing:
        // Playback started, so any earlier autoplay block no longer applies.
        _autoplayBlocked = false;
        _lastErrorCode = null;
        _lastErrorMessage = null;
        break;
      case YouTubePlayerEventType.ready:
      case YouTubePlayerEventType.unstarted:
      case YouTubePlayerEventType.cued:
      case YouTubePlayerEventType.buffering:
      case YouTubePlayerEventType.paused:
      case YouTubePlayerEventType.ended:
      case YouTubePlayerEventType.timeUpdate:
        break;
    }

    if (!_outgoing.isClosed) _outgoing.add(event);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    await _outgoing.close();
  }

  /// Logs a player event without leaking it into user-facing code.
  @visibleForTesting
  static void debugLog(YouTubePlayerEvent event) {
    debugPrint('[YouTubePlayerService] $event');
  }
}