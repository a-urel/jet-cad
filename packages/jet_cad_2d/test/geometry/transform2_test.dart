import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  const t = Tolerance.standard;

  test('identity leaves points untouched', () {
    final id = Transform2.identity();
    expect(id.isIdentity, isTrue);
    expect(t.eqPoint(id.transformPoint(Vector2(3, -7)), Vector2(3, -7)), isTrue);
  });

  test('translation moves points but not directions', () {
    final tr = Transform2.translation(10, 20);
    expect(t.eqPoint(tr.transformPoint(Vector2(1, 2)), Vector2(11, 22)), isTrue);
    // A direction has no position, so translation must not affect it.
    expect(t.eqPoint(tr.transformDirection(Vector2(1, 2)), Vector2(1, 2)), isTrue);
  });

  test('rotation by a quarter turn maps +x to +y', () {
    final rot = Transform2.rotation(math.pi / 2);
    final p = rot.transformPoint(Vector2(1, 0));
    expect(p.x, closeTo(0, 1e-12));
    expect(p.y, closeTo(1, 1e-12));
  });

  test('negative scale mirrors and flips the determinant sign', () {
    final mirror = Transform2.scale(-1, 1);
    expect(t.eqPoint(mirror.transformPoint(Vector2(2, 3)), Vector2(-2, 3)), isTrue);
    expect(mirror.determinant, lessThan(0));
  });

  test('multiply applies the argument first, then the receiver', () {
    // Composition order is the chain rule the renderer depends on:
    // parent.multiply(child) is the child's transform in the parent's space.
    final scaleThenMove =
        Transform2.translation(10, 0).multiply(Transform2.scale(2, 2));
    expect(t.eqPoint(scaleThenMove.transformPoint(Vector2(1, 0)), Vector2(12, 0)),
        isTrue);

    final moveThenScale =
        Transform2.scale(2, 2).multiply(Transform2.translation(10, 0));
    expect(t.eqPoint(moveThenScale.transformPoint(Vector2(1, 0)), Vector2(22, 0)),
        isTrue);
  });

  test('invert round-trips an arbitrary affine', () {
    final m = Transform2.translation(4.5e6, -3.2e6)
        .multiply(Transform2.rotation(0.7))
        .multiply(Transform2.scale(3, -2));
    final p = Vector2(12.5, -8.25);
    final back = m.invert().transformPoint(m.transformPoint(p));
    expect(back.x, closeTo(p.x, 1e-6));
    expect(back.y, closeTo(p.y, 1e-6));
  });

  test('invert throws on a singular transform rather than producing NaN', () {
    expect(Transform2.scale(0, 5).invert, throwsA(isA<SingularTransformError>()));
  });

  test('scaleMagnitude is the geometric mean of the axis scales', () {
    expect(Transform2.scale(4, 4).scaleMagnitude, closeTo(4, 1e-12));
    expect(Transform2.scale(1, 100).scaleMagnitude, closeTo(10, 1e-12));
    // Mirroring must not produce a negative or NaN magnitude.
    expect(Transform2.scale(-3, 3).scaleMagnitude, closeTo(3, 1e-12));
  });

  test('anisotropyRatio is 1 for rotation and uniform scale', () {
    expect(Transform2.rotation(0.9).anisotropyRatio, closeTo(1, 1e-9));
    expect(Transform2.scale(7, 7).anisotropyRatio, closeTo(1, 1e-9));
  });

  test('anisotropyRatio reports the stretch factor for non-uniform scale', () {
    // This is the number the renderer thresholds on before deciding whether a
    // single baked stroke width can be correct for the instance.
    expect(Transform2.scale(1, 10).anisotropyRatio, closeTo(10, 1e-9));
    expect(Transform2.scale(10, 1).anisotropyRatio, closeTo(10, 1e-9));
  });

  test('json round-trips as six ordered doubles', () {
    final m = Transform2(1, 2, 3, 4, 5, 6);
    expect(m.toJson(), [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]);
    expect(Transform2.fromJson(m.toJson()).equals(m, t), isTrue);
  });

  test('isIdentity is false for plainly non-identity transforms', () {
    expect(Transform2.translation(1, 0).isIdentity, isFalse);
    expect(Transform2.translation(0, 1).isIdentity, isFalse);
    expect(Transform2.scale(2, 2).isIdentity, isFalse);
    expect(Transform2.rotation(0.01).isIdentity, isFalse);
  });

  test(
      'isIdentity is false for mathematically-identity but bit-inexact composed transform',
      () {
    // Composing rotations by pi/4 four times to get 2*pi, then inverse pi rotation,
    // should be mathematically identity. But rotating by pi/4 involves irrational
    // values (sin/cos), and accumulated floating-point error prevents exact identity.
    // isIdentity must answer false to preserve the fast-path contract: answering true
    // would cause a fast path to skip this transform, silently discarding the rounding
    // error. equals() with tolerance must answer true to show they are equal
    // within tolerance.
    final composed = Transform2.rotation(math.pi / 4)
        .multiply(Transform2.rotation(math.pi / 4))
        .multiply(Transform2.rotation(math.pi / 4))
        .multiply(Transform2.rotation(math.pi / 4))
        .multiply(Transform2.rotation(-math.pi));
    expect(composed.isIdentity, isFalse);
    expect(composed.equals(Transform2.identity(), t), isTrue);
  });
}
