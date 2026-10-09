// The camera, public (host embedding API spec G-2): an immutable value over
// the view's world-to-canvas transform, so a host maps its own widgets onto
// the plan without the engine's types.
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Offset, Rect, Size;
import 'package:jet_cad_2d/jet_cad_2d.dart' show Transform2;
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ViewportTransform;

/// Where the plan is on the screen (spec G-2), as
/// `FloorPlanController.camera` holds it: one value per camera position,
/// replaced (never changed) by every pan, zoom and fit.
///
/// The **world** is the plan's millimetres, y up. The **canvas** is the
/// view's drawing area in logical pixels, origin at its top left, y down:
/// below the service bar in the selection mode, inside the rulers in the
/// design mode. `FloorPlanController.canvasRect` says where the canvas is
/// on the screen.
///
/// Two cameras are equal when their transforms are, coefficient for
/// coefficient, exactly.
@immutable
final class FloorPlanCamera {
  /// The camera over [transform]. For the controller: a host reads a camera
  /// from `FloorPlanController.camera`.
  @internal
  FloorPlanCamera(ViewportTransform transform)
      : _m = transform.worldToScreenMatrix,
        _inverse = transform.worldToScreenMatrix.invert(),
        _transform = transform;

  final Transform2 _m;
  final Transform2 _inverse;
  final ViewportTransform _transform;

  /// The camera's scale: logical pixels per world millimetre.
  double get scale => _m.scaleMagnitude;

  /// The canvas point that shows [world] (world millimetres, y up).
  Offset worldToCanvas(Offset world) => Offset(
      _m.a * world.dx + _m.c * world.dy + _m.e,
      _m.b * world.dx + _m.d * world.dy + _m.f);

  /// The world point (millimetres, y up) shown at [canvas].
  Offset canvasToWorld(Offset canvas) => Offset(
      _inverse.a * canvas.dx + _inverse.c * canvas.dy + _inverse.e,
      _inverse.b * canvas.dx + _inverse.d * canvas.dy + _inverse.f);

  /// The world a canvas of [canvas] shows: the bound of its four corners,
  /// in millimetres, y up (so [Rect.top] is the least y).
  Rect visibleWorld(Size canvas) {
    final box = _transform.visibleWorld(canvas);
    return Rect.fromLTRB(box.minX, box.minY, box.maxX, box.maxY);
  }

  @override
  bool operator ==(Object other) =>
      other is FloorPlanCamera &&
      other._m.a == _m.a &&
      other._m.b == _m.b &&
      other._m.c == _m.c &&
      other._m.d == _m.d &&
      other._m.e == _m.e &&
      other._m.f == _m.f;

  @override
  int get hashCode => Object.hash(_m.a, _m.b, _m.c, _m.d, _m.e, _m.f);

  @override
  String toString() => 'FloorPlanCamera(scale: $scale, '
      'matrix: [${_m.a}, ${_m.b}, ${_m.c}, ${_m.d}, ${_m.e}, ${_m.f}])';
}
