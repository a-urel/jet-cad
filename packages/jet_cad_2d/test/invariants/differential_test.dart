// The load-bearing test of the whole plan: every indexed query result must
// equal a brute-force linear scan over the same document (`reference_query
// .dart`), across the fixed corpus (`corpus.dart`). One property, checked
// as a *sequence* comparison (draw order is part of the contract, not an
// implementation detail) rather than a set comparison, which would pass
// while the order was wrong.
//
// Each fixture is exercised through a fresh `SpatialIndex` in its own test
// block, so a mutation `CorpusDocument.primeIndex` applies for one of the
// dirty-state or purge fixtures can never bleed into another block's query.
// `pickInto` and `snapInto` walk the whole tree once per trial via
// `allLeavesInWorld`, so that walk is computed once per test block and
// reused across all 200 trials rather than recomputed per trial -- the
// document does not change between queries in this harness, so nothing is
// lost by not recomputing it.
//
// Random points almost never land on a crossing, so intersection snapping
// is also checked at points *aimed* at every crossing and phantom the
// oracle's leaf list yields (`_crossingTargets`); the random-point snap test
// alone passed on `groupedCrossings` against an engine that intersected
// stored coordinates as world (post-11 found item (a)).

import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'corpus.dart';
import 'reference_query.dart';

/// A fresh document plus a fresh, freshly-primed index over it -- see
/// [CorpusDocument]'s own doc comment for why priming must happen against a
/// specific index instance rather than being baked into the document.
({DraftDocument doc, SpatialIndex index}) _fresh(CorpusDocument fixture) {
  final doc = fixture.build();
  final index = SpatialIndex(doc);
  fixture.primeIndex?.call(doc, index);
  return (doc: doc, index: index);
}

/// Generates rects across three deliberate regimes rather than relying on
/// pure randomness to occasionally cover them: comfortably outside the
/// document's extents (misses everything), comfortably containing them
/// (covers everything), and a small rect placed to plausibly clip a single
/// entity's edge. A generator that only ever produced mid-sized rects in the
/// populated region would test one case 200 times over.
Aabb2 _randomRect(math.Random rng, Aabb2 extents) {
  final base = extents.isEmpty ? const Aabb2.raw(-50, -50, 50, 50) : extents;
  final w = math.max(base.maxX - base.minX, 1.0);
  final h = math.max(base.maxY - base.minY, 1.0);

  switch (rng.nextInt(3)) {
    case 0: // covers everything, and then some
      final pad = math.max(w, h);
      return Aabb2.raw(
          base.minX - pad, base.minY - pad, base.maxX + pad, base.maxY + pad);
    case 1: // misses entirely -- well outside the extents
      final dx = w * (3 + rng.nextDouble() * 5);
      final dy = h * (3 + rng.nextDouble() * 5);
      final x = base.minX + dx;
      final y = base.minY + dy;
      final size = math.min(w, h) * 0.1 + rng.nextDouble();
      return Aabb2.raw(x, y, x + size, y + size);
    default: // small, somewhere in or near the extents -- may clip an edge
      final x = base.minX - w * 0.1 + rng.nextDouble() * (w * 1.2);
      final y = base.minY - h * 0.1 + rng.nextDouble() * (h * 1.2);
      final size = math.max(w, h) * (0.01 + rng.nextDouble() * 0.1);
      return Aabb2.raw(x, y, x + size, y + size);
  }
}

Vector2 _randomPoint(math.Random rng, Aabb2 extents) {
  final base = extents.isEmpty ? const Aabb2.raw(-50, -50, 50, 50) : extents;
  final w = math.max(base.maxX - base.minX, 1.0);
  final h = math.max(base.maxY - base.minY, 1.0);
  final pad = math.max(w, h) * 0.2;
  final x = base.minX - pad + rng.nextDouble() * (w + 2 * pad);
  final y = base.minY - pad + rng.nextDouble() * (h + 2 * pad);
  return Vector2(x, y);
}

/// Absolute tolerance scaled to the expected value's own magnitude: at the
/// `largeCoordinates` fixture's ~4.5e6 scale, a fixed `1e-9` is smaller than
/// a double's own precision there (ulp(4.5e6) is already ~1e-9), so it would
/// fail on rounding noise that has nothing to do with correctness. Both
/// sides compute in `Float64`, so `1e-6` relative to the coordinate's own
/// size is generous enough to absorb that and still tight enough to catch a
/// real disagreement.
void _expectClose(double actual, double expected, String reason) {
  final scale = math.max(1.0, expected.abs());
  expect(actual, closeTo(expected, scale * 1e-6), reason: reason);
}

