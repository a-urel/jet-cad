import 'dart:convert';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

DraftDocument withPage() {
  final doc = DraftDocument.empty();
  PageComponent.register(doc.components);
  doc.header.units = DrawingUnits.millimeters;
  doc.commands.execute(SetComponentCommand<PageComponent>(
    doc.rootHandle,
    PageComponent(
        widthMm: 215.9,
        heightMm: 279.4,
        orientation: PageOrientation.portrait,
        scaleDenominator: 48,
        originX: 7350,
        originY: -1230,
        displayUnit: DisplayUnit.feetInches,
        background: 0xFFFAF6EC,
        gridStepMm: 152.4,
        pageBreaks: true),
  ));
  return doc;
}

void main() {
  test(
      'the page round-trips typed when the load registers it, and the '
      'bytes are stable', () {
    // M-04d: registering after loadJson makes the typed value null.
    final doc = withPage();
    final original = doc.components.get<PageComponent>(doc.rootHandle)!;
    final first = DraftDocumentCodec.encodeToString(doc);

    final back = DraftDocumentCodec.decodeString(first,
        registerComponents: PageComponent.register);

    expect(back.components.get<PageComponent>(back.rootHandle), original);
    expect(back.components.unknownOf(back.rootHandle), isEmpty);
    expect(DraftDocumentCodec.encodeToString(back), first);
  });

  test(
      'without registration the bytes survive but the type does not — '
      'which is why the typed assertion above exists', () {
    final doc = withPage();
    final first = DraftDocumentCodec.encodeToString(doc);

    final back = DraftDocumentCodec.decodeString(first);

    expect(back.components.get<PageComponent>(back.rootHandle), isNull);
    final unknown = back.components.unknownOf(back.rootHandle);
    expect(unknown, hasLength(1));
    expect(unknown.single['typeId'], PageComponent.componentTypeId);
    expect(DraftDocumentCodec.encodeToString(back), first);
  });

  group('the decimal separator through the codec (spec Q0 M-Q0-c)', () {
    // The fixture rule: centimetres at 1:20, the origin off zero, `comma`.
    final commaPage = PageComponent(
        scaleDenominator: 20,
        originX: -4180.5,
        originY: 2645.25,
        displayUnit: DisplayUnit.centimeters,
        decimalSeparator: DecimalSeparator.comma);

    DraftDocument withCommaPage() {
      final doc = DraftDocument.empty();
      PageComponent.register(doc.components);
      doc.commands.execute(
          SetComponentCommand<PageComponent>(doc.rootHandle, commaPage));
      return doc;
    }

    Map<String, Object?> pageJsonOf(Map<String, Object?> json) =>
        ((json['components']
                    as Map<String, Object?>)[PageComponent.componentTypeId]
                as Map<String, Object?>)
            .values
            .single as Map<String, Object?>;

    test('Q0-C1 this build writes schema 9', () {
      expect(kSchemaVersion, 9);
      final json =
          jsonDecode(DraftDocumentCodec.encodeToString(withCommaPage()))
              as Map<String, Object?>;
      expect(json['schemaVersion'], 9);
    });

    test('Q0-C2 a comma page round-trips, and the bytes are stable', () {
      final doc = withCommaPage();
      final first = DraftDocumentCodec.encodeToString(doc);
      expect(
          pageJsonOf(
              jsonDecode(first) as Map<String, Object?>)['decimalSeparator'],
          'comma');
      final back = DraftDocumentCodec.decodeString(first,
          registerComponents: PageComponent.register);
      final page = back.components.get<PageComponent>(back.rootHandle)!;
      expect(page.decimalSeparator, DecimalSeparator.comma);
      expect(page, commaPage);
      expect(DraftDocumentCodec.encodeToString(back), first);
    });

    test('Q0-C3 a v7 document, whose page has no key, loads as point', () {
      // Derived from this build's encoding: the key stripped and the version
      // declared back down to 7, read through bytes as a file would be.
      final json =
          jsonDecode(DraftDocumentCodec.encodeToString(withCommaPage()))
              as Map<String, Object?>;
      pageJsonOf(json).remove('decimalSeparator');
      json['schemaVersion'] = 7;
      final back = DraftDocumentCodec.decodeString(jsonEncode(json),
          registerComponents: PageComponent.register);
      final page = back.components.get<PageComponent>(back.rootHandle)!;
      expect(page.decimalSeparator, DecimalSeparator.point);
      expect(
          page, commaPage.copyWith(decimalSeparator: DecimalSeparator.point));
    });
  });

  test('decode (the map form) takes the same hook', () {
    final doc = withPage();
    final json = DraftDocumentCodec.encode(doc);
    final back = DraftDocumentCodec.decode(json,
        registerComponents: PageComponent.register);
    expect(back.components.get<PageComponent>(back.rootHandle),
        doc.components.get<PageComponent>(doc.rootHandle));
  });
}
