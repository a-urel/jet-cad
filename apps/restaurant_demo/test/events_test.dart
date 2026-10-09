// Host embedding API spec E-1 to E-9 in the demo (Slice 2): "Link tables"
// writes the POS's ids into the design (`setTablesData`, one undo step),
// "Unlinked: n" counts the POS's ids no visible table carries (E-8); in the
// service a double tap logs the table and its id, a drag logs the moved
// numbers, and the mouse over a table or the floor, or a tap on the floor,
// feeds one pointer line, not the log; `designChanges` logs the tables
// added and removed and a replaced plan. On the Salon sample, its fitted
// camera neither the identity nor at the origin. Screen points come from
// the public `tableDetails` and `worldToGlobal`; double taps are driven by
// gestures with explicit stamps, the fake clock pumped differently from
// them (flutter_test stamps every synthetic event `Duration.zero`).
// The tests reach the design's document for fixture edits the demo's UI
// does not offer (a renumbering, a hidden layer, an unnumbered table).
// ignore_for_file: invalid_use_of_internal_member
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_floor_plan/editor.dart';
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart'
    show FloorPlanController, FloorPlanTableDetail;
import 'package:jet_cad_restaurant_symbols/jet_cad_restaurant_symbols.dart';
import 'package:restaurant_demo/main.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

Finder byKey(String k) => find.byKey(Key(k));

