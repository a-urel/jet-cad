import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'transform2.dart';

/// An axis-aligned bounding box in document units.
///
/// The empty box is represented by inverted infinite bounds rather than zeros,
/// so that expanding an empty box absorbs the first point exactly. A
/// zero-initialised box would silently include the origin, which inflates every
/// extent on a drawing that sits far from it — the common case in site plans.
///
/// Stored as four immutable doubles to prevent aliased mutation of cached boxes.
/// The spatial index holds Aabb2 instances and relies on them never changing
/// underneath it.
@immutable
class Aabb2 {
  final double minX, minY, maxX, maxY;

  Aabb2(Vector2 min, Vector2 max)
      : minX = min.x,
        minY = min.y,
        maxX = max.x,
        maxY = max.y;

  const Aabb2.raw(this.minX, this.minY, this.maxX, this.maxY);

  factory Aabb2.empty() => Aabb2.raw(
        double.infinity,
        double.infinity,
        double.negativeInfinity,
        double.negativeInfinity,
      );

  factory Aabb2.fromPoints(Iterable<Vector2> points) {
    var box = Aabb2.empty();
    for (final p in points) {
      box = box.expandedToPoint(p);
    }
    return box;
  }

  Vector2 get min => Vector2(minX, minY);
  Vector2 get max => Vector2(maxX, maxY);

  bool get isEmpty => minX > maxX || minY > maxY;

  Vector2 get center => Vector2((minX + maxX) / 2, (minY + maxY) / 2);

  Vector2 get size => Vector2(maxX - minX, maxY - minY);

  Aabb2 expandedToPoint(Vector2 p) => Aabb2.raw(
        math.min(minX, p.x),
        math.min(minY, p.y),
        math.max(maxX, p.x),
        math.max(maxY, p.y),
      );

  Aabb2 union(Aabb2 other) {
    if (other.isEmpty) return this;
    if (isEmpty) return other;
    return Aabb2.raw(
      math.min(minX, other.minX),
      math.min(minY, other.minY),
      math.max(maxX, other.maxX),
      math.max(maxY, other.maxY),
    );
  }

  Aabb2 expandedBy(double amount) => isEmpty
      ? this
      : Aabb2.raw(
          minX - amount,
          minY - amount,
          maxX + amount,
          maxY + amount,
        );

  bool containsPoint(Vector2 p) =>
      p.x >= minX && p.x <= maxX && p.y >= minY && p.y <= maxY;

  bool intersects(Aabb2 other) =>
      !isEmpty &&
      !other.isEmpty &&
      minX <= other.maxX &&
      maxX >= other.minX &&
      minY <= other.maxY &&
      maxY >= other.minY;

  /// The **conservative** axis-aligned bound of this box under [t] — the bound
  /// of the four transformed corners, not a rotated box.
  ///
  /// Conservative is the contract, not an approximation to be tightened later:
  /// the spatial index inverse-transforms a query region into a definition's
  /// local space, and a bound that were ever tighter than the true region would
  /// drop hits. Mirroring is handled by taking min and max of the corners
  /// rather than assuming the corner order is preserved.
  Aabb2 transformedBy(Transform2 t) {
    if (isEmpty) return this;
    return Aabb2.fromPoints([
      t.transformPoint(Vector2(minX, minY)),
      t.transformPoint(Vector2(maxX, minY)),
      t.transformPoint(Vector2(minX, maxY)),
      t.transformPoint(Vector2(maxX, maxY)),
    ]);
  }

  List<double> toJson() => [minX, minY, maxX, maxY];

  static Aabb2 fromJson(Object? json) {
    if (json is! List || json.length != 4) {
      throw FormatException('Aabb2 expects four numbers, got: $json');
    }
    final v = [for (final n in json) (n as num).toDouble()];
    return Aabb2.raw(v[0], v[1], v[2], v[3]);
  }

  @override
  String toString() => 'Aabb2($minX, $minY .. $maxX, $maxY)';
}
