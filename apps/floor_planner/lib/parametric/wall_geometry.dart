// Pure wall joint geometry (spec 07 D4-D7). No Flutter import: this file is
// Dart over `package:jet_cad_2d` and `vector_math` only (Ruling 07-2).
//
// Ported from the spike's node rule (`spike/07-walls` at 45aecb6,
// `test/spike_walls/wall.dart`) with Ruling 07-3's anchor rule, Ruling 07-4's
// coincident directions, per-call hole reporting instead of a global counter,
// and degenerate walls left out of every joint.
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'wall.dart';

/// A wall in world space: what every joint computation reads (spec 07 D4).
///
/// Built by this one constructor from `(params, toWorld)`, so two walls that
/// compute the same neighbour get the same bits.
final class WorldWall {
  WorldWall(this.handle, WallParams p, this.toWorld)
      : params = p,
        s = toWorld.transformPoint(p.start),
        e = toWorld.transformPoint(p.end),
        t = p.thickness,
        j = p.justification;

  final Handle handle;

  /// The stored parameters and the group's accumulated transform this wall
  /// was built from: what the host frame (spec 08 D7), computed in the
  /// wall's group-local space, reads.
  final WallParams params;
  final Transform2 toWorld;

  /// The world start and end of the centreline.
  final Vector2 s, e;

  /// The thickness.
  final double t;

  final Justification j;

  /// Spec 07 D2: a centreline no longer than `wallJoin.linear`, or a
  /// thickness that is not positive. Such a wall has no outline and is never
  /// classified against (a NaN counts as degenerate).
  bool get degenerate => !((e - s).length > wallJoin.linear) || !(t > 0);

  /// The unit direction from start to end. Undefined for a degenerate wall.
  late final Vector2 d = (e - s).normalized();

  /// The left and right face offsets along the left normal `(-d.y, d.x)`
  /// (spec 07 D2): `(t/2, -t/2)`, `(t, 0)` or `(0, -t)`.
  (double, double) get offsets => switch (j) {
        Justification.centre => (t / 2, -t / 2),
        Justification.left => (t, 0),
        Justification.right => (0, -t),
      };

  /// The start for `k == 0`, the end otherwise.
  Vector2 endpoint(int k) => k == 0 ? s : e;
}

/// One wall end seen from its joint, looking outward along the wall: [a]
/// points away from the end's point into the wall's body.
final class End {
  factory End(WorldWall wall, int k) {
    final d = wall.d;
    final a = k == 0 ? d : -d;
    final (l, r) = wall.offsets;
    // The outward-looking left normal is perp(a); at the end (k == 1) it is
    // the wall's right normal, so the faces swap sides and signs.
    return End._(wall, k, a, k == 0 ? l : -r, k == 0 ? r : -l);
  }

  End._(this.wall, this.k, this.a, this.left, this.right);

  final WorldWall wall;

  /// 0 for the wall's start, 1 for its end.
  final int k;

  /// The outgoing unit direction.
  final Vector2 a;

  /// The outgoing-left and outgoing-right face offsets along [nOut].
  final double left, right;

  /// The end's point.
  Vector2 get p => wall.endpoint(k);

  /// The outgoing left normal.
  Vector2 get nOut => Vector2(-a.y, a.x);

  Vector2 leftPoint(Vector2 at) => at + nOut * left;
  Vector2 rightPoint(Vector2 at) => at + nOut * right;

  /// The outgoing angle, in (-π, π].
  late final double angle = math.atan2(a.y, a.x);
}

/// Ascending by handle value, then end index (spec 07 D5.1's tie-break and
/// D5.5's owner order).
int _byHandleThenEnd(End x, End y) {
  final h = x.wall.handle.value.compareTo(y.wall.handle.value);
  return h != 0 ? h : x.k.compareTo(y.k);
}

/// Spec 07 D7: two endpoints join when they lie within `wallJoin.linear`.
bool _joined(Vector2 a, Vector2 b) => (a - b).length <= wallJoin.linear;

