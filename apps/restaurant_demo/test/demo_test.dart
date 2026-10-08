// Spec 14b-2 H10: the demo host drives the public API end to end -- two
// areas, the mode toggle, the service layout kept per area (spec 14d S9),
// selection by number, save and revert in memory, the table menu, the
// service options, the log.
// The tests reach a controller's active plan to make edits the 14b-2 UI
// cannot (a service move comes with 14c).
// ignore_for_file: invalid_use_of_internal_member
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart'
    show PointerDeviceKind, kSecondaryMouseButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_floor_plan/editor.dart';
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart'
    show
        FloorPlanController,
        FloorPlanMode,
        FloorPlanView,
        TableGroup,
        TableStatus;
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer, ViewportTransform;
import 'package:jet_cad_restaurant_symbols/jet_cad_restaurant_symbols.dart';
import 'package:restaurant_demo/main.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// A Salon plan: a four-seat table (1, turned) and a six-seat round one
/// (2, mirrored), off the page's centre.
String salonPlan() => DraftDocumentCodec.encodeToString(salonDocument());

/// [salonPlan]'s document, for fixtures that change it.
DraftDocument salonDocument() {
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
  return doc;
}

/// [salonPlan] with table 2 on a locked layer (review F-1).
String lockedSalonPlan() {
  final doc = salonDocument();
  final zero = doc.tables.layers[ReservedHandles.layerZero]!;
  final locked = doc.handleSeed.next();
  doc.commands.execute(AddLayerCommand(LayerRecord(
      handle: locked,
      name: 'Locked',
      color: const IndexedColor(1),
      linetype: zero.linetype,
      lineweight: zero.lineweight,
      transparency: zero.transparency,
      visible: true,
      locked: false)));
  doc.commands.execute(SetInstanceLayerCommand(
      TableSurvey.of(doc).withNumber('2').single.instance, locked));
  doc.commands.execute(
      SetLayerCommand(doc.tables.layers[locked]!.copyWith(locked: true)));
  return DraftDocumentCodec.encodeToString(doc);
}

Finder byKey(String k) => find.byKey(Key(k));

