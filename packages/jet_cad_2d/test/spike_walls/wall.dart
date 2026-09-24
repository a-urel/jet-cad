// SPIKE 07 — throwaway. The wall parametric type, as brainstormed on
// 2026-09-24: one straight segment per object, solid poché (a closed outline
// plus a fill naming it) and a generated centreline; joints derived in
// generate from the neighbours' parameters, never cached.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

enum Justification { left, centre, right }

/// Join decisions: 1 nm in a mm document, ~1000 ulps at the far origin.
const Tolerance wallJoin = Tolerance(linear: 1e-6, angular: 1e-9);

/// A corner farther than this many half-thicknesses of the thicker wall from
/// the node is clamped (SVG's default mitre limit).
const double mitreLimit = 4;

final class WallParams implements Component {
  const WallParams(this.sx, this.sy, this.ex, this.ey, this.thickness,
      [this.justification = Justification.centre]);

  static const String componentTypeId = 'spike.wall';

  final double sx, sy, ex, ey, thickness;
  final Justification justification;

  Vector2 get start => Vector2(sx, sy);
  Vector2 get end => Vector2(ex, ey);

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {
        'start': [sx, sy],
        'end': [ex, ey],
        'thickness': thickness,
        'justification': justification.name,
      };

  static WallParams fromJson(Map<String, Object?> j) {
    final s = (j['start']! as List).cast<num>();
    final e = (j['end']! as List).cast<num>();
    return WallParams(
        s[0].toDouble(),
        s[1].toDouble(),
        e[0].toDouble(),
        e[1].toDouble(),
        (j['thickness']! as num).toDouble(),
        Justification.values.byName(j['justification']! as String));
  }

  @override
  bool operator ==(Object o) =>
      o is WallParams &&
      o.sx == sx &&
      o.sy == sy &&
      o.ex == ex &&
      o.ey == ey &&
      o.thickness == thickness &&
      o.justification == justification;

  @override
  int get hashCode => Object.hash(sx, sy, ex, ey, thickness, justification);
}

/// A wall in world space: what every joint computation reads. Built by one
/// function from (params, toWorld), so two walls computing the same neighbour
/// get the same bits.
final class WorldWall {
  WorldWall(this.handle, WallParams p, Transform2 toWorld)
      : s = toWorld.transformPoint(p.start),
        e = toWorld.transformPoint(p.end),
        t = p.thickness,
        j = p.justification;

  final Handle handle;
  final Vector2 s, e;
  final double t;
  final Justification j;

  Vector2 get d => (e - s).normalized();

  /// Left and right face offsets along the left normal; l > r, r <= 0 <= l.
  (double, double) get offsets => switch (j) {
        Justification.centre => (t / 2, -t / 2),
        Justification.left => (t, 0),
        Justification.right => (0, -t),
      };

  Vector2 endpoint(int k) => k == 0 ? s : e;
}

/// One wall end seen from the joint, looking outward along the wall.
final class End {
  End(this.wall, this.k) {
    final d = wall.d;
    a = k == 0 ? d : -d;
    final (l, r) = wall.offsets;
    // Outward-looking left normal is perp(a); at the end it is -n.
    left = k == 0 ? l : -r;
    right = k == 0 ? r : -l;
  }

  final WorldWall wall;
  final int k;
  late final Vector2 a;
  late final double left, right;

  Vector2 get p => wall.endpoint(k);
  Vector2 get nOut => Vector2(-a.y, a.x);
  Vector2 leftPoint(Vector2 at) => at + nOut * left;
  Vector2 rightPoint(Vector2 at) => at + nOut * right;
  double get angle => math.atan2(a.y, a.x);
}

/// The intersection of p + u·a and q + v·b, or null when parallel.
Vector2? intersect(Vector2 p, Vector2 a, Vector2 q, Vector2 b) {
  final cross = a.x * b.y - a.y * b.x;
  if (cross.abs() <= wallJoin.angular) return null;
  final w = q - p;
  final u = (w.x * b.y - w.y * b.x) / cross;
  return p + a * u;
}

