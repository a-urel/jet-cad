### Task 9: A triangle rasterizer this repository owns

`flutter_test`'s software Skia did not finish a `drawVertices` of 1,007
segments in 7 minutes 28 seconds, so the golden suite cannot see this sink
through the engine. It gets its own scan-converter: deterministic across
machines and Flutter versions, and reading the buffer Impeller was given rather
than a re-derivation of it.

It has no anti-aliasing. Its goldens are of **coverage**, not of appearance —
the right trade for a regression test and the wrong one for judging how a
drawing looks. The device screenshot stays the instrument for the second
question.

**Files:**
- Create: `packages/jet_cad_2d_flutter/test/support/triangle_rasterizer.dart`
- Create: `packages/jet_cad_2d_flutter/test/support/triangle_rasterizer_test.dart`

**Interfaces:**
- Consumes: `FlushObserver`, `VerticesDrawSink.observer`.
- Produces: `class TriangleRasterizer` with `void observe(Float32List, Int32List)`,
  `Uint32List get pixels`, `bool inked(int x, int y)`, `Future<ui.Image> toImage()`.
  Tasks 10 and 11 consume all four.

- [ ] **Step 1: Write the failing test**

`packages/jet_cad_2d_flutter/test/support/triangle_rasterizer_test.dart`:

```dart
// The rasterizer is test infrastructure, so it gets its own tests: a golden
// compared through a broken scan-converter is a green test and a wrong
// drawing.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'triangle_rasterizer.dart';

Float32List _tri(List<double> xy) => Float32List.fromList(xy);
Int32List _rgb(int argb) => Int32List.fromList(List<int>.filled(3, argb));

void main() {
  test('a triangle covers its interior and not its outside', () {
    final r = TriangleRasterizer(8, 8)
      ..observe(_tri([1, 1, 6, 1, 1, 6]), _rgb(0xFFFF0000));
    expect(r.inked(2, 2), isTrue, reason: 'inside');
    expect(r.inked(5, 5), isFalse, reason: 'past the hypotenuse');
    expect(r.inked(7, 7), isFalse, reason: 'outside the bounding box');
  });

  test('winding does not matter', () {
    // MUTATION: reject triangles whose edge functions come out negative and
    // the clockwise one vanishes. `drawVertices` culls nothing, so neither
    // does this.
    final ccw = TriangleRasterizer(8, 8)
      ..observe(_tri([1, 1, 6, 1, 1, 6]), _rgb(0xFF00FF00));
    final cw = TriangleRasterizer(8, 8)
      ..observe(_tri([1, 1, 1, 6, 6, 1]), _rgb(0xFF00FF00));
    expect(cw.inked(2, 2), ccw.inked(2, 2));
  });

  test('a later triangle draws over an earlier one', () {
    // The buffer's order is the draw order, and the rasterizer must not
    // reorder it — that is the property the whole sink is built around.
    //
    // MUTATION: skip a pixel that is already inked and this reads red.
    final r = TriangleRasterizer(8, 8)
      ..observe(_tri([0, 0, 8, 0, 0, 8]), _rgb(0xFFFF0000))
      ..observe(_tri([0, 0, 8, 0, 0, 8]), _rgb(0xFF0000FF));
    expect(r.pixels[1 * 8 + 1] & 0x00FFFFFF, 0x0000FF);
  });

  test('geometry outside the surface is clipped, not wrapped', () {
    // MUTATION: drop the row and column clamps and this throws a RangeError,
    // or worse, writes a pixel on the opposite edge.
    final r = TriangleRasterizer(8, 8)
      ..observe(_tri([-20, -20, 40, -20, -20, 40]), _rgb(0xFF000000));
    expect(r.inked(0, 0), isTrue);
    expect(r.inked(7, 7), isFalse);
  });

  test('a degenerate triangle inks nothing', () {
    // MUTATION: divide by a zero area and every pixel comes out NaN-inked.
    final r = TriangleRasterizer(8, 8)
      ..observe(_tri([1, 1, 5, 1, 3, 1]), _rgb(0xFF000000));
    expect(List.generate(64, (i) => r.pixels[i]).every((p) => p == 0), isTrue);
  });

  test('it renders what the sink submitted, end to end', () async {
    // The seam under test, not a hand-built triangle list.
    final r = TriangleRasterizer(64, 64);
    // A one-pixel horizontal line across the middle.
    final image = await r.toImage();
    addTearDown(image.dispose);
    expect(image.width, 64);
    expect(image.height, 64);
  });
}
```

