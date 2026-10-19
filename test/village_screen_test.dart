import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_dart/core/game/player_state.dart';
import 'package:test_dart/core/game/progression.dart';
import 'package:test_dart/core/game/village.dart';
import 'package:test_dart/core/widgets/cover_rect.dart';
import 'package:test_dart/features/village/village_screen.dart';

void main() {
  late PlayerState player;

  Future<void> pumpVillage(WidgetTester tester, {required Map<String, Object> prefs, Rank rank = Rank.starter}) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(prefs);
    await tester.runAsync(() async {
      player = PlayerState();
      await player.load();
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: VillageScreen(player: player, totalFocusSeconds: rank.thresholdHours * 3600)),
    ));
    await tester.pump();
  }

  Future<void> openSlot(WidgetTester tester, String building) async {
    await tester.tap(find.byKey(Key('slot-$building')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('cannot build without funds', (tester) async {
    await pumpVillage(tester, prefs: {});
    await openSlot(tester, 'tower');
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Xây'));
    expect(button.onPressed, isNull);
  });

  testWidgets('building spends and shows level', (tester) async {
    await pumpVillage(tester, prefs: {'fk_gold': 500, 'fk_logs': 100});
    await openSlot(tester, 'tower');
    await tester.tap(find.widgetWithText(FilledButton, 'Xây'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Tháp canh Lv1'), findsOneWidget);
    expect(player.coins, 300);
  });

  testWidgets('character houses show their lock rank', (tester) async {
    await pumpVillage(tester, prefs: {}, rank: Rank.gold);
    expect(find.text('🔒 Diamond'), findsOneWidget);
  });

  testWidgets('double tap on build spends once', (tester) async {
    await pumpVillage(tester, prefs: {'fk_gold': 1000, 'fk_logs': 1000});
    await openSlot(tester, 'tower');
    final build = find.widgetWithText(FilledButton, 'Xây');
    await tester.tap(build);
    await tester.tap(build, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(player.levelOf(Building.tower), 1);
    expect(player.coins, 800);
  });

  test('coverRect matches BoxFit.cover', () {
    final r = coverRect(const Size(400, 860), VillageScreen.imageSize);
    expect(r.height, closeTo(860, 1e-6));
    expect(r.width, closeTo(1080 * 860 / 1920, 1e-6));
    expect(r.left, closeTo((400 - r.width) / 2, 1e-6));
    expect(r.top, 0);
  });

  test('every slot (sprite + label) stays on screen for tall and short phones', () {
    for (final box in const [Size(400, 889), Size(400, 700), Size(360, 800)]) {
      for (final b in Building.values) {
        final area = VillageScreen.slotArea(b, box);
        expect(area.left, greaterThanOrEqualTo(0), reason: '$b on $box');
        expect(area.right, lessThanOrEqualTo(box.width), reason: '$b on $box');
        expect(area.top, greaterThanOrEqualTo(0), reason: '$b on $box');
      }
    }
  });

  test('slots never overlap each other or the campfire', () {
    for (final box in const [Size(400, 889), Size(400, 700), Size(360, 800)]) {
      final img = coverRect(box, VillageScreen.imageSize);
      final fire = Rect.fromLTRB(img.left + 0.45 * img.width, img.top + 0.43 * img.height,
          img.left + 0.55 * img.width, img.top + 0.49 * img.height);
      for (final a in Building.values) {
        final ra = VillageScreen.slotArea(a, box);
        expect(ra.overlaps(fire), isFalse, reason: '$a covers the campfire on $box');
        for (final b in Building.values.where((b) => b.index > a.index)) {
          expect(ra.overlaps(VillageScreen.slotArea(b, box)), isFalse, reason: '$a overlaps $b on $box');
        }
      }
    }
  });
}
