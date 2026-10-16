// Ported from jet_cad_floor_plan/test/planner_box_test.dart (BX1-BX6, spec
// 06 D13); assertions unchanged. PlannerShell becomes PlanEditor over
// architectureController() (spec 3a C6, C7); the palette's 'tool-box' is
// 'tool-architecture.box' (C7 class 1, ids); BX4's drift is asked of the
// kit's types (kitCatalog) instead of the floor planner's catalog. The
// fixture is box_rig.dart's boxDoc (a 1:20 page anchored at (7000, 3000),
// nothing drawn) opened by the controller, its grid snap on: under the
// editor's turned camera a click's world point does not come back exactly
// (the plan library's selection_panel_test.dart:38-43 measured a box of
// 120 x 69.99999999999955), and the grid keeps the clicks on today's exact
// corners. BX1-BX6 do not need it to pass: with it off they pass too
// (BX2's closeTo absorbs the camera's error; Task 10's probe).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/editor_rig.dart';

/// box_rig.dart's `pumpDraw(tester, boxDoc(...))`: the page opened by a
/// controller over the kit, its editor under the turned, zoomed camera
/// centred on (7150, 3110).
Future<PlanController> pumpBoxes(WidgetTester tester) async {
  final c = architectureController(
      json: pagePlanJson(PageComponent(
          scaleDenominator: 20,
          originX: 7000,
          originY: 3000,
          snapToGrid: true)));
  addTearDown(c.dispose);
  await pumpEditor(tester, c, centre: Vector2(7150, 3110));
  return c;
}

/// box_rig.dart's `boxKids` (:77-80): [box]'s generated children,
/// ascending, found by owner.
List<Handle> boxKids(DraftDocument doc, Handle box) => [
      for (final slot in doc.leavesByOwner()[box] ?? const <int>[])
        doc.entities.handleAt(slot),
    ];

/// box_rig.dart's `boxes` (:84-85).
List<Handle> boxes(DraftDocument doc) =>
    doc.components.withComponent<BoxParams>().toList();

/// World coordinates of a box's local point (the box's own transform is a
/// pure translation -- spec 06 D13's Box tool is world-axis aligned, never
/// rotated).
Vector2 _worldOf(DraftDocument doc, Handle box, Vector2 local) =>
    doc.tree.accumulatedTransform(box).transformPoint(local);

/// A generated child's world midpoint, from its (local) line payload.
Vector2 _childMidpoint(DraftDocument doc, Handle box, Handle child) {
  final slot = doc.entities.slotOf(child)!;
  final payload = doc.geometry.read(doc.entities.geomIndexAt(slot));
  final mid = (payload.pointAt(0) + payload.pointAt(1)) * 0.5;
  return _worldOf(doc, box, mid);
}

/// Strictly inside the world-axis-aligned rectangle `(minX,minY)-(maxX,maxY)`
/// spanned by [box]'s own `BoxParams` (Tolerance is not needed: the sampled
/// midpoints below never sit on a boundary).
bool _strictlyInside(DraftDocument doc, Handle box, Vector2 p) {
  final params = doc.components.get<BoxParams>(box)!;
  final origin = _worldOf(doc, box, Vector2.zero());
  return p.x > origin.x &&
      p.x < origin.x + params.width &&
      p.y > origin.y &&
      p.y < origin.y + params.height;
}

