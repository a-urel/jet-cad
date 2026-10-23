// The alignment-guide solver (alignment guides spec, "Candidates on one
// axis"). Pure Dart: it knows boxes and handles, not the canvas.
//
// The solve allocates nothing: best-candidate state lives in the
// caller-owned [GuideSolution] (primitive typed lists sized once at its
// construction) and in locals of primitive type.
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart' show Handle, Tolerance;

/// The capture aperture for a mouse, in screen pixels (alignment guides
/// spec, Candidates step 3). The caller divides by the camera scale.
const double kGuideAperturePixels = 6.0;

/// The capture aperture for touch, in screen pixels (spec, Candidates
/// step 3).
const double kGuideTouchAperturePixels = 10.0;

/// The capacity of [GuideSolution.lines] and [GuideSolution.marks], each.
/// Past it further entries are dropped silently.
const int kGuideCapacity = 16;

/// The references: box i is `boxes[4i..4i+3]` = minX, minY, maxX, maxY.
final class GuideReferences {
  GuideReferences(this.boxes, this.handles);
  final Float64List boxes;
  final List<Handle> handles;
  int get length => handles.length;
}

/// What a captured axis aligned to (alignment guides spec, Candidates).
/// The declaration order is the tie order (step 4).
enum GuideKind { edge, centre, between, continuing }

/// The result of [solveGuides]. Caller-owned and reset by every solve, so a
/// drag reuses one instance and the solve allocates nothing.
final class GuideSolution {
  /// The shift to apply to the moving box: per axis the captured offset, or
  /// the caller's fallback.
  double dx = 0, dy = 0;
  bool capturedX = false, capturedY = false;
  GuideKind? kindX, kindY;

  /// The winning candidate's reference (the lower of a pair); null when the
  /// axis did not capture.
  Handle? refX, refY;

  /// Lines: `[axis (0: x, a vertical line; 1: y), coord, from, to]` each.
  /// `from`/`to` span the perpendicular axis from the moving box to the
  /// farthest aligned reference, in world units.
  final Float64List lines = Float64List(4 * kGuideCapacity);
  int lineCount = 0;

  /// Gap marks: `[axis, gapStart, gapEnd, at]` each; `at` is the middle of
  /// the perpendicular overlap of the two boxes beside the gap.
  final Float64List marks = Float64List(4 * kGuideCapacity);
  int markCount = 0;

  /// Clears the result for the next solve.
  void reset() {
    dx = 0;
    dy = 0;
    capturedX = false;
    capturedY = false;
    kindX = null;
    kindY = null;
    refX = null;
    refY = null;
    lineCount = 0;
    markCount = 0;
    for (var k = 0; k < 4; k++) {
      _has[k] = 0;
    }
    _nL = -1;
    _nR = -1;
    _nA = -1;
    _nR2 = -1;
  }

  // Best candidate per slot k = axis * 2 + s; s 0 is the best of any kind,
  // s 1 the best non-spacing one (the recheck's fallback, Candidates
  // step 5). Per slot: kind, pair index, handle, second handle, and the two
  // row members to recheck (-1 when none).
  static const int _stride = 6;
  final Uint8List _has = Uint8List(4);
  final Float64List _bestAbs = Float64List(4);
  final Float64List _bestO = Float64List(4);
  final Int64List _best = Int64List(4 * _stride);

  // Scratch of one neighbour search: L, R and their outer neighbours A, R2
  // (reference indices, -1 when absent).
  int _nL = -1, _nR = -1, _nA = -1, _nR2 = -1;

  /// Offers a candidate on [axis]. Beyond the aperture it is dropped.
  void _offer(int axis, double o, int kind, int pair, int h1, int h2, int row1,
      int row2, double aperture, double eps) {
    final ao = o < 0 ? -o : o;
    if (ao > aperture) return;
    _consider(axis * 2, ao, o, kind, pair, h1, h2, row1, row2, eps);
    if (kind < 2) {
      _consider(axis * 2 + 1, ao, o, kind, pair, h1, h2, row1, row2, eps);
    }
  }

  void _consider(int k, double ao, double o, int kind, int pair, int h1, int h2,
      int row1, int row2, double eps) {
    if (!_beats(k, ao, o, kind, pair, h1, h2, eps)) return;
    _has[k] = 1;
    _bestAbs[k] = ao;
    _bestO[k] = o;
    final s = k * _stride;
    _best[s] = kind;
    _best[s + 1] = pair;
    _best[s + 2] = h1;
    _best[s + 3] = h2;
    _best[s + 4] = row1;
    _best[s + 5] = row2;
  }

