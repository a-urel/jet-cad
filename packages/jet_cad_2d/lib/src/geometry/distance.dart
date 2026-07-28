import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import '../store/geometry_store.dart';
import 'primitives.dart';

/// Narrow-phase distance, in world space.
///
/// The broad phase inverse-transforms the query into local space and accepts
/// false positives; the narrow phase transforms the *candidate* into world
/// space instead. That is exact under any affine — mirroring and non-uniform
/// scale included — and avoids ellipse math entirely, which is why nothing
/// here takes a `Transform2`.
///
/// **Zero allocation in steady state.** These functions run per candidate at
/// pointer-move rate (`pickInto`, `snapInto`). None of them allocates a
/// `Vector2`, closure, or `Iterable`: functions that take a [GeometryPayload]
/// read `payload.coords` directly rather than through [GeometryPayload.pointAt],
/// which allocates a fresh `Vector2` per call. [nearestVertexDistance] writes
/// its answer through the caller-supplied `out` for the same reason.

/// Distance from [p] to the segment [a]-[b], clamped at the endpoints.
///
/// A degenerate (zero-length) segment is treated as the single point [a]:
/// the answer is simply the distance from [p] to [a].
double distanceToSegment(Vector2 p, Vector2 a, Vector2 b) =>
    _segmentDistance(p.x, p.y, a.x, a.y, b.x, b.y);

/// Raw-double core of [distanceToSegment], so callers walking a
/// [GeometryPayload] can feed it coordinates straight out of the backing
/// `Float64List` without allocating a `Vector2` per vertex.
double _segmentDistance(
  double px,
  double py,
  double ax,
  double ay,
  double bx,
  double by,
) {
  final abx = bx - ax, aby = by - ay;
  final lengthSq = abx * abx + aby * aby;
  // Exact zero, not a tolerance: this is the degenerate-segment branch, and
  // any non-zero length gives a valid projection no matter how short.
  if (lengthSq == 0.0) {
    final dx = px - ax, dy = py - ay;
    return math.sqrt(dx * dx + dy * dy);
  }
  // Clamped to the segment, not the infinite line it lies on: a hit test
  // against a line entity must not match a point far past its end.
  var t = ((px - ax) * abx + (py - ay) * aby) / lengthSq;
  if (t < 0.0) {
    t = 0.0;
  } else if (t > 1.0) {
    t = 1.0;
  }
  final dx = px - (ax + t * abx);
  final dy = py - (ay + t * aby);
  return math.sqrt(dx * dx + dy * dy);
}

/// Distance from [p] to the *rim*. A point inside the circle is still its
/// distance from the rim, not zero: a circle entity is a curve, not a disc.
///
/// A zero radius degenerates to the distance from [p] to [centre], which
/// falls out of the same formula without a special case.
double distanceToCircle(Vector2 p, Vector2 centre, double radius) {
  final dx = p.x - centre.x, dy = p.y - centre.y;
  return (math.sqrt(dx * dx + dy * dy) - radius).abs();
}

/// Distance from [p] to an arc of [sweep] radians starting at [startAngle].
///
/// **Conventions**, matching [angleInSweep] and [arcBounds] elsewhere in this
/// package: [sweep] is signed, positive turning counter-clockwise and
/// negative clockwise, and the arc's end angle is `startAngle + sweep`
/// regardless of sign. `|sweep| >= 2*pi` degenerates to a full circle — every
/// angle is "in the sweep" — matching [distanceToCircle] exactly.
///
/// When the ray from [centre] through [p] falls outside the sweep, the
/// answer is the distance to the *nearer* of the two arc endpoints, not the
/// distance to the rim. Without that clamp an arc would behave exactly like
/// a full circle, which is the entire difference between the two. The
/// containment test is delegated to [angleInSweep], which normalises the
/// comparison across the 0/2*pi wrap; re-deriving that modulo arithmetic here
/// would risk a second, inconsistent implementation of the same subtle case.
///
/// A zero radius degenerates to the distance from [p] to [centre]: every
/// point on the "arc", on-sweep or off, sits at [centre].
double distanceToArc(
  Vector2 p,
  Vector2 centre,
  double radius,
  double startAngle,
  double sweep,
) {
  final dx = p.x - centre.x, dy = p.y - centre.y;
  final dist = math.sqrt(dx * dx + dy * dy);

  if (angleInSweep(math.atan2(dy, dx), startAngle, sweep)) {
    return (dist - radius).abs();
  }

  final endAngle = startAngle + sweep;
  final ax = centre.x + radius * math.cos(startAngle) - p.x;
  final ay = centre.y + radius * math.sin(startAngle) - p.y;
  final bx = centre.x + radius * math.cos(endAngle) - p.x;
  final by = centre.y + radius * math.sin(endAngle) - p.y;
  final da = math.sqrt(ax * ax + ay * ay);
  final db = math.sqrt(bx * bx + by * by);
  return da < db ? da : db;
}

