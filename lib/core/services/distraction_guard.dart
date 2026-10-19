import '../game/economy.dart';

/// Penalty state machine for blacklisted apps during a battle, driven by periodic [tick]s.
/// idle → grace (blacklisted app opened) → penalized (grace expired; taxed every 30s).
/// Leaving the blacklisted app returns to idle, so the next visit is penalized again.
class DistractionGuard {
  DistractionGuard({
    required this.graceSeconds,
    required this.onPenalty,
    required this.onTax,
    required this.onLeftBlacklisted,
    this.onGraceStart,
  });

  final int Function() graceSeconds;
  final void Function(String pkg) onPenalty;
  final void Function() onTax;
  final void Function() onLeftBlacklisted;

  /// A blacklisted app was just opened: warn before the penalty lands.
  final void Function(String pkg)? onGraceStart;

  DateTime? _graceStart;
  DateTime? _lastTax;

  void tick(String? blacklistedPkg, DateTime now) {
    if (blacklistedPkg == null) {
      if (_graceStart != null || _lastTax != null) {
        reset();
        onLeftBlacklisted();
      }
      return;
    }
    if (_lastTax != null) {
      if (now.difference(_lastTax!).inSeconds >= kTaxIntervalSeconds) {
        _lastTax = now;
        onTax();
      }
      return;
    }
    if (_graceStart == null) {
      _graceStart = now;
      onGraceStart?.call(blacklistedPkg);
    }
    if (now.difference(_graceStart!).inSeconds >= graceSeconds()) {
      _graceStart = null;
      _lastTax = now;
      onPenalty(blacklistedPkg);
    }
  }

  void reset() {
    _graceStart = null;
    _lastTax = null;
  }
}