/// The intersection of `p + u·a` and `q + v·b`, or null when the directions
/// are parallel within `wallJoin.angular`.
Vector2? intersect(Vector2 p, Vector2 a, Vector2 q, Vector2 b) {
  final cross = a.x * b.y - a.y * b.x;
  if (cross.abs() <= wallJoin.angular) return null;
  final w = q - p;
  final u = (w.x * b.y - w.y * b.x) / cross;
  return p + a * u;
}

/// How one wall end is capped (spec 07 D4).
sealed class Joint {
  const Joint();
}

/// No joint: the end is square at its own endpoint.
final class Free extends Joint {
  const Free();
}

/// The end butts [through]'s near face (spec 07 D4.1).
final class Tee extends Joint {
  const Tee(this.through);
  final WorldWall through;
}

/// The end meets other ends at a node (spec 07 D4.2, D5).
final class NodeJoint extends Joint {
  NodeJoint(this.ends, this.members);

  /// The ends the node is built from, sorted anticlockwise by outgoing
  /// angle, ties by handle then end index (D5.1). Ends that share a direction
  /// with another member are not among them (Ruling 07-4).
  final List<End> ends;

  /// Every member wall of the node (Ruling 07-3), ascending, once each —
  /// including walls left out of [ends] by Ruling 07-4. D12's `wall.hole`
  /// names these.
  final List<Handle> members;
}

/// Whether [p] lies on [o]'s centreline within `wallJoin.linear` and more
/// than `wallJoin.linear` from both of its ends, measured along it (D4.1).
/// Spec 08 D7's T obstacle reads it with the host as [o].
bool strictlyInside(Vector2 p, WorldWall o) {
  final len = (o.e - o.s).length;
  final u = (p - o.s).dot(o.d);
  if (!(u > wallJoin.linear && u < len - wallJoin.linear)) return false;
  final foot = o.s + o.d * u;
  return (p - foot).length <= wallJoin.linear;
}

bool _lower(WorldWall w, int k, WorldWall than, int thanK) {
  final h = w.handle.value.compareTo(than.handle.value);
  return h < 0 || (h == 0 && k < thanK);
}

/// Ruling 07-4: two ends whose outgoing directions agree within
/// `wallJoin.angular` (a sweep of 0 or 2π) are two overlapping walls.
bool _sameDirection(End x, End y) {
  var d = (x.angle - y.angle).abs();
  if (d > math.pi) d = 2 * math.pi - d;
  return d <= wallJoin.angular;
}

/// The joint at [self]'s end [k] among [others], in this order (spec 07 D4):
///
/// 1. **T** — the end lies within `wallJoin.linear` of another centreline,
///    strictly inside it (more than `wallJoin.linear` from both of its
///    ends). Several: the lowest handle.
/// 2. **Node** (Ruling 07-3) — the candidates are this end and every other
///    wall's end within `wallJoin.linear` of it; the **anchor** is the lowest
///    `(handle, end index)` among them; the members are every end, this
///    wall's included, within `wallJoin.linear` of the anchor's endpoint.
///    Every member computes the same set whenever the lowest end is within
///    `wallJoin.linear` of all the others; a wider cluster, which snapping
///    never produces, can compute differing sets (ends at 0, 0.9 and
///    1.8 × `wallJoin.linear` in handle order: the first two see two
///    members, the third sees three). Ends sharing a direction with
///    another member keep free caps and the node is built from the rest
///    (Ruling 07-4); fewer than two left is no node.
/// 3. **Free** otherwise.
///
/// [self] must not be degenerate. Degenerate walls in [others], and [self]
/// itself if listed, are ignored.
Joint classify(WorldWall self, int k, List<WorldWall> others) {
  final p = self.endpoint(k);
  final walls = [
    for (final o in others)
      if (o.handle != self.handle && !o.degenerate) o,
  ];
  WorldWall? through;
  for (final o in walls) {
    if (!strictlyInside(p, o)) continue;
    if (through == null || o.handle.value < through.handle.value) through = o;
  }
  if (through != null) return Tee(through);

  var anchor = self;
  var anchorK = k;
  for (final o in walls) {
    for (final m in const [0, 1]) {
      if (_joined(o.endpoint(m), p) && _lower(o, m, anchor, anchorK)) {
        anchor = o;
        anchorK = m;
      }
    }
  }
  final at = anchor.endpoint(anchorK);
  final members = <End>[
    for (final w in [self, ...walls])
      for (final m in const [0, 1])
        if (_joined(w.endpoint(m), at)) End(w, m),
  ];
  final ends = [
    for (final x in members)
      if (!members.any((y) => !identical(x, y) && _sameDirection(x, y))) x,
  ];
  if (ends.length < 2 ||
      !ends.any((x) => x.wall.handle == self.handle && x.k == k)) {
    return const Free();
  }
  ends.sort((x, y) {
    final c = x.angle.compareTo(y.angle);
    return c != 0 ? c : _byHandleThenEnd(x, y);
  });
  final handles = {for (final x in members) x.wall.handle.value}.toList()
    ..sort();
  return NodeJoint(ends, [for (final h in handles) Handle(h)]);
}

