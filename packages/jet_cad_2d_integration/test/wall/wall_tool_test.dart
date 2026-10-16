// Ported from jet_cad_floor_plan/test/wall_tool_test.dart (3a Task 12):
// the cases that pump the shell (WT1-WT9, WT14, RF2, WT19), over a
// PlanController of the architecture kit in PlanEditor, assertions
// unchanged but for R-P1's: public libraries only, so the tool's settings
// are set through the property panel's settings fields (R12-1),
// `isPending` is read as the guard's `isMidShape` (the rig's activeTool;
// PlacementTool's isMidShape is its isPending, placement_tool.dart:76),
// and the joint kinds (`classify`, a kit internal) are asserted by the
// kit's companions WT3-k and WT9-k (R12-2). The direct cases (WT10-WT13,
// WT15-WT18, WT20) run in the kit.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/editor_rig.dart';
import '../support/wall_fixture.dart';
import '../support/wall_shell.dart';

// The room of WR12, turned 23° about the far origin: no corner is square,
// no wall is axis-aligned, and every coordinate is irrational.
final Vector2 c0 = plan(0, 0), c1 = plan(4000, 300);
final Vector2 c2 = plan(3600, 3100), c3 = plan(-200, 2700);

/// A point inside the room, off every wall: the T's stem starts here.
final Vector2 s0 = plan(1300, 1900);

final Vector2 _centre = plan(1850, 1500);

/// A 1:20 page near the far origin, **grid snap on** at [gridStep], and
/// (with [ticks]) one survey tick per point of [c0]..[c3] and [s0]: a root
/// LINE from the point, 400 mm outward. A click near a point snaps onto the
/// tick's endpoint (object snap beats the grid), so the snapped point is
/// known exactly and differs from the raw pointer point.
String wallShellPlan({bool ticks = true}) => wallPlanJson(wallPage(), (doc) {
      for (final p in [
        if (ticks) ...[c0, c1, c2, c3, s0]
      ]) {
        final out = (p - _centre).normalized() * 400;
        doc.commands.execute(addDrafted(
            doc, EntityKind.line, linePayload(p, p + out),
            layer: ReservedHandles.layerZero));
      }
    });

/// Pumps the editor over [plan] with a rotated, **non-reflecting** camera
/// centred on the room at the far origin, 0.15 px per mm: the room is
/// ~600 px across and the snap aperture is 10 / 0.15 ≈ 66.7 mm.
Future<PlanController> pumpWalls(WidgetTester tester, String plan) async {
  final pc = wallController(plan);
  await pumpEditor(tester, pc, centre: _centre, scale: 0.15);
  return pc;
}

/// The unit left normal of the line from [a] to [b].
Vector2 leftOf(Vector2 a, Vector2 b) {
  final d = (b - a).normalized();
  return Vector2(-d.y, d.x);
}

/// Wall [stem]'s end (index 1) is a T on [host], coming from the side of
/// [host]'s left normal given by [fromSign] (+1 left, -1 right): the stem
/// ends on the centreline, and its two cap corners lie on the host's face
/// on that side, far from the other face (WG4's property, in the
/// document).
void expectTee(DraftDocument doc, Handle host, Handle stem,
    {required double fromSign}) {
  final ph = doc.components.get<WallParams>(host)!;
  final ps = doc.components.get<WallParams>(stem)!;
  final wh = worldWallOf(doc, host);
  expect(distToLine(ps.end, wh.s, wh.e), lessThan(wallJoin.linear),
      reason: '${stem.toHex()} ends on the centreline');
  // classify: WT3-k (the kit).
  final (l, r) = facesOf(ph);
  final (n1, n2) = face(wh, fromSign > 0 ? l : r);
  final (f1, f2) = face(wh, fromSign > 0 ? r : l);
  final cap = [
    for (final q in worldOutline(doc, stem))
      if ((q - ps.end).length < 500) q
  ];
  expect(cap, hasLength(2), reason: stem.toHex());
  for (final q in cap) {
    expect(distToLine(q, n1, n2), lessThan(1e-6), reason: stem.toHex());
    expect(distToLine(q, f1, f2), greaterThan(150), reason: stem.toHex());
  }
}

