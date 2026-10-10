// Host embedding API spec C-5's select tool (Slice 4 plan, Task 5; S-9 a g
// h, S-15): the gates the shell builds from the capabilities, on the
// select tool and the grip cache -- `selectTablesOnly`'s pick (the table
// picker: a top, else a box, a finger's reach; a locked table passed over)
// and band, `move`, `rotate`, `reshape`, `delete`, the selection pruned on
// a change to tables only and a drag whose gate closes before its up.
// Through `FloorPlanView` on the editor fixture under `editorCamera()`,
// with `editor_tools_test.dart`'s host and helpers; screen points come
// from the camera's forward transform.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show GripCache, InteractionLayer, SelectionKey;
import 'package:jet_cad_floor_plan/editor.dart'
    show PlannerView, WallParams, liveObjectsOf;
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'editor_fixture.dart';
import 'editor_tools_test.dart' as t;

typedef Caps = FloorPlanEditorCapabilities;

/// The design's encoding: byte-identical means no edit.
String encoded(FloorPlanController c) =>
    DraftDocumentCodec.encodeToString(c.activeDocument);

/// Table [n]'s instance in the active plan. `7` and ` 7 ` share a number
/// (a label's text is trimmed); ` 7 ` is the later, by placement.
Handle tableOf(FloorPlanController c, String n) {
  final tables = TableSurvey.of(c.activeDocument).withNumber(n);
  return tables[n == ' 7 ' ? 1 : 0].instance;
}

/// Table [n]'s root key.
SelectionKey keyOf(FloorPlanController c, String n) =>
    SelectionKey.root(tableOf(c, n));

/// Table [n]'s transform.
Transform2 transformOf(FloorPlanController c, String n) =>
    (c.activeDocument.tree[tableOf(c, n)]! as InstanceNode).transform;

/// [local], in table [n]'s definition space, in the world.
Vector2 onTable(FloorPlanController c, String n, double x, double y) =>
    transformOf(c, n).transformPoint(Vector2(x, y));

/// A point inside table [n]'s top, away from its lines (the top is the
/// quadrilateral (300, -200), (1100, -200), (900, 400), (300, 250)).
Vector2 topOf(FloorPlanController c, String n) => onTable(c, n, 500, 0);

/// A point inside table [n]'s box, off its top: beyond the top's slanted
/// edge from (1100, -200) to (900, 400).
Vector2 boxOf(FloorPlanController c, String n) => onTable(c, n, 1050, 350);

/// A point on table [n]'s top's bottom edge: where the index's own pick
/// (no `selectTablesOnly`) finds the table, over the parquet.
Vector2 edgeOf(FloorPlanController c, String n) => onTable(c, n, 700, -200);

/// The world ends of wall [w].
(Vector2, Vector2) wallEnds(DraftDocument d, Handle w) {
  final p = d.components.get<WallParams>(w)!;
  final m = d.tree.accumulatedTransform(w);
  return (m.transformPoint(p.start), m.transformPoint(p.end));
}

/// The selection's keys.
Set<SelectionKey> selected(FloorPlanController c) =>
    {...c.activeSelection.keys};

/// The view's grip cache.
GripCache gripsOf(WidgetTester tester) =>
    tester.widget<PlannerView>(find.byType(PlannerView)).grips!;

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

/// The rotation grip's centre for table [n] alone selected (render spec
/// D6, the frame the world box): the screen box of its top's four corners
/// (its whole drawing; the number sits inside), its top edge's middle,
/// 24 px up.
Offset rotationGripOf(WidgetTester tester, FloorPlanController c, String n) {
  final corners = [
    for (final (x, y) in const [
      (300, -200),
      (1100, -200),
      (900, 400),
      (300, 250)
    ])
      t.screenOf(tester, c, onTable(c, n, x.toDouble(), y.toDouble())),
  ];
  final minX = corners.map((p) => p.dx).reduce(math.min);
  final maxX = corners.map((p) => p.dx).reduce(math.max);
  final minY = corners.map((p) => p.dy).reduce(math.min);
  return Offset((minX + maxX) / 2, minY - 24);
}

