import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_dart/core/services/alert_notifier.dart';
import 'package:test_dart/features/shell/app_shell.dart';
import 'package:test_dart/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'battle guard follows the chosen app instead of the old fixed list',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({
        'fk_tracked_apps': '{"com.example.reader":"Reader"}',
      });
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const usage = MethodChannel('usage_stats');
      var package = 'com.facebook.katana';
      messenger.setMockMethodCallHandler(usage, (call) async {
        if (call.method == 'isUsagePermission') return true;
        if (call.method == 'queryEvents') {
          return [
            {
              'packageName': package,
              'eventType': '1',
              'timeStamp':
                  '${DateTime.now().subtract(const Duration(seconds: 1)).millisecondsSinceEpoch}',
            },
          ];
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(usage, null));
      final alerts = <String>[];
      AlertNotifier.sink = (title, body) async {
        alerts.add(title);
      };
      addTearDown(() => AlertNotifier.sink = null);
      Future<void> flush() async {
        for (var i = 0; i < 10; i++) {
          await tester.pump();
        }
      }

      void lifecycle(List<AppLifecycleState> states) {
        for (final state in states) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
      }

      void background() => lifecycle([
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]);
      void foreground() => lifecycle([
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
      await tester.pumpWidget(const FocusKnightApp());
      await flush();
      final shell = tester.widget<AppShell>(find.byType(AppShell));
      final starting = shell.controller.startFocusSession(
        task: 'T',
        durationSeconds: 1500,
      );
      await flush();
      await starting;
      alerts.clear();
      background();
      await tester.pump(const Duration(seconds: 2));
      await flush();
      expect(alerts.any((title) => title.contains('Facebook')), isFalse);
      foreground();
      await flush();
      package = 'com.example.reader';
      background();
      await tester.pump(const Duration(seconds: 2));
      await flush();
      expect(alerts.any((title) => title.contains('Reader')), isTrue);
      foreground();
      await flush();
      await tester.pumpWidget(const SizedBox.shrink());
      await flush();
    },
  );
}
