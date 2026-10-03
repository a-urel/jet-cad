// Service (spec 14 V-6): the front-of-house fixtures. None is servable.
import 'package:jet_cad_floor_plan/symbols.dart';

import 'shapes.dart';

/// The palette category of this file's symbols.
const String service = 'Service';

/// Service, in palette order. Each base point is its outline's centre.
final List<FurnitureSymbol> serviceCatalog = [
  // A 1400 x 700 desk with a 400 x 300 register on it.
  FurnitureSymbol(
    key: 'restaurant.cashier',
    name: 'Cashier desk',
    category: service,
    tags: const ['cashier', 'register', 'desk', 'checkout'],
    baseX: 700,
    baseY: 350,
    shapes: [rect(0, 0, 1400, 700), rect(900, 300, 400, 300)],
  ),
  FurnitureSymbol(
    key: 'restaurant.host.stand',
    name: 'Host stand',
    category: service,
    tags: const ['host', 'stand', 'reception'],
    baseX: 300,
    baseY: 225,
    shapes: [rect(0, 0, 600, 450), inset(0, 0, 600, 450, 40)],
  ),
  // A 400 x 400 stand with a 300 x 200 screen.
  FurnitureSymbol(
    key: 'restaurant.pos.terminal',
    name: 'POS terminal',
    category: service,
    tags: const ['pos', 'terminal', 'register'],
    baseX: 200,
    baseY: 200,
    shapes: [rect(0, 0, 400, 400), rect(50, 150, 300, 200)],
  ),
  // A 1200 x 600 station with two drawer lines.
  FurnitureSymbol(
    key: 'restaurant.service.station',
    name: 'Service station',
    category: service,
    tags: const ['service', 'station', 'waiter'],
    baseX: 600,
    baseY: 300,
    shapes: [
      rect(0, 0, 1200, 600),
      const LineShape(400, 0, 400, 600),
      const LineShape(800, 0, 800, 600),
    ],
  ),
  // A 2400 x 800 counter with four 500 x 500 trays, 80 apart.
  FurnitureSymbol(
    key: 'restaurant.buffet',
    name: 'Buffet counter',
    category: service,
    tags: const ['buffet', 'counter', 'trays'],
    baseX: 1200,
    baseY: 400,
    shapes: [
      rect(0, 0, 2400, 800),
      for (var i = 0; i < 4; i++) rect(80.0 + 580 * i, 150, 500, 500),
    ],
  ),
  // A 1800 x 900 salad bar: a sneeze-guard line down its middle and three
  // 250 x 250 wells on each side.
  FurnitureSymbol(
    key: 'restaurant.salad.bar',
    name: 'Salad bar',
    category: service,
    tags: const ['salad', 'bar', 'buffet'],
    baseX: 900,
    baseY: 450,
    shapes: [
      rect(0, 0, 1800, 900),
      const LineShape(0, 450, 1800, 450),
      for (final y in const [100.0, 550.0])
        for (final x in const [200.0, 775.0, 1350.0]) rect(x, y, 250, 250),
    ],
  ),
  // A 1200 x 500 cabinet with a curved glass front bulging 200 forward
  // (an arc of radius 1000 through the front corners, centred 800 behind
  // the front edge).
  FurnitureSymbol(
    key: 'restaurant.dessert.display',
    name: 'Dessert display',
    category: service,
    tags: const ['dessert', 'display', 'cabinet', 'showcase'],
    baseX: 600,
    baseY: 250,
    shapes: [
      rect(0, 0, 1200, 500),
      const ArcShape(600, 800, 1000, 4.068887871591405, 1.2870022175865687),
    ],
  ),
  FurnitureSymbol(
    key: 'restaurant.drinks.fridge',
    name: 'Drinks fridge',
    category: service,
    tags: const ['fridge', 'drinks', 'cooler'],
    baseX: 350,
    baseY: 350,
    shapes: [rect(0, 0, 700, 700), const LineShape(0, 60, 700, 60)],
  ),
  // A 1500 x 650 counter with a 600 x 450 machine and a grinder.
  FurnitureSymbol(
    key: 'restaurant.coffee.station',
    name: 'Coffee station',
    category: service,
    tags: const ['coffee', 'espresso', 'station'],
    baseX: 750,
    baseY: 325,
    shapes: [
      rect(0, 0, 1500, 650),
      rect(100, 100, 600, 450),
      const CircleShape(1000, 325, 120),
    ],
  ),
  FurnitureSymbol(
    key: 'restaurant.service.cart',
    name: 'Service cart',
    category: service,
    tags: const ['cart', 'trolley', 'service'],
    baseX: 450,
    baseY: 250,
    shapes: [rect(0, 0, 900, 500), inset(0, 0, 900, 500, 40)],
  ),
  // A folding tray stand: its 550 x 400 outline and the crossed legs.
  FurnitureSymbol(
    key: 'restaurant.tray.stand',
    name: 'Tray stand',
    category: service,
    tags: const ['tray', 'stand', 'folding'],
    baseX: 275,
    baseY: 200,
    shapes: [
      rect(0, 0, 550, 400),
      const LineShape(0, 0, 550, 400),
      const LineShape(0, 400, 550, 0),
    ],
  ),
  // A 500 x 550 highchair with its tray line.
  FurnitureSymbol(
    key: 'restaurant.highchair',
    name: 'Highchair',
    category: service,
    tags: const ['highchair', 'child', 'baby', 'chair'],
    baseX: 250,
    baseY: 275,
    shapes: [rect(0, 0, 500, 550), const LineShape(0, 450, 500, 450)],
  ),
  // A 1500 x 450 bench with its back line.
  FurnitureSymbol(
    key: 'restaurant.waiting.bench',
    name: 'Waiting bench',
    category: service,
    tags: const ['bench', 'waiting', 'lobby'],
    baseX: 750,
    baseY: 225,
    shapes: [rect(0, 0, 1500, 450), const LineShape(0, 380, 1500, 380)],
  ),
  FurnitureSymbol(
    key: 'restaurant.coat.rack',
    name: 'Coat rack',
    category: service,
    tags: const ['coat', 'rack', 'cloakroom'],
    baseX: 250,
    baseY: 250,
    shapes: const [CircleShape(250, 250, 250), CircleShape(250, 250, 40)],
  ),
];
