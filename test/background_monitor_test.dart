import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_dart/core/services/alert_notifier.dart';
import 'package:test_dart/core/services/foreground_task_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const usage = MethodChannel('usage_stats');
  const overlay = MethodChannel('x-slayer/overlay_channel');
  const nativeOverlay = MethodChannel('focusknight/overlay');
  const messages = BasicMessageChannel<dynamic>(
    'x-slayer/overlay_messenger',
    JSONMessageCodec(),
  );
  late bool active;
  late List<String> alerts;
  late List<dynamic> shared;
  late FocusTaskHandler task;
  Completer<bool>? pendingOverlayPermission;
  late String currentPackage;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'fk_app_limit_com.facebook.katana': 1,
      'fk_app_limit_com.google.android.youtube': 1,
      'fk_app_limit_com.instagram.android': 1,
      'fk_app_limit_com.example.reader': 1,
      'fk_strict_mode': true,
    });
    active = false;
    alerts = [];
    shared = [];
    pendingOverlayPermission = null;
    currentPackage = 'com.facebook.katana';
    AlertNotifier.sink = (title, body) async => alerts.add(title);
    messenger.setMockMethodCallHandler(usage, (call) async {
      if (call.method == 'isUsagePermission') return true;
      if (call.method == 'queryEvents') {
        return [
          {
            'packageName': currentPackage,
            'eventType': '1',
            'timeStamp':
                '${DateTime.now().subtract(const Duration(minutes: 2)).millisecondsSinceEpoch}',
          },
        ];
      }
      return null;
    });
    messenger.setMockMethodCallHandler(overlay, (call) async {
      if (call.method == 'checkPermission') {
        return pendingOverlayPermission?.future ?? true;
      }
      if (call.method == 'isOverlayActive') return active;
      if (call.method == 'showOverlay') active = true;
      return null;
    });
    messenger.setMockMethodCallHandler(nativeOverlay, (call) async {
      if (call.method == 'shareData') {
        shared.add(call.arguments);
      } else {
        active = false;
      }
      return null;
    });
    // The overlay plugin's messenger handler can disappear when the UI engine detaches.
    messenger.setMockDecodedMessageHandler(messages, (data) async => null);
    task = FocusTaskHandler();
  });

  tearDown(() async {
    await task.onDestroy(DateTime.now(), false);
    await pumpEventQueue();
    AlertNotifier.sink = null;
    messenger.setMockMethodCallHandler(usage, null);
    messenger.setMockMethodCallHandler(overlay, null);
    messenger.setMockMethodCallHandler(nativeOverlay, null);
    messenger.setMockDecodedMessageHandler(messages, null);
  });

  Future<void> tick([DateTime? now]) async {
    task.onRepeatEvent(now ?? DateTime.now());
    await pumpEventQueue();
  }

  test('restarted service blocks an already open over-limit app without a Flutter screen', () async {
    await task.onStart(DateTime.now(), TaskStarter.system);
    await tick();
    expect(active, isTrue);
    expect(shared.last, containsPair('app', 'Facebook'));
    expect(alerts.any((title) => title.contains('Facebook')), isTrue);
  });

  test('background worker blocks a custom selected app and unblocks when deselected', () async {
    currentPackage = 'com.example.reader';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'fk_tracked_apps',
      jsonEncode({currentPackage: 'Reader'}),
    );
    await task.onStart(DateTime.now(), TaskStarter.system);
    await tick();
    expect(active, isTrue);
    expect(shared.last, containsPair('app', 'Reader'));
    await prefs.setString('fk_tracked_apps', '{}');
    await tick();
    expect(active, isFalse);
  });

  test('worker reloads settings written by the UI and closes when strict is disabled', () async {
    await task.onStart(DateTime.now(), TaskStarter.system);
    await tick();
    expect(active, isTrue);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fk_strict_mode', false);
    await tick();
    expect(active, isFalse);
    await prefs.setBool('fk_strict_mode', true);
    await prefs.setInt('fk_app_limit_com.facebook.katana', 120);
    await tick();
    expect(active, isFalse);
  });

  test(
    'battle heartbeat suppresses daily blocker and expires if UI is removed',
    () async {
      final now = DateTime.now();
      await task.onStart(now, TaskStarter.system);
      task.onReceiveData({
        'battleUntil': now
            .add(const Duration(seconds: 8))
            .millisecondsSinceEpoch,
      });
      await tick(now);
      expect(active, isFalse);
      await tick(now.add(const Duration(seconds: 10)));
      expect(active, isTrue);
    },
  );

  test(
    'battle starting during alert dispatch prevents a daily overlay',
    () async {
      currentPackage = 'com.instagram.android';
      final alertStarted = Completer<void>();
      final releaseAlert = Completer<void>();
      AlertNotifier.sink = (title, body) async {
        alertStarted.complete();
        await releaseAlert.future;
      };
      final now = DateTime.now();
      await task.onStart(now, TaskStarter.system);
      task.onRepeatEvent(now);
      await alertStarted.future;
      task.onReceiveData({
        'battleUntil': now
            .add(const Duration(seconds: 8))
            .millisecondsSinceEpoch,
      });
      releaseAlert.complete();
      await pumpEventQueue();
      expect(active, isFalse);
    },
  );

  test(
    'battle heartbeat cancels a daily overlay waiting for permission',
    () async {
      final now = DateTime.now();
      await task.onStart(now, TaskStarter.system);
      pendingOverlayPermission = Completer<bool>();
      task.onRepeatEvent(now);
      await pumpEventQueue();
      task.onReceiveData({
        'battleUntil': now
            .add(const Duration(seconds: 8))
            .millisecondsSinceEpoch,
      });
      pendingOverlayPermission!.complete(true);
      await pumpEventQueue();
      expect(active, isFalse);
    },
  );
}
