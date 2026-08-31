import 'dart:typed_data';
import 'dart:ui';

import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'draw_sink.dart';
import 'flutter_text_measurer.dart';

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
    required this.measurer,
    required this.textStyleOf,
    this.lineweightScale = 1.0,
  }) {
    if (canvas != null) this.canvas = canvas;
  }

  /// Rebound each frame rather than fixed at construction.
  ///
  /// The `Paint`, the `Path` and the typed list below are the whole reason
  /// this is an object: they are allocated once and rewritten per op. A sink
  /// built per paint would throw that away and put allocations back on the
  /// frame path. The `Canvas` is the only part that genuinely changes from
  /// one frame to the next, so it is the only part that moves.
  late Canvas canvas;

  final double pixelsPerPaperMm;

  /// Owns the paragraph cache [text] draws through. One per widget, not one
  /// per sink rebuild, so a prop change that recreates the sink does not
  /// throw away every paragraph already laid out.
  final FlutterTextMeasurer measurer;

  /// Resolves a text entity's style handle to the record [text] needs for
  /// `fontFamily`.
  ///
  /// [DrawSink.text] carries only the [Handle] — the sink has no document to
  /// look tables up in, so the caller that does (`DraftCanvas`, over
  /// `DraftDocument.textStyleOf`) hands over the one accessor rather than the
  /// whole document.
  final TextStyleRecord Function(Handle) textStyleOf;

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
  bool get shadesDashes => false;

  @override
  void beginDash(DashPattern pattern, double patternToLocal) =>
      throw UnsupportedError(
          'CanvasDrawSink consumes dash spans, not dash patterns; '
          'DraftPainter must not open a dash bracket on a sink whose '
          'shadesDashes is false');

  @override
  void endDash() =>
      throw UnsupportedError('CanvasDrawSink does not shade dashes');

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

  /// A square marker, axis-aligned on the screen.
  ///
  /// **Not** `drawRawPoints` under the pushed residual, which is what this used
  /// to be: that draws the cap in local space, so a rotated or sheared instance
  /// turned the marker with it. A marker marks a position and its orientation
  /// carries nothing, so it is drawn in screen space — which is also what
  /// `VerticesDrawSink` does, and the two backends have to agree.
  @override
  void point(double x, double y, ResolvedStyle style) {
    // Screen space, so the residual is applied here rather than pushed.
    final sx = _residual.a * x + _residual.c * y + _residual.e;
    final sy = _residual.b * x + _residual.d * y + _residual.f;
    final half = _widthFor(style.lineweightHundredths, 1.0) / 2;
    _paint
      ..color = Color(style.argb)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
        Rect.fromLTRB(sx - half, sy - half, sx + half, sy + half), _paint);
    _paint.style = PaintingStyle.stroke;
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

  @override
  void fillPolygon(
      Float64List points, int count, Int32List triangles, ResolvedStyle style) {
    if (count < 3) return;
    _pushTransform();
    _scratch.reset();
    _scratch.moveTo(points[0], points[1]);
    for (var i = 1; i < count; i++) {
      _scratch.lineTo(points[i * 2], points[i * 2 + 1]);
    }
    _scratch.close();
    _paint
      ..color = Color(style.argb)
      ..style = PaintingStyle.fill;
    canvas.drawPath(_scratch, _paint);
    // Restored for the same reason `point` restores it: one Paint is reused
    // for the whole frame, and a stroke drawn after this must not be filled.
    _paint.style = PaintingStyle.stroke;
    _canvasCalls++;
  }

  @override
  void fillCircle(double cx, double cy, double r, ResolvedStyle style) {
    _pushTransform();
    _paint
      ..color = Color(style.argb)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), r, _paint);
    _paint.style = PaintingStyle.stroke;
    _canvasCalls++;
  }

  @override
  void text(String text, Handle style, ResolvedStyle resolved) {
    _pushTransform();
    final paragraph =
        measurer.paragraphFor(text, style, textStyleOf(style), resolved.argb);
    // Two coordinate systems meet here, and only one of them is `dart:ui`'s.
    // `drawParagraph` lays glyphs out with y increasing *downward* from the
    // top of the first line; the residual maps *glyph* space — y up, origin
    // on the baseline — because that is the space `textLocalBounds`, and so
    // `entityBounds`, is expressed in, and the camera has already flipped y
    // once on the way there. Reconciling them is a flip about the baseline:
    // lift by the distance from the paragraph's top to it, then negate y.
    //
    // The flip belongs here and not in the painter because it is a fact about
    // `drawParagraph`, not about the document — `reference_walk` composes the
    // same residual by an independent route and must not have to know it, or
    // the two would be sharing exactly the assumption the oracle exists to
    // test.
    canvas.save();
    canvas.translate(0, paragraph.alphabeticBaseline);
    canvas.scale(1, -1);
    canvas.drawParagraph(paragraph, Offset.zero);
    canvas.restore();
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