  /// The total order of Candidates step 4: smallest |o|, then kind, pair
  /// index, handle, second handle, and a negative offset before a positive.
  bool _beats(int k, double ao, double o, int kind, int pair, int h1, int h2,
      double eps) {
    if (_has[k] == 0) return true;
    final bo = _bestAbs[k];
    if (ao < bo - eps) return true;
    if (ao > bo + eps) return false;
    final s = k * _stride;
    if (kind != _best[s]) return kind < _best[s];
    if (pair != _best[s + 1]) return pair < _best[s + 1];
    if (h1 != _best[s + 2]) return h1 < _best[s + 2];
    if (h2 != _best[s + 3]) return h2 < _best[s + 3];
    return o < _bestO[k];
  }

  /// Adds a line, merging into an existing one on the same axis at the same
  /// coordinate (within [eps]) by the union of their extents.
  void _addLine(int axis, double coord, double from, double to, double eps) {
    for (var j = 0; j < lineCount; j++) {
      final b = 4 * j;
      if (lines[b] != axis) continue;
      final d = lines[b + 1] - coord;
      if ((d < 0 ? -d : d) > eps) continue;
      if (from < lines[b + 2]) lines[b + 2] = from;
      if (to > lines[b + 3]) lines[b + 3] = to;
      return;
    }
    if (lineCount >= kGuideCapacity) return;
    final b = 4 * lineCount;
    lines[b] = axis.toDouble();
    lines[b + 1] = coord;
    lines[b + 2] = from;
    lines[b + 3] = to;
    lineCount++;
  }

  /// Adds a gap mark, skipping an identical one already present (a
  /// `between` and a `continuing` candidate can share a gap).
  void _addMark(int axis, double start, double end, double at, double eps) {
    for (var j = 0; j < markCount; j++) {
      final b = 4 * j;
      if (marks[b] == axis &&
          (marks[b + 1] - start).abs() <= eps &&
          (marks[b + 2] - end).abs() <= eps &&
          (marks[b + 3] - at).abs() <= eps) {
        return;
      }
    }
    if (markCount >= kGuideCapacity) return;
    final b = 4 * markCount;
    marks[b] = axis.toDouble();
    marks[b + 1] = start;
    marks[b + 2] = end;
    marks[b + 3] = at;
    markCount++;
  }
}

/// Solves the guides for the moving box `(minX, minY, maxX, maxY)` at the
/// raw delta, against [refs], into [out] (alignment guides spec, Candidates
/// on one axis, steps 1-6).
///
/// A reference in [moving] is skipped. An axis with `free… == false` never
/// captures and takes its fallback. Per axis, `out.dx`/`out.dy` is the
/// captured offset, or the caller's `fallbackDx`/`fallbackDy`. Allocates
/// nothing.
void solveGuides(
  GuideReferences refs, {
  required double minX,
  required double minY,
  required double maxX,
  required double maxY,
  required double aperture,
  required bool freeX,
  required bool freeY,
  required double fallbackDx,
  required double fallbackDy,
  required Set<Handle> moving,
  required GuideSolution out,
}) {
  out.reset();
  final eps = Tolerance.standard.linear;

  // Steps 1-4: both axes, once, on the box at the raw delta.
  if (freeX) {
    _solveAxis(refs, 0, minX, maxX, minY, maxY, aperture, moving, out, eps);
  }
  if (freeY) {
    _solveAxis(refs, 1, minY, maxY, minX, maxX, aperture, moving, out, eps);
  }

  // Step 5: the provisional delta, then simultaneous rechecks. Each axis
  // reads the provisional box of the other, so their order does not matter.
  final hasX = out._has[0] == 1;
  final hasY = out._has[2] == 1;
  final pdx = hasX ? out._bestO[0] : fallbackDx;
  final pdy = hasY ? out._bestO[2] : fallbackDy;
  var slotX = hasX ? 0 : -1;
  var slotY = hasY ? 2 : -1;
  if (hasX &&
      out._best[0] >= 2 &&
      !_rowHolds(refs, out, 0, 0, minY + pdy, maxY + pdy, eps)) {
    slotX = out._has[1] == 1 ? 1 : -1;
  }
  if (hasY &&
      out._best[2 * GuideSolution._stride] >= 2 &&
      !_rowHolds(refs, out, 2, 1, minX + pdx, maxX + pdx, eps)) {
    slotY = out._has[3] == 1 ? 3 : -1;
  }
  if (slotX >= 0) {
    out.capturedX = true;
    out.dx = out._bestO[slotX];
    final s = slotX * GuideSolution._stride;
    out.kindX = GuideKind.values[out._best[s]];
    out.refX = Handle(out._best[s + 2]);
  } else {
    out.dx = fallbackDx;
  }
  if (slotY >= 0) {
    out.capturedY = true;
    out.dy = out._bestO[slotY];
    final s = slotY * GuideSolution._stride;
    out.kindY = GuideKind.values[out._best[s]];
    out.refY = Handle(out._best[s + 2]);
  } else {
    out.dy = fallbackDy;
  }

  // Step 6: lines and marks for the final box.
  final fx0 = minX + out.dx, fx1 = maxX + out.dx;
  final fy0 = minY + out.dy, fy1 = maxY + out.dy;
  if (out.capturedX) {
    _draw(refs, 0, fx0, fx1, fy0, fy1, moving, out, eps);
  }
  if (out.capturedY) {
    _draw(refs, 1, fy0, fy1, fx0, fx1, moving, out, eps);
  }
}

