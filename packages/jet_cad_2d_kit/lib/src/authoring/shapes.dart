// The shared shape helpers (spec K6): the chair, chairs around a round top,
// the stool, rectangles, as today's furniture and restaurant catalogs copy
// them. Ported from jet_cad_restaurant_symbols' shapes.dart. A helper is a
// convenience for kit authors, not the runtime contract: changing one never
// changes a published key@N (K7 holds every kit to its committed geometry).
//
// Pure Dart: no Flutter, no dart:io.
import 'dart:math' as math;

import 'catalog.dart';

/// A chair's side, in millimetres.
const double chairSize = 450;

/// How deep a chair sits under its table's edge.
const double chairTuck = 100;

/// A bar stool's seat radius (Ø 380).
const double stoolRadius = 190;

/// How far a stool's seat reaches under its top's edge.
const double stoolTuck = 40;

/// The back line's distance in from a chair's outer edge.
const double _chairBack = 60;

/// A bar stool's footrest ring radius (Ø 300).
const double _footrestRadius = 150;

/// [v] rounded to 1e-6 mm, with -0 made 0: the dust of a rotation (1e-13
/// off a whole millimetre) never reaches a library. A sub-micrometre value
/// is never meaningful in a symbol.
double cleanCoordinate(double v) {
  final r = (v * 1e6).roundToDouble() / 1e6;
  return r == 0 ? 0 : r;
}

CatalogPoint _p(double x, double y) => (cleanCoordinate(x), cleanCoordinate(y));

/// A closed axis-aligned rectangle from ([x], [y]), [w] wide and [h] tall.
CatalogShape rect(double x, double y, double w, double h) =>
    CatalogPolyline([_p(x, y), _p(x + w, y), _p(x + w, y + h), _p(x, y + h)],
        closed: true);

/// [rect] of a [w] x [h] outline at ([x], [y]), inset by [d] on every side.
CatalogShape inset(double x, double y, double w, double h, double d) =>
    rect(x + d, y + d, w - 2 * d, h - 2 * d);

/// A closed polyline through [points].
CatalogShape poly(List<CatalogPoint> points) =>
    CatalogPolyline([for (final (x, y) in points) _p(x, y)], closed: true);

/// A chair facing a table: its seat (a closed 450 x 450 square) centred at
/// ([cx], [cy]) and its back line, the table in direction [facing] (radians
/// from +x). The back line is 60 in from the edge away from the table.
List<CatalogShape> chairAt(double cx, double cy, double facing) {
  const h = chairSize / 2;
  // The chair's frame: u towards the table, v across it.
  final ux = math.cos(facing), uy = math.sin(facing);
  final vx = -uy, vy = ux;
  CatalogPoint at(double u, double v) =>
      _p(cx + u * ux + v * vx, cy + u * uy + v * vy);
  return [
    poly([at(-h, -h), at(h, -h), at(h, h), at(-h, h)]),
    CatalogLine(at(-h + _chairBack, -h), at(-h + _chairBack, h)),
  ];
}

/// The angle of the [i]th of [count] places around a round top, the first
/// straight below it.
double _around(int i, int count) => -math.pi / 2 + 2 * math.pi * i / count;

/// [count] chairs around a round top of radius [r] centred at ([cx], [cy]),
/// at equal angles from the bottom, each tucked [chairTuck] under the edge.
List<CatalogShape> chairsAround(double cx, double cy, double r, int count) {
  final d = r + chairSize / 2 - chairTuck;
  return [
    for (var i = 0; i < count; i++)
      ...chairAt(
          cleanCoordinate(cx + d * math.cos(_around(i, count))),
          cleanCoordinate(cy + d * math.sin(_around(i, count))),
          _around(i, count) + math.pi),
  ];
}

/// A bar stool at ([cx], [cy]): its seat (Ø 380), then a Ø 300 footrest.
List<CatalogShape> stoolAt(double cx, double cy) => [
      CatalogCircle(_p(cx, cy), stoolRadius),
      CatalogCircle(_p(cx, cy), _footrestRadius),
    ];

/// [count] stools around a round top of radius [r] centred at ([cx], [cy]),
/// at equal angles from the bottom, each reaching [stoolTuck] under the edge.
List<CatalogShape> stoolsAround(double cx, double cy, double r, int count) {
  final d = r + stoolRadius - stoolTuck;
  return [
    for (var i = 0; i < count; i++)
      ...stoolAt(cx + d * math.cos(_around(i, count)),
          cy + d * math.sin(_around(i, count))),
  ];
}
