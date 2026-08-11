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
}
