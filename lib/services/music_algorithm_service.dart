import 'dart:math';
import 'package:flutter/material.dart';
import '../models/interaction_event.dart';
import '../models/recommendation.dart';
import '../models/track.dart';
import '../repositories/track_repository.dart';

enum RadioType { song, artist, album, genre, mood }

/// GoTune Personal Recommendation Engine
/// Independent local recommendation engine using deterministic mathematical ranking,
/// interaction event tracking (plays, skips, completions, likes, search),
/// weighted signal scoring, artist diversity caps, and dynamic radio queues.
/// Does NOT use remote AI/ML models or heavy tensors, ensuring lightweight and fast execution.
class MusicAlgorithmService {
  final TrackRepository _repository;
  final Random _random = Random();

  MusicAlgorithmService({required TrackRepository repository})
      : _repository = repository;

  // Curated genre & artist affinity matrix for intelligent candidate clustering
  static const Map<String, List<String>> _genreArtistClusters = {
    'pop_soul': [
      'Adele',
      'Sam Smith',
      'Amy Winehouse',
      'Lewis Capaldi',
      'Billie Eilish',
      'Ed Sheeran',
      'Olivia Rodrigo',
      'Bruno Mars',
      'Coldplay',
      'Lady Gaga',
      'Sia',
      'John Legend',
    ],
    'bollywood_romance': [
      'Arijit Singh',
      'Atif Aslam',
      'Mohit Chauhan',
      'Jubin Nautiyal',
      'Jasleen Royal',
      'Pritam',
      'Shreya Ghoshal',
      'Darshan Raval',
      'Armaan Malik',
      'Vishal Mishra',
      'KK',
      'Sonu Nigam',
    ],
    'punjabi_desi': [
      'Sidhu Moose Wala',
      'Karan Aujla',
      'Diljit Dosanjh',
      'AP Dhillon',
      'Badshah',
      'Yo Yo Honey Singh',
      'Shubh',
      'King',
      'Divine',
      'MC Stan',
    ],
    'synth_rnb': [
      'The Weeknd',
      'Dua Lipa',
      'Daft Punk',
      'SZA',
      'Frank Ocean',
      'Khalid',
      'Doja Cat',
      'Harry Styles',
      'Post Malone',
    ],
    'hiphop_rap': [
      'Drake',
      'Kendrick Lamar',
      'Travis Scott',
      'J. Cole',
      'Eminem',
      '21 Savage',
      'Metro Boomin',
      'Future',
      'Juice WRLD',
    ],
    'edm_dance': [
      'Avicii',
      'Martin Garrix',
      'The Chainsmokers',
      'Alan Walker',
      'David Guetta',
      'Calvin Harris',
      'Marshmello',
      'Kygo',
      'Zedd',
      'Tiësto',
    ],
    'phonk': [
      'Kordhell',
      'Hensonn',
      'DVRST',
      'Ghostwriter',
      'SXID',
      'Pharmacist',
      'Playaphonk',
    ],
    'lofi': [
      'Kijugo',
      'potsu',
      'Kupla',
      'idealism',
      'Jinsang',
      'lofi fruits',
      'ChilledCow',
    ],
    'rock_alt': [
      'Imagine Dragons',
      'Arctic Monkeys',
      'Queen',
      'Linkin Park',
      'The Neighbourhood',
      'Nirvana',
      'Twenty One Pilots',
      'The 1975',
    ],
  };

  // ==========================================
  // MATHEMATICAL SCORING ENGINE
  // ==========================================

