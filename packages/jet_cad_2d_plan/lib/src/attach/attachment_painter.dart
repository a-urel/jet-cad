// Spec P3 "Drawing" (Task 14): the plan library draws every kit's
// attachment marker alike: the nearest glyph at the marker's screen point
// (today's attached marker, symbol_place_tool.dart:503-522).
import 'dart:ui' show Canvas, Offset, Paint;

import 'package:jet_cad_2d/jet_cad_2d.dart' show SnapKind;
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ViewportTransform, drawSnapMarker;
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// Draws the attachment marker at world [marker] with [paint]. Allocates
/// only the screen offset.
void paintAttachmentMarker(
    Canvas canvas, ViewportTransform camera, Vector2 marker, Paint paint) {
  final m = camera.worldToScreenMatrix;
  final at = Offset(m.a * marker.x + m.c * marker.y + m.e,
      m.b * marker.x + m.d * marker.y + m.f);
  drawSnapMarker(canvas, at, SnapKind.nearest, grid: false, paint: paint);
}
