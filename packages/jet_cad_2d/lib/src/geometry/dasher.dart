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

/// Sums the absolute lengths in [dashes] — the pattern's true cycle length.
///
/// Never `pattern.totalLength`: nothing enforces that the declared total
/// agrees with the entries that produced it, and a disagreement drifts the
/// phase after the cursor's cycle skip (see [Dasher.patternStepCount]).
/// Shared by [Dasher.dashPolyline] and [Dasher.dashArc] so the segment walk
/// and the arc walk can never disagree about where a cycle ends.
double _dashCycle(List<double> dashes) {
  var cycle = 0.0;
  for (final d in dashes) {
    cycle += d.abs();
  }
  return cycle;
}

/// Reports one drawn span of a dash pattern.
typedef DashSpanEmit = void Function(
    double x0, double y0, double x1, double y1);

/// Reports one drawn span of a dash pattern along an arc.
typedef DashArcEmit = void Function(double startAngle, double sweep);

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

  /// Scratch space for [circleClipWindows]'s output, reused across calls to
  /// [dashArc] so the per-curve, per-frame hot path never allocates.
  final Float64List _windows = Float64List(16);

  int _collapsed = 0;
  int _steps = 0;

  /// Entities whose pattern collapsed to solid since [resetCounters].
  int get collapsedCount => _collapsed;

  /// Iterations of the pattern-walk loop since [resetCounters].
  ///
  /// Exists to make the cursor's cycle skip (below) testable. For a
  /// correctly-summed pattern, starting the walk at `cursor = 0` and at
  /// `cursor = floor(from / period) * period` reach the identical breakpoint
  /// with the same element index — the skip changes only how many loop
  /// iterations it takes to get there, never the emitted spans. No assertion
  /// on output can tell a working skip apart from one that has regressed to
  /// walking from zero; only a bound on this counter can.
  int get patternStepCount => _steps;

  void resetCounters() {
    _collapsed = 0;
    _steps = 0;
  }

  /// Emits the drawn spans of [pattern] along the polyline in [points].
  ///
  /// [scale] converts pattern units to the units [points] are in. Returns false
  /// when nothing was dashed and the caller must draw the geometry as it
  /// stands — an empty pattern, a pattern with no length, or a period under
  /// [collapsePx].
  ///
  /// The phase restarts at every vertex. That is DXF's default without
  /// LWPOLYLINE flag 128; the continuous-pattern flag is a field the DXF plan
  /// adds, not a decision made here.
  bool dashPolyline(Float64List points, int count, DashPattern pattern,
      double scale, Aabb2 clip, DashSpanEmit emit) {
    if (count < 2 || pattern.dashes.isEmpty) {
      return false;
    }
    // The cycle length comes from summing the array, not from
    // `pattern.totalLength`. Nothing enforces that the declared total agrees
    // with the dashes that produced it — a DXF importer is exactly the kind
    // of producer that could hand this class an inconsistent DashPattern —
    // and the cursor skip below assumes a period boundary is exactly where a
    // pass through `dashes` completes. Trust the array, not the label.
    final cycle = _dashCycle(pattern.dashes);
    if (!cycle.isFinite || cycle <= 0.0) {
      // No length to walk: this pattern was never dashed, so it is not a
      // collapse — the same reasoning that already exempts an empty
      // `dashes`. (A single [0.0] element reaches this branch too, which is
      // what keeps a degenerate "dot with no length" pattern from spinning
      // the cursor forever below.)
      return false;
    }
    final period = cycle * scale;
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

    // Skip whole cycles before `from` in one step rather than walking one
    // element at a time from zero: a 32,000-unit line clipped to a
    // 100-unit window must not cost thousands of iterations to reach it.
    // This is purely a cost optimisation — with `period` derived from the
    // array above, `floor(from / period) * period` always lands on a
    // breakpoint where `dashes` restarts at element 0, so the emitted spans
    // are identical to walking from zero. See patternStepCount.
    var cursor = (from / period).floorToDouble() * period;
    var element = 0;
    while (cursor < to) {
      _steps++;
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

  /// Emits the drawn spans of [pattern] along an arc, by angle.
  ///
  /// [r] is the arc's **screen** radius, so arc length is `r * |sweep|` in the
  /// same units the period is in. Returns false when the caller must draw the
  /// arc as it stands.
  bool dashArc(double cx, double cy, double r, double start, double sweep,
      DashPattern pattern, double scale, Aabb2 clip, DashArcEmit emit) {
    if (pattern.dashes.isEmpty) return false;
    // Same reasoning, and the same helper, as dashPolyline: the cycle comes
    // from summing the array, never from `pattern.totalLength`.
    final cycle = _dashCycle(pattern.dashes);
    if (!cycle.isFinite || cycle <= 0.0) return false;
    final period = cycle * scale;
    if (!period.isFinite || period < collapsePx) {
      _collapsed++;
      return false;
    }
    if (r <= 0 || !r.isFinite || sweep == 0.0) return false;

    final windows = circleClipWindows(cx, cy, r, clip, _windows);
    if (windows == 0) return true; // nothing visible; nothing to draw
    if (windows < 0) {
      // The whole circle is inside `clip`. Walk the arc's entire length
      // directly rather than synthesising a "-pi..3pi" window and routing it
      // through the angular intersection math below: that window is two full
      // turns wide, and along()'s modulo-2pi reduction maps both of its
      // endpoints to the *same* residue for any `start`, so the general
      // window-clipping code has no way to tell "the window wraps past the
      // arc's own start" apart from "the window is everything" — it always
      // takes the former reading and walks `[from, total*r]` instead of
      // `[0, total*r]`, silently dropping the arc's first `from` units. A
      // wholly-visible circle needs no clipping at all, so skip the angle
      // math and hand the walker the untrimmed range.
      _walkArcRange(
          r, start, sweep, 0.0, sweep.abs() * r, pattern, scale, period, emit);
      return true;
    }
    for (var w = 0; w < windows; w++) {
      _dashArcWindow(r, start, sweep, _windows[w * 2], _windows[w * 2 + 1],
          pattern, scale, period, emit);
    }
    return true;
  }

  /// Walks one angular window of the arc.
  ///
  /// The pattern's phase is measured from [start] along the arc, so clipping
  /// to a window shifts it exactly as clipping a segment does. Angles are
  /// reduced into the arc's own range before comparison, because a window
  /// from [circleClipWindows] may sit a full turn away from where the arc
  /// begins.
  void _dashArcWindow(
      double r,
      double start,
      double sweep,
      double windowStart,
      double windowEnd,
      DashPattern pattern,
      double scale,
      double period,
      DashArcEmit emit) {
    final direction = sweep < 0 ? -1.0 : 1.0;
    final total = sweep.abs();
    // The window, expressed as distances along the arc from `start`.
    double along(double angle) {
      var delta = (angle - start) * direction;
      while (delta < 0) {
        delta += 2 * math.pi;
      }
      while (delta > 2 * math.pi) {
        delta -= 2 * math.pi;
      }
      return delta * r;
    }

    final maxLen = total * r;
    final from = math.max(0.0, along(windowStart));
    final to = math.max(0.0, along(windowEnd));

    if (to > from) {
      // The common case: the window, expressed as an along-distance from
      // `start`, is one contiguous piece. Clamp to the arc's own length in
      // case the window (drawn from the full circle) extends past where a
      // partial arc actually ends.
      final clippedTo = math.min(maxLen, to);
      if (clippedTo > from) {
        _walkArcRange(
            r, start, sweep, from, clippedTo, pattern, scale, period, emit);
      }
      return;
    }
    if (to < from) {
      // The window wraps past `start`: `from` (measured going forward from
      // `start`) lands near the end of the turn and `to` lands near the
      // beginning, because `start` itself sits inside the visible window
      // rather than inside the excluded gap. A single [from, to] range
      // cannot represent that — it is two pieces of the arc, one on each
      // side of `start` — so walk both. Dropping the [0, to] piece here
      // silently under-draws every window whose visible cap straddles the
      // arc's own start angle, which for a full circle is any window that
      // contains angle 0.
      final clippedFrom = math.min(maxLen, from);
      if (clippedFrom < maxLen) {
        _walkArcRange(
            r, start, sweep, clippedFrom, maxLen, pattern, scale, period, emit);
      }
      final clippedTo = math.min(maxLen, to);
      if (clippedTo > 0.0) {
        _walkArcRange(
            r, start, sweep, 0.0, clippedTo, pattern, scale, period, emit);
      }
      return;
    }
    // to == from: a degenerate, zero-width window. A real window from
    // circleClipWindows always has positive angular extent, and the
    // full-turn case is handled entirely by the sentinel path in dashArc, so
    // this is not "the whole turn" — it is nothing.
  }

  /// Walks the pattern over `[from, to]`, both distances along the arc from
  /// `start` in the sweep direction, emitting each drawn span as an angle and
  /// sweep.
  ///
  /// Shared by the sentinel (whole-circle) and windowed paths of [dashArc] so
  /// there is exactly one place that turns arc-length distance into angle,
  /// and exactly one place that counts a step — see [patternStepCount].
  void _walkArcRange(
      double r,
      double start,
      double sweep,
      double from,
      double to,
      DashPattern pattern,
      double scale,
      double period,
      DashArcEmit emit) {
    final direction = sweep < 0 ? -1.0 : 1.0;
    // Skip whole cycles before `from` in one step, for the same reason
    // `_dashSegment` does: a circle with a ten-thousand-pixel screen radius,
    // clipped to a small window, must not cost thousands of iterations to
    // reach it.
    var cursor = (from / period).floorToDouble() * period;
    var element = 0;
    while (cursor < to) {
      _steps++;
      final raw = pattern.dashes[element];
      final span = raw.abs() * scale;
      final width = span == 0.0 ? 1e-9 : span;
      final end = cursor + width;
      if (raw >= 0 && end > from) {
        final a = math.max(cursor, from);
        final b = math.min(end, to);
        if (b > a) {
          emit(start + direction * (a / r), direction * ((b - a) / r));
        }
      }
      cursor = end;
      element = (element + 1) % pattern.dashes.length;
    }
  }
}
