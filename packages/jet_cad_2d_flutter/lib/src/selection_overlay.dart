import 'dart:typed_data';
import 'dart:ui' show Canvas, Offset, Paint, PaintingStyle, Size;

import 'package:flutter/rendering.dart' show CustomPainter;
import 'package:jet_cad_2d/jet_cad_2d.dart' show Transform2;

import 'camera_controller.dart';
import 'outline_cache.dart';
import 'selection.dart';
import 'selection_style.dart';
import 'tool.dart';

/// Draws the selected and hovered outlines, then lets the active tool draw
/// its own overlay — and never touches the drawing underneath.
///
/// Named `…Painter` rather than the spec's `SelectionOverlay`: Flutter's own
/// `SelectionOverlay` (text selection) is exported from
/// `package:flutter/widgets.dart`, so an app that imports Material and this
/// package's barrel would have to `hide` one of them at every consumer.
///
/// The overlay is a **second** `CustomPaint` inside its own
/// `RepaintBoundary`, over `Listenable.merge([selection, tools, camera])`.
/// That is the whole point of the split (spec criterion 6): a hover at
/// pointer rate repaints this painter and leaves the drawing's layer alone,
/// so the cost of moving the mouse over a large document is one overlay
/// frame, not one full re-render.
///
/// Three things keep the frame path allocation-free. The outlines come from
/// [OutlineCache] already built — the document walk happens at
/// selection-change rate, not per frame. The two [Paint]s and the matrix are
/// fields, re-stroked and refilled in place. And the origin the cache rebases
/// by is carried by the matrix rather than by the paths, so no absolute world
/// coordinate reaches `dart:ui`: at the generated corpus's x = 4.5e6 a
/// float32 `ui.Path` would sit visibly beside the entity it outlines.
class SelectionOverlayPainter extends CustomPainter {
  SelectionOverlayPainter({
    required this.selection,
    required this.tools,
    required this.camera,
    required this.outlines,
    super.repaint,
    this.onPaintForTest,
  });

  final SelectionController selection;
  final ToolController tools;
  final CameraController camera;
  final OutlineCache outlines;

  /// Counts frames in a widget test — the seam criterion 6 is measured on.
  final void Function()? onPaintForTest;

  /// `worldToScreen ∘ translate(origin)`, column-major, refilled per frame.
  /// `[10]` and `[15]` are the untouched z and w diagonal entries.
  final Float64List _matrix = Float64List(16)
    ..[10] = 1.0
    ..[15] = 1.0;

  final Paint _selected = Paint()
    ..color = kSelectionColor
    ..style = PaintingStyle.stroke;

  final Paint _hover = Paint()
    ..color = kHoverColor
    ..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    onPaintForTest?.call();
    // A zero-size paint is a real state, not a theoretical one — see
    // `ViewportTransform.fit`'s note on the layout passes that produce it.
    // It must return *before* the rebase, because `visibleWorld(Size.zero)`
    // collapses to a point, `rebaseOriginFor` answers the origin for a zero
    // span, and `pathFor(key, zero)` would then rebuild every cached path in
    // **absolute** world space and hand x = 4.5e6 to float32 `ui.Path` —
    // undoing the rebase the cache exists for, and re-doing the rebuild on
    // the next real frame.
    if (size.isEmpty) return;
    final cam = camera.value;
    final origin = rebaseOriginFor(cam.visibleWorld(size));
    final m = cam.worldToScreenMatrix;
    _matrix[0] = m.a;
    _matrix[1] = m.b;
    _matrix[4] = m.c;
    _matrix[5] = m.d;
    _matrix[12] = m.a * origin.x + m.c * origin.y + m.e;
    _matrix[13] = m.b * origin.x + m.d * origin.y + m.f;
    // The stroke rides the world→screen matrix, so the world width is the
    // screen width divided by the scale; that is what holds the outline at
    // two pixels through a zoom.
    final scale = cam.scale;
    _selected.strokeWidth = kSelectionStrokePixels / scale;
    _hover.strokeWidth = kHoverStrokePixels / scale;

    final hover = selection.hover;
    // A hovered key that is also selected is drawn once, by the selected
    // pass: stroking it twice would read as a third, brighter state.
    final hoverOnly =
        hover != null && !selection.contains(hover) ? hover : null;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.transform(_matrix);
    for (final key in selection.keys) {
      final path = outlines.pathFor(key, origin);
      if (path != null) canvas.drawPath(path, _selected);
    }
    if (hoverOnly != null) {
      final path = outlines.pathFor(hoverOnly, origin);
      if (path != null) canvas.drawPath(path, _hover);
    }
    canvas.restore();

    // Back in screen space, under its **own** clip: `restore` above popped
    // the first one, and neither the point crosses nor the tool's overlay is
    // bounded by the viewport on its own — a selected point just off screen
    // puts its cross over whatever sibling widget sits beside the canvas.
    //
    // A `point` entity has no extent, so its path is a lone `moveTo` and
    // strokes nothing; its marker is a cross whose size is in pixels and
    // therefore cannot live in the world-space cache. The two paints are
    // re-stroked rather than replaced — `Canvas` serialises a paint at call
    // time, so the world-space strokes above are already recorded at their
    // own widths.
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    _selected.strokeWidth = kSelectionStrokePixels;
    _hover.strokeWidth = kHoverStrokePixels;
    for (final key in selection.keys) {
      _drawPointCross(canvas, key, m, _selected, 3 * kSelectionStrokePixels);
    }
    if (hoverOnly != null) {
      _drawPointCross(canvas, hoverOnly, m, _hover, 3 * kHoverStrokePixels);
    }
    tools.active.paintOverlay(canvas, cam, size);
    canvas.restore();
  }

  /// A cross of half-length [half] **screen pixels** centred on [key]'s world
  /// position, or nothing at all when [key] is not a lone point.
  ///
  /// [worldToScreen] is the camera's own matrix, not [_matrix]: the position
  /// [OutlineCache.worldPointOf] hands back is absolute world, and this pass
  /// runs after the rebased transform has been popped. It never reaches
  /// `dart:ui` — only the screen coordinates derived from it do.
  void _drawPointCross(Canvas canvas, SelectionKey key,
      Transform2 worldToScreen, Paint paint, double half) {
    final p = outlines.worldPointOf(key);
    if (p == null) return;
    final x = worldToScreen.a * p.x + worldToScreen.c * p.y + worldToScreen.e;
    final y = worldToScreen.b * p.x + worldToScreen.d * p.y + worldToScreen.f;
    canvas.drawLine(Offset(x - half, y), Offset(x + half, y), paint);
    canvas.drawLine(Offset(x, y - half), Offset(x, y + half), paint);
  }

  /// Always false: every reason to repaint is in the `repaint` listenable the
  /// caller merged. Answering true would repaint on every ancestor rebuild,
  /// which is exactly the cost the boundary split exists to avoid.
  @override
  bool shouldRepaint(covariant SelectionOverlayPainter oldDelegate) => false;
}
