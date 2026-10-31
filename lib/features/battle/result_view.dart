import 'package:flutter/material.dart';
import '../../core/game/sprites.dart';
import '../../core/widgets/sprite_anim.dart';
import '../focus_session/focus_session_controller.dart';
import 'camp_view.dart';

/// End-of-battle summary: victory pays out, defeat forfeits everything.
class ResultView extends StatelessWidget {
  const ResultView({super.key, required this.result, required this.onDone,
    this.onRetry, this.isSaving = false});

  final BattleResult result;
  final VoidCallback onDone;
  final VoidCallback? onRetry;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final won = result.won;
    return ColoredBox(
      color: kWoodBg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Spacer(),
            if (won)
              Image.asset('ui/buildings/enemy_building/Goblin_House_Destroyed.png',
                  width: 140, filterQuality: FilterQuality.none)
            else
              const SpriteAnim(sheet: deadSprite, size: 160, loop: false),
            const SizedBox(height: 16),
            Text(won ? 'Chiến thắng!' : 'Thất bại – mất toàn bộ phần thưởng và giờ của trận',
                textAlign: TextAlign.center,
                style: woodText(won ? 30 : 20, color: won ? const Color(0xFFFFD54F) : const Color(0xFFF87171))),
            const SizedBox(height: 16),
            if (won) ...[
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const PixelIcon('coin', size: 30),
                Text('+${result.coins}', style: woodText(22)),
                const SizedBox(width: 24),
                const PixelIcon('log', size: 30),
                Text('+${result.logs}', style: woodText(22)),
              ]),
              const SizedBox(height: 8),
              Text('${result.sessions} phiên · ${result.focusSeconds ~/ 60} phút tập trung', style: woodText(14)),
            ],
            const Spacer(),
            if (isSaving) Text('Đang lưu phần thưởng…', style: woodText(14)),
            if (onRetry != null) ...[
              Text('Chưa lưu được phần thưởng. Hãy thử lại trước khi đóng ứng dụng.',
                  textAlign: TextAlign.center, style: woodText(14)),
              TextButton(onPressed: onRetry, child: const Text('Thử lại nhận thưởng')),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onDone,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB300),
                  foregroundColor: const Color(0xFF1A1200),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('Về trang chủ', style: woodText(17, color: const Color(0xFF1A1200))),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
