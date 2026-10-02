// The wall faces a symbol stands against (spec 09c D3), the one attachment
// rule (D4) and the shell-owned cache of runs and neighbours (`WallFaces`).
//
// No Flutter import and no `dart:ui` (spec D1, T-4; plan P-4): this file is
// Dart over `package:jet_cad_2d` and the app's parametric geometry. A
// Flutter-side predicate (`isUsableHost`, which lives in the
// Flutter-importing `opening_tool.dart`) is passed in as `accept`.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../parametric/opening_geometry.dart';
import '../parametric/wall.dart';
import '../parametric/wall_bands.dart';
import '../parametric/wall_geometry.dart';
import 'symbol_box.dart';
import 'symbol_component.dart';
import 'symbol_placer.dart' show placementTransform;

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

/// A placed symbol standing against a run (spec 09c D4's neighbours): the
/// interval `[lo, hi]` its back edge covers along the run's `t`, measured
/// from the run's `a`, and the instance's handle (so a move can leave its
/// own instance out, D8).
typedef FaceNeighbour = ({double lo, double hi, Handle instance});

/// What [attachToWall] returns: the attached placement [transform], the
/// point [q] on the face the symbol's back-centre lands on (the snap
/// marker's, D6), and the [run] it stands against.
typedef WallAttachment = ({Transform2 transform, Vector2 q, FaceRun run});

/// The one attachment rule (spec 09c D4): where a symbol whose local box is
/// [box] stands against one of [runs] for the anchor point [p] (the raw
/// pointer in placement, D6; the plain-moved back-centre in a move, D8), or
/// null when no run takes it.
///
/// [neighbours] is parallel to [runs]: `neighbours[i]` are the symbols
/// already against `runs[i]` (an [ArgumentError] when the lengths differ);
/// the one whose instance is [exclude] is passed over.
///
/// 1. **The face.** A run is a candidate when `−w/2 ≤ s ≤ captureWorld`
///    and `−captureWorld ≤ u ≤ L + captureWorld`, `s = (p − a)·m`,
///    `u = (p − a)·t`: [p] in the room near the face, or in the wall's body
///    on this face's half of the band. The winner: the smallest `|s|`;
///    then the smallest distance from `u` to `[0, L]`; then the lower wall
///    handle; then the left face; then the lower `a·t`. The two distances
///    are compared within `wallJoin.linear` (two pieces of one face line
///    give the same `s` only within rounding).
/// 2. The winner must hold the symbol: `W ≤ L + wallJoin.linear`, else
///    null.
/// 3. The rotation takes local `+y` to `−m`: `(cos, sin) = (t.x, t.y)`
///    exactly, `-0.0` normalised (by [placementTransform], which cleans
///    every component it stores).
/// 4. The centre at `u`, then the **edge snap** within [edgeCaptureWorld]
///    that shifts `u` least (a tie to the smaller `u`): the left side
///    `u − W/2` to `0` or to a neighbour's `hi`, the right side `u + W/2`
///    to `L` or to a neighbour's `lo`. Then the **clamp** to
///    `[W/2, L − W/2]` when `W < L`, else `u = L/2`.
/// 5. `placementTransform(at: q, basePoint: c, rotation: (cos, sin),
///    mirrored)`, `q = a + u·t`, `c` the box's back-centre: the back edge
///    on the face line, the front in the room, a mirror pivoting about the
///    box's centre `x`.
///
/// O(runs + neighbours of the winner), allocating only the result (no
/// per-run allocation).
WallAttachment? attachToWall(
  List<FaceRun> runs,
  SymbolBox box,
  Vector2 p,
  double captureWorld, {
  required bool mirrored,
  required List<List<FaceNeighbour>> neighbours,
  required double edgeCaptureWorld,
  Handle? exclude,
}) {
  if (neighbours.length != runs.length) {
    throw ArgumentError.value(neighbours.length, 'neighbours',
        'must be parallel to runs (${runs.length})');
  }
  final tol = wallJoin.linear;
  var best = -1;
  var bestS = 0.0, bestGap = 0.0, bestU = 0.0;
  for (var i = 0; i < runs.length; i++) {
    final r = runs[i];
    final dx = p.x - r.a.x, dy = p.y - r.a.y;
    final s = dx * r.m.x + dy * r.m.y;
    if (s < -r.thickness / 2 || s > captureWorld) continue;
    final u = dx * r.t.x + dy * r.t.y;
    if (u < -captureWorld || u > r.length + captureWorld) continue;
    final absS = s.abs();
    final gap = u < 0 ? -u : (u > r.length ? u - r.length : 0.0);
    if (best >= 0 &&
        !_ranksBefore(r, absS, gap, runs[best], bestS, bestGap, tol)) {
      continue;
    }
    best = i;
    bestS = absS;
    bestGap = gap;
    bestU = u;
  }
  if (best < 0) return null;
  final run = runs[best];

  final width = box.right - box.left;
  final length = run.length;
  if (width > length + tol) return null;

  final half = width / 2;
  var u = bestU;
  var shift = 0.0;
  var snapped = false;
  void consider(double to) {
    final d = to - u;
    if (d.abs() > edgeCaptureWorld) return;
    if (!snapped ||
        d.abs() < shift.abs() ||
        (d.abs() == shift.abs() && d < shift)) {
      shift = d;
      snapped = true;
    }
  }

  // Each target is where the centre goes when that side meets it.
  consider(half);
  consider(length - half);
  for (final n in neighbours[best]) {
    if (exclude != null && n.instance == exclude) continue;
    consider(n.hi + half);
    consider(n.lo - half);
  }
  if (snapped) u += shift;
  if (width < length) {
    final lo = half, hi = length - half;
    u = u < lo ? lo : (u > hi ? hi : u);
  } else {
    u = length / 2;
  }

  final q = Vector2(run.a.x + run.t.x * u, run.a.y + run.t.y * u);
  return (
    transform: placementTransform(
      at: q,
      basePoint: Vector2((box.left + box.right) / 2, box.back),
      // Step 3: `(t.x, t.y)` exactly. `placementTransform` normalises
      // every `-0.0` it stores (D5), so a `-0.0` in `t` never reaches the
      // transform; normalising here as well would be dead code.
      rotation: (run.t.x, run.t.y),
      mirrored: mirrored,
    ),
    q: q,
    run: run,
  );
}

