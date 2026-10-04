// Table-groups spec G5: the service bar's Merge and Split, through the real
// `FloorPlanView` / `ServiceView`. Tables are placed off the origin, turned
// and mirrored (one an asymmetric trapezoid), numbered out of handle order
// (`G7` holds 12, 3 and 7); one sits on a locked layer and one on a hidden
// layer; two are unnumbered; a variant carries a number twice (a
// hand-edited file). The camera is off the origin at 0.06 px per mm. The
// selection is made by mouse taps (Shift adds) and `controller.select`.
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_controller.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_view.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:jet_cad_floor_plan/src/tables/table_label.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../tables/table_fixture.dart';

/// The numbers given to the numbered tables in handle order: not sorted.
const List<String> kNumbers = ['12', '3', '7', '20', '5', '8', '9'];

/// The camera: world (0, 0) at screen (690, 420), 0.06 px per mm, y up.
const double kScale = 0.06;

/// A plan: tables numbered [kNumbers] in handle order, each off the origin,
/// turned or mirrored, table 3 an asymmetric mirrored trapezoid; table 8 on
/// a visible locked layer, table 9 on a hidden one; two unnumbered tables
/// last. [duplicate] renames table 5 to "3" (a file duplicate).
String toolbarPlanJson({bool duplicate = false}) {
  final doc = plan();
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

  final locked = layer('Locked', visible: true, locked: true);
  final hidden = layer('Hidden', visible: false, locked: false);
  final table = entryOf(tableSymbol());
  final placements = [
    (table, placementAt(-2600, 1400, kDeg37, mirrored: true)),
    (
      entryOf(trapezoidTable),
      placementAt(2300, 1700, kDeg37 * 2, mirrored: true, baseY: 650)
    ),
    (table, placementAt(5100, -900, -kDeg37, mirrored: true)),
    (table, placementAt(-4300, -2600, 0, mirrored: true)),
    (table, placementAt(800, -3300, kDeg37)),
    (table, placementAt(6400, 2400, kDeg37 * 3)),
    (table, placementAt(-6100, 3600, -kDeg37 * 2, mirrored: true)),
  ];
  for (final (entry, p) in placements) {
    doc.commands
        .execute(placeSymbol(doc, entry, at: Vector2.zero(), transform: p));
  }
  for (final p in [
    placementAt(3700, 4500, kDeg37 * 3, mirrored: true),
    placementAt(-1300, 4700, -kDeg37),
  ]) {
    doc.commands.execute(placeSymbol(doc, table,
        at: Vector2.zero(), transform: p, numbered: false));
  }
  final tables = tablesOf(doc);
  for (var i = 0; i < kNumbers.length; i++) {
    final n = duplicate && kNumbers[i] == '5' ? '3' : kNumbers[i];
    doc.commands
        .execute(SetEntityTextCommand(tables[i].label!, n, kTableLabelTag));
  }
  doc.commands.execute(SetInstanceLayerCommand(tables[5].instance, locked));
  doc.commands.execute(SetInstanceLayerCommand(tables[6].instance, hidden));
  return DraftDocumentCodec.encodeToString(doc);
}

TableGroup group(Set<String> members) => TableGroup(members: members);

/// The view under test and what its host heard.
final class Host {
  Host(this.c);

  final FloorPlanController c;

  /// `merge <numbers>` per `onMergeRequested` (the set as received) and
  /// `split <id>` per `onSplitRequested`, in the order heard.
  final List<Object> heard = [];

  /// The sets `onMergeRequested` received, in order.
  final List<Set<String>> merged = [];

  DraftDocument get doc => c.activeDocument;
}

Widget view(Host h, {bool merge = true, bool split = true}) => MaterialApp(
    home: Scaffold(
        body: FloorPlanView(
            controller: h.c,
            onMergeRequested: merge
                ? (numbers) {
                    h.merged.add(numbers);
                    h.heard.add('merge');
                  }
                : null,
            onSplitRequested: split ? (id) => h.heard.add('split $id') : null,
            onTableTap: (_) {})));

Future<Host> mount(WidgetTester tester,
    {bool duplicate = false, bool merge = true, bool split = true}) async {
  final c = FloorPlanController(json: toolbarPlanJson(duplicate: duplicate));
  addTearDown(c.dispose);
  final host = Host(c);
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(view(host, merge: merge, split: split));
  c.setMode(FloorPlanMode.selection);
  await tester.pump();
  await tester.pump();
  c.camera.value = ViewportTransform(
      worldToScreenMatrix: Transform2(kScale, 0, 0, -kScale, 690, 420));
  await tester.pump();
  return host;
}

