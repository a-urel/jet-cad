// Pure dimension geometry (spec 11 D1, D2, D4, D6-D9; the plan's Ruling
// 11-2): the wall attach points, the dimension tolerances, the value types
// of a dimension's ends and kind with their JSON, the measuring direction,
// the placement function, the layout with its paper constants, and the
// value's format.
// No Flutter import: this file is Dart over `package:jet_cad_2d` and
// `vector_math` only, and imports only pure files.
//
// Ported from the spike (`spike/11-dimensions`,
// `apps/floor_planner/lib/parametric/dimension_geometry.dart`), with the
// drawn caps ([drawnCapsOf], R-5) in place of the spike's `capsOf` alone,
// and the layout's side read from the offset's sign bit (R-2), `h1 = 0` for
// aligned (D6) and the paper constants of R-10.
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'wall.dart' show wallJoin;
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

/// What a dimension measures along (spec 11 D6, decision 2): the true
/// distance between its two points, or their distance along its group's
/// local x (horizontal) or local y (vertical) (decision 17).
enum DimKind { aligned, horizontal, vertical }

/// One end of a dimension (spec 11 D2, decision 1): a wall end point it
/// follows, or a fixed point. Value-equal, exactly (stored values,
/// CLAUDE.md).
sealed class DimEnd {
  const DimEnd();

  /// An attached end is `{"wall": h, "k": k, "side": s}`, `h` the wall's
  /// handle as an int, `k` an int and `s` `"left"`, `"centre"` or
  /// `"right"`; a fixed end is `{"point": [x, y]}` (spec 11 D2).
  Map<String, Object?> toJson();

  /// Either shape of [toJson]. Throws on a missing key, a wall that is not
  /// a handle, or an unknown side name, as 07's justification does. Any
  /// `k` int is accepted, and any coordinate (R-3): a `k` outside {0, 1} or
  /// a non-finite coordinate is `dimension.broken` (D15), and generates
  /// nothing (D7).
  static DimEnd fromJson(Map<String, Object?> json) {
    if (json['point'] case final List<Object?> p) {
      return FixedEnd((p[0]! as num).toDouble(), (p[1]! as num).toDouble());
    }
    return AttachedEnd(Handle.fromJson(json['wall']), json['k']! as int,
        WallSide.values.byName(json['side']! as String));
  }
}

/// A wall end point (spec 11 D2, decision 4): wall [wall]'s end [k] (0 its
/// start, 1 its end) on [side], looking from the wall's start to its end.
/// It stores no coordinate: its point is read from the wall
/// ([wallEndPoint]), and the dimension group's transform never touches it
/// (decision 12).
final class AttachedEnd extends DimEnd {
  const AttachedEnd(this.wall, this.k, this.side);

  final Handle wall;
  final int k;
  final WallSide side;

  @override
  Map<String, Object?> toJson() =>
      {'wall': wall.toJson(), 'k': k, 'side': side.name};

  @override
  bool operator ==(Object other) =>
      other is AttachedEnd &&
      other.wall == wall &&
      other.k == k &&
      other.side == side;

  @override
  int get hashCode => Object.hash(wall, k, side);

  /// `1A/1/left`: the wall's handle in hex, the end, the side.
  @override
  String toString() => '${wall.toHex()}/$k/${side.name}';
}

/// A fixed point (spec 11 D2, R-1) in the dimension group's **local**
/// space, so it moves and rotates with the group (decision 12).
final class FixedEnd extends DimEnd {
  const FixedEnd(this.x, this.y);

  final double x, y;

  Vector2 get point => Vector2(x, y);

  @override
  Map<String, Object?> toJson() => {
        'point': [x, y],
      };

  /// Exact `==` on the coordinates (stored values, CLAUDE.md): `-0.0` and
  /// `0.0` are the same point, and a NaN coordinate equals nothing, itself
  /// included. Only a dimension's offset carries a side in its sign, and is
  /// compared with `compareTo` (`DimensionParams.==`, R-2).
  @override
  bool operator ==(Object other) =>
      other is FixedEnd && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  /// `(x, y)`.
  @override
  String toString() => '($x, $y)';
}

