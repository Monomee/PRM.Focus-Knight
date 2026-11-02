import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/game/economy.dart';
import '../../core/game/player_state.dart';
import '../../core/game/progression.dart';
import '../../core/game/village.dart';
import '../../core/services/alert_notifier.dart';
import '../../core/services/foreground_task_service.dart';
import '../dashboard/services/focus_history_service.dart';
import '../dashboard/services/analytics_journal.dart';
import 'settlement.dart';

enum SessionPhase {
  setup, // Choosing task and duration
  focus, // Active Pomodoro focus session
  rest, // Rest break between sessions
}

/// Outcome of a whole battle (chain of sessions).
class BattleResult {
  const BattleResult({
    required this.won,
    required this.coins,
    required this.logs,
    required this.focusSeconds,
    required this.sessions,
    this.building,
  });
  final bool won;
  final int coins;
  final int logs;
  final int focusSeconds;
  final int sessions;
  final FocusBuilding? building;
}

/// Controller for a battle: Pomodoro countdown, rest breaks, hero HP, pause, and the
/// battle escrow. Coin/Log and focus hours are only committed when the whole battle is won.
class FocusSessionController extends ChangeNotifier {
  FocusSessionController({
    PlayerState? player,
    FocusHistoryService? history,
    DateTime Function()? clock,
    bool Function()? analyticsMonitoring,
  }) : player = player ?? PlayerState(),
       _history = history ?? FocusHistoryService.instance,
       _clock = clock ?? DateTime.now,
       _analyticsMonitoring = analyticsMonitoring ?? (() => false);

  final bool Function() _analyticsMonitoring;
  Map<String, dynamic>? _analyticsSession;
  static int _analyticsSequence = 0;

  void invalidateAnalyticsMonitoring() {
    if (_analyticsSession == null) return;
    _analyticsSession!['monitored'] = false;
    AnalyticsJournal.instance.save(_analyticsSession!);
  }

  void recordLifecycleEvent(String state) {
    final session = _analyticsSession;
    if (session == null) return;
    (session['lifecycle'] as List).add({
      'state': state,
      'at': _clock().toUtc().toIso8601String(),
    });
    AnalyticsJournal.instance.save(session);
  }

  void _saveAnalyticsEnd(String outcome, DateTime end, {String? reason}) {
    final session = _analyticsSession;
    if (session == null) return;
    final intervals = List<FocusInterval>.of(_focusIntervals);
    if (!_isPaused &&
        _focusStartedAt != null &&
        end.isAfter(_focusStartedAt!)) {
      intervals.add((start: _focusStartedAt!, end: end));
    }
    session['end'] = end.toUtc().toIso8601String();
    session['outcome'] = outcome;
    session['reason'] = reason ?? outcome;
    session['monitored'] =
        session['monitored'] == true && _analyticsMonitoring();
    session['intervals'] = [
      for (final i in intervals)
        {
          'start': i.start.toUtc().toIso8601String(),
          'end': i.end.toUtc().toIso8601String(),
        },
    ];
    AnalyticsJournal.instance.save(session, collectUsage: true);
    _analyticsSession = null;
  }

  final PlayerState player;
  final FocusHistoryService _history;
  final DateTime Function() _clock;

  SessionPhase _phase = SessionPhase.setup;
  SessionPhase get phase => _phase;

  String _taskName = 'Code API';
  String get taskName => _taskName;

  int _totalFocusSeconds = 60;
  int get totalFocusSeconds => _totalFocusSeconds;

  int _totalRestSeconds = 300;
  int get totalRestSeconds => _totalRestSeconds;

  int _longRestSeconds = 900;
  int _longBreakEvery = 0;
  bool _isLongRest = false;
  bool get isLongRest => _isLongRest;

  int _remainingSeconds = 60;
  int get remainingSeconds => _remainingSeconds;

  int _totalSessions = 1;
  int get totalSessions => _totalSessions;

  int _currentSession = 1;
  int get currentSession => _currentSession;

