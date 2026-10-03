// Commercial Kitchen (spec 14 V-6): the back-of-house equipment. None is
// servable. The front of each piece is on y = 0 (the furniture catalog's
// rule).
import 'dart:math' as math;

import 'package:jet_cad_floor_plan/symbols.dart';

import 'shapes.dart';

/// The palette category of this file's symbols.
const String commercialKitchen = 'Commercial Kitchen';

/// A [w] x [h] piece whose base point is its centre, with [details] drawn
/// after its outline.
FurnitureSymbol _piece(String key, String name, List<String> tags, double w,
        double h, List<FurnitureShape> details) =>
    FurnitureSymbol(
      key: key,
      name: name,
      category: commercialKitchen,
      tags: tags,
      baseX: w / 2,
      baseY: h / 2,
      shapes: [rect(0, 0, w, h), ...details],
    );

/// A burner: a Ø 240 ring at ([x], [y]).
FurnitureShape _burner(double x, double y) => CircleShape(x, y, 120);

/// Commercial Kitchen, in palette order.
final List<FurnitureSymbol> kitchenCatalog = [
  _piece(
      'restaurant.kitchen.pass',
      'Kitchen pass',
      const ['pass', 'window', 'heat lamp'],
      2000,
      600,
      const [
        LineShape(0, 200, 2000, 200),
        LineShape(0, 400, 2000, 400),
      ]),
  _piece(
      'restaurant.kitchen.prep.table',
      'Prep table',
      const ['prep', 'table', 'worktop'],
      1800,
      700,
      [
        inset(0, 0, 1800, 700, 50),
      ]),
  _piece(
      'restaurant.kitchen.range.four',
      'Range, 4 burners',
      const ['range', 'stove', 'burner', 'four'],
      900,
      900,
      [
        _burner(225, 225),
        _burner(675, 225),
        _burner(225, 675),
        _burner(675, 675),
      ]),
  _piece(
      'restaurant.kitchen.range.six',
      'Range, 6 burners',
      const ['range', 'stove', 'burner', 'six'],
      1200,
      900,
      [
        for (final y in const [250.0, 650.0])
          for (final x in const [200.0, 600.0, 1000.0]) _burner(x, y),
      ]),
  _piece(
      'restaurant.kitchen.fryer',
      'Fryer',
      const ['fryer', 'fry', 'oil'],
      400,
      800,
      [
        rect(35, 400, 150, 300),
        rect(215, 400, 150, 300),
      ]),
  _piece(
      'restaurant.kitchen.griddle',
      'Griddle',
      const ['griddle', 'plancha', 'grill'],
      900,
      800,
      [
        inset(0, 0, 900, 800, 50),
      ]),
  _piece(
      'restaurant.kitchen.oven.convection',
      'Convection oven',
      const ['oven', 'convection'],
      900,
      900,
      [
        const LineShape(0, 100, 900, 100),
        rect(200, 250, 500, 400),
      ]),
  // A 1600 x 1600 base with a Ø 1300 domed chamber and its mouth.
  _piece(
      'restaurant.kitchen.oven.pizza',
      'Pizza oven',
      const ['oven', 'pizza', 'wood fired'],
      1600,
      1600,
      [
        const CircleShape(800, 850, 650),
        // The mouth's sides meet the dome: at x = 800 ± 250 the circle's
        // lowest point is 850 - 600 = 250 (review F-10).
        const LineShape(550, 0, 550, 250),
        const LineShape(1050, 0, 1050, 250),
      ]),
  _piece(
      'restaurant.kitchen.dishwasher',
      'Dishwasher',
      const ['dishwasher', 'warewash'],
      700,
      750,
      [
        inset(0, 0, 700, 750, 50),
      ]),
  // A 1800 x 700 sink with three 500 x 500 bowls, 100 apart.
  _piece(
      'restaurant.kitchen.sink.three',
      'Three-bowl sink',
      const ['sink', 'three', 'wash'],
      1800,
      700,
      [
        for (final x in const [50.0, 650.0, 1250.0]) rect(x, 100, 500, 500),
      ]),
  _piece(
      'restaurant.kitchen.sink.hand',
      'Hand sink',
      const ['sink', 'hand', 'wash'],
      450,
      400,
      [
        inset(0, 0, 450, 400, 60),
      ]),
  _piece(
      'restaurant.kitchen.fridge.reachin',
      'Reach-in fridge',
      const ['fridge', 'refrigerator', 'reach-in'],
      700,
      800,
      [
        const LineShape(0, 60, 700, 60),
      ]),
  _piece(
      'restaurant.kitchen.freezer',
      'Freezer',
      const ['freezer', 'cold'],
      700,
      800,
      [
        const LineShape(0, 60, 700, 60),
        const LineShape(0, 60, 700, 800),
      ]),
  // A 2400 x 2000 cold room: its 100-thick walls as one closed outline with
  // an 800 opening in the front wall (x 200 to 1000), the door leaf swung
  // open out of it, and its swing (review F-7).
  const FurnitureSymbol(
    key: 'restaurant.kitchen.walkin',
    name: 'Walk-in cooler',
    category: commercialKitchen,
    tags: ['walk-in', 'cooler', 'cold room'],
    baseX: 1200,
    baseY: 1000,
    shapes: [
      PolylineShape([
        (1000, 0),
        (2400, 0),
        (2400, 2000),
        (0, 2000),
        (0, 0),
        (200, 0),
        (200, 100),
        (100, 100),
        (100, 1900),
        (2300, 1900),
        (2300, 100),
        (1000, 100),
      ], closed: true),
      LineShape(200, 0, 200, -800),
      ArcShape(200, 0, 800, -math.pi / 2, math.pi / 2),
    ],
  ),
  _piece(
      'restaurant.kitchen.shelving',
      'Shelving',
      const ['shelving', 'rack', 'storage'],
      1200,
      500,
      const [
        LineShape(0, 125, 1200, 125),
        LineShape(0, 250, 1200, 250),
        LineShape(0, 375, 1200, 375),
      ]),
  _piece(
      'restaurant.kitchen.ice.machine',
      'Ice machine',
      const ['ice', 'machine'],
      600,
      700,
      [
        inset(0, 0, 600, 700, 50),
      ]),
  // A Ø 500 bin. Its base point is its centre.
  const FurnitureSymbol(
    key: 'restaurant.kitchen.bin',
    name: 'Bin',
    category: commercialKitchen,
    tags: ['bin', 'trash', 'waste'],
    baseX: 250,
    baseY: 250,
    shapes: [CircleShape(250, 250, 250), CircleShape(250, 250, 200)],
  ),
];
