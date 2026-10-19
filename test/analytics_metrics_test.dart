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

    test('Generates 7 days correlation data with non-empty attributes', () async {
      final analytics = AnalyticsService();
      await analytics.refreshAnalytics();

      expect(analytics.correlationDays.length, 7);
      for (final day in analytics.correlationDays) {
        expect(day.dayLabel.isNotEmpty, isTrue);
        expect(day.socialHours, greaterThanOrEqualTo(0.0));
        expect(day.completionRate, inInclusiveRange(0.0, 1.0));
      }
    });

    test('Computes Distraction Velocity and assigns valid category', () async {
      final analytics = AnalyticsService();
      await analytics.refreshAnalytics();

      final velocity = analytics.distractionVelocity;
      expect(velocity.velocityPerHour, greaterThanOrEqualTo(0.0));
      expect(velocity.weeklyTrend.length, 7);
      expect(
        ['DEEP_FLOW', 'MODERATE', 'HIGH_RESTLESS'].contains(velocity.levelKey),
        isTrue,
      );
      expect(velocity.levelLabel.isNotEmpty, isTrue);
    });

    test('Computes Golden Hours and identifies valid peak block', () async {
      final analytics = AnalyticsService();
      await analytics.refreshAnalytics();

      final golden = analytics.goldenHours;
      expect(golden.blockProductivity.length, 6);
      expect(golden.peakTimeSlot.isNotEmpty, isTrue);
      expect(golden.peakEfficiency, inInclusiveRange(0.1, 1.0));
      expect(golden.recommendation.isNotEmpty, isTrue);
    });

    testWidgets('DistractionVelocityCard renders without overflow on narrow 340px viewport', (tester) async {
      tester.view.physicalSize = const Size(340, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final analytics = AnalyticsService();
      // Real I/O (SharedPreferences) must run outside the widget test's fake-async zone.
      await tester.runAsync(analytics.refreshAnalytics);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DistractionVelocityCard(data: analytics.distractionVelocity),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DistractionVelocityCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
