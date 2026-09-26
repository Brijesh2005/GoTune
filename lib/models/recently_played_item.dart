import 'track.dart';

/// Represents a track that was played, paired with a persistent timestamp.
class RecentlyPlayedItem {
  final Track track;
  final DateTime playedAt;

  const RecentlyPlayedItem({
    required this.track,
    required this.playedAt,
  });

  /// Relative human-readable string (e.g. "Just now", "5m ago", "Yesterday").
  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(playedAt);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${playedAt.day}/${playedAt.month}/${playedAt.year}';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'track': track.toJson(),
      'played_at': playedAt.toIso8601String(),
    };
  }

  factory RecentlyPlayedItem.fromJson(Map<String, dynamic> json) {
    return RecentlyPlayedItem(
      track: Track.fromJson(json['track'] as Map<String, dynamic>),
      playedAt: DateTime.tryParse(json['played_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecentlyPlayedItem &&
          runtimeType == other.runtimeType &&
          track.id == other.track.id;

  @override
  int get hashCode => track.id.hashCode;
}
