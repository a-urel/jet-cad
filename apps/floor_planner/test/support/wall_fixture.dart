import 'dart:math' as math;
import 'dart:typed_data';

import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/parametric/wall_geometry.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// The measurement corpus's far origin (`generate_document.dart`): one ulp
/// is ~9.3e-10 in x here.
const double ox = 4500000, oy = 1200000;

Vector2 far(double x, double y) => Vector2(ox + x, oy + y);

/// The plan point `(x, y)`, turned [deg] degrees about the far origin: every
/// relational fixture is drawn rotated.
Vector2 plan(double x, double y, [double deg = 23]) {
  final r = deg * math.pi / 180;
  final c = math.cos(r), s = math.sin(r);
  return far(x * c - y * s, x * s + y * c);
}

/// The next double above a positive [x]: one ulp.
double nextUp(double x) {
  final b = ByteData(8)..setFloat64(0, x);
  b.setInt64(0, b.getInt64(0) + 1);
  return b.getFloat64(0);
}

/// [from] plus [len] along [deg] degrees anticlockwise from +x.
Vector2 polar(Vector2 from, double deg, double len) {
  final r = deg * math.pi / 180;
  return from + Vector2(math.cos(r), math.sin(r)) * len;
}

/// Wall [h]'s own group transform: a translation near the far origin times
/// a rotation that is never a multiple of 90°. Every wall of a joint sits in
/// its own (06's M-06o lesson).
Transform2 groupAt(int h) => Transform2.translation(
        ox - 950 + 311.5 * (h % 7), oy + 420 - 173.25 * (h % 5))
    .multiply(Transform2.rotation(0.3 + 0.7 * (h % 9)));

/// A world wall from [s] to [e], stored in group [at] (default
/// [groupAt]`(h)`) as local parameters: its world endpoints are the local
/// ones taken back through [at], so a joint drawn at one world point meets
/// within rounding, not bitwise.
WorldWall worldWall(int h, Vector2 s, Vector2 e, double t,
    [Justification j = Justification.centre, Transform2? at]) {
  final g = at ?? groupAt(h);
  final inv = g.invert();
  final ls = inv.transformPoint(s), le = inv.transformPoint(e);
  return WorldWall(Handle(h), WallParams(ls.x, ls.y, le.x, le.y, t, j), g);
}

/// A spoke of a node at [hub]: wall [h] between [hub] and the point [len]
/// along [deg], starting at [hub] when [fromHub]. Its group sits at [hub]
/// under [groupAt]`(h)`'s rotation and its hub end is local `(0, 0)`, so
/// every spoke's hub end is **bitwise** [hub] in world — the exact joint a
/// pinched node needs.
WorldWall spoke(
    int h, Vector2 hub, double deg, double len, double t, Justification j,
    {required bool fromHub}) {
  final g = Transform2.translation(hub.x, hub.y)
      .multiply(Transform2.rotation(0.3 + 0.7 * (h % 9)));
  final tip = g.invert().transformPoint(polar(hub, deg, len));
  final p = fromHub
      ? WallParams(0, 0, tip.x, tip.y, t, j)
      : WallParams(tip.x, tip.y, 0, 0, t, j);
  return WorldWall(Handle(h), p, g);
}

/// [w]'s outline among [all] ([w] itself is skipped).
({List<Vector2> ring, bool fellBack, List<Handle>? hole}) ringOf(
        WorldWall w, List<WorldWall> all,
        {bool fallback = true}) =>
    outline(
        w,
        [
          for (final o in all)
            if (o.handle != w.handle) o
        ],
        fallback: fallback);

/// The meet of line p1p2 and line q1q2 by Cramer's rule on explicit
/// coordinates — an oracle independent of `intersect`.
Vector2 oracleMeet(Vector2 p1, Vector2 p2, Vector2 q1, Vector2 q2) {
  final a1 = p2.y - p1.y, b1 = p1.x - p2.x, c1 = a1 * p1.x + b1 * p1.y;
  final a2 = q2.y - q1.y, b2 = q1.x - q2.x, c2 = a2 * q1.x + b2 * q1.y;
  final det = a1 * b2 - a2 * b1;
  return Vector2((b2 * c1 - b1 * c2) / det, (a1 * c2 - a2 * c1) / det);
}

/// [w]'s face line at [offset] along its left normal (start to end), as two
/// points, from its world coordinates.
(Vector2, Vector2) face(WorldWall w, double offset) {
  final dx = w.e.x - w.s.x, dy = w.e.y - w.s.y;
  final len = math.sqrt(dx * dx + dy * dy);
  final nx = -dy / len * offset, ny = dx / len * offset;
  return (Vector2(w.s.x + nx, w.s.y + ny), Vector2(w.e.x + nx, w.e.y + ny));
}

/// The perpendicular distance from [p] to the line through [a] and [b].
double distToLine(Vector2 p, Vector2 a, Vector2 b) {
  final dx = b.x - a.x, dy = b.y - a.y;
  return (dx * (p.y - a.y) - dy * (p.x - a.x)).abs() /
      math.sqrt(dx * dx + dy * dy);
}

/// The foot of [p] on the line through [a] and [b].
Vector2 project(Vector2 p, Vector2 a, Vector2 b) {
  final d = b - a;
  return a + d * ((p - a).dot(d) / d.dot(d));
}

/// Crossing-number point-in-polygon.
bool insideRing(Vector2 p, List<Vector2> r) {
  var c = false;
  for (var i = 0, j = r.length - 1; i < r.length; j = i++) {
    final a = r[i], b = r[j];
    if ((a.y > p.y) != (b.y > p.y) &&
        p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) {
      c = !c;
    }
  }
  return c;
}

/// [count] points uniform in the disk of radius [r] about [centre].
List<Vector2> diskSamples(Vector2 centre, double r,
    {int count = 20000, int seed = 7}) {
  final rnd = math.Random(seed);
  return [
    for (var i = 0; i < count; i++)
      () {
        final a = rnd.nextDouble() * 2 * math.pi;
        final rad = r * math.sqrt(rnd.nextDouble());
        return centre + Vector2(math.cos(a), math.sin(a)) * rad;
      }(),
  ];
}

/// How many samples in the disk of radius [r] about [centre] lie in two or
/// more of [rings] — the overlap census.
int overlapCensus(List<List<Vector2>> rings, Vector2 centre, double r) => [
      for (final p in diskSamples(centre, r))
        if (rings.where((g) => insideRing(p, g)).length >= 2) p
    ].length;

/// The points of [a] that also occur in [b], compared bitwise.
List<Vector2> sharedBitwise(List<Vector2> a, List<Vector2> b) => [
      for (final p in a)
        if (b.any((q) => q.x == p.x && q.y == p.y)) p
    ];

/// Whether [ring] closes into a polyline that the engine triangulates.
bool triangulates(List<Vector2> ring) {
  final tri = triangulationFor(
      EntityKind.polyline, polylinePayload(ring, closed: true));
  return tri != null && tri.isNotEmpty;
}

/// The smallest distance from [p] to any point of [ring].
double nearestIn(List<Vector2> ring, Vector2 p) =>
    ring.map((q) => (q - p).length).reduce(math.min);
