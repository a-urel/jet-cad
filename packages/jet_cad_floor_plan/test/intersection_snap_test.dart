// Post-11 found item (a), reproduced on the sample plan: move P1 (the
// hall/living partition) by −300 mm, as the Plan 11 Task 4 probe did, and
// ask the engine for intersection snaps at the aperture the note measured
// (10 px at 0.05 px/mm, 200 mm).
//
// Every expected point is derived here, from the document, independently of
// the index: each root-container line and polyline leaf is taken to world by
// its own group chain (walked by hand), and crossings are computed by the
// parametric formula below. A **phantom** is where two leaves' *stored*
// coordinates cross with P1 on at least one side -- where an engine that read
// stored coordinates as world offered an intersection snap after the move.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/room_fixture.dart' show origin, samplePlan;

/// One root-container line or polyline leaf.
typedef _Leaf = ({Handle owner, List<Vector2> stored, List<Vector2> world});

/// A crossing of segment `a` of one leaf and segment `b` of another, at
/// parameters [t] and [u] along them.
typedef _Crossing = ({Vector2 p, double t, double u, double sin});

/// The transform from [owner]'s space to world when [owner] is the root or
/// a group chain up to it (the root container's leaves), else null.
Transform2? _toWorld(DraftDocument doc, Handle owner) {
  var acc = Transform2.identity();
  var h = owner;
  while (h != doc.rootHandle) {
    final node = doc.tree[h];
    if (node is! GroupNode) return null;
    acc = node.transform.multiply(acc);
    h = node.parent;
  }
  return acc;
}

List<_Leaf> _rootLineLeaves(DraftDocument doc) => [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.kindAt(slot) == EntityKind.line ||
            doc.entities.kindAt(slot) == EntityKind.polyline)
          if (_toWorld(doc, doc.entities.ownerAt(slot)) case final m?)
            () {
              final g = doc.geometry.peek(doc.entities.geomIndexAt(slot));
              final stored = [
                for (var i = 0; i < g.pointCount; i++) g.pointAt(i),
              ];
              return (
                owner: doc.entities.ownerAt(slot),
                stored: stored,
                world: [for (final p in stored) m.transformPoint(p)],
              );
            }(),
    ];

/// Every crossing of a segment of [a] with a segment of [b], with the clamp
/// widened by [slack] on each end.
List<_Crossing> _crossings(List<Vector2> a, List<Vector2> b,
    {double slack = 0}) {
  final out = <_Crossing>[];
  for (var i = 0; i + 1 < a.length; i++) {
    for (var j = 0; j + 1 < b.length; j++) {
      final r = a[i + 1] - a[i], s = b[j + 1] - b[j];
      final den = r.x * s.y - r.y * s.x;
      if (den == 0) continue;
      final qp = b[j] - a[i];
      final t = (qp.x * s.y - qp.y * s.x) / den;
      final u = (qp.x * r.y - qp.y * r.x) / den;
      if (t < -slack || t > 1 + slack || u < -slack || u > 1 + slack) {
        continue;
      }
      out.add((p: a[i] + r * t, t: t, u: u, sin: den / (r.length * s.length)));
    }
  }
  return out;
}

