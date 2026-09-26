// SPIKE 10 -- throwaway. Q1 and Q2: the tracer's areas against hand
// arithmetic, on every fixture, at every placement.
import 'package:floor_planner/parametric/opening.dart';
import 'package:floor_planner/parametric/room.dart';
import 'package:floor_planner/parametric/room_trace.dart';
import 'package:floor_planner/startup_plan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support.dart';

/// The largest area error seen, per placement, for the note.
final Map<String, double> worst = {};

/// Asserts the traced area at plan point ([x], [y]) is [hand] mm², within
/// [tol] mm², and records the error.
void expectArea(Plan plan, double x, double y, double hand, String what,
    {double tol = 1e-2}) {
  final r = traceAll(plan.doc, plan.at(x, y));
  expect(r, isA<Traced>(), reason: '$what at ${plan.place}: $r');
  final err = ((r as Traced).area - hand).abs();
  worst[plan.place.name] =
      [worst[plan.place.name] ?? 0.0, err].reduce((a, b) => a > b ? a : b);
  expect(err, lessThanOrEqualTo(tol),
      reason: '$what at ${plan.place}: ${r.area} vs $hand');
}

void main() {
  tearDownAll(() {
    for (final e in worst.entries) {
      // ignore: avoid_print
      print('Q2 worst area error at ${e.key}: ${e.value} mm2');
    }
  });

  // ---------------------------------------------------------------------
  // The sample plan. Hand arithmetic (plan mm): exterior 250 centred, so
  // the inner faces are x 12250..25750, y 8250..16750; partitions 120
  // centred, so faces +-60 about x 17000 (P1), y 13000 (P2), y 11500 (P3),
  // x 14600 (P4), x 21500 (P5).
  //   Hall      (16940-12250) x (12940-8250)  = 4690 x 4690 = 21,996,100
  //   Bedroom 1 (14540-12250) x (16750-13060) = 2290 x 3690 =  8,450,100
  //   Bedroom 2 (16940-14660) x (16750-13060) = 2280 x 3690 =  8,413,200
  //   Kitchen   (21440-17060) x (11440-8250)  = 4380 x 3190 = 13,972,200
  //   Bath      (25750-21560) x (11440-8250)  = 4190 x 3190 = 13,366,100
  //   Living    (25750-17060) x (16750-11560) = 8690 x 5190 = 45,101,100
  //   total 111,298,800 mm2 = 111.30 m2.
  const sampleHand = {
    'Hall': 21996100.0,
    'Bedroom 1': 8450100.0,
    'Bedroom 2': 8413200.0,
    'Kitchen': 13972200.0,
    'Bath': 13366100.0,
    'Living': 45101100.0,
  };

  test('Q2a the real sample plan (walls carry 15 openings): six rooms', () {
    final doc = startupPlan(FlutterTextMeasurer());
    var total = 0.0;
    for (final e in sampleSeeds.entries) {
      final (x, y) = e.value;
      final r = traceAll(doc, Vector2(x, y));
      expect(r, isA<Traced>());
      final a = (r as Traced).area;
      total += a;
      // ignore: avoid_print
      print('Q2a ${e.key}: $a mm2 = ${formatArea(a, DisplayUnit.meters)}, '
          '${r.ring.length} ring points, bounds '
          '${[for (final h in r.outerSources) h.value]..sort()}');
      expect((a - sampleHand[e.key]!).abs(), lessThanOrEqualTo(1e-6));
      expect(r.holes, isEmpty);
    }
    // ignore: avoid_print
    print('Q2a total: $total mm2');
    expect((total - 111298800).abs(), lessThanOrEqualTo(1e-5));
  });

  for (final place in placements) {
    group('at $place', () {
      test('Q2b the sample plan\'s nine walls, six rooms', () {
        final plan = buildPlan(sampleWalls(), place: place);
        for (final e in sampleSeeds.entries) {
          final (x, y) = e.value;
          expectArea(plan, x, y, sampleHand[e.key]!, e.key);
        }
      });

      test('Q2c decision 16: separator Living | Dining, column in Living', () {
        final plan = buildPlan([...sampleWalls(), sampleColumn],
            seps: [sampleSeparator], place: place);
        // Dining (21500-17060) x 5190 = 4440 x 5190 = 23,043,600.
        expectArea(plan, 19000, 14000, 23043600, 'Dining');
        // Living (25750-21500) x 5190 = 4250 x 5190 = 22,057,500, less the
        // column 400 x 400 = 160,000: 21,897,500.
        expectArea(plan, 22500, 14000, 21897500, 'Living');
        final r = traceAll(plan.doc, plan.at(22500, 14000)) as Traced;
        expect(r.holes, hasLength(1));
        expect(r.holeAreas.single, closeTo(160000, 1e-2));
      });

      test('Q2d an L with walls drawn in mixed directions', () {
        final plan = buildPlan(lWalls, place: place);
        // Inner faces 100 in: (100,100) (5900,100) (5900,2900) (2900,2900)
        // (2900,4900) (100,4900): 5800 x 2800 + 2800 x 2000
        // = 16,240,000 + 5,600,000 = 21,840,000.
        expectArea(plan, 1000, 1000, 21840000, 'L');
        final r = traceAll(plan.doc, plan.at(1000, 1000)) as Traced;
        expect(r.ring, hasLength(6));
      });

      test('Q2j the L with a door and a window in its walls', () {
        final plan = buildPlan(lWalls, place: place);
        addOpening(plan.doc,
            OpeningParams(plan.walls[0], 1500, 900, OpeningKind.door));
        addOpening(plan.doc,
            OpeningParams(plan.walls[1], 1500, 1200, OpeningKind.window));
        addOpening(
            plan.doc, OpeningParams(plan.walls[5], 2500, 800, OpeningKind.gap));
        expect(plan.system.drift(), isEmpty);
        // The pieces are cut: the bottom wall stores two regions.
        final fills = [
          for (final k in kids(plan.doc, plan.walls[0]))
            if (kindOf(plan.doc, k) == EntityKind.fill) k
        ];
        expect(fills, hasLength(2));
        expectArea(plan, 1000, 1000, 21840000, 'L with openings');
      });

      test('Q2e four walls of four thicknesses', () {
        final plan = buildPlan(mixedWalls, place: place);
        // Inner faces: x 0+125 .. 5000-50, y 0+150 .. 4000-100:
        // 4825 x 3750 = 18,093,750 (centrelines: 20,000,000).
        expectArea(plan, 2500, 2000, 18093750, 'mixed');
      });

      test('Q2f two rooms sharing a partition', () {
        final plan = buildPlan(twoRoomWalls, place: place);
        // Inner faces x 100..7900, y 100..3900; partition faces 2950, 3050.
        // Left 2850 x 3800 = 10,830,000; right 4850 x 3800 = 18,430,000.
        expectArea(plan, 1500, 2000, 10830000, 'left');
        expectArea(plan, 5500, 2000, 18430000, 'right');
      });

      test('Q2g a separator splits the box; a hollow column in one half', () {
        final plan = buildPlan([
          ...boxWalls,
          // A hollow column: a 600 x 600 centreline square, 100 thick,
          // mitred; its outer contour is 700 x 700 = 490,000.
          (5000, 1500, 5600, 1500, 100),
          (5600, 1500, 5600, 2100, 100),
          (5600, 2100, 5000, 2100, 100),
          (5000, 2100, 5000, 1500, 100),
        ], seps: [
          (3000, 100, 3000, 3900)
        ], place: place);
        // Left (3000-100) x 3800 = 2900 x 3800 = 11,020,000.
        expectArea(plan, 1500, 2000, 11020000, 'left of separator');
        // Right (7900-3000) x 3800 = 4900 x 3800 = 18,620,000, less
        // 490,000: 18,130,000.
        expectArea(plan, 7000, 2000, 18130000, 'right of separator');
        final r = traceAll(plan.doc, plan.at(7000, 2000)) as Traced;
        expect(r.holes, hasLength(1));
        expect(r.holeSources.single.expand((s) => s).toSet(), hasLength(4));
        // The courtyard of the column is its own room: 500 x 500.
        expectArea(plan, 5300, 1800, 250000, 'courtyard');
      });
    });
  }

  test('Q2h a separator ending on the walls\' centrelines: same rooms', () {
    final plan = buildPlan(boxWalls, seps: [(3000, 0, 3000, 4000)]);
    expectArea(plan, 1500, 2000, 11020000, 'left');
    expectArea(plan, 7000, 2000, 18620000, 'right');
  });

  test('Q2i a separator 50 mm short of a face: one merged room', () {
    final plan = buildPlan(boxWalls, seps: [(3000, 100, 3000, 3850)]);
    // 7800 x 3800 = 29,640,000, both seeds.
    expectArea(plan, 1500, 2000, 29640000, 'left');
    expectArea(plan, 7000, 2000, 29640000, 'right');
  });

  test('Q1 the seed in a wall, and an open plan', () {
    final plan = buildPlan(lWalls);
    expect(traceAll(plan.doc, plan.at(3000, 0)), isA<SeedInWall>());
    expect(traceAll(plan.doc, plan.at(9000, 9000)), isA<Unbounded>());
    final open = buildPlan(lWalls.sublist(1));
    expect(traceAll(open.doc, open.at(1000, 1000)), isA<Unbounded>());
  });

  test('Q1 cost: pairs tested and time per trace', () {
    final doc = startupPlan(FlutterTextMeasurer());
    final inputs = documentInputs(doc);
    final segs = inputs.fold<int>(0, (n, i) => n + i.points.length);
    debugTracePairs = 0;
    traceRoom(Vector2(14500, 10500), inputs);
    final pairs = debugTracePairs;
    final sw = Stopwatch()..start();
    const n = 200;
    for (var i = 0; i < n; i++) {
      traceRoom(Vector2(14500, 10500), inputs);
    }
    sw.stop();
    // ignore: avoid_print
    print('Q1 cost, all nine walls: ${inputs.length} inputs, $segs '
        'segments, $pairs pairs past the box test, '
        '${sw.elapsedMicroseconds / n} us per trace (JIT, $n runs)');
    final sw2 = Stopwatch()..start();
    for (var i = 0; i < n; i++) {
      documentInputs(doc);
    }
    sw2.stop();
    // ignore: avoid_print
    print('Q1 cost, the nine outlines (07 outline among all walls): '
        '${sw2.elapsedMicroseconds / n} us');
  });
}