/// Whether run [r] (`|s|` [absS], distance [gap] from `u` to `[0, L]`)
/// ranks before [b] (`|s|` [bS], distance [bGap]) by D4 step 1's order.
bool _ranksBefore(FaceRun r, double absS, double gap, FaceRun b, double bS,
    double bGap, double tol) {
  if (absS < bS - tol) return true;
  if (absS > bS + tol) return false;
  if (gap < bGap - tol) return true;
  if (gap > bGap + tol) return false;
  if (r.wall.value != b.wall.value) return r.wall.value < b.wall.value;
  if (r.side != b.side) return r.side == FaceSide.left;
  return r.a.x * r.t.x + r.a.y * r.t.y < b.a.x * b.t.x + b.a.y * b.t.y;
}

/// Whether [g]'s linear part is orthonormal (spec 09c W-8, S-10):
/// `|a² + b² − 1|`, `|c² + d² − 1|` and `|ac + bd|` each at most
/// `Tolerance.standard.linear`. A mirror is orthonormal; a scale is not.
bool isOrthonormal(Transform2 g) {
  final tol = Tolerance.standard.linear;
  return (g.a * g.a + g.b * g.b - 1).abs() <= tol &&
      (g.c * g.c + g.d * g.d - 1).abs() <= tol &&
      (g.a * g.c + g.b * g.d).abs() <= tol;
}

/// The shell-owned cache of the face runs and their neighbours (spec 09c
/// D3, D4, S-8), shared by the placement tool (D6) and the move resolver
/// (D8).
///
/// Built from [bands]' live walls (`WallBands.liveWalls`, which keeps
/// [WallBands.generation] current), the host predicate [accept] (the shell
/// passes `isUsableHost`: a hidden or locked wall hosts nothing) and the
/// document. The runs, the neighbours and the boxes of the document's
/// definitions are rebuilt only when the document or the bands' generation
/// changes; a query over a cached set ([attach]) is O(runs) and allocates
/// O(1).
final class WallFaces {
  WallFaces(this.bands, {bool Function(DraftDocument, Handle)? accept})
      : _accept = accept;

  /// The shell's bands, shared with the Wall and Opening tools.
  final WallBands bands;
  final bool Function(DraftDocument, Handle)? _accept;

  DraftDocument? _document;
  int _generation = 0;
  List<FaceRun> _runs = const [];
  List<List<FaceNeighbour>> _neighbours = const [];
  final Map<Handle, SymbolBox?> _boxes = <Handle, SymbolBox?>{};
  int _builds = 0;