Future<DemoHomeState> pumpDemo(WidgetTester tester,
    {Map<String, String> plans = const {}, math.Random? random}) async {
  await tester.binding.setSurfaceSize(const Size(1600, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(RestaurantDemo(plans: plans, random: random));
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
    expect(demo.log.first, 'Salon: mode Service');

    await tester.tap(byKey('mode-design'));
    await tester.pump();
    await tester.pump();
    expect(byKey('service-bar'), findsNothing);
    expect(demo.log.first, 'Salon: mode Design');
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
      'D3 the service layout is kept across Design and back, and only '
      'Reset layout drops it (spec 14d S9, M-14d-r)', (tester) async {
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
    await tester.pump();
    List<double> place() {
      final d = c.activeDocument;
      final t = (d.tree[TableSurvey.of(d).withNumber('1').single.instance]!
              as InstanceNode)
          .transform;
      return [t.a, t.b, t.c, t.d, t.e, t.f];
    }

    final moved = place();

    await tester.tap(byKey('mode-design'));
    await tester.pump();
    await tester.pump();
    expect(c.mode.value, FloorPlanMode.design, reason: 'no question asked');
    expect(c.dirty.value, isFalse, reason: 'the design never moved');
    final designed = place();
    expect(designed, isNot(moved));

    await tester.tap(byKey('mode-service'));
    await tester.pump();
    await tester.pump();
    expect(place(), moved, reason: 'the kept layout is back');
    expect(demo.log.first, 'Salon: layout restored, 1 moved, 0 dropped');

    await tester.tap(byKey('reset-layout'));
    await tester.pump();
    await tester.pump();
    expect(place(), designed);
    await tester.tap(byKey('mode-design'));
    await tester.pump();
    await tester.tap(byKey('mode-service'));
    await tester.pump();
    await tester.pump();
    expect(place(), designed, reason: 'Reset layout dropped it');
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

  /// Renames table [from] to [to] in [demo]'s current area.
  void rename(DemoHomeState demo, String from, String to) {
    final doc = demo.area.controller.activeDocument;
    final label = TableSurvey.of(doc).withNumber(from).single.label!;
    doc.commands.execute(SetEntityTextCommand(label, to, kTableLabelTag));
  }

  /// A service move of table [n] in [demo]'s current area.
  void serviceMove(DemoHomeState demo, String n) {
    final doc = demo.area.controller.activeDocument;
    final node = doc.tree[TableSurvey.of(doc).withNumber(n).single.instance]!
        as InstanceNode;
    doc.commands.execute(CompoundCommand([
      TransformNodeCommand(node.handle,
          Transform2.translation(400, -300).multiply(node.transform))
    ], label: 'Move'));
  }

  testWidgets(
      'D6 the tables follow every edit, not only the first (review F-1); '
      'Save is disabled while clean', (tester) async {
    final demo = await pumpDemo(tester, plans: {'Salon': salonPlan()});
    expect(tester.widget<FilledButton>(byKey('save')).onPressed, isNull);
    rename(demo, '2', '12');
    await tester.pump();
    await tester.pump();
    expect(tablesText(tester), '1 (4), 12 (6)');
    rename(demo, '12', '13');
    await tester.pump();
    await tester.pump();
    expect(tablesText(tester), '1 (4), 13 (6)');
    expect(tester.widget<FilledButton>(byKey('save')).onPressed, isNotNull);
    expect(demo.log, contains('Salon: edited'));
  });

  testWidgets('D7 every numbering warning has its line', (tester) async {
    final demo = await pumpDemo(tester, plans: {'Salon': salonPlan()});
    final doc = demo.area.controller.activeDocument;
    final round = SymbolLibrary.decode(Uint8List.fromList(utf8.encode(
            DraftDocumentCodec.encodeToString(
                buildSymbolLibrary(restaurantCatalog)))))
        .entries
        .firstWhere((e) => e.key == 'restaurant.bar.stool');
    doc.commands.execute(
        placeSymbol(doc, round, at: Vector2(500, -2500), numbered: false));
    rename(demo, '2', '1');
    await tester.pump();
    await tester.pump();
    expect(tester.widget<Text>(byKey('numbering-warning-0')).data,
        'Number 1 is used by 2 tables');
    expect(tester.widget<Text>(byKey('numbering-warning-1')).data,
        contains('has no number'));
  });

  testWidgets('D8 an export is logged with its name and size', (tester) async {
    final demo = await pumpDemo(tester, plans: {'Salon': salonPlan()});
    await tester.tap(byKey('toolbar-export'));
    await tester.pump();
    await tester.pump();
    await tester.tap(byKey('export-format-png'));
    await tester.pump();
    await tester.tap(byKey('export-dpi-96'));
    await tester.pump();
    await tester.tap(byKey('export-ok'));
    await tester.pump();
    bool exported() =>
        demo.log.isNotEmpty && demo.log.first.contains('exported');
    for (var i = 0; i < 400 && !exported(); i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(demo.log.first, startsWith('Salon: exported salon.png, '));
    expect(demo.log.first, endsWith(' bytes'));
  });

  testWidgets(
      'D9 Reset layout shows in the service only and undoes its moves; Fit '
      'refits', (tester) async {
    final demo = await pumpDemo(tester, plans: {'Salon': salonPlan()});
    final c = demo.area.controller;
    expect(byKey('reset-layout'), findsNothing);
    await tester.tap(byKey('mode-service'));
    await tester.pump();
    await tester.pump();
    expect(byKey('reset-layout'), findsOneWidget);
    serviceMove(demo, '1');
    expect(c.serviceEdited, isTrue);
    await tester.tap(byKey('reset-layout'));
    await tester.pump();
    await tester.pump();
    expect(c.serviceEdited, isFalse);

    await tester.tap(byKey('fit'));
    await tester.pump();
    await tester.pump();
    final fitted = c.camera.value.worldToScreenMatrix.a;
    c.camera.value = ViewportTransform(
        worldToScreenMatrix: Transform2(0.07, 0, 0, -0.07, -310, 2400));
    await tester.tap(byKey('fit'));
    await tester.pump();
    await tester.pump();
    expect(c.camera.value.worldToScreenMatrix.a, fitted);
  });

  testWidgets(
      'D10 Revert with nothing stored empties the area; Teras keeps its own '
      'service layout', (tester) async {
    final demo = await pumpDemo(tester, plans: {'Teras': salonPlan()});
    await tester.tap(byKey('area-1'));
    await tester.pump();
    await tester.pump();
    final teras = demo.area.controller;
    expect(demo.area.name, 'Teras');
    await tester.tap(byKey('mode-service'));
    await tester.pump();
    await tester.pump();
    serviceMove(demo, '2');
    await tester.pump();
    await tester.tap(byKey('mode-design'));
    await tester.pump();
    await tester.pump();
    expect(teras.mode.value, FloorPlanMode.design);
    expect(demo.area.layout, contains('"number":"2"'));
    expect(demo.areas.first.layout, isNull);
    expect(demo.areas.first.controller.mode.value, FloorPlanMode.design);

    await tester.tap(byKey('area-0'));
    await tester.pump();
    await tester.pump();
    expect(demo.area.stored, isNull);
    // Something in Salon first, so a Revert that does nothing shows.
    demo.area.controller.load(salonPlan());
    await tester.pump();
    await tester.pump();
    expect(tablesText(tester), '1 (4), 2 (6)');
    await tester.tap(byKey('revert'));
    await tester.pump();
    await tester.pump();
    expect(tablesText(tester), 'none');
  });

  testWidgets(
      'Dark theme (spec D9, review 6 finding 1): under a dark platform the '
      'demo is dark and its own UI paints without an exception: the areas, '
      'the service with statuses, back to design with the layout kept (spec '
      '14d S9: no discard dialog)', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final demo = await pumpDemo(tester,
        plans: {'Teras': salonPlan()}, random: math.Random(7));
    void dark(String step) {
      expect(tester.takeException(), isNull, reason: step);
      expect(Theme.of(tester.element(find.byType(DemoHome))).brightness,
          Brightness.dark,
          reason: step);
    }

    dark('start');
    await tester.tap(byKey('area-1'));
    await tester.pump();
    await tester.pump();
    dark('Teras');
    await tester.tap(byKey('mode-service'));
    await tester.pump();
    await tester.pump();
    await tester.tap(byKey('status-random'));
    await tester.pump();
    dark('service with statuses');
    serviceMove(demo, '2');
    await tester.pump();
    await tester.tap(byKey('mode-design'));
    await tester.pump();
    await tester.pump();
    expect(byKey('discard-dialog'), findsNothing, reason: 'spec 14d S9');
    expect(demo.area.controller.mode.value, FloorPlanMode.design);
    expect(demo.area.layout, isNotNull, reason: 'the layout is kept');
    dark('back to design');
  });

  testWidgets('D11 two numbers, padded, by Enter: both selected, logged sorted',
      (tester) async {
    final demo = await pumpDemo(tester, plans: {'Salon': salonPlan()});
    // Table 1 renamed 9: the tables' order (9, 2) is not the sorted one.
    rename(demo, '1', '9');
    await tester.pump();
    await tester.pump();
    await tester.enterText(byKey('select-number'), ' 9,2 ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(demo.area.controller.selectedTables.value, {'2', '9'});
    expect(demo.log.first, 'Salon: selected {2, 9}');
  });

  testWidgets(
      'D12 status buttons set the selected tables\' statuses; Free clears '
      'them (14c S10)', (tester) async {
    final demo = await pumpDemo(tester, plans: {'Salon': salonPlan()});
    final c = demo.area.controller;
    c.select({'1', '2'});
    await tester.pump();
    await tester.tap(byKey('status-eating'));
    await tester.pump();
    expect(c.tableStatuses.value, {
      '1': DemoHomeState.kStatuses['Eating'],
      '2': DemoHomeState.kStatuses['Eating'],
    });
    expect(demo.log.first, 'Salon: Eating for {1, 2}');
    c.select({'2'});
    await tester.tap(byKey('status-bill'));
    await tester.pump();
    expect(c.tableStatuses.value['2']!.caption, 'Bill');
    expect(c.tableStatuses.value['1'], DemoHomeState.kStatuses['Eating'],
        reason: 'only the selection changes (review T4-1)');
    c.select({'1'});
    await tester.tap(byKey('status-free'));
    await tester.pump();
    expect(c.tableStatuses.value.keys, ['2']);
  });

  testWidgets(
      'D13 random statuses are seeded and replace the previous ones '
      '(14c R-13, review T4-2)', (tester) async {
    final names = DemoHomeState.kStatuses.keys.toList();
    // The first seed that draws Free for some table, so a merge into the
    // previous statuses would show.
    var seed = 0;
    while (() {
      final r = math.Random(seed);
      return [r.nextInt(names.length), r.nextInt(names.length)]
          .every((i) => names[i] != 'Free');
    }()) {
      seed++;
    }
    final demo = await pumpDemo(tester,
        plans: {'Salon': salonPlan()}, random: math.Random(seed));
    final c = demo.area.controller;
    final stale = TableStatus(color: const Color(0xFF123456), caption: 'Old');
    c.setTableStatus({for (final t in c.tables) t.number!: stale});
    await tester.tap(byKey('status-random'));
    await tester.pump();
    final expected = math.Random(seed);
    final want = <String, TableStatus>{};
    for (final t in c.tables) {
      final s = DemoHomeState.kStatuses[names[expected.nextInt(names.length)]];
      if (s != null) want[t.number!] = s;
    }
    expect(want.length, lessThan(c.tables.length), reason: 'a Free drawn');
    expect(c.tableStatuses.value, want);
    expect(demo.log.first, 'Salon: random statuses for ${want.length} tables');
  });

  testWidgets('D14 in the service, a tap and a drag are logged by number',
      (tester) async {
    final demo = await pumpDemo(tester, plans: {'Salon': salonPlan()});
    final c = demo.area.controller;
    await tester.tap(byKey('mode-service'));
    await tester.pump();
    await tester.pump();
    Offset onScreen(String n) {
      final d = c.activeDocument;
      final node = d.tree[TableSurvey.of(d).withNumber(n).single.instance]!
          as InstanceNode;
      final def = d.tree.definition(node.definition)!;
      final w = node.transform.transformPoint(def.basePoint);
      final s = c.camera.value.worldToScreen(w);
      return tester.getTopLeft(find.byType(InteractionLayer)) +
          Offset(s.x, s.y);
    }

    await tester.tapAt(onScreen('2'));
    await tester.pump();
    // The newest line first: the selection, then the tap that made it.
    expect(demo.log.first, 'Salon: tapped 2');
    expect(demo.log[1], 'Salon: selected {2}');
    final g = await tester.startGesture(onScreen('1'));
    await g.moveBy(const Offset(40, 0));
    await g.moveBy(const Offset(40, 0));
    await g.up();
    await tester.pump();
    expect(demo.log.where((l) => l == 'Salon: layout changed'), hasLength(1),
        reason: 'once per drag (review T4-3)');
    expect(demo.log, isNot(contains('Salon: tapped 1')),
        reason: 'a drag is no tap');
    expect(c.serviceEdited, isTrue);
  });

  testWidgets(
      'D15 the demo opens on its sample plans: both assets load, every table '
      'numbered once (review T4-5)', (tester) async {
    // What main() loads, from the app's own bundle.
    final plans = (await tester.runAsync(() => loadSamplePlans(rootBundle)))!;
    expect(plans.keys, ['Salon', 'Teras']);
    final demo = await pumpDemo(tester, plans: plans);
    final salon = demo.areas[0].controller, teras = demo.areas[1].controller;
    expect([for (final t in salon.tables) t.number],
        [for (var i = 1; i <= 11; i++) '$i']);
    expect([for (final t in teras.tables) t.number],
        [for (var i = 1; i <= 6; i++) '$i']);
    expect(salon.numberingWarnings, isEmpty);
    expect(teras.numberingWarnings, isEmpty);
  });

  testWidgets(
      'D16 a Revert in the service, and the mode switches, keep the stored '
      'layout (spec 14d S4, M-14d-r)', (tester) async {
    final demo = await pumpDemo(tester, plans: {'Salon': salonPlan()});
    final c = demo.area.controller;
    await tester.tap(byKey('mode-service'));
    await tester.pump();
    await tester.pump();
    serviceMove(demo, '1');
    await tester.pump();
    final layout = demo.area.layout;
    expect(layout, contains('"number":"1"'));
    await tester.tap(byKey('revert'));
    await tester.pump();
    await tester.pump();
    expect(c.serviceEdited, isTrue, reason: 'restored after the load');
    expect(demo.area.layout, layout);
    expect(demo.log.first, 'Salon: layout restored, 1 moved, 0 dropped');
  });

  /// Table [n]'s base point on the screen.
  Offset onScreen(WidgetTester tester, DemoHomeState demo, String n) {
    final c = demo.area.controller;
    final d = c.activeDocument;
    final node = d.tree[TableSurvey.of(d).withNumber(n).single.instance]!
        as InstanceNode;
    final def = d.tree.definition(node.definition)!;
    final w = node.transform.transformPoint(def.basePoint);
    final s = c.camera.value.worldToScreen(w);
    return tester.getTopLeft(find.byType(InteractionLayer)) + Offset(s.x, s.y);
  }

  testWidgets(
      'D17 a right click opens the table\'s menu; a status chosen there is '
      'set on the table (spec 14d S6, S9)', (tester) async {
    final demo = await pumpDemo(tester, plans: {'Salon': salonPlan()});
    final c = demo.area.controller;
    await tester.tap(byKey('mode-service'));
    await tester.pump();
    await tester.pump();
    await tester.tapAt(onScreen(tester, demo, '2'),
        buttons: kSecondaryMouseButton, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(find.text('Table 2'), findsOneWidget);
    expect(c.selectedTables.value, {'2'});
    await tester.tap(byKey('menu-status-bill'));
    await tester.pumpAndSettle();
    expect(c.tableStatuses.value.keys, ['2']);
    expect(demo.log, contains('Salon: menu for 2'));
  });

  testWidgets(
      'D18 with Moves off a drag from a table pans and changes no layout '
      '(spec 14d S5, S9)', (tester) async {
    final demo = await pumpDemo(tester, plans: {'Salon': salonPlan()});
    final c = demo.area.controller;
    await tester.tap(byKey('mode-service'));
    await tester.pump();
    await tester.pump();
    await tester.tap(byKey('moves'));
    await tester.pump();
    expect(demo.moves, isFalse);
    final g = await tester.startGesture(onScreen(tester, demo, '1'));
    await g.moveBy(const Offset(40, 0));
    await g.moveBy(const Offset(40, 0));
    await g.up();
    await tester.pump();
    expect(c.serviceEdited, isFalse);
    expect(demo.log, isNot(contains('Salon: layout changed')));
  });

  testWidgets(
      'D19 the language switch: the demo, the planner and a status caption '
      'speak Turkish, then German (spec 14d L17)', (tester) async {
    final demo = await pumpDemo(tester, plans: {'Salon': salonPlan()});
    final c = demo.area.controller;
    await tester.tap(byKey('lang-tr'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Restoran demosu'), findsOneWidget);
    expect(find.text('Tasarım'), findsOneWidget);
    expect(find.text('Duvar'), findsOneWidget, reason: 'the planner too');
    await tester.tap(byKey('mode-service'));
    await tester.pump();
    await tester.pump();
    expect(demo.log, contains('Salon: mod Servis'));
    c.select({'2'});
    await tester.pump();
    await tester.tap(byKey('status-bill'));
    await tester.pump();
    expect(c.tableStatuses.value['2']!.caption, 'Hesap');
    expect(find.text('Hesap'), findsWidgets, reason: 'the button');

    await tester.tap(byKey('lang-de'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Entwurf'), findsOneWidget);
    expect(find.text('Anordnung zurücksetzen'), findsOneWidget);
  });

  testWidgets(
      'D20 a locked table\'s menu acts on that table, never on the '
      'selection (spec 14d S6, review F-1)', (tester) async {
    final demo = await pumpDemo(tester, plans: {'Salon': lockedSalonPlan()});
    final c = demo.area.controller;
    await tester.tap(byKey('mode-service'));
    await tester.pump();
    await tester.pump();
    c.select({'1'});
    await tester.pump();
    expect(c.selectedTables.value, {'1'}, reason: 'premise');
    await tester.tapAt(onScreen(tester, demo, '2'),
        buttons: kSecondaryMouseButton, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(find.text('Table 2'), findsOneWidget);
    expect(c.selectedTables.value, {'1'},
        reason: 'premise: a locked table leaves the selection alone');
    expect(tester.widget<PopupMenuItem<String>>(byKey('menu-select')).enabled,
        isFalse,
        reason: 'a locked table cannot be selected');
    await tester.tap(byKey('menu-status-bill'));
    await tester.pumpAndSettle();
    expect(c.tableStatuses.value.keys, ['2']);
  });

  testWidgets(
      'D21 a status caption is worded again when the language changes '
      '(review 14d-1 F-6)', (tester) async {
    final demo = await pumpDemo(tester, plans: {'Salon': salonPlan()});
    final c = demo.area.controller;
    await tester.tap(byKey('lang-tr'));
    await tester.pump();
    await tester.pump();
    c.select({'2'});
    await tester.pump();
    await tester.tap(byKey('status-bill'));
    await tester.pump();
    expect(c.tableStatuses.value['2']!.caption, 'Hesap', reason: 'premise');
    await tester.tap(byKey('lang-de'));
    await tester.pump();
    await tester.pump();
    expect(c.tableStatuses.value['2']!.caption, 'Rechnung');
    expect(c.tableStatuses.value['2']!.color,
        DemoHomeState.kStatuses['Bill']!.color);
  });

  testWidgets(
      'D22 with Long press: menu on, a finger\'s long press opens the '
      'table\'s menu and toggles nothing (spec 14d S7, review F-6)',
      (tester) async {
    final demo = await pumpDemo(tester, plans: {'Salon': salonPlan()});
    final c = demo.area.controller;
    await tester.tap(byKey('mode-service'));
    await tester.pump();
    await tester.pump();
    await tester.tap(byKey('long-press-menu'));
    await tester.pump();
    expect(demo.longPressMenu, isTrue);
    c.select({'2'});
    await tester.pump();
    final g = await tester.startGesture(onScreen(tester, demo, '1'),
        kind: PointerDeviceKind.touch);
    await tester.pump(const Duration(milliseconds: 700));
    await g.up();
    await tester.pumpAndSettle();
    expect(find.text('Table 1'), findsOneWidget);
    expect(c.selectedTables.value, {'1'},
        reason: 'an unselected table is selected alone, never toggled in');
    expect(demo.log, contains('Salon: menu for 1'));
  });

  // Table-groups spec G6: Merge (grow or a new `G<n>`), Split, the status
  // buttons by `selectedGroup`, the groups line and `onGroupTap`.

  /// The numbers of [groupPlan]'s numbered tables in handle order: not
  /// sorted. 8 sits on a visible locked layer, 9 on a hidden one.
  const groupNumbers = ['12', '3', '7', '20', '5', '11', '8', '9'];

  /// A Salon plan of eight tables numbered [groupNumbers], each off the
  /// origin, turned, mirrored or both, of four kinds.
  String groupPlan() {
    final doc = newDocument(MetricModelMeasurer());
    final entries = SymbolLibrary.decode(Uint8List.fromList(utf8.encode(
            DraftDocumentCodec.encodeToString(
                buildSymbolLibrary(restaurantCatalog)))))
        .entries;
    SymbolEntry entry(String key) => entries.firstWhere((e) => e.key == key);
    final placements = [
      ('restaurant.table.rect.four', Vector2(-3800, 2400), 1, false),
      ('restaurant.table.round.six', Vector2(1600, 2900), 0, true),
      ('restaurant.table.square.four', Vector2(4700, -700), 3, true),
      ('restaurant.table.rect.six', Vector2(-2200, -2600), 2, true),
      ('restaurant.table.round.four', Vector2(2100, -3100), 1, false),
      ('restaurant.table.square.two', Vector2(-5600, -300), 3, false),
      ('restaurant.table.round.two', Vector2(5900, 3300), 0, true),
      ('restaurant.table.rect.four', Vector2(-600, 300), 1, true),
    ];
    for (final (key, at, turns, mirrored) in placements) {
      doc.commands.execute(placeSymbol(doc, entry(key),
          at: at, quarterTurns: turns, mirrored: mirrored));
    }
    final tables = TableSurvey.of(doc).tables.toList();
    for (var i = 0; i < groupNumbers.length; i++) {
      doc.commands.execute(SetEntityTextCommand(
          tables[i].label!, groupNumbers[i], kTableLabelTag));
    }
    final zero = doc.tables.layers[ReservedHandles.layerZero]!;
    Handle layer(String name, {required bool visible, required bool locked}) {
      final h = doc.handleSeed.next();
      doc.commands.execute(AddLayerCommand(LayerRecord(
          handle: h,
          name: name,
          color: const IndexedColor(5),
          linetype: zero.linetype,
          lineweight: zero.lineweight,
          transparency: zero.transparency,
          visible: visible,
          locked: locked)));
      return h;
    }

    doc.commands.execute(SetInstanceLayerCommand(
        tables[6].instance, layer('Locked', visible: true, locked: true)));
    doc.commands.execute(SetInstanceLayerCommand(
        tables[7].instance, layer('Hidden', visible: false, locked: false)));
    return DraftDocumentCodec.encodeToString(doc);
  }

  /// [groupPlan] in Salon, in the service.
  Future<DemoHomeState> pumpGroups(WidgetTester tester) async {
    final demo = await pumpDemo(tester, plans: {'Salon': groupPlan()});
    await tester.tap(byKey('mode-service'));
    await tester.pump();
    await tester.pump();
    return demo;
  }

  /// The instance of the table numbered [n] in [demo]'s current area.
  InstanceNode instanceOf(DemoHomeState demo, String n) {
    final d = demo.area.controller.activeDocument;
    return d.tree[TableSurvey.of(d).withNumber(n).single.instance]!
        as InstanceNode;
  }

  /// The centre of table [n] on the screen: a restaurant table's base point
  /// is its centre.
  Offset centreOf(WidgetTester tester, DemoHomeState demo, String n) {
    final c = demo.area.controller;
    final node = instanceOf(demo, n);
    final def = c.activeDocument.tree.definition(node.definition)!;
    final s = c.camera.value
        .worldToScreen(node.transform.transformPoint(def.basePoint));
    return tester.getTopLeft(find.byType(InteractionLayer)) + Offset(s.x, s.y);
  }

  Future<void> tapTable(WidgetTester tester, DemoHomeState demo, String n,
      {bool add = false}) async {
    if (add) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tapAt(centreOf(tester, demo, n),
        kind: PointerDeviceKind.mouse);
    if (add) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
  }

  Future<void> selectByField(WidgetTester tester, String text) async {
    await tester.enterText(byKey('select-number'), text);
    await tester.tap(byKey('select'));
    await tester.pump();
  }

  Future<void> press(WidgetTester tester, String key) async {
    await tester.tap(byKey(key));
    await tester.pump();
    await tester.pump();
  }

  String groupsText(WidgetTester tester) =>
      tester.widget<Text>(byKey('groups')).data!;

  Map<String, Set<String>> membersOf(DemoHomeState demo) => {
        for (final e in demo.area.controller.tableGroups.value.entries)
          e.key: e.value.members
      };

  testWidgets(
      'D16 G6: Merge makes G1, Merge again grows it; a tap on a member is '
      'logged as the group\'s; Bill goes to the group; a drag moves the '
      'group; Split drops the group and its status', (tester) async {
    final demo = await pumpGroups(tester);
    final c = demo.area.controller;
    expect(groupsText(tester), 'none');

    // Two tables by Shift taps, out of order.
    await tapTable(tester, demo, '12');
    await tapTable(tester, demo, '3', add: true);
    expect(c.selectedTables.value, {'12', '3'});
    await press(tester, 'service-merge');
    expect(membersOf(demo), {
      'G1': {'3', '12'}
    });
    expect(demo.log.first, 'Salon: Merged {3, 12} as G1');
    expect(groupsText(tester), 'G1: 3+12');
    expect(c.selectedGroup.value, 'G1');

    // G1 plus a third table by the number field: 3 selects all of G1.
    await selectByField(tester, '3, 7');
    expect(c.selectedTables.value, {'3', '7', '12'});
    await press(tester, 'service-merge');
    expect(
        membersOf(demo),
        {
          'G1': {'3', '7', '12'}
        },
        reason: 'grown under its id, no new group');
    expect(demo.log.first, 'Salon: Merged {3, 7, 12} as G1');
    expect(groupsText(tester), 'G1: 3+7+12');

    // A tap on a table in no group reports no group.
    await tapTable(tester, demo, '20');
    expect(demo.log.first, 'Salon: tapped 20');
    expect(c.selectedGroup.value, isNull);
    // Per table while no group is selected.
    await press(tester, 'status-eating');
    expect(c.tableStatuses.value, {'20': DemoHomeState.kStatuses['Eating']});
    expect(c.groupStatuses.value, isEmpty);

    // A tap on a member selects the group and is logged as the group's.
    await tapTable(tester, demo, '7');
    expect(demo.log.take(3).toList(), [
      'Salon: group G1 tapped at 7',
      'Salon: tapped 7',
      'Salon: selected {12, 3, 7}',
    ]);
    expect(c.selectedGroup.value, 'G1');
    await press(tester, 'status-bill');
    expect(c.groupStatuses.value, {'G1': DemoHomeState.kStatuses['Bill']});
    expect(c.tableStatuses.value, {'20': DemoHomeState.kStatuses['Eating']},
        reason: 'the members\' own statuses are left alone');
    expect(demo.log.first, 'Salon: Bill for G1');
    expect(groupsText(tester), 'G1: 3+7+12 (Bill)');

    // A drag on a member moves every member by the same step, nothing else.
    final before = {
      for (final n in groupNumbers.take(5)) n: instanceOf(demo, n).transform
    };
    await tapTable(tester, demo, '20');
    final g = await tester.startGesture(centreOf(tester, demo, '3'),
        kind: PointerDeviceKind.mouse);
    await g.moveBy(const Offset(40, 0));
    await g.moveBy(const Offset(30, 25));
    await g.up();
    await tester.pump();
    expect(demo.log.where((l) => l == 'Salon: layout changed'), hasLength(1));
    final after = {
      for (final n in before.keys) n: instanceOf(demo, n).transform
    };
    final step =
        Vector2(after['3']!.e - before['3']!.e, after['3']!.f - before['3']!.f);
    expect(step.length, greaterThan(100), reason: 'the drag moved 3');
    for (final n in ['12', '7']) {
      expect(after[n]!.e - before[n]!.e, moreOrLessEquals(step.x), reason: n);
      expect(after[n]!.f - before[n]!.f, moreOrLessEquals(step.y), reason: n);
      expect((
        after[n]!.a,
        after[n]!.b,
        after[n]!.c,
        after[n]!.d
      ), (
        before[n]!.a,
        before[n]!.b,
        before[n]!.c,
        before[n]!.d
      ), reason: 'only moved');
    }
    for (final n in ['20', '5']) {
      expect(after[n], before[n], reason: '$n is in no group');
    }

    // Free on the selected group clears its status only (review 5).
    expect(c.selectedGroup.value, 'G1', reason: 'the drag selected G1');
    await press(tester, 'status-free');
    expect(c.groupStatuses.value, isEmpty);
    expect(c.tableStatuses.value, {'20': DemoHomeState.kStatuses['Eating']});
    expect(demo.log.first, 'Salon: Free for G1');
    await press(tester, 'status-bill');
    expect(c.groupStatuses.value, {'G1': DemoHomeState.kStatuses['Bill']});

    // Split: the group and its status go; table 20's own status stays.
    await press(tester, 'service-split');
    expect(c.tableGroups.value, isEmpty);
    expect(c.groupStatuses.value, isEmpty);
    expect(c.tableStatuses.value, {'20': DemoHomeState.kStatuses['Eating']});
    expect(demo.log.first, 'Salon: Split G1');
    expect(groupsText(tester), 'none');
    expect(tester.takeException(), isNull);
  });

  test(
      'D17b G6: the next id counts every id\'s trailing digits, a POS\'s own '
      'prefix included (Copilot review on #8)', () {
    expect(DemoHomeState.nextGroupId(const []), 'G1');
    expect(DemoHomeState.nextGroupId(const ['VIP9', 'G3']), 'G10');
    expect(DemoHomeState.nextGroupId(const ['Window', 'G2']), 'G3',
        reason: 'an id with no digits counts for nothing');
    expect(DemoHomeState.nextGroupId(const ['T007']), 'G8');
  });

  testWidgets(
      'D17 G6: a new group is G<largest suffix + 1> after a split; a merge '
      'spanning two groups makes a new one, and the groups it empties go '
      'with their statuses', (tester) async {
    final demo = await pumpGroups(tester);
    final c = demo.area.controller;
    for (final pair in ['12, 3', '7, 20', '5, 11']) {
      await selectByField(tester, pair);
      await press(tester, 'service-merge');
    }
    expect(membersOf(demo), {
      'G1': {'12', '3'},
      'G2': {'7', '20'},
      'G3': {'5', '11'},
    });
    await selectByField(tester, '7');
    expect(c.selectedGroup.value, 'G2');
    await press(tester, 'service-split');
    expect(c.tableGroups.value.keys, unorderedEquals(['G1', 'G3']));

    await selectByField(tester, '20, 7');
    await press(tester, 'service-merge');
    expect(
        membersOf(demo),
        {
          'G1': {'12', '3'},
          'G3': {'5', '11'},
          'G4': {'7', '20'},
        },
        reason: 'G4, not a second G3');
    expect(demo.log.first, 'Salon: Merged {7, 20} as G4');

    await selectByField(tester, '3');
    await press(tester, 'status-ordered');
    await selectByField(tester, '11');
    await press(tester, 'status-bill');
    expect(c.groupStatuses.value.keys, unorderedEquals(['G1', 'G3']));
    expect(groupsText(tester), 'G1: 3+12 (Ordered), G3: 5+11 (Bill), G4: 7+20');

    // G1 and G3 together touch two groups: a new group, not a grown one.
    await selectByField(tester, '11, 3');
    expect(c.selectedTables.value, {'12', '3', '5', '11'});
    await press(tester, 'service-merge');
    expect(membersOf(demo), {
      'G4': {'7', '20'},
      'G5': {'12', '3', '5', '11'},
    });
    expect(demo.log.first, 'Salon: Merged {3, 5, 11, 12} as G5');
    expect(c.groupStatuses.value, isEmpty,
        reason: 'G1 and G3 are gone, so are their statuses (R-C5-2)');
    expect(groupsText(tester), 'G4: 7+20, G5: 3+5+11+12');

    // The id comes from the groups before the merge: G6, not a reused G1.
    await selectByField(tester, '20, 5');
    await press(tester, 'service-merge');
    expect(membersOf(demo), {
      'G6': {'7', '20', '12', '3', '5', '11'},
    });
    expect(demo.log.first, 'Salon: Merged {3, 5, 7, 11, 12, 20} as G6');
  });

  testWidgets(
      'D18 G6: a POS-restored group with a locked and a hidden member grows '
      '(neither is ever selected) and keeps its label', (tester) async {
    final demo = await pumpGroups(tester);
    final c = demo.area.controller;
    c.setTableGroups({
      'G7': TableGroup(members: {'12', '3', '8', '9'}, label: 'Window'),
    });
    await tester.pump();
    await tapTable(tester, demo, '3');
    expect(c.selectedTables.value, {'12', '3'},
        reason: '8 is locked, 9 hidden');
    expect(c.selectedGroup.value, 'G7');
    await tapTable(tester, demo, '20', add: true);
    expect(c.selectedTables.value, {'12', '3', '20'});
    await press(tester, 'service-merge');
    expect(c.tableGroups.value, {
      'G7': TableGroup(members: {'12', '3', '8', '9', '20'}, label: 'Window')
    });
    expect(demo.log.first, 'Salon: Merged {3, 12, 20} as G7');
    expect(groupsText(tester), 'G7: 3+8+9+12+20');
  });

  testWidgets(
      'D20 G6, R-C5-4: a new-group merge leaves what remains of a POS group '
      'under its id and label, and drops a group it empties (review 5)',
      (tester) async {
    final demo = await pumpGroups(tester);
    final c = demo.area.controller;
    c.setTableGroups({
      'G7': TableGroup(members: {'12', '3', '8', '9'}, label: 'Window'),
      'G1': TableGroup(members: {'5', '11'}),
    });
    await tester.pump();
    await tapTable(tester, demo, '3');
    await tapTable(tester, demo, '5', add: true);
    expect(c.selectedTables.value, {'12', '3', '5', '11'},
        reason: 'premise: 8 locked, 9 hidden, both groups whole');
    await press(tester, 'service-merge');
    expect(c.tableGroups.value, {
      'G7': TableGroup(members: {'8', '9'}, label: 'Window'),
      'G8': TableGroup(members: {'12', '3', '5', '11'}),
    });
  });

  // Table-groups fixes spec X2: the grow rule is G6's literal one, over
  // `FloorPlanController.selectableMembers` (R-C5-1 retired).

  testWidgets(
      'D21 X2, M-TGF-4: groups set under a live selection that holds part of '
      'a group make a new group, not a grown one', (tester) async {
    final demo = await pumpGroups(tester);
    final c = demo.area.controller;
    await selectByField(tester, '3, 20');
    c.setTableGroups({
      'G7': TableGroup(members: {'12', '3', '7'}),
    });
    await tester.pump();
    expect(c.selectedTables.value, {'3', '20'},
        reason: 'premise: half of G7 selected');
    await press(tester, 'service-merge');
    expect(c.tableGroups.value, {
      'G7': TableGroup(members: {'12', '7'}),
      'G8': TableGroup(members: {'3', '20'}),
    });
    expect(demo.log.first, 'Salon: Merged {3, 20} as G8');
  });

  testWidgets('D22 X2, M-TGF-6: a group with no selectable member never grows',
      (tester) async {
    final demo = await pumpGroups(tester);
    final c = demo.area.controller;
    c.setTableGroups({
      'G9': TableGroup(members: {'8', '9'}, label: 'Back'),
    });
    await tester.pump();
    await selectByField(tester, '20, 5');
    expect(c.selectedTables.value, {'5', '20'});
    expect(c.selectableMembers('G9'), isEmpty,
        reason: 'premise: 8 locked, 9 hidden');
    await press(tester, 'service-merge');
    expect(c.tableGroups.value, {
      'G9': TableGroup(members: {'8', '9'}, label: 'Back'),
      'G10': TableGroup(members: {'20', '5'}),
    });
    expect(demo.log.first, 'Salon: Merged {5, 20} as G10');
  });

  testWidgets(
      'D23 X2, M-TGF-7: a grow takes a number from another group, which '
      'keeps its id, label and group status', (tester) async {
    final demo = await pumpGroups(tester);
    final c = demo.area.controller;
    c.setTableGroups({
      'G7': TableGroup(members: {'12', '3'}),
    });
    await tester.pump();
    await selectByField(tester, '3, 5');
    expect(c.selectedTables.value, {'12', '3', '5'});
    final bill = DemoHomeState.kStatuses['Bill']!;
    c.setTableGroups({
      'G7': TableGroup(members: {'12', '3'}),
      'G1': TableGroup(members: {'5', '11'}, label: 'Bar'),
    });
    c.setGroupStatus({'G1': bill});
    await tester.pump();
    expect(c.selectedTables.value, {'12', '3', '5'},
        reason: 'premise: part of G1 selected');
    await press(tester, 'service-merge');
    expect(tester.takeException(), isNull);
    expect(c.tableGroups.value, {
      'G7': TableGroup(members: {'12', '3', '5'}),
      'G1': TableGroup(members: {'11'}, label: 'Bar'),
    });
    expect(c.groupStatuses.value, {'G1': bill});
    expect(demo.log.first, 'Salon: Merged {3, 5, 12} as G7');
    expect(groupsText(tester), 'G1: 11 (Bill), G7: 3+5+12');
  });

  testWidgets(
      'D24 X2 edge cases from a host: a request of exactly one group\'s '
      'selectable members is a logged no-op grow; an empty request changes '
      'nothing', (tester) async {
    final demo = await pumpGroups(tester);
    final c = demo.area.controller;
    final groups = {
      'G7': TableGroup(members: {'12', '3', '8', '9'}, label: 'Window'),
      'G2': TableGroup(members: {'20', '5'}),
    };
    c.setTableGroups(groups);
    c.setGroupStatus({'G7': DemoHomeState.kStatuses['Eating']!});
    await tester.pump();
    final merge = tester
        .widget<FloorPlanView>(find.byType(FloorPlanView))
        .onMergeRequested!;
    merge({'3', '12'});
    await tester.pump();
    expect(c.tableGroups.value, groups);
    expect(c.groupStatuses.value, {'G7': DemoHomeState.kStatuses['Eating']});
    expect(demo.log.first, 'Salon: Merged {3, 12} as G7');

    final log = [...demo.log];
    merge(const {});
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(c.tableGroups.value, groups);
    expect(demo.log, log, reason: 'nothing logged');
  });

  testWidgets(
      'D19 G6 under a dark platform: merge, a group status, split paint '
      'without an exception', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final demo = await pumpGroups(tester);
    final c = demo.area.controller;
    expect(Theme.of(tester.element(find.byType(DemoHome))).brightness,
        Brightness.dark);
    await selectByField(tester, '20, 5, 7');
    await press(tester, 'service-merge');
    expect(c.tableGroups.value.keys, ['G1']);
    expect(tester.takeException(), isNull, reason: 'merged');
    await press(tester, 'status-eating');
    expect(c.groupStatuses.value.keys, ['G1']);
    expect(tester.takeException(), isNull, reason: 'group status');
    await press(tester, 'service-split');
    expect(c.tableGroups.value, isEmpty);
    expect(c.groupStatuses.value, isEmpty);
    expect(tester.takeException(), isNull, reason: 'split');
  });

  // Spec Q0 N1 (M-Q0-e): an empty area takes the language of the view that
  // shows it, as if made so; Revert with nothing stored makes a new plan in
  // the language of the moment; a stored plan keeps its own (N2).
  DecimalSeparator shownSeparator(DemoHomeState demo) {
    final doc = demo.area.controller.activeDocument;
    return doc.components.get<PageComponent>(doc.rootHandle)!.decimalSeparator;
  }

  testWidgets(
      'DQ1 no samples, in German: the shown area\'s empty plan prints comma, '
      'clean, with no undo step and no dirty line; Teras too once shown',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const RestaurantDemo(locale: Locale('de')));
    await tester.pump();
    await tester.pump();
    final demo = tester.state<DemoHomeState>(find.byType(DemoHome));
    expect(demo.area.name, 'Salon');
    expect(find.text('Entwurf'), findsOneWidget, reason: 'premise: German');
    expect(demo.area.stored, isNull, reason: 'premise: no sample');
    final c = demo.area.controller;
    expect(shownSeparator(demo), DecimalSeparator.comma);
    expect(c.dirty.value, isFalse);
    expect(c.canUndo.value, isFalse);
    expect(c.activeDocument.commands.undoDepth, 0);
    expect(demo.log.where((l) => l.startsWith('Salon:')), isEmpty,
        reason: 'no dirty line, no layout line');
    expect(tester.widget<FilledButton>(byKey('save')).onPressed, isNull,
        reason: 'nothing to save');

    await tester.tap(byKey('area-1'));
    await tester.pump();
    await tester.pump();
    expect(demo.area.name, 'Teras');
    expect(shownSeparator(demo), DecimalSeparator.comma);
    expect(demo.area.controller.dirty.value, isFalse);
  });

  testWidgets(
      'DQ2 Revert after a switch to German: an area with nothing stored gets '
      'a comma plan; one with a stored point plan reloads it as point (N2)',
      (tester) async {
    final demo = await pumpDemo(tester, plans: {'Teras': salonPlan()});
    expect(demo.area.name, 'Salon');
    expect(shownSeparator(demo), DecimalSeparator.point,
        reason: 'premise: settled in English');
    await tester.tap(byKey('lang-de'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Entwurf'), findsOneWidget, reason: 'premise: German');
    expect(shownSeparator(demo), DecimalSeparator.point,
        reason: 'a settled plan is not converted (N2)');

    await tester.tap(byKey('revert'));
    await tester.pump();
    await tester.pump();
    expect(shownSeparator(demo), DecimalSeparator.comma);
    expect(demo.area.controller.dirty.value, isFalse);
    expect(demo.area.controller.canUndo.value, isFalse);

    await tester.tap(byKey('area-1'));
    await tester.pump();
    await tester.pump();
    expect(demo.area.name, 'Teras');
    await tester.tap(byKey('revert'));
    await tester.pump();
    await tester.pump();
    expect(tablesText(tester), '1 (4), 2 (6)', reason: 'premise: reloaded');
    expect(shownSeparator(demo), DecimalSeparator.point);
  });

  // Zone spec Z22: the Salon's zones A = 1-5, B = 6-7, C = 8-11, through
  // the spec's showZone and showAllZones; none for the Teras.

  /// The four screen corners, in the drawing area's coordinates, of the
  /// box of each table numbered [n] in [c]'s active plan.
  List<Offset> boxOnScreen(FloorPlanController c, String n) {
    final d = c.activeDocument;
    return [
      for (final t in TableSurvey.of(d).withNumber(n))
        for (final (x, y) in [
          for (final b in [d.definitionBounds(t.definition)]) ...[
            (b.minX, b.minY),
            (b.maxX, b.minY),
            (b.maxX, b.maxY),
            (b.minX, b.maxY),
          ]
        ])
          () {
            final w = (d.tree[t.instance]! as InstanceNode)
                .transform
                .transformPoint(Vector2(x, y));
            final s = c.camera.value.worldToScreen(w);
            return Offset(s.x, s.y);
          }(),
    ];
  }

  /// Scrolls the side panel until [key] is in view.
  Future<void> reveal(WidgetTester tester, String key) async {
    await tester.scrollUntilVisible(byKey(key), 100,
        scrollable: find
            .descendant(
                of: byKey('side-panel'), matching: find.byType(Scrollable))
            .first);
    await tester.pump();
  }

  List<double> coefficients(ViewportTransform v) {
    final m = v.worldToScreenMatrix;
    return [m.a, m.b, m.c, m.d, m.e, m.f];
  }

  testWidgets(
      'DZ1 M-Z29: zone B frames tables 6 and 7, not 1; "Fade the others" '
      'focuses {6, 7}; All clears the focus and fits the page; the zone and '
      'the switch are kept per area, and the Teras has none', (tester) async {
    final plans = (await tester.runAsync(() => loadSamplePlans(rootBundle)))!;
    final demo = await pumpDemo(tester, plans: plans);
    final c = demo.area.controller;
    await tester.tap(byKey('mode-service'));
    await tester.pump();
    await tester.pump();
    await reveal(tester, 'fade-others');
    expect(byKey('zone-toggle'), findsOneWidget);
    expect(byKey('fade-others'), findsOneWidget);
    final canvas = Offset.zero & tester.getSize(find.byType(InteractionLayer));
    final page = c.camera.value;
    for (final n in ['1', '6', '7']) {
      expect(boxOnScreen(c, n), hasLength(4), reason: 'premise: one $n');
    }

    await tester.tap(byKey('zone-B'));
    await tester.pump();
    await tester.pump();
    expect(coefficients(c.camera.value), isNot(coefficients(page)),
        reason: 'premise: the camera moved');
    for (final n in ['6', '7']) {
      for (final p in boxOnScreen(c, n)) {
        expect(canvas.contains(p), isTrue, reason: '$n\'s corner $p');
      }
    }
    final one = boxOnScreen(c, '1');
    expect(one.every((p) => !canvas.contains(p)), isTrue,
        reason: 'table 1 is outside: $one in $canvas');
    expect(c.tableFocus.value, isNull, reason: 'fading is off');

    await tester.tap(byKey('fade-others'));
    await tester.pump();
    await tester.pump();
    expect(c.tableFocus.value, {'6', '7'});
    expect(demo.area.fadeOthers, isTrue);

    // Kept per area: the Teras has no zones; back in the Salon, B and the
    // switch are as they were.
    await tester.tap(byKey('area-1'));
    await tester.pump();
    await tester.pump();
    // The panel's end, where the zones would be: none.
    await tester.drag(byKey('side-panel'), const Offset(0, -5000));
    await tester.pump();
    expect(find.text('Log'), findsOneWidget, reason: 'premise: the end');
    expect(byKey('zone-toggle'), findsNothing);
    expect(byKey('fade-others'), findsNothing);
    expect(demo.area.controller.tableFocus.value, isNull);
    await tester.tap(byKey('area-0'));
    await tester.pump();
    await tester.pump();
    await reveal(tester, 'fade-others');
    expect(
        tester.widget<SegmentedButton<String>>(byKey('zone-toggle')).selected,
        {'B'});
    expect(tester.widget<SwitchListTile>(byKey('fade-others')).value, isTrue);
    expect(c.tableFocus.value, {'6', '7'});

    await tester.tap(byKey('zone-all'));
    await tester.pump();
    await tester.pump();
    expect(c.tableFocus.value, isNull);
    final all = coefficients(c.camera.value);
    c.camera.value = ViewportTransform(
        worldToScreenMatrix: Transform2(0.37, 0, 0, -0.37, 211.5, 307.25));
    c.fitToView();
    await tester.pump();
    await tester.pump();
    expect(coefficients(c.camera.value), all, reason: 'All fits the page');
    for (final n in ['1', '6', '7']) {
      for (final p in boxOnScreen(c, n)) {
        expect(canvas.contains(p), isTrue, reason: 'the page shows $n');
      }
    }

    // Fading on, zone C: the focus follows the zone.
    await tester.tap(byKey('zone-C'));
    await tester.pump();
    await tester.pump();
    expect(c.tableFocus.value, {'8', '9', '10', '11'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('DZ2 the zones\' three strings in German and Turkish (Z22)',
      (tester) async {
    await pumpDemo(tester, plans: {'Salon': salonPlan()});
    expect(find.text('Zones'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Fade the others'), findsOneWidget);
    await tester.tap(byKey('lang-de'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Bereiche'), findsOneWidget);
    expect(find.text('Alle'), findsOneWidget);
    expect(find.text('Andere abblenden'), findsOneWidget);
    await tester.tap(byKey('lang-tr'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Bölgeler'), findsOneWidget);
    expect(find.text('Tümü'), findsOneWidget);
    expect(find.text('Diğerlerini soldur'), findsOneWidget);
  });
}
