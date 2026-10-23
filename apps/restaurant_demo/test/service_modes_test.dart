// Ported from the old apps/restaurant_demo/test/demo_test.dart (the
// restaurant-kit test audit, section 4, docs/superpowers/specs/
// 2026-10-16-restaurant-kit-test-audit.md): the Design / Service toggle,
// selection by number, the service options (Moves, Long press, Floor drag)
// and the language. D1, D2, D5, D11, D18, D19 (without its German "Reset
// layout" line, Task 8's button), D22, D23. The old plans are the Salon and
// the Teras samples now; a table is a unit labelled with its number.
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import 'support/demo_rig.dart';

String tablesText(WidgetTester tester) =>
    tester.widget<Text>(byKey('tables')).data!;

void main() {
  testWidgets('D1 the toggle switches the view; the log has the mode',
      (tester) async {
    final demo = await pumpDemo(tester);
    expect(demo.areas.map((a) => a.name), ['Salon', 'Teras']);
    expect(tablesText(tester), startsWith('1 (4), 2 (4), 3 (4), 4 (6)'));
    expect(byKey('toolbar-print'), findsOneWidget, reason: 'the editor');
    expect(byKey('service-bar'), findsNothing);

    await enterService(tester);
    expect(byKey('service-bar'), findsOneWidget);
    expect(demo.area.controller.mode.value, PlanMode.service);
    expect(demo.log.first, 'Salon: mode Service');

    await tester.tap(byKey('mode-design'));
    await tester.pump();
    await tester.pump();
    expect(byKey('service-bar'), findsNothing);
    expect(demo.area.controller.mode.value, PlanMode.design);
    expect(demo.log.first, 'Salon: mode Design');
  });

  testWidgets('D2 selection by number: the numbers that exist are selected',
      (tester) async {
    final demo = await pumpDemo(tester);
    await tester.enterText(byKey('select-number'), '2, 99');
    await tester.tap(byKey('select'));
    await tester.pump();
    expect(demo.area.controller.selectedUnits.value, {'2'});
    expect(demo.log.first, 'Salon: selected {2}');
    await tester.pump();
    expect(byKey('unit-section'), findsOneWidget,
        reason: 'the editor shows the selected table');
  });

  testWidgets('D5 each area keeps its own plan and mode', (tester) async {
    final demo = await pumpDemo(tester);
    final salon = tablesText(tester);
    await enterService(tester);
    await tester.tap(byKey('area-1'));
    await tester.pump();
    await tester.pump();
    expect(demo.area.name, 'Teras');
    expect(tablesText(tester), '1 (4), 2 (4), 3 (4), 4 (4), 5 (2), 6 (2)');
    expect(tablesText(tester), isNot(salon));
    expect(byKey('service-bar'), findsNothing, reason: 'Teras designs');
    await tester.tap(byKey('area-0'));
    await tester.pump();
    await tester.pump();
    expect(byKey('service-bar'), findsOneWidget);
    expect(tablesText(tester), salon);
  });

  testWidgets('D11 two numbers, padded, by Enter: both selected, logged sorted',
      (tester) async {
    final demo = await pumpDemo(tester);
    await tester.enterText(byKey('select-number'), ' 9,2 ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(demo.area.controller.selectedUnits.value, {'2', '9'});
    expect(demo.log.first, 'Salon: selected {2, 9}');
  });

  testWidgets(
      'D18 with Moves off a drag from a table pans and changes no layout; '
      'with Moves on the same drag moves it', (tester) async {
    final demo = await pumpDemo(tester);
    final c = demo.area.controller;
    await enterService(tester);
    await tester.tap(byKey('moves'));
    await tester.pump();
    expect(demo.moves, isFalse);
    expect(c.permissions.serviceMove, isFalse);
    final before = placementOf(c, '1');
    Future<void> drag() async {
      final g = await tester.startGesture(unitScreen(c, '1'),
          kind: PointerDeviceKind.mouse);
      await g.moveBy(const Offset(40, 0));
      await g.moveBy(const Offset(40, 0));
      await g.up();
      await tester.pump();
    }

    await drag();
    expect(c.serviceEdited, isFalse);
    expect(placementOf(c, '1'), before);
    expect(demo.log, isNot(contains('Salon: layout changed')));

    await tester.tap(byKey('moves'));
    await tester.pump();
    expect(c.permissions.serviceMove, isTrue);
    await drag();
    expect(c.serviceEdited, isTrue, reason: 'the control: moves on moves');
    expect(placementOf(c, '1').e, isNot(before.e));
    expect(demo.log, contains('Salon: layout changed'));
  });

  testWidgets(
      'D19 the language switch: the demo, the planner and a status caption '
      'speak Turkish, then German', (tester) async {
    final demo = await pumpDemo(tester);
    final c = demo.area.controller;
    await switchLanguage(tester, 'tr');
    expect(find.text('Restoran demosu'), findsOneWidget);
    expect(find.text('Tasarım'), findsOneWidget);
    expect(find.text('Duvar'), findsOneWidget, reason: 'the planner too');
    await enterService(tester);
    expect(demo.log, contains('Salon: mod Servis'));
    c.select({'2'});
    await tester.pump();
    await tester.tap(byKey('status-bill'));
    await tester.pump();
    expect(c.unitStatuses.value['2']!.caption, 'Hesap');
    expect(find.text('Hesap'), findsWidgets, reason: 'the button');

    await switchLanguage(tester, 'de');
    expect(find.text('Entwurf'), findsOneWidget);
  });

  testWidgets(
      'D22 with Long press: menu on, a finger\'s long press opens the '
      'table\'s menu and toggles nothing', (tester) async {
    final demo = await pumpDemo(tester);
    final c = demo.area.controller;
    await enterService(tester);
    await tester.tap(byKey('long-press-menu'));
    await tester.pump();
    expect(demo.longPressMenu, isTrue);
    c.select({'2'});
    await tester.pump();
    final g = await tester.startGesture(unitScreen(c, '1'),
        kind: PointerDeviceKind.touch);
    await tester.pump(const Duration(milliseconds: 700));
    await g.up();
    await tester.pumpAndSettle();
    expect(find.text('Table 1'), findsOneWidget);
    expect(c.selectedUnits.value, {'1'},
        reason: 'an unselected table is selected alone, never toggled in');
    expect(demo.log, contains('Salon: menu for 1'));
  });

  testWidgets(
      'D23 the Floor drag: select switch flips the editor\'s floorDrag from '
      'pan to band and back', (tester) async {
    final demo = await pumpDemo(tester);
    await enterService(tester);
    PlanFloorDrag current() =>
        tester.widget<PlanEditor>(find.byType(PlanEditor)).floorDrag;
    expect(demo.floorBand, isFalse);
    expect(current(), PlanFloorDrag.pan);
    await tester.tap(byKey('floor-band'));
    await tester.pump();
    expect(demo.floorBand, isTrue);
    expect(current(), PlanFloorDrag.band);
    await tester.tap(byKey('floor-band'));
    await tester.pump();
    expect(current(), PlanFloorDrag.pan);
  });
}
