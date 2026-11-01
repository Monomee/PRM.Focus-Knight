import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:usage_stats/usage_stats.dart';

import '../../features/telemetry/screen_time_tracker.dart';
import 'alert_notifier.dart';
import 'overlay_service.dart';

// Top-level entry point required by flutter_foreground_task
@pragma('vm:entry-point')
void foregroundTaskCallback() {
  FlutterForegroundTask.setTaskHandler(FocusTaskHandler());
}

/// Daily monitoring lives here so it survives destruction of the Activity's engine.
class FocusTaskHandler extends TaskHandler {
  ScreenTimeTracker? _tracker;
  OverlayService? _overlay;
  bool _checking = false;
  bool _blocked = false;
  bool _destroyed = false;
  int _battleUntil = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _tracker = ScreenTimeTracker();
    _overlay = OverlayService()..isAppInForeground = false;
    await _tracker!.ready;
    _tracker!.stopPeriodicTracking();
    FlutterForegroundTask.sendDataToMain('monitorReady');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    unawaited(_checkDailyLimit(timestamp));
  }

  Future<void> _checkDailyLimit(DateTime now) async {
    if (_checking || _destroyed || _tracker == null) return;
    _checking = true;
    final tracker = _tracker!;
    final overlay = _overlay!;
    try {
      if (now.millisecondsSinceEpoch < _battleUntil) return;
      await tracker.reloadLimits();
      await tracker.checkPermission();
      tracker.stopPeriodicTracking();
      final pkg = await tracker.getActiveBlacklistedPackage();
      await tracker.refreshUsageStats();
      if (_destroyed || now.millisecondsSinceEpoch < _battleUntil) return;
      if (pkg != null && tracker.isAppLimitExceeded(pkg)) {
        final name = tracker.appNameFor(pkg);
        await ForegroundTaskService.notifyAppLimitExceeded(
          appName: name,
          packageName: pkg,
          limitMinutes: tracker.getAppLimit(pkg),
        );
        if (_destroyed || now.millisecondsSinceEpoch < _battleUntil) return;
        if (tracker.strictModeEnabled) {
          _blocked = true;
          await overlay.showDailyLimitOverlay(
            appName: name,
            limitMinutes: tracker.getAppLimit(pkg),
          );
          return;
        }
      }
      if (_blocked) {
        _blocked = false;
        await overlay.closeBlockerOverlay();
      }
    } catch (error) {
      debugPrint('Daily monitor: $error');
    } finally {
      _checking = false;
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _destroyed = true;
    _tracker?.dispose();
    _overlay?.dispose();
  }

  @override
  void onReceiveData(Object data) {
    if (data is Map) {
      _battleUntil = data['battleUntil'] as int? ?? _battleUntil;
      if (_battleUntil > DateTime.now().millisecondsSinceEpoch) {
        if (_blocked) unawaited(_overlay?.closeBlockerOverlay());
        _blocked = false;
      }
      final title = data['title'] as String?;
      final text = data['text'] as String?;
      if (title != null && text != null) {
        FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: text,
        );
      }
    }
  }

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/');
  }

  @override
  void onNotificationDismissed() {}
}

/// Wrapper service managing foreground task lifecycle
class ForegroundTaskService {
  static bool _configured = false;
  // Knight-helmet silhouette; declared as meta-data in AndroidManifest.xml.
  static const _icon = NotificationIcon(
    metaDataName: 'com.example.test_dart.SESSION_NOTIFICATION_ICON',
    backgroundColor: Color(0xFF2F8F91),
  );

