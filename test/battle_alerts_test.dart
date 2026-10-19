import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_dart/core/game/player_state.dart';
import 'package:test_dart/core/services/alert_notifier.dart';
import 'package:test_dart/features/dashboard/services/focus_history_service.dart';
import 'package:test_dart/features/focus_session/focus_session_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> alerts;
  late FocusSessionController c;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'fk_total_focus_seconds_all_time': 10 * 3600 - 600});
    alerts = [];
    AlertNotifier.sink = (title, body) async => alerts.add(title);
    final player = PlayerState();
    await player.load();
    final history = FocusHistoryService();
    await history.loadData();
    c = FocusSessionController(player: player, history: history);
  });

  tearDown(() {
    c.cancelSession();
    AlertNotifier.sink = null;
  });

  test('alerts only on session start/end and rank up', () async {
    c.startFocusSession(task: 'T', durationSeconds: 1500, totalSessions: 2);
    expect(alerts, ['⚔ Bắt đầu phiên 1/2']);

    c.debugCompleteFocus();
    expect(alerts.last, '🎉 Xong phiên 1/2');

    c.finishRestBreak();
    expect(alerts.last, '⚔ Bắt đầu phiên 2/2');

    c.debugCompleteFocus();
    await pumpEventQueue();
    expect(alerts.sublist(3), ['🏆 Hoàn thành trận!', '🏅 Lên hạng Gold!']);
  });

  test('the per-second countdown never alerts', () async {
    c.startFocusSession(task: 'T', durationSeconds: 5);
    await Future.delayed(const Duration(milliseconds: 2500));
    expect(alerts, ['⚔ Bắt đầu phiên 1/1']);
  });

  test('defeat ends the session with an alert', () {
    c.startFocusSession(task: 'T', durationSeconds: 1500);
    for (var i = 0; i < 4; i++) {
      c.applyBlacklistPenalty();
    }
    expect(alerts.last, '💀 Thất bại');
  });
}
