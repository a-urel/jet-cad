// Table-groups spec G4 and G1's tap callback: selecting, tapping and moving
// a group through the real `FloorPlanView` / `ServiceView`, by mouse (with
// Shift, Ctrl and Cmd) and by touch. Tables are placed off the origin,
// turned and mirrored (one an asymmetric trapezoid), numbered out of handle
// order (`G7` holds 12, 3 and 7); one sits on a locked layer and one on a
// hidden layer; a variant carries a number twice (a hand-edited file). The
// camera is off the origin at 0.06 px per mm.
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

/// The numbers given to the tables in handle order: not sorted.
const List<String> kNumbers = ['12', '3', '7', '20', '5', '8', '9'];

/// The camera: world (0, 0) at screen (690, 420), 0.06 px per mm, y up.
const double kScale = 0.06;

/// A plan: tables numbered [kNumbers] in handle order, each off the origin,
/// turned or mirrored, table 3 an asymmetric mirrored trapezoid; table 8 on
/// a visible locked layer, table 9 on a hidden one. [duplicate] renames
/// table 5 to "3" (a file duplicate).
String gesturePlanJson({bool duplicate = false}) {
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

  /// `table <n>` per `onTableTap`, `group <id> <n>` per `onGroupTap`, in
  /// the order heard.
  final List<String> heard = [];
  int layouts = 0;

  DraftDocument get doc => c.activeDocument;

  /// The tables numbered [n] in the service copy, ascending by handle.
  List<InstanceNode> nodes(String n) => [
        for (final t in TableSurvey.of(doc).withNumber(n))
          doc.tree[t.instance]! as InstanceNode
      ];

  InstanceNode node(String n) => nodes(n).single;

  Set<SelectionKey> keys(Set<String> numbers) => {
        for (final n in numbers)
          for (final t in nodes(n)) SelectionKey.root(t.handle)
      };

  Set<SelectionKey> get selected => c.activeSelection.keys;
}

Future<Host> mount(WidgetTester tester, {bool duplicate = false}) async {
  final c = FloorPlanController(json: gesturePlanJson(duplicate: duplicate));
  addTearDown(c.dispose);
  final host = Host(c);
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: FloorPlanView(
              controller: c,
              onTableTap: (n) => host.heard.add('table $n'),
              onGroupTap: (id, n) => host.heard.add('group $id $n'),
              onLayoutChanged: () => host.layouts++))));
  c.setMode(FloorPlanMode.selection);
  await tester.pump();
  await tester.pump();
  c.camera.value = ViewportTransform(
      worldToScreenMatrix: Transform2(kScale, 0, 0, -kScale, 690, 420));
  await tester.pump();
  return host;
}

/// The [which]th table numbered [n]'s top centre on the screen, in the
/// test's coordinates.
Offset onTable(WidgetTester tester, Host h, String n, {int which = 0}) {
  final table = TableSurvey.of(h.doc).withNumber(n)[which];
  final node = h.doc.tree[table.instance]! as InstanceNode;
  final trapezoid = table.symbolKey == trapezoidTable.key;
  final w = node.transform
      .transformPoint(trapezoid ? Vector2(900, 650) : Vector2(900, 700));
  final s = h.c.camera.value.worldToScreen(w);
  return tester.getTopLeft(find.byType(InteractionLayer)) + Offset(s.x, s.y);
}

Future<void> mouseTap(WidgetTester tester, Offset p,
    {LogicalKeyboardKey? modifier}) async {
  if (modifier != null) await tester.sendKeyDownEvent(modifier);
  await tester.tapAt(p, kind: PointerDeviceKind.mouse);
  if (modifier != null) await tester.sendKeyUpEvent(modifier);
  await tester.pump();
}

/// A mouse drag from [p] by [by] in two steps.
Future<void> mouseDrag(WidgetTester tester, Offset p, Offset by) async {
  final g = await tester.startGesture(p, kind: PointerDeviceKind.mouse);
  await g.moveBy(by / 2);
  await g.moveBy(by / 2);
  await g.up();
  await tester.pump();
}

List<double> parts(Transform2 t) => [t.a, t.b, t.c, t.d, t.e, t.f];

/// The world translation of a screen drag by [by].
(double, double) worldDelta(Offset by) => (by.dx / kScale, -by.dy / kScale);

/// Expects [after] to be [before] translated by [delta]: the linear part
/// unchanged.
void expectMoved(List<double> before, Transform2 after, (double, double) delta,
    String reason) {
  final a = parts(after);
  expect(a.sublist(0, 4), before.sublist(0, 4), reason: '$reason: linear');
  expect(a[4], closeTo(before[4] + delta.$1, 1e-6), reason: '$reason: x');
  expect(a[5], closeTo(before[5] + delta.$2, 1e-6), reason: '$reason: y');
}

