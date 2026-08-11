import 'dart:math' as math;
import 'dart:typed_data';

import 'aabb2.dart';

/// Scratch space for the crossing angles inside [circleClipWindows].
///
/// A circle crosses each of the clip's four edge *lines* at most twice, so
/// eight entries is the true upper bound — sized once, module-level, and
/// reused on every call so the hot dash-arc path never allocates.
final Float64List _crossings = Float64List(8);

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

/// Inserts [value] into the sorted prefix `buffer[0..count)` and returns the
/// new count.
///
/// A plain insertion sort over at most 8 elements, chosen over
/// `List<double>.sort()` because the caller ([circleClipWindows]) is on the
/// dash-arc hot path — one call per curve per frame — and must not allocate a
/// growable list to hold the crossings it sorts.
int _insertCrossing(Float64List buffer, int count, double value) {
  if (count >= buffer.length) return count;
  var i = count - 1;
  while (i >= 0 && buffer[i] > value) {
    buffer[i + 1] = buffer[i];
    i--;
  }
  buffer[i + 1] = value;
  return count + 1;
}

/// The angular ranges of a circle that lie inside [clip].
///
/// Writes `[start0, end0, start1, end1, …]` into [out], each `start < end` and
/// in `(-pi, 3pi]`, and returns the pair count. Returns `-1` when the entire
/// circle is inside, which the caller treats as one window of the full turn
/// without paying for the intersection maths.
///
/// Constant work regardless of radius, which is the point: a dashed circle
/// whose screen radius is ten thousand pixels must cost the same to clip as one
/// of ten, or the pixel-denominated period stops bounding anything.
int circleClipWindows(
    double cx, double cy, double r, Aabb2 clip, Float64List out) {
  if (r <= 0 || !r.isFinite) return 0;
  if (cx - r >= clip.minX &&
      cx + r <= clip.maxX &&
      cy - r >= clip.minY &&
      cy + r <= clip.maxY) {
    return -1;
  }

  // Angles where the circle crosses each edge line, kept only where the
  // crossing point is on the finite edge, and inserted in sorted order as we
  // go. `_crossings` is a fixed 8-slot buffer (two per edge, four edges) —
  // see its doc comment — reused across calls so this never allocates.
  var crossingCount = 0;

  final dxMinX = clip.minX - cx;
  if (dxMinX.abs() <= r) {
    final dy = math.sqrt(r * r - dxMinX * dxMinX);
    final y0 = cy - dy;
    if (y0 >= clip.minY && y0 <= clip.maxY) {
      crossingCount = _insertCrossing(
          _crossings, crossingCount, math.atan2(y0 - cy, dxMinX));
    }
    final y1 = cy + dy;
    if (y1 >= clip.minY && y1 <= clip.maxY) {
      crossingCount = _insertCrossing(
          _crossings, crossingCount, math.atan2(y1 - cy, dxMinX));
    }
  }

  final dxMaxX = clip.maxX - cx;
  if (dxMaxX.abs() <= r) {
    final dy = math.sqrt(r * r - dxMaxX * dxMaxX);
    final y0 = cy - dy;
    if (y0 >= clip.minY && y0 <= clip.maxY) {
      crossingCount = _insertCrossing(
          _crossings, crossingCount, math.atan2(y0 - cy, dxMaxX));
    }
    final y1 = cy + dy;
    if (y1 >= clip.minY && y1 <= clip.maxY) {
      crossingCount = _insertCrossing(
          _crossings, crossingCount, math.atan2(y1 - cy, dxMaxX));
    }
  }

  final dyMinY = clip.minY - cy;
  if (dyMinY.abs() <= r) {
    final dx = math.sqrt(r * r - dyMinY * dyMinY);
    final x0 = cx - dx;
    if (x0 >= clip.minX && x0 <= clip.maxX) {
      crossingCount = _insertCrossing(
          _crossings, crossingCount, math.atan2(dyMinY, x0 - cx));
    }
    final x1 = cx + dx;
    if (x1 >= clip.minX && x1 <= clip.maxX) {
      crossingCount = _insertCrossing(
          _crossings, crossingCount, math.atan2(dyMinY, x1 - cx));
    }
  }

  final dyMaxY = clip.maxY - cy;
  if (dyMaxY.abs() <= r) {
    final dx = math.sqrt(r * r - dyMaxY * dyMaxY);
    final x0 = cx - dx;
    if (x0 >= clip.minX && x0 <= clip.maxX) {
      crossingCount = _insertCrossing(
          _crossings, crossingCount, math.atan2(dyMaxY, x0 - cx));
    }
    final x1 = cx + dx;
    if (x1 >= clip.minX && x1 <= clip.maxX) {
      crossingCount = _insertCrossing(
          _crossings, crossingCount, math.atan2(dyMaxY, x1 - cx));
    }
  }

  if (crossingCount == 0) return 0;

  // Between two consecutive crossings the circle is wholly in or wholly out,
  // so one midpoint test per gap decides the whole gap.
  var pairs = 0;
  for (var i = 0; i < crossingCount; i++) {
    final a = _crossings[i];
    final b =
        i + 1 < crossingCount ? _crossings[i + 1] : _crossings[0] + 2 * math.pi;
    // A tangent circle touches an edge at a single point rather than
    // crossing it, and that point is found twice (once from each side of
    // the edge search), producing a gap of width zero. There is no visible
    // arc at a point, so skip it rather than reporting a start == end pair
    // that would violate this function's own contract.
    if (b <= a) continue;
    final mid = (a + b) / 2;
    final mx = cx + r * math.cos(mid);
    final my = cy + r * math.sin(mid);
    if (mx >= clip.minX &&
        mx <= clip.maxX &&
        my >= clip.minY &&
        my <= clip.maxY) {
      if (pairs * 2 + 1 >= out.length) break;
      out[pairs * 2] = a;
      out[pairs * 2 + 1] = b;
      pairs++;
    }
  }
  return pairs;
}
