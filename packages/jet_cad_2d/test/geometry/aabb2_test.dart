import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart' hide Aabb2;
import 'package:jet_cad_2d/src/geometry/aabb2.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

void main() {
  test('empty absorbs the first point instead of stretching from the origin', () {
    // A zero-initialised box would silently include (0,0) and inflate every
    // extent computation on a drawing that sits far from the origin.
    final box = Aabb2.empty().expandedToPoint(Vector2(4.5e6, -3.2e6));
    expect(box.isEmpty, isFalse);
    expect(box.min.x, 4.5e6);
    expect(box.max.x, 4.5e6);
    expect(Aabb2.empty().isEmpty, isTrue);
  });

  test('fromPoints bounds every point', () {
    final box = Aabb2.fromPoints([Vector2(1, 5), Vector2(-3, 2), Vector2(0, 9)]);
    expect(box.min, Vector2(-3, 2));
    expect(box.max, Vector2(1, 9));
    expect(box.center, Vector2(-1, 5.5));
    expect(box.size, Vector2(4, 7));
  });

  test('union with an empty box is the identity', () {
    final box = Aabb2(Vector2(0, 0), Vector2(2, 2));
    expect(box.union(Aabb2.empty()).max, Vector2(2, 2));
    expect(Aabb2.empty().union(box).max, Vector2(2, 2));
  });

  test('containsPoint and intersects use closed bounds', () {
    final box = Aabb2(Vector2(0, 0), Vector2(2, 2));
    expect(box.containsPoint(Vector2(2, 2)), isTrue);
    expect(box.containsPoint(Vector2(2.001, 1)), isFalse);
    expect(box.intersects(Aabb2(Vector2(2, 2), Vector2(3, 3))), isTrue);
    expect(box.intersects(Aabb2(Vector2(2.5, 0), Vector2(3, 3))), isFalse);
  });

  test('expandedBy grows in both directions', () {
    final box = Aabb2(Vector2(0, 0), Vector2(2, 2)).expandedBy(1);
    expect(box.min, Vector2(-1, -1));
    expect(box.max, Vector2(3, 3));
  });

  test('transformedBy returns a conservative bound under rotation', () {
    // A 45-degree rotation of the unit square must produce a box that contains
    // the rotated square, which is larger than the original — never smaller.
    final rotated = Aabb2(Vector2(0, 0), Vector2(1, 1))
        .transformedBy(Transform2.rotation(math.pi / 4));
    final halfDiagonal = math.sqrt(2);
    expect(rotated.max.y, closeTo(halfDiagonal, 1e-12));
    expect(rotated.min.x, closeTo(-math.sqrt(2) / 2, 1e-12));
  });

  test('transformedBy handles mirroring without inverting min and max', () {
    final mirrored = Aabb2(Vector2(1, 1), Vector2(3, 2))
        .transformedBy(Transform2.scale(-1, 1));
    expect(mirrored.min.x, closeTo(-3, 1e-12));
    expect(mirrored.max.x, closeTo(-1, 1e-12));
  });

  test('json round-trips, and empty survives the round trip', () {
    final box = Aabb2(Vector2(1, 2), Vector2(3, 4));
    expect(box.toJson(), [1.0, 2.0, 3.0, 4.0]);
    expect(Aabb2.fromJson(box.toJson()).max, Vector2(3, 4));
    expect(Aabb2.fromJson(Aabb2.empty().toJson()).isEmpty, isTrue);
  });

  test('box is immutable even though Vector2 getters are mutable', () {
    // Aabb2 stores doubles internally, so mutating the Vector2 from a getter
    // does not affect the cached box — critical for spatial index integrity.
    final box = Aabb2(Vector2(1, 2), Vector2(3, 4));
    final minVector = box.min;
    minVector.x = 999;
    minVector.y = 888;
    expect(box.min.x, 1);
    expect(box.min.y, 2);
  });
}