  /// How many times the runs and neighbours were rebuilt: once per
  /// document and bands generation, never per query.
  int get builds => _builds;

  /// The face runs of [doc]'s accepted live walls, ascending by wall handle
  /// (each wall's left face's runs, then its right face's).
  List<FaceRun> runsOf(DraftDocument doc) {
    _refresh(doc);
    return _runs;
  }

  /// Parallel to [runsOf]: the neighbours (spec D4) standing against each
  /// run.
  List<List<FaceNeighbour>> neighboursOf(DraftDocument doc) {
    _refresh(doc);
    return _neighbours;
  }

  /// The local box of [doc]'s definition [definition], memoised until the
  /// next rebuild (spec D2: per definition handle, cleared on a document
  /// change); null when it does not attach.
  SymbolBox? boxOf(DraftDocument doc, Handle definition) {
    _refresh(doc);
    return _box(doc, definition);
  }

  /// [attachToWall] over [doc]'s cached runs and neighbours, [exclude]
  /// (the instance a move carries, D8) not a neighbour.
  WallAttachment? attach(
    DraftDocument doc,
    SymbolBox box,
    Vector2 p,
    double captureWorld, {
    required bool mirrored,
    required double edgeCaptureWorld,
    Handle? exclude,
  }) {
    _refresh(doc);
    return attachToWall(_runs, box, p, captureWorld,
        mirrored: mirrored,
        neighbours: _neighbours,
        edgeCaptureWorld: edgeCaptureWorld,
        exclude: exclude);
  }

  SymbolBox? _box(DraftDocument doc, Handle definition) {
    if (_boxes.containsKey(definition)) return _boxes[definition];
    return _boxes[definition] = boxOfDefinition(doc, definition);
  }

  void _refresh(DraftDocument doc) {
    final walls = bands.liveWalls(doc);
    if (identical(doc, _document) && bands.generation == _generation) return;
    _document = doc;
    _generation = bands.generation;
    _builds++;
    _boxes.clear();
    final runs = <FaceRun>[
      for (final h in walls) ...faceRunsOf(doc, h, accept: _accept),
    ];
    _runs = List.unmodifiable(runs);
    _neighbours = _neighboursAlong(doc, runs);
  }

  /// Spec D4's neighbours of each of [runs]: the root-level instances on a
  /// visible, unlocked layer (the picking rule, [QueryFilter.picking])
  /// whose definition carries a [SymbolComponent] and has a box, whose
  /// transform is orthonormal, whose transformed back edge has both ends on
  /// the run's line (within `wallJoin.linear`) with the front on the room
  /// side, and whose interval along `t` overlaps `[0, L]`.
  List<List<FaceNeighbour>> _neighboursAlong(
      DraftDocument doc, List<FaceRun> runs) {
    final placed = <(Handle, Vector2, Vector2, Vector2)>[];
    final root = doc.tree[doc.tree.root];
    if (root is GroupNode) {
      final filter = FilterEvaluator(doc);
      for (final h in doc.tree.childNodesOf(root.children)) {
        final node = doc.tree[h];
        if (node is! InstanceNode) continue;
        if (doc.components.get<SymbolComponent>(node.definition) == null) {
          continue;
        }
        if (!filter.acceptsNode(h, const QueryFilter.picking())) continue;
        final box = _box(doc, node.definition);
        if (box == null) continue;
        final g = doc.tree.accumulatedTransform(h);
        if (!isOrthonormal(g)) continue;
        placed.add((
          h,
          g.transformPoint(Vector2(box.left, box.back)),
          g.transformPoint(Vector2(box.right, box.back)),
          g.transformPoint(Vector2((box.left + box.right) / 2, box.front)),
        ));
      }
    }
    final tol = wallJoin.linear;
    return List.unmodifiable([
      for (final r in runs)
        List<FaceNeighbour>.unmodifiable([
          for (final (h, e1, e2, front) in placed)
            if (((e1 - r.a).dot(r.m)).abs() <= tol &&
                ((e2 - r.a).dot(r.m)).abs() <= tol &&
                (front - r.a).dot(r.m) > 0)
              if (_interval((e1 - r.a).dot(r.t), (e2 - r.a).dot(r.t), h)
                  case final n when n.hi >= 0 && n.lo <= r.length)
                n,
        ]),
    ]);
  }

  static FaceNeighbour _interval(double u1, double u2, Handle h) =>
      u1 <= u2 ? (lo: u1, hi: u2, instance: h) : (lo: u2, hi: u1, instance: h);
}
