/// Interaction event types recorded by the GoTune recommendation engine.
enum InteractionEventType {
  songStarted,
  songCompleted,
  songSkipped,
  songPartiallyPlayed,
  songLiked,
  songUnliked,
  songAddedToPlaylist,
  songRemovedFromPlaylist,
  searchPerformed,
  songReplayed,
  artistPlayed,
  albumPlayed,
  genrePlayed,
}

/// Aggregated user interaction statistics for a specific track, artist, or genre.
class UserInteractionStats {
  final Map<String, int> songPlayCounts;
  final Map<String, int> songCompletionCounts;
  final Map<String, int> songSkipCounts;
  final Map<String, DateTime> songLastPlayed;
  final Map<String, int> artistPlayCounts;
  final Map<String, int> artistSkipCounts;
  final Map<String, int> genrePlayCounts;
  final List<String> recentSkippedTrackIds;

  const UserInteractionStats({
    this.songPlayCounts = const {},
    this.songCompletionCounts = const {},
    this.songSkipCounts = const {},
    this.songLastPlayed = const {},
    this.artistPlayCounts = const {},
    this.artistSkipCounts = const {},
    this.genrePlayCounts = const {},
    this.recentSkippedTrackIds = const [],
  });

  /// Completion rate for a specific track: completion / (play + skip)
  double getTrackCompletionRate(String trackId) {
    final completions = songCompletionCounts[trackId] ?? 0;
    final plays = songPlayCounts[trackId] ?? 0;
    final skips = songSkipCounts[trackId] ?? 0;
    final total = plays + skips;
    if (total == 0) return 0.5;
    return (completions / total).clamp(0.0, 1.0);
  }

  /// Skip rate for a specific track
  double getTrackSkipRate(String trackId) {
    final plays = songPlayCounts[trackId] ?? 0;
    final skips = songSkipCounts[trackId] ?? 0;
    final total = plays + skips;
    if (total == 0) return 0.0;
    return (skips / total).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() {
    return {
      'songPlayCounts': songPlayCounts,
      'songCompletionCounts': songCompletionCounts,
      'songSkipCounts': songSkipCounts,
      'songLastPlayed': songLastPlayed.map((k, v) => MapEntry(k, v.toIso8601String())),
      'artistPlayCounts': artistPlayCounts,
      'artistSkipCounts': artistSkipCounts,
      'genrePlayCounts': genrePlayCounts,
      'recentSkippedTrackIds': recentSkippedTrackIds,
    };
  }

  factory UserInteractionStats.fromJson(Map<String, dynamic> json) {
    Map<String, int> parseIntMap(dynamic map) {
      if (map is! Map) return {};
      return map.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    }

    Map<String, DateTime> parseDateMap(dynamic map) {
      if (map is! Map) return {};
      final res = <String, DateTime>{};
      map.forEach((k, v) {
        final parsed = DateTime.tryParse(v.toString());
        if (parsed != null) res[k.toString()] = parsed;
      });
      return res;
    }

    return UserInteractionStats(
      songPlayCounts: parseIntMap(json['songPlayCounts']),
      songCompletionCounts: parseIntMap(json['songCompletionCounts']),
      songSkipCounts: parseIntMap(json['songSkipCounts']),
      songLastPlayed: parseDateMap(json['songLastPlayed']),
      artistPlayCounts: parseIntMap(json['artistPlayCounts']),
      artistSkipCounts: parseIntMap(json['artistSkipCounts']),
      genrePlayCounts: parseIntMap(json['genrePlayCounts']),
      recentSkippedTrackIds: (json['recentSkippedTrackIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}
