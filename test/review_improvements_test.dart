import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_dart/core/game/player_state.dart';
import 'package:test_dart/features/dashboard/services/focus_history_service.dart';
import 'package:test_dart/features/focus_session/focus_session_controller.dart';
import 'package:test_dart/features/focus_session/settlement.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('review 9: delayed callbacks catch up elapsed focus time', () async {
    final controller = FocusSessionController();
    addTearDown(controller.dispose);
    controller.startFocusSession(task: 'Delayed', durationSeconds: 4);
    sleep(const Duration(milliseconds: 2200));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(controller.remainingSeconds, lessThanOrEqualTo(2));
  });

  test(
    'review 10: resumed payout keeps real intervals and paused gaps',
    () async {
      // Local intervals: 23:50–00:05, pause until 00:15, focus until 00:25.
      SharedPreferences.setMockInitialValues({
        Settlement.key: jsonEncode([
          {
            'id': 'midnight',
            'coins': 30,
            'logs': 12,
            'seconds': [1500],
            'intervals': [
              [
                {
                  'start': DateTime(
                    2026,
                    10,
                    29,
                    23,
                    50,
                  ).toUtc().toIso8601String(),
                  'end': DateTime(2026, 10, 30, 0, 5).toUtc().toIso8601String(),
                },
                {
                  'start': DateTime(
                    2026,
                    10,
                    30,
                    0,
                    15,
                  ).toUtc().toIso8601String(),
                  'end': DateTime(
                    2026,
                    10,
                    30,
                    0,
                    25,
                  ).toUtc().toIso8601String(),
                },
              ],
            ],
            'recorded': 0,
            'deposited': false,
          },
        ]),
      });
      final player = PlayerState();
      await player.load();
      final history = FocusHistoryService(clock: () => DateTime(2026, 10, 31));
      await history.loadData();

      await Settlement.resume(player, history);
      await Settlement.resume(player, history);

      expect(await history.getFocusSecondsForDate(DateTime(2026, 10, 29)), 600);
      expect(await history.getFocusSecondsForDate(DateTime(2026, 10, 30)), 900);
      expect(history.todayFocusSeconds, 0);
      expect(history.totalFocusSecondsAllTime, 1500);
      final hours = await history.getHourlyFocusStats();
      expect(hours[23], 600);
      expect(hours[0], 900);
      expect(await history.getSessionCountForDate(DateTime(2026, 10, 29)), 0);
      expect(await history.getSessionCountForDate(DateTime(2026, 10, 30)), 1);
      expect(player.coins, 30);
    },
  );

  group('Deadline and interval regression', () {
    late DateTime now;
    late FocusSessionController controller;
    late FocusHistoryService history;

    setUp(() async {
      now = DateTime(2026, 10, 30, 23, 59, 50);
      history = FocusHistoryService(clock: () => now);
      await history.loadData();
      final player = PlayerState();
      await player.load();
      controller = FocusSessionController(
        player: player,
        history: history,
        clock: () => now,
      );
    });

    tearDown(() => controller.dispose());

    test(
      'history splits a multi-hour session and preserves legacy totals',
      () async {
        SharedPreferences.setMockInitialValues({
          'fk_hourly_focus_9': 600,
          'fk_focus_sec_2026-10-29': 900,
          'fk_total_focus_seconds_all_time': 900,
        });
        await history.loadData();
        await history.recordCompletedSession(
          7200,
          intervals: [
            (
              start: DateTime(2026, 10, 29, 8, 30),
              end: DateTime(2026, 10, 29, 10, 30),
            ),
          ],
        );
        final hours = await history.getHourlyFocusStats();
        expect((hours[8], hours[9], hours[10]), (1800, 4200, 1800));
        expect(history.totalFocusSecondsAllTime, 8100);
        expect(
          await history.getFocusSecondsForDate(DateTime(2026, 10, 29)),
          8100,
        );
        expect(history.todayFocusSeconds, 0);
      },
    );

    test('invalid intervals cannot change durable history', () async {
      final start = DateTime(2026, 10, 30, 9);
      for (final intervals in <List<FocusInterval>>[
        [],
        [(start: start, end: start.subtract(const Duration(seconds: 1)))],
        [(start: start, end: start.add(const Duration(seconds: 2)))],
        [
          (start: start, end: start.add(const Duration(seconds: 1))),
          (start: start, end: start.add(const Duration(seconds: 1))),
        ],
      ]) {
        await expectLater(
          history.recordCompletedSession(1, intervals: intervals),
          throwsArgumentError,
        );
      }
      expect(history.totalFocusSecondsAllTime, 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('fk_history_settlement_state'), isNull);
    });

    test(
      'late callback catches up rest and next focus across midnight',
      () async {
        controller.startFocusSession(
          task: 'Midnight',
          durationSeconds: 20,
          totalSessions: 2,
          restDurationSeconds: 10,
        );
        now = now.add(const Duration(seconds: 45));
        controller.refreshTimer();
        expect(controller.currentSession, 2);
        expect(controller.remainingSeconds, 5);
        expect(history.totalFocusSecondsAllTime, 0);
        now = now.add(const Duration(seconds: 5));
        controller.refreshTimer();
        await pumpEventQueue();
        expect(controller.lastResult!.sessions, 2);
        expect(
          await history.getFocusSecondsForDate(DateTime(2026, 10, 30)),
          10,
        );
        expect(
          await history.getFocusSecondsForDate(DateTime(2026, 10, 31)),
          30,
        );
        expect(await history.getSessionCountForDate(DateTime(2026, 10, 31)), 2);
        expect(history.totalFocusSecondsAllTime, 40);
        controller.refreshTimer();
        await pumpEventQueue();
        expect(history.totalFocusSecondsAllTime, 40);
      },
    );

    test(
      'single callback can finish several elapsed phases exactly once',
      () async {
        controller.startFocusSession(
          task: 'Catch up',
          durationSeconds: 60,
          totalSessions: 3,
          restDurationSeconds: 10,
          longBreakEvery: 2,
          longRestSeconds: 30,
        );
        now = now.add(const Duration(seconds: 500));
        controller.refreshTimer();
        await pumpEventQueue();
        expect(controller.isSetup, isTrue);
        expect(controller.lastResult!.sessions, 3);
        expect(controller.player.coins, 3);
        expect(history.totalFocusSecondsAllTime, 180);
        expect(
          await history.getFocusSecondsForDate(DateTime(2026, 10, 30)),
          10,
        );
        expect(
          await history.getFocusSecondsForDate(DateTime(2026, 10, 31)),
          170,
        );
      },
    );

    test('manual pause excludes the gap across an hour boundary', () async {
      now = DateTime(2026, 10, 31, 10, 59, 50);
      controller.startFocusSession(task: 'Pause', durationSeconds: 20);
      now = now.add(const Duration(seconds: 5));
      expect(controller.pause(), isTrue);
      expect(controller.remainingSeconds, 15);
      now = now.add(const Duration(seconds: 20));
      controller.refreshTimer();
      expect(controller.remainingSeconds, 15);
      expect(controller.pauseRemainingSeconds, 280);
      controller.resumeFromPause();
      now = now.add(const Duration(seconds: 15));
      controller.refreshTimer();
      await pumpEventQueue();
      expect(history.totalFocusSecondsAllTime, 20);
      final hours = await history.getHourlyFocusStats();
      expect(hours[10], 5);
      expect(hours[11], 15);
    });

    test('late auto resume counts focus after the five minute pause', () async {
      controller.startFocusSession(task: 'Timeout', durationSeconds: 20);
      now = now.add(const Duration(seconds: 5));
      controller.pause();
      now = now.add(const Duration(seconds: 308));
      controller.refreshTimer();
      expect(controller.isPaused, isFalse);
      expect(controller.remainingSeconds, 7);
      now = now.add(const Duration(seconds: 7));
      controller.refreshTimer();
      await pumpEventQueue();
      expect(controller.lastResult!.focusSeconds, 20);
      expect(history.totalFocusSecondsAllTime, 20);
    });

    test(
      'fractional pause preserves seconds and fractional history totals',
      () async {
        controller.startFocusSession(task: 'Fractions', durationSeconds: 2);
        now = now.add(const Duration(milliseconds: 500));
        controller.pause();
        now = now.add(const Duration(milliseconds: 1250));
        controller.resumeFromPause();
        now = now.add(const Duration(milliseconds: 1499));
        controller.refreshTimer();
        expect(controller.remainingSeconds, 1);
        expect(controller.lastResult, isNull);
        now = now.add(const Duration(milliseconds: 1));
        controller.refreshTimer();
        await pumpEventQueue();
        expect(history.totalFocusSecondsAllTime, 2);
        expect(controller.settlementFailed, isFalse);
      },
    );

    test('pause cannot postpone an already completed battle', () async {
      controller.startFocusSession(task: 'Expired', durationSeconds: 1);
      now = now.add(const Duration(seconds: 10));
      expect(controller.pause(), isFalse);
      await pumpEventQueue();
      expect(controller.lastResult!.won, isTrue);
    });

    test('skipping rest timestamps next session at actual skip time', () async {
      controller.startFocusSession(
        task: 'Skip',
        durationSeconds: 10,
        totalSessions: 2,
        restDurationSeconds: 300,
      );
      now = now.add(const Duration(seconds: 10));
      controller.refreshTimer();
      now = DateTime(2026, 10, 31, 0, 1);
      controller.finishRestBreak();
      now = now.add(const Duration(seconds: 10));
      controller.refreshTimer();
      await pumpEventQueue();
      expect(history.totalFocusSecondsAllTime, 20);
      expect(await history.getFocusSecondsForDate(DateTime(2026, 10, 30)), 10);
      expect(await history.getFocusSecondsForDate(DateTime(2026, 10, 31)), 10);
    });

    test('skip cannot restart next focus after rest already elapsed', () async {
      controller.startFocusSession(
        task: 'Late skip',
        durationSeconds: 10,
        totalSessions: 2,
        restDurationSeconds: 5,
      );
      now = now.add(const Duration(seconds: 10));
      controller.refreshTimer();
      expect(controller.isResting, isTrue);
      now = now.add(const Duration(seconds: 9));
      controller.finishRestBreak();
      expect(controller.currentSession, 2);
      expect(controller.remainingSeconds, 6);
      now = now.add(const Duration(seconds: 6));
      controller.refreshTimer();
      await pumpEventQueue();
      expect(history.totalFocusSecondsAllTime, 20);
    });

    test('late abandon cannot forfeit an already completed victory', () async {
      controller.startFocusSession(task: 'Late abandon', durationSeconds: 60);
      now = now.add(const Duration(seconds: 61));
      controller.forceAbandonSession();
      await pumpEventQueue();
      expect(controller.lastResult!.won, isTrue);
      expect(controller.player.coins, 1);
      expect(history.totalFocusSecondsAllTime, 60);
    });

    test('stale skip does not skip a later rest in the same battle', () {
      controller.startFocusSession(
        task: 'Stale skip',
        durationSeconds: 10,
        totalSessions: 3,
        restDurationSeconds: 5,
      );
      now = now.add(const Duration(seconds: 10));
      controller.refreshTimer();
      now = now.add(const Duration(seconds: 19));
      controller.finishRestBreak();
      expect(controller.isResting, isTrue);
      expect(controller.currentSession, 2);
      expect(controller.remainingSeconds, 1);
    });
  });
}
