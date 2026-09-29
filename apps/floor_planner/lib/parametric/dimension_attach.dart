// Which wall end point a dimension's end is (spec 11 D10): the attach
// candidates at a resolved point (through the index, with the opening hosts
// and the line test), and decision 19's choice among them, with decision
// 22's timing. No Flutter import: this file is Dart over `package:jet_cad_2d`
// and `vector_math` only, and imports only pure files (the plan's Ruling
// 11-2).
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'dimension_geometry.dart';
import 'opening.dart' show OpeningParams;
import 'opening_geometry.dart' show wallsInDocument;
import 'wall.dart';

/// How many walls have passed [attachCandidates]' line test, ever. For
/// tests only, which read the difference across a call (`TL8`: a hover
/// inside a wall's band passes none); a plain counter, as 10's
/// `debugTracedSegments` (the plan's Ruling 11-2).
int debugLineTestPasses = 0;

/// How many times [attachCandidates] computed a wall's six points (one
/// `wallsInDocument` and `wallEndPoints` each), ever. For tests only, which
/// read the difference across calls (`TL8`: with a memo, a wall's points
/// are computed once per generation); a plain counter, as
/// [debugLineTestPasses].
int debugWallPointComputations = 0;

/// A wall's six attach points, `(k, side, point)`, as [wallEndPoints] gives
/// them among every other live wall.
typedef WallPoints = List<(int, WallSide, Vector2)>;

/// `T` (spec 11 D10): the largest **world** thickness of a live wall of
/// [doc], each wall's stored thickness times its group's `scaleMagnitude`
/// (so a scaled group, file only, is covered); 0 with no live wall. One pass
/// over the walls. A live wall is a root-level group carrying `WallParams`
/// (the plan's Ruling 11-4).
double thickestWall(DraftDocument doc) {
  var t = 0.0;
  for (final h in doc.components.withComponent<WallParams>()) {
    if (!_isLiveGroup(doc, h)) continue;
    final w = doc.components.get<WallParams>(h)!.thickness *
        doc.tree.accumulatedTransform(h).scaleMagnitude;
    if (w > t) t = w;
  }
  return t;
}

/// The attach candidates at world point [q] (spec 11 D10, R-16; decision
/// 23; S-13): every `(W, k, side)` of a live wall `W` whose point
/// ([wallEndPoint], among every other live wall: `wallsInDocument`) lies
/// within `dimAttach.linear` of [q], Euclidean. Ascending by wall handle,
/// then `k`, then side (left, centre, right).
///
/// **Only while object snap (F3) is on**, and then **by position**
/// (decision 23): [objectSnap] false gives none, so every end is fixed;
/// otherwise any point attaches, whether an object snap or the grid put it
/// at [q]. The tool and the grips see only the resolved point, so they
/// behave the same.
///
/// **The candidate walls** come from two rect queries on [index], with
/// `QueryFilter.rendering()`:
/// 1. every live wall that owns a child whose stored world box touches the
///    square `q ± dimAttach.linear`;
/// 2. the host (`OpeningParams.host`, when it is a live wall **the renderer
///    draws**) of every live opening that owns a child whose stored box
///    touches the square `q ± (dimAttach.linear + thickest)`, [thickest]
///    being `T` ([thickestWall]). The host is kept only when
///    `FilterEvaluator.acceptsNode(host, QueryFilter.rendering())` holds:
///    its group and every group above it visible, the visibility the first
///    query sees through each of a wall's own children. A wall group has
///    no layer of its own; its children are generated on layer 0, as the
///    opening's are, so a hidden layer 0 hides the opening from this query
///    too. So a hidden wall attaches through neither query (only a file
///    makes one: no command hides a group). One check per host found, its
///    answer cached per group within the call.
///
/// **Why the hosts (S-13):** an opening flush with a flat wall end (a T
/// butt or a free end; `placeCut` clamps a door placed near a T to exactly
/// there) leaves none of that end's points stored: 08's `_pieces` keeps no
/// piece shorter than `wallJoin.linear`, so the end's ring and centreline
/// pieces are gone, and the wall's own children do not reach the corner.
/// **Why the box is grown by `T`:** an opening's children do not reach every
/// corner of its cut either. A door's leaf and arc stand on its swing face,
/// so only that face's jamb corner is inside the door's own box; the
/// centreline point and the other face's corner lie up to a wall thickness
/// away.
///
/// **The line test:** a candidate wall is kept only if [q] lies within
/// `dimAttach.linear` of one of its three lines, the left face line, the
/// centreline or the right face line ([_onALine]). **Every attach point
/// lies on one of these lines**: a mitre, T-butt, node or lobe corner is the
/// meeting of two face lines (a node's taken through its hub, within
/// `wallJoin.linear` of the wall's own), a clamped or squared cap and the
/// free rectangle lie on the face lines, and the centre point on the
/// centreline. So the test loses none, and a point in a wall's band off
/// those lines builds no `WorldWall`. Only a wall that passes is laid out
/// (`wallsInDocument`, then its six points).
///
/// **[points]**, when given, memoises each wall's six points: a wall found
/// in it is not laid out again, and one laid out is stored in it. The
/// result is the same, bit for bit, since the points are the same
/// computation's. Its owner (the Dimension tool's hover memo) clears it
/// whenever the document may have changed; a click, a commit and a grip
/// drop pass none, and gather afresh (the plan's Ruling 11-8).
List<AttachedEnd> attachCandidates(
    DraftDocument doc, SpatialIndex index, Vector2 q,
    {required bool objectSnap,
    required double thickest,
    Map<Handle, WallPoints>? points}) {
  if (!objectSnap) return const [];
  final walls = <Handle>{};
  final tight = dimAttach.linear;
  index.forEachInRect(
      Aabb2.raw(q.x - tight, q.y - tight, q.x + tight, q.y + tight),
      const QueryFilter.rendering(), (slot) {
    final owner = doc.entities.ownerAt(slot);
    if (_isLiveWall(doc, owner)) walls.add(owner);
  });
  final grown = dimAttach.linear + thickest;
  FilterEvaluator? drawn;
  index.forEachInRect(
      Aabb2.raw(q.x - grown, q.y - grown, q.x + grown, q.y + grown),
      const QueryFilter.rendering(), (slot) {
    final owner = doc.entities.ownerAt(slot);
    if (!_isLiveGroup(doc, owner)) return;
    final host = doc.components.get<OpeningParams>(owner)?.host;
    if (host == null || !_isLiveWall(doc, host)) return;
    // Only a host the renderer draws (D10: what is drawn attaches): the
    // opening's children passed `rendering()`, its host's group must too.
    drawn ??= FilterEvaluator(doc);
    if (drawn!.acceptsNode(host, const QueryFilter.rendering())) {
      walls.add(host);
    }
  });
  final out = <AttachedEnd>[];
  for (final h in walls.toList()..sort((a, b) => a.value.compareTo(b.value))) {
    if (!_onALine(doc, h, q)) continue;
    debugLineTestPasses++;
    final six = points == null
        ? _wallPointsOf(doc, h)
        : (points[h] ??= _wallPointsOf(doc, h));
    for (final (k, side, p) in six) {
      if ((p - q).length <= dimAttach.linear) out.add(AttachedEnd(h, k, side));
    }
  }
  return out;
}

