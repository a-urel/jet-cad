import 'dart:math' as math;
import 'dart:ui' show Canvas, Offset, Rect;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../tool.dart';
import 'placement_tool.dart';

/// Spec 05 D8: centre, start, end. The start sets the radius and the start
/// angle; the end sets only the end angle. The sweep follows the angle the
/// pointer travelled around the centre ([SweepTracker]). Fill does not
/// apply.
class ArcTool extends PlacementTool {
  ArcTool();

  final SweepTracker _tracker = SweepTracker();
  double _r = 0;

  @override
  String get name => 'Arc';

  @override
  Vector2? get orthoBase => points.isEmpty ? null : points.first;

  double _angleOf(Vector2 p) =>
      math.atan2(p.y - points.first.y, p.x - points.first.x);

  @override
  void hovered(Vector2 raw) {
    if (points.length == 2) _tracker.track(_angleOf(raw));
  }

  @override
  void accept(Vector2 point, ToolContext ctx) {
    switch (points.length) {
      case 0:
        points.add(point);
      case 1:
        final r = points.first.distanceTo(point);
        if (isDegenerateRadius(r)) return;
        _r = r;
        _tracker.begin(_angleOf(point));
        points.add(point);
      default:
        final sweep = _tracker.sweepTo(_angleOf(point));
        if (sweep == 0) return;
        commitShape(ctx, EntityKind.arc,
            arcPayload(points.first, _r, _tracker.start, sweep));
        clearShape();
    }
  }

  @override
  void paintRubberBand(Canvas canvas, Vector2 origin, double scale) {
    if (points.isEmpty || !hoverVisible) return;
    final c = points.first;
    final co = Offset(c.x - origin.x, c.y - origin.y);
    final h = hoverPoint;
    band.reset();
    if (points.length == 1) {
      band
        ..moveTo(co.dx, co.dy)
        ..lineTo(h.x - origin.x, h.y - origin.y);
    } else {
      final sweep = _tracker.sweepTo(_angleOf(h));
      final start = _tracker.start;
      band
        ..addArc(Rect.fromCircle(center: co, radius: _r), start, sweep)
        ..moveTo(co.dx, co.dy)
        ..lineTo(co.dx + _r * math.cos(start), co.dy + _r * math.sin(start))
        ..moveTo(co.dx, co.dy)
        ..lineTo(co.dx + _r * math.cos(start + sweep),
            co.dy + _r * math.sin(start + sweep));
    }
    canvas.drawPath(band, bandPaint);
  }
}
