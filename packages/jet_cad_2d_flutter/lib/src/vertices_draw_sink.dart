import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'canvas_draw_sink.dart';
import 'draw_sink.dart';

/// Handed the position and colour views a [VerticesDrawSink.flush] submitted,
/// before it rewinds the buffer.
///
/// The views are live over the sink's own storage and are valid only for the
/// duration of the call; an observer that keeps one must copy it.
typedef FlushObserver = void Function(Float32List positions, Int32List colors);

/// Builds each stroked segment's two triangles itself and submits the whole
/// frame's strokes as **one** `drawVertices`, instead of one `drawPath` per
/// segment.
///
/// **The default backend on every platform, the web included.** It began as a
/// spike, built to answer one question — whether collapsing the draw calls
/// collapses the frame. Plan 3d's Phase C answered it and Task 13 flipped the
/// default; the numbers are in
/// `docs/superpowers/notes/2026-08-21-plan-3d-results.md`. What it gives up to
/// buy that is unchanged and still listed under "What this is not" below —
/// being the default does not make any of it go away.
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
/// - **No caps.** Miter and bevel joins fill the notch at every corner,
///   including a closed polyline's or a full sweep's seam; an open run's two
///   ends still draw nothing beyond their last quad.
/// - **Text goes to [CanvasDrawSink], and the buffer flushes before it.**
///   A paragraph is not triangles. Points, circles and arcs are batched;
///   only text falls back, and flushing first is what keeps a stroke batched
///   before a text op from drawing after it.
/// - **Anti-aliasing comes from MSAA, not from a coverage shader.** The SDF
///   path this replaces anti-aliases analytically.
/// - **`flutter_test` cannot *rasterise* it, so its goldens take another
///   route.** The software Skia backend takes minutes on a `drawVertices`
///   that Impeller draws instantly, which rules out `matchesGoldenFile` on a
///   widget drawn by this sink — that much is still true and still the reason
///   the seam below exists. It does **not** mean there are no goldens: the
///   [observer] hands each submitted buffer to
///   `test/support/triangle_rasterizer.dart`, which scan-converts it in Dart,
///   and the 14 PNGs in `test/golden/vertices/` are matched against *that*
///   image. Update them the same way as any other golden.
/// - **This sink is authoritative where it disagrees with [CanvasDrawSink].**
///   Under a non-conformal residual the two draw different stroke widths, and
///   this one is right: `CanvasDrawSink._widthFor` divides by
///   `scaleMagnitude`, one scalar standing in for two axis scales. The full
///   list of permitted divergences is in Plan 3d's design document; anything
///   not on it is a defect.
///
/// ## What a steady-state frame allocates
///
/// Three objects per flush — the `Vertices` and the two `sublistView`
/// wrappers — and nothing per entity. The buffers themselves are grown once
/// and reused; `test/invariants/paint_allocation_test.dart` fails if they grow
/// in a steady-state frame. With text in the corpus a frame flushes once per
/// text op plus once at the end, so the frame's total is
/// `3 * (textOps + 1)`.
class VerticesDrawSink implements DrawSink {
  VerticesDrawSink({
    required this.pixelsPerPaperMm,
    this.lineweightScale = 1.0,
    CanvasDrawSink? fallback,
    Canvas? canvas,
    this.devicePixelRatio = 1.0,
  }) : _fallback = fallback {
    if (canvas != null) this.canvas = canvas;
  }

  /// Device pixels per logical pixel, rebound per frame by the widget.
  ///
  /// The buffer is in logical pixels, because that is the space the `Canvas`
  /// this sink flushes into is in. Both of Impeller's stroke rules are in
  /// *device* pixels, so converting between them is what this is for.
  double devicePixelRatio;

  /// Where [flush] submits. Rebound each frame, as on [CanvasDrawSink].
  late Canvas canvas;

  /// Watches every flush, or null.
  ///
  /// **Test seam, null in production.** `flush` submits, disposes and rewinds
  /// in one call, so there is no moment outside it at which the triangles
  /// Impeller was given can be read. The rasterizer in
  /// `test/support/triangle_rasterizer.dart` is the only caller.
  FlushObserver? observer;

