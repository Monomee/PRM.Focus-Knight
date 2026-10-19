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
  });
  final bool won;
  final int coins;
  final int logs;
  final int focusSeconds;
  final int sessions;
}

/// Controller for a battle: Pomodoro countdown, rest breaks, hero HP, pause, and the
/// battle escrow. Coin/Log and focus hours are only committed when the whole battle is won.
class FocusSessionController extends ChangeNotifier {
  FocusSessionController({PlayerState? player, FocusHistoryService? history})
      : player = player ?? PlayerState(),
        _history = history ?? FocusHistoryService.instance;

  final PlayerState player;
  final FocusHistoryService _history;

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
  int get pendingFocusSeconds => _completedSessionSeconds.fold(0, (a, b) => a + b);
  ({int coins, int logs})? _lastSessionReward;
  ({int coins, int logs})? get lastSessionReward => _lastSessionReward;
  BattleResult? _lastResult;
  BattleResult? get lastResult => _lastResult;

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
  double get houseHpRatio =>
      isFocusing && _totalFocusSeconds > 0 ? (_remainingSeconds / _totalFocusSeconds).clamp(0.0, 1.0) : 0.0;

  double get progressRatio {
    if (_phase == SessionPhase.focus && _totalFocusSeconds > 0) {
      return ((_totalFocusSeconds - _remainingSeconds) / _totalFocusSeconds).clamp(0.0, 1.0);
    } else if (_phase == SessionPhase.rest) {
      final total = _isLongRest ? _longRestSeconds : _totalRestSeconds;
      if (total > 0) return ((total - _remainingSeconds) / total).clamp(0.0, 1.0);
    }
    return 0.0;
  }

  String get formattedTime => _format(_remainingSeconds);
  String get formattedPauseTime => _format(_pauseRemainingSeconds);

  static String _format(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  String get _sessionLabel => _totalSessions > 1 ? ' (Phiên $_currentSession/$_totalSessions)' : '';

  /// Start a new battle (one or more focus sessions)
  void startFocusSession({
    required String task,
    required int durationSeconds,
    int totalSessions = 1,
    int restDurationSeconds = 300,
    int longBreakEvery = 0,
    int longRestSeconds = 900,
  }) {
    if (inBattle) return; // never wipe a running battle's escrow
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
    _lastSessionReward = null;
    _lastResult = null;
    _beginFocus();
  }

  void _beginFocus() {
    _phase = SessionPhase.focus;
    _isLongRest = false;
    _isPaused = false;
    _pauseUsed = false;
    _pauseRemainingSeconds = kMaxPauseSeconds;
    _remainingSeconds = _totalFocusSeconds;
    notifyListeners();
    ForegroundTaskService.startSessionNotification(
      taskName: '$_taskName$_sessionLabel',
      remainingTime: _minutesLeft,
    );
    AlertNotifier.show('⚔ Bắt đầu phiên $_currentSession/$_totalSessions',
        '$_taskName · ${_totalFocusSeconds ~/ 60} phút');
    _startTicker();
  }

  /// Sticky-notification text; refreshed once a minute so the countdown stays silent.
  String get _minutesLeft => 'Còn ${(_remainingSeconds / 60).ceil()} phút';

  void _startTicker() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (_isPaused) {
      _pauseRemainingSeconds--;
      if (_pauseRemainingSeconds <= 0) {
        resumeFromPause();
      } else {
        notifyListeners();
      }
      return;
    }
    if (_remainingSeconds > 1) {
      _remainingSeconds--;
      notifyListeners();
      if (_remainingSeconds % 60 == 0) {
        ForegroundTaskService.updateSessionNotification(
          taskName: isFocusing ? '$_taskName$_sessionLabel' : _restLabel,
          remainingTime: _minutesLeft,
        );
      }
      return;
    }
    _remainingSeconds = 0;
    if (isFocusing) {
      _onFocusCompleted();
    } else {
      _onRestCompleted();
    }
  }

