import 'dart:ui' show Canvas;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../tool.dart';
import 'placement_tool.dart';

/// Spec 05 D6: AutoCAD's LINE. Each click commits one segment, and its end
/// is the next segment's start: the same stored values. Fill does not
/// apply.
class LineTool extends PlacementTool {
  LineTool();

  int _segments = 0;

  @override
  String get name => 'Line';

  /// The current start ends the chain, but only once a segment is committed
  /// (M-05x). Before that, a second click on the start is a zero-length
  /// segment and is refused.
  @override
  Vector2? selfSnap(Vector2 raw, double apertureWorld) => _segments > 0 &&
          points.isNotEmpty &&
          raw.distanceTo(points.last) <= apertureWorld
      ? points.last
      : null;

  @override
  void accept(Vector2 point, ToolContext ctx) {
    if (points.isEmpty) {
      points.add(point);
      return;
    }
    if (acceptingSelf) {
      clearShape();
      return;
    }
    final start = points.last;
    if (isDegenerateSegment(start, point)) return;
    if (commit(
        ctx,
        () => addDrafted(
            ctx.document, EntityKind.line, linePayload(start, point)))) {
      _segments++;
      points
        ..clear()
        ..add(point);
    } else {
      clearShape();
    }
  }

  @override
  void finish(ToolContext ctx) => clearShape();

  @override
  void clearShape() {
    super.clearShape();
    _segments = 0;
  }

  @override
  void paintRubberBand(Canvas canvas, Vector2 origin, double scale) {
    if (points.isEmpty || !hoverVisible) return;
    final a = points.last, h = hoverPoint;
    band
      ..reset()
      ..moveTo(a.x - origin.x, a.y - origin.y)
      ..lineTo(h.x - origin.x, h.y - origin.y);
    canvas.drawPath(band, bandPaint);
  }
}
