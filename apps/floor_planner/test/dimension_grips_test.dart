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
        'drag, at $place', () {
      final plan = buildPlan(const [], place: place);
      final doc = plan.doc;
      attachPage(doc, mmPage);
      final (grips, _) = gripsFor(doc);
      final g = turned(place, 30);
      // Horizontal over (0, 0) and (3000, 1200): aligned would lay the line
      // along the pair, (3000, 1200) / 3231.1, not along the group's x.
      final dim = addDimension(
          doc, const FixedEnd(0, 0), const FixedEnd(3000, 1200),
          kind: DimKind.horizontal, offset: 7.5, at: g);
      for (final (ordinal, local) in [
        (0, Vector2(1500.5, 2000.25)), // the offset: +800.25
        (2, Vector2(3500.75, 1700.5)), // b moved, fixed
        (1, Vector2(-400.25, -600.75)), // a moved, fixed
      ]) {
        final why = 'grip $ordinal to $local';
        final q = g.transformPoint(local);
        final gr = gripOf(grips, doc, dim, ordinal);
        final preview = grips.preview(doc, dim, gr, q);
        expect(preview, hasLength(5), reason: why);
        drop(grips, doc, dim, ordinal, q, why);
        expect(paramsOf(doc, dim).kind, DimKind.horizontal);
        final lines = dimLines(doc, dim);
        for (var i = 0; i < 5; i++) {
          final (kind, payload) = preview[i];
          expect(kind, EntityKind.line);
          final p = payload.coords;
          expectNear(Vector2(p[0], p[1]), lines[i].$1, 1e-9, '$why: line $i');
          expectNear(Vector2(p[2], p[3]), lines[i].$2, 1e-9, '$why: line $i');
        }
      }
      expect(driftOf(doc), isEmpty);
    });
  }
}
