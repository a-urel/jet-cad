// SPIKE 10 -- throwaway. Q4: the label point. The pole of inaccessibility
// of the ring minus its islands, against the centroid and the box centre.
import 'package:floor_planner/parametric/room_label.dart';
import 'package:floor_planner/parametric/room_trace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support.dart';

/// A thin L: arms 1200 on centrelines, 200 walls, so 1000 clear.
const List<W> thinLWalls = [
  (0, 0, 6000, 0, 200),
  (6000, 0, 6000, 1200, 200),
  (6000, 1200, 1200, 1200, 200),
  (1200, 1200, 1200, 6000, 200),
  (1200, 6000, 0, 6000, 200),
  (0, 6000, 0, 0, 200),
];

void main() {
  for (final place in [origin, corpus, km1000]) {
    test(
        'Q4a the thin L at $place: the pole is inside, within 10 mm of '
        'the widest point; the centroid and the box centre are outside', () {
      final plan = buildPlan(thinLWalls, place: place);
      final t = traceAll(plan.doc, plan.at(600, 600)) as Traced;
      // Inner faces 100 in: (100,100) (5900,100) (5900,1100) (1100,1100)
      // (1100,5900) (100,5900). Arms: 5800 x 1000 + 1000 x 4800 =
      // 10,600,000.
      expect(t.area, closeTo(10600000, 1e-2));
      final sw = Stopwatch()..start();
      final pole = poleOfInaccessibility(t.ring, t.holes, precision: 10);
      sw.stop();
      final cells = debugPoleCells;
      final dPole = signedDistance(pole, t.ring, t.holes);
      // By hand: the bottom arm's centroid (3000, 600), area 5.8e6; the
      // upright arm's (600, 3500), area 4.8e6; together
      // ((3000 x 5.8 + 600 x 4.8) / 10.6, (600 x 5.8 + 3500 x 4.8) / 10.6)
      // = (1913.2, 1913.2): outside, the arms being 1100 wide.
      final c = centroid(t.ring);
      final box = plan.at(3000, 3000);
      final dC = signedDistance(c, t.ring, t.holes);
      final dBox = signedDistance(box, t.ring, t.holes);
      // ignore: avoid_print
      print('Q4a $place: pole ${pole - plan.at(0, 0)} d=$dPole ($cells '
          'cells, ${sw.elapsedMicroseconds} us); centroid d=$dC; box '
          'centre d=$dBox');
      expect((c - plan.at(1913.2075, 1913.2075)).length, lessThan(0.01));
      // By hand, the largest inscribed circle sits in the corner square,
      // on its diagonal, touching both outer faces (x = 100, y = 100) and
      // the reflex corner (1100, 1100): x - 100 = sqrt2 (1100 - x), so
      // x = (100 + 1100 sqrt2) / (1 + sqrt2) = 685.786 and r = 585.786.
      // The arms themselves allow only 500.
      expect(dPole, greaterThan(585.786 - 10));
      expect(dPole, lessThanOrEqualTo(585.787));
      expect(dC, lessThan(0));
      expect(dBox, lessThan(0));
    });
  }

  test('Q4e the room object\'s own label, on the thin L: inside', () {
    final plan = buildPlan(thinLWalls, place: corpusGroups);
    final room = clickRoom(plan.doc, plan.at(600, 600), 'L')!;
    final t = traceAll(plan.doc, plan.at(600, 600)) as Traced;
    final m = plan.doc.tree.accumulatedTransform(room);
    for (final k in kids(plan.doc, room)) {
      if (kindOf(plan.doc, k) != EntityKind.text) continue;
      final c = payloadOf(plan.doc, k).coords;
      final p = m.transformPoint(Vector2(c[0], c[1]));
      final d = signedDistance(p, t.ring, t.holes);
      // ignore: avoid_print
      print('Q4e ${recordOf(plan.doc, k).text}: $d mm inside');
      expect(d, greaterThan(400));
    }
  });

  test('Q4b a column where the pole was: the label moves off it', () {
    final bare = buildPlan(boxWalls, place: corpus);
    final t0 = traceAll(bare.doc, bare.at(1000, 1000)) as Traced;
    final p0 = poleOfInaccessibility(t0.ring, t0.holes, precision: 10);
    // The box's inner 7800 x 3800 is centred on (4000, 2000); the pole is
    // there, 1900 from the long faces.
    expect((p0 - bare.at(4000, 2000)).length, lessThan(20));
    final col =
        buildPlan([...boxWalls, (3800, 2000, 4200, 2000, 400)], place: corpus);
    final t = traceAll(col.doc, col.at(1000, 1000)) as Traced;
    expect(t.holes, hasLength(1));
    final p = poleOfInaccessibility(t.ring, t.holes, precision: 10);
    final d = signedDistance(p, t.ring, t.holes);
    final toColumn = [
      for (var i = 0; i < 4; i++)
        distToSegment(p, t.holes.single[i], t.holes.single[(i + 1) % 4])
    ].reduce((a, b) => a < b ? a : b);
    // ignore: avoid_print
    print('Q4b column: pole at ${p - col.at(0, 0)}, $d from the boundary, '
        '$toColumn from the column; without it '
        '${(p0 - bare.at(4000, 2000)).length} from the box centre');
    expect(d, greaterThan(1000));
    expect(toColumn, greaterThan(1000));
  });

  test('Q4c cost on the sample plan\'s Living with its column', () {
    final plan = buildPlan([...sampleWalls(), sampleColumn],
        seps: const [], place: corpus);
    final t = traceAll(plan.doc, plan.at(21000, 14000)) as Traced;
    const n = 50;
    final sw = Stopwatch()..start();
    var cells = 0;
    for (var i = 0; i < n; i++) {
      poleOfInaccessibility(t.ring, t.holes, precision: 10);
      cells = debugPoleCells;
    }
    sw.stop();
    // ignore: avoid_print
    print('Q4c Living (ring ${t.ring.length}, hole '
        '${t.holes.single.length}): $cells cells, '
        '${sw.elapsedMicroseconds / n} us per call at 10 mm precision');
  });

  test('Q4d the pole never lands in a wall across the fixtures', () {
    for (final (walls, seps, seeds)
        in <(List<W>, List<S>, List<(double, double)>)>[
      (
        [...sampleWalls(), sampleColumn],
        [sampleSeparator],
        [...sampleSeeds.values, (19000, 14000), (22500, 14000)]
      ),
      (lWalls, const [], const [(1000, 1000)]),
      (thinLWalls, const [], const [(600, 600)]),
    ]) {
      final plan = buildPlan(walls, seps: seps, place: corpusGroups);
      for (final (x, y) in seeds) {
        final t = traceAll(plan.doc, plan.at(x, y)) as Traced;
        final p = poleOfInaccessibility(t.ring, t.holes, precision: 10);
        expect(signedDistance(p, t.ring, t.holes), greaterThan(0));
        // And the tracer, asked from the pole, finds the same room.
        final again = traceAll(plan.doc, p) as Traced;
        expect(again.area, closeTo(t.area, 1e-6));
      }
    }
  });
}
