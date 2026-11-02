import 'package:flutter_test/flutter_test.dart';
import 'package:test_dart/features/dashboard/services/analytics_calculations.dart';

void main() {
  test('a day without a goal breaks the current goal streak', () {
    final days = {
      '2026-11-01': DailyFocus(seconds: 1800, goalSeconds: 1800),
      '2026-11-02': DailyFocus(seconds: 1800),
    };
    expect(goalStreaks(days, DateTime(2026, 11, 2)), (current: 0, longest: 1));
  });
  test('elapsed time is conserved across DST offsets and censor-only curves stay at one', () {
    for (final (start, end) in [
      ('2026-11-01T01:30:00-04:00', '2026-11-01T01:30:00-05:00'),
      ('2026-03-08T01:30:00-05:00', '2026-03-08T03:30:00-04:00'),
    ]) {
      final slices = splitInterval(DateTime.parse(start), DateTime.parse(end));
      expect(slices.fold<double>(0, (sum, s) => sum + s.seconds), 3600);
    }
    final km = SurvivalEstimate.calculate([
      (minutes: 10.0, event: false),
      (minutes: 20.0, event: false),
    ]);
    expect(km.points.every((p) => p.y == 1), true);
    expect(km.median, isNull);
    final interrupted = SurvivalEstimate.calculate([
      (minutes: 1.0, event: true),
      (minutes: 2.0, event: true),
    ]);
    expect(interrupted.points.last.y, 0);
    expect(interrupted.median, 1);
    expect(
      correlation(List.generate(7, (i) => (x: i.toDouble(), y: 1.0))),
      isNull,
    );
    expect(
      correlation(
        List.generate(
          7,
          (i) => (x: i.toDouble(), y: i == 0 ? double.nan : i.toDouble()),
        ),
      ),
      isNull,
    );
  });
  test('KM includes tied censors in risk set and never invents median', () {
    final km = SurvivalEstimate.calculate([
      (minutes: 10.0, event: true),
      (minutes: 10.0, event: false),
      (minutes: 20.0, event: false),
    ]);
    expect(km.points.first.y, 1);
    expect(km.points[1].y, closeTo(2 / 3, 1e-9));
    expect(km.median, isNull);
    expect(SurvivalEstimate.calculate([(minutes: 3.0, event: true)]).median, 3);
    expect(SurvivalEstimate.calculate([]).median, isNull);
  });
  test('Pearson rejects small, constant and invalid samples', () {
    expect(correlation([(x: 1.0, y: 2.0)]), isNull);
    expect(
      correlation(List.generate(7, (i) => (x: 1.0, y: i.toDouble()))),
      isNull,
    );
    final r = correlation(
      List.generate(7, (i) => (x: i.toDouble(), y: 10.0 - i)),
    );
    expect(r?.r, closeTo(-1, 1e-9));
    expect(r?.slope, closeTo(-1, 1e-9));
  });
  test(
    'slot allocation splits midnight and slot boundaries, excludes pause',
    () {
      final slices = splitInterval(
        DateTime(2026, 11, 2, 23, 50),
        DateTime(2026, 11, 3, 5, 10),
      );
      expect(slices.fold<double>(0, (a, b) => a + b.seconds), 19200);
      expect(slices.map((s) => s.slot).toSet(), {6, 0, 1});
      expect(slices.map((s) => s.date.day).toSet(), {2, 3});
      expect(splitInterval(DateTime(2026), DateTime(2025)), isEmpty);
    },
  );
  test(
    'goal streak keeps yesterday pending today and ignores no-goal days',
    () {
      final days = {
        '2026-11-01': DailyFocus(seconds: 1800, goalSeconds: 1800),
        '2026-11-02': DailyFocus(seconds: 600, goalSeconds: 1800),
      };
      expect(goalStreaks(days, DateTime(2026, 11, 2)).current, 1);
      expect(goalStreaks(days, DateTime(2026, 11, 2)).longest, 1);
      expect(DailyFocus(seconds: 3600).achieved, false);
      expect(DailyFocus(seconds: 900, goalSeconds: 1800).heatLevel, 2);
      expect(distractionRate(0, 0), isNull);
      expect(distractionRate(0, 3600), 0);
      expect(distractionRate(2, 1800), 4);
    },
  );
}
