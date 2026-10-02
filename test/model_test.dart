import 'package:flutter_test/flutter_test.dart';
import 'package:gotune/models/playlist.dart';
import 'package:gotune/models/recently_played_item.dart';
import 'package:gotune/models/track.dart';
import 'package:gotune/utils/duration_formatter.dart';

void main() {
  group('DurationFormatter Tests', () {
    test('formats seconds to mm:ss correctly', () {
      expect(DurationFormatter.formatSeconds(0), '0:00');
      expect(DurationFormatter.formatSeconds(59), '0:59');
      expect(DurationFormatter.formatSeconds(60), '1:00');
      expect(DurationFormatter.formatSeconds(215), '3:35');
      expect(DurationFormatter.formatSeconds(3661), '1:01:01');
    });

    test('formats compact numbers', () {
      expect(DurationFormatter.formatCompactNumber(500), '500');
      expect(DurationFormatter.formatCompactNumber(1500), '1.5K');
      expect(DurationFormatter.formatCompactNumber(2500000), '2.5M');
    });
  });

  group('Track Model Tests', () {
    test('parses YouTube JSON properly', () {
      final sampleJson = {
        'id': 'test_track_123',
        'videoId': 'test_track_123',
        'title': 'Starlight Echoes',
        'genre': 'Electronic',
        'lengthSeconds': 180,
        'author': 'Nova Beats',
        'videoThumbnails': [
          {'url': 'https://example.com/art_150.jpg'},
          {'url': 'https://example.com/art_480.jpg'},
        ],
      };

      final track = Track.fromYouTubeJson(sampleJson);
      expect(track.id, 'test_track_123');
      expect(track.youtubeVideoId, 'test_track_123');
      expect(track.title, 'Starlight Echoes');
      expect(track.artist, 'Nova Beats');
      expect(track.bestArtworkUrl, 'https://example.com/art_480.jpg');
      expect(track.formattedDuration, '3:00');
      expect(track.isYouTubeIframe, isTrue);
    });

    test('serializes and deserializes to JSON correctly', () {
      const original = Track(
        id: 'track_99',
        title: 'Cyberpunk Synth',
        artist: 'Retrowave',
        durationSeconds: 240,
        genre: 'Synthwave',
      );

      final json = original.toJson();
      final restored = Track.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.artist, original.artist);
      expect(restored.durationSeconds, original.durationSeconds);
    });
  });

  group('Playlist Model Tests', () {
    test('calculates duration and prevents duplicates', () {
      const track1 = Track(id: 't1', title: 'Song 1', artist: 'Artist 1', durationSeconds: 120);
      const track2 = Track(id: 't2', title: 'Song 2', artist: 'Artist 2', durationSeconds: 180);

      final playlist = Playlist(
        id: 'pl_1',
        name: 'My Chill Mix',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        tracks: const [track1, track2],
      );

      expect(playlist.trackCount, 2);
      expect(playlist.totalDurationSeconds, 300);
      expect(playlist.formattedTotalDuration, '5:00');
      expect(playlist.containsTrack('t1'), true);
      expect(playlist.containsTrack('t3'), false);
    });

    test('serializes and deserializes playlist JSON correctly', () {
      const track1 = Track(id: 't1', title: 'Song 1', artist: 'Artist 1', durationSeconds: 120);
      final original = Playlist(
        id: 'pl_99',
        name: 'Workout Beats',
        description: 'High energy tracks',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
        tracks: const [track1],
      );

      final json = original.toJson();
      final restored = Playlist.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.description, original.description);
      expect(restored.trackCount, 1);
      expect(restored.tracks.first.id, 't1');
    });
  });

  group('RecentlyPlayedItem Model Tests', () {
    test('serializes and provides relative time', () {
      const track = Track(id: 't_recent', title: 'Midnight', artist: 'Luna', durationSeconds: 200);
      final item = RecentlyPlayedItem(
        track: track,
        playedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      expect(item.relativeTime, '5m ago');

      final json = item.toJson();
      final restored = RecentlyPlayedItem.fromJson(json);
      expect(restored.track.id, 't_recent');
    });
  });

  group('Queue Operations Logic Tests', () {
    test('Play Next inserts track immediately after current index', () {
      final queue = <String>['track_A', 'track_B', 'track_C'];
      const currentIndex = 0; // playing track_A

      const newTrack = 'track_INSERTED';
      const insertIndex = currentIndex + 1;
      queue.insert(insertIndex, newTrack);

      expect(queue, ['track_A', 'track_INSERTED', 'track_B', 'track_C']);
      expect(queue[1], 'track_INSERTED');
    });

    test('Reordering queue preserves integrity', () {
      final queue = <String>['track_1', 'track_2', 'track_3', 'track_4'];
      // Move track_1 (oldIndex 0) to after track_3 (newIndex 3)
      const oldIndex = 0;
      int newIndex = 3;
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = queue.removeAt(oldIndex);
      queue.insert(newIndex, item);

      expect(queue, ['track_2', 'track_3', 'track_1', 'track_4']);
    });
  });

  group('Phase 4: Smart Shuffle Logic Tests', () {
    test('Smart shuffle retains current track at index 0 and shuffles upcoming tracks', () {
      final originalQueue = ['song_current', 'song_1', 'song_2', 'song_3', 'song_4'];
      const currentIndex = 0;
      final currentTrack = originalQueue[currentIndex];

      final upcoming = List<String>.from(originalQueue)..removeAt(currentIndex);
      upcoming.shuffle();
      final shuffledQueue = [currentTrack, ...upcoming];

      // Current track must still be at index 0
      expect(shuffledQueue[0], 'song_current');
      // Total count must be equal
      expect(shuffledQueue.length, originalQueue.length);
      // All tracks present
      expect(shuffledQueue.toSet(), originalQueue.toSet());
    });

    test('Restoring un-shuffled queue recovers original track order', () {
      final originalQueue = ['track_A', 'track_B', 'track_C', 'track_D'];
      final unshuffledSaved = List<String>.from(originalQueue);

      // Suppose we shuffled and played
      const shuffled = ['track_B', 'track_D', 'track_A', 'track_C'];
      const activeTrack = 'track_C';
      expect(shuffled.contains(activeTrack), true);

      // Restore original
      final restored = List<String>.from(unshuffledSaved);
      final newIndex = restored.indexOf(activeTrack);

      expect(restored, ['track_A', 'track_B', 'track_C', 'track_D']);
      expect(newIndex, 2);
    });
  });

  group('Phase 4: Repeat Mode Cycle Tests', () {
    test('Repeat mode cycles through none -> one -> all -> none', () {
      int mode = 0; // 0: none, 1: one, 2: all

      int cycle(int current) {
        switch (current) {
          case 0:
            return 1; // one
          case 1:
            return 2; // all
          case 2:
          default:
            return 0; // none
        }
      }

      mode = cycle(mode);
      expect(mode, 1, reason: 'First cycle should be Repeat One (current track)');
      mode = cycle(mode);
      expect(mode, 2, reason: 'Second cycle should be Repeat All (queue)');
      mode = cycle(mode);
      expect(mode, 0, reason: 'Third cycle should be Repeat Off (none)');
    });
  });

  group('Phase 4: Sleep Timer Formatting Tests', () {
    String formatTimer(Duration d) {
      final minutes = d.inMinutes;
      final seconds = d.inSeconds % 60;
      if (minutes >= 60) {
        final hours = minutes ~/ 60;
        final remMinutes = minutes % 60;
        return '${hours}h ${remMinutes}m';
      }
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }

    test('formats sleep timer countdown durations correctly', () {
      expect(formatTimer(const Duration(minutes: 5)), '05:00');
      expect(formatTimer(const Duration(minutes: 10, seconds: 30)), '10:30');
      expect(formatTimer(const Duration(minutes: 45)), '45:00');
      expect(formatTimer(const Duration(minutes: 60)), '1h 0m');
      expect(formatTimer(const Duration(minutes: 90)), '1h 30m');
    });
  });

  group('Phase 4: Search History Deduplication Tests', () {
    test('Deduplicates case-insensitively and puts newest query first', () {
      final history = <String>['Chill Beats', 'Synthwave', 'EDM'];

      void addQuery(String query) {
        final trimmed = query.trim();
        if (trimmed.isEmpty) return;
        history.removeWhere((q) => q.toLowerCase() == trimmed.toLowerCase());
        history.insert(0, trimmed);
        if (history.length > 20) {
          history.removeRange(20, history.length);
        }
      }

      addQuery('synthwave'); // lowercase of existing
      expect(history, ['synthwave', 'Chill Beats', 'EDM']);

      addQuery('Lofi');
      expect(history, ['Lofi', 'synthwave', 'Chill Beats', 'EDM']);

      addQuery('Chill Beats');
      expect(history, ['Chill Beats', 'Lofi', 'synthwave', 'EDM']);
    });
  });
}

