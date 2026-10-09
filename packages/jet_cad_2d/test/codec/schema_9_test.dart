// Schema 9 (host embedding API spec, E-9; Slice 2 plan, Task 1): this build
// writes 9, reads an 8 document unchanged (the 8 -> 9 migration is empty)
// and refuses a 10 by its version.
//
// The fixture is not the default document: instances nested, mirrored and
// scaled non-uniformly, groups, three layers, dashed linetypes, room labels
// and attributes measured by a real model, the current layer off layer 0,
// and a comma page in centimetres at 1:20 with its origin off zero. Every
// stored field an 8 -> 9 read could drop sits off its default: the header's
// units, scale, linetype scale, imported extents and custom variables; a
// hidden layer and a locked one, both with a transparency; a raw-data
// entry; an unknown component (the planner's `jetcad.table_data`, which this
// engine does not register) on an instance; and an unknown top-level key.
// The older and newer documents are derived from this build's own encoding
// of it (the version set, then through bytes), never hand-written, so they
// cannot drift from the codec's JSON contract.
import 'dart:convert';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart';
import 'package:test/test.dart';

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

void main() {
  test('S9-1 this build writes schema 9, first, in every encoding', () {
    expect(kSchemaVersion, 9);
    final doc = fixture(MetricModelMeasurer());
    final encoding = DraftDocumentCodec.encodeToString(doc);
    final json = jsonDecode(encoding) as Map<String, Object?>;
    expect(json['schemaVersion'], 9);
    expect(json.keys.first, 'schemaVersion');
    final empty = DraftDocumentCodec.encode(DraftDocument.empty());
    expect(empty['schemaVersion'], 9,
        reason: 'an empty document is written at 9 as well');
    expect(empty.keys.first, 'schemaVersion', reason: 'and first, as well');
  });

  test(
      'S9-2 an 8 document loads unchanged, drawing and all, and saves to '
      'the 9 bytes this build wrote (the migration is empty)', () {
    final measurer = MetricModelMeasurer();
    final doc = fixture(measurer);
    final nine = DraftDocumentCodec.encodeToString(doc);
    final eight = withVersion(nine, 8);
    // Premise: what an 8 -> 9 read could drop is in the file, off its
    // default, so dropping it changes a byte.
    final json = jsonDecode(nine) as Map<String, Object?>;
    final header = json['header']! as Map<String, Object?>;
    expect(header['globalLinetypeScale'], 2.5, reason: 'premise');
    expect(header['scale'], 0.05, reason: 'premise');
    expect(header['customVariables'], hasLength(2), reason: 'premise');
    final layers = ((json['tables']! as Map)['layers']! as List)
        .cast<Map<String, Object?>>();
    expect(layers.where((l) => l['visible'] == false), hasLength(1),
        reason: 'premise: a hidden layer');
    expect(layers.where((l) => l['locked'] == true), hasLength(1),
        reason: 'premise: a locked layer');
    expect(layers.where((l) => l['transparency'] != 0), hasLength(2),
        reason: 'premise: translucent layers');
    expect(json['rawData'], hasLength(1), reason: 'premise: raw data');
    expect((json['components']! as Map).keys,
        containsAll(<String>['jetcad.page', tableDataType]),
        reason: 'premise: an unknown component beside the page');
    expect(json[unknownKey], isNotNull, reason: 'premise: an unknown key');
    expect(doc.entities.liveSlots.map(doc.entities.kindAt),
        containsAll(<EntityKind>[EntityKind.text, EntityKind.attrib]),
        reason: 'premise: labels and attributes');
    expect((jsonDecode(eight) as Map<String, Object?>)['schemaVersion'], 8,
        reason: 'premise: the file declares 8');
    expect(eight, isNot(nine), reason: 'premise');

    final loaded = DraftDocumentCodec.decodeString(eight,
        measurer: measurer, registerComponents: PageComponent.register);

    // The drawing: every entity, its kind, its layer and its coordinates;
    // every node's transform; the extents; the page and the current layer.
    expect(loaded.entities.liveSlots.length, doc.entities.liveSlots.length);
    expect(loaded.entities.liveSlots.length, greaterThanOrEqualTo(400),
        reason: 'premise: a drawing, not an empty file');
    for (final slot in doc.entities.liveSlots) {
      final handle = doc.entities.handleAt(slot);
      final other = loaded.entities.slotOf(handle)!;
      expect(loaded.entities.kindAt(other), doc.entities.kindAt(slot));
      expect(loaded.entities.layerAt(other), doc.entities.layerAt(slot));
      expect(loaded.geometry.peek(loaded.entities.geomIndexAt(other)).coords,
          doc.geometry.peek(doc.entities.geomIndexAt(slot)).coords);
    }
    for (final node in doc.tree.nodes) {
      expect(loaded.tree[node.handle], isNotNull, reason: '${node.handle}');
      if (node is InstanceNode) {
        final back = loaded.tree[node.handle]! as InstanceNode;
        List<double> parts(Transform2 t) => [t.a, t.b, t.c, t.d, t.e, t.f];
        expect(parts(back.transform), parts(node.transform));
        expect(back.definition, node.definition);
      }
    }
    expect(loaded.extents.minX, doc.extents.minX);
    expect(loaded.extents.minY, doc.extents.minY);
    expect(loaded.extents.maxX, doc.extents.maxX);
    expect(loaded.extents.maxY, doc.extents.maxY);
    expect(loaded.components.get<PageComponent>(loaded.rootHandle),
        doc.components.get<PageComponent>(doc.rootHandle));
    expect(loaded.header.currentLayer, doc.header.currentLayer);

    // Saved again, it is the 9 file this build wrote, byte for byte.
    expect(DraftDocumentCodec.encodeToString(loaded), nine);
  });

  test(
      'S9-3 a 10 document is refused by its version, and the error names '
      '10 and 9', () {
    final ten = withVersion(
        DraftDocumentCodec.encodeToString(fixture(MetricModelMeasurer())), 10);
    expect(
        () => DraftDocumentCodec.decodeString(ten,
            registerComponents: PageComponent.register),
        throwsA(isA<SchemaVersionError>()
            .having((e) => e.found, 'found', 10)
            .having(
                (e) => e.toString(),
                'toString',
                allOf(contains('unsupported schemaVersion 10'),
                    contains('this build writes 9')))));
  });
}
