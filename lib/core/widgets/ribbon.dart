import 'package:flutter/material.dart';

enum RibbonColor { yellow, blue, red }

/// Tiny Swords 3-slice ribbon stretched behind [child].
class Ribbon extends StatelessWidget {
  const Ribbon({super.key, required this.color, required this.child, this.height = 52});

  final RibbonColor color;
  final Widget child;
  final double height;

  static const _assets = {
    RibbonColor.yellow: 'ui/ribbons/Ribbon_Yellow_3Slides.png',
    RibbonColor.blue: 'ui/ribbons/Ribbon_Blue_3Slides.png',
    RibbonColor.red: 'ui/ribbons/Ribbon_Red_3Slides.png',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      constraints: BoxConstraints(minWidth: height * 3),
      padding: EdgeInsets.fromLTRB(height * 0.8, 0, height * 0.8, height * 0.12),
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(_assets[color]!),
          centerSlice: const Rect.fromLTWH(64, 0, 64, 64),
          scale: 64 / height,
          filterQuality: FilterQuality.none,
        ),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}