/// The points an intersection snap can be right or wrong about, derived from
/// the oracle's own leaf list ([allLeavesInWorld]) rather than from any
/// index structure: every crossing, in world, of two root-level line or
/// polyline leaves (each through its own `toWorld`), and every **phantom**
/// -- where the same two leaves' *stored* coordinates cross, for a pair
/// with a non-identity transform on either side (an identity pair's stored
/// crossing is its world one).
///
/// Random points almost never land within the snap radius of a crossing,
/// which is how an engine that intersected stored coordinates as world
/// agreed with this oracle across the whole corpus (post-11 found item (a)).
List<Vector2> _crossingTargets(DraftDocument doc, List<LeafCandidate> leaves) {
  final lineLike = [
    for (final leaf in leaves)
      if (leaf.root == doc.entities.handleAt(leaf.slot) &&
          (doc.entities.kindAt(leaf.slot) == EntityKind.line ||
              doc.entities.kindAt(leaf.slot) == EntityKind.polyline))
        (
          toWorld: leaf.toWorld,
          stored: doc.geometry.peek(doc.entities.geomIndexAt(leaf.slot)),
        ),
  ];
  final out = <Vector2>[];
  for (var i = 0; i < lineLike.length; i++) {
    final a = lineLike[i];
    for (var j = i + 1; j < lineLike.length; j++) {
      final b = lineLike[j];
      final mapped = !a.toWorld.isIdentity || !b.toWorld.isIdentity;
      for (var sa = 0; sa + 1 < a.stored.pointCount; sa++) {
        for (var sb = 0; sb + 1 < b.stored.pointCount; sb++) {
          final a1 = a.stored.pointAt(sa), a2 = a.stored.pointAt(sa + 1);
          final b1 = b.stored.pointAt(sb), b2 = b.stored.pointAt(sb + 1);
          final world = segmentIntersectionTol(
              a.toWorld.transformPoint(a1),
              a.toWorld.transformPoint(a2),
              b.toWorld.transformPoint(b1),
              b.toWorld.transformPoint(b2),
              Tolerance.standard);
          if (world != null) out.add(world);
          if (!mapped) continue;
          final phantom =
              segmentIntersectionTol(a1, a2, b1, b2, Tolerance.standard);
          if (phantom != null) out.add(phantom);
        }
      }
    }
  }
  return out;
}

/// Offsets from each crossing target, all within the aimed test's 2.0
/// radius: the target itself, then three points around it in different
/// directions, so the nearest-crossing decision is exercised off the
/// crossing as well as on it.
final List<Vector2> _aimOffsets = [
  Vector2.zero(),
  Vector2(0.7, -0.4),
  Vector2(-1.3, 0.9),
  Vector2(0.2, 1.6),
];

