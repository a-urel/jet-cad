// SPIKE 10 -- throwaway. The room ring tracer (Q1): a planar arrangement of
// the walls' uncut outline edges and the separators' segments, walked as
// half-edge faces. Pure Dart over `package:jet_cad_2d` and `vector_math`.
//
// The seed's face of the arrangement is the component of the plane outside
// every wall outline that holds the seed (no edge crosses that component, and
// no path leaves it without crossing an edge), so walking the arrangement is
// the polygon union of the outlines, read off at the one hole that matters,
// with zero-area separators as ordinary edges.
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// Every "do these touch" decision of the tracer: an endpoint on another
/// segment, two vertices that are one. 07's `wallJoin.linear`, so a joint
/// 07 builds is a joint the tracer sees.
const double roomJoin = 1e-6;

/// One boundary input: a wall's uncut outline (a closed ring, anticlockwise)
/// or a separator (an open polyline), tagged with the object it came from.
final class TraceInput {
  const TraceInput(this.source, this.points, {required this.closed});

  final Handle source;
  final List<Vector2> points;
  final bool closed;
}

/// What the tracer found for a seed.
sealed class TraceResult {
  const TraceResult();
}

/// The seed lies inside, or within [roomJoin] of, [source]'s outline or
/// segment.
final class SeedInWall extends TraceResult {
  const SeedInWall(this.source);
  final Handle source;
}

/// No bounded face holds the seed: the walls do not close around it.
final class Unbounded extends TraceResult {
  const Unbounded();
}

/// The seed's face: its outer ring (anticlockwise), its holes (each
/// anticlockwise), and the sources of every edge.
final class Traced extends TraceResult {
  Traced(this.ring, this.ringSources, this.holes, this.holeSources,
      this.outerArea, this.holeAreas);

  /// World points, anticlockwise, no closing duplicate.
  final List<Vector2> ring;

  /// `ringSources[i]`: the inputs whose segments carry edge `i`, from
  /// `ring[i]` to `ring[i + 1]`.
  final List<Set<Handle>> ringSources;

  /// World points, each anticlockwise.
  final List<List<Vector2>> holes;
  final List<List<Set<Handle>>> holeSources;

  /// Computed in the seed's local frame (see [traceRoom]).
  final double outerArea;
  final List<double> holeAreas;

  /// The net area: the outer ring minus the holes, mm².
  double get area => outerArea - holeAreas.fold(0.0, (a, b) => a + b);

  Set<Handle> get outerSources => {for (final s in ringSources) ...s};
  Set<Handle> get holeSourceSet => {
        for (final h in holeSources)
          for (final s in h) ...s
      };
}

/// Segment pairs tested by [traceRoom], for tests that report its cost.
int debugTracePairs = 0;

final class _Seg {
  _Seg(this.a, this.b, this.source);
  final Vector2 a, b;
  final Handle source;
  late final double minX = math.min(a.x, b.x), maxX = math.max(a.x, b.x);
  late final double minY = math.min(a.y, b.y), maxY = math.max(a.y, b.y);
}

double _cross(Vector2 a, Vector2 b) => a.x * b.y - a.y * b.x;

/// The distance from [p] to the segment [a]–[b].
double distToSegment(Vector2 p, Vector2 a, Vector2 b) {
  final d = b - a;
  final len2 = d.dot(d);
  if (len2 == 0) return (p - a).length;
  final t = ((p - a).dot(d) / len2).clamp(0.0, 1.0);
  return (p - (a + d * t)).length;
}

/// Crossing-number point-in-polygon; [r] without a closing duplicate.
bool pointInRing(Vector2 p, List<Vector2> r) {
  var c = false;
  for (var i = 0, j = r.length - 1; i < r.length; j = i++) {
    final a = r[i], b = r[j];
    if ((a.y > p.y) != (b.y > p.y) &&
        p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) {
      c = !c;
    }
  }
  return c;
}

/// The shoelace area, anticlockwise positive.
double shoelace(List<Vector2> r) {
  var s = 0.0;
  for (var i = 0; i < r.length; i++) {
    final p = r[i], q = r[(i + 1) % r.length];
    s += p.x * q.y - q.x * p.y;
  }
  return s / 2;
}

