import 'package:flutter_test/flutter_test.dart';
import 'package:test_dart/core/game/battle_plan.dart';

String _shape(BattlePlan p, {int longRestMinutes = 15}) => planTimeline(p, longRestMinutes: longRestMinutes)
    .map((s) => '${s.focus ? 'F' : s.longRest ? 'L' : 'R'}${s.minutes}')
    .join(' ');

void main() {
  test('clampFocusMinutes', () {
    expect(clampFocusMinutes(''), 25);
    expect(clampFocusMinutes('abc'), 25);
    expect(clampFocusMinutes('0'), 1);
    expect(clampFocusMinutes('999'), 180);
    expect(clampFocusMinutes('40'), 40);
  });

  test('clampRestMinutes', () {
    expect(clampRestMinutes(''), 5);
    expect(clampRestMinutes('0'), 1);
    expect(clampRestMinutes('90'), 60);
  });

  test('planTimeline has no rest after the last session', () {
    final p = BattlePlan(task: 'x', focusMinutes: 25, restMinutes: 5, sessions: 4, longBreakEvery: 4);
    expect(_shape(p), 'F25 R5 F25 R5 F25 R5 F25');
  });

  test('planTimeline inserts long breaks', () {
    final p = BattlePlan(task: 'x', focusMinutes: 25, restMinutes: 5, sessions: 3, longBreakEvery: 2);
    expect(_shape(p), 'F25 R5 F25 L15 F25');
  });

  test('planEndTime', () {
    final p = BattlePlan(task: 'x', focusMinutes: 25, restMinutes: 5, sessions: 4, longBreakEvery: 0);
    expect(planEndTime(p, DateTime(2026, 10, 19, 10)), DateTime(2026, 10, 19, 11, 55));
  });

  test('planCoins', () {
    final p = BattlePlan(task: 'x', focusMinutes: 25, restMinutes: 5, sessions: 3, longBreakEvery: 0);
    expect(planCoins(p, 0), 90);
  });

  test('BattlePlan JSON round-trip', () {
    final p = BattlePlan(task: 'Học', focusMinutes: 50, restMinutes: 10, sessions: 2, longBreakEvery: 2);
    final q = BattlePlan.fromJson(p.toJson());
    expect((q.task, q.focusMinutes, q.restMinutes, q.sessions, q.longBreakEvery), ('Học', 50, 10, 2, 2));
  });
}
