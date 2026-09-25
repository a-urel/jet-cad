// Oracles for openings (Ruling 08-9). Nothing here calls
// `opening_geometry.dart`: every frame, face and crossing is written out
// from the stored parameters and a transform, and face lines meet through
// `oracleMeet` (Cramer's rule on explicit coordinates).
//
// The first part is the pure level (Task 3): frames, faces, a point's `u`,
// the L's mitre corners, the T's butt and square end, and the X's face
// crossings. The second is the document level (Task 4): openings added and
// deleted as the tools and the select tool do, the pieces and centrelines
// read back to world, the tiling oracle against a twin document's stored
// uncut band, and an independent span, obstacles, stretches and clamp.
import 'dart:math' as math;

import 'package:floor_planner/parametric/opening.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/parametric/wall_geometry.dart' show isSimpleCcw;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'wall_fixture.dart';

/// An independent frame: a wall's world centreline from `s`, its unit
/// direction `d`, left normal `n`, length `len`, and its face offsets `lo`
/// and `ro` along `n`.
typedef OracleFrame = ({
  Vector2 s,
  Vector2 d,
  Vector2 n,
  double len,
  double lo,
  double ro,
});

/// The world frame of a wall stored as [p] in a group whose accumulated
/// transform is [m], written out without the geometry library.
OracleFrame oracleFrame(WallParams p, Transform2 m) {
  final s = m.transformPoint(Vector2(p.sx, p.sy));
  final e = m.transformPoint(Vector2(p.ex, p.ey));
  final dx = e.x - s.x, dy = e.y - s.y;
  final len = math.sqrt(dx * dx + dy * dy);
  final d = Vector2(dx / len, dy / len);
  final t = p.thickness;
  final (lo, ro) = switch (p.justification) {
    Justification.left => (t, 0.0),
    Justification.right => (0.0, -t),
    Justification.centre => (t / 2, -t / 2),
  };
  return (s: s, d: d, n: Vector2(-d.y, d.x), len: len, lo: lo, ro: ro);
}

/// [f]'s end point: `s` for [k] 0, `s + len·d` otherwise.
Vector2 oracleEnd(OracleFrame f, int k) =>
    k == 0 ? f.s : Vector2(f.s.x + f.d.x * f.len, f.s.y + f.d.y * f.len);

/// [f]'s face line at [offset] along `n`, as two world points.
(Vector2, Vector2) oracleFace(OracleFrame f, double offset) {
  final e = oracleEnd(f, 1);
  return (
    Vector2(f.s.x + f.n.x * offset, f.s.y + f.n.y * offset),
    Vector2(e.x + f.n.x * offset, e.y + f.n.y * offset),
  );
}

/// The `u` of world point [q] in [f]: its distance from `s` along `d`.
double oracleU(OracleFrame f, Vector2 q) =>
    (q.x - f.s.x) * f.d.x + (q.y - f.s.y) * f.d.y;

/// The `u`-range of [points] in [f].
(double, double) oracleRange(OracleFrame f, Iterable<Vector2> points) {
  final us = [for (final q in points) oracleU(f, q)];
  return (us.reduce(math.min), us.reduce(math.max));
}

/// Where face line [p] meets face line [q].
Vector2 meetFaces((Vector2, Vector2) p, (Vector2, Vector2) q) =>
    oracleMeet(p.$1, p.$2, q.$1, q.$2);

/// The two mitre corners of wall [a]'s end and wall [b]'s start at one
/// node: left face meets left face, right face meets right face.
List<Vector2> oracleMitre(OracleFrame a, OracleFrame b) => [
      meetFaces(oracleFace(a, a.lo), oracleFace(b, b.lo)),
      meetFaces(oracleFace(a, a.ro), oracleFace(b, b.ro)),
    ];

/// The two corners where [stem]'s faces meet [host]'s **near** face, the
/// one on the side [stem]'s body lies on, seen from its end [k].
List<Vector2> oracleTeeButt(OracleFrame host, OracleFrame stem, int k) {
  // Into the stem's body from its end k.
  final ax = k == 0 ? stem.d.x : -stem.d.x, ay = k == 0 ? stem.d.y : -stem.d.y;
  final side = ax * host.n.x + ay * host.n.y;
  final near = oracleFace(host, side > 0 ? host.lo : host.ro);
  return [
    meetFaces(oracleFace(stem, stem.lo), near),
    meetFaces(oracleFace(stem, stem.ro), near),
  ];
}

