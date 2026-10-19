import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_dart/features/overlay/blocker_overlay_widget.dart';

void main() {
  testWidgets('overlay shows live HP and escrow from shared data', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final updates = StreamController<dynamic>();
    addTearDown(updates.close);
    await tester.pumpWidget(MaterialApp(home: BlockerOverlayWidget(updates: updates.stream)));

    updates.add({'app': 'YouTube', 'hp': 75, 'coins': 30, 'defeated': false});
    await tester.pump();
    expect(find.text('YouTube'), findsOneWidget);
    expect(find.text('HP 75/100'), findsOneWidget);
    expect(find.text('Quỹ trận: 30 coin'), findsOneWidget);
    expect(find.text('QUAY LẠI TRẬN'), findsOneWidget);

    updates.add({'app': 'YouTube', 'hp': 0, 'coins': 0, 'defeated': true});
    await tester.pump();
    expect(find.textContaining('Thất bại'), findsOneWidget);
  });
}
