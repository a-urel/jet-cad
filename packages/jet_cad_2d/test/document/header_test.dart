import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

void main() {
  test('defaults to unitless with unit scale and no imported extents', () {
    final header = DocumentHeader();
    expect(header.units, DrawingUnits.unitless);
    expect(header.scale, 1.0);
    expect(header.importedExtents, isNull);
    expect(header.customVariables, isEmpty);
  });

  test('importedExtents is stored verbatim and never recomputed', () {
    // It exists only so $EXTMIN/$EXTMAX survive a round-trip. Working extents
    // are a separate, derived value.
    final header = DocumentHeader()
      ..importedExtents = Aabb2(Vector2(0, 0), Vector2(100, 50));
    expect(DocumentHeader.fromJson(header.toJson()).importedExtents!.max,
        Vector2(100, 50));
  });

  test('json key order is stable and custom variables are sorted', () {
    final header = DocumentHeader()
      ..units = DrawingUnits.millimeters
      ..customVariables['zeta'] = 1
      ..customVariables['alpha'] = 2;
    expect(header.toJson().keys.toList(),
        ['units', 'scale', 'importedExtents', 'customVariables']);
    expect((header.toJson()['customVariables']! as Map).keys.toList(),
        ['alpha', 'zeta']);
  });

  test('round-trips', () {
    final header = DocumentHeader()
      ..units = DrawingUnits.meters
      ..scale = 0.001
      ..customVariables['acadver'] = 'AC1027';
    final decoded = DocumentHeader.fromJson(header.toJson());
    expect(decoded.units, DrawingUnits.meters);
    expect(decoded.scale, 0.001);
    expect(decoded.customVariables['acadver'], 'AC1027');
  });

  test(
      'a header with no imported extents round-trips importedExtents as '
      'null, not as a fabricated box', () {
    // The brief's own "stored verbatim" test only exercises the present
    // case. A document that was never imported (or was authored natively)
    // must not gain a synthesized importedExtents on the way through JSON.
    final decoded = DocumentHeader.fromJson(DocumentHeader().toJson());
    expect(decoded.importedExtents, isNull);
  });
}
