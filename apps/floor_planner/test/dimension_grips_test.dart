// Spec 11 D13: a dimension's grips. Three `stretch` grips, in world: the
// offset grip (ordinal 0) at the dimension line's midpoint, the end grips at
// `a` (1) and `b` (2) on the measured points (R-26). The offset grip stores
// D6's `offsetFor` of the drop with the dimension's current kind; an end
// grip makes the dropped end D10's choice at the drop, and only that end
// (decision 22), from candidates gathered afresh, by position while F3 is on
// (decision 23), or a fixed end at the drop in the group's local space. A
// drop that changes nothing or makes the dimension degenerate is refused;
// the grips are hit only while `components` and `geometry` are allowed
// (07 OG5, the plan's Ruling 11-25); a broken dimension has none; the
// preview is the committed lines (S-15).
//
// Every relational case runs at the origin and at the corpus far origin
// with every wall in its own rotated, translated group; the dimension's
// group sits at the placement and, where the case does not measure along a
// wall, is turned 30° further, so a local hand value holds at every
// placement and a world/local confusion shows at the origin too. Expected
// values are hand arithmetic beside the assertion.
import 'dart:math' as math;

import 'package:floor_planner/parametric/dimension.dart';
import 'package:floor_planner/parametric/dimension_attach.dart';
import 'package:floor_planner/parametric/dimension_grips.dart';
import 'package:floor_planner/parametric/object_grips.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/dimension_fixture.dart';

const l = WallSide.left, r = WallSide.right;

/// The group a dimension sits in: the placement, turned [deg] further.
Transform2 turned(Placement place, double deg) =>
    place.m.multiply(Transform2.rotation(deg * math.pi / 180));

/// A [DimensionGrips] over [doc]'s own spatial index, F3 as [snap] says at
/// each call; torn down with the test.
(DimensionGrips, SpatialIndex) gripsFor(DraftDocument doc,
    {bool Function()? snap}) {
  final index = SpatialIndex(doc);
  addTearDown(index.dispose);
  return (DimensionGrips(index: index, objectSnap: snap ?? () => true), index);
}

/// The grip of [dim] with ordinal [ordinal].
Grip gripOf(DimensionGrips g, DraftDocument doc, Handle dim, int ordinal) =>
    g.gripsOf(doc, dim)[ordinal];

Vector2 at(Grip g) => Vector2(g.x, g.y);

DimensionParams paramsOf(DraftDocument doc, Handle h) =>
    doc.components.get<DimensionParams>(h)!;

/// Drops [ordinal] of [dim] at world [q] and executes the command, which
/// must exist: one undo step.
void drop(DimensionGrips g, DraftDocument doc, Handle dim, int ordinal,
    Vector2 q, String why) {
  final depth = doc.commands.undoDepth;
  final cmd = g.drag(doc, dim, gripOf(g, doc, dim, ordinal), q);
  expect(cmd, isNotNull, reason: '$why: a command');
  doc.commands.execute(cmd!);
  expect(doc.commands.undoDepth, depth + 1, reason: '$why: one undo step');
}

/// [w] in the local frame of [m].
Vector2 localOf(Transform2 m, Vector2 w) => m.invert().transformPoint(w);

void expectNear(Vector2 got, Vector2 want, double tol, String why) =>
    expect((got - want).length, lessThan(tol), reason: '$why: $got vs $want');

