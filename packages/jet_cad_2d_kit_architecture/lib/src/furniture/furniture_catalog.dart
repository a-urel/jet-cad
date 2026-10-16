// The architecture kit's furniture (spec 3a C4): today's 41 symbols
// (jet_cad_floor_plan/lib/src/symbols/furniture_catalog.dart), rewritten in
// the authoring language, each in millimetres in a corner-origin local frame
// (x to the right, y up the plan, the front of the piece on y = 0), its base
// point off the origin.
//
// - Keys: `architecture.` and today's key, at version 1 (umbrella decision
//   9: no plan of jet_cad_floor_plan is read, so versions restart);
//   `armchair`, one segment, is `architecture.armchair.single`.
// - Behaviour is fields (umbrella A5): the 30 symbols of 09c D9's
//   against-the-wall set attach to `wall-face`; the six size families are
//   `family` fields; tags are search words only.
// - The dining tables are plain symbols (decision 3): no unit.
// - Every symbol's leaves are today's, in today's order and vertex order: a
//   chair is today's `_chair` (a `rect` and its back line), not `chairAt`.
//
// Pure Dart: no Flutter, no dart:io (the generator runs it under `dart run`).
import 'dart:math' as math;

import 'package:jet_cad_2d_kit/authoring.dart';

const double _pi = math.pi;

const String _dining = 'Dining Room';
const String _kitchen = 'Kitchen';
const String _bedRoom = 'Bed Room';
const String _livingRoom = 'Living Room';
const String _bathroom = 'Bathroom';
const String _office = 'Office';

/// The one attachment kind the kit's symbols name (spec C5).
const List<String> _wallFace = ['wall-face'];

/// Which side of the table a chair sits on; the chair's back is on the far
/// side from the table.
enum _Side { bottom, top, left, right }

/// Today's seat depth beyond the table edge: 450 − 100 = 350.
const double _chairReach = chairSize - chairTuck;

CatalogLine _line(double x1, double y1, double x2, double y2) =>
    CatalogLine((x1, y1), (x2, y2));

/// One chair: a closed 450 x 450 seat outline from (x, y) and a thin back
/// line 60 mm in from the outer edge, on the side away from the table.
List<CatalogShape> _chair(double x, double y, _Side back) => [
      rect(x, y, chairSize, chairSize),
      switch (back) {
        _Side.bottom => _line(x, y + 60, x + chairSize, y + 60),
        _Side.top =>
          _line(x, y + chairSize - 60, x + chairSize, y + chairSize - 60),
        _Side.left => _line(x + 60, y, x + 60, y + chairSize),
        _Side.right =>
          _line(x + chairSize - 60, y, x + chairSize - 60, y + chairSize),
      },
    ];

/// A [tw] x [th] table with its chairs, its lower-left corner at ([ox],
/// [oy]); [chairs] are (side, centre along that side) pairs. The base point
/// is the table centre. Leaves: table outline, table inset, then each chair
/// (outline, back line). A plain symbol (decision 3).
CatalogSymbol _diningSet(String key, String name, double tw, double th,
    double ox, double oy, List<String> tags, List<(_Side, double)> chairs) {
  final shapes = <CatalogShape>[
    rect(ox, oy, tw, th),
    rect(ox + 50, oy + 50, tw - 100, th - 100),
  ];
  for (final (side, c) in chairs) {
    const h = chairSize / 2;
    switch (side) {
      case _Side.bottom:
        shapes.addAll(_chair(ox + c - h, oy - _chairReach, side));
      case _Side.top:
        shapes.addAll(_chair(ox + c - h, oy + th - chairTuck, side));
      case _Side.left:
        shapes.addAll(_chair(ox - _chairReach, oy + c - h, side));
      case _Side.right:
        shapes.addAll(_chair(ox + tw - chairTuck, oy + c - h, side));
    }
  }
  return CatalogSymbol(
    key: key,
    name: name,
    category: _dining,
    tags: tags,
    base: (ox + tw / 2, oy + th / 2),
    shapes: shapes,
  );
}

