// The wall faces a symbol stands against (spec 09c D3).
//
// No Flutter import and no `dart:ui` (spec D1, T-4; plan P-4): this file is
// Dart over `package:jet_cad_2d` and the app's parametric geometry. A
// Flutter-side predicate (`isUsableHost`, which lives in the
// Flutter-importing `opening_tool.dart`) is passed in as `accept`.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../parametric/opening_geometry.dart';
import '../parametric/wall.dart';
import '../parametric/wall_geometry.dart';

/// Which of a wall's two faces a run lies on: the wall's **frame's**
/// (local) sides ([HostFrame.n] is the left normal), not the world's. Under
/// a mirrored group the frame's left face is on the world's right.
enum FaceSide { left, right }

/// A straight piece of a wall face a symbol can stand against, in world
/// space (spec 09c D3).
///
/// - [m]: the unit normal pointing **out of the wall into the room** (away
///   from the wall's other face line);
/// - [t] `= (−m.y, m.x)`: the unit direction along the face, the right hand
///   of a person in the room facing the wall. Which of `±d` it is depends
///   on the group's mirror and is never assumed;
/// - [a]: the run's end with the smaller `(·)·t`; [length] (`L`) its length,
///   so the other end is `a + t·L`;
/// - [thickness] (`w`): the distance between the wall's two **drawn** face
///   lines;
/// - [wall], [side]: the wall and the frame's face the run lies on.
final class FaceRun {
  const FaceRun({
    required this.a,
    required this.t,
    required this.m,
    required this.length,
    required this.thickness,
    required this.wall,
    required this.side,
  });

  final Vector2 a, t, m;
  final double length, thickness;
  final Handle wall;
  final FaceSide side;

  @override
  String toString() => 'FaceRun(${wall.value} ${side.name} a: $a, t: $t, '
      'm: $m, L: $length, w: $thickness)';
}

/// The face runs of wall [wall] of [doc] (spec 09c D3) through the document
/// adapter ([wallsInDocument]: every other live wall can cut it). Empty when
/// [wall] is not a live wall, is degenerate, or [accept] refuses it (the
/// shell passes `isUsableHost`: a hidden or locked wall hosts nothing).
/// [accept] is asked only for a live wall.
List<FaceRun> faceRunsOf(DraftDocument doc, Handle wall,
    {bool Function(DraftDocument, Handle)? accept}) {
  final w = wallsInDocument(doc, wall);
  if (w == null) return const [];
  if (accept != null && !accept(doc, wall)) return const [];
  return faceRunsAmong(w.host, w.walls);
}