void main() {
  for (final fixture in buildCorpus()) {
    group(fixture.name, () {
      test('entitiesInRect matches brute force over 200 random rects', () {
        final fresh = _fresh(fixture);
        addTearDown(fresh.index.dispose);
        final rng = math.Random(20260728);

        for (var trial = 0; trial < 200; trial++) {
          final rect = _randomRect(rng, fresh.doc.extents);
          for (final filter in const [
            QueryFilter.all(),
            QueryFilter.rendering(),
            QueryFilter.picking(),
          ]) {
            expect(
              fresh.index.entitiesInRect(rect, filter).toList(),
              referenceEntitiesInRect(fresh.doc, rect, filter),
              reason: '${fixture.name} trial $trial rect $rect '
                  'visibleOnly=${filter.visibleOnly} '
                  'excludeLocked=${filter.excludeLocked}',
            );
          }
        }
      });

      test('instancesInRect matches brute force over 200 random rects', () {
        final fresh = _fresh(fixture);
        addTearDown(fresh.index.dispose);
        final rng = math.Random(20260729);

        for (var trial = 0; trial < 200; trial++) {
          final rect = _randomRect(rng, fresh.doc.extents);
          for (final filter in const [
            QueryFilter.all(),
            QueryFilter.rendering(),
          ]) {
            final actual = <Handle>[];
            fresh.index.forEachInstanceInRect(rect, filter, actual.add);
            expect(
              actual,
              referenceInstancesInRect(fresh.doc, rect, filter),
              reason: '${fixture.name} trial $trial rect $rect '
                  'visibleOnly=${filter.visibleOnly}',
            );
          }
        }
      });

      test('pick matches brute force over 200 random points', () {
        final fresh = _fresh(fixture);
        addTearDown(fresh.index.dispose);
        final rng = math.Random(20260730);
        final hit = HitPath(32);
        final leaves = allLeavesInWorld(fresh.doc);

        for (var trial = 0; trial < 200; trial++) {
          final point = _randomPoint(rng, fresh.doc.extents);
          // Two radii: one tight enough to miss often, one loose enough
          // that several entities compete and the tie-break rule is
          // exercised.
          for (final radius in const [0.01, 5.0]) {
            final found = fresh.index
                .pickInto(point, radius, const QueryFilter.picking(), hit);
            final expected = referencePick(
                fresh.doc, point, radius, const QueryFilter.picking(), leaves);

            final reason = '${fixture.name} trial $trial at $point r=$radius';
            expect(found, expected != null, reason: reason);
            if (expected != null) {
              expect(hit.entity, expected.entity, reason: reason);
              expect(hit.kind, expected.kind, reason: reason);
              // The point too, not just entity and kind. Comparing only the
              // latter two is how an arc's `worldPoint` stayed a radial
              // projection with no sweep check across the whole corpus while
              // the snap half of this file had compared coordinates all
              // along.
              _expectClose(hit.worldPoint.x, expected.point.x, reason);
              _expectClose(hit.worldPoint.y, expected.point.y, reason);
            }
          }
        }
      });

      test('snap matches brute force over 200 random points', () {
        final fresh = _fresh(fixture);
        addTearDown(fresh.index.dispose);
        final rng = math.Random(20260731);
        final out = SnapResult(32);
        final leaves = allLeavesInWorld(fresh.doc);

        for (var trial = 0; trial < 200; trial++) {
          final point = _randomPoint(rng, fresh.doc.extents);
          for (final mask in [SnapMask.cheap, SnapMask.all]) {
            // `QueryFilter.all()` explicitly, not `snapInto`'s default:
            // `referenceSnap` applies no visibility or lock filtering at
            // all, so this is what makes the two sides answer the *same*
            // question rather than agreeing because no corpus fixture
            // happens to hide anything.
            fresh.index.snapInto(point, 2.0, mask, out,
                filter: const QueryFilter.all());
            final expected = referenceSnap(fresh.doc, point, 2.0, mask, leaves);

            final reason = '${fixture.name} trial $trial at $point '
                'mask=${mask.bits}';
            expect(out.found, expected != null, reason: reason);
            if (expected != null) {
              expect(out.kind, expected.kind, reason: reason);
              expect(out.entity, expected.entity, reason: reason);
              _expectClose(out.point.x, expected.point.x, reason);
              _expectClose(out.point.y, expected.point.y, reason);
            }
          }
        }
      });

      test('snap matches brute force at and around every crossing and phantom',
          () {
        final fresh = _fresh(fixture);
        addTearDown(fresh.index.dispose);
        final out = SnapResult(32);
        final leaves = allLeavesInWorld(fresh.doc);
        final targets = _crossingTargets(fresh.doc, leaves);
        if (fixture.name == 'groupedCrossings') {
          expect(targets.length, greaterThanOrEqualTo(20),
              reason: 'premise: the fixture built to be aimed at has '
                  'crossings and phantoms to aim at');
        }

        for (final target in targets) {
          for (final offset in _aimOffsets) {
            final point = target + offset;
            // Intersection alone first: under every wider mask a cheap kind
            // or `perpendicular` outranks `intersection` wherever a line is
            // in reach, which is at every crossing. The drag mask (the app's)
            // and `SnapMask.all` then check the ranking against it.
            for (final mask in [
              const SnapMask(0).with_(SnapKind.intersection),
              kDragSnapMask,
              SnapMask.all,
            ]) {
              fresh.index.snapInto(point, 2.0, mask, out,
                  filter: const QueryFilter.all());
              final expected =
                  referenceSnap(fresh.doc, point, 2.0, mask, leaves);

              final reason = '${fixture.name} aimed at $target, query $point '
                  'mask=${mask.bits}';
              expect(out.found, expected != null, reason: reason);
              if (expected != null) {
                expect(out.kind, expected.kind, reason: reason);
                expect(out.entity, expected.entity, reason: reason);
                _expectClose(out.point.x, expected.point.x, reason);
                _expectClose(out.point.y, expected.point.y, reason);
              }
            }
          }
        }
      });
    });
  }
}
