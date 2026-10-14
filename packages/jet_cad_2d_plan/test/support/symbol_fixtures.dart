// Symbol fixtures for the plan library (Task 13).
//
// Part one: the 09a fixture library of jet_cad_floor_plan's
// test/support/symbol_fixtures.dart (lines 1-133), in the kit format: a
// LibraryComponent on the root and every key under the kit "fixture".
// Non-degenerate as before: every base point and leaf off the origin,
// versions 3, 2 and 1, three tags each, definition handles far apart, the
// leaves inserted out of handle order.
//
// Part two: the gallery's library (kit "demo", one retired symbol, words in
// Turkish) and small per-kit libraries for the loader, built with the
// authoring toolkit's encodeLibrary.
import 'dart:convert';
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/authoring.dart'
    show Catalog, CatalogLine, CatalogPolyline, CatalogSymbol, encodeLibrary;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

// ---- part one ----

const Handle sofaDef = Handle(4200);
const Handle nightstandDef = Handle(4300);
const Handle armchairDef = Handle(4400);

const int sofaLine = 4210,
    sofaPolyline = 4211,
    sofaArc = 4212,
    sofaCircle = 4213;
const int nightstandRect = 4310, nightstandLine = 4311;
const int armchairCircle = 4410, armchairArc = 4411;

SymbolComponent sofaSymbol() => SymbolComponent(
    key: 'fixture.sofa.three',
    name: 'Three-seat sofa',
    category: 'Living Room',
    tags: const ['sofa', 'seating', 'couch'],
    version: 3);

SymbolComponent nightstandSymbol() => SymbolComponent(
    key: 'fixture.nightstand.single',
    name: 'Nightstand',
    category: 'Bed Room',
    tags: const ['nightstand', 'bedside', 'table'],
    version: 2);

SymbolComponent armchairSymbol() => SymbolComponent(
    key: 'fixture.armchair.single',
    name: 'Armchair',
    category: 'Living Room',
    tags: const ['armchair', 'seating', 'chair'],
    version: 1);

EntityRecord leafRecord(int handle, Handle owner, EntityKind kind) =>
    EntityRecord(
      handle: Handle(handle),
      owner: owner,
      kind: kind,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byBlockLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByBlockColor(),
      lineweight: kByBlock,
      transparency: kByBlock,
      flags: 0,
    );

/// The leaves in their insertion (file) order: not ascending by handle,
/// the symbols interleaved.
List<SymbolLeaf> fixtureLeaves() => [
      (
        record: leafRecord(sofaCircle, sofaDef, EntityKind.circle),
        payload: circlePayload(Vector2(1500, 620), 45),
      ),
      (
        record: leafRecord(nightstandRect, nightstandDef, EntityKind.polyline),
        payload: polylinePayload([
          Vector2(50, 60),
          Vector2(450, 60),
          Vector2(450, 410),
          Vector2(50, 410),
        ], closed: true),
      ),
      (
        record: leafRecord(sofaLine, sofaDef, EntityKind.line),
        payload: linePayload(Vector2(120, 340), Vector2(1680, 340)),
      ),
      (
        record: leafRecord(armchairArc, armchairDef, EntityKind.arc),
        payload: arcPayload(Vector2(500, 500), 300, 0.25, 2.5),
      ),
      (
        record: leafRecord(sofaArc, sofaDef, EntityKind.arc),
        payload: arcPayload(Vector2(900, 900), 250, 0.5, 1.75),
      ),
      (
        record: leafRecord(nightstandLine, nightstandDef, EntityKind.line),
        payload: linePayload(Vector2(70, 230), Vector2(430, 230)),
      ),
      (
        record: leafRecord(sofaPolyline, sofaDef, EntityKind.polyline),
        payload: polylinePayload(
            [Vector2(120, 340), Vector2(120, 900), Vector2(400, 950)]),
      ),
      (
        record: leafRecord(armchairCircle, armchairDef, EntityKind.circle),
        payload: circlePayload(Vector2(510, 480), 120),
      ),
    ];

/// The valid library: kit "fixture", three symbols, two categories.
DraftDocument buildValidLibrary() {
  final doc = DraftDocument.empty();
  registerKitComponents(doc.components);
  doc.header.units = DrawingUnits.millimeters;
  Definition def(Handle h, String name, double x, double y) =>
      Definition(handle: h, name: name, basePoint: Vector2(x, y), children: []);
  doc.commands.execute(CompoundCommand([
    SetComponentCommand<LibraryComponent>(
        doc.rootHandle, LibraryComponent(kit: 'fixture')),
    AddDefinitionCommand(def(armchairDef, 'fixture.armchair.single@1', 510, 0)),
    AddDefinitionCommand(def(sofaDef, 'fixture.sofa.three@3', 900, 400)),
    AddDefinitionCommand(
        def(nightstandDef, 'fixture.nightstand.single@2', 250, 60)),
    SetComponentCommand<SymbolComponent>(sofaDef, sofaSymbol()),
    SetComponentCommand<SymbolComponent>(nightstandDef, nightstandSymbol()),
    SetComponentCommand<SymbolComponent>(armchairDef, armchairSymbol()),
    for (final l in fixtureLeaves())
      AddEntityCommand(record: l.record, payload: l.payload),
  ], label: 'Fixture library'));
  doc.commands.clearHistory();
  return doc;
}

