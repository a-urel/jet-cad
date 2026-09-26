// The room tracer (spec 10 D5, D6): a planar arrangement of the walls'
// uncut bands and the separators' segments, walked as half-edge faces. The
// seed's face of that arrangement is the room. No Flutter import: this file
// is Dart over `package:jet_cad_2d` and `vector_math` only (spec 10 D1).
//
// Why the face is the right region (the spike's Q1): no input edge crosses
// the component of the plane outside every band that holds the seed, and no
// path leaves that component without crossing an edge. So the
// arrangement's face is the union's hole, and no polygon union is computed;
// a separator, which has no area, is an ordinary edge.
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'room_inputs.dart';

/// What [traceRoom] found for a seed.
sealed class TraceResult {
  const TraceResult();
}

/// The seed lies inside [source]'s band, or within `roomTrace.linear` of
/// one of its edges or of its separator's segment. When several inputs hold
/// the seed, [source] is the lowest handle among them (Ruling 10-7).
final class SeedInWall extends TraceResult {
  const SeedInWall(this.source);

  final Handle source;

  @override
  String toString() => 'SeedInWall(${source.toHex()})';
}

/// No bounded face holds the seed: the walls and separators do not close
/// around it.
final class Unbounded extends TraceResult {
  const Unbounded();

  @override
  String toString() => 'Unbounded()';
}

/// The seed's face (spec 10 D5, D6): its outer ring and its holes, the
/// inputs that carry each of their edges, and their areas.
///
/// The output is canonical (Ruling 10-7): a function of the input set and
/// the seed only. Each ring runs anticlockwise from its least vertex in
/// `(x, y)` order in the seed-relative frame; the holes are ordered by
/// their first vertex in the same order; the sources move with their edges,
/// each set ascending by handle.
final class Traced extends TraceResult {
  Traced(
      List<Vector2> ring,
      List<Set<Handle>> ringSources,
      List<List<Vector2>> holes,
      List<List<Set<Handle>>> holeSources,
      this.outerArea,
      List<double> holeAreas)
      : ring = List.unmodifiable(ring),
        ringSources = List.unmodifiable(ringSources),
        holes = List.unmodifiable(
            [for (final h in holes) List<Vector2>.unmodifiable(h)]),
        holeSources = List.unmodifiable(
            [for (final s in holeSources) List<Set<Handle>>.unmodifiable(s)]),
        holeAreas = List.unmodifiable(holeAreas);

  /// The outer ring, world points, anticlockwise, no closing duplicate.
  final List<Vector2> ring;

  /// `ringSources[i]`: the inputs whose segments carry edge `i`, from
  /// `ring[i]` to `ring[i + 1]` (the last to `ring[0]`).
  final List<Set<Handle>> ringSources;

  /// Each hole, world points, anticlockwise, no closing duplicate.
  final List<List<Vector2>> holes;

  /// `holeSources[k][i]`: the inputs that carry edge `i` of hole `k`.
  final List<List<Set<Handle>>> holeSources;

  /// The outer ring's area, mm², by the shoelace in the seed-relative
  /// frame.
  final double outerArea;

  /// Each hole's area, mm², positive, likewise.
  final List<double> holeAreas;

  /// The net area, mm²: [outerArea] less [holeAreas], in their order.
  double get area => outerArea - holeAreas.fold(0.0, (a, b) => a + b);

  @override
  String toString() => 'Traced(area $area, ${ring.length} ring points, '
      '${holes.length} holes)';
}

/// The segments every [traceRoom] call has taken in (step 3 of spec 10 D5,
/// after the short ones are dropped), summed: the tracer's cost for tests
/// that pin it (D7's counter). Never reset by the library.
///
/// For tests only. It carries no `@visibleForTesting`: that annotation
/// lives in `package:meta` or Flutter, and this file imports neither (as
/// `RoomInputs.debugRebuilds`).
int debugTracedSegments = 0;