/// The overlap of two intervals exceeds [eps].
bool _overlaps(double a0, double a1, double b0, double b1, double eps) {
  final lo = a0 > b0 ? a0 : b0;
  final hi = a1 < b1 ? a1 : b1;
  return hi - lo > eps;
}

/// The middle of the overlap of two intervals.
double _midOverlap(double a0, double a1, double b0, double b1) {
  final lo = a0 > b0 ? a0 : b0;
  final hi = a1 < b1 ? a1 : b1;
  return (lo + hi) * 0.5;
}

/// A position of an interval: 0 min, 1 centre, 2 max.
double _pos(double lo, double hi, int m) =>
    m == 0 ? lo : (m == 1 ? (lo + hi) * 0.5 : hi);

/// Whether the row members of slot [k]'s winner still overlap the
/// perpendicular interval `[plo, phi]` (Candidates step 5).
bool _rowHolds(GuideReferences refs, GuideSolution out, int k, int axis,
    double plo, double phi, double eps) {
  final b = refs.boxes;
  final s = k * GuideSolution._stride;
  for (var j = 4; j <= 5; j++) {
    final i = out._best[s + j];
    if (i < 0) continue;
    if (!_overlaps(b[4 * i + 1 - axis], b[4 * i + 3 - axis], plo, phi, eps)) {
      return false;
    }
  }
  return true;
}

/// Finds, for the box `[lo, hi]` x `[plo, phi]` on [a], the row neighbours
/// L and R and their outer neighbours A and R2 into the scratch of [out]
/// (Candidates step 2). Ties go to the lower handle.
void _findNeighbours(GuideReferences refs, int a, double lo, double hi,
    double plo, double phi, Set<Handle> moving, GuideSolution out, double eps) {
  final b = refs.boxes;
  final hs = refs.handles;
  final n = refs.length;
  var li = -1, ri = -1;
  var lmax = 0.0, rmin = 0.0;
  var lh = 0, rh = 0;
  for (var i = 0; i < n; i++) {
    final h = hs[i];
    if (moving.contains(h)) continue;
    if (!_overlaps(b[4 * i + 1 - a], b[4 * i + 3 - a], plo, phi, eps)) {
      continue;
    }
    final mn = b[4 * i + a], mx = b[4 * i + 2 + a];
    if (mx <= lo + eps &&
        (li < 0 || mx > lmax + eps || (mx >= lmax - eps && h.value < lh))) {
      li = i;
      lmax = mx;
      lh = h.value;
    }
    if (mn >= hi - eps &&
        (ri < 0 || mn < rmin - eps || (mn <= rmin + eps && h.value < rh))) {
      ri = i;
      rmin = mn;
      rh = h.value;
    }
  }
  out._nL = li;
  out._nR = ri;
  out._nA = -1;
  out._nR2 = -1;
  if (li >= 0) {
    out._nA = _outer(refs, a, li, true, moving, eps);
  }
  if (ri >= 0) {
    out._nR2 = _outer(refs, a, ri, false, moving, eps);
  }
}