/// The measuring direction `u` (spec 11 D6), a world unit vector, of a
/// dimension of [kind] from world point [p0] to world point [p1] in a group
/// whose local-to-world transform is [m]:
///
/// - **aligned:** `(p1 − p0) / |p1 − p0|` when `|p1 − p0| >
///   wallJoin.linear`; otherwise [m]'s local x in world, normalised (R-8: a
///   degenerate aligned pair still lays out);
/// - **horizontal:** [m]'s local x in world, normalised;
/// - **vertical:** [m]'s local y in world, normalised.
///
/// Linear axes are the group's own (decision 17): world x and y while the
/// group is at the identity, turning with it under a rotation. The one
/// definition every caller uses (the plan's Ruling 11-3): the layout, the
/// placement function, and decision 19's choice (`decideEnd`).
Vector2 measuringDirection(DimKind kind, Vector2 p0, Vector2 p1, Transform2 m) {
  switch (kind) {
    case DimKind.aligned:
      final d = p1 - p0;
      final len = d.length;
      if (len > wallJoin.linear) return d / len;
      return m.transformDirection(Vector2(1, 0)).normalized();
    case DimKind.horizontal:
      return m.transformDirection(Vector2(1, 0)).normalized();
    case DimKind.vertical:
      return m.transformDirection(Vector2(0, 1)).normalized();
  }
}

/// The placement function (spec 11 D6, R-7): the offset, in the group's
/// local units, that puts a dimension of [kind] from world [p0] to world
/// [p1] in a group whose local-to-world transform is [m] through world point
/// [q]. With `u` = [measuringDirection], `n` its left normal, the heights
/// `h0 = 0` and `h1` (0 for aligned by definition, `(p1 − p0) · n` for a
/// linear kind), `hi`/`lo` their max and min, `hq = (q − p0) · n` and `s =
/// m.scaleMagnitude`:
///
/// 1. `hq ≥ hi`: `(hq − hi) / s`, from the upper extreme (`+0.0` on it);
/// 2. `hq ≤ lo`: `−((lo − hq) / s)`, from the lower one (`-0.0` on it);
/// 3. between (a linear kind only): the **nearer** extreme with a zero
///    offset, `+0.0` when `hi − hq ≤ hq − lo`, else `-0.0`.
///
/// The side is the result's sign bit (R-2), which [layoutDimension] reads.
/// The tool's third click and the offset grip both place the line with it
/// (the plan's Ruling 11-3).
double offsetFor(
    Vector2 q, Vector2 p0, Vector2 p1, DimKind kind, Transform2 m) {
  final u = measuringDirection(kind, p0, p1, m);
  final n = Vector2(-u.y, u.x);
  final h1 = kind == DimKind.aligned ? 0.0 : (p1 - p0).dot(n);
  final hi = math.max(0.0, h1), lo = math.min(0.0, h1);
  final hq = (q - p0).dot(n);
  final s = m.scaleMagnitude;
  if (hq >= hi) return (hq - hi) / s;
  if (hq <= lo) return -((lo - hq) / s);
  return hi - hq <= hq - lo ? 0.0 : -0.0;
}

/// [u] (a world unit direction) or its reverse, so text along it reads
/// from the bottom or the right of the page (spec 11 D8, R-11): reversed
/// when `u.x < −dimFormat.angular`, or when `|u.x| ≤ dimFormat.angular` and
/// `u.y < 0`. Text angles land in (−90°, 90°], and exactly vertical, within
/// the tolerance, reads upwards (+90°): a group turned −90° gives `u =
/// (6.1e-17, −1)`, which without it would read from the left.
Vector2 readable(Vector2 u) {
  if (u.x < -dimFormat.angular || (u.x.abs() <= dimFormat.angular && u.y < 0)) {
    return -u;
  }
  return u;
}

/// The text's cap height, paper mm (spec 11 D8, R-10).
const double kDimTextPaperMm = 2.5;

/// From the dimension line to the text's bottom, paper mm (D8, R-12).
const double kDimTextGapPaperMm = 1.0;

/// A slash's whole length, paper mm (D7).
const double kDimSlashPaperMm = 3.0;