/// Finds the room around [seed] among [inputs] (spec 10 D5, D6):
///
/// 1. **Local frame.** Every point is taken relative to [seed] first, so
///    the arithmetic runs on numbers the size of a building, not of the far
///    origin.
/// 2. **The seed in a wall.** The seed inside a closed input (crossing
///    number), or within `roomTrace.linear` of any input segment, is
///    [SeedInWall], naming the lowest-handle such input.
/// 3. **Segments**, each tagged with its source; one no longer than
///    `roomTrace.linear` is dropped. Inputs are taken in ascending source
///    order, so the output is a function of the input set.
/// 4. **Splits**, by a sweep over the segments sorted by `minX` with a box
///    reject on `y`: each endpoint of one segment within `roomTrace.linear`
///    of another splits the other there (a T butt on a through face, a
///    separator's end on a face, a collinear overlap); otherwise, unless
///    the two are parallel within `roomTrace.angular`, a proper crossing
///    splits both.
/// 5. **Vertices** within `roomTrace.linear` of an earlier vertex are that
///    vertex (a grid hash, the lowest index winning); duplicate edges merge
///    and keep every source.
/// 6. **Faces.** Half-edges around each vertex sorted by angle; the edge
///    after `u → v` is the one leaving `v` just clockwise of `v → u`, so
///    every face lies to the left of its walk and bounded faces walk
///    anticlockwise.
/// 7. **The seed's face**: the anticlockwise cycle of least area holding
///    the seed. None: [Unbounded].
/// 8. **Holes** (D6): every other connected component whose outer contour
///    (its most negative cycle) lies inside the outer ring and inside no
///    bounded face of a third component that does not hold the seed. A
///    component with no area (a free separator) is not a hole.
/// 9. **Clean-up**: spikes (`u → v → u`, a dangling separator end), then
///    vertices collinear within `roomTrace.linear`; holes reversed to
///    anticlockwise, their sources moving with their edges; the canonical
///    order of Ruling 10-7; areas by the shoelace in the local frame.
TraceResult traceRoom(Vector2 seed, List<RoomInput> inputs) {
  final tol = roomTrace.linear;

  // 1. The local frame: world point p is p - o here, and the seed is s0.
  final o = seed.clone();
  final s0 = Vector2.zero();

  // Inputs in ascending source order (3), relative to the seed (1).
  final sorted = [...inputs]
    ..sort((a, b) => a.source.value.compareTo(b.source.value));
  final local = [
    for (final input in sorted) [for (final p in input.points) p - o],
  ];

  // 2. The seed in a wall: the first input in ascending order that holds it.
  for (var k = 0; k < sorted.length; k++) {
    final pts = local[k];
    final n = pts.length;
    final closed = sorted[k].closed;
    if (closed && n >= 3 && pointInRing(s0, pts)) {
      return SeedInWall(sorted[k].source);
    }
    final m = closed ? n : n - 1;
    for (var i = 0; i < m; i++) {
      if (distToSegment(s0, pts[i], pts[(i + 1) % n]) <= tol) {
        return SeedInWall(sorted[k].source);
      }
    }
  }

  // 3. Segments.
  final segs = <_Seg>[];
  for (var k = 0; k < sorted.length; k++) {
    final pts = local[k];
    final n = pts.length;
    final m = sorted[k].closed ? n : n - 1;
    for (var i = 0; i < m; i++) {
      final a = pts[i], b = pts[(i + 1) % n];
      if ((b - a).length > tol) segs.add(_Seg(a, b, sorted[k].source));
    }
  }
  debugTracedSegments += segs.length;

  // 4. Splits: (t, point) per segment, found by a sweep.
  final splits = [for (final _ in segs) <(double, Vector2)>[]];
  void addSplit(int i, Vector2 p) {
    final s = segs[i];
    final d = s.b - s.a;
    final t = (p - s.a).dot(d) / d.dot(d);
    if (t <= 0 || t >= 1) return;
    splits[i].add((t, p));
  }

  // [i] < [j], so a pair is decided the same way whatever the sweep order.
  void split(int i, int j) {
    final si = segs[i], sj = segs[j];
    var touched = false;
    if (distToSegment(sj.a, si.a, si.b) <= tol) {
      addSplit(i, sj.a);
      touched = true;
    }
    if (distToSegment(sj.b, si.a, si.b) <= tol) {
      addSplit(i, sj.b);
      touched = true;
    }
    if (distToSegment(si.a, sj.a, sj.b) <= tol) {
      addSplit(j, si.a);
      touched = true;
    }
    if (distToSegment(si.b, sj.a, sj.b) <= tol) {
      addSplit(j, si.b);
      touched = true;
    }
    if (touched) return;
    final di = si.b - si.a, dj = sj.b - sj.a;
    final den = _cross(di, dj);
    if (den.abs() <= roomTrace.angular * di.length * dj.length) return;
    final w = sj.a - si.a;
    final t = _cross(w, dj) / den, u = _cross(w, di) / den;
    if (t > 0 && t < 1 && u > 0 && u < 1) {
      final p = si.a + di * t;
      addSplit(i, p);
      addSplit(j, p);
    }
  }

  final byMinX = List<int>.generate(segs.length, (i) => i)
    ..sort((x, y) {
      final c = segs[x].minX.compareTo(segs[y].minX);
      return c != 0 ? c : x.compareTo(y);
    });
  for (var p = 0; p < byMinX.length; p++) {
    final i = byMinX[p];
    final si = segs[i];
    final right = si.maxX + tol;
    for (var q = p + 1; q < byMinX.length; q++) {
      final j = byMinX[q];
      final sj = segs[j];
      if (sj.minX > right) break;
      if (si.maxY < sj.minY - tol || sj.maxY < si.minY - tol) continue;
      if (i < j) {
        split(i, j);
      } else {
        split(j, i);
      }
    }
  }

  // 5. Vertices, clustered within tol through a grid hash.
  final verts = <Vector2>[];
  final grid = <(int, int), List<int>>{};
  final cell = 4 * tol;
  int vertexOf(Vector2 p) {
    final cx = (p.x / cell).floor(), cy = (p.y / cell).floor();
    int? best;
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        for (final v in grid[(cx + dx, cy + dy)] ?? const <int>[]) {
          if ((verts[v] - p).length <= tol && (best == null || v < best)) {
            best = v;
          }
        }
      }
    }
    if (best != null) return best;
    verts.add(p);
    (grid[(cx, cy)] ??= []).add(verts.length - 1);
    return verts.length - 1;
  }

  final edges = <(int, int), Set<Handle>>{};
  for (var i = 0; i < segs.length; i++) {
    final s = segs[i];
    final chain = [
      s.a,
      for (final (_, p) in splits[i]..sort(_byT)) p,
      s.b,
    ];
    var prev = vertexOf(chain.first);
    for (var k = 1; k < chain.length; k++) {
      final v = vertexOf(chain[k]);
      if (v != prev) {
        final key = prev < v ? (prev, v) : (v, prev);
        (edges[key] ??= <Handle>{}).add(s.source);
      }
      prev = v;
    }
  }

  // 6. Half-edges: 2k is u -> v, 2k + 1 is v -> u, for edge k = (u, v).
  final keys = edges.keys.toList();
  final from = <int>[], to = <int>[];
  for (final (u, v) in keys) {
    from
      ..add(u)
      ..add(v);
    to
      ..add(v)
      ..add(u);
  }
  final angle = [
    for (var h = 0; h < from.length; h++)
      () {
        final d = verts[to[h]] - verts[from[h]];
        return math.atan2(d.y, d.x);
      }(),
  ];
  final out = [for (final _ in verts) <int>[]];
  for (var h = 0; h < from.length; h++) {
    out[from[h]].add(h);
  }
  final pos = List<int>.filled(from.length, 0);
  for (final list in out) {
    list.sort((x, y) {
      final c = angle[x].compareTo(angle[y]);
      return c != 0 ? c : x.compareTo(y);
    });
    for (var i = 0; i < list.length; i++) {
      pos[list[i]] = i;
    }
  }
  int next(int h) {
    final list = out[to[h]];
    final i = pos[h ^ 1];
    return list[(i - 1 + list.length) % list.length];
  }

  // Components, by union-find over the vertices.
  final parent = List<int>.generate(verts.length, (i) => i);
  int find(int x) {
    while (parent[x] != x) {
      parent[x] = parent[parent[x]];
      x = parent[x];
    }
    return x;
  }

  for (final (u, v) in keys) {
    final a = find(u), b = find(v);
    if (a != b) parent[math.max(a, b)] = math.min(a, b);
  }

  // Every face cycle, its area and its component.
  final seen = List<bool>.filled(from.length, false);
  final cycles = <List<int>>[];
  for (var h0 = 0; h0 < from.length; h0++) {
    if (seen[h0]) continue;
    final cycle = <int>[];
    var h = h0;
    while (!seen[h]) {
      seen[h] = true;
      cycle.add(h);
      h = next(h);
    }
    cycles.add(cycle);
  }
  List<Vector2> pointsOf(List<int> cycle) =>
      [for (final h in cycle) verts[from[h]]];
  final areas = [for (final c in cycles) shoelace(pointsOf(c))];
  final comp = [for (final c in cycles) find(from[c.first])];

  // 7. The seed's face: the least positive cycle holding the seed.
  int? outer;
  for (var c = 0; c < cycles.length; c++) {
    if (!(areas[c] > 0)) continue;
    if (!pointInRing(s0, pointsOf(cycles[c]))) continue;
    if (outer == null || areas[c] < areas[outer]) outer = c;
  }
  if (outer == null) return const Unbounded();
  final k0 = comp[outer];

  // 8. Holes.
  final contour = <int, int>{}; // component -> its most negative cycle
  for (var c = 0; c < cycles.length; c++) {
    if (comp[c] == k0) continue;
    final best = contour[comp[c]];
    if (best == null || areas[c] < areas[best]) contour[comp[c]] = c;
  }
  final outerPoints = pointsOf(cycles[outer]);
  final holeCycles = <int>[];
  for (final MapEntry(key: component, value: c) in contour.entries) {
    if (!(areas[c] < 0)) continue; // a free separator: no area
    final p = verts[from[cycles[c].first]];
    if (!pointInRing(p, outerPoints)) continue;
    var nested = false;
    for (var d = 0; d < cycles.length; d++) {
      if (comp[d] == k0 || comp[d] == component || !(areas[d] > 0)) continue;
      final pts = pointsOf(cycles[d]);
      if (pointInRing(p, pts) && !pointInRing(s0, pts)) {
        nested = true;
        break;
      }
    }
    if (!nested) holeCycles.add(c);
  }

  // 9. Clean-up and the canonical order.
  _Ring clean(List<int> cycle) {
    // Spikes: a half-edge followed by its twin.
    final hs = [...cycle];
    var changed = true;
    while (changed && hs.length > 2) {
      changed = false;
      for (var i = 0; i < hs.length; i++) {
        final j = (i + 1) % hs.length;
        if (hs[j] == (hs[i] ^ 1)) {
          if (j > i) {
            hs
              ..removeAt(j)
              ..removeAt(i);
          } else {
            hs
              ..removeAt(i)
              ..removeAt(j);
          }
          changed = true;
          break;
        }
      }
    }
    final ring = _rotated((
      pts: [for (final h in hs) verts[from[h]]],
      src: [
        for (final h in hs)
          edges[from[h] < to[h] ? (from[h], to[h]) : (to[h], from[h])]!,
      ],
    ));
    // Collinear vertices, scanned from the canonical start.
    final pts = [...ring.pts];
    final src = [...ring.src];
    changed = true;
    while (changed && pts.length > 3) {
      changed = false;
      for (var i = 0; i < pts.length; i++) {
        final prev = (i - 1 + pts.length) % pts.length;
        final a = pts[prev], b = pts[i], c = pts[(i + 1) % pts.length];
        final d = c - a;
        final along = (b - a).dot(d);
        if (distToSegment(b, a, c) <= tol && along > 0 && along < d.dot(d)) {
          src[prev] = {...src[prev], ...src[i]};
          pts.removeAt(i);
          src.removeAt(i);
          changed = true;
          break;
        }
      }
    }
    return _rotated((pts: pts, src: src));
  }

  final ring = clean(cycles[outer]);
  final holes = [
    for (final c in holeCycles)
      () {
        // Walked clockwise (the face lies outside it): reversed to
        // anticlockwise, each source moving with its edge.
        final r = clean(cycles[c]);
        final n = r.pts.length;
        return _rotated((
          pts: [for (var i = n - 1; i >= 0; i--) r.pts[i]],
          src: [for (var i = n - 1; i >= 0; i--) r.src[(i - 1 + n) % n]],
        ));
      }(),
  ]..sort((a, b) => _lex(a.pts.first, b.pts.first));

  return Traced(
    [for (final p in ring.pts) p + o],
    [for (final s in ring.src) _ascending(s)],
    [
      for (final h in holes) [for (final p in h.pts) p + o],
    ],
    [
      for (final h in holes) [for (final s in h.src) _ascending(s)],
    ],
    shoelace(ring.pts),
    [for (final h in holes) shoelace(h.pts)],
  );
}

