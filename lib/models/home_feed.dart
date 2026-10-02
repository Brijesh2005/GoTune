import 'music_content.dart';
import 'recommendation.dart';
import 'track.dart';

/// Unified HomeFeed model inspired by the YouTube-clone content discovery architecture.
/// Encapsulates the entire home discovery dashboard as a coherent content pipeline
/// rather than ad-hoc, disparate network calls.
class HomeFeed {
  final List<Track> quickPicks;
  final List<Track> recommendedSongs;
  final List<Track> trendingTracks;
  final List<Track> popularNow;
  final List<Track> newReleases;
  final List<Track> recentlyPlayed;
  final List<Track> becauseYouListened;
  final String? becauseYouListenedSeed;
  final List<Track> mostPlayed;
  final List<Track> onRepeat;
  final List<Track> rediscover;
  final List<String> favoriteArtists;

  /// Genre and mood facets, supplied by the discovery layer rather than a
  /// hardcoded list, so the browse shelves stay in sync with the catalogs.
  final List<MusicGenre> genres;
  final List<MusicMood> moods;
  final List<PersonalizedMix> personalizedMixes;
  final DateTime updatedAt;
  final bool isLoading;
  final String? errorMessage;

  const HomeFeed({
    this.quickPicks = const [],
    this.recommendedSongs = const [],
    this.trendingTracks = const [],
    this.popularNow = const [],
    this.newReleases = const [],
    this.recentlyPlayed = const [],
    this.becauseYouListened = const [],
    this.becauseYouListenedSeed,
    this.mostPlayed = const [],
    this.onRepeat = const [],
    this.rediscover = const [],
    this.favoriteArtists = const [],
    this.genres = const [],
    this.moods = const [],
    this.personalizedMixes = const [],
    required this.updatedAt,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isEmpty =>
      quickPicks.isEmpty &&
      trendingTracks.isEmpty &&
      recommendedSongs.isEmpty &&
      recentlyPlayed.isEmpty;

  bool get isNotEmpty => !isEmpty;
  bool get hasContent => isNotEmpty;

  HomeFeed copyWith({
    List<Track>? quickPicks,
    List<Track>? recommendedSongs,
    List<Track>? trendingTracks,
    List<Track>? popularNow,
    List<Track>? newReleases,
    List<Track>? recentlyPlayed,
    List<Track>? becauseYouListened,
    String? becauseYouListenedSeed,
    List<Track>? mostPlayed,
    List<Track>? onRepeat,
    List<Track>? rediscover,
    List<String>? favoriteArtists,
    List<MusicGenre>? genres,
    List<MusicMood>? moods,
    List<PersonalizedMix>? personalizedMixes,
    DateTime? updatedAt,
    bool? isLoading,
    String? errorMessage,
  }) {
    return HomeFeed(
      quickPicks: quickPicks ?? this.quickPicks,
      recommendedSongs: recommendedSongs ?? this.recommendedSongs,
      trendingTracks: trendingTracks ?? this.trendingTracks,
      popularNow: popularNow ?? this.popularNow,
      newReleases: newReleases ?? this.newReleases,
      recentlyPlayed: recentlyPlayed ?? this.recentlyPlayed,
      becauseYouListened: becauseYouListened ?? this.becauseYouListened,
      becauseYouListenedSeed: becauseYouListenedSeed ?? this.becauseYouListenedSeed,
      mostPlayed: mostPlayed ?? this.mostPlayed,
      onRepeat: onRepeat ?? this.onRepeat,
      rediscover: rediscover ?? this.rediscover,
      favoriteArtists: favoriteArtists ?? this.favoriteArtists,
      genres: genres ?? this.genres,
      moods: moods ?? this.moods,
      personalizedMixes: personalizedMixes ?? this.personalizedMixes,
      updatedAt: updatedAt ?? this.updatedAt,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