/// [base]'s neighbour beyond it, in [base]'s own row: on the low side the
/// reference with the largest `max <= base.min + eps`, on the high side the
/// one with the smallest `min >= base.max - eps`; its perpendicular
/// interval overlaps [base]'s by more than [eps]. Ties go to the lower
/// handle. -1 when none.
int _outer(GuideReferences refs, int a, int base, bool low, Set<Handle> moving,
    double eps) {
  final b = refs.boxes;
  final hs = refs.handles;
  final n = refs.length;
  final p0 = b[4 * base + 1 - a], p1 = b[4 * base + 3 - a];
  final edge = low ? b[4 * base + a] : b[4 * base + 2 + a];
  var best = -1;
  var bestV = 0.0;
  var bestH = 0;
  for (var j = 0; j < n; j++) {
    if (j == base) continue;
    final h = hs[j];
    if (moving.contains(h)) continue;
    if (!_overlaps(b[4 * j + 1 - a], b[4 * j + 3 - a], p0, p1, eps)) continue;
    final mn = b[4 * j + a], mx = b[4 * j + 2 + a];
    if (low) {
      if (mx <= edge + eps &&
          (best < 0 ||
              mx > bestV + eps ||
              (mx >= bestV - eps && h.value < bestH))) {
        best = j;
        bestV = mx;
        bestH = h.value;
      }
    } else {
      if (mn >= edge - eps &&
          (best < 0 ||
              mn < bestV - eps ||
              (mn <= bestV + eps && h.value < bestH))) {
        best = j;
        bestV = mn;
        bestH = h.value;
      }
    }
  }
  return best;
}

/// The `between` offset for the neighbours in [out], or NaN when there is
/// none: both neighbours present and each resulting gap greater than [eps]
/// (which also implies the box fits, `R.min - L.max >= hi - lo`).
double _betweenOffset(GuideReferences refs, int a, GuideSolution out, double lo,
    double hi, double eps) {
  if (out._nL < 0 || out._nR < 0) return double.nan;
  final lmax = refs.boxes[4 * out._nL + 2 + a];
  final rmin = refs.boxes[4 * out._nR + a];
  final gap = (rmin - lmax - (hi - lo)) * 0.5;
  if (!(gap > eps)) return double.nan;
  return ((rmin + lmax) - (lo + hi)) * 0.5;
}

/// The `continuing`-on-the-low-side offset, or NaN: `L` and its neighbour
/// `A` with a gap greater than [eps] (a touching pair never counts).
double _continueLowOffset(
    GuideReferences refs, int a, GuideSolution out, double lo, double eps) {
  if (out._nL < 0 || out._nA < 0) return double.nan;
  final b = refs.boxes;
  final g = b[4 * out._nL + a] - b[4 * out._nA + 2 + a];
  if (!(g > eps)) return double.nan;
  return (b[4 * out._nL + 2 + a] + g) - lo;
}

/// The mirror of [_continueLowOffset] on the high side.
double _continueHighOffset(
    GuideReferences refs, int a, GuideSolution out, double hi, double eps) {
  if (out._nR < 0 || out._nR2 < 0) return double.nan;
  final b = refs.boxes;
  final g = b[4 * out._nR2 + a] - b[4 * out._nR + 2 + a];
  if (!(g > eps)) return double.nan;
  return (b[4 * out._nR + a] - g) - hi;
}