  /// Computes deterministic recommendation score using specified weighted signals:
  /// score = 0.25 * artistAffinity
  ///       + 0.20 * genreAffinity
  ///       + 0.15 * recentInterest
  ///       + 0.15 * favoriteAffinity
  ///       + 0.10 * popularity
  ///       + 0.10 * similarity
  ///       + 0.05 * exploration
  double calculateScore({
    required Track candidate,
    required List<Track> history,
    required List<Track> favorites,
    Track? seedTrack,
    UserInteractionStats? stats,
    double artistWeight = 0.25,
    double genreWeight = 0.20,
    double recentWeight = 0.15,
    double favoriteWeight = 0.15,
    double popularityWeight = 0.10,
    double similarityWeight = 0.10,
    double explorationWeight = 0.05,
  }) {
    final artistAffinity = _computeArtistAffinity(candidate, history, favorites, stats);
    final genreAffinity = _computeGenreAffinity(candidate, history, favorites, stats);
    final recentInterest = _computeRecentInterest(candidate, history);
    final favoriteAffinity = _computeFavoriteAffinity(candidate, favorites);
    final popularity = _computePopularity(candidate);
    final similarity = seedTrack != null ? _computeSimilarity(candidate, seedTrack) : 0.5;
    final exploration = _computeExploration(candidate, history);

    // Apply exact configurable weights
    double score = (artistWeight * artistAffinity) +
        (genreWeight * genreAffinity) +
        (recentWeight * recentInterest) +
        (favoriteWeight * favoriteAffinity) +
        (popularityWeight * popularity) +
        (similarityWeight * similarity) +
        (explorationWeight * exploration);

    // Factor in user completion vs skip rate signals if available
    if (stats != null) {
      final completionRate = stats.getTrackCompletionRate(candidate.id);
      final skipRate = stats.getTrackSkipRate(candidate.id);
      score = score * (0.85 + 0.15 * completionRate) * (1.0 - 0.4 * skipRate);
    }

    return score.clamp(0.0, 1.0);
  }

  double _computeArtistAffinity(
    Track candidate,
    List<Track> history,
    List<Track> favorites,
    UserInteractionStats? stats,
  ) {
    if (history.isEmpty && favorites.isEmpty && stats == null) return 0.5;
    final targetArtist = cleanArtist(candidate.artist).toLowerCase();

    int matches = 0;
    for (final t in history) {
      if (cleanArtist(t.artist).toLowerCase() == targetArtist) matches += 2;
    }
    for (final t in favorites) {
      if (cleanArtist(t.artist).toLowerCase() == targetArtist) matches += 3;
    }
    if (stats != null) {
      final plays = stats.artistPlayCounts[candidate.artist] ?? 0;
      final skips = stats.artistSkipCounts[candidate.artist] ?? 0;
      matches += (plays * 2 - skips).clamp(0, 50);
    }

    final totalInteractions = max(1, history.length * 2 + favorites.length * 3);
    return (matches / totalInteractions).clamp(0.0, 1.0);
  }

  double _computeGenreAffinity(
    Track candidate,
    List<Track> history,
    List<Track> favorites,
    UserInteractionStats? stats,
  ) {
    if (history.isEmpty && favorites.isEmpty && stats == null) return 0.5;
    final targetGenre = candidate.genre.toLowerCase();

    int matches = 0;
    for (final t in history) {
      if (t.genre.toLowerCase() == targetGenre) matches++;
    }
    for (final t in favorites) {
      if (t.genre.toLowerCase() == targetGenre) matches += 2;
    }
    if (stats != null) {
      final gPlays = stats.genrePlayCounts[candidate.genre] ?? 0;
      matches += gPlays.clamp(0, 30);
    }

    final total = max(1, history.length + favorites.length * 2);
    return (matches / total).clamp(0.0, 1.0);
  }

  double _computeRecentInterest(Track candidate, List<Track> history) {
    if (history.isEmpty) return 0.0;
    final targetArtist = cleanArtist(candidate.artist).toLowerCase();
    final recents = history.take(10).toList();

    for (int i = 0; i < recents.length; i++) {
      if (cleanArtist(recents[i].artist).toLowerCase() == targetArtist) {
        return (1.0 - (i / recents.length)).clamp(0.0, 1.0);
      }
    }
    return 0.1;
  }

  double _computeFavoriteAffinity(Track candidate, List<Track> favorites) {
    if (favorites.isEmpty) return 0.0;
    final targetArtist = cleanArtist(candidate.artist).toLowerCase();

    if (favorites.any((t) => t.id == candidate.id)) {
      return 1.0;
    }
    if (favorites.any((t) => cleanArtist(t.artist).toLowerCase() == targetArtist)) {
      return 0.7;
    }
    return 0.0;
  }

