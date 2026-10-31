import 'package:shared_preferences/shared_preferences.dart';

// Generations keep a newer write failure dirty while an older reload is in flight.
int _failedWrite = 0;
int _reloadedWrite = 0;

void invalidatePreferenceCache() => _failedWrite++;

Future<SharedPreferences> loadPersistentPreferences() async {
  final prefs = await SharedPreferences.getInstance();
  // Failed writes change the plugin cache; trust it again only after a successful read.
  while (_reloadedWrite != _failedWrite) {
    final generation = _failedWrite;
    await prefs.reload();
    _reloadedWrite = generation;
  }
  return prefs;
}
