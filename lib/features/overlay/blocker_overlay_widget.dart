import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../../core/game/economy.dart';
import '../../core/widgets/sprite_anim.dart';

/// Full-screen blocker shown over a blacklisted app during a battle.
/// Runs in the overlay isolate; live HP/escrow arrive via [FlutterOverlayWindow.shareData].
class BlockerOverlayWidget extends StatefulWidget {
  const BlockerOverlayWidget({super.key, this.updates, this.onAutoClose});

  /// Defaults to [FlutterOverlayWindow.overlayListener]; injectable for tests.
  final Stream<dynamic>? updates;

  /// Defaults to [FlutterOverlayWindow.closeOverlay]; injectable for tests.
  final Future<void> Function()? onAutoClose;

  static const defeatDisplay = Duration(seconds: 5);

  @override
  State<BlockerOverlayWidget> createState() => _BlockerOverlayWidgetState();
}

class _BlockerOverlayWidgetState extends State<BlockerOverlayWidget> {
  StreamSubscription<dynamic>? _sub;
  String _app = '';
  int _hp = kHeroMaxHp;
  int _coins = 0;
  bool _defeated = false;
  Timer? _closeTimer;

  @override
  void initState() {
    super.initState();
    _sub = (widget.updates ?? FlutterOverlayWindow.overlayListener).listen((data) {
      if (data is! Map) return;
      setState(() {
        _app = data['app'] as String? ?? _app;
        _hp = data['hp'] as int? ?? _hp;
        _coins = data['coins'] as int? ?? _coins;
        _defeated = data['defeated'] as bool? ?? _defeated;
      });
      // The battle is over: show the defeat briefly, then stop blocking.
      if (!_defeated) {
        // The overlay engine is reused across battles: a live battle cancels any old countdown.
        _closeTimer?.cancel();
        _closeTimer = null;
      } else {
        _closeTimer ??= Timer(BlockerOverlayWidget.defeatDisplay, () {
          _closeTimer = null;
          (widget.onAutoClose ?? FlutterOverlayWindow.closeOverlay)();
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _closeTimer?.cancel();
    super.dispose();
  }

  TextStyle _pixel(double size, Color color) =>
      TextStyle(fontFamily: kPixelFont, fontSize: size, color: color, fontWeight: FontWeight.w700);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0B0E14),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1712),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEF4444), width: 2),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const PixelIcon('shield', size: 64),
                const SizedBox(height: 12),
                Text(_defeated ? 'Thất bại – mất toàn bộ phần thưởng của trận' : 'ĐANG TRONG TRẬN!',
                    textAlign: TextAlign.center, style: _pixel(22, const Color(0xFFEF4444))),
                if (_app.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(_app, style: _pixel(16, const Color(0xFFF5E6C8))),
                ],
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: _hp / kHeroMaxHp,
                    minHeight: 12,
                    color: const Color(0xFFEF4444),
                    backgroundColor: const Color(0xFF3A2A20),
                  ),
                ),
                const SizedBox(height: 4),
                Text('HP $_hp/$kHeroMaxHp', style: _pixel(14, const Color(0xFFF5E6C8))),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const PixelIcon('coin', size: 24),
                  const SizedBox(width: 6),
                  Text('Quỹ trận: $_coins coin', style: _pixel(15, const Color(0xFFFFD54F))),
                ]),
                if (!_defeated)
                  Text('−$kDistractionTax coin mỗi $kTaxIntervalSeconds giây',
                      style: _pixel(12, const Color(0xFFF87171))),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      FlutterForegroundTask.launchApp('/');
                      await FlutterOverlayWindow.closeOverlay();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('QUAY LẠI TRẬN', style: _pixel(17, Colors.white)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
