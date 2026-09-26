// Spec 10 D10, D11: the label point and the area format (RL1, RL2, RA1).
// The pole is checked against the face in plan coordinates, written by hand
// here, not against the tracer's rings: the pole's point is taken back to
// the plan through the placement and its distance to the hand-written
// boundary measured there.
import 'dart:math' as math;

import 'package:floor_planner/parametric/room_inputs.dart';
import 'package:floor_planner/parametric/room_label.dart';
import 'package:floor_planner/parametric/room_trace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/room_fixture.dart';

/// The distance from [p] to the segment [a]-[b], by hand.
double segDist(Vector2 p, Vector2 a, Vector2 b) {
  final d = b - a;
  final t = ((p - a).dot(d) / d.dot(d)).clamp(0.0, 1.0);
  return (p - (a + d * t)).length;
}

/// The distance from [p] to the closed ring [ring]'s edges.
double ringDist(Vector2 p, List<(double, double)> ring) {
  var d = double.infinity;
  for (var i = 0; i < ring.length; i++) {
    final (ax, ay) = ring[i];
    final (bx, by) = ring[(i + 1) % ring.length];
    d = math.min(d, segDist(p, Vector2(ax, ay), Vector2(bx, by)));
  }
  return d;
}

/// The room at plan point [xy] of [plan], traced through the document's
/// place source.
Traced roomAt(Plan plan, (double, double) xy) {
  final inputs = RoomInputs(plan.doc);
  addTearDown(inputs.dispose);
  final (x, y) = xy;
  final r = traceRoomAmong(plan.at(x, y), inputs);
  expect(r, isA<Traced>(), reason: '${plan.place}: $r');
  return r as Traced;
}

