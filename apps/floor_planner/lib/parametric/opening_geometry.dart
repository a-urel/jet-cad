// Pure opening geometry (spec 08 D7, D8; Ruling 08-8). No Flutter import:
// this file is Dart over `package:jet_cad_2d` and `vector_math` only.
//
// One function computes a host wall's frame, called by the wall and by each
// of its openings, so both get the same bits. Everything here is in the
// host's group-local space, where 07 stores the wall's outline.
//
// Ported from the spike (`spike/08-openings` at 634fa7c,
// `apps/floor_planner/lib/parametric/opening.dart`): `hostFrame`, `cutOf`
// and `mergeCuts`. The spike had no obstacles and clamped into the whole
// straight span; D7's obstacles and stretches and D8's candidate rule are
// new.
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'wall.dart';
import 'wall_geometry.dart';

/// A host wall seen from its own group-local space (spec 08 D7).
///
/// - [s] is the stored `start`, [d] the unit direction to `end`, [n] the
///   left normal and [len] the centreline's length; `u` is the distance
///   from [s] along [d];
/// - [lOff] and [rOff] are 07 D2's face offsets along [n];
/// - [endCap] (right face to left face) and [startCap] (left face to right
///   face) are 07's own caps ([capsOf]) taken to local space;
/// - the **straight span** `[uS, uE]`: [uS] is the largest `u` of any
///   start-cap vertex and [uE] the smallest `u` of any end-cap vertex.
///   Between them both faces are plain offsets, whatever the joint;
/// - [fellBack] when the caps are the free caps (07's fallback, in world
///   or in local space).
final class HostFrame {
  HostFrame._(this.s, this.d, this.len, this.lOff, this.rOff, this.endCap,
      this.startCap, this.fellBack)
      : n = Vector2(-d.y, d.x),
        uS = startCap.map((q) => (q - s).dot(d)).reduce(math.max),
        uE = endCap.map((q) => (q - s).dot(d)).reduce(math.min);

  final Vector2 s, d, n;
  final double len, lOff, rOff;
  final List<Vector2> endCap, startCap;
  final bool fellBack;
  final double uS, uE;

  /// The local point [u] along the centreline and [off] along [n].
  Vector2 at(double u, double off) => s + d * u + n * off;

  /// The left and right face points at [u].
  Vector2 left(double u) => at(u, lOff);
  Vector2 right(double u) => at(u, rOff);

  /// The `u` of the local point [q].
  double uOf(Vector2 q) => (q - s).dot(d);
}

/// [host]'s frame (spec 08 D7), among [walls] (any walls; [classify] skips
/// [host] itself, degenerate walls and walls that do not join it). Null
/// for a degenerate host (07 D2).
///
/// The caps are computed in world, as 07's outline is, then taken to the
/// host's group-local space through `host.toWorld.invert()` and judged
/// again there (07's final review I1): a local ring that is not simple and
/// anticlockwise is replaced by the free caps computed in local space, the
/// wall at the identity with no neighbours, and the frame falls back.
HostFrame? hostFrameOf(WorldWall host, List<WorldWall> walls) {
  final caps = capsOf(host, walls);
  if (caps == null) return null;
  final p = host.params;
  final toLocal = host.toWorld.invert();
  var ce = [for (final q in caps.endCap) toLocal.transformPoint(q)];
  var cs = [for (final q in caps.startCap) toLocal.transformPoint(q)];
  var fellBack = caps.fellBack;
  if (!isSimpleCcw(simplifyRing([...ce, ...cs]))) {
    final free = WorldWall(host.handle, p, Transform2.identity());
    ce = cap(End(free, 1), const Free()).points;
    cs = cap(End(free, 0), const Free()).points;
    fellBack = true;
  }
  final dv = p.end - p.start;
  final (l, r) = host.offsets;
  return HostFrame._(
      p.start, dv.normalized(), dv.length, l, r, ce, cs, fellBack);
}

/// An interval `[a, b]` of `u` that another wall's band occupies inside the
/// host (spec 08 D7), and that wall.
typedef Obstacle = ({double a, double b, Handle wall});

