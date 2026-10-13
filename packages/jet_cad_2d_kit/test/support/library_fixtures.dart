// Fixtures for the library validator (spec K3): a small valid library of the
// kit "sample", its bytes, and the codec-JSON helpers that break it one rule
// at a time (the breaker pattern of jet_cad_floor_plan's symbol_fixtures).
//
// Not degenerate: every base point and leaf is off the origin, the versions
// are 3, 2 and 1, the definition handles are far apart, the leaves are
// inserted out of handle order and interleaved across symbols, one symbol is
// a unit, one carries attachment kinds and a family.
import 'dart:convert';
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

const Handle sofaDef = Handle(4200);
const Handle tableDef = Handle(4300);
const Handle armchairDef = Handle(4400);

/// Leaves, by handle; the fixture inserts them in another order.
const int sofaLine = 4210,
    sofaPolyline = 4211,
    sofaArc = 4212,
    sofaCircle = 4213;
const int tableTop = 4310, tableStool = 4311;
const int armchairSeat = 4410, armchairArc = 4411;

SymbolComponent sofaSymbol() => SymbolComponent(
      key: 'sample.sofa.three',
      version: 3,
      name: 'Three-seat sofa',
      category: 'Living Room',
      tags: const ['sofa', 'seating', 'couch'],
      attachTo: const ['wall-face'],
      family: 'sofa-long',
    );

SymbolComponent tableSymbol() => SymbolComponent(
      key: 'sample.table.high-top',
      version: 2,
      name: 'High-top table',
      category: 'Bar',
      tags: const ['table', 'bar', 'high'],
    );

UnitComponent tableUnit() => UnitComponent(kind: UnitKinds.table, capacity: 4);

SymbolComponent armchairSymbol() => SymbolComponent(
      key: 'sample.chair.arm',
      version: 1,
      name: 'Armchair',
      category: 'Living Room',
      tags: const ['armchair', 'seating', 'chair'],
    );

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

/// The leaves in their **insertion** (file) order: not ascending by handle,
/// and the symbols interleaved. The table's first leaf by handle is its
/// closed top; the armchair's is a circle.
List<SymbolLeaf> fixtureLeaves() => [
      (
        record: leafRecord(sofaCircle, sofaDef, EntityKind.circle),
        payload: circlePayload(Vector2(1500, 620), 45),
      ),
      (
        record: leafRecord(tableTop, tableDef, EntityKind.polyline),
        payload: polylinePayload([
          Vector2(950, 560),
          Vector2(1550, 560),
          Vector2(1550, 1160),
          Vector2(950, 1160),
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
        record: leafRecord(tableStool, tableDef, EntityKind.circle),
        payload: circlePayload(Vector2(1250, 400), 190),
      ),
      (
        record: leafRecord(sofaPolyline, sofaDef, EntityKind.polyline),
        payload: polylinePayload(
            [Vector2(120, 340), Vector2(120, 900), Vector2(400, 950)]),
      ),
      (
        record: leafRecord(armchairSeat, armchairDef, EntityKind.circle),
        payload: circlePayload(Vector2(510, 480), 120),
      ),
    ];

/// The valid library: kit "sample", three symbols in two categories, the
/// table a unit.
DraftDocument buildValidLibrary() {
  final doc = DraftDocument.empty();
  registerKitComponents(doc.components);
  doc.header.units = DrawingUnits.millimeters;
  Definition def(Handle h, String name, double x, double y) =>
      Definition(handle: h, name: name, basePoint: Vector2(x, y), children: []);
  doc.commands.execute(CompoundCommand([
    SetComponentCommand<LibraryComponent>(
        doc.rootHandle, LibraryComponent(kit: 'sample')),
    AddDefinitionCommand(def(armchairDef, 'sample.chair.arm@1', 510, 35)),
    AddDefinitionCommand(def(sofaDef, 'sample.sofa.three@3', 900, 400)),
    AddDefinitionCommand(def(tableDef, 'sample.table.high-top@2', 1250, 860)),
    SetComponentCommand<SymbolComponent>(sofaDef, sofaSymbol()),
    SetComponentCommand<SymbolComponent>(tableDef, tableSymbol()),
    SetComponentCommand<UnitComponent>(tableDef, tableUnit()),
    SetComponentCommand<SymbolComponent>(armchairDef, armchairSymbol()),
    for (final l in fixtureLeaves())
      AddEntityCommand(record: l.record, payload: l.payload),
  ], label: 'Fixture library'));
  doc.commands.clearHistory();
  return doc;
}

Uint8List bytesOf(DraftDocument doc) =>
    Uint8List.fromList(utf8.encode(DraftDocumentCodec.encodeToString(doc)));

/// The valid library as mutable JSON (a deep copy through text).
Map<String, Object?> validLibraryJson() =>
    (jsonDecode(DraftDocumentCodec.encodeToString(buildValidLibrary())) as Map)
        .cast<String, Object?>();

/// [json] as bytes, after replacing each key of [text] by its value in the
/// encoded text (how a non-finite number reaches the file: `1e999`).
Uint8List bytesOfJson(Map<String, Object?> json, {Map<String, String>? text}) {
  var s = jsonEncode(json);
  text?.forEach((from, to) => s = s.replaceAll(from, to));
  return Uint8List.fromList(utf8.encode(s));
}

/// The `entities` entry (`{record, geometry}`) of the leaf [handle].
Map<String, Object?> entityJson(Map<String, Object?> lib, int handle) {
  for (final e in lib['entities']! as List) {
    final m = (e as Map).cast<String, Object?>();
    if ((m['record']! as Map)['handle'] == handle) return m;
  }
  throw StateError('no leaf $handle');
}

Map<String, Object?> recordJson(Map<String, Object?> lib, int handle) =>
    (entityJson(lib, handle)['record']! as Map).cast<String, Object?>();

Map<String, Object?> geometryJson(Map<String, Object?> lib, int handle) =>
    (entityJson(lib, handle)['geometry']! as Map).cast<String, Object?>();

Map<String, Object?> definitionJson(Map<String, Object?> lib, int handle) {
  for (final d in lib['definitions']! as List) {
    final m = (d as Map).cast<String, Object?>();
    if (m['handle'] == handle) return m;
  }
  throw StateError('no definition $handle');
}

/// The per-handle map of component type [typeId], created when absent.
Map<String, Object?> componentsJson(Map<String, Object?> lib, String typeId) {
  final all = (lib['components']! as Map).cast<String, Object?>();
  return (all.putIfAbsent(typeId, () => <String, Object?>{})! as Map)
      .cast<String, Object?>();
}

/// The component [typeId] on [handle].
Map<String, Object?> componentJson(
        Map<String, Object?> lib, String typeId, int handle) =>
    (componentsJson(lib, typeId)['$handle']! as Map).cast<String, Object?>();

/// An instance node of [definition], parented to [parent].
Map<String, Object?> instanceNodeJson(
        {required int handle, required int parent, required int definition}) =>
    {
      'type': 'instance',
      'handle': handle,
      'parent': parent,
      'transform': [1.0, 0.0, 0.0, 1.0, 0.0, 0.0],
      'visible': true,
      'definition': definition,
      'layer': ReservedHandles.layerZero.value,
      'color': encodeColor(const ByBlockColor()),
      'lineweight': kByBlock,
      'transparency': kByBlock,
      'linetype': ReservedHandles.byBlockLinetype.value,
      'linetypeScale': 1.0,
    };
