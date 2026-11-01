import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_dart/features/telemetry/screen_time_tracker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('strict mode defaults off and persists both choices', () async {
    SharedPreferences.setMockInitialValues({});
    final tracker = ScreenTimeTracker();
    addTearDown(tracker.dispose);
    await tracker.init();
    expect(tracker.strictModeEnabled, isFalse);
    await tracker.setStrictModeEnabled(true);
    final restored = ScreenTimeTracker();
    addTearDown(restored.dispose);
    await restored.init();
    expect(restored.strictModeEnabled, isTrue);
    await restored.setStrictModeEnabled(false);
    expect(
      (await SharedPreferences.getInstance()).getBool('fk_strict_mode'),
      false,
    );
  });

  test('apps without a custom limit use 30 minutes and ignore the old global setting', () async {
    SharedPreferences.setMockInitialValues({
      'fk_daily_limit_minutes': 120,
      'fk_app_limit_com.facebook.katana': 86,
    });
    final tracker = ScreenTimeTracker();
    addTearDown(tracker.dispose);
    await tracker.ready;
    expect(tracker.getAppLimit('com.facebook.katana'), 86);
    expect(tracker.getAppLimit('com.instagram.android'), 30);
    await tracker.setTrackedApps({'com.example.reader': 'Reader'});
    expect(tracker.getAppLimit('com.example.reader'), 30);
    await tracker.setAppLimit('com.example.reader', 75);
    final restored = ScreenTimeTracker();
    addTearDown(restored.dispose);
    await restored.ready;
    expect(restored.getAppLimit('com.example.reader'), 75);
    await restored.reloadLimits();
    expect(restored.getAppLimit('com.example.reader'), 75);
  });
}
