// New (restaurant-kit plan, Review Focus 3): two areas, two controllers. An
// action in the Salon (a status, a selection, an undo) never reaches the
// Teras, and the other way round. The Teras starts with an edit of its own
// on its undo stack, a status and a selection, so a leak in either
// direction shows.
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import 'support/demo_rig.dart';

/// What a controller holds that an action elsewhere must not change, as
/// one comparable text (the plan's text by hash, not printed).
String held(PlanController c) => [
      'plan ${c.save().hashCode}',
      'labels ${[for (final u in c.units) u.label]}',
      'statuses ${c.unitStatuses.value}',
      'selected ${(c.selectedUnits.value.toList()..sort())}',
      'canUndo ${c.canUndo.value}, depth ${c.document.commands.undoDepth}',
    ].join('\n');

void main() {
  testWidgets(
      'AR-isolated: a status, a selection and an undo in the Salon leave the '
      'Teras unchanged; the Teras\' leave the Salon', (tester) async {
    final demo = await pumpDemo(tester);
    final salon = demo.areas[0].controller, teras = demo.areas[1].controller;
    expect(identical(salon, teras), isFalse);

    // The Teras' own state: a rename (one undo step), a status, a selection.
    expect(teras.setUnitLabel('1', '41'), isTrue);
    teras.setUnitStatus(
        {'2': UnitStatus(color: const Color(0xFF123456), caption: 'Mine')});
    teras.select({'3'});
    final terasBefore = held(teras);
    expect(teras.canUndo.value, isTrue, reason: 'premise: an edit to undo');
    expect(teras.document.commands.undoDepth, 1);

    // In the Salon, through the page: a status on a selection, then an edit
    // and its undo from the editor's bar.
    await tester.enterText(byKey('select-number'), '4, 5');
    await tester.tap(byKey('select'));
    await tester.pump();
    await tester.tap(byKey('status-bill'));
    await tester.pump();
    expect(salon.selectedUnits.value, {'4', '5'});
    expect(salon.unitStatuses.value.keys, unorderedEquals(['4', '5']));
    expect(salon.setUnitLabel('1', '51'), isTrue);
    await tester.pump();
    await tester.pump();
    expect(salon.units.first.label, '51');
    await tester.tap(byKey('toolbar-undo'));
    await tester.pump();
    await tester.pump();
    expect(salon.units.first.label, '1', reason: 'the Salon undid its edit');

    expect(held(teras), terasBefore, reason: 'the Teras is as it was');
    expect(teras.units.first.label, '41', reason: 'its own edit stands');

    // And the other way round.
    final salonBefore = held(salon);
    await tester.tap(byKey('area-1'));
    await tester.pump();
    await tester.pump();
    await tester.enterText(byKey('select-number'), '2');
    await tester.tap(byKey('select'));
    await tester.pump();
    await tester.tap(byKey('status-eating'));
    await tester.pump();
    await tester.tap(byKey('toolbar-undo'));
    await tester.pump();
    await tester.pump();
    expect(teras.units.first.label, '1', reason: 'the Teras undid its edit');
    expect(held(salon), salonBefore, reason: 'the Salon is as it was');
  });
}
