import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

void main() {
  final clip = Aabb2(Vector2(0, 0), Vector2(100, 100));
  final out = Float64List(2);

  test('a segment inside is unclipped', () {
    expect(clipSegment(10, 10, 90, 90, clip, out), isTrue);
    expect(out[0], 0.0);
    expect(out[1], 1.0);
  });

  test('a segment entering from the left is clipped at the edge', () {
    expect(clipSegment(-100, 50, 100, 50, clip, out), isTrue);
    expect(out[0], closeTo(0.5, 1e-12));
    expect(out[1], 1.0);
  });

  test('a segment wholly outside is rejected', () {
    expect(clipSegment(-50, -50, -10, -10, clip, out), isFalse);
  });

  test('a degenerate point inside is kept, outside is rejected', () {
    expect(clipSegment(50, 50, 50, 50, clip, out), isTrue);
    expect(clipSegment(-5, -5, -5, -5, clip, out), isFalse);
  });

  test('a segment crossing a corner keeps only the crossing part', () {
    // x + y == 0 along this whole segment, so it only ever touches the box
    // at (0, 0) - the corner itself, which is inside the closed rectangle.
    // The result is a degenerate point, not a rejection.
    expect(clipSegment(-50, 50, 50, -50, clip, out), isTrue);
    expect(out[0], closeTo(0.5, 1e-12));
    expect(out[1], closeTo(0.5, 1e-12));
  });

  group('circleClipWindows', () {
    final out = Float64List(16);

    test('a circle entirely inside reports the whole-circle sentinel', () {
      expect(circleClipWindows(50, 50, 10, clip, out), -1);
    });

    test('a circle entirely outside reports no windows', () {
      expect(circleClipWindows(500, 500, 10, clip, out), 0);
    });

    test('a circle centred on the left edge keeps its right half', () {
      // Centre at x=0, radius 40: the arc from -pi/2 to +pi/2 is inside.
      final n = circleClipWindows(0, 50, 40, clip, out);
      expect(n, 1);
      expect(out[0], closeTo(-math.pi / 2, 1e-9));
      expect(out[1], closeTo(math.pi / 2, 1e-9));
    });

    test('a circle larger than the rect reports the windows over each edge',
        () {
      // Radius 200 around the rect centre: no part of the circle is inside, so
      // nothing is drawn even though the circle encloses the whole view.
      expect(circleClipWindows(50, 50, 200, clip, out), 0);
    });

    test('a circle tangent to an edge reports no zero-width window', () {
      // Centre (50, -40), radius 40: cy + r == 0 == clip.minY exactly, so the
      // circle's topmost point (50, 0) touches the bottom edge at a single
      // point rather than crossing it. Both crossings the edge search finds
      // there coincide at angle pi/2, and that point's midpoint-of-itself is
      // inside the (closed) clip, so before the fix this reported one pair
      // [pi/2, pi/2] — violating the doc comment's `start < end`. A tangent
      // touches at a point; there is no visible arc there, so the correct
      // count is zero.
      expect(circleClipWindows(50, -40, 40, clip, out), 0);
    });
  });
}
