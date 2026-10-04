// Bar (spec 14 V-6): the stool and the high tables are servable (spec 14
// decision 4: a bar stool can be a "table"); the counters, the back bar and
// the tap tower are not.
import 'package:jet_cad_floor_plan/symbols.dart';

import 'shapes.dart';

/// The palette category of this file's symbols.
const String bar = 'Bar';

/// A high table: a round top of diameter [d] with [stools] stools around it.
FurnitureSymbol highTable(String key, String name, double d, int stools,
    {required List<String> tags}) {
  final r = d / 2;
  final o = r + 2 * stoolRadius - stoolTuck; // every stool's edge positive
  return FurnitureSymbol(
    key: key,
    name: name,
    category: bar,
    tags: tags,
    seats: stools,
    baseX: o,
    baseY: o,
    shapes: [
      CircleShape(o, o, r),
      CircleShape(o, o, r - 40),
      ...stoolsAround(o, o, r, stools),
    ],
  );
}

/// Bar, in palette order.
final List<FurnitureSymbol> barCatalog = [
  FurnitureSymbol(
    key: 'restaurant.bar.stool',
    name: 'Bar stool',
    category: bar,
    tags: const ['stool', 'bar', 'seat'],
    seats: 1,
    baseX: stoolRadius,
    baseY: stoolRadius,
    shapes: stoolAt(stoolRadius, stoolRadius),
  ),
  highTable('restaurant.bar.table.high.two', 'High table, 2 stools', 600, 2,
      tags: const ['table', 'high', 'bar', 'two']),
  highTable('restaurant.bar.table.high.four', 'High table, 4 stools', 700, 4,
      tags: const ['table', 'high', 'bar', 'four']),
  // A 2000 x 400 ledge with four stools along its front (below it).
  FurnitureSymbol(
    key: 'restaurant.bar.table.ledge',
    name: 'Bar ledge, 4 stools',
    category: bar,
    tags: const ['ledge', 'bar', 'table', 'four'],
    seats: 4,
    baseX: 1000,
    baseY: 2 * stoolRadius - stoolTuck + 200,
    shapes: [
      rect(0, 2 * stoolRadius - stoolTuck, 2000, 400),
      for (var i = 0; i < 4; i++) ...stoolAt(250.0 + 500 * i, stoolRadius),
    ],
  ),
  // A 3000 x 600 counter; the work line 250 in from its back (top) edge.
  FurnitureSymbol(
    key: 'restaurant.bar.counter',
    name: 'Bar counter',
    category: bar,
    tags: const ['counter', 'bar'],
    baseX: 1500,
    baseY: 300,
    shapes: [rect(0, 0, 3000, 600), const LineShape(0, 350, 3000, 350)],
  ),
  // An L counter: a 2400 leg along x and an 1800 leg along y, 600 deep.
  FurnitureSymbol(
    key: 'restaurant.bar.counter.corner',
    name: 'Corner bar counter',
    category: bar,
    tags: const ['counter', 'bar', 'corner'],
    baseX: 1200,
    baseY: 900,
    shapes: [
      poly(const [
        (0, 0),
        (2400, 0),
        (2400, 600),
        (600, 600),
        (600, 1800),
        (0, 1800),
      ]),
      const LineShape(350, 350, 2400, 350),
      const LineShape(350, 350, 350, 1800),
    ],
  ),
  // A U counter, 4000 wide, its legs 2400 long, 600 deep, open at the
  // bottom.
  FurnitureSymbol(
    key: 'restaurant.bar.counter.u',
    name: 'U bar counter',
    category: bar,
    tags: const ['counter', 'bar', 'island'],
    baseX: 2000,
    baseY: 1200,
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
      const LineShape(350, 0, 350, 2050),
      const LineShape(350, 2050, 3650, 2050),
      const LineShape(3650, 2050, 3650, 0),
    ],
  ),
  // A 3000 x 450 back bar with two shelf lines.
  FurnitureSymbol(
    key: 'restaurant.bar.back',
    name: 'Back bar',
    category: bar,
    tags: const ['back bar', 'shelf', 'bar'],
    baseX: 1500,
    baseY: 225,
    shapes: [
      rect(0, 0, 3000, 450),
      const LineShape(0, 150, 3000, 150),
      const LineShape(0, 300, 3000, 300),
    ],
  ),
  // A 600 x 300 tap tower with five taps.
  FurnitureSymbol(
    key: 'restaurant.bar.taps',
    name: 'Beer taps',
    category: bar,
    tags: const ['taps', 'beer', 'bar'],
    baseX: 300,
    baseY: 150,
    shapes: [
      rect(0, 0, 600, 300),
      for (var i = 0; i < 5; i++) CircleShape(100.0 + 100 * i, 150, 40),
    ],
  ),
];
