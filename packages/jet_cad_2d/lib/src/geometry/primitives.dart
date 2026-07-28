import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import '../core/tolerance.dart';
import 'aabb2.dart';

/// The point on segment `a`–`b` nearest to `p`, clamped to the endpoints.
Vector2 closestPointOnSegment(Vector2 p, Vector2 a, Vector2 b) {
  final abx = b.x - a.x;
  final aby = b.y - a.y;
  final lengthSq = abx * abx + aby * aby;
  // Exact on purpose: this guards only against dividing by literal zero.
  // A merely tiny lengthSq is already safe — t comes out huge and the
  // clamp below pins it to an endpoint, which is the correct closest
  // point on a near-degenerate segment. A tolerance here would instead
  // misclassify short-but-real segments as points.
  if (lengthSq == 0.0) return a.clone();
  var t = ((p.x - a.x) * abx + (p.y - a.y) * aby) / lengthSq;
  t = t.clamp(0.0, 1.0);
  return Vector2(a.x + t * abx, a.y + t * aby);
}

double distancePointToSegment(Vector2 p, Vector2 a, Vector2 b) =>
    (p - closestPointOnSegment(p, a, b)).length;

/// The single crossing point of two segments, or null.
///
/// Parallel segments return null, and so does collinear overlap: an overlap has
/// no single intersection point, and a caller that needs the overlap interval
/// is asking a different question and gets a different function when one is
/// needed. Touching endpoints do intersect.
///
/// **Named `...Tol`, not `segmentIntersection`**, to avoid colliding with
/// `distance.dart`'s [segmentIntersection] of the same arity: this one
/// allocates a fresh [Vector2] per call and takes an explicit [Tolerance],
/// for general callers off the frame path; that one writes through a
/// caller-owned `out` and uses a fixed internal tolerance, for `snapInto`'s
/// zero-allocation, pointer-move-rate intersection candidate search. Both
/// are exported, unprefixed, from the same `jet_cad_2d.dart` barrel, so the
/// two cannot share a name: verified experimentally that `dart analyze`
/// does not flag two same-named top-level functions exported from sibling
/// library files as an ambiguous export -- it silently resolves an
/// unqualified call to just one of them, which is a worse failure mode than
/// a compile error and the actual reason this rename exists, not merely
/// tidiness.
Vector2? segmentIntersectionTol(
  Vector2 p1,
  Vector2 p2,
  Vector2 q1,
  Vector2 q2,
  Tolerance tol,
) {
  final r = p2 - p1;
  final s = q2 - q1;
  final denominator = r.x * s.y - r.y * s.x;
  if (tol.isZero(denominator)) return null; // parallel or collinear
  final qp = q1 - p1;
  final t = (qp.x * s.y - qp.y * s.x) / denominator;
  final u = (qp.x * r.y - qp.y * r.x) / denominator;
  if (t < 0.0 || t > 1.0 || u < 0.0 || u > 1.0) return null;
  return Vector2(p1.x + t * r.x, p1.y + t * r.y);
}

/// Whether [angle] lies within the sweep that starts at [startAngle] and turns
/// by [sweepAngle], counter-clockwise when the sweep is positive.
bool angleInSweep(double angle, double startAngle, double sweepAngle) {
  const twoPi = 2 * math.pi;
  if (sweepAngle.abs() >= twoPi) return true;
  final delta = sweepAngle >= 0 ? angle - startAngle : startAngle - angle;
  var normalized = delta % twoPi;
  if (normalized < 0) normalized += twoPi;
  return normalized <= sweepAngle.abs();
}

/// Bounds of a circular arc.
///
/// Bounding only the two endpoints is the classic arc-extents bug: an arc from
/// -45° to +45° has both endpoints at x = cos 45°, yet passes through x = r at
/// 0°. Each of the four axis extremes is therefore tested for membership in the
/// sweep and included when it falls inside.
Aabb2 arcBounds(
  Vector2 center,
  double radius,
  double startAngle,
  double sweepAngle,
) {
  final endAngle = startAngle + sweepAngle;
  var box = Aabb2.fromPoints([
    Vector2(center.x + radius * math.cos(startAngle),
        center.y + radius * math.sin(startAngle)),
    Vector2(center.x + radius * math.cos(endAngle),
        center.y + radius * math.sin(endAngle)),
  ]);

  const extremes = <Vector2Function>[
    _right,
    _top,
    _left,
    _bottom,
  ];
  for (var quadrant = 0; quadrant < 4; quadrant++) {
    final angle = quadrant * math.pi / 2;
    if (angleInSweep(angle, startAngle, sweepAngle)) {
      box = box.expandedToPoint(extremes[quadrant](center, radius));
    }
  }
  return box;
}

typedef Vector2Function = Vector2 Function(Vector2 center, double radius);

Vector2 _right(Vector2 c, double r) => Vector2(c.x + r, c.y);
Vector2 _top(Vector2 c, double r) => Vector2(c.x, c.y + r);
Vector2 _left(Vector2 c, double r) => Vector2(c.x - r, c.y);
Vector2 _bottom(Vector2 c, double r) => Vector2(c.x, c.y - r);
