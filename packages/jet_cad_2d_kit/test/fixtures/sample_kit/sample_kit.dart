// The sample kit (spec K7, "Tests"): a stand-in for the architecture and
// restaurant kits of sub-projects 3 and 4. Every shape kind, both unit
// kinds and labellings, attachment kinds and a family, the shape helpers,
// two declared locales, everything off the origin.
import 'dart:math' as math;

import 'package:jet_cad_2d_kit/authoring.dart';

const String tables = 'Tables';
const String bar = 'Bar';
const String bedroom = 'Bedroom';

final List<CatalogSymbol> sampleSymbols = [
  CatalogSymbol(
    key: 'sample.table.round-four',
    name: 'Round table, 4 seats',
    category: tables,
    tags: const ['table', 'round', 'four'],
    unit: const CatalogUnit(kind: UnitKinds.table, capacity: 4),
    base: (2000, 1500),
    shapes: [
      const CatalogCircle((2000, 1500), 450),
      ...chairsAround(2000, 1500, 450, 4),
    ],
  ),
  CatalogSymbol(
    key: 'sample.table.rect-two',
    version: 2,
    name: 'Rectangular table, 2 seats',
    category: tables,
    tags: const ['table', 'rectangular', 'two'],
    unit: const CatalogUnit(kind: UnitKinds.table, capacity: 2),
    base: (1400, 1100),
    shapes: [
      rect(1000, 800, 800, 600),
      inset(1000, 800, 800, 600, 50),
      ...chairAt(1400, 675, math.pi / 2),
      ...chairAt(1400, 1525, -math.pi / 2),
    ],
  ),
  CatalogSymbol(
    key: 'sample.stool.bar',
    name: 'Bar stool',
    category: bar,
    tags: const ['stool', 'bar', 'seat'],
    unit: const CatalogUnit(
        kind: UnitKinds.seat, capacity: 1, labelling: UnitLabelling.assigned),
    base: (640, 410),
    shapes: [
      ...stoolAt(640, 410),
      const CatalogArc((640, 410), 230, 0.4, 2.3),
    ],
  ),
  CatalogSymbol(
    key: 'sample.bed.double',
    name: 'Double bed',
    category: bedroom,
    tags: const ['bed', 'double', 'sleeping'],
    attachTo: const ['wall-face'],
    family: 'bed-double',
    base: (900, 1050),
    shapes: [
      rect(100, 50, 1600, 2000),
      const CatalogLine((100, 1350), (1700, 1350)),
      rect(200, 1750, 650, 240),
      rect(950, 1750, 650, 240),
    ],
  ),
];

final Catalog sampleCatalog = Catalog(kit: 'sample', symbols: sampleSymbols);

const List<String> sampleLocales = ['de', 'tr'];

/// "Bar" is the right word for a bar in German and in Turkish.
const Map<String, Set<String>> sampleSameAsEnglish = {
  'de': {'category:sample/Bar'},
  'tr': {'category:sample/Bar'},
};

const KitNames sampleNames = KitNames({
  'de': {
    'symbol:sample.table.round-four': 'Runder Tisch, 4 Plätze',
    'symbol:sample.table.rect-two': 'Rechteckiger Tisch, 2 Plätze',
    'symbol:sample.stool.bar': 'Barhocker',
    'symbol:sample.bed.double': 'Doppelbett',
    'category:sample/Tables': 'Tische',
    'category:sample/Bar': 'Bar',
    'category:sample/Bedroom': 'Schlafzimmer',
  },
  'tr': {
    'symbol:sample.table.round-four': 'Yuvarlak masa, 4 kişilik',
    'symbol:sample.table.rect-two': 'Dikdörtgen masa, 2 kişilik',
    'symbol:sample.stool.bar': 'Bar taburesi',
    'symbol:sample.bed.double': 'Çift kişilik yatak',
    'category:sample/Tables': 'Masalar',
    'category:sample/Bar': 'Bar',
    'category:sample/Bedroom': 'Yatak odası',
  },
});
