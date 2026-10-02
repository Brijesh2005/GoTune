/// Typed representation of everything the YouTube IFrame player reports back
/// to Dart.
///
/// The JavaScript host never hands the app a raw payload: it converts
/// `YT.PlayerState` integers and `onError` codes into these strings, so no
/// screen ever parses IFrame internals and the mapping can be unit tested.
library;

/// Every event the IFrame host can emit.
enum YouTubePlayerEventType {
  /// The IFrame API finished booting and `YT.Player` accepted construction.
  ready,

  /// `YT.PlayerState.UNSTARTED`
  unstarted,

  /// `YT.PlayerState.CUED` — a video is loaded and ready to play.
  cued,

  /// `YT.PlayerState.BUFFERING`
  buffering,

  /// `YT.PlayerState.PLAYING`
  playing,

  /// `YT.PlayerState.PAUSED`
  paused,

  /// `YT.PlayerState.ENDED`
  ended,

  /// The browser refused programmatic playback (the IFrame `onAutoplayBlocked`
  /// event). Playback must not be retried silently; the UI asks for a tap.
  autoplayBlocked,

  /// `onError` fired.
  error,

  /// Periodic position/duration tick while playing.
  timeUpdate,
}

/// Wire names shared with `assets/youtube_player/index.html`.
extension YouTubePlayerEventTypeWire on YouTubePlayerEventType {
  String get wireName => switch (this) {
        YouTubePlayerEventType.ready => 'ready',
        YouTubePlayerEventType.unstarted => 'unstarted',
        YouTubePlayerEventType.cued => 'cued',
        YouTubePlayerEventType.buffering => 'buffering',
        YouTubePlayerEventType.playing => 'playing',
        YouTubePlayerEventType.paused => 'paused',
        YouTubePlayerEventType.ended => 'ended',
        YouTubePlayerEventType.autoplayBlocked => 'autoplayBlocked',
        YouTubePlayerEventType.error => 'error',
        YouTubePlayerEventType.timeUpdate => 'timeUpdate',
      };

  /// Parses a wire name, returning null for unknown or malformed payloads.
  ///
  /// Nullability is deliberate: silently defaulting an unknown type to
  /// [YouTubePlayerEventType.ready] would let a bad message masquerade as a
  /// successful player start.
  static YouTubePlayerEventType? fromWire(String? value) {
    return switch (value) {
      'ready' => YouTubePlayerEventType.ready,
      'unstarted' => YouTubePlayerEventType.unstarted,
      'cued' => YouTubePlayerEventType.cued,
      'buffering' => YouTubePlayerEventType.buffering,
      'playing' => YouTubePlayerEventType.playing,
      'paused' => YouTubePlayerEventType.paused,
      'ended' => YouTubePlayerEventType.ended,
      'autoplayBlocked' => YouTubePlayerEventType.autoplayBlocked,
      'error' => YouTubePlayerEventType.error,
      'timeUpdate' => YouTubePlayerEventType.timeUpdate,
      // An unrecognised payload must not be mistaken for a readiness signal.
      _ => null,
    };
  }
}

/// A single, immutable IFrame player event.
class YouTubePlayerEvent {
  final YouTubePlayerEventType type;

  /// Playhead position reported with the event.
  final Duration position;

  /// Media duration reported with the event.
  final Duration duration;

  /// `onError` code (2, 5, 100, 101, 150, 153, …) for
  /// [YouTubePlayerEventType.error].
  final int? errorCode;

  /// Human readable detail, already mapped by [describeYouTubePlayerError].
  final String? message;

  /// Video the event relates to, so late events from a previous load can be
  /// discarded after the user skipped ahead.
  final String? videoId;

  const YouTubePlayerEvent({
    required this.type,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.errorCode,
    this.message,
    this.videoId,
  });

  /// Builds an event from the JSON posted by the JavaScript host.
  ///
  /// Returns null when the payload carries no recognisable event type, so a
  /// malformed or foreign message is dropped instead of being reinterpreted.
  static YouTubePlayerEvent? tryFromBridge(Map<String, dynamic> json) {
    final type = YouTubePlayerEventTypeWire.fromWire(json['type']?.toString());
    if (type == null) return null;
    final errorCode = switch (json['code']) {
      final num n => n.toInt(),
      final String s => int.tryParse(s),
      _ => null,
    };

    return YouTubePlayerEvent(
      type: type,
      position: _secondsToDuration(json['position']),
      duration: _secondsToDuration(json['duration']),
      errorCode: errorCode,
      message: json['message']?.toString() ??
          (errorCode != null ? describeYouTubePlayerError(errorCode) : null),
      videoId: json['videoId']?.toString(),
    );
  }

  static Duration _secondsToDuration(Object? raw) {
    final seconds = switch (raw) {
      final num n => n.toDouble(),
      final String s => double.tryParse(s),
      _ => null,
    };
    if (seconds == null || seconds.isNaN || seconds.isInfinite || seconds < 0) {
      return Duration.zero;
    }
    return Duration(milliseconds: (seconds * 1000).round());
  }

  bool get isError => type == YouTubePlayerEventType.error;

  @override
  String toString() =>
      'YouTubePlayerEvent(${type.wireName}, position: ${position.inSeconds}s, '
      'duration: ${duration.inSeconds}s, code: $errorCode, videoId: $videoId)';
}

/// Maps IFrame `onError` codes to a message a music listener can act on.
///
/// Codes follow the published IFrame Player API error list; 150/153 are the
/// embedding failures that matter most for an app-hosted player.
String describeYouTubePlayerError(int code) {
  return switch (code) {
    2 => 'This YouTube video cannot be played in an embedded player.',
    5 =>
      'YouTube could not play this video in the embedded player. The video owner may have disabled embedding.',
    100 => 'This YouTube video was removed or is no longer available.',
    101 => 'The video owner does not allow this video to be played in other apps.',
    150 => 'The video owner does not allow embedded playback in other apps.',
    153 =>
      'YouTube could not verify this embedded player. The request was missing the required Referer or client identification.',
    _ => 'YouTube playback failed (error $code).',
  };
}