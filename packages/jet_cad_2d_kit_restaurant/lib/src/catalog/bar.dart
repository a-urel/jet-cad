// Bar (ported from jet_cad_restaurant_symbols' bar.dart): the stool, the high
// tables, the counters, the back bar and the tap tower.
//
// Pure Dart: no Flutter, no dart:io.
import 'package:jet_cad_2d_kit/authoring.dart';

import 'units.dart';

/// The palette category of this file's symbols.
const String bar = 'Bar';

CatalogLine _line(double x1, double y1, double x2, double y2) =>
    CatalogLine((x1, y1), (x2, y2));

/// A high table: a round top of diameter [d] with [stools] stools around it.
CatalogSymbol _highTable(String key, String name, double d, int stools,
    {required List<String> tags}) {
  final r = d / 2;
  final o = r + 2 * stoolRadius - stoolTuck; // every stool's edge positive
  return CatalogSymbol(
    key: key,
    name: name,
    category: bar,
    tags: tags,
    unit: tableUnit(stools),
    base: (o, o),
    shapes: [
      CatalogCircle((o, o), r),
      CatalogCircle((o, o), r - 40),
      ...stoolsAround(o, o, r, stools),
    ],
  );
}

/// Bar, in palette order.
final List<CatalogSymbol> barCatalog = [
  CatalogSymbol(
    key: 'restaurant.bar.stool',
    name: 'Bar stool',
    category: bar,
    unit: tableUnit(1),
    tags: const ['stool', 'bar', 'seat'],
    base: (stoolRadius, stoolRadius),
    shapes: stoolAt(stoolRadius, stoolRadius),
  ),
  _highTable('restaurant.bar.table.high.two', 'High table, 2 stools', 600, 2,
      tags: const ['table', 'high', 'bar', 'two']),
  _highTable('restaurant.bar.table.high.four', 'High table, 4 stools', 700, 4,
      tags: const ['table', 'high', 'bar', 'four']),
  // A 2000 x 400 ledge with four stools along its front (below it).
  CatalogSymbol(
    key: 'restaurant.bar.table.ledge',
    name: 'Bar ledge, 4 stools',
    category: bar,
    unit: tableUnit(4),
    tags: const ['ledge', 'bar', 'table', 'four'],
    base: (1000, 2 * stoolRadius - stoolTuck + 200),
    shapes: [
      rect(0, 2 * stoolRadius - stoolTuck, 2000, 400),
      for (var i = 0; i < 4; i++) ...stoolAt(250.0 + 500 * i, stoolRadius),
    ],
  ),
  // A 3000 x 600 counter; the work line 250 in from its back (top) edge.
  CatalogSymbol(
    key: 'restaurant.bar.counter',
    name: 'Bar counter',
    category: bar,
    tags: const ['counter', 'bar'],
    base: (1500, 300),
    shapes: [rect(0, 0, 3000, 600), _line(0, 350, 3000, 350)],
  ),
  // An L counter: a 2400 leg along x and an 1800 leg along y, 600 deep.
  CatalogSymbol(
    key: 'restaurant.bar.counter.corner',
    name: 'Corner bar counter',
    category: bar,
    tags: const ['counter', 'bar', 'corner'],
    base: (1200, 900),
    shapes: [
      poly(const [
        (0, 0),
        (2400, 0),
        (2400, 600),
        (600, 600),
        (600, 1800),
        (0, 1800),
      ]),
      _line(350, 350, 2400, 350),
      _line(350, 350, 350, 1800),
    ],
  ),
  // A U counter, 4000 wide, its legs 2400 long, 600 deep, open at the
  // bottom.
  CatalogSymbol(
    key: 'restaurant.bar.counter.u',
    name: 'U bar counter',
    category: bar,
    tags: const ['counter', 'bar', 'island'],
    base: (2000, 1200),
    shapes: [
      poly(const [
        (0, 0),
        (600, 0),
        (600, 1800),
        (3400, 1800),
        (3400, 0),
        (4000, 0),
        (4000, 2400),
        (0, 2400),
      ]),
      _line(350, 0, 350, 2050),
      _line(350, 2050, 3650, 2050),
      _line(3650, 2050, 3650, 0),
    ],
  ),
  // A 3000 x 450 back bar with two shelf lines.
  CatalogSymbol(
    key: 'restaurant.bar.back',
    name: 'Back bar',
    category: bar,
    tags: const ['back bar', 'shelf', 'bar'],
    base: (1500, 225),
    shapes: [
      rect(0, 0, 3000, 450),
      _line(0, 150, 3000, 150),
      _line(0, 300, 3000, 300),
    ],
  ),
  // A 600 x 300 tap tower with five taps.
  CatalogSymbol(
    key: 'restaurant.bar.taps',
    name: 'Beer taps',
    category: bar,
    tags: const ['taps', 'beer', 'bar'],
    base: (300, 150),
    shapes: [
      rect(0, 0, 600, 300),
      for (var i = 0; i < 5; i++) CatalogCircle((100.0 + 100 * i, 150), 40),
    ],
  ),
];