/// [stem]'s square end at its end [k]: its two face points there.
List<Vector2> oracleSquareEnd(OracleFrame stem, int k) {
  final p = oracleEnd(stem, k);
  return [
    for (final o in [stem.lo, stem.ro])
      Vector2(p.x + stem.n.x * o, p.y + stem.n.y * o),
  ];
}

/// The four points where [b]'s two faces cross [host]'s two faces.
List<Vector2> oracleCrossings(OracleFrame host, OracleFrame b) => [
      for (final ho in [host.lo, host.ro])
        for (final bo in [b.lo, b.ro])
          meetFaces(oracleFace(host, ho), oracleFace(b, bo)),
    ];

/// The footprint of [stem]'s end [k] teeing into [host] (spec 08 D7 as
/// amended by Task 3's review S1): the corners where [stem]'s faces meet
/// [host]'s near face, together with 07's cap, which is those same corners
/// unless one lies farther than `mitreLimit / 2 ×` the thicker wall
/// (`lo − ro`) from the end point, when it is [stem]'s square end.
List<Vector2> oracleTeeFootprint(OracleFrame host, OracleFrame stem, int k) {
  final butt = oracleTeeButt(host, stem, k);
  final p = oracleEnd(stem, k);
  final limit = mitreLimit / 2 * math.max(host.lo - host.ro, stem.lo - stem.ro);
  double dist(Vector2 q) =>
      math.sqrt((q.x - p.x) * (q.x - p.x) + (q.y - p.y) * (q.y - p.y));
  final clamped = butt.any((q) => dist(q) > limit);
  return [...butt, if (clamped) ...oracleSquareEnd(stem, k)];
}

// ---------------------------------------------------------------------------
// Documents (Task 4): openings through the parametric system.

/// Creates opening [h] as its own root-level group at [at] (default the
/// identity, like a wall): one command, as the tools will.
DraftCommand addOpening(DraftDocument doc, Handle h, OpeningParams o,
        {Transform2? at}) =>
    CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: h,
          parent: doc.rootHandle,
          transform: at ?? Transform2.identity(),
          children: const [])),
      SetComponentCommand<OpeningParams>(h, o),
    ], label: 'Add opening');

/// The select tool's group delete (`select_tool.dart` `_groupCascade`):
/// every leaf except a fill whose boundary goes too, then the node.
DraftCommand deleteLikeSelectTool(DraftDocument doc, Handle g) =>
    CompoundCommand([
      for (final k in kids(doc, g))
        if (kindOf(doc, k) != EntityKind.fill) RemoveEntityCommand(k),
      RemoveNodeCommand(g),
    ], label: 'Delete');

/// Wall [h]'s [oracleFrame], from its stored parameters and its group's
/// accumulated transform.
OracleFrame oracleFrameOf(DraftDocument doc, Handle h) => oracleFrame(
    doc.components.get<WallParams>(h)!, doc.tree.accumulatedTransform(h));

/// [f]'s world point [u] along the centreline and [off] along `n`.
Vector2 oracleAt(OracleFrame f, double u, double off) =>
    Vector2(f.s.x + f.d.x * u + f.n.x * off, f.s.y + f.d.y * u + f.n.y * off);

/// [h]'s fill children, ascending.
List<Handle> fillsOf(DraftDocument doc, Handle h) => [
      for (final k in kids(doc, h))
        if (kindOf(doc, k) == EntityKind.fill) k
    ];

/// The boundary fill [fill] names.
Handle boundaryOf(DraftDocument doc, Handle fill) =>
    Handle(payloadOf(doc, fill).scalars[0].toInt());

/// Every region boundary of [h] (the polylines its fills name), ascending
/// by fill handle, read back to world.
List<List<Vector2>> worldPieces(DraftDocument doc, Handle h) {
  final m = doc.tree.accumulatedTransform(h);
  return [
    for (final f in fillsOf(doc, h))
      [
        for (final q
            in pointsOf(payloadOf(doc, boundaryOf(doc, f)), closed: true))
          m.transformPoint(q),
      ],
  ];
}

/// [h]'s polyline children that no fill names (a wall's centreline
/// pieces), ascending, as their stored handles.
List<Handle> centrelineHandles(DraftDocument doc, Handle h) {
  final boundaries = {for (final f in fillsOf(doc, h)) boundaryOf(doc, f)};
  return [
    for (final k in kids(doc, h))
      if (kindOf(doc, k) == EntityKind.polyline && !boundaries.contains(k)) k
  ];
}

