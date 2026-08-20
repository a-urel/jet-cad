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
  /// earlier one -- which is the property the sink's whole design rests on.
  void observe(Float32List positions, Int32List colors) {
    for (var t = 0; t + 2 < colors.length; t += 3) {
      _fill(
        positions[t * 2],
        positions[t * 2 + 1],
        positions[t * 2 + 2],
        positions[t * 2 + 3],
        positions[t * 2 + 4],
        positions[t * 2 + 5],
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
