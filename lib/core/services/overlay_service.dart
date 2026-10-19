import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// Service managing the full-screen warning overlay blocker and its permission
class OverlayService extends ChangeNotifier {
  bool _hasPermission = false;
  bool get hasPermission => _hasPermission;

  bool _isOverlayOpen = false;
  bool get isOverlayOpen => _isOverlayOpen;

  OverlayService() {
    checkPermission();
  }

  Future<bool> checkPermission() async {
    try {
      final granted = await FlutterOverlayWindow.isPermissionGranted();
      _hasPermission = granted;
      notifyListeners();
      return _hasPermission;
    } catch (_) {
      _hasPermission = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> requestPermission() async {
    try {
      await FlutterOverlayWindow.requestPermission();
      await Future.delayed(const Duration(milliseconds: 500));
      await checkPermission();
    } catch (_) {}
  }

  /// Opens the system "Display over other apps" settings screen so users can manage or revoke the permission
  Future<void> openSettings() async {
    try {
      await FlutterOverlayWindow.requestPermission();
      await Future.delayed(const Duration(milliseconds: 500));
      await checkPermission();
    } catch (_) {}
  }

  bool isAppInForeground = true;

  /// Show the full-screen blocker overlay properly centered without vertical pixel drift
  Future<void> showBlockerOverlay({
    String reason = 'Quest abandoned! Return to Focus.',
    bool force = false,
  }) async {
    // CRITICAL: Never show overlay if user is actively inside FocusKnight, unless manual preview
    if (!force && isAppInForeground) {
      return;
    }

    final hasPerm = await checkPermission();
    if (!hasPerm) return;

    try {
      final active = await FlutterOverlayWindow.isActive();
      if (!active) {
        await FlutterOverlayWindow.showOverlay(
          enableDrag: false,
          overlayTitle: 'FocusKnight Blocker',
          overlayContent: reason,
          flag: OverlayFlag.defaultFlag,
          visibility: NotificationVisibility.visibilitySecret,
          height: WindowSize.fullCover,
          width: WindowSize.matchParent,
          alignment: OverlayAlignment.center,
          startPosition: const OverlayPosition(0, 0), // Explicit (0,0) fixes Android status_bar offset bug
        );
        _isOverlayOpen = true;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Sends live battle state to the overlay isolate (it can't read the controller directly).
  Future<void> pushState({
    required String appName,
    required int heroHp,
    required int pendingCoins,
    required bool defeated,
  }) async {
    try {
      await FlutterOverlayWindow.shareData({
        'app': appName,
        'hp': heroHp,
        'coins': pendingCoins,
        'defeated': defeated,
      });
    } catch (_) {}
  }

  /// Close the overlay
  Future<void> closeBlockerOverlay() async {
    try {
      await FlutterOverlayWindow.closeOverlay();
      _isOverlayOpen = false;
      notifyListeners();
    } catch (_) {}
  }

}
