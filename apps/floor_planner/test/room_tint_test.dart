// Spec 10 D9: the tint's shape, `tintOf`, tested directly (TN1). Each case
// is written in plan mm and handed to `tintOf` as the tracer's seed-relative
// frame would: placed at each of the six placements and taken relative to
// a seed, so the holes' order, their rightmost vertices and the bridges are
// decided on turned coordinates too.
import 'dart:typed_data';

import 'package:floor_planner/parametric/room_inputs.dart';
import 'package:floor_planner/parametric/room_trace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/room_fixture.dart';

/// [xy] at [place], relative to the plan point (5,000, 5,000): the tracer's
/// seed-relative frame.
List<Vector2> rel(Placement place, List<(double, double)> xy) {
  final seed = place.at(5000, 5000);
  return [for (final (x, y) in xy) place.at(x, y) - seed];
}

/// The engine's triangulation of the closed ring [r], as `AddRegionCommand`
/// computes it.
Int32List? triangles(List<Vector2> r) =>
    triangulationFor(EntityKind.polyline, polylinePayload(r, closed: true));

/// Asserts that every point of [outer] is among [points], exactly.
void expectOuterKept(List<Vector2> points, List<Vector2> outer, String what) {
  for (final p in outer) {
    expect(points.any((q) => q.x == p.x && q.y == p.y), isTrue,
        reason: '$what: outer vertex $p kept');
  }
}

/// [hole]'s rightmost vertex (the first, walking it clockwise
/// from its last point, of those with the greatest x).
Vector2 rightmostOf(List<Vector2> hole) {
  final cw = hole.reversed.toList();
  var hi = 0;
  for (var i = 1; i < cw.length; i++) {
    if (cw[i].x > cw[hi].x) hi = i;
  }
  return cw[hi];
}

/// Asserts that [points] joins [hole] by D9's keyhole: its rightmost vertex
/// `H` follows the bridge's far end `V`; the hole is walked clockwise from
/// `H`; then `H` and `V` again, both moved 0.5 mm to the bridge's right.
/// Returns `V`, and [points] without the hole's run (so a hole joined
/// earlier, into which this one was inserted, can be checked next).
(Vector2, List<Vector2>) expectKeyhole(
    List<Vector2> points, List<Vector2> hole, String what) {
  final h = rightmostOf(hole);
  final at = points.indexWhere((p) => p.x == h.x && p.y == h.y);
  expect(at, greaterThan(0), reason: '$what: H in the ring');
  final v = points[at - 1];
  final cw = hole.reversed.toList();
  final start = cw.indexWhere((p) => p.x == h.x && p.y == h.y);
  for (var j = 0; j < cw.length; j++) {
    final p = points[at + j], q = cw[(start + j) % cw.length];
    expect((p.x, p.y), (q.x, q.y), reason: '$what: hole point $j');
  }
  final h2 = points[at + cw.length], v2 = points[at + cw.length + 1];
  // The slit: the return edge 0.5 mm from the bridge, to its right (the
  // bridge runs V -> H), parallel to it.
  final d = (h - v).normalized();
  final right = Vector2(d.y, -d.x);
  for (final (moved, from) in [(h2, h), (v2, v)]) {
    expect((moved - from).length, closeTo(kSlit, 1e-9), reason: what);
    expect((moved - from).dot(right), closeTo(0.5, 1e-9),
        reason: '$what: to the bridge\'s right');
  }
  return (v, [...points]..removeRange(at, at + cw.length + 2));
}

/// Asserts that the closed ring [r] is simple: no two points within 1e-6
/// of each other, no two edges that do not share a point properly
/// crossing, and no point within 1e-6 of an edge it is not an end of.
void expectSimple(List<Vector2> r, String what) {
  final n = r.length;
  double side(Vector2 o, Vector2 p, Vector2 q) =>
      (p.x - o.x) * (q.y - o.y) - (p.y - o.y) * (q.x - o.x);
  double segDist(Vector2 p, Vector2 a, Vector2 b) {
    final d = b - a;
    final t = ((p - a).dot(d) / d.dot(d)).clamp(0.0, 1.0);
    return (p - (a + d * t)).length;
  }

  for (var i = 0; i < n; i++) {
    for (var j = i + 1; j < n; j++) {
      expect((r[i] - r[j]).length, greaterThan(1e-6),
          reason: '$what: points $i and $j apart');
    }
  }
  for (var i = 0; i < n; i++) {
    final a = r[i], b = r[(i + 1) % n];
    for (var k = 0; k < n; k++) {
      if (k == i || k == (i + 1) % n) continue;
      expect(segDist(r[k], a, b), greaterThan(1e-6),
          reason: '$what: point $k off edge $i');
    }
    for (var j = i + 2; j < n; j++) {
      if (i == 0 && j == n - 1) continue;
      final c = r[j], d = r[(j + 1) % n];
      final d1 = side(c, d, a), d2 = side(c, d, b);
      final d3 = side(a, b, c), d4 = side(a, b, d);
      expect(
          ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
              ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0)),
          isFalse,
          reason: '$what: edges $i and $j cross');
    }
  }
}