/// Finds the room around [seed] among [inputs] (Q1, approach (a)).
///
/// 1. **Local frame.** Every point is taken relative to [seed] first, so
///    the arithmetic below runs on numbers the size of a building, not of
///    the far origin.
/// 2. **Segments**, one per outline edge and separator piece; the seed
///    inside an outline, or within [roomJoin] of any segment, is
///    [SeedInWall].
/// 3. **Splits.** Each segment is split at every other segment's endpoint
///    lying within [roomJoin] of it (T butts, a separator's end on a face,
///    collinear overlaps) and at every proper crossing.
/// 4. **Vertices** within [roomJoin] of an earlier one are that one; edges
///    are deduplicated, each keeping every source that carries it.
/// 5. **Faces.** Half-edges around each vertex sorted by angle; `next` of
///    `u → v` is the edge leaving `v` just clockwise of `v → u`, so every
///    face lies to the left of its walk. Bounded faces walk anticlockwise.
/// 6. **The seed's face**: the anticlockwise cycle of least area holding the
///    seed. None: [Unbounded].
/// 7. **Holes**: every other connected component whose outer contour (its
///    most negative cycle) lies inside that ring and inside no bounded face
///    of a third component that does not hold the seed.
/// 8. Spikes (`u → v → u`, a separator's free end) and collinear vertices
///    are removed from the rings; areas are the local shoelace.
TraceResult traceRoom(Vector2 seed, List<TraceInput> inputs,
    {double tol = roomJoin}) {
  final o = seed.clone();
  final origin = Vector2.zero();
  final segs = <_Seg>[];
  for (final input in inputs) {
    final pts = [for (final p in input.points) p - o];
    final n = pts.length;
    if (input.closed && n >= 3 && pointInRing(origin, pts)) {
      return SeedInWall(input.source);
    }
    final m = input.closed ? n : n - 1;
    for (var i = 0; i < m; i++) {
      final a = pts[i], b = pts[(i + 1) % n];
      if ((b - a).length > tol) segs.add(_Seg(a, b, input.source));
    }
  }
  for (final s in segs) {
    if (distToSegment(origin, s.a, s.b) <= tol) return SeedInWall(s.source);
  }

  // 3. Splits: (t, point) per segment.
  final splits = [for (final _ in segs) <(double, Vector2)>[]];
  void addSplit(int i, Vector2 p) {
    final s = segs[i];
    final d = s.b - s.a;
    final t = (p - s.a).dot(d) / d.dot(d);
    if (t <= 0 || t >= 1) return;
    splits[i].add((t, p));
  }

  for (var i = 0; i < segs.length; i++) {
    final si = segs[i];
    for (var j = i + 1; j < segs.length; j++) {
      final sj = segs[j];
      if (si.maxX < sj.minX - tol ||
          sj.maxX < si.minX - tol ||
          si.maxY < sj.minY - tol ||
          sj.maxY < si.minY - tol) {
        continue;
      }
      debugTracePairs++;
      var touched = false;
      for (final e in [sj.a, sj.b]) {
        if (distToSegment(e, si.a, si.b) <= tol) {
          addSplit(i, e);
          touched = true;
        }
      }
      for (final e in [si.a, si.b]) {
        if (distToSegment(e, sj.a, sj.b) <= tol) {
          addSplit(j, e);
          touched = true;
        }
      }
      if (touched) continue;
      final di = si.b - si.a, dj = sj.b - sj.a;
      final den = _cross(di, dj);
      if (den.abs() <= 1e-12 * di.length * dj.length) continue; // parallel
      final w = sj.a - si.a;
      final t = _cross(w, dj) / den, u = _cross(w, di) / den;
      if (t > 0 && t < 1 && u > 0 && u < 1) {
        final p = si.a + di * t;
        addSplit(i, p);
        addSplit(j, p);
      }
    }
  }

  // 4. Vertices, clustered within tol through a grid hash.
  final verts = <Vector2>[];
  final grid = <(int, int), List<int>>{};
  final cell = tol * 4;
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
      for (final (_, p) in splits[i]..sort((x, y) => x.$1.compareTo(y.$1))) p,
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

  // 5. Half-edges: 2k is u -> v, 2k + 1 is v -> u, for edge k = (u, v).
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
  final out = [for (final _ in verts) <int>[]];
  for (var h = 0; h < from.length; h++) {
    out[from[h]].add(h);
  }
  double angleOf(int h) {
    final d = verts[to[h]] - verts[from[h]];
    return math.atan2(d.y, d.x);
  }

  final pos = List<int>.filled(from.length, 0);
  for (final list in out) {
    list.sort((x, y) => angleOf(x).compareTo(angleOf(y)));
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

  // Every face cycle.
  final seen = List<bool>.filled(from.length, false);
  final cycles = <List<int>>[];
  for (var h0 = 0; h0 < from.length; h0++) {
    if (seen[h0]) continue;
    final cyc = <int>[];
    var h = h0;
    while (!seen[h]) {
      seen[h] = true;
      cyc.add(h);
      h = next(h);
    }
    cycles.add(cyc);
  }
  List<Vector2> pointsOf(List<int> cyc) =>
      [for (final h in cyc) verts[from[h]]];
  final areas = [for (final c in cycles) shoelace(pointsOf(c))];
  final comp = [for (final c in cycles) find(from[c.first])];

  // 6. The seed's face: the least positive cycle holding the seed.
  int? outer;
  for (var c = 0; c < cycles.length; c++) {
    if (!(areas[c] > 0)) continue;
    if (!pointInRing(origin, pointsOf(cycles[c]))) continue;
    if (outer == null || areas[c] < areas[outer]) outer = c;
  }
  if (outer == null) return const Unbounded();
  final k0 = comp[outer];

  // 7. Holes.
  final contour = <int, int>{}; // component -> its most negative cycle
  for (var c = 0; c < cycles.length; c++) {
    if (comp[c] == k0) continue;
    final best = contour[comp[c]];
    if (best == null || areas[c] < areas[best]) contour[comp[c]] = c;
  }
  final outerPts = pointsOf(cycles[outer]);
  final holeCycles = <int>[];
  for (final e in contour.entries) {
    if (!(areas[e.value] < 0)) continue; // a free separator: no area
    final p = verts[from[cycles[e.value].first]];
    if (!pointInRing(p, outerPts)) continue;
    var nested = false;
    for (var c = 0; c < cycles.length; c++) {
      if (comp[c] == k0 || comp[c] == e.key || !(areas[c] > 0)) continue;
      final pts = pointsOf(cycles[c]);
      if (pointInRing(p, pts) && !pointInRing(origin, pts)) {
        nested = true;
        break;
      }
    }
    if (!nested) holeCycles.add(e.value);
  }
  holeCycles.sort();

  // 8. Clean-up and output.
  Set<Handle> sourcesOf(int h) {
    final u = from[h], v = to[h];
    return edges[u < v ? (u, v) : (v, u)]!;
  }

  ({List<Vector2> pts, List<Set<Handle>> src}) clean(List<int> cyc) {
    final hs = [...cyc];
    var changed = true;
    while (changed && hs.length > 2) {
      changed = false;
      for (var i = 0; i < hs.length; i++) {
        final j = (i + 1) % hs.length;
        if (hs[j] == (hs[i] ^ 1)) {
          if (j > i) {
            hs.removeAt(j);
            hs.removeAt(i);
          } else {
            hs.removeAt(i);
            hs.removeAt(j);
          }
          changed = true;
          break;
        }
      }
    }
    final pts = [for (final h in hs) verts[from[h]]];
    final src = [
      for (final h in hs) {...sourcesOf(h)}
    ];
    changed = true;
    while (changed && pts.length > 3) {
      changed = false;
      for (var i = 0; i < pts.length; i++) {
        final a = pts[(i - 1 + pts.length) % pts.length], b = pts[i];
        final c = pts[(i + 1) % pts.length];
        final d = c - a;
        final along = (b - a).dot(d);
        if (distToSegment(b, a, c) <= tol && along > 0 && along < d.dot(d)) {
          final prev = (i - 1 + pts.length) % pts.length;
          src[prev] = {...src[prev], ...src[i]};
          pts.removeAt(i);
          src.removeAt(i);
          changed = true;
          break;
        }
      }
    }
    return (pts: pts, src: src);
  }

  final ring = clean(cycles[outer]);
  final holes = [
    for (final c in holeCycles)
      () {
        final r = clean(cycles[c]);
        // Walked clockwise (the face lies outside it): reverse to
        // anticlockwise, the sources moving with their edges.
        final n = r.pts.length;
        return (
          pts: [for (var i = n - 1; i >= 0; i--) r.pts[i]],
          src: [for (var i = n - 1; i >= 0; i--) r.src[(i - 1 + n) % n]],
        );
      }(),
  ];
  return Traced(
    [for (final p in ring.pts) p + o],
    ring.src,
    [
      for (final h in holes) [for (final p in h.pts) p + o]
    ],
    [for (final h in holes) h.src],
    shoelace(ring.pts),
    [for (final h in holes) shoelace(h.pts)],
  );
}
