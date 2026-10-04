// Spec 09b D6 "The ghost", F-14, plan 09b Task 5: the ghost's local path
// and its matrix.
//
// Fixtures (plan P-3): real entries of the committed asset, read by `File`
// and decoded by `SymbolLibrary.decode`; every base point is off the origin.
// `office.chair` carries two circles and an arc (start π/4, sweep π/2),
// `bath.toilet` two arcs (start π, sweep π, so its endpoints alone cannot
// tell the sweep's sign: its mid point can), `dining.table.rect.six` closed
// polylines and lines. The placement point and the rebase origin are both
// far from zero and from each other; every quarter turn, mirrored and not.
//
// The expected values are computed here independently of the code under
// test: the quarter-turn directions are a literal table, the mirror flips
// the local x before the turn, and the arc points come from the engine's
// `leafGrips` (its `c + r·(cos θ, sin θ)` convention).
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:jet_cad_floor_plan/src/symbols/symbol_ghost.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_library.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

final SymbolLibrary library = SymbolLibrary.decode(
    File('assets/library/furniture.jetlib').readAsBytesSync());

SymbolEntry entry(String key) =>
    library.entries.singleWhere((e) => e.key == key);

/// Local +x after `q` counter-clockwise quarter turns: a literal table.
const List<(double, double)> turned = [(1, 0), (0, 1), (-1, 0), (0, -1)];

final Vector2 at = Vector2(73250.5, -41810.25);
final Vector2 origin = Vector2(70000, -40000);

/// [m] (column-major 4×4) applied to the point (x, y).
(double, double) apply(Float64List m, double x, double y) =>
    (m[0] * x + m[4] * y + m[12], m[1] * x + m[5] * y + m[13]);

/// The placement of the local point (x, y), less [origin]: `at + R(q) ·
/// S(mirror) · (p − base) − origin`, from the table.
(double, double) expectedWorld(SymbolEntry e, int q, bool mirrored, double x,
    double y, Vector2 at, Vector2 origin) {
  final b = e.definition.basePoint;
  final u = (x - b.x) * (mirrored ? -1 : 1), v = y - b.y;
  final (xx, xy) = turned[q];
  final (yx, yy) = turned[(q + 1) % 4];
  return (
    at.x + u * xx + v * yx - origin.x,
    at.y + u * xy + v * yy - origin.y,
  );
}

/// Every stored coordinate pair of every leaf of [e], local.
Iterable<(double, double)> leafPoints(SymbolEntry e) sync* {
  for (final l in e.leaves) {
    final c = l.payload.coords;
    for (var i = 0; i + 1 < c.length; i += 2) {
      yield (c[i], c[i + 1]);
    }
  }
}

void expectPoint((double, double) actual, (double, double) expected,
    double tolerance, String reason) {
  expect(actual.$1, closeTo(expected.$1, tolerance), reason: '$reason (x)');
  expect(actual.$2, closeTo(expected.$2, tolerance), reason: '$reason (y)');
}

(double, double) offsetOf(ui.Offset o) => (o.dx, o.dy);

const keys = ['office.chair', 'bath.toilet', 'dining.table.rect.six'];

