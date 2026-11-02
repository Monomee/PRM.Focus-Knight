import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_dart/core/game/player_state.dart';
import 'package:test_dart/core/game/progression.dart';
import 'package:test_dart/core/game/village.dart';
import 'package:test_dart/features/dashboard/services/focus_history_service.dart';
import 'package:test_dart/features/focus_session/focus_session_controller.dart';
import 'package:test_dart/features/focus_session/settlement.dart';
import 'package:test_dart/features/telemetry/screen_time_tracker.dart';
import 'package:test_dart/features/dashboard/services/analytics_journal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/shared_preferences');
  late Map<String, Object> disk;
  String? failKey;
  int? failJournalWrite;
  int journalWrites = 0;
  bool failRead = false;

  setUp(() {
    SharedPreferences.resetStatic();
    disk = {};
    failKey = null;
    failJournalWrite = null;
    journalWrites = 0;
    failRead = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getAll') {
            if (failRead) {
              failRead = false;
              throw PlatformException(code: 'storage_unavailable');
            }
            return disk;
          }
          final args = Map<String, dynamic>.from(call.arguments as Map);
          final key = args['key'] as String;
          if (key == 'flutter.${Settlement.key}' &&
              ++journalWrites == failJournalWrite) {
            return false;
          }
          if (key == failKey) {
            failKey = null;
            return false;
          }
          if (call.method == 'remove') {
            disk.remove(key);
          } else {
            disk[key] = args['value'] as Object;
          }
          return true;
        });
  });

  tearDown(() {
    SharedPreferences.resetStatic();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'analytics storage failure is visible and retry preserves legacy data',
    () async {
      await AnalyticsJournal.instance.flushed;
      final start = DateTime(2026, 11, 2, 9), end = DateTime(2026, 11, 2, 9, 1);
      final record = <String, dynamic>{
        'id': 'storage-retry',
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'target': 60,
        'outcome': 'completed',
        'monitored': false,
        'intervals': [
          {'start': start.toIso8601String(), 'end': end.toIso8601String()},
        ],
        'interruptions': [],
        'pauses': [],
      };
      disk['flutter.fk_total_focus_seconds_all_time'] = 3600;
      failKey = 'flutter.${AnalyticsJournal.prefix}storage-retry';
      AnalyticsJournal.instance.save(record);
      await AnalyticsJournal.instance.flushed;
      expect(AnalyticsJournal.instance.error, isNotNull);
      await AnalyticsJournal.instance.retryFailed();
      expect(AnalyticsJournal.instance.error, isNull);
      expect(
        SessionSample.parse(
          disk['flutter.${AnalyticsJournal.prefix}storage-retry'] as String,
        )!.seconds,
        60,
      );
      expect(disk['flutter.fk_total_focus_seconds_all_time'], 3600);
    },
  );

  test(
    'decoration refund retries once and preserves applied rewards',
    () async {
      disk['flutter.fk_wallet_state'] = jsonEncode({
        'coins': 10,
        'logs': 5,
        'buildings': ['archery:1'],
        'applied': ['old-win'],
      });
      final player = PlayerState();
      failKey = 'flutter.fk_wallet_state';
      await expectLater(player.load(), throwsStateError);
      await player.load();
      final refunded = (player.coins, player.logs);
      await player.deposit(coins: 99, logs: 99, settlementId: 'old-win');
      expect((player.coins, player.logs), refunded);
      await player.load();
      expect((player.coins, player.logs), refunded);
    },
  );

  test('failed plot reservation never starts a battle', () async {
    final player = PlayerState();
    await player.load();
    final controller = FocusSessionController(player: player);
    addTearDown(controller.dispose);
    failKey = 'flutter.fk_wallet_state';
    await expectLater(
      controller.startFocusSession(task: 'T', durationSeconds: 60),
      throwsStateError,
    );
    expect(controller.inBattle, isFalse);
    expect(controller.isStarting, isFalse);
    expect(player.plots, isEmpty);
    expect(
      await controller.startFocusSession(task: 'T', durationSeconds: 60),
      isTrue,
    );
    controller.cancelSession();
    await controller.retrySettlement();
  });

  test('failed ruin save blocks new battles until retry', () async {
    final player = PlayerState();
    await player.load();
    final controller = FocusSessionController(player: player);
    addTearDown(controller.dispose);
    await controller.startFocusSession(task: 'T', durationSeconds: 60);
    failKey = 'flutter.fk_wallet_state';
    controller.forceAbandonSession();
    await controller.retrySettlement();
    expect(controller.settlementFailed, isTrue);
    expect(
      await controller.startFocusSession(task: 'T2', durationSeconds: 60),
      isFalse,
    );
    await controller.retrySettlement();
    expect(player.plots.single.state, PlotState.ruined);
    expect(controller.hasPendingSettlement, isFalse);
  });

  test('strict mode save failure does not enable it or reload a failed cache value', () async {
    final tracker = ScreenTimeTracker();
    addTearDown(tracker.dispose);
    await tracker.init();
    failKey = 'flutter.fk_strict_mode';
    await expectLater(tracker.setStrictModeEnabled(true), throwsStateError);
    expect(tracker.strictModeEnabled, isFalse);
    final restored = ScreenTimeTracker();
    addTearDown(restored.dispose);
    await restored.init();
    expect(restored.strictModeEnabled, isFalse);
    await tracker.setStrictModeEnabled(true);
    expect(tracker.strictModeEnabled, isTrue);
  });

  test(
    'failed app selection write preserves previous selection on reload',
    () async {
      final tracker = ScreenTimeTracker();
      addTearDown(tracker.dispose);
      await tracker.ready;
      failKey = 'flutter.fk_tracked_apps';
      await expectLater(
        tracker.setTrackedApps({'com.example.reader': 'Reader'}),
        throwsStateError,
      );
      expect(tracker.trackedApps.containsKey('com.facebook.katana'), isTrue);
      final restored = ScreenTimeTracker();
      addTearDown(restored.dispose);
      await restored.ready;
      expect(restored.trackedApps.containsKey('com.facebook.katana'), isTrue);
      expect(restored.trackedApps.containsKey('com.example.reader'), isFalse);
    },
  );

  test(
    'timestamped settlement retry after midnight preserves original allocation',
    () async {
      var now = DateTime(2026, 10, 30, 23, 59, 50);
      final player = PlayerState();
      await player.load();
      final history = FocusHistoryService(clock: () => now);
      await history.loadData();
      final controller = FocusSessionController(
        player: player,
        history: history,
        clock: () => now,
      );
      addTearDown(controller.dispose);
      failJournalWrite = 2; // History saved, journal progress not yet saved.
      await controller.startFocusSession(task: 'Retry', durationSeconds: 20);
      now = now.add(const Duration(seconds: 20));
      controller.refreshTimer();
      await pumpEventQueue();
      expect(controller.settlementFailed, isTrue);
      expect(disk['flutter.${Settlement.key}'], isNotNull);

      now = DateTime(2026, 11, 1);
      await controller.retrySettlement();
      expect(controller.hasPendingSettlement, isFalse);
      expect(history.totalFocusSecondsAllTime, 20);
      expect(history.todayFocusSeconds, 0);
      expect(await history.getFocusSecondsForDate(DateTime(2026, 10, 30)), 10);
      expect(await history.getFocusSecondsForDate(DateTime(2026, 10, 31)), 10);
      expect(await history.getSessionCountForDate(DateTime(2026, 10, 31)), 1);
      expect(await history.getFocusSecondsForDate(DateTime(2026, 11, 1)), 0);
      expect(disk['flutter.${Settlement.key}'], isNull);
    },
  );

  test(
    'failed wallet write retries once without losing the reward to cache',
    () async {
      final player = PlayerState();
      await player.load();
      failKey = 'flutter.fk_wallet_state';
      await expectLater(
        player.deposit(coins: 30, logs: 12, settlementId: 's'),
        throwsStateError,
      );
      expect(player.coins, 0);
      await player.deposit(coins: 30, logs: 12, settlementId: 's');
      final wallet =
          jsonDecode(disk['flutter.fk_wallet_state']! as String) as Map;
      expect(wallet['coins'], 30);
      expect(wallet['logs'], 12);
      expect(wallet['applied'], ['s']);
    },
  );

  test(
    'failed history write retries once without trusting the failed cache',
    () async {
      final history = FocusHistoryService();
      await history.loadData();
      failKey = 'flutter.fk_history_settlement_state';
      await expectLater(
        history.recordCompletedSession(1500, settlementId: 's'),
        throwsStateError,
      );
      expect(history.totalFocusSecondsAllTime, 0);
      await history.recordCompletedSession(1500, settlementId: 's');
      expect(disk['flutter.fk_history_settlement_state'], isNotNull);
      final saved = jsonDecode(
        disk['flutter.fk_history_settlement_state']! as String,
      ) as Map;
      expect(saved['total'], 1500);
      expect(saved['applied'], ['s']);
    },
  );

  test(
    'a failed first journal write cannot be discarded by a new battle',
    () async {
      final player = PlayerState();
      await player.load();
      final history = FocusHistoryService();
      await history.loadData();
      final controller = FocusSessionController(
        player: player,
        history: history,
      );
      addTearDown(controller.dispose);
      failKey = 'flutter.${Settlement.key}';
      await controller.startFocusSession(
        task: 'Won battle',
        durationSeconds: 1500,
      );
      controller.debugCompleteFocus();
      await pumpEventQueue();
      await controller.startFocusSession(
        task: 'Another battle',
        durationSeconds: 900,
      );
      expect(controller.taskName, 'Won battle');
      expect(player.coins, 0);
      expect(controller.settlementFailed, isTrue);
      await controller.retrySettlement();
      expect(controller.hasPendingSettlement, isFalse);
      expect(player.coins, 30);
      expect(history.totalFocusSecondsAllTime, 1500);
      await controller.retrySettlement();
      expect(player.coins, 30);
    },
  );

  test(
    'retry after payout but before journal progress does not pay twice',
    () async {
      final player = PlayerState();
      await player.load();
      final history = FocusHistoryService();
      await history.loadData();
      final controller = FocusSessionController(
        player: player,
        history: history,
      );
      addTearDown(controller.dispose);
      failJournalWrite = 3;
      await controller.startFocusSession(task: 'T', durationSeconds: 1500);
      controller.debugCompleteFocus();
      await pumpEventQueue();
      expect(controller.settlementFailed, isTrue);
      expect(player.coins, 30);
      await controller.retrySettlement();
      expect(controller.hasPendingSettlement, isFalse);
      expect(player.coins, 30);
      expect(history.totalFocusSecondsAllTime, 1500);
    },
  );

  test('failed building write leaves balance and building unchanged', () async {
    final player = PlayerState();
    await player.load();
    await player.deposit(coins: 500, logs: 100, settlementId: 'first');
    failKey = 'flutter.fk_wallet_state';
    await expectLater(
      player.build(Building.tower, Rank.starter),
      throwsStateError,
    );
    expect((player.coins, player.logs), (500, 100));
    expect(player.levelOf(Building.tower), 0);
    final reloaded = PlayerState();
    await reloaded.load();
    expect((reloaded.coins, reloaded.logs), (500, 100));
    expect(reloaded.levelOf(Building.tower), 0);
  });

  for (final domain in ['wallet', 'history']) {
    test(
      '$domain retry cannot trust cache if write and recovery read both fail',
      () async {
        final player = PlayerState();
        await player.load();
        final history = FocusHistoryService();
        await history.loadData();
        final key = domain == 'wallet'
            ? 'fk_wallet_state'
            : 'fk_history_settlement_state';
        Future<void> save() => domain == 'wallet'
            ? player.deposit(coins: 30, logs: 12, settlementId: 'retry')
            : history.recordCompletedSession(1500, settlementId: 'retry');
        failKey = 'flutter.$key';
        failRead = true;
        await expectLater(save(), throwsA(anything));
        await expectLater(save(), throwsA(anything));
        await save();
        expect(disk['flutter.$key'], isNotNull);
        final saved = jsonDecode(disk['flutter.$key']! as String) as Map;
        expect(
          saved[domain == 'wallet' ? 'coins' : 'total'],
          domain == 'wallet' ? 30 : 1500,
        );
        expect(saved['applied'], ['retry']);
      },
    );
  }
}
