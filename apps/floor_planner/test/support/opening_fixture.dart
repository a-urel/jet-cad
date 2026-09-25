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

  /// Wall [h]'s straight span `[uS, uE]`, read off its stored uncut outline.
  /// 07's ring is anticlockwise: the end cap (right face to left face), the
  /// left face back towards the start, the start cap (left face to right
  /// face), the right face forward to the end. The two face edges are the
  /// longest ring edges lying on each face line, running `−d` on the left
  /// and `+d` on the right; the start cap is every vertex from the left
  /// edge's end to the right edge's start, the end cap the rest. `uS` is the
  /// start cap's largest `u`, `uE` the end cap's smallest.
  (double, double) span(Handle h) {
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
    final startCap = <Vector2>[];
    for (var i = (le + 1) % n;; i = (i + 1) % n) {
      startCap.add(ring[i]);
      if (i == re) break;
    }
    final endCap = <Vector2>[];
    for (var i = (re + 1) % n;; i = (i + 1) % n) {
      endCap.add(ring[i]);
      if (i == le) break;
    }
    return (
      startCap.map((q) => oracleU(f, q)).reduce(math.max),
      endCap.map((q) => oracleU(f, q)).reduce(math.min),
    );
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
  List<(double, double)> obstacles(Handle h) {
    final f = oracleFrameOf(doc, h);
    final out = <(double, double)>[];
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
          out.add(oracleRange(f, oracleTeeFootprint(f, g, k)));
        }
      }
      if (tee) continue;
      final hit = oracleMeet(f.s, oracleEnd(f, 1), g.s, oracleEnd(g, 1));
      final uh = oracleU(f, hit), ub = oracleU(g, hit);
      if (uh > _tol && uh < f.len - _tol && ub > _tol && ub < g.len - _tol) {
        out.add(oracleRange(f, oracleCrossings(f, g)));
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

  /// Wall [h]'s gaps: its openings' [cut]s, sorted and merged when one
  /// starts within 1e-6 of the previous one's end.
  List<(double, double)> gaps(Handle h) {
    final cuts = [
      for (final o in openingsOn(h))
        if (cut(doc.components.get<OpeningParams>(o)!) case final c?) (c.a, c.b)
    ]..sort((x, y) => x.$1.compareTo(y.$1));
    final out = <(double, double)>[];
    for (final c in cuts) {
      if (out.isNotEmpty && c.$1 <= out.last.$2 + _tol) {
        out.last = (out.last.$1, math.max(out.last.$2, c.$2));
      } else {
        out.add(c);
      }
    }
    return out;
  }

  /// [tiling] of wall [h]'s stored pieces against its stored uncut band and
  /// its oracle [gaps].
  Map<String, int> tilingOf(Handle h) => tiling(outline(h), worldPieces(doc, h),
      [for (final (a, b) in gaps(h)) gapRect(doc, h, a, b)]);
}

/// Wall [h]'s straight span, by [OpeningOracle.span].
(double, double) oracleSpan(DraftDocument doc, Handle h) =>
    OpeningOracle(doc).span(h);

/// Wall [h]'s obstacles, by [OpeningOracle.obstacles].
List<(double, double)> oracleObstacles(DraftDocument doc, Handle h) =>
    OpeningOracle(doc).obstacles(h);

/// Opening [h]'s cut, by [OpeningOracle.cut].
OracleCut? oracleCut(DraftDocument doc, Handle h) =>
    OpeningOracle(doc).cut(doc.components.get<OpeningParams>(h)!);
