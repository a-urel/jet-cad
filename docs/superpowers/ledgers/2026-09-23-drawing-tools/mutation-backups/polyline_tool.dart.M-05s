import 'dart:ui' show Canvas;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../tool.dart';
import 'placement_tool.dart';

/// Spec 05 D6. Each click appends a vertex:
/// - the last vertex again, or Enter, finishes it open;
/// - the first vertex (from three vertices on) closes it, appending the
///   **stored** first point, so closedness holds under `==`.
///
/// Closed with Fill on, it commits a region, or the plain boundary when the
/// loop cannot fill.
class PolylineTool extends PlacementTool {
  PolylineTool({super.fill});

  @override
  String get name => 'Polyline';

  @override
  Vector2? selfSnap(Vector2 raw, double apertureWorld) {
    if (points.length >= 3 && raw.distanceTo(points.first) <= apertureWorld) {
      return points.first;
    }
    if (points.length >= 2 && raw.distanceTo(points.last) <= apertureWorld) {
      return points.last;
    }
    return null;
  }

  @override
  void accept(Vector2 point, ToolContext ctx) {
    if (acceptingSelf) {
      if (points.length >= 3 && identical(point, points.first)) {
        // Ruling 05-4: the accepted point *is* the stored first vertex.
        _commit(ctx, polylinePayload([...points, point]), closed: true);
      } else {
        _commit(ctx, polylinePayload(points), closed: false);
      }
      return;
    }
    if (points.isNotEmpty && isDegenerateSegment(points.last, point)) return;
    points.add(point);
  }

  @override
  void finish(ToolContext ctx) {
    if (points.length >= 2) {
      _commit(ctx, polylinePayload(points), closed: false);
    }
  }

  void _commit(ToolContext ctx, GeometryPayload payload,
      {required bool closed}) {
    commitShape(ctx, EntityKind.polyline, payload, fillable: closed);
    clearShape();
  }

  @override
  void paintRubberBand(Canvas canvas, Vector2 origin, double scale) {
    if (points.isEmpty) return;
    band.reset();
    band.moveTo(points.first.x - origin.x, points.first.y - origin.y);
    for (var i = 1; i < points.length; i++) {
      band.lineTo(points[i].x - origin.x, points[i].y - origin.y);
    }
    if (hoverVisible) {
      band.lineTo(hoverPoint.x - origin.x, hoverPoint.y - origin.y);
    }
    canvas.drawPath(band, bandPaint);
  }
}