void main() {
  testWidgets(
      'TG-G1 a plain tap on a member selects all its selectable members and '
      'reports the number, then the group; a table in no group is as '
      'before (M-TG-4, M-TG-6)', (tester) async {
    final h = await mount(tester);
    h.c.setTableGroups({
      'G7': group({'12', '3', '7', '9'})
    });
    await mouseTap(tester, onTable(tester, h, '12'));
    expect(h.selected, h.keys({'3', '7', '12'}),
        reason: 'the hidden member 9 is not selected');
    expect(h.c.selectedTables.value, {'3', '7', '12'});
    expect(h.heard, ['table 12', 'group G7 12']);

    await mouseTap(tester, onTable(tester, h, '20'));
    expect(h.selected, h.keys({'20'}), reason: 'replaced, as before');
    await tester.tapAt(onTable(tester, h, '7')); // a finger
    await tester.pump();
    expect(h.selected, h.keys({'3', '7', '12'}));
    expect(h.heard,
        ['table 12', 'group G7 12', 'table 20', 'table 7', 'group G7 7']);
    expect(h.doc.commands.undoDepth, 0);
  });

  testWidgets(
      'TG-G2 a tap on a locked member reports the number and the group and '
      'selects nothing (M-TG-6, R-1)', (tester) async {
    final h = await mount(tester);
    h.c.setTableGroups({
      'G2': group({'5', '8'})
    });
    await mouseTap(tester, onTable(tester, h, '20'));
    await mouseTap(tester, onTable(tester, h, '8'));
    expect(h.selected, h.keys({'20'}));
    expect(h.heard, ['table 20', 'table 8', 'group G2 8']);
  });

  testWidgets(
      'TG-G3 a Shift, Ctrl or Cmd tap adds or removes the whole group in one '
      'replace: a half-selected group comes out whole (M-TG-5)',
      (tester) async {
    final h = await mount(tester);
    h.c.select({'3', '20'});
    h.c.setTableGroups({
      'G7': group({'12', '3', '7'})
    });
    await tester.pump();
    expect(h.selected, h.keys({'3', '20'}), reason: 'half selected');
    await mouseTap(tester, onTable(tester, h, '7'),
        modifier: LogicalKeyboardKey.shiftLeft);
    expect(h.selected, h.keys({'3', '7', '12', '20'}));
    await mouseTap(tester, onTable(tester, h, '12'),
        modifier: LogicalKeyboardKey.controlLeft);
    expect(h.selected, h.keys({'20'}), reason: 'removed whole');
    await mouseTap(tester, onTable(tester, h, '3'),
        modifier: LogicalKeyboardKey.metaLeft);
    expect(h.selected, h.keys({'3', '7', '12', '20'}));
    expect(h.heard, [
      'table 7',
      'group G7 7',
      'table 12',
      'group G7 12',
      'table 3',
      'group G7 3'
    ]);
  });

  testWidgets(
      'TG-G4 a long press, by mouse or by finger, adds or removes the whole '
      'group in one replace and reports nothing (M-TG-5b)', (tester) async {
    final h = await mount(tester);
    h.c.select({'3', '20'});
    h.c.setTableGroups({
      'G7': group({'12', '3', '7'})
    });
    await tester.pump();
    final g = await tester.startGesture(onTable(tester, h, '7'),
        kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 499));
    expect(h.selected, h.keys({'3', '20'}));
    await tester.pump(const Duration(milliseconds: 2));
    expect(h.selected, h.keys({'3', '7', '12', '20'}));
    await g.up();
    await tester.pump();

    final f = await tester.startGesture(onTable(tester, h, '12'),
        pointer: 41, kind: PointerDeviceKind.touch);
    await tester.pump(const Duration(milliseconds: 501));
    expect(h.selected, h.keys({'20'}), reason: 'removed whole');
    await f.up();
    await tester.pump();
    expect(h.selected, h.keys({'20'}), reason: 'spent: no tap after');
    expect(h.heard, isEmpty, reason: 'a long press reports nothing');
    expect(h.doc.commands.undoDepth, 0);
  });

  testWidgets(
      'TG-G5 a drag on an unselected member selects its group and moves all '
      'of it by one delta in one Move (M-TG-7)', (tester) async {
    final h = await mount(tester);
    h.c.setTableGroups({
      'G7': group({'12', '3', '7'})
    });
    await mouseTap(tester, onTable(tester, h, '20'));
    final before = {
      for (final n in ['12', '3', '7', '20']) n: parts(h.node(n).transform)
    };
    const by = Offset(54, -24);
    await mouseDrag(tester, onTable(tester, h, '3'), by);
    expect(h.selected, h.keys({'3', '7', '12'}),
        reason: 'the group replaced the selection');
    expect(h.doc.commands.undoDepth, 1, reason: 'one Move');
    expect(h.layouts, 1);
    for (final n in ['12', '3', '7']) {
      expectMoved(before[n]!, h.node(n).transform, worldDelta(by), n);
    }
    expect(parts(h.node('20').transform), before['20'],
        reason: 'the previous selection stays where it was');
    expect(h.heard, ['table 20'], reason: 'a drag reports no tap');
    h.c.undo();
    for (final n in ['12', '3', '7']) {
      expect(parts(h.node(n).transform), before[n], reason: 'one undo: $n');
    }
  });

  testWidgets(
      'TG-G6 a drag on a member of a group with a locked member is spent: '
      'nothing moves, no pan, the selection is as before the press '
      '(M-TG-8)', (tester) async {
    final h = await mount(tester);
    h.c.setTableGroups({
      'G2': group({'5', '8'})
    });
    await mouseTap(tester, onTable(tester, h, '20'));
    final before = parts(h.node('5').transform);
    final camera = parts(h.c.camera.value.worldToScreenMatrix);
    await mouseDrag(tester, onTable(tester, h, '5'), const Offset(60, 30));
    expect(parts(h.node('5').transform), before);
    expect(h.doc.commands.undoDepth, 0);
    expect(h.layouts, 0);
    expect(parts(h.c.camera.value.worldToScreenMatrix), camera,
        reason: 'no pan');
    expect(h.selected, h.keys({'20'}), reason: 'not replaced');
  });

  testWidgets(
      'TG-G7 a drag on a non-member is spent when a selected group has a '
      'locked member (M-TG-8b)', (tester) async {
    final h = await mount(tester);
    h.c.setTableGroups({
      'G2': group({'5', '8'})
    });
    await mouseTap(tester, onTable(tester, h, '5'));
    await mouseTap(tester, onTable(tester, h, '20'),
        modifier: LogicalKeyboardKey.shiftLeft);
    expect(h.selected, h.keys({'5', '20'}));
    final before = {
      for (final n in ['5', '20']) n: parts(h.node(n).transform)
    };
    await mouseDrag(tester, onTable(tester, h, '20'), const Offset(-48, 36));
    for (final n in ['5', '20']) {
      expect(parts(h.node(n).transform), before[n], reason: n);
    }
    expect(h.doc.commands.undoDepth, 0);
    expect(h.layouts, 0);
    expect(h.selected, h.keys({'5', '20'}));
  });

  testWidgets(
      'TG-G8 a drag on a half-selected group\'s member moves the whole group '
      'with the rest of the selection (M-TG-8c)', (tester) async {
    final h = await mount(tester);
    h.c.select({'3', '20'});
    h.c.setTableGroups({
      'G7': group({'12', '3', '7'})
    });
    await tester.pump();
    final before = {
      for (final n in ['12', '3', '7', '20', '5']) n: parts(h.node(n).transform)
    };
    const by = Offset(-42, -30);
    await mouseDrag(tester, onTable(tester, h, '3'), by);
    expect(h.doc.commands.undoDepth, 1);
    expect(h.layouts, 1);
    for (final n in ['12', '3', '7', '20']) {
      expectMoved(before[n]!, h.node(n).transform, worldDelta(by), n);
    }
    expect(parts(h.node('5').transform), before['5'], reason: 'not selected');
  });

  testWidgets(
      'TG-G9 the tool follows setTableGroups alone: tap, regroup, tap again '
      '(M-TG-17c)', (tester) async {
    final h = await mount(tester);
    h.c.setTableGroups({
      'G7': group({'12', '3', '7'})
    });
    await mouseTap(tester, onTable(tester, h, '20'));
    expect(h.selected, h.keys({'20'}));
    h.c.setTableGroups({
      'G4': group({'20', '5'})
    });
    await tester.pump();
    await mouseTap(tester, onTable(tester, h, '20'));
    expect(h.selected, h.keys({'5', '20'}));
    await mouseTap(tester, onTable(tester, h, '12'));
    expect(h.selected, h.keys({'12'}), reason: 'G7 is gone');
    h.c.setTableGroups(const {});
    await tester.pump();
    await mouseTap(tester, onTable(tester, h, '5'));
    expect(h.selected, h.keys({'5'}));
    expect(h.heard,
        ['table 20', 'table 20', 'group G4 20', 'table 12', 'table 5']);
  });

  testWidgets(
      'TG-G10 the tool follows the picker: a member shown by a raw layer '
      'edit joins the next tap (lookup keyed on the candidates)',
      (tester) async {
    final h = await mount(tester);
    h.c.setTableGroups({
      'G7': group({'12', '3', '7', '9'})
    });
    await mouseTap(tester, onTable(tester, h, '3'));
    expect(h.selected, h.keys({'3', '7', '12'}));
    // Layer `Hidden` shown with no command: only the tables' revision.
    final layers = h.doc.tables.layers;
    final hidden = layers.byName('Hidden')!;
    layers
      ..remove(hidden.handle)
      ..add(hidden.copyWith(visible: true));
    await mouseTap(tester, onTable(tester, h, '12'));
    expect(h.selected, h.keys({'3', '7', '9', '12'}));
  });

  testWidgets(
      'TG-G11 by touch, with a number in the file twice: a drag on the second '
      'table numbered 3 moves every member (M-TG-7)', (tester) async {
    final h = await mount(tester, duplicate: true);
    h.c.setTableGroups({
      'G7': group({'12', '3', '7'})
    });
    expect(h.nodes('3'), hasLength(2));
    final before = {
      for (final n in h.nodes('3') + [h.node('12'), h.node('7')])
        n.handle: parts(n.transform)
    };
    final p = onTable(tester, h, '3', which: 1);
    final g = await tester.startGesture(p,
        pointer: 42, kind: PointerDeviceKind.touch);
    await tester.pump(const Duration(milliseconds: 150));
    await g.moveTo(p + const Offset(30, 0));
    await g.moveTo(p + const Offset(66, 18));
    await g.up();
    await tester.pump();
    expect(h.selected, h.keys({'3', '7', '12'}));
    expect(h.selected, hasLength(4));
    expect(h.c.selectedTables.value, {'3', '7', '12'});
    expect(h.doc.commands.undoDepth, 1);
    expect(h.layouts, 1);
    for (final MapEntry(key: handle, value: b) in before.entries) {
      expectMoved(b, (h.doc.tree[handle]! as InstanceNode).transform,
          worldDelta(const Offset(66, 18)), handle.toHex());
    }
  });

  testWidgets(
      'TG-G12 groups cleared: a drag on a former member selects and moves it '
      'alone (review 2 finding 1, the drag start\'s stale-map guard)',
      (tester) async {
    final h = await mount(tester);
    h.c.setTableGroups({
      'G7': group({'12', '3', '7'})
    });
    await mouseTap(tester, onTable(tester, h, '12'));
    expect(h.selected, h.keys({'3', '7', '12'}), reason: 'premise');
    await mouseTap(tester, onTable(tester, h, '20'));
    h.c.setTableGroups(const {});
    await tester.pump();
    final before = {
      for (final n in ['12', '3', '7']) n: parts(h.node(n).transform)
    };
    await mouseDrag(tester, onTable(tester, h, '3'), const Offset(54, -24));
    expect(h.selected, h.keys({'3'}));
    expectMoved(before['3']!, h.node('3').transform,
        worldDelta(const Offset(54, -24)), '3');
    expect(parts(h.node('12').transform), before['12']);
    expect(parts(h.node('7').transform), before['7']);
  });

  testWidgets(
      'TG-G13 groups cleared: a long press and a Shift tap toggle one table '
      '(review 2 finding 1, the long press\'s stale-map guard)',
      (tester) async {
    final h = await mount(tester);
    h.c.setTableGroups({
      'G7': group({'12', '3', '7'})
    });
    await mouseTap(tester, onTable(tester, h, '20'));
    h.c.setTableGroups(const {});
    await tester.pump();
    final p = await tester.startGesture(onTable(tester, h, '7'),
        kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 501));
    await p.up();
    await tester.pump();
    expect(h.selected, h.keys({'7', '20'}));
    await mouseTap(tester, onTable(tester, h, '12'),
        modifier: LogicalKeyboardKey.shiftLeft);
    expect(h.selected, h.keys({'7', '12', '20'}));
    expect(h.heard, ['table 20', 'table 12']);
  });

  testWidgets(
      'TG-G14 a locked member on a hidden layer does not spend the drag '
      '(spec G4: the picker cannot see it)', (tester) async {
    final h = await mount(tester);
    h.c.setTableGroups({
      'G2': group({'5', '8'})
    });
    final layers = h.doc.tables.layers;
    final locked = layers.byName('Locked')!;
    layers
      ..remove(locked.handle)
      ..add(locked.copyWith(visible: false));
    final before = parts(h.node('5').transform);
    await mouseDrag(tester, onTable(tester, h, '5'), const Offset(60, 30));
    expect(h.selected, h.keys({'5'}));
    expectMoved(
        before, h.node('5').transform, worldDelta(const Offset(60, 30)), '5');
  });
}
