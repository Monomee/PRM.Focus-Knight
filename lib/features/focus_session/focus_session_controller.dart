import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/foreground_task_service.dart';
import '../dashboard/services/focus_history_service.dart';

enum SessionPhase {
  setup, // Choosing task and duration
  focus, // Active Pomodoro focus session (auto-battle runs, upgrades locked)
  rest, // Rest break (upgrades unlocked in Camp Shop)
}

/// Controller managing Pomodoro focus countdown, rest break, and phase transitions.
class FocusSessionController extends ChangeNotifier {
  SessionPhase _phase = SessionPhase.setup;
  SessionPhase get phase => _phase;

  String _taskName = 'Code API';
  String get taskName => _taskName;

  int _totalFocusSeconds = 60; // Default 1 min for fast testing, togglable to 25 min (1500s)
  int get totalFocusSeconds => _totalFocusSeconds;

  int _totalRestSeconds = 300; // 5 minutes (300s), or testable
  int get totalRestSeconds => _totalRestSeconds;

  int _remainingSeconds = 60;
  int get remainingSeconds => _remainingSeconds;

  int _totalSessions = 1;
  int get totalSessions => _totalSessions;

  int _currentSession = 1;
  int get currentSession => _currentSession;

  Timer? _countdownTimer;

  bool get isFocusing => _phase == SessionPhase.focus;
  bool get isResting => _phase == SessionPhase.rest;
  bool get isSetup => _phase == SessionPhase.setup;

  double get progressRatio {
    if (_phase == SessionPhase.focus && _totalFocusSeconds > 0) {
      return ((_totalFocusSeconds - _remainingSeconds) / _totalFocusSeconds).clamp(0.0, 1.0);
    } else if (_phase == SessionPhase.rest && _totalRestSeconds > 0) {
      return ((_totalRestSeconds - _remainingSeconds) / _totalRestSeconds).clamp(0.0, 1.0);
    }
    return 0.0;
  }

