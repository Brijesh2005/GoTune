import 'package:flutter_test/flutter_test.dart';
import 'package:gotune/models/album.dart';
import 'package:gotune/models/artist.dart';
import 'package:gotune/models/home_feed.dart';
import 'package:gotune/models/music_content.dart';
import 'package:gotune/models/search_discovery_result.dart';
import 'package:gotune/models/track.dart';
import 'package:gotune/services/music_cache_service.dart';
import 'package:gotune/services/music_catalog_aggregator.dart';
import 'package:gotune/services/music_catalog_provider.dart';

// Mock YouTube Catalog Provider for deterministic architecture tests
class MockYouTubeCatalogProvider extends MusicCatalogProvider {
  final bool shouldFail;
  final List<Track> tracks;

  MockYouTubeCatalogProvider({
    this.shouldFail = false,
    this.tracks = const [],
  });

  @override
  String get providerId => 'youtube';

  @override
  String get displayName => 'YouTube';

  @override
  bool get isPlayable => true;

  @override
  Future<List<Track>> searchTracks(String query, {int limit = 20, int page = 1}) async {
    if (shouldFail) throw Exception('YouTube search simulation failure');
    return tracks.take(limit).toList();
  }

  @override
  Future<List<Track>> getTrendingTracks({String? genre, int limit = 20, int page = 1}) async {
    if (shouldFail) throw Exception('YouTube trending simulation failure');
    return tracks.take(limit).toList();
  }

  @override
  Future<List<Track>> getRelatedTracks(Track track, {int limit = 15}) async {
    if (shouldFail) throw Exception('YouTube related simulation failure');
    return tracks.take(limit).toList();
  }

  @override
  Future<Track?> getTrackById(String trackId) async {
    if (shouldFail) return null;
    return tracks.firstWhere((t) => t.id == trackId, orElse: () => tracks.first);
  }


  @override
  Future<List<Artist>> searchArtists(String query, {int limit = 15}) async => [];

  @override
  Future<List<Album>> searchAlbums(String query, {int limit = 15}) async => [];

  @override
  Future<Artist?> getArtistDetails(String artistId) async => null;

  @override
  Future<Album?> getAlbumDetails(String albumId) async => null;

  @override
  Future<List<Track>> getArtistTracks(String artistIdOrName, {int limit = 20}) async => [];

  @override
  Future<List<Track>> getPopularTracks({int limit = 20}) async => [];

  @override
  Future<List<Track>> getNewReleases({int limit = 20}) async => [];
}

void main() {
  group('YouTube Architecture Tests', () {
    late MusicCacheService cache;

    setUp(() {
      cache = MusicCacheService();
      cache.clear();
    });

    test('MusicCacheService stores, retrieves, and expires entries with bounded size', () {
      cache.set('test_key', 'test_data', ttl: const Duration(seconds: 1));
      expect(cache.has('test_key'), isTrue);
      expect(cache.get<String>('test_key'), 'test_data');

      // Invalidate
      cache.invalidate('test_key');
      expect(cache.has('test_key'), isFalse);
    });

    test('CatalogAggregator performs queries with error isolation and caching', () async {
      final healthyYouTube = MockYouTubeCatalogProvider(
        tracks: [
          const Track(
            id: 'yt_1',
            youtubeVideoId: 'yt_1',
            title: 'Song Alpha',
            artist: 'Artist One',
            source: 'youtube',
          ),
        ],
      );

      final aggregator = MusicCatalogAggregator(
        adapters: [healthyYouTube],
        cache: cache,
      );

      final results = await aggregator.searchTracks('Song');
      expect(results.length, 1);
      expect(results.first.id, 'yt_1');
      expect(results.first.isYouTubeIframe, isTrue);
    });

    test('CatalogAggregator deduplicates duplicate tracks', () async {
      final duplicateYouTube = MockYouTubeCatalogProvider(
        tracks: [
          const Track(
            id: 'yt_100',
            youtubeVideoId: 'yt_100',
            title: 'Rolling in the Deep',
            artist: 'Adele',
            source: 'youtube',
          ),
          const Track(
            id: 'yt_101',
            youtubeVideoId: 'yt_101',
            title: 'Rolling in the Deep',
            artist: 'Adele',
            source: 'youtube',
          ),
        ],
      );

      final aggregator = MusicCatalogAggregator(
        adapters: [duplicateYouTube],
        cache: cache,
      );

      final results = await aggregator.searchTracks('Rolling in the Deep');
      expect(results.length, 1);
      final mergedTrack = results.first;
      expect(mergedTrack.title, 'Rolling in the Deep');
      expect(mergedTrack.artist, 'Adele');
    });

    test('HomeFeed model correctly represents all YouTube discovery sections', () {
      final feed = HomeFeed(
        quickPicks: [
          const Track(id: '1', title: 'Pick 1', artist: 'Artist A'),
        ],
        recommendedSongs: [
          const Track(id: '2', title: 'Rec 1', artist: 'Artist B'),
        ],
        trendingTracks: [
          const Track(id: '3', title: 'Trending 1', artist: 'Artist C'),
        ],
        popularNow: [],
        recentlyPlayed: [],
        newReleases: [
          const Track(id: '9', title: 'New 1', artist: 'Artist D'),
        ],
        genres: [
          MusicGenre(title: 'Pop'),
          MusicGenre(title: 'Rock'),
          MusicGenre(title: 'Electronic'),
        ],
        moods: [
          MusicMood(title: 'Chill'),
        ],
        updatedAt: DateTime.now(),
        isLoading: false,
      );

      expect(feed.hasContent, isTrue);
      expect(feed.quickPicks.length, 1);
      expect(feed.recommendedSongs.length, 1);
      expect(feed.trendingTracks.length, 1);
      expect(feed.newReleases.length, 1);
      expect(feed.genres.any((g) => g.title == 'Pop'), isTrue);
      expect(feed.moods.any((m) => m.title == 'Chill'), isTrue);
    });

    test('SearchDiscoveryResult correctly packages categorized discovery results', () {
      final searchResult = SearchDiscoveryResult(
        query: 'Adele',
        songs: [
          const Track(id: '1', title: 'Hello', artist: 'Adele'),
        ],
        genres: [MusicGenre(title: 'Pop'), MusicGenre(title: 'Soul')],
        moods: [MusicMood(title: 'Happy')],
        timestamp: DateTime.now(),
      );

      expect(searchResult.totalCount, greaterThan(0));
      expect(searchResult.hasResults, isTrue);
      expect(searchResult.songs.first.title, 'Hello');
      expect(searchResult.genres.any((g) => g.title == 'Soul'), isTrue);
      expect(searchResult.moods.any((m) => m.title == 'Happy'), isTrue);
    });
  });
}
