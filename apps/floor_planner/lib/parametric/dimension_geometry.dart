// SPIKE 11 -- throwaway. Pure dimension geometry: a wall's six attach
// points (decision 4), the value format (decision 7), the readable text
// direction (decision 8) and a linear or aligned dimension's layout
// (decisions 2, 5, 6, 11). Dart over `package:jet_cad_2d` and `vector_math`
// only.
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'wall.dart';
import 'wall_geometry.dart';

/// Which of a wall end's three points (decision 4): the left face, the
/// centreline or the right face, looking from the wall's start to its end.
enum WallSide { left, centre, right }

/// Wall [w]'s point at end [k] on [side], among [others] (its wall
/// neighbours; [w] itself and degenerate walls are ignored, as in
/// `classify`):
///
/// - **centre**: the stored centreline end, `w.endpoint(k)`: the end of the
///   centreline polyline the wall generates, so what a snap finds. At an L it
///   is the node point, at a T butt the stem's end on the through wall's
///   centreline (inside the through wall's band).
/// - **left / right**: the cleaned-up corner, that is, the first or last
///   point of 07's cap at that end ([capsOf], which already takes 07's
///   short-wall fallback). A cap runs from the end's *outgoing*-left face to
///   its outgoing-right face; at the start (k = 0) outgoing-left is the
///   wall's left, at the end (k = 1) it is the wall's right. So the wall's
///   left point is `startCap.first` or `endCap.last`, its right point
///   `startCap.last` or `endCap.first`. A node owner's cap walks its lobe,
///   but its first and last points are still its own left and right
///   corners.
/// - A degenerate wall (07 D2) has no outline: every side is its centreline
///   end.
Vector2 wallEndPoint(
    WorldWall w, List<WorldWall> others, int k, WallSide side) {
  if (side == WallSide.centre || w.degenerate) return w.endpoint(k);
  final caps = capsOf(w, others)!;
  final c = k == 0 ? caps.startCap : caps.endCap;
  final outgoingLeft = (k == 0) == (side == WallSide.left);
  return outgoingLeft ? c.first : c.last;
}

/// All six of [w]'s points, in (k, side) order: k = 0 then 1; left, centre,
/// right.
List<(int, WallSide, Vector2)> wallEndPoints(
        WorldWall w, List<WorldWall> others) =>
    [
      for (final k in const [0, 1])
        for (final side in WallSide.values)
          (k, side, wallEndPoint(w, others, k, side)),
    ];

// ---------------------------------------------------------------------------
// Decision 7: the value's format, round-half-up at the unit's precision.

/// A measured value within this many mm of a rounding boundary (a half
/// quantum) is on it and rounds up (M-11e). One `wallJoin.linear`: a length
/// meant to end on a half (3450.5 mm; 3/16" = 4.7625 mm) arrives as a
/// computed double a few ulps off it, and below it for about half of them.
const double kHalfTolerance = 1e-6;

/// [mm] in whole quanta of [quantumMm], half-up: a value within
/// [kHalfTolerance] of `(n + 0.5) · quantum` rounds to `n + 1`.
int roundHalfUp(double mm, double quantumMm) {
  final q = mm / quantumMm;
  final n = q.floorToDouble();
  if ((mm - (n + 0.5) * quantumMm).abs() <= kHalfTolerance) {
    return n.toInt() + 1;
  }
  return q.round();
}

/// The naive rule the spike compares against: convert to the unit, scale to
/// the precision, `round()`.
int naiveRound(double mm, double unitMm, int perUnit) =>
    (mm / unitMm * perUnit).round();

/// Decision 7's text for a length of [mm] in [unit]: mm to 1 (`3450`); cm
/// to 0.1 (`345.0`: the spike keeps the trailing zero); m to 0.01
/// (`3.45`); inches to 1/8 (`136 3/8`, no unit mark); feet-inches to the
/// nearest 1/4 (`11'-4 1/4"`: the marks are the notation). Fractions are
/// reduced. A negative length is formatted by its magnitude.
String formatDimension(double mm, DisplayUnit unit) {
  final v = mm.abs();
  switch (unit) {
    case DisplayUnit.millimeters:
      return '${roundHalfUp(v, 1)}';
    case DisplayUnit.centimeters:
      final n = roundHalfUp(v, 1);
      return '${n ~/ 10}.${n % 10}';
    case DisplayUnit.meters:
      final n = roundHalfUp(v, 10);
      return '${n ~/ 100}.${(n % 100).toString().padLeft(2, '0')}';
    case DisplayUnit.inches:
      final n = roundHalfUp(v, 25.4 / 8);
      return '${n ~/ 8}${_fraction(n % 8, 8)}';
    case DisplayUnit.feetInches:
      final n = roundHalfUp(v, 25.4 / 4);
      final feet = n ~/ 48, rest = n % 48;
      return "$feet'-${rest ~/ 4}${_fraction(rest % 4, 4)}\"";
  }
}

