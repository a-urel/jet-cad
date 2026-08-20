// The vertices sink turns each stroked segment into two triangles itself
// instead of handing `Canvas` one `drawPath` per segment. A performance spike
// with no correctness check is worthless — a sink that emits nothing is very
// fast — so the triangles are pinned here before anything is measured.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/vertices_draw_sink.dart';

/// 0.25 mm at 4 px/mm is exactly 1 device pixel, so the half-width is 0.5 and
/// every expected coordinate below is exact in binary.
const _lw = 25;
const _pxPerMm = 4.0;

ResolvedStyle _style({int argb = 0xFF000000, int lineweight = _lw}) =>
    ResolvedStyle(
      argb: argb,
      lineweightHundredths: lineweight,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
    );

VerticesDrawSink _sink() => VerticesDrawSink(pixelsPerPaperMm: _pxPerMm);

Float64List _seg(double x0, double y0, double x1, double y1) =>
    Float64List.fromList([x0, y0, x1, y1]);

void main() {
  test('a segment becomes two triangles a half-width either side of it', () {
    final sink = _sink()
      ..beginResidual(Transform2.identity())
      ..polyline(_seg(0, 0, 10, 0), 2, _style(), closed: false)
      ..endResidual();

    // Emitted as the triangle pair (A, B, C), (B, D, C) with
    // A = p0 + n, B = p0 - n, C = p1 + n, D = p1 - n and n the left normal
    // of half the stroke width.
    expect(
        sink.debugPositions(),
        orderedEquals(<double>[
          0, 0.5, 0, -0.5, 10, 0.5, //
          0, -0.5, 10, -0.5, 10, 0.5,
        ]));
  });

  test('the residual is baked into the positions, not pushed on the canvas',
      () {
    // A quarter turn: local +x becomes device +y.
    const t = Transform2(0, 1, -1, 0, 100, 200);
    final sink = _sink()
      ..beginResidual(t)
      ..polyline(_seg(0, 0, 10, 0), 2, _style(), closed: false)
      ..endResidual();

    final v = sink.debugPositions();
    // The segment now runs from (100, 200) to (100, 210), so its normal points
    // along -x and the corners straddle x = 100.
    expect(v.sublist(0, 6),
        orderedEquals(<double>[99.5, 200, 100.5, 200, 99.5, 210]));
  });

  test('stroke width is device pixels under a non-uniform residual', () {
    // 3x in x, 1x in y. `CanvasDrawSink` divides one scalar, `sqrt(3)`, into a
    // width that `Canvas` then scales by two different amounts; baking the
    // transform into the positions removes the approximation, so the width is
    // exactly 1 device pixel on both axes.
    //
    // MUTATION: take the perpendicular in local space and transform it with
    // the segment, and this reads 3 for the horizontal case.
    const t = Transform2(3, 0, 0, 1, 0, 0);

    final horizontal = _sink()
      ..beginResidual(t)
      ..polyline(_seg(0, 0, 10, 0), 2, _style(), closed: false)
      ..endResidual();
    final h = horizontal.debugPositions();
    expect(h[1] - h[3], closeTo(1.0, 1e-12), reason: 'horizontal width');

    final vertical = _sink()
      ..beginResidual(t)
      ..polyline(_seg(0, 0, 0, 10), 2, _style(), closed: false)
      ..endResidual();
    final w = vertical.debugPositions();
    expect(w[2] - w[0], closeTo(1.0, 1e-12), reason: 'vertical width');
  });

  test('a polyline of n points emits n-1 segments, and closed adds one more',
      () {
    final open = _sink()
      ..beginResidual(Transform2.identity())
      ..polyline(Float64List.fromList([0, 0, 10, 0, 10, 10]), 3, _style(),
          closed: false)
      ..endResidual();
    expect(open.debugPositions().length, 2 * 6 * 2);

    final closed = _sink()
      ..beginResidual(Transform2.identity())
      ..polyline(Float64List.fromList([0, 0, 10, 0, 10, 10]), 3, _style(),
          closed: true)
      ..endResidual();
    expect(closed.debugPositions().length, 3 * 6 * 2);
  });

  test('colour rides on the vertices, so one buffer carries every colour', () {
    final sink = _sink()..beginResidual(Transform2.identity());
    sink.polyline(_seg(0, 0, 10, 0), 2, _style(argb: 0xFFFF0000),
        closed: false);
    // Different lineweight as well as different colour: the width is already
    // spent on the triangles, so it cannot split anything either.
    sink.polyline(
        _seg(0, 5, 10, 5), 2, _style(argb: 0xFF00FF00, lineweight: 50),
        closed: false);
    sink.endResidual();

    expect(sink.debugPositions().length, 2 * 6 * 2);
    expect(sink.debugColors().length, 2 * 6);
    // `Vertices.raw` takes `Int32List`, so an ARGB above 0x7FFFFFFF is stored
    // as its signed twin. `toUnsigned(32)` reads it back as written.
    final colors = sink.debugColors().map((c) => c.toUnsigned(32)).toList();
    expect(colors.sublist(0, 6), everyElement(0xFFFF0000));
    expect(colors.sublist(6, 12), everyElement(0xFF00FF00));
  });

  test('draw order survives batching: segments stay in emission order', () {
    // The bug the first cut of this sink shipped. One buffer per colour meant
    // every red segment drew after every green one whatever the walk said, and
    // a screenshot of the harness showed it plainly: strokes are opaque, so a
    // reordered stroke covers a different neighbour. Draw order is ascending
    // handle value and the walk emits in that order, so the buffer must keep
    // the order it was given.
    //
    // MUTATION: group the vertices by colour before flushing, and this reads
    // red, red, green.
    final sink = _sink()..beginResidual(Transform2.identity());
    sink.polyline(_seg(0, 0, 10, 0), 2, _style(argb: 0xFFFF0000),
        closed: false);
    sink.polyline(_seg(0, 1, 10, 1), 2, _style(argb: 0xFF00FF00),
        closed: false);
    sink.polyline(_seg(0, 2, 10, 2), 2, _style(argb: 0xFFFF0000),
        closed: false);
    sink.endResidual();

    final colors = sink.debugColors().map((c) => c.toUnsigned(32)).toList();
    expect([colors[0], colors[6], colors[12]],
        orderedEquals(<int>[0xFFFF0000, 0xFF00FF00, 0xFFFF0000]));
    // And the positions agree: the middle segment is the one at y = 1.
    expect(sink.debugPositions()[13], closeTo(1.5, 1e-12));
  });

  test('one flush, one draw call, whatever the colours', () {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final sink = _sink()..beginResidual(Transform2.identity());
    for (var i = 0; i < 5; i++) {
      sink.polyline(_seg(0, i * 1.0, 10, i * 1.0), 2,
          _style(argb: 0xFF000000 | (i * 0x203040)),
          closed: false);
    }
    sink.endResidual();
    sink.flush(canvas);
    expect(sink.flushCallCount, 1);
    expect(sink.lastFlushSegmentCount, 5);
    // What was submitted, not what was counted: a flush that rewound first
    // would report a full segment count over an empty buffer.
    expect(sink.lastFlushVertexCount, 5 * 6);
    // Rewound, not reallocated.
    expect(sink.debugPositions(), isEmpty);
    recorder.endRecording().dispose();
  });

  test('a zero-length segment emits nothing rather than a NaN normal', () {
    final sink = _sink()
      ..beginResidual(Transform2.identity())
      ..polyline(_seg(3, 4, 3, 4), 2, _style(), closed: false)
      ..endResidual();
    expect(sink.debugPositions(), isEmpty);
  });

  test('the batched buffers survive a residual ending', () {
    // The whole point of batching is that a buffer outlives the residual that
    // filled it, so `endResidual` must not flush or clear.
    final sink = _sink();
    sink.beginResidual(const Transform2(1, 0, 0, 1, 0, 0));
    sink.polyline(_seg(0, 0, 10, 0), 2, _style(), closed: false);
    sink.endResidual();
    sink.beginResidual(const Transform2(1, 0, 0, 1, 0, 50));
    sink.polyline(_seg(0, 0, 10, 0), 2, _style(), closed: false);
    sink.endResidual();

    final v = sink.debugPositions();
    expect(v.length, 2 * 6 * 2);
    // Second segment carried its own residual's translation.
    expect(v[13], closeTo(50.5, 1e-12));
  });

  test('the segment count is what a rig reads to compare sinks', () {
    final sink = _sink()..beginResidual(Transform2.identity());
    for (var i = 0; i < 7; i++) {
      sink.polyline(_seg(0, i * 1.0, 10, i * 1.0), 2, _style(), closed: false);
    }
    sink.endResidual();
    expect(sink.batchedSegmentCount, 7);
  });

  test('a 45-degree segment gets a normal of the right length', () {
    // Degenerate-fixture guard: every case above is axis-aligned, so a normal
    // that forgot to normalise would still pass them.
    final sink = _sink()
      ..beginResidual(Transform2.identity())
      ..polyline(_seg(0, 0, 10, 10), 2, _style(), closed: false)
      ..endResidual();
    final v = sink.debugPositions();
    final dx = v[0] - v[2], dy = v[1] - v[3];
    // 1e-6, not the 1e-12 the axis-aligned cases use: the buffer is
    // `Float32List`, and a 45-degree normal is the first value here that is
    // not exactly representable in it.
    expect(math.sqrt(dx * dx + dy * dy), closeTo(1.0, 1e-6));
  });
}
