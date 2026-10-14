// Spec K6: the builder. Deterministic, handles in catalog order, every shape
// kind round-trips through decode, a unit's components, and the format's
// refusals reach the generator. Off the origin, an arc with a negative
// sweep, a seat unit with assigned labels (umbrella A6).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/authoring.dart';

const CatalogSymbol table = CatalogSymbol(
  key: 'sample.table.round-two',
  version: 2,
  name: 'Round table, 2 seats',
  category: 'Tables',
  tags: ['table', 'round', 'two'],
  unit: CatalogUnit(kind: UnitKinds.table, capacity: 2),
  base: (1800, 950),
  shapes: [
    CatalogCircle((1800, 950), 400),
    CatalogPolyline([(1575, 325), (2025, 325), (2025, 775), (1575, 775)],
        closed: true),
    CatalogLine((1575, 385), (2025, 385)),
  ],
);

const CatalogSymbol lamp = CatalogSymbol(
  key: 'sample.lamp.wall',
  name: 'Wall lamp',
  category: 'Lighting',
  tags: ['lamp', 'light'],
  attachTo: ['wall-face'],
  family: 'lamp-wall',
  base: (640, 220),
  shapes: [
    CatalogArc((640, 220), 180, 0.25, -2.75),
    CatalogPolyline([(460, 220), (820, 220), (700, 90)]),
  ],
);

const CatalogSymbol seat = CatalogSymbol(
  key: 'sample.seat.row-end',
  name: 'Row-end seat',
  category: 'Seats',
  tags: ['seat'],
  unit: CatalogUnit(
      kind: UnitKinds.seat, capacity: 1, labelling: UnitLabelling.assigned),
  base: (300, 260),
  shapes: [
    CatalogPolyline([(80, 60), (520, 60), (520, 480), (80, 480)], closed: true),
    CatalogLine((80, 120), (520, 120)),
  ],
);

const Catalog catalog = Catalog(kit: 'sample', symbols: [table, lamp, seat]);

