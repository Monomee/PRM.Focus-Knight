import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_dart/core/services/overlay_service.dart';
import 'package:test_dart/features/settings/settings_screen.dart';
import 'package:test_dart/features/telemetry/screen_time_tracker.dart';

class TestScreenTimeTracker extends ScreenTimeTracker {
  @override
  bool get hasPermission => true;
  @override
  Future<void> refreshUsageStats() async {}
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
    'only per-app limits are editable and new apps start at 30 minutes',
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
      expect(find.byType(TextField), findsNothing);
      expect(find.text('HẠN MỨC MẶC ĐỊNH'), findsNothing);
      final edit = find.byIcon(Icons.edit).first;
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      final field = find.byType(TextField);
      expect(tester.widget<TextField>(field).controller!.text, '30');
      await tester.enterText(field, '90');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Lưu'));
      await tester.pumpAndSettle();
      expect(tracker.getAppLimit('com.facebook.katana'), 90);
      expect(find.text('0s / 90m'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      tracker.dispose();
      overlay.dispose();
    },
  );
}
