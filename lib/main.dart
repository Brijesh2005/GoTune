import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'repositories/favorites_repository.dart';
import 'repositories/playlist_repository.dart';
import 'repositories/recently_played_repository.dart';
import 'repositories/track_repository.dart';
import 'services/audius_api_service.dart';
import 'services/saavn_api_service.dart';
import 'services/audio_handler.dart';
import 'services/local_storage_service.dart';
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

  // Initialize central local persistence
  final storageService = await LocalStorageService.init();

  // Initialize modular repositories
  final favoritesRepository = FavoritesRepository(storageService);
  final playlistRepository = PlaylistRepository(storageService);
  final recentlyPlayedRepository = RecentlyPlayedRepository(storageService);

  // Initialize API clients
  final apiService = AudiusApiService(
    appName: storageService.getAppName(),
    apiKey: storageService.getApiKey(),
    baseUrl: storageService.getCustomBaseUrl(),
  );
  final saavnService = SaavnApiService();

  // Initialize central catalog repository with dual providers (Audius + JioSaavn)
  final repository = TrackRepository(
    apiService: apiService,
    saavnService: saavnService,
    storageService: storageService,
  );

  // Initialize background audio service & just_audio engine
  final audioHandler = await initAudioService();

  runApp(
    GoTuneApp(
      repository: repository,
      favoritesRepository: favoritesRepository,
      playlistRepository: playlistRepository,
      recentlyPlayedRepository: recentlyPlayedRepository,
      audioHandler: audioHandler,
    ),
  );
}
