import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'canvas_draw_sink.dart';
import 'draw_sink.dart';

/// Builds each stroked segment's two triangles itself and submits the whole
/// frame's strokes as **one** `drawVertices`, instead of one `drawPath` per
/// segment.
///
/// **A spike.** It exists to answer one question — whether collapsing the draw
/// calls collapses the frame — and it is honest about what it gives up to ask
/// it; see "What this is not" below.
///
/// ## Why this shape
///
/// `2026-08-20-dash-leaf-separation.md` measured the frame at a fixed drawn
/// geometry and found the unit of cost is the canvas call, not the drawn leaf:
/// holding `screenSpaceLeafCount` at 1664 and moving only the dash fraction
/// moved the frame 6.0x. Reading the engine at the revision that produced
/// those numbers showed why a cheaper *geometry* cannot help — a dash span is
/// a two-point path, so `dl_dispatcher.cc` lowers it through `IsLine` to
/// `AttemptDrawLineSDF` and it never reaches the stroke tessellator. There is
/// no tessellation left to remove. What is left is one Impeller `Entity` per
/// call, and the only lever on that is to make fewer calls.
///
/// ## One buffer, and why draw order survives
///
/// The first cut of this sink kept one buffer per colour and flushed them at
/// the end of the frame. That is a call per colour rather than a call per
/// segment, and it was fast — but it reordered the drawing, because every
/// segment of one colour then drew after every segment of another whatever
/// order the walk emitted them in. A screenshot of the harness showed it at
/// once: strokes are opaque, so a reordered stroke covers a different
/// neighbour, and the picture's colour balance changed. Draw order is
/// ascending handle value, and that is a rule about *strokes*, not only about
/// fills.
///
/// Carrying the colour on the vertices instead of on the `Paint` fixes both
/// halves at once. Triangles inside a single `drawVertices` rasterise in
/// submission order with no depth test between them, so the buffer's order
/// *is* the draw order — and there is exactly one call regardless of how many
/// colours the frame uses.
///
/// ## Width, and an approximation this does not make
///
/// `CanvasDrawSink._widthFor` divides the device width by the residual's
/// `scaleMagnitude`, because `Paint.strokeWidth` is measured in the canvas
/// units the residual has already scaled. `scaleMagnitude` is `sqrt(|det|)` —
/// one scalar standing in for two axis scales, which is exact only when the
/// residual is conformal. This sink takes the perpendicular **after**
/// transforming the endpoints, so the half-width is a device-pixel quantity on
/// both axes and the approximation is not made at all.
///
/// ## What this is not
///
/// - **No joins and no caps.** Every segment is an independent quad, so a
///   polyline's corners have a notch on the outside. Dash spans are two points
///   each and have no corners, which is where the measurement is aimed.
/// - **Points, circles, arcs and text still go to [CanvasDrawSink].** They are
///   drawn as they arrive, so they land *before* the flush — the one place
///   draw order is still wrong. Dashed curves reach `arc`, which is why the
///   measured call count does not fall as far as the segment count suggests.
/// - **Anti-aliasing comes from MSAA, not from a coverage shader.** The SDF
///   path this replaces anti-aliases analytically.
/// - **Hairlines are one device pixel, not zero.** A `strokeWidth` of 0 means
///   "hairline" to `Canvas`; a quad of width 0 means "invisible".
/// - **`flutter_test` cannot render it.** The software Skia backend takes
///   minutes on a `drawVertices` that Impeller draws instantly, so the golden
///   suite is not available to this sink.
class VerticesDrawSink implements DrawSink {
  VerticesDrawSink({
    required this.pixelsPerPaperMm,
    this.lineweightScale = 1.0,
    CanvasDrawSink? fallback,
  }) : _fallback = fallback;

  final double pixelsPerPaperMm;

  /// Measurement-only, as on [CanvasDrawSink]. Inert at 1.0.
  final double lineweightScale;

  /// Takes every op this sink does not batch: points, circles, arcs and text.
  ///
  /// Composition rather than reimplementation, so the spike changes exactly
  /// one thing about the frame and a run against it is comparable to a run
  /// against [CanvasDrawSink].
  final CanvasDrawSink? _fallback;

  /// Interleaved `[x, y]` per vertex, six vertices per segment.
  ///
  /// Capacity is never given back, so a steady-state frame allocates nothing
  /// here: [flush] rewinds the length and leaves the storage in place.
  Float32List _positions = Float32List(8192);

  /// One ARGB per vertex, parallel to [_positions].
  Int32List _colors = Int32List(4096);

  /// Vertices written, so `_vertices * 2` floats and `_vertices` colours.
  int _vertices = 0;

  Transform2 _residual = Transform2.identity();

  int _segments = 0;
  int _flushCalls = 0;
  int _lastFlushSegments = 0;
  int _lastFlushVertices = 0;

  /// Segments batched since the last [flush].
  int get batchedSegmentCount => _segments;

  /// Segments the last [flush] submitted. Survives the flush, which
  /// [batchedSegmentCount] does not, so a rig can read it after the frame.
  int get lastFlushSegmentCount => _lastFlushSegments;

  /// `drawVertices` calls the last [flush] issued: one, or none when the frame
  /// batched nothing.
  int get flushCallCount => _flushCalls;

  /// Vertices the last [flush] actually handed to `drawVertices`.
  ///
  /// Read from the view that was submitted rather than from the counter, so a
  /// flush that rewinds before it submits reports the empty buffer it drew
  /// rather than the full one it meant to.
  int get lastFlushVertexCount => _lastFlushVertices;

