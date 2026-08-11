import 'dart:typed_data';

import 'aabb2.dart';

/// Clips the segment to [clip], writing the parametric range into [out].
///
/// Liang–Barsky. Returns false when the segment misses the rectangle, in which
/// case [out] is untouched. `out[0]` and `out[1]` are `t` values in `[0, 1]`
/// along `(x0,y0) → (x1,y1)`.
///
/// The caller needs the parameters rather than the clipped endpoints because a
/// dash pattern's phase at the clip entry is the arc length to `t0`, measured
/// from the *original* start. Returning points alone would lose that.
bool clipSegment(
    double x0, double y0, double x1, double y1, Aabb2 clip, Float64List out) {
  final dx = x1 - x0;
  final dy = y1 - y0;
  var t0 = 0.0;
  var t1 = 1.0;

  for (var edge = 0; edge < 4; edge++) {
    final double p, q;
    switch (edge) {
      case 0:
        p = -dx;
        q = x0 - clip.minX;
      case 1:
        p = dx;
        q = clip.maxX - x0;
      case 2:
        p = -dy;
        q = y0 - clip.minY;
      default:
        p = dy;
        q = clip.maxY - y0;
    }
    if (p == 0.0) {
      // Parallel to this edge: inside if q >= 0, otherwise nothing survives.
      if (q < 0.0) return false;
      continue;
    }
    final r = q / p;
    if (p < 0.0) {
      if (r > t1) return false;
      if (r > t0) t0 = r;
    } else {
      if (r < t0) return false;
      if (r < t1) t1 = r;
    }
  }
  out[0] = t0;
  out[1] = t1;
  return true;
}
