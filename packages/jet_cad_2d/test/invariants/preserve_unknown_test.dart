import 'dart:convert';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

/// "No layer discards data it does not understand."
///
/// The rule appears in three places, which is what makes it an architectural
/// invariant rather than a coincidence. All three are exercised in one shared
/// document, but as three independent tests: with everything in one test
/// body, the first failure aborts before the other two layers are even
/// checked, which hides exactly the kind of partial regression this file
/// exists to catch.
void main() {
  const target = Handle(1000);

  Map<String, Object?> buildAndEncode() {
    final doc = DraftDocument.empty();

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
    return DraftDocumentCodec.encode(doc)
      ..['futureSection'] = {
        'anything': [1, 'two']
      };
  }

  test('an unknown component type survives the round-trip', () {
    final loaded = DraftDocumentCodec.decode(buildAndEncode());
    expect(loaded.components.unknownOf(target).single['diameter'], 32);
  });

  test('an opaque per-source raw-data blob survives the round-trip', () {
    final loaded = DraftDocumentCodec.decode(buildAndEncode());
    expect(
        (loaded.rawData.get(target, SourceKind.dxf)! as Map)['1001'], 'ACME');
  });

  test('an unknown top-level document field survives byte-identically', () {
    final encoded = buildAndEncode();
    final loaded = DraftDocumentCodec.decode(encoded);

    expect(loaded.unknownDocumentFields['futureSection'], isNotNull);
    expect(DraftDocumentCodec.encode(loaded)['futureSection'], {
      'anything': [1, 'two']
    });

    // The whole second write is byte-identical to the first — not merely
    // deterministic against itself (loaded *is* decode(encoded), so
    // comparing loaded's write to a second decode(encoded) would only ever
    // fail under genuine nondeterminism, already covered elsewhere). This
    // compares against the original encoded document directly.
    expect(DraftDocumentCodec.encodeToString(loaded), jsonEncode(encoded));
  });
}
