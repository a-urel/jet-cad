import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';

import '../draw_sink.dart';
import 'instance_record.dart';

/// Collects a document's stroked segments into one buffer, in walk order.
///
/// **This is a `DrawSink`, and that is deliberate.** `RecordingDrawSink`
/// equality is this project's primary correctness mechanism; a backend that
/// invented its own traversal would give it up. What changes is not the
/// interface but *when* it runs — on a rebuild, not on a frame.
///
/// **Walk order is the draw order and nothing may reorder it.** The buffer is
/// submitted in the order written, in one draw call, and that is the whole
/// reason this design needs no depth buffer. Sorting it — by handle, by colour,
/// by anything — reintroduces the defect `vertices_draw_sink.dart:41-57`
/// records.
class GeometryCollector implements DrawSink {
  GeometryCollector({
    required this.pixelsPerPaperMm,
    required this.devicePixelRatio,
    this.lineweightScale = 1.0,
  });

  final double pixelsPerPaperMm;
  final double devicePixelRatio;
  final double lineweightScale;

  /// **A minimum stroke width in device pixels.** Copied from
  /// `VerticesDrawSink.kMinStrokeDevicePixels` rather than referenced —
  /// that constant is public (`vertices_draw_sink.dart:527`), so this is not
  /// a visibility workaround. It is kept a separate copy because these two
  /// classes are independent implementations of the same `DrawSink`
  /// contract, cross-checked by `collector_differential_test.dart` precisely
  /// *because* they arrive at their numbers separately; sharing this field
  /// would make that comparison partly circular, since both sides would be
  /// reading one value rather than two that happen to agree. If the two
  /// ever disagree the differential test (Task 8) goes red, which is the
  /// intended alarm — and `collector_differential_test.dart:204` reads
  /// `VerticesDrawSink.kMinStrokeDevicePixels` live (not hardcoded) on the
  /// reference side specifically so that alarm stays real if either value
  /// changes.
  static const double kMinStrokeDevicePixels = 1.0;

  Float32List _buffer = Float32List(0);
  int _instances = 0;
  int _skipped = 0;
  Transform2 _residual = Transform2.identity();

  /// Copies `_buffer` on every access — `sublist` allocates a fresh
  /// `Float32List`, not a view. At this plan's measured 10,000-entity scale
  /// (59,875 segments; `resident_geometry_test.dart:23`) that is roughly 2.3 MB
  /// copied per call (59,875 × [kFloatsPerInstance] × 4 bytes). Read it
  /// once per rebuild, into `ResidentGeometry.create`, and hoist it out of
  /// any per-frame path — Plan F's `paint()` call site included — or it
  /// breaks this project's "the frame path allocates nothing per entity in
  /// steady state" non-negotiable.
  Float32List get data => _buffer.sublist(0, _instances * kFloatsPerInstance);
  int get instanceCount => _instances;

  /// Ops this plan does not draw yet — `fillPolygon`, `fillCircle` and
  /// `text`. Counted rather than ignored so a corpus that needs Plan B
  /// through E is visible as a number instead of as a missing picture.
  ///
  /// This is the post-Plan-B set, landing ahead of the code that makes it
  /// true: `circle` and `arc` still count here today and stop counting in
  /// Task 5, `point` stops counting in Task 6. Task 6 is also where the test
  /// verifying this sentence lands.
  int get skippedOps => _skipped;

  /// Half the stroke's width, **in device pixels** — the space the vertex
  /// shader consumes `half_width` in (`shaders/cad_stroke.vert` documents
  /// the attribute `// device pixels` and applies it directly against
  /// `frame_info.half_viewport`, which `buildFrameInfo` also builds in
  /// device pixels; `gpu_draw_backend.dart`).
  ///
  /// **This method's first version computed the *logical* half-width
  /// instead, and every stroke drew at half weight under any
  /// `devicePixelRatio` other than 1.** `VerticesDrawSink._halfWidthFor`
  /// (`vertices_draw_sink.dart:544-552`) is correct for itself — Skia
  /// strokes in logical space, and its own local variable is even named
  /// `floorLogical` — and this method's original body copied that formula
  /// verbatim into a shader that does not share Skia's space. The fix is not
  /// a division relocated: the *logical* width is converted into device
  /// pixels (`* devicePixelRatio`) before it is compared against the floor
  /// or halved, and the floor is the device minimum
  /// (`kMinStrokeDevicePixels`) applied directly, not that minimum divided
  /// back down into logical space.
  double _halfWidthFor(int lineweightHundredths) {
    final logical =
        lineweightHundredths / 100.0 * pixelsPerPaperMm * lineweightScale;
    final device = logical * devicePixelRatio;
    final w = device.isFinite && device > kMinStrokeDevicePixels
        ? device
        : kMinStrokeDevicePixels;
    return w / 2;
  }

