// Spec 10 D5, D6: the room tracer, on every fixture at every placement,
// against hand arithmetic (RT1-RT4, RT6-RT9). The inputs come from
// `RoomInputs`, the document adapter the tools use (RI1 made it equal to
// the view adapter). Every expected area is worked by hand next to its
// assertion, to 1e-2 mm2.
import 'dart:math' as math;

import 'package:floor_planner/parametric/room_inputs.dart';
import 'package:floor_planner/parametric/room_trace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/room_fixture.dart';

/// Every live wall's and separator's input in [plan], ascending, through
/// the document adapter.
List<RoomInput> inputsOf(Plan plan) {
  final inputs = RoomInputs(plan.doc);
  addTearDown(inputs.dispose);
  return [for (final h in inputs.placedIn(everywhere)) inputs.inputOf(h)!];
}

/// Traces the room at plan point [xy] and asserts it is [Traced].
Traced traceAt(
    Plan plan, List<RoomInput> inputs, (double, double) xy, String what) {
  final (x, y) = xy;
  final r = traceRoom(plan.at(x, y), inputs);
  expect(r, isA<Traced>(), reason: '$what at ${plan.place}: $r');
  return r as Traced;
}

/// Asserts [r]'s net area is [hand] mm2 within 1e-2 mm2; returns the error.
double expectArea(Traced r, double hand, String what) {
  final err = (r.area - hand).abs();
  expect(err, lessThanOrEqualTo(1e-2), reason: '$what: ${r.area} vs $hand');
  return err;
}

int lex(Vector2 a, Vector2 b) {
  final c = a.x.compareTo(b.x);
  return c != 0 ? c : a.y.compareTo(b.y);
}

/// Ruling 10-7's canonical order, read back through the world points: each
/// ring anticlockwise and starting at its least vertex in `(x, y)` order
/// relative to [seed]; the holes ordered by their first vertex; every area
/// positive; one source set per edge.
void expectCanonical(Vector2 seed, Traced r, String what) {
  for (final (k, ring) in [r.ring, ...r.holes].indexed) {
    final rel = [for (final p in ring) p - seed];
    for (final p in rel) {
      expect(lex(rel.first, p), lessThanOrEqualTo(0),
          reason: '$what: ring $k starts at its least vertex');
    }
    expect(shoelace(rel), greaterThan(0),
        reason: '$what: ring $k anticlockwise');
  }
  expect(r.ringSources, hasLength(r.ring.length), reason: what);
  for (var k = 0; k < r.holes.length; k++) {
    expect(r.holeSources[k], hasLength(r.holes[k].length), reason: what);
    expect(r.holeAreas[k], greaterThan(0), reason: '$what: hole $k area');
    if (k > 0) {
      expect(lex(r.holes[k - 1].first - seed, r.holes[k].first - seed),
          lessThan(0),
          reason: '$what: holes ordered by their first vertex');
    }
  }
  expect(r.outerArea, greaterThan(0), reason: what);
}

/// Asserts [ring] is [expected] (plan points, anticlockwise) at [plan]'s
/// placement, as a cycle, each point within 1e-3 mm.
void expectRing(Plan plan, List<Vector2> ring, List<(double, double)> expected,
    String what) {
  expect(ring, hasLength(expected.length), reason: '$what: $ring');
  final world = [for (final (x, y) in expected) plan.at(x, y)];
  var k = 0;
  for (var i = 1; i < world.length; i++) {
    if ((world[i] - ring[0]).length < (world[k] - ring[0]).length) k = i;
  }
  for (var i = 0; i < ring.length; i++) {
    final want = world[(k + i) % world.length];
    expect((ring[i] - want).length, lessThan(1e-3),
        reason: '$what: point $i ${ring[i]} vs $want');
  }
}

/// An axis-aligned rectangle's corners, anticlockwise from its least one.
List<(double, double)> rect(double x0, double y0, double x1, double y1) =>
    [(x0, y0), (x1, y0), (x1, y1), (x0, y1)];