/// One end's cap, from its outgoing-left face to its outgoing-right face,
/// and whether this end owns a crossing lobe that was dropped (spec 07 D5.6).
typedef Cap = ({List<Vector2> points, bool ownsHole});

/// The cap of [me] under [joint].
///
/// - **Free:** square at the end's own point.
/// - **Tee** (D4.1, D6): the two faces meet the through wall's **near** face
///   (the one on the side the stem's body goes to); a corner farther than
///   `mitreLimit / 2 ×` the thicker wall from the end's point squares the
///   end at its own point instead, inside the through wall's body.
/// - **Node** (D5): the straight segment from this end's left corner (the
///   wedge after it) to its right corner (the wedge before it). The node
///   point is never inserted as a cap vertex (D5.3). At two ends that is the
///   mitre (D5.4). At three or more, or when a wedge is clamped, the corners
///   enclose a central polygon, split at exactly repeated vertices into
///   lobes; the lowest `(handle, end)` whose cap is an edge of a lobe owns it
///   and its cap walks the lobe from its left corner to its right corner
///   (D5.5). A folded (signed area ≤ 0) or self-crossing lobe is dropped and
///   every cap stays straight; a crossing lobe of positive area leaves a hole,
///   which its owner reports (D5.6).
Cap cap(End me, Joint joint) {
  switch (joint) {
    case Free():
      return (
        points: [me.leftPoint(me.p), me.rightPoint(me.p)],
        ownsHole: false
      );
    case Tee(:final through):
      final (l, r) = through.offsets;
      final n = Vector2(-through.d.y, through.d.x);
      final off = me.a.dot(n) > 0 ? l : r;
      final q = through.s + n * off;
      final cl = intersect(me.leftPoint(me.p), me.a, q, through.d);
      final cr = intersect(me.rightPoint(me.p), me.a, q, through.d);
      final limit = mitreLimit / 2 * math.max(me.wall.t, through.t);
      if (cl == null ||
          cr == null ||
          (cl - me.p).length > limit ||
          (cr - me.p).length > limit) {
        return (
          points: [me.leftPoint(me.p), me.rightPoint(me.p)],
          ownsHole: false
        );
      }
      return (points: [cl, cr], ownsHole: false);
    case NodeJoint(:final ends):
      final i = ends
          .indexWhere((x) => x.wall.handle == me.wall.handle && x.k == me.k);
      final hub = nodeHub(ends);
      final n = ends.length;
      final wedges = [for (var w = 0; w < n; w++) wedge(ends, w, hub)];
      final left = wedges[i].first; // on my outgoing-left face
      final right = wedges[(i - 1 + n) % n].last; // on my outgoing-right face
      if (n == 2 && wedges.every((w) => w.length == 1)) {
        return (points: [left, right], ownsHole: false); // the mitre
      }
      // The central polygon, anticlockwise: edge q runs from vertex q to
      // q + 1 and carries the index of the end whose cap it is, or -1 for a
      // clamp edge between two feet.
      final verts = <Vector2>[], edgeEnd = <int>[];
      for (var w = 0; w < n; w++) {
        final pts = wedges[w];
        for (var q = 0; q < pts.length; q++) {
          verts.add(pts[q]);
          edgeEnd.add(q < pts.length - 1 ? -1 : (w + 1) % n);
        }
      }
      for (final (ring, labels) in lobes(verts, edgeEnd)) {
        final capsOn = [
          for (final e in labels)
            if (e >= 0) e
        ];
        if (!capsOn.contains(i)) continue;
        capsOn.sort((x, y) => _byHandleThenEnd(ends[x], ends[y]));
        final owner = capsOn.first == i;
        if (ring.length < 3 || !isSimpleCcw(ring)) {
          return (
            points: [left, right],
            ownsHole: owner && ring.length >= 3 && signedArea(ring) > 0
          );
        }
        if (!owner) break;
        // My cap edge runs from my right corner (vertex q) to my left corner
        // (vertex q + 1): start just after it.
        final q = labels.indexOf(i);
        final m = ring.length;
        return (
          points: [for (var s = 1; s <= m; s++) ring[(q + s) % m]],
          ownsHole: false
        );
      }
      return (points: [left, right], ownsHole: false);
  }
}

