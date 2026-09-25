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
      // The frame is local; the oracle is world. The group is rigid.
      final ws = m.transformPoint(f.s);
      final wd = m.transformDirection(f.d);
      final wn = m.transformDirection(f.n);
      expect((ws - o.s).length, lessThan(1e-9), reason: j.name);
      expect((wd - o.d).length, lessThan(1e-9), reason: j.name);
      expect((wn - o.n).length, lessThan(1e-9), reason: j.name);
      expect((f.len - o.len).abs(), lessThan(1e-9), reason: j.name);
      expect(o.len, closeTo(3700, 1e-6), reason: j.name);
      expect(f.lOff, o.lo, reason: j.name);
      expect(f.rOff, o.ro, reason: j.name);
      expect(f.fellBack, isFalse, reason: j.name);
      expect(f.uS.abs(), lessThan(1e-9), reason: j.name);
      expect((f.uE - f.len).abs(), lessThan(1e-9), reason: j.name);
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
      'HF3 T obstacles: 07\'s WG4 T at 58° butts the host\'s near face; '
      '07\'s WG19 shallow T is its stem\'s square end inside the host', () {
    // WG4: a 115 centre stem onto a 200 right-justified host.
    final host = worldWall(5, plan(-2000, 0), plan(3000, 0), 200, right);
    final p = plan(700, 0);
    final stem = worldWall(6, polar(p, 58 + rot, 2400), p, 115, centre);
    final walls = [host, stem];
    final f = hostFrameOf(host, walls)!;
    final obs = obstaclesOf(f, host, walls);
    expect(obs, hasLength(1));
    expect(obs.single.wall, stem.handle);
    final oh = oracleOf(host);
    final (lo, hi) = oracleRange(oh, oracleTeeButt(oh, oracleOf(stem), 1));
    expect(hi - lo, greaterThan(100), reason: 'not degenerate');
    expect((obs.single.a - lo).abs(), lessThan(1e-6));
    expect((obs.single.b - hi).abs(), lessThan(1e-6));

    // WG19: onto a 300 centre host at 10° the butt's corners lie beyond
    // 4 × 150 of the end, so the stem squares at its own end; at 25° it
    // butts the near face.
    final host2 = worldWall(95, plan(-2000, 0), plan(3000, 0), 300, centre);
    for (final deg in const [10.0, 25.0]) {
      final stem2 = worldWall(96, polar(p, deg + rot, 2400), p, 115, centre);
      final walls2 = [host2, stem2];
      final f2 = hostFrameOf(host2, walls2)!;
      final obs2 = obstaclesOf(f2, host2, walls2);
      expect(obs2, hasLength(1), reason: '$deg°');
      final oh2 = oracleOf(host2), os2 = oracleOf(stem2);
      final want =
          deg == 10 ? oracleSquareEnd(os2, 1) : oracleTeeButt(oh2, os2, 1);
      final (lo2, hi2) = oracleRange(oh2, want);
      expect((obs2.single.a - lo2).abs(), lessThan(1e-6), reason: '$deg°');
      expect((obs2.single.b - hi2).abs(), lessThan(1e-6), reason: '$deg°');
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
      'tolerance apart leave no sliver', () {
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
