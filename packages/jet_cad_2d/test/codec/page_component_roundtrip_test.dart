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

  test('decode (the map form) takes the same hook', () {
    final doc = withPage();
    final json = DraftDocumentCodec.encode(doc);
    final back = DraftDocumentCodec.decode(json,
        registerComponents: PageComponent.register);
    expect(back.components.get<PageComponent>(back.rootHandle),
        doc.components.get<PageComponent>(doc.rootHandle));
  });
}