/// Candidates steps 1-4 on one axis: [lo, hi] is the moving box's interval
/// on it, [plo, phi] its perpendicular one.
void _solveAxis(
    GuideReferences refs,
    int a,
    double lo,
    double hi,
    double plo,
    double phi,
    double aperture,
    Set<Handle> moving,
    GuideSolution out,
    double eps) {
  final b = refs.boxes;
  final hs = refs.handles;
  final n = refs.length;

  // Step 1: nine pairs per reference.
  for (var i = 0; i < n; i++) {
    final h = hs[i];
    if (moving.contains(h)) continue;
    final rlo = b[4 * i + a], rhi = b[4 * i + 2 + a];
    for (var m = 0; m < 3; m++) {
      final mp = _pos(lo, hi, m);
      for (var r = 0; r < 3; r++) {
        // Centre pairs are those involving a centre; edge pairs are
        // edge-to-edge.
        final kind = (m == 1 || r == 1) ? 1 : 0;
        out._offer(a, _pos(rlo, rhi, r) - mp, kind, m * 3 + r, h.value, 0, -1,
            -1, aperture, eps);
      }
    }
  }

  // Step 2: equal spacing.
  _findNeighbours(refs, a, lo, hi, plo, phi, moving, out, eps);
  final li = out._nL, ri = out._nR, ai = out._nA, r2 = out._nR2;
  final between = _betweenOffset(refs, a, out, lo, hi, eps);
  if (!between.isNaN) {
    final hl = hs[li].value, hr = hs[ri].value;
    out._offer(a, between, 2, 0, hl < hr ? hl : hr, hl < hr ? hr : hl, li, ri,
        aperture, eps);
  }
  final low = _continueLowOffset(refs, a, out, lo, eps);
  if (!low.isNaN) {
    final ha = hs[ai].value, hl = hs[li].value;
    out._offer(a, low, 3, 0, ha < hl ? ha : hl, ha < hl ? hl : ha, li, -1,
        aperture, eps);
  }
  final high = _continueHighOffset(refs, a, out, hi, eps);
  if (!high.isNaN) {
    final hr = hs[ri].value, h2 = hs[r2].value;
    out._offer(a, high, 3, 0, hr < h2 ? hr : h2, hr < h2 ? h2 : hr, ri, -1,
        aperture, eps);
  }
}

/// Candidates step 6 on one captured axis: draws every candidate whose
/// offset is now zero within epsilon, for the final box `[lo, hi]` x
/// `[plo, phi]`.
void _draw(GuideReferences refs, int a, double lo, double hi, double plo,
    double phi, Set<Handle> moving, GuideSolution out, double eps) {
  final b = refs.boxes;
  final hs = refs.handles;
  final n = refs.length;

  for (var i = 0; i < n; i++) {
    if (moving.contains(hs[i])) continue;
    final rlo = b[4 * i + a], rhi = b[4 * i + 2 + a];
    final from = plo < b[4 * i + 1 - a] ? plo : b[4 * i + 1 - a];
    final to = phi > b[4 * i + 3 - a] ? phi : b[4 * i + 3 - a];
    for (var m = 0; m < 3; m++) {
      final mp = _pos(lo, hi, m);
      for (var r = 0; r < 3; r++) {
        final rp = _pos(rlo, rhi, r);
        final d = rp - mp;
        if ((d < 0 ? -d : d) <= eps) out._addLine(a, rp, from, to, eps);
      }
    }
  }

  _findNeighbours(refs, a, lo, hi, plo, phi, moving, out, eps);
  final li = out._nL, ri = out._nR, ai = out._nA, r2 = out._nR2;

  final between = _betweenOffset(refs, a, out, lo, hi, eps);
  if (between.abs() <= eps) {
    final l = 4 * li, r = 4 * ri;
    out._addMark(a, b[l + 2 + a], lo,
        _midOverlap(b[l + 1 - a], b[l + 3 - a], plo, phi), eps);
    out._addMark(a, hi, b[r + a],
        _midOverlap(plo, phi, b[r + 1 - a], b[r + 3 - a]), eps);
  }
  final low = _continueLowOffset(refs, a, out, lo, eps);
  if (low.abs() <= eps) {
    final l = 4 * li, p = 4 * ai;
    out._addMark(
        a,
        b[p + 2 + a],
        b[l + a],
        _midOverlap(b[p + 1 - a], b[p + 3 - a], b[l + 1 - a], b[l + 3 - a]),
        eps);
    out._addMark(a, b[l + 2 + a], lo,
        _midOverlap(b[l + 1 - a], b[l + 3 - a], plo, phi), eps);
  }
  final high = _continueHighOffset(refs, a, out, hi, eps);
  if (high.abs() <= eps) {
    final r = 4 * ri, q = 4 * r2;
    out._addMark(a, hi, b[r + a],
        _midOverlap(plo, phi, b[r + 1 - a], b[r + 3 - a]), eps);
    out._addMark(
        a,
        b[r + 2 + a],
        b[q + a],
        _midOverlap(b[r + 1 - a], b[r + 3 - a], b[q + 1 - a], b[q + 3 - a]),
        eps);
  }
}