  String get formattedTime {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Start a new focus session or multi-session cycle
  void startFocusSession({
    required String task,
    required int durationSeconds,
    int totalSessions = 1,
    int restDurationSeconds = 300,
  }) {
    _countdownTimer?.cancel();
    _taskName = task.trim().isEmpty ? 'Deep Work' : task.trim();
    _totalSessions = totalSessions > 0 ? totalSessions : 1;
    _currentSession = 1;
    _totalFocusSeconds = durationSeconds;
    _totalRestSeconds = restDurationSeconds;
    _remainingSeconds = durationSeconds;
    _phase = SessionPhase.focus;
    notifyListeners();

    _startFocusCountdown();
  }

  void _startFocusCountdown() {
    _countdownTimer?.cancel();
    final sessionLabel = _totalSessions > 1 ? ' (Phiên $_currentSession/$_totalSessions)' : '';
    ForegroundTaskService.startSessionNotification(
      taskName: '$_taskName$sessionLabel',
      remainingTime: formattedTime,
    );

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 1) {
        _remainingSeconds--;
        notifyListeners();
        ForegroundTaskService.updateSessionNotification(
          taskName: '$_taskName$sessionLabel',
          remainingTime: formattedTime,
        );
      } else {
        _remainingSeconds = 0;
        _onFocusCompleted();
      }
    });
  }

  /// Triggered when focus countdown reaches 0
  void _onFocusCompleted() {
    _countdownTimer?.cancel();
    ForegroundTaskService.stopSessionNotification();

    // Record completed session in lightweight FocusHistoryService
    FocusHistoryService.instance.recordCompletedSession(_totalFocusSeconds);

    HapticFeedback.vibrate();
    SystemSound.play(SystemSoundType.alert);

    if (_currentSession < _totalSessions) {
      // More sessions remaining in this cycle: transition to Rest break!
      ForegroundTaskService.notifySessionEvent(
        title: '🎉 Hoàn thành phiên $_currentSession/$_totalSessions!',
        message: 'Bắt đầu nghỉ ngơi ${_totalRestSeconds >= 60 ? "${_totalRestSeconds ~/ 60} phút" : "$_totalRestSeconds giây"}. Phiên tiếp theo sẽ tự động bắt đầu.',
      );
      _phase = SessionPhase.rest;
      _remainingSeconds = _totalRestSeconds;
      notifyListeners();

      _startRestCountdown();
    } else {
      // All sessions completed!
      ForegroundTaskService.notifySessionEvent(
        title: '🏆 Hoàn thành mục tiêu tập trung!',
        message: 'Chúc mừng! Bạn đã hoàn thành toàn bộ $_totalSessions phiên tập trung.',
      );
      HapticFeedback.heavyImpact();
      _phase = SessionPhase.setup;
      _remainingSeconds = _totalFocusSeconds;
      _currentSession = 1;
      notifyListeners();
    }
  }

  void _startRestCountdown() {
    _countdownTimer?.cancel();
    final restLabel = 'Nghỉ giải lao (Xong phiên $_currentSession/$_totalSessions)';
    ForegroundTaskService.startSessionNotification(
      taskName: restLabel,
      remainingTime: formattedTime,
    );

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 1) {
        _remainingSeconds--;
        notifyListeners();
        ForegroundTaskService.updateSessionNotification(
          taskName: restLabel,
          remainingTime: formattedTime,
        );
      } else {
        _remainingSeconds = 0;
        _onRestCompleted();
      }
    });
  }

  /// Triggered when rest break finishes
  void _onRestCompleted() {
    _countdownTimer?.cancel();
    ForegroundTaskService.stopSessionNotification();
    HapticFeedback.vibrate();
    SystemSound.play(SystemSoundType.alert);

    if (_currentSession < _totalSessions) {
      // Automatically advance to the next focus session!
      _currentSession++;
      ForegroundTaskService.notifySessionEvent(
        title: '⚡ Bắt đầu phiên $_currentSession/$_totalSessions!',
        message: 'Hết giờ nghỉ! Hiệp sĩ tiếp tục chiến đấu tập trung.',
      );
      _phase = SessionPhase.focus;
      _remainingSeconds = _totalFocusSeconds;
      notifyListeners();

      _startFocusCountdown();
    } else {
      _phase = SessionPhase.setup;
      _remainingSeconds = _totalFocusSeconds;
      _currentSession = 1;
      notifyListeners();
    }
  }

  /// Skip rest break directly to next focus session or setup
  void finishRestBreak() {
    _countdownTimer?.cancel();
    ForegroundTaskService.stopSessionNotification();

    if (_currentSession < _totalSessions) {
      _currentSession++;
      _phase = SessionPhase.focus;
      _remainingSeconds = _totalFocusSeconds;
      notifyListeners();
      _startFocusCountdown();
    } else {
      _phase = SessionPhase.setup;
      _remainingSeconds = _totalFocusSeconds;
      _currentSession = 1;
      notifyListeners();
    }
  }

  /// Cancel current session and return to setup
  void cancelSession() {
    _countdownTimer?.cancel();
    ForegroundTaskService.stopSessionNotification();
    _phase = SessionPhase.setup;
    _remainingSeconds = _totalFocusSeconds;
    _currentSession = 1;
    notifyListeners();
  }

  /// Forcibly abandon session (via Mindful Interruption Log or forced exit)
  void forceAbandonSession({String? reason}) {
    _countdownTimer?.cancel();
    ForegroundTaskService.stopSessionNotification();
    HapticFeedback.heavyImpact();
    // Record interruption in telemetry for Distraction Velocity
    FocusHistoryService.instance.recordInterruption();
    _phase = SessionPhase.setup;
    _remainingSeconds = _totalFocusSeconds;
    _currentSession = 1;
    notifyListeners();
  }

  /// Records an interruption event (e.g. app sent to background during focus)
  void recordInterruptionEvent() {
    FocusHistoryService.instance.recordInterruption();
    notifyListeners();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    ForegroundTaskService.stopSessionNotification();
    super.dispose();
  }
}
