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
            fresh.index.snapInto(point, 2.0, mask, out);
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
    });
  }
}
