import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'youtube_player_channel.dart';
import 'youtube_player_event.dart';
import 'youtube_player_service.dart';

/// Hosts the Android WebView that renders `assets/youtube_player/index.html`,
/// which in turn hosts the official YouTube IFrame Player API.
///
/// This widget is the *only* component that knows about `webview_flutter`. It
/// translates typed commands into `window.*` calls and turns posted messages
/// into [YouTubePlayerEvent]s, so the rest of the app never runs JavaScript.
///
/// Sizing rule: YouTube requires the embedded viewport to be at least
/// 200x200 px and recommends ~480x270 px for a 16:9 player. Callers must keep
/// the surface at least that large; [minPlayerSize] documents the floor.
class YouTubePlayerWidget extends StatefulWidget {
  /// The service this host attaches to. Passing it in (rather than creating it)
  /// keeps the service alive across navigation and WebView rebuilds.
  final YouTubePlayerService service;

  const YouTubePlayerWidget({
    super.key,
    required this.service,
  });

  /// YouTube's documented minimum embedded player viewport.
  static const Size minPlayerSize = Size(200, 200);

  /// YouTube's recommended 16:9 viewport for a player with controls.
  static const Size recommendedPlayerSize = Size(480, 270);

  /// Local asset containing the IFrame host document.
  static const String playerAsset = 'assets/youtube_player/index.html';

  @override
  State<YouTubePlayerWidget> createState() => _YouTubePlayerWidgetState();
}

