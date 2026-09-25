// Pure opening geometry (spec 08 D7-D9; Ruling 08-8). No Flutter import:
// this file is Dart over `package:jet_cad_2d` and `vector_math` only.
//
// One function computes a host wall's frame, called by the wall and by each
// of its openings, so both get the same bits. Everything here is in the
// host's group-local space, where 07 stores the wall's outline.
//
// Ported from the spike (`spike/08-openings` at 634fa7c,
// `apps/floor_planner/lib/parametric/opening.dart`): `hostFrame`, `cutOf`,
// `mergeCuts` and `piecesOf` with its cap-vertex snap. The spike had no
// obstacles and clamped into the whole straight span; D7's obstacles and
// stretches, D8's candidate rule and its "a wall keeps a piece" (amended at
// execution), and D9's split centreline are new.
import 'dart:math' as math;
import 'dart:typed_data' show ByteData;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'opening.dart';
import 'wall.dart';
import 'wall_geometry.dart';

/// A host wall seen from its own group-local space (spec 08 D7).
///
/// - [s] is the stored `start`, [e] the stored `end`, [d] the unit
///   direction from [s] to [e], [n] the left normal and [len] the
///   centreline's length; `u` is the distance from [s] along [d];
/// - [lOff] and [rOff] are 07 D2's face offsets along [n];
/// - [endCap] (right face to left face) and [startCap] (left face to right
///   face) are 07's own caps ([capsOf]) taken to local space;
/// - the **straight span** `[uS, uE]`: [uS] is the largest `u` of any
///   start-cap vertex and [uE] the smallest `u` of any end-cap vertex.
///   Between them both faces are plain offsets, whatever the joint;
/// - [fellBack] when the caps are the free caps (07's fallback, in world
///   or in local space).
final class HostFrame {
  HostFrame._(this.s, this.e, this.d, this.len, this.lOff, this.rOff,
      this.endCap, this.startCap, this.fellBack)
      : n = Vector2(-d.y, d.x),
        uS = startCap.map((q) => (q - s).dot(d)).reduce(math.max),
        uE = endCap.map((q) => (q - s).dot(d)).reduce(math.min);

  final Vector2 s, d, n;