  static void init() {
    _configured = true;
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        // Silent sticky timer. A new id is needed: Android never lowers an existing channel's
        // importance. Alerts (session start/end, violations, rank up) go through AlertNotifier.
        channelId: 'focus_session_silent',
        channelName: 'FocusKnight – đồng hồ phiên',
        channelDescription: 'Thông báo thường trực giữ đồng hồ phiên chạy nền (không âm thanh).',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(2000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        stopWithTask: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  static Future<void>? _startingMonitor;

  static Future<void> ensureMonitoring() =>
      _startingMonitor ??= _startMonitoring().whenComplete(() {
        _startingMonitor = null;
      });

  static Future<void> _startMonitoring() async {
    try {
      if (await FlutterForegroundTask.isRunningService) return;
      if (!(await UsageStats.checkUsagePermission() ?? false)) return;
      await requestPermissions();
      final result = await FlutterForegroundTask.startService(
        serviceTypes: [ForegroundServiceTypes.specialUse],
        notificationTitle: 'FocusKnight đang giám sát hạn mức',
        notificationText: 'Cảnh báo và Strict mode hoạt động trong nền.',
        notificationIcon: _icon,
        callback: foregroundTaskCallback,
      );
      if (result is ServiceRequestFailure) {
        debugPrint('Start monitor: ${result.error}');
      }
    } catch (error) {
      debugPrint('Start monitor: $error');
    }
  }

  static void sendBattleState(bool inBattle) {
    if (!_configured) return;
    // A removed UI stops heartbeats, so it cannot suppress daily limits forever.
    FlutterForegroundTask.sendDataToTask({
      'battleUntil': inBattle
          ? DateTime.now()
                .add(const Duration(seconds: 8))
                .millisecondsSinceEpoch
          : 0,
    });
  }

  static Future<void> requestPermissions() async {
    try {
      final notificationPermission =
          await FlutterForegroundTask.checkNotificationPermission();
      if (notificationPermission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
    } catch (_) {}
  }

  static Future<void> startSessionNotification({
    required String taskName,
    required String remainingTime,
  }) async {
    try {
      await requestPermissions();
      if (await FlutterForegroundTask.isRunningService) {
        await updateSessionNotification(
          taskName: taskName,
          remainingTime: remainingTime,
        );
      } else {
        await FlutterForegroundTask.startService(
          serviceTypes: [ForegroundServiceTypes.specialUse],
          notificationTitle: 'FocusKnight: $taskName',
          notificationText: remainingTime,
          notificationIcon: _icon,
          callback: foregroundTaskCallback,
        );
      }
    } catch (_) {}
  }

  static Future<void> updateSessionNotification({
    required String taskName,
    required String remainingTime,
  }) async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: 'FocusKnight: $taskName',
          notificationText: remainingTime,
        );
      }
    } catch (_) {}
  }

  static Future<void> stopSessionNotification() async {
    try {
      sendBattleState(false);
      if (await FlutterForegroundTask.isRunningService) {
        if (await UsageStats.checkUsagePermission() ?? false) {
          await FlutterForegroundTask.updateService(
            notificationTitle: 'FocusKnight đang giám sát hạn mức',
            notificationText: 'Cảnh báo và Strict mode hoạt động trong nền.',
          );
        } else {
          await FlutterForegroundTask.stopService();
        }
      }
    } catch (_) {}
  }

  static DateTime? _lastNotificationTime;
  static String? _lastNotifiedPackage;

  /// Alerts when a social media app is over its daily limit (outside a battle).
  static Future<void> notifyAppLimitExceeded({
    required String appName,
    required String packageName,
    required int limitMinutes,
  }) async {
    final now = DateTime.now();
    // Throttle notifications: do not alert more than once every 2 minutes for the same app
    if (_lastNotifiedPackage == packageName &&
        _lastNotificationTime != null &&
        now.difference(_lastNotificationTime!) < const Duration(minutes: 2)) {
      return;
    }
    _lastNotificationTime = now;
    _lastNotifiedPackage = packageName;
    await AlertNotifier.show(
      '⚠️ Cảnh báo hạn mức: $appName',
      'Bạn đã dùng $appName vượt quá $limitMinutes phút hôm nay! Hãy nghỉ ngơi.',
      id: AlertNotifier.appLimit,
    );
  }
}
