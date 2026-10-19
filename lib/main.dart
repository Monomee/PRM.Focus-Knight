import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/constants/blacklist_constants.dart';
import 'core/services/foreground_task_service.dart';
import 'core/services/overlay_service.dart';
import 'features/shell/app_shell.dart';
import 'features/dashboard/services/focus_history_service.dart';
import 'features/focus_session/focus_session_controller.dart';
import 'core/game/player_state.dart';
import 'features/overlay/blocker_overlay_widget.dart';
import 'features/telemetry/screen_time_tracker.dart';

/// Entry point for the main Flutter application
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize background foreground task service
  ForegroundTaskService.init();

  runApp(const FocusKnightApp());
}

/// Overlay entry point required by flutter_overlay_window
@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: BlockerOverlayWidget(),
  ));
}

class FocusKnightApp extends StatelessWidget {
  const FocusKnightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FocusKnight',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F131C),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFB300),
          secondary: Color(0xFF60A5FA),
          surface: Color(0xFF151A26),
        ),
      ),
      home: const FocusKnightHomePage(),
    );
  }
}

class FocusKnightHomePage extends StatefulWidget {
  const FocusKnightHomePage({super.key});

  @override
  State<FocusKnightHomePage> createState() => _FocusKnightHomePageState();
}

class _FocusKnightHomePageState extends State<FocusKnightHomePage>
    with WidgetsBindingObserver {
  late final PlayerState _player;
  late final FocusSessionController _sessionController;
  late final ScreenTimeTracker _screenTimeTracker;
  late final OverlayService _overlayService;

  Timer? _distractionCheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _player = PlayerState();
    _initProgress();
    _sessionController = FocusSessionController(player: _player);
    _screenTimeTracker = ScreenTimeTracker();
    _overlayService = OverlayService();
  }

  /// Weekly granary ticket, then use it to cover a missed day if needed.
  Future<void> _initProgress() async {
    await _player.load();
    final history = FocusHistoryService.instance;
    await history.loadData();
    final now = DateTime.now();
    await _player.grantWeeklyTicket(now);
    await history.tryShieldGap(
      now: now,
      protectFrom: _player.granaryBuiltAt,
      consumeTicket: _player.consumeTicket,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // FocusKnight moved to background
      _overlayService.isAppInForeground = false;

      // Start periodic monitor for blacklisted apps when in background
      _distractionCheckTimer?.cancel();
      _distractionCheckTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
        if (_overlayService.isAppInForeground) return;

        final blacklistedPkg = await _screenTimeTracker.getActiveBlacklistedPackage();
        if (blacklistedPkg != null) {
          final appName = BlacklistConstants.appNames[blacklistedPkg] ?? blacklistedPkg;
          if (_sessionController.isFocusing) {
            _overlayService.showBlockerOverlay(
              reason: 'Blocked! Access to $appName is restricted while focusing.',
            );
          } else if (_screenTimeTracker.isAppLimitExceeded(blacklistedPkg)) {
            // Standard system notification popup (NOT full-screen blocker overlay!)
            final limit = _screenTimeTracker.getAppLimit(blacklistedPkg);
            ForegroundTaskService.notifyAppLimitExceeded(
              appName: appName,
              packageName: blacklistedPkg,
              limitMinutes: limit,
            );
          }
        }
      });

      // If in active focus, start 10-second grace period
      if (_sessionController.isFocusing) {
        _overlayService.startGracePeriod(
          onGraceExpired: () {
            _overlayService.showBlockerOverlay(
              reason:
                  'Quest abandoned! You left FocusKnight while focusing on ${_sessionController.taskName}.',
            );
          },
        );
      }
    } else if (state == AppLifecycleState.resumed) {
      // User returned to FocusKnight: cancel grace period, stop tracker timer, close overlay immediately
      _overlayService.isAppInForeground = true;
      _distractionCheckTimer?.cancel();
      _overlayService.cancelGracePeriod();
      _overlayService.closeBlockerOverlay();
      _screenTimeTracker.refreshUsageStats();
    }
  }

  @override
  void dispose() {
    _distractionCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _player.dispose();
    _sessionController.dispose();
    _screenTimeTracker.dispose();
    _overlayService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      controller: _sessionController,
      player: _player,
      tracker: _screenTimeTracker,
      overlay: _overlayService,
    );
  }
}