import 'dart:math' as math;
import 'dart:typed_data';

import '../document/tables.dart';
import 'aabb2.dart';
import 'segment_clip.dart';

/// Below this on-screen pattern period, a linetype is drawn solid.
///
/// Zoomed far enough out a dashed line is visually solid anyway, and below the
/// floor dash generation buys nothing but segments. **Swept and reviewed**, not
/// chosen — see the results note.
const double kDashCollapsePx = 3.0;

/// Reports one drawn span of a dash pattern.
typedef DashSpanEmit = void Function(
    double x0, double y0, double x1, double y1);

/// Walks a dash pattern along screen-space geometry.
///
/// Pure geometry: no `dart:ui`, no document access, no allocation per call. The
/// period is denominated in the same units as the points, which for the render
/// path means device pixels — and that is the point. **A pixel-denominated
/// period bounds segment count by the viewport rather than by the document.**
/// Generating in world units puts tens of thousands of segments on a single
/// long line regardless of zoom, and CanvasKit's abort at about 3.4 million ops
/// in one picture is measured, not theoretical.
class Dasher {
  Dasher({this.collapsePx = kDashCollapsePx});

  final double collapsePx;

  final Float64List _range = Float64List(2);

  int _collapsed = 0;

  /// Entities whose pattern collapsed to solid since [resetCounters].
  int get collapsedCount => _collapsed;

  void resetCounters() => _collapsed = 0;

  /// Emits the drawn spans of [pattern] along the polyline in [points].
  ///
  /// [scale] converts pattern units to the units [points] are in. Returns false
  /// when nothing was dashed and the caller must draw the geometry as it
  /// stands — an empty pattern, or a period under [collapsePx].
  ///
  /// The phase restarts at every vertex. That is DXF's default without
  /// LWPOLYLINE flag 128; the continuous-pattern flag is a field the DXF plan
  /// adds, not a decision made here.
  bool dashPolyline(Float64List points, int count, DashPattern pattern,
      double scale, Aabb2 clip, DashSpanEmit emit) {
    if (count < 2 || pattern.dashes.isEmpty || pattern.totalLength <= 0) {
      return false;
    }
    final period = pattern.totalLength * scale;
    if (!period.isFinite || period < collapsePx) {
      _collapsed++;
      return false;
    }
    for (var i = 0; i + 1 < count; i++) {
      _dashSegment(points[i * 2], points[i * 2 + 1], points[i * 2 + 2],
          points[i * 2 + 3], pattern, scale, period, clip, emit);
    }
    return true;
  }

  void _dashSegment(
      double x0,
      double y0,
      double x1,
      double y1,
      DashPattern pattern,
      double scale,
      double period,
      Aabb2 clip,
      DashSpanEmit emit) {
    if (!clipSegment(x0, y0, x1, y1, clip, _range)) return;
    final dx = x1 - x0;
    final dy = y1 - y0;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length == 0.0) return;

    // Distances along the *original* segment. The pattern's phase at the clip
    // entry is the arc length to t0, not zero — resetting it here would give a
    // picture that is correct at rest and slides as the camera moves.
    final from = _range[0] * length;
    final to = _range[1] * length;

    final ux = dx / length;
    final uy = dy / length;

    // Walk the pattern from its start, skipping cycles before `from` in one
    // step rather than one element at a time: a 32,000-pixel line clipped to
    // 200 visible pixels must not cost 10,000 iterations to reach them.
    var cursor = (from / period).floorToDouble() * period;
    var element = 0;
    while (cursor < to) {
      final raw = pattern.dashes[element];
      final span = raw.abs() * scale;
      // A zero-length element is a DXF dot: give it the smallest visible run
      // rather than looping forever on a span of nothing.
      final width = span == 0.0 ? 1e-9 : span;
      final end = cursor + width;
      if (raw >= 0 && end > from) {
        final a = math.max(cursor, from);
        final b = math.min(end, to);
        if (b > a) {
          emit(x0 + ux * a, y0 + uy * a, x0 + ux * b, y0 + uy * b);
        }
      }
      cursor = end;
      element = (element + 1) % pattern.dashes.length;
    }
  }
}