// The size families (spec 09c D9): each member is its family's drawing at
// another width, the depth, the front (y = 0) and the back the same, the
// base point on the box's centre x.

/// A double bed [w] x 2000: outline, two pillows 240 deep with 100 mm
/// margins and gap, the fold line at 1300. Base point: the centre.
CatalogSymbol _doubleBed(String key, String name, double w) {
  final pillow = (w - 300) / 2;
  return CatalogSymbol(
    key: key,
    name: name,
    category: _bedRoom,
    tags: const ['bed', 'double', 'sleeping'],
    attachTo: _wallFace,
    family: 'bed-double',
    base: (w / 2, 1000),
    shapes: [
      rect(0, 0, w, 2000),
      rect(100, 1680, pillow, 240),
      rect(200 + pillow, 1680, pillow, 240),
      _line(0, 1300, w, 1300),
    ],
  );
}

/// A single bed [w] x 2000: outline, one pillow 240 deep with 120 mm
/// margins, the fold line at 1300. Base point: the centre.
CatalogSymbol _singleBed(String key, String name, double w) => CatalogSymbol(
      key: key,
      name: name,
      category: _bedRoom,
      tags: const ['bed', 'single', 'sleeping'],
      attachTo: _wallFace,
      family: 'bed-single',
      base: (w / 2, 1000),
      shapes: [
        rect(0, 0, w, 2000),
        rect(120, 1680, w - 240, 240),
        _line(0, 1300, w, 1300),
      ],
    );

/// A wardrobe [w] x 600 of 600 mm doors: outline, the door line at y = 40,
/// a line between each pair of doors, the handles either side of the first.
/// Base point: the front centre.
CatalogSymbol _wardrobe(String key, String name, double w) => CatalogSymbol(
      key: key,
      name: name,
      category: _bedRoom,
      tags: const ['wardrobe', 'storage', 'closet'],
      attachTo: _wallFace,
      family: 'wardrobe',
      base: (w / 2, 0),
      shapes: [
        rect(0, 0, w, 600),
        _line(0, 40, w, 40),
        for (var x = 600.0; x < w; x += 600) _line(x, 40, x, 600),
        _line(560, 40, 560, 160),
        _line(640, 40, 640, 160),
      ],
    );

/// A kitchen base unit [w] x 600: outline, the front line at y = 40, the
/// knob at the front centre. Base point: the front centre.
CatalogSymbol _baseUnit(String key, String name, double w) => CatalogSymbol(
      key: key,
      name: name,
      category: _kitchen,
      tags: const ['base unit', 'cabinet', 'cupboard'],
      attachTo: _wallFace,
      family: 'kitchen-base',
      base: (w / 2, 0),
      shapes: [
        rect(0, 0, w, 600),
        _line(0, 40, w, 40),
        CatalogCircle((w / 2, 20), 10),
      ],
    );

/// A desk [w] x 700: outline, a 400 mm drawer block at the right with two
/// drawer lines. Base point: the front centre.
CatalogSymbol _desk(String key, String name, double w) => CatalogSymbol(
      key: key,
      name: name,
      category: _office,
      tags: const ['desk', 'office', 'table'],
      attachTo: _wallFace,
      family: 'desk',
      base: (w / 2, 0),
      shapes: [
        rect(0, 0, w, 700),
        _line(w - 400, 0, w - 400, 700),
        _line(w - 400, 230, w, 230),
        _line(w - 400, 460, w, 460),
      ],
    );

