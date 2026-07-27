import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

void main() {
  const tol = Tolerance.standard;

  group('segment distance', () {
    final a = Vector2(0, 0);
    final b = Vector2(10, 0);

    test('projects onto the interior when the foot lies within', () {
      expect(distancePointToSegment(Vector2(3, 4), a, b), closeTo(4, 1e-12));
      expect(closestPointOnSegment(Vector2(3, 4), a, b), Vector2(3, 0));
    });

    test('clamps to the endpoints when the foot lies outside', () {
      expect(distancePointToSegment(Vector2(-3, 4), a, b), closeTo(5, 1e-12));
      expect(distancePointToSegment(Vector2(13, 4), a, b), closeTo(5, 1e-12));
    });

    test('degenerate segment behaves as a point', () {
      expect(distancePointToSegment(Vector2(3, 4), a, a), closeTo(5, 1e-12));
    });
  });

  group('segment intersection', () {
    test('finds a crossing point', () {
      final hit = segmentIntersection(
          Vector2(0, 0), Vector2(10, 10), Vector2(0, 10), Vector2(10, 0), tol);
      expect(hit, isNotNull);
      expect(tol.eqPoint(hit!, Vector2(5, 5)), isTrue);
    });

    test('returns null when the segments miss', () {
      expect(
          segmentIntersection(
              Vector2(0, 0), Vector2(1, 1), Vector2(5, 0), Vector2(6, 1), tol),
          isNull);
    });

    test('returns null for parallel and for collinear overlap', () {
      // Collinear overlap has no single intersection point; callers that need
      // the overlap interval ask a different question.
      expect(
          segmentIntersection(
              Vector2(0, 0), Vector2(10, 0), Vector2(0, 1), Vector2(10, 1), tol),
          isNull);
      expect(
          segmentIntersection(
              Vector2(0, 0), Vector2(10, 0), Vector2(5, 0), Vector2(15, 0), tol),
          isNull);
    });

    test('touching endpoints count as an intersection', () {
      final hit = segmentIntersection(
          Vector2(0, 0), Vector2(5, 0), Vector2(5, 0), Vector2(5, 5), tol);
      expect(hit, isNotNull);
      expect(tol.eqPoint(hit!, Vector2(5, 0)), isTrue);
    });
  });

  group('arcBounds', () {
    final c = Vector2(0, 0);

    test('a full circle bounds the whole circle', () {
      final box = arcBounds(c, 2, 0, 2 * math.pi);
      expect(box.min.x, closeTo(-2, 1e-12));
      expect(box.max.y, closeTo(2, 1e-12));
    });

    test('a quarter arc bounds only its own quadrant', () {
      final box = arcBounds(c, 1, 0, math.pi / 2);
      expect(box.min.x, closeTo(0, 1e-12));
      expect(box.min.y, closeTo(0, 1e-12));
      expect(box.max.x, closeTo(1, 1e-12));
      expect(box.max.y, closeTo(1, 1e-12));
    });

    test('includes an axis extreme that falls inside the sweep', () {
      // From -45 to +45 the endpoints both have x = cos(45) < 1, but the arc
      // passes through 0 degrees where x = 1. Bounding only the endpoints is
      // the classic arc-extents bug.
      final box = arcBounds(c, 1, -math.pi / 4, math.pi / 2);
      expect(box.max.x, closeTo(1, 1e-12));
      expect(box.max.y, closeTo(math.sqrt(2) / 2, 1e-12));
      expect(box.min.y, closeTo(-math.sqrt(2) / 2, 1e-12));
    });

    test('handles a negative (clockwise) sweep', () {
      final box = arcBounds(c, 1, math.pi / 4, -math.pi / 2);
      expect(box.max.x, closeTo(1, 1e-12));
      expect(box.max.y, closeTo(math.sqrt(2) / 2, 1e-12));
    });

    test('is offset by the centre', () {
      final box = arcBounds(Vector2(100, 50), 1, 0, 2 * math.pi);
      expect(box.min.x, closeTo(99, 1e-12));
      expect(box.max.y, closeTo(51, 1e-12));
    });
  });

  group('angleInSweep', () {
    test('accepts angles inside a counter-clockwise sweep', () {
      expect(angleInSweep(math.pi / 4, 0, math.pi / 2), isTrue);
      expect(angleInSweep(math.pi, 0, math.pi / 2), isFalse);
    });

    test('accepts angles inside a clockwise sweep', () {
      expect(angleInSweep(-math.pi / 4, 0, -math.pi / 2), isTrue);
      expect(angleInSweep(math.pi / 4, 0, -math.pi / 2), isFalse);
    });

    test('normalises across the 2π wrap', () {
      expect(angleInSweep(0, 7 * math.pi / 4, math.pi / 2), isTrue);
    });
  });
}
