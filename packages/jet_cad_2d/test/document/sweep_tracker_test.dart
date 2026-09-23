import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

const double tau = 2 * math.pi;

/// The reference (spec 05, Differential check): the true signed angle a
/// straight pointer segment sweeps around (cx, cy), by summing 64
/// sub-sample steps. Each sub-step is far below π, so wrapping it is exact.
double segmentTravel(
    double cx, double cy, double ax, double ay, double bx, double by) {
  var total = 0.0;
  var prev = math.atan2(ay - cy, ax - cx);
  for (var k = 1; k <= 64; k++) {
    final t = k / 64;
    final a = math.atan2(ay + (by - ay) * t - cy, ax + (bx - ax) * t - cx);
    total += wrapAngle(a - prev);
    prev = a;
  }
  return total;
}

void main() {
  test('S1 wrapAngle maps into (−π, π]', () {
    expect(wrapAngle(0), 0);
    expect(wrapAngle(math.pi), closeTo(math.pi, 1e-15));
    expect(wrapAngle(-math.pi), closeTo(math.pi, 1e-15));
    expect(wrapAngle(1.5 * math.pi), closeTo(-0.5 * math.pi, 1e-15));
    expect(wrapAngle(-1.5 * math.pi), closeTo(0.5 * math.pi, 1e-15));
    expect(wrapAngle(7.0), closeTo(7.0 - tau, 1e-15));
  });

  test('S2 counter-clockwise travel gives the positive sweep', () {
    final t = SweepTracker()..begin(0.3);
    t
      ..track(0.8)
      ..track(1.6)
      ..track(2.2);
    expect(t.sweepTo(2.2), closeTo(1.9, 1e-12));
  });

  test('S3 clockwise travel gives the negative sweep (M-05g)', () {
    final t = SweepTracker()..begin(0.3);
    t
      ..track(-0.2)
      ..track(-0.9);
    // The same end angle a CCW path would reach the long way round.
    expect(t.sweepTo(-0.9), closeTo(-1.2, 1e-12));
    expect(t.sweepTo(2.2), closeTo(1.9 - tau, 1e-12),
        reason: 'the direction is the travelled one, not the short way');
  });

  test('S4 travel across the ±π seam keeps its direction (M-05f)', () {
    final t = SweepTracker()..begin(2.9);
    t
      ..track(3.1)
      ..track(-3.1) // just past π: a raw difference would be −6.2
      ..track(-2.8);
    expect(t.travel, greaterThan(0));
    expect(t.sweepTo(-2.8), closeTo(-2.8 + tau - 2.9, 1e-12));
  });

  test('S5 no travel at all is counter-clockwise (M-05z)', () {
    final t = SweepTracker()..begin(0.3);
    expect(t.travel, 0);
    expect(t.sweepTo(1.4), closeTo(1.1, 1e-12),
        reason: 'τ == 0 is the CCW tie-break (spec D8)');
    t
      ..track(0.9)
      ..track(0.3); // out and back, cancelling exactly
    // Deviation from the brief: exact 0 fails by 4.44e-16. Wrapping the
    // negative leg through +τ then subtracting τ back out is not an exact
    // round trip in double precision, unlike the positive leg (which needs
    // no wrap at all). closeTo admits that residual without hiding a real
    // accumulation bug (which would be orders of magnitude larger).
    expect(t.travel, closeTo(0, 1e-15));
    expect(t.sweepTo(1.4), greaterThan(0));
  });

  test('S6 an end on the start is refused, even after a full turn', () {
    final t = SweepTracker()..begin(0.3);
    for (var a = 0.3; a < 0.3 + tau; a += 0.5) {
      t.track(a);
    }
    expect(t.sweepTo(0.3), 0, reason: 'a full circle is not an arc');
    expect(t.sweepTo(0.3 + tau), 0);
    // Wind past a full turn, then come back part way: the sign follows the
    // cumulative travel, unclamped (Ruling 05-1).
    final u = SweepTracker()..begin(0.0);
    for (var a = 0.0; a <= 3 * math.pi; a += 0.4) {
      u.track(a);
    }
    for (var a = 3 * math.pi; a >= math.pi; a -= 0.4) {
      u.track(a);
    }
    expect(u.travel, greaterThan(0));
    expect(u.sweepTo(math.pi), greaterThan(0));
  });

  test(
      'differential: sweepTo matches the swept reference '
      '(seed 0x5EED0005, 500 trials)', () {
    final rng = math.Random(0x5EED0005);
    var skipped = 0;
    var checked = 0;
    for (var trial = 0; trial < 500; trial++) {
      final cx = 7000 + rng.nextDouble() * 400;
      final cy = 3000 + rng.nextDouble() * 300;
      final steps = 3 + rng.nextInt(18);
      var px = cx + 50 + rng.nextDouble() * 100;
      var py = cy + (rng.nextDouble() - 0.5) * 100;
      final start = math.atan2(py - cy, px - cx);
      final t = SweepTracker()..begin(start);
      var truth = 0.0;
      for (var s = 0; s < steps; s++) {
        final nx = cx + (rng.nextDouble() - 0.5) * 400;
        final ny = cy + (rng.nextDouble() - 0.5) * 400;
        truth += segmentTravel(cx, cy, px, py, nx, ny);
        t.track(math.atan2(ny - cy, nx - cx));
        px = nx;
        py = ny;
      }
      final end = math.atan2(py - cy, px - cx);
      final delta = (end - start) % tau;
      if (truth.abs() < 1e-6 || delta < 1e-6 || tau - delta < 1e-6) {
        skipped++;
        continue;
      }
      checked++;
      final expected = truth >= 0 ? delta : delta - tau;
      final got = t.sweepTo(end);
      expect(got.sign, expected.sign, reason: 'trial $trial');
      expect(got, closeTo(expected, Tolerance.standard.angular),
          reason: 'trial $trial');
    }
    // ignore: avoid_print
    print('SWEEP differential: checked $checked, skipped $skipped');
    expect(checked, greaterThan(450));
  });
}
