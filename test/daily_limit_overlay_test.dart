import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_dart/core/services/alert_notifier.dart';
import 'package:test_dart/core/services/overlay_service.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:test_dart/core/services/foreground_task_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const overlayChannel = MethodChannel('x-slayer/overlay_channel');
  const nativeOverlayChannel = MethodChannel('focusknight/overlay');
  const usageChannel = MethodChannel('usage_stats');
  const messages = BasicMessageChannel<dynamic>(
    'x-slayer/overlay_messenger',
    JSONMessageCodec(),
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late bool granted;
  late bool active;
  late List<String> calls;
  late List<dynamic> shared;
  late List<Map<String, String>> events;
  Completer<bool>? pendingPermission;
  bool hangOnInactiveClose = false;
  Completer<bool>? permissionRequest;
  bool delayActivation = false;
  Timer? activationTimer;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'fk_app_limit_com.facebook.katana': 1,
      'fk_app_limit_com.google.android.youtube': 1,
      'fk_app_limit_com.instagram.android': 1,
      'fk_app_limit_com.example.reader': 1,
    });
    granted = true;
    active = false;
    calls = [];
    shared = [];
    events = [];
    pendingPermission = null;
    hangOnInactiveClose = false;
    permissionRequest = null;
    delayActivation = false;
    messenger.setMockMethodCallHandler(overlayChannel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'checkPermission':
          return pendingPermission?.future ?? granted;
        case 'requestPermission':
          return permissionRequest?.future ?? granted;
        case 'isOverlayActive':
          return active;
        case 'showOverlay':
          if (delayActivation) {
            activationTimer = Timer(const Duration(milliseconds: 20), () {
              active = true;
            });
          } else {
            active = true;
          }
          return null;
        case 'closeOverlay':
          if (!active && hangOnInactiveClose) return Completer<bool>().future;
          active = false;
          return true;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(nativeOverlayChannel, (call) async {
      if (call.method == 'shareData') {
        shared.add(call.arguments);
        return null;
      }
      calls.add('nativeClose');
      activationTimer?.cancel();
      active = false;
      return null;
    });
    messenger.setMockDecodedMessageHandler(messages, (data) async {
      shared.add(data);
      return data;
    });
    messenger.setMockMethodCallHandler(usageChannel, (call) async {
      if (call.method == 'isUsagePermission') return true;
      if (call.method == 'queryEvents') return events;
      return null;
    });
  });

  tearDown(() {
    activationTimer?.cancel();
    activationTimer = null;
    AlertNotifier.sink = null;
    messenger.setMockMethodCallHandler(overlayChannel, null);
    messenger.setMockMethodCallHandler(nativeOverlayChannel, null);
    messenger.setMockMethodCallHandler(usageChannel, null);
    messenger.setMockDecodedMessageHandler(messages, null);
  });

  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
  }

  void visit(String pkg) {
    final now = DateTime.now().millisecondsSinceEpoch;
    events = [
      {'packageName': pkg, 'eventType': '1', 'timeStamp': '${now - 70000}'},
      {'packageName': pkg, 'eventType': '1', 'timeStamp': '${now - 1000}'},
    ];
  }

  testWidgets(
    'background worker notifies in both modes and closes when conditions end',
    (tester) async {
      final alerts = <String>[];
      AlertNotifier.sink = (title, body) async {
        alerts.add(title);
      };
      final worker = FocusTaskHandler();
      await worker.onStart(DateTime.now(), TaskStarter.system);
      Future<void> tick() async {
        worker.onRepeatEvent(DateTime.now());
        await flush(tester);
      }

      final prefs = await SharedPreferences.getInstance();
      visit('com.google.android.youtube');
      await tick();
      expect(alerts.any((a) => a.contains('YouTube')), isTrue);
      expect(active, isFalse);

      await prefs.setBool('fk_strict_mode', true);
      visit('com.facebook.katana');
      await tick();
      expect(alerts.any((a) => a.contains('Facebook')), isTrue);
      expect(active, isTrue);
      expect(shared.last, containsPair('mode', 'dailyLimit'));
      expect(shared.last, containsPair('app', 'Facebook'));

      visit('com.google.android.youtube');
      await tick();
      expect(shared.last, containsPair('app', 'YouTube'));
      events.add({
        'packageName': 'android',
        'eventType': '16',
        'timeStamp': '${DateTime.now().millisecondsSinceEpoch}',
      });
      await tick();
      expect(active, isFalse);

      visit('com.facebook.katana');
      await tick();
      expect(active, isTrue);
      await prefs.setInt('fk_app_limit_com.facebook.katana', 120);
      await tick();
      expect(active, isFalse);

      granted = false;
      await prefs.setInt('fk_app_limit_com.facebook.katana', 1);
      await tick();
      expect(active, isFalse);
      granted = true;
      await tick();
      expect(active, isTrue);
      await prefs.setBool('fk_strict_mode', false);
      await tick();
      expect(active, isFalse);
      await worker.onDestroy(DateTime.now(), false);
      await flush(tester);
    },
  );

  test('close cancels an overlay opening during permission check', () async {
    final overlay = OverlayService();
    await overlay.checkPermission();
    overlay.isAppInForeground = false;
    pendingPermission = Completer<bool>();
    final opening = overlay.showBlockerOverlay();
    await Future<void>.delayed(Duration.zero);
    final closing = overlay.closeBlockerOverlay();
    pendingPermission!.complete(true);
    await Future.wait([opening, closing]);
    expect(calls.where((c) => c == 'showOverlay'), isEmpty);
    expect(active, isFalse);
    overlay.dispose();
  });

  test(
    'permission request is not overwritten by resume checks or closing',
    () async {
      final overlay = OverlayService();
      await overlay.checkPermission();
      permissionRequest = Completer<bool>();
      final requesting = overlay.requestPermission();
      await Future<void>.delayed(Duration.zero);
      calls.clear();
      await overlay.checkPermission();
      final closing = overlay.closeBlockerOverlay();
      await Future<void>.delayed(Duration.zero);
      final callsWhileRequesting = List<String>.of(calls);
      permissionRequest!.complete(true);
      await Future.wait([requesting, closing]);
      expect(
        callsWhileRequesting,
        isEmpty,
        reason: 'Plugin 0.5.0 replaces its pending permission result on every method call',
      );
      expect(overlay.hasPermission, isTrue);
      overlay.dispose();
    },
  );

  test(
    'closing an inactive native overlay does not stall later opens',
    () async {
      hangOnInactiveClose = true;
      final overlay = OverlayService();
      await overlay.checkPermission();
      await overlay.closeBlockerOverlay().timeout(
        const Duration(milliseconds: 100),
      );
      expect(calls.where((c) => c == 'closeOverlay'), isEmpty);
      overlay.isAppInForeground = false;
      await overlay.showDailyLimitOverlay(appName: 'Facebook', limitMinutes: 1);
      expect(active, isTrue);
      await overlay.closeBlockerOverlay();
      overlay.dispose();
    },
  );

  test(
    'resume closes a native overlay whose service starts after show returns',
    () async {
      delayActivation = true;
      final overlay = OverlayService();
      await overlay.checkPermission();
      overlay.isAppInForeground = false;
      final opening = overlay.showDailyLimitOverlay(
        appName: 'Facebook',
        limitMinutes: 1,
      );
      await Future<void>.delayed(Duration.zero);
      expect(calls, contains('showOverlay'));
      overlay.isAppInForeground = true;
      final closing = overlay.closeBlockerOverlay();
      await Future.wait([opening, closing]);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(active, isFalse);
      expect(overlay.isOverlayOpen, isFalse);
      overlay.dispose();
    },
  );
}
