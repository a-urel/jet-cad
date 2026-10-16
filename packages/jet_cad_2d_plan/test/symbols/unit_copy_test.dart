// D-17's SE8 (spec 3a C7, C1.12; Task 8): jet_cad_floor_plan's
// test/symbols/seating_test.dart SE8, ported over the plan library's
// placer. 2b's SP-1 (symbol_placer_test.dart) pins the copy's unit; SE8
// also pins that it survives a save and goes with the definition in one
// undo step. The library is written as the test kit's unit library is (a
// Catalog of kit "test" with a CatalogUnit), with SE8's own table. 2b
// replaced jetcad.seating with the contract's jetcad.unit (2b spec S2):
// SeatingComponent(seats: 3) is UnitComponent(kind: table, capacity: 3);
// the key test.table is test.table.plain (K2).
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/authoring.dart'
    show Catalog, CatalogPolyline, CatalogSymbol, CatalogUnit, encodeLibrary;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/src/symbols/symbol_placer.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// A 600 x 400 table with one 300 x 300 seat below it, its base point at
/// the top's centre (off the origin); three seats.
SymbolEntry table() => SymbolLibrary.decode(encodeLibrary(Catalog(
      kit: 'test',
      symbols: [
        CatalogSymbol(
          key: 'test.table.plain',
          name: 'Test table',
          category: 'Tests',
          tags: const ['table', 'test'],
          unit: const CatalogUnit(kind: UnitKinds.table, capacity: 3),
          base: (300, 500),
          shapes: const [
            CatalogPolyline([(0, 300), (600, 300), (600, 700), (0, 700)],
                closed: true),
            CatalogPolyline([(150, 0), (450, 0), (450, 300), (150, 300)],
                closed: true),
          ],
        ),
      ],
    ))).entries.single;

DraftDocument plan() {
  final doc = DraftDocument.empty();
  registerKitComponents(doc.components);
  doc.header.units = DrawingUnits.millimeters;
  return doc;
}

Handle definitionOfOnlyInstance(DraftDocument doc) =>
    doc.tree.nodes.whereType<InstanceNode>().single.definition;

void main() {
  test(
      'SE8 a quarter-turned, mirrored, off-origin placement copies the '
      'seats with the definition, and they survive a save (M-14s-3)', () {
    final entry = table();
    final doc = plan();
    doc.commands.execute(placeSymbol(doc, entry,
        at: Vector2(12345, -6789), quarterTurns: 3, mirrored: true));
    final def = definitionOfOnlyInstance(doc);
    expect(doc.components.get<UnitComponent>(def),
        UnitComponent(kind: UnitKinds.table, capacity: 3));
    final reloaded = DraftDocumentCodec.decodeString(
        DraftDocumentCodec.encodeToString(doc),
        registerComponents: registerKitComponents);
    expect(reloaded.components.get<UnitComponent>(def),
        UnitComponent(kind: UnitKinds.table, capacity: 3));
    // One undo step takes it away with the definition.
    doc.commands.undo();
    expect(doc.components.get<UnitComponent>(def), isNull);
  });
}
