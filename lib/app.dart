import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/audio_player_provider.dart';
import 'providers/library_provider.dart';
import 'providers/music_provider.dart';
import 'providers/settings_provider.dart';
import 'repositories/favorites_repository.dart';
import 'repositories/playlist_repository.dart';
import 'repositories/recently_played_repository.dart';
import 'repositories/track_repository.dart';
import 'screens/main_screen.dart';
import 'services/audio_handler.dart';
import 'theme/app_theme.dart';

/// Top-level application widget providing multi-provider state management,
/// app theme, and lifecycle-aware background playback monitoring.
class GoTuneApp extends StatefulWidget {
  final TrackRepository repository;
  final FavoritesRepository favoritesRepository;
  final PlaylistRepository playlistRepository;
  final RecentlyPlayedRepository recentlyPlayedRepository;
  final GoTuneAudioHandler audioHandler;

  const GoTuneApp({
    super.key,
    required this.repository,
    required this.favoritesRepository,
    required this.playlistRepository,
    required this.recentlyPlayedRepository,
    required this.audioHandler,
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
          create: (_) => MusicProvider(widget.repository),
        ),
        ChangeNotifierProvider<LibraryProvider>(
          create: (_) => LibraryProvider(
            favoritesRepository: widget.favoritesRepository,
            playlistRepository: widget.playlistRepository,
            recentlyPlayedRepository: widget.recentlyPlayedRepository,
          ),
        ),
        ChangeNotifierProvider<AudioPlayerProvider>(
          create: (_) => AudioPlayerProvider(
            audioHandler: widget.audioHandler,
            repository: widget.repository,
            recentlyPlayedRepository: widget.recentlyPlayedRepository,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'GoTune',
        debugShowCheckedModeBanner: false,
        theme: GoTuneTheme.darkTheme,
        darkTheme: GoTuneTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: const MainScreen(),
      ),
    );
  }
}
