// Ported from jet_cad_floor_plan/test/planner_shell_test.dart (3a Task 26, spec C6); assertions unchanged.
//
// The three sample-flat cases: a click on a wall selects it, cmd+Z undoes
// a Delete, ctrl+Z after deleting two walls brings both back in one step.
// The shell is the plan library's PlanEditor over sampleFlatController(),
// at 1440 x 900 (ruling IT-R4: PlanEditor's columns would leave a 280 px
// canvas at flutter_test's 800 x 600); the first fit is the page's, as
// today's shell's.
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer, SelectionKey;
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/canvas_rig.dart' show pumpPlanEditor;
import '../support/plans.dart'
    show kPlanHeight, kPlanOriginX, kPlanOriginY, kPlanWidth, kids;

/// The sample plan's wall whose stored start is (`sx`, `sy`) and end is
/// (`ex`, `ey`) (spec 08 D18's table).
Handle wallFrom(
        DraftDocument doc, double sx, double sy, double ex, double ey) =>
    doc.components.withComponent<WallParams>().singleWhere((w) {
      final p = doc.components.get<WallParams>(w)!;
      return p.sx == sx && p.sy == sy && p.ex == ex && p.ey == ey;
    });

/// E1, the south exterior wall, and E4, the west one (spec 08 D18).
Handle e1Of(DraftDocument doc) => wallFrom(doc, kPlanOriginX + 125,
    kPlanOriginY + 125, kPlanOriginX + kPlanWidth - 125, kPlanOriginY + 125);
Handle e4Of(DraftDocument doc) => wallFrom(doc, kPlanOriginX + 125,
    kPlanOriginY + kPlanHeight - 125, kPlanOriginX + 125, kPlanOriginY + 125);

/// [wall]'s openings, ascending.
List<Handle> openingsOf(DraftDocument doc, Handle wall) => [
      for (final o in doc.components.withComponent<OpeningParams>())
        if (doc.components.get<OpeningParams>(o)!.host == wall) o
    ]..sort((a, b) => a.value.compareTo(b.value));

/// The sample plan's rooms named [names] (spec 10 D23), in that order.
List<Handle> roomsNamed(DraftDocument doc, List<String> names) => [
      for (final name in names)
        doc.components.withComponent<RoomParams>().singleWhere(
            (r) => doc.components.get<RoomParams>(r)!.name == name),
    ];

/// The dimensions measuring [wall], ascending: a dimension references the
/// walls of its attached ends (today's DimensionType.references,
/// jet_cad_floor_plan/lib/src/parametric/dimension.dart:150).
List<Handle> dimensionsOn(DraftDocument doc, Handle wall) => [
      for (final d in doc.components.withComponent<DimensionParams>())
        if ([
          for (final end in [
            doc.components.get<DimensionParams>(d)!.a,
            doc.components.get<DimensionParams>(d)!.b,
          ])
            if (end is AttachedEnd) end.wall
        ].contains(wall))
          d
    ]..sort((a, b) => a.value.compareTo(b.value));

/// Every live entity handle, ascending.
List<Handle> liveHandles(DraftDocument doc) => [
      for (final slot in doc.entities.liveSlots) doc.entities.handleAt(slot)
    ]..sort((a, b) => a.value.compareTo(b.value));

/// The lowest y of [wall]'s piece outlines: `y0` at a mitred south corner,
/// `y0 + 125` at a square end on E1's centreline.
double lowestY(DraftDocument doc, Handle wall) {
  var y = double.infinity;
  for (final k in kids(doc, wall)) {
    final slot = doc.entities.slotOf(k)!;
    if (doc.entities.kindAt(slot) != EntityKind.polyline) continue;
    final p = doc.geometry.read(doc.entities.geomIndexAt(slot));
    for (var i = 0; i < p.pointCount; i++) {
      if (p.pointAt(i).y < y) y = p.pointAt(i).y;
    }
  }
  return y;
}

/// The plan library's editor over the sample flat (spec 3a C3.7, C1.9),
/// 1440 x 900 (ruling IT-R4); the controller is disposed at tear-down.
Future<PlanController> pumpSample(WidgetTester tester) async {
  final c = sampleFlatController();
  addTearDown(c.dispose);
  await pumpPlanEditor(tester, c);
  return c;
}

