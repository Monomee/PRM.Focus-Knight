import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_dart/core/services/foreground_task_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('flutter_foreground_task/methods');
  const usage = MethodChannel('usage_stats');
  late bool running;
  late bool permission;
  late List<MethodCall> calls;

  setUp(() {
    running = false;
    permission = true;
    calls = [];
    FlutterForegroundTask.resetStatic();
    ForegroundTaskService.init();
    FlutterForegroundTask.skipServiceResponseCheck = true;
    messenger.setMockMethodCallHandler(usage, (call) async => permission);
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'isRunningService') return running;
      if (call.method == 'checkNotificationPermission') {
        return NotificationPermission.granted.index;
      }
      if (call.method == 'startService') running = true;
      if (call.method == 'stopService') running = false;
      return null;
    });
  });

  tearDown(() async {
    await pumpEventQueue();
    FlutterForegroundTask.resetStatic();
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(usage, null);
  });

  test(
    'monitor starts without a battle and remains running after a battle ends',
    () async {
      await ForegroundTaskService.ensureMonitoring();
      expect(running, isTrue);
      await ForegroundTaskService.startSessionNotification(
        taskName: 'T',
        remainingTime: '1 phút',
      );
      await ForegroundTaskService.stopSessionNotification();
      expect(running, isTrue);
      expect(calls.where((c) => c.method == 'startService'), hasLength(1));
      expect(calls.where((c) => c.method == 'stopService'), isEmpty);
      final lastUpdate = calls.lastWhere((c) => c.method == 'updateService');
      expect(lastUpdate.arguments.toString(), contains('giám sát hạn mức'));
      final options = FlutterForegroundTask.foregroundTaskOptions!;
      expect(options.stopWithTask, isFalse);
      expect(options.autoRunOnBoot, isTrue);
      expect(options.autoRunOnMyPackageReplaced, isTrue);
    },
  );

  test(
    'monitor does not start or request notifications without usage permission',
    () async {
      permission = false;
      await ForegroundTaskService.ensureMonitoring();
      expect(running, isFalse);
      expect(calls.map((c) => c.method), ['isRunningService']);
    },
  );
}
