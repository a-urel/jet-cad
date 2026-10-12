// Schema 10 (plan colours spec PC-2): this build writes 10 and reads a 9
// document unchanged (the 9 -> 10 migration is empty). The 9 document is
// derived from this build's own encoding of the schema fixture (the version
// set, then through bytes), never hand-written.
import 'dart:convert';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

import 'support/schema_fixture.dart';

void main() {
  test('S10-1 this build writes schema 10, first', () {
    expect(kSchemaVersion, 10);
    final json = jsonDecode(
            DraftDocumentCodec.encodeToString(fixture(MetricModelMeasurer())))
        as Map<String, Object?>;
    expect(json['schemaVersion'], 10);
    expect(json.keys.first, 'schemaVersion');
  });

  test(
      'S10-2 a 9 document reads unchanged and saves as this build\'s 10 '
      'file, byte for byte', () {
    final ten =
        DraftDocumentCodec.encodeToString(fixture(MetricModelMeasurer()));
    final nine = withVersion(ten, 9);
    final loaded = DraftDocumentCodec.decodeString(nine,
        measurer: MetricModelMeasurer(),
        registerComponents: PageComponent.register);
    expect(DraftDocumentCodec.encodeToString(loaded), ten);
  });
}
