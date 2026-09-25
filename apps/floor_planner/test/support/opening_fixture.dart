// Oracles for openings (Ruling 08-9). Nothing here calls
// `opening_geometry.dart`: every frame, face and crossing is written out
// from the stored parameters and a transform, and face lines meet through
// `oracleMeet` (Cramer's rule on explicit coordinates).
//
// This first part is the pure level (Task 3): frames, faces, a point's `u`,
// the L's mitre corners, the T's butt and square end, and the X's face
// crossings. The document-level oracles (pieces, tiling, obstacles read
// from a twin document's stored outline) come with the cut (Task 4).
import 'dart:math' as math;

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
