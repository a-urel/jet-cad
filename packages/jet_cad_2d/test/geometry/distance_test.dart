import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

GeometryPayload poly(List<double> coords) => GeometryPayload(
      coords: Float64List.fromList(coords),
      scalars: Float64List(0),
    );

void main() {
  group('distanceToSegment', () {
    test('is zero on the segment and at its endpoints', () {
      final a = Vector2(0, 0), b = Vector2(10, 0);
      expect(distanceToSegment(Vector2(5, 0), a, b), closeTo(0, 1e-12));
      expect(distanceToSegment(a, a, b), closeTo(0, 1e-12));
      expect(distanceToSegment(b, a, b), closeTo(0, 1e-12));
    });

    test('is the perpendicular distance beside the segment', () {
      expect(distanceToSegment(Vector2(5, 3), Vector2(0, 0), Vector2(10, 0)),
          closeTo(3, 1e-12));
    });

    test('clamps to the endpoint beyond the ends', () {
      // Beyond b, the answer is the distance to b, not to the infinite line.
      expect(distanceToSegment(Vector2(20, 0), Vector2(0, 0), Vector2(10, 0)),
          closeTo(10, 1e-12));
      expect(distanceToSegment(Vector2(-3, 4), Vector2(0, 0), Vector2(10, 0)),
          closeTo(5, 1e-12));
    });

    test('handles a degenerate zero-length segment', () {
      final p = Vector2(3, 4);
      expect(distanceToSegment(p, Vector2.zero(), Vector2.zero()),
          closeTo(5, 1e-12));
    });

    test('is exact at large coordinates', () {
      // 4.5e6 is where float32 would fail; Float64 must not.
      const big = 4500000.0;
      final d = distanceToSegment(
          Vector2(big + 5, big + 3), Vector2(big, big), Vector2(big + 10, big));
      expect(d, closeTo(3, 1e-9));
    });
  });

  group('distanceToCircle', () {
    test('is the distance to the rim, inside and out', () {
      final c = Vector2(0, 0);
      expect(distanceToCircle(Vector2(15, 0), c, 10), closeTo(5, 1e-12));
      expect(distanceToCircle(Vector2(5, 0), c, 10), closeTo(5, 1e-12),
          reason: 'a point inside is still 5 from the rim');
      expect(distanceToCircle(c, c, 10), closeTo(10, 1e-12));
      expect(distanceToCircle(Vector2(10, 0), c, 10), closeTo(0, 1e-12));
    });

    test('handles a zero radius as distance to the centre', () {
      expect(distanceToCircle(Vector2(3, 4), Vector2.zero(), 0),
          closeTo(5, 1e-12));
    });
  });

  group('distanceToArc', () {
    test('is zero on the arc and grows off it', () {
      // Quarter arc from 0 to pi/2, radius 10, centred at origin.
      final c = Vector2.zero();
      expect(distanceToArc(Vector2(10, 0), c, 10, 0, math.pi / 2),
          closeTo(0, 1e-9));
      expect(distanceToArc(Vector2(0, 10), c, 10, 0, math.pi / 2),
          closeTo(0, 1e-9));
      final mid =
          Vector2(10 * math.cos(math.pi / 4), 10 * math.sin(math.pi / 4));
      expect(distanceToArc(mid, c, 10, 0, math.pi / 2), closeTo(0, 1e-9));
    });

    test('measures to the nearer endpoint outside the sweep', () {
      // A point at angle pi (opposite side) is outside a 0..pi/2 arc, so the
      // answer is the distance to the nearer endpoint — (0, 10), at
      // sqrt(200) — not the distance to the far endpoint (10, 0), at 20, and
      // not the rim distance, which would be 0.
      final c = Vector2.zero();
      final d = distanceToArc(Vector2(-10, 0), c, 10, 0, math.pi / 2);
      expect(d, closeTo(math.sqrt(200), 1e-9),
          reason: 'clamping to the sweep is what separates an arc '
              'from a circle; without it this would be 0, and picking the '
              'wrong endpoint would give 20');
    });

    test('uses the sweep sign to place the far endpoint, not its negation', () {
      // A query point that lies on an axis of symmetry between the two
      // candidate endpoints cannot tell startAngle + sweep apart from
      // startAngle - sweep: both endpoint placements end up equidistant.
      // This fixture is deliberately off that axis, so getting the sign
      // wrong moves the far endpoint to a measurably different distance.
      final c = Vector2.zero();
      final p = Vector2(0, -20);
      const startAngle = 0.0;
      const sweep = math.pi / 3;

      final toStart = p.distanceTo(Vector2(10, 0));
      final toCorrectEnd = p.distanceTo(Vector2(
          10 * math.cos(startAngle + sweep),
          10 * math.sin(startAngle + sweep)));
      final toWrongEnd = p.distanceTo(Vector2(10 * math.cos(startAngle - sweep),
          10 * math.sin(startAngle - sweep)));
      expect(toCorrectEnd, isNot(closeTo(toWrongEnd, 1e-6)),
          reason: 'fixture must be asymmetric enough to separate the two '
              'endpoint placements, or this test cannot catch a sign error');

      final d = distanceToArc(p, c, 10, startAngle, sweep);
      expect(d, closeTo(math.min(toStart, toCorrectEnd), 1e-9));
    });

    test('handles a negative sweep', () {
      final c = Vector2.zero();
      expect(distanceToArc(Vector2(10, 0), c, 10, 0, -math.pi / 2),
          closeTo(0, 1e-9));
      expect(distanceToArc(Vector2(0, -10), c, 10, 0, -math.pi / 2),
          closeTo(0, 1e-9));
    });

    test('normalises containment across the 0/2pi seam', () {
      // Arc from 315 degrees sweeping 90 degrees CCW wraps through 0/360,
      // covering 315..360..45 — the same wrap angleInSweep's own test pins.
      final c = Vector2.zero();
      expect(distanceToArc(Vector2(10, 0), c, 10, 7 * math.pi / 4, math.pi / 2),
          closeTo(0, 1e-9),
          reason: 'angle 0 is inside the wrapped sweep');

      // Angle -90 degrees sits exactly on the rim (distance 10 from centre)
      // but outside the wrapped span. A wrap bug that fails to normalise the
      // modulo would misclassify it as inside the sweep and report 0.
      final d =
          distanceToArc(Vector2(0, -10), c, 10, 7 * math.pi / 4, math.pi / 2);
      expect(d, greaterThan(1));
    });

    test('a sweep of at least 2pi degenerates to a full circle', () {
      final c = Vector2.zero();
      // A point outside a partial 0..pi/2 sweep must read as on-arc once the
      // sweep covers the whole circle, exactly like distanceToCircle.
      expect(distanceToArc(Vector2(-10, 0), c, 10, 0, 2 * math.pi),
          closeTo(0, 1e-9));
      expect(distanceToArc(Vector2(-15, 0), c, 10, 0, 2 * math.pi + 1),
          closeTo(5, 1e-9));
    });

    test('handles a zero radius as distance to the centre', () {
      expect(distanceToArc(Vector2(3, 4), Vector2.zero(), 0, 0, math.pi / 2),
          closeTo(5, 1e-9));
    });
  });

  group('distanceToPolyline', () {
    test('is the minimum over every segment', () {
      final p = poly([0, 0, 10, 0, 10, 10]);
      expect(distanceToPolyline(Vector2(5, 2), p), closeTo(2, 1e-12));
      expect(distanceToPolyline(Vector2(12, 5), p), closeTo(2, 1e-12));
    });

    test('handles a single point', () {
      expect(
          distanceToPolyline(Vector2(3, 4), poly([0, 0])), closeTo(5, 1e-12));
    });

    test('handles an empty payload', () {
      expect(distanceToPolyline(Vector2(0, 0), poly([])), double.infinity);
    });

    test('does not propagate NaN from a zero-length segment mid-polyline', () {
      // The middle segment (5,5)-(5,5) is degenerate; distanceToPolyline
      // must still find the true minimum across the surrounding segments.
      final p = poly([0, 0, 5, 5, 5, 5, 10, 0]);
      expect(distanceToPolyline(Vector2(5, 5), p), closeTo(0, 1e-12));
    });
  });

  group('insideClosedPolyline', () {
    test('separates inside from outside for a square', () {
      final square = poly([0, 0, 10, 0, 10, 10, 0, 10]);
      expect(insideClosedPolyline(Vector2(5, 5), square), isTrue);
      expect(insideClosedPolyline(Vector2(15, 5), square), isFalse);
      expect(insideClosedPolyline(Vector2(-1, 5), square), isFalse);
    });

    test('handles a concave shape, where a bounding box would not', () {
      // An L: the notch at (8,8) is outside the shape but inside its box.
      final l = poly([0, 0, 10, 0, 10, 4, 4, 4, 4, 10, 0, 10]);
      expect(insideClosedPolyline(Vector2(2, 2), l), isTrue);
      expect(insideClosedPolyline(Vector2(8, 8), l), isFalse,
          reason: 'inside the bounding box but outside the shape');
    });

    test('is false for a degenerate polyline', () {
      expect(insideClosedPolyline(Vector2(0, 0), poly([0, 0, 1, 1])), isFalse);
    });

    test('resolves an on-boundary point by the even-odd convention', () {
      // A point exactly on the boundary is the case most likely to be wrong.
      // This pins the actual, deterministic behaviour of the even-odd test
      // rather than leaving it to chance: the bottom edge counts as inside,
      // the top edge does not.
      final square = poly([0, 0, 10, 0, 10, 10, 0, 10]);
      expect(insideClosedPolyline(Vector2(5, 0), square), isTrue,
          reason: 'on the bottom edge');
      expect(insideClosedPolyline(Vector2(5, 10), square), isFalse,
          reason: 'on the top edge');
    });
  });

  group('nearestVertexDistance', () {
    test('finds the closest vertex and writes it out', () {
      final p = poly([0, 0, 10, 0, 10, 10]);
      final out = Vector2.zero();
      final d = nearestVertexDistance(Vector2(9, 1), p, out);
      expect(d, closeTo(math.sqrt(2), 1e-12));
      expect(out.x, closeTo(10, 1e-12));
      expect(out.y, closeTo(0, 1e-12));
    });

    test('returns null for an empty payload and leaves out untouched', () {
      final out = Vector2(42, 42);
      expect(nearestVertexDistance(Vector2.zero(), poly([]), out), isNull);
      expect(out.x, 42);
    });
  });

  group('projectOntoSegment', () {
    test('returns null for a degenerate zero-length segment', () {
      final out = Vector2.zero();
      expect(
          projectOntoSegment(Vector2(3, 4), Vector2(5, 5), Vector2(5, 5), out),
          isNull);
    });
  });

  group('segmentIntersection', () {
    test(
        'rejects a near-parallel pair even though the parameter range '
        'check alone would accept it', () {
      // Two long, converging segments: direction (1000, 0) and direction
      // (1000, 1e-7), offset so the geometric crossing genuinely falls at
      // t = u = 0.5 -- well inside both segments, so this is not the
      // "infinite lines cross outside the segments" case the range check
      // already handles. sin(angle) between the two directions is about
      // 1e-10, below Tolerance.standard.angular (1e-9), so the near-parallel
      // guard is the only thing standing between this pair and a reported
      // hit.
      //
      // The reported point at that exact t is not itself absurd -- it lands
      // at (500, 0), an entirely unremarkable coordinate for this fixture.
      // That is the point: the danger here is not that this one answer is
      // wrong, it is that the answer is arbitrarily sensitive to a change
      // in either direction far too small to matter for anything else,
      // which is exactly what an ordinary drawing edit produces. A snap
      // target that unstable is worse than no snap at all.
      final out = Vector2.zero();
      final hit = segmentIntersection(Vector2(0, 0), Vector2(1000, 0),
          Vector2(0, -5e-8), Vector2(1000, 5e-8), out);
      expect(hit, isNull,
          reason: 'sin(angle) ~= 1e-10 is below Tolerance.standard.angular, '
              'so this pair must be rejected as near-parallel even though '
              't and u both land inside [0, 1]');
    });

    test('accepts a shallow but clearly non-parallel crossing', () {
      // A sanity check that the near-parallel guard is not simply
      // rejecting every shallow angle: sin(angle) here is about 1e-3, far
      // above the threshold, so this must be found.
      final out = Vector2.zero();
      final hit = segmentIntersection(Vector2(0, 0), Vector2(1000, 0),
          Vector2(0, -0.5), Vector2(1000, 0.5), out);
      expect(hit, isNotNull);
      expect(out.x, closeTo(500, 1e-6));
      expect(out.y, closeTo(0, 1e-9));
    });

    test('returns null for a degenerate zero-length input segment', () {
      final out = Vector2.zero();
      expect(
          segmentIntersection(Vector2(0, 0), Vector2(0, 0), Vector2(-1, -1),
              Vector2(1, 1), out),
          isNull);
    });
  });
}
