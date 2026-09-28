// Pure dimension geometry (spec 11 D1, D4; the plan's Ruling 11-2): the
// wall attach points and the dimension tolerances. Later tasks add the value
// types, the measuring direction, the layout and the value's format here.
// No Flutter import: this file is Dart over `package:jet_cad_2d` and
// `vector_math` only, and imports only pure files.
//
// Ported from the spike (`spike/11-dimensions`,
// `apps/floor_planner/lib/parametric/dimension_geometry.dart`), with the
// drawn caps ([drawnCapsOf], R-5) in place of the spike's `capsOf` alone.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'wall_geometry.dart';

/// Which of a wall end's three points (spec 11 D4, decision 4): the left
/// face, the centreline or the right face, looking from the wall's start to
/// its end.
enum WallSide { left, centre, right }

/// Every attach decision of a dimension (spec 11 D10): a candidate is a
/// wall end point within `linear` mm of the resolved point, Euclidean, and
/// decision 19's parallel band is `angular` wide. Absolute, in mm, like
/// `wallJoin`: the snapped point is the stored local ring mapped to world,
/// the attach point is computed in world, and they differ by rounding only,
/// worst 4.3e-7 mm at +1e9 mm turned 23° in own groups (the spike's `Q3a`).
/// Nothing a person draws is 1e-5 mm apart. Stored values are still
/// compared with exact `==`.
const Tolerance dimAttach = Tolerance(linear: 1e-5, angular: 1e-9);

/// Every rounding and reading decision of a dimension's value and text
/// (spec 11 D8, D9): a value within `linear` mm (one `wallJoin.linear`) of
/// a rounding half is on it and rounds up, and a unit direction whose
/// `|x|` is at most `angular` is vertical.
const Tolerance dimFormat = Tolerance(linear: 1e-6, angular: 1e-9);

/// Wall [w]'s point at end [k] (0 its start, 1 its end) on [side], among
/// [others], its wall neighbours ([w] itself and degenerate walls are
/// ignored, as in `classify`) (spec 11 D4):
///
/// - **centre**: the stored centreline end, `w.endpoint(k)` (R-4): the end
///   of the centreline polyline the wall generates, so what a snap finds. At
///   an L it is the node point; at a T butt the stem's end on the through
///   wall's centreline, inside the through wall's band.
/// - **left / right**: the first or last point of the wall's **drawn** cap
///   at that end ([drawnCapsOf], which takes 07's two fallbacks, R-5). A cap
///   runs from the end's *outgoing*-left face to its outgoing-right face,
///   looking out of the wall along the end's outgoing direction. At the
///   start (`k = 0`) that direction is the wall's own, so outgoing-left is
///   the wall's left; at the end (`k = 1`) it is reversed, so outgoing-left
///   is the wall's right. So the wall's left point is `startCap.first` or
///   `endCap.last`, and its right point `startCap.last` or `endCap.first`.
///   A node owner's cap walks its lobe, but its first and last points are
///   still its own corners.
/// - **A degenerate wall** (07 D2) has no outline: every side is its
///   centreline end.
Vector2 wallEndPoint(
    WorldWall w, List<WorldWall> others, int k, WallSide side) {
  if (side == WallSide.centre || w.degenerate) return w.endpoint(k);
  final caps = drawnCapsOf(w, others)!;
  final c = k == 0 ? caps.startCap : caps.endCap;
  final outgoingLeft = (k == 0) == (side == WallSide.left);
  return outgoingLeft ? c.first : c.last;
}

/// All six of [w]'s points (spec 11 D4), in `(k, side)` order: `k = 0`
/// then 1; left, centre, right.
List<(int, WallSide, Vector2)> wallEndPoints(
        WorldWall w, List<WorldWall> others) =>
    [
      for (final k in const [0, 1])
        for (final side in WallSide.values)
          (k, side, wallEndPoint(w, others, k, side)),
    ];