  /// Chord error allowed when flattening a curve, in device pixels.
  ///
  /// A quarter pixel: below what MSAA can show, and low enough that a curve
  /// zoomed to fill the viewport still reads as a curve. It sets the segment
  /// count through `N = theta * sqrt(R / (8 * tolerance))`, which is the
  /// inverse of the sagitta `R * (1 - cos(theta / 2N))`.
  static const double kFlattenTolerance = 0.25;

  /// Ceiling on the segments one curve may contribute.
  ///
  /// A curve larger than the viewport is clipped by the camera long before it
  /// needs this many, so the cap costs nothing on a drawing and bounds the
  /// damage from a residual that has gone wrong.
  static const int kMaxFlattenSegments = 512;

  final double pixelsPerPaperMm;

  /// Measurement-only, as on [CanvasDrawSink]. Inert at 1.0.
  final double lineweightScale;

  /// Takes the ops this sink does not batch, which is fewer than it sounds:
  /// exactly [beginResidual], [endResidual] and [text] forward here. Points,
  /// circles and arcs all become triangles in this sink and never reach it.
  ///
  /// Composition rather than reimplementation, so the spike changes exactly
  /// one thing about the frame and a run against it is comparable to a run
  /// against [CanvasDrawSink].
  final CanvasDrawSink? _fallback;

  /// Interleaved `[x, y]` per vertex, six vertices per segment.
  ///
  /// Capacity is never given back, so a steady-state frame allocates nothing
  /// here: [flush] rewinds the length and leaves the storage in place. That
  /// is not free — see [debugCapacityVertices] for what the high-water mark
  /// costs in bytes and for the measurement it was read from.
  Float32List _positions = Float32List(8192);

  /// One ARGB per vertex, parallel to [_positions].
  Int32List _colors = Int32List(4096);

  /// One paint for the life of the sink, as on [CanvasDrawSink].
  ///
  /// It never varies: the colour rides on the vertices, so the only thing the
  /// paint contributes is its alpha, and that is always opaque.
  final Paint _paint = Paint()..color = const Color(0xFFFFFFFF);

  /// The [Paint] instance [flush] hands to `drawVertices`.
  ///
  /// Exposed so `paint_allocation_test.dart` can pin its *identity* across
  /// flushes -- `debugCapacityVertices` alone cannot see a fresh [Paint]
  /// built every call, because a `Paint` is not part of either buffer.
  Paint get debugPaint => _paint;

  /// Vertices written, so `_vertices * 2` floats and `_vertices` colours.
  int _vertices = 0;

  // Run state. Fields and not a per-run object, because a `_StrokeRun`
  // allocated per polyline would put an allocation back on the frame path
  // that `paint_allocation_test.dart` has just finished pinning at zero.
  //
  // `_runFirst*` and `_runSegments` are read by the closed branch of
  // `_endRun`: the seam join needs the first point to close the run to and
  // the first segment's own direction to join against, and the guard needs
  // the segment count to tell a real corner from a two-point reversal.
  double _runFirstX = 0, _runFirstY = 0;
  double _runFirstDx = 0, _runFirstDy = 0;
  double _runPrevX = 0, _runPrevY = 0;
  double _runPrevDx = 0, _runPrevDy = 0;
  bool _runHasDirection = false;
  int _runSegments = 0;

  Transform2 _residual = Transform2.identity();

  int _segments = 0;
  int _flushCalls = 0;
  int _lastFlushSegments = 0;
  int _lastFlushVertices = 0;
  int _totalFlushes = 0;
  int _frameTriangles = 0;
  bool _lastFlushDisposed = false;

  /// Segments batched since the last [flush].
  int get batchedSegmentCount => _segments;

  /// Segments the last [flush] submitted. Survives the flush, which
  /// [batchedSegmentCount] does not, so a rig can read it after the frame.
  int get lastFlushSegmentCount => _lastFlushSegments;

  /// `drawVertices` calls the last [flush] issued: one, or none when the frame
  /// batched nothing.
  int get flushCallCount => _flushCalls;

  /// `drawVertices` calls issued since [resetCounters], including the
  /// mid-frame ones an unbatchable op forces.
  ///
  /// [flushCallCount] reports the *last* flush alone, which is one or none.
  /// With text in the corpus a frame flushes many times, so this is the number
  /// a rig should print beside `CanvasDrawSink.canvasCallCount`.
  int get totalFlushCount => _totalFlushes;