/// Asserts that each edge of [ring] carries exactly the sources that
/// [expected] gives for the side whose plan midpoint is nearest the edge's.
void expectEdgeSources(Plan plan, List<Vector2> ring, List<Set<Handle>> sources,
    Map<(double, double), Set<Handle>> expected, String what) {
  final mids = {
    for (final MapEntry(key: (x, y), value: s) in expected.entries)
      plan.at(x, y): s,
  };
  for (var i = 0; i < ring.length; i++) {
    final m = (ring[i] + ring[(i + 1) % ring.length]) * 0.5;
    var best = mids.keys.first;
    for (final k in mids.keys) {
      if ((k - m).length < (best - m).length) best = k;
    }
    expect((best - m).length, lessThan(1e-3), reason: '$what: edge $i');
    expect(sources[i].toList(), mids[best]!.toList(),
        reason: '$what: edge $i\'s sources, ascending');
  }
}

/// Whether [a] and [b] are the same trace, bit for bit: points, sources in
/// their order, and areas.
bool sameTraced(Traced a, Traced b) {
  bool samePts(List<Vector2> p, List<Vector2> q) =>
      p.length == q.length &&
      [for (var i = 0; i < p.length; i++) p[i].x == q[i].x && p[i].y == q[i].y]
          .every((e) => e);
  bool sameSrc(List<Set<Handle>> p, List<Set<Handle>> q) =>
      p.length == q.length &&
      [
        for (var i = 0; i < p.length; i++)
          p[i].length == q[i].length &&
              [
                for (var k = 0; k < p[i].length; k++)
                  p[i].elementAt(k) == q[i].elementAt(k)
              ].every((e) => e)
      ].every((e) => e);
  if (!samePts(a.ring, b.ring) ||
      !sameSrc(a.ringSources, b.ringSources) ||
      a.outerArea != b.outerArea ||
      a.holes.length != b.holes.length) {
    return false;
  }
  for (var k = 0; k < a.holes.length; k++) {
    if (!samePts(a.holes[k], b.holes[k]) ||
        !sameSrc(a.holeSources[k], b.holeSources[k]) ||
        a.holeAreas[k] != b.holeAreas[k]) {
      return false;
    }
  }
  return true;
}

/// Wall [h]'s stored fills: one per piece of its band.
int fillsOf(Plan plan, Handle h) => [
      for (final k in kids(plan.doc, h))
        if (kindOf(plan.doc, k) == EntityKind.fill) k,
    ].length;