/// [centrelineHandles]' points, read back to world.
List<List<Vector2>> worldCentrelines(DraftDocument doc, Handle h) {
  final m = doc.tree.accumulatedTransform(h);
  return [
    for (final k in centrelineHandles(doc, h))
      [for (final q in pointsOf(payloadOf(doc, k))) m.transformPoint(q)],
  ];
}

/// Whether every region of [h] has a non-empty stored triangulation:
/// every stored piece triangulates (spec 08 D9, 07 D6).
bool storedPiecesTriangulate(DraftDocument doc, Handle h) =>
    fillsOf(doc, h).every(
        (f) => doc.fills.trianglesFor(boundaryOf(doc, f))?.isNotEmpty ?? false);

/// Whether every region of [h] is stored simple and anticlockwise, in its
/// own stored (group-local) coordinates: 07 D6's invariant, per piece (spec
/// 08 D9). A triangulation alone accepts a clockwise ring.
bool storedPiecesSimpleCcw(DraftDocument doc, Handle h) =>
    fillsOf(doc, h).every((f) => isSimpleCcw(
        pointsOf(payloadOf(doc, boundaryOf(doc, f)), closed: true)));

/// The world rectangle of wall [h] between `u = a` and `u = b`, face to
/// face, by [oracleFrameOf].
List<Vector2> gapRect(DraftDocument doc, Handle h, double a, double b) {
  final f = oracleFrameOf(doc, h);
  return [
    oracleAt(f, a, f.ro),
    oracleAt(f, b, f.ro),
    oracleAt(f, b, f.lo),
    oracleAt(f, a, f.lo),
  ];
}

/// A twin of [doc] with every opening deleted: saved, reloaded, then every
/// opening removed in one edit, as the select tool removes a selection.
/// What 07 **stores** there is the uncut band, the differential oracle
/// (spike: "The oracle"). One edit, so no wall is ever regenerated with
/// only some of its openings.
DraftDocument uncutTwin(DraftDocument doc) {
  final twin = reload(enc(doc));
  final openings = twin.components.withComponent<OpeningParams>().toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  if (openings.isNotEmpty) {
    twin.commands.execute(CompoundCommand([
      for (final o in openings) ...[
        for (final k in kids(twin, o))
          if (kindOf(twin, k) != EntityKind.fill) RemoveEntityCommand(k),
        RemoveNodeCommand(o),
      ],
    ], label: 'Delete'));
  }
  return twin;
}

/// Wall [h]'s uncut world outline, from [uncutTwin].
List<Vector2> uncutOutline(DraftDocument doc, Handle h) =>
    worldOutline(uncutTwin(doc), h);

/// The tiling oracle: [count] points uniform in the bounding box of
/// [original] grown by 50 mm. Every point inside [original] must be in
/// exactly one piece xor in some gap rectangle; no point outside it may be
/// in a piece or a gap; no point is in two pieces. The violations by kind.
Map<String, int> tiling(List<Vector2> original, List<List<Vector2>> pieces,
    List<List<Vector2>> gaps,
    {int count = 20000, int seed = 11}) {
  final box = Aabb2.fromPoints(original).expandedBy(50);
  final rnd = math.Random(seed);
  final out = <String, int>{
    'overlap': 0,
    'hole': 0,
    'pieceInGap': 0,
    'pieceOutside': 0,
    'gapOutside': 0,
  };
  for (var i = 0; i < count; i++) {
    final p = Vector2(box.minX + rnd.nextDouble() * (box.maxX - box.minX),
        box.minY + rnd.nextDouble() * (box.maxY - box.minY));
    final inside = insideRing(p, original);
    final k = pieces.where((r) => insideRing(p, r)).length;
    final g = gaps.any((r) => insideRing(p, r));
    if (k > 1) out['overlap'] = out['overlap']! + 1;
    if (inside && !g && k == 0) out['hole'] = out['hole']! + 1;
    if (g && k > 0) out['pieceInGap'] = out['pieceInGap']! + 1;
    if (!inside && k > 0) out['pieceOutside'] = out['pieceOutside']! + 1;
    if (!inside && g) out['gapOutside'] = out['gapOutside']! + 1;
  }
  return out;
}

