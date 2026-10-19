import 'package:flutter/material.dart';
import '../../core/game/player_state.dart';
import '../../core/game/sprites.dart';
import '../focus_session/focus_session_controller.dart';
import 'camp_view.dart';
import 'focus_view.dart';
import 'mindful_interruption_dialog.dart';
import 'result_view.dart';

/// Full-screen game UI for a battle: Focus → (house destroyed) → Camp → … → Result.
class BattleScreen extends StatefulWidget {
  const BattleScreen({super.key, required this.controller, required this.player, this.onOpenVillage});

  final FocusSessionController controller;
  final PlayerState player;
  final VoidCallback? onOpenVillage;

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  late SessionPhase _lastPhase = widget.controller.phase;
  bool _victoryRun = false;
  bool _mindfulOpen = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onController);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    super.dispose();
  }

  void _onController() {
    final c = widget.controller;
    final sessionWon = _lastPhase == SessionPhase.focus &&
        (c.isResting || (c.isSetup && (c.lastResult?.won ?? false)));
    _lastPhase = c.phase;
    // The session ended (time up or defeat) while the mindful dialog was open: close it.
    if (_mindfulOpen && !c.isFocusing && mounted) {
      _mindfulOpen = false;
      Navigator.of(context).pop();
    }
    if (sessionWon) {
      _victoryRun = true;
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _victoryRun = false);
      });
    }
    if (mounted) setState(() {});
  }

  void _showMindfulDialog() {
    _mindfulOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => MindfulInterruptionDialog(
        onConfirmAbandon: (reason) {
          Navigator.of(ctx).pop();
          // Only a focus session can be abandoned from here; never forfeit a rest break.
          if (widget.controller.isFocusing) widget.controller.forceAbandonSession(reason: reason);
        },
        onResumeFocus: () => Navigator.of(ctx).pop(),
      ),
    ).whenComplete(() => _mindfulOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final hero = characterSprites[widget.player.selectedCharacter]!;

    final Widget body;
    if (c.isFocusing || _victoryRun) {
      body = FocusView(
        controller: c,
        hero: hero,
        victoryRun: _victoryRun,
        onGiveUp: () => c.forceAbandonSession(reason: 'Giữ nút bỏ cuộc'),
      );
    } else if (c.isResting) {
      body = CampView(controller: c, hero: hero, onOpenVillage: widget.onOpenVillage);
    } else if (c.lastResult != null) {
      body = ResultView(result: c.lastResult!, onDone: () => Navigator.of(context).maybePop());
    } else {
      body = const SizedBox.shrink();
    }

    return PopScope(
      canPop: !c.isFocusing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showMindfulDialog();
      },
      child: Scaffold(backgroundColor: kWoodBg, body: body),
    );
  }
}