  /// Triangles emitted since [resetCounters], across every flush in the
  /// frame -- a quad's own two and a join's one or two, both counted
  /// individually, so this equals `debugPositions().length ~/ 6` for the
  /// frame as a whole.
  ///
  /// Named `frameSegmentCount` before joins existed, when a quad's two
  /// triangles and "one segment" were the same count. [batchedSegmentCount]
  /// and [lastFlushSegmentCount] are both per-flush and both still count
  /// quads, not triangles; neither is the frame's total once a mid-frame
  /// flush has happened.
  int get frameTriangleCount => _frameTriangles;

  /// Zeroes the frame counters. The buffer and its capacity are untouched.
  void resetCounters() {
    _totalFlushes = 0;
    _frameTriangles = 0;
  }

  /// Vertices the last [flush] actually handed to `drawVertices`.
  ///
  /// Read from the view that was submitted rather than from the counter, so a
  /// flush that rewinds before it submits reports the empty buffer it drew
  /// rather than the full one it meant to.
  int get lastFlushVertexCount => _lastFlushVertices;

  /// Whether the last [flush] disposed the `Vertices` it submitted.
  ///
  /// Exposed rather than the object itself, because the object is gone by the
  /// time anything could read it — which is the point.
  ///
  /// **Debug-only.** It is set from `Vertices.debugDisposed`, which reads a
  /// private field guarded by `assert` in the engine and throws a
  /// `StateError` when asserts are off. This getter never reads that field
  /// outside an `assert` block, so in a release build it stays `false`
  /// whether or not disposal happened -- it exists for the test in
  /// `vertices_draw_sink_test.dart` to check, not for the frame path to rely
  /// on.
  bool get lastFlushDisposed => _lastFlushDisposed;

  /// The positions written so far, as `[x0, y0, x1, y1, ...]`.
  Float32List debugPositions() =>
      Float32List.sublistView(_positions, 0, _vertices * 2);

  /// The per-vertex colours written so far.
  Int32List debugColors() => Int32List.sublistView(_colors, 0, _vertices);

  /// Vertices the buffers can hold without growing.
  ///
  /// The steady-state claim is that this stops changing: `_reserve` doubles
  /// and never gives capacity back, so once a frame has drawn its widest view
  /// the buffer is large enough for every later one.
  ///
  /// **What that costs, measured.** A vertex is 12 bytes here — a `Float32x2`
  /// position plus an `Int32` colour — and the peak is pinned for the life of
  /// the widget, because nothing ever shrinks it. On the dev harness's R2
  /// corpus (`apps/dev_harness_2d`, pan 120 / zoom 120 over an 800x600
  /// viewport) the peaks read out of this getter were 262,144 vertices at
  /// 10,000 entities (3.00 MiB), 1,048,576 at 50,000 (12.00 MiB) and
  /// **8,388,608 at 500,000 entities — 100,663,296 bytes, exactly 96.00
  /// MiB**. The canvas backend has no equivalent cost. Whoever budgets memory
  /// for a large drawing needs that number; the full table is in
  /// `docs/superpowers/notes/2026-08-21-plan-3d-results.md`.
  int get debugCapacityVertices => _colors.length;

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
    final argb = _coveredArgb(style.argb, style.lineweightHundredths);

    final a = _residual.a, b = _residual.b, c = _residual.c;
    final d = _residual.d, e = _residual.e, f = _residual.f;