/// `g`, from the measured point to the extension line's start, paper mm
/// (D7).
const double kDimExtGapPaperMm = 1.5;

/// `v`, the extension line past the dimension line, paper mm (D7).
const double kDimExtOvershootPaperMm = 2.0;

/// The five LINEs' lineweight, 0.25 mm (spec 11 D7, decision 20; R-31: it
/// survives the rasteriser at a display's device pixel ratio).
const int kDimLineweight = 25;

/// The value's justification: bottom-centre, so the text sits centred above
/// the dimension line (spec 11 D7, decision 8).
final int kDimTextAttrs =
    packTextAttrs(h: TextJustifyH.centre, v: TextJustifyV.bottom);

/// The largest value, mm, a dimension lays out (spec 11 D9, D15): 1e15 mm,
/// 1e9 km. Above it [layoutDimension] gives null and the dimension is
/// `dimension.broken`, as for a value that is not finite.
///
/// **Why 1e15.** [formatDimension] counts whole quanta in a double, then an
/// `int` ([roundHalfUp]). Below 2^50 mm (about 1.13e15) a double still
/// resolves 1/8 mm, so every quantum (1 mm the finest) and its half are
/// exact, and the count is right. From 2^52 mm (about 4.5e15) the spacing
/// is 1 mm, so `n + 0.5 == n` and every value reads as a half; from 2^63
/// quanta (about 9.2e18 mm) `toInt` saturates and the half's `+ 1` wraps,
/// so 1e19 prints `-9223372036854775808`. 1e15 is a round bound below the
/// first failure, and far beyond any plan: about 2.2e8 times the corpus far
/// origin (4.5e6 mm), and a million times only against the +1e9 mm
/// placement, which does not make a value large anyway (a value is a
/// length). Only a wall made absurdly thick (a panel-legal 1e20 mm) or a
/// file reaches it.
const double kDimMaxValueMm = 1e15;

/// One dimension's geometry in **world** (spec 11 D6-D8), from
/// [layoutDimension]:
///
/// - [value]: what it measures, never negative; [text], its format in the
///   page's unit with the page's decimal separator;
/// - [u], [n]: the measuring direction and its left normal;
/// - [q0], [q1]: the dimension line's ends;
/// - [ext0], [ext1]: the extension lines at `a` and `b`, (start, end);
/// - [slash0], [slash1]: the slashes about [q0] and [q1];
/// - [textAt], [textAngle] (radians), [textHeight]: the value's insertion
///   point, world angle and cap height.
typedef DimLayout = ({
  double value,
  Vector2 u,
  Vector2 n,
  Vector2 q0,
  Vector2 q1,
  (Vector2, Vector2) ext0,
  (Vector2, Vector2) ext1,
  (Vector2, Vector2) slash0,
  (Vector2, Vector2) slash1,
  Vector2 textAt,
  double textAngle,
  double textHeight,
  String text,
});

