import 'dart:typed_data';

/// Triangulates one simple closed loop by ear clipping.
///
/// [coords] is the boundary's stored `coords` -- interleaved x, y, with the
/// first point repeated as the last, which is how this model records
/// closedness. [count] is the stored point count including that duplicate; the
/// last point is ignored.
///
/// Returns triple-indices into [coords]' point numbering, every triangle wound
/// counter-clockwise whatever the input winding. Returns an **empty** list --
/// never throws, never guesses -- when the loop has fewer than three distinct
/// points, is self-intersecting, or is otherwise degenerate and cannot be
/// reduced. Self-intersection is checked explicitly up front, because the
/// clipper's own "no ear anywhere" stall does not see every case: see
/// `_hasSelfIntersection` for the fixture that motivates it.
///
/// A point repeated consecutively *within* the ring (not the store's closing
/// duplicate, which is dropped by `count - 1` before any of this) is
/// tolerated, not rejected: it collapses to the single vertex it geometrically
/// is, per the contract's "at least three distinct points". A plausible
/// DXF-imported boundary with a snap-rounding duplicate vertex must still
/// fill. See `_dedupeConsecutive`.
///
/// O(n^2). Room boundaries are tens of points, and this runs once per edit,
/// off the frame path -- see the plan's global constraints.
Int32List triangulateSimplePolygon(Float64List coords, int count) {
  final n = count - 1; // drop the duplicated closing point
  if (n < 3) return Int32List(0);

  final index = _dedupeConsecutive(coords, List<int>.generate(n, (i) => i));
  if (index.length < 3) return Int32List(0);
  // Reject a self-intersecting boundary before clipping. Plain ear-clipping's
  // "no ear anywhere" stall does not see every self-intersection: at n == 4 a
  // bow tie crosses between its two far edges, and every candidate diagonal
  // is adjacent to both, so no vertex ever falls inside a candidate ear and
  // the clipper never gets stuck. This check is orientation-independent, so
  // it runs before winding normalisation.
  if (_hasSelfIntersection(coords, index)) return Int32List(0);
  if (_signedArea(coords, index) < 0) {
    // Normalised, not rejected: DXF produces both windings, and every ear test
    // below assumes counter-clockwise.
    index.setAll(0, index.reversed.toList());
  }

  final out = <int>[];
  var guard = n * n; // the clipper must strictly shrink; this bounds a stall
  while (index.length > 3 && guard-- > 0) {
    var clipped = false;
    for (var i = 0; i < index.length; i++) {
      final a = index[(i - 1 + index.length) % index.length];
      final b = index[i];
      final c = index[(i + 1) % index.length];
      if (!_isEar(coords, index, a, b, c)) continue;
      out
        ..add(a)
        ..add(b)
        ..add(c);
      index.removeAt(i);
      clipped = true;
      break;
    }
    // No ear anywhere means the loop is not simple. Say so by returning
    // nothing rather than emitting a partial cover that looks like a drawing.
    if (!clipped) return Int32List(0);
  }
  if (index.length != 3) return Int32List(0);
  out
    ..add(index[0])
    ..add(index[1])
    ..add(index[2]);
  return Int32List.fromList(out);
}

/// Collapses a point repeated at consecutive ring positions (including the
/// wrap from the last position back to the first) into a single entry,
/// keeping the earlier index. This is a stored-value comparison, not a
/// geometric decision -- exact `==`, no tolerance, consistent with this
/// file's other exact comparisons -- because it is asking "are these two
/// stored coordinate pairs bit-for-bit the same point", not "are these two
/// distinct points close enough to treat as one".
///
/// Only *consecutive* duplicates collapse. A duplicate coordinate elsewhere
/// in the ring is a different situation -- a loop touching itself at a
/// vertex -- and stays exactly as many entries as stored; whether that is a
/// simple loop is for the ear-clipper (and `_hasSelfIntersection`) to decide,
/// not this function.
List<int> _dedupeConsecutive(Float64List c, List<int> raw) {
  final out = <int>[];
  for (final p in raw) {
    if (out.isNotEmpty && _samePoint(c, out.last, p)) continue;
    out.add(p);
  }
  if (out.length > 1 && _samePoint(c, out.first, out.last)) {
    out.removeLast();
  }
  return out;
}

bool _samePoint(Float64List c, int a, int b) =>
    c[a * 2] == c[b * 2] && c[a * 2 + 1] == c[b * 2 + 1];

double _signedArea(Float64List c, List<int> index) {
  var sum = 0.0;
  for (var i = 0; i < index.length; i++) {
    final p = index[i], q = index[(i + 1) % index.length];
    sum += c[p * 2] * c[q * 2 + 1] - c[q * 2] * c[p * 2 + 1];
  }
  return sum / 2;
}

double _cross(Float64List c, int a, int b, int d) =>
    (c[b * 2] - c[a * 2]) * (c[d * 2 + 1] - c[a * 2 + 1]) -
    (c[b * 2 + 1] - c[a * 2 + 1]) * (c[d * 2] - c[a * 2]);

/// True if any two non-adjacent edges of the loop `index` describes properly
/// cross. Adjacent edges (sharing an endpoint) are exempt -- that is an
/// ordinary vertex, not a crossing. Uses the same exact sign comparisons as
/// the rest of this file: this is a geometric decision, made without
/// tolerance, consistent with `_isEar` above.
bool _hasSelfIntersection(Float64List c, List<int> index) {
  final n = index.length;
  for (var i = 0; i < n; i++) {
    final a1 = index[i], a2 = index[(i + 1) % n];
    for (var j = i + 1; j < n; j++) {
      if (j == i + 1) continue; // shares a2
      if (i == 0 && j == n - 1) continue; // wraps around, shares a1
      final b1 = index[j], b2 = index[(j + 1) % n];
      if (_segmentsCross(c, a1, a2, b1, b2)) return true;
    }
  }
  return false;
}

/// True if segment (a,b) properly crosses segment (d,e) -- each endpoint of
/// one segment strictly separates the other. Endpoints touching or collinear
/// overlap do not count, so a shared or grazing vertex is not a crossing.
bool _segmentsCross(Float64List c, int a, int b, int d, int e) {
  final d1 = _cross(c, d, e, a);
  final d2 = _cross(c, d, e, b);
  final d3 = _cross(c, a, b, d);
  final d4 = _cross(c, a, b, e);
  return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
      ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0));
}

bool _isEar(Float64List c, List<int> index, int a, int b, int d) {
  final area = _cross(c, a, b, d);
  // Reflex or collinear: not an ear. `<= 0` rather than `< 0` so a collinear
  // run is skipped here and clipped from one of its neighbours instead, which
  // is why the collinear fixture does not stall.
  if (area <= 0) return false;
  for (final p in index) {
    if (p == a || p == b || p == d) continue;
    if (_cross(c, a, b, p) >= 0 &&
        _cross(c, b, d, p) >= 0 &&
        _cross(c, d, a, p) >= 0) {
      return false;
    }
  }
  return true;
}