/// Live wall [h]'s six points among every other live wall of [doc].
WallPoints _wallPointsOf(DraftDocument doc, Handle h) {
  debugWallPointComputations++;
  final ws = wallsInDocument(doc, h)!;
  return wallEndPoints(ws.host, ws.walls);
}

/// The line test (spec 11 D10): whether [q] lies within `dimAttach.linear`
/// of one of live wall [h]'s three lines. In world, with its world start
/// `s`, left normal `n` and face offsets `{lOff, 0, rOff}` (07 D2, as
/// `WorldWall.offsets`): `|(q − s) · n − o| ≤ dimAttach.linear`. For a wall
/// whose group is not a rigid motion (a scaled group, file only), also in
/// its local frame with `WallParams`' own points and offsets, where 07's
/// local-ring fallback stores the free rectangle (D4 step 2). A degenerate
/// wall (length ≤ `wallJoin.linear`: no direction) passes when [q] lies
/// within `dimAttach.linear` of an endpoint. Reads `WallParams` and the
/// transform only: no payload, no `WorldWall`.
bool _onALine(DraftDocument doc, Handle h, Vector2 q) {
  final p = doc.components.get<WallParams>(h)!;
  final m = doc.tree.accumulatedTransform(h);
  final (lOff, rOff) = switch (p.justification) {
    Justification.centre => (p.thickness / 2, -p.thickness / 2),
    Justification.left => (p.thickness, 0.0),
    Justification.right => (0.0, -p.thickness),
  };
  if (_nearALine(
      q, m.transformPoint(p.start), m.transformPoint(p.end), lOff, rOff)) {
    return true;
  }
  if ((m.scaleMagnitude - 1).abs() > dimAttach.angular) {
    return _nearALine(m.invert().transformPoint(q), p.start, p.end, lOff, rOff);
  }
  return false;
}

/// Whether [q] lies within `dimAttach.linear` of the line at offset `lOff`,
/// 0 or `rOff` along the left normal of `s → e`, or, when `s → e` is no
/// longer than `wallJoin.linear`, of `s` or `e`.
bool _nearALine(Vector2 q, Vector2 s, Vector2 e, double lOff, double rOff) {
  final tol = dimAttach.linear;
  final dx = e.x - s.x, dy = e.y - s.y;
  final len = e.distanceTo(s);
  if (!(len > wallJoin.linear)) {
    return q.distanceTo(s) <= tol || q.distanceTo(e) <= tol;
  }
  final o = ((q.x - s.x) * -dy + (q.y - s.y) * dx) / len;
  return (o - lOff).abs() <= tol || o.abs() <= tol || (o - rOff).abs() <= tol;
}

