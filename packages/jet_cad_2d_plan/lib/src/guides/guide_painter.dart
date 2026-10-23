// The alignment-guide painter (alignment guides spec, "The look"): the
// lines and gap marks of a [GuideSolution], drawn in screen space.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:jet_cad_2d/jet_cad_2d.dart' show Transform2;

import 'guide_solver.dart';

/// How far a guide line runs past each end of its span, in screen pixels.
const double kGuideOverhangPixels = 8.0;

/// How far a gap mark's end tick reaches to each side of the mark, in
/// screen pixels.
const double kGuideTickPixels = 4.0;

/// Paints a [GuideSolution]'s lines and marks in screen space: lines
/// extended [kGuideOverhangPixels] past each end, marks with
/// [kGuideTickPixels] ticks. Overhang and ticks are measured on screen
/// along the segment's own direction, so a rotated camera makes a guide
/// diagonal and its overhang follows.
///
/// Reuses one [Paint] and one [Float32List] (`drawRawPoints`,
/// `PointMode.lines`); allocates nothing per call. The list is always
/// drawn whole: a segment no entry uses is degenerate (both points equal)
/// and a butt cap draws nothing for it.
final class GuidePainter {
  final Paint _paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.butt;

  // Lines then marks, one segment (two points) per line and three per mark
  // (the span and a tick at each end).
  final Float32List _points =
      Float32List(4 * (kGuideCapacity + 3 * kGuideCapacity));

  /// The segments the last [paint] built (tests read it).
  @visibleForTesting
  Float32List get debugPoints => _points;

  /// Draws [s]'s lines and marks through [worldToScreen] in [color], a
  /// [strokePixels] wide.
  void paint(Canvas canvas, Transform2 worldToScreen, GuideSolution s,
      {required Color color, required double strokePixels}) {
    final m = worldToScreen;
    final p = _points;
    var k = 0;
    for (var i = 0; i < s.lineCount && i < kGuideCapacity; i++) {
      final b = 4 * i;
      final coord = s.lines[b + 1], from = s.lines[b + 2], to = s.lines[b + 3];
      final vertical = s.lines[b] == 0;
      final x0 = vertical ? coord : from, y0 = vertical ? from : coord;
      final x1 = vertical ? coord : to, y1 = vertical ? to : coord;
      final sx0 = m.a * x0 + m.c * y0 + m.e, sy0 = m.b * x0 + m.d * y0 + m.f;
      final sx1 = m.a * x1 + m.c * y1 + m.e, sy1 = m.b * x1 + m.d * y1 + m.f;
      var ux = sx1 - sx0, uy = sy1 - sy0;
      final len = math.sqrt(ux * ux + uy * uy);
      if (len > 0) {
        ux = ux / len * kGuideOverhangPixels;
        uy = uy / len * kGuideOverhangPixels;
      } else {
        ux = 0;
        uy = 0;
      }
      p[k++] = sx0 - ux;
      p[k++] = sy0 - uy;
      p[k++] = sx1 + ux;
      p[k++] = sy1 + uy;
    }
    for (var i = 0; i < s.markCount && i < kGuideCapacity; i++) {
      final b = 4 * i;
      final start = s.marks[b + 1], end = s.marks[b + 2], at = s.marks[b + 3];
      final alongX = s.marks[b] == 0;
      final x0 = alongX ? start : at, y0 = alongX ? at : start;
      final x1 = alongX ? end : at, y1 = alongX ? at : end;
      final sx0 = m.a * x0 + m.c * y0 + m.e, sy0 = m.b * x0 + m.d * y0 + m.f;
      final sx1 = m.a * x1 + m.c * y1 + m.e, sy1 = m.b * x1 + m.d * y1 + m.f;
      var dx = sx1 - sx0, dy = sy1 - sy0;
      final len = math.sqrt(dx * dx + dy * dy);
      // The tick: the span's screen normal, scaled to the tick's reach.
      if (len > 0) {
        final nx = -dy / len * kGuideTickPixels;
        final ny = dx / len * kGuideTickPixels;
        dx = nx;
        dy = ny;
      } else {
        dx = 0;
        dy = 0;
      }
      p[k++] = sx0;
      p[k++] = sy0;
      p[k++] = sx1;
      p[k++] = sy1;
      p[k++] = sx0 - dx;
      p[k++] = sy0 - dy;
      p[k++] = sx0 + dx;
      p[k++] = sy0 + dy;
      p[k++] = sx1 - dx;
      p[k++] = sy1 - dy;
      p[k++] = sx1 + dx;
      p[k++] = sy1 + dy;
    }
    p.fillRange(k, p.length, 0);
    _paint
      ..color = color
      ..strokeWidth = strokePixels;
    canvas.drawRawPoints(PointMode.lines, p, _paint);
  }
}
