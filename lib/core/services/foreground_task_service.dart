import 'dart:async';
import 'dart:ui';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'alert_notifier.dart';

// Top-level entry point required by flutter_foreground_task
@pragma('vm:entry-point')
void foregroundTaskCallback() {
  FlutterForegroundTask.setTaskHandler(FocusTaskHandler());
}

/// Background task handler that keeps the countdown timer active and updates sticky notification
class FocusTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onReceiveData(Object data) {
    if (data is Map) {
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
  // Knight-helmet silhouette; declared as meta-data in AndroidManifest.xml.
  static const _icon = NotificationIcon(
    metaDataName: 'com.example.test_dart.SESSION_NOTIFICATION_ICON',
    backgroundColor: Color(0xFF2F8F91),
  );

  static void init() {
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
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  static Future<void> requestPermissions() async {
    try {
      final notificationPermission = await FlutterForegroundTask.checkNotificationPermission();
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
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
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
