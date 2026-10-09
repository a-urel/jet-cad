// Schema 9 (host embedding API spec, E-9; Slice 2 plan, Task 1): this build
// writes 9, reads an 8 document unchanged (the 8 -> 9 migration is empty)
// and refuses a 10 by its version.
//
// The fixture is not the default document: instances nested, mirrored and
// scaled non-uniformly, groups, three layers, dashed linetypes, the current
// layer off layer 0, and a comma page in centimetres at 1:20 with its origin
// off zero. The older and newer documents are derived from this build's own
// encoding of it (the version set, then through bytes), never hand-written,
// so they cannot drift from the codec's JSON contract.
import 'dart:convert';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart';
import 'package:test/test.dart';

DraftDocument fixture() {
  final doc = generateDocument(400,
      definitionCount: 6,
      instanceCount: 12,
      nestingDepth: 2,
      mirroredFraction: 0.3,
      nonUniformFraction: 0.3,
      groupCount: 2,
      layerCount: 3,
      dashedFraction: 0.2);
  PageComponent.register(doc.components);
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle,
      PageComponent(
          scaleDenominator: 20,
          originX: -4180.5,
          originY: 2645.25,
          displayUnit: DisplayUnit.centimeters,
          decimalSeparator: DecimalSeparator.comma)));
  doc.header.currentLayer = doc.tables.layers.records.last.handle;
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
    final doc = fixture();
    final encoding = DraftDocumentCodec.encodeToString(doc);
    final json = jsonDecode(encoding) as Map<String, Object?>;
    expect(json['schemaVersion'], 9);
    expect(json.keys.first, 'schemaVersion');
    expect(DraftDocumentCodec.encode(DraftDocument.empty())['schemaVersion'], 9,
        reason: 'an empty document is written at 9 as well');
  });

  test(
      'S9-2 an 8 document loads unchanged, drawing and all, and saves to '
      'the 9 bytes this build wrote (the migration is empty)', () {
    final doc = fixture();
    final nine = DraftDocumentCodec.encodeToString(doc);
    final eight = withVersion(nine, 8);
    expect((jsonDecode(eight) as Map<String, Object?>)['schemaVersion'], 8,
        reason: 'premise: the file declares 8');
    expect(eight, isNot(nine), reason: 'premise');

    final loaded = DraftDocumentCodec.decodeString(eight,
        registerComponents: PageComponent.register);

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
    final ten = withVersion(DraftDocumentCodec.encodeToString(fixture()), 10);
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