/// The layout of a dimension of [kind] from world [p0] to world [p1], in a
/// group whose local-to-world transform is [m], with [offset] its **stored
/// local** offset, on [page] (spec 11 D6-D8; the plan's Ruling 11-3: the
/// one layout every caller uses). All in world, computed relative to [p0]
/// (a far origin costs nothing beyond the points' own rounding):
///
/// - `u` = [measuringDirection], `n = (−u.y, u.x)`; the value is `|p1 − p0|`
///   for aligned and `|(p1 − p0) · u|` for a linear kind; `h0 = 0`, `h1 = 0`
///   for aligned by definition and `(p1 − p0) · n` for a linear kind;
/// - the line at height `c = hi + o` when [offset]'s sign bit is clear and
///   `lo + o` when it is set (R-2), `o = offset · m.scaleMagnitude`: from
///   the outermost measured point on the line's side (R-6); `Q0 = p0 + n (c
///   − h0)`, `Q1 = p1 + n (c − h1)`;
/// - each extension line from `P + σ n · min(g, |c − h|)` to `Q + σ n · v`,
///   `σ` −1 when the sign bit is set, else +1;
/// - each slash `Q ∓ t`, `t = normalize(ur + nr) · (slash / 2)`, `ur` =
///   [readable]`(u)`, `nr = (−ur.y, ur.x)`;
/// - the text at `(Q0 + Q1) / 2 + nr · gap`, at the world angle
///   `atan2(ur.y, ur.x)`.
///
/// Every paper constant is multiplied by `page.scaleDenominator` here, and
/// nowhere else.
///
/// **Null when the dimension cannot be laid out in finite numbers** (the one
/// guard every caller inherits, Ruling 11-3): when the value for [kind] is
/// not finite or is above [kDimMaxValueMm], or any point, the text's height
/// or its angle is not finite. The value is checked before it is formatted:
/// [formatDimension] formats only a finite value (a non-finite one throws
/// there) and misprints one above [kDimMaxValueMm]. This happens for:
///
/// - a non-finite end point (an attached wall's `1e999` from a file), or a
///   non-finite [offset];
/// - finite points so far apart that a length overflows: an aligned pair
///   beyond about 1.3e154 mm, where the distance's square does;
/// - a finite value above [kDimMaxValueMm] (an aligned pair across a wall
///   1e20 mm thick);
/// - a page so large that a paper constant overflows (1:1e308: the text's
///   height, 2.5 × 1e308, is not finite, though the value is 4000).
///
/// A linear kind whose component stays finite and small still lays out: a
/// horizontal dimension between two points 1.5e154 apart along its local y
/// measures 0 and draws. `generate` makes no child for null, and D15 reports
/// the dimension `dimension.broken` ("it cannot be laid out in finite
/// numbers"): a dimension either draws its six children or is broken, never
/// silently empty (D7).
DimLayout? layoutDimension(Vector2 p0, Vector2 p1, DimKind kind, Transform2 m,
    double offset, PageComponent page) {
  final d = p1 - p0;
  final u = measuringDirection(kind, p0, p1, m);
  final n = Vector2(-u.y, u.x);
  final value = kind == DimKind.aligned ? d.length : d.dot(u).abs();
  const h0 = 0.0;
  final h1 = kind == DimKind.aligned ? 0.0 : d.dot(n);
  final hi = math.max(h0, h1), lo = math.min(h0, h1);
  // The side is the sign bit (R-2): one read, for the line and for σ.
  final below = offset.isNegative;
  final c = (below ? lo : hi) + offset * m.scaleMagnitude;
  final sigma = below ? -1.0 : 1.0;

  final scale = page.scaleDenominator;
  final g = kDimExtGapPaperMm * scale;
  final v = kDimExtOvershootPaperMm * scale;

  // Relative to p0.
  final r0 = n * (c - h0);
  final r1 = d + n * (c - h1);
  (Vector2, Vector2) ext(Vector2 r, double h, Vector2 q) => (
        p0 + r + n * (sigma * math.min(g, (c - h).abs())),
        p0 + q + n * (sigma * v),
      );

  final ur = readable(u);
  final nr = Vector2(-ur.y, ur.x);
  final t = (ur + nr).normalized() * (kDimSlashPaperMm * scale / 2);
  final textAt = p0 + ((r0 + r1) * 0.5 + nr * (kDimTextGapPaperMm * scale));
  final q0 = p0 + r0, q1 = p0 + r1;
  final ext0 = ext(Vector2.zero(), h0, r0), ext1 = ext(d, h1, r1);
  final slash0 = (q0 - t, q0 + t), slash1 = (q1 - t, q1 + t);
  final textAngle = math.atan2(ur.y, ur.x);
  final textHeight = kDimTextPaperMm * scale;
  bool finite(Vector2 w) => w.x.isFinite && w.y.isFinite;
  if (!value.isFinite ||
      value > kDimMaxValueMm ||
      !textAngle.isFinite ||
      !textHeight.isFinite ||
      ![
        q0, q1, ext0.$1, ext0.$2, ext1.$1, ext1.$2, //
        slash0.$1, slash0.$2, slash1.$1, slash1.$2, textAt,
      ].every(finite)) {
    return null;
  }
  return (
    value: value,
    u: u,
    n: n,
    q0: q0,
    q1: q1,
    ext0: ext0,
    ext1: ext1,
    slash0: slash0,
    slash1: slash1,
    textAt: textAt,
    textAngle: textAngle,
    textHeight: textHeight,
    text: formatDimension(value, page.displayUnit,
        decimalSeparator: page.decimalSeparator),
  );
}

