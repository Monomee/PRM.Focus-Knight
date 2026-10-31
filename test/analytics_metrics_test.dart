import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_dart/features/dashboard/services/analytics_service.dart';
import 'package:test_dart/features/dashboard/services/focus_history_service.dart';
import 'package:test_dart/features/dashboard/widgets/distraction_velocity_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FocusHistoryService Analytics Extensions', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Records and retrieves interruptions and hourly focus', () async {
      final history = FocusHistoryService();
      await history.loadData();

      final today = DateTime.now();
      expect(await history.getInterruptionsForDate(today), 0);

      await history.recordInterruption();
      await history.recordInterruption();
      expect(await history.getInterruptionsForDate(today), 2);

      await history.recordCompletedSession(1500);
      final hourlyStats = await history.getHourlyFocusStats();
      expect(hourlyStats[today.hour], greaterThanOrEqualTo(1500));
    });
  });

  group('AnalyticsService Calculations', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'Does not invent correlation data when usage data is unavailable',
      () async {
        final analytics = AnalyticsService();
        await analytics.refreshAnalytics();

        expect(analytics.correlationDays.length, 7);
        for (final day in analytics.correlationDays) {
          expect(day.dayLabel, isNotEmpty);
          expect(day.socialHours, isNull);
          expect(day.focusHours, 0);
          expect(day.completionRate, 0);
        }
      },
    );

    test(
      'Reports insufficient distraction data instead of a fallback',
      () async {
        final analytics = AnalyticsService();
        await analytics.refreshAnalytics();

        final velocity = analytics.distractionVelocity;
        expect(velocity.velocityPerHour, isNull);
        expect(velocity.totalInterruptions, 0);
        expect(velocity.focusWorkHours, 0);
        expect(velocity.weeklyTrend, everyElement(isNull));
        expect(velocity.levelKey, 'NO_DATA');
      },
    );

    test('Reports insufficient golden hours data without a baseline', () async {
      final analytics = AnalyticsService();
      await analytics.refreshAnalytics();

      final golden = analytics.goldenHours;
      expect(golden.blockProductivity.length, 7);
      expect(golden.blockProductivity.values, everyElement(0));
      expect(golden.peakTimeSlot, isEmpty);
      expect(golden.peakEfficiency, 0);
      expect(golden.recommendation, contains('Chưa đủ dữ liệu'));
    });

    test(
      'Maps winning golden hour block directly and separates midnight',
      () async {
        SharedPreferences.setMockInitialValues({
          'fk_hourly_focus_1': 1200,
          'fk_hourly_focus_12': 3600,
          'fk_hourly_focus_22': 1800,
        });
        final analytics = AnalyticsService();
        await analytics.refreshAnalytics();

        final golden = analytics.goldenHours;
        expect(golden.peakTimeSlot, '11:00 - 14:00');
        expect(golden.blockProductivity['00h - 05h'], closeTo(0.33, 0.01));
        expect(golden.blockProductivity['21h - 24h'], 0.5);
      },
    );

    testWidgets(
      'DistractionVelocityCard renders without overflow on narrow 340px viewport',
      (tester) async {
        tester.view.physicalSize = const Size(340, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final analytics = AnalyticsService();
        // Real I/O (SharedPreferences) must run outside the widget test's fake-async zone.
        await tester.runAsync(analytics.refreshAnalytics);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DistractionVelocityCard(
                data: analytics.distractionVelocity,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(DistractionVelocityCard), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
