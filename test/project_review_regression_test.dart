import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_dart/core/game/player_state.dart';
import 'package:test_dart/core/game/progression.dart';
import 'package:test_dart/core/game/village.dart';
import 'package:test_dart/features/dashboard/services/focus_history_service.dart';
import 'package:test_dart/features/dashboard/services/analytics_service.dart';
import 'package:test_dart/features/focus_session/settlement.dart';
import 'package:test_dart/core/services/overlay_service.dart';
import 'package:test_dart/features/settings/settings_screen.dart';
import 'package:test_dart/features/telemetry/screen_time_tracker.dart';

class _LoadingTracker extends ScreenTimeTracker {
  int limit = 60;

  @override
  int get dailyLimitMinutes => limit;

  @override
  bool get hasPermission => true;

  @override
  Future<void> init() async {}

  @override
  Future<void> refreshUsageStats() async {}

  void finishLoading() {
    limit = 240;
    notifyListeners();
  }
}

class _QuietOverlay extends OverlayService {
  @override
  Future<bool> checkPermission() async => false;
}

class _UnavailableHistory extends FocusHistoryService {
  @override
  Future<void> recordCompletedSession(
    int durationSeconds, {
    String? settlementId,
  }) async {
    throw StateError('storage unavailable');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('review 1: spent rewards stay spent after reload', () async {
    final player = PlayerState();
    await player.load();
    await player.deposit(coins: 500, logs: 100, settlementId: 'battle-1');
    expect(await player.build(Building.tower, Rank.starter), isTrue);
    final reloaded = PlayerState();
    await reloaded.load();
    expect((reloaded.coins, reloaded.logs), (300, 60));
  });

  test(
    'review 1: next payout starts from the balance after building',
    () async {
      final player = PlayerState();
      await player.load();
      await player.deposit(coins: 500, logs: 100, settlementId: 'battle-1');
      await player.build(Building.tower, Rank.starter);
      await player.deposit(coins: 30, logs: 12, settlementId: 'battle-2');
      expect((player.coins, player.logs), (330, 72));
    },
  );

  test(
    'review 1: concurrent building and deposit preserve both changes',
    () async {
      final player = PlayerState();
      await player.load();
      await player.deposit(coins: 500, logs: 100, settlementId: 'first');
      await Future.wait([
        player.build(Building.tower, Rank.starter),
        player.deposit(coins: 30, logs: 12, settlementId: 'second'),
      ]);
      final reloaded = PlayerState();
      await reloaded.load();
      expect((reloaded.coins, reloaded.logs), (330, 72));
      expect(reloaded.levelOf(Building.tower), 1);
    },
  );

  test(
    'review 1: a new payout is journaled even if the previous payout fails',
    () async {
      final history = _UnavailableHistory();
      final player = PlayerState();
      await player.load();
      for (final coins in [30, 60]) {
        await expectLater(
          Settlement.commit(
            coins: coins,
            logs: 12,
            sessionSeconds: [900],
            player: player,
            history: history,
          ),
          throwsStateError,
        );
      }
      final prefs = await SharedPreferences.getInstance();
      final pending = jsonDecode(prefs.getString(Settlement.key)!) as List;
      expect(pending.map((s) => s['coins']).toList(), [30, 60]);
    },
  );

  test(
    'review 1: retry recovers history when killed between snapshot and mirrors',
    () async {
      final date = FocusHistoryService.formatDate(DateTime.now());
      final hour = DateTime.now().hour.toString();
      SharedPreferences.setMockInitialValues({
        'fk_history_settlement_state': jsonEncode({
          'applied': ['battle:history:0'],
          'total': 1500,
          'days': {date: 1500},
          'hours': {hour: 1500},
          'counts': {date: 1},
        }),
        Settlement.key: jsonEncode([
          {
            'id': 'battle',
            'coins': 30,
            'logs': 12,
            'seconds': [1500],
            'recorded': 0,
            'deposited': false,
          },
        ]),
      });
      final player = PlayerState();
      await player.load();
      final history = FocusHistoryService();
      await history.loadData();
      await Settlement.resume(player, history);
      expect(history.totalFocusSecondsAllTime, 1500);
      expect(await history.getFocusSecondsForDate(DateTime.now()), 1500);
      expect(await history.getSessionCountForDate(DateTime.now()), 1);
      expect((await history.getHourlyFocusStats())[int.parse(hour)], 1500);
    },
  );

  test(
    'review 7: rounding does not select a smaller golden hour block',
    () async {
      SharedPreferences.setMockInitialValues({
        'fk_hourly_focus_12': 599 * 60,
        'fk_hourly_focus_22': 600 * 60,
      });
      final analytics = AnalyticsService();
      await analytics.refreshAnalytics();
      expect(analytics.goldenHours.peakTimeSlot, '21:00 - 24:00');
    },
  );

  testWidgets('review 8: first async settings load updates the clean field', (
    tester,
  ) async {
    final tracker = _LoadingTracker();
    final overlay = _QuietOverlay();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsScreen(
            screenTimeTracker: tracker,
            overlayService: overlay,
          ),
        ),
      ),
    );
    await tester.pump();
    tracker.finishLoading();
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, '240');
    await tester.pumpWidget(const SizedBox());
    tracker.dispose();
    overlay.dispose();
  });
}
