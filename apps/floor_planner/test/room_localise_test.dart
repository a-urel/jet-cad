// Spec 10 D7: the localised trace (LZ1, LZ2). `traceRoomAmong` traces only
// the contributors near a room's face, and must answer exactly what the
// all-inputs trace answers: LZ1 compares the two bit for bit on every seed
// of every fixture at every placement, with and without 200 far walls, and
// through both place sources (the document's and the view's). LZ2 is the
// triangle whose column lies beyond the first growth box.
import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:floor_planner/parametric/room_inputs.dart';
import 'package:floor_planner/parametric/room_trace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/room_fixture.dart';

/// A fixture: its walls, separators and openings in plan mm, and its seeds.
typedef Fixture = (
  String name,
  List<W> walls,
  List<S> seps,
  List<O> openings,
  List<(double, double)> seeds,
);

/// The fixture whose separator only D7's margin brings into `C`.
const marginCase = 'a separator 0.5 nm outside a face';

/// Every seed of every tracer fixture (RT1-RT9, the triangle, FB, the thin
/// L): rooms, courtyards, seeds in bands and on separators, and seeds no
/// ring closes around.
final List<Fixture> fixtures = [
  (
    'the sample plan, its openings, separator and column',
    [...sampleWalls(), sampleColumn],
    const [sampleSeparator],
    sampleOpenings,
    [
      ...sampleSeeds.values,
      (14000, 8100), // in E1's band
      (21500, 14000), // on the separator
      (23700, 14000), // in the column
      (30000, 20000), // outside the flat
    ],
  ),
  (
    'the sample plan without separator or column',
    sampleWalls(),
    const [],
    sampleOpenings,
    [...sampleSeeds.values],
  ),
  (
    'Living with two columns',
    [...sampleWalls(), sampleColumn, const W(22200, 15800, 22600, 15800, 400)],
    const [sampleSeparator],
    sampleOpenings,
    [sampleSeeds['Living']!, sampleSeeds['Dining']!],
  ),
  (
    'the L with a door, a window and a gap',
    lWalls,
    const [],
    lOpenings,
    const [(1000, 1000), (50, 50), (3000, 0)],
  ),
  (
    'four thicknesses',
    fourThickWalls,
    const [],
    const [],
    const [(2500, 2000)]
  ),
  ('JM', jmWalls, const [], const [], const [(3000, 2000)]),
  (
    'two rooms and a column against the ring',
    [...twoRoomWalls, const W(5000, 300, 5400, 300, 400)],
    const [],
    const [],
    const [(1500, 2000), (6500, 2000)],
  ),
  (
    'the box, the hollow column and the separator',
    [...boxWalls, ...hollowColumnWalls],
    const [boxSeparator],
    const [],
    const [(1500, 2000), (7000, 2000), (5300, 1800), (3000, 2000)],
  ),
  (
    'an island in the courtyard',
    [...boxWalls, ...hollowColumnWalls, const W(5250, 1800, 5350, 1800, 100)],
    const [boxSeparator],
    const [],
    const [(7000, 2000), (5100, 1600)],
  ),
  (
    'a separator 50 mm short and a free one',
    boxWalls,
    const [(3000, 100, 3000, 3850), (5000, 1000, 6000, 2000)],
    const [],
    const [(1500, 2000), (7000, 2000)],
  ),
  (
    'a diagonal separator',
    boxWalls,
    const [(0, 2000, 4000, 0)],
    const [],
    const [(500, 500), (4000, 2000)],
  ),
  (
    'a triangle of separators',
    boxWalls,
    const [
      (5000, 1000, 6000, 1000),
      (6000, 1000, 5500, 2000),
      (5500, 2000, 5000, 1000),
    ],
    const [],
    const [(2000, 2000), (5500, 1300)],
  ),
  (
    // A separator 0.5 nm (100 - 99.9999995 = 5e-7 mm) outside the south
    // face, inside the south band: within roomTrace.linear of the face, so
    // the all-inputs trace splits the face at its ends and the ring's south
    // edge carries it too. At the unturned placements its box misses the
    // room's ring box by 0.5 nm: only D7's 1 mm margin brings it into C.
    marginCase,
    boxWalls,
    const [(1000, 99.9999995, 2000, 99.9999995)],
    const [],
    const [(4000, 2000)],
  ),
  ('TR', trWalls, const [], const [], const [trSeed]),
  ('FB', fbWalls, const [], const [], const [fbSeed, (-1000, 1000)]),
  (
    'the thin L',
    thinLWalls,
    const [],
    const [],
    const [(600, 600), (3000, 600), (600, 3000)],
  ),
  (
    'an open U',
    boxWalls.sublist(0, 3),
    const [],
    const [],
    const [(4000, 2000)]
  ),
];

