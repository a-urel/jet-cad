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

VerticesDrawSink _sink({Canvas? canvas, double devicePixelRatio = 1.0}) =>
    VerticesDrawSink(
        pixelsPerPaperMm: _pxPerMm,
        canvas: canvas,
        devicePixelRatio: devicePixelRatio);

/// Half the height of the quad the sink emitted for a horizontal segment.
double _halfOf(Float32List v) => (v[1] - v[3]) / 2;

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

  test('a polyline of n points emits n-1 segments plus a join at each corner',
      () {
    // 2 segments are 4 triangles; the one corner between them turns a right
    // angle, well inside the miter limit, so `_emitJoin` adds a bevel and a
    // tip triangle -- 6 triangles, 36 floats, in total.
    final open = _sink()
      ..beginResidual(Transform2.identity())
      ..polyline(Float64List.fromList([0, 0, 10, 0, 10, 10]), 3, _style(),
          closed: false)
      ..endResidual();
    expect(open.debugPositions().length, 6 * 6);
  });

  test('a closed polyline draws its closing segment and seam join', () {
    // `polyline` forwards its own `closed:` to `_endRun`, which now closes
    // the run instead of asserting against reaching this branch. No caller
    // reaches it today: `closed:` is `false` at every one of the painter's
    // four call sites.
    final closed = _sink()
      ..beginResidual(Transform2.identity())
      ..polyline(Float64List.fromList([0, 0, 10, 0, 10, 10]), 3, _style(),
          closed: true)
      ..endResidual();
    // Three segments and three corners: 3 * 2 quad triangles plus 3 * 2 join
    // triangles, every corner shallow enough to mitre.
    expect(closed.debugPositions().length, (3 * 2 + 3 * 2) * 3 * 2);
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
    final sink = _sink(canvas: canvas)..beginResidual(Transform2.identity());
    for (var i = 0; i < 5; i++) {
      sink.polyline(_seg(0, i * 1.0, 10, i * 1.0), 2,
          _style(argb: 0xFF000000 | (i * 0x203040)),
          closed: false);
    }
    sink.endResidual();
    sink.flush();
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

  _arcTests();
  _widthTests();

  test('the submitted Vertices is disposed, and the flag reads its state', () {
    // `Vertices` is native-backed: `dispose()` frees the position and colour
    // buffers the engine holds, and dropping the object instead leaves them to
    // a finalizer. At 19 flushes a frame that is about 1,140 a second.
    //
    // MUTATION: drop the dispose call and `lastFlushDisposed` reads false,
    // because it is derived from `Vertices.debugDisposed` -- the object's own
    // state -- rather than asserted unconditionally beside the call.
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final sink = _sink(canvas: canvas)..beginResidual(Transform2.identity());
    for (var i = 0; i < 5; i++) {
      sink.polyline(_seg(0, i * 1.0, 10, i * 1.0), 2, _style(), closed: false);
    }
    sink.endResidual();
    sink.flush();

    expect(sink.lastFlushDisposed, isTrue);
    recorder.endRecording().dispose();
  });

  test('the disposed Vertices rasterises the same pixels a retained one would',
      () async {
    // `PictureRecorder.endRecording()` only finalises a display-list op
    // list -- it does not dereference vertex data, so a picture that merely
    // records without throwing says nothing about whether disposal freed
    // buffers a rasteriser would later read. Rasterising is the only way to
    // ask the real question, so this compares actual pixels: one image drawn
    // through the sink's real `flush()` (which disposes), one through a
    // control that submits the identical geometry the same way but is never
    // disposed -- exactly what `flush()` did before this task.
    //
    // Kept to one segment / two triangles / a 16x16 image: `flutter_test`'s
    // software rasteriser did not finish a 1,007-segment `drawVertices` in
    // seven and a half minutes, so a bigger buffer would hang the suite.
    Future<Uint8List> rasterise(Picture picture) async {
      final image = await picture.toImage(16, 16);
      final bytes = (await image.toByteData())!.buffer.asUint8List();
      image.dispose();
      picture.dispose();
      return bytes;
    }

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final sink = _sink(canvas: canvas)..beginResidual(Transform2.identity());
    sink.polyline(_seg(0, 1, 10, 1), 2, _style(argb: 0xFFFF0000),
        closed: false);
    sink.endResidual();
    sink.flush();
    expect(sink.lastFlushDisposed, isTrue);
    final disposedPixels = await rasterise(recorder.endRecording());

    // The exact two triangles `polyline` emits for this segment and style --
    // see 'a segment becomes two triangles a half-width either side of it'
    // for the derivation -- submitted the same way `flush` does, but never
    // disposed.
    final controlRecorder = PictureRecorder();
    final controlCanvas = Canvas(controlRecorder);
    final positions = Float32List.fromList(<double>[
      0, 1.5, 0, 0.5, 10, 1.5, //
      0, 0.5, 10, 0.5, 10, 1.5,
    ]);
    final colors = Int32List.fromList(List<int>.filled(6, 0xFFFF0000));
    controlCanvas.drawVertices(
      Vertices.raw(VertexMode.triangles, positions, colors: colors),
      BlendMode.dst,
      Paint()..color = const Color(0xFFFFFFFF),
    );
    final retainedPixels = await rasterise(controlRecorder.endRecording());

    // MUTATION: dispose before `drawVertices` instead of after, and the
    // `flush` call above throws -- confirmed empirically: swapping the two
    // lines fails an `assert(!vertices.debugDisposed)` inside
    // `dart:ui`'s `Canvas.drawVertices`, before this expectation is ever
    // reached.
    expect(disposedPixels, orderedEquals(retainedPixels));
  });

  test('a flush with nothing batched disposes nothing', () {
    // MUTATION: dispose unconditionally and this throws on a null.
    final recorder = PictureRecorder();
    final sink = _sink(canvas: Canvas(recorder));
    sink.flush();
    expect(sink.flushCallCount, 0);
    expect(sink.lastFlushDisposed, isFalse);
    recorder.endRecording().dispose();
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

  test('the observer sees exactly what was submitted, before the rewind', () {
    // The rasterizer's seam. Reading the buffer after a flush finds it
    // rewound; reading it before finds work the flush has not yet done.
    //
    // MUTATION: hand the observer the whole buffer rather than the submitted
    // view and the length reads the capacity, 4096, instead of 12.
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    late Float32List seenPositions;
    late Int32List seenColors;
    late bool disposedAtCallTime;
    var calls = 0;

    // Built without the cascade the brief's snippet uses, so the closure can
    // read `sink.lastFlushDisposed` at call time -- a self-reference a
    // chained `..observer = ...` cannot make before `sink` exists.
    final sink = _sink(canvas: canvas);
    sink.observer = (positions, colors) {
      calls++;
      seenPositions = Float32List.fromList(positions);
      seenColors = Int32List.fromList(colors);
      // `flush()` sets `_lastFlushDisposed` from `Vertices.debugDisposed`
      // only in the `assert` block that runs after `vertices.dispose()`, so
      // this reads false only if the observer runs before that block.
      //
      // MUTATION: move the observer call to after that `assert` block
      // (still ahead of the rewind) and this reads true instead of false --
      // confirmed empirically: moving it there flips this expectation from
      // green to red. Moving it to the narrower window between
      // `vertices.dispose()` itself and the `assert` block that follows it
      // does *not* flip it -- also confirmed empirically -- because
      // `Vertices.raw` copies `positions`/`colors` into native memory
      // synchronously at construction, so disposing the `Vertices` object
      // never touches the Dart-side views this test already holds. That
      // three-line window has no observable side effect through any public
      // API; every mutation that matters (rewound, or the assert's own
      // disposal record) is still caught above and below.
      disposedAtCallTime = sink.lastFlushDisposed;
    };
    sink.beginResidual(Transform2.identity());
    sink.polyline(_seg(0, 0, 10, 0), 2, _style(argb: 0xFF112233),
        closed: false);
    sink.endResidual();
    sink.flush();

    expect(calls, 1);
    expect(seenPositions.length, 12);
    expect(seenColors.length, 6);
    expect(seenColors[0].toUnsigned(32), 0xFF112233);
    expect(disposedAtCallTime, isFalse);
    // And the buffer really was rewound afterwards.
    expect(sink.debugPositions(), isEmpty);
    recorder.endRecording().dispose();
  });

  test('a flush with nothing batched does not call the observer', () {
    // MUTATION: call it unconditionally and a frame that drew nothing
    // rasterises an empty buffer over the previous one.
    var calls = 0;
    final recorder = PictureRecorder();
    _sink(canvas: Canvas(recorder))
      ..observer = ((_, __) => calls++)
      ..flush();
    expect(calls, 0);
    recorder.endRecording().dispose();
  });

  test('the observer fires once per flush, text included', () {
    // MUTATION: observe only the final flush and a fixture with text loses
    // every triangle drawn before the first text op.
    var calls = 0;
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final sink = _sink(canvas: canvas)
      ..observer = ((_, __) => calls++)
      ..beginResidual(Transform2.identity());
    sink.polyline(_seg(0, 0, 10, 0), 2, _style(), closed: false);
    sink.text('x', ReservedHandles.standardTextStyle, _style());
    sink.polyline(_seg(0, 5, 10, 5), 2, _style(), closed: false);
    sink.endResidual();
    sink.flush();
    expect(calls, 2);
    recorder.endRecording().dispose();
  });
}

/// Every corner an arc or circle flattens into turns by a small angle -- well
/// inside the miter limit -- so `_emitJoin` writes exactly two triangles
/// between every pair of quads: the stride from one chord's quad to the
/// next's is 4 triangles (24 floats), not 2, because a join sits in between.
/// Checked once per fixture below rather than assumed, so a fixture that ever
/// crossed the miter limit or went collinear would fail loudly here instead
/// of reading the wrong floats silently.
///
/// An open run's `segments` chords have `segments - 1` interior corners; a
/// closed one -- a circle -- has one more, the seam, so its stride carries no
/// `-2`.
void _expectUniformMiterStride(VerticesDrawSink sink, {bool closed = false}) {
  final segments = sink.batchedSegmentCount;
  final triangles = sink.debugPositions().length ~/ 6;
  expect(triangles, closed ? 4 * segments : 4 * segments - 2,
      reason: 'every corner between the $segments chords is expected to '
          'stay well inside the miter limit, so _startCentre/_endCentre\'s '
          'fixed stride of 4 triangles per chord applies');
}

/// Centre of the segment that starts at vertex [seg] * 24.
(double, double) _startCentre(Float32List v, int seg) {
  final i = seg * 24;
  return ((v[i] + v[i + 2]) / 2, (v[i + 1] + v[i + 3]) / 2);
}

(double, double) _endCentre(Float32List v, int seg) {
  final i = seg * 24;
  return ((v[i + 4] + v[i + 8]) / 2, (v[i + 5] + v[i + 9]) / 2);
}

void _arcTests() {
  test('an arc is flattened, and its ends sit on the arc', () {
    final sink = _sink()
      ..beginResidual(Transform2.identity())
      ..arc(0, 0, 10, 0, math.pi / 2, _style())
      ..endResidual();

    final v = sink.debugPositions();
    final segments = sink.batchedSegmentCount;
    expect(segments, greaterThan(1), reason: 'a quarter arc is not one chord');
    _expectUniformMiterStride(sink);

    final (sx, sy) = _startCentre(v, 0);
    expect(sx, closeTo(10, 1e-4), reason: 'start x');
    expect(sy, closeTo(0, 1e-4), reason: 'start y');

    final (ex, ey) = _endCentre(v, segments - 1);
    expect(ex, closeTo(0, 1e-4), reason: 'end x');
    expect(ey, closeTo(10, 1e-4), reason: 'end y');
  });

  test('the flattened arc stays within a quarter pixel of the true one', () {
    // Measured at the *middle* of each chord, not at its ends. The ends are on
    // the arc by construction, so a test that sampled them would read zero
    // error for any segment count at all -- it would pass a sink that drew a
    // single chord across a half circle.
    //
    // MUTATION: replace the segment count with a constant 8, and r = 500 reads
    // about 12 pixels of sag against a budget of 0.25.
    for (final r in <double>[5, 50, 500]) {
      final sink = _sink()
        ..beginResidual(Transform2.identity())
        ..arc(0, 0, r, 0.3, math.pi, _style())
        ..endResidual();
      final v = sink.debugPositions();
      final segments = sink.batchedSegmentCount;
      _expectUniformMiterStride(sink);
      var worst = 0.0;
      for (var s = 0; s < segments; s++) {
        final (sx, sy) = _startCentre(v, s);
        final (ex, ey) = _endCentre(v, s);
        final mx = (sx + ex) / 2, my = (sy + ey) / 2;
        worst = math.max(worst, (r - math.sqrt(mx * mx + my * my)).abs());
      }
      expect(worst, lessThan(VerticesDrawSink.kFlattenTolerance),
          reason: 'r=$r used $segments segments');
    }
  });

  test('the segment count follows the arc as the residual scales it', () {
    // MUTATION: take the radius in local space and the two counts match.
    int countAt(double scale) {
      final sink = _sink()
        ..beginResidual(Transform2(scale, 0, 0, scale, 0, 0))
        ..arc(0, 0, 10, 0, math.pi, _style())
        ..endResidual();
      return sink.batchedSegmentCount;
    }

    expect(countAt(100), greaterThan(countAt(1) * 4),
        reason: 'a 100x residual is a 100x arc on screen');
  });

  test('a non-uniform residual turns a circle into an ellipse', () {
    // Degenerate-fixture guard: flattening in device space from one radius
    // would draw a circle here, which is what `Canvas` would not do either.
    const t = Transform2(3, 0, 0, 1, 0, 0);
    final sink = _sink()
      ..beginResidual(t)
      ..circle(0, 0, 10, _style())
      ..endResidual();
    final v = sink.debugPositions();
    _expectUniformMiterStride(sink, closed: true);
    var maxX = 0.0, maxY = 0.0;
    for (var s = 0; s < sink.batchedSegmentCount; s++) {
      final (x, y) = _startCentre(v, s);
      maxX = math.max(maxX, x.abs());
      maxY = math.max(maxY, y.abs());
    }
    expect(maxX, closeTo(30, 0.3));
    expect(maxY, closeTo(10, 0.3));
  });

  test('a point is a square of the stroke width, at the residual', () {
    // Under a residual, not at the identity: a point placed at the origin of
    // an identity transform would pass with the transform dropped entirely.
    //
    // MUTATION: emit nothing for a point and this finds an empty buffer.
    const t = Transform2(1, 0, 0, 1, 100, 200);
    final sink = _sink()
      ..beginResidual(t)
      ..point(3, 4, _style())
      ..endResidual();

    final v = sink.debugPositions();
    expect(sink.batchedSegmentCount, 1);
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (var i = 0; i < v.length; i += 2) {
      minX = math.min(minX, v[i]);
      maxX = math.max(maxX, v[i]);
      minY = math.min(minY, v[i + 1]);
      maxY = math.max(maxY, v[i + 1]);
    }
    // 0.25 mm at 4 px/mm is a 1-pixel stroke, so the square is 1 x 1 around
    // the transformed point.
    expect(minX, closeTo(102.5, 1e-12));
    expect(maxX, closeTo(103.5, 1e-12));
    expect(minY, closeTo(203.5, 1e-12));
    expect(maxY, closeTo(204.5, 1e-12));
  });

  test('a circle closes on itself', () {
    final sink = _sink()
      ..beginResidual(Transform2.identity())
      ..circle(0, 0, 10, _style())
      ..endResidual();
    final v = sink.debugPositions();
    _expectUniformMiterStride(sink, closed: true);
    final (sx, sy) = _startCentre(v, 0);
    final (ex, ey) = _endCentre(v, sink.batchedSegmentCount - 1);
    expect(ex, closeTo(sx, 1e-4));
    expect(ey, closeTo(sy, 1e-4));
  });

  test('an unbatchable op flushes first, so draw order holds across it', () {
    // Text cannot become triangles, so it goes to the fallback -- and it must
    // not jump ahead of every stroke batched before it.
    //
    // MUTATION: let `text` reach the fallback without flushing, and this
    // reads one flush instead of two.
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final sink = _sink(canvas: canvas)..beginResidual(Transform2.identity());
    sink.polyline(_seg(0, 0, 10, 0), 2, _style(), closed: false);
    sink.text('x', ReservedHandles.standardTextStyle, _style());
    sink.polyline(_seg(0, 5, 10, 5), 2, _style(), closed: false);
    sink.endResidual();
    sink.flush();

    expect(sink.totalFlushCount, 2,
        reason: 'one flush before the text, one at the end of the frame');
    // Per-flush counters cannot see past the mid-frame flush; the frame
    // counter is what a rig prints. Each `polyline` call here is its own
    // run -- no join between them, since they are two separate calls -- so
    // this is 2 quads' own triangles, 4, not the 2 quads themselves.
    //
    // MUTATION: report `lastFlushSegmentCount` as the frame total and this
    // reads 1, the tail after the text, instead of 4.
    expect(sink.lastFlushSegmentCount, 1);
    expect(sink.frameTriangleCount, 4);
    recorder.endRecording().dispose();
  });
}

void _widthTests() {
  // `CanvasDrawSink` hands `Canvas` a width and lets Impeller apply two rules
  // to it, both in *device* space and neither reachable from Dart. Baking the
  // transform into the positions means this sink has to apply them itself, or
  // it draws a visibly different line from its sibling.
  //
  //   line_geometry.cc:24  max(width, kMinStrokeSize / max_basis) with
  //                        kMinStrokeSize = 1.0f -- one device pixel is the
  //                        thinnest line there is
  //   geometry.cc:148      a stroke thinner than that keeps its one pixel but
  //                        loses alpha in proportion, clamp(w * 2, 0, 1)
  test('a stroke above the floor keeps its exact width, not a rounded one', () {
    // 0.25 mm at 4 px/mm is 1.0 logical pixels, which at devicePixelRatio 2 is
    // 2 device pixels -- above the floor, so nothing clamps it.
    //
    // MUTATION: floor the width at one logical pixel and a thinner case than
    // this one rounds up; see the ratio test below for the case that catches it.
    final sink = _sink(devicePixelRatio: 2.0)
      ..beginResidual(Transform2.identity())
      ..polyline(_seg(0, 0, 10, 0), 2, _style(lineweight: 30), closed: false)
      ..endResidual();
    expect(_halfOf(sink.debugPositions()),
        closeTo(0.5 * 30 / 100 * _pxPerMm, 1e-6));
    expect(sink.debugColors()[0].toUnsigned(32), 0xFF000000);
  });

  test('a sub-pixel stroke gets one device pixel and loses alpha for it', () {
    // 0.05 mm at 4 px/mm is 0.2 logical, 0.4 device pixels at ratio 2: under
    // the floor. Impeller draws it one device pixel wide at 0.4 * 2 = 0.8 alpha.
    //
    // MUTATION: clamp the width without touching the alpha, and this stays at
    // 0xFF.
    final sink = _sink(devicePixelRatio: 2.0)
      ..beginResidual(Transform2.identity())
      ..polyline(_seg(0, 0, 10, 0), 2, _style(lineweight: 5), closed: false)
      ..endResidual();
    // One device pixel is half a logical one at ratio 2, so the half-width is
    // a quarter.
    expect(_halfOf(sink.debugPositions()), closeTo(0.25, 1e-6));
    expect(sink.debugColors()[0].toUnsigned(32), 0xCC000000);
  });

  test('the floor is device pixels, so it moves with the ratio', () {
    // Degenerate-fixture guard: a sink that floored in logical pixels would
    // draw the same line at every ratio.
    //
    // MUTATION: drop `devicePixelRatio` from the floor and the two read the
    // same.
    double halfAt(double ratio) {
      final sink = _sink(devicePixelRatio: ratio)
        ..beginResidual(Transform2.identity())
        ..polyline(_seg(0, 0, 10, 0), 2, _style(lineweight: 5), closed: false)
        ..endResidual();
      return _halfOf(sink.debugPositions());
    }

    expect(halfAt(1.0), closeTo(0.5, 1e-6));
    expect(halfAt(4.0), closeTo(0.125, 1e-6));
  });

  test('a lineweight of zero is a hairline at full alpha', () {
    // `Canvas` reads a `strokeWidth` of 0 as "one device pixel whatever the
    // transform", and Impeller returns full coverage for it rather than fading
    // it to nothing -- `scaled_stroke_width == 0.0` is the first branch of
    // ComputeStrokeAlphaCoverage.
    //
    // MUTATION: let zero fall through to the proportional fade and the alpha
    // goes to 0x00.
    final sink = _sink(devicePixelRatio: 2.0)
      ..beginResidual(Transform2.identity())
      ..polyline(_seg(0, 0, 10, 0), 2, _style(lineweight: 0), closed: false)
      ..endResidual();
    expect(_halfOf(sink.debugPositions()), closeTo(0.25, 1e-6));
    expect(sink.debugColors()[0].toUnsigned(32), 0xFF000000);
  });

  test('every emitter fades, not just the straight one', () {
    // Degenerate-coverage guard: the fade lives in one helper, but three call
    // sites reach it and a curve or a point that took `style.argb` directly
    // would draw at full alpha beside a faded line.
    //
    // MUTATION: pass `style.argb` in `_flatten` or in `point`, and the arc or
    // the point row here stays at 0xFF.
    final thin = _style(lineweight: 5);
    final emitters = <String, void Function(VerticesDrawSink)>{
      'polyline': (s) => s.polyline(_seg(0, 0, 10, 0), 2, thin, closed: false),
      'arc': (s) => s.arc(0, 0, 10, 0, math.pi / 2, thin),
      'circle': (s) => s.circle(0, 0, 10, thin),
      'point': (s) => s.point(3, 4, thin),
    };
    emitters.forEach((name, emit) {
      final sink = _sink(devicePixelRatio: 2.0)
        ..beginResidual(Transform2.identity());
      emit(sink);
      sink.endResidual();
      expect(sink.debugColors(), isNotEmpty, reason: name);
      expect(sink.debugColors()[0].toUnsigned(32), 0xCC000000, reason: name);
    });
  });

  test('the fade multiplies the style alpha rather than replacing it', () {
    // A half-transparent entity at a sub-pixel width is both: 0x80 * 0.8.
    //
    // MUTATION: write the coverage as the alpha instead of scaling by it, and
    // this reads 0xCC.
    final sink = _sink(devicePixelRatio: 2.0)
      ..beginResidual(Transform2.identity())
      ..polyline(_seg(0, 0, 10, 0), 2, _style(argb: 0x80123456, lineweight: 5),
          closed: false)
      ..endResidual();
    expect(sink.debugColors()[0].toUnsigned(32), 0x66123456);
  });
}
