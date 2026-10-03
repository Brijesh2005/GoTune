import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'repositories/favorites_repository.dart';
import 'repositories/playlist_repository.dart';
import 'repositories/recently_played_repository.dart';
import 'repositories/track_repository.dart';
import 'services/audio_handler.dart';
import 'services/local_storage_service.dart';
import 'services/music_algorithm_service.dart';
import 'services/music_cache_service.dart';
import 'services/music_catalog_aggregator.dart';
import 'services/music_catalog_provider.dart';
import 'services/music_discovery_service.dart';
import 'services/playback/direct_audio_backend.dart';
import 'services/playback/youtube_iframe_backend.dart';
import 'services/saavn_api_service.dart';
import 'services/youtube/youtube_player_service.dart';
import 'services/youtube_api_service.dart';
import 'theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure sleek edge-to-edge transparent system bars
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // 1. Initialize central local persistence
  final storageService = await LocalStorageService.init();

  // 2. Initialize modular repositories
  final favoritesRepository = FavoritesRepository(storageService);
  final playlistRepository = PlaylistRepository(storageService);
  final recentlyPlayedRepository = RecentlyPlayedRepository(storageService);

  // 3. Initialize low-level backend YouTube API and discovery adapter
  final youtubeService = YouTubeApiService();

  // 4. Initialize centralized cache service (TTL-based bounded caching)
  final cacheService = MusicCacheService();

  // 5. Initialize YouTube catalog provider
  final youtubeProvider = YouTubeCatalogProvider(service: youtubeService);

  // 6. Initialize centralized catalog aggregator
  final catalogAggregator = MusicCatalogAggregator(
    youtubeProvider: youtubeProvider,
    cacheService: cacheService,
  );

  // 7. Initialize central catalog repository
  final repository = TrackRepository(
    youtubeProvider: youtubeProvider,
    catalogAggregator: catalogAggregator,
    cacheService: cacheService,
    storageService: storageService,
  );

  // 8. Initialize recommendation algorithm & discovery pipeline
  final algorithmService = MusicAlgorithmService(repository: repository);
  final discoveryService = MusicDiscoveryService(
    aggregator: catalogAggregator,
    algorithmService: algorithmService,
    storageService: storageService,
    cache: cacheService,
  );

  // 9. Initialize the YouTube IFrame player service.
  final youtubePlayerService = YouTubePlayerService();

  // 10. Build the YouTube IFrame playback backend
  final youtubeIframeBackend = YouTubeIframeBackend(
    service: youtubePlayerService,
  );

  // 11. Initialize Native Audio Service for Background Play & 320kbps Streams
  final audioHandler = await initAudioService();
  final directBackend = DirectAudioBackend(audioHandler: audioHandler);
  final saavnService = SaavnApiService();

  runApp(
    GoTuneApp(
      repository: repository,
      favoritesRepository: favoritesRepository,
      playlistRepository: playlistRepository,
      recentlyPlayedRepository: recentlyPlayedRepository,
      discoveryService: discoveryService,
      algorithmService: algorithmService,
      youtubeIframeBackend: youtubeIframeBackend,
      youtubePlayerService: youtubePlayerService,
      audioHandler: audioHandler,
      directBackend: directBackend,
      saavnService: saavnService,
    ),
  );
}