Uint8List bytesOf(DraftDocument doc) =>
    Uint8List.fromList(utf8.encode(DraftDocumentCodec.encodeToString(doc)));

// ---- part two ----

/// A symbol drawn as a closed outline and a middle line, its base point
/// off the origin.
CatalogSymbol box(String key, String name, String category, List<String> tags,
        {int version = 1,
        bool retired = false,
        List<String> attachTo = const [],
        (double, double) base = (950, 410)}) =>
    CatalogSymbol(
      key: key,
      version: version,
      name: name,
      category: category,
      tags: tags,
      attachTo: attachTo,
      retired: retired,
      base: base,
      shapes: const [
        CatalogPolyline([(150, 210), (1750, 210), (1750, 960), (150, 960)],
            closed: true),
        CatalogLine((150, 585), (1750, 585)),
      ],
    );

/// The gallery's library, in library order. `bed` matches the Bed Room
/// symbols only (a name, a tag or the category); `demo.chair.old` is
/// retired.
final Catalog demoCatalog = Catalog(kit: 'demo', symbols: [
  box('demo.bed.double', 'Double bed', 'Bed Room', ['bed', 'sleep'],
      base: (980.5, 640.25)),
  box('demo.bed.single', 'Single bed', 'Bed Room', ['bed'],
      base: (720.25, 515.5)),
  box('demo.bed.night', 'Nightstand', 'Bed Room', ['bedside'],
      base: (402.75, 233.5)),
  box('demo.sofa.three', 'Three-seat sofa', 'Living Room', ['sofa', 'couch'],
      base: (1100.5, 480.75)),
  box('demo.sofa.two', 'Two-seat sofa', 'Living Room', ['sofa', 'couch'],
      base: (860.25, 470.5)),
  box('demo.chair.old', 'Old chair', 'Living Room', ['chair'],
      retired: true, base: (512.5, 301.25)),
  box('demo.desk.office', 'Office desk', 'Office', ['desk', 'work'],
      base: (1203.75, 655.5)),
]);

/// The demo kit's Turkish words; no German (the English fallback).
const KitNames demoNames = KitNames({
  'tr': {
    'symbol:demo.bed.double': 'Çift kişilik yatak',
    'symbol:demo.sofa.three': 'Üçlü kanepe',
    'category:demo/Bed Room': 'Yatak odası',
    'category:demo/Living Room': 'Oturma odası',
  },
});

Uint8List demoBytes() => encodeLibrary(demoCatalog);

/// The visible (not retired) demo symbols' ids, in library order.
List<String> demoVisibleIds() => [
      for (final s in demoCatalog.symbols)
        if (!s.retired) s.id,
    ];

/// A library of kit [kit] holding `<kit>.item.<name>` for each of [names]
/// at [version].
Uint8List itemsBytes(String kit, List<String> names, {int version = 1}) =>
    encodeLibrary(Catalog(kit: kit, symbols: [
      for (final (i, n) in names.indexed)
        box('$kit.item.$n', 'Item $n', 'Things', [n],
            version: version, base: (300.5 + 100 * i, 220.25 + 50 * i)),
    ]));

/// A source whose reads are counted and whose bytes come from [read].
final class CountingSource {
  CountingSource(String label, Future<Uint8List> Function() read) {
    source = SymbolLibrarySource(
        label: label,
        read: () {
          reads++;
          return read();
        });
  }

  late final SymbolLibrarySource source;
  int reads = 0;
}

/// A kit of symbols only.
PlanKit symbolKit(String id, List<SymbolLibrarySource> sources,
        {KitNames names = KitNames.empty}) =>
    PlanKit(id: id, version: '1.0.0', symbols: sources, names: names);

/// The demo kit, read through [source] (a counting one by default).
PlanKit demoKit({SymbolLibrarySource? source}) => symbolKit(
    'demo',
    [
      source ??
          SymbolLibrarySource(label: 'demo', read: () async => demoBytes())
    ],
    names: demoNames);

/// The ids of [symbols].
List<String> idsOf(Iterable<PlanSymbol> symbols) =>
    [for (final s in symbols) s.id];

/// Lets every pending read and decode of a loader finish (plain tests).
Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
