import 'dart:typed_data';
import 'dart:ui';

import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'draw_sink.dart';

/// Writes to `dart:ui`.
///
/// Stroke width is the one place paper space meets device space:
/// `lineweightHundredths` is 1/100 mm on paper and must not grow with zoom, so
/// it is converted to pixels and then divided by the residual's representative
/// scale — because `Paint.strokeWidth` is measured in the *current* canvas
/// units, which the residual has already scaled.
class CanvasDrawSink implements DrawSink {
  CanvasDrawSink({
    Canvas? canvas,
    required this.pixelsPerPaperMm,
    this.lineweightScale = 1.0,
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

  /// Multiplies every stroke's device-pixel width before it reaches `Canvas`.
  ///
  /// **Measurement-only**, for Task 4c's fill-rate experiment (B): it exists
  /// so a run can change the number of shaded pixels while leaving geometry,
  /// draw-call count and the walk byte-identical to every other run. Inert at
  /// its default of 1.0 — nothing here branches on that value, the
  /// multiplication is simply a no-op at it. Not read anywhere in the
  /// painter or the style resolver; the point of the experiment is that
  /// only the sink's idea of width changes.
  final double lineweightScale;

  // One paint and one scratch path for the whole frame, reused in place;
  // neither is handed to a caller that could retain it.
  final Paint _paint = Paint()..style = PaintingStyle.stroke;
  final Path _scratch = Path();
  final Float32List _point = Float32List(2);
  final Float64List _matrix = Float64List(16)..[10] = 1.0;

  Transform2 _residual = Transform2.identity();
  double _residualScale = 1.0;
  bool _transformPushed = false;

  int _canvasCalls = 0;

  /// Real `Canvas` draw calls since [resetCounters].
  ///
  /// Deliberately separate from `NullDrawSink.opCount`, which counts painter
  /// calls and keeps Plan 3a's R1 and R3 rows comparable. The gap between the
  /// two numbers is a diagnostic: how many painter ops become how many real
  /// draw calls, whatever the sink does with them.
  int get canvasCallCount => _canvasCalls;

  void resetCounters() => _canvasCalls = 0;

  @override
  void beginResidual(Transform2 residual, {Handle debugHandle = Handle.none}) {
    _residual = residual;
    _residualScale = residual.scaleMagnitude;
    _transformPushed = false;
  }

  /// Pushes the residual onto the `Canvas`, deferred to the first primitive
  /// drawn under it rather than done in [beginResidual].
  ///
  /// A residual under which nothing is drawn — the common case for a residual
  /// whose subtree culls away entirely — never calls this, so [endResidual]
  /// has nothing to restore and skips the `save`/`restore` pair rather than
  /// paying for one on every empty residual in the walk.
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

  @override
  void point(double x, double y, ResolvedStyle style) {
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
    _pushTransform();
    canvas.drawCircle(Offset(cx, cy), r, _paintFor(style));
    _canvasCalls++;
  }

  @override
  void arc(double cx, double cy, double r, double start, double sweep,
      ResolvedStyle style) {
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
    final devicePx =
        lineweightHundredths / 100.0 * pixelsPerPaperMm * lineweightScale;
    final w = residualScale == 0 ? devicePx : devicePx / residualScale;
    // 0 means "hairline" to Skia — one device pixel regardless of transform,
    // which is the right floor for a lineweight that has scaled away.
    return w.isFinite && w > 0 ? w : 0.0;
  }
}