/// How one end is capped.
sealed class Joint {}

final class Free extends Joint {}

final class Tee extends Joint {
  Tee(this.through);
  final WorldWall through;
}

final class NodeJoint extends Joint {
  /// Every end at the node, sorted anticlockwise by outgoing angle, ties by
  /// handle then end index.
  NodeJoint(this.ends);
  final List<End> ends;
}

double _distToSegment(Vector2 p, Vector2 s, Vector2 e) {
  final d = e - s;
  final len2 = d.length2;
  if (len2 == 0) return (p - s).length;
  final u = ((p - s).dot(d) / len2).clamp(0.0, 1.0);
  return (p - (s + d * u)).length;
}

/// The joint at [self]'s end [k] among [others] (every neighbouring wall).
Joint classify(WorldWall self, int k, List<WorldWall> others) {
  final p = self.endpoint(k);
  // T first: the end lies strictly inside another centreline.
  for (final o in others) {
    final len = (o.e - o.s).length;
    final u = (p - o.s).dot(o.d);
    if (u > wallJoin.linear &&
        u < len - wallJoin.linear &&
        _distToSegment(p, o.s, o.e) <= wallJoin.linear) {
      return Tee(o);
    }
  }
  final ends = <End>[End(self, k)];
  for (final o in others) {
    for (final m in const [0, 1]) {
      if (wallJoin.eqPoint(o.endpoint(m), p) ||
          (o.endpoint(m) - p).length <= wallJoin.linear) {
        ends.add(End(o, m));
      }
    }
  }
  if (ends.length < 2) return Free();
  ends.sort((x, y) {
    final c = x.angle.compareTo(y.angle);
    if (c != 0) return c;
    final h = x.wall.handle.value.compareTo(y.wall.handle.value);
    return h != 0 ? h : x.k.compareTo(y.k);
  });
  return NodeJoint(ends);
}

/// Points from the outgoing-left face to the outgoing-right face.
List<Vector2> cap(End me, Joint joint) {
  switch (joint) {
    case Free():
      return [me.leftPoint(me.p), me.rightPoint(me.p)];
    case Tee(:final through):
      final (l, r) = through.offsets;
      final n = Vector2(-through.d.y, through.d.x);
      // The near face is the one on the side my body goes to.
      final off = me.a.dot(n) > 0 ? l : r;
      final q = through.s + n * off;
      final cl = intersect(me.leftPoint(me.p), me.a, q, through.d);
      final cr = intersect(me.rightPoint(me.p), me.a, q, through.d);
      final limit = mitreLimit / 2 * math.max(me.wall.t, through.t);
      if (cl == null ||
          cr == null ||
          (cl - me.p).length > limit ||
          (cr - me.p).length > limit) {
        return [me.leftPoint(me.p), me.rightPoint(me.p)];
      }
      return [cl, cr];
    case NodeJoint(:final ends):
      final i = ends.indexWhere(
          (x) => x.wall.handle == me.wall.handle && x.k == me.k);
      final hub = nodeHub(ends);
      final wedges = [for (var w = 0; w < ends.length; w++) wedge(ends, w, hub)];
      final n = ends.length;
      final left = wedges[i].first; // on my outgoing-left face
      final right = wedges[(i - 1 + n) % n].last; // on my outgoing-right face
      if (ends.length == 2 && wedges.every((w) => w.length == 1)) {
        return [left, right]; // the mitre segment
      }
      // The central polygon, anticlockwise; edge k runs from vertex k to
      // k+1 and carries the end whose cap it is (or -1 for a clamp edge).
      final verts = <Vector2>[], edgeEnd = <int>[];
      for (var w = 0; w < n; w++) {
        final pts = wedges[w];
        for (var q = 0; q < pts.length; q++) {
          verts.add(pts[q]);
          edgeEnd.add(q < pts.length - 1 ? -1 : (w + 1) % n);
        }
      }
      for (final lobe in lobes(verts, edgeEnd)) {
        final members = [for (final e in lobe.$2) if (e >= 0) e];
        if (!members.contains(i)) continue;
        // A folded (non-positive) or crossing lobe is not a hole to fill:
        // the caps already meet, or it is left open (measured).
        if (lobe.$1.length < 3 || !isSimpleCcw(lobe.$1)) {
          if (lobe.$1.length >= 3 && signedArea(lobe.$1) > 0) holeLobes++;
          break;
        }
        members.sort((x, y) {
          final h = ends[x].wall.handle.value.compareTo(ends[y].wall.handle.value);
          return h != 0 ? h : ends[x].k.compareTo(ends[y].k);
        });
        if (members.first != i) break;
        // Rotate the lobe to start at my left point: my cap edge runs from
        // my right point to my left point, so start just after it.
        final k = lobe.$2.indexOf(i);
        final m = lobe.$1.length;
        return [for (var q = 1; q <= m; q++) lobe.$1[(k + q) % m]];
      }
      return [left, right];
  }
}