/// The total of [tiling]'s counters.
int violations(Map<String, int> m) => m.values.fold(0, (a, b) => a + b);

/// The oracle's cut of one opening: `[a, b]` along its host's centreline,
/// and whether the clamp moved it.
typedef OracleCut = ({double a, double b, bool clamped});

/// The independent oracles over one document (Ruling 08-9), built once
/// over its [uncutTwin]. Nothing here calls `opening_geometry.dart`: every
/// frame is [oracleFrameOf], every crossing [oracleMeet], and the span is
/// read off the twin's **stored** outline.
final class OpeningOracle {
  OpeningOracle(this.doc) : twin = uncutTwin(doc);

  final DraftDocument doc;
  final DraftDocument twin;

  static const double _tol = 1e-6;

  /// Wall [h]'s uncut world outline, as 07 stores it in [twin].
  List<Vector2> outline(Handle h) => worldOutline(twin, h);

  /// The `u` of every vertex of wall [h]'s start cap and of its end cap,
  /// read off its stored uncut outline. 07's ring is anticlockwise: the end
  /// cap (right face to left face), the left face back towards the start,
  /// the start cap (left face to right face), the right face forward to the
  /// end. The two face edges are the longest ring edges lying on each face
  /// line, running `−d` on the left and `+d` on the right; the start cap is
  /// every vertex from the left edge's end to the right edge's start, the
  /// end cap the rest.
  ({List<double> start, List<double> end}) capUs(Handle h) {
    final f = oracleFrameOf(doc, h);
    final ring = outline(h);
    final n = ring.length;
    double off(Vector2 q) => (q.x - f.s.x) * f.n.x + (q.y - f.s.y) * f.n.y;
    bool onFace(Vector2 q, double o) => (off(q) - o).abs() <= _tol;
    int? le, re;
    var leLen = 0.0, reLen = 0.0;
    for (var i = 0; i < n; i++) {
      final p = ring[i], q = ring[(i + 1) % n];
      final du = oracleU(f, q) - oracleU(f, p);
      if (onFace(p, f.lo) && onFace(q, f.lo) && -du > leLen) {
        le = i;
        leLen = -du;
      }
      if (onFace(p, f.ro) && onFace(q, f.ro) && du > reLen) {
        re = i;
        reLen = du;
      }
    }
    if (le == null || re == null) {
      throw StateError('wall ${h.toHex()}: no face edges in $ring');
    }
    final start = <double>[];
    for (var i = (le + 1) % n;; i = (i + 1) % n) {
      start.add(oracleU(f, ring[i]));
      if (i == re) break;
    }
    final end = <double>[];
    for (var i = (re + 1) % n;; i = (i + 1) % n) {
      end.add(oracleU(f, ring[i]));
      if (i == le) break;
    }
    return (start: start, end: end);
  }

  /// Wall [h]'s straight span `[uS, uE]`: its start cap's largest `u` and
  /// its end cap's smallest ([capUs]).
  (double, double) span(Handle h) {
    final caps = capUs(h);
    return (caps.start.reduce(math.max), caps.end.reduce(math.min));
  }

  /// The obstacles other walls make in wall [h]'s band (spec 08 D7, as
  /// amended by Task 3's review S1), each a `u`-interval, sorted by start:
  /// - **a T:** another wall's end within 1e-6 of [h]'s centreline, more
  ///   than 1e-6 from both of its ends: the `u`-range of
  ///   [oracleTeeFootprint], the stem's whole footprint in the band;
  /// - otherwise **an X:** the two centrelines cross more than 1e-6 inside
  ///   both: the `u`-range of the four [oracleCrossings].
  ///
  /// Walls parallel to [h] make none.
  List<(double, double)> obstacles(Handle h) =>
      [for (final (a, b, _) in obstacleWalls(h)) (a, b)];

