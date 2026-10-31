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
      controller.startFocusSession(task: 'Won battle', durationSeconds: 1500);
      controller.debugCompleteFocus();
      await pumpEventQueue();
      controller.startFocusSession(
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
      controller.startFocusSession(task: 'T', durationSeconds: 1500);
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