/// Whether [h] is a live object of [doc]: its node is a root-level group
/// (`opening_geometry.dart`'s `_isLiveGroup`, the engine's survey).
bool _isLiveGroup(DraftDocument doc, Handle h) {
  final node = doc.tree[h];
  return node is GroupNode && node.parent == doc.tree.root;
}

/// Whether [h] is a live wall of [doc]: a root-level group carrying
/// `WallParams`.
bool _isLiveWall(DraftDocument doc, Handle h) =>
    doc.components.get<WallParams>(h) != null && _isLiveGroup(doc, h);

/// The end a dimension stores for a point whose attach [candidates] are
/// given (spec 11 D10's "The choice among candidates", R-17; decisions 19
/// and 22), or null when there are none (the end is fixed).
///
/// [at] is the world point being decided, [other] the dimension's other end's
/// world point, [kind] the kind being committed and [m] the dimension group's
/// local-to-world transform. The measuring direction is
/// `u = measuringDirection(kind, at, other, m)` (D6): for aligned the pair's
/// direction, for horizontal and vertical the group's local x or y in world.
///
/// 1. **The parallel measure:** for each candidate wall `W`, with world unit
///    direction `d_W` (its start to its end, read through [doc]),
///    `σ_W = |u × d_W|`, the sine of the angle between the wall and `u`. A
///    degenerate wall (length ≤ `wallJoin.linear`) has no direction and
///    takes `σ_W = 1`, the least parallel.
/// 2. **The most parallel:** keep the candidates with
///    `σ_W ≤ min σ + dimAttach.angular`: a band around the minimum, so the
///    order is total (two walls meeting end to end in line are both kept).
/// 3. **The lowest wall handle.**
/// 4. **Face before centre**, then the lower `k`, then left before right.
///    Within one wall only coincident points reach this step: a
///    left-justified wall's right face is its centreline, so `(k, right)`
///    is stored over `(k, centre)`.
///
/// **When it is decided is the callers' (decision 22)**, never this
/// function's:
/// - the tool decides both ends **at the commit** (the third click), with
///   the committed kind, from candidates gathered against the document as it
///   is then;
/// - an end grip decides **the dropped end only, at the drop**, with the
///   dimension's current kind and, for aligned, the other end's current
///   world point; the other end keeps its stored reference;
/// - **never** a kind switch, a wall edit or a move: a stored reference
///   changes only when a person re-picks that end.
///
/// Every candidate's wall is a wall of [doc] (the candidates are gathered
/// against it).
AttachedEnd? decideEnd(DraftDocument doc, List<AttachedEnd> candidates,
    {required DimKind kind,
    required Vector2 at,
    required Vector2 other,
    required Transform2 m}) {
  if (candidates.isEmpty) return null;
  final u = measuringDirection(kind, at, other, m);
  final sigma = <Handle, double>{};
  var least = double.infinity;
  for (final e in candidates) {
    final s = sigma[e.wall] ??= _parallelMeasure(doc, e.wall, u);
    if (s < least) least = s;
  }
  AttachedEnd? best;
  for (final e in candidates) {
    if (!(sigma[e.wall]! <= least + dimAttach.angular)) continue;
    if (best == null || _before(e, best)) best = e;
  }
  return best;
}

/// `σ_W = |u × d_W|` for wall [wall] of [doc]: 1 for a degenerate wall.
double _parallelMeasure(DraftDocument doc, Handle wall, Vector2 u) {
  final p = doc.components.get<WallParams>(wall)!;
  final toWorld = doc.tree.accumulatedTransform(wall);
  final d = toWorld.transformPoint(p.end) - toWorld.transformPoint(p.start);
  final len = d.length;
  if (!(len > wallJoin.linear)) return 1;
  final dw = d / len;
  return (u.x * dw.y - u.y * dw.x).abs();
}

/// Steps 3 and 4: whether [a] comes before [b]: the lower wall handle, then
/// a face point before a centre point, then the lower `k`, then left before
/// right.
bool _before(AttachedEnd a, AttachedEnd b) {
  final h = a.wall.value.compareTo(b.wall.value);
  if (h != 0) return h < 0;
  final f = _centreRank(a.side).compareTo(_centreRank(b.side));
  if (f != 0) return f < 0;
  final k = a.k.compareTo(b.k);
  if (k != 0) return k < 0;
  return a.side.index < b.side.index;
}

int _centreRank(WallSide side) => side == WallSide.centre ? 1 : 0;