void main() {
  test('the fixtures are not degenerate', () {
    for (final key in keys) {
      final b = entry(key).definition.basePoint;
      expect(b.x != 0 || b.y != 0, isTrue, reason: '$key base point');
    }
    expect(entry('office.chair').leaves.map((l) => l.record.kind),
        containsAll([EntityKind.circle, EntityKind.arc]));
    expect(entry('bath.toilet').leaves.map((l) => l.record.kind),
        contains(EntityKind.arc));
    expect(at.x != origin.x && at.y != origin.y, isTrue);
  });

  group('the matrix', () {
    test(
        'maps the base point to at − origin, local +x and +y to the turned '
        'and mirrored directions, and every leaf point to its placement', () {
      for (final key in keys) {
        final e = entry(key);
        final b = e.definition.basePoint;
        for (var q = 0; q < 4; q++) {
          for (final mirrored in [false, true]) {
            final why = '$key q=$q mirrored=$mirrored';
            final g = GhostMatrix()
              ..update(
                  at: at, basePoint: b, quarterTurns: q, mirrored: mirrored);
            final m = g.forOrigin(origin);
            expectPoint(apply(m, b.x, b.y), (at.x - origin.x, at.y - origin.y),
                1e-9, '$why base point');
            final (xx, xy) = turned[q];
            final s = mirrored ? -1.0 : 1.0;
            // The linear part is exact for quarter turns.
            expect((m[0], m[1]), (s * xx, s * xy), reason: '$why local +x');
            expect((m[4], m[5]), turned[(q + 1) % 4], reason: '$why local +y');
            for (final (x, y) in leafPoints(e)) {
              expectPoint(apply(m, x, y),
                  expectedWorld(e, q, mirrored, x, y, at, origin), 1e-9, why);
            }
            // The rest of the storage stays the identity's.
            for (final i in [2, 3, 6, 7, 8, 9, 11, 14]) {
              expect(m[i], 0.0, reason: '$why m[$i]');
            }
            expect([m[10], m[15]], [1.0, 1.0], reason: why);
          }
        }
      }
    });

    test('writeGhostMatrix writes translate(−origin) ∘ P into an identity', () {
      final e = entry('office.chair');
      final b = e.definition.basePoint;
      final p = placementTransform(
          at: at, basePoint: b, quarterTurns: 3, mirrored: true);
      final m = identityGhostMatrix();
      writeGhostMatrix(m, p, origin);
      expect(m.toList(), [
        p.a, p.b, 0, 0, //
        p.c, p.d, 0, 0, //
        0, 0, 1, 0, //
        p.e - origin.x, p.f - origin.y, 0, 1,
      ]);
      expectPoint(apply(m, b.x, b.y), (at.x - origin.x, at.y - origin.y), 1e-9,
          'base point');
      for (final (x, y) in leafPoints(e)) {
        expectPoint(apply(m, x, y), expectedWorld(e, 3, true, x, y, at, origin),
            1e-9, '($x, $y)');
      }
    });

    test('P is computed only when the placement changes, not the origin', () {
      final b = entry('bath.toilet').definition.basePoint;
      final g = GhostMatrix()
        ..update(at: at, basePoint: b, quarterTurns: 1, mirrored: true);
      expect(g.computations, 1);
      final linear = [g.storage[0], g.storage[1], g.storage[4], g.storage[5]];

      // Three paints at three origins: the translation follows each, P stays.
      for (final o in [origin, Vector2(-5000, 92000), Vector2(70001, -40000)]) {
        g.update(
            at: at.clone(),
            basePoint: b.clone(),
            quarterTurns: 1,
            mirrored: true);
        final m = g.forOrigin(o);
        expect((m[12], m[13]), (g.placement!.e - o.x, g.placement!.f - o.y));
        expect([m[0], m[1], m[4], m[5]], linear);
      }
      expect(g.computations, 1);
      expect(identical(g.forOrigin(origin), g.storage), isTrue);

      g.update(
          at: at + Vector2(10, 0),
          basePoint: b,
          quarterTurns: 1,
          mirrored: true);
      expect(g.computations, 2, reason: 'at changed');
      g.update(
          at: at + Vector2(10, 0),
          basePoint: b,
          quarterTurns: 2,
          mirrored: true);
      expect(g.computations, 3, reason: 'turns changed');
      g.update(
          at: at + Vector2(10, 0),
          basePoint: b,
          quarterTurns: 2,
          mirrored: false);
      expect(g.computations, 4, reason: 'mirror changed');
      final other = entry('office.chair').definition.basePoint;
      g.update(
          at: at + Vector2(10, 0),
          basePoint: other,
          quarterTurns: 2,
          mirrored: false);
      expect(g.computations, 5, reason: 'base point changed');
      expectPoint(apply(g.forOrigin(origin), other.x, other.y),
          (at.x + 10 - origin.x, at.y - origin.y), 1e-9, 'new base point');
    });

    test(
        'a change of the base point\'s x alone, then of its y alone, each '
        'recomputes P once', () {
      final b = entry('office.chair').definition.basePoint;
      final g = GhostMatrix()
        ..update(at: at, basePoint: b, quarterTurns: 3, mirrored: true);
      expect(g.computations, 1);
      final onlyX = Vector2(b.x + 125, b.y);
      g.update(at: at, basePoint: onlyX, quarterTurns: 3, mirrored: true);
      expect(g.computations, 2, reason: 'base point x changed');
      expectPoint(apply(g.forOrigin(origin), onlyX.x, onlyX.y),
          (at.x - origin.x, at.y - origin.y), 1e-9, 'x-moved base point');
      final onlyY = Vector2(onlyX.x, onlyX.y - 75);
      g.update(at: at, basePoint: onlyY, quarterTurns: 3, mirrored: true);
      expect(g.computations, 3, reason: 'base point y changed');
      expectPoint(apply(g.forOrigin(origin), onlyY.x, onlyY.y),
          (at.x - origin.x, at.y - origin.y), 1e-9, 'y-moved base point');
    });
  });

  group('the path', () {
    test('a closed polyline\'s contour is closed, a line\'s is not', () {
      final e = entry('dining.table.rect.six');
      final metrics = ghostPathFor(e).computeMetrics().toList();
      expect(metrics.length, e.leaves.length);
      var closed = 0, open = 0;
      for (var i = 0; i < e.leaves.length; i++) {
        final leaf = e.leaves[i];
        final isClosed = leaf.record.kind == EntityKind.polyline &&
            isClosedPolyline(leaf.payload);
        expect(metrics[i].isClosed, isClosed,
            reason: '${leaf.record.kind.name} leaf $i');
        if (isClosed) {
          closed++;
        } else if (leaf.record.kind == EntityKind.line) {
          open++;
        }
      }
      expect(closed, 8, reason: 'closed polylines');
      expect(open, 6, reason: 'lines');
    });

    test('is cached: the same object on a second call, one per entry', () {
      final chair = entry('office.chair');
      final toilet = entry('bath.toilet');
      final p = ghostPathFor(chair);
      expect(identical(ghostPathFor(chair), p), isTrue);
      expect(identical(ghostPathFor(toilet), p), isFalse);
      expect(identical(ghostPathFor(toilet), ghostPathFor(toilet)), isTrue);
    });

    test(
        'has one contour per leaf, and its bounds are the leaves\' local '
        'bounds (every entry with no arc)', () {
      var checked = 0;
      for (final e in library.entries) {
        final path = ghostPathFor(e);
        expect(path.computeMetrics().length, e.leaves.length,
            reason: '${e.key} contours');
        if (e.leaves.any((l) => l.record.kind == EntityKind.arc)) continue;
        var l = double.infinity, t = double.infinity;
        var r = double.negativeInfinity, btm = double.negativeInfinity;
        for (final leaf in e.leaves) {
          final c = leaf.payload.coords;
          final rad = leaf.record.kind == EntityKind.circle
              ? leaf.payload.scalars[0]
              : 0;
          for (var i = 0; i + 1 < c.length; i += 2) {
            l = math.min(l, c[i] - rad);
            r = math.max(r, c[i] + rad);
            t = math.min(t, c[i + 1] - rad);
            btm = math.max(btm, c[i + 1] + rad);
          }
        }
        final bounds = path.getBounds();
        // Path coordinates are float32.
        expect(bounds.left, closeTo(l, 1e-3), reason: e.key);
        expect(bounds.top, closeTo(t, 1e-3), reason: e.key);
        expect(bounds.right, closeTo(r, 1e-3), reason: e.key);
        expect(bounds.bottom, closeTo(btm, 1e-3), reason: e.key);
        checked++;
      }
      expect(checked, greaterThan(20));
    });

    test(
        'an arc runs from the payload start to start + sweep, through the '
        'engine\'s mid point', () {
      var arcs = 0;
      for (final key in ['office.chair', 'bath.toilet']) {
        final e = entry(key);
        final metrics = ghostPathFor(e).computeMetrics().toList();
        for (var i = 0; i < e.leaves.length; i++) {
          final leaf = e.leaves[i];
          if (leaf.record.kind != EntityKind.arc) continue;
          final grips = leafGrips(leaf.record.kind, leaf.payload);
          final metric = metrics[i];
          (double, double) pos(double d) =>
              offsetOf(metric.getTangentForOffset(d)!.position);
          final start = (grips[1].x, grips[1].y);
          final end = (grips[2].x, grips[2].y);
          final mid = (grips[3].x, grips[3].y);
          expectPoint(pos(0), start, 1e-2, '$key leaf $i start');
          expectPoint(pos(metric.length), end, 1e-2, '$key leaf $i end');
          // Arc length metrics are approximate on conics.
          expectPoint(pos(metric.length / 2), mid, 0.5, '$key leaf $i mid');
          final r = leaf.payload.scalars[0];
          final sweep = leaf.payload.scalars[2];
          expect(metric.length, closeTo(r * sweep.abs(), 0.5));
          arcs++;
        }
      }
      expect(arcs, 3);
    });

    test(
        'drawn under the matrix, an arc lands where its placement puts it '
        '(mirrored and turned, far from the origin)', () {
      final e = entry('office.chair');
      final b = e.definition.basePoint;
      final i = e.leaves.indexWhere((l) => l.record.kind == EntityKind.arc);
      final leaf = e.leaves[i];
      final grips = leafGrips(leaf.record.kind, leaf.payload);
      for (var q = 0; q < 4; q++) {
        for (final mirrored in [false, true]) {
          final g = GhostMatrix()
            ..update(at: at, basePoint: b, quarterTurns: q, mirrored: mirrored);
          final world = ghostPathFor(e).transform(g.forOrigin(origin));
          final metric = world.computeMetrics().toList()[i];
          final why = 'q=$q mirrored=$mirrored';
          for (final (d, grip) in [
            (0.0, grips[1]),
            (metric.length, grips[2]),
            (metric.length / 2, grips[3]),
          ]) {
            expectPoint(
                offsetOf(metric.getTangentForOffset(d)!.position),
                expectedWorld(e, q, mirrored, grip.x, grip.y, at, origin),
                d == 0 || d == metric.length ? 1e-2 : 0.5,
                '$why at $d');
          }
        }
      }
    });
  });
}
