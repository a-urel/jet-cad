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
@immutable
class Aabb2 {
  final Vector2 min;
  final Vector2 max;

  Aabb2(Vector2 min, Vector2 max)
      : min = min.clone(),
        max = max.clone();

  factory Aabb2.empty() => Aabb2(
        Vector2(double.infinity, double.infinity),
        Vector2(double.negativeInfinity, double.negativeInfinity),
      );

  factory Aabb2.fromPoints(Iterable<Vector2> points) {
    var box = Aabb2.empty();
    for (final p in points) {
      box = box.expandedToPoint(p);
    }
    return box;
  }

  bool get isEmpty => min.x > max.x || min.y > max.y;

  Vector2 get center => Vector2((min.x + max.x) / 2, (min.y + max.y) / 2);

  Vector2 get size => Vector2(max.x - min.x, max.y - min.y);

  Aabb2 expandedToPoint(Vector2 p) => Aabb2(
        Vector2(math.min(min.x, p.x), math.min(min.y, p.y)),
        Vector2(math.max(max.x, p.x), math.max(max.y, p.y)),
      );

  Aabb2 union(Aabb2 other) {
    if (other.isEmpty) return this;
    if (isEmpty) return other;
    return Aabb2(
      Vector2(math.min(min.x, other.min.x), math.min(min.y, other.min.y)),
      Vector2(math.max(max.x, other.max.x), math.max(max.y, other.max.y)),
    );
  }

  Aabb2 expandedBy(double amount) => isEmpty
      ? this
      : Aabb2(
          Vector2(min.x - amount, min.y - amount),
          Vector2(max.x + amount, max.y + amount),
        );

  bool containsPoint(Vector2 p) =>
      p.x >= min.x && p.x <= max.x && p.y >= min.y && p.y <= max.y;

  bool intersects(Aabb2 other) =>
      !isEmpty &&
      !other.isEmpty &&
      min.x <= other.max.x &&
      max.x >= other.min.x &&
      min.y <= other.max.y &&
      max.y >= other.min.y;

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
      t.transformPoint(Vector2(min.x, min.y)),
      t.transformPoint(Vector2(max.x, min.y)),
      t.transformPoint(Vector2(min.x, max.y)),
      t.transformPoint(Vector2(max.x, max.y)),
    ]);
  }

  List<double> toJson() => [min.x, min.y, max.x, max.y];

  static Aabb2 fromJson(Object? json) {
    if (json is! List || json.length != 4) {
      throw FormatException('Aabb2 expects four numbers, got: $json');
    }
    final v = [for (final n in json) (n as num).toDouble()];
    return Aabb2(Vector2(v[0], v[1]), Vector2(v[2], v[3]));
  }

  @override
  String toString() => 'Aabb2(${min.x}, ${min.y} .. ${max.x}, ${max.y})';
}