class _YouTubePlayerWidgetState extends State<YouTubePlayerWidget>
    implements YouTubePlayerChannel {
  final StreamController<YouTubePlayerEvent> _events =
      StreamController<YouTubePlayerEvent>.broadcast();

  WebViewController? _webViewController;
  bool _apiReady = false;
  String? _currentVideoId;
  Completer<void>? _readyCompleter;

  /// Upper bound on waiting for the IFrame API, so a blocked or slow script
  /// load degrades into a reported error instead of a hung command.
  static const Duration _startupTimeout = Duration(seconds: 4);

  @override
  bool get isReady => _apiReady;

  @override
  String? get currentVideoId => _currentVideoId;

  @override
  Stream<YouTubePlayerEvent> get events => _events.stream;

  @override
  void initState() {
    super.initState();
    widget.service.attachChannel(this);
    // Construct the platform WebView immediately so the player is warm by the
    // time a listener taps a YouTube result. Errors are reported through the
    // event stream rather than thrown during build.
    unawaited(_initialize().catchError((Object e) {
      debugPrint('[YouTubePlayerWidget] WebView init failed: $e');
      _emit(
        const YouTubePlayerEvent(
          type: YouTubePlayerEventType.error,
          errorCode: -1,
          message: 'The embedded player could not be created.',
        ),
      );
    }));
  }

  @override
  void dispose() {
    // Leave the service usable: if this host is rebuilt the new instance
    // re-attaches, and if it is not, commands fail loudly instead of silently
    // hitting a disposed WebView.
    widget.service.detachChannel(this);
    // Unblock anything waiting on readiness so it fails fast rather than
    // lingering until its timeout.
    if (_readyCompleter != null && !_readyCompleter!.isCompleted) {
      _readyCompleter!.complete();
    }
    _events.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _webViewController;
    if (controller == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white54,
            ),
          ),
        ),
      );
    }

    // The engine is transparent until the host document is ready, so the
    // player never flashes a white rectangle over the dark GoTune surface.
    return ColoredBox(
      color: Colors.black,
      child: WebViewWidget(controller: controller),
    );
  }

  Future<void> _initialize() async {
    _readyCompleter = Completer<void>();
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36')
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;

            final host = uri.host.toLowerCase();
            bool isHostOrSubdomain(String domain) {
              return host == domain || host.endsWith('.$domain');
            }

            final allowed = uri.scheme == 'file' ||
                uri.scheme == 'data' ||
                uri.scheme == 'about' ||
                host.isEmpty ||
                isHostOrSubdomain('com.gotune.gotune') ||
                isHostOrSubdomain('youtube.com') ||
                isHostOrSubdomain('youtube-nocookie.com') ||
                isHostOrSubdomain('googlevideo.com') ||
                isHostOrSubdomain('googleapis.com') ||
                isHostOrSubdomain('ytimg.com') ||
                isHostOrSubdomain('ggpht.com') ||
                isHostOrSubdomain('google.com') ||
                isHostOrSubdomain('googleusercontent.com') ||
                isHostOrSubdomain('gstatic.com') ||
                isHostOrSubdomain('doubleclick.net') ||
                isHostOrSubdomain('localhost');
            return allowed
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onWebResourceError: (error) {
            debugPrint('[YouTubePlayerWidget] WebResourceError: ${error.description} (code: ${error.errorCode})');
          },
        ),
      )
      ..addJavaScriptChannel(
        'flutter_webview',
        onMessageReceived: (message) => _onBridgeMessage(message.message),
      );

    // Permit media autoplay on Android WebView without requiring prior DOM touch
    if (controller.platform is AndroidWebViewController) {
      final androidController = controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
    }

    // Assign before the first rebuild so `build` can render the real engine.
    _webViewController = controller;
    if (mounted) setState(() {});

    try {
      final html = await rootBundle.loadString(YouTubePlayerWidget.playerAsset);
      await controller.loadHtmlString(html, baseUrl: 'https://com.gotune.gotune');
    } catch (e) {
      debugPrint('[YouTubePlayerWidget] loadHtmlString fallback: $e');
      await controller.loadFlutterAsset(YouTubePlayerWidget.playerAsset);
    }
  }

  /// Parses one structured message posted by `window.flutter_webview`.
  void _onBridgeMessage(String raw) {
    if (raw.isEmpty) return;

    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return;
    }
    if (decoded is! Map<String, dynamic>) return;

    final event = YouTubePlayerEvent.tryFromBridge(decoded);
    // Drop unknown payloads rather than guessing at their meaning.
    if (event == null) return;

    switch (event.type) {
      case YouTubePlayerEventType.ready:
        _apiReady = true;
        // Release commands that arrived while the API was still loading.
        if (_readyCompleter != null && !_readyCompleter!.isCompleted) {
          _readyCompleter!.complete();
        }
      case YouTubePlayerEventType.unstarted:
      case YouTubePlayerEventType.cued:
      case YouTubePlayerEventType.buffering:
      case YouTubePlayerEventType.playing:
      case YouTubePlayerEventType.paused:
      case YouTubePlayerEventType.ended:
      case YouTubePlayerEventType.autoplayBlocked:
      case YouTubePlayerEventType.error:
      case YouTubePlayerEventType.timeUpdate:
        break;
    }

    if (event.videoId != null && event.videoId!.isNotEmpty) {
      _currentVideoId = event.videoId;
    }

    _emit(event);
  }

  void _emit(YouTubePlayerEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  // --- Commands ---------------------------------------------------------------

  /// Creates the player, or loads into the existing instance when one exists.
  ///
  /// Dart never builds player JS itself: this is a single call into the
  /// documented `window.createPlayer(videoId, autoplay)` contract.
  ///
  /// Waits for the IFrame API to finish loading before dispatching, so a tap
  /// during start-up still plays instead of being dropped on the floor.
  @override
  Future<void> loadVideo(String videoId, {bool autoplay = true}) async {
    _currentVideoId = videoId;
    await _whenApiReady();
    await _run('window.createPlayer(${jsonEncode(videoId)}, $autoplay);');
    if (autoplay) {
      await _run('window.loadVideo(${jsonEncode(videoId)}, true);');
    }
  }

  @override
  Future<void> loadAndPlayVideo(String videoId) async {
    _currentVideoId = videoId;
    await _whenApiReady();
    await _run('window.createPlayer(${jsonEncode(videoId)}, true);');
    await _run('window.loadAndPlayVideo(${jsonEncode(videoId)});');
  }

  @override
  Future<void> play() async {
    await _whenApiReady();
    await _run('window.playVideo();');
  }

  @override
  Future<void> pause() async {
    await _whenApiReady();
    await _run('window.pauseVideo();');
  }

  @override
  Future<void> seekTo(Duration position) async {
    await _whenApiReady();
    await _run('window.seekTo(${position.inMilliseconds / 1000.0});');
  }

  @override
  Future<void> stop() => _run('window.stopVideo();');

  @override
  Future<void> setVolume(int volume) async {
    await _whenApiReady();
    await _run('window.setVolume(${volume.clamp(0, 100)});');
  }

  @override
  Future<double?> currentTimeSeconds() => _runReturningNumber('window.getCurrentTime();');

  @override
  Future<double?> durationSeconds() => _runReturningNumber('window.getDuration();');

  /// Completes once the IFrame API has reported in, or after [_startupTimeout] if
  /// it never does.
  ///
  /// Commands issued before the API loads would otherwise be no-ops, which looks
  /// to the user like a track that silently refuses to play.
  Future<void> _whenApiReady() async {
    if (_apiReady) return;
    await _readyCompleter?.future.timeout(
      _startupTimeout,
      onTimeout: () {
        debugPrint('[YouTubePlayerWidget] IFrame API did not become ready');
        return;
      },
    );
  }

  /// Waits for the platform WebView and the IFrame API to be available.
  Future<void> _run(String script) async {
    final controller = _webViewController;
    if (controller == null) {
      debugPrint('[YouTubePlayerWidget] command dropped, WebView not built: $script');
      return;
    }
    try {
      await controller.runJavaScript(script);
    } catch (e) {
      debugPrint('[YouTubePlayerWidget] JavaScript "$script" failed: $e');
      _emit(
        YouTubePlayerEvent(
          type: YouTubePlayerEventType.error,
          errorCode: -1,
          message: 'The embedded player rejected a command.',
          videoId: _currentVideoId,
        ),
      );
    }
  }

  /// Runs an expression whose result is a number, returning null when the page
  /// is gone or the expression is not numeric.
  Future<double?> _runReturningNumber(String expression) async {
    final controller = _webViewController;
    if (controller == null) return null;
    try {
      final raw = await controller.runJavaScriptReturningResult(expression);
      final value = raw is num ? raw.toDouble() : double.tryParse(raw.toString());
      return value;
    } catch (_) {
      return null;
    }
  }
}