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
  /// (109,068 instances, strokes and joins together — the 59,875 in Plan A's
  /// original version of this note was strokes only, before joins existed;
  /// see `docs/superpowers/notes/2026-08-30-plan-b-results.md`) that is
  /// roughly 5.23 MB copied per call (109,068 × [kFloatsPerInstance] × 4
  /// bytes = 5,235,264 bytes). Read it once per rebuild, into
  /// `ResidentGeometry.create`, and hoist it out of any per-frame path —
  /// Plan F's `paint()` call site included — or it breaks this project's
  /// "the frame path allocates nothing per entity in steady state"
  /// non-negotiable.
  Float32List get data => _buffer.sublist(0, _instances * kFloatsPerInstance);
  int get instanceCount => _instances;

  /// Ops this plan does not draw yet — `text` alone, since Plan D.
  ///
  /// Counted rather than ignored so a corpus that needs Plan E is visible as
  /// a number instead of as a missing picture.
  ///
  /// `circle` and `arc` stopped counting here in Plan B's Task 5; `point` in
  /// its Task 6; `fillPolygon` and `fillCircle` in Plan D's Tasks 2 and 3.
  int get skippedOps => _skipped;

  /// **Diagnostic only — read by nobody in this class and never changes what
  /// is written.** Ruling B4 keeps the bevel/miter/collinear decision in the
  /// shader, in device pixels, on purpose: a collector-side test would run in
  /// `double`, in collection space, against a reference that decides in
  /// `float32`, in device space, and the two would disagree on exactly the
  /// corners that are nearly straight. This counts, in collection-space
  /// `double` arithmetic, how many of the joins this collector wrote carry a
  /// zero (or reversed) cross product between their incoming and outgoing
  /// arms — the same predicate the shader's own degenerate branch uses
  /// (`cad_stroke.vert`'s `cross_z == 0.0 || in_len == 0.0 || out_len ==
  /// 0.0`, transcribed at `test/support/instance_expander.dart`) — so Task
  /// 11 can report the buffer's collinear cost against the 8 MB budget
  /// without moving the decision itself. `debug`-prefixed for exactly that
  /// reason: nothing downstream reads it.
  int get debugCollinearJoins => _debugCollinearJoins;
  int _debugCollinearJoins = 0;

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

  /// Writes this primitive's instances: one, if it is solid; one per drawn
  /// pattern element, if it is dashed; exactly one, if it is dashed with a
  /// pattern that draws nothing.
  ///
  /// **The first instance carries a negative period.** That marks it as the
  /// primitive's collapse representative -- the one the shader draws solid
  /// when the live period falls under `kDashCollapsePx`, while its
  /// siblings collapse to a degenerate vertex. Without the mark, all of them
  /// draw solid and a collapsed translucent line is drawn D times over
  /// itself.
  void _emit(
      double x0, double y0, double x1, double y1, double half, int argb) {
    // The reference's own test (`vertices_draw_sink.dart`, `_emitSegment`): a
    // zero-length segment has no direction to take a normal from. Matching
    // the formula, not the intention -- see `_runTo`.
    final dx = x1 - x0, dy = y1 - y0;
    if (math.sqrt(dx * dx + dy * dy) == 0) return;
    final period = _pendingSegPeriod;
    if (period == 0.0) {
      _reserve(_instances + 1);
      writeStroke(_buffer, _instances,
          x0: x0, y0: y0, x1: x1, y1: y1, halfWidth: half, argb: argb);
      _instances++;
      return;
    }
    final n = _dashFracStart.isEmpty ? 1 : _dashFracStart.length;
    _reserve(_instances + n);
    for (var k = 0; k < n; k++) {
      writeStroke(_buffer, _instances,
          x0: x0,
          y0: y0,
          x1: x1,
          y1: y1,
          halfWidth: half,
          argb: argb,
          dashPeriod: k == 0 ? -period : period,
          dashPhase: _pendingSegPhase,
          dashFracStart: k < _dashFracStart.length ? _dashFracStart[k] : 0.0,
          dashFracEnd: k < _dashFracEnd.length ? _dashFracEnd[k] : 0.0);
      _instances++;
    }
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

    if (_runHasDirection && !_suppressJoins) {
      _emitJoin(_runPrevX, _runPrevY, _runBackX, _runBackY, x, y, half, argb);
    } else if (!_runHasDirection) {
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
  ///
  /// [suppressSeam] suppresses only the closing corner's own join — the seam
  /// — without touching the join `_runTo` writes for the closing *chord*
  /// itself (the interior join at the vertex the closing chord starts from).
  /// It is a separate parameter from [_suppressJoins] on purpose: a dashed
  /// arc suppresses the seam alone (Ruling C3's interior joins stay live),
  /// while a dashed polyline suppresses every join via [_suppressJoins],
  /// including this one — setting [_suppressJoins] before this call, as a
  /// dashed arc's first draft did, silently drops that interior join too,
  /// since the `_runTo` call two lines below honours [_suppressJoins] as
  /// well. `suppressSeam` reaches only the explicit call below.
  void _endRun(
      {required bool closed,
      required double half,
      required int argb,
      bool suppressSeam = false}) {
    if (!closed || !_runHasDirection) return;
    _runTo(_runFirstX, _runFirstY, half, argb);
    // Guarded for the same reason the reference guards it: today's callers
    // cannot reach here with one segment, but that is a fact about the
    // callers, not a promise the join arithmetic makes.
    if (_runSegments >= 2 && !_suppressJoins && !suppressSeam) {
      _emitJoin(_runFirstX, _runFirstY, _runBackX, _runBackY, _runSecondX,
          _runSecondY, half, argb);
    }
  }

  void _emitJoin(double vx, double vy, double prevX, double prevY, double nextX,
      double nextY, double half, int argb) {
    // No collinearity test decides anything here, deliberately: the
    // bevel/miter/collinear decision belongs to the shader, in device
    // pixels, where the reference makes it too. See this plan's Ruling B4.
    // `debugCollinearJoins` below is instrumentation, not a decision — it
    // reads the same predicate back afterwards, in a different space, purely
    // to report a count.
    final d0x = vx - prevX, d0y = vy - prevY;
    final d1x = nextX - vx, d1y = nextY - vy;
    final crossZ = d0x * d1y - d0y * d1x;
    if (crossZ == 0.0 ||
        (d0x == 0.0 && d0y == 0.0) ||
        (d1x == 0.0 && d1y == 0.0)) {
      // Counted once per corner, not once per dashed element -- otherwise
      // this diagnostic reports D times the corners the drawing has.
      _debugCollinearJoins++;
    }
    final period = _pendingJoinPeriod;
    if (period == 0.0) {
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
      return;
    }
    final n = _dashFracStart.isEmpty ? 1 : _dashFracStart.length;
    _reserve(_instances + n);
    for (var k = 0; k < n; k++) {
      writeJoin(_buffer, _instances,
          vx: vx,
          vy: vy,
          prevX: prevX,
          prevY: prevY,
          nextX: nextX,
          nextY: nextY,
          halfWidth: half,
          argb: argb,
          dashPeriod: k == 0 ? -period : period,
          dashPhase: _pendingJoinPhase,
          dashFracStart: k < _dashFracStart.length ? _dashFracStart[k] : 0.0,
          dashFracEnd: k < _dashFracEnd.length ? _dashFracEnd[k] : 0.0);
      _instances++;
    }
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

  // --- the dash bracket ---------------------------------------------------
  //
  // Set by `beginDash`, cleared by `endDash`. Kept as fields rather than
  // threaded through `_runTo` for the same reason `DraftPainter` keeps
  // `_spanSink` and `_spanStyle` as fields: the alternative is a closure or a
  // widened signature on the hot path, and this class's contract is that a
  // rebuild allocates per document, not per primitive.
  bool _dashActive = false;
  double _dashPeriodLocal = 0;

  /// The drawn elements' extents, as fractions of the cycle. Two parallel
  /// lists rather than a list of pairs: a pair object per element per
  /// `beginDash` is an allocation per dashed entity per rebuild.
  final List<double> _dashFracStart = <double>[];
  final List<double> _dashFracEnd = <double>[];

  /// Per-primitive values, set immediately before the `_emit` / `_emitJoin`
  /// call that consumes them. Same idiom, same reason.
  double _pendingSegPeriod = 0, _pendingSegPhase = 0;
  double _pendingJoinPeriod = 0, _pendingJoinPhase = 0;
  bool _suppressJoins = false;

  @override
  bool get shadesDashes => true;

  @override
  void beginDash(DashPattern pattern, double patternToLocal) {
    _dashFracStart.clear();
    _dashFracEnd.clear();
    // The cycle is summed from the array, never read from
    // `pattern.totalLength` -- `dasher.dart` says why in as many words, and
    // this class must agree with the dasher about where a cycle ends or the
    // two draw different pictures from the same pattern.
    var cycle = 0.0;
    for (final d in pattern.dashes) {
      cycle += d.abs();
    }
    if (!cycle.isFinite || cycle <= 0.0 || !patternToLocal.isFinite) {
      // `dashPolyline` returns false here and the caller draws solid. This is
      // the same decision, reached by the same test.
      _dashActive = false;
      return;
    }
    _dashPeriodLocal = cycle * patternToLocal;
    var at = 0.0;
    for (final d in pattern.dashes) {
      // `beginDash` uses `|d|` for the extents where `dasher.dart` substitutes
      // `1e-9` for a zero-length element (`dasher.dart:169`). The divergence
      // is `1e-9` pattern units per zero element, which against a period the
      // collapse rule floors at 3 device pixels is at most `3 x 10^-10` px --
      // below any representable difference.
      final w = d.abs();
      if (d >= 0) {
        _dashFracStart.add(at / cycle);
        _dashFracEnd.add((at + w) / cycle);
      }
      at += w;
    }
    _dashActive = true;
  }

  @override
  void endDash() {
    _dashActive = false;
    _suppressJoins = false;
    _pendingSegPeriod = 0;
    _pendingSegPhase = 0;
    _pendingJoinPeriod = 0;
    _pendingJoinPhase = 0;
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
    _suppressJoins = _dashActive;
    var px = t.a * points[0] + t.c * points[1] + t.e;
    var py = t.b * points[0] + t.d * points[1] + t.f;
    _beginRun(px, py);
    for (var i = 1; i < count; i++) {
      final lx = points[i * 2], ly = points[i * 2 + 1];
      final nx = t.a * lx + t.c * ly + t.e;
      final ny = t.b * lx + t.d * ly + t.f;
      if (_dashActive) {
        // The phase restarts at every vertex (`dasher.dart:94-96`), so a
        // polyline's segments all carry phase 0. The period is scaled by
        // THIS segment's own local-to-collection length ratio rather than by
        // the residual's scale magnitude: under an anisotropic residual the
        // two disagree, and only the first one is right for this segment.
        final llx = lx - points[i * 2 - 2], lly = ly - points[i * 2 - 1];
        final localLen = math.sqrt(llx * llx + lly * lly);
        final cdx = nx - px, cdy = ny - py;
        final collectionLen = math.sqrt(cdx * cdx + cdy * cdy);
        _pendingSegPeriod =
            localLen > 0 ? _dashPeriodLocal * (collectionLen / localLen) : 0.0;
        _pendingSegPhase = 0.0;
      }
      _runTo(nx, ny, half, argb);
      px = nx;
      py = ny;
    }
    _endRun(closed: closed, half: half, argb: argb);
    _suppressJoins = false;
    _pendingSegPeriod = 0;
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

    // Arcs keep their interior joins -- Ruling B4/C3 leaves the
    // bevel/miter/collinear decision to the shader regardless of the
    // linetype, and unlike a dashed polyline (which suppresses every join
    // via `_suppressJoins`), a dashed arc suppresses only the seam. So
    // `_suppressJoins` itself stays false for the whole walk below --
    // `_endRun`'s `suppressSeam` parameter is what turns off the seam alone.
    _suppressJoins = false;
    final arcStep = r * step.abs(); // local arc length per chord

    var lx = cx + r * math.cos(start);
    var ly = cy + r * math.sin(start);
    var px = t.a * lx + t.c * ly + t.e;
    var py = t.b * lx + t.d * ly + t.f;
    _beginRun(px, py);
    // A closed sweep stops one sample short: its last chord is the segment
    // `_endRun` draws back to the first point, so closing here would draw
    // that chord twice and leave the seam a duplicated point instead of a
    // join.
    final last = closed ? steps - 1 : steps;
    for (var i = 1; i <= last; i++) {
      final angle = start + step * i;
      lx = cx + r * math.cos(angle);
      ly = cy + r * math.sin(angle);
      final nx = t.a * lx + t.c * ly + t.e;
      final ny = t.b * lx + t.d * ly + t.f;
      if (_dashActive && arcStep > 0) {
        final cdx = nx - px, cdy = ny - py;
        // The pattern is measured along the ARC and drawn along the CHORD.
        // Dividing the chord's collection length by the chord's LOCAL ARC
        // length makes the two agree exactly at every chord endpoint and
        // leaves the disagreement inside one chord, bounded by (arc - chord)
        // -- under a tenth of a pixel at this flattener's 0.25 px sagitta.
        // Ruling C4 records this rather than removing it: removing it means
        // re-chording per span, which is chording at one camera, which is
        // what this plan exists to stop doing.
        final factor = math.sqrt(cdx * cdx + cdy * cdy) / arcStep;
        _pendingSegPeriod = _dashPeriodLocal * factor;
        // The reduction happens before the scaling -- parenthesised
        // explicitly rather than relying on `%` and `*` sharing precedence
        // and associating left to right, because a precedence argument left
        // only in a comment is a defect waiting for a reader who does not
        // check.
        _pendingSegPhase = ((arcStep * (i - 1)) % _dashPeriodLocal) * factor;
        // The join at the vertex this step arrives from sits at the START of
        // this chord, so it takes this chord's phase and this chord's
        // factor.
        _pendingJoinPeriod = _pendingSegPeriod;
        _pendingJoinPhase = _pendingSegPhase;
      }
      _runTo(nx, ny, half, argb);
      px = nx;
      py = ny;
    }
    // The loop above never assigns the pending values for the CLOSING
    // chord -- it stops at `last = steps - 1`, so `_endRun`'s own `_runTo`
    // call below (the segment back to the first point) would otherwise
    // draw with whatever phase the loop's last iteration left behind: the
    // phase belonging to chord `steps - 1`, not chord `steps`. Set them
    // here, from the same phase law the loop uses, evaluated for the
    // closing chord itself -- point `steps - 1` (left in `px`, `py` by the
    // loop) to point `0` (`_runFirstX`, `_runFirstY`).
    if (_dashActive && closed && arcStep > 0) {
      final cdx = _runFirstX - px, cdy = _runFirstY - py;
      final factor = math.sqrt(cdx * cdx + cdy * cdy) / arcStep;
      _pendingSegPeriod = _dashPeriodLocal * factor;
      // Same explicit parenthesisation as the loop, same reason.
      _pendingSegPhase = ((arcStep * (steps - 1)) % _dashPeriodLocal) * factor;
      _pendingJoinPeriod = _pendingSegPeriod;
      _pendingJoinPhase = _pendingSegPhase;
    }
    // Ruling C3, third clause: the reference emits every dash span as its
    // own `arc()` op, so a dashed circle is a sequence of OPEN runs and no
    // closed run -- and therefore no seam join -- exists anywhere in it.
    // `suppressSeam` reproduces that without touching the interior join
    // `_endRun`'s own `_runTo` call writes for the closing chord.
    _endRun(closed: closed, half: half, argb: argb, suppressSeam: _dashActive);
    _pendingSegPeriod = 0;
    _pendingSegPhase = 0;
    _pendingJoinPeriod = 0;
    _pendingJoinPhase = 0;
  }

  int _flattenSteps(double deviceRadius, double theta) {
    final ideal =
        (theta * math.sqrt(deviceRadius / (8 * kFlattenTolerance))).ceil();
    return ideal.clamp(1, kMaxFlattenSegments);
  }

  /// One instance per triangle, in the triangulation's own order.
  ///
  /// **Read, never computed** — the triangulation was materialised by the
  /// command, the codec or undo, and `DraftPainter._drawFill` passes it
  /// through. This transcribes `VerticesDrawSink.fillPolygon`, including
  /// that `triangles` triple-indexes into `points`' *point* numbering, so
  /// each index is doubled to reach a coordinate pair.
  ///
  /// **`style.argb` directly, NOT `_coveredArgb`** (Ruling D3): a fill has no
  /// width to fade, and a fill entity's `ResolvedStyle` still carries a
  /// lineweight because the column is shared with strokes.
  ///
  /// **No degenerate-triangle test** (Ruling D6): the reference's
  /// `_emitTriangle` has none, and adding one here would make the two arms'
  /// instance lists differ on a triangulation that contains one.
  @override
  void fillPolygon(
      Float64List points, int count, Int32List triangles, ResolvedStyle style) {
    if (triangles.isEmpty) return;
    final t = _residual;
    final argb = style.argb;
    _reserve(_instances + triangles.length ~/ 3);
    for (var i = 0; i + 2 < triangles.length; i += 3) {
      final a = triangles[i], b = triangles[i + 1], c = triangles[i + 2];
      final ax = points[a * 2], ay = points[a * 2 + 1];
      final bx = points[b * 2], by = points[b * 2 + 1];
      final cx = points[c * 2], cy = points[c * 2 + 1];
      writeFill(_buffer, _instances,
          x0: t.a * ax + t.c * ay + t.e,
          y0: t.b * ax + t.d * ay + t.f,
          x1: t.a * bx + t.c * by + t.e,
          y1: t.b * bx + t.d * by + t.f,
          x2: t.a * cx + t.c * cy + t.e,
          y2: t.b * cx + t.d * cy + t.f,
          argb: argb);
      _instances++;
    }
  }

  @override
  void fillCircle(double cx, double cy, double r, ResolvedStyle style) =>
      _skipped++;

  @override
  void text(String text, Handle style, ResolvedStyle resolved) => _skipped++;
}
