import 'dart:convert';

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
    expect(header.toJson().keys.toList(), [
      'units',
      'scale',
      'globalLinetypeScale',
      'importedExtents',
      'customVariables'
    ]);
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

  test('a non-finite importedExtents is dropped rather than emitted', () {
    // Aabb2.empty() is the package's own factory and importedExtents is a
    // public settable field, so `header.importedExtents = doc.extents` on an
    // empty document — or a DXF importer reading an absent $EXTMIN/$EXTMAX —
    // lands an inverted-infinity box here directly.
    for (final box in [
      Aabb2.empty(),
      Aabb2.raw(0, 0, double.infinity, double.infinity),
      Aabb2.raw(double.nan, 0, 1, 1),
    ]) {
      final header = DocumentHeader()..importedExtents = box;
      expect(header.toJson()['importedExtents'], isNull, reason: '$box');
      // The real symptom: jsonEncode has no representation for these.
      expect(() => jsonEncode(header.toJson()), returnsNormally,
          reason: '$box');
      // Symmetric on the way back in, so what is loaded is what a save would
      // write: a file naming a non-finite box yields null, not that box.
      expect(
        DocumentHeader.fromJson({
          'units': 'unitless',
          'scale': 1.0,
          'importedExtents': box.toJson(),
          'customVariables': const <String, Object?>{},
        }).importedExtents,
        isNull,
        reason: '$box',
      );
    }
  });

  test('a whole empty document still encodes', () {
    final doc = DraftDocument.empty();
    doc.header.importedExtents = doc.extents; // Aabb2.empty()
    expect(() => DraftDocumentCodec.encodeToString(doc), returnsNormally);
    final loaded = DraftDocumentCodec.decode(DraftDocumentCodec.encode(doc));
    expect(loaded.header.importedExtents, isNull);
  });

  test('globalLinetypeScale round-trips and defaults to 1', () {
    final header = DocumentHeader();
    expect(header.globalLinetypeScale, 1.0);

    header.globalLinetypeScale = 0.375;
    final restored = DocumentHeader.fromJson(header.toJson());
    expect(restored.globalLinetypeScale, 0.375);
  });

  test('a document written before the field reads back as 1', () {
    // Forward compatibility runs both ways: an older file has no key, and the
    // default has to be the value that changes nothing.
    final json = DocumentHeader().toJson()..remove('globalLinetypeScale');
    expect(DocumentHeader.fromJson(json).globalLinetypeScale, 1.0);
  });
}
