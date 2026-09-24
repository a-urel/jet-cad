import 'dart:ui' show Canvas, Offset, Paint, Path, Rect;

import 'package:jet_cad_2d/jet_cad_2d.dart' show SnapKind;

import 'selection_style.dart';

/// Spec D9's marker at [at], in screen space: a fixed, small number of draw
/// calls. [kind] non-null means an object snap won; otherwise [grid] draws
/// the grid's `+`, and nothing is drawn when the raw point won.
void drawSnapMarker(Canvas canvas, Offset at, SnapKind? kind,
    {required bool grid, required Paint paint}) {
  const h = kSnapMarkerPixels / 2;
  if (kind == null) {
    if (!grid) return;
    const g = kGridMarkerPixels / 2;
    canvas.drawLine(at.translate(-g, 0), at.translate(g, 0), paint);
    canvas.drawLine(at.translate(0, -g), at.translate(0, g), paint);
    return;
  }
  switch (kind) {
    case SnapKind.endpoint:
      canvas.drawRect(
          Rect.fromCenter(
              center: at, width: kSnapMarkerPixels, height: kSnapMarkerPixels),
          paint);
    case SnapKind.midpoint:
      // Apex up: screen y grows downward.
      canvas.drawPath(
          Path()
            ..moveTo(at.dx, at.dy - h)
            ..lineTo(at.dx + h, at.dy + h)
            ..lineTo(at.dx - h, at.dy + h)
            ..close(),
          paint);
    case SnapKind.center:
      canvas.drawCircle(at, h, paint);
    case SnapKind.quadrant:
      canvas.drawPath(
          Path()
            ..moveTo(at.dx, at.dy - h)
            ..lineTo(at.dx + h, at.dy)
            ..lineTo(at.dx, at.dy + h)
            ..lineTo(at.dx - h, at.dy)
            ..close(),
          paint);
    case SnapKind.insertion:
      canvas.drawRect(
          Rect.fromCenter(
              center: at, width: kSnapMarkerPixels, height: kSnapMarkerPixels),
          paint);
      canvas.drawLine(at.translate(-h, 0), at.translate(h, 0), paint);
      canvas.drawLine(at.translate(0, -h), at.translate(0, h), paint);
    case SnapKind.intersection:
      canvas.drawLine(at.translate(-h, -h), at.translate(h, h), paint);
      canvas.drawLine(at.translate(-h, h), at.translate(h, -h), paint);
    case SnapKind.nearest:
      // An hourglass: only the Wall tool resolves `nearest` (spec 07 D11).
      canvas.drawLine(at.translate(-h, -h), at.translate(h, -h), paint);
      canvas.drawLine(at.translate(h, -h), at.translate(-h, h), paint);
      canvas.drawLine(at.translate(-h, h), at.translate(h, h), paint);
      canvas.drawLine(at.translate(h, h), at.translate(-h, -h), paint);
    case SnapKind.perpendicular:
    case SnapKind.tangent:
      // In no tool's snap mask: a drag never produces them.
      return;
  }
}
