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

  /// Vertical offset from top when YouTube surface is requested.
  static final ValueNotifier<double> youtubeSurfaceTopOffset = ValueNotifier<double>(0.0);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        // Positioned (not IgnorePointer) so the mini player stays tappable
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
                // When at root depth (depth <= 1), MainScreen hosts MiniPlayer above the bottom bar.
                // When pushed into a subroute without a bottom bar (depth > 1), dock MiniPlayer at bottom.
                if (depth <= 1) return const SizedBox.shrink();

                return const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 8,
                  child: MiniPlayer(),
                );
              },
            );
          },
        ),

        // The persistent YouTube IFrame surface.
        // When requested (Video mode), it aligns with the video surface in Now Playing.
        // When not requested (Audio mode), it remains active at an on-screen compact 200x200 box
        // with near-zero opacity so continuous background audio never pauses.
        ValueListenableBuilder<bool>(
          valueListenable: youtubeSurfaceRequested,
          builder: (context, requested, __) {
            return ValueListenableBuilder<double>(
              valueListenable: youtubeSurfaceTopOffset,
              builder: (context, topOffset, __) {
                final screenWidth = MediaQuery.sizeOf(context).width;
                final surfaceHeight = GlobalAudioPlayer.youtubeSurfaceHeight(screenWidth);

                return Positioned(
                  top: requested ? topOffset : 0,
                  left: 0,
                  right: requested ? 0 : null,
                  width: requested ? null : 200,
                  height: requested ? surfaceHeight : 200,
                  child: IgnorePointer(
                    ignoring: !requested,
                    child: Opacity(
                      opacity: requested ? 1.0 : 0.001,
                      child: YouTubePlayerWidget(service: youtubePlayerService),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

/// Tracks navigator depth so [GlobalAudioPlayer] can dock itself correctly.
///
/// Only [PageRoute] transitions update depth, ensuring dialogs, sheets, and popups
/// never corrupt navigation state. When depth is 1 (MainScreen), MiniPlayer docks
/// above the bottom navigation bar; when depth > 1 (detail routes), it docks at bottom: 8.
class AppNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> _routeStack = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) {
      _routeStack.add(route);
      _syncDepth();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) {
      _routeStack.remove(route);
      _syncDepth();
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) {
      _routeStack.remove(route);
      _syncDepth();
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute is PageRoute) _routeStack.remove(oldRoute);
    if (newRoute is PageRoute) _routeStack.add(newRoute);
    _syncDepth();
  }

  void _syncDepth() {
    final depth = _routeStack.isEmpty ? 1 : _routeStack.length;
    if (depth != GlobalAudioPlayer.routeDepth.value) {
      GlobalAudioPlayer.routeDepth.value = depth;
    }
  }
}