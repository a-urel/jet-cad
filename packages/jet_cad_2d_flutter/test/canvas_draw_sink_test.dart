import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

const ResolvedStyle _red = ResolvedStyle(
    argb: 0xFFFF0000,
    lineweightHundredths: 25,
    linetype: ReservedHandles.continuousLinetype,
    linetypeScale: 1.0);

CanvasDrawSink _sinkOn(PictureRecorder recorder) =>
    CanvasDrawSink(canvas: Canvas(recorder), pixelsPerPaperMm: 8.0);

void _line(CanvasDrawSink sink, double x, ResolvedStyle style) {
  sink.beginResidual(Transform2.translation(0, 0));
  sink.polyline(Float64List.fromList([x, 0, x, 50]), 2, style, closed: false);
  sink.endResidual();
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
}
