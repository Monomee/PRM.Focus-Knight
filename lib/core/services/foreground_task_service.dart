import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

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
  static void init() {
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'focus_session_service',
        channelName: 'FocusKnight Session Timer',
        channelDescription: 'Keeps focus session timer alive and updates sticky notification.',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
        onlyAlertOnce: false,
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
          notificationText: 'Focusing on $taskName: $remainingTime left',
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
          notificationText: 'Focusing on $taskName: $remainingTime left',
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

  /// Shows standard Android heads-up notification popup when a social media limit is exceeded
  static Future<void> notifyAppLimitExceeded({
    required String appName,
    required String packageName,
    required int limitMinutes,
  }) async {
    try {
      final now = DateTime.now();
      // Throttle notifications: do not alert more than once every 2 minutes for the same app
      if (_lastNotifiedPackage == packageName &&
          _lastNotificationTime != null &&
          now.difference(_lastNotificationTime!) < const Duration(minutes: 2)) {
        return;
      }

      _lastNotificationTime = now;
      _lastNotifiedPackage = packageName;

      await requestPermissions();
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: '⚠️ Cảnh báo hạn mức: $appName',
          notificationText: 'Bạn đã dùng $appName vượt quá $limitMinutes phút hôm nay! Hãy nghỉ ngơi.',
        );
      } else {
        await FlutterForegroundTask.startService(
          serviceTypes: [ForegroundServiceTypes.specialUse],
          notificationTitle: '⚠️ Cảnh báo hạn mức: $appName',
          notificationText: 'Bạn đã dùng $appName vượt quá $limitMinutes phút hôm nay! Hãy nghỉ ngơi.',
          callback: foregroundTaskCallback,
        );
      }
    } catch (_) {}
  }

  /// Shows standard Android heads-up notification popup when a session event occurs (inter-session or completion)
  static Future<void> notifySessionEvent({
    required String title,
    required String message,
  }) async {
    try {
      await requestPermissions();
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: message,
        );
      } else {
        await FlutterForegroundTask.startService(
          serviceTypes: [ForegroundServiceTypes.specialUse],
          notificationTitle: title,
          notificationText: message,
          callback: foregroundTaskCallback,
        );
      }
    } catch (_) {}
  }
}
