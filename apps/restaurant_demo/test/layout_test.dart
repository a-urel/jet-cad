// Ported from the old apps/restaurant_demo/test/demo_test.dart (the
// restaurant-kit test audit, section 4, docs/superpowers/specs/
// 2026-10-16-restaurant-kit-test-audit.md): the service layout kept across
// Design and back (D3, D16), Save and Revert in memory (D4, D6, D10), the
// numbering warnings (D7), Reset layout and Fit (D9), the dark theme (the
// Dark theme row) and the decimal separator of a new plan (DQ1, DQ2). New:
// LAY-groups (the groups ride the record: the restored line names the
// groups it put back and dropped) and LAY-reset (Reset layout also splits
// the groups, spec decision 14, and their statuses go with them).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart'
    show DecimalSeparator, PageComponent, Transform2;
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ViewportTransform;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:restaurant_demo/main.dart';

import 'support/demo_rig.dart';

const String salonTables =
    '1 (4), 2 (4), 3 (4), 4 (6), 5 (6), 6 (4), 7 (4), 8 (1), 9 (1), 10 (1), '
    '11 (1)';

/// Unit [label]'s placement as six numbers.
List<double> placeOf(PlanController c, String label) {
  final t = placementOf(c, label);
  return [t.a, t.b, t.c, t.d, t.e, t.f];
}

DecimalSeparator separatorOf(PlanController c) => c.document.components
    .get<PageComponent>(c.document.rootHandle)!
    .decimalSeparator;