  double _computePopularity(Track candidate) {
    final count = candidate.playCount ?? 0;
    if (count <= 0) return 0.4;
    final logPlay = (log(count) / ln10).clamp(0.0, 7.0);
    return (logPlay / 7.0).clamp(0.2, 1.0);
  }

  double _computeSimilarity(Track candidate, Track seedTrack) {
    final candArt = cleanArtist(candidate.artist).toLowerCase();
    final seedArt = cleanArtist(seedTrack.artist).toLowerCase();

    if (candArt == seedArt) return 0.9;

    // Check sibling cluster match
    final siblings = getSiblingArtists(seedTrack.artist, seedTrack.genre);
    if (siblings.any((s) => s.toLowerCase() == candArt)) {
      return 0.8;
    }

    if (candidate.genre.toLowerCase() == seedTrack.genre.toLowerCase()) {
      return 0.6;
    }
    return 0.2;
  }

  double _computeExploration(Track candidate, List<Track> history) {
    if (history.isEmpty) return 1.0;
    final candArt = cleanArtist(candidate.artist).toLowerCase();
    final hasListened = history.any((t) => cleanArtist(t.artist).toLowerCase() == candArt);
    return hasListened ? 0.1 : 0.9;
  }

  // ==========================================
  // RECOMMENDATION API
  // ==========================================

  /// Returns recommended tracks tailored for the user with artist diversity caps.
  ///
  /// Pure ranking: the caller supplies [catalogPool]. This engine never queries
  /// a catalog itself, which keeps discovery and ranking independently testable
  /// and prevents a single provider from owning the recommendation pipeline.
  Future<List<Track>> getRecommendedForYou({
    required List<Track> history,
    required List<Track> favorites,
    List<Track>? catalogPool,
    int limit = 15,
  }) async {
    final pool = List<Track>.from(catalogPool ?? []);
    if (pool.isEmpty) return const [];

    final stats = _repository.storageService.getInteractionStats();

    // Filter recently skipped songs
    final skippedIds = stats.recentSkippedTrackIds.toSet();
    final candidates = pool.where((t) => !skippedIds.contains(t.id)).toList();

    return _rankTracksWithDiversity(
      candidates: candidates.isNotEmpty ? candidates : pool,
      history: history,
      favorites: favorites,
      stats: stats,
      limit: limit,
      maxPerArtist: 2,
    );
  }

  /// Returns quick picks: familiar favorites and high completion songs.
  List<Track> getQuickPicks({
    required List<Track> history,
    required List<Track> favorites,
    int limit = 8,
  }) {
    final combined = <Track>[...favorites, ...history];
    return Track.deduplicate(combined).take(limit).toList();
  }

  /// Returns most played tracks based on user interaction statistics.
  List<Track> getMostPlayed({
    required List<Track> history,
    required List<Track> favorites,
    int limit = 15,
  }) {
    final stats = _repository.storageService.getInteractionStats();
    final combined = Track.deduplicate([...history, ...favorites]);

    combined.sort((a, b) {
      final countA = stats.songPlayCounts[a.id] ?? ((a.playCount ?? 0) > 0 ? 1 : 0);
      final countB = stats.songPlayCounts[b.id] ?? ((b.playCount ?? 0) > 0 ? 1 : 0);
      return countB.compareTo(countA);
    });

    return combined.take(limit).toList();
  }

  /// Returns on repeat tracks: tracks played frequently and recently.
  List<Track> getOnRepeat({
    required List<Track> history,
    int limit = 15,
  }) {
    final counts = <String, int>{};
    for (final t in history) {
      counts[t.id] = (counts[t.id] ?? 0) + 1;
    }
    final onRepeat = history.where((t) => (counts[t.id] ?? 0) >= 2).toList();
    return Track.deduplicate(onRepeat).take(limit).toList();
  }

