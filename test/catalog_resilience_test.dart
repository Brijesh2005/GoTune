import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gotune/models/album.dart';
import 'package:gotune/models/artist.dart';
import 'package:gotune/models/music_content.dart';
import 'package:gotune/models/playlist.dart';
import 'package:gotune/models/track.dart';
import 'package:gotune/services/music_cache_service.dart';
import 'package:gotune/services/music_catalog_aggregator.dart';
import 'package:gotune/services/music_catalog_provider.dart';
import 'package:gotune/services/provider_execution.dart';

/// Scriptable provider whose behaviour is fully controlled by the test, so
/// aggregation, isolation, fallback and diagnostics can be asserted without
/// touching the network.
class ScriptedCatalogProvider implements MusicCatalogProvider {
  @override
  final String providerId;
  @override
  final String displayName;

  /// Delay applied to every call, used to prove concurrency.
  final Duration latency;

  /// Thrown by every call when set.
  final Object? failure;

  /// Never completes when true, used to exercise the hard timeout.
  final bool hang;

  final List<Track> tracks;
  final List<Artist> artists;
  final List<Album> albums;
  final Track? detailTrack;
  final Artist? detailArtist;

  int _calls = 0;

  /// Number of provider calls observed, used to assert caching and retry.
  int get callCount => _calls;

  ScriptedCatalogProvider({
    required this.providerId,
    String? displayName,
    this.latency = Duration.zero,
    this.failure,
    this.hang = false,
    this.tracks = const [],
    this.artists = const [],
    this.albums = const [],
    this.detailTrack,
    this.detailArtist,
  }) : displayName = displayName ?? providerId;

  Future<void> _enter() async {
    _calls++;
    if (latency > Duration.zero) {
      await Future<void>.delayed(latency);
    }
    if (hang) {
      // Never completes: the invoker's timeout must break this.
      await Completer<void>().future;
    }
    final error = failure;
    if (error != null) throw error;
  }

  @override
  bool get isPlayable => true;

  @override
  Future<List<Track>> searchTracks(String query, {int limit = 20, int page = 1}) async {
    await _enter();
    return tracks.take(limit).toList();
  }

  @override
  Future<List<Track>> getTrendingTracks({String? genre, int limit = 20, int page = 1}) async {
    await _enter();
    return tracks.take(limit).toList();
  }

  @override
  Future<List<Track>> getArtistTracks(String artistIdOrName, {int limit = 20}) async {
    await _enter();
    return tracks.take(limit).toList();
  }

  @override
  Future<List<Track>> getRelatedTracks(Track track, {int limit = 15}) async {
    await _enter();
    return tracks.take(limit).toList();
  }

  @override
  Future<Track?> getTrackById(String id) async {
    await _enter();
    // Resolves only its own id, so an unknown id is a genuine miss.
    return detailTrack != null && detailTrack!.id == id ? detailTrack : null;
  }


  @override
  Future<List<Artist>> searchArtists(String query, {int limit = 15}) async {
    await _enter();
    return artists.take(limit).toList();
  }

  @override
  Future<List<Album>> searchAlbums(String query, {int limit = 15}) async {
    await _enter();
    return albums.take(limit).toList();
  }

  @override
  Future<Artist?> getArtistDetails(String artistId) async {
    await _enter();
    return detailArtist;
  }

  @override
  Future<Album?> getAlbumDetails(String albumId) async => null;

  @override
  Future<List<Track>> getPopularTracks({int limit = 20}) async {
    await _enter();
    return tracks.take(limit).toList();
  }

  @override
  Future<List<Track>> getNewReleases({int limit = 20}) async {
    await _enter();
    return tracks.take(limit).toList();
  }
}

Track _track(
  String id,
  String title,
  String artist, {
  String provider = 'test',
  String? streamUrl,
  DateTime? releaseDate,
  String genre = 'Pop',
}) {
  return Track(
    id: id,
    title: title,
    artist: artist,
    genre: genre,
    provider: provider,
    releaseDate: releaseDate,
    durationSeconds: 200,
  );
}

