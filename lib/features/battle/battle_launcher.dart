import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/game/battle_plan.dart';
import '../../core/game/player_state.dart';
import '../../core/game/village.dart';
import '../focus_session/focus_session_controller.dart';
import 'battle_screen.dart';
import 'battle_setup_sheet.dart';

const kLastPlanKey = 'fk_last_plan';
const kLongRestMinutesKey = 'fk_long_rest_minutes';

/// Opens the battle: resumes a running one, otherwise asks for a plan first.
Future<void> openBattle(
  BuildContext context, {
  required FocusSessionController controller,
  required PlayerState player,
  VoidCallback? onOpenVillage,
}) async {
  if (controller.isSetup) {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(kLastPlanKey);
    final initial = saved == null ? BattlePlan.defaults : BattlePlan.fromJson(jsonDecode(saved));
    final longRest = prefs.getInt(kLongRestMinutesKey) ?? 15;
    if (!context.mounted) return;
    final plan = await showBattleSetupSheet(
      context,
      initial: initial,
      barracksLevel: player.levelOf(Building.barracks),
      longRestMinutes: longRest,
    );
    if (plan == null) return;
    await prefs.setString(kLastPlanKey, jsonEncode(plan.toJson()));
    controller.startFocusSession(
      task: plan.task,
      durationSeconds: plan.focusMinutes * 60,
      restDurationSeconds: plan.restMinutes * 60,
      totalSessions: plan.sessions,
      longBreakEvery: plan.longBreakEvery,
      longRestSeconds: longRest * 60,
    );
  }
  if (!context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => BattleScreen(controller: controller, player: player, onOpenVillage: onOpenVillage),
  ));
}