/// The catalog, in the order the library stores it: definition handles and
/// leaf handles ascend in this order (today's order).
final Catalog furnitureCatalog = Catalog(kit: 'architecture', symbols: [
  // Dining Room
  _diningSet(
      'architecture.dining.table.square.two',
      'Square dining table, 2 seats',
      800,
      800,
      0,
      350,
      const ['table', 'dining', 'square', 'two'],
      const [(_Side.bottom, 400), (_Side.top, 400)]),
  _diningSet('architecture.dining.table.square.four',
      'Square dining table, 4 seats', 900, 900, 350, 350, const [
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
  _diningSet('architecture.dining.table.rect.four',
      'Rectangular dining table, 4 seats', 1400, 800, 0, 350, const [
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
  _diningSet('architecture.dining.table.rect.six',
      'Rectangular dining table, 6 seats', 1800, 900, 350, 350, const [
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
  // A Ø 1100 top with four chairs, centred far enough from the origin that
  // every chair has non-negative coordinates.
  CatalogSymbol(
    key: 'architecture.dining.table.round',
    name: 'Round dining table, 4 seats',
    category: _dining,
    tags: const ['table', 'dining', 'round', 'four'],
    base: (900, 900),
    shapes: [
      const CatalogCircle((900, 900), 550),
      const CatalogCircle((900, 900), 500),
      ..._chair(900 - chairSize / 2, 900 - 550 - _chairReach, _Side.bottom),
      ..._chair(900 - chairSize / 2, 900 + 550 - chairTuck, _Side.top),
      ..._chair(900 - 550 - _chairReach, 900 - chairSize / 2, _Side.left),
      ..._chair(900 + 550 - chairTuck, 900 - chairSize / 2, _Side.right),
    ],
  ),
  CatalogSymbol(
    key: 'architecture.dining.chair',
    name: 'Dining chair',
    category: _dining,
    tags: const ['chair', 'seating', 'dining'],
    base: (225, 225),
    shapes: [
      rect(0, 0, 450, 450),
      _line(0, 380, 450, 380),
      rect(40, 40, 370, 300),
    ],
  ),
  CatalogSymbol(
    key: 'architecture.dining.bench',
    name: 'Bench',
    category: _dining,
    tags: const ['bench', 'seating', 'dining'],
    base: (600, 175),
    shapes: [rect(0, 0, 1200, 350), inset(0, 0, 1200, 350, 30)],
  ),

  // Kitchen
  _baseUnit('architecture.kitchen.base.300', 'Base unit 300', 300),
  _baseUnit('architecture.kitchen.base.400', 'Base unit 400', 400),
  _baseUnit('architecture.kitchen.base.600', 'Base unit 600', 600),
  _baseUnit('architecture.kitchen.base.800', 'Base unit 800', 800),
  CatalogSymbol(
    key: 'architecture.kitchen.sink',
    name: 'Sink unit',
    category: _kitchen,
    tags: const ['sink', 'basin', 'cabinet'],
    attachTo: _wallFace,
    base: (600, 0),
    shapes: [
      rect(0, 0, 1200, 600),
      rect(60, 60, 500, 480),
      const CatalogCircle((310, 300), 35),
      _line(640, 100, 1140, 100),
      _line(640, 200, 1140, 200),
      _line(640, 300, 1140, 300),
      _line(640, 400, 1140, 400),
      const CatalogCircle((600, 570), 25),
    ],
  ),
  CatalogSymbol(
    key: 'architecture.kitchen.hob',
    name: 'Hob',
    category: _kitchen,
    tags: const ['hob', 'cooker', 'stove'],
    attachTo: _wallFace,
    base: (300, 0),
    shapes: [
      poly(const [(0, 0), (600, 0), (600, 520), (0, 520)]),
      const CatalogCircle((150, 140), 90),
      const CatalogCircle((150, 140), 40),
      const CatalogCircle((450, 140), 70),
      const CatalogCircle((450, 140), 30),
      const CatalogCircle((150, 390), 70),
      const CatalogCircle((150, 390), 30),
      const CatalogCircle((450, 390), 90),
      const CatalogCircle((450, 390), 40),
    ],
  ),
  CatalogSymbol(
    key: 'architecture.kitchen.fridge',
    name: 'Fridge',
    category: _kitchen,
    tags: const ['fridge', 'refrigerator', 'appliance'],
    attachTo: _wallFace,
    base: (300, 0),
    shapes: [
      rect(0, 0, 600, 650),
      _line(0, 40, 600, 40),
      _line(60, 40, 60, 160),
      _line(540, 40, 540, 160),
    ],
  ),
  CatalogSymbol(
    key: 'architecture.kitchen.dishwasher',
    name: 'Dishwasher',
    category: _kitchen,
    tags: const ['dishwasher', 'dishes', 'appliance'],
    attachTo: _wallFace,
    base: (300, 0),
    shapes: [
      rect(0, 0, 600, 600),
      _line(0, 40, 600, 40),
      _line(200, 20, 400, 20),
    ],
  ),
  CatalogSymbol(
    key: 'architecture.kitchen.washer',
    name: 'Washing machine',
    category: _kitchen,
    tags: const ['washer', 'laundry', 'appliance'],
    attachTo: _wallFace,
    base: (300, 0),
    shapes: [
      rect(0, 0, 600, 600),
      _line(0, 40, 600, 40),
      const CatalogCircle((300, 330), 220),
    ],
  ),
  CatalogSymbol(
    key: 'architecture.kitchen.island',
    name: 'Kitchen island',
    category: _kitchen,
    tags: const ['island', 'counter', 'worktop'],
    base: (900, 450),
    shapes: [
      rect(0, 0, 1800, 900),
      inset(0, 0, 1800, 900, 60),
      _line(600, 60, 600, 840),
      _line(1200, 60, 1200, 840),
    ],
  ),

  // Bed Room
  _doubleBed('architecture.bed.double.1400', 'Double bed 1400', 1400),
  _doubleBed('architecture.bed.double', 'Double bed', 1600),
  _doubleBed('architecture.bed.double.1800', 'Double bed 1800', 1800),
  _singleBed('architecture.bed.single.800', 'Single bed 800', 800),
  _singleBed('architecture.bed.single', 'Single bed', 900),
  _singleBed('architecture.bed.single.1000', 'Single bed 1000', 1000),
  CatalogSymbol(
    key: 'architecture.bed.nightstand',
    name: 'Nightstand',
    category: _bedRoom,
    tags: const ['nightstand', 'bedside', 'table'],
    attachTo: _wallFace,
    base: (225, 0),
    shapes: [
      rect(0, 0, 450, 400),
      inset(0, 0, 450, 400, 40),
      const CatalogCircle((225, 60), 12),
    ],
  ),
  _wardrobe('architecture.bed.wardrobe.1200', 'Wardrobe 1200', 1200),
  _wardrobe('architecture.bed.wardrobe', 'Wardrobe', 1800),
  _wardrobe('architecture.bed.wardrobe.2400', 'Wardrobe 2400', 2400),

  // Living Room
  CatalogSymbol(
    key: 'architecture.sofa.two',
    name: 'Two-seat sofa',
    category: _livingRoom,
    tags: const ['sofa', 'seating', 'couch'],
    attachTo: _wallFace,
    family: 'sofa',
    base: (750, 0),
    shapes: [
      rect(0, 0, 1500, 900),
      _line(0, 700, 1500, 700),
      _line(200, 0, 200, 700),
      _line(1300, 0, 1300, 700),
      _line(750, 0, 750, 700),
    ],
  ),
  CatalogSymbol(
    key: 'architecture.sofa.three',
    name: 'Three-seat sofa',
    category: _livingRoom,
    tags: const ['sofa', 'seating', 'couch'],
    attachTo: _wallFace,
    family: 'sofa',
    base: (1000, 0),
    shapes: [
      rect(0, 0, 2000, 900),
      _line(0, 700, 2000, 700),
      _line(200, 0, 200, 700),
      _line(1800, 0, 1800, 700),
      _line(733, 0, 733, 700),
      _line(1267, 0, 1267, 700),
    ],
  ),
  CatalogSymbol(
    key: 'architecture.armchair.single',
    name: 'Armchair',
    category: _livingRoom,
    tags: const ['armchair', 'seating', 'chair'],
    base: (425, 0),
    shapes: [
      rect(0, 0, 850, 850),
      _line(0, 650, 850, 650),
      _line(150, 0, 150, 650),
      _line(700, 0, 700, 650),
    ],
  ),
  CatalogSymbol(
    key: 'architecture.table.coffee',
    name: 'Coffee table',
    category: _livingRoom,
    tags: const ['table', 'coffee', 'low'],
    base: (550, 300),
    shapes: [rect(0, 0, 1100, 600), inset(0, 0, 1100, 600, 40)],
  ),
  CatalogSymbol(
    key: 'architecture.tv.unit',
    name: 'TV unit',
    category: _livingRoom,
    tags: const ['tv', 'media', 'unit', 'storage'],
    attachTo: _wallFace,
    base: (800, 0),
    shapes: [
      rect(0, 0, 1600, 450),
      _line(533, 0, 533, 450),
      _line(1066, 0, 1066, 450),
      _line(0, 40, 1600, 40),
    ],
  ),

  // Bathroom
  CatalogSymbol(
    key: 'architecture.bath.toilet',
    name: 'Toilet',
    category: _bathroom,
    tags: const ['toilet', 'wc', 'sanitary'],
    attachTo: _wallFace,
    base: (200, 0),
    shapes: [
      poly(const [(0, 500), (400, 500), (400, 700), (0, 700)]),
      _line(0, 500, 0, 200),
      _line(400, 500, 400, 200),
      const CatalogArc((200, 200), 200, _pi, _pi),
      _line(50, 500, 50, 200),
      _line(350, 500, 350, 200),
      const CatalogArc((200, 200), 150, _pi, _pi),
    ],
  ),
  CatalogSymbol(
    key: 'architecture.bath.washbasin',
    name: 'Washbasin',
    category: _bathroom,
    tags: const ['washbasin', 'sink', 'sanitary'],
    attachTo: _wallFace,
    base: (300, 0),
    shapes: [
      poly(const [(0, 0), (600, 0), (600, 450), (0, 450)]),
      const CatalogCircle((300, 210), 170),
      const CatalogCircle((300, 210), 20),
      const CatalogCircle((300, 410), 18),
    ],
  ),
  CatalogSymbol(
    key: 'architecture.bath.tub',
    name: 'Bathtub',
    category: _bathroom,
    tags: const ['bathtub', 'bath', 'sanitary'],
    attachTo: _wallFace,
    base: (850, 375),
    shapes: [
      rect(0, 0, 1700, 750),
      inset(0, 0, 1700, 750, 70),
      const CatalogCircle((170, 375), 25),
      const CatalogCircle((1620, 375), 15),
    ],
  ),
  CatalogSymbol(
    key: 'architecture.bath.shower',
    name: 'Shower tray',
    category: _bathroom,
    tags: const ['shower', 'tray', 'sanitary'],
    attachTo: _wallFace,
    base: (450, 450),
    shapes: [
      rect(0, 0, 900, 900),
      inset(0, 0, 900, 900, 50),
      const CatalogCircle((450, 450), 40),
    ],
  ),

  // Office
  _desk('architecture.office.desk.1200', 'Desk 1200', 1200),
  _desk('architecture.office.desk', 'Desk', 1400),
  _desk('architecture.office.desk.1600', 'Desk 1600', 1600),
  CatalogSymbol(
    key: 'architecture.office.chair',
    name: 'Office chair',
    category: _office,
    tags: const ['chair', 'office', 'seating'],
    base: (300, 300),
    shapes: [
      const CatalogCircle((300, 300), 300),
      const CatalogCircle((300, 300), 230),
      const CatalogArc((300, 300), 280, _pi / 4, _pi / 2),
    ],
  ),
  CatalogSymbol(
    key: 'architecture.office.bookshelf',
    name: 'Bookshelf',
    category: _office,
    tags: const ['bookshelf', 'shelf', 'storage'],
    attachTo: _wallFace,
    base: (450, 0),
    shapes: [
      rect(0, 0, 900, 300),
      _line(0, 30, 900, 30),
      _line(300, 30, 300, 300),
      _line(600, 30, 600, 300),
    ],
  ),
]);
