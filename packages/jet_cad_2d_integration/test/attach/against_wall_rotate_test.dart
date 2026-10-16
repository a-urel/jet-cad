// F-7 (Slice 4's results, found not fixed): a symbol tagged `against-wall`
// turned to the wall it was placed or moved against under `rotate: false`,
// since the wall's attachment set its turn. Through `FloorPlanView` on the
// editor fixture under `editorCamera()`: a base unit 600 (tagged, its base
// point its front centre) placed against the east wall's inner face (x
// 25,750, which takes a quarter turn) and the north wall's (y 16,750, which
// takes none), and one placed free in the room, then dragged so its back
// meets the east face. Under `full` each east attachment turns (the
// control); under `rotate: false` none does, while the north face, which
// keeps the unit's turn, still attaches.
//
// Ported to jet_cad_2d_integration (3a Task 28, D-03; rulings IA-R4,
// IA-R5) from jet_cad_floor_plan/test/host/against_wall_rotate_test.dart:
// the editor is Task 26's fixture (`mountEditor`: the sample flat with 2b's
// units, `PlanEditor`, `editorCamera()`); the capabilities are the
// controller's permissions (`h.caps.value = X` → `c.permissions = X` and a
// pump); the Symbols tab, its search and its cell are the plan's gallery
// (`symbol-cell-architecture.kitchen.base.600@1`, C7 class 1); the active
// tool is the canvas's (`activeTool`, the rig's), plan.select's a
// `SelectTool` in the plan's guard: its id read through the controller.
// R-3's ghost reads (`tool.ghostAttachment`, `tool.ghostPlacement`, a
// private tool's) are read from the resting ghost's own drawing, with no
// pointer event (IA-R4, review fix 1): `restingMarker` (the hourglass the
// tool's screen overlay draws at the attachment's marker) and
// `restingPlacement` (the matrix its world overlay draws the ghost under);
// the commit a click at the resting pointer makes, read and undone, is
// checked after them.
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/attach_plans.dart'
    show
        answerAt,
        armable,
        rawWorldAt,
        restingMarker,
        restingPlacement,
        screenAt;
import '../support/canvas_rig.dart' show byKey, pressKey;
import '../support/editor_fixture.dart' show mountEditor, screenOf;
import 'editor_tools_review_test.dart'
    show arm, drag, gridSnapOff, hover, instancesOf, openSymbols, place;

/// [m]'s linear part.
List<double> linearOf(Transform2 m) => [m.a, m.b, m.c, m.d];

const List<double> unturned = [1.0, 0.0, 0.0, 1.0];

/// The transform a click of the resting mouse [g] at world [w] commits,
/// then undone (IA-R4: a ghost read at the resting pointer).
Future<Transform2> ghostAt(
    WidgetTester tester, PlanController c, TestGesture g, Vector2 w) async {
  final depth = c.document.commands.undoDepth;
  final before = instancesOf(c.document);
  final at = screenOf(tester, c, w);
  await g.down(at);
  await tester.pump();
  await g.up();
  await tester.pump();
  final added = instancesOf(c.document).difference(before);
  expect(added, hasLength(1), reason: 'one placement at $w');
  final t = (c.document.tree[added.single]! as InstanceNode).transform;
  c.undo();
  await tester.pump();
  expect(c.document.commands.undoDepth, depth, reason: 'premise: undone');
  return t;
}

/// Whether [m] places the base unit free at [w]: its base point, the
/// front centre (300, 0), at the click (no face took it).
bool isFree(Transform2 m, Vector2 w) =>
    m.transformPoint(Vector2(300, 0)).distanceTo(w) < 1e-6;