  /// [obstacles], each with the wall that makes it.
  List<(double, double, Handle)> obstacleWalls(Handle h) {
    final f = oracleFrameOf(doc, h);
    final out = <(double, double, Handle)>[];
    for (final b in doc.components.withComponent<WallParams>()) {
      if (b == h) continue;
      final g = oracleFrameOf(doc, b);
      final cross = f.d.x * g.d.y - f.d.y * g.d.x;
      if (cross.abs() <= 1e-9) continue;
      var tee = false;
      for (final k in const [0, 1]) {
        final p = oracleEnd(g, k);
        final u = oracleU(f, p);
        final v = (p.x - f.s.x) * f.n.x + (p.y - f.s.y) * f.n.y;
        if (u > _tol && u < f.len - _tol && v.abs() <= _tol) {
          tee = true;
          final (a, c) = oracleRange(f, oracleTeeFootprint(f, g, k));
          out.add((a, c, b));
        }
      }
      if (tee) continue;
      final hit = oracleMeet(f.s, oracleEnd(f, 1), g.s, oracleEnd(g, 1));
      final uh = oracleU(f, hit), ub = oracleU(g, hit);
      if (uh > _tol && uh < f.len - _tol && ub > _tol && ub < g.len - _tol) {
        final (a, c) = oracleRange(f, oracleCrossings(f, g));
        out.add((a, c, b));
      }
    }
    return out..sort((x, y) => x.$1.compareTo(y.$1));
  }

  /// Wall [h]'s stretches: [span] minus the union of [obstacles], a
  /// stretch no longer than 1e-6 dropped.
  List<(double, double)> stretches(Handle h) {
    final (s, e) = span(h);
    final out = <(double, double)>[];
    var from = s;
    for (final (a, b) in obstacles(h)) {
      if (math.min(a, e) - from > _tol) out.add((from, math.min(a, e)));
      from = math.max(from, b);
    }
    if (e - from > _tol) out.add((from, e));
    return out;
  }

  /// Where opening [o] cuts (spec 08 D8), by an independent clamp: among
  /// the [stretches] of its host at least its width long, the one nearest
  /// its stored centre (ties to the lower start), the interval of its
  /// width clamped into it. Null when none holds it, or for a degenerate
  /// width or position.
  OracleCut? cut(OpeningParams o) {
    final c = o.position, w = o.width;
    if (!c.isFinite || !w.isFinite || !(w > _tol)) return null;
    (double, double)? best;
    var bestD = double.infinity;
    for (final (a, b) in stretches(o.host)) {
      if (w > b - a) continue;
      final dist = c < a ? a - c : (c > b ? c - b : 0.0);
      if (dist < bestD) {
        bestD = dist;
        best = (a, b);
      }
    }
    if (best == null) return null;
    final x = math.min(math.max(c - w / 2, best.$1), best.$2 - w);
    return (a: x, b: x + w, clamped: x != c - w / 2);
  }

  /// Wall [h]'s openings, ascending.
  List<Handle> openingsOn(Handle h) => [
        for (final o in doc.components.withComponent<OpeningParams>())
          if (doc.components.get<OpeningParams>(o)!.host == h) o
      ]..sort((x, y) => x.value.compareTo(y.value));

  /// [cuts] sorted by start and merged when one starts within 1e-6 of the
  /// previous one's end.
  static List<(double, double)> _merge(Iterable<(double, double)> cuts) {
    final sorted = [...cuts]..sort((x, y) => x.$1.compareTo(y.$1));
    final out = <(double, double)>[];
    for (final c in sorted) {
      if (out.isNotEmpty && c.$1 <= out.last.$2 + _tol) {
        out.last = (out.last.$1, math.max(out.last.$2, c.$2));
      } else {
        out.add(c);
      }
    }
    return out;
  }

  /// Wall [h]'s openings, ascending, each with the cut the wall draws for
  /// it: its [cut], then D8's "a wall keeps a piece" (as amended at
  /// execution and revised after Task 5's review): the fitting openings are
  /// admitted in ascending handle order, and one whose cut, merged with the
  /// admitted ones, would leave no piece longer than 1e-6 -- the start
  /// piece from the start cap's smallest `u` to the first gap, each middle
  /// piece between two gaps, the end piece from the last gap to the end
  /// cap's largest `u` -- is made no-fit (null) and left out.
  List<(Handle, OracleCut?)> cutsOn(Handle h) {
    final caps = capUs(h);
    final from = caps.start.reduce(math.min), to = caps.end.reduce(math.max);
    final admitted = <(double, double)>[];
    final out = <(Handle, OracleCut?)>[];
    for (final o in openingsOn(h)) {
      final c = cut(doc.components.get<OpeningParams>(o)!);
      if (c == null) {
        out.add((o, null));
        continue;
      }
      final merged = _merge([...admitted, (c.a, c.b)]);
      final ends = [
        from,
        for (final (a, b) in merged) ...[a, b],
        to
      ];
      var piece = false;
      for (var i = 0; i < ends.length; i += 2) {
        if (ends[i + 1] - ends[i] > _tol) piece = true;
      }
      if (piece) {
        admitted.add((c.a, c.b));
        out.add((o, c));
      } else {
        out.add((o, null));
      }
    }
    return out;
  }

