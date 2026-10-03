// Booths and Lounge (spec 14 V-6): booths, banquettes and lounge sets, every
// one servable. The first leaf is the table top; benches and sofas follow.
import 'dart:math' as math;

import 'package:jet_cad_floor_plan/symbols.dart';

import 'shapes.dart';

/// The palette category of this file's symbols.
const String boothsAndLounge = 'Booths and Lounge';

/// A booth bench's depth, its back's depth, and how far it reaches under the
/// table's edge (the chairs' tuck).
const double benchDepth = 600;
const double benchBack = 150;

/// A [len]-long bench with its back on the far side from the table, its
/// near edge [chairTuck] under the table edge at [edgeY], below the table
/// when [below] (back at the bottom), above it otherwise.
List<FurnitureShape> _benchH(double x, double edgeY, double len,
    {required bool below}) {
  final y = below ? edgeY + chairTuck - benchDepth : edgeY - chairTuck;
  final back = below ? y + benchBack : y + benchDepth - benchBack;
  return [rect(x, y, len, benchDepth), LineShape(x, back, x + len, back)];
}

/// A booth: a [w] x [h] top between two benches as long as the top.
FurnitureSymbol booth(String key, String name, double w, double h, int seats,
    {required List<String> tags}) {
  const oy = benchDepth - chairTuck; // 500: the lower bench starts at 0
  return FurnitureSymbol(
    key: key,
    name: name,
    category: boothsAndLounge,
    tags: tags,
    seats: seats,
    baseX: w / 2,
    baseY: oy + h / 2,
    shapes: [
      rect(0, oy, w, h),
      inset(0, oy, w, h, 50),
      ..._benchH(0, oy, w, below: true),
      ..._benchH(0, oy + h, w, below: false),
    ],
  );
}

/// A banquette: a [w] x [h] top with a wall bench behind it (above) and
/// [chairs] chairs in front (below), spaced evenly.
FurnitureSymbol banquette(
    String key, String name, double w, double h, int chairs,
    {required List<String> tags}) {
  const c = chairSize / 2 - chairTuck;
  const oy = chairSize - chairTuck; // 350: the chairs start at 0
  return FurnitureSymbol(
    key: key,
    name: name,
    category: boothsAndLounge,
    tags: tags,
    seats: 2 * chairs,
    baseX: w / 2,
    baseY: oy + h / 2,
    shapes: [
      rect(0, oy, w, h),
      inset(0, oy, w, h, 50),
      ..._benchH(0, oy + h, w, below: false),
      for (var i = 0; i < chairs; i++)
        ...chairAt(w / chairs * (i + 0.5), oy - c, math.pi / 2),
    ],
  );
}

/// Booths and Lounge, in palette order.
final List<FurnitureSymbol> boothsCatalog = [
  booth('restaurant.booth.two', 'Booth, 2 seats', 700, 700, 2,
      tags: const ['booth', 'table', 'two']),
  booth('restaurant.booth.four', 'Booth, 4 seats', 1200, 700, 4,
      tags: const ['booth', 'table', 'four']),
  booth('restaurant.booth.six', 'Booth, 6 seats', 1800, 750, 6,
      tags: const ['booth', 'table', 'six']),
  // A 1200 x 800 top; an L bench on its left and top sides; one chair on
  // its right. The top's lower-left corner is at (500, 0): the left bench
  // runs from x 0 to 600, 100 under the top's left edge.
  FurnitureSymbol(
    key: 'restaurant.booth.corner',
    name: 'Corner booth, 5 seats',
    category: boothsAndLounge,
    tags: const ['booth', 'corner', 'table', 'five'],
    seats: 5,
    baseX: 1100,
    baseY: 400,
    shapes: [
      rect(500, 0, 1200, 800),
      inset(500, 0, 1200, 800, 50),
      // The L bench: along the left side (x 0..600, y 0..1300) and the top
      // (y 700..1300, x 0..1700), one closed outline.
      poly(const [
        (0, 0),
        (600, 0),
        (600, 700),
        (1700, 700),
        (1700, 1300),
        (0, 1300),
      ]),
      // Its back: 150 in from the outer edges.
      const LineShape(150, 0, 150, 1150),
      const LineShape(150, 1150, 1700, 1150),
      ...chairAt(1700 + chairSize / 2 - chairTuck, 400, math.pi),
    ],
  ),
  // A Ø 1200 top in a half-ring bench open at the bottom: the ring from
  // radius 500 (100 under the top's edge) to 1100, its back arc at 950.
  FurnitureSymbol(
    key: 'restaurant.booth.round',
    name: 'Round booth, 6 seats',
    category: boothsAndLounge,
    tags: const ['booth', 'round', 'table', 'six'],
    seats: 6,
    baseX: 1100,
    baseY: 600,
    shapes: const [
      CircleShape(1100, 600, 600),
      CircleShape(1100, 600, 550),
      ArcShape(1100, 600, 500, 0, math.pi),
      ArcShape(1100, 600, 1100, 0, math.pi),
      LineShape(1600, 600, 2200, 600),
      LineShape(0, 600, 600, 600),
      ArcShape(1100, 600, 950, 0, math.pi),
    ],
  ),
  banquette('restaurant.banquette.two', 'Banquette, 2 seats', 700, 700, 1,
      tags: const ['banquette', 'table', 'two']),
  banquette('restaurant.banquette.four', 'Banquette, 4 seats', 1400, 700, 2,
      tags: const ['banquette', 'table', 'four']),
  // A 1000 x 600 low table; a three-seat sofa (2000 x 850) above it, 300
  // clear; an armchair (850 x 850) to its right, 300 clear.
  FurnitureSymbol(
    key: 'restaurant.lounge.four',
    name: 'Lounge set, 4 seats',
    category: boothsAndLounge,
    tags: const ['lounge', 'sofa', 'table', 'four'],
    seats: 4,
    baseX: 1000,
    baseY: 300,
    shapes: [
      rect(500, 0, 1000, 600),
      inset(500, 0, 1000, 600, 40),
      // The sofa: its outline, its back line, its two arm lines.
      rect(0, 900, 2000, 850),
      const LineShape(0, 1550, 2000, 1550),
      const LineShape(200, 900, 200, 1550),
      const LineShape(1800, 900, 1800, 1550),
      // The armchair, back to the right.
      rect(1800, -125, 850, 850),
      const LineShape(2450, -125, 2450, 725),
    ],
  ),
  // A Ø 600 low table between two 750 x 750 armchairs, 250 clear each side.
  FurnitureSymbol(
    key: 'restaurant.lounge.two',
    name: 'Lounge set, 2 seats',
    category: boothsAndLounge,
    tags: const ['lounge', 'armchair', 'table', 'two'],
    seats: 2,
    baseX: 1300,
    baseY: 375,
    shapes: [
      const CircleShape(1300, 375, 300),
      const CircleShape(1300, 375, 260),
      rect(0, 0, 750, 750),
      const LineShape(150, 0, 150, 750),
      rect(1850, 0, 750, 750),
      const LineShape(2450, 0, 2450, 750),
    ],
  ),
];
