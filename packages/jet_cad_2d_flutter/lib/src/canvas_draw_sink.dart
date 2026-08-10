import 'dart:typed_data';
import 'dart:ui';

import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'draw_sink.dart';

/// How [CanvasDrawSink] turns the painter's primitives into `Canvas` calls.
///
/// These are **different designs, not different tunings**: they differ in how
/// much draw order survives, which is a contract and not a setting. Plan 3b's
/// spike measures them and ships one.
enum BatchMode {
  /// One `Canvas` call per primitive, one `save`/`transform`/`restore` per
  /// residual. Plan 3a's behaviour, kept as the reference the goldens compare
  /// the batched modes against.
  off,

  /// One open bucket: a `Path` and the paint key it holds. A primitive whose
  /// key differs flushes it and opens a new one, so **draw order is preserved
  /// exactly** and batching is limited to runs of one paint in walk order.
  openBucket,

  /// A `Path` per paint key, held until the end of the frame. Every primitive
  /// of a key merges across the whole frame, so this is the lifecycle that can
  /// actually collapse the op count — and the one that loses draw order
  /// between keys. A curve flushes **every** bucket first, so it lands in
  /// order relative to everything drawn before it.
  bucketMap,

  /// [bucketMap], plus curves baked into their bucket's path through
  /// `Path.addPath(matrix4:)`. Nothing but a translucent style or the end of
  /// the frame flushes, so this is the widest ordering contract in the enum.
  ///
  /// It is also the only mode that is *more* correct than [off] for an
  /// anisotropically placed curve: baking the matrix means the stroke is
  /// applied in screen space, so the ellipse carries a uniform paper-space
  /// width. That is what `ResolvedStyle.lineweightHundredths` says a lineweight
  /// is — "paper-space width in 1/100 mm, **not** a world quantity".
  bucketMapBakedCurves,
}

/// Writes to `dart:ui`.
///
/// Stroke width is the one place paper space meets device space:
/// `lineweightHundredths` is 1/100 mm on paper and must not grow with zoom, so
/// it is converted to pixels and then divided by the residual's representative
/// scale — because `Paint.strokeWidth` is measured in the *current* canvas
/// units, which the residual has already scaled. A batched primitive arrives
/// under a translation-only residual, where that division is by one.
class CanvasDrawSink implements DrawSink {
  CanvasDrawSink({
    Canvas? canvas,
    required this.pixelsPerPaperMm,
    this.mode = BatchMode.openBucket,
  }) {
    if (canvas != null) this.canvas = canvas;
  }

  /// Rebound each frame rather than fixed at construction.
  ///
  /// The `Paint`, the `Path` and the two typed lists below are the whole
  /// reason this is an object: they are allocated once and rewritten per op.
  /// A sink built per paint would throw that away and put four allocations
  /// back on the frame path. The `Canvas` is the only part that genuinely
  /// changes from one frame to the next, so it is the only part that moves.
  late Canvas canvas;

  final double pixelsPerPaperMm;
  final BatchMode mode;

  // One paint and two paths for the whole frame. Both paths are reused in
  // place; neither is handed to a caller that could retain it.
  final Paint _paint = Paint()..style = PaintingStyle.stroke;
  final Path _scratch = Path();
  final Path _bucket = Path();
  final Float32List _point = Float32List(2);
  final Float64List _matrix = Float64List(16)..[10] = 1.0;

  Transform2 _residual = Transform2.identity();
  double _residualScale = 1.0;
  bool _transformPushed = false;

  // The open bucket: whether it holds anything, and the paint key it holds.
  bool _bucketOpen = false;
  int _bucketArgb = 0;
  int _bucketLineweight = 0;

  /// Open buckets, keyed by colour and then by lineweight.
  ///
  /// **Two levels, not one packed integer**, and that is a correction rather
  /// than a preference. A packed key — `argb * 4096 + lineweightHundredths` —
  /// is invertible only while the lineweight stays inside `[0, 4096)`, and
  /// nothing guarantees that. `DocumentStyleResolver` passes a lineweight
  /// through unclamped (`_ => lw`), its source column is an `Int16List`, and a
  /// `LayerRecord.lineweight` is a plain `int`. A lineweight of 5000 packs to
  /// the same key as a different colour with a lineweight of 904, and the
  /// flush then paints one of them in the other's colour — reachable through
  /// `AddEntityCommand`, no malformed file required. Nesting **removes** the
  /// domain assumption instead of restating it with a bigger number.
  ///
  /// Neither level is keyed by a `(int, int)` record: a record is an object,
  /// so building one per primitive would be an allocation per primitive per
  /// frame.
  ///
  /// Both levels preserve insertion order, which is the order buckets are
  /// flushed in — the only draw order the mapped modes keep. The inner maps
  /// are **kept across frames** and only emptied, so a steady-state frame
  /// allocates no map at all.
  final Map<int, Map<int, Path>> _buckets = <int, Map<int, Path>>{};