  // Battle state
  int _heroHp = kHeroMaxHp;
  int get heroHp => _heroHp;
  int _pendingCoins = 0;
  int get pendingCoins => _pendingCoins;
  int _pendingLogs = 0;
  int get pendingLogs => _pendingLogs;
  final List<int> _completedSessionSeconds = [];
  final List<String?> _completedAnalyticsIds = [];
  final List<List<FocusInterval>> _completedSessionIntervals = [];
  final List<FocusInterval> _focusIntervals = [];
  DateTime? _focusStartedAt;
  DateTime? _phaseEndsAt;
  DateTime? _pauseEndsAt;
  int get pendingFocusSeconds =>
      _completedSessionSeconds.fold(0, (a, b) => a + b);
  ({int coins, int logs})? _lastSessionReward;
  ({int coins, int logs})? get lastSessionReward => _lastSessionReward;
  BattleResult? _lastResult;
  BattleResult? get lastResult => _lastResult;
  ({
    String id,
    int coins,
    int logs,
    List<int> seconds,
    List<String?> analyticsIds,
    List<List<FocusInterval>> intervals,
    String? constructionId,
  })?
  _unsettledVictory;
  bool get hasPendingSettlement =>
      _unsettledVictory != null || _unsettledFailure != null;
  bool _settling = false;
  bool get isSettling => _settling;
  bool _settlementFailed = false;
  bool get settlementFailed => _settlementFailed;
  bool _disposed = false;
  bool _starting = false;
  bool get isStarting => _starting;
  String? _constructionId;
  FocusBuilding? _focusBuilding;
  String? _unsettledFailure;
  Future<void>? _settlementFuture;

  // Pause state
  bool _isPaused = false;
  bool get isPaused => _isPaused;
  bool _pauseUsed = false;
  bool get canPause => isFocusing && !_isPaused && !_pauseUsed;
  int _pauseRemainingSeconds = kMaxPauseSeconds;
  int get pauseRemainingSeconds => _pauseRemainingSeconds;

  Timer? _countdownTimer;

  bool get isFocusing => _phase == SessionPhase.focus;
  bool get isResting => _phase == SessionPhase.rest;
  bool get isSetup => _phase == SessionPhase.setup;
  bool get inBattle => !isSetup;

  /// Goblin house HP: drains linearly with the focus countdown.
  double get houseHpRatio => isFocusing && _totalFocusSeconds > 0
      ? (_remainingSeconds / _totalFocusSeconds).clamp(0.0, 1.0)
      : 0.0;

  double get progressRatio {
    if (_phase == SessionPhase.focus && _totalFocusSeconds > 0) {
      return ((_totalFocusSeconds - _remainingSeconds) / _totalFocusSeconds)
          .clamp(0.0, 1.0);
    } else if (_phase == SessionPhase.rest) {
      final total = _isLongRest ? _longRestSeconds : _totalRestSeconds;
      if (total > 0) {
        return ((total - _remainingSeconds) / total).clamp(0.0, 1.0);
      }
    }
    return 0.0;
  }

  String get formattedTime => _format(_remainingSeconds);
  String get formattedPauseTime => _format(_pauseRemainingSeconds);

