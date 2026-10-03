/// The playback backend servicing tracks in GoTune.
enum PlaybackType {
  /// YouTube video played inside the official IFrame Player API hosted by a WebView.
  youtubeIframe,

  /// Direct audio stream (320kbps MP4/M4A/AAC) with full background play & notification support.
  directStream,
}

extension PlaybackTypeWire on PlaybackType {
  String get wireName {
    switch (this) {
      case PlaybackType.youtubeIframe:
        return 'youtubeIframe';
      case PlaybackType.directStream:
        return 'directStream';
    }
  }

  static PlaybackType fromWire(String? value) {
    if (value == 'directStream') return PlaybackType.directStream;
    return PlaybackType.youtubeIframe;
  }

  bool get usesDirectAudioEngine => this == PlaybackType.directStream;

  bool get requiresForegroundView => this == PlaybackType.youtubeIframe;
}