  /// The stored `end`: where the end piece's centreline stops (D9), the
  /// stored value itself rather than `s + len·d` recomputed.
  final Vector2 e;

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
      p.start, p.end, dv.normalized(), dv.length, l, r, ce, cs, fellBack);
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
///   is the `u`-range of `cap(End(B, k), Tee(host))`'s points (07's own T
///   cap on [host]'s near face, or B's own square end inside [host]'s body
///   when the mitre limit clamps it) **together with** the points where B's
///   two faces cross [host]'s near face, so a clamped T covers B's whole
///   footprint in [host]'s band (D7 as amended by Task 3's review S1).
///   Judged against [host] only, whichever wall 07 picks as B's through
///   wall;
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
    final bn = Vector2(-b.d.y, b.d.x);
    final (bl, br) = b.offsets;
    var tee = false;
    for (final k in const [0, 1]) {
      if (!strictlyInside(b.endpoint(k), host)) continue;
      tee = true;
      final end = End(b, k);
      // The near face: the one on the side B's body goes to, as 07's cap.
      final near = host.s + hn * (end.a.dot(hn) > 0 ? hl : hr);
      out.add(span([
        ...cap(end, Tee(host)).points,
        for (final bo in [bl, br])
          if (intersect(near, host.d, b.s + bn * bo, b.d) case final q?) q,
      ], b.handle));
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

/// One opening's cut (spec 08 D8): `[a, b]` along its host's centreline, and
/// whether the clamp moved it off its stored interval.
typedef Cut = ({double a, double b, bool clamped});

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
Cut? placeCut(List<(double, double)> stretches, double c, double w) {
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

/// The centre to store for an opening of width [w] that is to cut at
/// [cut] among [stretches] (spec 08 D14, D16: stored where it is drawn):
/// `cut.a + w/2`, moved by the fewest ulps that make [placeCut] place it
/// unclamped. `(cut.a + w/2) − w/2` need not round back to `cut.a`, and a
/// start one ulp outside `[a, b − w]` would be clamped (D8's exact
/// comparison), so the opening would be `opening.clamped` from birth.
/// Gives up after a few ulps and returns the last value tried: a stretch
/// exactly `w` long whose `b − w` rounds below `a` holds no unclamped
/// start at all.
double storedCentreOf(List<(double, double)> stretches, Cut cut, double w) {
  var c = cut.a + w / 2;
  for (var i = 0; i < 8; i++) {
    final placed = placeCut(stretches, c, w);
    if (placed == null || !placed.clamped) return c;
    // Raised by the clamp: the centre is too low, and the other way round.
    c = _nextAfter(c, placed.a > c - w / 2);
  }
  return c;
}

/// The double next to [x], above it when [up].
double _nextAfter(double x, bool up) {
  if (x == 0) return up ? double.minPositive : -double.minPositive;
  final b = ByteData(8)..setFloat64(0, x);
  final bits = b.getInt64(0);
  b.setInt64(0, (x > 0) == up ? bits + 1 : bits - 1);
  return b.getFloat64(0);
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

/// Where each of one host's openings cuts, and the host's merged cuts (spec
/// 08 D8). [openings] are `(centre, width)` in **ascending handle order**;
/// [stretches] and [frame] are the host's.
///
/// Each opening is placed on its own ([placeCut]): no opening's placement
/// depends on another's. Then **a wall keeps a piece** (D8 as amended at
/// execution, revised after Task 5's review): the fitting openings are
/// admitted in ascending handle order; each one's cut is added to the
/// admitted cuts and merged ([mergeCuts]), and if that would leave [frame]
/// no piece longer than `wallJoin.linear` (a cut spanning the whole span,
/// cuts covering it together, or cuts leaving only slivers), this opening
/// is made no-fit and left out; otherwise it is kept. So a cut wall always
/// generates a piece, the outcome is deterministic, and an opening yields
/// only when admitting it is what would empty the wall.
///
/// `cuts[i]` is null when opening `i` does not fit, from the start or by
/// that rule; `merged` is the admitted cuts merged, empty when nothing cuts
/// the host.
({List<Cut?> cuts, List<(double, double)> merged}) cutsOf(HostFrame frame,
    List<(double, double)> stretches, List<(double, double)> openings) {
  final cuts = [for (final (c, w) in openings) placeCut(stretches, c, w)];
  final admitted = <(double, double)>[];
  var merged = const <(double, double)>[];
  for (var i = 0; i < cuts.length; i++) {
    final c = cuts[i];
    if (c == null) continue;
    final trial = mergeCuts([...admitted, (c.a, c.b)]);
    if (_pieces(frame, trial).isEmpty) {
      cuts[i] = null;
    } else {
      admitted.add((c.a, c.b));
      merged = trial;
    }
  }
  return (cuts: cuts, merged: merged);
}

/// Whether two fitting cuts of one host overlap (spec 08 D8, for D17): each
/// starts more than `wallJoin.linear` before the other ends. Touching is not
/// overlap.
bool overlaps((double, double) x, (double, double) y) =>
    x.$1 < y.$2 - wallJoin.linear && y.$1 < x.$2 - wallJoin.linear;

/// Spec 08 D15's edge snap: the centre that puts one edge of an opening
/// centred at [u], [w] wide, on a candidate, or null.
///
/// - The candidates are every stretch's ends ([stretches], as [stretchesOf]
///   gives them: the straight span's ends and the obstacles' edges inside
///   it) and every edge of [otherCuts] (the host's other openings' drawn
///   cuts, D8).
/// - An edge `u − w/2` or `u + w/2` within [aperture] of a candidate (the
///   distance at most [aperture]) snaps: the centre becomes the one that
///   puts that edge on it.
/// - The nearest (edge, candidate) pair wins; ties go to the lower centre.
///
/// Everything is along the host's centreline, in its local units: the
/// caller gives [aperture] in them.
double? edgeSnap(List<(double, double)> stretches,
    List<(double, double)> otherCuts, double u, double w, double aperture) {
  final lo = u - w / 2, hi = u + w / 2;
  double? best;
  var bestDistance = double.infinity;
  void offer(double centre, double distance) {
    if (distance > aperture) return;
    if (distance < bestDistance ||
        (distance == bestDistance && centre < best!)) {
      best = centre;
      bestDistance = distance;
    }
  }

  void candidate(double q) {
    offer(q + w / 2, (lo - q).abs());
    offer(q - w / 2, (hi - q).abs());
  }

  for (final (a, b) in stretches) {
    candidate(a);
    candidate(b);
  }
  for (final (a, b) in otherCuts) {
    candidate(a);
    candidate(b);
  }
  return best;
}

/// One piece of a cut wall's band (spec 08 D9): its anticlockwise ring and
/// its centreline's two points, in the host's local space.
typedef _Piece = ({List<Vector2> ring, List<Vector2> line});

/// The pieces of [f]'s band between the cuts [merged] (sorted and merged,
/// as [mergeCuts] gives them, all inside the straight span), start piece
/// first (spec 08 D9; spike rule 3):
/// - the start piece `[R(a₀), L(a₀)] + start cap`;
/// - middle piece `i`: `[R(aᵢ₊₁), L(aᵢ₊₁), L(bᵢ), R(bᵢ)]`;
/// - the end piece `end cap + [L(bₙ), R(bₙ)]`.
///
/// The **cap-vertex snap:** a cut clamped onto the span lands on a cap's face
/// vertex, and the face point recomputed there differs from it by rounding
/// (~1e-10); that near duplicate makes the triangulator refuse the piece, and
/// the edit with it. So within `wallJoin.linear` along `u` of a cap's face
/// vertex, that vertex is the piece's corner and the recomputed point is left
/// out. A piece no longer than `wallJoin.linear` along the centreline (an
/// opening clamped against a square cap) is dropped, and its centreline with
/// it; [simplifyRing] guards every ring.
List<_Piece> _pieces(HostFrame f, List<(double, double)> merged) {
  final out = <_Piece>[];
  void add(List<Vector2> ring, double extent, Vector2 from, Vector2 to) {
    if (!(extent > wallJoin.linear)) return;
    out.add((ring: simplifyRing(ring), line: [from, to]));
  }

  bool on(Vector2 capVertex, double u) =>
      (f.uOf(capVertex) - u).abs() <= wallJoin.linear;
  // The start cap runs from the left face to the right face, the end cap
  // from the right face to the left face (07's `cap`).
  final a0 = merged.first.$1;
  add([
    if (!on(f.startCap.last, a0)) f.right(a0),
    if (!on(f.startCap.first, a0)) f.left(a0),
    ...f.startCap,
  ], a0 - f.startCap.map(f.uOf).reduce(math.min), f.s, f.at(a0, 0));
  for (var i = 0; i + 1 < merged.length; i++) {
    final b = merged[i].$2, a = merged[i + 1].$1;
    add([f.right(a), f.left(a), f.left(b), f.right(b)], a - b, f.at(b, 0),
        f.at(a, 0));
  }
  final bn = merged.last.$2;
  add([
    ...f.endCap,
    if (!on(f.endCap.last, bn)) f.left(bn),
    if (!on(f.endCap.first, bn)) f.right(bn),
  ], f.endCap.map(f.uOf).reduce(math.max) - bn, f.at(bn, 0), f.e);
  return out;
}

/// The rings of [f]'s band cut at [merged] (spec 08 D9), in `u` order, start
/// piece first: each simple and anticlockwise in the host's local space.
/// [merged] must not be empty.
List<List<Vector2>> piecesOf(HostFrame f, List<(double, double)> merged) =>
    [for (final p in _pieces(f, merged)) p.ring];

/// One open two-point centreline per piece [piecesOf] keeps, in the same
/// order (spec 08 D9, decision 16): the start piece's from `u = 0` (the
/// stored `start`) to `a₀`, a middle piece's from `bᵢ` to `aᵢ₊₁`, the end
/// piece's from `bₙ` to `L` (the stored `end`). A dropped piece has none.
List<List<Vector2>> centrelinePieces(
        HostFrame f, List<(double, double)> merged) =>
    [for (final p in _pieces(f, merged)) p.line];

/// Opening [o]'s symbol (spec 08 D10, D11), computed in its host's local
/// space on the host's frame [f] and taken to the opening's own local space
/// by [toOwn], which is `toWorld(self)⁻¹ · toWorld(host)`: host-local →
/// world → own local. Every child is ByLayer, `Generated`'s default.
///
/// [cut] is the opening's cut (D8); the symbol is drawn over `[x₁, x₂]`,
/// the cut's interval. Null means no-fit (D11): the symbol is drawn over
/// the **stored** interval `[c − w/2, c + w/2]`, never over the band.
///
/// - **door** (a LINE, then an ARC): the hinge `H` is the jamb corner on the
///   swing-side face at `x₁` (hinge `start`) or `x₂` (hinge `end`); the leaf
///   runs from `H` perpendicular to the wall, away from the band, `w` long;
///   the swing is the quarter arc about `H` of radius `w` between the leaf's
///   tip and the shut jamb (the other jamb on the same face), a sweep of
///   +π/2, starting at whichever of the two makes it anticlockwise. A no-fit
///   door is drawn the same way: its symbol lies outside the band already;
/// - **window** (three LINEs, in order): the left face, the midline
///   `(lOff + rOff)/2` and the right face, from `x₁` to `x₂`. No-fit, each
///   is translated by the thickness `t` along the left normal: offsets
///   `lOff + t`, `lOff + t/2` and `lOff`;
/// - **gap** (one LINE): the threshold line on the centreline (offset 0)
///   from `x₁ + m` to `x₂ − m`, `m = min(t/4, w/4)`. No-fit, at offset
///   `lOff + t/2`.
///
/// [o] must not be degenerate (D6): it generates nothing.
List<Generated> symbolOf(
    HostFrame f, OpeningParams o, Cut? cut, Transform2 toOwn) {
  final w = o.width;
  final fits = cut != null;
  final x1 = fits ? cut.a : o.position - w / 2;
  final x2 = fits ? cut.b : o.position + w / 2;
  final t = f.lOff - f.rOff;
  Vector2 own(double u, double off) => toOwn.transformPoint(f.at(u, off));
  Generated line(double u1, double u2, double off) =>
      Generated(EntityKind.line, linePayload(own(u1, off), own(u2, off)));
  switch (o.kind) {
    case OpeningKind.door:
      final (uh, us) = o.hinge == HingeEnd.start ? (x1, x2) : (x2, x1);
      final (face, out) =
          o.swing == SwingSide.left ? (f.lOff, w) : (f.rOff, -w);
      final hinge = own(uh, face);
      final tip = own(uh, face + out);
      final shut = own(us, face);
      final toTip = tip - hinge, toShut = shut - hinge;
      final ccw = toTip.x * toShut.y - toTip.y * toShut.x > 0;
      final from = ccw ? toTip : toShut;
      return [
        Generated(EntityKind.line, linePayload(hinge, tip)),
        Generated(
            EntityKind.arc,
            arcPayload(
                hinge, toTip.length, math.atan2(from.y, from.x), math.pi / 2)),
      ];
    case OpeningKind.window:
      final offsets = fits
          ? [f.lOff, (f.lOff + f.rOff) / 2, f.rOff]
          : [f.lOff + t, f.lOff + t / 2, f.lOff];
      return [for (final off in offsets) line(x1, x2, off)];
    case OpeningKind.gap:
      final m = math.min(t / 4, w / 4);
      return [line(x1 + m, x2 - m, fits ? 0 : f.lOff + t / 2)];
  }
}

/// The walls a regeneration sees around [host] (the **view adapter**,
/// Ruling 08-8): [host] as a [WorldWall], and every neighbour of it in
/// [view] carrying `WallParams`, as 07's outline reads them. Null when
/// [host] is not a live wall.
({WorldWall host, List<WorldWall> walls})? wallsInView(
    ParametricView view, Handle host) {
  final p = view.paramsOf<WallParams>(host);
  if (p == null) return null;
  return (
    host: WorldWall(host, p, view.toWorld(host)),
    walls: [
      for (final n in view.neighbours(host))
        if (view.paramsOf<WallParams>(n) case final q?)
          WorldWall(n, q, view.toWorld(n)),
    ],
  );
}

/// A host's frame, its obstacles and its stretches (spec 08 D7).
typedef HostLayout = ({
  HostFrame frame,
  List<Obstacle> obstacles,
  List<(double, double)> stretches,
});

/// [host]'s layout among [walls]: one computation for the wall and for each
/// of its openings. Null for a degenerate host.
HostLayout? layoutOf(WorldWall host, List<WorldWall> walls) {
  final frame = hostFrameOf(host, walls);
  if (frame == null) return null;
  final obstacles = obstaclesOf(frame, host, walls);
  return (
    frame: frame,
    obstacles: obstacles,
    stretches: stretchesOf(frame, obstacles),
  );
}

/// [host]'s layout through the view adapter ([wallsInView]). Null when
/// [host] is not a live wall or is degenerate.
HostLayout? layoutInView(ParametricView view, Handle host) {
  final w = wallsInView(view, host);
  return w == null ? null : layoutOf(w.host, w.walls);
}

/// [host]'s openings in [view]: its referrers carrying `OpeningParams` whose
/// host is [host], ascending by handle, with their parameters.
List<(Handle, OpeningParams)> openingsInView(
        ParametricView view, Handle host) =>
    [
      for (final h in view.referrers(host))
        if (view.paramsOf<OpeningParams>(h) case final o? when o.host == host)
          (h, o),
    ];

/// Everything D7 and D8 decide for one host: its [HostLayout], its openings
/// (ascending), each one's cut (null: no fit, D8), and the merged cuts.
typedef HostCuts = ({
  HostLayout layout,
  List<Handle> openings,
  List<Cut?> cuts,
  List<(double, double)> merged,
});

/// Each view's [hostCutsInView] results, by host. A view is built for one
/// pass (an edit's plan, `drift()`, `diagnostics()`) over a document that
/// does not change during it, so a host's cuts are computed once per pass:
/// the wall and each of its `n` openings would otherwise each recompute
/// them, `n + 1` times per host edit.
final Expando<Map<Handle, HostCuts?>> _hostCutsByView =
    Expando('hostCutsInView');

/// [host]'s cuts through the view adapter: one computation, made by the wall
/// for its pieces and by each of its openings for its symbol and its
/// diagnostics, so all of them see the same decision. Memoised per [view]
/// and host. Null when [host] has no openings, is not a live wall, or is
/// degenerate (07 D2: no frame).
HostCuts? hostCutsInView(ParametricView view, Handle host) {
  final memo = _hostCutsByView[view] ??= <Handle, HostCuts?>{};
  if (memo.containsKey(host)) return memo[host];
  return memo[host] = _hostCuts(view, host);
}

HostCuts? _hostCuts(ParametricView view, Handle host) {
  final openings = openingsInView(view, host);
  if (openings.isEmpty) return null;
  final layout = layoutInView(view, host);
  if (layout == null) return null;
  final placed = cutsOf(layout.frame, layout.stretches, [
    for (final (_, o) in openings) (o.position, o.width),
  ]);
  return (
    layout: layout,
    openings: [for (final (h, _) in openings) h],
    cuts: placed.cuts,
    merged: placed.merged,
  );
}

/// Whether [h] is a live object of [doc] as the engine's survey reads one:
/// its node is a root-level group.
bool _isLiveGroup(DraftDocument doc, Handle h) {
  final node = doc.tree[h];
  return node is GroupNode && node.parent == doc.tree.root;
}

/// The walls the tools, the grips and the panel see around [host] (the
/// **document adapter**, Ruling 08-8): [host] as a [WorldWall], and every
/// other live wall object of [doc] (a root-level group carrying
/// `WallParams`), ascending by handle. The view adapter ([wallsInView])
/// sees only [host]'s neighbours; [classify], [cap] and [obstaclesOf]
/// ignore a wall that does not join [host], so the extra walls change
/// nothing (`HF7` pins that both give the same bits). Null when [host] is
/// not a live wall.
///
/// [moved] stands in for the walls it names (an end drag's walls before it
/// is executed, spec 08 D13): each is read from it instead of [doc].
({WorldWall host, List<WorldWall> walls})? wallsInDocument(
    DraftDocument doc, Handle host,
    {Map<Handle, WorldWall> moved = const {}}) {
  final p = doc.components.get<WallParams>(host);
  if (p == null || !_isLiveGroup(doc, host)) return null;
  return (
    host:
        moved[host] ?? WorldWall(host, p, doc.tree.accumulatedTransform(host)),
    walls: [
      for (final h in doc.components.withComponent<WallParams>())
        if (h != host && _isLiveGroup(doc, h))
          moved[h] ??
              WorldWall(h, doc.components.get<WallParams>(h)!,
                  doc.tree.accumulatedTransform(h)),
    ],
  );
}

/// [host]'s frame through the document adapter ([wallsInDocument]). Null
/// when [host] is not a live wall or is degenerate.
HostFrame? hostFrameInDocument(DraftDocument doc, Handle host) {
  final w = wallsInDocument(doc, host);
  return w == null ? null : hostFrameOf(w.host, w.walls);
}

/// [host]'s layout (frame, obstacles, stretches) through the document
/// adapter ([wallsInDocument], with [moved] standing in for the walls it
/// names). Null when [host] is not a live wall or is degenerate.
HostLayout? layoutInDocument(DraftDocument doc, Handle host,
    {Map<Handle, WorldWall> moved = const {}}) {
  final w = wallsInDocument(doc, host, moved: moved);
  return w == null ? null : layoutOf(w.host, w.walls);
}

/// [host]'s openings in [doc]: the live objects carrying `OpeningParams`
/// whose host is [host], ascending by handle, with their parameters, as
/// [openingsInView] reads them in a regeneration.
List<(Handle, OpeningParams)> openingsInDocument(
        DraftDocument doc, Handle host) =>
    [
      for (final h in doc.components.withComponent<OpeningParams>())
        if (doc.components.get<OpeningParams>(h)! case final o
            when o.host == host && _isLiveGroup(doc, h))
          (h, o),
    ];
