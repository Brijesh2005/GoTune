import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/library_provider.dart';
import 'providers/music_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/unified_playback_controller.dart';
import 'repositories/favorites_repository.dart';
import 'repositories/playlist_repository.dart';
import 'repositories/recently_played_repository.dart';
import 'repositories/track_repository.dart';
import 'screens/main_screen.dart';
import 'services/music_algorithm_service.dart';
import 'services/music_discovery_service.dart';
import 'services/playback/youtube_iframe_backend.dart';
import 'services/youtube/youtube_player_service.dart';
import 'theme/app_theme.dart';
import 'widgets/global_audio_player.dart';

/// Top-level application widget providing YouTube-only state management,
/// dark app theme, and persistent embedded YouTube IFrame player surface.
class GoTuneApp extends StatefulWidget {
  final TrackRepository repository;
  final FavoritesRepository favoritesRepository;
  final PlaylistRepository playlistRepository;
  final RecentlyPlayedRepository recentlyPlayedRepository;
  final MusicDiscoveryService? discoveryService;
  final MusicAlgorithmService? algorithmService;
  final YouTubeIframeBackend youtubeIframeBackend;
  final YouTubePlayerService youtubePlayerService;

  const GoTuneApp({
    super.key,
    required this.repository,
    required this.favoritesRepository,
    required this.playlistRepository,
    required this.recentlyPlayedRepository,
    required this.youtubeIframeBackend,
    required this.youtubePlayerService,
    this.discoveryService,
    this.algorithmService,
  });

  @override
  State<GoTuneApp> createState() => _GoTuneAppState();
}

class _GoTuneAppState extends State<GoTuneApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[GoTuneApp] AppLifecycleState changed to: $state');
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider(widget.repository),
        ),
        ChangeNotifierProvider<MusicProvider>(
          create: (_) => MusicProvider(
            widget.repository,
            algorithmService: widget.algorithmService,
            discoveryService: widget.discoveryService,
          ),
        ),
        ChangeNotifierProvider<LibraryProvider>(
          create: (_) => LibraryProvider(
            favoritesRepository: widget.favoritesRepository,
            playlistRepository: widget.playlistRepository,
            recentlyPlayedRepository: widget.recentlyPlayedRepository,
          ),
        ),
        ChangeNotifierProvider<UnifiedPlaybackController>(
          create: (_) => UnifiedPlaybackController(
            repository: widget.repository,
            youtubeBackend: widget.youtubeIframeBackend,
            youtubePlayerService: widget.youtubePlayerService,
            recentlyPlayedRepository: widget.recentlyPlayedRepository,
            algorithmService: widget.algorithmService,
            discoveryService: widget.discoveryService,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'GoTune',
        debugShowCheckedModeBanner: false,
        theme: GoTuneTheme.darkTheme,
        darkTheme: GoTuneTheme.darkTheme,
        themeMode: ThemeMode.dark,
        navigatorObservers: [AppNavigatorObserver()],
        builder: (context, navigator) {
          return GlobalAudioPlayer(
            youtubePlayerService: widget.youtubePlayerService,
            child: navigator ?? const SizedBox.shrink(),
          );
        },
        home: const MainScreen(),
      ),
    );
  }
}
