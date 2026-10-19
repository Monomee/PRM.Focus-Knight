import 'package:flutter/material.dart';
import '../../core/game/player_state.dart';
import '../../core/services/overlay_service.dart';
import '../../core/widgets/flat_theme.dart';
import '../../core/widgets/sprite_anim.dart';
import '../collection/collection_screen.dart';
import '../dashboard/services/focus_history_service.dart';
import '../focus_session/focus_session_controller.dart';
import '../home/home_screen.dart';
import '../settings/settings_screen.dart';
import '../telemetry/screen_time_tracker.dart';

/// Flat 4-tab shell: Trang chủ · Làng · Bộ sưu tập · Cài đặt.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.controller,
    required this.player,
    required this.tracker,
    required this.overlay,
  });

  final FocusSessionController controller;
  final PlayerState player;
  final ScreenTimeTracker tracker;
  final OverlayService overlay;

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  static const villageTab = 1;
  int _index = 0;

  /// Switches tab, closing any pushed route (e.g. the battle camp) first.
  void openTab(int index) {
    Navigator.of(context).popUntil((r) => r.isFirst);
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final history = FocusHistoryService.instance;
    final pages = [
      HomeScreen(
        controller: widget.controller,
        player: widget.player,
        history: history,
        onOpenVillage: () => openTab(villageTab),
      ),
      const Center(child: Text('Sắp có', style: Flat.label)),
      ListenableBuilder(
        listenable: history,
        builder: (context, _) =>
            CollectionScreen(player: widget.player, totalFocusSeconds: history.totalFocusSecondsAllTime),
      ),
      SettingsScreen(screenTimeTracker: widget.tracker, overlayService: widget.overlay),
    ];
    return Scaffold(
      backgroundColor: Flat.bg,
      body: SafeArea(child: IndexedStack(index: _index, children: pages)),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF11151F),
          border: Border(top: BorderSide(color: Flat.border, width: 1.5)),
        ),
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          indicatorColor: Flat.accent.withValues(alpha: 0.15),
          elevation: 0,
          height: 64,
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(icon: PixelIcon('sword'), label: 'Trang chủ'),
            NavigationDestination(icon: PixelIcon('hammer'), label: 'Làng'),
            NavigationDestination(icon: PixelIcon('shield'), label: 'Bộ sưu tập'),
            NavigationDestination(icon: PixelIcon('setting'), label: 'Cài đặt'),
          ],
        ),
      ),
    );
  }
}