void main() {
  test(
      'TN1 tintOf: a pinched ring takes step 3; a second hole whose view is '
      'blocked by the first bridges to the growing ring; a hole with no '
      'visible vertex is left out and reported', () {
    expect(kSlit, 0.5);
    for (final place in placements) {
      // 1. A pinched ring: two 1,000 x 1,000 squares touching at (6,000,
      // 6,000), walked as one anticlockwise face that passes that vertex
      // twice (as a face walk can where two bands meet at one corner). The
      // triangulator finds no ear at the pinch, so neither the keyholed ring
      // (here the ring itself) nor the outer ring fills: step 3, the ring
      // as given.
      var what = 'the pinched ring at $place';
      final pinched = rel(place, const [
        (5000.5, 5000.25),
        (6000, 5000.25),
        (6000, 6000),
        (7000.75, 6000),
        (7000.75, 7000.5),
        (6000, 7000.5),
        (6000, 6000),
        (5000.5, 6000),
      ]);
      expect(triangles(pinched), isEmpty, reason: '$what: premise');
      var t = tintOf(pinched, const []);
      expect(t.step, 3, reason: what);
      expect([
        for (final p in t.points) (p.x, p.y)
      ], [
        for (final p in pinched) (p.x, p.y)
      ], reason: what);
      expect(t.holesLeftOut, isEmpty, reason: what);
      expect(t.isExact, isFalse, reason: what);

      // 2. Two holes in a 10 m square with a notch vertex N (8,000, 5,000)
      // on its east side. A, tall (x 6,000..7,000, y 1,000..9,000), has the
      // greater rightmost x and joins first. B (x 5,000..5,500, y
      // 4,900..5,100) is nearest N (about 2,502 away), but its bridge to N
      // runs straight through A. Its nearest vertex whose bridge crosses no
      // edge of the growing ring is one of A's west corners (about 3,932
      // away): B bridges to A, now part of the ring. Step 1, and the ring
      // triangulates.
      what = 'the blocked hole at $place';
      final outer = rel(place, const [
        (0, 0),
        (10000, 0),
        (10000, 4500),
        (8000, 5000),
        (10000, 5500),
        (10000, 10000),
        (0, 10000),
      ]);
      final a = rel(place, const [
        (6000, 1000),
        (7000, 1000),
        (7000, 9000),
        (6000, 9000),
      ]);
      final b = rel(place, const [
        (5000, 4900),
        (5500, 4900),
        (5500, 5100),
        (5000, 5100),
      ]);
      final n = outer[3];
      // Premises: N is B's nearest ring vertex, and A stands in the way.
      final hb = rightmostOf(b);
      for (final p in [...outer, ...a]) {
        expect((n - hb).length, lessThanOrEqualTo((p - hb).length),
            reason: '$what: N nearest');
      }
      expect(rightmostOf(a).x, greaterThan(hb.x), reason: '$what: A first');
      t = tintOf(outer, [b, a]);
      expect(t.step, 1, reason: what);
      expect(t.holesLeftOut, isEmpty, reason: what);
      expect(t.isExact, isTrue, reason: what);
      expectOuterKept(t.points, outer, what);
      // The outer ring, then each hole and its two slit points.
      expect(t.points, hasLength(7 + (4 + 2) * 2), reason: what);
      // B joined last, into A's run: B first, then A in what is left.
      final (vb, withoutB) = expectKeyhole(t.points, b, '$what, B');
      expect(a.any((p) => p.x == vb.x && p.y == vb.y), isTrue,
          reason: '$what: B bridges to A, a vertex of the growing ring');
      final (va, _) = expectKeyhole(withoutB, a, '$what, A');
      expect(outer.contains(va), isTrue,
          reason: '$what: A bridges to the ring');
      expect(triangles(t.points), isNotEmpty, reason: '$what: triangulates');

      // 3. A hole with no visible vertex: a triangle whose tip H (21,000,
      // 5,000) points away from the ring. Every ring vertex lies within 45
      // deg of west from H (the farthest off is (10,000, 10,000), at atan
      // (5,000 / 11,000) ~ 24.4 deg), inside the triangle's own wedge, so
      // every bridge crosses the triangle's west edge. It is left out and
      // reported; A still joins, and the tint takes step 1.
      //
      // This branch is defensive: a real trace never reaches it. Holes join
      // in descending order of their rightmost x, so a ray to the right
      // from a hole's rightmost vertex H meets the growing ring first (the
      // holes not yet joined lie at x <= H.x; the joined ones are part of
      // the ring), and some ring vertex is visible from H (Eberly's
      // argument). A hole outside the ring is a unit-level stand-in.
      what = 'the hidden hole at $place';
      final square = rel(place, const [
        (0, 0),
        (10000, 0),
        (10000, 10000),
        (0, 10000),
      ]);
      final hidden = rel(place, const [
        (20000, 4000),
        (21000, 5000),
        (20000, 6000),
      ]);
      t = tintOf(square, [a, hidden]);
      expect(t.step, 1, reason: what);
      expect(t.holesLeftOut, [1], reason: what);
      expect(t.isExact, isFalse, reason: what);
      expectOuterKept(t.points, square, what);
      expect(t.points, hasLength(4 + 4 + 2), reason: what);
      expectKeyhole(t.points, a, '$what, A');
      for (final p in hidden) {
        expect(t.points.any((q) => q.x == p.x && q.y == p.y), isFalse,
            reason: '$what: no point of the hidden hole');
      }
      expect(triangles(t.points), isNotEmpty, reason: what);

      // 4. Traced: a column (x 3,800..4,200, y 1,800..2,200) whose east face
      // is flush with the west face of a stub below it (x 4,200..4,320, y
      // 100..1,000). Unturned, the column's top-right corner H (4,200,
      // 2,200) sees the stub's corner (4,200, 1,000) along its own east
      // edge, through its corner (4,200, 1,800): no proper crossing, yet
      // the bridge would lie on that edge and the ring would not be simple
      // (the review's I-1, step 2 before the fix). A vertex strictly inside
      // the bridge blocks it: step 1, the ring simple and triangulable.
      what = 'a column flush with a stub below it at $place';
      final plan = buildPlan([
        ...boxWalls,
        const W(4260, 0, 4260, 1000, 120),
        const W(3800, 2000, 4200, 2000, 400),
      ], place: place);
      final inputs = RoomInputs(plan.doc);
      addTearDown(inputs.dispose);
      final seed = plan.at(1000, 3000);
      final traced = traceRoomAmong(seed, inputs) as Traced;
      // 7,800 x 3,800 - 120 x 900 - 400 x 400 = 29,640,000 - 108,000 -
      // 160,000 = 29,372,000.
      expect(traced.area, closeTo(29372000, 1e-2), reason: what);
      expect(traced.holes, hasLength(1), reason: what);
      final ringRel = [for (final p in traced.ring) p - seed];
      final column = [for (final p in traced.holes.single) p - seed];
      t = tintOf(ringRel, [column]);
      expect(t.step, 1, reason: '$what: $t');
      expect(t.holesLeftOut, isEmpty, reason: what);
      expect(t.isExact, isTrue, reason: what);
      expectOuterKept(t.points, ringRel, what);
      expect(t.points, hasLength(ringRel.length + 4 + 2), reason: what);
      expectKeyhole(t.points, column, what);
      expectSimple(t.points, what);
      expect(triangles(t.points), isNotEmpty, reason: '$what: triangulates');

      // 5. Two holes that overlap (a file's, never a trace's): C's rightmost
      // vertices lie inside A2, so C joins at one of A2's corners and its
      // edges cross A2's. The keyholed ring does not triangulate; the outer
      // ring alone does: step 2, the outer ring as given.
      what = 'overlapping holes at $place';
      final a2 = rel(place, const [
        (4000, 4000),
        (6000, 4000),
        (6000, 6000),
        (4000, 6000),
      ]);
      final c = rel(place, const [
        (3000, 4500),
        (5000, 4500),
        (5000, 5500),
        (3000, 5500),
      ]);
      t = tintOf(square, [a2, c]);
      expect(t.step, 2, reason: what);
      expect([
        for (final p in t.points) (p.x, p.y)
      ], [
        for (final p in square) (p.x, p.y)
      ], reason: what);
      expect(t.holesLeftOut, isEmpty, reason: what);
      expect(t.isExact, isFalse, reason: what);
    }
  });
}
