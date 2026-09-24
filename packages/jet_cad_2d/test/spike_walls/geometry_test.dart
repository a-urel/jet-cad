// SPIKE 07 — throwaway. Q1–Q5: the node rule, T/X, clamps and the
// simple-polygon invariant, on world geometry at the far origin.
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'svg.dart';
import 'wall.dart';

const double ox = 4500000.0, oy = 1200000.0;
Vector2 far(double x, double y) => Vector2(ox + x, oy + y);
Vector2 polar(Vector2 from, double deg, double len) {
  final r = deg * math.pi / 180;
  return from + Vector2(math.cos(r), math.sin(r)) * len;
}

var _next = 1;
WorldWall wall(Vector2 s, Vector2 e, double t,
        [Justification j = Justification.centre]) =>
    WorldWall(Handle(100 + _next++), WallParams(s.x, s.y, e.x, e.y, t, j),
        Transform2.identity());

List<Vector2> ring(WorldWall w, List<WorldWall> all, {bool fallback = true}) =>
    outline(w, [
      for (final o in all)
        if (o.handle != w.handle) o
    ], fallback: fallback);

bool triangulates(List<Vector2> r) {
  final tri = triangulationFor(EntityKind.polyline,
      polylinePayload(r, closed: true));
  return tri != null && tri.isNotEmpty;
}

