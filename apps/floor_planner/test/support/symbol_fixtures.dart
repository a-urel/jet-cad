// Fixtures for the symbol library loader (spec 09 D5, plan 09a Task 3): a
// small valid library document, its bytes, and a way to break it one rule at
// a time by editing the codec's JSON (the only way to reach a leaf handle in
// a definition's `children`, which the codec never writes: spec V-9).
//
// Non-degenerate by construction: every base point is off the origin, every
// leaf is off the origin, versions are 3, 2 and 1, every symbol has three
// tags, the definition handles are far apart, and the **file order of the
// leaves is not their handle order**.
import 'dart:convert';
import 'dart:typed_data';

import 'package:jet_cad_floor_plan/editor.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

const Handle sofaDef = Handle(4200);
const Handle nightstandDef = Handle(4300);
const Handle armchairDef = Handle(4400);

/// Sofa leaves, in **handle order**; the fixture inserts them in another.
const int sofaLine = 4210,
    sofaPolyline = 4211,
    sofaArc = 4212,
    sofaCircle = 4213;
const int nightstandRect = 4310, nightstandLine = 4311;
const int armchairCircle = 4410, armchairArc = 4411;

SymbolComponent sofaSymbol() => SymbolComponent(
    key: 'sofa.three',
    name: 'Three-seat sofa',
    category: 'Living Room',
    tags: const ['sofa', 'seating', 'couch'],
    version: 3);

SymbolComponent nightstandSymbol() => SymbolComponent(
    key: 'nightstand.single',
    name: 'Nightstand',
    category: 'Bed Room',
    tags: const ['nightstand', 'bedside', 'table'],
    version: 2);

SymbolComponent armchairSymbol() => SymbolComponent(
    key: 'armchair.single',
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

/// The fixture's leaves in the order they are **inserted** (file order):
/// deliberately not ascending by handle, and the symbols interleaved.
List<({EntityRecord record, GeometryPayload payload})> fixtureLeaves() => [
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

/// A valid library: three symbols, two categories, base points off the
/// origin, a line, two polylines (one closed), two arcs and two circles.
DraftDocument buildValidLibrary() {
  final doc = DraftDocument.empty();
  registerAppComponents(doc.components);
  doc.header.units = DrawingUnits.millimeters;
  Definition def(Handle h, String name, double x, double y) =>
      Definition(handle: h, name: name, basePoint: Vector2(x, y), children: []);
  doc.commands.execute(CompoundCommand([
    AddDefinitionCommand(def(armchairDef, 'armchair.single@1', 510, 0)),
    AddDefinitionCommand(def(sofaDef, 'sofa.three@3', 900, 400)),
    AddDefinitionCommand(def(nightstandDef, 'nightstand.single@2', 250, 60)),
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

/// The valid library as mutable JSON (a deep copy through text).
Map<String, Object?> validLibraryJson() =>
    (jsonDecode(DraftDocumentCodec.encodeToString(buildValidLibrary())) as Map)
        .cast<String, Object?>();

Uint8List bytesOfJson(Map<String, Object?> json, {Map<String, String>? text}) {
  var s = jsonEncode(json);
  text?.forEach((from, to) => s = s.replaceAll(from, to));
  return Uint8List.fromList(utf8.encode(s));
}

/// The `entities` entry (`{record, geometry}`) of the leaf with [handle].
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

/// The `jetcad.symbol` component of a definition.
Map<String, Object?> symbolComponentJson(
        Map<String, Object?> lib, int handle) =>
    (((lib['components']! as Map)[SymbolComponent.componentTypeId]!
            as Map)['$handle'] as Map)
        .cast<String, Object?>();

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