/// The obstacles [walls] make in [host]'s band (spec 08 D7, decision 18),
/// sorted by `a`, then `b`, then handle. [frame] is [host]'s.
///
/// Among the walls that are neither [host] nor degenerate, and whose
/// direction is not parallel to [host]'s within `wallJoin.angular`:
/// - **a T:** an end of B that lies strictly inside [host]'s centreline
///   (07 D4.1's [strictlyInside], [host] as the through wall). The interval
///   is the `u`-range of `cap(End(B, k), Tee(host))`'s points: 07's own T
///   cap on [host]'s near face, or B's own square end inside [host]'s body
///   when the mitre limit clamps it. Judged against [host] only, whichever
///   wall 07 picks as B's through wall;
/// - **an X:** B's centreline crosses [host]'s more than `wallJoin.linear`
///   inside both (07 D4's X). The interval is the `u`-range of the four
///   points where B's two faces cross [host]'s two faces.
///
/// Not obstacles: a free end that pokes into the band off the centreline,
/// and a collinear overlapping wall (07 Ruling 07-4; it is parallel).
List<Obstacle> obstaclesOf(
    HostFrame frame, WorldWall host, List<WorldWall> walls) {
  final toLocal = host.toWorld.invert();
  final hn = Vector2(-host.d.y, host.d.x);
  final (hl, hr) = host.offsets;
  final hLen = (host.e - host.s).length;
  Obstacle span(Iterable<Vector2> world, Handle wall) {
    final us = [for (final q in world) frame.uOf(toLocal.transformPoint(q))];
    return (a: us.reduce(math.min), b: us.reduce(math.max), wall: wall);
  }

  final out = <Obstacle>[];
  for (final b in walls) {
    if (b.handle == host.handle || b.degenerate) continue;
    final cross = host.d.x * b.d.y - host.d.y * b.d.x;
    if (cross.abs() <= wallJoin.angular) continue;
    var tee = false;
    for (final k in const [0, 1]) {
      if (!strictlyInside(b.endpoint(k), host)) continue;
      tee = true;
      out.add(span(cap(End(b, k), Tee(host)).points, b.handle));
    }
    if (tee) continue;
    // Where the centrelines cross, as parameters along each.
    final w = b.s - host.s;
    final uh = (w.x * b.d.y - w.y * b.d.x) / cross;
    final ub = (w.x * host.d.y - w.y * host.d.x) / cross;
    final bLen = (b.e - b.s).length;
    if (!(uh > wallJoin.linear && uh < hLen - wallJoin.linear) ||
        !(ub > wallJoin.linear && ub < bLen - wallJoin.linear)) {
      continue;
    }
    final bn = Vector2(-b.d.y, b.d.x);
    final (bl, br) = b.offsets;
    out.add(span([
      for (final ho in [hl, hr])
        for (final bo in [bl, br])
          if (intersect(host.s + hn * ho, host.d, b.s + bn * bo, b.d)
              case final q?)
            q,
    ], b.handle));
  }
  out.sort((x, y) {
    final c = x.a.compareTo(y.a);
    if (c != 0) return c;
    final e = x.b.compareTo(y.b);
    return e != 0 ? e : x.wall.value.compareTo(y.wall.value);
  });
  return out;
}

/// The stretches of [frame] (spec 08 D7): its straight span minus the union
/// of [obstacles], sorted and disjoint. Subtracting compares computed values
/// exactly, so each stretch's ends are the span's or an obstacle's own
/// bits; only the final test, which drops a stretch no longer than
/// `wallJoin.linear`, uses the tolerance.
List<(double, double)> stretchesOf(HostFrame frame, List<Obstacle> obstacles) {
  final sorted = [...obstacles]..sort((x, y) => x.a.compareTo(y.a));
  final out = <(double, double)>[];
  void add(double a, double b) {
    if (b - a > wallJoin.linear) out.add((a, b));
  }

  var from = frame.uS;
  for (final o in sorted) {
    if (!(from < frame.uE)) break;
    if (o.a > from) add(from, o.a < frame.uE ? o.a : frame.uE);
    if (o.b > from) from = o.b;
  }
  if (from < frame.uE) add(from, frame.uE);
  return out;
}

/// Where an opening centred at [c] with width [w] cuts (spec 08 D8), among
/// [stretches] (sorted, as [stretchesOf] gives them):
///
/// 1. the candidates are the stretches at least [w] long;
/// 2. none: no fit, null;
/// 3. the chosen one is the candidate nearest [c] (the distance from [c] to
///    the interval, 0 inside it); ties go to the lower `a`;
/// 4. the cut is `[x, x + w]` with `x = clamp(c − w/2, a, b − w)`, and it
///    is `clamped` when `x ≠ c − w/2`: exact, since an unclamped `x` is
///    `c − w/2` itself.
///
/// Null too for a degenerate opening (D6): a width not greater than
/// `wallJoin.linear`, or a non-finite width or centre.
({double a, double b, bool clamped})? placeCut(
    List<(double, double)> stretches, double c, double w) {
  if (!c.isFinite || !w.isFinite || !(w > wallJoin.linear)) return null;
  (double, double)? best;
  var bestDistance = double.infinity;
  for (final s in stretches) {
    final (a, b) = s;
    if (!(w <= b - a)) continue;
    final distance = c < a ? a - c : (c > b ? c - b : 0.0);
    if (distance < bestDistance) {
      best = s;
      bestDistance = distance;
    }
  }
  if (best == null) return null;
  final (a, b) = best;
  final want = c - w / 2;
  var x = want;
  if (x < a) x = a;
  if (x > b - w) x = b - w;
  return (a: x, b: x + w, clamped: x != want);
}

/// The cuts of one wall merged (spec 08 D8, decision 6): sorted by start; a
/// cut that starts within `wallJoin.linear` of the previous merged cut's end
/// joins it, so two overlapping or touching openings make one gap and no
/// sliver piece.
List<(double, double)> mergeCuts(List<(double, double)> cuts) {
  final sorted = [...cuts]..sort((x, y) => x.$1.compareTo(y.$1));
  final out = <(double, double)>[];
  for (final c in sorted) {
    if (out.isNotEmpty && c.$1 <= out.last.$2 + wallJoin.linear) {
      out.last = (out.last.$1, math.max(out.last.$2, c.$2));
    } else {
      out.add(c);
    }
  }
  return out;
}

/// Whether two fitting cuts of one host overlap (spec 08 D8, for D17): each
/// starts more than `wallJoin.linear` before the other ends. Touching is not
/// overlap.
bool overlaps((double, double) x, (double, double) y) =>
    x.$1 < y.$2 - wallJoin.linear && y.$1 < x.$2 - wallJoin.linear;
