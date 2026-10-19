import 'package:flutter_test/flutter_test.dart';
import 'package:test_dart/core/services/distraction_guard.dart';

void main() {
  final t0 = DateTime(2026, 10, 19, 10);
  DateTime at(int s) => t0.add(Duration(seconds: s));
  const pkg = 'com.google.android.youtube';

  late int penalties, taxes, lefts, warnings;
  late int grace;
  late DistractionGuard guard;

  setUp(() {
    penalties = taxes = lefts = warnings = 0;
    grace = 10;
    guard = DistractionGuard(
      graceSeconds: () => grace,
      onPenalty: (_) => penalties++,
      onTax: () => taxes++,
      onLeftBlacklisted: () => lefts++,
      onGraceStart: (_) => warnings++,
    );
  });

  test('no penalty during grace', () {
    guard.tick(pkg, at(0));
    guard.tick(pkg, at(9));
    expect(penalties, 0);
  });

  test('penalty after grace, once', () {
    guard.tick(pkg, at(0));
    guard.tick(pkg, at(10));
    guard.tick(pkg, at(12));
    expect(penalties, 1);
  });

  test('tax every 30s while staying', () {
    guard.tick(pkg, at(0));
    guard.tick(pkg, at(10));
    guard.tick(pkg, at(39));
    expect(taxes, 0);
    guard.tick(pkg, at(40));
    expect(taxes, 1);
    guard.tick(pkg, at(70));
    expect(taxes, 2);
  });

  test('leaving resets, returning re-penalizes', () {
    guard.tick(pkg, at(0));
    guard.tick(pkg, at(10));
    guard.tick(null, at(15));
    expect(lefts, 1);
    guard.tick(pkg, at(20));
    guard.tick(pkg, at(30));
    expect(penalties, 2);
  });

  test('null while idle does nothing', () {
    guard.tick(null, at(0));
    guard.tick(null, at(5));
    guard.tick(null, at(10));
    expect(lefts, 0);
  });

  test('grace reads current tower level', () {
    grace = 15;
    guard.tick(pkg, at(0));
    guard.tick(pkg, at(14));
    expect(penalties, 0);
    guard.tick(pkg, at(15));
    expect(penalties, 1);
  });

  test('reset returns to idle', () {
    guard.tick(pkg, at(0));
    guard.reset();
    guard.tick(pkg, at(10));
    expect(penalties, 0);
  });

  test('warns once when a visit starts, again on the next visit', () {
    guard.tick(pkg, at(0));
    guard.tick(pkg, at(2));
    guard.tick(pkg, at(10));
    guard.tick(pkg, at(12));
    expect(warnings, 1);
    guard.tick(null, at(14));
    guard.tick(pkg, at(16));
    expect(warnings, 2);
  });
}