/// The placement point of [table] on the screen, in the test's coordinates.
Offset onSurveyed(WidgetTester tester, Host h, TableInfo table) {
  final node = h.doc.tree[table.instance]! as InstanceNode;
  final trapezoid = table.symbolKey == trapezoidTable.key;
  final w = node.transform
      .transformPoint(trapezoid ? Vector2(900, 650) : Vector2(900, 700));
  final s = h.c.camera.value.worldToScreen(w);
  return tester.getTopLeft(find.byType(InteractionLayer)) + Offset(s.x, s.y);
}

/// The [which]th table numbered [n] on the screen.
Offset onTable(WidgetTester tester, Host h, String n, {int which = 0}) =>
    onSurveyed(tester, h, TableSurvey.of(h.doc).withNumber(n)[which]);

/// The [which]th unnumbered table on the screen.
Offset onUnnumbered(WidgetTester tester, Host h, int which) => onSurveyed(
    tester,
    h,
    TableSurvey.of(h.doc)
        .tables
        .where((t) => t.number == null)
        .elementAt(which));

Future<void> tap(WidgetTester tester, Offset p, {bool add = false}) async {
  if (add) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.tapAt(p, kind: PointerDeviceKind.mouse);
  if (add) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pump();
}

Finder byKey(String k) => find.byKey(Key(k));

bool enabled(WidgetTester tester, String k) =>
    tester.widget<IconButton>(byKey(k)).onPressed != null;

/// Merge's and Split's enabled flags, as `(merge, split)`.
(bool, bool) flags(WidgetTester tester) =>
    (enabled(tester, 'service-merge'), enabled(tester, 'service-split'));

Future<void> press(WidgetTester tester, String k) async {
  await tester.tap(byKey(k));
  await tester.pump();
}

int selectedCount(Host h) => h.c.activeSelection.keys.length;

