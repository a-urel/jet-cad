import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:meta/meta.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

/// The world→screen affine, held in `Float64` for its whole life.
///
/// Screen coordinates are logical pixels with y down; world coordinates are
/// document units with y up, which the fitting constructor flips. Nothing here
/// ever hands an absolute world coordinate to `dart:ui` — see `CameraController`
/// and the rebase origin for why that matters at 4.5e6.
@immutable
class ViewportTransform {
  ViewportTransform({required this.worldToScreenMatrix})
      : _inverse = worldToScreenMatrix.invert();

  /// Fits [world] into [viewport] with a 5% margin, y flipped.
  ///
  /// The scale is forced positive and finite before the matrix is built. An
  /// empty document — the state every session opens in — has an inverted
  /// `Aabb2` whose width is infinite, a viewport is laid out at `Size.zero`
  /// on some build passes, and a single-line document has no height. Each of
  /// those drives the scale to 0 or NaN, and the constructor's `invert()`
  /// would then throw `SingularTransformError` on the first frame.
  factory ViewportTransform.fit(Aabb2 world, Size viewport) {
    final w = (world.maxX - world.minX).abs();
    final h = (world.maxY - world.minY).abs();
    var s = w == 0 || h == 0
        ? 1.0
        : 0.95 * math.min(viewport.width / w, viewport.height / h);
    if (!s.isFinite || s <= 0) s = 1.0;
    // An empty box's centre is NaN, not a point; the origin is the only
    // defined answer.
    final cx = world.isEmpty ? 0.0 : (world.minX + world.maxX) / 2;
    final cy = world.isEmpty ? 0.0 : (world.minY + world.maxY) / 2;
    return ViewportTransform(
      worldToScreenMatrix: Transform2(
        s,
        0,
        0,
        -s,
        viewport.width / 2 - s * cx,
        viewport.height / 2 + s * cy,
      ),
    );
  }

  final Transform2 worldToScreenMatrix;
  final Transform2 _inverse;

  /// Geometric mean of the axis scales — the number stroke widths divide by.
  double get scale => worldToScreenMatrix.scaleMagnitude;

  Vector2 worldToScreen(Vector2 world) =>
      worldToScreenMatrix.transformPoint(world);

  Vector2 screenToWorld(Vector2 screen) => _inverse.transformPoint(screen);

  /// The world-space AABB of the viewport rectangle.
  ///
  /// All four corners are transformed, not two: under rotation the axis-aligned
  /// box of two opposite corners omits geometry that is genuinely on screen.
  Aabb2 visibleWorld(Size viewport) {
    var box = Aabb2.empty();
    for (final p in [
      Vector2(0, 0),
      Vector2(viewport.width, 0),
      Vector2(0, viewport.height),
      Vector2(viewport.width, viewport.height),
    ]) {
      box = box.expandedToPoint(screenToWorld(p));
    }
    return box;
  }
}
