import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/track.dart';
import '../repositories/track_repository.dart';

/// Intelligent Music Recommendation and Radio Queue Algorithm inspired by
/// YouTube Music, Spotify Radio, and Instagram Reels audio engines.
///
/// Given a seed track, this algorithm:
/// 1. Extracts the clean artist, title, and genre/mood cues.
/// 2. Queries related artist clusters, same-artist non-duplicate hits, and YouTube Music radio vectors.
/// 3. Strictly filters out duplicate/cover versions of the searched song title.
/// 4. Interleaves and randomizes recommendations with genre-affinity weighting for seamless playback.
class MusicAlgorithmService {
  final TrackRepository _repository;
  final Random _random = Random();

  MusicAlgorithmService({required TrackRepository repository})
      : _repository = repository;

  // Genre & Artist clustering matrix (Instagram / YouTube Music style)
  static const Map<String, List<String>> _genreArtistClusters = {
    // Soulful Pop / Ballads
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
    // Bollywood Romantic / Acoustic / Melody
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
    // Punjabi / Desi Hip-Hop & Pop
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
    // Synthwave / R&B / Modern Pop
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
    // Hip-Hop / Rap
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
    // EDM / Dance
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
    // Phonk / Drift / Bass
    'phonk': [
      'Kordhell',
      'Hensonn',
      'DVRST',
      'Ghostwriter',
      'SXID',
      'Pharmacist',
      'Playaphonk',
    ],
    // Lo-Fi / Chill / Study
    'lofi': [
      'Kijugo',
      'potsu',
      'Kupla',
      'idealism',
      'Jinsang',
      'lofi fruits',
      'ChilledCow',
    ],
    // Rock / Alternative / Indie
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
    // K-Pop
    'kpop': [
      'BTS',
      'BLACKPINK',
      'NewJeans',
      'Stray Kids',
      'TWICE',
      'FIFTY FIFTY',
      'LE SSERAFIM',
    ],
  };

