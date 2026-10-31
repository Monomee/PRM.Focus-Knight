import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'progression.dart';
import 'village.dart';
import '../services/persistent_preferences.dart';

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
  static const _kWalletState = 'fk_wallet_state';

  int coins = 0;
  int logs = 0;
  GameCharacter selectedCharacter = GameCharacter.pawn;
  GameCharacter badgeCharacter = GameCharacter.pawn;
  Rank badgeRank = Rank.starter;
  int streakTickets = 0;
  DateTime? granaryBuiltAt;
  DateTime? _ticketWeek;
  final Map<Building, int> _levels = {};
  Future<void> _walletSerial = Future.value();

  Future<T> _withWallet<T>(Future<T> Function() action) {
    final result = _walletSerial.then((_) => action());
    _walletSerial = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  int levelOf(Building b) => _levels[b] ?? 0;

  Future<void> load() async {
    final p = await loadPersistentPreferences();
    final walletRaw = p.getString(_kWalletState);
    final wallet = walletRaw == null
        ? null
        : jsonDecode(walletRaw) as Map<String, dynamic>;
    coins = wallet?['coins'] as int? ?? p.getInt(_kCoins) ?? 0;
    logs = wallet?['logs'] as int? ?? p.getInt(_kLogs) ?? 0;
    selectedCharacter =
        GameCharacter.values.asNameMap()[p.getString(_kCharacter)] ??
        GameCharacter.pawn;
    final badge = p.getString(_kBadge)?.split('_');
    if (badge != null && badge.length == 2) {
      badgeCharacter =
          GameCharacter.values.asNameMap()[badge[0]] ?? GameCharacter.pawn;
      badgeRank = Rank.values.asNameMap()[badge[1]] ?? Rank.starter;
    }
    _levels.clear();
    final buildings =
        (wallet?['buildings'] as List?)?.cast<String>() ??
        p.getStringList(_kBuildings) ??
        const <String>[];
    for (final entry in buildings) {
      final parts = entry.split(':');
      final b = Building.values.asNameMap()[parts.first];
      if (b != null && parts.length == 2) {
        _levels[b] = int.tryParse(parts[1]) ?? 0;
      }
    }
    streakTickets = p.getInt(_kTickets) ?? 0;
    granaryBuiltAt = DateTime.tryParse(
      wallet?['granaryBuilt'] as String? ?? p.getString(_kGranaryBuilt) ?? '',
    );
    _ticketWeek = DateTime.tryParse(p.getString(_kTicketWeek) ?? '');
    notifyListeners();
  }

  Future<void> deposit({
    required int coins,
    required int logs,
    String? settlementId,
  }) => _withWallet(() async {
    final p = await loadPersistentPreferences();
    final walletRaw = p.getString(_kWalletState);
    final wallet = walletRaw == null
        ? <String, dynamic>{
            'coins': this.coins,
            'logs': this.logs,
            'applied': <String>[],
          }
        : jsonDecode(walletRaw) as Map<String, dynamic>;
    final applied = (wallet['applied'] as List? ?? const []).cast<String>();
    if (settlementId != null && applied.contains(settlementId)) {
      this.coins = wallet['coins'] as int;
      this.logs = wallet['logs'] as int;
      return;
    }
    final nextCoins = (wallet['coins'] as int) + coins;
    final nextLogs = (wallet['logs'] as int) + logs;
    await _writeWallet(p, nextCoins, nextLogs, _levels, granaryBuiltAt, [
      ...applied,
      ?settlementId,
    ]);
    this.coins = nextCoins;
    this.logs = nextLogs;
    notifyListeners();
  });

  Future<bool> build(Building b, Rank current) => _withWallet(() async {
    final level = levelOf(b);
    final required = b.requiredCharacter;
    if (level >= b.maxLevel) return false;
    if (required != null && !isCharacterUnlocked(required, current)) {
      return false;
    }
    final cost = buildCost(b, level);
    if (coins < cost.coins || logs < cost.logs) return false;

    final nextLevels = {..._levels, b: level + 1};
    final builtAt = b == Building.granary
        ? granaryBuiltAt ?? _dayOf(_clock())
        : granaryBuiltAt;
    final p = await loadPersistentPreferences();
    final raw = p.getString(_kWalletState);
    final applied = raw == null
        ? <String>[]
        : ((jsonDecode(raw) as Map)['applied'] as List).cast<String>();
    await _writeWallet(
      p,
      coins - cost.coins,
      logs - cost.logs,
      nextLevels,
      builtAt,
      applied,
    );
    coins -= cost.coins;
    logs -= cost.logs;
    _levels[b] = level + 1;
    granaryBuiltAt = builtAt;
    if (b == Building.granary) {
      await grantWeeklyTicket(_clock());
    }
    notifyListeners();
    await _save();
    return true;
  });

  Future<void> _writeWallet(
    SharedPreferences p,
    int nextCoins,
    int nextLogs,
    Map<Building, int> levels,
    DateTime? builtAt,
    List<String> applied,
  ) async {
    try {
      if (!await p.setString(
        _kWalletState,
        jsonEncode({
          'coins': nextCoins,
          'logs': nextLogs,
          'applied': applied,
          'buildings': [
            for (final e in levels.entries) '${e.key.name}:${e.value}',
          ],
          'granaryBuilt': builtAt == null ? null : _fmt(builtAt),
        }),
      )) {
        throw StateError('Failed to save wallet');
      }
    } catch (_) {
      invalidatePreferenceCache();
      rethrow;
    }
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
    final p = await loadPersistentPreferences();
    final writes = <Future<bool>>[
      p.setInt(_kCoins, coins),
      p.setInt(_kLogs, logs),
      p.setString(_kCharacter, selectedCharacter.name),
      p.setString(_kBadge, '${badgeCharacter.name}_${badgeRank.name}'),
      p.setStringList(_kBuildings, [
        for (final e in _levels.entries) '${e.key.name}:${e.value}',
      ]),
      p.setInt(_kTickets, streakTickets),
      if (granaryBuiltAt != null)
        p.setString(_kGranaryBuilt, _fmt(granaryBuiltAt!)),
      if (_ticketWeek != null) p.setString(_kTicketWeek, _fmt(_ticketWeek!)),
    ];
    if ((await Future.wait(writes)).contains(false)) {
      throw StateError('Failed to save player state');
    }
  }
}
