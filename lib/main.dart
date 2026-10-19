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
import 'core/game/village.dart';
import 'core/services/distraction_guard.dart';
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
  late final DistractionGuard _guard = DistractionGuard(
    graceSeconds: () => graceSecondsFor(_player.levelOf(Building.tower)),
    onPenalty: (pkg) {
      _sessionController.applyBlacklistPenalty();
      _overlayService.showBlockerOverlay(
        reason: '${BlacklistConstants.appNames[pkg] ?? pkg} bị chặn trong lúc tập trung!',
      );
      _pushOverlayState(pkg);
    },
    onTax: () {
      _sessionController.applyDistractionTax();
      _pushOverlayState(null);
    },
    onLeftBlacklisted: _overlayService.closeBlockerOverlay,
  );
  String? _blockedPkg;
  bool _interruptionCounted = false;

  void _pushOverlayState(String? pkg) {
    _blockedPkg = pkg ?? _blockedPkg;
    _overlayService.pushState(
      appName: BlacklistConstants.appNames[_blockedPkg] ?? _blockedPkg ?? '',
      heroHp: _sessionController.heroHp,
      pendingCoins: _sessionController.pendingCoins,
      defeated: _sessionController.lastResult?.won == false && !_sessionController.inBattle,
    );
  }

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
      // FocusKnight moved to background (hidden and paused both fire; count once)
      if (_overlayService.isAppInForeground) {
        _screenTimeTracker.markLeftApp();
        _interruptionCounted = false;
      }
      _overlayService.isAppInForeground = false;

      // Periodic monitor for blacklisted apps while in background
      _distractionCheckTimer?.cancel();
      _distractionCheckTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
        if (_overlayService.isAppInForeground) return;

        if (_sessionController.inBattle) {
          final fg = await _screenTimeTracker.foregroundSinceLeft();
          if (_overlayService.isAppInForeground) return; // resumed while we were querying
          // Locking the screen opens no app, so it is not a distraction.
          if (fg != null && !_interruptionCounted && _sessionController.isFocusing) {
            _interruptionCounted = true;
            _sessionController.recordInterruptionEvent();
          }
          if (_sessionController.isFocusing) {
            _guard.tick(BlacklistConstants.defaultBlacklist.contains(fg) ? fg : null, DateTime.now());
          } else {
            // Rest breaks are free: drop any pending grace and blocker.
            _guard.reset();
            if (_overlayService.isOverlayOpen) _overlayService.closeBlockerOverlay();
          }
          return;
        }
        final blacklistedPkg = await _screenTimeTracker.getActiveBlacklistedPackage();
        if (blacklistedPkg != null && _screenTimeTracker.isAppLimitExceeded(blacklistedPkg)) {
          // Standard system notification popup (NOT full-screen blocker overlay!)
          ForegroundTaskService.notifyAppLimitExceeded(
            appName: BlacklistConstants.appNames[blacklistedPkg] ?? blacklistedPkg,
            packageName: blacklistedPkg,
            limitMinutes: _screenTimeTracker.getAppLimit(blacklistedPkg),
          );
        }
      });
    } else if (state == AppLifecycleState.resumed) {
      // User returned to FocusKnight: stop tracker timer, close overlay immediately
      _overlayService.isAppInForeground = true;
      _distractionCheckTimer?.cancel();
      _guard.reset();
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