  /// The walls D17's `opening.clamped` names for opening [o] (as amended
  /// after Task 5's review): those whose [obstacleWalls] interval overlaps
  /// its unclamped interval `[lo, hi]` exactly, ascending; and whether that
  /// interval leaves the [span] (a corner).
  ({List<Handle> walls, bool corner}) clampCause(OpeningParams o) {
    final lo = o.position - o.width / 2, hi = o.position + o.width / 2;
    final (s, e) = span(o.host);
    final walls = {
      for (final (a, b, w) in obstacleWalls(o.host))
        if (lo < b && a < hi) w
    }.toList()
      ..sort((x, y) => x.value.compareTo(y.value));
    return (walls: walls, corner: lo < s || hi > e);
  }

  /// Wall [h]'s gaps: the fitting cuts of [cutsOn], merged.
  List<(double, double)> gaps(Handle h) => _merge([
        for (final (_, c) in cutsOn(h))
          if (c != null) (c.a, c.b)
      ]);

  /// [tiling] of wall [h]'s stored pieces against its stored uncut band and
  /// its oracle [gaps].
  Map<String, int> tilingOf(Handle h) => tiling(outline(h), worldPieces(doc, h),
      [for (final (a, b) in gaps(h)) gapRect(doc, h, a, b)]);

  /// Where D10 and D11 draw opening [o]'s symbol, by [cutsOn]: its cut
  /// `[a, b]` when it fits, else its stored interval `[c − w/2, c + w/2]`;
  /// and whether it fits.
  ({double a, double b, bool fits}) drawn(Handle o) {
    final p = doc.components.get<OpeningParams>(o)!;
    for (final (h, c) in cutsOn(p.host)) {
      if (h == o && c != null) return (a: c.a, b: c.b, fits: true);
    }
    return (
      a: p.position - p.width / 2,
      b: p.position + p.width / 2,
      fits: false,
    );
  }

  /// Door [o]'s symbol in world (spec 08 D10): the hinge is the jamb corner
  /// on the swing side's face ([OracleFrame.lo] for `left`, `ro` for
  /// `right`) at the [drawn] interval's start (hinge `start`) or end; the
  /// leaf's tip is the width away from it along the normal, outwards: `+n`
  /// off the left face, `−n` off the right one; the shut jamb is the other
  /// end of the interval on the same face.
  ({Vector2 hinge, Vector2 tip, Vector2 shut}) door(Handle o) {
    final p = doc.components.get<OpeningParams>(o)!;
    final f = oracleFrameOf(doc, p.host);
    final at = drawn(o);
    final (uh, us) = p.hinge == HingeEnd.start ? (at.a, at.b) : (at.b, at.a);
    final left = p.swing == SwingSide.left;
    final face = left ? f.lo : f.ro;
    return (
      hinge: oracleAt(f, uh, face),
      tip: oracleAt(f, uh, left ? face + p.width : face - p.width),
      shut: oracleAt(f, us, face),
    );
  }

  /// Window [o]'s three lines or gap [o]'s one, in world, each as its two
  /// ends (spec 08 D10, D11), over the [drawn] interval, `t` the host's
  /// stored thickness:
  /// - a window: the left face, the midline and the right face; no-fit,
  ///   each moved `t` along `n`: offsets `lo + t`, `lo + t/2` and `lo`;
  /// - a gap: offset 0 (the centreline), no-fit `lo + t/2`, from `a + m`
  ///   to `b − m` with `m = min(t/4, w/4)`.
  List<(Vector2, Vector2)> lines(Handle o) {
    final p = doc.components.get<OpeningParams>(o)!;
    final f = oracleFrameOf(doc, p.host);
    final t = doc.components.get<WallParams>(p.host)!.thickness;
    final at = drawn(o);
    switch (p.kind) {
      case OpeningKind.window:
        final offsets = at.fits
            ? [f.lo, (f.lo + f.ro) / 2, f.ro]
            : [f.lo + t, f.lo + t / 2, f.lo];
        return [
          for (final off in offsets)
            (oracleAt(f, at.a, off), oracleAt(f, at.b, off)),
        ];
      case OpeningKind.gap:
        final m = math.min(t / 4, p.width / 4);
        final off = at.fits ? 0.0 : f.lo + t / 2;
        return [(oracleAt(f, at.a + m, off), oracleAt(f, at.b - m, off))];
      case OpeningKind.door:
        throw ArgumentError.value(o, 'o', 'a door: use door()');
    }
  }
}

