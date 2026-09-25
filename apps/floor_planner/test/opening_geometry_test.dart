// Spec 08 D7, D8: the host frame, its obstacles and stretches, and where an
// opening cuts. Every wall is at the far origin in its own rotated group
// (`groupAt`), no host is axis-aligned, and no opening is central. The
// expected values come from `support/opening_fixture.dart`'s oracles, which
// never call the geometry under test.
import 'package:floor_planner/parametric/opening_geometry.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/parametric/wall_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/opening_fixture.dart';
import 'support/wall_fixture.dart';

const centre = Justification.centre;
const left = Justification.left;
const right = Justification.right;

/// The plan's rotation for relational fixtures: never 0° or 90°.
const double rot = 23;

OracleFrame oracleOf(WorldWall w) => oracleFrame(w.params, w.toWorld);

/// Every cap vertex's `u` in [f].
List<double> capUs(HostFrame f) => [
      for (final q in [...f.startCap, ...f.endCap]) f.uOf(q)
    ];

void main() {
  test(
      'HF1 a 3,700 mm wall at 31°, each justification: s, d, n, len, lOff '
      'and rOff equal the oracle\'s; the free wall\'s span is [0, L]', () {
    for (final j in Justification.values) {
      final s = plan(-1200, 450);
      final w = worldWall(31, s, polar(s, 31, 3700), 115, j);
      final f = hostFrameOf(w, [w])!;
      final o = oracleOf(w);
      final m = w.toWorld;
      // The frame is local; the oracle is world. The group is rigid. The
      // bound is 1e-8: at the far origin one ulp is ~9.3e-10, and the caps
      // are computed in world and taken to local, so a free end's `u` lands
      // a few ulps off 0 or L (Task 3's review swept 3,600 neighbouring
      // fixtures: 114 exceed 1e-9, the largest 1.75e-9). Every mutant this
      // test guards moves a value by far more.
      const bound = 1e-8;
      final ws = m.transformPoint(f.s);
      final wd = m.transformDirection(f.d);
      final wn = m.transformDirection(f.n);
      expect((ws - o.s).length, lessThan(bound), reason: j.name);
      expect((wd - o.d).length, lessThan(bound), reason: j.name);
      expect((wn - o.n).length, lessThan(bound), reason: j.name);
      expect((f.len - o.len).abs(), lessThan(bound), reason: j.name);
      expect(o.len, closeTo(3700, 1e-6), reason: j.name);
      expect(f.lOff, o.lo, reason: j.name);
      expect(f.rOff, o.ro, reason: j.name);
      expect(f.fellBack, isFalse, reason: j.name);
      expect(f.uS.abs(), lessThan(bound), reason: j.name);
      expect((f.uE - f.len).abs(), lessThan(bound), reason: j.name);
    }
  });

  test(
      'HF2 the 67° L (A 200, B 115), all nine justification pairs: A\'s uE '
      'and B\'s uS are the u of the oracle\'s mitre corners; no cap vertex '
      'lies strictly inside a span', () {
    for (final ja in Justification.values) {
      for (final jb in Justification.values) {
        final why = '${ja.name}/${jb.name}';
        final h = plan(0, 0);
        final a = worldWall(1, plan(-3000, 0), h, 200, ja);
        final b = worldWall(2, h, polar(h, 180 - 67 + rot, 2500), 115, jb);
        final fa = hostFrameOf(a, [a, b])!, fb = hostFrameOf(b, [a, b])!;
        expect(fa.fellBack || fb.fellBack, isFalse, reason: why);
        final oa = oracleOf(a), ob = oracleOf(b);
        final corners = oracleMitre(oa, ob);
        // Not degenerate: the two corners sit at different u on each wall.
        final (aMin, aMax) = oracleRange(oa, corners);
        final (bMin, bMax) = oracleRange(ob, corners);
        expect(aMax - aMin, greaterThan(10), reason: why);
        expect(bMax - bMin, greaterThan(10), reason: why);
        expect((fa.uE - aMin).abs(), lessThan(1e-6), reason: why);
        expect((fb.uS - bMax).abs(), lessThan(1e-6), reason: why);
        // The free ends.
        expect(fa.uS.abs(), lessThan(1e-6), reason: why);
        expect((fb.uE - fb.len).abs(), lessThan(1e-6), reason: why);
        for (final f in [fa, fb]) {
          for (final u in capUs(f)) {
            expect(u > f.uS && u < f.uE, isFalse, reason: '$why: $u');
          }
        }
      }
    }
  });

  test(
      'HF3 T obstacles: 07\'s WG4 T at 58° butts the host\'s near face; a '
      'stem whose start tees in from the host\'s right; 07\'s WG19 shallow '
      'T covers its stem\'s whole footprint in the band, square end to '
      'where its faces leave the near face (D7, Task 3 review S1)', () {
    // WG4: a 115 centre stem onto a 200 right-justified host, from its left.
    final host = worldWall(5, plan(-2000, 0), plan(3000, 0), 200, right);
    final p = plan(700, 0);
    final stem = worldWall(6, polar(p, 58 + rot, 2400), p, 115, centre);
    final walls = [host, stem];
    final f = hostFrameOf(host, walls)!;
    final obs = obstaclesOf(f, host, walls);
    expect(obs, hasLength(1));
    expect(obs.single.wall, stem.handle);
    final oh = oracleOf(host);
    final (lo, hi) = oracleRange(oh, oracleTeeFootprint(oh, oracleOf(stem), 1));
    expect(hi - lo, greaterThan(100), reason: 'not degenerate');
    expect((obs.single.a - lo).abs(), lessThan(1e-6));
    expect((obs.single.b - hi).abs(), lessThan(1e-6));

    // A stem whose START (k = 0) lies on a 240 centre host, its body on the
    // host's right, so it butts the right face.
    final host1 = worldWall(14, plan(-1500, 0), plan(2800, 0), 240, centre);
    final p1 = plan(1100, 0);
    final stem1 = worldWall(15, p1, polar(p1, -63 + rot, 2100), 150, left);
    final walls1 = [host1, stem1];
    expect(strictlyInside(stem1.s, host1), isTrue);
    final obs1 = obstaclesOf(hostFrameOf(host1, walls1)!, host1, walls1);
    expect(obs1, hasLength(1));
    expect(obs1.single.wall, stem1.handle);
    final oh1 = oracleOf(host1);
    final os1 = oracleOf(stem1);
    final butt1 = oracleTeeButt(oh1, os1, 0);
    // Not degenerate: the corners lie on the right face, off the left one.
    for (final q in butt1) {
      final v = (q.x - oh1.s.x) * oh1.n.x + (q.y - oh1.s.y) * oh1.n.y;
      expect(v, closeTo(oh1.ro, 1e-6));
    }
    final (lo1, hi1) = oracleRange(oh1, oracleTeeFootprint(oh1, os1, 0));
    expect(hi1 - lo1, greaterThan(100), reason: 'not degenerate');
    expect((obs1.single.a - lo1).abs(), lessThan(1e-6));
    expect((obs1.single.b - hi1).abs(), lessThan(1e-6));

    // WG19: onto a 300 centre host at 10° the butt's corners lie beyond
    // 4 × 150 of the end, so 07 squares the stem at its own end, and its
    // band still crosses the host's band until its faces leave the near
    // face; at 25° it butts the near face.
    final host2 = worldWall(95, plan(-2000, 0), plan(3000, 0), 300, centre);
    for (final deg in const [10.0, 25.0]) {
      final stem2 = worldWall(96, polar(p, deg + rot, 2400), p, 115, centre);
      final walls2 = [host2, stem2];
      final f2 = hostFrameOf(host2, walls2)!;
      final obs2 = obstaclesOf(f2, host2, walls2);
      expect(obs2, hasLength(1), reason: '$deg°');
      final oh2 = oracleOf(host2), os2 = oracleOf(stem2);
      final footprint = oracleTeeFootprint(oh2, os2, 1);
      // The oracle's own clamp decision: 07's, independently.
      expect(footprint, hasLength(deg == 10 ? 4 : 2), reason: '$deg°');
      final (lo2, hi2) = oracleRange(oh2, footprint);
      expect((obs2.single.a - lo2).abs(), lessThan(1e-6), reason: '$deg°');
      expect((obs2.single.b - hi2).abs(), lessThan(1e-6), reason: '$deg°');
      if (deg == 10) {
        // The square end alone would be ~20 mm; the footprint is ~1,192.
        expect(obs2.single.a, closeTo(2690.0, 0.05));
        expect(obs2.single.b, closeTo(3881.8, 0.05));
        // A door at u 2,710-3,610 would sit under the stem: no stretch
        // holds it, and placing it there moves it clear of the stem.
        final st = stretchesOf(f2, obs2);
        expect(st.any((s) => s.$1 <= 2710 && s.$2 >= 3610), isFalse);
        final cut = placeCut(st, 3160, 900)!;
        expect(cut.clamped, isTrue);
        expect(cut.b <= obs2.single.a || cut.a >= obs2.single.b, isTrue,
            reason: '[${cut.a}, ${cut.b}]');
      }
    }
  });

  test(
      'HF4 an X at 71° (a 200 left host crossed by a 150 centre wall): the '
      'interval is the u-range of the four face crossings; a free end in '
      'the band and a collinear overlapping wall are no obstacles', () {
    final host = worldWall(7, plan(-2000, 0), plan(2500, 0), 200, left);
    final c = plan(600, 0);
    final x = worldWall(8, polar(c, 71 + rot + 180, 1400),
        polar(c, 71 + rot, 1700), 150, centre);
    final walls = [host, x];
    final f = hostFrameOf(host, walls)!;
    final obs = obstaclesOf(f, host, walls);
    expect(obs, hasLength(1));
    expect(obs.single.wall, x.handle);
    final oh = oracleOf(host);
    final (lo, hi) = oracleRange(oh, oracleCrossings(oh, oracleOf(x)));
    expect((obs.single.a - lo).abs(), lessThan(1e-6));
    expect((obs.single.b - hi).abs(), lessThan(1e-6));

    // A free end 100 into the band (its body on the left, the band's side),
    // off the centreline: 07 does not join it, and it is no obstacle.
    final poke = worldWall(9, polar(plan(-300, 100), 64 + rot, 1800),
        plan(-300, 100), 115, centre);
    final tip = poke.e - oh.s;
    final side = tip.x * oh.n.x + tip.y * oh.n.y;
    expect(side, closeTo(100, 1e-6), reason: 'inside the band, 0 to 200');
    expect(classify(poke, 1, [host]), isA<Free>());
    // A collinear wall overlapping the host's end: its start lies on the
    // host's centreline, strictly inside it.
    final along = worldWall(10, plan(1800, 0), plan(4200, 0), 200, left);
    expect(strictlyInside(along.s, host), isTrue, reason: 'not degenerate');
    expect(classify(along, 0, [host]), isA<Tee>(), reason: '07 tees it');
    for (final other in [poke, along]) {
      final ws = [host, other];
      final fo = hostFrameOf(host, ws)!;
      expect(obstaclesOf(fo, host, ws), isEmpty,
          reason: '${other.handle.value}');
    }
  });

  test(
      'HF5 stretches: the span minus a T and an X is three sorted stretches '
      'whose ends are the obstacles\' own bits; two obstacles half a '
      'tolerance apart leave no sliver; a nested obstacle does not reopen '
      'its outer one; an obstacle beyond uE leaves the span whole', () {
    final host = worldWall(11, plan(-2000, 0), plan(3000, 0), 200, right);
    final p = plan(-700, 0);
    final stem = worldWall(12, polar(p, 58 + rot, 2400), p, 115, centre);
    final c = plan(1400, 0);
    final x = worldWall(13, polar(c, 71 + rot + 180, 1400),
        polar(c, 71 + rot, 1700), 150, centre);
    final walls = [host, x, stem];
    final f = hostFrameOf(host, walls)!;
    final obs = obstaclesOf(f, host, walls);
    expect([for (final o in obs) o.wall], [stem.handle, x.handle]);
    final st = stretchesOf(f, obs);
    expect(st, [
      (f.uS, obs[0].a),
      (obs[0].b, obs[1].a),
      (obs[1].b, f.uE),
    ]);
    for (var i = 0; i < st.length; i++) {
      expect(st[i].$1 < st[i].$2, isTrue);
      if (i > 0) expect(st[i - 1].$2 < st[i].$1, isTrue);
    }

    // Synthetic obstacles, 0.5 × wallJoin.linear apart.
    final gap = 0.5 * wallJoin.linear;
    final near = [
      (a: 1000.25, b: 1400.5, wall: x.handle),
      (a: 1400.5 + gap, b: 1900.75, wall: stem.handle),
    ];
    expect(near[1].a > near[0].b, isTrue, reason: 'a real gap');
    expect(stretchesOf(f, near), [(f.uS, 1000.25), (1900.75, f.uE)]);

    // A "+": two stems tee in at one point from opposite sides, 200 from
    // the left and 115 from the right, so the thinner one's interval lies
    // inside the thicker one's.
    final plus = worldWall(19, plan(-1800, 0), plan(3200, 0), 200, centre);
    final q = plan(900, 0);
    final wide = worldWall(20, polar(q, 80 + rot, 1600), q, 200, centre);
    final thin = worldWall(21, polar(q, 80 + rot + 180, 1400), q, 115, centre);
    final plusWalls = [plus, wide, thin];
    final fp = hostFrameOf(plus, plusWalls)!;
    final op = obstaclesOf(fp, plus, plusWalls);
    expect([for (final o in op) o.wall], [wide.handle, thin.handle]);
    expect(op[0].a < op[1].a && op[1].b < op[0].b, isTrue, reason: 'nested');
    expect(stretchesOf(fp, op), [(fp.uS, op[0].a), (op[0].b, fp.uE)]);

    // A 50° L of two 200 walls: its end cap reaches ~215 mm back from the
    // node, and a stem teeing in 90 mm back lies wholly inside that mitre
    // zone, beyond uE.
    final node = plan(0, 0);
    final la = worldWall(16, plan(-3000, 0), node, 200, centre);
    final lb =
        worldWall(17, node, polar(node, 180 - 50 + rot, 2500), 200, centre);
    final r = plan(-90, 0);
    final late = worldWall(18, polar(r, -80 + rot, 1500), r, 115, centre);
    final lWalls = [la, lb, late];
    final fl = hostFrameOf(la, lWalls)!;
    expect(fl.fellBack, isFalse);
    final ol = obstaclesOf(fl, la, lWalls);
    expect(ol, hasLength(1));
    expect(ol.single.a, greaterThan(fl.uE + 50), reason: 'wholly beyond uE');
    expect(ol.single.b, lessThan(fl.len));
    expect(stretchesOf(fl, ol), [(fl.uS, fl.uE)]);
  });

  test(
      'HF6 placement: an unclamped cut starts at c − w/2 bit for bit; a tie '
      'goes to the lower a; a degenerate width or position places nothing', () {
    const stretches = [(12.5, 1800.75), (2300.25, 4100.5)];
    const c = 3100.3, w = 900.1;
    final cut = placeCut(stretches, c, w)!;
    expect(cut.a, c - w / 2);
    expect(cut.b, cut.a + w);
    expect(cut.clamped, isFalse);
    // Clamped against the stretch's start.
    final clamped = placeCut(stretches, 2400.5, w)!;
    expect(clamped.a, 2300.25);
    expect(clamped.clamped, isTrue);

    // 1500.5 is 500.25 from each stretch, and both hold 500.
    const tie = [(100.25, 1000.25), (2000.75, 3000.75)];
    expect(1500.5 - tie[0].$2, tie[1].$1 - 1500.5);
    final t = placeCut(tie, 1500.5, 500)!;
    expect(t.a, 500.25);
    expect(t.b, 1000.25);
    expect(t.clamped, isTrue);

    for (final bad in [
      wallJoin.linear,
      0.5 * wallJoin.linear,
      0.0,
      -900.0,
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      expect(placeCut(stretches, c, bad), isNull, reason: 'width $bad');
    }
    for (final bad in [double.nan, double.infinity, double.negativeInfinity]) {
      expect(placeCut(stretches, bad, w), isNull, reason: 'position $bad');
    }
    // Control: just above the tolerance places.
    expect(placeCut(stretches, c, nextUp(wallJoin.linear)), isNotNull);
  });

  test(
      'OG5 (M-08w) a T splits the span: the stretch nearest the centre is '
      'too narrow and a farther one fits, so the farther one holds it; with '
      'both too narrow there is no fit', () {
    final host = worldWall(21, plan(-1500, 600), plan(2500, 600), 200, centre);
    final p = plan(-600, 600);
    final stem = worldWall(22, polar(p, 75 + rot, 2000), p, 115, centre);
    final walls = [host, stem];
    final f = hostFrameOf(host, walls)!;
    final obs = obstaclesOf(f, host, walls);
    expect(obs, hasLength(1));
    final st = stretchesOf(f, obs);
    expect(st, hasLength(2));
    final oh = oracleOf(host);
    final (_, butt) = oracleRange(oh, oracleTeeButt(oh, oracleOf(stem), 1));

    // Centred inside the first stretch, which is ~840 long.
    const c = 350.25, w = 1200.5;
    expect(c > st[0].$1 && c < st[0].$2, isTrue);
    expect(st[0].$2 - st[0].$1, lessThan(w));
    final cut = placeCut(st, c, w)!;
    expect(cut.a, st[1].$1);
    expect(cut.a, obs.single.b);
    expect((cut.a - butt).abs(), lessThan(1e-6));
    expect(cut.b, cut.a + w);
    expect(cut.clamped, isTrue);

    // Control: a width the first stretch holds stays there, unclamped.
    final small = placeCut(st, c, 600.5)!;
    expect(small.a, c - 600.5 / 2);
    expect(small.clamped, isFalse);

    // Wider than either stretch.
    const wide = 3200.5;
    expect(st.every((s) => s.$2 - s.$1 < wide), isTrue);
    expect(f.uE - f.uS, greaterThan(wide), reason: 'the span would hold it');
    expect(placeCut(st, c, wide), isNull);
  });
}