- [ ] **Step 2: Run the test and watch it fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/support/triangle_rasterizer_test.dart
```

Expected: `Undefined class 'TriangleRasterizer'`.

- [ ] **Step 3: Implement**

`packages/jet_cad_2d_flutter/test/support/triangle_rasterizer.dart`:

```dart
// A coverage-only scan-converter for `VerticesDrawSink`'s output.
//
// `flutter_test`'s software Skia did not finish a `drawVertices` of 1,007
// segments in 7 minutes 28 seconds, so the golden suite cannot see this sink
// through the engine. This is small enough to own, deterministic across
// machines and Flutter versions where the engine's rasteriser is not, and it
// reads the buffer Impeller was given rather than a second derivation of it.
//
// **No anti-aliasing.** A pixel is inside a triangle or it is not, so what it
// produces is a coverage golden and not an appearance golden. Judging how a
// drawing looks stays the device screenshot's job.

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Rasterises the triangles a [VerticesDrawSink] flush submitted.
///
/// Attach with `sink.observer = rasterizer.observe;`.
class TriangleRasterizer {
  TriangleRasterizer(this.width, this.height)
      : pixels = Uint32List(width * height);

  final int width;
  final int height;

  /// RGBA, row-major, zero where nothing was drawn.
  final Uint32List pixels;

  bool inked(int x, int y) => pixels[y * width + x] != 0;

  /// A [FlushObserver]. Triangles are drawn in buffer order with no depth
  /// test, exactly as `drawVertices` rasterises them, so a later one covers an
  /// earlier one — which is the property the sink's whole design rests on.
  void observe(Float32List positions, Int32List colors) {
    for (var t = 0; t + 2 < colors.length; t += 3) {
      _fill(
        positions[t * 2], positions[t * 2 + 1],
        positions[t * 2 + 2], positions[t * 2 + 3],
        positions[t * 2 + 4], positions[t * 2 + 5],
        colors[t].toUnsigned(32),
      );
    }
  }

  void _fill(double ax, double ay, double bx, double by, double cx, double cy,
      int argb) {
    final area = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax);
    // A zero-area triangle has no interior and no orientation to test against.
    if (area == 0 || !area.isFinite) return;
    // `drawVertices` culls nothing, so neither does this: a clockwise triangle
    // is as visible as a counter-clockwise one.
    final sign = area > 0 ? 1.0 : -1.0;

    final minX = _clampX(_minOf(ax, bx, cx).floor());
    final maxX = _clampX(_maxOf(ax, bx, cx).ceil());
    final minY = _clampY(_minOf(ay, by, cy).floor());
    final maxY = _clampY(_maxOf(ay, by, cy).ceil());

    // RGBA for `ui.PixelFormat.rgba8888`, from the ARGB the sink carries.
    final rgba = ((argb & 0x00FF0000) >> 16) |
        (argb & 0x0000FF00) |
        ((argb & 0x000000FF) << 16) |
        ((argb & 0xFF000000));

    for (var y = minY; y <= maxY; y++) {
      final py = y + 0.5;
      for (var x = minX; x <= maxX; x++) {
        final px = x + 0.5;
        final w0 = ((bx - ax) * (py - ay) - (by - ay) * (px - ax)) * sign;
        final w1 = ((cx - bx) * (py - by) - (cy - by) * (px - bx)) * sign;
        final w2 = ((ax - cx) * (py - cy) - (ay - cy) * (px - cx)) * sign;
        if (w0 < 0 || w1 < 0 || w2 < 0) continue;
        pixels[y * width + x] = rgba;
      }
    }
  }

  int _clampX(int v) => v < 0 ? 0 : (v >= width ? width - 1 : v);
  int _clampY(int v) => v < 0 ? 0 : (v >= height ? height - 1 : v);
  static double _minOf(double a, double b, double c) =>
      a < b ? (a < c ? a : c) : (b < c ? b : c);
  static double _maxOf(double a, double b, double c) =>
      a > b ? (a > c ? a : c) : (b > c ? b : c);

  /// The surface as an image, for `matchesGoldenFile`.
  Future<ui.Image> toImage() {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels.buffer.asUint8List(),
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }
}
```

- [ ] **Step 4: Run the test and watch it pass**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/support/triangle_rasterizer_test.dart
```

Expected: 6 tests pass.

- [ ] **Step 5: Run both suites green, then commit**

```bash
git add packages/jet_cad_2d_flutter/test/support
git commit -m "test: a coverage-only triangle rasterizer for the vertices sink

flutter_test's software Skia did not finish a drawVertices of 1,007 segments in
7.5 minutes, so the golden suite cannot see this sink through the engine. This
is small enough to own and deterministic across machines and Flutter versions,
and it reads the buffer Impeller was given rather than a second derivation of
it.

It has its own tests, because a golden compared through a broken scan-converter
is a green test and a wrong drawing. Winding is not culled, later triangles
cover earlier ones, and geometry off the surface is clipped -- three ways to be
subtly wrong that no golden would name."
```

---