/// [mm] in whole quanta of [quantumMm], round-half-up, the half decided
/// robustly (spec 11 D9, R-13): with `x = mm / quantum` and `n = floor(x)`,
/// a value within [dimFormat]`.linear` mm of `(n + 0.5) · quantum` is on the
/// half and gives `n + 1`; any other value gives `round(x)`.
///
/// The half is decided in millimetres, the unit the geometry has. A length
/// meant to end on a half arrives as a computed double a few ulps off it,
/// below it about half the time, and an imperial half has no exact double
/// (3/16" is 4.762499999999999 mm), so neither the naive `round` nor exact
/// arithmetic on the stored double decides those halves as intended (the
/// spike's `Q5c`). The cost, recorded in D18 and pinned by `DF2`: a true
/// length within 1e-6 mm below a half prints rounded up (R-32).
int roundHalfUp(double mm, double quantumMm) {
  final x = mm / quantumMm;
  final n = x.floorToDouble();
  if ((mm - (n + 0.5) * quantumMm).abs() <= dimFormat.linear) {
    return n.toInt() + 1;
  }
  return x.round();
}

/// A dimension's text for a length of [mm] in the page's display [unit]
/// (spec 11 D9, decision 7): no unit symbol, the page's [decimalSeparator]
/// (spec Q0 T1; `.` in the examples below), no grouping, each unit at its
/// plan precision:
///
/// - **mm**, to 1 mm: the integer (`3450`);
/// - **cm**, to 0.1 cm: one decimal, **always** (`345.0`, R-14);
/// - **m**, to 0.01 m: two decimals, always (`3.45`, `14.00`);
/// - **inches**, to 1/8": whole inches then a reduced fraction, **no mark**
///   (`136 3/8`, `136`, `0 1/4`, R-15);
/// - **feet-inches**, to 1/4": `F'-I"` or `F'-I N/D"`, the fraction reduced
///   (`11'-4 1/4"`, `12'-0"`, `0'-0 1/2"`); the marks are the notation that
///   separates feet from inches, not a unit symbol (R-15).
///
/// The total is rounded ([roundHalfUp]) in quanta of the precision before
/// it is split into whole units and a fraction, so a carry reaches the next
/// unit: 143 7/8" is 575.5 quarters and prints `12'-0"`, never `11'-12"`.
/// The magnitude of [mm] is formatted. Only cm and m print a decimal
/// separator; mm prints an integer, inches and feet-inches fractions.
String formatDimension(double mm, DisplayUnit unit,
    {DecimalSeparator decimalSeparator = DecimalSeparator.point}) {
  final v = mm.abs();
  switch (unit) {
    case DisplayUnit.millimeters:
      return '${roundHalfUp(v, 1)}';
    case DisplayUnit.centimeters:
      final n = roundHalfUp(v, 1); // millimetres, tenths of a cm
      return '${n ~/ 10}${decimalSeparator.char}${n % 10}';
    case DisplayUnit.meters:
      final n = roundHalfUp(v, 10); // hundredths of a metre
      return '${n ~/ 100}${decimalSeparator.char}'
          '${(n % 100).toString().padLeft(2, '0')}';
    case DisplayUnit.inches:
      final n = roundHalfUp(v, 25.4 / 8); // eighths of an inch
      return '${n ~/ 8}${_fraction(n % 8, 8)}';
    case DisplayUnit.feetInches:
      final n = roundHalfUp(v, 25.4 / 4); // quarters of an inch
      final feet = n ~/ 48, rest = n % 48;
      return "$feet'-${rest ~/ 4}${_fraction(rest % 4, 4)}\"";
  }
}

/// ` N/D`, [num] / [den] reduced ([den] a power of two), or nothing for 0.
String _fraction(int num, int den) {
  if (num == 0) return '';
  var n = num, d = den;
  while (n.isEven) {
    n ~/= 2;
    d ~/= 2;
  }
  return ' $n/$d';
}