/// Crossing-number point-in-polygon.
bool inside(Vector2 p, List<Vector2> r) {
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

/// Cramer's rule on explicit coordinates — deliberately not `intersect`.
Vector2 oracleMeet(Vector2 p1, Vector2 p2, Vector2 q1, Vector2 q2) {
  final a1 = p2.y - p1.y, b1 = p1.x - p2.x, c1 = a1 * p1.x + b1 * p1.y;
  final a2 = q2.y - q1.y, b2 = q1.x - q2.x, c2 = a2 * q1.x + b2 * q1.y;
  final det = a1 * b2 - a2 * b1;
  return Vector2((b2 * c1 - b1 * c2) / det, (a1 * c2 - a2 * c1) / det);
}

/// A face line of [w] as two points: offset [o] along the left normal.
(Vector2, Vector2) face(WorldWall w, double o) {
  final n = Vector2(-w.d.y, w.d.x);
  return (w.s + n * o, w.e + n * o);
}

/// Overlap and gap census around [hub]: samples in a disk of radius [r].
/// A sample is a gap if no polygon holds it but it lies inside some wall's
/// own strip (between its faces, within its length) — i.e. inside the
/// union the walls should cover.
(int, int, int) census(List<List<Vector2>> rings, List<WorldWall> walls,
    Vector2 hub, double r) {
  var overlap = 0, gap = 0, n = 0;
  final rnd = math.Random(7);
  bool inStrip(Vector2 p, WorldWall w) {
    final (l, rr) = w.offsets;
    final d = w.d, nn = Vector2(-d.y, d.x);
    final u = (p - w.s).dot(d), v = (p - w.s).dot(nn);
    return u > 0 && u < (w.e - w.s).length && v < l && v > rr;
  }

  for (var i = 0; i < 20000; i++) {
    final a = rnd.nextDouble() * 2 * math.pi;
    final rad = r * math.sqrt(rnd.nextDouble());
    final p = hub + Vector2(math.cos(a), math.sin(a)) * rad;
    final count = rings.where((g) => inside(p, g)).length;
    n++;
    if (count > 1) overlap++;
    if (count == 0 && walls.any((w) => inStrip(p, w))) gap++;
  }
  return (overlap, gap, n);
}

void main() {
  _tests();
}

void _tests() {
  test('Q1 L at 67°, 200 centre / 115 left', () {
    final h = far(0, 0);
    final a = wall(far(-3000, 0), h, 200);
    final b = wall(h, polar(h, 180 - 67, 2500), 115, Justification.left);
    final ra = ring(a, [a, b]), rb = ring(b, [a, b]);
    // A: end cap [c(A,B) , hub, c(B,A)]: 3 points + start cap 2.
    print('Q1 A ring ${ra.length} pts, B ring ${rb.length} pts');
    expect(isSimpleCcw(ra) && isSimpleCcw(rb), isTrue);
    expect(triangulates(ra) && triangulates(rb), isTrue);

    // Oracle corners: A's faces (±100) against B's faces (0, +115).
    final (al1, al2) = face(a, 100);
    final (ar1, ar2) = face(a, -100);
    final (bl1, bl2) = face(b, 115);
    final (br1, br2) = face(b, 0);
    final outer = oracleMeet(al1, al2, bl1, bl2);
    final inner = oracleMeet(ar1, ar2, br1, br2);
    final shared = [
      for (final p in ra)
        if (rb.any((q) => q.x == p.x && q.y == p.y)) p
    ];
    print('Q1 shared points (bitwise) ${shared.length}: '
        '${shared.map((p) => '(${(p.x - ox).toStringAsFixed(6)}, '
            '${(p.y - oy).toStringAsFixed(6)})').join(' ')}');
    print('Q1 oracle outer (${(outer.x - ox).toStringAsFixed(6)}, '
        '${(outer.y - oy).toStringAsFixed(6)}) inner '
        '(${(inner.x - ox).toStringAsFixed(6)}, '
        '${(inner.y - oy).toStringAsFixed(6)})');
    double near(Vector2 p) =>
        shared.map((q) => (q - p).length).reduce(math.min);
    print('Q1 |oracle - generated| outer ${near(outer)} inner ${near(inner)}');
    expect(near(outer), lessThan(1e-6));
    expect(near(inner), lessThan(1e-6));

    // M-07a probe: the "average direction" corner at the symmetric distance.
    final ea = -a.d, eb = b.d; // outgoing directions from the hub
    final avg = (ea + eb) * 0.5;
    final theta = math.acos(ea.dot(eb));
    final m07a = h + avg.normalized() * (100 / math.sin(theta / 2));
    print('Q1 M-07a bisector-at-symmetric-distance vs oracle inner: '
        '${(m07a - inner).length.toStringAsFixed(3)} mm, vs outer '
        '${(m07a - outer).length.toStringAsFixed(3)} mm');
    // M-07b probe: both walls at A's half-thickness, centre.
    final b2 = WorldWall(b.handle,
        WallParams(b.s.x, b.s.y, b.e.x, b.e.y, 200), Transform2.identity());
    final rb2 = ring(a, [a, b2]);
    final moved = [
      for (var i = 0; i < ra.length; i++) (ra[i] - rb2[i]).length
    ].reduce(math.max);
    print('Q1 M-07b (B as 200 centre) max corner displacement on A: '
        '${moved.toStringAsFixed(3)} mm');
    // Tiling.
    final (ov, gp, n) = census([ra, rb], [a, b], h, 400);
    print('Q1 census overlap $ov gap $gp of $n');
  });

  test('Q2 three ends at 10°/50°/200°, mixed thickness and justification',
      () {
    final h = far(0, 0);
    final w1 = wall(h, polar(h, 10, 3000), 200);
    final w2 = wall(polar(h, 50, 2000), h, 115, Justification.left);
    final w3 = wall(h, polar(h, 200, 2500), 150, Justification.right);
    final all = [w1, w2, w3];
    final rings = [for (final w in all) ring(w, all, fallback: false)];
    for (final (i, r) in rings.indexed) {
      print('Q2 w${i + 1} ring ${r.length} pts simple ${isSimpleCcw(r)} '
          'triangulates ${triangulates(r)}');
    }
    final (ov, gp, n) = census(rings, all, h, 500);
    print('Q2 census overlap $ov gap $gp of $n');
    expect(rings.every(isSimpleCcw), isTrue);
  });

  test('Q2b sweep: hub inside the corner star under every justification', () {
    // Every justification triple, three ends at uneven angles.
    var bad = 0, total = 0, overlaps = 0, gaps = 0;
    for (final j1 in Justification.values) {
      for (final j2 in Justification.values) {
        for (final j3 in Justification.values) {
          final h = far(0, 0);
          final w1 = wall(h, polar(h, 10, 3000), 200, j1);
          final w2 = wall(polar(h, 50, 2000), h, 115, j2);
          final w3 = wall(h, polar(h, 200, 2500), 150, j3);
          final all = [w1, w2, w3];
          final rings = [for (final w in all) ring(w, all, fallback: false)];
          total++;
          if (!rings.every(isSimpleCcw)) {
            bad++;
            print('Q2b not simple: ${j1.name}/${j2.name}/${j3.name} '
                '${rings.map(isSimpleCcw).toList()}');
          }
          final (ov, gp, _) = census(rings, all, h, 500);
          overlaps += ov;
          gaps += gp;
          if (ov > 0 || gp > 0) {
            print('Q2b ${j1.name}/${j2.name}/${j3.name} overlap $ov gap $gp');
          }
        }
      }
    }
    print('Q2b $bad of $total not simple; overlap $overlaps gap $gaps');
  });

  test('Q3 T at 58°: stem 115 butts the 200 right-justified through wall', () {
    final b = wall(far(-2000, 0), far(3000, 0), 200, Justification.right);
    final p = far(700, 0);
    final a = wall(polar(p, 58, 2400), p, 115);
    final ra = ring(a, [a, b]), rb = ring(b, [a, b]);
    print('Q3 stem ring ${ra.length} pts, through ring ${rb.length} pts');
    // Stem comes from +y; B right-justified: body is below (-n), so the
    // near face is the centreline itself (offset 0).
    final (f1, f2) = face(b, 0);
    final capPts = ra.sublist(0, 2); // end cap
    for (final q in capPts) {
      final dist = ((f2 - f1).x * (q.y - f1.y) - (f2 - f1).y * (q.x - f1.x))
              .abs() /
          (f2 - f1).length;
      print('Q3 cap point distance to near face: $dist');
      expect(dist, lessThan(1e-6));
    }
    expect(rb.length, 4, reason: 'the through wall is untouched');
    final (ov, gp, n) = census([ra, rb], [a, b], p, 300);
    print('Q3 census overlap $ov gap $gp of $n');
    // X: two crossing walls stay rectangles.
    final x1 = wall(far(-1000, -1000), far(1000, 900), 150);
    final x2 = wall(far(-1000, 800), far(1200, -700), 240, Justification.left);
    expect(ring(x1, [x1, x2]).length, 4);
    expect(ring(x2, [x1, x2]).length, 4);
  });

  test('Q4 clamps: 20° bevel, collinear step, short wall', () {
    final h = far(0, 0);
    final a = wall(far(-3000, 0), h, 200);
    final b = wall(h, polar(h, 180 - 20, 2500), 200);
    final ra = ring(a, [a, b]), rb = ring(b, [a, b]);
    print('Q4 20° L: A ${ra.length} pts simple ${isSimpleCcw(ra)}, '
        'B ${rb.length} pts simple ${isSimpleCcw(rb)}');
    final (ov, gp, n) = census([ra, rb], [a, b], h, 800);
    print('Q4 20° census overlap $ov gap $gp of $n');

    final c = wall(far(-3000, 0), h, 200);
    final d = wall(h, far(3000, 0), 115, Justification.left);
    final rc = ring(c, [c, d]), rd = ring(d, [c, d]);
    print('Q4 collinear step: C ${rc.length} pts simple ${isSimpleCcw(rc)}, '
        'D ${rd.length} pts simple ${isSimpleCcw(rd)}');
    final (ov2, gp2, n2) = census([rc, rd], [c, d], h, 300);
    print('Q4 step census overlap $ov2 gap $gp2 of $n2');

    // Short wall: 150 long, 200 thick, between two acute-ish nodes.
    final s0 = far(0, 0), s1 = far(150, 0);
    final m = wall(s0, s1, 200);
    final l = wall(polar(s0, 120, 2000), s0, 200);
    final r = wall(s1, polar(s1, 60, 2000), 200);
    final all = [m, l, r];
    final raw = ring(m, all, fallback: false);
    final fixed = ring(m, all);
    print('Q4 short wall raw simple ${isSimpleCcw(raw)} '
        '-> fallback ${fixed.length} pts simple ${isSimpleCcw(fixed)}');
    expect(isSimpleCcw(fixed), isTrue);
  });

  test('Q2c common plan nodes, rotated, every justification pairing', () {
    // (name, [(angle, thickness, justification, starts at hub)])
    final cases = <(String, List<(double, double, Justification, bool)>)>[];
    const js = Justification.values;
    for (final ext in js) {
      for (final int_ in js) {
        cases.add(('split300$ext+br115$int_', [
          (0, 300, ext, true), (180, 300, ext, false), (90, 115, int_, true)]));
        cases.add(('split300$ext+br300$int_', [
          (0, 300, ext, true), (180, 300, ext, false), (90, 300, int_, true)]));
        cases.add(('cross200$ext/115$int_', [
          (0, 200, ext, true), (180, 200, ext, false),
          (90, 115, int_, true), (270, 115, int_, false)]));
        cases.add(('L300$ext/115$int_', [(0, 300, ext, true), (90, 115, int_, false)]));
        cases.add(('L300$ext/300$int_ 120', [(0, 300, ext, true), (120, 300, int_, false)]));
        cases.add(('Y 0/135/225 200$ext/115$int_', [
          (0, 200, ext, true), (135, 115, int_, true), (225, 115, int_, false)]));
      }
    }
    var bad = 0, holes = 0, total = 0;
    for (final (name, spec) in cases) {
      for (final rot in [0.0, 17.0, 73.0, 131.0]) {
        holeLobes = 0;
        final h = far(0, 0);
        final all = [
          for (final (a, t, j, fromHub) in spec)
            fromHub
                ? wall(h, polar(h, a + rot, 3000), t, j)
                : wall(polar(h, a + rot, 3000), h, t, j),
        ];
        total++;
        final rings = [for (final w in all) ring(w, all, fallback: false)];
        final ok = rings.every(isSimpleCcw) && rings.every(triangulates);
        final (ov, _, _) = census(rings, all, h, 400);
        if (!ok || holeLobes > 0) {
          bad += ok ? 0 : 1;
          holes += holeLobes > 0 ? 1 : 0;
          print('Q2c $name rot $rot simple/tri $ok holeLobe ${holeLobes > 0} overlap $ov');
        }
      }
    }
    print('Q2c $total nodes: not simple $bad, with a crossing lobe $holes');
  });

  test('Q5b plausible nodes: fallback rate', () {
    holeLobes = 0;
    final rnd = math.Random(7707);
    const ts = [100.0, 115.0, 150.0, 200.0, 250.0, 300.0];
    final js = Justification.values;
    var walls = 0, fellBack = 0, overlapNodes = 0, noTri = 0, dumped = 0;
    var holeNodes = 0, nodes = 0;
    final byK = <int, List<int>>{};
    for (var trial = 0; trial < 20000; trial++) {
      final hub = far(rnd.nextDouble() * 1e5, rnd.nextDouble() * 1e5);
      final r = rnd.nextDouble();
      final k = r < 0.6 ? 2 : (r < 0.9 ? 3 : 4);
      final angles = <double>[];
      var guard = 0;
      while (angles.length < k && guard++ < 1000) {
        final a = rnd.nextDouble() * 360;
        if (angles.every((b) {
          final d = ((a - b) % 360 + 360) % 360;
          return d >= 30 && d <= 330;
        })) {
          angles.add(a);
        }
      }
      if (angles.length < k) continue;
      nodes++;
      final uniform = rnd.nextDouble() < 0.7;
      final j0 = js[rnd.nextInt(3)];
      final all = [
        for (final a in angles)
          () {
            final t = ts[rnd.nextInt(ts.length)];
            final len = 3 * t + rnd.nextDouble() * 5000;
            final j = uniform ? j0 : js[rnd.nextInt(3)];
            final f = polar(hub, a, len);
            return rnd.nextBool() ? wall(hub, f, t, j) : wall(f, hub, t, j);
          }(),
      ];
      var nodeFell = 0;
      final before = holeLobes;
      final rings = <List<Vector2>>[];
      for (final w in all) {
        walls++;
        final raw = ring(w, all, fallback: false);
        final rr = ring(w, all);
        if (!isSimpleCcw(raw)) {
          fellBack++;
          nodeFell++;
          if (k == 2 && fellBack < 400 && byK[2] != null && byK[2]![1] < 4) {
            print('Q5b K2FALL ' + [for (final x in all) '${x.handle.value} s=(${(x.s.x - hub.x).toStringAsFixed(3)},${(x.s.y - hub.y).toStringAsFixed(3)}) e=(${(x.e.x - hub.x).toStringAsFixed(3)},${(x.e.y - hub.y).toStringAsFixed(3)}) t=${x.t} ${x.j.name}'].join(' | ') + ' failing=${w.handle.value}');
          }
        }
        if (!triangulates(rr)) noTri++;
        rings.add(rr);
      }
      if (holeLobes > before) holeNodes++;
      if (holeLobes > before && dumped < 4) {
        dumped++;
        dump('q5b_hole_$dumped', all, hub, 700);
      }
      (byK[k] ??= [0, 0, 0])
        ..[0] += 1
        ..[1] += nodeFell > 0 ? 1 : 0;
      if (trial < 2000) {
        final (o, _, _) = census(rings, all, hub, 80);
        if (o > 0) {
          overlapNodes++;
          byK[k]![2] += 1;
        }
      }
    }
    print('Q5b nodes $nodes with a crossing (dropped, positive-area) lobe: '
        '$holeNodes (${(100 * holeNodes / nodes).toStringAsFixed(2)}%)');
    print('Q5b walls $walls fell back $fellBack '
        '(${(100 * fellBack / walls).toStringAsFixed(2)}%) no triangulation '
        '$noTri; nodes with overlap (first 2000) $overlapNodes');
    byK.forEach((k, v) => print('Q5b k=$k nodes ${v[0]} with a fallback '
        '${v[1]} (${(100 * v[1] / v[0]).toStringAsFixed(2)}%) '
        'overlap-sampled ${v[2]}'));
    expect(noTri, 0);
  });

  test('Q5 random nodes: every outline simple and triangulates', () {
    holeLobes = 0;
    final rnd = math.Random(20260924);
    var walls = 0, notSimple = 0, noTri = 0, fellBack = 0;
    var ov = 0, gp = 0, samples = 0, bevelNodes = 0;
    final js = Justification.values;
    for (var trial = 0; trial < 10000; trial++) {
      final hub = far(rnd.nextDouble() * 1e5, rnd.nextDouble() * 1e5);
      final k = 2 + rnd.nextInt(4);
      final angles = <double>[];
      while (angles.length < k) {
        final a = rnd.nextDouble() * 360;
        // Distinct directions: two ends in one direction is overlap, not a
        // node, and out of scope here.
        if (angles.every((b) {
          final d = ((a - b) % 360 + 360) % 360;
          return d > 1 && d < 359;
        })) {
          angles.add(a);
        }
      }
      final all = [
        for (final a in angles)
          () {
            final len = 30 + rnd.nextDouble() * 4000;
            final t = 50 + rnd.nextDouble() * 350;
            final j = js[rnd.nextInt(3)];
            final far0 = polar(hub, a, len);
            return rnd.nextBool() ? wall(hub, far0, t, j) : wall(far0, hub, t, j);
          }(),
      ];
      final rings = <List<Vector2>>[];
      for (final w in all) {
        walls++;
        final raw = ring(w, all, fallback: false);
        final r = ring(w, all);
        if (!isSimpleCcw(raw)) fellBack++;
        if (!isSimpleCcw(r)) notSimple++;
        if (!triangulates(r)) {
          noTri++;
          if (noTri <= 3) {
            print('Q5 NOTRI k=$k ' + r.map((p) => '(${(p.x - hub.x).toStringAsFixed(6)}, ${(p.y - hub.y).toStringAsFixed(6)})').join(' '));
          }
        }
        rings.add(r);
      }
      if (trial < 300) {
        final (o, g, n) = census(rings, all, hub, 60);
        ov += o;
        gp += g;
        samples += n;
      }
      // Count nodes where some wedge clamps.
      final e0 = [
        for (final w in all)
          End(w, (w.s - hub).length < 1e-3 ? 0 : 1),
      ];
      final node = classify(all.first, e0.first.k, all.sublist(1));
      if (node is NodeJoint) {
        final ends = node.ends;
        for (var i = 0; i < ends.length; i++) {
          final x = ends[i], y = ends[(i + 1) % ends.length];
          final c = intersect(x.leftPoint(x.p), x.a, y.rightPoint(y.p), y.a);
          if (c == null ||
              (c - hub).length > mitreLimit / 2 * math.max(x.wall.t, y.wall.t)) {
            bevelNodes++;
            break;
          }
        }
      }
    }
    print('Q5 hole lobes (counted per wall call) $holeLobes');
    print('Q5 walls $walls fell back $fellBack not simple $notSimple '
        'no triangulation $noTri; nodes with a clamp $bevelNodes; '
        'census (r=60, 300 nodes) overlap $ov gap $gp of $samples');
    expect(notSimple, 0);
    expect(noTri, 0);
  });
}