  /// The positions written so far, as `[x0, y0, x1, y1, ...]`.
  Float32List debugPositions() =>
      Float32List.sublistView(_positions, 0, _vertices * 2);

  /// The per-vertex colours written so far.
  Int32List debugColors() => Int32List.sublistView(_colors, 0, _vertices);

  @override
  void beginResidual(Transform2 residual, {Handle debugHandle = Handle.none}) {
    _residual = residual;
    _fallback?.beginResidual(residual, debugHandle: debugHandle);
  }

  @override
  void endResidual() {
    // Deliberately does not flush. A buffer outliving the residual that filled
    // it is the entire mechanism.
    _fallback?.endResidual();
  }

  @override
  void polyline(Float64List points, int count, ResolvedStyle style,
      {required bool closed}) {
    if (count < 2) return;
    final half = _halfWidthFor(style.lineweightHundredths);
    final argb = style.argb;

    final a = _residual.a, b = _residual.b, c = _residual.c;
    final d = _residual.d, e = _residual.e, f = _residual.f;

    // The transform is applied once per point rather than once per segment:
    // each point is the end of one segment and the start of the next.
    var px = a * points[0] + c * points[1] + e;
    var py = b * points[0] + d * points[1] + f;
    final firstX = px, firstY = py;

    for (var i = 1; i < count; i++) {
      final qx = a * points[i * 2] + c * points[i * 2 + 1] + e;
      final qy = b * points[i * 2] + d * points[i * 2 + 1] + f;
      _emitSegment(px, py, qx, qy, half, argb);
      px = qx;
      py = qy;
    }
    if (closed) _emitSegment(px, py, firstX, firstY, half, argb);
  }

  /// Two triangles, `(A, B, C)` and `(B, D, C)`, around the segment.
  void _emitSegment(
      double x0, double y0, double x1, double y1, double half, int argb) {
    final dx = x1 - x0, dy = y1 - y0;
    final length = math.sqrt(dx * dx + dy * dy);
    // A zero-length segment has no direction to take a normal from. `Canvas`
    // would draw a cap-shaped dot here; a quad would be NaN.
    if (length == 0) return;

    final nx = -dy / length * half;
    final ny = dx / length * half;

    _reserve(6);
    final v = _positions;
    var i = _vertices * 2;
    v[i++] = x0 + nx;
    v[i++] = y0 + ny;
    v[i++] = x0 - nx;
    v[i++] = y0 - ny;
    v[i++] = x1 + nx;
    v[i++] = y1 + ny;
    v[i++] = x0 - nx;
    v[i++] = y0 - ny;
    v[i++] = x1 - nx;
    v[i++] = y1 - ny;
    v[i++] = x1 + nx;
    v[i++] = y1 + ny;

    final colors = _colors;
    for (var k = _vertices; k < _vertices + 6; k++) {
      colors[k] = argb;
    }
    _vertices += 6;
    _segments++;
  }

  void _reserve(int moreVertices) {
    if (_vertices + moreVertices <= _colors.length) return;
    var capacity = _colors.length;
    while (capacity < _vertices + moreVertices) {
      capacity *= 2;
    }
    final positions = Float32List(capacity * 2);
    positions.setRange(0, _vertices * 2, _positions);
    _positions = positions;
    final colors = Int32List(capacity);
    colors.setRange(0, _vertices, _colors);
    _colors = colors;
  }

  double _halfWidthFor(int lineweightHundredths) {
    final devicePx =
        lineweightHundredths / 100.0 * pixelsPerPaperMm * lineweightScale;
    // A quad of width 0 is invisible, where a `strokeWidth` of 0 is a
    // hairline. One device pixel is the floor.
    final w = devicePx.isFinite && devicePx > 1.0 ? devicePx : 1.0;
    return w / 2;
  }

  /// Submits the frame's strokes as one `drawVertices` and rewinds the buffer.
  ///
  /// Called once a frame by the painter's owner, not by the walk.
  void flush(Canvas canvas) {
    _flushCalls = 0;
    _lastFlushSegments = _segments;
    _lastFlushVertices = 0;
    if (_vertices == 0) {
      _segments = 0;
      return;
    }
    final positions = Float32List.sublistView(_positions, 0, _vertices * 2);
    final colors = Int32List.sublistView(_colors, 0, _vertices);
    _lastFlushVertices = colors.length;
    canvas.drawVertices(
      Vertices.raw(
        VertexMode.triangles,
        positions,
        colors: colors,
      ),
      // With per-vertex colours and no shader on the paint, the vertex colour
      // is the colour drawn; the paint contributes only its alpha.
      BlendMode.dst,
      Paint()..color = const Color(0xFFFFFFFF),
    );
    _flushCalls = 1;
    _vertices = 0;
    _segments = 0;
  }

  @override
  void point(double x, double y, ResolvedStyle style) =>
      _fallback?.point(x, y, style);

  @override
  void circle(double cx, double cy, double r, ResolvedStyle style) =>
      _fallback?.circle(cx, cy, r, style);

  @override
  void arc(double cx, double cy, double r, double start, double sweep,
          ResolvedStyle style) =>
      _fallback?.arc(cx, cy, r, start, sweep, style);

  @override
  void text(String text, Handle style, ResolvedStyle resolved) =>
      _fallback?.text(text, style, resolved);
}
