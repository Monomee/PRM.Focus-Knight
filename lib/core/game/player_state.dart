import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'progression.dart';
import 'village.dart';

/// Wallet, chosen character/badge, village buildings and streak tickets.
class PlayerState extends ChangeNotifier {
  PlayerState({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  static const _kCoins = 'fk_gold'; // legacy key, keeps old gold
  static const _kLogs = 'fk_logs';
  static const _kCharacter = 'fk_character';
  static const _kBadge = 'fk_badge';
  static const _kBuildings = 'fk_buildings';
  static const _kTickets = 'fk_streak_tickets';
  static const _kGranaryBuilt = 'fk_granary_built';
  static const _kTicketWeek = 'fk_ticket_week';

  int coins = 0;
  int logs = 0;
  GameCharacter selectedCharacter = GameCharacter.pawn;
  GameCharacter badgeCharacter = GameCharacter.pawn;
  Rank badgeRank = Rank.starter;
  int streakTickets = 0;
  DateTime? granaryBuiltAt;
  DateTime? _ticketWeek;
  final Map<Building, int> _levels = {};

  int levelOf(Building b) => _levels[b] ?? 0;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    coins = p.getInt(_kCoins) ?? 0;
    logs = p.getInt(_kLogs) ?? 0;
    selectedCharacter = GameCharacter.values.asNameMap()[p.getString(_kCharacter)] ?? GameCharacter.pawn;
    final badge = p.getString(_kBadge)?.split('_');
    if (badge != null && badge.length == 2) {
      badgeCharacter = GameCharacter.values.asNameMap()[badge[0]] ?? GameCharacter.pawn;
      badgeRank = Rank.values.asNameMap()[badge[1]] ?? Rank.starter;
    }
    _levels.clear();
    for (final entry in p.getStringList(_kBuildings) ?? const <String>[]) {
      final parts = entry.split(':');
      final b = Building.values.asNameMap()[parts.first];
      if (b != null && parts.length == 2) _levels[b] = int.tryParse(parts[1]) ?? 0;
    }
    streakTickets = p.getInt(_kTickets) ?? 0;
    granaryBuiltAt = DateTime.tryParse(p.getString(_kGranaryBuilt) ?? '');
    _ticketWeek = DateTime.tryParse(p.getString(_kTicketWeek) ?? '');
    notifyListeners();
  }

  Future<void> deposit({required int coins, required int logs}) async {
    this.coins += coins;
    this.logs += logs;
    notifyListeners();
    await _save();
  }

  Future<bool> build(Building b, Rank current) async {
    final level = levelOf(b);
    final required = b.requiredCharacter;
    if (level >= b.maxLevel) return false;
    if (required != null && !isCharacterUnlocked(required, current)) return false;
    final cost = buildCost(b, level);
    if (coins < cost.coins || logs < cost.logs) return false;

    coins -= cost.coins;
    logs -= cost.logs;
    _levels[b] = level + 1;
    if (b == Building.granary && granaryBuiltAt == null) {
      granaryBuiltAt = _dayOf(_clock());
      await grantWeeklyTicket(_clock());
    }
    notifyListeners();
    await _save();
    return true;
  }

  Future<void> selectCharacter(GameCharacter c, Rank current) async {
    if (!isCharacterUnlocked(c, current)) return;
    selectedCharacter = c;
    notifyListeners();
    await _save();
  }

  Future<void> selectBadge(GameCharacter c, Rank badge, Rank current) async {
    if (!isBadgeUnlocked(c, badge, current)) return;
    badgeCharacter = c;
    badgeRank = badge;
    notifyListeners();
    await _save();
  }

  /// Grants one ticket per calendar week (Monday start) once the granary exists; holds at most 1.
  Future<void> grantWeeklyTicket(DateTime now) async {
    if (levelOf(Building.granary) == 0) return;
    final day = _dayOf(now);
    final monday = day.subtract(Duration(days: day.weekday - DateTime.monday));
    if (_ticketWeek == monday) return;
    _ticketWeek = monday;
    streakTickets = 1;
    notifyListeners();
    await _save();
  }

  bool consumeTicket() {
    if (streakTickets <= 0) return false;
    streakTickets--;
    notifyListeners();
    _save();
    return true;
  }

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_kCoins, coins);
      await p.setInt(_kLogs, logs);
      await p.setString(_kCharacter, selectedCharacter.name);
      await p.setString(_kBadge, '${badgeCharacter.name}_${badgeRank.name}');
      await p.setStringList(_kBuildings, [for (final e in _levels.entries) '${e.key.name}:${e.value}']);
      await p.setInt(_kTickets, streakTickets);
      if (granaryBuiltAt != null) await p.setString(_kGranaryBuilt, _fmt(granaryBuiltAt!));
      if (_ticketWeek != null) await p.setString(_kTicketWeek, _fmt(_ticketWeek!));
    } catch (_) {}
  }
}
