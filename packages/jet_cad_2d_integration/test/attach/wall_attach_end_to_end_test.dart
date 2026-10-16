// Spec 09c "Testing" and Exit gate, plan 09c-1 Task 11: wall-aware placement
// through the app's real widgets, from the Symbols tab to a byte-identical
// save round trip, and a plan saved before 09c opened, saved and placed into.
//
// Fixtures (plan P-2): the app over a scripted `DocumentFiles` and a loader
// over the real asset read by `File`; walls added through the document's
// commands, each in its own group with a non-identity transform near
// (1e5, −7e4); a camera at 0.1 px/mm, rotated, so the attach capture is
// 160 mm and the edge capture 100 mm. The L is 100 and 240 mm thick, its two
// walls justified differently, so its inside corner is the drawn faces'
// meet, not the centrelines'. Every pointer is a mouse gesture on the
// canvas; no tool method is called directly. Each placement's transform is
// compared, byte for byte, with `attachToWall` computed here from the
// document (its runs from `faceRunsOf`, its neighbours from the placed
// instances), and its flushness is checked against the definition's own
// drawn vertices, not against `SymbolBox`.
//
// Ported to jet_cad_2d_integration (3a Task 28, D-04; rulings IA-R1,
// IA-R5) from apps/floor_planner/test/symbols/wall_attach_end_to_end_test
// .dart, WE1 (:219-381): the app is `PlanEditor` over
// `architectureController` whose plan file holds the L (`attachPlan`, each
// wall in its own `attachGroup` turned as today's handles 7 and 8 turned
// it); the camera is today's `aimCamera` on `c.camera`; the double bed and
// the base unit are the kit's (`architecture.*`, C7 class 1; the tag
// against-wall is `attachTo`, class 2), armed through the gallery's search
// and cell. The oracle is the kit's provider through the contract (IA-R1:
// `attachToWall` over `runsIn(doc)` and the placed neighbours is the
// provider's answer over the document, which holds them); a run's `a`, `t`
// and `m` are written here (`faceLineOf`; the inside run starts at the
// drawn inside corner, the meet of the two inside face lines). The save round trip is `c.save()` and a second controller's open
// (`host.saveAsStep`, `openFlow`, `saveStep`: the plan library has no host
// files). WE2 is not ported (C7: premise impossible under umbrella
// decision 9, no pre-09c library).
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/attach_plans.dart';
import '../support/canvas_rig.dart'
    show activeTool, globalAt, pumpPlanEditor, symbolsReady, worldAt;
import '../support/plans.dart' show polar, walls;
import '../support/room_plans.dart' show undoKey;

List<InstanceNode> instancesOf(DraftDocument doc) =>
    doc.tree.nodes.whereType<InstanceNode>().toList();

List<double> partsOf(Transform2 t) => [t.a, t.b, t.c, t.d, t.e, t.f];

/// A mouse that hovers at world [hover], then presses there, moves and
/// releases at world [release]. Returns the raw world points of the hover
/// and of the release.
Future<({Vector2 hoverRaw, Vector2 releaseRaw})> hoverPressRelease(
    WidgetTester tester,
    PlanController c,
    Vector2 hover,
    Vector2 release) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(
      location: globalAt(tester, c, hover) + const Offset(9, 7));
  await tester.pump();
  await mouse.moveTo(globalAt(tester, c, hover));
  await tester.pump();
  // Not ported (ruling IA-R5): expect(tool.ghostVisible, isTrue) and the
  // hovered attachment (`tool.ghostAttachment`), a private tool's.
  await mouse.down(globalAt(tester, c, hover));
  await tester.pump();
  await mouse.moveTo(globalAt(tester, c, release));
  await tester.pump();
  await mouse.up();
  await tester.pump();
  await mouse.removePointer();
  await tester.pump();
  return (
    hoverRaw: worldAt(tester, c, globalAt(tester, c, hover)),
    releaseRaw: worldAt(tester, c, globalAt(tester, c, release)),
  );
}

