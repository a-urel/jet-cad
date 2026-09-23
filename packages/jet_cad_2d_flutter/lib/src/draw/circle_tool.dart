import 'dart:ui' show Canvas, Offset, Rect;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../tool.dart';
import 'placement_tool.dart';

/// Spec 05 D7: the centre, then a point on the circle.
class CircleTool extends PlacementTool {
  CircleTool({super.fill});

  @override
  String get name => 'Circle';

  @override
  Vector2? get orthoBase => points.isEmpty ? null : points.first;

  @override
  void accept(Vector2 point, ToolContext ctx) {
    if (points.isEmpty) {
      points.add(point);
      return;
    }
    final c = points.first;
    final r = c.distanceTo(point);
    if (isDegenerateRadius(r)) return;
    commitShape(ctx, EntityKind.circle, circlePayload(c, r), fillable: true);
    clearShape();
  }

  @override
  void paintRubberBand(Canvas canvas, Vector2 origin, double scale) {
    if (points.isEmpty || !hoverVisible) return;
    final c = points.first, h = hoverPoint;
    final r = c.distanceTo(h);
    band
      ..reset()
      ..addOval(Rect.fromCircle(
          center: Offset(c.x - origin.x, c.y - origin.y), radius: r))
      ..moveTo(c.x - origin.x, c.y - origin.y)
      ..lineTo(h.x - origin.x, h.y - origin.y);
    canvas.drawPath(band, bandPaint);
  }
}
