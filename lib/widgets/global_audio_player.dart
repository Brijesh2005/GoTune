import 'package:flutter/material.dart';

import '../services/youtube/youtube_player_service.dart';
import '../services/youtube/youtube_player_widget.dart';
import 'mini_player.dart';
import 'yt_bottom_player_bar.dart';

/// Application-level persistent player surface.
///
/// Mounted once, above the [Navigator], so playback UI survives every route
/// change and is never rebuilt or disposed by navigation — the audio analogue
/// of the reference project's `GlobalVideoPlayer` mounted in `__root.tsx`
/// outside `<Outlet />`.
///
/// It hosts two things:
///
/// * the mini player UI for every engine, and
/// * exactly one YouTube IFrame WebView ([YouTubePlayerWidget]), which stays
///   mounted for the lifetime of the app. A YouTube track is therefore loaded
///   into a player that already exists: opening Now Playing never creates a
///   second WebView, and navigating away never destroys the one that is
///   playing.
///
/// The iframe surface is kept in the tree but laid out off-screen when the
/// active track is not a YouTube one. Disposing it instead would stop playback
/// and force a fresh `YT.Player` (and another ad break) on the next track.
class GlobalAudioPlayer extends StatelessWidget {
  final Widget child;
  final YouTubePlayerService youtubePlayerService;

  const GlobalAudioPlayer({
    super.key,
    required this.child,
    required this.youtubePlayerService,
  });

  /// Height reserved by the tab shell's bottom navigation bar.
  static const double bottomBarHeight = 72;

  /// Current navigator depth, maintained by [AppNavigatorObserver].
  ///
  /// `1` means only the tab shell is mounted, so the player must clear the
  /// bottom bar. Anything higher means a detail route is pushed and there is no
  /// bar to clear.
  static final ValueNotifier<int> routeDepth = ValueNotifier<int>(1);

  /// True while the full-screen player sheet covers the mini player.
  static final ValueNotifier<bool> fullPlayerVisible = ValueNotifier<bool>(false);

  /// Raised by Now Playing while the embedded video is on screen, so the same
  /// WebView instance is revealed instead of a second one being created.
  static final ValueNotifier<bool> youtubeSurfaceRequested = ValueNotifier<bool>(false);

  /// YouTube's documented minimum embedded player viewport.
  static const double youtubeSurfaceMinHeight = 200;

  /// YouTube's recommended player height for a 16:9 player with controls.
  static const double youtubeSurfaceMaxHeight = 270;

  /// Height of the global IFrame surface for a given screen width.
  ///
  /// YouTube requires at least 200x200 px and recommends ~480x270 px for 16:9
  /// with controls, so the box is 16:9 clamped into that range. Now Playing
  /// insets its own layout by the same value, keeping the GoTune controls clear
  /// of the player.
  static double youtubeSurfaceHeight(double screenWidth) {
    final sixteenByNine = screenWidth * 9 / 16;
    return sixteenByNine.clamp(
      youtubeSurfaceMinHeight,
      youtubeSurfaceMaxHeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        // Positioned (not IgnorePointer) so the mini player stays tappable:
        // a Stack only hit-tests where its children actually paint, so the
        // route content beneath remains fully interactive.
        ValueListenableBuilder<bool>(
          valueListenable: fullPlayerVisible,
          builder: (context, isFullPlayerVisible, __) {
            if (isFullPlayerVisible) return const SizedBox.shrink();

            final isWide = MediaQuery.of(context).size.width >= 800;

            if (isWide) {
              return const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: YtBottomPlayerBar(),
              );
            }

            return ValueListenableBuilder<int>(
              valueListenable: routeDepth,
              builder: (context, depth, __) {
                return Positioned(
                  left: 0,
                  right: 0,
                  bottom: depth > 1 ? 8 : bottomBarHeight,
                  child: const MiniPlayer(),
                );
              },
            );
          },
        ),

        // The one and only YouTube IFrame surface.
        //
        // It stays laid out and painted for the whole app session so the
        // embedded player keeps running audio when GoTune is showing an
        // audio-first view; only its visibility changes. Destroying it would
        // stop playback and force a fresh `YT.Player` (plus another ad break)
        // on the next YouTube track.
        ValueListenableBuilder<bool>(
          valueListenable: youtubeSurfaceRequested,
          builder: (context, requested, __) {
            final screenWidth = MediaQuery.sizeOf(context).width;
            final surfaceHeight = GlobalAudioPlayer.youtubeSurfaceHeight(screenWidth);

            return Positioned(
              top: requested ? 0 : -9999,
              left: 0,
              right: requested ? 0 : null,
              width: requested ? null : screenWidth.clamp(320.0, 480.0),
              height: surfaceHeight,
              child: IgnorePointer(
                ignoring: !requested,
                child: YouTubePlayerWidget(service: youtubePlayerService),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Tracks navigator depth so [GlobalAudioPlayer] can dock itself correctly.
///
/// Depth is derived from push/pop activity instead of route types, which keeps
/// the observer free of any knowledge about GoTune's screens.
class AppNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _syncDepth(() => GlobalAudioPlayer.routeDepth.value + 1);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _syncDepth(() {
      final depth = GlobalAudioPlayer.routeDepth.value;
      return depth > 1 ? depth - 1 : 1;
    });
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _syncDepth(() {
      final depth = GlobalAudioPlayer.routeDepth.value;
      return depth > 1 ? depth - 1 : 1;
    });
  }

  void _syncDepth(int Function() compute) {
    final next = compute();
    if (next != GlobalAudioPlayer.routeDepth.value) {
      GlobalAudioPlayer.routeDepth.value = next;
    }
  }
}