String _fraction(int num, int den) {
  if (num == 0) return '';
  var n = num, d = den;
  while (n.isEven) {
    n ~/= 2;
    d ~/= 2;
  }
  return ' $n/$d';
}

// ---------------------------------------------------------------------------
// Decision 8: readable from the bottom or the right of the page.

/// Tolerance on "exactly vertical": `|u.x|` at or below this counts as zero.
const double kVerticalTolerance = 1e-9;

/// [u] (a unit direction, world) or its reverse, so text along it reads from
/// the bottom or the right of the page: the text angle lands in (-90°, 90°].
/// At exactly vertical, within [kVerticalTolerance], the text runs upwards
/// (+90°, read from the right).
Vector2 readable(Vector2 u) {
  if (u.x < -kVerticalTolerance ||
      (u.x.abs() <= kVerticalTolerance && u.y < 0)) {
    return -u;
  }
  return u;
}

// ---------------------------------------------------------------------------
// Decisions 2, 5, 6, 11: the layout.

/// Paper sizes, mm (decision 6), multiplied by the page's scale
/// denominator. Placeholders for the spec.
const double kDimTextPaperMm = 2.5;
const double kDimTextGapPaperMm = 1.0;
const double kDimSlashPaperMm = 3.0;
const double kDimExtGapPaperMm = 1.5;
const double kDimExtOvershootPaperMm = 2.0;
const double kDimOffsetPaperMm = 10.0;

/// What a dimension measures along.
enum DimKind { aligned, horizontal, vertical }

/// One dimension's world geometry.
typedef DimLayout = ({
  double value,
  Vector2 q0,
  Vector2 q1,
  (Vector2, Vector2) ext0,
  (Vector2, Vector2) ext1,
  (Vector2, Vector2) slash0,
  (Vector2, Vector2) slash1,
  Vector2 textAt,
  double textAngle,
  double textHeight,
});

/// The layout of a dimension measuring world [p0] to [p1].
///
/// - [axis]: the world unit direction a linear dimension measures along
///   (the group's local x or y taken to world); ignored for aligned, which
///   measures along `p1 − p0` (or [axis] when the two points coincide).
/// - [offset]: world mm, signed, from the **outermost** measured point on
///   the line's side (decision 11): `n = perp(u)` is the measuring
///   direction's left normal; `offset ≥ 0` puts the line `offset` beyond the
///   larger of the two points' `n` heights, `offset < 0` below the smaller.
///   So an extension line never runs back through the geometry, whichever
///   point a wall edit moves.
/// - [scale]: the page's scale denominator: every paper constant times it.
///
/// Computed relative to [p0] (the local frame), so a far origin costs no
/// precision beyond the points' own.
DimLayout layoutDimension(Vector2 p0, Vector2 p1, DimKind kind, Vector2 axis,
    double offset, double scale) {
  final d = p1 - p0;
  final len = d.length;
  final u = kind == DimKind.aligned && len > wallJoin.linear
      ? d / len
      : axis.normalized();
  final value = kind == DimKind.aligned ? len : d.dot(u).abs();
  final n = Vector2(-u.y, u.x);
  const s0 = 0.0;
  final s1 = d.dot(n);
  final c = offset >= 0 ? math.max(s0, s1) + offset : math.min(s0, s1) + offset;
  final side = offset >= 0 ? n : -n;
  // Relative to p0.
  final r0 = n * (c - s0);
  final r1 = d + n * (c - s1);
  final gap = kDimExtGapPaperMm * scale;
  final over = kDimExtOvershootPaperMm * scale;
  (Vector2, Vector2) ext(Vector2 from, double dist, Vector2 to) =>
      (from + side * math.min(gap, dist), to + side * over);
  final ur = readable(u);
  final nr = Vector2(-ur.y, ur.x);
  final t = (ur + nr).normalized() * (kDimSlashPaperMm * scale / 2);
  final mid = (r0 + r1) * 0.5;
  final textAt = mid + nr * (kDimTextGapPaperMm * scale);
  return (
    value: value,
    q0: p0 + r0,
    q1: p0 + r1,
    ext0: _abs(p0, ext(Vector2.zero(), (c - s0).abs(), r0)),
    ext1: _abs(p0, ext(d, (c - s1).abs(), r1)),
    slash0: (p0 + r0 - t, p0 + r0 + t),
    slash1: (p0 + r1 - t, p0 + r1 + t),
    textAt: p0 + textAt,
    textAngle: math.atan2(ur.y, ur.x),
    textHeight: kDimTextPaperMm * scale,
  );
}

(Vector2, Vector2) _abs(Vector2 o, (Vector2, Vector2) s) =>
    (o + s.$1, o + s.$2);
