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
  final double baseX, baseY;
  final List<FurnitureShape> shapes;

  const FurnitureSymbol({
    required this.key,
    required this.name,
    required this.category,
    required this.tags,
    this.version = 1,
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
/// each chair (outline, back line).
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
    baseX: ox + tw / 2,
    baseY: oy + th / 2,
    shapes: shapes,
  );
}

// The size families (spec 09c D9): each member is its family's drawing at
// another width, the depth, the front (y = 0) and the back the same, the
// base point on the box's centre x. Tags: the plain ones, then
// `against-wall`, then `family:<id>` (spec 09c D2, the loader's R03d).

/// A double bed [w] x 2000: outline, two pillows 240 deep with 100 mm
/// margins and gap, the fold line at 1300. Base point: the centre.
FurnitureSymbol _doubleBed(String key, String name, double w) {
  final pillow = (w - 300) / 2;
  return FurnitureSymbol(
    key: key,
    name: name,
    category: bedRoom,
    tags: const [
      'bed',
      'double',
      'sleeping',
      'against-wall',
      'family:bed-double'
    ],
    baseX: w / 2,
    baseY: 1000,
    shapes: [
      _rect(0, 0, w, 2000),
      _rect(100, 1680, pillow, 240),
      _rect(200 + pillow, 1680, pillow, 240),
      LineShape(0, 1300, w, 1300),
    ],
  );
}

/// A single bed [w] x 2000: outline, one pillow 240 deep with 120 mm
/// margins, the fold line at 1300. Base point: the centre.
FurnitureSymbol _singleBed(String key, String name, double w) =>
    FurnitureSymbol(
      key: key,
      name: name,
      category: bedRoom,
      tags: const [
        'bed',
        'single',
        'sleeping',
        'against-wall',
        'family:bed-single'
      ],
      baseX: w / 2,
      baseY: 1000,
      shapes: [
        _rect(0, 0, w, 2000),
        _rect(120, 1680, w - 240, 240),
        LineShape(0, 1300, w, 1300),
      ],
    );

/// A wardrobe [w] x 600 of 600 mm doors: outline, the door line at y = 40,
/// a line between each pair of doors, the handles either side of the first.
/// Base point: the front centre.
FurnitureSymbol _wardrobe(String key, String name, double w) => FurnitureSymbol(
      key: key,
      name: name,
      category: bedRoom,
      tags: const [
        'wardrobe',
        'storage',
        'closet',
        'against-wall',
        'family:wardrobe'
      ],
      baseX: w / 2,
      baseY: 0,
      shapes: [
        _rect(0, 0, w, 600),
        LineShape(0, 40, w, 40),
        for (var x = 600.0; x < w; x += 600) LineShape(x, 40, x, 600),
        const LineShape(560, 40, 560, 160),
        const LineShape(640, 40, 640, 160),
      ],
    );

/// A kitchen base unit [w] x 600: outline, the front line at y = 40, the
/// knob at the front centre. Base point: the front centre.
FurnitureSymbol _baseUnit(String key, String name, double w) => FurnitureSymbol(
      key: key,
      name: name,
      category: kitchen,
      tags: const [
        'base unit',
        'cabinet',
        'cupboard',
        'against-wall',
        'family:kitchen-base'
      ],
      baseX: w / 2,
      baseY: 0,
      shapes: [
        _rect(0, 0, w, 600),
        LineShape(0, 40, w, 40),
        CircleShape(w / 2, 20, 10),
      ],
    );

