// The furniture catalog (spec 09 D2, D7): each symbol as plain data, in
// millimetres, in a corner-origin local frame (x to the right, y up the
// plan, the front of the piece on y = 0). The base point is the centre or
// the front-centre, so it is off the origin for every symbol.
//
// Geometry only: lines, polylines, arcs and circles. No text, no fill, no
// point (spec R-5).
//
// No Flutter import and no `dart:io`: this file is Dart over
// `package:jet_cad_2d` only.
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// One drawn shape of a symbol.
sealed class FurnitureShape {
  const FurnitureShape();

  EntityKind get kind;
  GeometryPayload payload();
}

final class LineShape extends FurnitureShape {
  final double x1, y1, x2, y2;
  const LineShape(this.x1, this.y1, this.x2, this.y2);

  @override
  EntityKind get kind => EntityKind.line;

  @override
  GeometryPayload payload() => linePayload(Vector2(x1, y1), Vector2(x2, y2));
}

/// A polyline through [points] (x, y pairs); [closed] repeats the first point.
final class PolylineShape extends FurnitureShape {
  final List<(double, double)> points;
  final bool closed;
  const PolylineShape(this.points, {this.closed = false});

  @override
  EntityKind get kind => EntityKind.polyline;

  @override
  GeometryPayload payload() => polylinePayload(
        [for (final (x, y) in points) Vector2(x, y)],
        closed: closed,
      );
}

final class CircleShape extends FurnitureShape {
  final double cx, cy, r;
  const CircleShape(this.cx, this.cy, this.r);

  @override
  EntityKind get kind => EntityKind.circle;

  @override
  GeometryPayload payload() => circlePayload(Vector2(cx, cy), r);
}

/// A counter-clockwise arc from [start] through [sweep] (radians).
final class ArcShape extends FurnitureShape {
  final double cx, cy, r, start, sweep;
  const ArcShape(this.cx, this.cy, this.r, this.start, this.sweep);

  @override
  EntityKind get kind => EntityKind.arc;

  @override
  GeometryPayload payload() => arcPayload(Vector2(cx, cy), r, start, sweep);
}

/// One symbol of the library.
final class FurnitureSymbol {
  final String key;
  final String name;
  final String category;
  final List<String> tags;
  final int version;

  /// How many people the symbol seats when it is servable (a table, a
  /// booth, a bar stool: spec 14 S1, S2), or null when it is not. A
  /// servable symbol draws its served top first (S4).
  final int? seats;
  final double baseX, baseY;
  final List<FurnitureShape> shapes;

  const FurnitureSymbol({
    required this.key,
    required this.name,
    required this.category,
    required this.tags,
    this.version = 1,
    this.seats,
    required this.baseX,
    required this.baseY,
    required this.shapes,
  });
}

/// A closed axis-aligned rectangle from (x, y), [w] wide and [h] tall.
FurnitureShape _rect(double x, double y, double w, double h) =>
    PolylineShape([(x, y), (x + w, y), (x + w, y + h), (x, y + h)],
        closed: true);

/// [_rect] inset by [d] on every side of a [w] x [h] outline.
FurnitureShape _inset(double w, double h, double d) =>
    _rect(d, d, w - 2 * d, h - 2 * d);

const double _pi = math.pi;

const String dining = 'Dining Room';
const String kitchen = 'Kitchen';
const String bedRoom = 'Bed Room';
const String livingRoom = 'Living Room';
const String bathroom = 'Bathroom';
const String office = 'Office';

/// Which side of the table a chair sits on; the chair's back is on the far
/// side from the table.
enum _Side { bottom, top, left, right }

const double _chairSize = 450;
const double _chairTuck = 100; // seat depth tucked under the table edge
const double _chairReach = _chairSize - _chairTuck; // 350 beyond the edge

/// One chair: a closed 450 x 450 seat outline from (x, y) and a thin back
/// line 60 mm in from the outer edge, on the side away from the table.
List<FurnitureShape> _chair(double x, double y, _Side back) => [
      _rect(x, y, _chairSize, _chairSize),
      switch (back) {
        _Side.bottom => LineShape(x, y + 60, x + _chairSize, y + 60),
        _Side.top => LineShape(
            x, y + _chairSize - 60, x + _chairSize, y + _chairSize - 60),
        _Side.left => LineShape(x + 60, y, x + 60, y + _chairSize),
        _Side.right => LineShape(
            x + _chairSize - 60, y, x + _chairSize - 60, y + _chairSize),
      },
    ];