  String get _restLabel => '${_isLongRest ? 'Nghỉ dài' : 'Nghỉ giải lao'} (Xong phiên $_currentSession/$_totalSessions)';

  @visibleForTesting
  void debugCompleteFocus() => _onFocusCompleted();

  /// Triggered when focus countdown reaches 0
  void _onFocusCompleted() {
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

    if (_currentSession < _totalSessions) {
      _isLongRest = _longBreakEvery > 0 && _currentSession % _longBreakEvery == 0;
      final rest = _isLongRest ? _longRestSeconds : _totalRestSeconds;
      AlertNotifier.show('🎉 Xong phiên $_currentSession/$_totalSessions',
          '+${reward.coins} coin vào quỹ trận · nghỉ ${rest >= 60 ? "${rest ~/ 60} phút" : "$rest giây"}');
      _phase = SessionPhase.rest;
      _isPaused = false;
      _remainingSeconds = rest;
      notifyListeners();
      ForegroundTaskService.startSessionNotification(taskName: _restLabel, remainingTime: _minutesLeft);
      _startTicker();
    } else {
      HapticFeedback.heavyImpact();
      _settleVictory();
    }
  }

  void _settleVictory() {
    final seconds = List<int>.of(_completedSessionSeconds);
    _lastResult = BattleResult(
      won: true,
      coins: _pendingCoins,
      logs: _pendingLogs,
      focusSeconds: pendingFocusSeconds,
      sessions: seconds.length,
    );
    final coins = _pendingCoins, logs = _pendingLogs;
    final newRank = rankUp(_history.totalFocusSecondsAllTime, pendingFocusSeconds);
    _resetToSetup();
    AlertNotifier.show('🏆 Hoàn thành trận!', '+$coins coin · +$logs log');
    if (newRank != null) {
      AlertNotifier.show('🏅 Lên hạng ${newRank.label}!',
          'Mở khóa ${GameCharacter.values[newRank.index].label} và huy hiệu ${newRank.label}.',
          id: AlertNotifier.rank);
    }
    Settlement.commit(coins: coins, logs: logs, sessionSeconds: seconds, player: player, history: _history);
  }

  void _defeat() {
    _countdownTimer?.cancel();
    ForegroundTaskService.stopSessionNotification();
    HapticFeedback.heavyImpact();
    AlertNotifier.show('💀 Thất bại', 'Mất toàn bộ phần thưởng và giờ của trận.');
    _history.recordInterruption();
    _lastResult = BattleResult(
      won: false,
      coins: 0,
      logs: 0,
      focusSeconds: 0,
      sessions: _completedSessionSeconds.length,
    );
    _resetToSetup();
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
    notifyListeners();
  }

  /// Triggered when rest break finishes
  void _onRestCompleted() {
    _countdownTimer?.cancel();
    ForegroundTaskService.stopSessionNotification();
    HapticFeedback.vibrate();
    SystemSound.play(SystemSoundType.alert);
    finishRestBreak();
  }

  /// Skip rest break directly to next focus session
  void finishRestBreak() {
    if (!isResting) return;
    _countdownTimer?.cancel();
    ForegroundTaskService.stopSessionNotification();
    _currentSession++;
    _beginFocus();
  }

  /// One pause per session, up to [kMaxPauseSeconds]; auto-resumes.
  bool pause() {
    if (!canPause) return false;
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
    ForegroundTaskService.stopSessionNotification();
    _resetToSetup();
  }

  /// Give up the battle: forfeits all escrowed rewards and hours.
  void forceAbandonSession({String? reason}) {
    if (!inBattle) return;
    _defeat();
  }

  /// Records an interruption event (e.g. app sent to background during focus)
  void recordInterruptionEvent() {
    _history.recordInterruption();
    notifyListeners();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    ForegroundTaskService.stopSessionNotification();
    super.dispose();
  }
}