void main() {
  testWidgets('a click on a wall selects it in the running shell',
      (tester) async {
    final c = await pumpSample(tester);
    await tester.pump();

    // On E1's outer face, 3,000 mm along (spec 08 D18): the click selects
    // E1's group. Not 100 mm along: at this surface the pick radius is about
    // 366 mm, which reaches the corner where E1's and E4's centrelines end,
    // and a vertex hit outranks an edge hit, its tie going to the greater
    // handle, E4.
    final world = Vector2(kPlanOriginX + 3000, kPlanOriginY);
    final screen = c.camera.value.worldToScreen(world);
    final viewportSize = tester.getSize(find.byType(InteractionLayer));
    expect(screen.x, inInclusiveRange(0, viewportSize.width));
    expect(screen.y, inInclusiveRange(0, viewportSize.height));

    final topLeft = tester.getTopLeft(find.byType(InteractionLayer));
    await tester.tapAt(topLeft + Offset(screen.x, screen.y));
    await tester.pump();

    expect(c.activeSelection.keys, [SelectionKey.root(e1Of(c.document))]);
  });

  // A5 / spec D12: the look asks the human to delete a wall and put it back,
  // and until this binding existed the shell had no way to put it back.
  testWidgets('cmd+Z undoes a Delete through the command log', (tester) async {
    final c = await pumpSample(tester);
    await tester.pump();

    final doc = c.document;
    // E1's outer face, as the test above clicks it.
    final world = Vector2(kPlanOriginX + 3000, kPlanOriginY);
    final screen = c.camera.value.worldToScreen(world);
    final topLeft = tester.getTopLeft(find.byType(InteractionLayer));
    await tester.tapAt(topLeft + Offset(screen.x, screen.y));
    await tester.pump();

    // E1 and its front door (spec 08 D18); E2 and E4 mitre with E1 at the
    // south corners.
    final e1 = e1Of(doc);
    expect(c.activeSelection.keys, [SelectionKey.root(e1)]);
    final [door] = openingsOf(doc, e1);
    final e2 = wallFrom(
        doc,
        kPlanOriginX + kPlanWidth - 125,
        kPlanOriginY + 125,
        kPlanOriginX + kPlanWidth - 125,
        kPlanOriginY + kPlanHeight - 125);
    final e4 = e4Of(doc);
    expect(lowestY(doc, e2), kPlanOriginY, reason: 'E2 mitres with E1');
    expect(lowestY(doc, e4), kPlanOriginY, reason: 'E4 mitres with E1');
    final removed = kids(doc, e1).length + kids(doc, door).length;
    expect(removed, 6 + 2, reason: 'two pieces, and a leaf and an arc');
    // Spec 10 D8, D23: E1's inner face bounds the Hall, the Kitchen and the
    // Bath from the south; with E1 gone their faces open to the outside, so
    // they dissolve in the same step, a tint and two labels each.
    final rooms = roomsNamed(doc, ['Hall', 'Kitchen', 'Bath']);
    var dissolved = 0;
    for (final r in rooms) {
      dissolved += kids(doc, r).length;
    }
    expect(dissolved, 3 * 4, reason: 'a fill, its boundary and two TEXTs');
    // Spec 11 D17, decision 3 (Ruling 11-14, the controller's ruling): E1
    // carries three of the sample's dimensions -- the overall width, the
    // Hall and the Bath diagonal -- and deleting it cascades them in the
    // same step, six children each.
    final dims = dimensionsOn(doc, e1);
    expect(dims, hasLength(3), reason: 'the width, the Hall, the diagonal');
    for (final d in dims) {
      expect(kids(doc, d), hasLength(6), reason: 'dimension $d');
    }
    // The startup plan is itself built through the log, so the counts below
    // are what pin the undo to exactly one command: the Delete.
    final liveBefore = doc.entities.liveCount;
    final handlesBefore = liveHandles(doc);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.delete);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.delete);
    await tester.pump();

    // The door goes with its host (spec 08 D4), in the same step, and the
    // neighbours' corners square.
    expect(doc.tree[e1], isNull);
    expect(doc.tree[door], isNull, reason: 'the cascade');
    for (final r in rooms) {
      expect(doc.tree[r], isNull, reason: 'room $r dissolves (10 D8)');
    }
    expect(doc.commands.undoDepth, 1, reason: 'one step');
    for (final d in dims) {
      expect(doc.tree[d], isNull, reason: 'dimension $d cascades (11 D3)');
    }
    // The three dimensions' 3 × 6 children go too.
    expect(doc.entities.liveCount, liveBefore - removed - dissolved - 3 * 6);
    expect(lowestY(doc, e2), closeTo(kPlanOriginY + 125, 1e-9),
        reason: 'E2\'s corner squares');
    expect(lowestY(doc, e4), closeTo(kPlanOriginY + 125, 1e-9),
        reason: 'E4\'s corner squares');
    expect(c.activeSelection.isEmpty, isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    expect(doc.tree[e1], isA<GroupNode>(), reason: 'the wall is back');
    expect(doc.tree[door], isA<GroupNode>(), reason: 'its door too');
    for (final r in rooms) {
      expect(doc.tree[r], isA<GroupNode>(), reason: 'room $r is back');
    }
    for (final d in dims) {
      expect(doc.tree[d], isA<GroupNode>(), reason: 'dimension $d is back');
      expect(kids(doc, d), hasLength(6), reason: 'dimension $d');
    }
    expect(doc.entities.liveCount, liveBefore,
        reason: 'exactly one command came off the log, not the plan under it');
    expect(liveHandles(doc), handlesBefore, reason: 'every child handle');
    expect(lowestY(doc, e2), kPlanOriginY);
    expect(lowestY(doc, e4), kPlanOriginY);
    expect(c.activeSelection.isEmpty, isTrue,
        reason: 'undo replays the command log; it never restores the '
            "selection controller's own state");
  });

  testWidgets('ctrl+Z after deleting two walls brings both back in one step',
      (tester) async {
    final c = await pumpSample(tester);
    await tester.pump();

    final topLeft = tester.getTopLeft(find.byType(InteractionLayer));
    Offset at(Vector2 world) {
      final s = c.camera.value.worldToScreen(world);
      return topLeft + Offset(s.x, s.y);
    }

    // E1 and E4 (spec 08 D18), by points on their outer faces: E1's 3,000
    // mm along, as above (its mid-edge is the front door's jamb), and E4's
    // mid-edge. Each is past the pick radius (about 366 mm here) of every
    // vertex of another object: the corners, the front door
    // (x0 + 6000..7000), E4's windows (y0 + 1700..2700, y0 + 5900..7300)
    // and P2's butt (y0 + 5000), so each tap can only mean one wall. E4's
    // point holds while the pick radius (6 px) is under about 506 mm, its
    // distance to P2's nearest cap vertex (x0 + 250, y0 + 4940): that is,
    // at flutter_test's default 800 x 600 surface, not at any size.
    final doc = c.document;
    final e1 = e1Of(doc), e4 = e4Of(doc);
    final objects = [e1, e4, ...openingsOf(doc, e1), ...openingsOf(doc, e4)];
    expect(objects, hasLength(5), reason: 'a door and two windows');
    // Spec 10 D8, D23: E1 bounds the Hall, the Kitchen and the Bath, and E4
    // the Hall and Bedroom 1; with both gone those four faces open to the
    // outside, and the rooms dissolve in the same step.
    final rooms = roomsNamed(doc, ['Hall', 'Bedroom 1', 'Kitchen', 'Bath']);
    var removed = 0;
    for (final o in [...objects, ...rooms]) {
      removed += kids(doc, o).length;
    }
    // Spec 11 D17, decision 3 (Ruling 11-14, the controller's ruling): E1
    // carries three of the sample's dimensions (the overall width, the Hall
    // and the Bath diagonal), six children each, which go with it; E4
    // carries none.
    final dims = dimensionsOn(doc, e1);
    expect(dims, hasLength(3), reason: 'the width, the Hall, the diagonal');
    expect(dimensionsOn(doc, e4), isEmpty, reason: 'E4 carries none');
    for (final d in dims) {
      expect(kids(doc, d), hasLength(6), reason: 'dimension $d');
    }
    await tester.tapAt(at(Vector2(kPlanOriginX + 3000, kPlanOriginY)));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tapAt(at(Vector2(kPlanOriginX, kPlanOriginY + 4500)));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(c.activeSelection.keys.toSet(),
        {SelectionKey.root(e1), SelectionKey.root(e4)});
    // Ruling 04-1: the history is cleared at startup, so `undoDepth` here
    // would only count what happens from this point on; the live count
    // after exactly one ctrl+Z is what pins it to one entry regardless.
    final liveBefore = doc.entities.liveCount;
    final handlesBefore = liveHandles(doc);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.delete);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.delete);
    await tester.pump();

    for (final o in [...objects, ...rooms]) {
      expect(doc.tree[o], isNull, reason: 'object $o, with its wall');
    }
    expect(doc.commands.undoDepth, 1, reason: 'one step');
    for (final d in dims) {
      expect(doc.tree[d], isNull, reason: 'dimension $d cascades (11 D3)');
    }
    // The three dimensions' 3 × 6 children go too.
    expect(doc.entities.liveCount, liveBefore - removed - 3 * 6);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(doc.entities.liveCount, liveBefore,
        reason: 'one ctrl+Z restores both walls, not one');
    for (final o in [...objects, ...rooms]) {
      expect(doc.tree[o], isA<GroupNode>(), reason: 'object $o is back');
    }
    for (final d in dims) {
      expect(doc.tree[d], isA<GroupNode>(), reason: 'dimension $d is back');
      expect(kids(doc, d), hasLength(6), reason: 'dimension $d');
    }
    expect(liveHandles(doc), handlesBefore, reason: 'every child handle');
    expect(c.activeSelection.isEmpty, isTrue);
  });
}