/// Splits a closed ring at exactly repeated vertices into lobes, each with
/// its edge labels (spec 07 D5.5). Exact: a stored-value comparison.
List<(List<Vector2>, List<int>)> lobes(List<Vector2> v, List<int> e) {
  for (var a = 0; a < v.length; a++) {
    for (var b = a + 1; b < v.length; b++) {
      if (_same(v[a], v[b])) {
        return [
          ...lobes(v.sublist(a, b), e.sublist(a, b)),
          ...lobes([...v.sublist(b), ...v.sublist(0, a)],
              [...e.sublist(b), ...e.sublist(0, a)]),
        ];
      }
    }
  }
  return [(v, e)];
}

/// The node's reference point: the endpoint of its lowest `(handle, end)`,
/// the same bits for every member. Used only as the clamp reference and the
/// feet's base, never inserted as a cap vertex (spec 07 D5.3).
Vector2 nodeHub(List<End> ends) => ends[nodeOwner(ends)].p;

/// The index of the lowest `(handle, end)` among [ends].
int nodeOwner(List<End> ends) {
  var o = 0;
  for (var i = 1; i < ends.length; i++) {
    if (_byHandleThenEnd(ends[i], ends[o]) < 0) o = i;
  }
  return o;
}

/// Wedge [w], anticlockwise from end `w` to end `w + 1`: its points on the
/// central polygon, in anticlockwise order (spec 07 D5.2, D6).
///
/// One corner, end `w`'s outgoing-left face ∩ end `w + 1`'s outgoing-right
/// face, computed once in that argument order so both walls hold the same
/// bits. Both faces are taken through [hub], not through each end's own
/// point: the members' points differ by up to `wallJoin.linear`, and a face
/// at offset 0 must pass exactly through the node, so that a corner and a
/// foot on it coincide bitwise and the lobes split there (D5.5). Measured on
/// spike Q5b's generator with every wall in its own rotated group: through
/// each end's own point, 1.19% of nodes leave a hole and 0.17% of walls fall
/// back; through [hub], 0.76% and 0.11%, as with bitwise joints.
///
/// A wedge narrower than 90° is never clamped: its long inner mitre is real
/// geometry. A wider wedge whose faces are parallel, or whose corner lies
/// farther than `mitreLimit / 2 ×` the thicker wall from [hub], is clamped to
/// two feet: end `w`'s left face point at [hub], then end `w + 1`'s right
/// face point at [hub].
List<Vector2> wedge(List<End> ends, int w, Vector2 hub) {
  final x = ends[w], y = ends[(w + 1) % ends.length];
  final s = sweep(x, y);
  final c = intersect(x.leftPoint(hub), x.a, y.rightPoint(hub), y.a);
  final limit = mitreLimit / 2 * math.max(x.wall.t, y.wall.t);
  if (c != null && (s < math.pi / 2 || (c - hub).length <= limit)) return [c];
  return [x.leftPoint(hub), y.rightPoint(hub)];
}

/// The anticlockwise sweep from [x]'s direction to [y]'s, in (0, 2π].
double sweep(End x, End y) {
  var s = y.angle - x.angle;
  if (s <= 0) s += 2 * math.pi;
  return s;
}

