import 'dart:ui' show Canvas;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../tool.dart';
import 'placement_tool.dart';

/// Spec 05 D7: two opposite corners, world-axis aligned, committed as a
/// closed polyline whose every coordinate is a copy of a corner's.
class RectangleTool extends PlacementTool {
  RectangleTool({super.fill});

  @override
  String get name => 'Rectangle';

  @override
  Vector2? get orthoBase => points.isEmpty ? null : points.first;

  @override
  void accept(Vector2 point, ToolContext ctx) {
    if (points.isEmpty) {
      points.add(point);
      return;
    }
    final c1 = points.first;
    if (isDegenerateRectangle(c1, point)) return;
    commitShape(ctx, EntityKind.polyline, rectanglePayload(c1, point),
        fillable: true);
    clearShape();
  }

  @override
  void paintRubberBand(Canvas canvas, Vector2 origin, double scale) {
    if (points.isEmpty || !hoverVisible) return;
    final c1 = points.first, c2 = hoverPoint;
    final x1 = c1.x - origin.x, y1 = c1.y - origin.y;
    final x2 = c2.x - origin.x, y2 = c2.y - origin.y;
    band
      ..reset()
      ..moveTo(x1, y1)
      ..lineTo(x2, y1)
      ..lineTo(x2, y2)
      ..lineTo(x1, y2)
      ..close();
    canvas.drawPath(band, bandPaint);
  }
}
