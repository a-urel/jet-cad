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
  CanvasDrawSink(this.canvas, {required this.pixelsPerPaperMm});

  final Canvas canvas;
  final double pixelsPerPaperMm;

  // One paint and one path for the whole frame. Both are rewritten per op;
  // neither is handed to a caller that could retain it.
  final Paint _paint = Paint()..style = PaintingStyle.stroke;
  final Path _path = Path();
  final Float32List _point = Float32List(2);
  final Float64List _matrix = Float64List(16)..[10] = 1.0;

  double _residualScale = 1.0;

  @override
  void beginResidual(Transform2 residual, {Handle debugHandle = Handle.none}) {
    canvas.save();
    // Matrix4 storage is column-major: columns 0 and 1 carry the linear part,
    // column 3 the translation. Row-major here would transpose every residual.
    _matrix[0] = residual.a;
    _matrix[1] = residual.b;
    _matrix[4] = residual.c;
    _matrix[5] = residual.d;
    _matrix[12] = residual.e;
    _matrix[13] = residual.f;
    _matrix[15] = 1.0;
    canvas.transform(_matrix);
    _residualScale = residual.scaleMagnitude;
  }

  @override
  void endResidual() {
    canvas.restore();
    _residualScale = 1.0;
  }

  @override
  void point(double x, double y, ResolvedStyle style) {
    _point[0] = x;
    _point[1] = y;
    canvas.drawRawPoints(PointMode.points, _point, _paintFor(style));
  }

  @override
  void polyline(Float64List points, int count, ResolvedStyle style,
      {required bool closed}) {
    if (count <= 0) return;
    _path.reset();
    _path.moveTo(points[0], points[1]);
    for (var i = 1; i < count; i++) {
      _path.lineTo(points[i * 2], points[i * 2 + 1]);
    }
    if (closed) _path.close();
    canvas.drawPath(_path, _paintFor(style));
  }

  @override
  void circle(double cx, double cy, double r, ResolvedStyle style) =>
      canvas.drawCircle(Offset(cx, cy), r, _paintFor(style));

  @override
  void arc(double cx, double cy, double r, double start, double sweep,
          ResolvedStyle style) =>
      canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), start,
          sweep, false, _paintFor(style));

  Paint _paintFor(ResolvedStyle style) {
    _paint
      ..color = Color(style.argb)
      ..strokeWidth = _strokeWidth(style);
    return _paint;
  }

  double _strokeWidth(ResolvedStyle style) {
    final devicePx = style.lineweightHundredths / 100.0 * pixelsPerPaperMm;
    final w = _residualScale == 0 ? devicePx : devicePx / _residualScale;
    // 0 means "hairline" to Skia — one device pixel regardless of transform,
    // which is the right floor for a lineweight that has scaled away.
    return w.isFinite && w > 0 ? w : 0.0;
  }
}
