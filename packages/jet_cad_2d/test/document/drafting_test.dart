import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

DraftDocument _doc() => DraftDocument.empty(measurer: MetricModelMeasurer());

EntityRecord _record(DraftDocument doc, Handle h) =>
    doc.entities.read(doc.entities.slotOf(h)!);

GeometryPayload _payload(DraftDocument doc, Handle h) =>
    doc.geometry.read(doc.entities.geomIndexAt(doc.entities.slotOf(h)!));

// Off-lattice, off-origin corners: a copy error shows in the low bits.
final Vector2 c1 = Vector2(7137.3, 3161.7);
final Vector2 c2 = Vector2(7300.9, 3190.1);

void main() {
  test('E1 draftRecord carries the D2 defaults, owned by the given owner', () {
    final r = draftRecord(
        const Handle(0x51), const Handle(0x11), EntityKind.text,
        text: 'Hall');
    expect(r.handle, const Handle(0x51));
    expect(r.owner, const Handle(0x11));
    expect(r.kind, EntityKind.text);
    expect(r.layer, ReservedHandles.layerZero);
    expect(r.linetype, ReservedHandles.byLayerLinetype);
    expect(r.linetypeScale, 1.0);
    expect(r.color, const ByLayerColor());
    expect(r.lineweight, kByLayer);
    expect(r.transparency, kByLayer);
    expect(r.flags, 0);
    expect(r.text, 'Hall');
    expect(r.textStyle, ReservedHandles.standardTextStyle);
    expect(r.textAttrs, 0, reason: 'left, baseline, no override bits (D2)');
  });

  test('E2 addDrafted allocates from the seed when built, and does not run',
      () {
    final doc = _doc();
    final before = doc.handleSeed.current;
    final cmd = addDrafted(doc, EntityKind.line, linePayload(c1, c2));
    expect(cmd.record.handle.value, before.value + 1);
    expect(cmd.record.owner, doc.rootHandle);
    expect(doc.entities.liveCount, 0, reason: 'built, not executed');
    doc.commands.execute(cmd);
    expect(_payload(doc, cmd.record.handle).coords,
        Float64List.fromList([c1.x, c1.y, c2.x, c2.y]));
  });

  test(
      'E3 draw, undo, draw again: the second handle is never the first '
      '(M-05d)', () {
    final doc = _doc();
    final a = addDrafted(doc, EntityKind.line, linePayload(c1, c2));
    doc.commands.execute(a);
    doc.commands.undo();
    final b = addDrafted(doc, EntityKind.line, linePayload(c2, c1));
    doc.commands.execute(b);
    expect(b.record.handle, isNot(a.record.handle),
        reason: 'handles are never reissued');
    expect(b.record.handle.value, greaterThan(a.record.handle.value));
  });

  test('E4 undo removes a drafted entity and redo restores the same handle',
      () {
    final doc = _doc();
    final a = addDrafted(doc, EntityKind.line, linePayload(c1, c2));
    doc.commands.execute(a);
    final b = addDrafted(doc, EntityKind.circle, circlePayload(c2, 40));
    doc.commands.execute(b);
    final full = DraftDocumentCodec.encodeToString(doc);
    doc.commands.undo();
    doc.commands.undo();
    expect(doc.entities.liveCount, 0);
    doc.commands.redo();
    doc.commands.redo();
    expect(DraftDocumentCodec.encodeToString(doc), full,
        reason: 'exit criterion 2: same handles, same bytes');
  });

  test('E5 a rectangle is five exact corners and round-trips closed (M-05b)',
      () {
    final p = rectanglePayload(c1, c2);
    expect(
        p.coords,
        Float64List.fromList(
            [c1.x, c1.y, c2.x, c1.y, c2.x, c2.y, c1.x, c2.y, c1.x, c1.y]));
    expect(p.scalars, isEmpty);
    expect(isClosedPolyline(p), isTrue);
    final doc = _doc();
    final cmd = addDrafted(doc, EntityKind.polyline, p);
    doc.commands.execute(cmd);
    final back = DraftDocumentCodec.decodeString(
        DraftDocumentCodec.encodeToString(doc),
        measurer: MetricModelMeasurer());
    final q = _payload(back, cmd.record.handle);
    expect(q, p, reason: 'GeometryPayload == compares exactly');
    expect(isClosedPolyline(q), isTrue);
  });

  test('E6 polylinePayload copies points, and closed repeats the first', () {
    final pts = [c1, Vector2(7200.25, 3000.5), c2];
    final open = polylinePayload(pts);
    expect(open.pointCount, 3);
    expect(isClosedPolyline(open), isFalse);
    final closed = polylinePayload(pts, closed: true);
    expect(closed.pointCount, 4);
    expect(closed.coords[6], c1.x);
    expect(closed.coords[7], c1.y);
    expect(isClosedPolyline(closed), isTrue);
    pts[0].setValues(0, 0);
    expect(open.coords[0], 7137.3, reason: 'a copy, not a view');
  });

  test(
      'E7 text: height is cap height, and width and oblique inherit the '
      'style (M-05c, M-05t)', () {
    final doc = _doc();
    const heightMm = 50.0; // 2.5 paper mm at 1:20
    final cmd = addDrafted(doc, EntityKind.text, textPayload(c1, heightMm),
        text: 'Living');
    doc.commands.execute(cmd);
    final r = _record(doc, cmd.record.handle);
    final payload = _payload(doc, cmd.record.handle);
    expect(payload.scalars, Float64List.fromList([heightMm, 0, 1, 0]));
    // Rendered cap height: the text transform maps a capital's height in
    // glyph space onto exactly heightMm in model space.
    final style = doc.textStyleOf(r.textStyle);
    final metrics = doc.textMeasurer.measure(text: r.text, style: style);
    final t = textLocalTransform(
        resolveTextAttributes(payload, r.textAttrs, style), metrics, c1);
    final capTop = t.transformPoint(Vector2(0, metrics.capHeight));
    final base = t.transformPoint(Vector2.zero());
    expect((capTop - base).length, closeTo(heightMm, 1e-9),
        reason: 'DXF height is cap height, not em height (M-05c)');
    // M-05t: with the style's width factor at 0.8, the placed text is 0.8
    // wide — the payload's 1 is padding, not an override.
    doc.tables.textStyles.remove(ReservedHandles.standardTextStyle);
    doc.tables.textStyles.add(const TextStyleRecord(
        handle: ReservedHandles.standardTextStyle,
        name: 'Standard',
        fontFamily: 'Roboto',
        widthFactor: 0.8));
    final resolved = resolveTextAttributes(
        payload, r.textAttrs, doc.textStyleOf(r.textStyle));
    expect(resolved.widthFactor, 0.8);
  });

  test('E8 textHeightMm is 2.5 paper mm at the page scale (M-05j)', () {
    expect(textHeightMm(null), 2.5);
    expect(textHeightMm(PageComponent(scaleDenominator: 20)), 50.0);
    expect(textHeightMm(PageComponent(scaleDenominator: 100)), 250.0);
  });

  test(
      'E9 addDraftedRegion: a rectangle and a circle fill; a bow tie does '
      'not (M-05q)', () {
    final doc = _doc();
    final seed = doc.handleSeed.current;
    final rect =
        addDraftedRegion(doc, EntityKind.polyline, rectanglePayload(c1, c2))!;
    expect(rect.fill.handle.value, lessThan(rect.boundary.handle.value),
        reason: 'the fill draws under its boundary (invariant 6)');
    expect(rect.fill.color, kDraftFillColor);
    expect(rect.boundary.color, const ByLayerColor());
    expect(rect.boundary.lineweight, kLineweightDefault);
    doc.commands.execute(rect);
    expect(doc.fills.fillsOf(rect.boundary.handle), [rect.fill.handle]);
    expect(doc.commands.undoDepth, 1, reason: 'one command, one undo step');

    final circle =
        addDraftedRegion(doc, EntityKind.circle, circlePayload(c2, 40));
    expect(circle, isNotNull,
        reason: "a circle's empty triangulation is its normal case");

    final before = doc.handleSeed.current;
    final bowTie = polylinePayload([
      Vector2(7000, 3000),
      Vector2(7100, 3100),
      Vector2(7100, 3000),
      Vector2(7000, 3100),
    ], closed: true);
    expect(triangulationFor(EntityKind.polyline, bowTie), isEmpty,
        reason: 'empty, not null: why D11 needs its own refusal');
    expect(addDraftedRegion(doc, EntityKind.polyline, bowTie), isNull);
    expect(doc.handleSeed.current, before, reason: 'a refusal allocates none');
    expect(
        addDraftedRegion(
            doc, EntityKind.polyline, polylinePayload([c1, c2, c1 + c2])),
        isNull,
        reason: 'an open polyline cannot fill');
    expect(seed.value, lessThan(doc.handleSeed.current.value));
  });

  test('E10 the degeneracy predicates decide under Tolerance', () {
    final tiny = Vector2(c1.x + 1e-10, c1.y);
    expect(isDegenerateSegment(c1, tiny), isTrue);
    expect(isDegenerateSegment(c1, c2), isFalse);
    expect(isDegenerateRectangle(c1, Vector2(c2.x, c1.y)), isTrue);
    expect(isDegenerateRectangle(c1, Vector2(c1.x, c2.y)), isTrue);
    expect(isDegenerateRectangle(c1, c2), isFalse);
    expect(isDegenerateRadius(0), isTrue);
    expect(isDegenerateRadius(1e-10), isTrue);
    expect(isDegenerateRadius(0.001), isFalse);
  });
}