void main() {
  testWidgets(
      'D3 the service layout is kept across Design and back, and only '
      'Reset layout drops it (spec 14d S9, M-14d-r)', (tester) async {
    final demo = await pumpDemo(tester);
    final c = demo.area.controller;
    final home = placeOf(c, '1');
    await enterService(tester);
    serviceMove(c, '1');
    expect(c.serviceEdited, isTrue);
    await tester.pump();
    final moved = placeOf(c, '1');
    expect(moved, isNot(home), reason: 'premise: moved');

    await tester.tap(byKey('mode-design'));
    await settle(tester);
    expect(c.mode.value, PlanMode.design, reason: 'no question asked');
    expect(c.dirty.value, isFalse, reason: 'the design never moved');
    expect(placeOf(c, '1'), home);

    await enterService(tester);
    expect(placeOf(c, '1'), moved, reason: 'the kept layout is back');
    expect(demo.log.first, 'Salon: layout restored, 1 moved, 0 dropped');

    await press(tester, 'reset-layout');
    expect(placeOf(c, '1'), home);
    await tester.tap(byKey('mode-design'));
    await tester.pump();
    await enterService(tester);
    expect(placeOf(c, '1'), home, reason: 'Reset layout dropped it');
    expect(demo.log.first, isNot(startsWith('Salon: layout restored')),
        reason: 'an empty record restores nothing, and logs nothing');
  });

  testWidgets('D4 Save stores the plan in memory; Revert reloads it',
      (tester) async {
    final demo = await pumpDemo(tester);
    final c = demo.area.controller;
    expect(c.setUnitLabel('2', '12'), isTrue);
    await settle(tester);
    expect(c.dirty.value, isTrue);

    await press(tester, 'save');
    expect(c.dirty.value, isFalse);
    expect(demo.area.stored, c.save(), reason: 'the plan, byte for byte');
    expect(demo.area.stored, contains('"12"'));
    expect(demo.log.first, startsWith('Salon: stored '));

    expect(c.setUnitLabel('12', '13'), isTrue);
    await settle(tester);
    await press(tester, 'revert');
    expect(tablesText(tester), salonTables.replaceFirst('2 (4)', '12 (4)'));
    expect(c.dirty.value, isFalse);
  });

  testWidgets(
      'D6 the tables follow every edit, not only the first (review F-1); '
      'Save is disabled while clean', (tester) async {
    final demo = await pumpDemo(tester);
    final c = demo.area.controller;
    expect(tester.widget<FilledButton>(byKey('save')).onPressed, isNull);
    expect(c.setUnitLabel('2', '12'), isTrue);
    await settle(tester);
    expect(tablesText(tester), salonTables.replaceFirst('2 (4)', '12 (4)'));
    expect(c.setUnitLabel('12', '13'), isTrue);
    await settle(tester);
    expect(tablesText(tester), salonTables.replaceFirst('2 (4)', '13 (4)'));
    expect(tester.widget<FilledButton>(byKey('save')).onPressed, isNotNull);
    expect(demo.log, contains('Salon: edited'));
  });

  testWidgets('D7 every numbering warning has its line', (tester) async {
    final demo = await pumpDemo(tester);
    final c = demo.area.controller;
    // 2 renumbered 1 (two 1s) and the stool 11 stripped of its number.
    relabel(c, {'2': '1', '11': ''});
    await settle(tester);
    expect(c.labelWarnings, hasLength(2), reason: 'premise');
    expect(
        textOf(tester, 'numbering-warning-0'), 'Number 1 is used by 2 tables');
    expect(textOf(tester, 'numbering-warning-1'),
        'A table with 1 seat has no number');
    expect(demo.area.name, 'Salon');
  });

  testWidgets(
      'D9 Reset layout shows in the service only and undoes its moves; Fit '
      'refits', (tester) async {
    final demo = await pumpDemo(tester);
    final c = demo.area.controller;
    expect(byKey('reset-layout'), findsNothing);
    await enterService(tester);
    expect(byKey('reset-layout'), findsOneWidget);
    serviceMove(c, '1');
    expect(c.serviceEdited, isTrue);
    await press(tester, 'reset-layout');
    expect(c.serviceEdited, isFalse);

    await press(tester, 'fit');
    final fitted = c.camera.value.worldToScreenMatrix.a;
    c.camera.value = ViewportTransform(
        worldToScreenMatrix: Transform2(0.07, 0, 0, -0.07, -310, 2400));
    await press(tester, 'fit');
    expect(c.camera.value.worldToScreenMatrix.a, fitted);
  });

  testWidgets(
      'D10 Revert with nothing stored empties the area; Teras keeps its own '
      'service layout', (tester) async {
    final demo = await pumpDemo(tester);
    await press(tester, 'area-1');
    final teras = demo.area.controller;
    expect(demo.area.name, 'Teras');
    final home = placeOf(teras, '2');
    await enterService(tester);
    serviceMove(teras, '2');
    await tester.pump();
    final moved = placeOf(teras, '2');
    await tester.tap(byKey('mode-design'));
    await settle(tester);
    expect(teras.mode.value, PlanMode.design);
    expect(demo.area.layout, isNotNull);
    expect(demo.areas.first.layout, isNull, reason: 'the Salon moved none');
    expect(demo.areas.first.controller.mode.value, PlanMode.design);

    await press(tester, 'area-0');
    expect(demo.area.stored, isNull, reason: 'premise: nothing stored');
    expect(tablesText(tester), salonTables, reason: 'premise: a plan');
    await press(tester, 'revert');
    expect(tablesText(tester), 'none');

    await press(tester, 'area-1');
    expect(tablesText(tester), '1 (4), 2 (4), 3 (4), 4 (4), 5 (2), 6 (2)',
        reason: 'the Salon\'s Revert left the Teras alone');
    await enterService(tester);
    expect(placeOf(teras, '2'), moved, reason: 'the Teras\'s own layout');
    expect(placeOf(teras, '2'), isNot(home));
  });

  testWidgets(
      'Dark theme (spec D9, review 6 finding 1): under a dark platform the '
      'demo is dark and its own UI paints without an exception: the areas, '
      'the service with statuses, back to design with the layout kept (spec '
      '14d S9: no discard dialog)', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final demo = await pumpDemo(tester, random: math.Random(7));
    void dark(String step) {
      expect(tester.takeException(), isNull, reason: step);
      expect(Theme.of(tester.element(find.byType(DemoHome))).brightness,
          Brightness.dark,
          reason: step);
    }

    dark('start');
    await press(tester, 'area-1');
    dark('Teras');
    await enterService(tester);
    await pressInPanel(tester, 'status-random');
    dark('service with statuses');
    serviceMove(demo.area.controller, '2');
    await tester.pump();
    await tester.tap(byKey('mode-design'));
    await settle(tester);
    expect(byKey('discard-dialog'), findsNothing, reason: 'spec 14d S9');
    expect(demo.area.controller.mode.value, PlanMode.design);
    expect(demo.area.layout, isNotNull, reason: 'the layout is kept');
    dark('back to design');
  });

  testWidgets(
      'D16 a Revert in the service, and the mode switches, keep the stored '
      'layout (spec 14d S4, M-14d-r)', (tester) async {
    final demo = await pumpDemo(tester);
    final c = demo.area.controller;
    demo.area.stored = c.save();
    await enterService(tester);
    serviceMove(c, '1');
    await tester.pump();
    final layout = demo.area.layout;
    expect(layout, isNotNull);
    final moved = placeOf(c, '1');
    await press(tester, 'revert');
    expect(c.serviceEdited, isTrue, reason: 'restored after the load');
    expect(demo.area.layout, layout);
    expect(placeOf(c, '1'), moved);
    expect(demo.log.first, 'Salon: layout restored, 1 moved, 0 dropped');
  });

  testWidgets('D19b the German "Reset layout" button (D19 ported without it)',
      (tester) async {
    await pumpDemo(tester);
    await tester.tap(byKey('lang-de'));
    await settle(tester);
    await enterService(tester);
    expect(find.text('Anordnung zurücksetzen'), findsOneWidget);
  });

  testWidgets(
      'DQ1 in German: the shown area\'s plan prints comma, clean, with no '
      'undo step and no dirty line; Teras too once shown', (tester) async {
    final demo = await pumpDemo(tester, locale: const Locale('de'));
    expect(demo.area.name, 'Salon');
    expect(find.text('Entwurf'), findsOneWidget, reason: 'premise: German');
    final c = demo.area.controller;
    expect(demo.area.stored, isNull, reason: 'premise: nothing saved');
    expect(separatorOf(c), DecimalSeparator.comma);
    expect(c.dirty.value, isFalse);
    expect(c.canUndo.value, isFalse);
    expect(c.document.commands.undoDepth, 0);
    expect(demo.log.where((l) => l.startsWith('Salon:')), isEmpty,
        reason: 'no dirty line, no layout line');
    expect(tester.widget<FilledButton>(byKey('save')).onPressed, isNull,
        reason: 'nothing to save');

    await press(tester, 'area-1');
    expect(demo.area.name, 'Teras');
    expect(separatorOf(demo.area.controller), DecimalSeparator.comma);
    expect(demo.area.controller.dirty.value, isFalse);
  });

  testWidgets(
      'DQ2 Revert after a switch to German: an area with nothing stored gets '
      'a comma plan; one with a stored point plan reloads it as point (N2)',
      (tester) async {
    final demo = await pumpDemo(tester);
    expect(demo.area.name, 'Salon');
    expect(separatorOf(demo.area.controller), DecimalSeparator.point,
        reason: 'premise: settled in English');
    // The Teras, saved before it is shown: a point plan stored.
    final teras = demo.areas[1];
    teras.stored = teras.controller.save();
    await tester.tap(byKey('lang-de'));
    await settle(tester);
    expect(find.text('Entwurf'), findsOneWidget, reason: 'premise: German');
    expect(separatorOf(demo.area.controller), DecimalSeparator.point,
        reason: 'a settled plan is not converted (N2)');

    expect(demo.area.stored, isNull, reason: 'premise: nothing stored');
    await press(tester, 'revert');
    expect(separatorOf(demo.area.controller), DecimalSeparator.comma);
    expect(demo.area.controller.dirty.value, isFalse);
    expect(demo.area.controller.canUndo.value, isFalse);

    await press(tester, 'area-1');
    expect(demo.area.name, 'Teras');
    await press(tester, 'revert');
    expect(tablesText(tester), '1 (4), 2 (4), 3 (4), 4 (4), 5 (2), 6 (2)',
        reason: 'premise: reloaded');
    expect(separatorOf(demo.area.controller), DecimalSeparator.point);
  });

  testWidgets(
      'LAY-groups the groups ride the layout record: back in the service the '
      'line names the groups put back and the groups dropped, and a dropped '
      'group\'s status goes with it', (tester) async {
    final demo = await pumpDemo(tester);
    final c = demo.area.controller;
    await enterService(tester);
    c.setUnitGroups({
      'G1': UnitGroup(members: {'1', '2'}),
      'G2': UnitGroup(members: {'4', '5'}),
    });
    c.select({'4'});
    await pressInPanel(tester, 'status-bill');
    expect(c.groupStatuses.value.keys, ['G2'], reason: 'premise');
    expect(demo.area.groupStatusNames, {'G2': 'Bill'});
    expect(demo.area.layout, contains('G1'));
    await tester.tap(byKey('mode-design'));
    await settle(tester);

    // In the design table 5 is renumbered: G2 no longer matches the plan.
    expect(c.setUnitLabel('5', '15'), isTrue);
    await enterService(tester);
    expect(c.unitGroups.value.keys, ['G1'], reason: 'G2 is dropped whole');
    expect(
        demo.log.first,
        'Salon: layout restored, 0 moved, 0 dropped; groups G1 applied; '
        'groups G2 dropped');
    expect(demo.area.groupStatusNames, isEmpty,
        reason: 'the status goes with its group');
    expect(c.groupStatuses.value, isEmpty);

    // Nothing but a group: still one line; with a move too, the move's
    // numbers first.
    serviceMove(c, '3');
    await tester.tap(byKey('mode-design'));
    await settle(tester);
    await enterService(tester);
    expect(demo.log.first,
        'Salon: layout restored, 1 moved, 0 dropped; groups G1 applied');
  });

  testWidgets(
      'LAY-reset Reset layout also splits the groups (decision 14), and a '
      'split group\'s status goes with it', (tester) async {
    final demo = await pumpDemo(tester);
    final c = demo.area.controller;
    await enterService(tester);
    c.setUnitGroups({
      'G1': UnitGroup(members: {'1', '2'})
    });
    c.select({'1'});
    await pressInPanel(tester, 'status-eating');
    serviceMove(c, '3');
    expect(demo.area.groupStatusNames, {'G1': 'Eating'}, reason: 'premise');
    expect(c.serviceEdited, isTrue);

    await pressInPanel(tester, 'reset-layout');
    expect(c.unitGroups.value, isEmpty);
    expect(demo.area.groupStatusNames, isEmpty);
    expect(c.groupStatuses.value, isEmpty);
    expect(c.serviceEdited, isFalse);
    expect(demo.area.layout, isNot(contains('G1')),
        reason: 'the kept record is the empty one');
    await tester.tap(byKey('mode-design'));
    await settle(tester);
    await enterService(tester);
    expect(c.unitGroups.value, isEmpty, reason: 'nothing comes back');
  });
}
