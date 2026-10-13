// Spec K6: the shared shape helpers. Every fixture is off the origin and,
// where a direction matters, at a non-axis angle; the cleaning test is the
// one place a coordinate lands on zero, because that is where rotation dust
// shows.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/authoring.dart';

List<CatalogPoint> pointsOf(CatalogShape s) => (s as CatalogPolyline).points;

/// The centroid of a chair's seat (four distinct corners).
(double, double) centreOf(CatalogShape seat) {
  final p = pointsOf(seat);
  return (
    p.fold(0.0, (a, q) => a + q.$1) / p.length,
    p.fold(0.0, (a, q) => a + q.$2) / p.length,
  );
}

(double, double) midOf(CatalogShape line) {
  final l = line as CatalogLine;
  return ((l.from.$1 + l.to.$1) / 2, (l.from.$2 + l.to.$2) / 2);
}

double dist((double, double) a, (double, double) b) =>
    math.sqrt(math.pow(a.$1 - b.$1, 2) + math.pow(a.$2 - b.$2, 2));

Iterable<double> coordinatesOf(List<CatalogShape> shapes) sync* {
  for (final s in shapes) {
    switch (s) {
      case CatalogLine(:final from, :final to):
        yield* [from.$1, from.$2, to.$1, to.$2];
      case CatalogPolyline(:final points):
        for (final p in points) {
          yield* [p.$1, p.$2];
        }
      case CatalogCircle(:final center):
        yield* [center.$1, center.$2];
      case CatalogArc(:final center):
        yield* [center.$1, center.$2];
    }
  }
}

void main() {
  test("H1 today's constants", () {
    expect(chairSize, 450);
    expect(chairTuck, 100);
    expect(stoolRadius, 190);
    expect(stoolTuck, 40);
  });

  test('H2 rect and inset are closed, off the origin', () {
    final r = rect(1200, -350, 800, 600) as CatalogPolyline;
    expect(r.closed, isTrue);
    // M-H2: swap w and h.
    expect(r.points, [(1200, -350), (2000, -350), (2000, 250), (1200, 250)]);
    expect(pointsOf(inset(1200, -350, 800, 600, 50)),
        [(1250, -300), (1950, -300), (1950, 200), (1250, 200)]);
    final p = poly([(10, 20), (30, 25), (15, 60)]) as CatalogPolyline;
    expect(p.closed, isTrue);
    expect(p.points, [(10, 20), (30, 25), (15, 60)]);
  });

  test(
      'H3 a chair: a 450 square on its centre, the back 165 away from the '
      'table', () {
    const facing = 0.7;
    final chair = chairAt(2500, 1300, facing);
    expect(chair, hasLength(2));
    final (cx, cy) = centreOf(chair[0]);
    expect(cx, closeTo(2500, 1e-5));
    expect(cy, closeTo(1300, 1e-5));
    for (final corner in pointsOf(chair[0])) {
      expect(dist(corner, (2500, 1300)), closeTo(225 * math.sqrt2, 1e-5));
    }
    final back = chair[1] as CatalogLine;
    expect(dist(back.from, back.to), closeTo(450, 1e-5));
    final mid = midOf(back);
    // M-H3a: `_chairBack = 70` puts the back 155 from the centre.
    expect(dist(mid, (2500, 1300)), closeTo(165, 1e-5));
    // M-H3b: the back on the table's side (u = +h - 60): the dot is +1.
    final out = ((mid.$1 - 2500) / 165, (mid.$2 - 1300) / 165);
    expect(out.$1 * math.cos(facing) + out.$2 * math.sin(facing),
        closeTo(-1, 1e-6));
  });

  test(
      'H4 chairs around a round top: the first straight below, each tucked '
      '100, each facing the top', () {
    const top = (3000.0, 2000.0);
    final shapes = chairsAround(top.$1, top.$2, 400, 5);
    expect(shapes, hasLength(10));
    final first = centreOf(shapes[0]);
    // M-H4a: start at angle 0 instead of -pi/2.
    expect(first.$1, closeTo(3000, 1e-6));
    expect(first.$2, lessThan(2000));
    for (var i = 0; i < 5; i++) {
      final c = centreOf(shapes[2 * i]);
      // M-H4b: `r + chairSize / 2 + chairTuck` puts them at 725.
      expect(dist(c, top), closeTo(400 + 225 - 100, 1e-5), reason: 'chair $i');
      // M-H4c: facing `a` instead of `a + pi`: the back is at 360, not 690.
      expect(dist(midOf(shapes[2 * i + 1]), top), closeTo(525 + 165, 1e-5),
          reason: 'chair $i');
    }
  });

  test('H5 a stool: the seat, then the footrest, on one centre', () {
    final stool = stoolAt(-700, 820);
    // M-H5: the footrest first.
    expect([for (final s in stool) (s as CatalogCircle).radius], [190, 150]);
    for (final s in stool) {
      expect((s as CatalogCircle).center, (-700, 820));
    }
  });

  test('H6 stools around a round top reach 40 under it, the first below', () {
    final shapes = stoolsAround(1000, 600, 300, 3);
    expect(shapes, hasLength(6));
    final centres = [
      for (var i = 0; i < 6; i += 2) (shapes[i] as CatalogCircle).center
    ];
    expect(centres.first.$1, closeTo(1000, 1e-6));
    expect(centres.first.$2, closeTo(150, 1e-6));
    for (final c in centres) {
      // M-H6: `+ stoolTuck` puts them at 530.
      expect(dist(c, (1000, 600)), closeTo(300 + 190 - 40, 1e-5));
    }
  });

  test('H7 every coordinate is cleaned to 1e-6, and no zero is negative', () {
    // At (225, 225) facing +y, a corner's y is 225 - 225 plus the dust of
    // cos(pi/2) = 6e-17 times 225: -1.4e-14 before cleaning, 0 after.
    final shapes = chairAt(225, 225, math.pi / 2);
    final all = coordinatesOf(shapes).toList();
    // M-H7a: drop the cleaning; the dust survives.
    expect(all, contains(0.0));
    for (final c in all) {
      expect(c, cleanCoordinate(c));
      // M-H7b: return `r` without the `r == 0` fix; -0.0 survives.
      expect(c == 0 && c.isNegative, isFalse, reason: '$c');
    }
    // M-H7c: rect does not clean; 0.30000000000000004 survives.
    expect(pointsOf(rect(0.1, 0.2, 0.2, 0.1)),
        [(0.1, 0.2), (0.3, 0.2), (0.3, 0.3), (0.1, 0.3)]);
  });

  test('H8 cleanCoordinate', () {
    expect(cleanCoordinate(1.0000004), 1.0);
    expect(cleanCoordinate(1.0000006), 1.000001);
    expect(cleanCoordinate(2.5), 2.5);
    expect(cleanCoordinate(-1e-9), 0.0);
    expect(cleanCoordinate(-1e-9).isNegative, isFalse);
  });
}
