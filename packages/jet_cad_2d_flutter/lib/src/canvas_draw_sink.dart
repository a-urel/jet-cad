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
    if (!_bucketOpen) return;
    _bucketOpen = false;
    _paint
      ..color = Color(_bucketArgb)
      ..strokeWidth = _widthFor(_bucketLineweight, 1.0);
    canvas.drawPath(_bucket, _paint);
    _canvasCalls++;
    _bucket.reset();
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
    _matrix[0] = _residual.a;
    _matrix[1] = _residual.b;
    _matrix[4] = _residual.c;
    _matrix[5] = _residual.d;
    _matrix[12] = _residual.e;
    _matrix[13] = _residual.f;
    _matrix[15] = 1.0;
    canvas.transform(_matrix);
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

  /// Opens or reuses the bucket for [style], flushing first if the key differs.
  ///
  /// Returns false when [style] must not be batched at all.
  bool _bucketFor(ResolvedStyle style) {
    if (mode == BatchMode.off || !_opaque(style) || !_translationOnly) {
      flush();
      return false;
    }
    if (_bucketOpen &&
        (_bucketArgb != style.argb ||
            _bucketLineweight != style.lineweightHundredths)) {
      flush();
    }
    _bucketArgb = style.argb;
    _bucketLineweight = style.lineweightHundredths;
    _bucketOpen = true;
    return true;
  }

  @override
  void point(double x, double y, ResolvedStyle style) {
    if (_bucketFor(style)) {
      // A zero-length subpath strokes as a cap-shaped dot, which is what a
      // DXF POINT is. moveTo alone would contribute nothing.
      _bucket
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
    if (_bucketFor(style)) {
      final dx = _residual.e;
      final dy = _residual.f;
      _bucket.moveTo(points[0] + dx, points[1] + dy);
      for (var i = 1; i < count; i++) {
        _bucket.lineTo(points[i * 2] + dx, points[i * 2 + 1] + dy);
      }
      if (closed) _bucket.close();
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
    flush();
    _pushTransform();
    canvas.drawCircle(Offset(cx, cy), r, _paintFor(style));
    _canvasCalls++;
  }

  @override
  void arc(double cx, double cy, double r, double start, double sweep,
      ResolvedStyle style) {
    flush();
    _pushTransform();
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), start,
        sweep, false, _paintFor(style));
    _canvasCalls++;
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
