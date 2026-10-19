import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_dart/features/dashboard/services/focus_history_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 10, 21);
  late FocusHistoryService history;
  late int consumed;

  Future<void> load(List<String> completed) async {
    SharedPreferences.setMockInitialValues({'fk_completed_dates': completed});
    history = FocusHistoryService();
    await history.loadData();
    consumed = 0;
  }

  bool Function() ticket(bool available) => () {
        consumed++;
        return available;
      };

  test('shields yesterday when a ticket is available', () async {
    await load(['2026-10-19']);
    final ok = await history.tryShieldGap(
        now: now, protectFrom: DateTime(2026, 10, 1), consumeTicket: ticket(true));
    expect(ok, isTrue);
    expect(consumed, 1);
    expect(history.calculateStreak(now), 2);
    expect(history.shieldedDates, ['2026-10-20']);

    final reloaded = FocusHistoryService();
    await reloaded.loadData();
    expect(reloaded.calculateStreak(now), 2);
  });

  test('no ticket keeps the streak broken', () async {
    await load(['2026-10-19']);
    final ok = await history.tryShieldGap(
        now: now, protectFrom: DateTime(2026, 10, 1), consumeTicket: ticket(false));
    expect(ok, isFalse);
    expect(history.calculateStreak(now), 0);
  });

  test('does not cover gaps before the granary was built', () async {
    await load(['2026-10-19']);
    final ok = await history.tryShieldGap(
        now: now, protectFrom: DateTime(2026, 10, 21), consumeTicket: ticket(true));
    expect(ok, isFalse);
    expect(consumed, 0);
  });

  test('no gap means no ticket used', () async {
    await load(['2026-10-19', '2026-10-20']);
    final ok = await history.tryShieldGap(
        now: now, protectFrom: DateTime(2026, 10, 1), consumeTicket: ticket(true));
    expect(ok, isFalse);
    expect(consumed, 0);
  });

  test('no granary means nothing to protect', () async {
    await load(['2026-10-19']);
    final ok = await history.tryShieldGap(now: now, protectFrom: null, consumeTicket: ticket(true));
    expect(ok, isFalse);
    expect(consumed, 0);
  });
}
