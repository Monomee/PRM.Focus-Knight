import 'package:flutter/material.dart';
import '../game_view/combat_engine.dart';

/// Camp upgrade sheet accessible ONLY during the Rest interval.
/// Allows spending Gold earned during focus sessions to upgrade ATK, Max HP, and Crit Rate.
class CampUpgradeSheet extends StatelessWidget {
  final CombatEngine engine;
  final VoidCallback onFinishRest;

  const CampUpgradeSheet({
    super.key,
    required this.engine,
    required this.onFinishRest,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Workshop Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.fireplace, color: Color(0xFFF97316), size: 22),
                SizedBox(width: 8),
                Text(
                  'CAMP WORKSHOP',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Color(0xFFF1F5F9),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFB45309).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFB300), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.monetization_on, color: Color(0xFFFFD54F), size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${engine.gold} GOLD',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFFD54F),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 6),
        const Text(
          'Rest break active! Spend your quest bounty on permanent stat upgrades.',
          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
        ),

        const SizedBox(height: 14),

        // Upgrade 1: ATK (+2)
        _buildUpgradeCard(
          title: 'Weapon Sharpness',
          statPreview: '${engine.atk} ATK  ➜  ${engine.atk + 2} ATK',
          cost: engine.atkUpgradeCost,
          canAfford: engine.gold >= engine.atkUpgradeCost,
          icon: Icons.colorize,
          accentColor: const Color(0xFFEF4444),
          onUpgrade: () => engine.upgradeAtk(),
        ),

        const SizedBox(height: 10),

        // Upgrade 2: Max HP (+10)
        _buildUpgradeCard(
          title: 'Knight Armor Plate',
          statPreview: '${engine.maxHp} HP  ➜  ${engine.maxHp + 10} HP',
          cost: engine.hpUpgradeCost,
          canAfford: engine.gold >= engine.hpUpgradeCost,
          icon: Icons.shield,
          accentColor: const Color(0xFF22C55E),
          onUpgrade: () => engine.upgradeMaxHp(),
        ),

        const SizedBox(height: 10),

        // Upgrade 3: Crit Rate (+1%)
        _buildUpgradeCard(
          title: 'Deadly Precision',
          statPreview: '${engine.critRate.toInt()}% CRIT  ➜  ${engine.critRate.toInt() + 1}% CRIT',
          cost: engine.critUpgradeCost,
          canAfford: engine.gold >= engine.critUpgradeCost && engine.critRate < 100,
          icon: Icons.flash_on,
          accentColor: const Color(0xFFFBBF24),
          onUpgrade: () => engine.upgradeCritRate(),
        ),

        const SizedBox(height: 16),

        // Quick Ready Action Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onFinishRest,
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text(
              'READY FOR NEXT QUEST',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUpgradeCard({
    required String title,
    required String statPreview,
    required int cost,
    required bool canAfford,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onUpgrade,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2333),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          // Icon badge
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),

          const SizedBox(width: 12),

          // Upgrade Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF1F5F9),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statPreview,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),

          // Buy Button
          ElevatedButton(
            onPressed: canAfford ? onUpgrade : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB45309),
              disabledBackgroundColor: const Color(0xFF1F2937),
              foregroundColor: Colors.white,
              disabledForegroundColor: const Color(0xFF4B5563),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on, size: 14, color: Color(0xFFFFD54F)),
                const SizedBox(width: 4),
                Text(
                  '$cost',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
