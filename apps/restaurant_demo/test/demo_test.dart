// Spec 14b-2 H10: the demo host drives the public API end to end -- two
// areas, the mode toggle and its discard question, selection by number,
// save and revert in memory, the log.
// The tests reach a controller's active plan to make edits the 14b-2 UI
// cannot (a service move comes with 14c).
// ignore_for_file: invalid_use_of_internal_member
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_floor_plan/editor.dart';
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart' show FloorPlanMode;
import 'package:jet_cad_restaurant_symbols/jet_cad_restaurant_symbols.dart';
import 'package:restaurant_demo/main.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// A Salon plan: a four-seat table (1, turned) and a six-seat round one
/// (2, mirrored), off the page's centre.
String salonPlan() {
  final doc = newDocument(MetricModelMeasurer());
  final lib = buildSymbolLibrary(restaurantCatalog);
  final entries = SymbolLibrary.decode(Uint8List.fromList(
          utf8.encode(DraftDocumentCodec.encodeToString(lib))))
      .entries;
  SymbolEntry entry(String key) => entries.firstWhere((e) => e.key == key);
  doc.commands.execute(placeSymbol(doc, entry('restaurant.table.rect.four'),
      at: Vector2(-1800, 2400), quarterTurns: 1));
  doc.commands.execute(placeSymbol(doc, entry('restaurant.table.round.six'),
      at: Vector2(2600, 900), mirrored: true));
  return DraftDocumentCodec.encodeToString(doc);
}

Finder byKey(String k) => find.byKey(Key(k));

Future<DemoHomeState> pumpDemo(WidgetTester tester,
    {Map<String, String> plans = const {}}) async {
  await tester.binding.setSurfaceSize(const Size(1600, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(RestaurantDemo(plans: plans));
  await tester.pump();
  await tester.pump();
  return tester.state<DemoHomeState>(find.byType(DemoHome));
}

String tablesText(WidgetTester tester) =>
    tester.widget<Text>(byKey('tables')).data!;

void main() {
  testWidgets('D1 two empty areas; the toggle switches the view',
      (tester) async {
    final demo = await pumpDemo(tester);
    expect(demo.areas.map((a) => a.name), ['Salon', 'Teras']);
    expect(tablesText(tester), 'none');
    expect(byKey('toolbar-print'), findsOneWidget, reason: 'the editor');

    await tester.tap(byKey('mode-service'));
    await tester.pump();
    await tester.pump();
    expect(byKey('service-bar'), findsOneWidget);
    expect(demo.log.first, 'Salon: mode selection');

    await tester.tap(byKey('mode-design'));
    await tester.pump();
    await tester.pump();
    expect(byKey('service-bar'), findsNothing);
    expect(demo.log.first, 'Salon: mode design');
  });

  testWidgets('D2 a seeded plan\'s tables; selection by number',
      (tester) async {
    final demo = await pumpDemo(tester, plans: {'Salon': salonPlan()});
    expect(tablesText(tester), '1 (4), 2 (6)');
    await tester.enterText(byKey('select-number'), '2, 9');
    await tester.tap(byKey('select'));
    await tester.pump();
    expect(demo.area.controller.selectedTables.value, {'2'});
    expect(demo.log.first, 'Salon: selected {2}');
    expect(byKey('table-section'), findsOneWidget,
        reason: 'the editor shows the selected table');
  });

  testWidgets(
      'D3 leaving a service with edits asks first; Cancel keeps it, '
      'Discard drops it', (tester) async {
    final demo = await pumpDemo(tester, plans: {'Salon': salonPlan()});
    final c = demo.area.controller;
    await tester.tap(byKey('mode-service'));
    await tester.pump();
    await tester.pump();
    final doc = c.activeDocument;
    final node = doc.tree[TableSurvey.of(doc).withNumber('1').single.instance]!
        as InstanceNode;
    doc.commands.execute(CompoundCommand([
      TransformNodeCommand(node.handle,
          Transform2.translation(400, -300).multiply(node.transform))
    ], label: 'Move'));
    expect(c.serviceEdited, isTrue);

    await tester.tap(byKey('mode-design'));
    await tester.pump();
    expect(byKey('discard-dialog'), findsOneWidget);
    await tester.tap(byKey('discard-cancel'));
    await tester.pump();
    expect(c.mode.value, FloorPlanMode.selection);

    await tester.tap(byKey('mode-design'));
    await tester.pump();
    await tester.tap(byKey('discard-ok'));
    await tester.pump();
    await tester.pump();
    expect(c.mode.value, FloorPlanMode.design);
    expect(c.dirty.value, isFalse, reason: 'the design never moved');
  });

  testWidgets('D4 Save stores the plan in memory; Revert reloads it',
      (tester) async {
    final demo = await pumpDemo(tester, plans: {'Salon': salonPlan()});
    final c = demo.area.controller;
    final doc = c.activeDocument;
    final label = TableSurvey.of(doc).withNumber('2').single.label!;
    doc.commands.execute(SetEntityTextCommand(label, '12', kTableLabelTag));
    await tester.pump();
    expect(c.dirty.value, isTrue);
    await tester.pump();

    await tester.tap(byKey('save'));
    await tester.pump();
    expect(c.dirty.value, isFalse);
    expect(demo.area.stored!.contains('"12"'), isTrue);

    doc.commands.execute(SetEntityTextCommand(label, '13', kTableLabelTag));
    await tester.pump();
    await tester.tap(byKey('revert'));
    await tester.pump();
    await tester.pump();
    expect(tablesText(tester), '1 (4), 12 (6)');
  });

  testWidgets('D5 each area keeps its own plan and mode', (tester) async {
    final demo = await pumpDemo(tester, plans: {'Salon': salonPlan()});
    await tester.tap(byKey('mode-service'));
    await tester.pump();
    await tester.pump();
    await tester.tap(byKey('area-1'));
    await tester.pump();
    await tester.pump();
    expect(demo.area.name, 'Teras');
    expect(tablesText(tester), 'none');
    expect(byKey('service-bar'), findsNothing, reason: 'Teras designs');
    await tester.tap(byKey('area-0'));
    await tester.pump();
    await tester.pump();
    expect(byKey('service-bar'), findsOneWidget);
    expect(tablesText(tester), '1 (4), 2 (6)');
  });
}