/// The demo on its sample plans, at 1600 x 1000, in the Salon's design.
Future<DemoHomeState> pumpSamples(WidgetTester tester, {Locale? locale}) async {
  final plans = (await tester.runAsync(() => loadSamplePlans(rootBundle)))!;
  await tester.binding.setSurfaceSize(const Size(1600, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(RestaurantDemo(plans: plans, locale: locale));
  await tester.pump();
  await tester.pump();
  return tester.state<DemoHomeState>(find.byType(DemoHome));
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

Future<void> press(WidgetTester tester, String key) async {
  await tester.tap(byKey(key));
  await settle(tester);
}

/// The detail of the one table numbered [n] in [c]'s current mode.
FloorPlanTableDetail detailOf(FloorPlanController c, String n) =>
    c.tableDetails.singleWhere((d) => d.table.number == n);

/// Table [n]'s centre on the screen, through the public API.
Offset centreOf(FloorPlanController c, String n) =>
    c.worldToGlobal(detailOf(c, n).center!)!;

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(byKey(key)).data!;

/// A floor point of the Salon, world millimetres: between the top row
/// (1 to 3, from y 1625) and the middle one (4 and 5, up to y 0), left of
/// 6 and 7 (from x 2975): on no table's box, off the origin.
const Offset kFloor = Offset(-3210, 810);

Duration ms(int n) => Duration(milliseconds: n);

/// A mouse click whose down is stamped [down], the up 40 ms later.
Future<void> click(WidgetTester tester, Offset at, Duration down) async {
  final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await g.down(at, timeStamp: down);
  await g.up(timeStamp: down + ms(40));
  await g.removePointer();
}

/// A mouse drag from [from] by [by], in three moves.
Future<void> drag(WidgetTester tester, Offset from, Offset by) async {
  final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await g.down(from, timeStamp: ms(5000));
  for (var i = 1; i <= 3; i++) {
    await g.moveTo(from + by * (i / 3), timeStamp: ms(5000 + 20 * i));
  }
  await g.up(timeStamp: ms(5100));
  await g.removePointer();
}

/// The restaurant library's entries, as a host's library decodes them.
List<SymbolEntry> restaurantEntries() => SymbolLibrary.decode(
        Uint8List.fromList(utf8.encode(DraftDocumentCodec.encodeToString(
            buildSymbolLibrary(restaurantCatalog)))))
    .entries;

/// Renames table [from] to [to] in [c]'s design.
void rename(FloorPlanController c, String from, String to) {
  final doc = c.activeDocument;
  final label = TableSurvey.of(doc).withNumber(from).single.label!;
  doc.commands.execute(SetEntityTextCommand(label, to, kTableLabelTag));
}

/// Puts table [n] of [c]'s design on a new hidden layer.
void hide(FloorPlanController c, String n) {
  final doc = c.activeDocument;
  final zero = doc.tables.layers[ReservedHandles.layerZero]!;
  final hidden = doc.handleSeed.next();
  doc.commands.execute(AddLayerCommand(LayerRecord(
      handle: hidden,
      name: 'Hidden',
      color: const IndexedColor(3),
      linetype: zero.linetype,
      lineweight: zero.lineweight,
      transparency: zero.transparency,
      visible: false,
      locked: false)));
  doc.commands.execute(SetInstanceLayerCommand(
      TableSurvey.of(doc).withNumber(n).single.instance, hidden));
}

Map<String, Map<String, String>> dataByNumber(FloorPlanController c) => {
      for (final d in c.tableDetails)
        if (d.data.isNotEmpty) d.table.number ?? '—': d.data,
    };

void main() {
  testWidgets(
      'DE1 Link tables gives each numbered table without an id '
      '<area>-<number> beside its data, in one undo step; a shared number '
      'is left out; Unlinked counts the POS ids no visible table carries',
      (tester) async {
    final demo = await pumpSamples(tester);
    final c = demo.area.controller;
    // Table 2 renumbered 1 (two 1s), 11 on a hidden layer, 5 linked by the
    // POS already, 6 carrying a key of its own.
    rename(c, '2', '1');
    hide(c, '11');
    expect(c.setTableData('5', {'zeta': 'z', 'id': 'pos-55'}), isTrue);
    expect(c.setTableData('6', {'alpha': 'Masa 6.ğ'}), isTrue);
    await settle(tester);
    expect(textOf(tester, 'unlinked'), 'Unlinked: 11');
    final depth = c.activeDocument.commands.undoDepth;

    await press(tester, 'link-tables');
    expect(dataByNumber(c), {
      '3': {'id': 'salon-3'},
      '4': {'id': 'salon-4'},
      '5': {'id': 'pos-55', 'zeta': 'z'},
      '6': {'alpha': 'Masa 6.ğ', 'id': 'salon-6'},
      '7': {'id': 'salon-7'},
      '8': {'id': 'salon-8'},
      '9': {'id': 'salon-9'},
      '10': {'id': 'salon-10'},
      '11': {'id': 'salon-11'},
    });
    expect(demo.log.first, 'Salon: linked 8 tables');
    expect(c.activeDocument.commands.undoDepth, depth + 1,
        reason: 'one undo step');
    // salon-1: two tables share 1; salon-2: no table 2; salon-5: 5 carries
    // the POS's own id; salon-11: 11 is not drawn.
    expect(demo.unlinkedTables(demo.area),
        {'salon-1', 'salon-2', 'salon-5', 'salon-11'});
    expect(textOf(tester, 'unlinked'), 'Unlinked: 4');

    await press(tester, 'link-tables');
    expect(demo.log.first, 'Salon: linked 0 tables');
    expect(c.activeDocument.commands.undoDepth, depth + 1,
        reason: 'nothing to link is no step');

    c.undo();
    await settle(tester);
    expect(dataByNumber(c), {
      '5': {'id': 'pos-55', 'zeta': 'z'},
      '6': {'alpha': 'Masa 6.ğ'},
    });
    expect(textOf(tester, 'unlinked'), 'Unlinked: 11');
  });

  testWidgets(
      'DE2 the Teras links as teras-<n>; Link tables and Unlinked show in '
      'the design only', (tester) async {
    final demo = await pumpSamples(tester);
    await press(tester, 'area-1');
    expect(demo.area.name, 'Teras');
    expect(textOf(tester, 'unlinked'), 'Unlinked: 6');
    await press(tester, 'link-tables');
    expect(dataByNumber(demo.area.controller), {
      for (var n = 1; n <= 6; n++) '$n': {'id': 'teras-$n'},
    });
    expect(textOf(tester, 'unlinked'), 'Unlinked: 0');
    await press(tester, 'mode-service');
    expect(byKey('link-tables'), findsNothing);
    expect(byKey('unlinked'), findsNothing);
    expect(byKey('pointer-line'), findsOneWidget);
  });

  testWidgets(
      'DE3 a saved plan declares schema 9 and keeps its ids across Save and '
      'Revert', (tester) async {
    final demo = await pumpSamples(tester);
    final c = demo.area.controller;
    await press(tester, 'link-tables');
    await press(tester, 'save');
    final stored = demo.area.stored!;
    expect((jsonDecode(stored) as Map<String, Object?>)['schemaVersion'], 9);
    expect(stored, contains('"jetcad.table_data"'));
    final linked = dataByNumber(c);
    expect(linked, hasLength(11), reason: 'premise: every table linked');

    expect(c.setTableData('7', {}), isTrue);
    expect(c.setTableData('3', {'id': 'other'}), isTrue);
    await settle(tester);
    expect(dataByNumber(c), isNot(linked), reason: 'premise: edited');
    await press(tester, 'revert');
    expect(dataByNumber(c), linked);
    expect(c.designJson(), stored, reason: 'byte for byte');
    expect(c.dirty.value, isFalse);
  });

  testWidgets(
      'DE4 a double click on table 7 logs it with its id, after both taps; '
      'timed from the stamps, not the clock; an unlinked table logs no id',
      (tester) async {
    final demo = await pumpSamples(tester);
    final c = demo.area.controller;
    await press(tester, 'link-tables');
    expect(c.setTableData('3', {'zeta': 'z'}), isTrue);
    await press(tester, 'mode-service');
    final seven = centreOf(c, '7');

    // 299 ms apart by the stamps, a second by the clock: a double tap.
    await click(tester, seven, ms(10000));
    await tester.pump(const Duration(seconds: 1));
    await click(tester, seven + const Offset(6, -4), ms(10299));
    await tester.pump();
    expect(demo.log.take(4).toList(), [
      'Salon: table 7 opened (id salon-7)',
      'Salon: tapped 7',
      'Salon: tapped 7',
      'Salon: selected {7}',
    ]);
    expect(c.selectedTables.value, {'7'}, reason: 'a click still selects');

    // 301 ms apart by the stamps, no time by the clock: two taps.
    final three = centreOf(c, '3');
    await click(tester, three, ms(20000));
    await click(tester, three, ms(20301));
    await tester.pump();
    expect(demo.log.take(3).toList(), [
      'Salon: tapped 3',
      'Salon: tapped 3',
      'Salon: selected {3}',
    ]);

    // Table 3 carries data but no id.
    await click(tester, three, ms(30000));
    await click(tester, three, ms(30100));
    await tester.pump();
    expect(demo.log.first, 'Salon: table 3 opened (no id)');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'DE5 a drag logs the moved numbers once, after the layout line; Undo '
      'logs no move; an unnumbered table moves as —', (tester) async {
    final demo = await pumpSamples(tester);
    final c = demo.area.controller;
    final doc = c.activeDocument;
    final stool = restaurantEntries().firstWhere(
        (e) => e.key == 'restaurant.bar.stool',
        orElse: () => throw StateError('no stool'));
    doc.commands.execute(
        placeSymbol(doc, stool, at: Vector2(-6400, -3100), numbered: false));
    await settle(tester);
    await press(tester, 'mode-service');
    c.select({'7', '3'});
    await tester.pump();
    await drag(tester, centreOf(c, '7'), const Offset(60, 40));
    await tester.pump();
    expect(demo.log.take(2).toList(),
        ['Salon: moved {3, 7}', 'Salon: layout changed']);

    await press(tester, 'service-undo');
    expect(c.serviceEdited, isFalse, reason: 'premise: undone');
    expect(demo.log.where((l) => l.startsWith('Salon: moved')), hasLength(1));

    final unnumbered =
        c.tableDetails.singleWhere((d) => d.table.number == null).center!;
    await drag(tester, c.worldToGlobal(unnumbered)!, const Offset(-50, 30));
    await tester.pump();
    expect(demo.log.first, 'Salon: moved {—}');
  });

  testWidgets(
      'DE6 the pointer line: over a table, over no table, a floor tap\'s '
      'point in metres; never the log; cleared by a reset, a mode switch '
      'and an area switch', (tester) async {
    final demo = await pumpSamples(tester);
    final c = demo.area.controller;
    await press(tester, 'mode-service');
    expect(textOf(tester, 'pointer-line'), '');
    final log = [...demo.log];
    final floor = c.worldToGlobal(kFloor)!;
    final canvas = c.canvasRect.value!;
    expect(canvas.contains(floor), isTrue, reason: 'premise: on the canvas');
    expect(c.tableAt(floor - canvas.topLeft), isNull,
        reason: 'premise: on no table');

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: floor);
    await mouse.moveTo(centreOf(c, '7'));
    await tester.pump();
    expect(textOf(tester, 'pointer-line'), 'over table 7');
    await mouse.moveTo(floor);
    await tester.pump();
    expect(textOf(tester, 'pointer-line'), 'over no table');
    await mouse.moveTo(centreOf(c, '10'));
    await tester.pump();
    expect(textOf(tester, 'pointer-line'), 'over table 10');
    expect(demo.log, log, reason: 'a hover is not logged');

    c.select({'4'});
    await tester.pump();
    await mouse.moveTo(floor);
    await mouse.down(floor, timeStamp: ms(1000));
    await mouse.up(timeStamp: ms(1040));
    await tester.pump();
    expect(textOf(tester, 'pointer-line'), 'floor at −3.2, 0.8 m');
    expect(c.selectedTables.value, isEmpty,
        reason: 'a floor tap still clears the selection');

    await mouse.moveTo(centreOf(c, '7'));
    await tester.pump();
    expect(textOf(tester, 'pointer-line'), 'over table 7');
    await press(tester, 'reset-layout');
    expect(textOf(tester, 'pointer-line'), '', reason: 'reset');

    await mouse.moveTo(floor);
    await mouse.moveTo(centreOf(c, '7'));
    await tester.pump();
    expect(textOf(tester, 'pointer-line'), 'over table 7');
    await press(tester, 'mode-design');
    await press(tester, 'mode-service');
    expect(textOf(tester, 'pointer-line'), '', reason: 'mode switch');

    // The new view heard no table yet: the floor is no change for it.
    await mouse.moveTo(floor);
    await tester.pump();
    expect(textOf(tester, 'pointer-line'), '');
    await mouse.moveTo(centreOf(c, '3'));
    await tester.pump();
    expect(textOf(tester, 'pointer-line'), 'over table 3');
    await press(tester, 'area-1');
    await press(tester, 'mode-service');
    expect(textOf(tester, 'pointer-line'), '', reason: 'area switch');
  });

  testWidgets(
      'DE7 designChanges: a table added and removed is logged, undo too; a '
      'renumbering is not; a Revert logs the replaced plan, and in the '
      'service the kept layout goes back after it', (tester) async {
    final demo = await pumpSamples(tester);
    final c = demo.area.controller;
    final doc = c.activeDocument;
    final stool =
        restaurantEntries().firstWhere((e) => e.key == 'restaurant.bar.stool');
    doc.commands.execute(
        placeSymbol(doc, stool, at: Vector2(-6400, -3100), numbered: false));
    await settle(tester);
    expect(demo.log.first, 'Salon: table — added');

    c.select({'3'});
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.delete);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.delete);
    await settle(tester);
    expect(c.tables.map((t) => t.number), isNot(contains('3')),
        reason: 'premise: deleted');
    expect(demo.log.first, 'Salon: table 3 removed');
    c.undo();
    await settle(tester);
    expect(demo.log.first, 'Salon: table 3 added');

    final log = [...demo.log];
    rename(c, '4', '14');
    await settle(tester);
    expect(demo.log, log, reason: 'a changed table is not logged');

    await press(tester, 'revert');
    expect(
        demo.log.take(2).toList(), ['Salon: plan replaced', 'Salon: reloaded']);

    // In the service: a move kept, then Revert.
    await press(tester, 'mode-service');
    await drag(tester, centreOf(c, '1'), const Offset(50, 0));
    await tester.pump();
    expect(c.serviceEdited, isTrue, reason: 'premise: moved');
    await press(tester, 'revert');
    expect(demo.log.take(3).toList(), [
      'Salon: layout restored, 1 moved, 0 dropped',
      'Salon: plan replaced',
      'Salon: reloaded',
    ]);
    expect(c.serviceEdited, isTrue, reason: 'the kept move is back');
    expect(tester.takeException(), isNull);
  });

  testWidgets('DE8 the new words in German and Turkish', (tester) async {
    final demo = await pumpSamples(tester, locale: const Locale('de'));
    final c = demo.area.controller;
    expect(find.text('Tische verknüpfen'), findsOneWidget);
    expect(textOf(tester, 'unlinked'), 'Nicht verknüpft: 11');
    await press(tester, 'link-tables');
    expect(demo.log.first, 'Salon: 11 Tische verknüpft');
    await press(tester, 'mode-service');
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: c.worldToGlobal(kFloor)!);
    await mouse.moveTo(centreOf(c, '7'));
    await tester.pump();
    expect(textOf(tester, 'pointer-line'), 'über Tisch 7');
    await mouse.moveTo(c.worldToGlobal(kFloor)!);
    await tester.pump();
    expect(textOf(tester, 'pointer-line'), 'über keinem Tisch');
    await mouse.down(c.worldToGlobal(kFloor)!, timeStamp: ms(1000));
    await mouse.up(timeStamp: ms(1040));
    await tester.pump();
    expect(textOf(tester, 'pointer-line'), 'Boden bei −3,2; 0,8 m');
    await click(tester, centreOf(c, '7'), ms(2000));
    await click(tester, centreOf(c, '7'), ms(2200));
    await tester.pump();
    expect(demo.log.first, 'Salon: Tisch 7 geöffnet (ID salon-7)');
    await drag(tester, centreOf(c, '7'), const Offset(60, 40));
    await tester.pump();
    expect(demo.log.first, 'Salon: {7} verschoben');
    await press(tester, 'revert');
    expect(demo.log[1], 'Salon: Plan ersetzt');

    // The stored sample carries no ids: Revert unlinked the tables.
    await press(tester, 'lang-tr');
    await press(tester, 'mode-design');
    expect(find.text('Masaları bağla'), findsOneWidget);
    expect(textOf(tester, 'unlinked'), 'Bağlanmamış: 11');
    await press(tester, 'link-tables');
    expect(demo.log.first, 'Salon: 11 masa bağlandı');
    await press(tester, 'mode-service');
    await mouse.moveTo(centreOf(c, '7'));
    await tester.pump();
    expect(textOf(tester, 'pointer-line'), 'masa 7 üzerinde');
    await mouse.moveTo(c.worldToGlobal(kFloor)!);
    await tester.pump();
    expect(textOf(tester, 'pointer-line'), 'masa üzerinde değil');
    await mouse.down(c.worldToGlobal(kFloor)!, timeStamp: ms(3000));
    await mouse.up(timeStamp: ms(3040));
    await tester.pump();
    expect(textOf(tester, 'pointer-line'), 'zemin: −3,2; 0,8 m');
    await click(tester, centreOf(c, '7'), ms(4000));
    await click(tester, centreOf(c, '7'), ms(4100));
    await tester.pump();
    expect(demo.log.first, 'Salon: masa 7 açıldı (kimlik salon-7)');
    await drag(tester, centreOf(c, '7'), const Offset(60, 40));
    await tester.pump();
    expect(demo.log.first, 'Salon: {7} taşındı');
  });
}