/// [count] short walls on a grid starting 50 m beyond [walls]' east end,
/// none of them touching another: far clutter.
List<W> farWalls(List<W> walls, int count, int from) {
  final x0 = walls.map((w) => math.max(w.sx, w.ex)).reduce(math.max) + 50000.0;
  return [
    for (var k = from; k < from + count; k++)
      W(x0 + 1500.0 * (k % 20), 1100.0 * (k ~/ 20) - 5000,
          x0 + 1500.0 * (k % 20) + 1000, 1100.0 * (k ~/ 20) - 5000, 150),
  ];
}

/// [fixture] at [place]; with [clutter], 100 far walls before its own (lower
/// handles) and 100 after (higher), its openings re-indexed.
Plan build(Fixture fixture, Placement place, {required bool clutter}) {
  final (_, walls, seps, openings, _) = fixture;
  final before = clutter ? farWalls(walls, 100, 0) : const <W>[];
  final after = clutter ? farWalls(walls, 100, 100) : const <W>[];
  return buildPlan([...before, ...walls],
      seps: seps,
      wallsAfter: after,
      openings: [
        for (final (i, position, width, kind, swing) in openings)
          (i + before.length, position, width, kind, swing),
      ],
      place: place);
}

/// A place source that records every handle whose input is asked.
final class Recording implements PlaceSource {
  Recording(this.inner);

  final PlaceSource inner;
  final Set<Handle> asked = {};

  @override
  List<Handle> placedIn(Aabb2 box) => inner.placedIn(box);

  @override
  RoomInput? inputOf(Handle h) {
    asked.add(h);
    return inner.inputOf(h);
  }

  @override
  Aabb2? get bounds => inner.bounds;
}

/// Asserts that [got] is [want], bit for bit: the same kind; the same
/// source for [SeedInWall]; for [Traced], every point with `==` on both
/// coordinates, every source set in its order, and every area.
void expectSameTrace(TraceResult got, TraceResult want, String what) {
  expect(got.runtimeType, want.runtimeType, reason: '$what: $got vs $want');
  switch ((got, want)) {
    case (SeedInWall(source: final a), SeedInWall(source: final b)):
      expect(a, b, reason: '$what: the source');
    case (final Traced a, final Traced b):
      void samePoints(List<Vector2> p, List<Vector2> q, String ring) {
        expect(p.length, q.length, reason: '$what: $ring');
        for (var i = 0; i < p.length; i++) {
          expect((p[i].x, p[i].y), (q[i].x, q[i].y),
              reason: '$what: $ring point $i');
        }
      }
      void sameSources(List<Set<Handle>> p, List<Set<Handle>> q, String ring) {
        expect([for (final s in p) s.toList()], [for (final s in q) s.toList()],
            reason: '$what: $ring sources');
      }
      samePoints(a.ring, b.ring, 'ring');
      sameSources(a.ringSources, b.ringSources, 'ring');
      expect(a.outerArea, b.outerArea, reason: '$what: outer area');
      expect(a.holes.length, b.holes.length, reason: '$what: holes');
      for (var k = 0; k < a.holes.length; k++) {
        samePoints(a.holes[k], b.holes[k], 'hole $k');
        sameSources(a.holeSources[k], b.holeSources[k], 'hole $k');
        expect(a.holeAreas[k], b.holeAreas[k], reason: '$what: hole $k area');
      }
      expect(a.area, b.area, reason: '$what: area');
    default:
  }
}

/// A place source over a fixed list of inputs, which an isolate can take.
final class ListSource implements PlaceSource {
  ListSource(List<RoomInput> inputs)
      : inputs = [...inputs]
          ..sort((a, b) => a.source.value.compareTo(b.source.value));

  final List<RoomInput> inputs;

  @override
  List<Handle> placedIn(Aabb2 box) => [
        for (final i in inputs)
          if (i.box.intersects(box)) i.source,
      ];

