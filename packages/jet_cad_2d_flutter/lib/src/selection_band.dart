// The selection band's direction rule and look (interaction-core D1, spec
// D8), shared by the design mode's SelectTool and the floor planner's
// selection mode (rubber-band spec RB-6).
import 'dart:math' as math;
import 'dart:ui';

import 'package:jet_cad_2d/jet_cad_2d.dart' show BandMode;

import 'canvas_palette.dart';
import 'selection_style.dart';

/// The band's mode by its drag direction (interaction-core D1): left to
/// right is a window, right to left a crossing.
BandMode bandModeFor(Offset start, Offset end) =>
    end.dx >= start.dx ? BandMode.window : BandMode.crossing;

/// Paints a selection band over a rect in screen pixels: the band colour
/// at [kBandFillAlpha], a 1 px outline, solid for a window, dashed 6 on and
/// 4 off for a crossing, walking the edges clockwise from the top-left.
///
/// Keeps its two paints and its path and resets them per call, so a live
/// band builds no `Paint` and no `Path` per frame.
final class SelectionBandPainter {
  SelectionBandPainter();

  final Paint _fill = Paint();
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  final Path _dashes = Path();

  void paint(Canvas canvas, Rect rect, BandMode mode, PaperPalette paper) {
    final crossing = mode == BandMode.crossing;
    final color = crossing ? paper.crossingBand : paper.windowBand;
    _fill.color = color.withAlpha(kBandFillAlpha);
    canvas.drawRect(rect, _fill);
    _stroke.color = color;
    if (!crossing) {
      canvas.drawRect(rect, _stroke);
      return;
    }
    _dashes.reset();
    _edge(rect.left, rect.top, rect.right, rect.top);
    _edge(rect.right, rect.top, rect.right, rect.bottom);
    _edge(rect.right, rect.bottom, rect.left, rect.bottom);
    _edge(rect.left, rect.bottom, rect.left, rect.top);
    canvas.drawPath(_dashes, _stroke);
  }

  /// Adds one edge's dashes to the path, walking from (x0, y0) to (x1, y1):
  /// 6 px on, 4 px off, starting on, the last dash cut at the corner.
  void _edge(double x0, double y0, double x1, double y1) {
    const on = 6.0, off = 4.0;
    final dx = x1 - x0, dy = y1 - y0;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length == 0) return;
    final ux = dx / length, uy = dy / length;
    var travelled = 0.0;
    var drawing = true;
    while (travelled < length) {
      final step = math.min(drawing ? on : off, length - travelled);
      if (drawing) {
        _dashes
          ..moveTo(x0 + ux * travelled, y0 + uy * travelled)
          ..lineTo(x0 + ux * (travelled + step), y0 + uy * (travelled + step));
      }
      travelled += step;
      drawing = !drawing;
    }
  }
}
