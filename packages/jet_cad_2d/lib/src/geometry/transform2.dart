import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import '../core/tolerance.dart';

class SingularTransformError implements Exception {
  const SingularTransformError();

  @override
  String toString() => 'SingularTransformError: transform is not invertible';
}

/// A full 2×3 affine transform:
///
///     [ a  c  e ]
///     [ b  d  f ]
///
/// Affine rather than translate-rotate-scale because DXF INSERT carries
/// independent per-axis scale factors which may be negative. Mirrored blocks
/// are common, and a TRS-only transform cannot represent one.
///
/// Only containers carry a transform. Leaf entity coordinates live in their
/// owner's space, which is both DXF-correct and what keeps large documents
/// free of per-entity matrices.
@immutable
class Transform2 {
  final double a, b, c, d, e, f;

  const Transform2(this.a, this.b, this.c, this.d, this.e, this.f);

  factory Transform2.identity() => const Transform2(1, 0, 0, 1, 0, 0);

  factory Transform2.translation(double dx, double dy) =>
      Transform2(1, 0, 0, 1, dx, dy);

  factory Transform2.scale(double sx, double sy) =>
      Transform2(sx, 0, 0, sy, 0, 0);

  factory Transform2.rotation(double radians) {
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    return Transform2(cos, sin, -sin, cos, 0, 0);
  }

  /// True only for a bit-exact identity.
  ///
  /// Deliberately not tolerance-based: this is a cheap fast-path guard, not
  /// an equality decision. A near-identity answering `false` costs one
  /// redundant multiply; there is no answer it can get dangerously wrong.
  /// A tolerance-based version could report identity for a sub-tolerance
  /// transform, and a fast path would then skip it — silently discarding a
  /// real transform. For semantic comparison use `equals(other, tolerance)`.
  bool get isIdentity =>
      a == 1 && b == 0 && c == 0 && d == 1 && e == 0 && f == 0;

  /// Composition. The argument is applied **first**, then the receiver, so
  /// `parent.multiply(child)` yields the child's transform expressed in the
  /// parent's space. The renderer relies on this order when it collapses
  /// `camera ∘ ancestors ∘ instance ∘ rebase` into one matrix in Float64.
  Transform2 multiply(Transform2 other) => Transform2(
        a * other.a + c * other.b,
        b * other.a + d * other.b,
        a * other.c + c * other.d,
        b * other.c + d * other.d,
        a * other.e + c * other.f + e,
        b * other.e + d * other.f + f,
      );

  Vector2 transformPoint(Vector2 p) =>
      Vector2(a * p.x + c * p.y + e, b * p.x + d * p.y + f);

  /// Like [transformPoint] but without the translation, for vectors that
  /// represent a direction or an offset rather than a position.
  Vector2 transformDirection(Vector2 v) =>
      Vector2(a * v.x + c * v.y, b * v.x + d * v.y);

  double get determinant => a * d - b * c;

  /// Geometric mean of the axis scales, `sqrt(|det|)`.
  ///
  /// This is the representative scale the renderer uses to pre-divide baked
  /// stroke widths and dash lengths, which are paper-space quantities and must
  /// stay constant on screen regardless of the instance transform. It is
  /// always non-negative, so mirroring cannot produce a negative width.
  double get scaleMagnitude => math.sqrt(determinant.abs());

  /// Ratio of the larger singular value to the smaller — how far the transform
  /// is from conformal.
  ///
  /// Returns [double.infinity] for a degenerate transform. The renderer
  /// thresholds on this: within the threshold a single baked stroke width is
  /// close enough; beyond it the instance bypasses the definition picture cache
  /// and draws with exact per-axis handling, because no single width is right.
  double get anisotropyRatio {
    final sumSq = a * a + b * b + c * c + d * d;
    final diffSq = a * a + b * b - c * c - d * d;
    final cross = a * c + b * d;
    final q = math.sqrt(diffSq * diffSq / 4 + cross * cross);
    final half = sumSq / 2;
    final maxSq = half + q;
    // Rounding can push this a hair below zero for a conformal transform.
    final minSq = math.max(half - q, 0.0);
    if (minSq == 0.0) return double.infinity;
    return math.sqrt(maxSq / minSq);
  }

  Transform2 invert() {
    final det = determinant;
    if (det == 0.0 || !det.isFinite) throw const SingularTransformError();
    final inv = 1.0 / det;
    return Transform2(
      d * inv,
      -b * inv,
      -c * inv,
      a * inv,
      (c * f - d * e) * inv,
      (b * e - a * f) * inv,
    );
  }

  /// Component-wise comparison under a tolerance. There is deliberately no
  /// `operator ==`: exact double equality on a composed transform is almost
  /// always a bug, and nothing in the architecture uses a transform as a map
  /// key.
  bool equals(Transform2 other, Tolerance tol) =>
      tol.eq(a, other.a) &&
      tol.eq(b, other.b) &&
      tol.eq(c, other.c) &&
      tol.eq(d, other.d) &&
      tol.eq(e, other.e) &&
      tol.eq(f, other.f);

  List<double> toJson() => [a, b, c, d, e, f];

  static Transform2 fromJson(Object? json) {
    if (json is! List || json.length != 6) {
      throw FormatException('Transform2 expects six numbers, got: $json');
    }
    final v = [for (final n in json) (n as num).toDouble()];
    return Transform2(v[0], v[1], v[2], v[3], v[4], v[5]);
  }

  @override
  String toString() => 'Transform2($a, $b, $c, $d, $e, $f)';
}
