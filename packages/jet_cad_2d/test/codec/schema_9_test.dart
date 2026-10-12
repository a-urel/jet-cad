// Schema 9 (host embedding API spec, E-9; Slice 2 plan, Task 1): this build
// reads an 8 document unchanged (the 8 -> 9 migration is empty); since schema
// 10 (plan colours spec PC-2) it writes 10, and refuses an 11 by its version.
//
// The fixture is `support/schema_fixture.dart`'s: every stored field an
// 8 -> 9 read could drop sits off its default there. The older and newer
// documents are derived from this build's own encoding of it (the version
// set, then through bytes), never hand-written, so they cannot drift from the
// codec's JSON contract.
import 'dart:convert';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

import 'support/schema_fixture.dart';

void main() {
  test('S9-1 this build writes schema 10, first, in every encoding', () {
    expect(kSchemaVersion, 10);
    final doc = fixture(MetricModelMeasurer());
    final encoding = DraftDocumentCodec.encodeToString(doc);
    final json = jsonDecode(encoding) as Map<String, Object?>;
    expect(json['schemaVersion'], 10);
    expect(json.keys.first, 'schemaVersion');
    final empty = DraftDocumentCodec.encode(DraftDocument.empty());
    expect(empty['schemaVersion'], 10,
        reason: 'an empty document is written at 10 as well');
    expect(empty.keys.first, 'schemaVersion', reason: 'and first, as well');
  });

  test(
      'S9-2 an 8 document loads unchanged, drawing and all, and saves to '
      'the 10 bytes this build wrote (the migration is empty)', () {
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

    // Saved again, it is the 10 file this build writes, byte for byte.
    expect(DraftDocumentCodec.encodeToString(loaded), nine);
  });

  test(
      'S9-3 an 11 document is refused by its version, and the error names '
      '11 and 10', () {
    final eleven = withVersion(
        DraftDocumentCodec.encodeToString(fixture(MetricModelMeasurer())), 11);
    expect(
        () => DraftDocumentCodec.decodeString(eleven,
            registerComponents: PageComponent.register),
        throwsA(isA<SchemaVersionError>()
            .having((e) => e.found, 'found', 11)
            .having(
                (e) => e.toString(),
                'toString',
                allOf(contains('unsupported schemaVersion 11'),
                    contains('this build writes 10')))));
  });
}
