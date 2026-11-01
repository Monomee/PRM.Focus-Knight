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

  group('ScreenTimeTracker Daily Limit Logic', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({'fk_daily_limit_minutes': 45});
    });

    test(
      'Initializes with persisted limit and calculates limit getters correctly',
      () async {
        final tracker = ScreenTimeTracker();
        await tracker.init();

        expect(tracker.dailyLimitMinutes, 45);
        expect(tracker.isLimitExceeded, isFalse);
        expect(tracker.limitProgress, 0.0);
        expect(tracker.remainingTime.inMinutes, 45);

        await tracker.setDailyLimitMinutes(90);
        expect(tracker.dailyLimitMinutes, 90);
        expect(tracker.remainingTime.inMinutes, 90);
      },
    );
  });
}