/// Opening [h]'s door symbol, by [OpeningOracle.door]; by [oracle] when
/// given, which must be built over [doc] as it is now.
({Vector2 hinge, Vector2 tip, Vector2 shut}) doorOracle(
        DraftDocument doc, Handle h,
        {OpeningOracle? oracle}) =>
    (oracle ?? OpeningOracle(doc)).door(h);

/// [h]'s LINE children, ascending, each read back to world as its two ends.
List<(Vector2, Vector2)> worldLines(DraftDocument doc, Handle h) {
  final m = doc.tree.accumulatedTransform(h);
  return [
    for (final k in kids(doc, h))
      if (kindOf(doc, k) == EntityKind.line)
        (
          m.transformPoint(payloadOf(doc, k).pointAt(0)),
          m.transformPoint(payloadOf(doc, k).pointAt(1)),
        ),
  ];
}

/// An ARC read back to world: its centre and radius, the points at its
/// start angle, its end angle and mid-sweep, and its world sweep (negated
/// under a reflecting transform, as the engine's index reads it).
typedef WorldArc = ({
  Vector2 centre,
  double radius,
  Vector2 from,
  Vector2 to,
  Vector2 mid,
  double sweep,
});

/// [h]'s one ARC child, read back to world through its group's
/// accumulated transform.
WorldArc worldArc(DraftDocument doc, Handle h) {
  final m = doc.tree.accumulatedTransform(h);
  final k = [
    for (final k in kids(doc, h))
      if (kindOf(doc, k) == EntityKind.arc) k
  ].single;
  final p = payloadOf(doc, k);
  final c = p.pointAt(0);
  final r = p.scalars[0], start = p.scalars[1], sweep = p.scalars[2];
  Vector2 at(double a) =>
      m.transformPoint(Vector2(c.x + r * math.cos(a), c.y + r * math.sin(a)));
  final centre = m.transformPoint(c);
  final from = at(start);
  return (
    centre: centre,
    radius: (from - centre).length,
    from: from,
    to: at(start + sweep),
    mid: at(start + sweep / 2),
    sweep: m.determinant < 0 ? -sweep : sweep,
  );
}

/// Door [h]'s children are a LINE then an ARC, both ByLayer, and they lie
/// on [OpeningOracle.door], in world within 1e-6 (spec 08 D10): the leaf
/// from the hinge to the tip; the arc about the hinge, of radius the width,
/// sweeping +π/2 anticlockwise between the tip and the shut jamb, its
/// middle on their bisector. [oracle], when given, must be built over [doc]
/// as it is now.
void expectDoorOnOracle(DraftDocument doc, Handle h,
    {String? reason, OpeningOracle? oracle}) {
  final why = reason ?? 'door ${h.toHex()}';
  final ks = kids(doc, h);
  expect(
      [for (final k in ks) kindOf(doc, k)], [EntityKind.line, EntityKind.arc],
      reason: why);
  for (final k in ks) {
    expect(doc.entities.colorAt(doc.entities.slotOf(k)!), kByLayer,
        reason: '$why: ByLayer');
  }
  final want = doorOracle(doc, h, oracle: oracle);
  final w = doc.components.get<OpeningParams>(h)!.width;
  final (from, to) = worldLines(doc, h).single;
  expect((from - want.hinge).length, lessThan(1e-6), reason: '$why: hinge');
  expect((to - want.tip).length, lessThan(1e-6), reason: '$why: tip');
  final arc = worldArc(doc, h);
  expect((arc.centre - want.hinge).length, lessThan(1e-6),
      reason: '$why: arc centre');
  expect(arc.radius, closeTo(w, 1e-6), reason: '$why: arc radius');
  expect(arc.sweep, math.pi / 2, reason: '$why: +π/2, anticlockwise');
  final ends = [arc.from, arc.to];
  expect(
      ends.any((q) => (q - want.tip).length < 1e-6) &&
          ends.any((q) => (q - want.shut).length < 1e-6),
      isTrue,
      reason: '$why: the arc runs between the tip and the shut jamb');
  final bisector = ((want.tip - want.hinge).normalized() +
          (want.shut - want.hinge).normalized())
      .normalized();
  expect((arc.mid - (want.hinge + bisector * w)).length, lessThan(1e-6),
      reason: '$why: the arc is the quarter between them');
}