/// A ring in the local frame: its points and, for each, the sources of the
/// edge that leaves it.
typedef _Ring = ({List<Vector2> pts, List<Set<Handle>> src});

final class _Seg {
  _Seg(this.a, this.b, this.source)
      : minX = math.min(a.x, b.x),
        maxX = math.max(a.x, b.x),
        minY = math.min(a.y, b.y),
        maxY = math.max(a.y, b.y);

  final Vector2 a, b;
  final Handle source;
  final double minX, maxX, minY, maxY;
}

double _cross(Vector2 a, Vector2 b) => a.x * b.y - a.y * b.x;

int _byT((double, Vector2) p, (double, Vector2) q) {
  final c = p.$1.compareTo(q.$1);
  return c != 0 ? c : _lex(p.$2, q.$2);
}

/// `(x, y)` order.
int _lex(Vector2 a, Vector2 b) {
  final c = a.x.compareTo(b.x);
  return c != 0 ? c : a.y.compareTo(b.y);
}

/// [r] turned to start at its least rotation in `(x, y)` order: its least
/// vertex, and where a ring passes through that vertex more than once, the
/// start whose following vertices are least (Ruling 10-7).
_Ring _rotated(_Ring r) {
  final n = r.pts.length;
  if (n == 0) return r;
  var best = 0;
  for (var i = 1; i < n; i++) {
    for (var k = 0; k < n; k++) {
      final c = _lex(r.pts[(i + k) % n], r.pts[(best + k) % n]);
      if (c < 0) best = i;
      if (c != 0) break;
    }
  }
  return (
    pts: [for (var k = 0; k < n; k++) r.pts[(best + k) % n]],
    src: [for (var k = 0; k < n; k++) r.src[(best + k) % n]],
  );
}

