import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_dart/features/dashboard/services/focus_history_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FocusHistoryService & Streak Edge Case A Tests', () {
    late FocusHistoryService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = FocusHistoryService();
    });

    test('Lỗ hổng A: Streak does not reset to 0 at start of new day if yesterday was completed', () async {
      final now = DateTime.now();
      final todayStr = FocusHistoryService.formatDate(now);
      final yesterdayStr = FocusHistoryService.formatDate(now.subtract(const Duration(days: 1)));
      final twoDaysAgoStr = FocusHistoryService.formatDate(now.subtract(const Duration(days: 2)));

      // Scenario 1: Only yesterday was completed (User opened app at 00:01 AM today)
      SharedPreferences.setMockInitialValues({
        'fk_completed_dates': [yesterdayStr, twoDaysAgoStr],
      });
      await service.loadData();

      expect(service.completedDates.contains(todayStr), isFalse);
      expect(service.calculateStreak(), 2,
          reason: 'Streak must NOT reset to 0 at 00:01 AM if yesterday was completed!');

      // Scenario 2: Today is now completed
      await service.recordCompletedSession(1500);
      expect(service.calculateStreak(), 3);
      expect(service.todayFocusSeconds, 1500);

      // Scenario 3: Neither today nor yesterday was completed -> Streak officially broken (0)
      SharedPreferences.setMockInitialValues({
        'fk_completed_dates': [twoDaysAgoStr],
      });
      await service.loadData();
      expect(service.calculateStreak(), 0,
          reason: 'Streak must be 0 if neither today nor yesterday was completed');
    });

    test('All-time and today focus accumulation', () async {
      await service.recordCompletedSession(1800);
      await service.recordCompletedSession(1800);

      expect(service.todayFocusSeconds, 3600);
      expect(service.totalFocusSecondsAllTime, 3600);
      expect(service.totalFocusHoursAllTime, 1);
      expect(service.formatSeconds(service.todayFocusSeconds), '1h 0m');
    });
  
    test('Session count per day', () async {
      final today = DateTime.now();
      expect(await service.getSessionCountForDate(today), 0);
      await service.recordCompletedSession(1500);
      await service.recordCompletedSession(1500);
      expect(await service.getSessionCountForDate(today), 2);
    });
  });
}
