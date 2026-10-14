// The one clamp every fit passes through (today's host embedding API G-3):
// a camera a fit computes is brought inside the zoom bounds about the
// canvas's centre, as `CameraController.zoomAt` brings a zoom. Ported from
// jet_cad_floor_plan's camera_bounds.dart.
import 'dart:ui' show Size;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ViewportTransform;

/// The default zoom bounds, logical pixels per millimetre (today's
/// `kMinScale`, `kMaxScale`).
const double kPlanMinScale = 0.001;
const double kPlanMaxScale = 100.0;

/// [camera] with its scale inside `[minScale, maxScale]`, scaled about the
/// centre of a canvas of [canvas]: the world point at the centre stays
/// there. [camera] itself when its scale is already inside.
///
/// Whether a scale is past a bound is a geometric decision on a derived
/// number, made with the tolerance `CameraController.zoomAt` uses.
ViewportTransform clampCameraScale(ViewportTransform camera, Size canvas,
    {required double minScale, required double maxScale}) {
  const tolerance = Tolerance.standard;
  final scale = camera.scale;
  final double bound;
  if (tolerance.compare(scale, maxScale) > 0) {
    bound = maxScale;
  } else if (tolerance.compare(scale, minScale) < 0) {
    bound = minScale;
  } else {
    return camera;
  }
  final k = bound / scale;
  final cx = canvas.width / 2, cy = canvas.height / 2;
  final about = Transform2.translation(cx, cy)
      .multiply(Transform2.scale(k, k))
      .multiply(Transform2.translation(-cx, -cy));
  return ViewportTransform(
      worldToScreenMatrix: about.multiply(camera.worldToScreenMatrix));
}