/// A [tw] x [th] table with its chairs. The table's lower-left corner is at
/// ([ox], [oy]); [chairs] are (side, centre along that side) pairs, the
/// centre measured from the table's lower-left corner along the side. The
/// base point is the table centre. Leaves: table outline, table inset, then
/// each chair (outline, back line). Servable at version 2 (spec 14 S3): it
/// seats one per chair.
FurnitureSymbol _diningSet(String key, String name, double tw, double th,
    double ox, double oy, List<String> tags, List<(_Side, double)> chairs) {
  final shapes = <FurnitureShape>[
    _rect(ox, oy, tw, th),
    _rect(ox + 50, oy + 50, tw - 100, th - 100),
  ];
  for (final (side, c) in chairs) {
    const h = _chairSize / 2;
    switch (side) {
      case _Side.bottom:
        shapes.addAll(_chair(ox + c - h, oy - _chairReach, side));
      case _Side.top:
        shapes.addAll(_chair(ox + c - h, oy + th - _chairTuck, side));
      case _Side.left:
        shapes.addAll(_chair(ox - _chairReach, oy + c - h, side));
      case _Side.right:
        shapes.addAll(_chair(ox + tw - _chairTuck, oy + c - h, side));
    }
  }
  return FurnitureSymbol(
    key: key,
    name: name,
    category: dining,
    tags: tags,
    version: 2,
    seats: chairs.length,
    baseX: ox + tw / 2,
    baseY: oy + th / 2,
    shapes: shapes,
  );
}

