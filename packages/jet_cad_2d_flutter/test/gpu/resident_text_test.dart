import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

const TextStyleRecord _standard =
    TextStyleRecord(handle: Handle(11), name: 'Standard', fontFamily: 'Roboto');

/// Fixed metrics, so the box below is arithmetic rather than font trivia:
/// advance 40, ascent 8, descent 2 -> glyph box (0, -2) .. (40, 8).
class _FixedMeasurer implements TextMeasurer {
  const _FixedMeasurer();
  @override
  TextMetrics measure({required String text, required TextStyleRecord style}) =>
      const TextMetrics(advanceWidth: 40, ascent: 8, descent: 2, capHeight: 7);
}

const ResolvedStyle _style = ResolvedStyle(
    argb: 0xFF112233,
    lineweightHundredths: 25,
    linetype: Handle.none,
    linetypeScale: 1);

GeometryCollector _collector({double dpr = 2.0}) => GeometryCollector(
    pixelsPerPaperMm: 3.78,
    devicePixelRatio: dpr,
    measurer: const _FixedMeasurer(),
    textStyleOf: (Handle h) => _standard);

void main() {
  test('a text op becomes one record carrying the residual, flat', () {
    final c = _collector();
    // Rotated, sheared, non-uniform, off-origin: an identity residual would
    // leave b == c == 0 and hide a transposed element.
    const t = Transform2(2, 3, 5, 7, 110, -40);
    c.beginResidual(t, debugHandle: const Handle(901));
    c.text('WC', const Handle(11), _style);
    c.endResidual();

    expect(c.texts, hasLength(1));
    expect(c.skippedOps, 0, reason: 'text is recorded now, not counted');
    final r = c.texts.single;
    expect(r.text, 'WC');
    expect(r.style, const Handle(11));
    expect(r.argb, 0xFF112233);
    expect([r.a, r.b, r.c, r.d, r.e, r.f], [2, 3, 5, 7, 110, -40]);
  });

  test('the instance index is the number of instances written before it', () {
    final c = _collector();
    c.beginResidual(Transform2.translation(10, 10));
    c.polyline(Float64List.fromList([0, 0, 50, 0, 50, 40]), 3, _style,
        closed: false);
    c.endResidual();
    final before = c.instanceCount;
    expect(before, greaterThan(0));
    c.beginResidual(Transform2.translation(20, 20));
    c.text('A', const Handle(11), _style);
    c.endResidual();
    c.beginResidual(Transform2.translation(10, 10));
    c.polyline(Float64List.fromList([0, 0, 5, 5]), 2, _style, closed: false);
    c.endResidual();
    expect(c.texts.single.instanceIndex, before,
        reason: 'instances at or past this index were emitted AFTER the label');
  });

  test('the box is the four transformed corners, padded at the band floor', () {
    // dpr 2, band floor 0.5: one device pixel is 1 / (2 * 0.5) = 1.0
    // collection unit of padding.
    final c = _collector(dpr: 2.0);
    // A pure rotation by 90 degrees about the origin, then a translation:
    // glyph box (0,-2)..(40,8) rotates to (-8,0)..(2,40), so a classifier
    // that transformed only min and max corners (instead of all four) gets
    // a box with a negative width.
    final t = Transform2.translation(100, 200)
        .multiply(Transform2.rotation(3.141592653589793 / 2));
    c.beginResidual(t);
    c.text('WC', const Handle(11), _style);
    c.endResidual();
    final r = c.texts.single;
    expect(r.boxMinX, closeTo(100 - 8 - 1, 1e-6));
    expect(r.boxMaxX, closeTo(100 + 2 + 1, 1e-6));
    expect(r.boxMinY, closeTo(200 + 0 - 1, 1e-6));
    expect(r.boxMaxY, closeTo(200 + 40 + 1, 1e-6));
  });

  test('the pad is one device pixel at the band floor, not at the ceiling', () {
    // The pad must be the LARGEST one device pixel is inside the band:
    // 1 / (dpr * kBandLowerScale). At dpr 1 and floor 0.5 that is 2.0
    // collection units; a pad taken at the ceiling would be 0.5.
    final c = _collector(dpr: 1.0);
    c.beginResidual(Transform2.identity());
    c.text('WC', const Handle(11), _style);
    c.endResidual();
    final r = c.texts.single;
    expect(r.boxMinX, closeTo(0 - 1 / (1.0 * kBandLowerScale), 1e-9));
    expect(r.boxMaxX, closeTo(40 + 1 / (1.0 * kBandLowerScale), 1e-9));
  });

  test('a mirrored residual still yields min <= max', () {
    final c = _collector();
    c.beginResidual(const Transform2(-1, 0, 0, 1, 0, 0));
    c.text('WC', const Handle(11), _style);
    c.endResidual();
    final r = c.texts.single;
    expect(r.boxMinX, lessThan(r.boxMaxX));
    expect(r.boxMinX, closeTo(-40 - 1, 1e-6));
  });

  test('without a measurer, text is counted and not recorded (Ruling E2)', () {
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 1.0);
    c.beginResidual(Transform2.identity());
    c.text('WC', const Handle(11), _style);
    c.endResidual();
    expect(c.texts, isEmpty);
    expect(c.skippedOps, 1);
  });

  test('the text list is in emission order and is not sortable by handle', () {
    final c = _collector();
    for (final s in ['C', 'A', 'B']) {
      c.beginResidual(Transform2.identity());
      c.text(s, const Handle(11), _style);
      c.endResidual();
    }
    expect(c.texts.map((r) => r.text), ['C', 'A', 'B']);
    expect(() => c.texts.add(c.texts.first), throwsUnsupportedError,
        reason: 'the list handed out is a view; nobody reorders it');
  });

  test('the band constants and the pad are what the spec says', () {
    expect(kBandLowerScale, 0.5);
    expect(kBandUpperScale, 2.0);
    expect(kTextBoxPadDevicePixels, 1.0);
    expect(kMiterLimit, VerticesDrawSink.kMiterLimit,
        reason: 'a copy, pinned to the oracle so it cannot drift');
  });

  test('boundTransformedBox: a 90-degree rotation of the box re-bounds it', () {
    // (0,-2)..(40,8) rotated 90 degrees about the origin -> (-8,0)..(2,40),
    // the same rotation the box test above checks end to end. A classifier
    // that transformed only two corners (instead of all four) would get a
    // box with a negative width here.
    final out = Float64List(4);
    boundTransformedBox(
        0, -2, 40, 8, Transform2.rotation(3.141592653589793 / 2), out);
    expect(out[0], closeTo(-8, 1e-9));
    expect(out[1], closeTo(0, 1e-9));
    expect(out[2], closeTo(2, 1e-9));
    expect(out[3], closeTo(40, 1e-9));
  });

  test('boundTransformedBox: a mirror still yields min <= max', () {
    final out = Float64List(4);
    boundTransformedBox(0, -2, 40, 8, const Transform2(-1, 0, 0, 1, 0, 0), out);
    expect(out[0], lessThanOrEqualTo(out[2]));
    expect(out[1], lessThanOrEqualTo(out[3]));
  });
}
