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
///    component with no area (a free separator, or a free tree of them) is
///    not a hole: its contour, spikes removed, has fewer than three
///    vertices.
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
    if (!(areas[c] < 0)) continue; // no area: not a contour
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
  final holes = <_Ring>[];
  for (final c in holeCycles) {
    final r = clean(cycles[c]);
    final n = r.pts.length;
    // A component with no area (a free separator, or a free tree of them)
    // walks out and back: with its spikes removed, fewer than three
    // vertices are left. It is not a hole (D6), whatever the sign of its
    // shoelace residue.
    if (n < 3) continue;
    // Walked clockwise (the face lies outside it): reversed to
    // anticlockwise, each source moving with its edge.
    holes.add(_rotated((
      pts: [for (var i = n - 1; i >= 0; i--) r.pts[i]],
      src: [for (var i = n - 1; i >= 0; i--) r.src[(i - 1 + n) % n]],
    )));
  }
  holes.sort((a, b) => _lex(a.pts.first, b.pts.first));

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

// ---------------------------------------------------------------------------
// The localised trace (spec 10 D7).

/// What [traceRoomAmong] traces among (spec 10 D7): the live walls and
/// separators, by place box. `RoomInputs` (the document adapter) and
/// `placeSourceInView` (the view's) implement it.
abstract interface class PlaceSource {
  /// The contributors whose place box touches [box] (closed: touching
  /// counts), ascending.
  List<Handle> placedIn(Aabb2 box);

  /// [h]'s input, or null when [h] is not a contributor with one.
  RoomInput? inputOf(Handle h);

  /// `U`: the union of every contributor's finite place box; null when
  /// nothing is placed.
  Aabb2? get bounds;
}

/// D7's first growth radius, mm (R-7): a room is metres across, so one or
/// two doublings find its walls.
const double kGrowthStart = 1000;

/// D7's certificate margin, mm (R-7): 10⁶ × `roomTrace.linear`, far above
/// any rounding, so no vertex merge or split reaches across it.
const double kCertificateMargin = 1;

/// The room around [seed] among every contributor [source] holds, tracing
/// only those near its face (spec 10 D7). The result is, bit for bit,
/// `traceRoom(seed, every input)` (`LZ1`):
///
/// 1. **Growth.** Trace among `placedIn(B)`, `B = seed ⊕ r`, from `r =`
///    [kGrowthStart]. [SeedInWall] is final: the wall holding the seed
///    touches `B`. [Unbounded]: double `r` and repeat until `B` contains
///    `U` ([PlaceSource.bounds]); then [Unbounded] is final. With nothing
///    placed at all, [Unbounded] at once.
/// 2. **Certificate.** On `Traced(F)`, `C = placedIn(box(F) ⊕ m)`, `m =`
///    [kCertificateMargin]. While `C` holds a contributor not yet traced,
///    add it and trace again. The face can only shrink or gain holes, so one
///    round always suffices; the loop's exit is the certificate itself.
/// 3. **Canonical trace.** The trace among exactly `C`: a function of `C`
///    and the seed only, whatever growth rounds led there (D16's no-drift
///    proof needs this). When the last trace was already among exactly `C`,
///    it is that trace: the same inputs give the same bits.
///
/// Why exact: every contributor outside `C` is disjoint from the closed
/// face grown by `m`, and so changes nothing inside it.
///
/// A seed with a non-finite coordinate is [Unbounded]: no box around it
/// ever contains `U`.
TraceResult traceRoomAmong(Vector2 seed, PlaceSource source) {
  final u = source.bounds;
  if (u == null || !seed.x.isFinite || !seed.y.isFinite) {
    return const Unbounded();
  }
  List<RoomInput> inputsOf(Iterable<Handle> hs) => [
        for (final h in hs)
          if (source.inputOf(h) case final input?) input,
      ];

  // 1. Growth.
  var r = kGrowthStart;
  List<Handle> traced;
  Traced face;
  while (true) {
    final b = Aabb2.raw(seed.x - r, seed.y - r, seed.x + r, seed.y + r);
    traced = source.placedIn(b);
    final result = traceRoom(seed, inputsOf(traced));
    if (result is Traced) {
      face = result;
      break;
    }
    if (result is SeedInWall || _holds(b, u)) return result;
    r *= 2;
  }

  // 2. The certificate.
  Aabb2 grown(Traced f) =>
      Aabb2.fromPoints(f.ring).expandedBy(kCertificateMargin);
  final set = {...traced};
  var c = source.placedIn(grown(face));
  while (!c.every(set.contains)) {
    set.addAll(c);
    traced = [...set]..sort((a, b) => a.value.compareTo(b.value));
    final result = traceRoom(seed, inputsOf(traced));
    // Unreachable (D7: more inputs only shrink the face, and the wall
    // holding the seed would have touched B), but never a wrong answer.
    if (result is! Traced) return result;
    face = result;
    c = source.placedIn(grown(face));
  }

  // 3. The canonical trace, among exactly C.
  if (_sameHandles(traced, c)) return face;
  return traceRoom(seed, inputsOf(c));
}