/// A wall's world outline: an anticlockwise ring, end cap then start cap
/// (spec 07 D5, D6).
///
/// - `ring` is empty for a degenerate wall (D2).
/// - `fellBack` is true when the joined ring was not simple and
///   anticlockwise, so this wall alone squared both ends at its own endpoints
///   (D6's short wall). Its neighbours are unaffected: squaring them too
///   would make them depend on each other through this wall, a two-hop
///   dependency 06's closure does not regenerate.
/// - `hole` lists the node's member walls (Ruling 07-3), ascending, when a
///   crossing lobe of positive area was dropped at one of this wall's ends
///   and this wall owns that lobe (D5.6, D12: reported once, by the owner).
///   If both ends own one, it lists both nodes' members, ascending, once each.
///
/// The ring is simplified (D6): exact consecutive duplicates and zero-width
/// spikes, which do occur (a closing duplicate at some right-angle Ls of
/// round sizes), are removed. No measured triangulation outcome has depended
/// on it, since lobes split at exactly repeated vertices and the triangulator
/// tolerates consecutive duplicates; it stays as D6's guard.
///
/// [fallback] false returns the joined ring even when it is not simple — a
/// measurement hook, never used to store an outline.
({List<Vector2> ring, bool fellBack, List<Handle>? hole}) outline(
    WorldWall w, List<WorldWall> others,
    {bool fallback = true}) {
  if (w.degenerate) {
    return (ring: const <Vector2>[], fellBack: false, hole: null);
  }
  final je = classify(w, 1, others), js = classify(w, 0, others);
  final ce = cap(End(w, 1), je), cs = cap(End(w, 0), js);
  final owned = <int>{
    if (ce.ownsHole)
      for (final h in (je as NodeJoint).members) h.value,
    if (cs.ownsHole)
      for (final h in (js as NodeJoint).members) h.value,
  }.toList()
    ..sort();
  final hole = owned.isEmpty ? null : [for (final h in owned) Handle(h)];
  final ring = simplifyRing([...ce.points, ...cs.points]);
  if (fallback && !isSimpleCcw(ring)) {
    return (
      ring: [
        ...cap(End(w, 1), const Free()).points,
        ...cap(End(w, 0), const Free()).points,
      ],
      fellBack: true,
      hole: hole,
    );
  }
  return (ring: ring, fellBack: false, hole: hole);
}

/// [outline]'s two caps kept apart (spec 08 D7), in world space: the end
/// cap, from the wall's right face to its left face, and the start cap,
/// from its left face to its right face — `[...endCap, ...startCap]` is
/// [outline]'s ring before it is simplified. When that ring is not simple
/// and anticlockwise, both caps are the free caps and `fellBack` is true,
/// as [outline]'s fallback. Null for a degenerate wall (07 D2).
({List<Vector2> endCap, List<Vector2> startCap, bool fellBack})? capsOf(
    WorldWall w, List<WorldWall> others) {
  if (w.degenerate) return null;
  final ce = cap(End(w, 1), classify(w, 1, others)).points;
  final cs = cap(End(w, 0), classify(w, 0, others)).points;
  if (!isSimpleCcw(simplifyRing([...ce, ...cs]))) {
    return (
      endCap: cap(End(w, 1), const Free()).points,
      startCap: cap(End(w, 0), const Free()).points,
      fellBack: true,
    );
  }
  return (endCap: ce, startCap: cs, fellBack: false);
}

/// The signed area of a closed ring, anticlockwise positive.
double signedArea(List<Vector2> r) {
  var a = 0.0;
  for (var i = 0; i < r.length; i++) {
    final p = r[i], q = r[(i + 1) % r.length];
    a += p.x * q.y - q.x * p.y;
  }
  return a / 2;
}

bool _same(Vector2 a, Vector2 b) => a.x == b.x && a.y == b.y;

/// Removes exact consecutive duplicates and zero-width spikes `a, b, a`
/// (spec 07 D6). Stored-value comparisons, so exact; zero area, so the tiling
/// is unchanged. Without it the triangulator refuses a pinched outline.
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

/// Exact, like the triangulator: the signed area is positive and no two
/// non-adjacent edges properly cross (spec 07 D6's invariant).
bool isSimpleCcw(List<Vector2> ring) {
  final n = ring.length;
  if (!(signedArea(ring) > 0)) return false;
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
