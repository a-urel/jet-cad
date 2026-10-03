// Outdoor and Decor (spec 14 V-6): terrace and room furnishings. None is
// servable.
import 'dart:math' as math;

import 'package:jet_cad_floor_plan/symbols.dart';

import 'shapes.dart';

/// The palette category of this file's symbols.
const String outdoorAndDecor = 'Outdoor and Decor';

/// The parasol's radius (Ø 2700).
const double _parasol = 1350;

/// Outdoor and Decor, in palette order. Each base point is the outline's
/// centre.
final List<FurnitureSymbol> outdoorCatalog = [
  // A Ø 2700 canopy, its eight spokes from the Ø 100 pole.
  FurnitureSymbol(
    key: 'restaurant.parasol',
    name: 'Parasol',
    category: outdoorAndDecor,
    tags: const ['parasol', 'umbrella', 'terrace', 'outdoor'],
    baseX: _parasol,
    baseY: _parasol,
    shapes: [
      const CircleShape(_parasol, _parasol, _parasol),
      const CircleShape(_parasol, _parasol, 50),
      for (var i = 0; i < 8; i++)
        LineShape(
          _parasol + 50 * _cos(i),
          _parasol + 50 * _sin(i),
          _parasol + _parasol * _cos(i),
          _parasol + _parasol * _sin(i),
        ),
    ],
  ),
  const FurnitureSymbol(
    key: 'restaurant.heater',
    name: 'Patio heater',
    category: outdoorAndDecor,
    tags: ['heater', 'patio', 'outdoor'],
    baseX: 250,
    baseY: 250,
    shapes: [CircleShape(250, 250, 250), CircleShape(250, 250, 100)],
  ),
  const FurnitureSymbol(
    key: 'restaurant.planter.round',
    name: 'Round planter',
    category: outdoorAndDecor,
    tags: ['planter', 'plant', 'pot', 'round'],
    baseX: 300,
    baseY: 300,
    shapes: [CircleShape(300, 300, 300), CircleShape(300, 300, 225)],
  ),
  FurnitureSymbol(
    key: 'restaurant.planter.long',
    name: 'Long planter',
    category: outdoorAndDecor,
    tags: const ['planter', 'plant', 'trough'],
    baseX: 600,
    baseY: 200,
    shapes: [rect(0, 0, 1200, 400), inset(0, 0, 1200, 400, 50)],
  ),
  FurnitureSymbol(
    key: 'restaurant.partition',
    name: 'Partition',
    category: outdoorAndDecor,
    tags: const ['partition', 'divider', 'screen'],
    baseX: 750,
    baseY: 50,
    shapes: [rect(0, 0, 1500, 100)],
  ),
  // A 3000 x 2000 stage with its front edge 100 in.
  FurnitureSymbol(
    key: 'restaurant.stage',
    name: 'Stage',
    category: outdoorAndDecor,
    tags: const ['stage', 'platform', 'music'],
    baseX: 1500,
    baseY: 1000,
    shapes: [rect(0, 0, 3000, 2000), const LineShape(0, 100, 3000, 100)],
  ),
  // A 1500 x 700 booth with two Ø 300 decks.
  FurnitureSymbol(
    key: 'restaurant.dj.booth',
    name: 'DJ booth',
    category: outdoorAndDecor,
    tags: const ['dj', 'booth', 'music'],
    baseX: 750,
    baseY: 350,
    shapes: [
      rect(0, 0, 1500, 700),
      const CircleShape(400, 400, 150),
      const CircleShape(1100, 400, 150),
    ],
  ),
  // A grand piano, 1500 wide and 1600 long: the keyboard (1500 x 300) at
  // the front and the body behind it, its curved side drawn as a polyline.
  FurnitureSymbol(
    key: 'restaurant.piano',
    name: 'Grand piano',
    category: outdoorAndDecor,
    tags: const ['piano', 'grand', 'music'],
    baseX: 750,
    baseY: 800,
    shapes: [
      poly(const [
        (0, 300),
        (1500, 300),
        (1500, 900),
        (1300, 1250),
        (950, 1500),
        (600, 1600),
        (0, 1600),
      ]),
      rect(0, 0, 1500, 300),
    ],
  ),
];

double _cos(int i) => _round(math.cos(math.pi / 4 * i));
double _sin(int i) => _round(math.sin(math.pi / 4 * i));

/// A unit-circle coordinate without its floating-point dust.
double _round(double v) {
  final r = (v * 1e12).roundToDouble() / 1e12;
  return r == 0 ? 0 : r;
}