    // The transform is applied once per point rather than once per segment:
    // each point is the end of one segment and the start of the next.
    final px = a * points[0] + c * points[1] + e;
    final py = b * points[0] + d * points[1] + f;
    _beginRun(px, py);
    for (var i = 1; i < count; i++) {
      final qx = a * points[i * 2] + c * points[i * 2 + 1] + e;
      final qy = b * points[i * 2] + d * points[i * 2 + 1] + f;
      _runTo(qx, qy, half, argb);
    }
    _endRun(closed: closed, half: half, argb: argb);
    // `closed` is forwarded rather than hardcoded so a closed polyline gets
    // its closing segment and seam join. No caller reaches it today:
    // `closed:` is `false` at all four of the painter's call sites.
  }

  /// Starts a connected run at a device-space point.
  void _beginRun(double x, double y) {
    _runFirstX = x;
    _runFirstY = y;
    _runPrevX = x;
    _runPrevY = y;
    _runHasDirection = false;
    _runSegments = 0;
  }

  /// Extends the run to a device-space point, emitting the join first.
  ///
  /// The join comes before the segment so the buffer's order is the drawing's
  /// order: at a corner the ink nearer the start of the run is written first.
  void _runTo(double x, double y, double half, int argb) {
    final dx = x - _runPrevX, dy = y - _runPrevY;
    final length = math.sqrt(dx * dx + dy * dy);
    // A repeated point carries no direction. Skip the step, keep the previous
    // direction, and let the join span it — the corner is still there.
    if (length == 0) return;
    final ux = dx / length, uy = dy / length;

    if (_runHasDirection) {
      _emitJoin(
          _runPrevX, _runPrevY, _runPrevDx, _runPrevDy, ux, uy, half, argb);
    } else {
      _runFirstDx = ux;
      _runFirstDy = uy;
    }
    _emitQuad(_runPrevX, _runPrevY, x, y, ux, uy, half, argb);

    _runPrevX = x;
    _runPrevY = y;
    _runPrevDx = ux;
    _runPrevDy = uy;
    _runHasDirection = true;
    _runSegments++;
  }

  /// Ends the run.
  ///
  /// An open run gets butt caps, which is to say nothing at all. A closed run
  /// gets the segment back to its first point and then the seam join — the
  /// corner no vertex list contains, and the one whose absence puts a notch on
  /// every circle at its start angle.
  void _endRun(
      {required bool closed, required double half, required int argb}) {
    if (!closed || !_runHasDirection) return;
    _runTo(_runFirstX, _runFirstY, half, argb);
    // Defensive, not currently reachable-false: `_runHasDirection` already
    // guarantees at least one real segment before this point, and the
    // closing `_runTo` above either adds a second (when it moves) or leaves
    // `_runSegments` at that pre-existing count of at least one (when it is
    // already back at the start and skips as a zero-length step) -- there is
    // no path that reaches here with exactly one. Kept as a guard anyway
    // because the invariant is a fact about today's callers, not a promise
    // `_emitJoin` makes on its own.
    if (_runSegments >= 2) {
      _emitJoin(_runFirstX, _runFirstY, _runPrevDx, _runPrevDy, _runFirstDx,
          _runFirstDy, half, argb);
    }
  }

  /// Fills the notch at a vertex between two unit directions.
  ///
  /// The notch is the quadrilateral `(V, A, M, B)` — vertex, outer corner of
  /// the incoming segment, miter point, outer corner of the outgoing one — so
  /// a miter is **two** triangles: the bevel `(V, A, B)` and the tip
  /// `(A, M, B)`. The tip alone leaves a hairline crack along `AB`.
  void _emitJoin(double vx, double vy, double d0x, double d0y, double d1x,
      double d1y, double half, int argb) {
    final cross = d0x * d1y - d0y * d1x;
    // Collinear: either straight through, where the quads already meet, or a
    // reversal, where both the miter and the bevel are degenerate.
    if (cross == 0) return;

    // The outer side of the turn is the one away from it: a left turn
    // (cross > 0) opens a notch on the right.
    final s = cross > 0 ? -half : half;
    final n0x = -d0y * s, n0y = d0x * s;
    final n1x = -d1y * s, n1y = d1x * s;
    final ax = vx + n0x, ay = vy + n0y;
    final bx = vx + n1x, by = vy + n1y;

    _emitTriangle(vx, vy, ax, ay, bx, by, argb);

    if (d0x * d1x + d0y * d1y < kMinMiterCosine) return;

    var mx = n0x + n1x, my = n0y + n1y;
    final mlen = math.sqrt(mx * mx + my * my);
    // Defensive, not currently reachable, and kept for the same reason as
    // `_endRun`'s guard: `n0` and `n1` have equal length, so their sum
    // vanishes only when they are antiparallel -- which is `d0` and `d1`
    // antiparallel, a dot product of -1, and the `kMinMiterCosine` bail three
    // lines up already returned. It stays because that is a fact about
    // today's bail threshold (-0.875 at a miter limit of 4) and not a promise
    // the arithmetic below makes on its own; without it a loosened limit
    // divides by zero and writes NaN positions into the buffer.
    if (mlen == 0) return;
    mx /= mlen;
    my /= mlen;
    // `n0` has length `half`, so this is the cosine of half the included angle.
    final cosHalf = (mx * n0x + my * n0y) / half;
    // Defensive, not currently reachable, and unreachable for the same reason:
    // the bail bounds the turn at about 151 degrees, so half of it is under
    // 76 and its cosine is comfortably positive. Kept because the alternative
    // to a bounded `reach` is a miter spike of unbounded length -- the failure
    // a miter limit exists to prevent -- so this is the guard that survives if
    // the threshold ever moves.
    if (cosHalf <= 0) return;
    final reach = half / cosHalf;
    _emitTriangle(ax, ay, vx + mx * reach, vy + my * reach, bx, by, argb);
  }

  /// Writes one triangle, six floats and three colours.
  void _emitTriangle(double ax, double ay, double bx, double by, double cx,
      double cy, int argb) {
    _reserve(3);
    final v = _positions;
    var i = _vertices * 2;
    v[i++] = ax;
    v[i++] = ay;
    v[i++] = bx;
    v[i++] = by;
    v[i++] = cx;
    v[i++] = cy;
    final colors = _colors;
    for (var k = _vertices; k < _vertices + 3; k++) {
      colors[k] = argb;
    }
    _vertices += 3;
    _frameTriangles++;
  }

  /// Two triangles around a segment whose unit direction is already known.
  void _emitQuad(double x0, double y0, double x1, double y1, double ux,
      double uy, double half, int argb) {
    final nx = -uy * half, ny = ux * half;

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
    _frameTriangles += 2;
  }

  /// Two triangles around a segment, taking its direction from its endpoints.
  void _emitSegment(
      double x0, double y0, double x1, double y1, double half, int argb) {
    final dx = x1 - x0, dy = y1 - y0;
    final length = math.sqrt(dx * dx + dy * dy);
    // A zero-length segment has no direction to take a normal from. `Canvas`
    // would draw a cap-shaped dot here; a quad would be NaN.
    if (length == 0) return;
    _emitQuad(x0, y0, x1, y1, dx / length, dy / length, half, argb);
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

  /// Impeller's thinnest line, in device pixels: `kMinStrokeSize` from
  /// `impeller/entity/geometry/geometry.h`.
  static const double kMinStrokeDevicePixels = 1.0;

  /// Flutter's default miter limit (`painting.dart:1535`).
  static const double kMiterLimit = 4.0;

  /// The cosine of the direction change at which a miter becomes a bevel.
  ///
  /// Impeller's own conversion of the limit: `2 * (1 / limit)^2 - 1`
  /// (`stroke_path_geometry.cc:442`). At a limit of 4 that is -0.875, so a
  /// corner is mitred up to about a 151-degree turn and bevelled past it.
  static const double kMinMiterCosine =
      2.0 * (1.0 / kMiterLimit) * (1.0 / kMiterLimit) - 1.0;

  /// Half the stroke's width, in the logical pixels the buffer is in.
  ///
  /// Mirrors `LineGeometry::ComputePixelHalfWidth`: the width is clamped in
  /// device space, never in logical space, so the same lineweight draws the
  /// same line on a retina display and an external monitor.
  double _halfWidthFor(int lineweightHundredths) {
    final logical =
        lineweightHundredths / 100.0 * pixelsPerPaperMm * lineweightScale;
    final floorLogical = kMinStrokeDevicePixels / devicePixelRatio;
    final w =
        logical.isFinite && logical > floorLogical ? logical : floorLogical;
    return w / 2;
  }

  /// The colour a stroke of this width is actually drawn in.
  ///
  /// Mirrors `Geometry::ComputeStrokeAlphaCoverage`. A stroke thinner than one
  /// device pixel keeps its pixel and gives up alpha in proportion, so that
  /// thinning a line fades it out instead of stopping at one pixel and staying
  /// there. A width of exactly zero is the hairline case and keeps full alpha
  /// — that is the first branch there, not an omission.
  int _coveredArgb(int argb, int lineweightHundredths) {
    final deviceWidth = lineweightHundredths /
        100.0 *
        pixelsPerPaperMm *
        lineweightScale *
        devicePixelRatio;
    if (!deviceWidth.isFinite ||
        deviceWidth <= 0 ||
        deviceWidth >= kMinStrokeDevicePixels) {
      return argb;
    }
    final coverage = (deviceWidth * 2).clamp(0.0, 1.0);
    final alpha = (((argb >> 24) & 0xFF) * coverage).round();
    return (alpha << 24) | (argb & 0x00FFFFFF);
  }

  /// Submits everything batched so far as one `drawVertices` and rewinds the
  /// buffer.
  ///
  /// Called at the end of the frame by the painter's owner, and mid-frame by
  /// any op that cannot become triangles -- see [_flushBeforeUnbatchable].
  void flush() {
    _flushCalls = 0;
    _lastFlushSegments = _segments;
    _lastFlushVertices = 0;
    _lastFlushDisposed = false;
    if (_vertices == 0) {
      _segments = 0;
      return;
    }
    final positions = Float32List.sublistView(_positions, 0, _vertices * 2);
    final colors = Int32List.sublistView(_colors, 0, _vertices);
    _lastFlushVertices = colors.length;
    observer?.call(positions, colors);
    final vertices = Vertices.raw(
      VertexMode.triangles,
      positions,
      colors: colors,
    );
    canvas.drawVertices(
      vertices,
      // With per-vertex colours and no shader on the paint, the vertex colour
      // is the colour drawn; the paint contributes only its alpha.
      BlendMode.dst,
      _paint,
    );
    // `drawVertices` has taken what it needs by the time it returns; holding
    // the object past that point holds native buffers the engine has already
    // copied. Verified against a `PictureRecorder` here and on a device in
    // Plan 3d Task 2 step 7.
    vertices.dispose();
    // Read the object's own state rather than assert the flag beside the
    // call above -- an unconditional `= true` here would stay true even if
    // `dispose()` were deleted, which is the exact regression this field
    // exists to catch. `debugDisposed` throws outside asserts, so it must
    // never execute in a release build.
    assert(() {
      _lastFlushDisposed = vertices.debugDisposed;
      return true;
    }());
    _flushCalls = 1;
    _totalFlushes++;
    _vertices = 0;
    _segments = 0;
  }

  /// Submits the batch so an op that cannot be batched draws after it.
  ///
  /// Without this the unbatchable op would reach the `Canvas` immediately
  /// while every stroke before it waited for the end of the frame, which is
  /// the reordering the class comment's history describes. Text is the only
  /// caller: a paragraph is not triangles.
  void _flushBeforeUnbatchable() {
    if (_vertices == 0) return;
    flush();
  }

  /// A dot the width of the stroke, as two triangles.
  ///
  /// `Canvas` would draw it through `drawRawPoints`, whose square-cap form is
  /// exactly this quad; the round-cap form is not reachable from here, and no
  /// caller asks for one.
  @override
  void point(double x, double y, ResolvedStyle style) {
    final half = _halfWidthFor(style.lineweightHundredths);
    final t = _residual;
    final px = t.a * x + t.c * y + t.e;
    final py = t.b * x + t.d * y + t.f;
    // A horizontal segment of the stroke's own width is a square of it.
    _emitSegment(px - half, py, px + half, py, half,
        _coveredArgb(style.argb, style.lineweightHundredths));
  }

  @override
  void circle(double cx, double cy, double r, ResolvedStyle style) =>
      _flatten(cx, cy, r, 0, 2 * math.pi, style, closed: true);

  @override
  void arc(double cx, double cy, double r, double start, double sweep,
          ResolvedStyle style) =>
      _flatten(cx, cy, r, start, sweep, style, closed: false);

  /// Walks a circular arc in the residual's local space, emitting a chord per
  /// step.
  ///
  /// Local space, not device space, on purpose: the residual may be
  /// non-uniform, and the arc that `Canvas` would draw under it is an ellipse.
  /// Flattening here and transforming each point reproduces that ellipse;
  /// flattening a device-space circle would not.
  ///
  /// Only the *count* is a device-space decision — the chord error the viewer
  /// sees is a device-pixel quantity, so the radius that sets it has to be the
  /// on-screen one.
  void _flatten(double cx, double cy, double r, double start, double sweep,
      ResolvedStyle style,
      {required bool closed}) {
    if (r <= 0 || sweep == 0) return;
    final t = _residual;
    final deviceRadius = r * t.scaleMagnitude;
    if (deviceRadius <= 0) return;

    final theta = sweep.abs();
    final steps = _flattenSteps(deviceRadius, theta);

    final half = _halfWidthFor(style.lineweightHundredths);
    final argb = _coveredArgb(style.argb, style.lineweightHundredths);
    final step = sweep / steps;

    var lx = cx + r * math.cos(start);
    var ly = cy + r * math.sin(start);
    _beginRun(t.a * lx + t.c * ly + t.e, t.b * lx + t.d * ly + t.f);
    // A closed sweep stops one sample short: its last chord is the segment
    // `_endRun` draws back to the first point, so closing here would draw
    // that chord twice and leave the seam a duplicated point instead of a
    // join.
    final last = closed ? steps - 1 : steps;
    for (var i = 1; i <= last; i++) {
      final angle = start + step * i;
      lx = cx + r * math.cos(angle);
      ly = cy + r * math.sin(angle);
      _runTo(t.a * lx + t.c * ly + t.e, t.b * lx + t.d * ly + t.f, half, argb);
    }
    _endRun(closed: closed, half: half, argb: argb);
  }

  /// The chord count a device-space circle or arc of [deviceRadius] and
  /// sweep [theta] flattens to.
  ///
  /// One expression, shared by `_flatten`'s stroke and [fillCircle]'s fan:
  /// a filled circle's silhouette is tessellated by the *same* call as its
  /// own outline, so the two never disagree, at any zoom.
  int _flattenSteps(double deviceRadius, double theta) {
    final ideal =
        (theta * math.sqrt(deviceRadius / (8 * kFlattenTolerance))).ceil();
    return ideal.clamp(1, kMaxFlattenSegments);
  }

  @override
  void text(String text, Handle style, ResolvedStyle resolved) {
    _flushBeforeUnbatchable();
    _fallback?.text(text, style, resolved);
  }

  /// Emits [triangles] straight into the batch, transforming each referenced
  /// point as it goes.
  ///
  /// `triangles` triple-indexes into `points`' own point numbering, so each
  /// index is doubled to reach the coordinate pair. Nothing is allocated: the
  /// boundary's points are transformed straight into the shared buffer, same
  /// as every other emitter here.
  @override
  void fillPolygon(
      Float64List points, int count, Int32List triangles, ResolvedStyle style) {
    if (triangles.isEmpty) return;
    final t = _residual;
    // `style.argb` directly, NOT `_coveredArgb`: that function fades a stroke
    // thinner than a device pixel, and a fill has no width. A fill entity's
    // `ResolvedStyle` still carries a lineweight because the column is
    // shared with strokes, so routing a fill through `_coveredArgb` would
    // fade a filled room on a hairline layer -- on this backend only.
    final argb = style.argb;
    for (var i = 0; i < triangles.length; i += 3) {
      final a = triangles[i], b = triangles[i + 1], c = triangles[i + 2];
      _emitTriangle(
        t.a * points[a * 2] + t.c * points[a * 2 + 1] + t.e,
        t.b * points[a * 2] + t.d * points[a * 2 + 1] + t.f,
        t.a * points[b * 2] + t.c * points[b * 2 + 1] + t.e,
        t.b * points[b * 2] + t.d * points[b * 2 + 1] + t.f,
        t.a * points[c * 2] + t.c * points[c * 2 + 1] + t.e,
        t.b * points[c * 2] + t.d * points[c * 2 + 1] + t.f,
        argb,
      );
    }
  }

  /// A triangle fan around the circle's centre, at the same step count
  /// `_flatten` would give its own outline.
  @override
  void fillCircle(double cx, double cy, double r, ResolvedStyle style) {
    if (r <= 0) return;
    final t = _residual;
    final deviceRadius = r * t.scaleMagnitude;
    if (deviceRadius <= 0) return;
    const theta = 2 * math.pi;
    final steps = _flattenSteps(deviceRadius, theta);
    final argb = style.argb;
    final ccx = t.a * cx + t.c * cy + t.e;
    final ccy = t.b * cx + t.d * cy + t.f;
    var px = cx + r, py = cy;
    var dx = t.a * px + t.c * py + t.e, dy = t.b * px + t.d * py + t.f;
    for (var i = 1; i <= steps; i++) {
      final angle = theta * i / steps;
      px = cx + r * math.cos(angle);
      py = cy + r * math.sin(angle);
      final nx = t.a * px + t.c * py + t.e, ny = t.b * px + t.d * py + t.f;
      _emitTriangle(ccx, ccy, dx, dy, nx, ny, argb);
      dx = nx;
      dy = ny;
    }
  }
}
