// Outdoor and Decor (ported from jet_cad_restaurant_symbols' outdoor.dart):
// terrace and room furnishings.
//
// Pure Dart: no Flutter, no dart:io.
import 'dart:math' as math;

import 'package:jet_cad_2d_kit/authoring.dart';

/// The palette category of this file's symbols.
const String outdoorAndDecor = 'Outdoor and Decor';

/// The parasol's radius (Ø 2700).
const double _parasol = 1350;

CatalogLine _line(double x1, double y1, double x2, double y2) =>
    CatalogLine((x1, y1), (x2, y2));

/// Outdoor and Decor, in palette order. Each base point is the outline's
/// centre.
final List<CatalogSymbol> outdoorCatalog = [
  // A Ø 2700 canopy, its eight spokes from the Ø 100 pole.
  CatalogSymbol(
    key: 'restaurant.parasol.round',
    name: 'Parasol',
    category: outdoorAndDecor,
    tags: const ['parasol', 'umbrella', 'terrace', 'outdoor'],
    base: (_parasol, _parasol),
    shapes: [
      const CatalogCircle((_parasol, _parasol), _parasol),
      const CatalogCircle((_parasol, _parasol), 50),
      for (var i = 0; i < 8; i++)
        _line(
          _parasol + 50 * _cos(i),
          _parasol + 50 * _sin(i),
          _parasol + _parasol * _cos(i),
          _parasol + _parasol * _sin(i),
        ),
    ],
  ),
  const CatalogSymbol(
    key: 'restaurant.heater.patio',
    name: 'Patio heater',
    category: outdoorAndDecor,
    tags: ['heater', 'patio', 'outdoor'],
    base: (250, 250),
    shapes: [CatalogCircle((250, 250), 250), CatalogCircle((250, 250), 100)],
  ),
  const CatalogSymbol(
    key: 'restaurant.planter.round',
    name: 'Round planter',
    category: outdoorAndDecor,
    tags: ['planter', 'plant', 'pot', 'round'],
    base: (300, 300),
    shapes: [CatalogCircle((300, 300), 300), CatalogCircle((300, 300), 225)],
  ),
  CatalogSymbol(
    key: 'restaurant.planter.long',
    name: 'Long planter',
    category: outdoorAndDecor,
    tags: const ['planter', 'plant', 'trough'],
    base: (600, 200),
    shapes: [rect(0, 0, 1200, 400), inset(0, 0, 1200, 400, 50)],
  ),
  CatalogSymbol(
    key: 'restaurant.partition.screen',
    name: 'Partition',
    category: outdoorAndDecor,
    tags: const ['partition', 'divider', 'screen'],
    base: (750, 50),
    shapes: [rect(0, 0, 1500, 100)],
  ),
  // A 3000 x 2000 stage with its front edge 100 in.
  CatalogSymbol(
    key: 'restaurant.stage.platform',
    name: 'Stage',
    category: outdoorAndDecor,
    tags: const ['stage', 'platform', 'music'],
    base: (1500, 1000),
    shapes: [rect(0, 0, 3000, 2000), _line(0, 100, 3000, 100)],
  ),
  // A 1500 x 700 booth with two Ø 300 decks.
  CatalogSymbol(
    key: 'restaurant.dj.booth',
    name: 'DJ booth',
    category: outdoorAndDecor,
    tags: const ['dj', 'booth', 'music'],
    base: (750, 350),
    shapes: [
      rect(0, 0, 1500, 700),
      const CatalogCircle((400, 400), 150),
      const CatalogCircle((1100, 400), 150),
    ],
  ),
  // A grand piano, 1500 wide and 1600 long: the keyboard (1500 x 300) at
  // the front and the body behind it, its curved side drawn as a polyline.
  CatalogSymbol(
    key: 'restaurant.piano.grand',
    name: 'Grand piano',
    category: outdoorAndDecor,
    tags: const ['piano', 'grand', 'music'],
    base: (750, 800),
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
