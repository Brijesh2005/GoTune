import 'youtube_player_event.dart';

/// The single seam between GoTune and the YouTube IFrame player.
///
/// `YouTubePlayerService` talks only to this interface, so:
/// * no screen or provider ever runs JavaScript,
/// * the coordinator can be unit tested against an in-memory fake,
/// * swapping the WebView host (or the whole platform) touches one file.
///
/// Implementations must translate these calls into the `window.*` functions
/// defined in `assets/youtube_player/index.html`.
abstract class YouTubePlayerChannel {
  /// True once the WebView finished loading and `YT.Player` is usable.
  bool get isReady;

  /// Video currently loaded in the player, if any.
  String? get currentVideoId;

  /// All player events, newest last.
  Stream<YouTubePlayerEvent> get events;

  /// Loads [videoId], optionally starting playback immediately.
  Future<void> loadVideo(String videoId, {bool autoplay = true});

  /// Loads [videoId] and starts playback as a single gesture-bound step.
  ///
  /// Separate from [loadVideo] because recovering from an autoplay block needs
  /// load *and* play within the user's tap; two round trips can lose the gesture.
  Future<void> loadAndPlayVideo(String videoId);

  Future<void> play();

  Future<void> pause();

  Future<void> seekTo(Duration position);

  Future<void> stop();

  /// Sets player volume, 0-100.
  Future<void> setVolume(int volume);

  /// Current playhead in seconds as reported by the player, or null when the
  /// player is not ready.
  Future<double?> currentTimeSeconds();

  /// Media duration in seconds as reported by the player, or null when
  /// unknown.
  Future<double?> durationSeconds();
}