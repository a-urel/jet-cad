// Spec 10 D17: the dashed linetype's handle is reserved in the engine's
// range and the default tables do not change. The byte hash tests in
// test/testing/generate_document_test.dart pin the default document too,
// but they are standing failures on Linux (Ruling 10-25), so this is the
// structural check.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

/// Every record handle of every table of [doc], ascending.
List<int> tableHandles(DraftDocument doc) => [
      for (final r in [
        ...doc.tables.layers.records,
        ...doc.tables.linetypes.records,
        ...doc.tables.textStyles.records,
        ...doc.tables.patterns.records,
        ...doc.tables.dimStyles.records,
        ...doc.tables.appIds.records,
      ])
        r.handle.value,
    ]..sort();

void main() {
  test(
      'RP2 the default tables are unchanged: no record at the dashed '
      'handle, which is reserved', () {
    expect(ReservedHandles.dashedLinetype, const Handle(6));
    expect(ReservedHandles.dashedLinetype.value,
        lessThan(ReservedHandles.firstFree.value));
    expect(ReservedHandles.dashedLinetype.value,
        greaterThan(ReservedHandles.standardTextStyle.value));

    final doc = DraftDocument.empty();
    // The linetype table holds BYLAYER, BYBLOCK and CONTINUOUS only; the
    // default tables together hold handles 1 to 5 only, one record each.
    expect([
      for (final r in doc.tables.linetypes.records) r.handle
    ], [
      ReservedHandles.byLayerLinetype,
      ReservedHandles.byBlockLinetype,
      ReservedHandles.continuousLinetype,
    ]);
    expect(
        doc.tables.linetypes.contains(ReservedHandles.dashedLinetype), isFalse);
    expect(doc.tables.linetypes.byName('DASHED'), isNull);
    expect(tableHandles(doc), [1, 2, 3, 4, 5]);

    // The handle seed starts at firstFree: the root takes the next handle,
    // and so does every later allocation, never the reserved one.
    expect(doc.rootHandle.value, ReservedHandles.firstFree.value + 1);
    expect(doc.handleSeed.next().value, ReservedHandles.firstFree.value + 2);

    // A save and a load keep the tables as they were.
    final loaded = DraftDocumentCodec.decode(DraftDocumentCodec.encode(doc));
    expect(tableHandles(loaded), [1, 2, 3, 4, 5]);
  });
}