/// Window or gap [h]'s LINE children lie on [OpeningOracle.lines], in
/// order, in world within 1e-6, and are ByLayer. [oracle], when given, must
/// be built over [doc] as it is now.
void expectLinesOnOracle(DraftDocument doc, Handle h,
    {String? reason, OpeningOracle? oracle}) {
  final why = reason ?? 'opening ${h.toHex()}';
  final ks = kids(doc, h);
  expect([for (final k in ks) kindOf(doc, k)], everyElement(EntityKind.line),
      reason: why);
  for (final k in ks) {
    expect(doc.entities.colorAt(doc.entities.slotOf(k)!), kByLayer,
        reason: '$why: ByLayer');
  }
  final want = (oracle ?? OpeningOracle(doc)).lines(h);
  final got = worldLines(doc, h);
  expect(got, hasLength(want.length), reason: why);
  for (var i = 0; i < want.length; i++) {
    expect((got[i].$1 - want[i].$1).length, lessThan(1e-6),
        reason: '$why: line $i from');
    expect((got[i].$2 - want[i].$2).length, lessThan(1e-6),
        reason: '$why: line $i to');
  }
}

/// The distance from [p] to the segment [a]–[b].
double distToSegment(Vector2 p, Vector2 a, Vector2 b) {
  final d = b - a;
  final t = ((p - a).dot(d) / d.dot(d)).clamp(0.0, 1.0);
  return (p - (a + d * t)).length;
}

/// Whether [p] lies inside [ring] farther than 1e-6 from its edges: a point
/// on a face of the band is not strictly inside it.
bool strictlyInsideRing(Vector2 p, List<Vector2> ring) {
  if (!insideRing(p, ring)) return false;
  for (var i = 0; i < ring.length; i++) {
    if (distToSegment(p, ring[i], ring[(i + 1) % ring.length]) <= 1e-6) {
      return false;
    }
  }
  return true;
}

/// Opening [h]'s symbol sampled in world: 65 points along each LINE, and
/// along its ARC, if any, from its start angle to its end.
List<Vector2> symbolSamples(DraftDocument doc, Handle h) {
  final out = <Vector2>[
    for (final (a, b) in worldLines(doc, h))
      for (var i = 0; i <= 64; i++) a + (b - a) * (i / 64),
  ];
  if (kids(doc, h).any((k) => kindOf(doc, k) == EntityKind.arc)) {
    final arc = worldArc(doc, h);
    final a0 = math.atan2(arc.from.y - arc.centre.y, arc.from.x - arc.centre.x);
    for (var i = 0; i <= 64; i++) {
      final a = a0 + arc.sweep * i / 64;
      out.add(arc.centre + Vector2(math.cos(a), math.sin(a)) * arc.radius);
    }
  }
  return out;
}

/// Opening [h]'s symbol in world, as a flat list of numbers: each LINE's
/// ends, then its ARC's centre, radius, ends and sweep.
List<double> worldSymbol(DraftDocument doc, Handle h) => [
      for (final (a, b) in worldLines(doc, h)) ...[a.x, a.y, b.x, b.y],
      if (kids(doc, h).any((k) => kindOf(doc, k) == EntityKind.arc))
        ...() {
          final arc = worldArc(doc, h);
          return [
            arc.centre.x,
            arc.centre.y,
            arc.radius,
            arc.from.x,
            arc.from.y,
            arc.to.x,
            arc.to.y,
            arc.sweep,
          ];
        }(),
    ];

/// Wall [h]'s straight span, by [OpeningOracle.span].
(double, double) oracleSpan(DraftDocument doc, Handle h) =>
    OpeningOracle(doc).span(h);

/// Wall [h]'s obstacles, by [OpeningOracle.obstacles].
List<(double, double)> oracleObstacles(DraftDocument doc, Handle h) =>
    OpeningOracle(doc).obstacles(h);

/// Opening [h]'s cut, by [OpeningOracle.cut].
OracleCut? oracleCut(DraftDocument doc, Handle h) =>
    OpeningOracle(doc).cut(doc.components.get<OpeningParams>(h)!);
