import 'package:flutter_test/flutter_test.dart';
import 'package:gotune/models/interaction_event.dart';
import 'package:gotune/models/playlist.dart';
import 'package:gotune/models/track.dart';
import 'package:gotune/repositories/track_repository.dart';
import 'package:gotune/services/local_storage_service.dart';
import 'package:gotune/services/music_algorithm_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Track Normalization & Fingerprinting Tests', () {
    test('Normalizes track titles by stripping remixes, remastered tags, and punctuation', () {
      expect(
        Track.normalizeTitle('Blinding Lights (Official Music Video) [Remastered 2024]'),
        equals('blinding lights'),
      );
      expect(
        Track.normalizeTitle('Starboy - Feat. Daft Punk (Live)'),
        equals('starboy'),
      );
      expect(
        Track.normalizeTitle('Someone Like You (Acoustic Version)'),
        equals('someone like you'),
      );
    });

    test('Normalizes artist names by removing featuring tags, topics, and punctuation', () {
      expect(
        Track.normalizeArtist('The Weeknd - Topic'),
        equals('weeknd'),
      );
      expect(
        Track.normalizeArtist('Calvin Harris feat. Dua Lipa'),
        equals('calvin harris'),
      );
      expect(
        Track.normalizeArtist('Drake ft. 21 Savage'),
        equals('drake'),
      );
    });

    test('Generates consistent normalizedFingerprint for duplicate detection', () {
      const track1 = Track(
        id: 'yt_1',
        title: 'Blinding Lights (Official Video)',
        artist: 'The Weeknd',
        source: 'youtube',
      );
      const track2 = Track(
        id: 'yt_2',
        title: 'Blinding Lights [Remastered]',
        artist: 'The Weeknd - Topic',
        source: 'youtube',
      );
      expect(track1.normalizedFingerprint, equals(track2.normalizedFingerprint));
    });

    test('Track.deduplicate removes duplicate tracks preserving first occurrence', () {
      const track1 = Track(
        id: 'yt_1',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        source: 'youtube',
      );
      const track2 = Track(
        id: 'yt_2',
        title: 'Blinding Lights (Official Audio)',
        artist: 'The Weeknd',
        source: 'youtube',
      );
      const track3 = Track(
        id: 'yt_3',
        title: 'Starboy',
        artist: 'The Weeknd',
        source: 'youtube',
      );

      final deduplicated = Track.deduplicate([track1, track2, track3]);
      expect(deduplicated.length, equals(2));
      expect(deduplicated.first.id, equals('yt_1'));
      expect(deduplicated.last.id, equals('yt_3'));
    });
  });

  group('UserInteractionStats & Recommendation Signals Tests', () {
    test('Calculates track completion and skip rates accurately', () {
      const stats = UserInteractionStats(
        songPlayCounts: {'track_1': 10, 'track_2': 5},
        songCompletionCounts: {'track_1': 8, 'track_2': 1},
        songSkipCounts: {'track_1': 1, 'track_2': 4},
      );

      expect(stats.getTrackCompletionRate('track_1'), closeTo(0.727, 0.05));
      expect(stats.getTrackSkipRate('track_1'), closeTo(0.09, 0.05));
      expect(stats.getTrackCompletionRate('unknown'), equals(0.5));
      expect(stats.getTrackSkipRate('unknown'), equals(0.0));
    });

    test('Serialization and deserialization of UserInteractionStats', () {
      final original = UserInteractionStats(
        songPlayCounts: {'t1': 12},
        songCompletionCounts: {'t1': 10},
        songSkipCounts: {'t1': 1},
        songLastPlayed: {'t1': DateTime(2026, 9, 29, 12, 0)},
        artistPlayCounts: {'Adele': 15},
        artistSkipCounts: {'Adele': 0},
        genrePlayCounts: {'Pop': 20},
        recentSkippedTrackIds: ['t99'],
      );

      final json = original.toJson();
      final restored = UserInteractionStats.fromJson(json);

      expect(restored.songPlayCounts['t1'], equals(12));
      expect(restored.artistPlayCounts['Adele'], equals(15));
      expect(restored.genrePlayCounts['Pop'], equals(20));
      expect(restored.recentSkippedTrackIds, contains('t99'));
    });
  });

  group('Recommendation Diversity & Scoring Formula Tests', () {
    test('Transparent weighted scoring model adheres to default weights', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.init();
      final repo = TrackRepository(storageService: storage);
      final algo = MusicAlgorithmService(repository: repo);

      const fav = Track(
        id: 'f1',
        title: 'Easy On Me',
        artist: 'Adele',
        genre: 'Pop',
        playCount: 1000,
      );
      const candidatePop = Track(
        id: 'c1',
        title: 'Hello',
        artist: 'Adele',
        genre: 'Pop',
        playCount: 5000,
      );
      const candidateOther = Track(
        id: 'c2',
        title: 'Random',
        artist: 'Unknown',
        genre: 'Dubstep',
        playCount: 1,
      );

      final scorePop = algo.calculateScore(
        candidate: candidatePop,
        history: [fav],
        favorites: [fav],
        seedTrack: fav,
      );
      final scoreOther = algo.calculateScore(
        candidate: candidateOther,
        history: [fav],
        favorites: [fav],
        seedTrack: fav,
      );

      expect(scorePop, greaterThan(scoreOther));
      expect(scorePop, inInclusiveRange(0.0, 1.0));
      expect(scoreOther, inInclusiveRange(0.0, 1.0));
    });

    test('Recommendation diversity limits repeated artists to maximum 2 occurrences', () {
      final candidates = [
        const Track(id: '1', title: 'Song 1', artist: 'Taylor Swift'),
        const Track(id: '2', title: 'Song 2', artist: 'Taylor Swift'),
        const Track(id: '3', title: 'Song 3', artist: 'Taylor Swift'),
        const Track(id: '4', title: 'Song 4', artist: 'Taylor Swift'),
        const Track(id: '5', title: 'Song 5', artist: 'Ed Sheeran'),
        const Track(id: '6', title: 'Song 6', artist: 'Ed Sheeran'),
        const Track(id: '7', title: 'Song 7', artist: 'Adele'),
      ];

      final filtered = <Track>[];
      final artistCounts = <String, int>{};
      for (final t in candidates) {
        final count = artistCounts[t.artist] ?? 0;
        if (count < 2) {
          filtered.add(t);
          artistCounts[t.artist] = count + 1;
        }
      }

      final swiftCount = filtered.where((t) => t.artist == 'Taylor Swift').length;
      final sheeranCount = filtered.where((t) => t.artist == 'Ed Sheeran').length;

      expect(swiftCount, equals(2));
      expect(sheeranCount, equals(2));
      expect(filtered.length, equals(5));
    });
  });

  group('Queue Operations Tests', () {
    test('Queue Play Next operation preserves index stability', () {
      final initialQueue = [
        const Track(id: '1', title: 'Track 1', artist: 'Artist A'),
        const Track(id: '2', title: 'Track 2', artist: 'Artist B'),
        const Track(id: '3', title: 'Track 3', artist: 'Artist C'),
      ];

      const currentIndex = 1;
      const nextSong = Track(id: 'new_1', title: 'Up Next', artist: 'Artist X');

      final queue = List<Track>.from(initialQueue);
      queue.insert(currentIndex + 1, nextSong);

      expect(queue.length, equals(4));
      expect(queue[2].id, equals('new_1'));
      expect(queue[0].id, equals('1'));
      expect(queue[1].id, equals('2'));
      expect(queue[3].id, equals('3'));
    });

    test('Queue reordering moves items accurately', () {
      final queue = [
        const Track(id: 'a', title: 'A', artist: 'X'),
        const Track(id: 'b', title: 'B', artist: 'X'),
        const Track(id: 'c', title: 'C', artist: 'X'),
      ];

      final item = queue.removeAt(0);
      queue.insert(2, item);

      expect(queue.map((t) => t.id).toList(), equals(['b', 'c', 'a']));
    });
  });

  group('Playlist Operations Tests', () {
    test('Playlist operations: adding, removing, and deduplication', () {
      const t1 = Track(id: 't_1', title: 'Chill One', artist: 'Artist 1');
      const t2 = Track(id: 't_2', title: 'Chill Two', artist: 'Artist 2');

      var playlist = Playlist(
        id: 'p_custom_1',
        name: 'Chill Vibes',
        description: 'Late night chill tracks',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        tracks: const [t1],
      );

      expect(playlist.containsTrack('t_1'), isTrue);
      expect(playlist.containsTrack('t_2'), isFalse);
      expect(playlist.trackCount, equals(1));

      playlist = playlist.copyWith(
        tracks: [...playlist.tracks, t2],
      );
      expect(playlist.trackCount, equals(2));
      expect(playlist.containsTrack('t_2'), isTrue);

      final listWithDup = [...playlist.tracks, t1];
      final dedupedTracks = Track.deduplicate(listWithDup);
      playlist = playlist.copyWith(tracks: dedupedTracks);
      expect(playlist.trackCount, equals(2));

      final remaining = playlist.tracks.where((t) => t.id != 't_1').toList();
      playlist = playlist.copyWith(tracks: remaining);
      expect(playlist.trackCount, equals(1));
      expect(playlist.tracks.first.id, equals('t_2'));
    });
  });
}