  /// Returns rediscover tracks: tracks played in the past but not recently.
  List<Track> getRediscover({
    required List<Track> history,
    required List<Track> favorites,
    int limit = 15,
  }) {
    if (history.length <= 5 && favorites.isEmpty) return [];
    // Skip the most recent 10 tracks, take older history and favorites
    final olderHistory = history.skip(min(10, history.length)).toList();
    final candidates = Track.deduplicate([...olderHistory, ...favorites]);
    candidates.shuffle(_random);
    return candidates.take(limit).toList();
  }

  /// Returns recommended artists based on user interactions.
  ///
  /// Derived purely from what the user actually played or saved — this engine
  /// never invents artist names, so every name shown here is one the user has a
  /// real connection to and can be resolved by the catalog.
  List<String> getRecommendedArtistNames({
    required List<Track> history,
    required List<Track> favorites,
    int limit = 10,
  }) {
    final counts = <String, int>{};
    for (final t in history) {
      final art = cleanArtist(t.artist);
      if (art.isNotEmpty && art != 'Unknown Artist') {
        counts[art] = (counts[art] ?? 0) + 1;
      }
    }
    for (final t in favorites) {
      final art = cleanArtist(t.artist);
      if (art.isNotEmpty && art != 'Unknown Artist') {
        counts[art] = (counts[art] ?? 0) + 3;
      }
    }
    if (counts.isEmpty) return const [];

    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => e.key).toList();
  }

  // ==========================================
  // PERSONALIZED MIXES (LOCAL ENGINE)
  // ==========================================

  Future<List<PersonalizedMix>> generatePersonalizedMixes({
    required List<Track> history,
    required List<Track> favorites,
    List<Track>? catalogPool,
  }) async {
    final pool = List<Track>.from(catalogPool ?? []);
    if (pool.isEmpty) return const [];

    final topArtist = _getTopArtist(history, favorites);

    // 1. My Mix: Balanced personal mix with diversity
    final myMixTracks = _rankTracksWithDiversity(
      candidates: pool,
      history: history,
      favorites: favorites,
      limit: 12,
      maxPerArtist: 2,
    );

    // 2. Recent Mix: Focused heavily on recent history tracks
    final recentMixTracks = _buildRecentMix(history, pool);

    // 3. Favorites Mix: Favorite tracks combined with sibling artist hits
    final favoritesMixTracks = _buildFavoritesMix(favorites, pool);

    // 4. Discovery Mix: Higher exploration weight for discovering new sounds
    final discoveryMixTracks = _buildDiscoveryMix(pool, history, favorites);

    // 5. Artist Mix: Seeded with the user's top artist
    final artistMixTracks = _buildArtistMix(topArtist, pool);

    return [
      PersonalizedMix(
        id: 'my_mix',
        title: 'My Mix',
        subtitle: topArtist != null ? '$topArtist, and more' : 'Tailored for you',
        description: 'Your continuous personal soundtrack updated daily',
        gradientColors: const [Color(0xFFE50914), Color(0xFF6B0E1A)],
        icon: Icons.auto_awesome_rounded,
        tracks: myMixTracks.isNotEmpty ? myMixTracks : pool.take(8).toList(),
      ),
      PersonalizedMix(
        id: 'recent_mix',
        title: 'Recent Mix',
        subtitle: 'Based on your recent listening',
        description: 'Pick up where you left off with familiar hits',
        gradientColors: const [Color(0xFF1DB954), Color(0xFF0F5A29)],
        icon: Icons.history_rounded,
        tracks: recentMixTracks.isNotEmpty ? recentMixTracks : pool.take(8).toList(),
      ),
      PersonalizedMix(
        id: 'favorites_mix',
        title: 'Favorites Mix',
        subtitle: 'Your most loved songs',
        description: 'Only your verified favorites and closest matches',
        gradientColors: const [Color(0xFF9C27B0), Color(0xFF4A148C)],
        icon: Icons.favorite_rounded,
        tracks: favoritesMixTracks.isNotEmpty ? favoritesMixTracks : pool.take(8).toList(),
      ),
      PersonalizedMix(
        id: 'discovery_mix',
        title: 'Discovery Mix',
        subtitle: 'Fresh sounds & new artists',
        description: 'Step outside your usual rotation with exciting gems',
        gradientColors: const [Color(0xFFFF9800), Color(0xFFB26A00)],
        icon: Icons.explore_rounded,
        tracks: discoveryMixTracks.isNotEmpty ? discoveryMixTracks : pool.take(8).toList(),
      ),
      PersonalizedMix(
        id: 'artist_mix',
        title: topArtist != null ? '$topArtist Mix' : 'Artist Spotlight',
        subtitle: topArtist != null ? 'Best of $topArtist & similar' : 'Spotlight rotation',
        description: 'Deep dive into your favorite artist and related sounds',
        gradientColors: const [Color(0xFF00B0FF), Color(0xFF005B9F)],
        icon: Icons.person_rounded,
        tracks: artistMixTracks.isNotEmpty ? artistMixTracks : pool.take(8).toList(),
      ),
    ];
  }

  List<Track> _rankTracksWithDiversity({
    required List<Track> candidates,
    required List<Track> history,
    required List<Track> favorites,
    UserInteractionStats? stats,
    Track? seedTrack,
    int limit = 12,
    int maxPerArtist = 2,
    Map<String, int> existingArtistCounts = const {},
    Set<String> skipFingerprints = const {},
  }) {
    if (limit <= 0 || candidates.isEmpty) return const [];

    final scored = candidates.map((t) {
      final s = calculateScore(
        candidate: t,
        history: history,
        favorites: favorites,
        seedTrack: seedTrack,
        stats: stats,
      );
      return MapEntry(t, s);
    }).toList();

    scored.sort((a, b) => b.value.compareTo(a.value));

    final artistCounts = <String, int>{...existingArtistCounts};
    final seenFingerprints = <String>{...skipFingerprints};
    final results = <Track>[];

    for (final entry in scored) {
      final track = entry.key;
      final fp = track.normalizedFingerprint;
      final primaryArt = cleanArtist(track.artist).toLowerCase();

      if (seenFingerprints.contains(fp)) continue;
      if ((artistCounts[primaryArt] ?? 0) >= maxPerArtist) continue;

      seenFingerprints.add(fp);
      artistCounts[primaryArt] = (artistCounts[primaryArt] ?? 0) + 1;
      results.add(track);

      if (results.length >= limit) break;
    }

    return results;
  }

  List<Track> _buildRecentMix(List<Track> history, List<Track> pool) {
    if (history.isEmpty) return pool.take(10).toList();
    final uniqueRecents = <String, Track>{};
    for (final t in history) {
      uniqueRecents.putIfAbsent(t.normalizedFingerprint, () => t);
    }
    return uniqueRecents.values.take(12).toList();
  }

  List<Track> _buildFavoritesMix(List<Track> favorites, List<Track> pool) {
    if (favorites.isEmpty) return pool.take(10).toList();
    final favList = List<Track>.from(favorites);
    favList.shuffle(_random);
    return favList.take(12).toList();
  }

  List<Track> _buildDiscoveryMix(List<Track> pool, List<Track> history, List<Track> favorites) {
    final scored = pool.map((t) {
      final expScore = _computeExploration(t, history);
      final popScore = _computePopularity(t);
      return MapEntry(t, (expScore * 0.7) + (popScore * 0.3));
    }).toList();

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).take(12).toList();
  }

  List<Track> _buildArtistMix(String? topArtist, List<Track> pool) {
    if (topArtist == null) return pool.take(10).toList();
    final artLower = topArtist.toLowerCase();
    final matching = pool.where((t) => t.artist.toLowerCase().contains(artLower)).toList();
    final siblings = getSiblingArtists(topArtist, null);

    final siblingTracks = pool.where((t) {
      return siblings.any((s) => t.artist.toLowerCase().contains(s.toLowerCase()));
    }).toList();

    return [...matching, ...siblingTracks].take(12).toList();
  }

  String? _getTopArtist(List<Track> history, List<Track> favorites) {
    final counts = <String, int>{};
    for (final t in history) {
      final art = cleanArtist(t.artist);
      if (art.isNotEmpty && art != 'Unknown Artist') {
        counts[art] = (counts[art] ?? 0) + 1;
      }
    }
    for (final t in favorites) {
      final art = cleanArtist(t.artist);
      if (art.isNotEmpty && art != 'Unknown Artist') {
        counts[art] = (counts[art] ?? 0) + 2;
      }
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  // ==========================================
  // SMART RADIO (AUTOPLAY QUEUE)
  // ==========================================

  /// Ranks externally discovered [candidates] into a radio queue.
  ///
  /// This is the second stage of radio. Stage one (discovery) lives in
  /// `MusicDiscoveryService.getRadioCandidates`, which fans out provider
  /// related endpoints, the seed's artist, the seed's genre and trending.
  /// This stage only orders and diversifies what it was handed — it performs no
  /// I/O at all, so radio quality is a pure function of the candidate set and
  /// the user's listening data.
  ///
  /// Steps:
  /// 1. drop the seed, explicit [excludedIds] and implausible durations,
  /// 2. drop normalized-title duplicates of the seed (no repeated song),
  /// 3. emit [pinned] tracks first (guaranteed opening acts for artist/genre
  ///    radio),
  /// 4. score the remainder with [calculateScore] using [seed] similarity,
  /// 5. enforce an [maxPerArtist] diversity cap so one artist cannot flood
  ///    the queue.
  Future<List<Track>> rankCandidates({
    required List<Track> candidates,
    required Track seed,
    List<Track> history = const [],
    List<Track> favorites = const [],
    int limit = 12,
    int maxPerArtist = 2,
    Set<String> excludedIds = const {},
    List<Track> pinned = const [],
  }) async {
    final blocked = Set<String>.from(excludedIds)..add(seed.id);
    final seedTitle = _normalizeString(cleanTitle(seed.title));
    final seenTitles = <String>{if (seedTitle.isNotEmpty) seedTitle};

    // Dedup set scoped to the validation pass below. It must not leak into the
    // ranking stage, otherwise every already-validated candidate would be
    // discarded as "already seen".
    final validatedFingerprints = <String>{};

    final valid = <Track>[];
    for (final track in candidates) {
      if (blocked.contains(track.id)) continue;
      if (!_isReasonableDuration(track)) continue;

      final fingerprint = track.normalizedFingerprint;
      if (validatedFingerprints.contains(fingerprint)) continue;

      final titleKey = _normalizeString(cleanTitle(track.title));
      if (titleKey.isNotEmpty) {
        if (seenTitles.contains(titleKey)) continue;
        seenTitles.add(titleKey);
      }

      validatedFingerprints.add(fingerprint);
      valid.add(track);
    }

    if (valid.isEmpty) return const [];

    // Fingerprints actually emitted, so pinned tracks are not re-ranked.
    final emittedFingerprints = <String>{};
    final results = <Track>[];
    final artistCounts = <String, int>{};

    // Pinned tracks lead the queue, still respecting the diversity cap.
    for (final track in pinned) {
      if (results.length >= limit) break;
      final fingerprint = track.normalizedFingerprint;
      if (!emittedFingerprints.add(fingerprint)) continue;
      if (blocked.contains(track.id)) continue;
      if (!_isReasonableDuration(track)) continue;

      final artist = cleanArtist(track.artist).toLowerCase();
      if ((artistCounts[artist] ?? 0) >= maxPerArtist) continue;
      artistCounts[artist] = (artistCounts[artist] ?? 0) + 1;
      results.add(track);
    }

    final stats = _repository.storageService.getInteractionStats();
    final remaining = _rankTracksWithDiversity(
      candidates: valid,
      history: history,
      favorites: favorites,
      stats: stats,
      seedTrack: seed,
      limit: limit - results.length,
      maxPerArtist: maxPerArtist,
      existingArtistCounts: artistCounts,
      skipFingerprints: emittedFingerprints,
    );

    results.addAll(remaining);
    debugPrint(
      '[MusicAlgorithmService] ranked ${results.length} radio tracks '
      'from ${candidates.length} candidates for seed "${seed.title}"',
    );
    return results.take(limit).toList();
  }

  // ==========================================
  // YOUTUBE QUERY GENERATION
  // ==========================================

  /// Generates intelligent YouTube search queries for recommendations and radio.
  /// Uses recently played, favorite artists, favorite tracks, search history,
  /// current track, artist, and genre.
  List<String> generateYouTubeQueries([
    Track? currentTrack,
    List<Track> history = const [],
    List<Track> favorites = const [],
    List<String> searchHistory = const [],
    String? currentGenre,
  ]) {
    final queries = <String>{};

    if (currentTrack != null) {
      final art = cleanArtist(currentTrack.artist);
      final tit = cleanTitle(currentTrack.title);
      if (art.isNotEmpty) {
        queries.add(art);
        queries.add('$art hits');
        queries.add('$art similar songs');
        queries.add('$tit radio');
      }
      if (currentTrack.genre.isNotEmpty && currentTrack.genre != 'Music') {
        queries.add(currentTrack.genre);
      }
    }

    final topArtist = _getTopArtist(history, favorites);
    if (topArtist != null && topArtist.isNotEmpty) {
      queries.add(topArtist);
      queries.add('$topArtist popular songs');
      final siblings = getSiblingArtists(topArtist, currentGenre);
      if (siblings.isNotEmpty) {
        queries.add(siblings.first);
      }
    }

    if (currentGenre != null && currentGenre.isNotEmpty && currentGenre != 'All') {
      queries.add('$currentGenre music');
    }

    for (final q in searchHistory.take(2)) {
      if (q.trim().isNotEmpty) queries.add(q.trim());
    }

    return queries.toList();
  }

  // ==========================================
  // HELPERS
  // ==========================================

  static String cleanArtist(String artist) {
    var result = artist
        .replaceAll(RegExp(r'\s*(feat\.|ft\.|featuring|with|&|,|x|\+).*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '')
        .trim();
    return result.isEmpty ? artist.trim() : result;
  }

  static String cleanTitle(String title) {
    var result = title
        .replaceAll(
          RegExp(
            r'\s*[\(\[](official\s*(music\s*)?video|official\s*audio|remastered|lyric\s*video|live|remix|acoustic|cover|instrumental|hd|4k)[\)\]]',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'-\s*(official\s*video|audio|lyrics?)$', caseSensitive: false), '')
        .trim();
    return result.isEmpty ? title.trim() : result;
  }

  static String _normalizeString(String str) {
    return str.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static bool _isReasonableDuration(Track track) {
    return track.durationSeconds == 0 ||
        (track.durationSeconds >= 45 && track.durationSeconds <= 600);
  }

  static List<String> getSiblingArtists(String artist, String? genre) {
    final artLower = artist.toLowerCase();

    for (final cluster in _genreArtistClusters.values) {
      if (cluster.any((name) => name.toLowerCase() == artLower || artLower.contains(name.toLowerCase()))) {
        return cluster.where((name) => name.toLowerCase() != artLower).toList();
      }
    }

    if (genre != null) {
      final genLower = genre.toLowerCase();
      if (genLower.contains('punjabi') || genLower.contains('desi')) {
        return _genreArtistClusters['punjabi_desi']!;
      }
      if (genLower.contains('hindi') || genLower.contains('bollywood')) {
        return _genreArtistClusters['bollywood_romance']!;
      }
      if (genLower.contains('phonk')) {
        return _genreArtistClusters['phonk']!;
      }
      if (genLower.contains('lofi') || genLower.contains('chill')) {
        return _genreArtistClusters['lofi']!;
      }
      if (genLower.contains('rock') || genLower.contains('metal')) {
        return _genreArtistClusters['rock_alt']!;
      }
      if (genLower.contains('edm') || genLower.contains('dance')) {
        return _genreArtistClusters['edm_dance']!;
      }
      if (genLower.contains('hip') || genLower.contains('rap')) {
        return _genreArtistClusters['hiphop_rap']!;
      }
    }

    return _genreArtistClusters['pop_soul']!;
  }
}

