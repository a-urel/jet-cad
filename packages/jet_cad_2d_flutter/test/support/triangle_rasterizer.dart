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
  TriangleRasterizer(this.width, this.height,
      {this.debugDisableDashTest = false})
      : pixels = Uint32List(width * height);

  final int width;
  final int height;

  /// **Test-only, and it stays that way.** Setting this skips the
  /// `fract(t)` keep/discard test in [_fill] entirely, so every fragment of
  /// a dashed triangle inks as if it were solid -- the control arm Task 10's
  /// pixel differential needs to prove its own gate can actually fail (Plan
  /// 3i's Ruling 14: an interleaved control that cannot be switched on reads
  /// 1.00 and proves nothing). This field has no counterpart in
  /// `cad_stroke.frag` or `lib/` -- the real fragment shader has no such
  /// escape hatch, and this one must never grow one either.
  final bool debugDisableDashTest;

  /// Row-major, zero where nothing was drawn.
  ///
  /// Each element is a packed little-endian `0xAABBGGRR` `Uint32`: byte 0
  /// (R) is the least-significant byte, byte 3 (A) the most-significant.
  /// [toImage] reinterprets this buffer's raw bytes as `rgba8888` via
  /// `asUint8List()`, which reproduces that channel order only on a
  /// little-endian host -- true of every platform this repository builds or
  /// tests on, so it is not a portability gap this class actually carries,
  /// only an assumption worth stating next to a "deterministic across
  /// machines" claim.
  final Uint32List pixels;

  /// Whether `(x, y)` was painted by any triangle.
  ///
  /// Bounds-checked rather than left to fall through to [pixels]' own index
  /// check: `y * width + x` is a single flat index, so an out-of-range `x`
  /// with an in-range `y` would otherwise silently read a neighbouring row
  /// instead of failing. Tasks 10 and 11 assert on coordinates near the
  /// surface's edge, where that silent wraparound would read as a passing,
  /// wrong assertion rather than a crash.
  bool inked(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) {
      throw RangeError('($x, $y) is outside the ${width}x$height surface');
    }
    return pixels[y * width + x] != 0;
  }

  /// A [FlushObserver]. Triangles are drawn in buffer order with no depth
  /// test, exactly as `drawVertices` rasterises them, so a later one covers an
  /// earlier one -- which is the property the sink's whole design rests on.
  ///
  /// **Task 9's fragment stage.** [dash] is `v_dash` -- `(t, fracStart,
  /// fracEnd)` per vertex, in the same order as [positions] -- the same shape
  /// `instance_expander.dart`'s `ExpandedTriangles.dashVaryings` produces.
  /// `null` (the default) is the pre-Task-9 contract: every existing test in
  /// this file pins that a triangle observed with no [dash] is filled exactly
  /// as it always was, with no fragment discarded.
  void observe(Float32List positions, Int32List colors, {Float32List? dash}) {
    for (var t = 0; t + 2 < colors.length; t += 3) {
      double? ta, tb, tc, startA, endA;
      if (dash != null) {
        ta = dash[t * 3];
        startA = dash[t * 3 + 1];
        endA = dash[t * 3 + 2];
        tb = dash[(t + 1) * 3];
        tc = dash[(t + 2) * 3];
        // Every vertex of one instance carries the same element extent by
        // construction (`instance_expander.dart` writes `fracStart`/
        // `fracEnd` once per instance, not once per vertex) -- asserted
        // rather than assumed, because a triangle whose vertices disagree
        // came from two different instances stitched together, which is a
        // bug this rasterizer should not paper over by averaging.
        final startB = dash[(t + 1) * 3 + 1];
        final endB = dash[(t + 1) * 3 + 2];
        final startC = dash[(t + 2) * 3 + 1];
        final endC = dash[(t + 2) * 3 + 2];
        assert(
            startA == startB &&
                startA == startC &&
                endA == endB &&
                endA == endC,
            'every vertex of one instance carries the same element extent; '
            'a triangle whose vertices disagree came from two instances');
      }
      _fill(
        positions[t * 2],
        positions[t * 2 + 1],
        positions[t * 2 + 2],
        positions[t * 2 + 3],
        positions[t * 2 + 4],
        positions[t * 2 + 5],
        // Only the first vertex's colour is read: `VerticesDrawSink` always
        // writes three identical colours per triangle (colour rides on the
        // vertex, not on a shared shader), so a flat fill matches its output
        // exactly. This is a coverage rasterizer, not a rendering one, and
        // it does not interpolate -- a future producer that submitted a
        // genuine per-vertex gradient would be flattened to vertex 0's
        // colour here rather than blended, which would be wrong for that
        // producer and is unreachable for this one today.
        colors[t].toUnsigned(32),
        ta: ta,
        tb: tb,
        tc: tc,
        startA: startA,
        endA: endA,
      );
    }
  }

  void _fill(double ax, double ay, double bx, double by, double cx, double cy,
      int argb,
      {double? ta, double? tb, double? tc, double? startA, double? endA}) {
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

    // A negative `fracStart` is the solid sentinel `instance_expander.dart`
    // writes for an undashed instance -- the whole test is skipped for it,
    // not just widened, so a solid triangle sharing a buffer with dashed
    // ones is unaffected by them.
    final hasDash = !debugDisableDashTest && ta != null && startA! >= 0;

    for (var y = minY; y <= maxY; y++) {
      final py = y + 0.5;
      for (var x = minX; x <= maxX; x++) {
        final px = x + 0.5;
        final w0 = ((bx - ax) * (py - ay) - (by - ay) * (px - ax)) * sign;
        final w1 = ((cx - bx) * (py - by) - (cy - by) * (px - bx)) * sign;
        final w2 = ((ax - cx) * (py - cy) - (ay - cy) * (px - cx)) * sign;
        if (w0 < 0 || w1 < 0 || w2 < 0) continue;
        if (hasDash) {
          // Barycentric weights from the edge functions already computed.
          // `w0` is the edge (a, b) against p, which is proportional to the
          // weight of the OPPOSITE vertex, c -- getting that correspondence
          // wrong reads a plausible number at every pixel and the wrong one
          // at all but the (exact, continuous) centroid, where every
          // vertex's weight is equal regardless of which weight is paired
          // with which vertex.
          final sum = w0 + w1 + w2;
          // Defensive, not reachable in practice: `sum` is the triangle's
          // own (signed-corrected) area, already rejected above via `area
          // == 0`, so it is a positive constant here for every pixel this
          // loop visits.
          if (sum <= 0) continue;
          final t = (w1 * ta + w2 * tb! + w0 * tc!) / sum;
          final f = t - t.floorToDouble(); // `fract`
          if (f < startA || f >= endA!) continue;
        }
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
