// Where a room's labels go and what the area label reads (spec 10 D10,
// D11): the pole of inaccessibility of the room's face, and the area in the
// page's unit. No Flutter import: this file is Dart over `package:jet_cad_2d`
// and `vector_math` only (spec 10 D1).
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart' show DisplayUnit;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'room_trace.dart' show distToSegment, pointInRing;

/// The point of the face [ring] minus [holes] farthest from its boundary,
/// to within [precision] mm (spec 10 D10, R-12), and its distance to that
/// boundary.
///
/// Polylabel's quadtree search: the ring's box is covered by square cells,
/// and the cell whose bound (its centre's distance plus its half-diagonal)
/// is highest is taken next from a binary heap, and split in four while its
/// bound beats the best distance found by more than [precision]. The search
/// runs relative to the ring's first vertex, so a far-origin room costs
/// what a near one does, and its point is exact to the same few ulps.
///
/// Not the centroid or the box centre: on a thin L both lie outside the
/// face (the spike's Q4a). [ring] must hold three points or more;
/// [precision] must be positive.
({Vector2 point, double distance}) poleOfInaccessibility(
    List<Vector2> ring, List<List<Vector2>> holes,
    {double precision = 10}) {
  final o = ring.first;
  final r = [for (final p in ring) p - o];
  final hs = [
    for (final h in holes) [for (final p in h) p - o],
  ];
  var minX = double.infinity, minY = double.infinity;
  var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
  for (final p in r) {
    minX = math.min(minX, p.x);
    minY = math.min(minY, p.y);
    maxX = math.max(maxX, p.x);
    maxY = math.max(maxY, p.y);
  }
  final w = maxX - minX, ht = maxY - minY;
  final size = math.min(w, ht);
  _Cell cell(double x, double y, double half) =>
      _Cell(x, y, half, _signedDistance(Vector2(x, y), r, hs));
  if (!(size > 0) || !size.isFinite) {
    final c = cell(minX, minY, 0);
    return (point: Vector2(c.x, c.y) + o, distance: c.d);
  }

  final queue = _MaxHeap();
  final half = size / 2;
  for (var x = minX; x < maxX; x += size) {
    for (var y = minY; y < maxY; y += size) {
      queue.push(cell(x + half, y + half, half));
    }
  }
  // Polylabel's first guesses: the centroid, then the box centre.
  final c0 = _centroid(r);
  var best = cell(c0.x, c0.y, 0);
  final box = cell(minX + w / 2, minY + ht / 2, 0);
  if (box.d > best.d) best = box;

  while (queue.isNotEmpty) {
    final c = queue.pop();
    if (c.d > best.d) best = c;
    // Written negated, so that a NaN bound ends the split, not the search.
    if (!(c.max - best.d > precision)) continue;
    final h = c.half / 2;
    queue
      ..push(cell(c.x - h, c.y - h, h))
      ..push(cell(c.x + h, c.y - h, h))
      ..push(cell(c.x - h, c.y + h, h))
      ..push(cell(c.x + h, c.y + h, h));
  }
  return (point: Vector2(best.x, best.y) + o, distance: best.d);
}

/// The distance from [p] to the boundary of [ring] minus [holes]: positive
/// inside the face, negative outside it or inside a hole.
double _signedDistance(
    Vector2 p, List<Vector2> ring, List<List<Vector2>> holes) {
  var inside = pointInRing(p, ring);
  var d = double.infinity;
  for (final r in [ring, ...holes]) {
    for (var i = 0; i < r.length; i++) {
      d = math.min(d, distToSegment(p, r[i], r[(i + 1) % r.length]));
    }
  }
  for (final h in holes) {
    if (pointInRing(p, h)) inside = false;
  }
  return inside ? d : -d;
}

/// The area centroid of ring [r] (its holes ignored), or its first point
/// when it has no area.
Vector2 _centroid(List<Vector2> r) {
  var a = 0.0, cx = 0.0, cy = 0.0;
  for (var i = 0; i < r.length; i++) {
    final p = r[i], q = r[(i + 1) % r.length];
    final f = p.x * q.y - q.x * p.y;
    a += f;
    cx += (p.x + q.x) * f;
    cy += (p.y + q.y) * f;
  }
  if (a == 0) return r.first.clone();
  return Vector2(cx / (3 * a), cy / (3 * a));
}

/// A square cell of the search: its centre, half its side, its centre's
/// signed distance and the best distance any point in it could have.
final class _Cell {
  _Cell(this.x, this.y, this.half, this.d) : max = d + half * math.sqrt2;

  final double x, y, half, d, max;
}

/// A binary max-heap of cells by [_Cell.max].
final class _MaxHeap {
  final List<_Cell> _a = [];

  bool get isNotEmpty => _a.isNotEmpty;

  void push(_Cell c) {
    _a.add(c);
    var i = _a.length - 1;
    while (i > 0) {
      final parent = (i - 1) >> 1;
      if (!(_a[i].max > _a[parent].max)) break;
      final t = _a[i];
      _a[i] = _a[parent];
      _a[parent] = t;
      i = parent;
    }
  }

  _Cell pop() {
    final top = _a.first;
    final last = _a.removeLast();
    if (_a.isNotEmpty) {
      _a[0] = last;
      var i = 0;
      while (true) {
        final l = 2 * i + 1, r = l + 1;
        var m = i;
        if (l < _a.length && _a[l].max > _a[m].max) m = l;
        if (r < _a.length && _a[r].max > _a[m].max) m = r;
        if (m == i) break;
        final t = _a[i];
        _a[i] = _a[m];
        _a[m] = t;
        i = m;
      }
    }
    return top;
  }
}

/// The area label's string for [mm2] mm² in the page's [unit] (spec 10
/// D11, decision 6): m² for millimetres, centimetres and metres, ft² for
/// inches and feet-inches (`304.8 × 304.8` mm² to the square foot, in double
/// arithmetic); always two decimals, `.` as the separator, no grouping.
String formatArea(double mm2, DisplayUnit unit) => switch (unit) {
      DisplayUnit.millimeters ||
      DisplayUnit.centimeters ||
      DisplayUnit.meters =>
        '${(mm2 / 1e6).toStringAsFixed(2)} m²',
      DisplayUnit.inches ||
      DisplayUnit.feetInches =>
        '${(mm2 / (304.8 * 304.8)).toStringAsFixed(2)} ft²',
    };