/// The drawn vertices of [instance]'s definition, in world: every line's
/// two ends and every polyline's points, through the instance's transform.
/// Read from the document's entities, not from `SymbolBox`.
List<Vector2> drawnVertices(DraftDocument doc, InstanceNode instance) {
  final g = doc.tree.accumulatedTransform(instance.handle);
  final e = doc.entities;
  final out = <Vector2>[];
  for (final slot in e.liveSlots) {
    if (e.ownerAt(slot) != instance.definition) continue;
    final p = doc.geometry.read(e.geomIndexAt(slot));
    final kind = e.kindAt(slot);
    final n = kind == EntityKind.line
        ? 2
        : kind == EntityKind.polyline
            ? p.pointCount
            : 0;
    for (var i = 0; i < n; i++) {
      out.add(g.transformPoint(Vector2(p.coords[2 * i], p.coords[2 * i + 1])));
    }
  }
  return out;
}

/// Asserts [instance] stands flush against [run], turned to it: its drawn
/// vertices all on the room side (`s ≥ −tol`), the nearest exactly on the
/// face line (within 1e-9 relative to the coordinates' size), those on the
/// face spanning [width] along it; local `+y` (towards the back) on `−m`
/// (into the wall) and local `+x` on `t` (mirrored: `−t`).
void expectFlush(
    DraftDocument doc, InstanceNode instance, FaceLine run, double width,
    {required bool mirrored, required String why}) {
  final tol = 1e-9 * run.a.length;
  final vs = drawnVertices(doc, instance);
  expect(vs.length, greaterThan(4), reason: '$why: premise: drawn');
  final ss = [for (final v in vs) (v - run.a).dot(run.m)];
  final nearest = ss.reduce((a, b) => a < b ? a : b);
  expect(nearest.abs(), lessThanOrEqualTo(tol),
      reason: '$why: the back on the face line (nearest s $nearest)');
  final onFace = [
    for (var i = 0; i < vs.length; i++)
      if (ss[i].abs() <= tol) (vs[i] - run.a).dot(run.t),
  ];
  final span = onFace.reduce((a, b) => a > b ? a : b) -
      onFace.reduce((a, b) => a < b ? a : b);
  expect(span, closeTo(width, tol),
      reason: '$why: the whole back edge on the face');
  final g = instance.transform;
  final sx = mirrored ? -1.0 : 1.0;
  expect(g.c, closeTo(-run.m.x, 1e-12), reason: '$why: +y into the wall');
  expect(g.d, closeTo(-run.m.y, 1e-12), reason: '$why: +y into the wall');
  expect(g.a, closeTo(sx * run.t.x, 1e-12), reason: '$why: +x along t');
  expect(g.b, closeTo(sx * run.t.y, 1e-12), reason: '$why: +x along t');
}

/// The interval along [run]'s `t`, from its `a`, that [instance]'s back
/// edge covers (its box's back corners through the instance's transform).
({double lo, double hi}) backAlong(
    InstanceNode instance, SymbolBox box, FaceLine run) {
  final g = instance.transform;
  final u1 = (g.transformPoint(Vector2(box.left, box.back)) - run.a).dot(run.t);
  final u2 =
      (g.transformPoint(Vector2(box.right, box.back)) - run.a).dot(run.t);
  return u1 <= u2 ? (lo: u1, hi: u2) : (lo: u2, hi: u1);
}

/// The L's corner, and its two walls' world angles: A (100 thick, right
/// justified) runs 4000 at 30° into the corner, B (240 thick, left
/// justified) runs 3000 out of it at 120°: a left turn, so the left faces
/// are inside.
final Vector2 corner = farAt(-321.75, 987.5);

/// The provider's answer for [e] at the raw world point [raw] on [c]'s
/// camera (IA-R1), its free placement the raw point's.
Attachment? answerAt(PlanController c, PlanSymbol e, Vector2 raw) {
  final scale = c.camera.value.scale;
  return attachOf(
      c.document,
      e.entry,
      raw,
      placementTransform(at: raw, basePoint: e.entry.definition.basePoint),
      scale);
}

