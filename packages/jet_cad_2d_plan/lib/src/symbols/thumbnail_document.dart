// Spec P2 "PlanSymbolGallery" (Task 13): a gallery cell's thumbnail is what
// a placement makes (today's symbolThumbnailDocument, symbol_panel.dart:
// 43-50): the kit components registered, millimetres, the symbol placed at
// its own base point with no turn and no mirror, an identity transform.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show registerKitComponents;

import 'plan_symbol.dart';
import 'symbol_placer.dart';

DraftDocument symbolThumbnailDocument(PlanSymbol symbol) {
  final doc = DraftDocument.empty(measurer: const InsertionPointMeasurer());
  registerKitComponents(doc.components);
  doc.header.units = DrawingUnits.millimeters;
  doc.commands.execute(
      placeSymbol(doc, symbol.entry, at: symbol.entry.definition.basePoint));
  return doc;
}
