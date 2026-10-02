import 'package:flutter_test/flutter_test.dart';
import 'package:gotune/models/track.dart';
import 'package:gotune/repositories/track_repository.dart';
import 'package:gotune/services/local_storage_service.dart';
import 'package:gotune/services/music_algorithm_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('GoTune Personal Recommendation Engine Tests', () {
    test('Cleans artist collaborations and featured tags properly', () {
      expect(MusicAlgorithmService.cleanArtist('Adele feat. John Legend'), 'Adele');
      expect(MusicAlgorithmService.cleanArtist('Arijit Singh, Shreya Ghoshal'), 'Arijit Singh');
      expect(MusicAlgorithmService.cleanArtist('Sidhu Moose Wala ft. Divine'), 'Sidhu Moose Wala');
      expect(MusicAlgorithmService.cleanArtist('The Weeknd with Daft Punk'), 'The Weeknd');
    });

    test('Cleans title metadata and parenthetical tags', () {
      expect(MusicAlgorithmService.cleanTitle('Lovesong (Official Music Video)'), 'Lovesong');
      expect(MusicAlgorithmService.cleanTitle('Tum Hi Ho [Remix]'), 'Tum Hi Ho');
      expect(MusicAlgorithmService.cleanTitle('Starboy (Live)'), 'Starboy');
      expect(MusicAlgorithmService.cleanTitle('Blinding Lights (Acoustic)'), 'Blinding Lights');
    });

    test('Finds genre & sibling artists correctly', () {
      final adeleSiblings = MusicAlgorithmService.getSiblingArtists('Adele', 'Pop');
      expect(adeleSiblings.contains('Sam Smith') || adeleSiblings.contains('Amy Winehouse'), isTrue);

      final arijitSiblings = MusicAlgorithmService.getSiblingArtists('Arijit Singh', 'Bollywood');
      expect(arijitSiblings.contains('Atif Aslam') || arijitSiblings.contains('Mohit Chauhan'), isTrue);

      final sidhuSiblings = MusicAlgorithmService.getSiblingArtists('Sidhu Moose Wala', 'Punjabi');
      expect(sidhuSiblings.contains('Karan Aujla') || sidhuSiblings.contains('Diljit Dosanjh'), isTrue);
    });

    test('Generates targeted YouTube search queries for algorithm discovery', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.init();
      final repo = TrackRepository(storageService: storage);
      final algorithm = MusicAlgorithmService(repository: repo);

      const currentSong = Track(
        id: 'yt_bl',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        genre: 'Synthpop',
      );

      final queries = algorithm.generateYouTubeQueries(currentSong);
      expect(queries, isNotEmpty);
      expect(queries, contains('The Weeknd'));
      expect(queries.any((q) => q.contains('The Weeknd')), isTrue);
      expect(queries.any((q) => q.contains('Blinding Lights')), isTrue);
    });

    test('Calculates deterministic recommendation score correctly with exact weights', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.init();
      final repo = TrackRepository(storageService: storage);
      final algorithm = MusicAlgorithmService(repository: repo);

      const favoriteTrack = Track(
        id: 'fav_1',
        title: 'Rolling in the Deep',
        artist: 'Adele',
        genre: 'Pop',
        playCount: 500000,
      );

      const candidateA = Track(
        id: 'cand_1',
        title: 'Someone Like You',
        artist: 'Adele',
        genre: 'Pop',
        playCount: 1000000,
      );

      const candidateB = Track(
        id: 'cand_2',
        title: 'Random Track',
        artist: 'Unknown Singer',
        genre: 'Heavy Metal',
        playCount: 10,
      );

      final scoreA = algorithm.calculateScore(
        candidate: candidateA,
        history: [favoriteTrack],
        favorites: [favoriteTrack],
        seedTrack: favoriteTrack,
      );

      final scoreB = algorithm.calculateScore(
        candidate: candidateB,
        history: [favoriteTrack],
        favorites: [favoriteTrack],
        seedTrack: favoriteTrack,
      );

      expect(scoreA, greaterThan(scoreB));
      expect(scoreA, inInclusiveRange(0.0, 1.0));
      expect(scoreB, inInclusiveRange(0.0, 1.0));
    });

    test('Generates personalized mixes locally from history & library', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.init();
      final repo = TrackRepository(storageService: storage);
      final algorithm = MusicAlgorithmService(repository: repo);

      final history = [
        const Track(id: 't1', title: 'Kesariya', artist: 'Arijit Singh', genre: 'Bollywood'),
        const Track(id: 't2', title: 'Apna Bana Le', artist: 'Arijit Singh', genre: 'Bollywood'),
        const Track(id: 't3', title: 'Blinding Lights', artist: 'The Weeknd', genre: 'Pop'),
      ];

      final favorites = [
        const Track(id: 't1', title: 'Kesariya', artist: 'Arijit Singh', genre: 'Bollywood'),
      ];

      final mixes = await algorithm.generatePersonalizedMixes(
        history: history,
        favorites: favorites,
        catalogPool: history,
      );

      expect(mixes.length, 5);
      final mixIds = mixes.map((m) => m.id).toList();
      expect(mixIds, containsAll(['my_mix', 'recent_mix', 'favorites_mix', 'discovery_mix', 'artist_mix']));
    });

    test('Ranks externally discovered radio candidates with diversity caps', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.init();
      final repo = TrackRepository(storageService: storage);

      final algorithm = MusicAlgorithmService(repository: repo);
      const seed = Track(
        id: 'seed_1',
        title: 'Lovesong',
        artist: 'Adele',
        genre: 'Pop',
        durationSeconds: 240,
        source: 'youtube',
      );

      const candidates = [
        Track(id: 'c1', title: 'Hello', artist: 'Adele', genre: 'Pop', durationSeconds: 200),
        Track(id: 'c2', title: 'Easy On Me', artist: 'Adele', genre: 'Pop', durationSeconds: 215),
        Track(id: 'c3', title: 'Someone Like You', artist: 'Adele', genre: 'Pop', durationSeconds: 240),
        Track(id: 'c4', title: 'Blinding Lights', artist: 'The Weeknd', genre: 'Pop', durationSeconds: 200),
        Track(id: 'c5', title: 'Levitating', artist: 'Dua Lipa', genre: 'Pop', durationSeconds: 203),
        Track(id: 'c6', title: 'Lovesong', artist: 'Adele', genre: 'Pop', durationSeconds: 210),
        Track(id: 'c7', title: 'Intro Sting', artist: 'Unknown', genre: 'Pop', durationSeconds: 4),
      ];

      final queue = await algorithm.rankCandidates(
        candidates: candidates,
        seed: seed,
        limit: 8,
        maxPerArtist: 2,
      );

      expect(queue, isNotEmpty);
      expect(queue.any((t) => t.id == 'seed_1'), isFalse, reason: 'Seed must never be queued');

      for (final track in queue) {
        expect(
          track.title.toLowerCase().trim() == 'lovesong',
          isFalse,
          reason: 'Ranking must not return duplicates of seed song: ${track.title}',
        );
        expect(
          track.durationSeconds >= 45,
          isTrue,
          reason: 'Implausible durations must be filtered: ${track.title}',
        );
      }

      final perArtist = <String, int>{};
      for (final track in queue) {
        perArtist[track.artist] = (perArtist[track.artist] ?? 0) + 1;
      }
      expect(perArtist.values.every((count) => count <= 2), isTrue);
    });

    test('Radio ranking is pure: identical candidates yield identical order', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.init();
      final repo = TrackRepository(storageService: storage);

      final algorithm = MusicAlgorithmService(repository: repo);
      const seed = Track(id: 'seed', title: 'Lovesong', artist: 'Adele', genre: 'Pop');
      const candidates = [
        Track(id: 'c1', title: 'Hello', artist: 'Adele', genre: 'Pop'),
        Track(id: 'c2', title: 'Blinding Lights', artist: 'The Weeknd', genre: 'Pop'),
      ];

      final first = await algorithm.rankCandidates(candidates: candidates, seed: seed, limit: 5);
      final second = await algorithm.rankCandidates(candidates: candidates, seed: seed, limit: 5);

      expect(first.map((t) => t.id).toList(), second.map((t) => t.id).toList());
    });
  });
}