void main() {
  late MusicCacheService cache;

  // MusicDiagnostics is a process-wide singleton; each test starts from a
  // clean slate rather than its own instance.
  final diagnostics = MusicDiagnostics.instance;

  setUp(() {
    cache = MusicCacheService();
    cache.clear();
    diagnostics.clear();
  });

  group('Concurrent fan-out', () {
    test('a slow provider does not delay the others', () async {
      final slow = ScriptedCatalogProvider(
        providerId: 'slow',
        latency: const Duration(milliseconds: 600),
        tracks: [_track('slow_1', 'Slow Song', 'Slow Artist', provider: 'slow')],
      );
      final fast = ScriptedCatalogProvider(
        providerId: 'fast',
        tracks: [_track('fast_1', 'Fast Song', 'Fast Artist', provider: 'fast')],
      );

      final aggregator = MusicCatalogAggregator(
        adapters: [slow, fast],
        cache: cache,
        invoker: ProviderInvoker(diagnostics: diagnostics),
      );

      final stopwatch = Stopwatch()..start();
      final results = await aggregator.searchTracks('song');
      stopwatch.stop();

      expect(results.length, 2);
      // A 600ms provider plus a 0ms provider must cost roughly one slow call,
      // not their sum — proving the fan-out is genuinely concurrent.
      expect(stopwatch.elapsedMilliseconds, lessThan(1400));
    });

    test('every provider is invoked, not just the first', () async {
      final a = ScriptedCatalogProvider(providerId: 'a', tracks: [_track('a1', 'A', 'Ar', provider: 'a')]);
      final b = ScriptedCatalogProvider(providerId: 'b', tracks: [_track('b1', 'B', 'Br', provider: 'b')]);
      final c = ScriptedCatalogProvider(providerId: 'c', tracks: [_track('c1', 'C', 'Cr', provider: 'c')]);

      final aggregator = MusicCatalogAggregator(
        adapters: [a, b, c],
        cache: cache,
        invoker: ProviderInvoker(diagnostics: diagnostics),
      );

      final results = await aggregator.searchTracks('x');
      expect(results.length, 3);
      expect(a.callCount, 1);
      expect(b.callCount, 1);
      expect(c.callCount, 1);
    });

    test('artist and album search merge every provider instead of first-hit wins', () async {
      final a = ScriptedCatalogProvider(
        providerId: 'a',
        artists: const [Artist(id: 'a_artist', name: 'Alpha', provider: 'a')],
      );
      final b = ScriptedCatalogProvider(
        providerId: 'b',
        artists: const [Artist(id: 'b_artist', name: 'Beta', provider: 'b')],
      );

      final aggregator = MusicCatalogAggregator(
        adapters: [a, b],
        cache: cache,
        invoker: ProviderInvoker(diagnostics: diagnostics),
      );

      final artists = await aggregator.searchArtists('al');
      expect(artists.map((x) => x.name), containsAll(<String>['Alpha', 'Beta']));
    });

    test('an album from the first provider does not suppress later providers', () async {
      final a = ScriptedCatalogProvider(
        providerId: 'a',
        albums: const [Album(id: 'a_alb', name: 'First', artist: 'X', provider: 'a')],
      );
      final b = ScriptedCatalogProvider(
        providerId: 'b',
        albums: const [Album(id: 'b_alb', name: 'Second', artist: 'Y', provider: 'b')],
      );

      final aggregator = MusicCatalogAggregator(
        adapters: [a, b],
        cache: cache,
        invoker: ProviderInvoker(diagnostics: diagnostics),
      );

      final albums = await aggregator.searchAlbums('x');
      expect(albums.length, 2);
    });
  });

  group('Error isolation and fallback', () {
    test('one failing provider never fails the aggregated call', () async {
      final good = ScriptedCatalogProvider(
        providerId: 'good',
        tracks: [_track('g1', 'Good Song', 'Good Artist', provider: 'good')],
      );
      final bad = ScriptedCatalogProvider(
        providerId: 'bad',
        failure: StateError('catalog offline'),
      );

      final aggregator = MusicCatalogAggregator(
        adapters: [bad, good],
        cache: cache,
        invoker: ProviderInvoker(diagnostics: diagnostics),
      );

      final results = await aggregator.searchTracks('song');
      expect(results.length, 1);
      expect(results.single.id, 'g1');
    });

    test('a hanging provider is cut off by the hard timeout', () async {
      final hung = ScriptedCatalogProvider(providerId: 'hung', hang: true);
      final healthy = ScriptedCatalogProvider(
        providerId: 'healthy',
        tracks: [_track('h1', 'Song', 'Artist', provider: 'healthy')],
      );

      final aggregator = MusicCatalogAggregator(
        adapters: [hung, healthy],
        cache: cache,
        invoker: ProviderInvoker(diagnostics: diagnostics),
      );

      final stopwatch = Stopwatch()..start();
      final results = await aggregator.searchTracks('song');
      stopwatch.stop();

      expect(results.length, 1);
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(ProviderExecutionPolicy.discovery.timeout.inMilliseconds * 3),
      );
      expect(diagnostics.healthFor('hung', 'hung').timeoutCount, greaterThan(0));
    });

    test('a transient failure is recovered by retry', () async {
      final flaky = _FlakyProvider(
        providerId: 'flaky',
        failuresRemaining: 1,
        tracks: [_track('f1', 'Song', 'Artist', provider: 'flaky')],
      );

      final aggregator = MusicCatalogAggregator(
        adapters: [flaky],
        cache: cache,
        invoker: ProviderInvoker(diagnostics: diagnostics),
      );

      final results = await aggregator.searchTracks('song');
      expect(results.length, 1);
      expect(diagnostics.totalRecoveredByRetry, greaterThan(0));
      expect(flaky.callCount, 2);
    });

    test('stale cache is served when every provider fails', () async {
      const key = '${MusicCacheService.nsAggregatedSearch}::stale::all::25';

      // Seed a fresh cache entry, then let it expire.
      cache.set(key, <Track>[_track('cached_1', 'Cached', 'Cached Artist')], ttl: const Duration(milliseconds: 40));
      await Future<void>.delayed(const Duration(milliseconds: 90));

      final failing = ScriptedCatalogProvider(
        providerId: 'failing',
        failure: StateError('all down'),
      );
      final aggregator = MusicCatalogAggregator(
        adapters: [failing],
        cache: cache,
        invoker: ProviderInvoker(diagnostics: diagnostics),
      );

      final results = await aggregator.searchTracks('stale');
      expect(results.length, 1);
      expect(results.single.id, 'cached_1');
      expect(diagnostics.totalStaleCacheServes, 1);
    });

    test('a fresh cache entry is returned without any provider call', () async {
      final provider = ScriptedCatalogProvider(
        providerId: 'p',
        tracks: [_track('p1', 'Song', 'Artist', provider: 'p')],
      );
      final aggregator = MusicCatalogAggregator(
        adapters: [provider],
        cache: cache,
        invoker: ProviderInvoker(diagnostics: diagnostics),
      );

      await aggregator.searchTracks('cached query');
      expect(provider.callCount, 1);

      await aggregator.searchTracks('cached query');
      expect(provider.callCount, 1, reason: 'Second call must be served from cache');
    });
  });

  group('Normalization and deduplication', () {
    test('identical tracks from different providers merge into one source list', () async {
      final providerALike = ScriptedCatalogProvider(
        providerId: 'provider_a',
        tracks: [_track('s1', 'Same Song', 'Same Artist', provider: 'provider_a', streamUrl: 'https://a/1.mp3')],
      );
      final providerBLike = ScriptedCatalogProvider(
        providerId: 'provider_b',
        tracks: [_track('a1', 'Same Song', 'Same Artist', provider: 'provider_b', streamUrl: 'https://b/1.mp3')],
      );

      final aggregator = MusicCatalogAggregator(
        adapters: [providerALike, providerBLike],
        cache: cache,
        invoker: ProviderInvoker(diagnostics: diagnostics),
      );

      final results = await aggregator.searchTracks('same song');
      expect(results.length, 1);
      expect(results.single.title, 'Same Song');
    });

    test('every content type exposes a stable, namespaced content key', () {
      const track = Track(id: 't1', title: 'T', artist: 'A', provider: 'youtube');
      const artist = Artist(id: 'ar1', name: 'A', provider: 'youtube');
      const album = Album(id: 'al1', name: 'Al', artist: 'A', provider: 'youtube');
      final playlist = Playlist(
        id: 'p1',
        name: 'P',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        provider: 'local',
      );
      final genre = MusicGenre(title: 'Bollywood Romance');
      final mood = MusicMood(title: 'Chill');

      expect(track.contentKey, 'youtube:song:t1');
      expect(artist.contentKey, 'youtube:artist:ar1');
      expect(album.contentKey, 'youtube:album:al1');
      expect(playlist.contentKey, 'local:playlist:p1');
      expect(genre.contentKey, 'builtin:genre:bollywood-romance');
      expect(mood.contentKey, 'builtin:mood:chill');

      // Keys must not collide across content types.
      final keys = <String>{
        track.contentKey,
        artist.contentKey,
        album.contentKey,
        playlist.contentKey,
        genre.contentKey,
        mood.contentKey,
      };
      expect(keys.length, 6);
    });
  });

  group('Batch resolution', () {
    test('a failing id does not fail the batch', () async {
      final good = ScriptedCatalogProvider(
        providerId: 'good',
        detailTrack: _track('good_id', 'Song', 'Artist', provider: 'good'),
      );
      final bad = ScriptedCatalogProvider(providerId: 'bad', failure: StateError('down'));

      final aggregator = MusicCatalogAggregator(
        adapters: [good, bad],
        cache: cache,
        invoker: ProviderInvoker(diagnostics: diagnostics),
      );

      final resolved = await aggregator.getTracksByIds(['good_id', 'missing_id']);
      expect(resolved.containsKey('good_id'), isTrue);
      expect(resolved.containsKey('missing_id'), isFalse);
    });

    test('an unknown id is simply omitted', () async {
      final aggregator = MusicCatalogAggregator(
        adapters: [ScriptedCatalogProvider(providerId: 'p')],
        cache: cache,
        invoker: ProviderInvoker(diagnostics: diagnostics),
      );

      final resolved = await aggregator.getTracksByIds(['nope']);
      expect(resolved, isEmpty);
    });
  });

  group('Diagnostics', () {
    test('per-provider health is recorded independently', () async {
      final good = ScriptedCatalogProvider(
        providerId: 'good',
        tracks: [_track('g1', 'S', 'A', provider: 'good')],
      );
      final bad = ScriptedCatalogProvider(providerId: 'bad', failure: StateError('offline'));

      final aggregator = MusicCatalogAggregator(
        adapters: [good, bad],
        cache: cache,
        invoker: ProviderInvoker(diagnostics: diagnostics),
      );

      await aggregator.searchTracks('s');
      await aggregator.searchTracks('s2');

      final goodHealth = diagnostics.healthFor('good', 'good');
      final badHealth = diagnostics.healthFor('bad', 'bad');

      expect(goodHealth.successCount, 2);
      expect(goodHealth.successRate, 1.0);
      expect(goodHealth.isDegraded, isFalse);

      expect(badHealth.successCount, 0);
      expect(badHealth.successRate, 0.0);
      expect(badHealth.lastError, contains('offline'));
      // One call fans out to maxAttempts tries, so a hard-down provider shows
      // at least two recorded failures.
      expect(badHealth.failureCount, greaterThanOrEqualTo(2));
      expect(badHealth.isDegraded, isTrue);
    });

    test('an empty result is not counted as a failure', () async {
      final empty = ScriptedCatalogProvider(providerId: 'empty');
      final aggregator = MusicCatalogAggregator(
        adapters: [empty],
        cache: cache,
        invoker: ProviderInvoker(diagnostics: diagnostics),
      );

      await aggregator.searchTracks('nothing');
      final health = diagnostics.healthFor('empty', 'empty');
      expect(health.emptyCount, 1);
      expect(health.failureCount, 0);
    });
  });
}

/// Fails its first [failuresRemaining] calls, then succeeds.
class _FlakyProvider extends ScriptedCatalogProvider {
  int failuresRemaining;
  int _flakyCalls = 0;

  @override
  int get callCount => _flakyCalls;

  _FlakyProvider({
    required super.providerId,
    required this.failuresRemaining,
    super.tracks,
  });

  @override
  Future<List<Track>> searchTracks(String query, {int limit = 20, int page = 1}) async {
    _flakyCalls++;
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw StateError('transient');
    }
    return tracks.take(limit).toList();
  }
}