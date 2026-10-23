// Ported from jet_cad_floor_plan's test/host/editor_select_test.dart (2b
// Task 8, spec S4 selectUnitsOnly, the unitsOnly profile): its
// `selectTablesOnly` and `tablesOnly` cases. The gates the controller
// builds from its permissions, on the select tool and the grip cache --
// selectUnitsOnly's pick (the unit picker: a top, else a box, a finger's
// reach; a locked unit passed over) and band, `move`, `delete`, the
// selection pruned on a change to units only and a drag cancelled by it.
// Through `PlanEditor` on the unit editor fixture under `editorCamera()`;
// screen points come from the camera's forward transform. The north wall
// is a root-level line, the column a closed square (fixture changes, A12).
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer, SelectionKey;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/chrome/text_field.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart' show coordsOf;
import '../support/unit_editor_fixture.dart';

typedef P = PlanPermissions;

/// The design's encoding: byte-identical means no edit.
String encoded(PlanController c) =>
    DraftDocumentCodec.encodeToString(c.document);

/// Table [n]'s root key.
SelectionKey keyOf(PlanController c, String n) =>
    SelectionKey.root(tableOf(c, n));

/// Table [n]'s transform.
Transform2 transformOf(PlanController c, String n) =>
    (c.document.tree[tableOf(c, n)]! as InstanceNode).transform;

/// [local], in table [n]'s definition space, in the world.
Vector2 onTable(PlanController c, String n, double x, double y) =>
    transformOf(c, n).transformPoint(Vector2(x, y));

/// A point inside table [n]'s top, away from its lines (the top is the
/// quadrilateral (300, -200), (1100, -200), (900, 400), (300, 250)).
Vector2 topOf(PlanController c, String n) => onTable(c, n, 500, 0);

/// A point inside table [n]'s box, off its top: beyond the top's slanted
/// edge from (1100, -200) to (900, 400).
Vector2 boxOf(PlanController c, String n) => onTable(c, n, 1050, 350);

/// A point on table [n]'s top's bottom edge: where the index's own pick
/// (no `selectUnitsOnly`) finds the table, over the parquet.
Vector2 edgeOf(PlanController c, String n) => onTable(c, n, 700, -200);

/// [line]'s first point in the world (a root-level line).
Vector2 startOf(DraftDocument d, Handle line) {
  final p = coordsOf(d, line);
  return Vector2(p[0], p[1]);
}

/// Whether [h] is a live line entity (today's wall).
bool isLine(DraftDocument d, Handle h) {
  final slot = d.entities.slotOf(h);
  return slot != null && d.entities.kindAt(slot) == EntityKind.line;
}

/// The selection's keys.
Set<SelectionKey> selected(PlanController c) => {...c.selection.keys};

/// A mouse drag from [from] to [to] in eight steps; [before] runs after
/// the last move and before the up.
Future<void> drag(WidgetTester tester, Offset from, Offset to,
    {Future<void> Function()? before}) async {
  final g = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
  await g.addPointer(location: from - const Offset(2, 2));
  await g.moveTo(from);
  await tester.pump();
  await g.down(from);
  await tester.pump();
  for (var i = 1; i <= 8; i++) {
    await g.moveTo(Offset.lerp(from, to, i / 8)!);
    await tester.pump();
  }
  if (before != null) await before();
  await g.up();
  await tester.pump();
  await g.removePointer();
  await tester.pump();
}

/// A finger's tap at [at]: down, held past the touch hold-back, up.
Future<void> fingerTap(WidgetTester tester, Offset at) async {
  final g = await tester.startGesture(at,
      pointer: 41, kind: ui.PointerDeviceKind.touch);
  await tester.pump(const Duration(milliseconds: 150));
  await g.up();
  await tester.pump(const Duration(milliseconds: 300));
}