/// The turn of [m], in degrees.
double degreesOf(Transform2 m) => math.atan2(m.b, m.a) * 180 / math.pi;

/// The bands' corners: the whole canvas, inset 4 px; and a strip across
/// the north wall holding `1`, `2` and the chair.
Rect canvasRect(WidgetTester tester) =>
    tester.getRect(find.byType(InteractionLayer)).deflate(4);

Future<void> setCaps(WidgetTester tester, t.EditorHost h, Caps caps) async {
  h.caps.value = caps;
  await tester.pump();
}

void main() {
  group('selectTablesOnly (M-H42, S-15)', () {
    testWidgets(
        'M-H42 tablesOnly: a window and a crossing band over the whole '
        'canvas (walls, rooms and their edges, the dimension, the free '
        'line, the group, the TEXT, the chair, every table) select exactly '
        'the five visible unlocked tables; a crossing band over the north '
        'wall, its room edge, the chair and 1 and 2 selects exactly 1 and 2; '
        'one over the group, the free line and the TEXT selects nothing',
        (tester) async {
      final h = await t.mountEditor(tester, caps: Caps.tablesOnly);
      final c = h.c;
      final tables = {
        for (final n in ['1', '2', '7', ' 7 ']) keyOf(c, n),
        SelectionKey.root(TableSurvey.of(c.activeDocument)
            .tables
            .singleWhere((x) => x.number == null)
            .instance),
      };
      final r = canvasRect(tester);
      // A window band (left to right) and a crossing band (right to left).
      await drag(tester, r.topLeft, r.bottomRight);
      expect(selected(c), tables, reason: 'the window band');
      c.activeSelection.clear();
      await tester.pump();
      await drag(tester, r.bottomRight, r.topLeft);
      expect(selected(c), tables, reason: 'the crossing band');
      c.activeSelection.clear();
      await tester.pump();
      // North: y 15,740..16,900 crosses the north wall and its inner face
      // (16,750), the parquet, the chair and 1 and 2, x 21,450..24,450.
      await drag(tester, t.screenOf(tester, c, Vector2(24450, 16900)),
          t.screenOf(tester, c, Vector2(21450, 15740)));
      expect(selected(c), {keyOf(c, '1'), keyOf(c, '2')},
          reason: 'the north strip');
      c.activeSelection.clear();
      await tester.pump();
      // South-west: the group, the free line and the TEXT, no table.
      await drag(tester, t.screenOf(tester, c, Vector2(23400, 14600)),
          t.screenOf(tester, c, Vector2(21450, 13250)));
      expect(selected(c), isEmpty, reason: 'the south-west strip');
    });

    testWidgets(
        'M-H42 S-15 a click on a wall line, the free line or the TEXT '
        'selects nothing under tablesOnly; a click inside 1\'s top away '
        'from its lines selects 1, though the topmost hit there is a '
        'parquet hairline (under full the same click selects the hairline); '
        'inside its box off its top too', (tester) async {
      final h = await t.mountEditor(tester);
      final c = h.c;
      // The control under full: the engine's topmost hit inside 1's top is
      // not 1 (S-15: a filter after it would lose the table).
      await t.click(tester, t.screenOf(tester, c, topOf(c, '1')));
      expect(selected(c), hasLength(1));
      expect(selected(c).single, isNot(keyOf(c, '1')));
      await t.click(tester, t.screenOf(tester, c, Vector2(22000, 16850)));
      expect(selected(c), hasLength(1), reason: 'the north wall, under full');
      final wall = selected(c).single;
      expect(
          c.activeDocument.components.get<WallParams>(wall.target), isNotNull);
      await setCaps(tester, h, Caps.tablesOnly);
      expect(selected(c), isEmpty, reason: 'pruned (S-9 g)');
      for (final (what, w) in [
        ('the north wall', Vector2(22000, 16850)),
        ('the column', Vector2(23500, 14000)),
        ('the free line', Vector2(23000, 13850)),
        ('the TEXT', Vector2(21750, 14300)),
      ]) {
        await t.click(tester, t.screenOf(tester, c, w));
        expect(selected(c), isEmpty, reason: what);
      }
      await t.click(tester, t.screenOf(tester, c, topOf(c, '1')));
      expect(selected(c), {keyOf(c, '1')}, reason: 'inside the top');
      c.activeSelection.clear();
      await tester.pump();
      await t.click(tester, t.screenOf(tester, c, boxOf(c, '2')));
      expect(selected(c), {keyOf(c, '2')}, reason: 'inside the box');
    });

    testWidgets(
        'S-15 a finger reaches a table within its reach under tablesOnly; a '
        'mouse click at the same point selects nothing', (tester) async {
      final h = await t.mountEditor(tester, caps: Caps.tablesOnly);
      final c = h.c;
      // 40 mm (about 15 px) beyond 1's box, on its local x axis; 2's box
      // is over 300 mm away.
      final near = t.screenOf(tester, c, onTable(c, '1', 1140, 100));
      await t.click(tester, near);
      expect(selected(c), isEmpty, reason: 'the mouse');
      await fingerTap(tester, near);
      expect(selected(c), {keyOf(c, '1')}, reason: 'the finger');
    });

    testWidgets(
        'the tables on the hidden and the locked layers are never selected, '
        'by a click or a band; a locked table is passed over, so the table '
        'under it answers', (tester) async {
      final h = await t.mountEditor(tester, caps: Caps.tablesOnly);
      final c = h.c;
      final d = c.activeDocument;
      final hidden = TableSurvey.of(d).withNumber('5').single;
      final hiddenAt = (d.tree[hidden.instance]! as InstanceNode)
          .transform
          .transformPoint(Vector2(500, 0));
      await t.click(tester, t.screenOf(tester, c, hiddenAt));
      expect(selected(c), isEmpty, reason: '5, hidden');
      await t.click(tester, t.screenOf(tester, c, topOf(c, 'L')));
      expect(selected(c), isEmpty, reason: 'L, locked');
      final r = canvasRect(tester);
      await drag(tester, r.bottomRight, r.topLeft);
      expect(selected(c).map((k) => k.target),
          isNot(anyOf(contains(tableOf(c, 'L')), contains(hidden.instance))));
      c.activeSelection.clear();
      await tester.pump();
      // ` 7 ` (a lower handle than L, so drawn under it) moved under L.
      d.commands.execute(
          TransformNodeCommand(tableOf(c, ' 7 '), transformOf(c, 'L')));
      await tester.pump();
      await t.click(tester, t.screenOf(tester, c, topOf(c, 'L')));
      expect(selected(c), {keyOf(c, ' 7 ')});
    });
  });

  group('move, rotate, delete (T5-a, T5-b, T5-c)', () {
    testWidgets(
        'T5-a readOnly: a body drag of 1 executes nothing; tablesOnly: it '
        'moves 1 by the drag', (tester) async {
      final h = await t.mountEditor(tester, caps: Caps.readOnly);
      final c = h.c;
      final before = encoded(c);
      // readOnly picks by the index: the top's inside is a hairline; the
      // table is clicked and pressed on its top's bottom edge.
      final edge = t.screenOf(tester, c, edgeOf(c, '1'));
      await t.click(tester, edge);
      expect(selected(c), {keyOf(c, '1')}, reason: 'selectable');
      await drag(tester, edge, edge + const Offset(80, -40));
      expect(encoded(c), before, reason: 'readOnly');
      expect(c.canUndo.value, isFalse);
      await setCaps(tester, h, Caps.tablesOnly);
      final centre = t.centreOf(c, '1');
      final from = t.screenOf(tester, c, topOf(c, '1'));
      await drag(tester, from, from + const Offset(80, -40));
      final moved = t.centreOf(c, '1') - centre;
      // 80 px right and 40 px up at 0.37 px/mm, y up; the table attaches
      // to no wall here (a table's box is not tagged), so the move is exact
      // up to the grid's 50 mm snap.
      expect(moved.x, closeTo(80 / 0.37, 50));
      expect(moved.y, closeTo(40 / 0.37, 50));
    });

    testWidgets(
        'T5-b readOnly: 1 selected shows no rotation grip, no ±90, and a '
        'read-only Rotation field whose typed value does not commit; a drag '
        'at the grip\'s place turns nothing. tablesOnly: the grip turns it',
        (tester) async {
      final h = await t.mountEditor(tester, caps: Caps.readOnly);
      final c = h.c;
      c.activeSelection.replace([keyOf(c, '1')]);
      await tester.pump();
      final before = encoded(c);
      expect(gripsOf(tester).rotatable, isFalse);
      expect(t.byKey('table-rotate-left'), findsNothing);
      expect(t.byKey('table-rotate-right'), findsNothing);
      final field = tester.widget<TextField>(t.byKey('symbol-rotation'));
      expect(field.readOnly, isTrue);
      await tester.tap(t.byKey('symbol-rotation'));
      await tester.pump();
      field.controller!.text = '75';
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(encoded(c), before, reason: 'the typed value');
      final grip = rotationGripOf(tester, c, '1');
      await drag(tester, grip, grip + const Offset(120, 60));
      expect(encoded(c), before, reason: 'the grip\'s place');
      await setCaps(tester, h, Caps.tablesOnly);
      c.activeSelection.replace([keyOf(c, '1')]);
      await tester.pump();
      expect(gripsOf(tester).rotatable, isTrue);
      expect(t.byKey('table-rotate-left'), findsOneWidget);
      expect(tester.widget<TextField>(t.byKey('symbol-rotation')).readOnly,
          isFalse);
      final turn = degreesOf(transformOf(c, '1'));
      // The left column came back: the canvas moved on the screen.
      final grip2 = rotationGripOf(tester, c, '1');
      await drag(tester, grip2, grip2 + const Offset(120, 60));
      expect(degreesOf(transformOf(c, '1')), isNot(closeTo(turn, 1)));
    });

    testWidgets(
        'T5-c readOnly: Delete removes nothing; tablesOnly: Delete removes '
        '1 and its data, and Undo restores both', (tester) async {
      final h = await t.mountEditor(tester, caps: Caps.readOnly);
      final c = h.c;
      expect(c.setTableData('1', const {'pos': 'a1'}), isTrue,
          reason: 'a host call under readOnly (V-5)');
      Map<String, String>? dataOf1() =>
          c.tableDetails.where((d) => d.table.number == '1').firstOrNull?.data;
      expect(dataOf1(), const {'pos': 'a1'});
      await t.click(tester, t.screenOf(tester, c, edgeOf(c, '1')));
      expect(selected(c), {keyOf(c, '1')});
      final before = encoded(c);
      await t.press(tester, LogicalKeyboardKey.delete);
      await t.press(tester, LogicalKeyboardKey.backspace);
      expect(encoded(c), before);
      await setCaps(tester, h, Caps.tablesOnly);
      await t.click(tester, t.screenOf(tester, c, topOf(c, '1')));
      expect(selected(c), {keyOf(c, '1')});
      await t.press(tester, LogicalKeyboardKey.delete);
      expect(TableSurvey.of(c.activeDocument).withNumber('1'), isEmpty);
      expect(dataOf1(), isNull);
      c.undo();
      await tester.pump();
      expect(TableSurvey.of(c.activeDocument).withNumber('1'), hasLength(1));
      expect(dataOf1(), const {'pos': 'a1'});
    });
  });

  group('a change across a selection or a drag (S-9 g, h)', () {
    testWidgets(
        'T5-d full, a wall and 1 selected, then tablesOnly: the selection '
        'holds 1 alone, and Delete removes 1 only', (tester) async {
      final h = await t.mountEditor(tester);
      final c = h.c;
      final d = c.activeDocument;
      final wall = SelectionKey.root(liveObjectsOf<WallParams>(d).first);
      c.activeSelection.replace([wall, keyOf(c, '1')]);
      await tester.pump();
      final tables = c.selectedTables.value;
      await setCaps(tester, h, Caps.tablesOnly);
      expect(selected(c), {keyOf(c, '1')});
      expect(c.selectedTables.value, tables, reason: 'no table left it');
      // The canvas has the focus; Delete reaches the select tool.
      await t.press(tester, LogicalKeyboardKey.delete);
      expect(TableSurvey.of(d).withNumber('1'), isEmpty);
      expect(liveObjectsOf<WallParams>(d), contains(wall.target));
    });

    testWidgets(
        'S-9 h a body drag of 1 started under tablesOnly and switched to '
        'move: false before its up executes nothing; kept under tablesOnly '
        'it moves 1', (tester) async {
      final h = await t.mountEditor(tester, caps: Caps.tablesOnly);
      final c = h.c;
      final from = t.screenOf(tester, c, topOf(c, '1'));
      final before = encoded(c);
      await drag(tester, from, from + const Offset(80, -40),
          before: () =>
              setCaps(tester, h, Caps.tablesOnly.copyWith(move: false)));
      expect(encoded(c), before);
      expect(c.canUndo.value, isFalse);
      await setCaps(tester, h, Caps.tablesOnly);
      await drag(tester, from, from + const Offset(80, -40));
      expect(encoded(c), isNot(before));
      expect(c.canUndo.value, isTrue);
    });
  });

  group('reshape (M-H43c)', () {
    testWidgets(
        'M-H43c full.copyWith(reshape: false): the free line selected shows '
        'no stretch grip and its end is not hit; a drag from its end never '
        'reshapes it (the press falls to its body: it moves whole); a wall\'s '
        'end grip the same; with move false too the document is unchanged; '
        'under full both reshape', (tester) async {
      final h =
          await t.mountEditor(tester, caps: Caps.full.copyWith(reshape: false));
      final c = h.c;
      final d = c.activeDocument;
      double lineLength() {
        final (a, b) = t.newestLine(d);
        return (b - a).length;
      }

      // The column: a 400 mm wall from (23,500, 14,000) to (23,900,
      // 14,000); its start lies on its west face.
      final column = liveObjectsOf<WallParams>(d).singleWhere(
          (w) => wallEnds(d, w).$1.distanceTo(Vector2(23500, 14000)) < 1);
      double wallLength() {
        final (a, b) = wallEnds(d, column);
        return (b - a).length;
      }

      // Each read where the line and the wall are now.
      Offset lineEnd() => t.screenOf(tester, c, t.newestLine(d).$1);
      Offset wallEnd() => t.screenOf(tester, c, wallEnds(d, column).$1);
      Future<void> selectLine() async {
        final (a, b) = t.newestLine(d);
        await t.click(tester, t.screenOf(tester, c, (a + b) / 2));
        expect(selected(c), hasLength(1));
      }

      await selectLine();
      final grips = gripsOf(tester);
      expect(grips.leafGripsLive, isTrue);
      expect(grips.stretchGripsLive, isFalse);
      final m = c.cameraController.value.worldToScreenMatrix;
      expect(grips.hitTest(lineEnd() - t.canvasOrigin(tester), m), -1);
      final length = lineLength();
      final start = t.newestLine(d).$1.clone();
      await drag(tester, lineEnd(), lineEnd() + const Offset(60, 30));
      expect(lineLength(), closeTo(length, 1e-6), reason: 'no reshape');
      expect(t.newestLine(d).$1, isNot(start), reason: 'a body move');
      await t.click(tester, wallEnd());
      expect(selected(c).single.target, column);
      final wallBefore = wallLength();
      await drag(tester, wallEnd(), wallEnd() + const Offset(-60, 0));
      expect(wallLength(), closeTo(wallBefore, 1e-6), reason: 'no reshape');
      // With move false too, nothing at all.
      await setCaps(tester, h, Caps.full.copyWith(reshape: false, move: false));
      await selectLine();
      final before = encoded(c);
      await drag(tester, lineEnd(), lineEnd() + const Offset(60, 30));
      expect(encoded(c), before);
      await t.click(tester, wallEnd());
      await drag(tester, wallEnd(), wallEnd() + const Offset(-60, 0));
      expect(encoded(c), before);
      // Under full, both reshape.
      await setCaps(tester, h, Caps.full);
      await selectLine();
      expect(gripsOf(tester).stretchGripsLive, isTrue);
      await drag(tester, lineEnd(), lineEnd() + const Offset(60, 30));
      expect(lineLength(), isNot(closeTo(length, 1)));
      await t.click(tester, wallEnd());
      await drag(tester, wallEnd(), wallEnd() + const Offset(-60, 0));
      expect(wallLength(), isNot(closeTo(wallBefore, 1)));
    });

    testWidgets(
        'a runtime change reaches the grips at once (gatesChanged): the '
        'free line\'s end grip hot under the mouse, then reshape false: the '
        'hot grip is reset and the overlay told, with no pointer event',
        (tester) async {
      final h = await t.mountEditor(tester);
      final c = h.c;
      final (a, b) = t.newestLine(c.activeDocument);
      await t.click(tester, t.screenOf(tester, c, (a + b) / 2));
      final g = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
      final end = t.screenOf(tester, c, a);
      await g.addPointer(location: end - const Offset(3, 3));
      await g.moveTo(end);
      await tester.pump();
      final grips = gripsOf(tester);
      expect(grips.hot, isNot(-1), reason: 'the end grip under the mouse');
      var told = 0;
      void tell() => told++;
      grips.addListener(tell);
      addTearDown(() => grips.removeListener(tell));
      await setCaps(tester, h, Caps.full.copyWith(reshape: false));
      expect(grips.hot, -1);
      expect(told, greaterThan(0));
      await g.removePointer();
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
      final h = await t.mountEditor(tester);
      final c = h.c;
      final d = c.activeDocument;
      Offset at(Vector2 w) => t.screenOf(tester, c, w);
      await t.click(tester, at(northWall));
      final wall = selected(c).single.target;
      expect(liveObjectsOf<WallParams>(d), contains(wall),
          reason: 'premise: the wall selected');
      final before = encoded(c);
      final ends = wallEnds(d, wall);
      await drag(tester, at(northWall), at(northWall) + const Offset(0, -60),
          before: () => setCaps(tester, h, Caps.tablesOnly));
      expect(encoded(c), before);
      expect(c.canUndo.value, isFalse);
      expect(selected(c), isEmpty, reason: 'pruned (S-9 g)');
      // The control: the same drag under full moves the wall.
      await setCaps(tester, h, Caps.full);
      await t.click(tester, at(northWall));
      expect(selected(c).single.target, wall);
      await drag(tester, at(northWall), at(northWall) + const Offset(0, -60));
      expect(wallEnds(d, wall).$1, isNot(ends.$1));
      expect(c.canUndo.value, isTrue);
    });

    testWidgets(
        "R-1 the chair turned by its rotation grip, started under full, the "
        'host switching to tablesOnly before its up: cancelled, the design '
        'byte-identical; kept under full the same drag turns it',
        (tester) async {
      final h = await t.mountEditor(tester);
      final c = h.c;
      final d = c.activeDocument;
      Offset at(Vector2 w) => t.screenOf(tester, c, w);
      // The chair's outline at local (50, 275).
      final onChair = editorChairPlacement.transformPoint(Vector2(50, 275));
      await t.click(tester, at(onChair));
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

      final m = c.cameraController.value.worldToScreenMatrix;
      expect(
          gripsOf(tester).hitsRotationGrip(grip() - t.canvasOrigin(tester), m),
          isTrue,
          reason: 'premise: the rotation grip');
      double turn() => degreesOf((d.tree[chair]! as InstanceNode).transform);
      final turnBefore = turn();
      final before = encoded(c);
      await drag(tester, grip(), grip() + const Offset(120, 60),
          before: () => setCaps(tester, h, Caps.tablesOnly));
      expect(encoded(c), before);
      expect(c.canUndo.value, isFalse);
      // The control.
      await setCaps(tester, h, Caps.full);
      await t.click(tester, at(onChair));
      expect(selected(c).single.target, chair);
      await drag(tester, grip(), grip() + const Offset(120, 60));
      expect(turn(), isNot(closeTo(turnBefore, 1)));
    });

    testWidgets(
        'R-1 a gate closed mid-drag cancels the drag at once: reopened before '
        'the up, a body drag, a rotation-grip drag and an end-grip drag each '
        'execute nothing; never closed, each executes', (tester) async {
      final h = await t.mountEditor(tester);
      final c = h.c;
      final d = c.activeDocument;
      Offset at(Vector2 w) => t.screenOf(tester, c, w);
      // The column: a 400 mm wall whose start lies at (23,500, 14,000).
      final column = liveObjectsOf<WallParams>(d).singleWhere(
          (w) => wallEnds(d, w).$1.distanceTo(Vector2(23500, 14000)) < 1);
      final cases = <(String, Caps, Future<Offset> Function())>[
        (
          'move',
          Caps.full.copyWith(move: false),
          () async {
            c.activeSelection.replace([keyOf(c, '1')]);
            await tester.pump();
            return at(edgeOf(c, '1'));
          }
        ),
        (
          'rotate',
          Caps.full.copyWith(rotate: false),
          () async {
            c.activeSelection.replace([keyOf(c, '1')]);
            await tester.pump();
            return rotationGripOf(tester, c, '1');
          }
        ),
        (
          'reshape',
          Caps.full.copyWith(reshape: false),
          () async {
            c.activeSelection.replace([SelectionKey.root(column)]);
            await tester.pump();
            return at(wallEnds(d, column).$1);
          }
        ),
      ];
      for (final (name, closed, press) in cases) {
        final before = encoded(c);
        final depth = d.commands.undoDepth;
        final from = await press();
        await drag(tester, from, from + const Offset(60, -30),
            before: () async {
          await setCaps(tester, h, closed);
          await setCaps(tester, h, Caps.full);
        });
        expect(encoded(c), before, reason: '$name: closed, then reopened');
        expect(d.commands.undoDepth, depth, reason: name);
        // The control: the same drag, its gate never closed.
        final again = await press();
        await drag(tester, again, again + const Offset(60, -30));
        expect(d.commands.undoDepth, depth + 1, reason: '$name: the control');
      }
    });

    testWidgets(
        'R-3 tablesOnly.copyWith(delete: false), 1 selected: Delete and '
        'Backspace remove nothing, while a body drag still moves 1',
        (tester) async {
      final h = await t.mountEditor(tester,
          caps: Caps.tablesOnly.copyWith(delete: false));
      final c = h.c;
      await t.click(tester, t.screenOf(tester, c, topOf(c, '1')));
      expect(selected(c), {keyOf(c, '1')});
      final before = encoded(c);
      await t.press(tester, LogicalKeyboardKey.delete);
      await t.press(tester, LogicalKeyboardKey.backspace);
      expect(encoded(c), before);
      expect(TableSurvey.of(c.activeDocument).withNumber('1'), hasLength(1));
      final centre = t.centreOf(c, '1');
      final from = t.screenOf(tester, c, topOf(c, '1'));
      await drag(tester, from, from + const Offset(80, -40));
      expect(t.centreOf(c, '1').distanceTo(centre), greaterThan(100));
    });

    testWidgets(
        'R-5 tablesOnly: a mouse click 3 px outside 1\'s box selects 1 (the '
        'index pick\'s 6 px tolerance), one 15 px outside it nothing',
        (tester) async {
      final h = await t.mountEditor(tester, caps: Caps.tablesOnly);
      final c = h.c;
      final scale = c.cameraController.value.scale;
      // Beyond the box's right edge (x 1,100) on its local x axis.
      Offset outside(double px) =>
          t.screenOf(tester, c, onTable(c, '1', 1100 + px / scale, 100));
      await t.click(tester, outside(15));
      expect(selected(c), isEmpty, reason: '15 px');
      await t.click(tester, outside(3));
      expect(selected(c), {keyOf(c, '1')}, reason: '3 px');
    });

    testWidgets(
        'R-4 tablesOnly: a finger within its reach of the locked L, outside '
        'L\'s box, selects nothing; at the same offset from 1 it selects 1',
        (tester) async {
      final h = await t.mountEditor(tester, caps: Caps.tablesOnly);
      final c = h.c;
      // 40 mm (about 15 px) beyond each box on its local x axis: within a
      // finger's 24 px, beyond a mouse's 6; every other table is farther.
      await fingerTap(
          tester, t.screenOf(tester, c, onTable(c, 'L', 1140, 100)));
      expect(selected(c), isEmpty, reason: 'L, locked: never by reach');
      await fingerTap(
          tester, t.screenOf(tester, c, onTable(c, '1', 1140, 100)));
      expect(selected(c), {keyOf(c, '1')}, reason: 'the control');
    });
  });
}
