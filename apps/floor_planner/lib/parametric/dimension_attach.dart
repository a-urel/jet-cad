// Which wall end point a dimension's end is (spec 11 D10): decision 19's
// choice among the candidates, with decision 22's timing. Task 4 adds the
// candidates themselves (through the index, with the opening hosts and the
// line test). No Flutter import: this file is Dart over `package:jet_cad_2d`
// and `vector_math` only, and imports only pure files (the plan's Ruling
// 11-2).
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'dimension_geometry.dart';
import 'wall.dart';

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
