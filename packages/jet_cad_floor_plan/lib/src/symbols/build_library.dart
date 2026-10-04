// Builds the furniture library document from the catalog (spec 09 D2). The
// generator tool writes its bytes to `assets/library/furniture.jetlib`, and a
// test asserts the committed asset equals them.
//
// The library document is **not** made by `prepareDocument`: that adds the
// DASHED linetype record at handle 6, which the loader's allow-list refuses
// for a leaf and which a library has no use for. It is `DraftDocument.empty`,
// the app's components and millimetre units, nothing else.
//
// No Flutter import and no `dart:io`: this file is Dart over
// `package:jet_cad_2d` only, so the tool runs under plain `dart`.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../parametric/catalog.dart';
import 'furniture_catalog.dart';
import 'seating_component.dart';
import 'symbol_component.dart';

/// The furniture library: [buildSymbolLibrary] over [furnitureCatalog].
DraftDocument buildFurnitureLibrary() => buildSymbolLibrary(furnitureCatalog);

/// The document holding every symbol of [catalog] as a definition with its
/// leaves (spec 14 V-3: any catalog, the furniture one or a host's).
/// Deterministic: handles ascend in catalog order (a definition, then its
/// leaves, then the next definition), so two builds encode to identical
/// bytes. A servable symbol's definition also carries its
/// [SeatingComponent] (spec 14 S2), set right after its [SymbolComponent].
///
/// Leaves are BYBLOCK-friendly: layer 0, BYBLOCK linetype, `ByBlockColor`,
/// lineweight and transparency BYBLOCK, no flag. A BYBLOCK lineweight
/// resolves from the instance, whose own default is also BYBLOCK, which
/// resolves from the document default; both values are on the loader's
/// allow-list.
DraftDocument buildSymbolLibrary(List<FurnitureSymbol> catalog) {
  final doc = DraftDocument.empty();
  registerAppComponents(doc.components);
  doc.header.units = DrawingUnits.millimeters;

  final commands = <DraftCommand>[];
  for (final s in catalog) {
    final def = doc.handleSeed.next();
    commands
      ..add(AddDefinitionCommand(Definition(
        handle: def,
        name: '${s.key}@${s.version}',
        basePoint: Vector2(s.baseX, s.baseY),
        children: const [],
      )))
      ..add(SetComponentCommand<SymbolComponent>(
        def,
        SymbolComponent(
          key: s.key,
          name: s.name,
          category: s.category,
          tags: s.tags,
          version: s.version,
        ),
      ));
    final seats = s.seats;
    if (seats != null) {
      commands.add(SetComponentCommand<SeatingComponent>(
          def, SeatingComponent(seats: seats)));
    }
    for (final shape in s.shapes) {
      commands.add(AddEntityCommand(
        record: EntityRecord(
          handle: doc.handleSeed.next(),
          owner: def,
          kind: shape.kind,
          layer: ReservedHandles.layerZero,
          linetype: ReservedHandles.byBlockLinetype,
          linetypeScale: 1.0,
          geomIndex: 0,
          color: const ByBlockColor(),
          lineweight: kByBlock,
          transparency: kByBlock,
          flags: 0,
        ),
        payload: shape.payload(),
      ));
    }
  }
  doc.commands.execute(CompoundCommand(commands, label: 'Furniture library'));
  doc.commands.clearHistory();
  return doc;
}
