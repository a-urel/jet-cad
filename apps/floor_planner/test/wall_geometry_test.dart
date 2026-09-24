import 'dart:math' as math;

import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/parametric/wall_geometry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/wall_fixture.dart';

const centre = Justification.centre;
const left = Justification.left;
const right = Justification.right;

/// The plan's rotation for relational fixtures: never 0° or 90°.
const double rot = 23;

/// [w]'s free rectangle between its face offsets [lo] and [ro], from the
/// fixture's explicit faces.
List<Vector2> rect(WorldWall w, double lo, double ro) {
  final (a, b) = face(w, lo);
  final (c, d) = face(w, ro);
  return [a, b, c, d];
}

void expectRect(List<Vector2> ring, List<Vector2> want, {String? reason}) {
  expect(ring, hasLength(4), reason: reason);
  for (final p in want) {
    expect(nearestIn(ring, p), lessThan(1e-6), reason: reason);
  }
}

void expectSound(({List<Vector2> ring, bool fellBack, List<Handle>? hole}) o,
    {String? reason}) {
  expect(isSimpleCcw(o.ring), isTrue, reason: reason);
  expect(triangulates(o.ring), isTrue, reason: reason);
  expect(o.fellBack, isFalse, reason: reason);
  expect(o.hole, isNull, reason: reason);
}

/// The index of the point of [ring] within 1e-6 of [p], or -1.
int indexNear(List<Vector2> ring, Vector2 p) =>
    ring.indexWhere((q) => (q - p).length < 1e-6);

