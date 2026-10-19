import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Alerting notifications (sound / heads-up) on their own channel, posted by MainActivity.
/// Kept separate from the silent foreground-service notification so the countdown never buzzes.
class AlertNotifier {
  static const _channel = MethodChannel('focusknight/alerts');

  // One slot per kind: a newer alert of the same kind replaces the older one.
  static const session = 1;
  static const violation = 2;
  static const rank = 3;
  static const appLimit = 4;

  @visibleForTesting
  static Future<void> Function(String title, String body)? sink;

  static Future<void> show(String title, String body, {int id = session}) async {
    final test = sink;
    if (test != null) return test(title, body);
    try {
      await _channel.invokeMethod('show', {'id': id, 'title': title, 'body': body});
    } catch (_) {}
  }
}