  static String _format(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  String get _sessionLabel =>
      _totalSessions > 1 ? ' (Phiên $_currentSession/$_totalSessions)' : '';

  /// Start a new battle (one or more focus sessions)
  Future<bool> startFocusSession({
    required String task,
    required int durationSeconds,
    int totalSessions = 1,
    int restDurationSeconds = 300,
    int longBreakEvery = 0,
    int longRestSeconds = 900,
  }) async {
    if (_disposed || _starting || inBattle || hasPendingSettlement) {
      return false;
    }
    if (durationSeconds < 1) {
      throw ArgumentError.value(durationSeconds, 'durationSeconds');
    }
    _starting = true;
    notifyListeners();
    try {
      final count = totalSessions > 0 ? totalSessions : 1;
      final minutes = (durationSeconds * count / 60).ceil();
      final id = await player.beginConstruction(
        task: task.trim(),
        focusMinutes: minutes,
      );
      if (_disposed) {
        await player.finishConstruction(id, won: false);
        return false;
      }
      _constructionId = id;
      _focusBuilding = focusBuildingForMinutes(minutes);
      _countdownTimer?.cancel();
      _taskName = task.trim().isEmpty ? 'Deep Work' : task.trim();
      _totalSessions = totalSessions > 0 ? totalSessions : 1;
      _currentSession = 1;
      _totalFocusSeconds = durationSeconds;
      _totalRestSeconds = restDurationSeconds;
      _longBreakEvery = longBreakEvery;
      _longRestSeconds = longRestSeconds;
      _heroHp = kHeroMaxHp;
      _pendingCoins = 0;
      _pendingLogs = 0;
      _completedSessionSeconds.clear();
      _completedAnalyticsIds.clear();
      _completedSessionIntervals.clear();
      _lastSessionReward = null;
      _lastResult = null;
      _beginFocus();
      return true;
    } finally {
      _starting = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _beginFocus({DateTime? startedAt}) {
    _phase = SessionPhase.focus;
    _isLongRest = false;
    _isPaused = false;
    _pauseUsed = false;
    _pauseRemainingSeconds = kMaxPauseSeconds;
    _remainingSeconds = _totalFocusSeconds;
    _focusIntervals.clear();
    _focusStartedAt = startedAt ?? _clock();
    _analyticsSession = {
      'id':
          '${_focusStartedAt!.microsecondsSinceEpoch}-${_analyticsSequence++}',
      'start': _focusStartedAt!.toUtc().toIso8601String(),
      'target': _totalFocusSeconds,
      'monitored': _analyticsMonitoring(),
      'interruptions': <String>[],
      'lifecycle': <Map<String, dynamic>>[],
      'pauses': <String>[],
      'resumes': <String>[],
      'intervals': <Map<String, dynamic>>[],
    };
    AnalyticsJournal.instance.save(_analyticsSession!);
    _phaseEndsAt = _focusStartedAt!.add(Duration(seconds: _totalFocusSeconds));
    _pauseEndsAt = null;
    notifyListeners();
    ForegroundTaskService.startSessionNotification(
      taskName: '$_taskName$_sessionLabel',
      remainingTime: _minutesLeft,
    );
    AlertNotifier.show(
      '⚔ Bắt đầu phiên $_currentSession/$_totalSessions',
      '$_taskName · ${_totalFocusSeconds ~/ 60} phút',
    );
    _startTicker();
  }

  /// Sticky-notification text; refreshed once a minute so the countdown stays silent.
  String get _minutesLeft => 'Còn ${(_remainingSeconds / 60).ceil()} phút';

  void _startTicker() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => refreshTimer(),
    );
  }

  static int _secondsUntil(DateTime end, DateTime now) => math.max(
    0,
    (end.difference(now).inMicroseconds / Duration.microsecondsPerSecond)
        .ceil(),
  );

  /// Catch up even if Android delayed callbacks while the process stayed alive.
  void refreshTimer() {
    if (!inBattle) return;
    final now = _clock();
    if (_isPaused) {
      _pauseRemainingSeconds = _secondsUntil(_pauseEndsAt!, now);
      if (_pauseRemainingSeconds > 0) {
        notifyListeners();
        return;
      }
      _resumePause(_pauseEndsAt!);
    }
    // Carry deadlines forward, so a late callback cannot lengthen later phases.
    while (inBattle && !now.isBefore(_phaseEndsAt!)) {
      _remainingSeconds = 0;
      if (isFocusing) {
        _onFocusCompleted();
      } else {
        _onRestCompleted();
      }
    }
    if (!inBattle) return;
    final previousMinutes = (_remainingSeconds / 60).ceil();
    _remainingSeconds = _secondsUntil(_phaseEndsAt!, now);
    notifyListeners();
    if ((_remainingSeconds / 60).ceil() != previousMinutes) {
      ForegroundTaskService.updateSessionNotification(
        taskName: isFocusing ? '$_taskName$_sessionLabel' : _restLabel,
        remainingTime: _minutesLeft,
      );
    }
  }

  String get _restLabel =>
      '${_isLongRest ? 'Nghỉ dài' : 'Nghỉ giải lao'} (Xong phiên $_currentSession/$_totalSessions)';

  @visibleForTesting
  void debugCompleteFocus() {
    if (!isFocusing || _isPaused) return;
    _onFocusCompleted();
  }

  /// Triggered when focus countdown reaches 0
  void _onFocusCompleted() {
    final endedAt = _phaseEndsAt!;
    _completedAnalyticsIds.add(_analyticsSession?['id'] as String?);
    _saveAnalyticsEnd('completed', endedAt);
    _countdownTimer?.cancel();
    ForegroundTaskService.stopSessionNotification();
    HapticFeedback.vibrate();
    SystemSound.play(SystemSoundType.alert);

    final reward = sessionReward(
      focusMinutes: _totalFocusSeconds ~/ 60,
      barracksLevel: player.levelOf(Building.barracks),
    );
    _lastSessionReward = reward;
    _pendingCoins += reward.coins;
    _pendingLogs += reward.logs;
    _completedSessionSeconds.add(_totalFocusSeconds);
    _focusIntervals.add((start: _focusStartedAt!, end: endedAt));
    _completedSessionIntervals.add(List.of(_focusIntervals));

    if (_currentSession < _totalSessions) {
      _isLongRest =
          _longBreakEvery > 0 && _currentSession % _longBreakEvery == 0;
      final rest = _isLongRest ? _longRestSeconds : _totalRestSeconds;
      AlertNotifier.show(
        '🎉 Xong phiên $_currentSession/$_totalSessions',
        '+${reward.coins} coin vào quỹ trận · nghỉ ${rest >= 60 ? "${rest ~/ 60} phút" : "$rest giây"}',
      );
      _phase = SessionPhase.rest;
      _isPaused = false;
      _remainingSeconds = rest;
      _phaseEndsAt = endedAt.add(Duration(seconds: rest));
      notifyListeners();
      ForegroundTaskService.startSessionNotification(
        taskName: _restLabel,
        remainingTime: _minutesLeft,
      );
      _startTicker();
    } else {
      HapticFeedback.heavyImpact();
      _settleVictory();
    }
  }

  void _settleVictory() {
    final seconds = List<int>.of(_completedSessionSeconds);
    final intervals = [
      for (final session in _completedSessionIntervals)
        List<FocusInterval>.of(session),
    ];
    _lastResult = BattleResult(
      won: true,
      coins: _pendingCoins,
      logs: _pendingLogs,
      focusSeconds: pendingFocusSeconds,
      sessions: seconds.length,
      building: _focusBuilding,
    );
    final coins = _pendingCoins, logs = _pendingLogs;
    _unsettledVictory = (
      id: 'battle-${DateTime.now().microsecondsSinceEpoch}',
      coins: coins,
      logs: logs,
      seconds: seconds,
      analyticsIds: List.of(_completedAnalyticsIds),
      intervals: intervals,
      constructionId: _constructionId,
    );
    final newRank = rankUp(
      _history.totalFocusSecondsAllTime,
      pendingFocusSeconds,
    );
    _resetToSetup();
    AlertNotifier.show('🏆 Hoàn thành trận!', '+$coins coin · +$logs log');
    if (newRank != null) {
      AlertNotifier.show(
        '🏅 Lên hạng ${newRank.label}!',
        'Mở khóa ${GameCharacter.values[newRank.index].label} và huy hiệu ${newRank.label}.',
        id: AlertNotifier.rank,
      );
    }
    unawaited(retrySettlement());
  }

  Future<void> retrySettlement() =>
      _settlementFuture ??= _performSettlement().whenComplete(() {
        _settlementFuture = null;
      });

  Future<void> _performSettlement() async {
    final payout = _unsettledVictory;
    final failed = _unsettledFailure;
    if (payout == null && failed == null) return;
    _settling = true;
    _settlementFailed = false;
    notifyListeners();
    try {
      if (payout != null) {
        await Settlement.commit(
          settlementId: payout.id,
          coins: payout.coins,
          logs: payout.logs,
          sessionSeconds: payout.seconds,
          analyticsSessionIds: payout.analyticsIds,
          sessionIntervals: payout.intervals,
          player: player,
          history: _history,
          constructionId: payout.constructionId,
        );
      } else {
        await player.finishConstruction(failed!, won: false);
      }
      _unsettledVictory = null;
      _unsettledFailure = null;
    } catch (_) {
      _settlementFailed = true;
    } finally {
      _settling = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _defeat({String reason = 'blacklist_penalty'}) {
    if (isFocusing) _saveAnalyticsEnd('defeated', _clock(), reason: reason);
    _countdownTimer?.cancel();
    ForegroundTaskService.stopSessionNotification();
    HapticFeedback.heavyImpact();
    AlertNotifier.show(
      '💀 Thất bại',
      'Mất toàn bộ phần thưởng và giờ của trận.',
    );
    _history.recordInterruption();
    _lastResult = BattleResult(
      won: false,
      coins: 0,
      logs: 0,
      focusSeconds: 0,
      sessions: _completedSessionSeconds.length,
      building: _focusBuilding,
    );
    _unsettledFailure = _constructionId;
    _resetToSetup();
    unawaited(retrySettlement());
  }

  void _resetToSetup() {
    _countdownTimer?.cancel();
    _phase = SessionPhase.setup;
    _isPaused = false;
    _isLongRest = false;
    _remainingSeconds = _totalFocusSeconds;
    _currentSession = 1;
    _pendingCoins = 0;
    _pendingLogs = 0;
    _completedSessionSeconds.clear();
    _completedAnalyticsIds.clear();
    _completedSessionIntervals.clear();
    _focusIntervals.clear();
    _focusStartedAt = null;
    _phaseEndsAt = null;
    _pauseEndsAt = null;
    _constructionId = null;
    _focusBuilding = null;
    notifyListeners();
  }

  /// Triggered when rest break finishes
  void _onRestCompleted() {
    _countdownTimer?.cancel();
    ForegroundTaskService.stopSessionNotification();
    HapticFeedback.vibrate();
    SystemSound.play(SystemSoundType.alert);
    final startedAt = _phaseEndsAt!;
    _currentSession++;
    _beginFocus(startedAt: startedAt);
  }

  /// Skip rest break directly to next focus session
  void finishRestBreak() {
    if (!isResting) return;
    final restingSession = _currentSession;
    refreshTimer();
    if (!isResting || _currentSession != restingSession) return;
    _countdownTimer?.cancel();
    ForegroundTaskService.stopSessionNotification();
    _currentSession++;
    _beginFocus();
  }

  /// One pause per session, up to [kMaxPauseSeconds]; auto-resumes.
  bool pause() {
    if (!canPause) return false;
    refreshTimer();
    if (!canPause) return false;
    final now = _clock();
    _focusIntervals.add((start: _focusStartedAt!, end: now));
    if (_analyticsSession != null) {
      (_analyticsSession!['pauses'] as List).add(now.toUtc().toIso8601String());
      AnalyticsJournal.instance.save(_analyticsSession!);
    }
    _pauseEndsAt = now.add(const Duration(seconds: kMaxPauseSeconds));
    _phaseEndsAt = _phaseEndsAt!.add(const Duration(seconds: kMaxPauseSeconds));
    _isPaused = true;
    _pauseUsed = true;
    _pauseRemainingSeconds = kMaxPauseSeconds;
    notifyListeners();
    ForegroundTaskService.updateSessionNotification(
      taskName: '$_taskName$_sessionLabel',
      remainingTime: 'Tạm dừng (tối đa ${kMaxPauseSeconds ~/ 60} phút)',
    );
    return true;
  }

  void resumeFromPause() {
    if (!_isPaused) return;
    final now = _clock();
    _resumePause(now.isBefore(_pauseEndsAt!) ? now : _pauseEndsAt!);
    refreshTimer();
  }

  void _resumePause(DateTime resumedAt) {
    if (_analyticsSession != null) {
      (_analyticsSession!['resumes'] as List).add(
        resumedAt.toUtc().toIso8601String(),
      );
      AnalyticsJournal.instance.save(_analyticsSession!);
    }
    _phaseEndsAt = _phaseEndsAt!.subtract(_pauseEndsAt!.difference(resumedAt));
    _focusStartedAt = resumedAt;
    _pauseEndsAt = null;
    _isPaused = false;
    notifyListeners();
    ForegroundTaskService.updateSessionNotification(
      taskName: '$_taskName$_sessionLabel',
      remainingTime: _minutesLeft,
    );
  }

  /// Hero takes [kPenaltyHp] damage for using a blacklisted app while focusing (incl. paused);
  /// rest breaks are free. 0 HP loses the battle.
  void applyBlacklistPenalty() {
    if (!isFocusing) return;
    _heroHp = math.max(0, _heroHp - kPenaltyHp);
    if (_heroHp == 0) {
      _defeat();
    } else {
      notifyListeners();
    }
  }

  /// Takes [kDistractionTax] coins from the battle escrow (never below 0).
  void applyDistractionTax() {
    if (!isFocusing) return;
    _pendingCoins = math.max(0, _pendingCoins - kDistractionTax);
    notifyListeners();
  }

  /// Cancel current session and return to setup (no rewards, nothing recorded)
  void cancelSession() {
    if (isFocusing) _saveAnalyticsEnd('cancelled', _clock());
    if (inBattle && _constructionId != null) {
      _defeat();
      return;
    }
    ForegroundTaskService.stopSessionNotification();
    _resetToSetup();
  }

  /// Give up the battle: forfeits all escrowed rewards and hours.
  void forceAbandonSession({String? reason}) {
    refreshTimer();
    if (!inBattle) return;
    _defeat(reason: reason ?? 'voluntary_abandon');
  }

  /// Records an interruption event (e.g. app sent to background during focus)
  void recordInterruptionEvent() {
    if (!isFocusing || _isPaused) return;
    if (_analyticsSession != null) {
      (_analyticsSession!['interruptions'] as List).add(
        _clock().toUtc().toIso8601String(),
      );
      AnalyticsJournal.instance.save(_analyticsSession!);
    }
    _history.recordInterruption();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _countdownTimer?.cancel();
    ForegroundTaskService.stopSessionNotification();
    super.dispose();
  }
}
