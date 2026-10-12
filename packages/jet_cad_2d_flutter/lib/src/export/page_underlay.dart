import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:meta/meta.dart';

import '../draw_sink.dart';
import '../viewport_transform.dart';

/// A fill under a page export's drawing (plan colours spec PC-7): a closed
/// shape in its own space, placed in world by [placement], in [argb]
/// (0xAARRGGBB, drawn as given).
///
/// The export draws these after the paper and before the document, so the
/// drawing's own strokes and text stay on top of them. The shape is stored in
/// its own space and carries its placement beside it, as an instance does:
/// the export composes `camera · placement` once per fill, in `Float64`, and
/// no coordinate is rebased or copied.
@immutable
sealed class PageUnderlayFill {
  const PageUnderlayFill({required this.placement, required this.argb});

  /// The shape's space to world.
  final Transform2 placement;

  /// 0xAARRGGBB, drawn as given: the alpha is the fill's own, and the
  /// export applies none of its own.
  final int argb;
}

/// A closed polygon: [xy] interleaved x, y with the first point repeated as
/// the last; [count] the point count including that duplicate; [triangles]
/// its triangulation (`triangulateSimplePolygon`), never empty.
final class PageUnderlayPolygon extends PageUnderlayFill {
  PageUnderlayPolygon({
    required super.placement,
    required super.argb,
    required this.xy,
    required this.count,
    required this.triangles,
  }) {
    if (triangles.isEmpty) {
      throw ArgumentError.value(
        triangles,
        'triangles',
        'a polygon with no triangulation is not fillable',
      );
    }
    if (count < 4) {
      throw ArgumentError.value(
        count,
        'count',
        'a closed polygon has at least three points and the repeated first',
      );
    }
    if (count * 2 > xy.length) {
      throw ArgumentError.value(
        count,
        'count',
        'count * 2 exceeds xy.length (${xy.length})',
      );
    }
  }

  /// Interleaved x, y, the first point repeated as the last.
  final Float64List xy;

  /// The point count including the repeated first point.
  final int count;

  /// Triple-indices into [xy]'s point numbering.
  final Int32List triangles;
}

/// A circle of radius [r] about ([cx], [cy]) in its own space.
final class PageUnderlayCircle extends PageUnderlayFill {
  const PageUnderlayCircle({
    required super.placement,
    required super.argb,
    required this.cx,
    required this.cy,
    required this.r,
  });

  final double cx, cy, r;
}

/// Draws [fills] in order through [sink] under [camera]: each under the
/// residual `camera.worldToScreenMatrix · placement`, as `DraftPainter`
/// draws a leaf.
///
/// The style carries the fill's colour and nothing else: a fill has no
/// outline, so its lineweight is 0 and its linetype the continuous one.
void drawPageUnderlay(
  DrawSink sink,
  ViewportTransform camera,
  List<PageUnderlayFill> fills,
) {
  final world = camera.worldToScreenMatrix;
  for (final f in fills) {
    final style = ResolvedStyle(
      argb: f.argb,
      lineweightHundredths: 0,
      linetype: ReservedHandles.continuousLinetype,
      linetypeScale: 1,
    );
    sink.beginResidual(world.multiply(f.placement));
    switch (f) {
      case PageUnderlayPolygon(:final xy, :final count, :final triangles):
        sink.fillPolygon(xy, count, triangles, style);
      case PageUnderlayCircle(:final cx, :final cy, :final r):
        sink.fillCircle(cx, cy, r, style);
    }
    sink.endResidual();
  }
}