/// Draws one wall from world [a] to world [b] by two clicks (at those
/// points exactly, plus the raw offsets) and Enter; returns it.
Future<Handle> drawWall(
    WidgetTester tester, PlanController pc, Vector2 a, Vector2 b) async {
  await clickAt(tester, pc, a);
  await clickAt(tester, pc, b);
  await press(tester, LogicalKeyboardKey.enter);
  return walls(pc.document).last;
}

void main() {
  testWidgets(
      'WT1 two clicks make one wall at the snapped points, stored exactly, '
      'in a group at the identity', (tester) async {
    final pc = await pumpWalls(tester, wallShellPlan());
    final doc = pc.document;
    await press(tester, LogicalKeyboardKey.keyW);
    expect(status(tester), 'Wall');
    await clickNear(tester, pc, c0);
    expect(walls(doc), isEmpty);
    await clickNear(tester, pc, c1);
    final h = walls(doc).single;
    final p = doc.components.get<WallParams>(h)!;
    expect(xy(p.start), xy(c0));
    expect(xy(p.end), xy(c1));
    expect([p.thickness, p.justification], [200, Justification.centre]);
    expect(doc.tree[h]!.transform, Transform2.identity());
    final w = worldWallOf(doc, h);
    expect(xy(w.s), xy(c0));
    expect(xy(w.e), xy(c1));
    expect(kids(doc, h).map((k) => kindOf(doc, k)),
        [EntityKind.fill, EntityKind.polyline, EntityKind.polyline]);
    expectSquare(doc, h);
    expect(doc.commands.undoDepth, 1);
    expect(activeTool(tester).isMidShape, isTrue,
        reason: 'the chain continues from the new point');
  });

  testWidgets(
      'WT2 three clicks and Enter: two walls, each in the settings current '
      'at its click, joined bit for bit and mitred, two undo steps',
      (tester) async {
    final pc = await pumpWalls(tester, wallShellPlan());
    final doc = pc.document;
    await press(tester, LogicalKeyboardKey.keyW);
    await clickNear(tester, pc, c0);
    await clickNear(tester, pc, c1);
    // Mid-chain: the next wall takes the new settings, the first keeps its.
    await setWallSettings(tester,
        thickness: '115', justification: Justification.left);
    await clickNear(tester, pc, c2);
    await press(tester, LogicalKeyboardKey.enter);
    expect(activeTool(tester).isMidShape, isFalse);
    final [a, b] = walls(doc);
    final pa = doc.components.get<WallParams>(a)!;
    final pb = doc.components.get<WallParams>(b)!;
    expect([xy(pa.start), xy(pa.end)], [xy(c0), xy(c1)]);
    expect([xy(pb.start), xy(pb.end)], [xy(c1), xy(c2)]);
    expect(pa.ex == pb.sx && pa.ey == pb.sy, isTrue, reason: 'bit for bit');
    expect([pa.thickness, pa.justification], [200, Justification.centre]);
    expect([pb.thickness, pb.justification], [115, Justification.left]);
    expectMitre(doc, a, b);
    expect(driftOf(doc), isEmpty);
    expect(doc.commands.undoDepth, 2);
    doc.commands.undo();
    expect(walls(doc), [a]);
    expectSquare(doc, a);
    doc.commands.undo();
    expect(walls(doc), isEmpty);
  });

  testWidgets(
      'WT3 a click on a centreline body makes a T whose stem butts the near '
      'face; a click on a centreline end makes a node', (tester) async {
    final pc = await pumpWalls(tester, wallShellPlan());
    final doc = pc.document;
    await press(tester, LogicalKeyboardKey.keyW);
    // The through wall H.
    await clickNear(tester, pc, c0);
    await clickNear(tester, pc, c1);
    await press(tester, LogicalKeyboardKey.enter);
    // The stem S, 115 left, from s0 onto H's body: 35% along, and 20 mm
    // off the centreline toward s0 (inside H's band).
    await setWallSettings(tester,
        thickness: '115', justification: Justification.left);
    final foot = c0 + (c1 - c0) * 0.35;
    final side = (s0 - project(s0, c0, c1)).normalized();
    await clickNear(tester, pc, s0);
    await clickAt(tester, pc, foot + side * 20);
    await press(tester, LogicalKeyboardKey.enter);
    final [h, s] = walls(doc);
    final ps = doc.components.get<WallParams>(s)!;
    expect(xy(ps.start), xy(s0));
    expect(distToLine(ps.end, c0, c1), lessThan(wallJoin.linear),
        reason: 'the stem ends on the centreline, not at the raw point');
    // The click resolves to its grid point first (no object snap is near
    // it); the band then projects that point onto H's centreline, exactly.
    final clicked = gridOf(doc, foot + side * 20);
    expect((clicked - foot).length, lessThan(30), reason: 'a grid point');
    expect((ps.end - project(clicked, c0, c1)).length, lessThan(1e-6),
        reason: 'the grid point of the click, projected onto H');
    // classify: WT3-k (the kit).
    // WG4's property, in the document: the stem's cap corners lie on H's
    // near face (s0's side), far from its far face; H stays a rectangle.
    final nearSign = (c1 - c0).cross(s0 - c0) > 0 ? 1.0 : -1.0; // left of H: +
    final (n1, n2) = face(worldWallOf(doc, h), 100 * nearSign);
    final (f1, f2) = face(worldWallOf(doc, h), -100 * nearSign);
    final cap = [
      for (final q in worldOutline(doc, s))
        if ((q - ps.end).length < 500) q
    ];
    expect(cap, hasLength(2));
    for (final q in cap) {
      expect(distToLine(q, n1, n2), lessThan(1e-6));
      expect(distToLine(q, f1, f2), greaterThan(150));
    }
    expectSquare(doc, h);

    // D11: the tool joins a wall wherever its band is clicked, and that is
    // the only way it makes a joint. On H (200, centre), clicks nearer a
    // face than the centreline, on both sides; each lands on a grid point
    // first (within ~7 mm), which the band joins onto H.
    await setWallSettings(tester,
        thickness: '200', justification: Justification.centre);
    final nH = leftOf(c0, c1);
    final inSign = nH.dot(s0 - c0) > 0 ? 1.0 : -1.0; // the room's side
    final t1 = await drawWall(tester, pc, plan(2300, 1000),
        c0 + (c1 - c0) * 0.6 + nH * (90 * inSign));
    expectTee(doc, h, t1, fromSign: inSign);
    final t2 = await drawWall(tester, pc, plan(3100, -1300),
        c0 + (c1 - c0) * 0.8 - nH * (60 * inSign));
    expectTee(doc, h, t2, fromSign: -inSign);
    // Inside H's band within one thickness of its end: the new wall starts
    // at H's end, bit for bit, and the two make a node.
    final len = c0.distanceTo(c1);
    final n = await drawWall(
        tester,
        pc,
        c0 + (c1 - c0) * ((len - 120) / len) + nH * (70 * inSign),
        plan(5200, 1100));
    expect(xy(doc.components.get<WallParams>(n)!.start), xy(c1));
    // classify: WT3-k (the kit).
    expectMitre(doc, h, n);

    // H2 (240, left) from c3 to c2: its band lies on its left only. From
    // the room (its right), a click in the band beyond the centreline makes
    // a T that butts the centreline face; a click as far off on the right
    // is outside the band and stays where it is.
    await setWallSettings(tester,
        thickness: '240', justification: Justification.left);
    final h2 = await drawWall(tester, pc, c3, c2);
    final nH2 = leftOf(c3, c2);
    expect(nH2.dot(s0 - c3), lessThan(0), reason: 'the room is on the right');
    await setWallSettings(tester,
        thickness: '200', justification: Justification.centre);
    final t3 = await drawWall(
        tester, pc, plan(1500, 2200), c3 + (c2 - c3) * 0.4 + nH2 * 180);
    expectTee(doc, h2, t3, fromSign: -1);
    final t4 = await drawWall(
        tester, pc, plan(2500, 2100), c3 + (c2 - c3) * 0.7 - nH2 * 150);
    final p4 = doc.components.get<WallParams>(t4)!;
    expect(distToLine(p4.end, c3, c2), closeTo(150, gridStep),
        reason: 'outside the band: not joined');
    expect(xy(p4.end), xy(gridOf(doc, p4.end)), reason: 'a grid point');
    // classify: WT3-k (the kit).
    expect(driftOf(doc), isEmpty);

    // A free wall X from two raw points, then a chain whose first click
    // lands on X's end: the new wall Y starts there bit for bit.
    final q0 = plan(900, 1200), q1 = plan(2600, 1500);
    await clickAt(tester, pc, q0);
    await clickAt(tester, pc, q1);
    await press(tester, LogicalKeyboardKey.enter);
    final x = walls(doc).last;
    final px = doc.components.get<WallParams>(x)!;
    await clickAt(tester, pc, px.end, -14, 11);
    await clickNear(tester, pc, c2);
    await press(tester, LogicalKeyboardKey.enter);
    final y = walls(doc).last;
    final py = doc.components.get<WallParams>(y)!;
    expect(xy(py.start), xy(px.end));
    expect(xy(py.end), xy(c2));
    expectMitre(doc, x, y);
    expect(driftOf(doc), isEmpty);
  });

  testWidgets(
      'WT4 a closed room: four clicks and a click on the start make four '
      'walls, four mitres and four undo steps (Review Focus 1)',
      (tester) async {
    final pc = await pumpWalls(tester, wallShellPlan());
    final doc = pc.document;
    await press(tester, LogicalKeyboardKey.keyW);
    for (final c in [c0, c1, c2, c3]) {
      await clickNear(tester, pc, c);
    }
    expect(walls(doc), hasLength(3));
    await clickAt(tester, pc, c0, -15, 13);
    expect(activeTool(tester).isMidShape, isFalse,
        reason: 'the closing click ends the chain');
    final ws = walls(doc);
    expect(ws, hasLength(4));
    final corners = [c0, c1, c2, c3];
    for (var i = 0; i < 4; i++) {
      final p = doc.components.get<WallParams>(ws[i])!;
      expect(
          [xy(p.start), xy(p.end)], [xy(corners[i]), xy(corners[(i + 1) % 4])]);
      expect(worldOutline(doc, ws[i]), hasLength(4));
    }
    for (var i = 0; i < 4; i++) {
      expectMitre(doc, ws[i], ws[(i + 1) % 4]);
    }
    expect(driftOf(doc), isEmpty);
    expect(diagnosticsOf(doc), isEmpty);
    expect(doc.commands.undoDepth, 4);
    for (var i = 3; i >= 0; i--) {
      doc.commands.undo();
      expect(walls(doc), ws.sublist(0, i));
    }
  });

  testWidgets(
      'WT5 a zero-length click is refused and the chain goes on; a click on '
      'the last point ends it', (tester) async {
    final pc = await pumpWalls(tester, wallShellPlan());
    final doc = pc.document;
    await press(tester, LogicalKeyboardKey.keyW);
    await clickNear(tester, pc, c0);
    // Both clicks snap onto c0's tick: a zero-length wall.
    await clickAt(tester, pc, c0, -10, 14);
    expect(walls(doc), isEmpty);
    expect(doc.commands.undoDepth, 0);
    expect(activeTool(tester).isMidShape, isTrue);
    await clickNear(tester, pc, c1);
    final a = walls(doc).single;
    expect(xy(doc.components.get<WallParams>(a)!.start), xy(c0));
    // A second click on c1 is the chain's last point: it ends the chain,
    // and the next click starts a new one.
    await clickAt(tester, pc, c1, 16, 3);
    expect(activeTool(tester).isMidShape, isFalse);
    await clickNear(tester, pc, c2);
    expect(walls(doc), [a]);
    expect(activeTool(tester).isMidShape, isTrue);
    await clickNear(tester, pc, c3);
    final b = walls(doc).last;
    expect(xy(doc.components.get<WallParams>(b)!.start), xy(c2));
    // With one wall down, the chain's first point is an ordinary point:
    // closing needs two walls, so this click adds a wall and goes on.
    await clickAt(tester, pc, c2, 9, 12);
    expect(walls(doc), hasLength(3));
    expect(activeTool(tester).isMidShape, isTrue);
  });

  testWidgets(
      'WT6 cmd+Z mid-chain is swallowed; Escape, then cmd+Z removes the '
      'last wall (Ruling 07-1)', (tester) async {
    final pc = await pumpWalls(tester, wallShellPlan());
    final doc = pc.document;
    await press(tester, LogicalKeyboardKey.keyW);
    await clickNear(tester, pc, c0);
    await clickNear(tester, pc, c1);
    await clickNear(tester, pc, c2);
    final ws = walls(doc);
    final before = enc(doc);
    await undoKey(tester);
    expect(enc(doc), before);
    expect(doc.commands.undoDepth, 2);
    expect(activeTool(tester).isMidShape, isTrue);
    await press(tester, LogicalKeyboardKey.escape);
    expect(activeTool(tester).isMidShape, isFalse);
    expect(status(tester), 'Wall');
    await undoKey(tester);
    expect(walls(doc), [ws.first]);
    expect(doc.commands.undoDepth, 1);
  });

  testWidgets(
      'WT7 W and the palette entry activate the Wall tool; W typed in a '
      'panel field does not', (tester) async {
    await pumpWalls(tester, wallShellPlan());
    await press(tester, LogicalKeyboardKey.keyW);
    expect(status(tester), 'Wall');
    await press(tester, LogicalKeyboardKey.keyV);
    expect(status(tester), 'Select');
    await tester.tap(find.byKey(const Key('tool-architecture.wall')));
    await tester.pump();
    expect(status(tester), 'Wall');
    await press(tester, LogicalKeyboardKey.keyV);
    final field = find.descendant(
        of: find.byKey(const Key('chrome-right')),
        matching: find.byType(EditableText));
    await tester.tap(field.first);
    await tester.pump();
    await press(tester, LogicalKeyboardKey.keyW);
    expect(status(tester), 'Select');
  });

  testWidgets(
      'WT8 a denied wall allocates no handle, changes nothing and ends the '
      'chain; structure alone is enough to deny it', (tester) async {
    final pc = await pumpWalls(tester, wallShellPlan());
    final doc = pc.document;
    await press(tester, LogicalKeyboardKey.keyW);
    for (final denied in const [
      DraftPermissions.runtime,
      DraftPermissions(
          transform: true, components: true, geometry: true, structure: false),
    ]) {
      doc.commands.permissions = DraftPermissions.all;
      await clickNear(tester, pc, c0);
      await clickNear(tester, pc, c1);
      expect(activeTool(tester).isMidShape, isTrue);
      doc.commands.permissions = denied;
      final seed = doc.handleSeed.current;
      final before = enc(doc);
      final count = walls(doc).length;
      await clickNear(tester, pc, c2);
      expect(doc.handleSeed.current, seed);
      expect(enc(doc), before);
      expect(walls(doc), hasLength(count));
      expect(activeTool(tester).isMidShape, isFalse, reason: 'the chain ends');
    }
  });

  testWidgets(
      'WT9 with object snap off, a click in a wall\'s band joins nothing: it '
      'stays where it was clicked', (tester) async {
    final pc = await pumpWalls(tester, wallShellPlan());
    final doc = pc.document;
    await press(tester, LogicalKeyboardKey.keyW);
    // H, whose joint kind with T WT9-k asserts in the kit.
    await drawWall(tester, pc, c0, c1);
    await press(tester, LogicalKeyboardKey.f3);
    expect(tester.widget<Text>(find.byKey(const Key('osnap-text'))).data,
        'osnap off');
    final nH = leftOf(c0, c1);
    final inSign = nH.dot(s0 - c0) > 0 ? 1.0 : -1.0;
    final target = c0 + (c1 - c0) * 0.6 + nH * (90 * inSign);
    final t = await drawWall(tester, pc, plan(2300, 1000), target);
    final pt = doc.components.get<WallParams>(t)!;
    expect(distToLine(pt.end, c0, c1), closeTo(90, gridStep));
    expect(xy(pt.end), xy(gridOf(doc, target)),
        reason: 'the grid point of the click, not joined');
    // classify: WT9-k (the kit).
  });

  testWidgets(
      'WT14 with grid snap on and unrelated lines 4-7 mm from every click, a '
      'chain lands bitwise on the grid points (smoke test)', (tester) async {
    // Grid points of the page (origin ox - 2000, step 10): exact doubles.
    final g = [
      Vector2(ox - 500, oy + 600),
      Vector2(ox + 2500, oy + 500),
      Vector2(ox + 2700, oy + 3300),
      Vector2(ox - 300, oy + 3500),
    ];
    // Hatch-like clutter: two long parallel lines beside each point, 4 and
    // 7 mm off it, all parallel (no intersections), their ends and
    // midpoints far outside the aperture.
    final u = Vector2(math.cos(0.4), math.sin(0.4)), n = Vector2(-u.y, u.x);
    final plan = wallPlanJson(wallPage(), (doc) {
      for (final p in g) {
        for (final off in const [4.0, -7.0]) {
          final a = p + n * off - u * 300, b = p + n * off + u * 1700;
          doc.commands.execute(addDrafted(
              doc, EntityKind.line, linePayload(a, b),
              layer: ReservedHandles.layerZero));
        }
      }
    });
    final pc = await pumpWalls(tester, plan);
    final doc = pc.document;
    await press(tester, LogicalKeyboardKey.keyW);
    for (final p in g) {
      await clickAt(tester, pc, p, 2.5, -3.5);
    }
    await press(tester, LogicalKeyboardKey.enter);
    final ws = walls(doc);
    expect(ws, hasLength(3));
    for (var i = 0; i < 3; i++) {
      final p = doc.components.get<WallParams>(ws[i])!;
      expect([xy(p.start), xy(p.end)], [xy(g[i]), xy(g[i + 1])]);
    }
  });

  testWidgets(
      'RF2 in the shell: draw an L, select one wall, Delete: the survivor\'s '
      'end squares; cmd+Z restores the mitre (Review Focus 2)', (tester) async {
    final pc = await pumpWalls(tester, wallShellPlan());
    final doc = pc.document;
    await press(tester, LogicalKeyboardKey.keyW);
    await clickNear(tester, pc, c0);
    await clickNear(tester, pc, c1);
    await clickNear(tester, pc, c2);
    await press(tester, LogicalKeyboardKey.enter);
    final [a, b] = walls(doc);
    expectMitre(doc, a, b);
    await press(tester, LogicalKeyboardKey.keyV);
    // Inside A's band, 40% along it and 30 mm off its centreline.
    final side = (c2 - project(c2, c0, c1)).normalized();
    await clickAt(tester, pc, c0 + (c1 - c0) * 0.4 + side * 30);
    expect(status(tester), 'Select — 1 selected');
    await press(tester, LogicalKeyboardKey.delete);
    expect(walls(doc), [b]);
    expect(doc.tree[a], isNull);
    expect(kids(doc, a), isEmpty);
    expectSquare(doc, b);
    expect(driftOf(doc), isEmpty);
    await undoKey(tester);
    expect(walls(doc), [a, b]);
    expect(kids(doc, a), hasLength(3));
    expectMitre(doc, a, b);
    expect(driftOf(doc), isEmpty);
  });

  testWidgets(
      'WT19 a 3.2 mm wall, 50 thick, at georeferenced mm coordinates lands '
      'through the Wall tool: the ring keeps its winding (post-11 (B))',
      (tester) async {
    // UTM-like millimetres, about 499 km east and 5,499 km north. Before
    // fix/post-11 the engine's triangulator summed the shoelace over these
    // raw coordinates; the rounding of products near 2.7e18 swamped this
    // band's area of 160 mm^2, flipped its sign, and the edit was refused
    // (spec 07 D8): the click threw out of the pointer handler.
    final s = Vector2(498765432.5, 5498765432.25);
    final e = Vector2(498765433.7503396, 5498765435.195616);
    expect((e - s).length, closeTo(3.2, 1e-6));
    final plan = wallPlanJson(
        PageComponent(
            scaleDenominator: 20,
            originX: s.x - 2000,
            originY: s.y - 2000,
            gridStepMm: gridStep), (doc) {
      // A survey tick out of each end, so each click snaps onto it exactly.
      for (final (p, out) in [(s, s - (e - s) * 100), (e, e + (e - s) * 100)]) {
        doc.commands.execute(addDrafted(
            doc, EntityKind.line, linePayload(p, out),
            layer: ReservedHandles.layerZero));
      }
    });
    final pc = wallController(plan);
    final doc = pc.document;
    // 100 px per mm, turned: the wall is 320 px long, the aperture 0.1 mm.
    await pumpEditor(tester, pc, centre: (s + e) / 2, scale: 100);
    await press(tester, LogicalKeyboardKey.keyW);
    await setWallSettings(tester,
        thickness: '50', justification: Justification.centre);
    await clickAt(tester, pc, s);
    await clickAt(tester, pc, e);
    expect(tester.takeException(), isNull);
    final h = walls(doc).single;
    final p = doc.components.get<WallParams>(h)!;
    expect(xy(p.start), xy(s));
    expect(xy(p.end), xy(e));
    expect(p.thickness, 50);
    expect(doc.commands.undoDepth, 1);
    expect(kids(doc, h).map((k) => kindOf(doc, k)),
        [EntityKind.fill, EntityKind.polyline, EntityKind.polyline]);
    expect(driftOf(doc), isEmpty);
  });
}
