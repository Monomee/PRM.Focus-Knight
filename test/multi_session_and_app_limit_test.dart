import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_dart/features/focus_session/focus_session_controller.dart';
import 'package:test_dart/features/telemetry/screen_time_tracker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Per-App Time Limits (No 180 min cap)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Allows setting custom per-app limits without 180 min cap', () async {
      final tracker = ScreenTimeTracker();
      await tracker.init();

      // Default fallback
      expect(tracker.getAppLimit('com.facebook.katana'), 60);

      // Set custom limit to 300 minutes (exceeding old 180 min cap)
      await tracker.setAppLimit('com.facebook.katana', 300);
      expect(tracker.getAppLimit('com.facebook.katana'), 300);

      // Verify custom limit for TikTok
      await tracker.setAppLimit('com.zhiliaoapp.musically', 45);
      expect(tracker.getAppLimit('com.zhiliaoapp.musically'), 45);

      // Other apps still have default
      expect(tracker.getAppLimit('com.instagram.android'), 60);
    });
  });

  group('Multi-Session Cycles & Auto-Progression', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('FocusSessionController initializes and progresses through multi-session cycle', () async {
      final controller = FocusSessionController();

      expect(controller.isSetup, isTrue);
      expect(controller.totalSessions, 1);
      expect(controller.currentSession, 1);

      // Start 3-session cycle
      controller.startFocusSession(
        task: 'Tập trung học bài',
        durationSeconds: 1, // 1s for fast test
        totalSessions: 3,
        restDurationSeconds: 1,
      );

      expect(controller.isFocusing, isTrue);
      expect(controller.totalSessions, 3);
      expect(controller.currentSession, 1);
      expect(controller.taskName, 'Tập trung học bài');

      // Wait for focus countdown (1s) to complete
      await Future.delayed(const Duration(milliseconds: 1200));

      // Should automatically transition to rest phase for session 1
      expect(controller.isResting, isTrue);
      expect(controller.currentSession, 1);

      // Wait for rest countdown (1s) to complete
      await Future.delayed(const Duration(milliseconds: 1200));

      // Should automatically advance to session 2 and focus phase
      expect(controller.isFocusing, isTrue);
      expect(controller.currentSession, 2);

      controller.cancelSession();
      expect(controller.isSetup, isTrue);
    });
  });
}
