/// The playback backend servicing tracks in GoTune.
/// GoTune is YouTube-focused, using the official embedded YouTube IFrame player.
enum PlaybackType {
  /// YouTube video played inside the official IFrame Player API hosted by a WebView.
  youtubeIframe,
}

extension PlaybackTypeWire on PlaybackType {
  String get wireName => 'youtubeIframe';

  static PlaybackType fromWire(String? value) => PlaybackType.youtubeIframe;

  bool get usesDirectAudioEngine => false;

  bool get requiresForegroundView => true;
}