  /// The colour a stroke of this width is actually drawn in.
  ///
  /// Mirrors `VerticesDrawSink._coveredArgb`, which mirrors Impeller's
  /// `Geometry::ComputeStrokeAlphaCoverage`. A stroke thinner than one device
  /// pixel keeps its pixel — [_halfWidthFor] floors the width — and gives up
  /// alpha in proportion, so thinning a line fades it out instead of stopping
  /// at one pixel and staying there.
  ///
  /// **A width of exactly zero keeps full alpha.** That is the hairline case,
  /// and it is the first branch rather than an omission — the reference says
  /// so in as many words.
  ///
  /// **This must never reach a fill.** `fillPolygon` and `fillCircle` pass
  /// `style.argb` directly in the reference, because a fill entity's
  /// `ResolvedStyle` still carries a lineweight from the shared column and
  /// *"routing a fill through `_coveredArgb` would fade a filled room on a
  /// hairline layer"*. Plan D adds those two ops; it inherits that rule.
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

  void _emit(
      double x0, double y0, double x1, double y1, double half, int argb) {
    // Exactly the sink's own test: `_emitSegment` bails on zero length
    // (`vertices_draw_sink.dart:503-507`). A degenerate segment has no
    // direction and the shader would divide by zero building its normal.
    if (x0 == x1 && y0 == y1) return;
    _reserve(_instances + 1);
    writeStroke(_buffer, _instances,
        x0: x0, y0: y0, x1: x1, y1: y1, halfWidth: half, argb: argb);
    _instances++;
  }

  /// Doubling growth, mirroring `VerticesDrawSink._reserve`
  /// (`vertices_draw_sink.dart:511-521`). A `List<double>` grown via its
  /// `length` setter null-fills the new slots and throws for a non-nullable
  /// element type — confirmed by hand — so the buffer is a `Float32List`
  /// grown by copy, and `writeStroke` writes straight into it.
  void _reserve(int instances) {
    final needed = instances * kFloatsPerInstance;
    if (needed <= _buffer.length) return;
    var capacity = _buffer.isEmpty ? kFloatsPerInstance * 16 : _buffer.length;
    while (capacity < needed) {
      capacity *= 2;
    }
    final grown = Float32List(capacity);
    grown.setRange(0, _buffer.length, _buffer);
    _buffer = grown;
  }

  @override
  void beginResidual(Transform2 residual, {Handle debugHandle = Handle.none}) {
    _residual = residual;
  }

  @override
  void endResidual() {}

  @override
  void polyline(Float64List points, int count, ResolvedStyle style,
      {required bool closed}) {
    if (count < 2) return;
    final half = _halfWidthFor(style.lineweightHundredths);
    final argb = _coveredArgb(style.argb, style.lineweightHundredths);
    final t = _residual;
    var px = t.a * points[0] + t.c * points[1] + t.e;
    var py = t.b * points[0] + t.d * points[1] + t.f;
    final firstX = px, firstY = py;
    for (var i = 1; i < count; i++) {
      final qx = t.a * points[i * 2] + t.c * points[i * 2 + 1] + t.e;
      final qy = t.b * points[i * 2] + t.d * points[i * 2 + 1] + t.f;
      _emit(px, py, qx, qy, half, argb);
      px = qx;
      py = qy;
    }
    if (closed) _emit(px, py, firstX, firstY, half, argb);
  }

  @override
  void point(double x, double y, ResolvedStyle style) => _skipped++;

  @override
  void circle(double cx, double cy, double r, ResolvedStyle style) =>
      _skipped++;

  @override
  void arc(double cx, double cy, double r, double start, double sweep,
          ResolvedStyle style) =>
      _skipped++;

  @override
  void fillPolygon(Float64List points, int count, Int32List triangles,
          ResolvedStyle style) =>
      _skipped++;

  @override
  void fillCircle(double cx, double cy, double r, ResolvedStyle style) =>
      _skipped++;

  @override
  void text(String text, Handle style, ResolvedStyle resolved) => _skipped++;
}