  /// Generates a smart radio queue seeded by [seedTrack].
  /// Guaranteed NOT to be a wall of search-result duplicates of the same song title.
  Future<List<Track>> generateRadioQueue(
    Track seedTrack, {
    int targetCount = 14,
    Set<String>? excludedTrackIds,
  }) async {
    final cleanArt = cleanArtist(seedTrack.artist);
    final cleanTit = cleanTitle(seedTrack.title);
    final excludedIds = Set<String>.from(excludedTrackIds ?? {})..add(seedTrack.id);

    try {
      // Find related sibling artists
      final siblingArtists = getSiblingArtists(cleanArt, seedTrack.genre);
      final chosenSiblings = List<String>.from(siblingArtists)..shuffle(_random);
      final siblingA = chosenSiblings.isNotEmpty ? chosenSiblings[0] : null;
      final siblingB = chosenSiblings.length > 1 ? chosenSiblings[1] : null;

      // Concurrent multi-vector queries:
      // Vector 1: Same artist other hits (excluding current song title)
      // Vector 2: Primary sibling artist hits
      // Vector 3: Secondary sibling or genre radio mix
      // Vector 4: YouTube Music radio queue for this seed track
      final queries = <Future<List<Track>>>[
        _repository.searchTracks('$cleanArt top hits', limit: 8, provider: 'all').catchError((_) => <Track>[]),
        if (siblingA != null)
          _repository.searchTracks('$siblingA best songs', limit: 8, provider: 'all').catchError((_) => <Track>[]),
        if (siblingB != null)
          _repository.searchTracks('$siblingB hits', limit: 6, provider: 'all').catchError((_) => <Track>[])
        else
          _repository.searchTracks('${seedTrack.genre} trending', limit: 6, provider: 'all').catchError((_) => <Track>[]),
        _repository.searchTracks('$cleanArt - $cleanTit radio mix', limit: 10, provider: 'youtube').catchError((_) => <Track>[]),
      ];

      final results = await Future.wait(queries);

      final sameArtistPool = <Track>[];
      final siblingArtistPool = <Track>[];
      final radioMixPool = <Track>[];

      // Process Vector 1: Same artist pool
      if (results.isNotEmpty) {
        for (final t in results[0]) {
          if (_isSameSongTitle(cleanTit, cleanTitle(t.title))) continue; // Exclude duplicate song!
          if (excludedIds.contains(t.id)) continue;
          if (_isReasonableDuration(t)) {
            sameArtistPool.add(t);
          }
        }
      }

      // Process Vector 2 & 3: Sibling artist pools
      final siblingResults = results.length > 1 ? results.sublist(1, results.length - 1) : <List<Track>>[];
      for (final list in siblingResults) {
        for (final t in list) {
          if (_isSameSongTitle(cleanTit, cleanTitle(t.title))) continue;
          if (excludedIds.contains(t.id)) continue;
          if (_isReasonableDuration(t)) {
            siblingArtistPool.add(t);
          }
        }
      }

      // Process Vector 4: YouTube Radio mix
      if (results.isNotEmpty) {
        for (final t in results.last) {
          if (_isSameSongTitle(cleanTit, cleanTitle(t.title))) continue;
          if (excludedIds.contains(t.id)) continue;
          if (_isReasonableDuration(t)) {
            radioMixPool.add(t);
          }
        }
      }

      // Shuffle pools for freshness
      sameArtistPool.shuffle(_random);
      siblingArtistPool.shuffle(_random);
      radioMixPool.shuffle(_random);

      // Synthesize interleaved queue with artist diversity limits
      final curated = <Track>[];
      final seenNormalizedTitles = <String>{_normalizeString(cleanTit)};
      final artistTrackCount = <String, int>{
        cleanArt.toLowerCase(): 1, // seed track counts as 1
      };

      void tryAddTrack(Track candidate) {
        if (curated.length >= targetCount) return;
        if (excludedIds.contains(candidate.id)) return;

        final normTitle = _normalizeString(cleanTitle(candidate.title));
        if (seenNormalizedTitles.contains(normTitle)) return;

        final artKey = cleanArtist(candidate.artist).toLowerCase();
        final currentCount = artistTrackCount[artKey] ?? 0;
        // At most 2 tracks per artist in this queue window to preserve diversity
        if (currentCount >= 2) return;

        seenNormalizedTitles.add(normTitle);
        artistTrackCount[artKey] = currentCount + 1;
        excludedIds.add(candidate.id);
        curated.add(candidate);
      }

      // Interleave: Sibling -> Same Artist -> Radio Mix -> Sibling -> ...
      int sIdx = 0, aIdx = 0, rIdx = 0;
      while (curated.length < targetCount &&
          (sIdx < siblingArtistPool.length || aIdx < sameArtistPool.length || rIdx < radioMixPool.length)) {
        if (sIdx < siblingArtistPool.length) {
          tryAddTrack(siblingArtistPool[sIdx++]);
        }
        if (aIdx < sameArtistPool.length) {
          tryAddTrack(sameArtistPool[aIdx++]);
        }
        if (rIdx < radioMixPool.length) {
          tryAddTrack(radioMixPool[rIdx++]);
        }
      }

      // If still under target, relax artist cap to fill out queue
      final remainingPool = [...siblingArtistPool, ...sameArtistPool, ...radioMixPool]..shuffle(_random);
      for (final t in remainingPool) {
        if (curated.length >= targetCount) break;
        if (!excludedIds.contains(t.id)) {
          final norm = _normalizeString(cleanTitle(t.title));
          if (!seenNormalizedTitles.contains(norm)) {
            seenNormalizedTitles.add(norm);
            excludedIds.add(t.id);
            curated.add(t);
          }
        }
      }

      debugPrint('[MusicAlgorithmService] Generated ${curated.length} smart radio tracks for seed "${seedTrack.title}" by ${seedTrack.artist}');
      return curated;
    } catch (e) {
      debugPrint('[MusicAlgorithmService] generateRadioQueue error: $e');
      return [];
    }
  }

  /// Cleans artist name by stripping collaborations, featured tags, and punctuation.
  static String cleanArtist(String artist) {
    var result = artist
        .replaceAll(RegExp(r'\s*(feat\.|ft\.|featuring|with|&|,|x|\+).*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '')
        .trim();
    return result.isEmpty ? artist.trim() : result;
  }

  /// Cleans title by removing parenthetical metadata like "(Official Audio)", "(Live)", etc.
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

  /// Checks if two song titles represent essentially the same song.
  static bool _isSameSongTitle(String titleA, String titleB) {
    final a = _normalizeString(cleanTitle(titleA));
    final b = _normalizeString(cleanTitle(titleB));
    if (a == b) return true;
    if (a.isEmpty || b.isEmpty) return false;

    // Substring containment if long enough
    if (a.length >= 4 && b.contains(a)) return true;
    if (b.length >= 4 && a.contains(b)) return true;

    return false;
  }

  static String _normalizeString(String str) {
    return str.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static bool _isReasonableDuration(Track track) {
    // Keep tracks between 45 seconds and 10 minutes (exclude 10-sec clips or 1-hour DJ mixes)
    return track.durationSeconds == 0 ||
        (track.durationSeconds >= 45 && track.durationSeconds <= 600);
  }

  /// Finds sibling artists matching this artist or genre from the knowledge matrix.
  static List<String> getSiblingArtists(String artist, String? genre) {
    final artLower = artist.toLowerCase();

    // Check predefined clusters
    for (final cluster in _genreArtistClusters.values) {
      if (cluster.any((name) => name.toLowerCase() == artLower || artLower.contains(name.toLowerCase()))) {
        return cluster.where((name) => name.toLowerCase() != artLower).toList();
      }
    }

    // Genre-based fallback
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

    // Default global top recommendations
    return _genreArtistClusters['pop_soul']!;
  }
}