void main() {
  testWidgets('BX1 B and the palette entry activate the Box tool',
      (tester) async {
    await pumpBoxes(tester);
    await press(tester, LogicalKeyboardKey.keyB);
    expect(status(tester), 'Box');
    await press(tester, LogicalKeyboardKey.keyV);
    await tester.tap(find.byKey(const Key('tool-${ArchitectureTools.box}')));
    await tester.pump();
    expect(status(tester), 'Box');
  });

  testWidgets('BX2 two clicks: one box, four lines, one undo step',
      (tester) async {
    final c = await pumpBoxes(tester);
    final doc = c.document;
    await press(tester, LogicalKeyboardKey.keyB);
    await tester.tapAt(globalOf(tester, c, 7010, 3020));
    await tester.tapAt(globalOf(tester, c, 7130, 3090));
    await tester.pump();
    final b = boxes(doc).single;
    expect(doc.components.get<BoxParams>(b)!.width, closeTo(120, 1e-6));
    expect(doc.components.get<BoxParams>(b)!.height, closeTo(70, 1e-6));
    expect(boxKids(doc, b), hasLength(4));
    expect(doc.commands.undoDepth, 1);
    doc.commands.undo();
    await tester.pump();
    expect(boxes(doc), isEmpty);
    expect(doc.entities.liveSlots, isEmpty);
  });

  testWidgets('BX3 Fill does not apply to a box', (tester) async {
    final c = await pumpBoxes(tester);
    await press(tester, LogicalKeyboardKey.keyF);
    await press(tester, LogicalKeyboardKey.keyB);
    await tester.tapAt(globalOf(tester, c, 7010, 3020));
    await tester.tapAt(globalOf(tester, c, 7130, 3090));
    await tester.pump();
    for (final s in c.document.entities.liveSlots) {
      expect(c.document.entities.kindAt(s), EntityKind.line);
    }
  });

  testWidgets('BX4 two overlapping boxes read as one outline', (tester) async {
    final c = await pumpBoxes(tester);
    final doc = c.document;
    await press(tester, LogicalKeyboardKey.keyB);
    await tester.tapAt(globalOf(tester, c, 7010, 3020));
    await tester.tapAt(globalOf(tester, c, 7130, 3090));
    await tester.tapAt(globalOf(tester, c, 7100, 3060));
    await tester.tapAt(globalOf(tester, c, 7190, 3120));
    await tester.pump();
    final bs = boxes(doc);
    expect(bs, hasLength(2));
    // Box A: (7010,3020)-(7130,3090); Box B: (7100,3060)-(7190,3120). They
    // overlap in the corner rectangle (7100,3060)-(7130,3090): A's east and
    // north edges each lose the segment running through that corner, and
    // B's west and south edges each lose the same. Each box keeps its two
    // untouched edges whole and its two touched edges as one shortened
    // piece apiece: four children each.
    expect(boxKids(doc, bs[0]), hasLength(4));
    expect(boxKids(doc, bs[1]), hasLength(4));
    expect(ParametricSystem(doc, kitCatalog()).drift(), isEmpty);
    // Every child midpoint lies outside the other box's interior.
    for (final child in boxKids(doc, bs[0])) {
      final mid = _childMidpoint(doc, bs[0], child);
      expect(_strictlyInside(doc, bs[1], mid), isFalse,
          reason: 'box A child $child at $mid lies inside box B');
    }
    for (final child in boxKids(doc, bs[1])) {
      final mid = _childMidpoint(doc, bs[1], child);
      expect(_strictlyInside(doc, bs[0], mid), isFalse,
          reason: 'box B child $child at $mid lies inside box A');
    }
  });

  testWidgets(
      'BX5 click a box, Delete: gone with its component; cmd+Z '
      'brings both back (Review Focus 2)', (tester) async {
    final c = await pumpBoxes(tester);
    final doc = c.document;
    await press(tester, LogicalKeyboardKey.keyB);
    await tester.tapAt(globalOf(tester, c, 7010, 3020));
    await tester.tapAt(globalOf(tester, c, 7130, 3090));
    await tester.tapAt(globalOf(tester, c, 7100, 3060));
    await tester.tapAt(globalOf(tester, c, 7190, 3120));
    await press(tester, LogicalKeyboardKey.keyV);
    final first = boxes(doc).first;
    // The first box's bottom edge, away from the second box.
    await tester.tapAt(globalOf(tester, c, 7040, 3020));
    await tester.pump();
    await press(tester, LogicalKeyboardKey.delete);
    expect(doc.tree[first], isNull);
    expect(doc.components.get<BoxParams>(first), isNull);
    expect(boxKids(doc, boxes(doc).single), hasLength(4));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await press(tester, LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    expect(doc.components.get<BoxParams>(first), isNotNull);
    expect(boxes(doc), hasLength(2));
  });

  testWidgets('BX6 typing B in the page panel field does not switch tools',
      (tester) async {
    await pumpBoxes(tester);
    final field = find.descendant(
        of: find.byKey(const Key('chrome-right')),
        matching: find.byType(EditableText));
    await tester.tap(field.first);
    await tester.pump();
    await press(tester, LogicalKeyboardKey.keyB);
    expect(status(tester), isNot('Box'));
  });
}
