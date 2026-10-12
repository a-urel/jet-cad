// The schema tests' shared fixture (moved unchanged out of
// `schema_9_test.dart`; `schema_10_test.dart` reads it too).
//
// The fixture is not the default document: instances nested, mirrored and
// scaled non-uniformly, groups, three layers, dashed linetypes, room labels
// and attributes measured by a real model, the current layer off layer 0,
// and a comma page in centimetres at 1:20 with its origin off zero. Every
// stored field a read of an older document could drop sits off its default:
// the header's units, scale, linetype scale, imported extents and custom
// variables; a hidden layer and a locked one, both with a transparency; a
// raw-data entry; an unknown component (the planner's `jetcad.table_data`,
// which this engine does not register) on an instance; and an unknown
// top-level key.
import 'dart:convert';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart';

/// The type id of the planner's table data, unknown to this engine.
const tableDataType = 'jetcad.table_data';

/// The unknown top-level key the fixture carries.
const unknownKey = 'jetcad.hostNotes';

DraftDocument fixture(TextMeasurer measurer) {
  final doc = generateDocument(400,
      definitionCount: 6,
      instanceCount: 12,
      nestingDepth: 2,
      mirroredFraction: 0.3,
      nonUniformFraction: 0.3,
      groupCount: 2,
      layerCount: 3,
      dashedFraction: 0.2,
      labelFraction: 0.05,
      attributedInstanceFraction: 0.5,
      measurer: measurer);
  PageComponent.register(doc.components);
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle,
      PageComponent(
          scaleDenominator: 20,
          originX: -4180.5,
          originY: 2645.25,
          displayUnit: DisplayUnit.centimeters,
          decimalSeparator: DecimalSeparator.comma)));

  final layers = doc.tables.layers.records.toList();
  // layer_1 hidden, layer_2 (made current below) locked; both translucent.
  doc.commands.execute(SetLayerCommand.restore(
      layers[1].copyWith(transparency: 60, visible: false)));
  doc.commands.execute(SetLayerCommand.restore(
      layers[2].copyWith(transparency: 25, locked: true)));
  doc.header
    ..currentLayer = layers[2].handle
    ..units = DrawingUnits.millimeters
    ..scale = 0.05
    ..globalLinetypeScale = 2.5
    ..importedExtents = const Aabb2.raw(-1250.5, -730.25, 98000.75, 41000.5)
    // Out of order: the header writes them sorted.
    ..customVariables['\$ZETA'] = 7
    ..customVariables['\$ALPHA'] = 'kept';

  final instance = doc.tree.nodes.whereType<InstanceNode>().first.handle;
  doc.rawData.set(instance, SourceKind.dxf, {
    'groupCodes': [1001, 'ACAD', 1070, 3],
  });
  doc.components.attachUnknown(instance, {
    'typeId': tableDataType,
    'data': {'id': 'T-12', 'seats': 4},
  });
  doc.unknownDocumentFields[unknownKey] = {'by': 'a newer build', 'n': 3};
  return doc;
}

/// [encoding] (this build's) with `schemaVersion` set to [version], as the
/// bytes of a file.
String withVersion(String encoding, int version) {
  final json = jsonDecode(encoding) as Map<String, Object?>;
  json['schemaVersion'] = version;
  return jsonEncode(json);
}
