import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_dart/core/game/player_state.dart';
import 'package:test_dart/core/game/progression.dart';
import 'package:test_dart/core/game/village.dart';

Future<PlayerState> _loaded(Map<String, Object> prefs, {DateTime Function()? clock}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final p = PlayerState(clock: clock);
  await p.load();
  return p;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('load keeps legacy fk_gold', () async {
    final p = await _loaded({'fk_gold': 120});
    expect(p.coins, 120);
    expect(p.logs, 0);
    expect(p.selectedCharacter, GameCharacter.pawn);
    expect(p.badgeCharacter, GameCharacter.pawn);
    expect(p.badgeRank, Rank.starter);
  });

  test('deposit then reload persists', () async {
    final p = await _loaded({});
    await p.deposit(coins: 30, logs: 12);
    final reloaded = PlayerState();
    await reloaded.load();
    expect(reloaded.coins, 30);
    expect(reloaded.logs, 12);
  });

  test('build succeeds and spends', () async {
    final p = await _loaded({'fk_gold': 500, 'fk_logs': 100});
    expect(await p.build(Building.tower, Rank.starter), isTrue);
    expect(p.coins, 300);
    expect(p.logs, 60);
    expect(p.levelOf(Building.tower), 1);
    final reloaded = PlayerState();
    await reloaded.load();
    expect(reloaded.levelOf(Building.tower), 1);
  });

  test('build fails without funds', () async {
    final p = await _loaded({'fk_gold': 100, 'fk_logs': 100});
    expect(await p.build(Building.tower, Rank.starter), isFalse);
    expect(p.coins, 100);
    expect(p.levelOf(Building.tower), 0);
  });

  test('build fails for locked character house', () async {
    final p = await _loaded({'fk_gold': 9999, 'fk_logs': 9999});
    expect(await p.build(Building.archery, Rank.gold), isFalse);
    expect(p.coins, 9999);
    expect(await p.build(Building.archery, Rank.diamond), isTrue);
  });

  test('build fails at max level', () async {
    final p = await _loaded({'fk_gold': 9999, 'fk_logs': 9999});
    expect(await p.build(Building.granary, Rank.starter), isTrue);
    final coins = p.coins;
    expect(await p.build(Building.granary, Rank.starter), isFalse);
    expect(p.coins, coins);
  });

  test('ticket only after granary, once per week', () async {
    var now = DateTime(2026, 10, 21); // Wednesday
    final p = await _loaded({'fk_gold': 9999, 'fk_logs': 9999}, clock: () => now);
    await p.grantWeeklyTicket(now);
    expect(p.streakTickets, 0);

    await p.build(Building.granary, Rank.starter);
    expect(p.streakTickets, 1);
    expect(p.granaryBuiltAt, DateTime(2026, 10, 21));

    expect(p.consumeTicket(), isTrue);
    expect(p.streakTickets, 0);
    expect(p.consumeTicket(), isFalse);

    await p.grantWeeklyTicket(now);
    expect(p.streakTickets, 0);

    now = DateTime(2026, 10, 26); // next Monday
    await p.grantWeeklyTicket(now);
    expect(p.streakTickets, 1);
    await p.grantWeeklyTicket(now);
    expect(p.streakTickets, 1);
  });

  test('selectCharacter and selectBadge ignore locked choices', () async {
    final p = await _loaded({});
    await p.selectCharacter(GameCharacter.monk, Rank.gold);
    expect(p.selectedCharacter, GameCharacter.pawn);
    await p.selectCharacter(GameCharacter.lancer, Rank.gold);
    expect(p.selectedCharacter, GameCharacter.lancer);

    await p.selectBadge(GameCharacter.lancer, Rank.diamond, Rank.gold);
    expect(p.badgeRank, Rank.starter);
    await p.selectBadge(GameCharacter.lancer, Rank.gold, Rank.gold);
    expect((p.badgeCharacter, p.badgeRank), (GameCharacter.lancer, Rank.gold));

    final reloaded = PlayerState();
    await reloaded.load();
    expect(reloaded.selectedCharacter, GameCharacter.lancer);
    expect((reloaded.badgeCharacter, reloaded.badgeRank), (GameCharacter.lancer, Rank.gold));
  });
}