void main() {
  testWidgets(
      'TB1 Merge: disabled for one table, two unnumbered tables, a numbered '
      'plus an unnumbered table and exactly one whole group; enabled for '
      'two numbered tables and a group plus a table, reporting exactly '
      'selectedTables (M-TG-16)', (tester) async {
    final h = await mount(tester);
    h.c.setTableGroups({
      'G9': group({'9', '5'}),
      'G7': group({'12', '3', '7'}),
    });
    await tester.pump();
    expect(flags(tester), (false, false), reason: 'nothing selected');

    await tap(tester, onTable(tester, h, '20'));
    expect(h.c.selectedTables.value, {'20'});
    expect(flags(tester), (false, false), reason: 'one table');

    await tap(tester, onUnnumbered(tester, h, 0));
    await tap(tester, onUnnumbered(tester, h, 1), add: true);
    expect(selectedCount(h), 2);
    expect(h.c.selectedTables.value, isEmpty);
    expect(flags(tester), (false, false), reason: 'two unnumbered tables');
    // A groups change makes both flags recompute over the same selection.
    h.c.setTableGroups({
      'G9': group({'9', '5'}),
      'G7': group({'12', '3', '7'}),
      'G1': group({'20'}),
    });
    await tester.pump();
    expect(flags(tester), (false, false),
        reason: 'two unnumbered tables, recomputed');
    h.c.setTableGroups({
      'G9': group({'9', '5'}),
      'G7': group({'12', '3', '7'}),
    });

    await tap(tester, onTable(tester, h, '20'), add: true);
    expect(selectedCount(h), 3);
    expect(h.c.selectedTables.value, {'20'});
    expect(flags(tester).$1, isFalse,
        reason: 'unnumbered tables count for nothing');

    await tap(tester, onTable(tester, h, '7'));
    expect(h.c.selectedTables.value, {'3', '7', '12'});
    expect(flags(tester), (false, true), reason: 'exactly one whole group');
    await press(tester, 'service-merge');
    expect(h.heard, isEmpty, reason: 'disabled: no call');

    await tap(tester, onTable(tester, h, '20'));
    await tap(tester, onTable(tester, h, '5'), add: true);
    expect(h.c.selectedTables.value, {'5', '20'},
        reason: 'G9\'s hidden 9 is never selected');
    expect(flags(tester), (true, false), reason: 'a group plus a table');
    await press(tester, 'service-merge');
    expect(h.heard, ['merge']);
    expect(h.merged.single, {'5', '20'});

    h.c.setTableGroups({});
    h.c.select({'20', '3'});
    await tester.pump();
    expect(flags(tester), (true, false), reason: 'two numbered tables');
    await press(tester, 'service-merge');
    expect(h.merged.last, {'3', '20'});

    h.c.setTableGroups({
      'G9': group({'9', '5'}),
      'G7': group({'12', '3', '7'}),
    });
    h.c.select({'7', '20'});
    await tester.pump();
    expect(flags(tester), (true, false));
    await press(tester, 'service-merge');
    expect(h.merged.last, {'3', '7', '12', '20'},
        reason: 'exactly the selected numbers, the group not collapsed');
    expect(h.merged.last, h.c.selectedTables.value);
    expect(h.heard, ['merge', 'merge', 'merge']);
    expect(h.doc.commands.undoDepth, 0, reason: 'the planner only asks');
    expect(h.c.tableGroups.value.keys, ['G9', 'G7'],
        reason: 'the planner never changes a group itself');
  });

  testWidgets(
      'TB2 Merge is disabled for two tables sharing one duplicate number '
      '(M-TG-16)', (tester) async {
    final h = await mount(tester, duplicate: true);
    h.c.setTableGroups({
      'G2': group({'20', '8'})
    });
    await tap(tester, onTable(tester, h, '3'));
    await tap(tester, onTable(tester, h, '3', which: 1), add: true);
    expect(selectedCount(h), 2);
    expect(h.c.selectedTables.value, {'3'});
    expect(flags(tester), (false, false));
    // Recomputed over the same selection by a groups change.
    h.c.setTableGroups({
      'G2': group({'20', '8'}),
      'G5': group({'5', '9'}),
    });
    await tester.pump();
    expect(flags(tester), (false, false),
        reason: 'one number, though two tables');

    await tap(tester, onTable(tester, h, '12'), add: true);
    expect(flags(tester), (true, false));
    await press(tester, 'service-merge');
    expect(h.merged.single, {'3', '12'});
  });

  testWidgets(
      'TB3 Split: disabled for a group plus one table, part of a group and a '
      'group plus an unnumbered table; enabled for exactly one group\'s '
      'selectable members, its locked third member not selected, reporting '
      'the id (M-TG-17, the button half)', (tester) async {
    final h = await mount(tester);
    // Part of a group: 12 alone, then grouped with 3 and the locked 8.
    await tap(tester, onTable(tester, h, '12'));
    h.c.setTableGroups({
      'G9': group({'9', '5'}),
      'G7': group({'12', '3', '8'}),
    });
    await tester.pump();
    expect(h.c.selectedTables.value, {'12'});
    expect(flags(tester), (false, false), reason: 'part of a group');
    await press(tester, 'service-split');
    expect(h.heard, isEmpty, reason: 'disabled: no call');

    await tap(tester, onTable(tester, h, '3'));
    expect(h.c.selectedTables.value, {'3', '12'});
    expect(flags(tester), (false, true),
        reason: 'G7\'s selectable members; its locked 8 is not needed');
    await press(tester, 'service-split');
    expect(h.heard, ['split G7']);

    await tap(tester, onTable(tester, h, '20'), add: true);
    expect(h.c.selectedTables.value, {'3', '12', '20'});
    expect(flags(tester), (true, false), reason: 'a group plus one table');

    await tap(tester, onTable(tester, h, '12'));
    await tap(tester, onUnnumbered(tester, h, 1), add: true);
    expect(selectedCount(h), 3);
    expect(h.c.selectedTables.value, {'3', '12'});
    expect(flags(tester), (false, false),
        reason: 'a group plus an unnumbered table');

    await tap(tester, onTable(tester, h, '5'));
    expect(h.c.selectedTables.value, {'5'});
    expect(flags(tester), (false, true), reason: 'G9\'s 9 is hidden');
    await press(tester, 'service-split');
    expect(h.heard, ['split G7', 'split G9']);
    expect(h.merged, isEmpty);
    expect(h.c.tableGroups.value.keys, ['G9', 'G7'],
        reason: 'the planner never changes a group itself');
  });

  testWidgets(
      'TB4 with the selection unchanged, setTableGroups flips the flags: '
      'grouping the selected tables turns Merge off and Split on, and back '
      '(M-TG-17b through the widgets)', (tester) async {
    final h = await mount(tester);
    await tap(tester, onTable(tester, h, '3'));
    await tap(tester, onTable(tester, h, '20'), add: true);
    expect(h.c.selectedTables.value, {'3', '20'});
    expect(flags(tester), (true, false));

    h.c.setTableGroups({
      'G2': group({'20', '3'})
    });
    await tester.pump();
    expect(h.c.selectedTables.value, {'3', '20'}, reason: 'unchanged');
    expect(flags(tester), (false, true));
    await press(tester, 'service-split');
    expect(h.heard, ['split G2']);

    h.c.setTableGroups({
      'G2': group({'20', '3', '7'})
    });
    await tester.pump();
    expect(flags(tester), (false, false), reason: 'now part of G2');

    h.c.setTableGroups({
      'G2': group({'20', '9'}),
      'G4': group({'3', '12'}),
    });
    await tester.pump();
    expect(flags(tester), (true, false), reason: 'two groups, parts of each');

    h.c.setTableGroups({});
    await tester.pump();
    expect(flags(tester), (true, false));
    await press(tester, 'service-merge');
    expect(h.merged.single, {'3', '20'});
    expect(h.heard, ['split G2', 'merge']);
  });

  testWidgets(
      'TB5 without a merge or a split callback, its button is absent; it '
      'appears when the host rebuilds with one, and the bar keeps its order '
      '(M-TG-18)', (tester) async {
    final h = await mount(tester, merge: false, split: false);
    expect(byKey('service-bar'), findsOneWidget);
    expect(byKey('service-merge'), findsNothing);
    expect(byKey('service-split'), findsNothing);
    for (final k in ['service-undo', 'service-redo', 'service-print']) {
      expect(byKey(k), findsOneWidget, reason: k);
    }

    await tester.pumpWidget(view(h, merge: true, split: false));
    expect(byKey('service-merge'), findsOneWidget);
    expect(byKey('service-split'), findsNothing);

    await tester.pumpWidget(view(h, merge: false, split: true));
    expect(byKey('service-merge'), findsNothing);
    expect(byKey('service-split'), findsOneWidget);

    await tester.pumpWidget(view(h));
    final xs = [
      for (final k in [
        'service-undo',
        'service-redo',
        'service-merge',
        'service-split',
        'service-print'
      ])
        tester.getTopLeft(byKey(k)).dx
    ];
    for (var i = 1; i < xs.length; i++) {
      expect(xs[i], greaterThan(xs[i - 1]), reason: 'order at $i: $xs');
    }
    expect(tester.widget<IconButton>(byKey('service-merge')).tooltip, 'Merge');
    expect(tester.widget<IconButton>(byKey('service-split')).tooltip, 'Split');
    expect(find.byIcon(Icons.merge_type), findsOneWidget);
    expect(find.byIcon(Icons.call_split), findsOneWidget);

    // The rebuilt bar follows the selection as the first did.
    h.c.setTableGroups({
      'G7': group({'12', '3', '7'})
    });
    await tap(tester, onTable(tester, h, '7'));
    expect(flags(tester), (false, true));
    await press(tester, 'service-split');
    expect(h.heard, ['split G7']);
  });

  testWidgets(
      'TB6 the flags are released: a resetLayout\'s new bar listens, leaving '
      'the selection mode leaves none listening (review 4 finding 2)',
      (tester) async {
    final h = await mount(tester);
    // Only the bar's two flags listen to selectedGroup.
    final sg = h.c.selectedGroup as ValueNotifier<String?>;
    // ignore: invalid_use_of_protected_member
    expect(sg.hasListeners, isTrue, reason: 'premise');
    final before = h.c.activeDocument;
    h.c.resetLayout();
    await tester.pump();
    await tester.pump();
    expect(identical(before, h.c.activeDocument), isFalse, reason: 'premise');
    // ignore: invalid_use_of_protected_member
    expect(sg.hasListeners, isTrue, reason: 'the new view listens');
    h.c.setMode(FloorPlanMode.design);
    await tester.pump();
    await tester.pump();
    // ignore: invalid_use_of_protected_member
    expect(sg.hasListeners, isFalse, reason: 'no view left listening');
  });

  testWidgets(
      'TB7 no merge or split callback: Print sits 8 px after Redo, as before '
      '(R-C4-1, review 4 finding 1)', (tester) async {
    await mount(tester, merge: false, split: false);
    final gap = tester.getTopLeft(byKey('service-print')).dx -
        tester.getTopRight(byKey('service-redo')).dx;
    expect(gap, 8);
  });
}
