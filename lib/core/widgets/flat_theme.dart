import 'package:flutter/material.dart';

/// Flat "neo-retro minimal" palette for everything outside the battle.
class Flat {
  static const bg = Color(0xFF0F131C);
  static const card = Color(0xFF151A26);
  static const border = Color(0xFF232A3B);
  static const accent = Color(0xFFFFB300);
  static const text = Color(0xFFE2E8F0);
  static const muted = Color(0xFF7C8799);
  static const danger = Color(0xFFF87171);
  static const rest = Color(0xFF10B981);
  static const longRest = Color(0xFF3B82F6);

  static BoxDecoration cardBox({Color? borderColor}) => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor ?? border, width: 1.5),
      );

  static const label = TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w600, letterSpacing: 0.5);
}

/// Selectable flat chip.
class FlatChip extends StatelessWidget {
  const FlatChip({super.key, required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? Flat.accent.withValues(alpha: 0.1) : null,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: selected ? Flat.accent : Flat.border, width: 1.5),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Flat.accent : Flat.text)),
          ),
        ),
      );
}
