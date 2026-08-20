import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'support/spy_canvas.dart';

const ResolvedStyle _red = ResolvedStyle(
    argb: 0xFFFF0000,
    lineweightHundredths: 25,
    linetype: ReservedHandles.continuousLinetype,
    linetypeScale: 1.0);

const TextStyleRecord _standard =
    TextStyleRecord(handle: Handle(11), name: 'Standard', fontFamily: 'Roboto');

CanvasDrawSink _sinkOn(PictureRecorder recorder,
        {FlutterTextMeasurer? measurer}) =>
    CanvasDrawSink(
        canvas: Canvas(recorder),
        pixelsPerPaperMm: 8.0,
        measurer: measurer ?? FlutterTextMeasurer(),
        textStyleOf: (Handle handle) => _standard);

void _line(CanvasDrawSink sink, double x, ResolvedStyle style) {
  sink.beginResidual(Transform2.translation(0, 0));
  sink.polyline(Float64List.fromList([x, 0, x, 50]), 2, style, closed: false);
  sink.endResidual();
}

/// Everything the sink pushed onto the canvas before it drew, folded into one
/// transform.
///
/// Composed rather than asserted call by call: what matters is where a
/// paragraph-space point lands, not which of `transform`, `translate` and
/// `scale` the sink used to get it there.
Transform2 _transformBeforeDraw(SpyCanvas spy, String drawCall) {
  var m = Transform2.identity();
  for (final call in spy.calls) {
    if (call.name == drawCall) break;
    switch (call.name) {
      case 'transform':
        final v = call.args[0]! as Float64List;
        m = m.multiply(Transform2(v[0], v[1], v[4], v[5], v[12], v[13]));
      case 'translate':
        m = m.multiply(Transform2.translation(
            call.args[0]! as double, call.args[1]! as double));
      case 'scale':
        m = m.multiply(
            Transform2.scale(call.args[0]! as double, call.args[1]! as double));
    }
  }
  return m;
}

void main() {
  test('every primitive issues its own canvas call', () {
    // The counter outlives the batching. Plan 3b measured four coalescing
    // modes and all four were slower than this one, so what the sink does is
    // one call per primitive — and that is now an assertion rather than an
    // absence.
    final recorder = PictureRecorder();
    final sink = _sinkOn(recorder);
    for (var i = 0; i < 5; i++) {
      _line(sink, i * 10.0, _red);
    }
    sink.beginResidual(Transform2(2, 0, 0, 2, 5, 5));
    sink.circle(0, 0, 4, _red);
    sink.endResidual();
    expect(sink.canvasCallCount, 6);
  });

  test('resetCounters zeroes the count without touching the canvas', () {
    final recorder = PictureRecorder();
    final sink = _sinkOn(recorder);
    _line(sink, 0, _red);
    expect(sink.canvasCallCount, 1);
    sink.resetCounters();
    expect(sink.canvasCallCount, 0);
    _line(sink, 10, _red);
    expect(sink.canvasCallCount, 1);
  });

  test('text resolves a paragraph through the measurer and draws it', () {
    final recorder = PictureRecorder();
    final measurer = FlutterTextMeasurer();
    final sink = _sinkOn(recorder, measurer: measurer);
    sink.beginResidual(Transform2.translation(10, 20));
    sink.text('WC', const Handle(7), _red);
    sink.endResidual();
    expect(sink.canvasCallCount, 1);
    // The sink resolved the style handle and asked the measurer to lay the
    // string out — the same paragraph a direct paragraphFor call would hand
    // back, since both go through the same cache key.
    expect(measurer.layoutCount, 1);
    expect(measurer.liveParagraphCount, 1);
  });

  test('a paragraph is drawn in glyph space, y up, not paragraph space', () {
    // Two coordinate systems meet here and only one of them is `dart:ui`'s.
    // `Canvas.drawParagraph` lays glyphs out with y increasing *downward*
    // from the top of the first line. The residual the painter composes maps
    // *glyph* space — y up, origin on the baseline — because that is the
    // space `textLocalBounds` and therefore `entityBounds` are expressed in,
    // and the camera has already flipped y once on the way there. Nothing
    // else in this sink reconciles the two, so if this does not, every string
    // renders mirrored about its own baseline while every box in the document
    // stays right — a defect no bounds, pick or differential test can see.
    final spy = SpyCanvas();
    final measurer = FlutterTextMeasurer();
    final sink = CanvasDrawSink(
        canvas: spy,
        pixelsPerPaperMm: 8.0,
        measurer: measurer,
        textStyleOf: (Handle handle) => _standard);
    // The shape of residual the camera actually hands the painter: y flipped.
    sink.beginResidual(Transform2(1, 0, 0, -1, 0, 0));
    sink.text('WC', const Handle(7), _red);
    sink.endResidual();

    // The offset is part of the claim: a sink that drew at a non-zero offset
    // would place the string somewhere this composition does not describe.
    expect(spy.named('drawParagraph').single.args[1], Offset.zero);

    final composed = _transformBeforeDraw(spy, 'drawParagraph');
    final baseline = measurer
        .paragraphFor('WC', const Handle(7), _standard, _red.argb)
        .alphabeticBaseline;
    final top = composed.transformPoint(Vector2.zero());
    final base = composed.transformPoint(Vector2(0, baseline));
    final descender = composed.transformPoint(Vector2(0, baseline + 10));

    // The baseline lands on the residual's origin, which is what the residual
    // was composed to put it on ...
    expect(base.y, closeTo(0.0, 1e-9));
    // ... the top of the line sits above it on screen ...
    expect(top.y, lessThan(base.y - 1));
    // ... and a descender below it. All three reverse without the flip.
    expect(descender.y, greaterThan(base.y + 1));
    // x is untouched: the flip is vertical only, or every glyph would also
    // read backwards.
    expect(composed.transformPoint(Vector2(7, baseline)).x, closeTo(7.0, 1e-9));
  });

  test('the paragraph baseline is the ascent the glyph box is built from', () {
    // The flip above lifts by `alphabeticBaseline`; `textLocalBounds` puts the
    // box top at `TextMetrics.ascent`. They are two readings of one number and
    // the drawn glyphs sit inside the drawn box only while they agree.
    final measurer = FlutterTextMeasurer();
    for (final text in ['WC', 'Ay', 'STAIR 12']) {
      final paragraph =
          measurer.paragraphFor(text, const Handle(7), _standard, _red.argb);
      final metrics = measurer.measure(text: text, style: _standard);
      expect(paragraph.alphabeticBaseline, closeTo(metrics.ascent, 1e-9),
          reason: text);
    }
  });
}