void main() {
  for (final place in const [origin, corpusGroups]) {
    test(
        'GE1 a dimension has three grips, at its line\'s midpoint and its '
        'two measured points, in world, under a turned group, at $place', () {
      final plan = buildPlan(c2Walls, place: place);
      final doc = plan.doc;
      attachPage(doc, mmPage);
      final [a, _] = plan.walls;
      final (grips, index) = gripsFor(doc);
      final g = turned(place, 30);

      // Fixed-fixed, horizontal, offset 500.5: u = the group's x, n its y.
      // h0 = 0, h1 = 889.75 − (−310.25) = 1200, so hi = 1200 and the line
      // at c = 1200 + 500.5 = 1700.5 above P0: local y −310.25 + 1700.5 =
      // 1390.25, from Q0 (1234.5, 1390.25) to Q1 (4234.5, 1390.25). Its
      // midpoint is (2734.5, 1390.25).
      final dim = addDimension(
          doc, const FixedEnd(1234.5, -310.25), const FixedEnd(4234.5, 889.75),
          kind: DimKind.horizontal, offset: 500.5, at: g);
      var gs = grips.gripsOf(doc, dim);
      expect(gs, hasLength(3));
      for (var i = 0; i < 3; i++) {
        expect(gs[i].role, GripRole.stretch, reason: 'grip $i');
        expect(gs[i].index, i, reason: 'grip $i: its ordinal');
      }
      expectNear(at(gs[0]), g.transformPoint(Vector2(2734.5, 1390.25)), 1e-6,
          'the offset grip at the midpoint');
      expectNear(at(gs[1]), g.transformPoint(Vector2(1234.5, -310.25)), 1e-6,
          'the grip at a');
      expectNear(at(gs[2]), g.transformPoint(Vector2(4234.5, 889.75)), 1e-6,
          'the grip at b');

      // Attached-fixed, aligned, offset 300.25: a = A/1/left, the L's inner
      // corner (3900, 100) (A's left face y 100 meets B's left face x
      // 3900); b fixed at (1000.25, 1500.5) in the plan. d = b − a =
      // (−2899.75, 1400.5), |d| = √(2899.75² + 1400.5²) = √10,369,950.3 =
      // 3,220.24; the left normal n = (−d.y, d.x) / |d| = (−1400.5,
      // −2899.75) / 3,220.24. The line 300.25 along n from both points,
      // its midpoint ((3900 + 1000.25) / 2, (100 + 1500.5) / 2) + 300.25 n
      // = (2450.125, 800.25) + 300.25 n, in the plan (aligned measures in
      // world; the group's own turn does not enter it).
      final inner = place.at(3900, 100);
      expect(bruteCandidates(doc, inner), contains(AttachedEnd(a, 1, l)),
          reason: 'premise: A/1/left is the inner corner');
      final dim2 = addDimension(
          doc, AttachedEnd(a, 1, l), fixedAt(place.at(1000.25, 1500.5), g),
          kind: DimKind.aligned, offset: 300.25, at: g);
      final len = math.sqrt(2899.75 * 2899.75 + 1400.5 * 1400.5);
      expect(len, closeTo(3220.24, 0.005));
      final n = Vector2(-1400.5, -2899.75) / len;
      gs = grips.gripsOf(doc, dim2);
      expect(gs, hasLength(3));
      final mid = Vector2(2450.125, 800.25) + n * 300.25;
      expectNear(at(gs[0]), place.at(mid.x, mid.y), 1e-6,
          'attached-fixed: the offset grip');
      expectNear(at(gs[1]), inner, 1e-6, 'attached-fixed: the grip at a');
      expectNear(at(gs[2]), place.at(1000.25, 1500.5), 1e-6,
          'attached-fixed: the grip at b');

      // Through the shell's provider: the same grips, and a dimension is
      // movable (R-19). Without the index, no grips.
      final objects = ObjectGrips(edgeAperture: () => null, index: index);
      expect(objects.gripsOf(doc, dim2), gs);
      expect(objects.movable(doc, dim2), isTrue);
      expect(ObjectGrips(edgeAperture: () => null).gripsOf(doc, dim2), isEmpty);
      expect(driftOf(doc), isEmpty);
    });
  }

  for (final place in const [origin, corpusGroups]) {
    test(
        'GE2 the offset grip stores offsetFor of the drop with the current '
        'kind: outermost, between band, sign bit; one undo step; a drop that '
        'changes nothing returns null, at $place', () {
      final plan = buildPlan(const [], place: place);
      final doc = plan.doc;
      attachPage(doc, mmPage);
      final (grips, _) = gripsFor(doc);
      final g = turned(place, 30);
      // Horizontal over (0, 0) and (3000, 1200): n = the group's y, h0 = 0,
      // h1 = 1200, so lo = 0 and hi = 1200 (DL2).
      final dim = addDimension(
          doc, const FixedEnd(0, 0), const FixedEnd(3000, 1200),
          kind: DimKind.horizontal, offset: 7.5, at: g);
      final before = paramsOf(doc, dim);

      /// The dimension line, local: both ends at local y [y], x 0 and 3000.
      void lineAt(double y, String why) {
        final line = dimLines(doc, dim)[0];
        expectNear(localOf(g, line.$1), Vector2(0, y), 1e-6, '$why: Q0');
        expectNear(localOf(g, line.$2), Vector2(3000, y), 1e-6, '$why: Q1');
      }

      // DL2's local heights, dropped at x 1500.5 and taken to world:
      // - y 2000 ≥ hi: 2000 − 1200 = +800, the line at 2000;
      // - y −300 ≤ lo: −(0 − (−300)) = −300, the line at −300;
      // - y 900, between: hi − hq = 300 ≤ hq − lo = 900, the upper extreme,
      //   +0.0, the line at 1200;
      // - y 400, between: hi − hq = 800 > hq − lo = 400, the lower extreme,
      //   −0.0 (its side the sign bit, R-2), the line at 0.
      for (final (y, want, negative, line) in const [
        (2000.0, 800.0, false, 2000.0),
        (-300.0, -300.0, true, -300.0),
        (900.0, 0.0, false, 1200.0),
        (400.0, 0.0, true, 0.0),
      ]) {
        final why = 'drop at local y $y';
        drop(grips, doc, dim, 0, g.transformPoint(Vector2(1500.5, y)), why);
        final p = paramsOf(doc, dim);
        expect(p.offset, closeTo(want, 1e-6), reason: why);
        expect(p.offset.isNegative, negative, reason: '$why: the sign bit');
        expect(p.kind, DimKind.horizontal, reason: '$why: the kind kept');
        expect((p.a, p.b), (before.a, before.b), reason: '$why: the ends');
        lineAt(line, why);
        expect(driftOf(doc), isEmpty);
      }

      // Drops that change nothing: null, nothing executed. Deep in the
      // between band on the lower side (local y 350) the offset is −0.0
      // again; then +800 again, and a second drop at the point that gave it
      // (local (1500.5, 2000), on the line now) gives the same offset.
      final depth = doc.commands.undoDepth;
      final g0 = gripOf(grips, doc, dim, 0);
      expect(grips.drag(doc, dim, g0, g.transformPoint(Vector2(700.25, 350))),
          isNull,
          reason: 'the between band, the same side');
      drop(grips, doc, dim, 0, g.transformPoint(Vector2(1500.5, 2000)),
          'back to +800');
      final q800 = g.transformPoint(Vector2(1500.5, 2000));
      expect(grips.drag(doc, dim, gripOf(grips, doc, dim, 0), q800), isNull,
          reason: 'a drop on the line itself');
      expect(doc.commands.undoDepth, depth + 1, reason: 'one step only');
    });
  }

  for (final place in const [origin, corpusGroups]) {
    test(
        'GE3 an end grip attaches a fixed end, detaches an attached one, '
        'moves one to another wall\'s point, and never re-decides the other '
        'end, at $place', () {
      // The L of C2: A (0, 0) -> (4000, 0), B (4000, 0) -> (4000, 3000),
      // 200 centred. A's free start's left corner (0, 100) is A/0/left
      // alone; B's free end's left corner (3900, 3000) is B/1/left alone.
      final plan = buildPlan(c2Walls, place: place);
      final doc = plan.doc;
      attachPage(doc, mmPage);
      final [a, b] = plan.walls;
      var snap = true;
      final (grips, index) = gripsFor(doc, snap: () => snap);
      List<AttachedEnd> candidatesAt(Vector2 q) =>
          attachCandidates(doc, index, q,
              objectSnap: true, thickest: thickestWall(doc));
      final a0 = place.at(0, 100), b1 = place.at(3900, 3000);
      expect(candidatesAt(a0), [AttachedEnd(a, 0, l)],
          reason: 'premise: A/0/left');
      expect(candidatesAt(b1), [AttachedEnd(b, 1, l)],
          reason: 'premise: B/1/left');

      // Aligned, both ends fixed, in a group turned 30° further.
      final g = turned(place, 30);
      final fixedB = fixedAt(place.at(2500.75, 2200.25), g);
      final dim = addDimension(
          doc, fixedAt(place.at(500.25, 1500.5), g), fixedB,
          kind: DimKind.aligned, offset: 250.5, at: g);
      void kept(String why) {
        final p = paramsOf(doc, dim);
        expect(p.b, fixedB, reason: '$why: the other end kept');
        expect(p.kind, DimKind.aligned, reason: '$why: the kind kept');
        expect(p.offset, 250.5, reason: '$why: the offset kept');
        expect(driftOf(doc), isEmpty);
      }

      // -- Attach: a dropped on A/0/left, F3 on.
      drop(grips, doc, dim, 1, a0, 'attach');
      expect(paramsOf(doc, dim).a, AttachedEnd(a, 0, l), reason: 'attached');
      kept('attach');

      // -- Move: dropped on B/1/left.
      drop(grips, doc, dim, 1, b1, 'move');
      expect(paramsOf(doc, dim).a, AttachedEnd(b, 1, l), reason: 'moved');
      kept('move');

      // -- Detach: dropped mid-room, where nothing attaches: a fixed end at
      // the drop in the group's local space (not the world point).
      final free = place.at(2000.25, 1000.75);
      expect(candidatesAt(free), isEmpty, reason: 'premise: nothing there');
      drop(grips, doc, dim, 1, free, 'detach mid-room');
      final got = paramsOf(doc, dim).a as FixedEnd;
      expectNear(got.point, localOf(g, free), 1e-6, 'detached, local');
      kept('detach mid-room');

      // -- Detach with F3 off, on the corner itself: re-attached first,
      // then dropped on the same corner with F3 off. A fixed end at the
      // corner, local.
      drop(grips, doc, dim, 1, a0, 're-attach');
      expect(paramsOf(doc, dim).a, AttachedEnd(a, 0, l));
      snap = false;
      drop(grips, doc, dim, 1, a0, 'F3 off');
      final off = paramsOf(doc, dim).a as FixedEnd;
      expectNear(
          off.point, localOf(g, a0), 1e-6, 'F3 off: fixed at the corner');
      kept('F3 off');
      snap = true;

      // -- Decision 22 in the group's axes (the review's I-2): a horizontal
      // dimension in a group turned 90° further than the placement, so its
      // x runs along the plan's y, along B. Its a dropped on the L's outer
      // corner (4100, −100), A/1/right and B/0/right: u = the group's x,
      // σ_B = 0 < σ_A = 1, so B/0/right (A has the lower handle here, so
      // the lowest-handle step alone would store A). Decided in world axes
      // it would be A/1/right at both placements (world x: σ_A = 0 at the
      // origin; sin 23° = 0.39 < cos 23° = 0.92 at the far origin).
      {
        expect(a.value < b.value, isTrue, reason: 'premise: A is lower');
        final outer = place.at(4100, -100);
        expect(
            candidatesAt(outer), [AttachedEnd(a, 1, r), AttachedEnd(b, 0, r)],
            reason: 'premise: the outer corner is A/1/right and B/0/right');
        final g90 = turned(place, 90);
        final dim90 = addDimension(doc, fixedAt(place.at(1500.25, 2000.5), g90),
            fixedAt(place.at(3000.5, 3000.25), g90),
            kind: DimKind.horizontal, offset: 300.75, at: g90);
        drop(grips, doc, dim90, 1, outer, 'horizontal in a turned group');
        expect(paramsOf(doc, dim90).a, AttachedEnd(b, 0, r),
            reason: 'along the group\'s x: B');
      }

      // -- A flush door (the review's M-1): spike C5's T, the door on the
      // stem S at c = 450 swinging left, clamped flush with S's butt end on
      // C's face (flushT). S/0/right, (2,500 + 50, 100), is the far jamb
      // corner: no child of S reaches it, and the door's leaf and arc stand
      // on its left face, 100 mm off. Only the host box grown by T (C's 200)
      // finds S there; a drop on it attaches.
      {
        final plan = flushT(place);
        final doc = plan.doc;
        attachPage(doc, mmPage);
        final [_, s] = plan.walls;
        final (grips, _) = gripsFor(doc);
        // The drop 5e-6 mm off the corner, within the attach tolerance
        // (1e-5): it attaches, so the committed line starts on the corner,
        // not on the drop; the preview must show the same (its own T).
        final corner = plan.at(2550, 100) + Vector2(5e-6, 0);
        expect(bruteCandidates(doc, corner), [AttachedEnd(s, 0, r)],
            reason: 'premise: S/0/right alone');
        final dim = addDimension(doc, fixedAt(plan.at(1000.25, 2000.5)),
            fixedAt(plan.at(4000.5, 2500.25)),
            kind: DimKind.aligned, offset: 300.75);
        final preview =
            grips.preview(doc, dim, gripOf(grips, doc, dim, 1), corner);
        drop(grips, doc, dim, 1, corner, 'onto the far jamb corner');
        final lines = dimLines(doc, dim);
        expect((at(gripOf(grips, doc, dim, 1)) - corner).length,
            closeTo(5e-6, 1e-7),
            reason: 'premise: the committed end is the corner, not the drop');
        for (var i = 0; i < 5; i++) {
          final c = preview[i].$2.coords;
          expectNear(Vector2(c[0], c[1]), lines[i].$1, 1e-9, 'flush, $i');
          expectNear(Vector2(c[2], c[3]), lines[i].$2, 1e-9, 'flush, $i');
        }
        expect(paramsOf(doc, dim).a, AttachedEnd(s, 0, r));
        expect(driftOf(doc), isEmpty);
      }

      // -- The other end (AM3's L, B with the lower handle). B (4000, 0) ->
      // (4000, 3000), then A (0, 0) -> (4000, 0), 200 centred; the inner
      // corner (3900, 100) is B/0/left and A/1/left. The dimension's group
      // sits at the placement, so horizontal runs along A and vertical
      // along B.
      {
        final (doc, hs) = docOfWalls(worldWalls(const [
          W(4000, 0, 4000, 3000, 200),
          W(0, 0, 4000, 0, 200),
        ], place));
        attachPage(doc, mmPage);
        final bw = hs[0], aw = hs[1];
        expect(bw.value < aw.value, isTrue, reason: 'premise: B is lower');
        final (grips, index) = gripsFor(doc);
        final inner = place.at(3900, 100);
        expect(
            attachCandidates(doc, index, inner,
                objectSnap: true, thickest: thickestWall(doc)),
            [AttachedEnd(bw, 0, l), AttachedEnd(aw, 1, l)],
            reason: 'premise: the inner corner is B/0/left and A/1/left');
        // Decision 22 at a drop: the dropped end is decided with the
        // current kind and, for aligned, the other end's current point. The
        // outer corner (4100, −100) is B/0/right and A/1/right; b fixed at
        // (3000, 3000). Aligned: u ∝ (3000 − 4100, 3000 + 100) = (−1,100,
        // 3,100), |·| = 3,289.4, so σ_B = |u.x| = 0.334 < σ_A = |u.y| =
        // 0.942: B/0/right. Horizontal: u = the group's x, along A, σ_A = 0:
        // A/1/right.
        final outer = place.at(4100, -100);
        expect(
            attachCandidates(doc, index, outer,
                objectSnap: true, thickest: thickestWall(doc)),
            [AttachedEnd(bw, 0, r), AttachedEnd(aw, 1, r)],
            reason: 'premise: the outer corner is B/0/right and A/1/right');
        for (final (kind, want) in [
          (DimKind.aligned, AttachedEnd(bw, 0, r)),
          (DimKind.horizontal, AttachedEnd(aw, 1, r)),
        ]) {
          final far = fixedAt(place.at(3000, 3000), place.m);
          final dim = addDimension(
              doc, fixedAt(place.at(1500.25, 2000.5), place.m), far,
              kind: kind, offset: 300.75, at: place.m);
          drop(grips, doc, dim, 1, outer, '${kind.name} onto the corner');
          expect(paramsOf(doc, dim).a, want, reason: kind.name);
          expect(paramsOf(doc, dim).b, far, reason: '${kind.name}: b kept');
        }

        // 1. Horizontal from A/0/left to a fixed point; its b dropped on
        // the inner corner: u = the group's x, along A, σ_A = 0 < σ_B = 1,
        // so A/1/left.
        final dim = addDimension(doc, AttachedEnd(aw, 0, l),
            fixedAt(place.at(2000.5, 1800.25), place.m),
            kind: DimKind.horizontal, offset: 400.5, at: place.m);
        drop(grips, doc, dim, 2, inner, 'b onto the inner corner');
        expect(paramsOf(doc, dim).b, AttachedEnd(aw, 1, l),
            reason: 'stored on A, the wall the kind runs along');
        // 2. The kind switched to vertical, the kind alone (the command
        // the panel issues): the corner end is not re-decided.
        doc.commands.execute(SetComponentCommand<DimensionParams>(
            dim, paramsOf(doc, dim).copyWith(kind: DimKind.vertical)));
        expect(paramsOf(doc, dim).b, AttachedEnd(aw, 1, l));
        // 3. The other end, a, dropped at (0, 1500), where nothing
        // attaches. Re-deciding the corner now (vertical: u along B, σ_B =
        // 0) would store B/0/left; the corner end keeps A/1/left.
        final q = place.at(0, 1500);
        expect(
            attachCandidates(doc, index, q,
                objectSnap: true, thickest: thickestWall(doc)),
            isEmpty,
            reason: 'premise: nothing attaches at (0, 1500)');
        drop(grips, doc, dim, 1, q, 'a dragged');
        final p = paramsOf(doc, dim);
        expectNear((p.a as FixedEnd).point, Vector2(0, 1500), 1e-6,
            'a fixed at (0, 1500), local');
        expect(p.b, AttachedEnd(aw, 1, l), reason: 'the corner end kept');
        expect(p.kind, DimKind.vertical);
        expect(driftOf(doc), isEmpty);
      }
    });
  }

  for (final place in const [origin, corpusGroups]) {
    test(
        'GE4 a degenerate drop returns null; under runtime permissions no '
        'grip is hit and no drag lands; a broken dimension has no grips, at '
        '$place', () {
      final plan = buildPlan(c2Walls, place: place);
      final doc = plan.doc;
      attachPage(doc, mmPage);
      final [a, _] = plan.walls;
      var snap = true;
      final (grips, index) = gripsFor(doc, snap: () => snap);
      final g = turned(place, 30);

      // -- Degenerate. a fixed, b fixed: a dropped on b's point.
      final wa = place.at(500.25, 1500.5), wb = place.at(2500.75, 2200.25);
      final ff = addDimension(doc, fixedAt(wa, g), fixedAt(wb, g),
          kind: DimKind.aligned, offset: 250.5, at: g);
      final depth = doc.commands.undoDepth;
      expect(grips.drag(doc, ff, gripOf(grips, doc, ff, 1), wb), isNull,
          reason: 'a onto b\'s point');
      expect(grips.preview(doc, ff, gripOf(grips, doc, ff, 1), wb), isEmpty,
          reason: 'no preview of a refused drop');
      // a fixed, b = A/0/left (0, 100): a dropped on that wall end point,
      // with F3 on (it would store the same end) and off (a fixed point on
      // b's). Then b = A/1/left, the inner corner (3900, 100), and a dropped
      // there with F3 on: whichever wall it is stored on, the two points
      // coincide.
      final a0 = place.at(0, 100), inner = place.at(3900, 100);
      for (final (end, point) in [
        (AttachedEnd(a, 0, l), a0),
        (AttachedEnd(a, 1, l), inner),
      ]) {
        final dim = addDimension(doc, fixedAt(wa, g), end,
            kind: DimKind.aligned, offset: 250.5, at: g);
        for (final on in [true, false]) {
          snap = on;
          expect(
              grips.drag(doc, dim, gripOf(grips, doc, dim, 1), point), isNull,
              reason: 'a onto $end, F3 ${on ? 'on' : 'off'}');
        }
        snap = true;
      }
      expect(doc.commands.undoDepth, depth + 2, reason: 'no drop executed');

      // -- Runtime permissions, through a real grip cache: the control
      // hits each grip under full permissions; runtime hits none, and a
      // drag's command is null.
      final selection = SelectionController(doc);
      final outlines = OutlineCache(doc, selection);
      final objects = ObjectGrips(edgeAperture: () => null, index: index);
      final cache = GripCache(doc, selection, outlines, objects: objects);
      addTearDown(() {
        cache.dispose();
        outlines.dispose();
        selection.dispose();
      });
      selection.replace([SelectionKey.root(ff)]);
      final shown = [
        for (final ref in cache.grips)
          if (ref.object && ref.key.target == ff) ref.grip,
      ];
      expect(shown, grips.gripsOf(doc, ff), reason: 'the three grips shown');
      // 0.1 px/mm: the grips lie hundreds of mm apart, tens of pixels.
      final m = Transform2.translation(-0.1 * wa.x + 700, -0.1 * wa.y + 450)
          .multiply(Transform2.scale(0.1, 0.1));
      Offset screen(Grip gr) {
        final s = m.transformPoint(at(gr));
        return Offset(s.x, s.y);
      }

      final q = place.at(900.5, 1300.25);
      for (final gr in shown) {
        final hit = cache.hitTest(screen(gr), m);
        expect(hit, isNot(-1), reason: 'control: grip ${gr.index} is hit');
        expect(cache.grips[hit].grip, gr);
        final drag =
            GripDrag.reshapeObject(doc, SelectionKey.root(ff), gr, objects)!
              ..moveTo(q);
        expect(drag.command(DraftPermissions.all), isNotNull,
            reason: 'control: grip ${gr.index} lands with every permission');
      }
      doc.commands.permissions = DraftPermissions.runtime;
      for (final gr in shown) {
        expect(cache.hitTest(screen(gr), m), -1,
            reason: 'runtime: grip ${gr.index} is not hit');
        final drag =
            GripDrag.reshapeObject(doc, SelectionKey.root(ff), gr, objects)!
              ..moveTo(q);
        expect(drag.command(DraftPermissions.runtime), isNull,
            reason: 'runtime: grip ${gr.index} lands nothing');
      }
      doc.commands.permissions = DraftPermissions.all;

      // -- Broken: an attached end with k = 2 (D15). The control, k = 1,
      // has its three grips.
      final ok = addDimension(doc, AttachedEnd(a, 1, l), fixedAt(wa, g),
          kind: DimKind.aligned, offset: 250.5, at: g);
      expect(grips.gripsOf(doc, ok), hasLength(3));
      final broken = addDimension(doc, AttachedEnd(a, 2, l), fixedAt(wa, g),
          kind: DimKind.aligned, offset: 250.5, at: g);
      expect(grips.gripsOf(doc, broken), isEmpty);
      expect(objects.gripsOf(doc, broken), isEmpty);
    });
  }

  for (final place in const [origin, corpusGroups]) {
    test(
        'GE5 the preview equals the committed lines on a horizontal '
        'dimension over the non-axis pair, for an offset drag and an end '
        'drag, on a 1:50 mm page and a 1:100 ft-in page; after another '
        'dimension\'s drag abandoned the preview equals a fresh provider\'s, '
        'at $place', () {
      // The page's paper lengths enter the lines (D7): at 1:100 the
      // extension line's overshoot is 2 × 100 = 200 mm and a slash 3 × 100
      // = 300 mm, twice 1:50's, so a preview laid out on another page than
      // the document's differs from the committed lines.
      final ftIn100 = PageComponent()
          .copyWith(displayUnit: DisplayUnit.feetInches, scaleDenominator: 100);
      for (final page in [mmPage, ftIn100]) {
        final plan = buildPlan(const [], place: place);
        final doc = plan.doc;
        attachPage(doc, page);
        final (grips, _) = gripsFor(doc);
        final g = turned(place, 30);
        // Horizontal over (0, 0) and (3000, 1200): aligned would lay the
        // line along the pair, (3000, 1200) / 3231.1, not along the group's
        // x.
        final dim = addDimension(
            doc, const FixedEnd(0, 0), const FixedEnd(3000, 1200),
            kind: DimKind.horizontal, offset: 7.5, at: g);
        for (final (ordinal, local) in [
          (0, Vector2(1500.5, 2000.25)), // the offset: +800.25
          (2, Vector2(3500.75, 1700.5)), // b moved, fixed
          (1, Vector2(-400.25, -600.75)), // a moved, fixed
        ]) {
          final why = '1:${page.scaleDenominator}, grip $ordinal to $local';
          final q = g.transformPoint(local);
          final gr = gripOf(grips, doc, dim, ordinal);
          final preview = grips.preview(doc, dim, gr, q);
          expect(preview, hasLength(5), reason: why);
          drop(grips, doc, dim, ordinal, q, why);
          expect(paramsOf(doc, dim).kind, DimKind.horizontal);
          final lines = dimLines(doc, dim);
          // Premise: the page reached the children (the extension line at
          // a overshoots the dimension line by 2 paper mm).
          expect((lines[1].$2 - lines[0].$1).length,
              closeTo(2.0 * page.scaleDenominator, 1e-6),
              reason: '$why: premise: the page');
          for (var i = 0; i < 5; i++) {
            final (kind, payload) = preview[i];
            expect(kind, EntityKind.line);
            final p = payload.coords;
            expectNear(Vector2(p[0], p[1]), lines[i].$1, 1e-9, '$why: line $i');
            expectNear(Vector2(p[2], p[3]), lines[i].$2, 1e-9, '$why: line $i');
          }
        }
        expect(driftOf(doc), isEmpty);
      }

      // -- A drag abandoned for another dimension's (Task 11's re-review):
      // X's grip previewed, then Y's with no drop and no document change
      // in between, as after an Esc-cancelled drag. Y's previews equal a
      // fresh provider's, point for point, so no memo of X's leaks into Y.
      // X is aligned and fixed-fixed; Y horizontal with b attached to B's
      // end corner, so the two lay out differently at every drop point.
      final plan = buildPlan(c2Walls, place: place);
      final doc = plan.doc;
      attachPage(doc, mmPage);
      final [_, b] = plan.walls;
      final (memo, index) = gripsFor(doc);
      DimensionGrips fresh() =>
          DimensionGrips(index: index, objectSnap: () => true);
      final g = turned(place, 30);
      final x = addDimension(doc, fixedAt(plan.at(500.25, 1500.5), g),
          fixedAt(plan.at(2500.75, 2200.25), g),
          kind: DimKind.aligned, offset: 250.5, at: g);
      final y = addDimension(
          doc, AttachedEnd(b, 1, l), fixedAt(plan.at(1200.5, 2600.25), g),
          kind: DimKind.horizontal, offset: -180.25, at: g);
      final qs = [
        plan.at(4100, -100),
        plan.at(1700.5, 900.25),
        plan.at(3900, 100),
      ];
      List<double> flat(List<(EntityKind, GeometryPayload)> p) =>
          [for (final (_, pl) in p) ...pl.coords];
      void same(Handle h, int ordinal, String why) {
        for (final q in qs) {
          final gr = gripOf(memo, doc, h, ordinal);
          final got = flat(memo.preview(doc, h, gr, q));
          expect(got, hasLength(20), reason: '$why at $q: five lines');
          expect(got, flat(fresh().preview(doc, h, gr, q)),
              reason: '$why at $q');
        }
      }

      final depth = doc.commands.undoDepth;
      same(x, 1, 'X grip 1');
      same(y, 1, 'Y grip 1 after X\'s drag abandoned');
      same(y, 2, 'Y grip 2');
      same(x, 0, 'X grip 0');
      expect(doc.commands.undoDepth, depth, reason: 'no document change');
    });
  }

  test(
      'GE5b among 612 walls the end grip\'s previews along a face line lay '
      'each wall out once per drag, the drop lays out afresh, and a document '
      'change starts the memo afresh; the time per preview is printed',
      () async {
    final plan = dimGridDoor();
    final doc = plan.doc;
    attachPage(doc, mmPage);
    expect(plan.walls, hasLength(612));
    final (grips, _) = gripsFor(doc);
    final dim = addDimension(doc, const FixedEnd(24500.25, 25000.5),
        const FixedEnd(26500.75, 26000.25),
        kind: DimKind.aligned, offset: 300.5);
    // The history is capped; start it empty so a drop's step shows.
    doc.commands.clearHistory();
    final g1 = gripOf(grips, doc, dim, 1);
    // The path wall (24,000, 24,000) -> (27,000, 24,000), 200 centred: its
    // left face line y 24,100, from x 24,300 to 26,700 in 61 moves (step
    // 40), past the door's cut (x 25,050-25,950). Each move lies on that
    // line, so the path wall passes the line test, and 200 mm or more from
    // the nodes at x 24,000 and 27,000, beyond the neighbours' boxes (whose
    // face lines y 24,100 it also lies on).
    Vector2 on(int i) => Vector2(24300 + 40.0 * i, 24100);
    int layouts() => debugWallPointComputations;

    // -- One drag: the first preview lays the path wall out, the other 60
    // lay out nothing; the same 61 moves again lay out nothing.
    var w = layouts();
    final times = <int>[];
    for (var i = 0; i <= 60; i++) {
      final sw = Stopwatch()..start();
      final preview = grips.preview(doc, dim, g1, on(i));
      sw.stop();
      times.add(sw.elapsedMicroseconds);
      expect(preview, hasLength(5), reason: 'move $i');
    }
    expect(layouts(), w + 1, reason: 'the path wall, once per drag');
    for (var i = 60; i >= 0; i--) {
      grips.preview(doc, dim, g1, on(i));
    }
    expect(layouts(), w + 1, reason: 'the way back: nothing more');
    final first = times.first;
    times.sort();

    // -- The drop gathers afresh (Ruling 11-8): the path wall laid out
    // again, with no memo. The end stays fixed (no wall end point there).
    w = layouts();
    final q = on(30);
    drop(grips, doc, dim, 1, q, 'the drop on the face line');
    expect(layouts(), w + 1, reason: 'the drop lays out afresh');
    expect(paramsOf(doc, dim).a, isA<FixedEnd>());

    // -- A new drag makes a new memo: once more, then nothing.
    w = layouts();
    final g1b = gripOf(grips, doc, dim, 1);
    for (var i = 5; i < 15; i++) {
      grips.preview(doc, dim, g1b, on(i));
    }
    expect(layouts(), w + 1, reason: 'the next drag, once');

    // -- A document change (a far wall moved), heard at a pump: the memo
    // starts afresh within the same drag.
    doc.commands.execute(SetComponentCommand<WallParams>(plan.walls[0],
        const WallParams(0, -0.25, 3000, -0.25, 200, Justification.centre)));
    await Future<void>.delayed(Duration.zero);
    w = layouts();
    for (var i = 15; i < 25; i++) {
      grips.preview(doc, dim, g1b, on(i));
    }
    expect(layouts(), w + 1, reason: 'once after the change');

    // ignore: avoid_print
    print('GE5b 612 walls: end-grip preview along a face line: first '
        '$first us, median ${times[times.length ~/ 2]} us, worst '
        '${times.last} us, over 1 ms ${times.where((t) => t > 1000).length}'
        '/61 (printed, not asserted)');
  });
}