/// The rotation grip of table [n]: 24 px above its top's screen box.
Offset rotationGripOf(WidgetTester tester, PlanController c, String n) {
  final corners = [
    for (final (x, y) in const [
      (300, -200),
      (1100, -200),
      (900, 400),
      (300, 250)
    ])
      screenOf(tester, c, onTable(c, n, x.toDouble(), y.toDouble())),
  ];
  final minX = corners.map((p) => p.dx).reduce(math.min);
  final maxX = corners.map((p) => p.dx).reduce(math.max);
  final minY = corners.map((p) => p.dy).reduce(math.min);
  return Offset((minX + maxX) / 2, minY - 24);
}

/// The turn of [m], in degrees.
double degreesOf(Transform2 m) => math.atan2(m.b, m.a) * 180 / math.pi;

/// The bands' corners: the whole canvas, inset 4 px.
Rect canvasRect(WidgetTester tester) =>
    tester.getRect(find.byType(InteractionLayer)).deflate(4);

void main() {
  group('selectUnitsOnly (M-H42, S-15)', () {
    testWidgets(
        'M-H42 tablesOnly: a window and a crossing band over the whole '
        'canvas (walls, rooms and their edges, the dimension, the free '
        'line, the group, the TEXT, the chair, every table) select exactly '
        'the five visible unlocked tables; a crossing band over the north '
        'wall, its room edge, the chair and 1 and 2 selects exactly 1 and 2; '
        'one over the group, the free line and the TEXT selects nothing',
        (tester) async {
      final c = await mountUnitEditor(tester, permissions: P.unitsOnly);
      final tables = {
        for (final n in ['1', '2', '7', ' 7 ']) keyOf(c, n),
        SelectionKey.root(
            unitsIn(c).units.singleWhere((x) => x.text == null).instance),
      };
      final r = canvasRect(tester);
      // A window band (left to right) and a crossing band (right to left).
      await drag(tester, r.topLeft, r.bottomRight);
      expect(selected(c), tables, reason: 'the window band');
      c.selection.clear();
      await tester.pump();
      await drag(tester, r.bottomRight, r.topLeft);
      expect(selected(c), tables, reason: 'the crossing band');
      c.selection.clear();
      await tester.pump();
      // North: y 15,740..16,900 crosses the north wall and its inner face
      // (16,750), the parquet, the chair and 1 and 2, x 21,450..24,450.
      await drag(tester, screenOf(tester, c, Vector2(24450, 16900)),
          screenOf(tester, c, Vector2(21450, 15740)));
      expect(selected(c), {keyOf(c, '1'), keyOf(c, '2')},
          reason: 'the north strip');
      c.selection.clear();
      await tester.pump();
      // South-west: the group, the free line and the TEXT, no table.
      await drag(tester, screenOf(tester, c, Vector2(23400, 14600)),
          screenOf(tester, c, Vector2(21450, 13250)));
      expect(selected(c), isEmpty, reason: 'the south-west strip');
    });

    testWidgets(
        'M-H42 S-15 a click on a wall line, the free line or the TEXT '
        'selects nothing under tablesOnly; a click inside 1\'s top away '
        'from its lines selects 1, though the topmost hit there is a '
        'parquet hairline (under full the same click selects the hairline); '
        'inside its box off its top too', (tester) async {
      final c = await mountUnitEditor(tester);
      // The control under full: the engine's topmost hit inside 1's top is
      // not 1 (S-15: a filter after it would lose the table).
      await click(tester, screenOf(tester, c, topOf(c, '1')));
      expect(selected(c), hasLength(1));
      expect(selected(c).single, isNot(keyOf(c, '1')));
      await click(tester, screenOf(tester, c, Vector2(22000, 16850)));
      expect(selected(c), hasLength(1), reason: 'the north wall, under full');
      final wall = selected(c).single;
      expect(isLine(c.document, wall.target), isTrue);
      await setPermissions(tester, c, P.unitsOnly);
      expect(selected(c), isEmpty, reason: 'pruned (S-9 g)');
      for (final (what, w) in [
        ('the north wall', Vector2(22000, 16850)),
        ('the column', Vector2(23500, 14000)),
        ('the free line', Vector2(23000, 13850)),
        ('the TEXT', Vector2(21750, 14300)),
      ]) {
        await click(tester, screenOf(tester, c, w));
        expect(selected(c), isEmpty, reason: what);
      }
      await click(tester, screenOf(tester, c, topOf(c, '1')));
      expect(selected(c), {keyOf(c, '1')}, reason: 'inside the top');
      c.selection.clear();
      await tester.pump();
      await click(tester, screenOf(tester, c, boxOf(c, '2')));
      expect(selected(c), {keyOf(c, '2')}, reason: 'inside the box');
    });

    testWidgets(
        'S-15 a finger reaches a table within its reach under tablesOnly; a '
        'mouse click at the same point selects nothing', (tester) async {
      final c = await mountUnitEditor(tester, permissions: P.unitsOnly);
      // 40 mm (about 15 px) beyond 1's box, on its local x axis; 2's box
      // is over 300 mm away.
      final near = screenOf(tester, c, onTable(c, '1', 1140, 100));
      await click(tester, near);
      expect(selected(c), isEmpty, reason: 'the mouse');
      await fingerTap(tester, near);
      expect(selected(c), {keyOf(c, '1')}, reason: 'the finger');
    });

    testWidgets(
        'the tables on the hidden and the locked layers are never selected, '
        'by a click or a band; a locked table is passed over, so the table '
        'under it answers', (tester) async {
      final c = await mountUnitEditor(tester, permissions: P.unitsOnly);
      final d = c.document;
      final hidden = unitsIn(c).withLabel('5').single;
      final hiddenAt = (d.tree[hidden.instance]! as InstanceNode)
          .transform
          .transformPoint(Vector2(500, 0));
      await click(tester, screenOf(tester, c, hiddenAt));
      expect(selected(c), isEmpty, reason: '5, hidden');
      await click(tester, screenOf(tester, c, topOf(c, 'L')));
      expect(selected(c), isEmpty, reason: 'L, locked');
      final r = canvasRect(tester);
      await drag(tester, r.bottomRight, r.topLeft);
      expect(selected(c).map((k) => k.target),
          isNot(anyOf(contains(tableOf(c, 'L')), contains(hidden.instance))));
      c.selection.clear();
      await tester.pump();
      // ` 7 ` (a lower handle than L, so drawn under it) moved under L.
      d.commands.execute(
          TransformNodeCommand(tableOf(c, ' 7 '), transformOf(c, 'L')));
      await tester.pump();
      await click(tester, screenOf(tester, c, topOf(c, 'L')));
      expect(selected(c), {keyOf(c, ' 7 ')});
    });
  });

  group('move (T5-a, S-9 h)', () {
    testWidgets(
        'T5-a readOnly: a body drag of 1 executes nothing; tablesOnly: it '
        'moves 1 by the drag', (tester) async {
      final c = await mountUnitEditor(tester, permissions: P.readOnly);
      final before = encoded(c);
      // readOnly picks by the index: the top's inside is a hairline; the
      // table is clicked and pressed on its top's bottom edge.
      final edge = screenOf(tester, c, edgeOf(c, '1'));
      await click(tester, edge);
      expect(selected(c), {keyOf(c, '1')}, reason: 'selectable');
      await drag(tester, edge, edge + const Offset(80, -40));
      expect(encoded(c), before, reason: 'readOnly');
      expect(c.canUndo.value, isFalse);
      await setPermissions(tester, c, P.unitsOnly);
      final centre = centreOf(c, '1');
      final from = screenOf(tester, c, topOf(c, '1'));
      await drag(tester, from, from + const Offset(80, -40));
      final moved = centreOf(c, '1') - centre;
      // 80 px right and 40 px up at 0.37 px/mm, y up; the move is exact up
      // to the grid's 50 mm snap.
      expect(moved.x, closeTo(80 / 0.37, 50));
      expect(moved.y, closeTo(40 / 0.37, 50));
    });

    testWidgets(
        'T5-b readOnly: 1 selected shows no rotation grip, no ±90, and a '
        'read-only Rotation field whose typed value does not commit; a drag '
        'at the grip\'s place turns nothing. unitsOnly: the grip turns it',
        (tester) async {
      final c = await mountUnitEditor(tester, permissions: P.readOnly);
      c.selection.replace([keyOf(c, '1')]);
      await tester.pump();
      final before = encoded(c);
      expect(c.grips.rotatable, isFalse);
      expect(find.byKey(const Key('unit-rotate-left')), findsNothing);
      expect(find.byKey(const Key('unit-rotate-right')), findsNothing);
      final field = tester
          .widget<PlanTextField>(find.byKey(const Key('symbol-rotation')));
      expect(field.readOnly, isTrue);
      await tester.tap(find.byKey(const Key('symbol-rotation')));
      await tester.pump();
      field.controller.text = '75';
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(encoded(c), before, reason: 'the typed value');
      final grip = rotationGripOf(tester, c, '1');
      await drag(tester, grip, grip + const Offset(120, 60));
      expect(encoded(c), before, reason: 'the grip\'s place');
      await setPermissions(tester, c, P.unitsOnly);
      c.selection.replace([keyOf(c, '1')]);
      await tester.pump();
      expect(c.grips.rotatable, isTrue);
      expect(find.byKey(const Key('unit-rotate-left')), findsOneWidget);
      expect(
          tester
              .widget<PlanTextField>(find.byKey(const Key('symbol-rotation')))
              .readOnly,
          isFalse);
      final turn = degreesOf(transformOf(c, '1'));
      // The left column came back: the canvas moved on the screen.
      final grip2 = rotationGripOf(tester, c, '1');
      await drag(tester, grip2, grip2 + const Offset(120, 60));
      expect(degreesOf(transformOf(c, '1')), isNot(closeTo(turn, 1)));
    });

    testWidgets(
        'S-9 h a body drag of 1 started under tablesOnly and switched to '
        'move: false before its up executes nothing; kept under tablesOnly '
        'it moves 1', (tester) async {
      final c = await mountUnitEditor(tester, permissions: P.unitsOnly);
      final from = screenOf(tester, c, topOf(c, '1'));
      final before = encoded(c);
      await drag(tester, from, from + const Offset(80, -40),
          before: () =>
              setPermissions(tester, c, P.unitsOnly.copyWith(move: false)));
      expect(encoded(c), before);
      expect(c.canUndo.value, isFalse);
      await setPermissions(tester, c, P.unitsOnly);
      await drag(tester, from, from + const Offset(80, -40));
      expect(encoded(c), isNot(before));
      expect(c.canUndo.value, isTrue);
    });
  });

  group("the review's killers (Task 5 review R-1, R-3, R-4, R-5)", () {
    // The north wall, beyond its inner face; a click there selects it.
    final northWall = Vector2(25500, 16850);

    testWidgets(
        'R-1 a body drag of the north wall started under full, the host '
        'switching to tablesOnly before its up: the drag is cancelled, the '
        'design byte-identical; kept under full the same drag moves the '
        'wall', (tester) async {
      final c = await mountUnitEditor(tester);
      final d = c.document;
      Offset at(Vector2 w) => screenOf(tester, c, w);
      await click(tester, at(northWall));
      final wall = selected(c).single.target;
      expect(isLine(d, wall), isTrue, reason: 'premise: the wall selected');
      final before = encoded(c);
      final ends = startOf(d, wall);
      await drag(tester, at(northWall), at(northWall) + const Offset(0, -60),
          before: () => setPermissions(tester, c, P.unitsOnly));
      expect(encoded(c), before);
      expect(c.canUndo.value, isFalse);
      expect(selected(c), isEmpty, reason: 'pruned (S-9 g)');
      // The control: the same drag under full moves the wall.
      await setPermissions(tester, c, P.full);
      await click(tester, at(northWall));
      expect(selected(c).single.target, wall);
      await drag(tester, at(northWall), at(northWall) + const Offset(0, -60));
      expect(startOf(d, wall), isNot(ends));
      expect(c.canUndo.value, isTrue);
    });

    testWidgets(
        "R-1 the chair turned by its rotation grip, started under full, the "
        'host switching to tablesOnly before its up: cancelled, the design '
        'byte-identical; kept under full the same drag turns it',
        (tester) async {
      final c = await mountUnitEditor(tester);
      final d = c.document;
      Offset at(Vector2 w) => screenOf(tester, c, w);
      // The chair's outline at local (50, 275).
      final onChair = editorChairPlacement.transformPoint(Vector2(50, 275));
      await click(tester, at(onChair));
      final chair = selected(c).single.target;
      final node = d.tree[chair];
      expect(node, isA<InstanceNode>(), reason: 'premise: the chair');
      Offset grip() {
        // Its drawing's screen box, (50, 50)..(500, 500): the grip is 24
        // px above its top edge's middle.
        final corners = [
          for (final (x, y) in const [
            (50, 50),
            (500, 50),
            (500, 500),
            (50, 500)
          ])
            at(editorChairPlacement
                .transformPoint(Vector2(x.toDouble(), y.toDouble()))),
        ];
        final minX = corners.map((p) => p.dx).reduce(math.min);
        final maxX = corners.map((p) => p.dx).reduce(math.max);
        final minY = corners.map((p) => p.dy).reduce(math.min);
        return Offset((minX + maxX) / 2, minY - 24);
      }

      final m = c.camera.value.worldToScreenMatrix;
      expect(c.grips.hitsRotationGrip(grip() - canvasOrigin(tester), m), isTrue,
          reason: 'premise: the rotation grip');
      double turn() => degreesOf((d.tree[chair]! as InstanceNode).transform);
      final turnBefore = turn();
      final before = encoded(c);
      await drag(tester, grip(), grip() + const Offset(120, 60),
          before: () => setPermissions(tester, c, P.unitsOnly));
      expect(encoded(c), before);
      expect(c.canUndo.value, isFalse);
      // The control.
      await setPermissions(tester, c, P.full);
      await click(tester, at(onChair));
      expect(selected(c).single.target, chair);
      await drag(tester, grip(), grip() + const Offset(120, 60));
      expect(turn(), isNot(closeTo(turnBefore, 1)));
    });

    testWidgets(
        'R-3 tablesOnly.copyWith(delete: false), 1 selected: Delete and '
        'Backspace remove nothing, while a body drag still moves 1',
        (tester) async {
      final c = await mountUnitEditor(tester,
          permissions: P.unitsOnly.copyWith(delete: false));
      await click(tester, screenOf(tester, c, topOf(c, '1')));
      expect(selected(c), {keyOf(c, '1')});
      final before = encoded(c);
      await press(tester, LogicalKeyboardKey.delete);
      await press(tester, LogicalKeyboardKey.backspace);
      expect(encoded(c), before);
      expect(unitsIn(c).withLabel('1'), hasLength(1));
      final centre = centreOf(c, '1');
      final from = screenOf(tester, c, topOf(c, '1'));
      await drag(tester, from, from + const Offset(80, -40));
      expect(centreOf(c, '1').distanceTo(centre), greaterThan(100));
    });

    testWidgets(
        'R-5 tablesOnly: a mouse click 3 px outside 1\'s box selects 1 (the '
        'index pick\'s 6 px tolerance), one 15 px outside it nothing',
        (tester) async {
      final c = await mountUnitEditor(tester, permissions: P.unitsOnly);
      final scale = c.camera.value.scale;
      // Beyond the box's right edge (x 1,100) on its local x axis.
      Offset outside(double px) =>
          screenOf(tester, c, onTable(c, '1', 1100 + px / scale, 100));
      await click(tester, outside(15));
      expect(selected(c), isEmpty, reason: '15 px');
      await click(tester, outside(3));
      expect(selected(c), {keyOf(c, '1')}, reason: '3 px');
    });

    testWidgets(
        'R-4 tablesOnly: a finger within its reach of the locked L, outside '
        'L\'s box, selects nothing; at the same offset from 1 it selects 1',
        (tester) async {
      final c = await mountUnitEditor(tester, permissions: P.unitsOnly);
      // 40 mm (about 15 px) beyond each box on its local x axis: within a
      // finger's 24 px, beyond a mouse's 6; every other table is farther.
      await fingerTap(tester, screenOf(tester, c, onTable(c, 'L', 1140, 100)));
      expect(selected(c), isEmpty, reason: 'L, locked: never by reach');
      await fingerTap(tester, screenOf(tester, c, onTable(c, '1', 1140, 100)));
      expect(selected(c), {keyOf(c, '1')}, reason: 'the control');
    });
  });

  // 2b Task 9: editor_select_test.dart's T5-c and T5-d, over the unit API
  // (setUnitData, unitDetails, editorSelectedUnits).
  group('delete (T5-c)', () {
    testWidgets(
        'T5-c readOnly: Delete removes nothing; tablesOnly: Delete removes '
        '1 and its data, and Undo restores both', (tester) async {
      final c = await mountUnitEditor(tester, permissions: P.readOnly);
      expect(c.setUnitData('1', const {'pos': 'a1'}), isTrue,
          reason: 'a host call under readOnly (V-5)');
      Map<String, String>? dataOf1() =>
          c.unitDetails.where((d) => d.unit.label == '1').firstOrNull?.data;
      expect(dataOf1(), const {'pos': 'a1'});
      await click(tester, screenOf(tester, c, edgeOf(c, '1')));
      expect(selected(c), {keyOf(c, '1')});
      final before = encoded(c);
      await press(tester, LogicalKeyboardKey.delete);
      await press(tester, LogicalKeyboardKey.backspace);
      expect(encoded(c), before);
      await setPermissions(tester, c, P.unitsOnly);
      await click(tester, screenOf(tester, c, topOf(c, '1')));
      expect(selected(c), {keyOf(c, '1')});
      await press(tester, LogicalKeyboardKey.delete);
      expect(unitsIn(c).withLabel('1'), isEmpty);
      expect(dataOf1(), isNull);
      c.undo();
      await tester.pump();
      expect(unitsIn(c).withLabel('1'), hasLength(1));
      expect(dataOf1(), const {'pos': 'a1'});
    });
  });

  group('a change across a selection (S-9 g, T5-d)', () {
    testWidgets(
        'T5-d full, a wall and 1 selected, then tablesOnly: the selection '
        'holds 1 alone, and Delete removes 1 only', (tester) async {
      final c = await mountUnitEditor(tester);
      final d = c.document;
      // The north wall's stand-in: the root-level line from
      // editorNorthWall's first point (today's first WallParams object).
      final north = [
        for (final slot in d.entities.liveSlots)
          if (d.entities.kindAt(slot) == EntityKind.line &&
              d.entities.ownerAt(slot) == d.rootHandle &&
              startOf(d, d.entities.handleAt(slot)) == editorNorthWall.$1)
            d.entities.handleAt(slot),
      ].single;
      final wall = SelectionKey.root(north);
      c.selection.replace([wall, keyOf(c, '1')]);
      await tester.pump();
      final tables = c.editorSelectedUnits.value;
      await setPermissions(tester, c, P.unitsOnly);
      expect(selected(c), {keyOf(c, '1')});
      expect(c.editorSelectedUnits.value, tables, reason: 'no table left it');
      // The canvas has the focus; Delete reaches the select tool.
      await press(tester, LogicalKeyboardKey.delete);
      expect(unitsIn(c).withLabel('1'), isEmpty);
      expect(isLine(d, wall.target), isTrue);
    });
  });
}