  /// Paths returned to the pool by [flush], so a frame allocates at most one
  /// `Path` per distinct paint ever seen rather than one per frame.
  final List<Path> _pool = <Path>[];

  bool get _mapped =>
      mode == BatchMode.bucketMap || mode == BatchMode.bucketMapBakedCurves;

  int _canvasCalls = 0;

  /// Real `Canvas` draw calls since [resetCounters].
  ///
  /// Deliberately separate from `NullDrawSink.opCount`, which counts painter
  /// calls and keeps Plan 3a's R1 and R3 rows comparable. The gap between the
  /// two numbers is what this plan exists to open.
  int get canvasCallCount => _canvasCalls;

  void resetCounters() => _canvasCalls = 0;

  /// Draws whatever is open. **Must be called at the end of every frame.**
  ///
  /// Without it the last bucket of the frame is silently dropped — geometry
  /// that was accepted and never drawn, which no assertion inside the walk can
  /// see. Idempotent, so a caller that flushes twice pays nothing.
  void flush() {
    if (_bucketOpen) {
      _bucketOpen = false;
      _paint
        ..color = Color(_bucketArgb)
        ..strokeWidth = _widthFor(_bucketLineweight, 1.0);
      canvas.drawPath(_bucket, _paint);
      _canvasCalls++;
      _bucket.reset();
    }
    // The outer map keeps its (now empty) inner maps rather than being
    // cleared, so a steady-state frame allocates no map. Iterating a handful
    // of empty inner maps costs nothing next to a draw call.
    for (final byLineweight in _buckets.entries) {
      for (final entry in byLineweight.value.entries) {
        _paint
          ..color = Color(byLineweight.key)
          ..strokeWidth = _widthFor(entry.key, 1.0);
        canvas.drawPath(entry.value, _paint);
        _canvasCalls++;
        entry.value.reset();
        _pool.add(entry.value);
      }
      byLineweight.value.clear();
    }
  }

  /// Whether [style] may share a path with others of its paint.
  ///
  /// Below full alpha it may not: two overlapping strokes in one path are
  /// unioned, and drawn separately they are blended twice. With opaque paint
  /// the two agree; below it they do not, and the separate draw is the correct
  /// one. `ResolvedStyle` has no transparency field — an entity's transparency
  /// is folded into `argb` at resolution time, where alpha is `255 -
  /// transparency`.
  static bool _opaque(ResolvedStyle style) => (style.argb >>> 24) == 0xFF;

  /// Whether the residual is a pure translation, which is what the painter
  /// pushes for every point, line and polyline in a frame.
  bool get _translationOnly =>
      _residual.a == 1.0 &&
      _residual.b == 0.0 &&
      _residual.c == 0.0 &&
      _residual.d == 1.0;

  @override
  void beginResidual(Transform2 residual, {Handle debugHandle = Handle.none}) {
    _residual = residual;
    _residualScale = residual.scaleMagnitude;
    _transformPushed = false;
  }

  /// Pushes the residual onto the `Canvas`, for the primitives that cannot be
  /// batched. Deferred to here rather than done in [beginResidual] because a
  /// batched primitive must not disturb the canvas state at all.
  void _pushTransform() {
    if (_transformPushed) return;
    canvas.save();
    // Matrix4 storage is column-major: columns 0 and 1 carry the linear part,
    // column 3 the translation. Row-major here would transpose every residual.
    canvas.transform(_matrix4OfResidual());
    _transformPushed = true;
  }

  @override
  void endResidual() {
    if (_transformPushed) {
      canvas.restore();
      _transformPushed = false;
    }
    _residual = Transform2.identity();
    _residualScale = 1.0;
  }