void main() {
  for (final rotate in [true, false]) {
    testWidgets(
        'F-7 rotate: $rotate: a base unit placed against the east face '
        '${rotate ? 'turns' : 'does not turn'}; against the north face it '
        'attaches unturned; one dragged to the east face '
        '${rotate ? 'turns' : 'keeps its turn'}', (tester) async {
      final c = await mountEditor(tester,
          permissions: PlanPermissions.full.copyWith(rotate: rotate));
      final d = c.document;
      gridSnapOff(d);
      await openSymbols(tester, c);
      await tester.enterText(byKey('symbol-search'), 'base unit 600');
      await tester.pump();
      await arm(tester, 'kitchen.base.600');

      // 20 mm west of the east wall's inner face, north of its window
      // (y 13,300..15,100).
      final east = await place(tester, c, Vector2(25730, 16200));
      if (rotate) {
        expect(east.transform.a, closeTo(0, 1e-9),
            reason: 'premise: the east face turns the unit a quarter turn');
      } else {
        expect(linearOf(east.transform), unturned,
            reason: 'the east face may not turn it');
        final at = east.transform.transformPoint(Vector2(300, 0));
        expect(at.distanceTo(Vector2(25730, 16200)), lessThan(1e-6),
            reason: 'free, at the click: no face took it (M-F7a)');
      }

      // 20 mm below the north wall's inner face: this face keeps the turn.
      final north = await place(tester, c, Vector2(24200, 16730));
      expect(linearOf(north.transform), unturned);
      expect(north.transform.f, 16750 - 600,
          reason: 'attached: its back on the face, its front 600 below');

      // Mirrored (M), against the same face east of it: the face still
      // takes it, mirrored and unturned; M again for the rest.
      await pressKey(tester, LogicalKeyboardKey.keyM);
      final mirrored = await place(tester, c, Vector2(24900, 16730));
      expect(linearOf(mirrored.transform), [-1.0, 0.0, 0.0, 1.0]);
      expect(mirrored.transform.f, 16750 - 600, reason: 'attached');
      await pressKey(tester, LogicalKeyboardKey.keyM);

      // Free in the room: x 24,700..25,300, y 13,700..14,300.
      final free = await place(tester, c, Vector2(25000, 13700));
      expect(linearOf(free.transform), unturned, reason: 'premise');
      // Its base point, the front centre (300, 0), at the click.
      final base = free.transform.transformPoint(Vector2(300, 0));
      expect((base.x, base.y), (25000.0, 13700.0),
          reason: 'premise: free, at the click');
      await pressKey(tester, LogicalKeyboardKey.escape);
      await pressKey(tester, LogicalKeyboardKey.escape);
      expect(c.activeTool.value, 'plan.select', reason: 'premise');

      // Its east edge dragged so its back-centre (25,000, 14,300) comes to
      // 30 mm west of the east face, north of the window.
      final from = Vector2(25300, 14000);
      await drag(tester, c, from, from + Vector2(720, 1500));
      final moved = d.tree[free.handle]! as InstanceNode;
      expect(moved.transform == free.transform, isFalse,
          reason: 'premise: the drag moved it');
      if (rotate) {
        expect(moved.transform.a, closeTo(0, 1e-9),
            reason: 'premise: the move attaches it, a quarter turn');
      } else {
        // The plain move, its translation within the screen's rounding.
        final want = Transform2.translation(720, 1500).multiply(free.transform);
        expect(linearOf(moved.transform), unturned);
        expect(moved.transform.e, closeTo(want.e, 1e-6),
            reason: 'the plain move: no face took it (M-F7a)');
        expect(moved.transform.f, closeTo(want.f, 1e-6),
            reason: 'the plain move: no face took it (M-F7a)');
      }
    });
  }

  testWidgets(
      'F-7 review R-1: a unit turned and mirrored under full, then dragged '
      'under rotate: false, attaches to the face its back faces with its own '
      'linear part bit for bit, and stays a plain move near a face it does '
      'not', (tester) async {
    final c = await mountEditor(tester);
    final d = c.document;
    gridSnapOff(d);
    await openSymbols(tester, c);
    await tester.enterText(byKey('symbol-search'), 'base unit 600');
    await tester.pump();
    await arm(tester, 'kitchen.base.600');
    // Three quarter turns and a mirror: local +y (its back) to world +x.
    for (var i = 0; i < 3; i++) {
      await pressKey(tester, LogicalKeyboardKey.keyR);
    }
    await pressKey(tester, LogicalKeyboardKey.keyM);
    // Free: x 24,200..24,800, y 13,600..14,200, its back-centre
    // (24,800, 13,900) facing east.
    final unit = await place(tester, c, Vector2(24200, 13900));
    const turned = [0.0, 1.0, 1.0, 0.0];
    expect(linearOf(unit.transform), turned, reason: 'premise');
    final back0 = unit.transform.transformPoint(Vector2(300, 600));
    expect((back0.x, back0.y), (24800.0, 13900.0), reason: 'premise: free');
    c.permissions = PlanPermissions.full.copyWith(rotate: false);
    await tester.pump();
    await pressKey(tester, LogicalKeyboardKey.escape);
    await pressKey(tester, LogicalKeyboardKey.escape);
    expect(c.activeTool.value, 'plan.select', reason: 'premise');

    // Its south edge dragged so its back-centre comes to 30 mm west of
    // the east face (x 25,750), north of the window.
    final from = Vector2(24500, 13600);
    await drag(tester, c, from, from + Vector2(920, 2000));
    final m1 = (d.tree[unit.handle]! as InstanceNode).transform;
    expect(linearOf(m1), turned, reason: 'its own linear part, bit for bit');
    final back1 = m1.transformPoint(Vector2(300, 600));
    expect(back1.x, closeTo(25750, 1e-6), reason: 'attached: back on the face');

    // Then towards the north face (y 16,750), 20 mm off it: that face
    // would turn it, so a plain move.
    final press = m1.transformPoint(Vector2(0, 300));
    final delta = Vector2(25000, 16730) - back1;
    await drag(tester, c, press, press + delta);
    final m2 = (d.tree[unit.handle]! as InstanceNode).transform;
    expect(linearOf(m2), turned, reason: 'not turned to the north face');
    final back2 = m2.transformPoint(Vector2(300, 600));
    expect(back2.y, closeTo(16730, 1), reason: 'premise: near the face');
  });

  testWidgets(
      'F-7 review R-3: the ghost attached to the east face lets go and '
      'unturns when rotate turns false with no pointer event; full again, '
      'it attaches turned', (tester) async {
    final c = await mountEditor(tester);
    gridSnapOff(c.document);
    await openSymbols(tester, c);
    await tester.enterText(byKey('symbol-search'), 'base unit 600');
    await tester.pump();
    await arm(tester, 'kitchen.base.600');
    final at = Vector2(25730, 16200);
    final g = await hover(tester, c, at);
    // The provider's answer at the resting pointer, under full (IA-R1).
    final want =
        answerAt(c, armable(c, 'kitchen.base.600'), rawWorldAt(tester, c, at))!;
    // `tool.ghostAttachment` / `tool.ghostPlacement`, read on the resting
    // ghost with no pointer event.
    void expectAttached(String why) {
      final m = restingMarker(tester, c);
      expect(m, isNotNull, reason: why);
      expect((m! - screenAt(c, want.marker)).distance, lessThan(1e-6),
          reason: why);
    }

    expectAttached('premise');
    expect(restingPlacement(tester, c)!.a, closeTo(0, 1e-9), reason: 'premise');
    c.permissions = PlanPermissions.full.copyWith(rotate: false);
    await tester.pump();
    expect(restingMarker(tester, c), isNull, reason: 'ghostAttachment isNull');
    expect(linearOf(restingPlacement(tester, c)!), unturned);
    c.permissions = PlanPermissions.full;
    await tester.pump();
    expectAttached('ghostAttachment isNotNull');
    expect(restingPlacement(tester, c)!.a, closeTo(0, 1e-9));
    // The commit at the resting pointer is the attached one (IA-R4).
    final p = await ghostAt(tester, c, g, at);
    expect(isFree(p, at), isFalse, reason: 'committed attached');
    expect(p.a, closeTo(0, 1e-9));
    await g.removePointer();
  });
}
