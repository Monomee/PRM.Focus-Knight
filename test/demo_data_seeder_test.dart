import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_dart/core/game/player_state.dart';
import 'package:test_dart/core/game/progression.dart';
import 'package:test_dart/core/game/village.dart';
import 'package:test_dart/core/services/demo_data_seeder.dart';
import 'package:test_dart/features/dashboard/services/analytics_calculations.dart';
import 'package:test_dart/features/dashboard/services/analytics_journal.dart';
import 'package:test_dart/features/dashboard/services/analytics_service.dart';
import 'package:test_dart/features/dashboard/services/focus_history_service.dart';

Map<String, Object?> snapshot(SharedPreferences prefs) => {
  for (final key in prefs.getKeys()) key: prefs.get(key),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final reference = DateTime(2026, 11, 4, 8);

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'fk_pending_settlement': '{"old":true}',
      'fk_old_demo_value': 99,
      'unrelated': 'keep',
    });
  });

  test('disabled path leaves all preferences unchanged', () async {
    final prefs = await SharedPreferences.getInstance();
    final before = snapshot(prefs);

    expect(
      await DemoDataSeeder.reset(isEnabled: false, clock: () => reference),
      isFalse,
    );

    expect(snapshot(prefs), before);
  });

  test(
    'reset is deterministic and replaces the complete fk namespace',
    () async {
      final prefs = await SharedPreferences.getInstance();

      expect(
        await DemoDataSeeder.reset(isEnabled: true, clock: () => reference),
        isTrue,
      );
      final first = snapshot(prefs);
      await prefs.setInt('fk_runtime_mutation', 7);
      await prefs.setInt('fk_gold', 1);
      await DemoDataSeeder.reset(isEnabled: true, clock: () => reference);

      expect(snapshot(prefs), first);
      expect(prefs.containsKey('fk_pending_settlement'), isFalse);
      expect(prefs.containsKey('fk_old_demo_value'), isFalse);
      expect(prefs.getString('unrelated'), 'keep');
      final journals = prefs
          .getKeys()
          .where((key) => key.startsWith(AnalyticsJournal.prefix))
          .toList();
      expect(journals, isNotEmpty);
      final sessionDays = journals
          .map((key) => jsonDecode(prefs.getString(key)!) as Map)
          .map(
            (raw) => dateKey(DateTime.parse(raw['start'] as String).toLocal()),
          )
          .toSet();
      expect(sessionDays.length, 26);
      expect(
        sessionDays.every((day) {
          final date = DateTime.parse(day);
          return !date.isBefore(
                dayOf(reference).subtract(const Duration(days: 29)),
              ) &&
              !date.isAfter(dayOf(reference));
        }),
        isTrue,
      );
    },
  );

  test(
    'journal, canonical history and analytics credits stay consistent',
    () async {
      await DemoDataSeeder.reset(isEnabled: true, clock: () => reference);
      final prefs = await SharedPreferences.getInstance();
      final state = jsonDecode(
        prefs.getString('fk_history_settlement_state')!,
      ) as Map<String, dynamic>;
      final ids = (state['analyticsIds'] as List).cast<String>().toSet();
      final credits = Map<String, dynamic>.from(
        state['analyticsCredits'] as Map,
      );
      final completedJournals = <String>{};
      for (final key in prefs.getKeys().where(
        (key) => key.startsWith(AnalyticsJournal.prefix),
      )) {
        final raw = jsonDecode(prefs.getString(key)!) as Map<String, dynamic>;
        if (raw['outcome'] == 'completed') {
          completedJournals.add(raw['id'] as String);
        }
      }
      expect(ids, completedJournals);
      expect(credits.keys.toSet(), completedJournals);
      expect(
        prefs.getKeys().where((key) => key.startsWith(AnalyticsJournal.prefix)),
        hasLength(greaterThanOrEqualTo(115)),
      );
      expect(state['total'] as int, greaterThanOrEqualTo(40 * 3600));
      expect(
        (state['days'] as Map).values.cast<int>().fold(0, (a, b) => a + b),
        state['total'],
      );

      const usage = MethodChannel('usage_stats');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var nativeCalls = 0;
      messenger.setMockMethodCallHandler(usage, (call) async {
        nativeCalls++;
        throw MissingPluginException();
      });
      addTearDown(() => messenger.setMockMethodCallHandler(usage, null));
      final history = FocusHistoryService(clock: () => reference);
      await history.loadData();
      final analytics = AnalyticsService(
        history: history,
        clock: () => reference,
      );
      addTearDown(analytics.dispose);
      await analytics.refreshAnalytics();

      final canonicalDays = Map<String, dynamic>.from(state['days'] as Map);
      for (final entry in canonicalDays.entries) {
        final journalSeconds = analytics.sessions
            .where((session) => session.completed)
            .expand((session) => session.intervals)
            .expand((interval) => splitInterval(interval.start, interval.end))
            .where((part) => dateKey(part.date) == entry.key)
            .fold<double>(0, (sum, part) => sum + part.seconds);
        expect(journalSeconds, entry.value);
        final allJournalSeconds = analytics.sessions
            .expand((session) => session.intervals)
            .expand((interval) => splitInterval(interval.start, interval.end))
            .where((part) => dateKey(part.date) == entry.key)
            .fold<double>(0, (sum, part) => sum + part.seconds);
        expect(analytics.days[entry.key]!.seconds, allJournalSeconds);
      }
      expect(analytics.invalidSessions, 0);
      expect(nativeCalls, greaterThanOrEqualTo(1));
    },
  );

  test(
    'seeded wallet and player collection load through production schema',
    () async {
      await DemoDataSeeder.reset(isEnabled: true, clock: () => reference);
      final player = PlayerState(clock: () => reference);
      addTearDown(player.dispose);
      await player.load();

      expect((player.coins, player.logs), (1280, 340));
      expect(player.selectedCharacter, GameCharacter.archer);
      expect(
        (player.badgeCharacter, player.badgeRank),
        (GameCharacter.archer, Rank.diamond),
      );
      expect(player.levelOf(Building.tower), 2);
      expect(player.levelOf(Building.granary), 1);
      expect(player.levelOf(Building.barracks), 1);
      expect(player.streakTickets, 1);
      expect(player.plots, hasLength(18));
      expect(
        player.plots.where((plot) => plot.state == PlotState.ruined),
        hasLength(2),
      );
      expect(player.plots.last.state, PlotState.complete);
    },
  );
}