  /// The path [style]'s geometry belongs in, or null when it must be drawn on
  /// its own.
  ///
  /// Flushing here is what keeps the contract honest: under [BatchMode.off],
  /// below full alpha, or under a residual that is not a pure translation,
  /// everything open is drawn first so the primitive that follows lands after
  /// it rather than under it.
  Path? _bucketFor(ResolvedStyle style, {required bool batchable}) {
    if (mode == BatchMode.off || !_opaque(style) || !batchable) {
      flush();
      return null;
    }
    if (_mapped) {
      // Not putIfAbsent, at either level: its `ifAbsent` argument is a
      // closure, allocated on every call whether or not the key is missing.
      var byLineweight = _buckets[style.argb];
      if (byLineweight == null) {
        byLineweight = <int, Path>{};
        _buckets[style.argb] = byLineweight;
      }
      final existing = byLineweight[style.lineweightHundredths];
      if (existing != null) return existing;
      final fresh = _pool.isEmpty ? Path() : _pool.removeLast();
      byLineweight[style.lineweightHundredths] = fresh;
      return fresh;
    }
    if (_bucketOpen &&
        (_bucketArgb != style.argb ||
            _bucketLineweight != style.lineweightHundredths)) {
      flush();
    }
    _bucketArgb = style.argb;
    _bucketLineweight = style.lineweightHundredths;
    _bucketOpen = true;
    return _bucket;
  }

  @override
  void point(double x, double y, ResolvedStyle style) {
    final bucket = _bucketFor(style, batchable: _translationOnly);
    if (bucket != null) {
      // A zero-length subpath strokes as a cap-shaped dot, which is what a
      // DXF POINT is. moveTo alone would contribute nothing.
      bucket
        ..moveTo(x + _residual.e, y + _residual.f)
        ..lineTo(x + _residual.e, y + _residual.f);
      return;
    }
    _pushTransform();
    _point[0] = x;
    _point[1] = y;
    canvas.drawRawPoints(PointMode.points, _point, _paintFor(style));
    _canvasCalls++;
  }

  @override
  void polyline(Float64List points, int count, ResolvedStyle style,
      {required bool closed}) {
    if (count <= 0) return;
    final bucket = _bucketFor(style, batchable: _translationOnly);
    if (bucket != null) {
      final dx = _residual.e;
      final dy = _residual.f;
      bucket.moveTo(points[0] + dx, points[1] + dy);
      for (var i = 1; i < count; i++) {
        bucket.lineTo(points[i * 2] + dx, points[i * 2 + 1] + dy);
      }
      if (closed) bucket.close();
      return;
    }
    _pushTransform();
    _scratch.reset();
    _scratch.moveTo(points[0], points[1]);
    for (var i = 1; i < count; i++) {
      _scratch.lineTo(points[i * 2], points[i * 2 + 1]);
    }
    if (closed) _scratch.close();
    canvas.drawPath(_scratch, _paintFor(style));
    _canvasCalls++;
  }

  @override
  void circle(double cx, double cy, double r, ResolvedStyle style) {
    final bucket = _bucketFor(style,
        batchable: mode == BatchMode.bucketMapBakedCurves && _opaque(style));
    if (bucket != null) {
      _scratch.reset();
      _scratch.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
      bucket.addPath(_scratch, Offset.zero, matrix4: _matrix4OfResidual());
      return;
    }
    _pushTransform();
    canvas.drawCircle(Offset(cx, cy), r, _paintFor(style));
    _canvasCalls++;
  }

  @override
  void arc(double cx, double cy, double r, double start, double sweep,
      ResolvedStyle style) {
    final bucket = _bucketFor(style,
        batchable: mode == BatchMode.bucketMapBakedCurves && _opaque(style));
    if (bucket != null) {
      _scratch.reset();
      _scratch.addArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: r), start, sweep);
      bucket.addPath(_scratch, Offset.zero, matrix4: _matrix4OfResidual());
      return;
    }
    _pushTransform();
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), start,
        sweep, false, _paintFor(style));
    _canvasCalls++;
  }

  /// The current residual as the column-major `Float64List(16)` `addPath` and
  /// `Canvas.transform` both want. Rewritten in place — the list is a field.
  Float64List _matrix4OfResidual() {
    _matrix[0] = _residual.a;
    _matrix[1] = _residual.b;
    _matrix[4] = _residual.c;
    _matrix[5] = _residual.d;
    _matrix[12] = _residual.e;
    _matrix[13] = _residual.f;
    _matrix[15] = 1.0;
    return _matrix;
  }

  Paint _paintFor(ResolvedStyle style) {
    _paint
      ..color = Color(style.argb)
      ..strokeWidth = _widthFor(style.lineweightHundredths, _residualScale);
    return _paint;
  }

  double _widthFor(int lineweightHundredths, double residualScale) {
    final devicePx = lineweightHundredths / 100.0 * pixelsPerPaperMm;
    final w = residualScale == 0 ? devicePx : devicePx / residualScale;
    // 0 means "hairline" to Skia — one device pixel regardless of transform,
    // which is the right floor for a lineweight that has scaled away.
    return w.isFinite && w > 0 ? w : 0.0;
  }
}
