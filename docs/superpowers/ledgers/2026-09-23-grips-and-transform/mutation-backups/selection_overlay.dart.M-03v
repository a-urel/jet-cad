import 'dart:typed_data';
import 'dart:ui'
    show Canvas, Offset, Paint, PaintingStyle, PointMode, Size, StrokeCap;

import 'package:flutter/rendering.dart' show CustomPainter;
import 'package:jet_cad_2d/jet_cad_2d.dart' show GripRole, Transform2;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'camera_controller.dart';
import 'grip_cache.dart';
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
///
/// Since 03 it also draws, reading the grips from `tools.context.grips`
/// (Ruling 03-4):
/// - the move/rotate preview through a second reused matrix;
/// - the grips, with `drawRawPoints` from reused buffers, in O(1) draw calls
///   (invariant 6);
/// - the rotation grip.
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

  /// New in 03: `worldToScreen ∘ T ∘ translate(origin)` for the move/rotate
  /// preview (spec D7), refilled per frame. The paths hold `world − origin`,
  /// so T sits between the camera and the rebase (M-03u).
  final Float64List _preview = Float64List(16)
    ..[10] = 1.0
    ..[15] = 1.0;

  final Paint _selected = Paint()
    ..color = kSelectionColor
    ..style = PaintingStyle.stroke;

  final Paint _hover = Paint()
    ..color = kHoverColor
    ..style = PaintingStyle.stroke;

  // New in 03.
  final Paint _previewPaint = Paint()
    ..color = kPreviewColor
    ..style = PaintingStyle.stroke;

  final Paint _gripPaint = Paint()
    ..color = kGripColor
    ..strokeCap = StrokeCap.square
    ..strokeWidth = kGripPixels;

  final Paint _gripMovePaint = Paint()
    ..color = kGripMoveColor
    ..strokeCap = StrokeCap.square
    ..strokeWidth = kGripPixels;

  final Paint _gripHotPaint = Paint()
    ..color = kGripHotColor
    ..strokeCap = StrokeCap.square
    ..strokeWidth = kGripPixels;

  final Paint _stem = Paint()
    ..color = kGripColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  /// Screen positions, exact-size, reallocated only when the count changes
  /// (Ruling 03-10).
  Float32List _stretchPoints = Float32List(0);
  Float32List _movePoints = Float32List(0);
  final Float32List _hotPoint = Float32List(2);

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
    final tool = tools.active;

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
    // New in 03: the reshape preview, in rebased world, under this same
    // matrix (spec D7, Ruling 03-3).
    tool.paintWorldOverlay(canvas, origin, scale);
    canvas.restore();

    // New in 03: the move/rotate preview (spec D7).
    final preview = tool.selectionPreviewTransform;
    if (preview != null) {
      _paintPreview(canvas, size, m, preview, origin, scale);
    }

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
    if (preview != null) {
      // A point has no path; its preview is its cross at T(p) (spec D7).
      _previewPaint.strokeWidth = kPreviewStrokePixels;
      for (final key in selection.keys) {
        _drawPointCross(
            canvas, key, m, _previewPaint, 3 * kSelectionStrokePixels, preview);
      }
    }
    final grips = tools.context.grips;
    if (grips != null) _paintGrips(canvas, grips, m);
    tool.paintOverlay(canvas, cam, size);
    canvas.restore();
  }

  void _paintPreview(Canvas canvas, Size size, Transform2 m, Transform2 t,
      Vector2 origin, double scale) {
    // T ∘ translate(origin): the rebase first, then the drag. Composed in
    // doubles, with no Transform2 allocated per frame.
    final pe = t.a * origin.x + t.c * origin.y + t.e;
    final pf = t.b * origin.x + t.d * origin.y + t.f;
    _preview[0] = m.a * t.a + m.c * t.b;
    _preview[1] = m.b * t.a + m.d * t.b;
    _preview[4] = m.a * t.c + m.c * t.d;
    _preview[5] = m.b * t.c + m.d * t.d;
    _preview[12] = m.a * pe + m.c * pf + m.e;
    _preview[13] = m.b * pe + m.d * pf + m.f;
    // T is rigid, so the camera's scale is still the whole scale.
    _previewPaint.strokeWidth = kPreviewStrokePixels / scale;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.transform(_preview);
    for (final key in selection.keys) {
      final path = outlines.pathFor(key, origin);
      if (path != null) canvas.drawPath(path, _previewPaint);
    }
    canvas.restore();
  }

  /// Spec D6: one `drawRawPoints` per colour, whatever the grip count;
  /// projected in doubles, and only screen coordinates are narrowed
  /// (Ruling 03-10).
  void _paintGrips(Canvas canvas, GripCache grips, Transform2 m) {
    if (grips.leafGripsLive) {
      final list = grips.grips;
      if (_stretchPoints.length != 2 * grips.stretchCount) {
        _stretchPoints = Float32List(2 * grips.stretchCount);
      }
      if (_movePoints.length != 2 * grips.moveCount) {
        _movePoints = Float32List(2 * grips.moveCount);
      }
      var s = 0, mv = 0;
      for (var i = 0; i < list.length; i++) {
        final g = list[i].grip;
        final x = m.a * g.x + m.c * g.y + m.e;
        final y = m.b * g.x + m.d * g.y + m.f;
        if (g.role == GripRole.move) {
          _movePoints[mv++] = x;
          _movePoints[mv++] = y;
        } else {
          _stretchPoints[s++] = x;
          _stretchPoints[s++] = y;
        }
      }
      if (s > 0) {
        canvas.drawRawPoints(PointMode.points, _stretchPoints, _gripPaint);
      }
      if (mv > 0) {
        canvas.drawRawPoints(PointMode.points, _movePoints, _gripMovePaint);
      }
      final hot = grips.hot;
      if (hot >= 0 && hot < list.length) {
        final g = list[hot].grip;
        _hotPoint[0] = m.a * g.x + m.c * g.y + m.e;
        _hotPoint[1] = m.b * g.x + m.d * g.y + m.f;
        canvas.drawRawPoints(PointMode.points, _hotPoint, _gripHotPaint);
      }
    }
    final box = grips.box;
    if (grips.rotatable && box != null) {
      final g = rotationGripOf(box, m);
      canvas.drawLine(
          g.anchor, g.centre.translate(0, kRotationGripPixels / 2), _stem);
      canvas.drawCircle(g.centre, kRotationGripPixels / 2, _gripPaint);
    }
  }

  /// A cross of half-length [half] **screen pixels** centred on [key]'s world
  /// position — or, with [moved], on `moved(position)` — or nothing at all
  /// when [key] is not a lone point.
  ///
  /// [worldToScreen] is the camera's own matrix, not [_matrix]: the position
  /// [OutlineCache.worldPointOf] hands back is absolute world, and this pass
  /// runs after the rebased transform has been popped. It never reaches
  /// `dart:ui` — only the screen coordinates derived from it do.
  void _drawPointCross(Canvas canvas, SelectionKey key,
      Transform2 worldToScreen, Paint paint, double half,
      [Transform2? moved]) {
    final p = outlines.worldPointOf(key);
    if (p == null) return;
    var px = p.x, py = p.y;
    if (moved != null) {
      final tx = moved.a * px + moved.c * py + moved.e;
      final ty = moved.b * px + moved.d * py + moved.f;
      px = tx;
      py = ty;
    }
    final x = worldToScreen.a * px + worldToScreen.c * py + worldToScreen.e;
    final y = worldToScreen.b * px + worldToScreen.d * py + worldToScreen.f;
    canvas.drawLine(Offset(x - half, y), Offset(x + half, y), paint);
    canvas.drawLine(Offset(x, y - half), Offset(x, y + half), paint);
  }

  /// Always false: every reason to repaint is in the `repaint` listenable the
  /// caller merged. Answering true would repaint on every ancestor rebuild,
  /// which is exactly the cost the boundary split exists to avoid.
  @override
  bool shouldRepaint(covariant SelectionOverlayPainter oldDelegate) => false;
}