/// Splits a closed ring at exactly repeated vertices into lobes, each with
/// its edge labels.
List<(List<Vector2>, List<int>)> lobes(List<Vector2> v, List<int> e) {
  for (var a = 0; a < v.length; a++) {
    for (var b = a + 1; b < v.length; b++) {
      if (v[a].x == v[b].x && v[a].y == v[b].y) {
        final inner = (v.sublist(a, b), e.sublist(a, b));
        final outer = (
          [...v.sublist(b), ...v.sublist(0, a)],
          [...e.sublist(b), ...e.sublist(0, a)],
        );
        return [...lobes(inner.$1, inner.$2), ...lobes(outer.$1, outer.$2)];
      }
    }
  }
  return [(v, e)];
}

/// The lowest handle's endpoint: every member computes the same point.
Vector2 nodeHub(List<End> ends) => ends[nodeOwner(ends)].p;

/// The member that owns the central polygon: the lowest handle, then end.
int nodeOwner(List<End> ends) {
  var o = 0;
  for (var i = 1; i < ends.length; i++) {
    final h = ends[i].wall.handle.value.compareTo(ends[o].wall.handle.value);
    if (h < 0 || (h == 0 && ends[i].k < ends[o].k)) o = i;
  }
  return o;
}

/// Wedge w, anticlockwise from end w to end w+1: its point(s) on the
/// central polygon, in anticlockwise order. One shared corner, or — clamped
/// — end w's left foot then end w+1's right foot.
List<Vector2> wedge(List<End> ends, int w, Vector2 hub) {
  final x = ends[w], y = ends[(w + 1) % ends.length];
  final s = sweep(x, y);
  final c = intersect(x.leftPoint(x.p), x.a, y.rightPoint(y.p), y.a);
  final limit = mitreLimit / 2 * math.max(x.wall.t, y.wall.t);
  // An acute wedge is never clamped: its long inner mitre is real geometry.
  if (c != null && (s < math.pi / 2 || (c - hub).length <= limit)) return [c];
  return [x.leftPoint(hub), y.rightPoint(hub)];
}

/// The central polygon, anticlockwise, starting at end i's left point and
/// ending at its right point.
List<Vector2> centralPolygon(List<List<Vector2>> wedges, int i) => [
      for (var k = 0; k < wedges.length; k++)
        ...wedges[(i + k) % wedges.length],
    ];

/// The anticlockwise sweep from x to y, in (0, 2π].
double sweep(End x, End y) {
  var s = y.angle - x.angle;
  if (s <= 0) s += 2 * math.pi;
  return s;
}

/// The world outline, anticlockwise: end cap then start cap.
List<Vector2> outline(WorldWall w, List<WorldWall> others,
    {bool fallback = true}) {
  final ce = cap(End(w, 1), classify(w, 1, others));
  final cs = cap(End(w, 0), classify(w, 0, others));
  final ring = simplifyRing([...ce, ...cs]);
  if (fallback && !isSimpleCcw(ring)) {
    return [
      ...cap(End(w, 1), Free()),
      ...cap(End(w, 0), Free()),
    ];
  }
  return ring;
}