/// The catalog, in the order the library stores it: definition handles and
/// leaf handles ascend in this order.
final List<FurnitureSymbol> furnitureCatalog = List.unmodifiable([
  // Dining Room
  _diningSet(
      'dining.table.square.two',
      'Square dining table, 2 seats',
      800,
      800,
      0,
      350,
      const ['table', 'dining', 'square', 'two'],
      const [(_Side.bottom, 400), (_Side.top, 400)]),
  _diningSet('dining.table.square.four', 'Square dining table, 4 seats', 900,
      900, 350, 350, const [
    'table',
    'dining',
    'square',
    'four'
  ], const [
    (_Side.bottom, 450),
    (_Side.top, 450),
    (_Side.left, 450),
    (_Side.right, 450),
  ]),
  _diningSet('dining.table.rect.four', 'Rectangular dining table, 4 seats',
      1400, 800, 0, 350, const [
    'table',
    'dining',
    'rectangular',
    'four'
  ], const [
    (_Side.bottom, 350),
    (_Side.bottom, 1050),
    (_Side.top, 350),
    (_Side.top, 1050),
  ]),
  _diningSet('dining.table.rect.six', 'Rectangular dining table, 6 seats', 1800,
      900, 350, 350, const [
    'table',
    'dining',
    'rectangular',
    'six'
  ], const [
    (_Side.bottom, 450),
    (_Side.bottom, 1350),
    (_Side.top, 450),
    (_Side.top, 1350),
    (_Side.left, 450),
    (_Side.right, 450),
  ]),
  // A Ø 1100 top with four chairs (spec 14 S3: version 2 draws them, so
  // its seat count is visible), centred far enough from the origin that
  // every chair has non-negative coordinates.
  FurnitureSymbol(
    key: 'dining.table.round',
    name: 'Round dining table, 4 seats',
    category: dining,
    tags: const ['table', 'dining', 'round', 'four'],
    version: 2,
    seats: 4,
    baseX: 900,
    baseY: 900,
    shapes: [
      const CircleShape(900, 900, 550),
      const CircleShape(900, 900, 500),
      ..._chair(900 - _chairSize / 2, 900 - 550 - _chairReach, _Side.bottom),
      ..._chair(900 - _chairSize / 2, 900 + 550 - _chairTuck, _Side.top),
      ..._chair(900 - 550 - _chairReach, 900 - _chairSize / 2, _Side.left),
      ..._chair(900 + 550 - _chairTuck, 900 - _chairSize / 2, _Side.right),
    ],
  ),
  FurnitureSymbol(
    key: 'dining.chair',
    name: 'Dining chair',
    category: dining,
    tags: const ['chair', 'seating', 'dining'],
    baseX: 225,
    baseY: 225,
    shapes: [
      _rect(0, 0, 450, 450),
      const LineShape(0, 380, 450, 380),
      _rect(40, 40, 370, 300),
    ],
  ),
  FurnitureSymbol(
    key: 'dining.bench',
    name: 'Bench',
    category: dining,
    tags: const ['bench', 'seating', 'dining'],
    baseX: 600,
    baseY: 175,
    shapes: [_rect(0, 0, 1200, 350), _inset(1200, 350, 30)],
  ),

  // Kitchen
  FurnitureSymbol(
    key: 'kitchen.base.600',
    name: 'Base unit 600',
    category: kitchen,
    tags: const ['base unit', 'cabinet', 'cupboard'],
    baseX: 300,
    baseY: 0,
    shapes: [
      _rect(0, 0, 600, 600),
      const LineShape(0, 40, 600, 40),
      const CircleShape(300, 20, 10),
    ],
  ),
  FurnitureSymbol(
    key: 'kitchen.sink',
    name: 'Sink unit',
    category: kitchen,
    tags: const ['sink', 'basin', 'cabinet'],
    baseX: 600,
    baseY: 0,
    shapes: [
      _rect(0, 0, 1200, 600),
      _rect(60, 60, 500, 480),
      const CircleShape(310, 300, 35),
      const LineShape(640, 100, 1140, 100),
      const LineShape(640, 200, 1140, 200),
      const LineShape(640, 300, 1140, 300),
      const LineShape(640, 400, 1140, 400),
      const CircleShape(600, 570, 25),
    ],
  ),
  const FurnitureSymbol(
    key: 'kitchen.hob',
    name: 'Hob',
    category: kitchen,
    tags: ['hob', 'cooker', 'stove'],
    baseX: 300,
    baseY: 0,
    shapes: [
      PolylineShape([(0, 0), (600, 0), (600, 520), (0, 520)], closed: true),
      CircleShape(150, 140, 90),
      CircleShape(150, 140, 40),
      CircleShape(450, 140, 70),
      CircleShape(450, 140, 30),
      CircleShape(150, 390, 70),
      CircleShape(150, 390, 30),
      CircleShape(450, 390, 90),
      CircleShape(450, 390, 40),
    ],
  ),
  FurnitureSymbol(
    key: 'kitchen.fridge',
    name: 'Fridge',
    category: kitchen,
    tags: const ['fridge', 'refrigerator', 'appliance'],
    baseX: 300,
    baseY: 0,
    shapes: [
      _rect(0, 0, 600, 650),
      const LineShape(0, 40, 600, 40),
      const LineShape(60, 40, 60, 160),
      const LineShape(540, 40, 540, 160),
    ],
  ),
  FurnitureSymbol(
    key: 'kitchen.island',
    name: 'Kitchen island',
    category: kitchen,
    tags: const ['island', 'counter', 'worktop'],
    baseX: 900,
    baseY: 450,
    shapes: [
      _rect(0, 0, 1800, 900),
      _inset(1800, 900, 60),
      const LineShape(600, 60, 600, 840),
      const LineShape(1200, 60, 1200, 840),
    ],
  ),

  // Bed Room
  FurnitureSymbol(
    key: 'bed.double',
    name: 'Double bed',
    category: bedRoom,
    tags: const ['bed', 'double', 'sleeping'],
    baseX: 800,
    baseY: 1000,
    shapes: [
      _rect(0, 0, 1600, 2000),
      _rect(100, 1680, 650, 240),
      _rect(850, 1680, 650, 240),
      const LineShape(0, 1300, 1600, 1300),
    ],
  ),
  FurnitureSymbol(
    key: 'bed.single',
    name: 'Single bed',
    category: bedRoom,
    tags: const ['bed', 'single', 'sleeping'],
    baseX: 450,
    baseY: 1000,
    shapes: [
      _rect(0, 0, 900, 2000),
      _rect(120, 1680, 660, 240),
      const LineShape(0, 1300, 900, 1300),
    ],
  ),
  FurnitureSymbol(
    key: 'bed.nightstand',
    name: 'Nightstand',
    category: bedRoom,
    tags: const ['nightstand', 'bedside', 'table'],
    baseX: 225,
    baseY: 0,
    shapes: [
      _rect(0, 0, 450, 400),
      _inset(450, 400, 40),
      const CircleShape(225, 60, 12),
    ],
  ),
  FurnitureSymbol(
    key: 'bed.wardrobe',
    name: 'Wardrobe',
    category: bedRoom,
    tags: const ['wardrobe', 'storage', 'closet'],
    baseX: 900,
    baseY: 0,
    shapes: [
      _rect(0, 0, 1800, 600),
      const LineShape(0, 40, 1800, 40),
      const LineShape(600, 40, 600, 600),
      const LineShape(1200, 40, 1200, 600),
      const LineShape(560, 40, 560, 160),
      const LineShape(640, 40, 640, 160),
    ],
  ),

  // Living Room
  FurnitureSymbol(
    key: 'sofa.three',
    name: 'Three-seat sofa',
    category: livingRoom,
    tags: const ['sofa', 'seating', 'couch'],
    baseX: 1000,
    baseY: 0,
    shapes: [
      _rect(0, 0, 2000, 900),
      const LineShape(0, 700, 2000, 700),
      const LineShape(200, 0, 200, 700),
      const LineShape(1800, 0, 1800, 700),
      const LineShape(733, 0, 733, 700),
      const LineShape(1267, 0, 1267, 700),
    ],
  ),
  FurnitureSymbol(
    key: 'armchair',
    name: 'Armchair',
    category: livingRoom,
    tags: const ['armchair', 'seating', 'chair'],
    baseX: 425,
    baseY: 0,
    shapes: [
      _rect(0, 0, 850, 850),
      const LineShape(0, 650, 850, 650),
      const LineShape(150, 0, 150, 650),
      const LineShape(700, 0, 700, 650),
    ],
  ),
  FurnitureSymbol(
    key: 'table.coffee',
    name: 'Coffee table',
    category: livingRoom,
    tags: const ['table', 'coffee', 'low'],
    baseX: 550,
    baseY: 300,
    shapes: [_rect(0, 0, 1100, 600), _inset(1100, 600, 40)],
  ),
  FurnitureSymbol(
    key: 'tv.unit',
    name: 'TV unit',
    category: livingRoom,
    tags: const ['tv', 'media', 'unit', 'storage'],
    baseX: 800,
    baseY: 0,
    shapes: [
      _rect(0, 0, 1600, 450),
      const LineShape(533, 0, 533, 450),
      const LineShape(1066, 0, 1066, 450),
      const LineShape(0, 40, 1600, 40),
    ],
  ),

  // Bathroom
  const FurnitureSymbol(
    key: 'bath.toilet',
    name: 'Toilet',
    category: bathroom,
    tags: ['toilet', 'wc', 'sanitary'],
    baseX: 200,
    baseY: 0,
    shapes: [
      PolylineShape([(0, 500), (400, 500), (400, 700), (0, 700)], closed: true),
      LineShape(0, 500, 0, 200),
      LineShape(400, 500, 400, 200),
      ArcShape(200, 200, 200, _pi, _pi),
      LineShape(50, 500, 50, 200),
      LineShape(350, 500, 350, 200),
      ArcShape(200, 200, 150, _pi, _pi),
    ],
  ),
  const FurnitureSymbol(
    key: 'bath.washbasin',
    name: 'Washbasin',
    category: bathroom,
    tags: ['washbasin', 'sink', 'sanitary'],
    baseX: 300,
    baseY: 0,
    shapes: [
      PolylineShape([(0, 0), (600, 0), (600, 450), (0, 450)], closed: true),
      CircleShape(300, 210, 170),
      CircleShape(300, 210, 20),
      CircleShape(300, 410, 18),
    ],
  ),
  FurnitureSymbol(
    key: 'bath.tub',
    name: 'Bathtub',
    category: bathroom,
    tags: const ['bathtub', 'bath', 'sanitary'],
    baseX: 850,
    baseY: 375,
    shapes: [
      _rect(0, 0, 1700, 750),
      _inset(1700, 750, 70),
      const CircleShape(170, 375, 25),
      const CircleShape(1620, 375, 15),
    ],
  ),
  FurnitureSymbol(
    key: 'bath.shower',
    name: 'Shower tray',
    category: bathroom,
    tags: const ['shower', 'tray', 'sanitary'],
    baseX: 450,
    baseY: 450,
    shapes: [
      _rect(0, 0, 900, 900),
      _inset(900, 900, 50),
      const CircleShape(450, 450, 40),
    ],
  ),

  // Office
  FurnitureSymbol(
    key: 'office.desk',
    name: 'Desk',
    category: office,
    tags: const ['desk', 'office', 'table'],
    baseX: 700,
    baseY: 0,
    shapes: [
      _rect(0, 0, 1400, 700),
      const LineShape(1000, 0, 1000, 700),
      const LineShape(1000, 230, 1400, 230),
      const LineShape(1000, 460, 1400, 460),
    ],
  ),
  const FurnitureSymbol(
    key: 'office.chair',
    name: 'Office chair',
    category: office,
    tags: ['chair', 'office', 'seating'],
    baseX: 300,
    baseY: 300,
    shapes: [
      CircleShape(300, 300, 300),
      CircleShape(300, 300, 230),
      ArcShape(300, 300, 280, _pi / 4, _pi / 2),
    ],
  ),
  FurnitureSymbol(
    key: 'office.bookshelf',
    name: 'Bookshelf',
    category: office,
    tags: const ['bookshelf', 'shelf', 'storage'],
    baseX: 450,
    baseY: 0,
    shapes: [
      _rect(0, 0, 900, 300),
      const LineShape(0, 30, 900, 30),
      const LineShape(300, 30, 300, 300),
      const LineShape(600, 30, 600, 300),
    ],
  ),
]);
