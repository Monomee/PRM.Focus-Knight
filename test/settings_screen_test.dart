import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_dart/core/services/overlay_service.dart';
import 'package:test_dart/features/settings/settings_screen.dart';
import 'package:test_dart/features/telemetry/screen_time_tracker.dart';

class TestScreenTimeTracker extends ScreenTimeTracker {
  int limit = 60;

  @override
  bool get hasPermission => true;

  @override
  int get dailyLimitMinutes => limit;

  @override
  Future<void> refreshUsageStats() async {}

  @override
  Future<void> setDailyLimitMinutes(int minutes) async {
    limit = minutes;
    notifyListeners();
  }

  void refresh() {
    notifyListeners();
  }
}

class TestOverlayService extends OverlayService {
  bool permission = false;
  int requests = 0;

  @override
  bool get hasPermission => permission;

  @override
  Future<bool> checkPermission() async => permission;

  @override
  Future<void> requestPermission() async {
    requests++;
  }

  void refresh() {
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'strict switch requests permission, stays off on denial and saves when granted',
    (tester) async {
      final tracker = TestScreenTimeTracker();
      final overlay = TestOverlayService();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsScreen(
              screenTimeTracker: tracker,
              overlayService: overlay,
            ),
          ),
        ),
      );
      await tester.pump();
      final toggle = find.byType(SwitchListTile);
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pump();
      expect(overlay.requests, 1);
      expect(tracker.strictModeEnabled, isFalse);
      expect(
        find.text('Cần cấp quyền Overlay để bật Strict mode.'),
        findsOneWidget,
      );
      overlay.permission = true;
      await tester.tap(toggle);
      await tester.pump();
      expect(tracker.strictModeEnabled, isTrue);
      expect(
        (await SharedPreferences.getInstance()).getBool('fk_strict_mode'),
        isTrue,
      );
      await tester.tap(toggle);
      await tester.pump();
      expect(tracker.strictModeEnabled, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      tracker.dispose();
      overlay.dispose();
    },
  );

  testWidgets(
    'notifications do not overwrite a focused dirty daily limit draft',
    (tester) async {
      final tracker = TestScreenTimeTracker();
      final overlay = TestOverlayService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsScreen(
              screenTimeTracker: tracker,
              overlayService: overlay,
            ),
          ),
        ),
      );
      await tester.pump();

      final field = find.byType(TextField).first;
      await tester.tap(field);
      await tester.enterText(field, '120');

      tracker.refresh();
      overlay.refresh();
      await tester.pump();

      expect(tester.widget<TextField>(field).controller?.text, '120');

      tracker.limit = 90;
      tracker.refresh();
      await tester.pump();

      expect(tester.widget<TextField>(field).controller?.text, '120');
    },
  );

  testWidgets(
    'syncs a clean unfocused field only after the configured limit changes',
    (tester) async {
      final tracker = TestScreenTimeTracker();
      final overlay = TestOverlayService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsScreen(
              screenTimeTracker: tracker,
              overlayService: overlay,
            ),
          ),
        ),
      );
      await tester.pump();

      final field = find.byType(TextField).first;
      tracker.refresh();
      await tester.pump();
      expect(tester.widget<TextField>(field).controller?.text, '60');

      tracker.limit = 90;
      tracker.refresh();
      await tester.pump();

      expect(tester.widget<TextField>(field).controller?.text, '90');
    },
  );
}
