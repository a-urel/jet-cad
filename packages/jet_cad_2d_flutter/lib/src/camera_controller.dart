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
///
/// [minScale] and [maxScale] bound [ViewportTransform.scale] — the geometric
/// mean of the axis scales, the number stroke widths divide by. They default
/// to unbounded so a caller that passes nothing (the measurement harness) is
/// unaffected. The clamp lives here, not in a gesture widget, because a
/// keyboard zoom, a zoom-to-fit and a zoom-to-selection all pass through
/// [zoomAt] and a clamp in a widget guards only one of them.
class CameraController extends ValueNotifier<ViewportTransform> {
  CameraController(
    super.initial, {
    this.minScale = 0.0,
    this.maxScale = double.infinity,
  })  : assert(minScale >= 0.0),
        assert(maxScale > minScale);

  final double minScale;
  final double maxScale;

  /// The bound decisions compare a *derived* scale — `sqrt(|det|)` after a
  /// three-matrix product — against a bound, so they are geometric decisions
  /// and use a tolerance, not `==` (spec invariant 6).
  static const Tolerance _tolerance = Tolerance.standard;

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
  ///
  /// A result past a bound **lands on the bound**: the factor is reduced so
  /// the resulting scale is the bound, and the zoom still happens about
  /// [screenFocus]. Rejecting the gesture instead would make the view stick
  /// and jump. A gesture that pushes against a bound the camera already rests
  /// on returns before assigning, so nothing is notified and nothing repaints.
  void zoomAt(Offset screenFocus, double factor) {
    if (!factor.isFinite || factor <= 0) return;
    final current = value.scale;
    var f = factor;
    if (f > 1.0) {
      if (_tolerance.compare(current, maxScale) >= 0) return;
      if (_tolerance.compare(current * f, maxScale) > 0) f = maxScale / current;
    } else if (f < 1.0) {
      if (_tolerance.compare(current, minScale) <= 0) return;
      if (_tolerance.compare(current * f, minScale) < 0) f = minScale / current;
    }
    final m = value.worldToScreenMatrix;
    // The argument of `multiply` is applied first, so this scales in screen
    // space *after* the camera. Reversed, it would scale in world space and
    // the point under the cursor would drift.
    final about = Transform2.translation(screenFocus.dx, screenFocus.dy)
        .multiply(Transform2.scale(f, f))
        .multiply(Transform2.translation(-screenFocus.dx, -screenFocus.dy));
    value = ViewportTransform(worldToScreenMatrix: about.multiply(m));
  }
}