void main() {
  test(
      'a moved wall group: no intersection snap at the stored (phantom) '
      'crossings, and every crossing of its world geometry found', () {
    final plan = samplePlan(origin);
    addTearDown(plan.system.dispose);
    final doc = plan.doc;
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final p1 = plan.walls[4];
    expect(doc.tree[p1]!.transform.isIdentity, isTrue,
        reason: 'premise: P1 starts at the identity');

    // The select tool's whole-object move (03), −300 mm in x.
    doc.commands.execute(TransformNodeCommand(
        p1,
        Transform2.translation(-300, 0)
            .multiply(doc.tree.accumulatedTransform(p1))));

    const radius = kSnapAperturePixels / 0.05; // 200 mm at 0.05 px/mm
    const intersectionOnly = SnapMask(1 << 7);
    expect(intersectionOnly.has(SnapKind.intersection), isTrue);
    expect(intersectionOnly.bits & ~(1 << SnapKind.intersection.index), 0);

    final leaves = _rootLineLeaves(doc);
    final moved = [
      for (var i = 0; i < leaves.length; i++)
        if (leaves[i].owner == p1) i,
    ];
    expect(moved, isNotEmpty, reason: 'premise: P1 has line-like pieces');

    // Every world crossing, the clamp widened a hair so that a crossing on
    // a segment's end is never missed here by rounding: this is the set a
    // found snap must belong to.
    final world = <Vector2>[];
    for (var i = 0; i < leaves.length; i++) {
      for (var j = i + 1; j < leaves.length; j++) {
        world.addAll(_crossings(leaves[i].world, leaves[j].world, slack: 1e-9)
            .map((x) => x.p));
      }
    }
    double nearestWorld(Vector2 q) => world.fold(
        double.infinity, (m, w) => (w - q).length < m ? (w - q).length : m);

    // The phantoms: P1's stored pieces against every other piece, stored.
    final phantoms = <Vector2>[
      for (final i in moved)
        for (var j = 0; j < leaves.length; j++)
          if (j != i && !(moved.contains(j) && j < i))
            ..._crossings(leaves[i].stored, leaves[j].stored).map((x) => x.p),
    ];
    final bare = [
      for (final q in phantoms)
        if (nearestWorld(q) > radius) q,
    ];
    // ignore: avoid_print
    print('P1 moved -300: ${phantoms.length} stored crossings, '
        '${bare.length} with no world crossing within $radius mm');
    expect(bare, isNotEmpty,
        reason: 'premise: the move leaves stored crossings with nothing '
            'real within the aperture -- the reported symptom\'s points');

    // No query below can lose a real crossing to the candidate cap.
    int candidatesAt(Vector2 q) => leaves.where((l) {
          final xs = l.world.map((p) => p.x), ys = l.world.map((p) => p.y);
          return xs.reduce((a, b) => a < b ? a : b) <= q.x + radius &&
              xs.reduce((a, b) => a > b ? a : b) >= q.x - radius &&
              ys.reduce((a, b) => a < b ? a : b) <= q.y + radius &&
              ys.reduce((a, b) => a > b ? a : b) >= q.y - radius;
        }).length;

    final out = SnapResult();
    final drag = DragPoint();
    for (final q in phantoms) {
      expect(candidatesAt(q), lessThan(kIntersectionCandidateCap));
      index.snapInto(q, radius, intersectionOnly, out,
          filter: const QueryFilter.all());
      if (nearestWorld(q) > radius) {
        expect(out.found, isFalse,
            reason: 'phantom $q: nothing crosses within $radius, yet '
                '${out.kind} at ${out.point}');
        // The app's own route (spec D8), with its drag mask: whatever wins
        // there, it is not an intersection.
        resolveDragPoint(
            raw: q,
            orthoBase: null,
            index: index,
            apertureWorld: radius,
            objectSnap: true,
            page: null,
            gridStepMm: null,
            scratch: out,
            out: drag);
        expect(drag.objectKind, isNot(SnapKind.intersection),
            reason: 'phantom $q through resolveDragPoint: ${drag.point}');
      } else if (out.found) {
        expect(nearestWorld(out.point), lessThan(1e-6),
            reason: 'near phantom $q the snap ${out.point} is a world '
                'crossing');
      }
    }

    // Every crossing of P1's world geometry with anything, clear of both
    // segments' ends and not near-parallel, is found where it is.
    var aimed = 0;
    for (final i in moved) {
      for (var j = 0; j < leaves.length; j++) {
        if (j == i || (moved.contains(j) && j < i)) continue;
        for (final x in _crossings(leaves[i].world, leaves[j].world)) {
          if (x.t < 1e-6 || x.t > 1 - 1e-6) continue;
          if (x.u < 1e-6 || x.u > 1 - 1e-6) continue;
          if (x.sin.abs() < 1e-6) continue;
          aimed++;
          expect(candidatesAt(x.p), lessThan(kIntersectionCandidateCap));
          index.snapInto(x.p, radius, intersectionOnly, out,
              filter: const QueryFilter.all());
          expect(out.found, isTrue, reason: 'the moved crossing ${x.p}');
          expect(out.kind, SnapKind.intersection);
          expect((out.point - x.p).length, lessThan(1e-6),
              reason: 'the moved crossing ${x.p}: got ${out.point}');
        }
      }
    }
    // ignore: avoid_print
    print('P1 moved -300: $aimed world crossings of P1 aimed at');
    expect(aimed, greaterThan(0),
        reason: 'premise: P1 crosses something where it now is');
  });
}
