// The 09a fixture library (kit "fixture"), copied from jet_cad_2d_plan's
// test/support/symbol_fixtures.dart part one (lines 25-140, unchanged) for
// the symbol box and placement tests that moved into the contract (3a
// Task 1, spec C1.4): their assertions name these keys and boxes. Not
// degenerate: every base point and leaf off the origin, versions 3, 2 and
// 1, definition handles far apart, the leaves inserted out of handle order.
import 'dart:convert';
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

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