void main() {
  test(
      'WG1 a free wall is the rectangle between its face offsets, per '
      'justification (M-07f)', () {
    final want = {
      centre: (100.0, -100.0),
      left: (200.0, 0.0),
      right: (0.0, -200.0),
    };
    for (final j in Justification.values) {
      final s = plan(-1200, 300), e = plan(2300, 1150);
      final w = worldWall(7, s, e, 200, j);
      final o = ringOf(w, [w]);
      // The left normal of s -> e, from the plan points themselves.
      final dx = e.x - s.x, dy = e.y - s.y;
      final len = math.sqrt(dx * dx + dy * dy);
      final n = Vector2(-dy / len, dx / len);
      final (lo, ro) = want[j]!;
      expectRect(o.ring, [s + n * lo, s + n * ro, e + n * lo, e + n * ro],
          reason: j.name);
      expectSound(o, reason: j.name);
    }
  });

  test(
      'WG2 the 67° L, 200 centre against 115 left: two corners shared '
      'bitwise, each equal to the oracle (M-07a, M-07b, M-07f, M-07i)', () {
    final h = plan(0, 0);
    final a = worldWall(1, plan(-3000, 0), h, 200, centre);
    final b = worldWall(2, h, polar(h, 180 - 67 + rot, 2500), 115, left);
    // Joined within tolerance, not bitwise: each wall is in its own group.
    expect(a.e.x == b.s.x && a.e.y == b.s.y, isFalse);
    expect((a.e - b.s).length, lessThan(wallJoin.linear));
    final ra = ringOf(a, [a, b]), rb = ringOf(b, [a, b]);
    expectSound(ra);
    expectSound(rb);
    expect(ra.ring, hasLength(4));
    expect(rb.ring, hasLength(4));
    final shared = sharedBitwise(ra.ring, rb.ring);
    expect(shared, hasLength(2));
    // A's faces (±100) against B's faces (+115, 0).
    final (al1, al2) = face(a, 100);
    final (ar1, ar2) = face(a, -100);
    final (bl1, bl2) = face(b, 115);
    final (br1, br2) = face(b, 0);
    expect(nearestIn(shared, oracleMeet(al1, al2, bl1, bl2)), lessThan(1e-6));
    expect(nearestIn(shared, oracleMeet(ar1, ar2, br1, br2)), lessThan(1e-6));
  });

  test(
      'WG3 control only: the 90° equal-thickness centre L has its corners '
      'at (±t/2, ±t/2) from the node', () {
    const turn = 41.0;
    final h = plan(0, 0, turn);
    final a = worldWall(3, polar(h, 180 + turn, 3000), h, 200, centre);
    final b = worldWall(4, h, polar(h, 90 + turn, 2500), 200, centre);
    final ra = ringOf(a, [a, b]), rb = ringOf(b, [a, b]);
    expectSound(ra);
    expectSound(rb);
    final shared = sharedBitwise(ra.ring, rb.ring);
    expect(shared, hasLength(2));
    // The outgoing directions from the node.
    final ua = polar(Vector2.zero(), 180 + turn, 1);
    final ub = polar(Vector2.zero(), 90 + turn, 1);
    expect(nearestIn(shared, h + (ua + ub) * 100), lessThan(1e-6));
    expect(nearestIn(shared, h - (ua + ub) * 100), lessThan(1e-6));
  });

  test(
      'WG4 the T at 58°: the stem butts the near face of a 200 '
      'right-justified wall; the through wall stays four points '
      '(M-07c, M-07r)', () {
    final b = worldWall(5, plan(-2000, 0), plan(3000, 0), 200, right);
    final p = plan(700, 0);
    final a = worldWall(6, polar(p, 58 + rot, 2400), p, 115, centre);
    final ra = ringOf(a, [a, b]), rb = ringOf(b, [a, b]);
    expectSound(ra);
    expectSound(rb);
    // The stem comes from B's left side; B's body lies right of its
    // centreline, so the near face is the centreline (offset 0).
    final (n1, n2) = face(b, 0);
    final (f1, f2) = face(b, -200);
    final capPoints = [
      for (final q in ra.ring)
        if ((q - p).length < 500) q
    ];
    expect(capPoints, hasLength(2));
    for (final q in capPoints) {
      expect(distToLine(q, n1, n2), lessThan(1e-6));
      expect(distToLine(q, f1, f2), greaterThan(100));
    }
    expectRect(rb.ring, rect(b, 0, -200));
  });

  test('WG5 an X: both crossing walls stay rectangles', () {
    final x1 = worldWall(7, plan(-1000, -1000), plan(1000, 900), 150, centre);
    final x2 = worldWall(8, plan(-1000, 800), plan(1200, -700), 240, left);
    final r1 = ringOf(x1, [x1, x2]), r2 = ringOf(x2, [x1, x2]);
    expectSound(r1);
    expectSound(r2);
    expectRect(r1.ring, rect(x1, 75, -75));
    expectRect(r2.ring, rect(x2, 240, 0));
  });

  test(
      'WG6 a three-way node, 200 centre / 115 left / 150 right: every ring '
      'simple, the central polygon covered exactly once (M-07k)', () {
    // Twice: turned so that the lowest handle (w1) sorts second by angle,
    // and so that it sorts first — ownership must not depend on either.
    for (final (turn, firstIsLowest) in const [(rot, false), (-53.0, true)]) {
      final h = plan(0, 0);
      final w1 = worldWall(11, h, polar(h, 10 + turn, 3000), 200, centre);
      final w2 = worldWall(12, polar(h, 50 + turn, 2000), h, 115, left);
      final w3 = worldWall(13, h, polar(h, 200 + turn, 2500), 150, right);
      final all = [w1, w2, w3];
      final rings = [for (final w in all) ringOf(w, all)];
      for (final o in rings) {
        expectSound(o);
      }
      // The central polygon, from the oracle. The node point is the lowest
      // handle's endpoint; w3 (right-justified, from the node) and w2
      // (left-justified, into the node) each have a face through it, and their
      // wide wedges are clamped to feet there, so the node point is one vertex.
      // w1's right foot, and the corner of w1's left face with w2's left face.
      final hub = w1.s;
      final (r1, r2) = face(w1, -100);
      final foot = project(hub, r1, r2);
      final (a1, a2) = face(w1, 100);
      final (b1, b2) = face(w2, 115);
      final corner = oracleMeet(a1, a2, b1, b2);
      final central = [hub, foot, corner];
      expect(signedArea(central), greaterThan(1000));
      for (final v in central) {
        expect(nearestIn(rings[0].ring, v), lessThan(1e-6));
      }
      final inside = [
        for (final p in diskSamples(hub, 400))
          if (insideRing(p, central)) p
      ];
      expect(inside.length, greaterThan(300));
      final covered = [
        for (final p in inside) rings.where((o) => insideRing(p, o.ring)).length
      ];
      expect(covered.where((c) => c >= 2), isEmpty, reason: 'overlap');
      expect(covered.every((c) => c == 1), isTrue, reason: 'gap');
      final node = classify(w1, 0, [w2, w3]) as NodeJoint;
      expect(node.ends.first.wall.handle == w1.handle, firstIsLowest);
    }
  });

  test(
      'WG7 the 216 common plan nodes (spike Q2c): no non-simple ring, no '
      'hole', () {
    final cases = <(String, List<(double, double, Justification, bool)>)>[];
    for (final ext in Justification.values) {
      for (final br in Justification.values) {
        final n = '${ext.name}/${br.name}';
        cases
          ..add((
            'split300+br115 $n',
            [(0, 300, ext, true), (180, 300, ext, false), (90, 115, br, true)]
          ))
          ..add((
            'split300+br300 $n',
            [(0, 300, ext, true), (180, 300, ext, false), (90, 300, br, true)]
          ))
          ..add((
            'cross200/115 $n',
            [
              (0, 200, ext, true),
              (180, 200, ext, false),
              (90, 115, br, true),
              (270, 115, br, false),
            ]
          ))
          ..add(
              ('L300/115 90° $n', [(0, 300, ext, true), (90, 115, br, false)]))
          ..add((
            'L300/300 120° $n',
            [(0, 300, ext, true), (120, 300, br, false)]
          ))
          ..add((
            'Y 200/115 $n',
            [(0, 200, ext, true), (135, 115, br, true), (225, 115, br, false)]
          ));
      }
    }
    var nodes = 0;
    final bad = <String>[];
    for (final (name, spec) in cases) {
      for (final turn in const [0.0, 17.0, 73.0, 131.0]) {
        nodes++;
        final h = far(0, 0);
        final all = [
          for (final (i, (a, t, j, fromHub)) in spec.indexed)
            fromHub
                ? worldWall(i + 1, h, polar(h, a + turn, 3000), t, j)
                : worldWall(i + 1, polar(h, a + turn, 3000), h, t, j),
        ];
        for (final w in all) {
          final o = ringOf(w, all);
          if (!isSimpleCcw(o.ring) ||
              !triangulates(o.ring) ||
              o.fellBack ||
              o.hole != null) {
            bad.add('$name rot $turn wall ${w.handle.value}');
          }
        }
      }
    }
    expect(nodes, 216);
    expect(bad, isEmpty);
  });

  test('WG8 a 20° L: the two bands do not overlap (M-07j)', () {
    final h = plan(0, 0);
    final a = worldWall(21, plan(-3000, 0), h, 200, centre);
    final b = worldWall(22, h, polar(h, 180 - 20 + rot, 2500), 200, centre);
    final ra = ringOf(a, [a, b]), rb = ringOf(b, [a, b]);
    expectSound(ra);
    expectSound(rb);
    expect(overlapCensus([ra.ring, rb.ring], h, 800), 0);
    // The inner mitre is real geometry: 100 / sin 10° from the node.
    final (a1, a2) = face(a, 100);
    final (b1, b2) = face(b, 100);
    final inner = oracleMeet(a1, a2, b1, b2);
    expect((inner - h).length, greaterThan(500));
    expect(sharedBitwise(ra.ring, rb.ring), hasLength(2));
    expect(nearestIn(sharedBitwise(ra.ring, rb.ring), inner), lessThan(1e-6));
  });

  test(
      'WG9 a reflex bevel: the 20° L clamps its outer wedge, and the bevel '
      'edge belongs to the lower handle', () {
    final h = plan(0, 0);
    final a = worldWall(21, plan(-3000, 0), h, 200, centre);
    final b = worldWall(22, h, polar(h, 180 - 20 + rot, 2500), 200, centre);
    final ra = ringOf(a, [a, b]).ring, rb = ringOf(b, [a, b]).ring;
    final hub = a.e; // the lowest handle's endpoint
    final (a1, a2) = face(a, -100);
    final (b1, b2) = face(b, -100);
    // Unclamped, the outer faces would meet far beyond the mitre limit.
    final mitre = oracleMeet(a1, a2, b1, b2);
    expect((mitre - hub).length, greaterThan(mitreLimit / 2 * 200));
    expect(nearestIn(ra, mitre), greaterThan(1));
    expect(nearestIn(rb, mitre), greaterThan(1));
    // Clamped: the two feet, each outer face's point at the node.
    final fa = project(hub, a1, a2), fb = project(hub, b1, b2);
    final ia = indexNear(ra, fa), ib = indexNear(ra, fb);
    expect(ia, isNot(-1));
    expect(ib, isNot(-1));
    expect((ia + 1) % ra.length, ib, reason: 'the bevel edge fa -> fb');
    expect(indexNear(rb, fb), isNot(-1));
    expect(indexNear(rb, fa), -1);
  });

  test('WG10 a collinear step, 200 centre into 115 left: two feet each', () {
    final h = plan(0, 0);
    final c = worldWall(31, plan(-3000, 0), h, 200, centre);
    final d = worldWall(32, h, plan(3000, 0), 115, left);
    final rc = ringOf(c, [c, d]), rd = ringOf(d, [c, d]);
    expectSound(rc);
    expectSound(rd);
    final hub = c.e;
    for (final (w, o, offs) in [
      (c, rc, const [100.0, -100.0]),
      (d, rd, const [115.0, 0.0]),
    ]) {
      expect(o.ring, hasLength(4));
      for (final off in offs) {
        final (p1, p2) = face(w, off);
        expect(nearestIn(o.ring, project(hub, p1, p2)), lessThan(1e-6));
      }
    }
    expect(overlapCensus([rc.ring, rd.ring], hub, 300), 0);
  });

  test(
      'WG11 a short wall between two nodes falls back alone; its '
      'neighbours still mitre against its own corners', () {
    // 150 long, 200 thick, splayed neighbours on one side: its two mitres
    // cross, so its joined ring is not simple.
    final s0 = plan(0, 0), s1 = plan(150, 0);
    final m = worldWall(41, s0, s1, 200, centre);
    final l = worldWall(42, polar(s0, 100 + rot, 2000), s0, 200, centre);
    final r = worldWall(43, s1, polar(s1, 80 + rot, 2000), 200, centre);
    final all = [m, l, r];
    final raw = ringOf(m, all, fallback: false);
    expect(isSimpleCcw(raw.ring), isFalse);
    final fixed = ringOf(m, all);
    expect(fixed.fellBack, isTrue);
    expect(isSimpleCcw(fixed.ring), isTrue);
    expectRect(fixed.ring, rect(m, 100, -100));
    for (final n in [l, r]) {
      final o = ringOf(n, all);
      expectSound(o);
      // The short wall's fallback does not reach its neighbours: each still
      // mitres against the corners the short wall's joined ring holds.
      expect(sharedBitwise(o.ring, raw.ring), hasLength(2));
    }
  });

  test(
      'WG12 a pinched node (two corners exactly on the node): every ring '
      'triangulates; simplification removes the pinch (M-07n)', () {
    // Each wall in its own rotated group: the three joints meet within
    // tolerance, not bitwise. x1's left face and x2's right face both run
    // through the node, so their wedge's corner is the node; x3's left face
    // does too, and its wide wedge with x1 is clamped to feet, the first of
    // which is the node.
    final h = plan(0, 0);
    final x1 = worldWall(51, h, polar(h, 0 + rot, 3000), 200, right);
    final x2 = worldWall(52, h, polar(h, 100 + rot, 3000), 150, left);
    final x3 = worldWall(53, h, polar(h, 185 + rot, 3000), 115, right);
    expect(x2.s.x == x1.s.x && x2.s.y == x1.s.y, isFalse);
    final hub = x1.s; // the lowest handle's endpoint
    final all = [x1, x2, x3];
    final node = classify(x1, 0, [x2, x3]) as NodeJoint;
    final central = [
      for (var w = 0; w < node.ends.length; w++)
        ...wedge(node.ends, w, nodeHub(node.ends)),
    ];
    expect(central.where((p) => p.x == hub.x && p.y == hub.y), hasLength(2));
    final rings = [for (final w in all) ringOf(w, all)];
    for (final o in rings) {
      expectSound(o);
      final tri = triangulationFor(
          EntityKind.polyline, polylinePayload(o.ring, closed: true));
      expect(tri, isNotNull);
      expect(tri, isNotEmpty);
    }
    // The pinch spliced into x1's ring as a zero-width spike (node, corner,
    // node) and as a repeated vertex: the triangulator refuses the spike;
    // simplification restores x1's ring bit for bit.
    final r1 = rings[0].ring;
    final i = r1.indexWhere((p) => p.x == hub.x && p.y == hub.y);
    expect(i, isNot(-1));
    final corner = central.firstWhere((p) => p.x != hub.x || p.y != hub.y);
    final spiked = [
      ...r1.sublist(0, i + 1),
      corner,
      Vector2.copy(hub),
      ...r1.sublist(i + 1),
    ];
    expect(triangulates(spiked), isFalse);
    expect(simplifyRing(spiked), r1);
    final doubled = [
      ...r1.sublist(0, i + 1),
      Vector2.copy(hub),
      ...r1.sublist(i + 1)
    ];
    expect(simplifyRing(doubled), r1);
    expect(triangulates(simplifyRing(spiked)), isTrue);
  });

  test(
      'WG13 property: 10,000 random nodes at the far origin, every ring '
      'simple and triangulable, shared corners bitwise', () {
    final rnd = math.Random(20260924);
    var walls = 0, sharedChecks = 0;
    final failures = <String>[];
    for (var trial = 0; trial < 10000; trial++) {
      final hub = far(rnd.nextDouble() * 1e5, rnd.nextDouble() * 1e5);
      final k = 2 + rnd.nextInt(4);
      final angles = <double>[];
      while (angles.length < k) {
        final a = rnd.nextDouble() * 360;
        if (angles.every((b) {
          final d = ((a - b) % 360 + 360) % 360;
          return d >= 1 && d <= 359;
        })) {
          angles.add(a);
        }
      }
      final all = [
        for (final (i, a) in angles.indexed)
          () {
            final len = 30 + rnd.nextDouble() * 3970;
            final t = 50 + rnd.nextDouble() * 350;
            final j = Justification.values[rnd.nextInt(3)];
            final tip = polar(hub, a, len);
            return rnd.nextBool()
                ? worldWall(i + 1, hub, tip, t, j)
                : worldWall(i + 1, tip, hub, t, j);
          }(),
      ];
      final out = {for (final w in all) w.handle: ringOf(w, all)};
      for (final w in all) {
        walls++;
        final o = out[w.handle]!;
        if (!isSimpleCcw(o.ring) || !triangulates(o.ring)) {
          failures.add('trial $trial wall ${w.handle.value}');
        }
      }
      final first = all.first;
      final k0 = (first.s - hub).length < 1 ? 0 : 1;
      final node = classify(first, k0, all.sublist(1));
      if (node is! NodeJoint || node.ends.length != k) {
        failures.add('trial $trial: not a $k-way node');
        continue;
      }
      final hubPoint = nodeHub(node.ends);
      for (var w = 0; w < k; w++) {
        final corner = wedge(node.ends, w, hubPoint);
        if (corner.length != 1) continue;
        final x = out[node.ends[w].wall.handle]!;
        final y = out[node.ends[(w + 1) % k].wall.handle]!;
        if (x.fellBack || y.fellBack) continue;
        sharedChecks++;
        final c = corner.single;
        bool holds(List<Vector2> r) => r.any((p) => p.x == c.x && p.y == c.y);
        if (!holds(x.ring) || !holds(y.ring)) {
          failures.add('trial $trial wedge $w: corner not shared bitwise');
        }
      }
    }
    expect(walls, greaterThan(30000));
    expect(sharedChecks, greaterThan(20000));
    expect(failures, isEmpty);
  });

  test(
      'WG14 plausible nodes (spike Q5b): hole rate < 1.5%, fallback rate '
      '< 0.5%', () {
    final rnd = math.Random(7707);
    const ts = [100.0, 115.0, 150.0, 200.0, 250.0, 300.0];
    var nodes = 0, holeNodes = 0, walls = 0, fellBack = 0;
    final wrongHole = <String>[];
    for (var trial = 0; trial < 20000; trial++) {
      final hub = far(rnd.nextDouble() * 1e5, rnd.nextDouble() * 1e5);
      final u = rnd.nextDouble();
      final k = u < 0.6 ? 2 : (u < 0.9 ? 3 : 4);
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
      final j0 = Justification.values[rnd.nextInt(3)];
      final all = [
        for (final (i, a) in angles.indexed)
          () {
            final t = ts[rnd.nextInt(ts.length)];
            final len = 3 * t + rnd.nextDouble() * 5000;
            final j = uniform ? j0 : Justification.values[rnd.nextInt(3)];
            final tip = polar(hub, a, len);
            return rnd.nextBool()
                ? worldWall(i + 1, hub, tip, t, j)
                : worldWall(i + 1, tip, hub, t, j);
          }(),
      ];
      var reporters = 0;
      for (final w in all) {
        walls++;
        final o = ringOf(w, all);
        if (o.fellBack) fellBack++;
        if (o.hole case final members?) {
          reporters++;
          // The owner names every member of the node.
          if (members.map((h) => h.value).join(',') !=
              [for (var i = 1; i <= k; i++) i].join(',')) {
            wrongHole.add('trial $trial: $members');
          }
        }
      }
      if (reporters > 0) holeNodes++;
      // D12: one entry per node, by the lobe's owner.
      if (reporters > 1) wrongHole.add('trial $trial: $reporters reporters');
    }
    final holeRate = 100 * holeNodes / nodes;
    final fallbackRate = 100 * fellBack / walls;
    // ignore: avoid_print
    print('WG14 nodes $nodes with a hole $holeNodes '
        '(${holeRate.toStringAsFixed(2)}%); walls $walls fell back '
        '$fellBack (${fallbackRate.toStringAsFixed(2)}%)');
    expect(nodes, greaterThan(19000));
    expect(wrongHole, isEmpty);
    expect(holeRate, lessThan(1.5));
    expect(fallbackRate, lessThan(0.5));
  });

  test(
      'WG15 a joint one ulp apart at the far origin still shares two '
      'corners (M-07d)', () {
    final hub = far(0, 0);
    final ulp = Vector2(nextUp(hub.x), hub.y);
    final a = spoke(61, hub, 180 + rot, 3000, 200, centre, fromHub: false);
    final b = spoke(62, ulp, 180 - 67 + rot, 2500, 115, left, fromHub: true);
    expect(b.s.x - a.e.x, nextUp(hub.x) - hub.x);
    expect(b.s.x, isNot(a.e.x));
    expect(b.s.y, a.e.y);
    final ra = ringOf(a, [a, b]), rb = ringOf(b, [a, b]);
    expectSound(ra);
    expectSound(rb);
    final shared = sharedBitwise(ra.ring, rb.ring);
    expect(shared, hasLength(2));
    final (al1, al2) = face(a, 100);
    final (ar1, ar2) = face(a, -100);
    final (bl1, bl2) = face(b, 115);
    final (br1, br2) = face(b, 0);
    expect(nearestIn(shared, oracleMeet(al1, al2, bl1, bl2)), lessThan(1e-6));
    expect(nearestIn(shared, oracleMeet(ar1, ar2, br1, br2)), lessThan(1e-6));
  });

  test(
      'WG16 node membership is measured from the anchor (Ruling 07-3): '
      'ends 1.8e-6 apart, each within tolerance of the lowest, form one '
      'watertight node', () {
    final hub = far(0, 0);
    final w1 = spoke(71, hub, 20 + rot, 3000, 200, centre, fromHub: true);
    final w2 = spoke(72, polar(hub, 123, 0.9e-6), 140 + rot, 3000, 115, left,
        fromHub: true);
    final w3 = spoke(
        73, polar(hub, 123 + 180, 0.9e-6), 250 + rot, 3000, 150, right,
        fromHub: false);
    expect((w2.s - w3.e).length, greaterThan(wallJoin.linear));
    final all = [w1, w2, w3];
    for (final (w, k) in [(w1, 0), (w2, 0), (w3, 1)]) {
      final j = classify(w, k, [
        for (final o in all)
          if (o != w) o
      ]);
      expect(j, isA<NodeJoint>());
      expect([for (final h in (j as NodeJoint).members) h.value], [71, 72, 73]);
    }
    final rings = [for (final w in all) ringOf(w, all)];
    for (final o in rings) {
      expectSound(o);
    }
    // Anticlockwise neighbours w1 -> w2 -> w3 -> w1 each share their
    // wedge's corner, bit for bit.
    for (final (x, y) in [(0, 1), (1, 2), (2, 0)]) {
      expect(sharedBitwise(rings[x].ring, rings[y].ring), isNotEmpty,
          reason: '$x/$y');
    }
  });

  test(
      'WG17 two ends in one direction keep free caps; the node is built '
      'from the rest (Ruling 07-4)', () {
    final hub = far(0, 0);
    final a = spoke(81, hub, 30 + rot, 3000, 200, centre, fromHub: true);
    final b = spoke(82, hub, 30 + rot, 1800, 115, left, fromHub: true);
    final c = spoke(83, hub, 150 + rot, 2500, 200, centre, fromHub: true);
    final d = spoke(84, hub, 260 + rot, 2500, 150, right, fromHub: false);
    final all = [a, b, c, d];
    expect(classify(a, 0, [b, c, d]), isA<Free>());
    expect(classify(b, 0, [a, c, d]), isA<Free>());
    final ra = ringOf(a, all), rb = ringOf(b, all);
    expectSound(ra);
    expectSound(rb);
    expectRect(ra.ring, rect(a, 100, -100));
    expectRect(rb.ring, rect(b, 115, 0));
    final rc = ringOf(c, all), rd = ringOf(d, all);
    expectSound(rc);
    expectSound(rd);
    expect(sharedBitwise(rc.ring, rd.ring), hasLength(2));
    final node = classify(c, 0, [a, b, d]) as NodeJoint;
    expect([for (final e in node.ends) e.wall.handle.value]..sort(), [83, 84]);
    expect([for (final h in node.members) h.value], [81, 82, 83, 84]);
  });

  test(
      'WG18 a degenerate wall has no ring and is never classified against '
      '(spec 07 D2)', () {
    final h = plan(0, 0);
    final z = worldWall(90, h, h, 200, centre); // zero length, lowest handle
    final a = worldWall(91, plan(-3000, 0), h, 200, centre);
    final b = worldWall(92, h, polar(h, 180 - 67 + rot, 2500), 115, left);
    final zt = worldWall(93, h, polar(h, 250 + rot, 2000), 0, centre);
    final along = worldWall(94, plan(-1000, 0), plan(-1000, 0.0000005), 200,
        centre); // on A's centreline, shorter than the tolerance
    for (final w in [z, zt, along]) {
      expect(w.degenerate, isTrue);
    }
    final all = [z, a, b, zt, along];
    expect(ringOf(z, all).ring, isEmpty);
    expect(ringOf(zt, all).ring, isEmpty);
    expect(ringOf(along, all).ring, isEmpty);
    // A and B are exactly the plain L.
    expect(ringOf(a, all).ring, ringOf(a, [a, b]).ring);
    expect(ringOf(b, all).ring, ringOf(b, [a, b]).ring);
    expect(
        sharedBitwise(ringOf(a, all).ring, ringOf(b, all).ring), hasLength(2));
  });

  test(
      'WG19 a shallow T squares its stem at its own end; a steeper one butts '
      'the near face (spec 07 D6: the limit is on the thicker wall)', () {
    final b = worldWall(95, plan(-2000, 0), plan(3000, 0), 300, centre);
    final p = plan(700, 0);
    for (final deg in const [10.0, 25.0]) {
      final a = worldWall(96, polar(p, deg + rot, 2400), p, 115, centre);
      final ra = ringOf(a, [a, b]);
      expectSound(ra, reason: '$deg°');
      final capPoints = [
        for (final q in ra.ring)
          if ((q - p).length < 1500) q
      ];
      expect(capPoints, hasLength(2), reason: '$deg°');
      final (l1, l2) = face(a, 57.5);
      final (r1, r2) = face(a, -57.5);
      final square = [project(p, l1, l2), project(p, r1, r2)];
      final (n1, n2) = face(b, 150);
      if (deg == 10) {
        // The corners on the near face lie beyond 4 × 150 of the end point.
        for (final q in square) {
          expect(nearestIn(capPoints, q), lessThan(1e-6), reason: '10°');
        }
      } else {
        // Within 4 × 150 (the thicker wall), though beyond 4 × 57.5.
        for (final q in capPoints) {
          expect(distToLine(q, n1, n2), lessThan(1e-6), reason: '25°');
          expect(nearestIn(square, q), greaterThan(100), reason: '25°');
        }
      }
    }
  });

  test(
      'WG20 an end strictly inside two centrelines (an X) tees onto the '
      'lower handle, whatever the order of the neighbours', () {
    final p = plan(0, 0);
    final lo = worldWall(97, plan(-2000, 0), plan(2000, 0), 200, right);
    final hi = worldWall(98, plan(0, -2000), plan(0, 2000), 240, centre);
    final stem = worldWall(99, polar(p, 60 + rot, 2400), p, 115, centre);
    for (final others in [
      [hi, lo],
      [lo, hi],
    ]) {
      final j = classify(stem, 1, others);
      expect(j, isA<Tee>());
      expect((j as Tee).through.handle, lo.handle);
      final ring = ringOf(stem, [stem, ...others]).ring;
      final capPoints = [
        for (final q in ring)
          if ((q - p).length < 1500) q
      ];
      expect(capPoints, hasLength(2));
      // lo's body lies right of its centreline: the stem, from its left,
      // butts the centreline itself; hi's near face would be x = +120.
      final (n1, n2) = face(lo, 0);
      final (h1, h2) = face(hi, -120);
      for (final q in capPoints) {
        expect(distToLine(q, n1, n2), lessThan(1e-6));
        expect(distToLine(q, h1, h2), greaterThan(1));
      }
    }
  });
}