void main() {
  testWidgets(
      'WE1 an L of 100 and 240 mm walls, one at 30°, far from the origin, '
      'at 0.1 px/mm: the double bed armed from the Symbols tab lands flush '
      'and turned on the outside face; three base units from the inside '
      'corner, each against the previous; undo three, redo three, bytes '
      'equal; Save As -> Open -> Save byte-identical', (tester) async {
    // Today's handles 7 and 8 (the launch document's first two after its
    // DASHED record at 6) turned the two groups.
    final plan = attachPlan([
      (polar(corner, 30 + 180, 4000), corner, 100, Justification.right),
      (corner, polar(corner, 120, 3000), 240, Justification.left),
    ], rotations: [
      0.3 + 0.7 * (7 % 9),
      0.3 + 0.7 * (8 % 9),
    ]);
    final c = architectureController(json: plan.json);
    addTearDown(c.dispose);
    await pumpPlanEditor(tester, c);
    expect(await symbolsReady(tester, c), isTrue,
        reason: 'premise: the furniture library loaded');
    final doc = c.document;
    final [hA, hB] = plan.walls;
    await aimCamera(tester, c, polar(corner, 30 + 180, 1500));
    final scale = c.camera.value.scale;
    expect(scale, closeTo(0.1, 1e-12),
        reason: 'premise: capture 160 mm, edge capture 100 mm');
    expect(walls(doc), [hA, hB]);
    for (final h in [hA, hB]) {
      final g = doc.tree.accumulatedTransform(h);
      expect(g.a == 1 || g.b == 0 || g.e == 0, isFalse,
          reason: 'premise: a turned, translated group');
    }

    final outside = faceLineOf(doc, hA, left: false);
    final insideB = faceLineOf(doc, hB, left: true);
    final insideFace = faceLineOf(doc, hA, left: true);
    // The inside run starts at the drawn inside corner: the meet of A's
    // and B's inside face lines, solved along A's from its own point (the
    // differences are small, so the meet keeps the coordinates' precision).
    final w = insideB.a - insideFace.a;
    final along = (w.x * insideB.t.y - w.y * insideB.t.x) /
        (insideFace.t.x * insideB.t.y - insideFace.t.y * insideB.t.x);
    final inside = (
      a: insideFace.a + insideFace.t * along,
      t: insideFace.t,
      m: insideFace.m,
      length: insideFace.length,
    );
    final d = polar(Vector2.zero(), 30, 1);
    expect(outside.m.dot(Vector2(-d.y, d.x)), closeTo(-1, 1e-9),
        reason: 'premise: the outside face looks away from the L');
    // The inside run starts at the drawn inside corner: on B's inside face
    // line, which the centreline end is not (B is 240 thick, left
    // justified).
    expect((inside.a - insideB.a).dot(insideB.m).abs(), lessThan(1e-6),
        reason: 'premise: the inside run starts on B\'s drawn inside face');
    expect((corner - inside.a).length, greaterThan(100),
        reason: 'premise: the drawn corner is not the centrelines\' meet');
    expect(inside.t.dot(d), closeTo(-1, 1e-9),
        reason: 'premise: along the inside face, u grows away from it');

    // 1. The double bed, armed from the Symbols tab, hovered 120 mm off the
    // outside face, pressed there and released 40 mm further along.
    final bed = armable(c, 'bed.double');
    expect(bed.component.attachTo, contains('wall-face'), reason: 'premise');
    final bedBox = boxOfEntry(bed.entry)!;
    expect(bedBox.backCentre.y, isNot(bed.entry.definition.basePoint.y),
        reason: 'premise: the back is not the base point');
    await armBySymbolsTab(tester, c, bed);
    final depth0 = doc.commands.undoDepth;
    final bedAt = await hoverPressRelease(
        tester, c, onRun(outside, 1500, 120), onRun(outside, 1540, 100));
    // Not ported (ruling IA-R5): the hover's lines, `bedAt.hovered` isNotNull
    // and its transform attachToWall's at the hover.
    final bedWant = answerAt(c, bed, bedAt.releaseRaw)!;
    expect(faceDistance(doc, hA, bedWant.marker, left: false), lessThan(1e-6),
        reason: 'premise: the outside face');
    final placedBed = instancesOf(doc).single;
    expect(partsOf(placedBed.transform), partsOf(bedWant.transform),
        reason: 'the release commits attachToWall\'s transform, bytes');
    expect(doc.commands.undoDepth, depth0 + 1, reason: 'one undo step');
    expectFlush(doc, placedBed, outside, 1600, mirrored: false, why: 'bed');

    // 2. Three base units along the inside face from the drawn corner: the
    // first's left side snaps to the run's start (60 mm away), the second's
    // to the first's right side (70 mm), the third's to the second's
    // (55 mm the other way).
    final unit = armable(c, 'kitchen.base.600');
    expect(unit.component.attachTo, contains('wall-face'), reason: 'premise');
    final unitBox = boxOfEntry(unit.entry)!;
    await armBySymbolsTab(tester, c, unit);
    final armed = activeTool(tester);
    final units = <InstanceNode>[];
    for (final (i, (u, s))
        in [(360.0, 110.0), (970.0, 90.0), (1445.0, 130.0)].indexed) {
      // The answer over the document as the release finds it: the placed
      // instances are its neighbours.
      final raw = worldAt(tester, c, globalAt(tester, c, onRun(inside, u, s)));
      final want = answerAt(c, unit, raw)!;
      final at = await hoverPressRelease(
          tester, c, onRun(inside, u, s), onRun(inside, u, s));
      expect(at.releaseRaw, raw, reason: 'premise: the same raw point');
      expect(faceDistance(doc, hA, want.marker, left: true), lessThan(1e-6),
          reason: 'premise: unit $i inside');
      final placed = instancesOf(doc).last;
      expect(instancesOf(doc), hasLength(2 + i));
      expect(partsOf(placed.transform), partsOf(want.transform),
          reason: 'unit $i: attachToWall\'s transform, bytes');
      expectFlush(doc, placed, inside, 600, mirrored: false, why: 'unit $i');
      units.add(placed);
    }
    expect(doc.commands.undoDepth, depth0 + 4, reason: 'one step each');
    final spans = [for (final n in units) backAlong(n, unitBox, inside)];
    expect(spans[0].lo, closeTo(0, 1e-9),
        reason: 'the first starts at the drawn corner');
    expect(spans[1].lo, closeTo(spans[0].hi, 1e-9),
        reason: 'the second\'s left end on the first\'s right end');
    expect(spans[2].lo, closeTo(spans[1].hi, 1e-9),
        reason: 'the third\'s left end on the second\'s right end');
    expect(spans[2].hi, closeTo(1800, 1e-9));
    expect(doc.tree.definitions.where((x) => x.name.contains('#')), isEmpty,
        reason: 'one definition per symbol');

    // 3. Undo three times (the three units go), redo three times: the same
    // bytes as before the undo.
    final before = c.save();
    final unitTransforms = [for (final n in units) partsOf(n.transform)];
    for (var k = 0; k < 3; k++) {
      await undoKey(tester);
    }
    expect([for (final n in instancesOf(doc)) n.handle], [placedBed.handle],
        reason: 'three undo steps took the three units only');
    expect(doc.tree.definitions, hasLength(1),
        reason: 'and the unit\'s definition');
    expect(activeTool(tester), same(armed), reason: 'still armed');
    expect(c.armedSymbol.value, same(unit), reason: 'still armed');
    for (var k = 0; k < 3; k++) {
      await redoKey(tester);
    }
    expect([for (final n in instancesOf(doc).skip(1)) partsOf(n.transform)],
        unitTransforms);
    expect(c.save(), before, reason: 'redo restores the bytes');

    // 4. Save As -> Open those bytes -> Save: the second bytes are the
    // first.
    final first = c.save();
    expect(first, before, reason: 'the codec\'s bytes');
    final reopened = architectureController(json: first);
    addTearDown(reopened.dispose);
    final opened = reopened.document;
    expect(identical(opened, doc), isFalse, reason: 'premise: swapped');
    expect([for (final n in instancesOf(opened)) partsOf(n.transform)],
        [partsOf(placedBed.transform), ...unitTransforms]);
    expect(reopened.save(), first, reason: 'byte-identical');
  });
}