/// SPIKE counter: positive-area lobes dropped because they cross.
int holeLobes = 0;

double signedArea(List<Vector2> r) {
  var a = 0.0;
  for (var i = 0; i < r.length; i++) {
    final p = r[i], q = r[(i + 1) % r.length];
    a += p.x * q.y - q.x * p.y;
  }
  return a / 2;
}

bool _same(Vector2 a, Vector2 b) => a.x == b.x && a.y == b.y;

/// Removes exact consecutive duplicates and zero-width spikes (a, b, a):
/// stored-value comparisons, so exact. Zero area, so tiling is unchanged.
List<Vector2> simplifyRing(List<Vector2> ring) {
  final r = [...ring];
  var changed = true;
  while (changed && r.length > 3) {
    changed = false;
    for (var i = 0; i < r.length && r.length > 3; i++) {
      final prev = r[(i - 1 + r.length) % r.length];
      final next = r[(i + 1) % r.length];
      if (_same(r[i], next)) {
        r.removeAt(i);
        changed = true;
        break;
      }
      if (_same(prev, next)) {
        // a, b, a -> a: drop b and the repeated a.
        final j = (i + 1) % r.length;
        if (j > i) {
          r.removeAt(j);
          r.removeAt(i);
        } else {
          r.removeAt(i);
          r.removeAt(j);
        }
        changed = true;
        break;
      }
    }
  }
  return r;
}

/// Exact, like the triangulator: no two non-adjacent edges properly cross,
/// and the signed area is positive.
bool isSimpleCcw(List<Vector2> ring) {
  final c = Float64List(ring.length * 2);
  for (var i = 0; i < ring.length; i++) {
    c[i * 2] = ring[i].x;
    c[i * 2 + 1] = ring[i].y;
  }
  final n = ring.length;
  var area = 0.0;
  for (var i = 0; i < n; i++) {
    final p = ring[i], q = ring[(i + 1) % n];
    area += p.x * q.y - q.x * p.y;
  }
  if (!(area > 0)) return false;
  double cross(Vector2 a, Vector2 b, Vector2 d) =>
      (b.x - a.x) * (d.y - a.y) - (b.y - a.y) * (d.x - a.x);
  bool crosses(Vector2 a, Vector2 b, Vector2 d, Vector2 e) {
    final d1 = cross(d, e, a), d2 = cross(d, e, b);
    final d3 = cross(a, b, d), d4 = cross(a, b, e);
    return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0));
  }

  for (var i = 0; i < n; i++) {
    for (var j = i + 2; j < n; j++) {
      if (i == 0 && j == n - 1) continue;
      if (crosses(ring[i], ring[(i + 1) % n], ring[j], ring[(j + 1) % n])) {
        return false;
      }
    }
  }
  return true;
}

final class WallType extends ParametricType<WallParams> {
  const WallType();

  @override
  Capability get editCapability => Capability.geometry;

  @override
  Aabb2 reach(WallParams p, Transform2 toWorld) => Aabb2.fromPoints([
        toWorld.transformPoint(p.start),
        toWorld.transformPoint(p.end),
      ]).expandedBy(wallJoin.linear);

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    final me = WorldWall(self, view.paramsOf<WallParams>(self)!,
        view.toWorld(self));
    final others = [
      for (final n in view.neighbours(self))
        if (view.paramsOf<WallParams>(n) case final q?)
          WorldWall(n, q, view.toWorld(n)),
    ];
    final toLocal = view.toWorld(self).invert();
    final ring = [
      for (final p in outline(me, others)) toLocal.transformPoint(p),
    ];
    final p = view.paramsOf<WallParams>(self)!;
    return [
      Generated.region(polylinePayload(ring, closed: true)),
      Generated(EntityKind.polyline, polylinePayload([p.start, p.end])),
    ];
  }
}

final ParametricCatalog wallCatalog = ParametricCatalog()
  ..register<WallParams>(
      WallParams.componentTypeId, WallParams.fromJson, const WallType());
