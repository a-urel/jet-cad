// Geometry helpers for the restaurant catalog (spec 14 V-3, V-6): plain
// shapes in millimetres, in the symbol's own frame (x to the right, y up the
// plan). Every helper returns closed polylines, lines, circles or arcs only
// (spec 09 R-5): no text, no fill.
//
// No Flutter import: this file is Dart over the planner's symbol types.
import 'dart:math' as math;

import 'package:jet_cad_floor_plan/symbols.dart';

/// A chair's side, in millimetres (the dining sets' rule, spec 14 V-6).
const double chairSize = 450;

/// How deep a chair sits under its table's edge.
const double chairTuck = 100;

/// A bar stool's seat radius (Ø 380).
const double stoolRadius = 190;

/// How far a stool's seat reaches under its top's edge.
const double stoolTuck = 40;

/// The back line's distance in from a chair's outer edge.
const double _chairBack = 60;

/// A closed axis-aligned rectangle from ([x], [y]), [w] wide and [h] tall.
FurnitureShape rect(double x, double y, double w, double h) =>
    PolylineShape([(x, y), (x + w, y), (x + w, y + h), (x, y + h)],
        closed: true);

/// [rect] of a [w] x [h] outline at ([x], [y]), inset by [d] on every side.
FurnitureShape inset(double x, double y, double w, double h, double d) =>
    rect(x + d, y + d, w - 2 * d, h - 2 * d);

/// A closed polyline through [points].
FurnitureShape poly(List<(double, double)> points) =>
    PolylineShape(points, closed: true);

/// A chair facing a table: its seat (a closed 450 x 450 square) and its back
/// line, the seat's centre at ([cx], [cy]) and the table in direction
/// [facing] (radians, measured from +x) from it. The back line is 60 mm in
/// from the edge away from the table.
List<FurnitureShape> chairAt(double cx, double cy, double facing) {
  const h = chairSize / 2;
  // The chair's local frame: u towards the table, v across it.
  final ux = math.cos(facing), uy = math.sin(facing);
  final vx = -uy, vy = ux;
  (double, double) at(double u, double v) =>
      (_clean(cx + u * ux + v * vx), _clean(cy + u * uy + v * vy));
  return [
    poly([at(-h, -h), at(h, -h), at(h, h), at(-h, h)]),
    LineShape(
      at(-h + _chairBack, -h).$1,
      at(-h + _chairBack, -h).$2,
      at(-h + _chairBack, h).$1,
      at(-h + _chairBack, h).$2,
    ),
  ];
}

/// [count] chairs around a round top of radius [r] centred at ([cx], [cy]),
/// at equal angles starting at the bottom (spec 14 V-6), each tucked
/// [chairTuck] under the edge.
List<FurnitureShape> chairsAround(double cx, double cy, double r, int count) {
  final d = r + chairSize / 2 - chairTuck;
  return [
    for (var i = 0; i < count; i++)
      ...() {
        final a = -math.pi / 2 + 2 * math.pi * i / count;
        return chairAt(_clean(cx + d * math.cos(a)),
            _clean(cy + d * math.sin(a)), a + math.pi);
      }(),
  ];
}

/// A bar stool at ([cx], [cy]): its seat (Ø 380) and a Ø 300 footrest ring.
List<FurnitureShape> stoolAt(double cx, double cy) => [
      CircleShape(cx, cy, stoolRadius),
      CircleShape(cx, cy, 150),
    ];

/// [count] stools around a round top of radius [r] centred at ([cx], [cy]),
/// at equal angles starting at the bottom, each reaching [stoolTuck] under
/// the edge.
List<FurnitureShape> stoolsAround(double cx, double cy, double r, int count) {
  final d = r + stoolRadius - stoolTuck;
  return [
    for (var i = 0; i < count; i++)
      ...stoolAt(
          _clean(cx + d * math.cos(-math.pi / 2 + 2 * math.pi * i / count)),
          _clean(cy + d * math.sin(-math.pi / 2 + 2 * math.pi * i / count))),
  ];
}

/// Rounds away the floating-point dust of a rotation (1e-13 off a whole
/// millimetre), so the library's coordinates are the round numbers the
/// geometry means. A sub-micrometre value is never meaningful in a symbol.
double _clean(double v) {
  final r = (v * 1e6).roundToDouble() / 1e6;
  return r == 0 ? 0 : r;
}