void main() {
  // The sample plan. Hand arithmetic (plan mm): exterior 250 centred, so
  // the inner faces are x 12,250..25,750, y 8,250..16,750; partitions 120
  // centred, so faces +-60 about x 17,000 (P1), y 13,000 (P2), y 11,500
  // (P3), x 14,600 (P4), x 21,500 (P5).
  //   Hall      (16,940 - 12,250) x (12,940 - 8,250)  = 4,690 x 4,690
  //                                                   = 21,996,100
  //   Bedroom 1 (14,540 - 12,250) x (16,750 - 13,060) = 2,290 x 3,690
  //                                                   =  8,450,100
  //   Bedroom 2 (16,940 - 14,660) x (16,750 - 13,060) = 2,280 x 3,690
  //                                                   =  8,413,200
  //   Kitchen   (21,440 - 17,060) x (11,440 - 8,250)  = 4,380 x 3,190
  //                                                   = 13,972,200
  //   Bath      (25,750 - 21,560) x (11,440 - 8,250)  = 4,190 x 3,190
  //                                                   = 13,366,100
  //   Living    (25,750 - 17,060) x (16,750 - 11,560) = 8,690 x 5,190
  //                                                   = 45,101,100
  final sampleRooms = <String, (double, List<(double, double)>)>{
    'Hall': (21996100, rect(12250, 8250, 16940, 12940)),
    'Bedroom 1': (8450100, rect(12250, 13060, 14540, 16750)),
    'Bedroom 2': (8413200, rect(14660, 13060, 16940, 16750)),
    'Kitchen': (13972200, rect(17060, 8250, 21440, 11440)),
    'Bath': (13366100, rect(21560, 8250, 25750, 11440)),
    'Living': (45101100, rect(17060, 11560, 25750, 16750)),
  };

  test(
      'RT1 the sample plan\'s six rooms, with its fifteen openings, trace to '
      'their net floor areas at six placements', () {
    for (final place in placements) {
      final plan =
          buildPlan(sampleWalls(), openings: sampleOpenings, place: place);
      // Premises: the openings cut the stored bands (P1 holds two doors, so
      // three pieces; E3 four windows, five), and nothing drifts.
      expect(fillsOf(plan, plan.walls[4]), 3, reason: '$place: P1');
      expect(fillsOf(plan, plan.walls[2]), 5, reason: '$place: E3');
      expect(driftOf(plan.doc), isEmpty, reason: '$place');
      final inputs = inputsOf(plan);
      // The segments a trace takes in: every band's edges, none of them
      // short (premise).
      var segments = 0;
      for (final i in inputs) {
        final n = i.closed ? i.points.length : i.points.length - 1;
        for (var k = 0; k < n; k++) {
          final d = i.points[(k + 1) % i.points.length] - i.points[k];
          expect(d.length, greaterThan(1), reason: '$place');
          segments++;
        }
      }
      var worst = 0.0;
      for (final MapEntry(key: name, value: (hand, corners))
          in sampleRooms.entries) {
        final what = '$name at $place';
        final before = debugTracedSegments;
        final r = traceAt(plan, inputs, sampleSeeds[name]!, name);
        expect(debugTracedSegments - before, segments, reason: what);
        final err = expectArea(r, hand, what);
        if (err > worst) worst = err;
        expect(r.holes, isEmpty, reason: what);
        // Four ring points: every T butt split into a through face is a
        // corner of the room on that side, so no ring here passes straight
        // through a split vertex (X10-collinear is killed by RT8's short
        // separator, not here).
        expectRing(plan, r.ring, corners, what);
        final (x, y) = sampleSeeds[name]!;
        expectCanonical(plan.at(x, y), r, what);
      }
      // The Dining seed lies in the same face as Living's without the
      // separator.
      expectArea(traceAt(plan, inputs, sampleSeeds['Dining']!, 'Dining'),
          45101100, 'Dining at $place');
      // ignore: avoid_print
      print('RT1 worst area error at $place: $worst mm2');
    }
  });

  test(
      'RT2 an L of six walls drawn in mixed directions, and the same L with '
      'a door, a window and a gap, is one room', () {
    // Inner faces 100 in: (100, 100) (5,900, 100) (5,900, 2,900)
    // (2,900, 2,900) (2,900, 4,900) (100, 4,900):
    // 5,800 x 2,800 + 2,800 x 2,000 = 16,240,000 + 5,600,000 = 21,840,000.
    const corners = [
      (100.0, 100.0),
      (5900.0, 100.0),
      (5900.0, 2900.0),
      (2900.0, 2900.0),
      (2900.0, 4900.0),
      (100.0, 4900.0),
    ];
    for (final place in placements) {
      for (final (label, openings) in [
        ('the L', const <O>[]),
        ('the L with a door, a window and a gap', lOpenings),
      ]) {
        final what = '$label at $place';
        final plan = buildPlan(lWalls, openings: openings, place: place);
        if (openings.isNotEmpty) {
          // Premise: the door, the window and the gap cut their bands.
          for (final i in [0, 1, 5]) {
            expect(fillsOf(plan, plan.walls[i]), 2, reason: '$what: $i');
          }
        }
        expect(driftOf(plan.doc), isEmpty, reason: what);
        final r = traceAt(plan, inputsOf(plan), (1000, 1000), label);
        expectArea(r, 21840000, what);
        expect(r.holes, isEmpty, reason: what);
        expectRing(plan, r.ring, corners, what);
        expectCanonical(plan.at(1000, 1000), r, what);
      }
    }
  });

  test('RT3 a column island is a hole: subtracted and anticlockwise', () {
    for (final place in placements) {
      // Decision 16's plan: the separator Living | Dining at x 21,500 and
      // the column x 23,500..23,900, y 13,800..14,200 in Living.
      // Living (25,750 - 21,500) x (16,750 - 11,560) = 4,250 x 5,190
      // = 22,057,500, less the column 400 x 400 = 160,000: 21,897,500.
      final plan = samplePlan(place);
      final column = plan.walls[9];
      var what = 'Living at $place';
      var r = traceAt(plan, inputsOf(plan), sampleSeeds['Living']!, 'Living');
      expectArea(r, 21897500, what);
      expectRing(plan, r.ring, rect(21500, 11560, 25750, 16750), what);
      expect(r.holes, hasLength(1), reason: what);
      expectRing(plan, r.holes.single, rect(23500, 13800, 23900, 14200), what);
      expect(r.holeAreas.single, closeTo(160000, 1e-2), reason: what);
      expect(r.outerArea, closeTo(22057500, 1e-2), reason: what);
      expect(r.holeSources.single, everyElement(equals({column})),
          reason: what);
      expectCanonical(plan.at(24500, 16000), r, what);

      // A second column, x 22,200..22,600, y 15,600..16,000: two holes,
      // ordered by their first vertex. 21,897,500 - 160,000 = 21,737,500.
      final two = buildPlan([
        ...sampleWalls(),
        sampleColumn,
        const W(22200, 15800, 22600, 15800, 400),
      ], seps: const [
        sampleSeparator
      ], openings: sampleOpenings, place: place);
      what = 'Living with two columns at $place';
      r = traceAt(two, inputsOf(two), sampleSeeds['Living']!, 'Living');
      expectArea(r, 21737500, what);
      expect(r.holes, hasLength(2), reason: what);
      expect({
        for (final s in r.holeSources) s.first.single
      }, {
        two.walls[9],
        two.walls[10]
      }, reason: what);
      expectCanonical(two.at(24500, 16000), r, what);
    }
  });

  test(
      'RT4 a hollow column is a hole; its courtyard is not a hole of the '
      'room, and is its own face', () {
    for (final place in placements) {
      final plan = boxAndSeparatorPlan(place);
      final inputs = inputsOf(plan);
      final column = plan.walls.sublist(4, 8).toSet();
      // Left of the separator: (3,000 - 100) x (3,900 - 100) = 2,900 x
      // 3,800 = 11,020,000.
      var what = 'left at $place';
      var r = traceAt(plan, inputs, (1500, 2000), 'left');
      expectArea(r, 11020000, what);
      expect(r.holes, isEmpty, reason: what);
      expectRing(plan, r.ring, rect(100, 100, 3000, 3900), what);
      // Right: (7,900 - 3,000) x 3,800 = 4,900 x 3,800 = 18,620,000, less
      // the column's outer contour, 700 x 700 = 490,000: 18,130,000.
      what = 'right at $place';
      r = traceAt(plan, inputs, (7000, 2000), 'right');
      expectArea(r, 18130000, what);
      expectRing(plan, r.ring, rect(3000, 100, 7900, 3900), what);
      expect(r.holes, hasLength(1), reason: what);
      expectRing(plan, r.holes.single, rect(4950, 1450, 5650, 2150), what);
      expect({for (final s in r.holeSources.single) ...s}, column,
          reason: what);
      // Each hole edge carries its own wall's outer face: the column's four
      // walls are south, east, north and west, in that order.
      expectEdgeSources(
          plan,
          r.holes.single,
          r.holeSources.single,
          {
            (5300, 1450): {plan.walls[4]},
            (5650, 1800): {plan.walls[5]},
            (5300, 2150): {plan.walls[6]},
            (4950, 1800): {plan.walls[7]},
          },
          what);
      expectCanonical(plan.at(7000, 2000), r, what);
      // The courtyard is its own face: 500 x 500 = 250,000, no hole (the
      // room's walls are outside it).
      what = 'courtyard at $place';
      r = traceAt(plan, inputs, (5300, 1800), 'courtyard');
      expectArea(r, 250000, what);
      expect(r.holes, isEmpty, reason: what);
      expectRing(plan, r.ring, rect(5050, 1550, 5550, 2050), what);

      // An island inside the courtyard, a 100 x 100 column x 5,250..5,350,
      // y 1,750..1,850: inside a face of a third component that does not
      // hold the seed, so not a hole of the room (D6); the room is still
      // 18,130,000 with one hole. It is a hole of the courtyard: 250,000 -
      // 10,000 = 240,000.
      final nested = buildPlan([
        ...boxWalls,
        ...hollowColumnWalls,
        const W(5250, 1800, 5350, 1800, 100)
      ], seps: const [
        boxSeparator
      ], place: place);
      final nestedInputs = inputsOf(nested);
      what = 'right, an island in the courtyard, at $place';
      r = traceAt(nested, nestedInputs, (7000, 2000), 'right');
      expectArea(r, 18130000, what);
      expect(r.holes, hasLength(1), reason: what);
      expectRing(nested, r.holes.single, rect(4950, 1450, 5650, 2150), what);
      what = 'courtyard with its island at $place';
      r = traceAt(nested, nestedInputs, (5100, 1600), 'courtyard');
      expectArea(r, 240000, what);
      expect(r.holes, hasLength(1), reason: what);
      expectRing(nested, r.holes.single, rect(5250, 1750, 5350, 1850), what);
    }
  });

  test(
      'RT6 a column pushed against the ring is part of the boundary, walked '
      'around, not a hole', () {
    for (final place in placements) {
      // The two rooms, and a 400 x 400 column x 5,000..5,400, y 100..500,
      // its south face on the south wall's inner face (y 100).
      final plan = buildPlan(
          [...twoRoomWalls, const W(5000, 300, 5400, 300, 400)],
          place: place);
      final column = plan.walls[5];
      final what = 'right room at $place';
      // Right: (7,900 - 3,050) x (3,900 - 100) = 4,850 x 3,800 =
      // 18,430,000, less the column 400 x 400 = 160,000: 18,270,000.
      final r = traceAt(plan, inputsOf(plan), (6500, 2000), 'right');
      expectArea(r, 18270000, what);
      expect(r.holes, isEmpty, reason: what);
      expectRing(
          plan,
          r.ring,
          const [
            (3050, 100),
            (5000, 100),
            (5000, 500),
            (5400, 500),
            (5400, 100),
            (7900, 100),
            (7900, 3900),
            (3050, 3900),
          ],
          what);
      // The ring walks the column's three free faces, and only those.
      expect(r.ringSources.where((s) => s.contains(column)), hasLength(3),
          reason: what);
      expectCanonical(plan.at(6500, 2000), r, what);

      // Two triangles each touching the ring at one inner corner, (100,
      // 100) and (100, 3,900): the ring walks around each and passes the
      // touching corner twice. Whichever placement, the least vertex is one
      // of those pinches, so the start is decided by the vertices that
      // follow it (Ruling 10-7). The box as four mitred bands, crafted
      // inputs in plan mm: 7,800 x 3,800 = 29,640,000, less two triangles
      // of |500 x 500 - 200 x 200| / 2 = 105,000 each: 29,430,000.
      RoomInput band(int h, List<(double, double)> xy) =>
          RoomInput(Handle(h), [for (final (x, y) in xy) place.at(x, y)],
              closed: true);
      const shapes = [
        [(-100.0, -100.0), (8100.0, -100.0), (7900.0, 100.0), (100.0, 100.0)],
        [(8100.0, -100.0), (8100.0, 4100.0), (7900.0, 3900.0), (7900.0, 100.0)],
        [(8100.0, 4100.0), (-100.0, 4100.0), (100.0, 3900.0), (7900.0, 3900.0)],
        [(-100.0, 4100.0), (-100.0, -100.0), (100.0, 100.0), (100.0, 3900.0)],
        [(100.0, 100.0), (600.0, 300.0), (300.0, 600.0)],
        [(100.0, 3900.0), (300.0, 3400.0), (600.0, 3700.0)],
      ];
      final seed = place.at(4000, 2000);
      final pinched = traceRoom(seed, [
        for (var i = 0; i < shapes.length; i++) band(10 + i, shapes[i]),
      ]) as Traced;
      var pinch = 'pinch at $place';
      expect(pinched.area, closeTo(29430000, 1e-2), reason: pinch);
      expect(pinched.holes, isEmpty, reason: pinch);
      expect(pinched.ring, hasLength(10), reason: pinch);
      expectCanonical(seed, pinched, pinch);

      // The same shapes under other handles, shuffled, with far bands 50 m
      // off (handles 1-9 below the room's, 1,000 and up above it): the
      // handles decide the arrangement's vertex and half-edge order, and so
      // where the walk of the face starts, but not the output. The ring's
      // points and the area are bit for bit the same, and each edge
      // carries the same shapes.
      RoomInput far(int h, int j) => band(h, [
            (60000.0 + 1300 * j, 60000),
            (60800.0 + 1300 * j, 60000),
            (60800.0 + 1300 * j, 60150),
            (60000.0 + 1300 * j, 60150),
          ]);
      final rnd = math.Random(3);
      for (var k = 0; k < 20; k++) {
        pinch = 'pinch at $place, variant $k';
        final handles = [for (var i = 0; i < shapes.length; i++) 10 + i]
          ..shuffle(rnd);
        final shapeOf = {
          for (var i = 0; i < shapes.length; i++) Handle(handles[i]): i,
        };
        final other = traceRoom(
            seed,
            [
              for (var i = 0; i < shapes.length; i++)
                band(handles[i], shapes[i]),
              for (var j = 0; j < k % 10; j++) far(1 + j, j),
              for (var j = 0; j < k ~/ 2; j++) far(1000 + j, 10 + j),
            ]..shuffle(rnd)) as Traced;
        expect([
          for (final p in other.ring) (p.x, p.y)
        ], [
          for (final p in pinched.ring) (p.x, p.y)
        ], reason: pinch);
        expect(other.outerArea, pinched.outerArea, reason: pinch);
        expect([
          for (final s in other.ringSources) {for (final h in s) shapeOf[h]}
        ], [
          for (final s in pinched.ringSources) {for (final h in s) h.value - 10}
        ], reason: pinch);
      }
    }
  });

  test(
      'RT7 four thicknesses and a justification mix trace to the inner '
      'faces', () {
    for (final place in placements) {
      // Four thicknesses 300, 100, 200, 250 centred: inner faces x 125 and
      // 4,950, y 150 and 3,900: (4,950 - 125) x (3,900 - 150) = 4,825 x
      // 3,750 = 18,093,750 (the centrelines would give 5,000 x 4,000 =
      // 20,000,000).
      var plan = buildPlan(fourThickWalls, place: place);
      var what = 'four thicknesses at $place';
      var r = traceAt(plan, inputsOf(plan), (2500, 2000), 'four');
      expectArea(r, 18093750, what);
      expectRing(plan, r.ring, rect(125, 150, 4950, 3900), what);
      // JM: inner faces y 200 (t 200 left), x 6,000 (t 100 right), y 3,850
      // (t 300 centre), x 250 (t 250 right, drawn upwards): (6,000 - 250) x
      // (3,850 - 200) = 5,750 x 3,650 = 20,987,500.
      plan = buildPlan(jmWalls, place: place);
      what = 'JM at $place';
      r = traceAt(plan, inputsOf(plan), (3000, 2000), 'JM');
      expectArea(r, 20987500, what);
      expectRing(plan, r.ring, rect(250, 200, 6000, 3850), what);
      expectCanonical(plan.at(3000, 2000), r, what);
      if (place == origin) {
        // As the review's probe printed it, and in Ruling 10-7's order.
        expect([
          for (final p in r.ring) (p.x, p.y)
        ], const [
          (250.0, 200.0),
          (6000.0, 200.0),
          (6000.0, 3850.0),
          (250.0, 3850.0),
        ]);
      }

      // The north side drawn as two collinear walls joined end to end, the
      // west half first (so the lower handle): 7,800 x 3,800 = 29,640,000.
      // The ring walks the east half's face, then the west half's; the
      // vertex between them is collinear and removed, and the merged edge
      // carries both walls, ascending.
      plan = buildPlan(const [
        W(0, 0, 8000, 0, 200),
        W(8000, 0, 8000, 4000, 200),
        W(4000, 4000, 0, 4000, 200), // north, west half
        W(8000, 4000, 4000, 4000, 200), // north, east half
        W(0, 4000, 0, 0, 200),
      ], place: place);
      what = 'a split north side at $place';
      r = traceAt(plan, inputsOf(plan), (4000, 2000), 'split');
      expectArea(r, 29640000, what);
      expectRing(plan, r.ring, rect(100, 100, 7900, 3900), what);
      expect(plan.walls[2].value, lessThan(plan.walls[3].value));
      expectEdgeSources(
          plan,
          r.ring,
          r.ringSources,
          {
            (4000, 100): {plan.walls[0]},
            (7900, 2000): {plan.walls[1]},
            (4000, 3900): {plan.walls[2], plan.walls[3]},
            (100, 2000): {plan.walls[4]},
          },
          what);
    }
  });

  test(
      'RT8 a separator splits a face drawn face to face and centreline to '
      'centreline; 50 mm short it merges them', () {
    for (final place in placements) {
      for (final (label, sep) in [
        ('face to face', boxSeparator),
        ('centreline to centreline', (3000.0, 0.0, 3000.0, 4000.0)),
      ]) {
        final what = '$label at $place';
        final plan = buildPlan([...boxWalls, ...hollowColumnWalls],
            seps: [sep], place: place);
        final inputs = inputsOf(plan);
        // Left (3,000 - 100) x 3,800 = 11,020,000; right (7,900 - 3,000) x
        // 3,800 - 700 x 700 = 18,620,000 - 490,000 = 18,130,000.
        final left = traceAt(plan, inputs, (1500, 2000), label);
        expectArea(left, 11020000, '$what, left');
        expectRing(plan, left.ring, rect(100, 100, 3000, 3900), what);
        final right = traceAt(plan, inputs, (7000, 2000), label);
        expectArea(right, 18130000, '$what, right');
        expectRing(plan, right.ring, rect(3000, 100, 7900, 3900), what);
        for (final r in [left, right]) {
          expect(r.ringSources.where((s) => s.contains(plan.seps.single)),
              hasLength(1),
              reason: '$what: the separator bounds both rooms');
        }
      }
      // 50 mm short of the north face: one room, 7,800 x 3,800 =
      // 29,640,000 from both seeds; the dangling separator is walked out
      // and back (a spike), and removed from the ring. A second separator,
      // (5,000, 1,000) to (6,000, 2,000), both ends loose, is a component
      // with no area: not a hole, and it changes nothing (D6).
      final what = '50 mm short at $place';
      final plan = buildPlan(boxWalls,
          seps: const [(3000, 100, 3000, 3850), (5000, 1000, 6000, 2000)],
          place: place);
      final inputs = inputsOf(plan);
      for (final seed in const [(1500.0, 2000.0), (7000.0, 2000.0)]) {
        final r = traceAt(plan, inputs, seed, what);
        expectArea(r, 29640000, '$what, $seed');
        expectRing(plan, r.ring, rect(100, 100, 7900, 3900), what);
        expect(r.holes, isEmpty, reason: what);
        expect(r.ringSources.any((s) => s.contains(plan.seps.first)), isFalse,
            reason: what);
      }

      // A free tree of two separators sharing an end (the review's case):
      // no area, so not a hole, whatever the sign of its walk's shoelace
      // residue (at the origin it came back as a two-point hole of area
      // 0.0). The room is the whole box, 29,640,000.
      final tree = buildPlan(boxWalls,
          seps: const [
            (
              1476.9157974874054,
              2289.0131972203035,
              1881.3690635069213,
              2760.8488119065564
            ),
            (
              1881.3690635069213,
              2760.8488119065564,
              2979.0947358906415,
              3192.7374418753357
            ),
          ],
          place: place);
      final treeRoom = traceAt(tree, inputsOf(tree), (7000, 3500), 'tree');
      expectArea(treeRoom, 29640000, 'a free tree at $place');
      expect(treeRoom.holes, isEmpty, reason: 'a free tree at $place');

      // Centreline to centreline across the south-west corner, (0, 2,000)
      // to (4,000, 0), crossing the faces at about 26.57 and 63.43 deg: y =
      // 2,000 - x / 2 meets x = 100 at y 1,950 and y = 100 at x 3,800, a
      // triangle of 3,700 x 1,850 / 2 = 3,422,500; the rest 29,640,000 -
      // 3,422,500 = 26,217,500.
      final diagonal =
          buildPlan(boxWalls, seps: const [(0, 2000, 4000, 0)], place: place);
      final diagonalInputs = inputsOf(diagonal);
      var d = traceAt(diagonal, diagonalInputs, (500, 500), 'diagonal');
      expectArea(d, 3422500, 'the corner at $place');
      expectRing(diagonal, d.ring, const [(100, 100), (3800, 100), (100, 1950)],
          'the corner at $place');
      d = traceAt(diagonal, diagonalInputs, (4000, 2000), 'diagonal');
      expectArea(d, 26217500, 'the rest at $place');

      // Separators 0.5 um short of both faces: within roomTrace.linear, so
      // each still ends on the faces and splits the box (D5 step 4).
      // Vertical at x 3,000: 2,900 x 3,800 = 11,020,000 and 4,900 x 3,800 =
      // 18,620,000. Horizontal at y 2,000: 7,800 x 1,900 = 14,820,000 each.
      for (final (label, sep, seeds, areas) in [
        (
          'vertical',
          (3000.0, 100.0000005, 3000.0, 3899.9999995),
          const [(1500.0, 2000.0), (7000.0, 2000.0)],
          const [11020000.0, 18620000.0],
        ),
        (
          'horizontal',
          (100.0000005, 2000.0, 7899.9999995, 2000.0),
          const [(4000.0, 1000.0), (4000.0, 3000.0)],
          const [14820000.0, 14820000.0],
        ),
      ]) {
        final near = buildPlan(boxWalls, seps: [sep], place: place);
        final nearInputs = inputsOf(near);
        for (var k = 0; k < 2; k++) {
          final r = traceAt(near, nearInputs, seeds[k], label);
          expectArea(r, areas[k], '$label 0.5 um short at $place, $k');
        }
      }
    }
  });

  test(
      'RT9 a seed in a band, on a band\'s edge or on a separator is '
      'SeedInWall; a seed no ring closes around is Unbounded', () {
    Matcher seedIn(Handle h) =>
        isA<SeedInWall>().having((s) => s.source, 'source', h);
    for (final place in placements) {
      final l = buildPlan(lWalls, place: place);
      final lInputs = inputsOf(l);
      // Inside the south band, and on its inner face (y 100).
      expect(traceRoom(l.at(3000, 0), lInputs), seedIn(l.walls[0]),
          reason: '$place');
      expect(traceRoom(l.at(3000, 100), lInputs), seedIn(l.walls[0]),
          reason: '$place');
      // On the mitre line of the south and west bands at (0, 0): on both
      // bands' edges. The lowest handle is named, whatever the inputs'
      // order.
      final mitre = l.at(50, 50);
      for (final i in [lInputs.first, lInputs.last]) {
        var near = double.infinity;
        for (var k = 0; k < i.points.length; k++) {
          final d = distToSegment(
              mitre, i.points[k], i.points[(k + 1) % i.points.length]);
          if (d < near) near = d;
        }
        expect(near, lessThanOrEqualTo(roomTrace.linear), reason: '$place');
      }
      expect(traceRoom(mitre, lInputs.reversed.toList()), seedIn(l.walls[0]),
          reason: '$place');

      // Two bands crossing: the seed inside both.
      final x = buildPlan(const [
        W(0, 0, 4000, 0, 200),
        W(2000, -2000, 2000, 2000, 200),
      ], place: place);
      final xInputs = inputsOf(x);
      final centre = x.at(2000, 0);
      for (final i in xInputs) {
        expect(pointInRing(centre, i.points), isTrue, reason: '$place');
      }
      expect(traceRoom(centre, xInputs), seedIn(x.walls[0]), reason: '$place');
      expect(traceRoom(centre, xInputs.reversed.toList()), seedIn(x.walls[0]),
          reason: '$place');

      // On a separator.
      final box = buildPlan(boxWalls, seps: const [boxSeparator], place: place);
      expect(
          traceRoom(box.at(3000, 2000), inputsOf(box)), seedIn(box.seps.single),
          reason: '$place');
      // Outside every ring.
      expect(traceRoom(box.at(20000, 20000), inputsOf(box)), isA<Unbounded>(),
          reason: '$place');

      // An open U: the box without its west wall.
      final u = buildPlan(boxWalls.sublist(0, 3), place: place);
      expect(traceRoom(u.at(4000, 2000), inputsOf(u)), isA<Unbounded>(),
          reason: '$place');
      // No input at all.
      expect(traceRoom(u.at(4000, 2000), const []), isA<Unbounded>(),
          reason: '$place');
    }
  });
}
