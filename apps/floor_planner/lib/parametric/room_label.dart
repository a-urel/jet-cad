// SPIKE 10 -- throwaway. The label point (Q4): the pole of inaccessibility
// of a ring minus its holes, polylabel-style (Mapbox's quadtree search with
// a best-first queue), and the centroid it is compared with.
import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'room_trace.dart';

/// Cells the last [poleOfInaccessibility] call probed, for the cost report.
int debugPoleCells = 0;

/// The signed distance from [p] to the region: positive inside [ring] and
/// outside every hole, negative elsewhere.
double signedDistance(
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

final class _Cell {
  _Cell(this.c, this.h, List<Vector2> ring, List<List<Vector2>> holes)
      : d = signedDistance(c, ring, holes) {
    max = d + h * math.sqrt2;
  }
  final Vector2 c;
  final double h; // half size
  final double d;
  late final double max;
}

/// The point of the region farthest from its boundary, to within
/// [precision] mm. The search runs in [ring]'s own frame, relative to its
/// first point, so a far-origin room costs what a near one does.
Vector2 poleOfInaccessibility(List<Vector2> ring, List<List<Vector2>> holes,
    {double precision = 1.0}) {
  final o = ring.first;
  final r = [for (final p in ring) p - o];
  final hs = [
    for (final h in holes) [for (final p in h) p - o]
  ];
  var minX = double.infinity, minY = double.infinity;
  var maxX = -double.infinity, maxY = -double.infinity;
  for (final p in r) {
    minX = math.min(minX, p.x);
    minY = math.min(minY, p.y);
    maxX = math.max(maxX, p.x);
    maxY = math.max(maxY, p.y);
  }
  final w = maxX - minX, ht = maxY - minY;
  final size = math.min(w, ht);
  debugPoleCells = 0;
  if (size == 0) return o + Vector2(minX, minY);
  var h = size / 2;
  final queue = <_Cell>[];
  for (var x = minX; x < maxX; x += size) {
    for (var y = minY; y < maxY; y += size) {
      queue.add(_Cell(Vector2(x + h, y + h), h, r, hs));
      debugPoleCells++;
    }
  }
  // Start from the centroid, as polylabel does.
  var best = _Cell(centroid(r), 0, r, hs);
  final box = _Cell(Vector2(minX + w / 2, minY + ht / 2), 0, r, hs);
  if (box.d > best.d) best = box;
  while (queue.isNotEmpty) {
    // Best-first: the cell whose bound is highest.
    var k = 0;
    for (var i = 1; i < queue.length; i++) {
      if (queue[i].max > queue[k].max) k = i;
    }
    final cell = queue.removeAt(k);
    if (cell.d > best.d) best = cell;
    if (cell.max - best.d <= precision) continue;
    h = cell.h / 2;
    for (final (dx, dy) in const [(-1, -1), (1, -1), (-1, 1), (1, 1)]) {
      queue.add(_Cell(cell.c + Vector2(dx * h, dy * h), h, r, hs));
      debugPoleCells++;
    }
  }
  return best.c + o;
}

/// The area centroid of a simple ring (no holes).
Vector2 centroid(List<Vector2> ring) {
  final o = ring.first;
  var a = 0.0, cx = 0.0, cy = 0.0;
  for (var i = 0; i < ring.length; i++) {
    final p = ring[i] - o, q = ring[(i + 1) % ring.length] - o;
    final f = p.x * q.y - q.x * p.y;
    a += f;
    cx += (p.x + q.x) * f;
    cy += (p.y + q.y) * f;
  }
  return o + Vector2(cx / (3 * a), cy / (3 * a));
}