void main() {
  test(
      'RL1 the thin L\'s label point is inside it, 585.786 from its '
      'boundary, at six placements', () {
    // The thin L's inner faces, 100 in from the centrelines: arms 1,000
    // clear, the bottom one x 100..5,900, y 100..1,100, the upright one
    // x 100..1,100, y 100..5,900.
    const ring = [
      (100.0, 100.0),
      (5900.0, 100.0),
      (5900.0, 1100.0),
      (1100.0, 1100.0),
      (1100.0, 5900.0),
      (100.0, 5900.0),
    ];
    bool inside(Vector2 p) =>
        (p.x > 100 && p.x < 5900 && p.y > 100 && p.y < 1100) ||
        (p.x > 100 && p.x < 1100 && p.y > 100 && p.y < 5900);
    // By hand: the widest point is in the corner square, on its diagonal,
    // where the circle touches both outer faces (x = 100, y = 100) and the
    // reflex corner (1,100, 1,100): x - 100 = sqrt2 (1,100 - x), so x =
    // (100 + 1,100 sqrt2) / (1 + sqrt2) = 685.786 and the distance x - 100
    // = 585.786. The arms alone allow 500.
    final x = (100 + 1100 * math.sqrt2) / (1 + math.sqrt2);
    final hand = x - 100;
    expect(hand, closeTo(585.786, 1e-3));
    // Not the centroid, nor the box centre, both outside: the arms'
    // centroids (3,000, 600) and (600, 3,500), areas 5.8e6 and 4.8e6, give
    // ((3,000 x 5.8 + 600 x 4.8) / 10.6, (600 x 5.8 + 3,500 x 4.8) / 10.6)
    // = (1,913.2, 1,913.2), 813 mm past the reflex corner on each axis; the
    // ring's box centre (3,000, 3,000) is 1,900 mm past it.
    const why = 'the centroid (1,913.2, 1,913.2) lies 813 mm outside and the '
        'box centre (3,000, 3,000) 1,900 mm outside';
    expect(inside(Vector2(1913.2, 1913.2)), isFalse);
    expect(inside(Vector2(3000, 3000)), isFalse);
    for (final place in placements) {
      final what = 'the thin L at $place';
      final plan = buildPlan(thinLWalls, place: place);
      final t = roomAt(plan, (600, 600));
      expect(t.area, closeTo(10600000, 1e-2), reason: what);
      final pole = poleOfInaccessibility(t.ring, t.holes);
      final p = place.m.invert().transformPoint(pole.point);
      expect(inside(p), isTrue, reason: '$what: the pole $p inside; $why');
      final d = ringDist(p, ring);
      expect((d - hand).abs(), lessThanOrEqualTo(10),
          reason: '$what: the pole $p is $d from the boundary; $why');
      expect(pole.distance, closeTo(d, 1e-3), reason: '$what: its distance');
      // ignore: avoid_print
      print('RL1 at $place: the pole at $p (plan), $d from the boundary');
      if (place == origin) {
        expect((pole.point - Vector2(x, x)).length, lessThanOrEqualTo(10),
            reason: '$what: ${pole.point} against ($x, $x)');
      }
    }
  });

  test('RL2 a column at the box centre moves the label point off it', () {
    // The box's inner faces x 100..7,900, y 100..3,900, centre (4,000,
    // 2,000); the column x 3,800..4,200, y 1,800..2,200. By hand, the
    // widest circle sits beside the column, between it and an end wall:
    // (3,800 - 100) / 2 = 1,850, under the half-height 1,900 (the spike:
    // 1,849.78 each).
    const outer = [
      (100.0, 100.0),
      (7900.0, 100.0),
      (7900.0, 3900.0),
      (100.0, 3900.0),
    ];
    const column = [
      (3800.0, 1800.0),
      (4200.0, 1800.0),
      (4200.0, 2200.0),
      (3800.0, 2200.0),
    ];
    for (final place in placements) {
      final what = 'the box and its column at $place';
      final plan = buildPlan(
          [...boxWalls, const W(3800, 2000, 4200, 2000, 400)],
          place: place);
      final t = roomAt(plan, (1000, 1000));
      expect(t.holes, hasLength(1), reason: what);
      // 7,800 x 3,800 - 400 x 400 = 29,640,000 - 160,000 = 29,480,000.
      expect(t.area, closeTo(29480000, 1e-2), reason: what);
      final pole = poleOfInaccessibility(t.ring, t.holes);
      final p = place.m.invert().transformPoint(pole.point);
      expect((p - Vector2(4000, 2000)).length, greaterThan(200),
          reason: '$what: $p off the centre');
      final toColumn = ringDist(p, column), toOuter = ringDist(p, outer);
      expect((toColumn - toOuter).abs(), lessThanOrEqualTo(10),
          reason: '$what: $p is $toColumn from the column, $toOuter from '
              'the walls');
      expect((math.min(toColumn, toOuter) - 1850).abs(), lessThanOrEqualTo(10),
          reason: '$what: $p');
      expect(pole.distance, closeTo(math.min(toColumn, toOuter), 1e-3),
          reason: what);
      // ignore: avoid_print
      print('RL2 at $place: the pole at $p (plan), $toColumn from the '
          'column, $toOuter from the walls');
    }
  });

  test('RA1 the area format in each of the five units', () {
    // mm2 / 1e6 = m2; mm2 / (304.8 x 304.8) = mm2 / 92,903.04 = ft2. Each
    // value is at least 0.0005 from a rounding tie (x.xx5):
    //   10,830,000: 10.83 m2 (0.005 from 10.825 and 10.835);
    //     116.5731 ft2 (0.0019 from 116.575);
    //   21,897,500: 21.8975 m2 (0.0025 from 21.895); 235.7027 ft2 (0.0023
    //     from 235.705);
    //   1,234,567,890: 1,234.5679 m2 (0.0029 from 1,234.565); 13,288.7782
    //     ft2 (0.0032 from 13,288.775); written without grouping;
    //   4,321: 0.0043 m2 (0.0007 from 0.005); 0.0465 ft2 (0.0015 from
    //     0.045);
    //   0: 0.00 either way.
    const cases = [
      (10830000.0, '10.83 m²', '116.57 ft²'),
      (21897500.0, '21.90 m²', '235.70 ft²'),
      (1234567890.0, '1234.57 m²', '13288.78 ft²'),
      (4321.0, '0.00 m²', '0.05 ft²'),
      (0.0, '0.00 m²', '0.00 ft²'),
    ];
    for (final (mm2, metric, imperial) in cases) {
      for (final unit in DisplayUnit.values) {
        final want = switch (unit) {
          DisplayUnit.millimeters ||
          DisplayUnit.centimeters ||
          DisplayUnit.meters =>
            metric,
          DisplayUnit.inches || DisplayUnit.feetInches => imperial,
        };
        expect(formatArea(mm2, unit), want, reason: '$mm2 mm2 in $unit');
      }
    }
    expect(DisplayUnit.values, hasLength(5));
  });
}
