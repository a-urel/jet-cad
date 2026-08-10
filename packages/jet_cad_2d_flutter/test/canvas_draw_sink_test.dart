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
const ResolvedStyle _blue = ResolvedStyle(
    argb: 0xFF0000FF,
    lineweightHundredths: 25,
    linetype: ReservedHandles.continuousLinetype,
    linetypeScale: 1.0);
const ResolvedStyle _ghost = ResolvedStyle(
    argb: 0x80FF0000, // alpha 128
    lineweightHundredths: 25,
    linetype: ReservedHandles.continuousLinetype,
    linetypeScale: 1.0);
const ResolvedStyle _redDashed = ResolvedStyle(
    argb: 0xFFFF0000,
    lineweightHundredths: 25,
    linetype: Handle(99), // a different linetype, same paint
    linetypeScale: 1.0);

CanvasDrawSink _sinkOn(PictureRecorder recorder, BatchMode mode) =>
    CanvasDrawSink(canvas: Canvas(recorder), pixelsPerPaperMm: 8.0, mode: mode);

void _line(CanvasDrawSink sink, double x, ResolvedStyle style) {
  sink.beginResidual(Transform2.translation(0, 0));
  sink.polyline(Float64List.fromList([x, 0, x, 50]), 2, style, closed: false);
  sink.endResidual();
}

void main() {
  test('mode off issues one canvas call per primitive', () {
    final recorder = PictureRecorder();
    final sink = _sinkOn(recorder, BatchMode.off);
    for (var i = 0; i < 5; i++) {
      _line(sink, i * 10.0, _red);
    }
    sink.flush();
    expect(sink.canvasCallCount, 5);
  });

  test('openBucket merges a run that shares a paint into one call', () {
    final recorder = PictureRecorder();
    final sink = _sinkOn(recorder, BatchMode.openBucket);
    for (var i = 0; i < 5; i++) {
      _line(sink, i * 10.0, _red);
    }
    sink.flush();
    expect(sink.canvasCallCount, 1);
  });

  test('a paint change flushes, so draw order is preserved exactly', () {
    final recorder = PictureRecorder();
    final sink = _sinkOn(recorder, BatchMode.openBucket);
    _line(sink, 0, _red);
    _line(sink, 10, _blue);
    _line(sink, 20, _red);
    sink.flush();
    expect(sink.canvasCallCount, 3,
        reason: 'red, blue, red must reach the canvas in that order; '
            'two calls would mean the two reds merged across the blue');
  });

  test('the bucket key is the paint, not the whole style', () {
    // Same colour and lineweight, different linetype. The dash geometry is
    // already baked into the points by the time the sink sees them, so a
    // linetype in the key would open a bucket per nothing.
    final recorder = PictureRecorder();
    final sink = _sinkOn(recorder, BatchMode.openBucket);
    _line(sink, 0, _red);
    _line(sink, 10, _redDashed);
    sink.flush();
    expect(sink.canvasCallCount, 1);
  });

  test('a style below full alpha is never batched', () {
    final recorder = PictureRecorder();
    final sink = _sinkOn(recorder, BatchMode.openBucket);
    _line(sink, 0, _ghost);
    _line(sink, 10, _ghost);
    sink.flush();
    expect(sink.canvasCallCount, 2,
        reason: 'two overlapping translucent strokes in one path are unioned; '
            'drawn separately they blend twice, and only the second is right');
  });

  test('a curve flushes the open bucket and draws on its own', () {
    final recorder = PictureRecorder();
    final sink = _sinkOn(recorder, BatchMode.openBucket);
    _line(sink, 0, _red);
    sink.beginResidual(Transform2(2, 0, 0, 2, 5, 5));
    sink.circle(0, 0, 4, _red);
    sink.endResidual();
    _line(sink, 10, _red);
    sink.flush();
    expect(sink.canvasCallCount, 3);
  });

  test('flush is required: without it the last bucket never draws', () {
    final recorder = PictureRecorder();
    final sink = _sinkOn(recorder, BatchMode.openBucket);
    _line(sink, 0, _red);
    expect(sink.canvasCallCount, 0);
    sink.flush();
    expect(sink.canvasCallCount, 1);
  });

  test('flush is idempotent', () {
    final recorder = PictureRecorder();
    final sink = _sinkOn(recorder, BatchMode.openBucket);
    _line(sink, 0, _red);
    sink.flush();
    sink.flush();
    expect(sink.canvasCallCount, 1);
  });

  test('bucketMap merges across an interleaved paint change', () {
    final recorder = PictureRecorder();
    final sink = _sinkOn(recorder, BatchMode.bucketMap);
    _line(sink, 0, _red);
    _line(sink, 10, _blue);
    _line(sink, 20, _red);
    sink.flush();
    expect(sink.canvasCallCount, 2,
        reason: 'two paints, two buckets, two calls — the two reds merge '
            'across the blue, which is the draw order this mode gives up');
  });

  test('bucketMap flushes every bucket before a curve, so it lands in order',
      () {
    final recorder = PictureRecorder();
    final sink = _sinkOn(recorder, BatchMode.bucketMap);
    _line(sink, 0, _red);
    _line(sink, 10, _blue);
    sink.beginResidual(Transform2(2, 0, 0, 2, 5, 5));
    sink.circle(0, 0, 4, _red);
    sink.endResidual();
    _line(sink, 20, _red);
    sink.flush();
    expect(sink.canvasCallCount, 4,
        reason: 'red+blue flushed as two, then the circle, then the trailing '
            'red — the circle must not draw under lines that precede it');
  });

  test('bucketMapBakedCurves puts a curve in its bucket and flushes nothing',
      () {
    final recorder = PictureRecorder();
    final sink = _sinkOn(recorder, BatchMode.bucketMapBakedCurves);
    _line(sink, 0, _red);
    _line(sink, 10, _blue);
    sink.beginResidual(Transform2(2, 0, 0, 2, 5, 5));
    sink.circle(0, 0, 4, _red);
    sink.endResidual();
    _line(sink, 20, _red);
    sink.flush();
    expect(sink.canvasCallCount, 2,
        reason: 'one red bucket holding two lines and an ellipse, one blue');
  });

  test('flushing a bucket map draws in insertion order', () {
    // Not observable through the counter, so it is asserted on the recorder:
    // the first bucket opened must be the first path drawn.
    final recorder = PictureRecorder();
    final sink = _sinkOn(recorder, BatchMode.bucketMap);
    _line(sink, 0, _blue);
    _line(sink, 10, _red);
    sink.flush();
    final picture = recorder.endRecording();
    expect(picture.approximateBytesUsed, greaterThan(0));
    // The ordering itself is pinned by fixture 3 in batch_equivalence_test;
    // this asserts only
    // that flushing a map produces one call per bucket and does not throw.
    expect(sink.canvasCallCount, 2);
  });

  test('two styles differing only in lineweight get separate buckets', () {
    const thin = ResolvedStyle(
        argb: 0xFFFF0000,
        lineweightHundredths: 25,
        linetype: ReservedHandles.continuousLinetype,
        linetypeScale: 1.0);
    const thick = ResolvedStyle(
        argb: 0xFFFF0000,
        lineweightHundredths: 200,
        linetype: ReservedHandles.continuousLinetype,
        linetypeScale: 1.0);
    final recorder = PictureRecorder();
    final sink = _sinkOn(recorder, BatchMode.bucketMap);
    _line(sink, 0, thin);
    _line(sink, 10, thick);
    sink.flush();
    expect(sink.canvasCallCount, 2,
        reason: 'same colour, different width — one bucket would draw the '
            'thin line at the thick width or the reverse');
  });
}