/// [host]'s face runs among [walls] (any walls; [host] itself, degenerate
/// walls and walls that do not touch it are ignored), spec 09c D3. The
/// left face's runs, then the right face's, each ascending along the
/// frame's direction. Empty for a degenerate host.
///
/// - **The face lines are the drawn ones** (S-2, T-3): in [host]'s
///   [HostFrame] the left face passes through `startCap.first` and
///   `endCap.last`, the right face through `startCap.last` and
///   `endCap.first`, each mapped to world through `host.toWorld`. A face's
///   direction is the frame's `d` through `toWorld.transformDirection`,
///   normalised (never the difference of its cap points); the line passes
///   through its start-cap point; its extent is the interval between the
///   projections of its two cap points. The frame's `lOff`/`rOff` are not
///   used (unscaled, they are off the drawn face under a scaled group).
/// - [FaceRun.m] is the normal pointing away from the other face line,
///   [FaceRun.thickness] `|(pLeft − pRight)·m|` for the start-cap points.
/// - **Cuts** from the walls [obstaclesOf] names (its intervals are not
///   used; `stretchesOf` never is): a **T** (an end of B strictly inside
///   [host]) cuts only the face it butts, the left one when
///   `toLocal.transformDirection(End(B, k).a) · frame.n > 0` (the host's
///   local frame, S-3); an **X** cuts each face. Each cut is the range, on
///   that face line, of the two points where B's two **drawn** face lines
///   (this rule applied to B's own frame, T-2) cross it, so an oblique X
///   cuts each face by its own interval (S-7). Pieces no longer than
///   `wallJoin.linear` are dropped. Openings do not cut.
List<FaceRun> faceRunsAmong(WorldWall host, List<WorldWall> walls) {
  if (host.degenerate) return const [];
  final frame = hostFrameOf(host, walls);
  if (frame == null) return const [];
  final f = _drawnFaces(host, frame);
  final d = f.d;
  final nd = Vector2(-d.y, d.x);
  final mLeft = (f.ls - f.rs).dot(nd) > 0 ? nd : -nd;
  final thickness = (f.ls - f.rs).dot(mLeft).abs();

  final leftCuts = <(double, double)>[], rightCuts = <(double, double)>[];
  final toLocal = host.toWorld.invert();
  final done = <int>{};
  for (final o in obstaclesOf(frame, host, walls)) {
    if (!done.add(o.wall.value)) continue;
    final b = walls.firstWhere((x) => x.handle == o.wall);
    final others = [
      host,
      for (final x in walls)
        if (x.handle != b.handle) x,
    ]..sort((x, y) => x.handle.value.compareTo(y.handle.value));
    final bFrame = hostFrameOf(b, others);
    if (bFrame == null) continue;
    final bf = _drawnFaces(b, bFrame);

    // The range along d, from [p0], of B's two drawn face lines' crossings
    // with the face line through [p0]; null when either is parallel.
    (double, double)? cutOn(Vector2 p0) {
      final q1 = intersect(p0, d, bf.ls, bf.d);
      final q2 = intersect(p0, d, bf.rs, bf.d);
      if (q1 == null || q2 == null) return null;
      final v1 = (q1 - p0).dot(d), v2 = (q2 - p0).dot(d);
      return v1 <= v2 ? (v1, v2) : (v2, v1);
    }

    var tee = false;
    for (final k in const [0, 1]) {
      if (!strictlyInside(b.endpoint(k), host)) continue;
      tee = true;
      final left = toLocal.transformDirection(End(b, k).a).dot(frame.n) > 0;
      final cut = cutOn(left ? f.ls : f.rs);
      if (cut != null) (left ? leftCuts : rightCuts).add(cut);
    }
    if (tee) continue;
    final l = cutOn(f.ls), r = cutOn(f.rs);
    if (l != null) leftCuts.add(l);
    if (r != null) rightCuts.add(r);
  }

  return [
    ..._pieces(f.ls, (f.le - f.ls).dot(d), d, mLeft, leftCuts, thickness,
        host.handle, FaceSide.left),
    ..._pieces(f.rs, (f.re - f.rs).dot(d), d, -mLeft, rightCuts, thickness,
        host.handle, FaceSide.right),
  ];
}

/// A wall's drawn face lines in world: the unit direction [d] (the frame's
/// `d` mapped and normalised) and the four drawn cap points, left start
/// and end, right start and end.
typedef _Faces = ({Vector2 d, Vector2 ls, Vector2 le, Vector2 rs, Vector2 re});

_Faces _drawnFaces(WorldWall w, HostFrame frame) {
  final g = w.toWorld;
  return (
    d: g.transformDirection(frame.d).normalized(),
    ls: g.transformPoint(frame.startCap.first),
    le: g.transformPoint(frame.endCap.last),
    rs: g.transformPoint(frame.startCap.last),
    re: g.transformPoint(frame.endCap.first),
  );
}

/// One face's runs: the face line through [p0] along [d], its extent from
/// `0` to [end] along [d], less [cuts] (ranges along [d] from [p0]),
/// ascending along [d]; a piece no longer than `wallJoin.linear` dropped.
List<FaceRun> _pieces(Vector2 p0, double end, Vector2 d, Vector2 m,
    List<(double, double)> cuts, double thickness, Handle wall, FaceSide side) {
  final t = Vector2(-m.y, m.x);
  final forward = t.dot(d) > 0;
  final out = <FaceRun>[];
  void add(double x, double y) {
    if (!(y - x > wallJoin.linear)) return;
    out.add(FaceRun(
      a: p0 + d * (forward ? x : y),
      t: t,
      m: m,
      length: y - x,
      thickness: thickness,
      wall: wall,
      side: side,
    ));
  }

  final hi = end > 0 ? end : 0.0;
  var from = end < 0 ? end : 0.0;
  final sorted = [...cuts]..sort((x, y) => x.$1.compareTo(y.$1));
  for (final (a, b) in sorted) {
    if (!(from < hi)) break;
    if (a > from) add(from, a < hi ? a : hi);
    if (b > from) from = b;
  }
  if (from < hi) add(from, hi);
  return out;
}
