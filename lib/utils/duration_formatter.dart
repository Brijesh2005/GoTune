/// Formats seconds or [Duration] instances into clean readable strings like `3:45` or `1:02:30`.
class DurationFormatter {
  /// Converts an integer number of seconds into `m:ss` or `h:mm:ss`.
  static String formatSeconds(int totalSeconds) {
    if (totalSeconds <= 0) return '0:00';
    final duration = Duration(seconds: totalSeconds);
    return format(duration);
  }

  /// Converts a [Duration] object into `m:ss` or `h:mm:ss`.
  static String format(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    final secondsStr = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      final minutesStr = minutes.toString().padLeft(2, '0');
      return '$hours:$minutesStr:$secondsStr';
    } else {
      return '$minutes:$secondsStr';
    }
  }

  /// Formats compact numbers, e.g. 1500 -> 1.5K, 1200000 -> 1.2M.
  static String formatCompactNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}
