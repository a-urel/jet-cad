// Booths and Lounge (ported from jet_cad_restaurant_symbols' booths.dart):
// booths, banquettes and lounge sets. The first leaf is the table top;
// benches and sofas follow.
//
// Pure Dart: no Flutter, no dart:io.
import 'dart:math' as math;

import 'package:jet_cad_2d_kit/authoring.dart';

/// The palette category of this file's symbols.
const String boothsAndLounge = 'Booths and Lounge';

/// A booth bench's depth, its back's depth, and how far it reaches under the
/// table's edge (the chairs' tuck).
const double _benchDepth = 600;
const double _benchBack = 150;

CatalogLine _line(double x1, double y1, double x2, double y2) =>
    CatalogLine((x1, y1), (x2, y2));

/// A [len]-long bench with its back on the far side from the table, its
/// near edge [chairTuck] under the table edge at [edgeY], below the table
/// when [below] (back at the bottom), above it otherwise.
List<CatalogShape> _benchH(double x, double edgeY, double len,
    {required bool below}) {
  final y = below ? edgeY + chairTuck - _benchDepth : edgeY - chairTuck;
  final back = below ? y + _benchBack : y + _benchDepth - _benchBack;
  return [rect(x, y, len, _benchDepth), _line(x, back, x + len, back)];
}

/// A booth: a [w] x [h] top between two benches as long as the top.
CatalogSymbol _booth(String key, String name, double w, double h,
    {required List<String> tags}) {
  const oy = _benchDepth - chairTuck; // 500: the lower bench starts at 0
  return CatalogSymbol(
    key: key,
    name: name,
    category: boothsAndLounge,
    tags: tags,
    base: (w / 2, oy + h / 2),
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
CatalogSymbol _banquette(
    String key, String name, double w, double h, int chairs,
    {required List<String> tags}) {
  const c = chairSize / 2 - chairTuck;
  const oy = chairSize - chairTuck; // 350: the chairs start at 0
  return CatalogSymbol(
    key: key,
    name: name,
    category: boothsAndLounge,
    tags: tags,
    base: (w / 2, oy + h / 2),
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
final List<CatalogSymbol> boothsCatalog = [
  _booth('restaurant.booth.two', 'Booth, 2 seats', 700, 700,
      tags: const ['booth', 'table', 'two']),
  _booth('restaurant.booth.four', 'Booth, 4 seats', 1200, 700,
      tags: const ['booth', 'table', 'four']),
  _booth('restaurant.booth.six', 'Booth, 6 seats', 1800, 750,
      tags: const ['booth', 'table', 'six']),
  // A 1200 x 800 top; an L bench on its left and top sides; one chair on
  // its right. The top's lower-left corner is at (500, 0): the left bench
  // runs from x 0 to 600, 100 under the top's left edge.
  CatalogSymbol(
    key: 'restaurant.booth.corner',
    name: 'Corner booth, 5 seats',
    category: boothsAndLounge,
    tags: const ['booth', 'corner', 'table', 'five'],
    base: (1100, 400),
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
      _line(150, 0, 150, 1150),
      _line(150, 1150, 1700, 1150),
      ...chairAt(1700 + chairSize / 2 - chairTuck, 400, math.pi),
    ],
  ),
  // A Ø 1200 top in a half-ring bench open at the bottom: the ring from
  // radius 500 (100 under the top's edge) to 1100, its back arc at 950.
  const CatalogSymbol(
    key: 'restaurant.booth.round',
    name: 'Round booth, 6 seats',
    category: boothsAndLounge,
    tags: ['booth', 'round', 'table', 'six'],
    base: (1100, 600),
    shapes: [
      CatalogCircle((1100, 600), 600),
      CatalogCircle((1100, 600), 550),
      CatalogArc((1100, 600), 500, 0, math.pi),
      CatalogArc((1100, 600), 1100, 0, math.pi),
      CatalogLine((1600, 600), (2200, 600)),
      CatalogLine((0, 600), (600, 600)),
      CatalogArc((1100, 600), 950, 0, math.pi),
    ],
  ),
  _banquette('restaurant.banquette.two', 'Banquette, 2 seats', 700, 700, 1,
      tags: const ['banquette', 'table', 'two']),
  _banquette('restaurant.banquette.four', 'Banquette, 4 seats', 1400, 700, 2,
      tags: const ['banquette', 'table', 'four']),
  // A 1000 x 600 low table; a three-seat sofa (2000 x 850) above it, 300
  // clear; an armchair (850 x 850) to its right, 300 clear.
  CatalogSymbol(
    key: 'restaurant.lounge.four',
    name: 'Lounge set, 4 seats',
    category: boothsAndLounge,
    tags: const ['lounge', 'sofa', 'table', 'four'],
    base: (1000, 300),
    shapes: [
      rect(500, 0, 1000, 600),
      inset(500, 0, 1000, 600, 40),
      // The sofa: its outline, its back line, its two arm lines.
      rect(0, 900, 2000, 850),
      _line(0, 1550, 2000, 1550),
      _line(200, 900, 200, 1550),
      _line(1800, 900, 1800, 1550),
      // The armchair, back to the right.
      rect(1800, -125, 850, 850),
      _line(2450, -125, 2450, 725),
    ],
  ),
  // A Ø 600 low table between two 750 x 750 armchairs, 250 clear each side.
  CatalogSymbol(
    key: 'restaurant.lounge.two',
    name: 'Lounge set, 2 seats',
    category: boothsAndLounge,
    tags: const ['lounge', 'armchair', 'table', 'two'],
    base: (1300, 375),
    shapes: [
      const CatalogCircle((1300, 375), 300),
      const CatalogCircle((1300, 375), 260),
      rect(0, 0, 750, 750),
      _line(150, 0, 150, 750),
      rect(1850, 0, 750, 750),
      _line(2450, 0, 2450, 750),
    ],
  ),
];
