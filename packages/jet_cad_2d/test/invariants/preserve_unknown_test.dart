import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

/// "No layer discards data it does not understand."
///
/// The rule appears in three places, which is what makes it an architectural
/// invariant rather than a coincidence. All three are exercised in one document
/// so that a change which breaks one of them cannot pass by fixing the others.
void main() {
  test('all three unknown-data layers survive one round-trip', () {
    final doc = DraftDocument.empty();
    const target = Handle(1000);

    // 1. A component type this build has never heard of.
    doc.components.attachUnknown(target, {
      'typeId': 'acme.plumbing',
      'diameter': 32,
      'nested': {'material': 'copper'},
    });

    // 2. An opaque per-source blob from an adapter.
    doc.rawData.set(target, SourceKind.dxf, {
      '1001': 'ACME',
      'codes': [1, 2, 3]
    });

    // 3. A top-level document field written by a newer build.
    final encoded = DraftDocumentCodec.encode(doc)
      ..['futureSection'] = {
        'anything': [1, 'two']
      };

    final loaded = DraftDocumentCodec.decode(encoded);

    expect(loaded.components.unknownOf(target).single['diameter'], 32);
    expect(
        (loaded.rawData.get(target, SourceKind.dxf)! as Map)['1001'], 'ACME');
    expect(loaded.unknownDocumentFields['futureSection'], isNotNull);

    // And the second write is byte-identical to the first.
    expect(DraftDocumentCodec.encode(loaded)['futureSection'], {
      'anything': [1, 'two']
    });
    expect(DraftDocumentCodec.encodeToString(loaded),
        DraftDocumentCodec.encodeToString(DraftDocumentCodec.decode(encoded)));
  });
}
