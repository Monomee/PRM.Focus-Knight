import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// Service managing the full-screen warning overlay blocker and its permission
class OverlayService extends ChangeNotifier {
  static const _channel = MethodChannel('focusknight/overlay');
  bool _hasPermission = false;
  bool get hasPermission => _hasPermission;

  bool _isOverlayOpen = false;
  bool get isOverlayOpen => _isOverlayOpen;
  Future<void> _operations = Future.value();
  int _generation = 0;
  bool _disposed = false;
  bool _requestingPermission = false;

  Future<void> _enqueue(Future<void> Function() action) {
    return _operations = _operations
        .then((_) => action())
        .catchError((Object _) {});
  }

  // Stop even a pending native start; plugin 0.5.0 only closes running services.
  Future<void> _stopOverlay() => _channel.invokeMethod<void>('closeOverlay');

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  OverlayService() {
    checkPermission();
  }

  Future<bool> checkPermission() async {
    // Plugin 0.5.0 overwrites the pending permission result on any method call.
    if (_requestingPermission) return _hasPermission;
    try {
      final granted = await FlutterOverlayWindow.isPermissionGranted();
      _hasPermission = granted;
      _changed();
      return _hasPermission;
    } catch (_) {
      _hasPermission = false;
      _changed();
      return false;
    }
  }

  Future<void> requestPermission() => _enqueue(() async {
    if (_disposed) return;
    _requestingPermission = true;
    try {
      await FlutterOverlayWindow.requestPermission();
    } catch (_) {
    } finally {
      _requestingPermission = false;
    }
    await checkPermission();
  });

  /// Opens the system "Display over other apps" settings screen so users can manage or revoke the permission
  Future<void> openSettings() => requestPermission();

  bool isAppInForeground = true;

  /// Show the full-screen blocker overlay properly centered without vertical pixel drift
  Future<void> showBlockerOverlay({
    String reason = 'Quest abandoned! Return to Focus.',
    bool force = false,
    Map<String, Object>? state,
  }) {
    final generation = _generation;
    bool cancelled() =>
        _disposed || generation != _generation || (!force && isAppInForeground);
    return _enqueue(() async {
      // CRITICAL: Never show overlay if user is actively inside FocusKnight, unless manual preview
      if (cancelled()) return;

      final hasPerm = await checkPermission();
      if (!hasPerm || cancelled()) return;

      try {
        final active = await FlutterOverlayWindow.isActive();
        if (cancelled()) return;
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
            startPosition: const OverlayPosition(
              0,
              0,
            ), // Explicit (0,0) fixes Android status_bar offset bug
          );
        }
        if (cancelled()) {
          await _stopOverlay();
          return;
        }
        _isOverlayOpen = true;
        if (state != null) {
          await _channel.invokeMethod<void>('shareData', state);
        }
        _changed();
      } catch (_) {}
    });
  }

  Future<void> showDailyLimitOverlay({
    required String appName,
    required int limitMinutes,
  }) {
    return showBlockerOverlay(
      reason: '$appName đã hết hạn mức $limitMinutes phút hôm nay.',
      state: {
        'mode': 'dailyLimit',
        'app': appName,
        'limitMinutes': limitMinutes,
        'defeated': false,
      },
    );
  }

  /// Sends live battle state to the overlay isolate (it can't read the controller directly).
  Future<void> pushState({
    required String appName,
    required int heroHp,
    required int pendingCoins,
    required bool defeated,
  }) => _enqueue(() async {
    if (_disposed || isAppInForeground || !_isOverlayOpen) return;
    try {
      await _channel.invokeMethod<void>('shareData', {
        'mode': 'battle',
        'app': appName,
        'hp': heroHp,
        'coins': pendingCoins,
        'defeated': defeated,
      });
    } catch (_) {}
  });

  /// Close the overlay
  Future<void> closeBlockerOverlay() {
    _generation++;
    return _enqueue(() async {
      try {
        await _stopOverlay();
        _isOverlayOpen = false;
        _changed();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _disposed = true;
    closeBlockerOverlay();
    super.dispose();
  }
}
