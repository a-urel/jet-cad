// New (Task 7; host_chrome_test's DH1, DH2 and DH7 follow in Task 8 and may
// find these already covering their editor-profile, POS-id and find
// halves): the editor's three profiles as `PlanPermissions` composed with
// the Moves switch, the Tables profile's editor (no wall tool, no Layers or
// Page, the gallery's units only) with the POS id written as host data, the
// read-only profile, and the find field.
import 'package:flutter/material.dart' show ListTile;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import 'support/demo_rig.dart';

Future<void> profile(WidgetTester tester, String key) =>
    pressInPanel(tester, key);

void main() {
  testWidgets(
      'PF1 each profile is one PlanPermissions value, composed with the '
      'Moves switch, on both areas; read only keeps the service flags',
      (tester) async {
    final demo = await pumpDemo(tester);
    final salon = demo.areas[0].controller, teras = demo.areas[1].controller;
    expect(salon.permissions, PlanPermissions.full);

    await profile(tester, 'editor-tables');
    for (final c in [salon, teras]) {
      expect(c.permissions, PlanPermissions.unitsOnly);
    }
    await profile(tester, 'editor-read-only');
    for (final c in [salon, teras]) {
      expect(c.permissions, PlanPermissions.readOnly);
      expect(c.permissions.serviceMove, isTrue,
          reason: 'a plan only looked at can still be arranged in service');
    }
    await enterService(tester);
    await pressInPanel(tester, 'moves');
    for (final c in [salon, teras]) {
      expect(
          c.permissions, PlanPermissions.readOnly.copyWith(serviceMove: false));
    }
    await pressInPanel(tester, 'moves');
    await tester.tap(byKey('mode-design'));
    await tester.pump();
    await profile(tester, 'editor-full');
    expect(salon.permissions, PlanPermissions.full);
  });

  /// The gallery's cells for [query] typed in its search box.
  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(byKey('symbol-search'), query);
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
      'PF2 Tables: no wall tool, no Layers or Page, the gallery shows units '
      'only; Full shows them all', (tester) async {
    final demo = await pumpDemo(tester);
    await tester.runAsync(() async {
      while (demo.area.controller.symbolsState.value != SymbolsState.ready) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    bool wallEnabled() =>
        tester.widget<ListTile>(byKey('tool-architecture.wall')).enabled;
    expect(wallEnabled(), isTrue, reason: 'premise: Full draws walls');
    expect(byKey('layers-panel'), findsOneWidget);
    expect(byKey('page-preset'), findsOneWidget);
    await tester.tap(byKey('tab-symbols'));
    await tester.pump();
    await search(tester, 'planter');
    expect(byKey('symbol-cell-restaurant.planter.round@1'), findsOneWidget,
        reason: 'premise: Full offers a symbol that is no unit');

    await profile(tester, 'editor-tables');
    await tester.tap(byKey('tab-tools'));
    await tester.pump();
    expect(byKey('tool-plan.select'), findsOneWidget);
    expect(wallEnabled(), isFalse, reason: 'Tables cannot draw a wall');
    expect(byKey('layers-panel'), findsNothing);
    expect(byKey('page-preset'), findsNothing);
    await tester.tap(byKey('tab-symbols'));
    await tester.pump();
    await search(tester, 'planter');
    expect(byKey('symbol-cell-restaurant.planter.round@1'), findsNothing,
        reason: 'the gallery filters out what is no unit');
    await search(tester, 'rect');
    expect(byKey('symbol-cell-restaurant.table.rect.four@1'), findsOneWidget,
        reason: 'and keeps the units');
  });

  testWidgets(
      'PF3 Tables: the inspector writes the POS id as host data, its other '
      'data kept; an empty id unlinks; Full shows no inspector',
      (tester) async {
    final demo = await pumpDemo(tester);
    final c = demo.area.controller;
    c.select({'1'});
    await tester.pump();
    await tester.pump();
    expect(byKey('pos-id'), findsNothing, reason: 'Full has no inspector');

    await profile(tester, 'editor-tables');
    expect(byKey('pos-id'), findsOneWidget);
    expect(c.setUnitData('1', {'zone': 'terrace'}), isTrue);
    await tester.pump();
    // Decided: the inspector is a combo over the demo's records now (D14),
    // not a text field: a record is picked, and the empty entry unlinks.
    await pickRecord(tester, 'T-01');
    await tester.pump();
    Map<String, String> dataOf(String l) =>
        c.unitDetails.singleWhere((d) => d.unit.label == l).data;
    expect(dataOf('1'), {'id': 'T-01', 'zone': 'terrace'});
    expect(dataOf('2'), isEmpty, reason: 'only the selected table');
    expect(demo.log.first, 'Salon: table 1 is T-01');

    await pickRecord(tester, '');
    await tester.pump();
    expect(dataOf('1'), {'zone': 'terrace'});
  });

  testWidgets(
      'PF4 Read only moves and deletes nothing in the design; its bar shows '
      'Print, Export and the zoom', (tester) async {
    final demo = await pumpDemo(tester);
    final c = demo.area.controller;
    expect(byKey('toolbar-undo'), findsOneWidget, reason: 'premise: Full');
    await profile(tester, 'editor-read-only');
    expect(byKey('toolbar-print'), findsOneWidget);
    expect(byKey('zoom-text'), findsOneWidget);
    expect(
        tester.widget<PlanEditor>(find.byType(PlanEditor)).bar.actions,
        [
          PlanEditorAction.print,
          PlanEditorAction.export,
          PlanEditorAction.zoom
        ],
        reason: 'Export shows once the host takes the bytes (Task 8)');
    expect(byKey('toolbar-undo'), findsNothing);
    expect(byKey('toolbar-snap'), findsNothing);
    c.select({'1'});
    await tester.pump();
    expect(c.deleteSelection(), isFalse);
    expect(c.units.length, 11);
    await profile(tester, 'editor-full');
    expect(c.deleteSelection(), isTrue, reason: 'the control: Full deletes');
    expect(c.units.length, 10);
  });

  testWidgets(
      'FIND Enter in the find field selects the table and centres the view '
      'on it, its zoom kept; an unknown number is logged and changes nothing',
      (tester) async {
    final demo = await pumpDemo(tester);
    final c = demo.area.controller;
    final scale = c.cameraValue.value.scale;
    Offset centre(String n) => c.worldToGlobal(
        c.unitDetails.singleWhere((d) => d.unit.label == n).center!)!;
    final middle = c.canvasRect.value!.center;
    expect((centre('7') - middle).distance, greaterThan(50),
        reason: 'premise: 7 is off the middle');

    await tester.enterText(byKey('find-table'), ' 7 ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump();
    expect(c.selectedUnits.value, {'7'});
    expect((centre('7') - middle).distance, lessThan(1));
    expect(c.cameraValue.value.scale, scale);
    expect(demo.log.first, 'Salon: table 7 found');

    await tester.enterText(byKey('find-table'), '99');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(c.selectedUnits.value, {'7'});
    expect(demo.log.first, 'Salon: no table 99');
  });
}