Set<Handle> _ascending(Set<Handle> s) =>
    Set.unmodifiable(s.toList()..sort((a, b) => a.value.compareTo(b.value)));

/// The distance from [p] to the segment [a]–[b].
double distToSegment(Vector2 p, Vector2 a, Vector2 b) {
  final d = b - a;
  final len2 = d.dot(d);
  if (len2 == 0) return (p - a).length;
  final t = ((p - a).dot(d) / len2).clamp(0.0, 1.0);
  return (p - (a + d * t)).length;
}

/// Whether [p] is inside ring [r] (no closing duplicate), by the crossing
/// number.
bool pointInRing(Vector2 p, List<Vector2> r) {
  var inside = false;
  for (var i = 0, j = r.length - 1; i < r.length; j = i++) {
    final a = r[i], b = r[j];
    if ((a.y > p.y) != (b.y > p.y) &&
        p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) {
      inside = !inside;
    }
  }
  return inside;
}

/// The shoelace area of ring [r] (no closing duplicate), anticlockwise
/// positive, summed from `r[0]`.
double shoelace(List<Vector2> r) {
  var s = 0.0;
  for (var i = 0; i < r.length; i++) {
    final p = r[i], q = r[(i + 1) % r.length];
    s += p.x * q.y - q.x * p.y;
  }
  return s / 2;
}
