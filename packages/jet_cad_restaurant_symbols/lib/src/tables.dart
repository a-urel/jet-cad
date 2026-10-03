// Restaurant Tables (spec 14 V-6): rectangular and round tables with their
// chairs, every one servable. The first leaf is the table top, the second
// its 50 mm inset, then each chair's seat and back line.
import 'package:jet_cad_floor_plan/symbols.dart';

import 'shapes.dart';

/// The palette category of this file's symbols.
const String restaurantTables = 'Restaurant Tables';

/// A [w] x [h] table with [perSide] chairs on each long side (bottom and
/// top), spaced evenly, and one chair on each end when [ends]. The table's
/// lower-left corner sits far enough from the origin that every chair has
/// non-negative coordinates; the base point is the table's centre.
FurnitureSymbol rectTable(String key, String name, double w, double h,
    {required int perSide, required bool ends, required List<String> tags}) {
  const reach = chairSize - chairTuck; // 350 beyond the edge
  const c = chairSize / 2 - chairTuck; // a chair centre 125 beyond the edge
  final ox = ends ? reach : 0.0;
  const oy = reach;
  final step = w / perSide;
  return FurnitureSymbol(
    key: key,
    name: name,
    category: restaurantTables,
    tags: tags,
    seats: 2 * perSide + (ends ? 2 : 0),
    baseX: ox + w / 2,
    baseY: oy + h / 2,
    shapes: [
      rect(ox, oy, w, h),
      inset(ox, oy, w, h, 50),
      for (var i = 0; i < perSide; i++) ...[
        ...chairAt(ox + step * (i + 0.5), oy - c, _up),
        ...chairAt(ox + step * (i + 0.5), oy + h + c, _down),
      ],
      if (ends) ...[
        ...chairAt(ox - c, oy + h / 2, _right),
        ...chairAt(ox + w + c, oy + h / 2, _left),
      ],
    ],
  );
}

/// A round table of diameter [d] with [seats] chairs at equal angles from
/// the bottom. Centred so every chair has non-negative coordinates.
FurnitureSymbol roundTable(String key, String name, double d, int seats,
    {required List<String> tags}) {
  final r = d / 2;
  final c = r + chairSize - chairTuck; // the farthest reach of a chair
  // A chair's corner reaches past its centre line by up to half a diagonal;
  // a margin of a chair's side keeps every corner positive.
  final o = c + chairSize / 2;
  return FurnitureSymbol(
    key: key,
    name: name,
    category: restaurantTables,
    tags: tags,
    seats: seats,
    baseX: o,
    baseY: o,
    shapes: [
      CircleShape(o, o, r),
      CircleShape(o, o, r - 50),
      ...chairsAround(o, o, r, seats),
    ],
  );
}

const double _up = 1.5707963267948966; // pi / 2
const double _down = -1.5707963267948966;
const double _right = 0;
const double _left = 3.141592653589793;

/// Restaurant Tables, in palette order.
final List<FurnitureSymbol> tablesCatalog = [
  rectTable('restaurant.table.square.two', 'Square table, 2 seats', 700, 700,
      perSide: 1, ends: false, tags: const ['table', 'square', 'two']),
  rectTable('restaurant.table.square.four', 'Square table, 4 seats', 800, 800,
      perSide: 1, ends: true, tags: const ['table', 'square', 'four']),
  rectTable(
      'restaurant.table.rect.four', 'Rectangular table, 4 seats', 1200, 750,
      perSide: 2, ends: false, tags: const ['table', 'rectangular', 'four']),
  rectTable(
      'restaurant.table.rect.six', 'Rectangular table, 6 seats', 1800, 800,
      perSide: 2, ends: true, tags: const ['table', 'rectangular', 'six']),
  rectTable(
      'restaurant.table.rect.eight', 'Rectangular table, 8 seats', 2400, 900,
      perSide: 3, ends: true, tags: const ['table', 'rectangular', 'eight']),
  rectTable(
      'restaurant.table.rect.ten', 'Rectangular table, 10 seats', 3000, 900,
      perSide: 4,
      ends: true,
      tags: const ['table', 'rectangular', 'ten', 'banquet']),
  rectTable(
      'restaurant.table.rect.twelve', 'Rectangular table, 12 seats', 3600, 1000,
      perSide: 5,
      ends: true,
      tags: const ['table', 'rectangular', 'twelve', 'banquet']),
  roundTable('restaurant.table.round.two', 'Round table, 2 seats', 600, 2,
      tags: const ['table', 'round', 'two']),
  roundTable('restaurant.table.round.four', 'Round table, 4 seats', 900, 4,
      tags: const ['table', 'round', 'four']),
  roundTable('restaurant.table.round.six', 'Round table, 6 seats', 1200, 6,
      tags: const ['table', 'round', 'six']),
  roundTable('restaurant.table.round.eight', 'Round table, 8 seats', 1500, 8,
      tags: const ['table', 'round', 'eight']),
  roundTable('restaurant.table.round.ten', 'Round table, 10 seats', 1800, 10,
      tags: const ['table', 'round', 'ten', 'banquet']),
];
