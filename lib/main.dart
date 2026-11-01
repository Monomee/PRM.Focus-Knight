import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'core/services/foreground_task_service.dart';
import 'core/services/overlay_service.dart';
import 'features/shell/app_shell.dart';
import 'features/dashboard/services/focus_history_service.dart';
import 'features/focus_session/focus_session_controller.dart';
import 'features/focus_session/settlement.dart';
import 'core/game/player_state.dart';
import 'core/game/village.dart';
import 'core/game/economy.dart';
import 'core/services/alert_notifier.dart';
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
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BlockerOverlayWidget(),
    ),
  );
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
  bool _distractionCheckRunning = false;
  late final DistractionGuard _guard = DistractionGuard(
    graceSeconds: () => graceSecondsFor(_player.levelOf(Building.tower)),
    onPenalty: (pkg) {
      _sessionController.applyBlacklistPenalty();
      _overlayService.showBlockerOverlay(
        reason:
            '${_screenTimeTracker.appNameFor(pkg)} bị chặn trong lúc tập trung!',
      );
      _pushOverlayState(pkg);
    },
    onTax: () {
      _sessionController.applyDistractionTax();
      _pushOverlayState(null);
    },
    onLeftBlacklisted: _overlayService.closeBlockerOverlay,
    onGraceStart: (pkg) => AlertNotifier.show(
      '⚠️ Đang mở ${_screenTimeTracker.appNameFor(pkg)}',
      'Quay lại FocusKnight trong ${graceSecondsFor(_player.levelOf(Building.tower))} giây để không mất $kPenaltyHp HP.',
      id: AlertNotifier.violation,
    ),
  );
  String? _blockedPkg;
  bool _interruptionCounted = false;
  bool _wasInBattle = false;
  bool _progressReady = false;
  bool _progressFailed = false;

  void _handleBattleState() {
    final inBattle = _sessionController.inBattle;
    ForegroundTaskService.sendBattleState(inBattle);
    if (_wasInBattle && !inBattle) {
      _guard.reset();
      final defeated = _sessionController.lastResult?.won == false;
      if (defeated && _overlayService.isOverlayOpen) {
        _pushOverlayState(null);
      } else {
        _overlayService.closeBlockerOverlay();
      }
    }
    _wasInBattle = inBattle;
  }

  void _pushOverlayState(String? pkg) {
    _blockedPkg = pkg ?? _blockedPkg;
    _overlayService.pushState(
      appName: _screenTimeTracker.appNameFor(_blockedPkg),
      heroHp: _sessionController.heroHp,
      pendingCoins: _sessionController.pendingCoins,
      defeated:
          _sessionController.lastResult?.won == false &&
          !_sessionController.inBattle,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _player = PlayerState();
    _initProgress();
    _sessionController = FocusSessionController(player: _player);
    _wasInBattle = _sessionController.inBattle;
    _sessionController.addListener(_handleBattleState);
    _screenTimeTracker = ScreenTimeTracker();
    _overlayService = OverlayService();
    _screenTimeTracker.addListener(_syncMonitoring);
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
  }

  void _syncMonitoring() {
    if (_screenTimeTracker.hasPermission && _overlayService.isAppInForeground) {
      unawaited(ForegroundTaskService.ensureMonitoring());
    }
  }

  void _onTaskData(Object data) {
    if (data == 'monitorReady') {
      ForegroundTaskService.sendBattleState(_sessionController.inBattle);
    }
  }

  Future<void> _initProgress() async {
    if (mounted) setState(() => _progressFailed = false);
    try {
      await _player.load();
      final history = FocusHistoryService.instance;
      await history.loadData();
      // Finish a battle payout that was cut short by the app being killed.
      await Settlement.resume(_player, history);
      await _player.abandonUnfinishedConstructions();
      await _refreshStreakShield();
      _progressReady = true;
    } catch (_) {
      _progressFailed = true;
    } finally {
      if (mounted) setState(() {});
    }
  }

  /// Weekly granary ticket, then use it to cover a missed day if needed. Idempotent.
  Future<void> _refreshStreakShield() async {
    final history = FocusHistoryService.instance;
    final now = DateTime.now();
    await _player.grantWeeklyTicket(now);
    await history.tryShieldGap(
      now: now,
      protectFrom: _player.granaryBuiltAt,
      consumeTicket: _player.consumeTicket,
    );
  }

  Future<void> _checkDistraction() async {
    if (_distractionCheckRunning || _overlayService.isAppInForeground) return;
    _distractionCheckRunning = true;
    try {
      _sessionController.refreshTimer();
      if (_sessionController.inBattle) {
        final fg = await _screenTimeTracker.foregroundSinceLeft();
        if (_overlayService.isAppInForeground) return;
        _sessionController.refreshTimer();
        if (fg != null &&
            !_interruptionCounted &&
            _sessionController.isFocusing) {
          _interruptionCounted = true;
          _sessionController.recordInterruptionEvent();
        }
        if (_sessionController.isFocusing) {
          _guard.tick(
            _screenTimeTracker.isTrackedPackage(fg) ? fg : null,
            DateTime.now(),
          );
        } else {
          _guard.reset();
          if (_overlayService.isOverlayOpen) {
            _overlayService.closeBlockerOverlay();
          }
        }
        return;
      }
    } finally {
      _distractionCheckRunning = false;
    }
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
      _distractionCheckTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _checkDistraction(),
      );
    } else if (state == AppLifecycleState.resumed) {
      _sessionController.refreshTimer();
      unawaited(_sessionController.retrySettlement());
      // User returned to FocusKnight: stop tracker timer, close overlay immediately
      _overlayService.isAppInForeground = true;
      _distractionCheckTimer?.cancel();
      _guard.reset();
      _overlayService.closeBlockerOverlay();
      // Permissions may have been granted in system Settings while we were away.
      _overlayService.checkPermission();
      _screenTimeTracker.checkPermission().then(
        (_) => _screenTimeTracker.refreshUsageStats(),
      );
      // The process can live for days (foreground service): re-check the weekly ticket.
      _refreshStreakShield();
    }
  }

  @override
  void dispose() {
    _distractionCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _player.dispose();
    _sessionController.removeListener(_handleBattleState);
    _sessionController.dispose();
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    _screenTimeTracker.removeListener(_syncMonitoring);
    _screenTimeTracker.dispose();
    _overlayService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_progressReady) {
      return Scaffold(
        body: Center(
          child: _progressFailed
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Chưa tải được tiến độ. Hãy thử lại.'),
                    FilledButton(
                      onPressed: _initProgress,
                      child: const Text('Thử lại'),
                    ),
                  ],
                )
              : const CircularProgressIndicator(),
        ),
      );
    }
    return AppShell(
      controller: _sessionController,
      player: _player,
      tracker: _screenTimeTracker,
      overlay: _overlayService,
    );
  }
}