/// Minimum distance from [p] to any segment of the polyline.
///
/// Returns [double.infinity] for an empty payload, so a caller comparing
/// against a pick radius rejects it without a special case. A single-point
/// payload has no segment, so the answer is the distance to that one point.
double distanceToPolyline(Vector2 p, GeometryPayload payload) {
  final coords = payload.coords;
  final count = payload.pointCount;
  if (count == 0) return double.infinity;
  if (count == 1) {
    final dx = p.x - coords[0], dy = p.y - coords[1];
    return math.sqrt(dx * dx + dy * dy);
  }

  var best = double.infinity;
  for (var i = 0; i + 1 < count; i++) {
    final ax = coords[i * 2], ay = coords[i * 2 + 1];
    final bx = coords[i * 2 + 2], by = coords[i * 2 + 3];
    final d = _segmentDistance(p.x, p.y, ax, ay, bx, by);
    if (d < best) best = d;
  }
  return best;
}

/// Even-odd ray cast: is [p] inside the polygon the payload's points close?
///
/// A bounding-box test is not a substitute — a concave shape has points
/// inside its box and outside itself, which is exactly the fill-hit case
/// that matters for an L-shaped room.
///
/// Fewer than 3 points cannot enclose an area, so the answer is false. A
/// point exactly on the boundary resolves deterministically by the standard
/// even-odd convention (effectively: the bottom and left edges of a shape
/// count as inside, the top and right edges do not) rather than by any
/// tolerance — this is a decision, but it is a decision about which side of
/// an exact comparison a point falls on, not about near-equality, so a
/// `Tolerance` does not apply here either.
bool insideClosedPolyline(Vector2 p, GeometryPayload payload) {
  final coords = payload.coords;
  final count = payload.pointCount;
  if (count < 3) return false;

  var inside = false;
  for (var i = 0, j = count - 1; i < count; j = i++) {
    final xi = coords[i * 2], yi = coords[i * 2 + 1];
    final xj = coords[j * 2], yj = coords[j * 2 + 1];
    if ((yi > p.y) != (yj > p.y) &&
        p.x < (xj - xi) * (p.y - yi) / (yj - yi) + xi) {
      inside = !inside;
    }
  }
  return inside;
}

/// Distance to the nearest vertex, writing that vertex into [out].
///
/// Returns null and leaves [out] untouched when there are no points, so a
/// caller can distinguish "no vertex" from "a vertex at distance zero".
double? nearestVertexDistance(
  Vector2 p,
  GeometryPayload payload,
  Vector2 out,
) {
  final coords = payload.coords;
  final count = payload.pointCount;
  if (count == 0) return null;

  var best = double.infinity;
  var bestX = 0.0, bestY = 0.0;
  for (var i = 0; i < count; i++) {
    final vx = coords[i * 2], vy = coords[i * 2 + 1];
    final dx = p.x - vx, dy = p.y - vy;
    final d = math.sqrt(dx * dx + dy * dy);
    if (d < best) {
      best = d;
      bestX = vx;
      bestY = vy;
    }
  }
  out
    ..x = bestX
    ..y = bestY;
  return best;
}
