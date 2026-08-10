import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'viewport_transform.dart';

/// The rebase origin for one frame: the view's centre snapped to a
/// power-of-two world grid whose step is derived from the view span.
///
/// Two properties matter and both come from the snapping. The origin is
/// **stable** across small camera movements, so a pan does not re-quantise
/// every coordinate on every frame; and it is **near** the geometry, so the
/// residual reaching float32 is small. Deriving the step from the span rather
/// than fixing it keeps both true at every zoom level.
Vector2 rebaseOriginFor(Aabb2 visibleWorld) {
  final span = math.max(
    (visibleWorld.maxX - visibleWorld.minX).abs(),
    (visibleWorld.maxY - visibleWorld.minY).abs(),
  );
  if (span == 0 || !span.isFinite) return Vector2.zero();
  final exponent = (math.log(span) / math.ln2).floor();
  final step = math.pow(2.0, exponent).toDouble();
  final cx = (visibleWorld.minX + visibleWorld.maxX) / 2;
  final cy = (visibleWorld.minY + visibleWorld.maxY) / 2;
  // Floor, not truncate: truncation rounds toward zero, which on the negative
  // side puts the origin above the view and flips the sign of every residual
  // as the camera crosses zero.
  return Vector2(
      (cx / step).floorToDouble() * step, (cy / step).floorToDouble() * step);
}

/// The camera. A `ValueNotifier` so a change repaints inside a
/// `RepaintBoundary` without rebuilding the widget tree.
class CameraController extends ValueNotifier<ViewportTransform> {
  CameraController(super.initial);

  void panBy(Offset screenDelta) {
    final m = value.worldToScreenMatrix;
    value = ViewportTransform(
      worldToScreenMatrix: Transform2(
          m.a, m.b, m.c, m.d, m.e + screenDelta.dx, m.f + screenDelta.dy),
    );
  }

  /// Scales about a screen point, keeping the world point under it fixed.
  ///
  /// A factor that is not finite and positive is ignored rather than applied:
  /// it would make the matrix singular, and `invert()` in the
  /// [ViewportTransform] constructor would throw there, taking the gesture and
  /// the frame with it. Holding the camera still is the only meaning a
  /// zero-scale zoom could have.
  void zoomAt(Offset screenFocus, double factor) {
    if (!factor.isFinite || factor <= 0) return;
    final m = value.worldToScreenMatrix;
    // The argument of `multiply` is applied first, so this scales in screen
    // space *after* the camera. Reversed, it would scale in world space and
    // the point under the cursor would drift.
    final about = Transform2.translation(screenFocus.dx, screenFocus.dy)
        .multiply(Transform2.scale(factor, factor))
        .multiply(Transform2.translation(-screenFocus.dx, -screenFocus.dy));
    value = ViewportTransform(worldToScreenMatrix: about.multiply(m));
  }
}
