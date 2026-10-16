// Service (ported from jet_cad_restaurant_symbols' service.dart): the
// front-of-house fixtures.
//
// Pure Dart: no Flutter, no dart:io.
import 'package:jet_cad_2d_kit/authoring.dart';

/// The palette category of this file's symbols.
const String service = 'Service';

CatalogLine _line(double x1, double y1, double x2, double y2) =>
    CatalogLine((x1, y1), (x2, y2));

/// Service, in palette order. Each base point is its outline's centre.
final List<CatalogSymbol> serviceCatalog = [
  // A 1400 x 700 desk with a 400 x 300 register on it.
  CatalogSymbol(
    key: 'restaurant.cashier.desk',
    name: 'Cashier desk',
    category: service,
    tags: const ['cashier', 'register', 'desk', 'checkout'],
    base: (700, 350),
    shapes: [rect(0, 0, 1400, 700), rect(900, 300, 400, 300)],
  ),
  CatalogSymbol(
    key: 'restaurant.host.stand',
    name: 'Host stand',
    category: service,
    tags: const ['host', 'stand', 'reception'],
    base: (300, 225),
    shapes: [rect(0, 0, 600, 450), inset(0, 0, 600, 450, 40)],
  ),
  // A 400 x 400 stand with a 300 x 200 screen.
  CatalogSymbol(
    key: 'restaurant.pos.terminal',
    name: 'POS terminal',
    category: service,
    tags: const ['pos', 'terminal', 'register'],
    base: (200, 200),
    shapes: [rect(0, 0, 400, 400), rect(50, 150, 300, 200)],
  ),
  // A 1200 x 600 station with two drawer lines.
  CatalogSymbol(
    key: 'restaurant.service.station',
    name: 'Service station',
    category: service,
    tags: const ['service', 'station', 'waiter'],
    base: (600, 300),
    shapes: [
      rect(0, 0, 1200, 600),
      _line(400, 0, 400, 600),
      _line(800, 0, 800, 600),
    ],
  ),
  // A 2400 x 800 counter with four 500 x 500 trays, 80 apart.
  CatalogSymbol(
    key: 'restaurant.buffet.counter',
    name: 'Buffet counter',
    category: service,
    tags: const ['buffet', 'counter', 'trays'],
    base: (1200, 400),
    shapes: [
      rect(0, 0, 2400, 800),
      for (var i = 0; i < 4; i++) rect(80.0 + 580 * i, 150, 500, 500),
    ],
  ),
  // A 1800 x 900 salad bar: a sneeze-guard line down its middle and three
  // 250 x 250 wells on each side.
  CatalogSymbol(
    key: 'restaurant.salad.bar',
    name: 'Salad bar',
    category: service,
    tags: const ['salad', 'bar', 'buffet'],
    base: (900, 450),
    shapes: [
      rect(0, 0, 1800, 900),
      _line(0, 450, 1800, 450),
      for (final y in const [100.0, 550.0])
        for (final x in const [200.0, 775.0, 1350.0]) rect(x, y, 250, 250),
    ],
  ),
  // A 1200 x 500 cabinet with a curved glass front bulging 200 forward
  // (an arc of radius 1000 through the front corners, centred 800 behind
  // the front edge).
  CatalogSymbol(
    key: 'restaurant.dessert.display',
    name: 'Dessert display',
    category: service,
    tags: const ['dessert', 'display', 'cabinet', 'showcase'],
    base: (600, 250),
    shapes: [
      rect(0, 0, 1200, 500),
      const CatalogArc((600, 800), 1000, 4.068887871591405, 1.2870022175865687),
    ],
  ),
  CatalogSymbol(
    key: 'restaurant.drinks.fridge',
    name: 'Drinks fridge',
    category: service,
    tags: const ['fridge', 'drinks', 'cooler'],
    base: (350, 350),
    shapes: [rect(0, 0, 700, 700), _line(0, 60, 700, 60)],
  ),
  // A 1500 x 650 counter with a 600 x 450 machine and a grinder.
  CatalogSymbol(
    key: 'restaurant.coffee.station',
    name: 'Coffee station',
    category: service,
    tags: const ['coffee', 'espresso', 'station'],
    base: (750, 325),
    shapes: [
      rect(0, 0, 1500, 650),
      rect(100, 100, 600, 450),
      const CatalogCircle((1000, 325), 120),
    ],
  ),
  CatalogSymbol(
    key: 'restaurant.service.cart',
    name: 'Service cart',
    category: service,
    tags: const ['cart', 'trolley', 'service'],
    base: (450, 250),
    shapes: [rect(0, 0, 900, 500), inset(0, 0, 900, 500, 40)],
  ),
  // A folding tray stand: its 550 x 400 outline and the crossed legs.
  CatalogSymbol(
    key: 'restaurant.tray.stand',
    name: 'Tray stand',
    category: service,
    tags: const ['tray', 'stand', 'folding'],
    base: (275, 200),
    shapes: [
      rect(0, 0, 550, 400),
      _line(0, 0, 550, 400),
      _line(0, 400, 550, 0),
    ],
  ),
  // A 500 x 550 highchair with its tray line.
  CatalogSymbol(
    key: 'restaurant.highchair.child',
    name: 'Highchair',
    category: service,
    tags: const ['highchair', 'child', 'baby', 'chair'],
    base: (250, 275),
    shapes: [rect(0, 0, 500, 550), _line(0, 450, 500, 450)],
  ),
  // A 1500 x 450 bench with its back line.
  CatalogSymbol(
    key: 'restaurant.waiting.bench',
    name: 'Waiting bench',
    category: service,
    tags: const ['bench', 'waiting', 'lobby'],
    base: (750, 225),
    shapes: [rect(0, 0, 1500, 450), _line(0, 380, 1500, 380)],
  ),
  const CatalogSymbol(
    key: 'restaurant.coat.rack',
    name: 'Coat rack',
    category: service,
    tags: ['coat', 'rack', 'cloakroom'],
    base: (250, 250),
    shapes: [CatalogCircle((250, 250), 250), CatalogCircle((250, 250), 40)],
  ),
];