void main() {
  test('B1 deterministic: two builds give the same bytes', () {
    // M-B1: allocate handles from a random start.
    expect(encodeLibrary(catalog), encodeLibrary(catalog));
    const again = Catalog(kit: 'sample', symbols: [table, lamp, seat]);
    expect(encodeLibrary(again), encodeLibrary(catalog));
  });

  test('B2 handles ascend: a definition, its leaves, the next definition', () {
    final doc = buildLibraryDocument(catalog);
    addTearDown(doc.dispose);
    final defs = [for (final d in doc.tree.definitions) d.handle.value];
    expect(defs, hasLength(3));
    // M-B2: allocate every definition first, then the leaves.
    expect(defs[1], defs[0] + table.shapes.length + 1);
    expect(defs[2], defs[1] + lamp.shapes.length + 1);
    final names = [for (final d in doc.tree.definitions) d.name];
    expect(names, [
      'sample.table.round-two@2',
      'sample.lamp.wall@1',
      'sample.seat.row-end@1',
    ]);
    final leaves = [
      for (final slot in doc.entities.liveSlots) doc.entities.read(slot),
    ];
    expect([
      for (final r in leaves) r.handle.value
    ], [
      for (var i = 0; i < 3; i++) defs[0] + 1 + i,
      for (var i = 0; i < 2; i++) defs[1] + 1 + i,
      for (var i = 0; i < 2; i++) defs[2] + 1 + i,
    ]);
    expect([
      for (final r in leaves) r.owner.value
    ], [
      defs[0], defs[0], defs[0], defs[1], defs[1], defs[2], defs[2], //
    ]);
  });

  test('B3 every shape kind and every field round-trips through decode', () {
    final library = SymbolLibrary.decode(encodeLibrary(catalog));
    expect(library.kits, ['sample']);
    final byId = {for (final e in library.entries) e.id: e};
    expect(byId.keys.toList(), [
      'sample.table.round-two@2',
      'sample.lamp.wall@1',
      'sample.seat.row-end@1',
    ]);
    // M-B3a: drop attachTo or family when building the component.
    expect(
        byId['sample.lamp.wall@1']!.symbol,
        SymbolComponent(
          key: 'sample.lamp.wall',
          version: 1,
          name: 'Wall lamp',
          category: 'Lighting',
          tags: const ['lamp', 'light'],
          attachTo: const ['wall-face'],
          family: 'lamp-wall',
        ));
    expect(byId['sample.lamp.wall@1']!.unit, isNull);
    // M-B3b: drop the labelling when building the unit.
    expect(
        byId['sample.seat.row-end@1']!.unit,
        UnitComponent(
            kind: UnitKinds.seat,
            capacity: 1,
            labelling: UnitLabelling.assigned));
    expect(byId['sample.table.round-two@2']!.unit,
        UnitComponent(kind: UnitKinds.table, capacity: 2));
    final t = byId['sample.table.round-two@2']!;
    expect(t.definition.basePoint.x, 1800);
    expect(t.definition.basePoint.y, 950);
    expect([for (final l in t.leaves) l.record.kind],
        [EntityKind.circle, EntityKind.polyline, EntityKind.line]);
    expect(t.leaves[0].payload.coords, [1800, 950]);
    expect(t.leaves[0].payload.scalars, [400]);
    // A closed polyline repeats its first point.
    expect(t.leaves[1].payload.coords,
        [1575, 325, 2025, 325, 2025, 775, 1575, 775, 1575, 325]);
    expect(t.leaves[2].payload.coords, [1575, 385, 2025, 385]);
    final l = byId['sample.lamp.wall@1']!;
    // M-B3c: write the arc's start and sweep swapped.
    expect(l.leaves[0].payload.coords, [640, 220]);
    expect(l.leaves[0].payload.scalars, [180, 0.25, -2.75]);
    expect(l.leaves[1].payload.coords, [460, 220, 820, 220, 700, 90]);
  });

  test('B4 the root carries the library component, in millimetres', () {
    final doc = buildLibraryDocument(catalog);
    addTearDown(doc.dispose);
    expect(doc.header.units, DrawingUnits.millimeters);
    final text = utf8.decode(encodeLibrary(catalog));
    expect(
        text,
        contains('"jetcad.library":{"${doc.rootHandle.value}":'
            '{"format":1,"kit":"sample"}}'));
  });

  test("B5 the format's refusals reach the generator", () {
    // M-B5: return the bytes without decoding them.
    expect(
        () => encodeLibrary(
            const Catalog(kit: 'sample', symbols: [table, lamp, table])),
        throwsA(isA<SymbolLibraryError>().having((e) => e.rule, 'rule', 6)));
    const openUnit = CatalogSymbol(
      key: 'sample.table.open',
      name: 'Open table',
      category: 'Tables',
      unit: CatalogUnit(kind: UnitKinds.table, capacity: 4),
      base: (500, 500),
      shapes: [CatalogLine((100, 100), (900, 900))],
    );
    expect(
        () => encodeLibrary(const Catalog(kit: 'sample', symbols: [openUnit])),
        throwsA(isA<SymbolLibraryError>().having((e) => e.rule, 'rule', 11)));
    const dot = CatalogSymbol(
      key: 'sample.dot.zero',
      name: 'Dot',
      category: 'Tests',
      base: (500, 500),
      shapes: [CatalogCircle((500, 500), 0)],
    );
    expect(() => encodeLibrary(const Catalog(kit: 'sample', symbols: [dot])),
        throwsA(isA<SymbolLibraryError>().having((e) => e.rule, 'rule', 15)));
  });

  test("B6 a component's refusal is the constructor's ArgumentError", () {
    const upper = CatalogSymbol(
      key: 'sample.Table.round',
      name: 'Table',
      category: 'Tables',
      base: (500, 500),
      shapes: [CatalogCircle((500, 500), 300)],
    );
    expect(() => encodeLibrary(const Catalog(kit: 'sample', symbols: [upper])),
        throwsArgumentError);
    expect(() => encodeLibrary(const Catalog(kit: 'Sample', symbols: [])),
        throwsArgumentError);
  });

  test('B7 an empty catalog is a valid, empty library', () {
    // Review Focus 4.
    final library = SymbolLibrary.decode(
        encodeLibrary(const Catalog(kit: 'sample', symbols: [])));
    expect(library.kits, ['sample']);
    expect(library.entries, isEmpty);
  });

  test('B8 a payload that throws once the document exists throws through', () {
    // A premise check, exempt from the mutation rule: it pins that an empty
    // closed polyline throws after buildLibraryDocument created its document
    // (the path FR9's dispose-on-throw covers) and that the error reaches
    // the caller unchanged. The disposal itself is not observable: the
    // document never reaches the caller, and the engine keeps no registry of
    // live documents.
    const empty = CatalogSymbol(
      key: 'sample.mark.empty',
      name: 'Empty mark',
      category: 'Marks',
      base: (700, 300),
      shapes: [
        CatalogCircle((700, 300), 120),
        CatalogPolyline([], closed: true),
      ],
    );
    const throwing = Catalog(kit: 'sample', symbols: [empty]);
    expect(() => buildLibraryDocument(throwing), throwsStateError);
    expect(() => encodeLibrary(throwing), throwsStateError);
  });

  test('R2-5 a retired symbol is built retired, the others not', () {
    const retiredLamp = CatalogSymbol(
      key: 'sample.lamp.wall',
      name: 'Wall lamp',
      category: 'Lighting',
      tags: ['lamp', 'light'],
      attachTo: ['wall-face'],
      family: 'lamp-wall',
      base: (640, 220),
      shapes: [
        CatalogArc((640, 220), 180, 0.25, -2.75),
        CatalogPolyline([(460, 220), (820, 220), (700, 90)]),
      ],
      retired: true,
    );
    final bytes = encodeLibrary(
        const Catalog(kit: 'sample', symbols: [table, retiredLamp, seat]));
    // M-R2e: the builder leaves `retired` out.
    expect(
        [for (final e in SymbolLibrary.decode(bytes).entries) e.symbol.retired],
        [false, true, false]);
    expect('"retired":true'.allMatches(utf8.decode(bytes)), hasLength(1));
    // Not retired, nothing is written: a library built before R2 keeps its
    // bytes.
    expect(utf8.decode(encodeLibrary(catalog)), isNot(contains('retired')));
  });
}