/// A desk [w] x 700: outline, a 400 mm drawer block at the right with two
/// drawer lines. Base point: the front centre.
FurnitureSymbol _desk(String key, String name, double w) => FurnitureSymbol(
      key: key,
      name: name,
      category: office,
      tags: const ['desk', 'office', 'table', 'against-wall', 'family:desk'],
      baseX: w / 2,
      baseY: 0,
      shapes: [
        _rect(0, 0, w, 700),
        LineShape(w - 400, 0, w - 400, 700),
        LineShape(w - 400, 230, w, 230),
        LineShape(w - 400, 460, w, 460),
      ],
    );

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
  const FurnitureSymbol(
    key: 'dining.table.round',
    name: 'Round dining table',
    category: dining,
    tags: ['table', 'dining', 'round'],
    baseX: 550,
    baseY: 550,
    shapes: [CircleShape(550, 550, 550), CircleShape(550, 550, 500)],
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
  _baseUnit('kitchen.base.300', 'Base unit 300', 300),
  _baseUnit('kitchen.base.400', 'Base unit 400', 400),
  _baseUnit('kitchen.base.600', 'Base unit 600', 600),
  _baseUnit('kitchen.base.800', 'Base unit 800', 800),
  FurnitureSymbol(
    key: 'kitchen.sink',
    name: 'Sink unit',
    category: kitchen,
    tags: const ['sink', 'basin', 'cabinet', 'against-wall'],
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
    tags: ['hob', 'cooker', 'stove', 'against-wall'],
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
    tags: const ['fridge', 'refrigerator', 'appliance', 'against-wall'],
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
    key: 'kitchen.dishwasher',
    name: 'Dishwasher',
    category: kitchen,
    tags: const ['dishwasher', 'dishes', 'appliance', 'against-wall'],
    baseX: 300,
    baseY: 0,
    shapes: [
      _rect(0, 0, 600, 600),
      const LineShape(0, 40, 600, 40),
      const LineShape(200, 20, 400, 20),
    ],
  ),
  FurnitureSymbol(
    key: 'kitchen.washer',
    name: 'Washing machine',
    category: kitchen,
    tags: const ['washer', 'laundry', 'appliance', 'against-wall'],
    baseX: 300,
    baseY: 0,
    shapes: [
      _rect(0, 0, 600, 600),
      const LineShape(0, 40, 600, 40),
      const CircleShape(300, 330, 220),
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
  _doubleBed('bed.double.1400', 'Double bed 1400', 1400),
  _doubleBed('bed.double', 'Double bed', 1600),
  _doubleBed('bed.double.1800', 'Double bed 1800', 1800),
  _singleBed('bed.single.800', 'Single bed 800', 800),
  _singleBed('bed.single', 'Single bed', 900),
  _singleBed('bed.single.1000', 'Single bed 1000', 1000),
  FurnitureSymbol(
    key: 'bed.nightstand',
    name: 'Nightstand',
    category: bedRoom,
    tags: const ['nightstand', 'bedside', 'table', 'against-wall'],
    baseX: 225,
    baseY: 0,
    shapes: [
      _rect(0, 0, 450, 400),
      _inset(450, 400, 40),
      const CircleShape(225, 60, 12),
    ],
  ),
  _wardrobe('bed.wardrobe.1200', 'Wardrobe 1200', 1200),
  _wardrobe('bed.wardrobe', 'Wardrobe', 1800),
  _wardrobe('bed.wardrobe.2400', 'Wardrobe 2400', 2400),

  // Living Room
  FurnitureSymbol(
    key: 'sofa.two',
    name: 'Two-seat sofa',
    category: livingRoom,
    tags: const ['sofa', 'seating', 'couch', 'against-wall', 'family:sofa'],
    baseX: 750,
    baseY: 0,
    shapes: [
      _rect(0, 0, 1500, 900),
      const LineShape(0, 700, 1500, 700),
      const LineShape(200, 0, 200, 700),
      const LineShape(1300, 0, 1300, 700),
      const LineShape(750, 0, 750, 700),
    ],
  ),
  FurnitureSymbol(
    key: 'sofa.three',
    name: 'Three-seat sofa',
    category: livingRoom,
    tags: const ['sofa', 'seating', 'couch', 'against-wall', 'family:sofa'],
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
    tags: const ['tv', 'media', 'unit', 'storage', 'against-wall'],
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
    tags: ['toilet', 'wc', 'sanitary', 'against-wall'],
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
    tags: ['washbasin', 'sink', 'sanitary', 'against-wall'],
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
    tags: const ['bathtub', 'bath', 'sanitary', 'against-wall'],
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
    tags: const ['shower', 'tray', 'sanitary', 'against-wall'],
    baseX: 450,
    baseY: 450,
    shapes: [
      _rect(0, 0, 900, 900),
      _inset(900, 900, 50),
      const CircleShape(450, 450, 40),
    ],
  ),

  // Office
  _desk('office.desk.1200', 'Desk 1200', 1200),
  _desk('office.desk', 'Desk', 1400),
  _desk('office.desk.1600', 'Desk 1600', 1600),
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
    tags: const ['bookshelf', 'shelf', 'storage', 'against-wall'],
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