  @override
  RoomInput? inputOf(Handle h) {
    for (final i in inputs) {
      if (i.source == h) return i;
    }
    return null;
  }

  @override
  Aabb2? get bounds {
    var u = Aabb2.empty();
    for (final i in inputs) {
      u = u.union(i.box);
    }
    return u.isEmpty ? null : u;
  }
}

void _traceIn((SendPort, List<RoomInput>, double, double) m) {
  final (port, inputs, x, y) = m;
  port.send(traceRoomAmong(Vector2(x, y), ListSource(inputs)).toString());
}

/// `traceRoomAmong(seed, ListSource(inputs))` run in its own isolate, its
/// answer as a string, or null when it has not answered within [limit] (the
/// isolate is then killed): a trace that never ends is a red test, not a
/// hung run.
Future<String?> traceWithin(
    List<RoomInput> inputs, Vector2 seed, Duration limit) async {
  final port = ReceivePort();
  final isolate =
      await Isolate.spawn(_traceIn, (port.sendPort, inputs, seed.x, seed.y));
  try {
    return await port.first.timeout(limit) as String;
  } on TimeoutException {
    return null;
  } finally {
    isolate.kill(priority: Isolate.immediate);
    port.close();
  }
}

void main() {
  test(
      'LZ1 the localised trace equals the all-inputs trace bit for bit on '
      'every fixture at every placement, with and without 200 far walls', () {
    var compared = 0, traced = 0, marginChecked = 0;
    for (final place in placements) {
      for (final fixture in fixtures) {
        for (final clutter in [false, true]) {
          final what = '${fixture.$1}${clutter ? ', 200 far walls' : ''} '
              'at $place';
          final plan = build(fixture, place, clutter: clutter);
          final inputs = RoomInputs(plan.doc);
          addTearDown(inputs.dispose);
          final all = [
            for (final h in inputs.placedIn(everywhere)) inputs.inputOf(h)!,
          ];
          // Premise: every wall and separator is placed.
          expect(all, hasLength(plan.walls.length + plan.seps.length),
              reason: what);
          final far = {
            if (clutter) ...[
              ...plan.walls.take(100),
              ...plan.walls.skip(plan.walls.length - 100),
            ],
          };
          final seeds = [for (final (x, y) in fixture.$5) plan.at(x, y)];
          final seen = probeView(plan.doc, seeds: seeds);
          // The two sources' U, bit for bit.
          expect(sameBox(seen.bounds, inputs.bounds), isTrue, reason: what);
          for (var i = 0; i < seeds.length; i++) {
            final seed = seeds[i];
            final at = '$what, seed ${fixture.$5[i]}';
            final want = traceRoom(seed, all);
            final source = Recording(inputs);
            final got = traceRoomAmong(seed, source);
            expectSameTrace(got, want, '$at (the document\'s source)');
            expectSameTrace(seen.traces[i], want, '$at (the view\'s source)');
            compared += 2;
            if (want is Traced) {
              traced++;
              // Premise: localised. A room's trace never reads a far wall.
              expect(source.asked.intersection(far), isEmpty, reason: at);
              if (fixture.$1 == marginCase && place.deg == 0) {
                // Premises: the separator carries the south edge, and its
                // box misses the ring's box by 0.5 nm.
                final sep = plan.seps.single;
                expect(want.ringSources.any((s) => s.contains(sep)), isTrue,
                    reason: at);
                expect(
                    inputs
                        .placeBoxOf(sep)!
                        .intersects(Aabb2.fromPoints(want.ring)),
                    isFalse,
                    reason: at);
                marginChecked++;
              }
            }
          }
        }
      }
    }
    expect(marginChecked, 4, reason: 'two unturned placements, two clutters');
    // ignore: avoid_print
    print('LZ1: $compared comparisons, $traced seeds traced a room');
  });

  test(
      'LZ2 the triangle: the column beyond the first growth box is found by '
      'the certificate', () {
    for (final place in placements) {
      final what = 'TR at $place';
      final plan = buildPlan(trWalls, place: place);
      final inputs = RoomInputs(plan.doc);
      addTearDown(inputs.dispose);
      final (sx, sy) = trSeed;
      final seed = plan.at(sx, sy);
      final column = plan.walls[3];
      // Premises: the column's place box misses the first growth box, seed
      // plus or minus 1,000 mm; and the first growth box (r = 1,000 x 2^k)
      // that meets all three walls, where the growth first finds a face,
      // still misses the column. Only the certificate can find it.
      Aabb2 around(double r) =>
          Aabb2.raw(seed.x - r, seed.y - r, seed.x + r, seed.y + r);
      expect(inputs.placeBoxOf(column)!.intersects(around(1000)), isFalse,
          reason: what);
      var r0 = 1000.0;
      while (!inputs
          .placedIn(around(r0))
          .toSet()
          .containsAll(plan.walls.sublist(0, 3))) {
        r0 *= 2;
      }
      expect(inputs.placedIn(around(r0)), plan.walls.sublist(0, 3),
          reason: '$what: r $r0');

      // The inner faces 100 in from the centrelines: y = 100, x = 100 and
      // x + 2y = 12,000 - 100 sqrt5 (the hypotenuse, its normal (1, 2) /
      // sqrt5). A right triangle with legs 11,700 - 100 sqrt5 and half
      // that: (11,700 - 100 sqrt5)^2 / 4 = (136,890,000 - 2,340,000 sqrt5 +
      // 50,000) / 4 = 34,235,000 - 585,000 sqrt5 ~ 32,926,900.23, less the
      // column's 400 x 400 = 160,000: ~ 32,766,900.23 (32.77 m2; 32.93 m2
      // without the column).
      final triangle = 34235000 - 585000 * math.sqrt(5);
      final r = traceRoomAmong(seed, inputs);
      expect(r, isA<Traced>(), reason: what);
      final t = r as Traced;
      expect(t.area, closeTo(triangle - 160000, 1e-2), reason: what);
      expect(t.outerArea, closeTo(triangle, 1e-2), reason: what);
      expect(t.holes, hasLength(1), reason: what);
      expect(t.holeAreas.single, closeTo(160000, 1e-2), reason: what);
      expect(t.holeSources.single, everyElement(equals({column})),
          reason: what);
      // Among that box's walls, the face has no hole: the first Traced
      // result, which the certificate must correct.
      final alone = traceRoom(seed, [
        for (final h in inputs.placedIn(around(r0))) inputs.inputOf(h)!,
      ]) as Traced;
      expect(alone.area, closeTo(triangle, 1e-2), reason: what);
      expect(alone.holes, isEmpty, reason: what);
    }
  });

  test(
      'LZ4 a seed with a non-finite coordinate, and a source with nothing '
      'placed, trace Unbounded at once', () async {
    for (final place in placements) {
      final what = 'the box at $place';
      final plan = buildPlan(boxWalls, place: place);
      final inputs = RoomInputs(plan.doc);
      addTearDown(inputs.dispose);
      final all = [
        for (final h in inputs.placedIn(everywhere)) inputs.inputOf(h)!,
      ];
      // Premise: a room at a finite seed, so U is not null.
      final inside = plan.at(4000, 2000);
      expect(await traceWithin(all, inside, const Duration(seconds: 20)),
          startsWith('Traced'),
          reason: what);
      // No box around a non-finite seed ever holds U: without the guard,
      // the growth never ends.
      for (final seed in [
        Vector2(double.nan, inside.y),
        Vector2(inside.x, double.nan),
        Vector2(double.infinity, inside.y),
        Vector2(inside.x, double.negativeInfinity),
      ]) {
        expect(await traceWithin(all, seed, const Duration(seconds: 5)),
            'Unbounded()',
            reason: '$what, seed $seed');
      }
    }
    // Nothing placed: a document with no wall or separator, and one whose
    // only separator is degenerate. U is null; Unbounded at once, nothing
    // traced.
    final empty = buildPlan(const []);
    final degenerate =
        buildPlan(const [], seps: const [(1000, 1000, 1000, 1000.0000005)]);
    for (final plan in [empty, degenerate]) {
      final inputs = RoomInputs(plan.doc);
      addTearDown(inputs.dispose);
      expect(inputs.bounds, isNull);
      final before = debugTracedSegments;
      expect(
          traceRoomAmong(Vector2(1000.5, 2000.25), inputs), isA<Unbounded>());
      expect(debugTracedSegments, before, reason: 'nothing traced');
      final seen = probeView(plan.doc, seeds: [Vector2(1000.5, 2000.25)]);
      expect(seen.bounds, isNull);
      expect(seen.traces.single, isA<Unbounded>());
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