/// Whether [b] contains [u] (closed).
bool _holds(Aabb2 b, Aabb2 u) =>
    b.minX <= u.minX &&
    b.minY <= u.minY &&
    b.maxX >= u.maxX &&
    b.maxY >= u.maxY;

bool _sameHandles(List<Handle> a, List<Handle> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// ---------------------------------------------------------------------------
// The tint's shape (spec 10 D9).

/// The width of the tint's slit to each hole, mm (spec 10 D9, R-11): the
/// engine's triangulator refuses an exact keyhole, whose bridge is two
/// coincident edges (the spike's Q5, M-slit).
const double kSlit = 0.5;

/// [tintOf]'s answer: which form of D9's fallback chain the tint takes, its
/// ring, and the holes the keyhole could not bridge.
final class Tint {
  Tint(this.step, List<Vector2> points, List<int> holesLeftOut)
      : points = List.unmodifiable(points),
        holesLeftOut = List.unmodifiable(holesLeftOut);

  /// 1: the keyholed ring, a region; 2: the outer ring alone, a region (the
  /// holes tinted over); 3: the outer ring as an invisible, unfilled closed
  /// polyline (neither ring triangulates).
  final int step;

  /// The ring, in the frame [tintOf] was given, no closing duplicate. Every
  /// outer-ring vertex is among them, whatever the step.
  final List<Vector2> points;

  /// Indices into [tintOf]'s holes of those that found no bridge: step 1's
  /// region covers them. Steps 2 and 3 cover every hole anyway.
  ///
  /// Defensive: a real trace never fills it. Holes are joined in descending
  /// order of their rightmost x, so a ray to the right from a hole's
  /// rightmost vertex H meets the growing ring first (the holes not yet
  /// joined lie at x ≤ H.x, the joined ones are part of the ring), and a
  /// vertex of the ring is visible from H (Eberly's argument). Only a ring
  /// and holes that are not a trace's, as `TN1`'s hole outside the ring,
  /// reach it.
  final List<int> holesLeftOut;

  /// Whether the tint shows the face as traced: step 1, every hole cut out.
  /// Otherwise the room reports `room.tint` (D22).
  bool get isExact => step == 1 && holesLeftOut.isEmpty;

  @override
  String toString() => 'Tint(step $step, ${points.length} points, '
      'holes left out $holesLeftOut)';
}

/// The tint of the face [ring] minus [holes] (spec 10 D9), both
/// anticlockwise as [Traced] gives them, **in the trace's seed-relative
/// frame** (the caller subtracts the seed, and maps [Tint.points] to the
/// room's local space after): so the bridges and the slit are decided on
/// numbers the size of a building, not of the far origin.
///
/// **The keyhole.** The holes are taken in descending order of their
/// rightmost `x` (ties in the order given). Each joins the **growing
/// keyholed ring** (the outer ring with the holes already joined) through a
/// bridge from its rightmost vertex `H` to the nearest vertex `V` of that
/// ring whose bridge properly crosses no edge of that ring and no edge of
/// any hole not yet joined, this one included (ties to the earlier vertex).
/// The hole is walked clockwise from `H`, and the return edge runs [kSlit]
/// to the bridge's right, from `H` to `V` both moved, so the ring stays
/// simple. A hole with no such vertex is left out (the tint covers it) and
/// named in [Tint.holesLeftOut].
///
/// **The fallback chain**, so an edit is never refused because of a tint:
/// 1. the keyholed ring, if it triangulates (`triangulationFor` non-empty);
/// 2. else the outer ring alone, if it triangulates;
/// 3. else the outer ring, which the room stores as an invisible, unfilled
///    closed polyline.
Tint tintOf(List<Vector2> ring, List<List<Vector2>> holes) {
  final keyholed = <Vector2>[...ring];
  final order = List<int>.generate(holes.length, (i) => i);
  double rightmost(List<Vector2> r) =>
      r.fold(double.negativeInfinity, (m, p) => math.max(m, p.x));
  final right = [for (final h in holes) rightmost(h)];
  order.sort((a, b) {
    final c = right[b].compareTo(right[a]);
    return c != 0 ? c : a.compareTo(b);
  });
  final leftOut = <int>[];
  for (var k = 0; k < order.length; k++) {
    // Clockwise inside the ring: the region lies to its left.
    final hole = holes[order[k]].reversed.toList();
    if (hole.length < 3) {
      leftOut.add(order[k]);
      continue;
    }
    var hi = 0;
    for (var i = 1; i < hole.length; i++) {
      if (hole[i].x > hole[hi].x) hi = i;
    }
    final h = hole[hi];
    final byDistance = List<int>.generate(keyholed.length, (i) => i)
      ..sort((a, b) {
        final c =
            (keyholed[a] - h).length2.compareTo((keyholed[b] - h).length2);
        return c != 0 ? c : a.compareTo(b);
      });
    final obstacles = [
      keyholed,
      for (var j = k; j < order.length; j++) holes[order[j]],
    ];
    int? vi;
    for (final i in byDistance) {
      final v = keyholed[i];
      if ((v - h).length2 == 0) continue;
      if (!_blocked(h, v, obstacles)) {
        vi = i;
        break;
      }
    }
    if (vi == null) {
      leftOut.add(order[k]);
      continue;
    }
    final v = keyholed[vi];
    final d = (h - v).normalized();
    final slit = Vector2(d.y, -d.x) * kSlit; // to the bridge's right
    keyholed.insertAll(vi + 1, [
      for (var j = 0; j < hole.length; j++) hole[(hi + j) % hole.length],
      h + slit,
      v + slit,
    ]);
  }
  leftOut.sort();
  if (_triangulates(keyholed)) return Tint(1, keyholed, leftOut);
  if (_triangulates(ring)) return Tint(2, ring, leftOut);
  return Tint(3, ring, leftOut);
}

/// Whether the bridge [h]–[v] is blocked by any of [rings]: it properly
/// crosses one of their edges, or one of their vertices lies strictly
/// inside it (within `roomTrace.linear` of the bridge and farther than that
/// from both its ends). The second rule catches a bridge that runs along an
/// edge or through a vertex, which no proper crossing sees: on an
/// axis-aligned plan a column's top-right corner would otherwise bridge
/// straight down the column's own east edge to a corner below it, and the
/// keyholed ring would not be simple.
bool _blocked(Vector2 h, Vector2 v, List<List<Vector2>> rings) {
  final tol = roomTrace.linear;
  for (final r in rings) {
    for (var e = 0; e < r.length; e++) {
      if (_properlyCross(h, v, r[e], r[(e + 1) % r.length])) return true;
    }
    for (final p in r) {
      if (distToSegment(p, h, v) <= tol &&
          (p - h).length > tol &&
          (p - v).length > tol) {
        return true;
      }
    }
  }
  return false;
}

/// Whether segment [a]–[b] properly crosses [c]–[d]: each strictly
/// separates the other's ends, so touching at an end is not a crossing.
bool _properlyCross(Vector2 a, Vector2 b, Vector2 c, Vector2 d) {
  double side(Vector2 o, Vector2 p, Vector2 q) =>
      (p.x - o.x) * (q.y - o.y) - (p.y - o.y) * (q.x - o.x);
  final d1 = side(c, d, a), d2 = side(c, d, b);
  final d3 = side(a, b, c), d4 = side(a, b, d);
  return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
      ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0));
}

/// Whether the closed ring [r] is a region the engine can fill: its
/// triangulation, as `AddRegionCommand` computes it, is not empty.
bool _triangulates(List<Vector2> r) =>
    r.length >= 3 &&
    (triangulationFor(EntityKind.polyline, polylinePayload(r, closed: true))
            ?.isNotEmpty ??
        false);

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
