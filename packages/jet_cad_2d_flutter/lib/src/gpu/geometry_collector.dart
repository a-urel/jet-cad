import 'dart:math' as math;
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

  // The run state machine, mirroring `VerticesDrawSink._beginRun` /
  // `_runTo` / `_endRun`. It is duplicated rather than shared because these
  // two classes are independent implementations of one `DrawSink` contract,
  // cross-checked against each other by the differential gates -- the same
  // reason `kMinStrokeDevicePixels` is a separate copy.
  //
  // Points, not directions: `_runBack` is the point BEFORE `_runPrev`, so a
  // join is written as its three points and the shader normalises after the
  // mvp. See `writeJoin`'s doc for why directions could not be stored here.
  double _runFirstX = 0, _runFirstY = 0;
  double _runSecondX = 0, _runSecondY = 0;
  double _runPrevX = 0, _runPrevY = 0;
  double _runBackX = 0, _runBackY = 0;
  bool _runHasDirection = false;
  int _runSegments = 0;

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
  /// `circle` and `arc` stopped counting here in Task 5; `point` in Task 6,
  /// which is also where the test that pins this whole sentence lands.
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
    // The reference's own test (`vertices_draw_sink.dart`, `_emitSegment`): a
    // zero-length segment has no direction to take a normal from. Matching
    // the formula, not the intention -- see `_runTo`.
    final dx = x1 - x0, dy = y1 - y0;
    if (math.sqrt(dx * dx + dy * dy) == 0) return;
    _reserve(_instances + 1);
    writeStroke(_buffer, _instances,
        x0: x0, y0: y0, x1: x1, y1: y1, halfWidth: half, argb: argb);
    _instances++;
  }

  /// Starts a connected run at a collection-space point.
  void _beginRun(double x, double y) {
    _runFirstX = x;
    _runFirstY = y;
    _runSecondX = x;
    _runSecondY = y;
    _runPrevX = x;
    _runPrevY = y;
    _runBackX = x;
    _runBackY = y;
    _runHasDirection = false;
    _runSegments = 0;
  }

  /// Extends the run, emitting the join **before** the segment.
  ///
  /// The zero-length test is `length == 0` on the square root, not
  /// `x == _runPrevX && y == _runPrevY`, because that is the reference's test
  /// (`vertices_draw_sink.dart`, `_runTo`) and the two are not the same
  /// predicate: for a displacement near the underflow boundary `dx * dx`
  /// rounds to zero while `dx` itself is non-zero, so the equality form keeps
  /// a step the reference drops. Matching the formula rather than the
  /// intention is what keeps the two arms' instance lists identical.
  void _runTo(double x, double y, double half, int argb) {
    final dx = x - _runPrevX, dy = y - _runPrevY;
    if (math.sqrt(dx * dx + dy * dy) == 0) return;

    if (_runHasDirection) {
      _emitJoin(_runPrevX, _runPrevY, _runBackX, _runBackY, x, y, half, argb);
    } else {
      _runSecondX = x;
      _runSecondY = y;
    }
    _emit(_runPrevX, _runPrevY, x, y, half, argb);

    _runBackX = _runPrevX;
    _runBackY = _runPrevY;
    _runPrevX = x;
    _runPrevY = y;
    _runHasDirection = true;
    _runSegments++;
  }

  /// Ends the run.
  ///
  /// An open run gets butt caps, which is to say nothing at all — the
  /// reference's own words, and the reason this plan emits no cap geometry.
  /// A closed run gets the segment back to its first point and then the seam
  /// join, the corner no vertex list contains and the one whose absence puts
  /// a notch on every circle at its start angle.
  void _endRun(
      {required bool closed, required double half, required int argb}) {
    if (!closed || !_runHasDirection) return;
    _runTo(_runFirstX, _runFirstY, half, argb);
    // Guarded for the same reason the reference guards it: today's callers
    // cannot reach here with one segment, but that is a fact about the
    // callers, not a promise the join arithmetic makes.
    if (_runSegments >= 2) {
      _emitJoin(_runFirstX, _runFirstY, _runBackX, _runBackY, _runSecondX,
          _runSecondY, half, argb);
    }
  }

  void _emitJoin(double vx, double vy, double prevX, double prevY, double nextX,
      double nextY, double half, int argb) {
    // No collinearity test here, deliberately: the bevel/miter/collinear
    // decision belongs to the shader, in device pixels, where the reference
    // makes it too. See this plan's Ruling B4.
    _reserve(_instances + 1);
    writeJoin(_buffer, _instances,
        vx: vx,
        vy: vy,
        prevX: prevX,
        prevY: prevY,
        nextX: nextX,
        nextY: nextY,
        halfWidth: half,
        argb: argb);
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
    _beginRun(t.a * points[0] + t.c * points[1] + t.e,
        t.b * points[0] + t.d * points[1] + t.f);
    for (var i = 1; i < count; i++) {
      _runTo(t.a * points[i * 2] + t.c * points[i * 2 + 1] + t.e,
          t.b * points[i * 2] + t.d * points[i * 2 + 1] + t.f, half, argb);
    }
    _endRun(closed: closed, half: half, argb: argb);
  }

  /// A dot the width of the stroke.
  ///
  /// The reference draws it as a horizontal segment of the stroke's own
  /// width, which is a square of it (`vertices_draw_sink.dart`, `point`);
  /// here it is [kKindPoint] instead, because that `± half` is a **device**
  /// quantity and this record holds collection space. See [kKindPoint]'s doc.
  @override
  void point(double x, double y, ResolvedStyle style) {
    final t = _residual;
    _reserve(_instances + 1);
    writePoint(_buffer, _instances,
        x: t.a * x + t.c * y + t.e,
        y: t.b * x + t.d * y + t.f,
        halfWidth: _halfWidthFor(style.lineweightHundredths),
        argb: _coveredArgb(style.argb, style.lineweightHundredths));
    _instances++;
  }

  /// The chord error a flattened arc is allowed, in device pixels. The
  /// reference's own value, copied for the same reason
  /// [kMinStrokeDevicePixels] is: two independent implementations that agree
  /// are a differential test; one shared field is not.
  static const double kFlattenTolerance = 0.25;

  /// The chord ceiling, likewise copied.
  static const int kMaxFlattenSegments = 512;

  @override
  void circle(double cx, double cy, double r, ResolvedStyle style) =>
      _flatten(cx, cy, r, 0, 2 * math.pi, style, closed: true);

  @override
  void arc(double cx, double cy, double r, double start, double sweep,
          ResolvedStyle style) =>
      _flatten(cx, cy, r, start, sweep, style, closed: false);

  /// Walks a circular arc in the residual's **local** space, emitting a chord
  /// per step.
  ///
  /// Local space, not collection space, on purpose: the residual may be
  /// non-uniform, and the arc that `Canvas` would draw under it is an
  /// ellipse. Flattening here and transforming each point reproduces that
  /// ellipse; flattening a collection-space circle would not. Only the
  /// *count* is a scale decision, because the chord error the viewer sees is
  /// a pixel quantity.
  ///
  /// **This is the op that turns on the general-affine residual.**
  /// `draft_painter.dart:568` pushes `camera ∘ placement` here, where a
  /// polyline gets only a translation — the path Plan A's transposition
  /// test was written to guard and no Plan A fixture could reach.
  void _flatten(double cx, double cy, double r, double start, double sweep,
      ResolvedStyle style,
      {required bool closed}) {
    if (r <= 0 || sweep == 0) return;
    final t = _residual;
    final deviceRadius = r * t.scaleMagnitude;
    if (deviceRadius <= 0) return;

    final steps = _flattenSteps(deviceRadius, sweep.abs());
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

  int _flattenSteps(double deviceRadius, double theta) {
    final ideal =
        (theta * math.sqrt(deviceRadius / (8 * kFlattenTolerance))).ceil();
    return ideal.clamp(1, kMaxFlattenSegments);
  }

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
