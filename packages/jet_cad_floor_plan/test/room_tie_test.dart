// Spec 10 D5 step 9, D6 and D9 as amended by decision 29: a doubled edge (a
// separator, or a chain or tree of them, tying an island to the room's
// ring or to another island) is split out of the walk before anything reads
// it. Both its halves go, and the loop between them is a hole: the room
// keeps its fill, its area and its label clear of the island.
//
// DE1 traces at all six placements, DE2 builds the room at all six, DE3 is
// the transient of the Separator tool drawing wall → column → wall, at the
// origin, the corpus far origin turned 23° and the same in own groups. LZ1
// (room_localise_test.dart) holds the same fixtures, localised against
// all-inputs bit for bit; FZ1 (room_follow_test.dart) pins the random run's
// census. Expected areas are hand arithmetic next to the assertion, to 1e-2
// mm²; every label string is at least 0.0005 m² from a rounding tie.
import 'package:jet_cad_floor_plan/src/parametric/room_inputs.dart';
import 'package:jet_cad_floor_plan/src/parametric/room_label.dart';
import 'package:jet_cad_floor_plan/src/parametric/room_trace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/room_fixture.dart';

/// The room's seed, plan mm (fractional), west of every island.
const (double, double) seedXY = (2000.5, 2000.25);

/// A 400 × 400 column standing free in the box: x 5,000..5,400, y
/// 1,800..2,200.
const W column = W(5000, 2000, 5400, 2000, 400);

/// A second column east of it: x 6,500..6,900, y 1,800..2,200.
const W column2 = W(6500, 2000, 6900, 2000, 400);

/// A column touching [column] at its north-east corner (5,400, 2,200) only:
/// x 5,400..5,800, y 2,200..2,600.
const W cornerColumn = W(5400, 2400, 5800, 2400, 400);

/// The tie: from the south wall's inner face (y 100) to [column]'s south
/// face (y 1,800), at x 5,200.5.
const S tie = (5200.5, 100, 5200.5, 1800);

/// The Separator tool's second segment: [column]'s north face (y 2,200) to
/// the north wall's inner face (y 3,900).
const S tieNorth = (5200.5, 2200, 5200.5, 3900);

/// The box's four inner-face corners, and [column]'s and [column2]'s.
const box = [
  (100.0, 100.0),
  (7900.0, 100.0),
  (7900.0, 3900.0),
  (100.0, 3900.0)
];
const columnCorners = [
  (5000.0, 1800.0),
  (5400.0, 1800.0),
  (5400.0, 2200.0),
  (5000.0, 2200.0),
];
const column2Corners = [
  (6500.0, 1800.0),
  (6900.0, 1800.0),
  (6900.0, 2200.0),
  (6500.0, 2200.0),
];

/// Every live input of [plan], ascending, through the document adapter.
List<RoomInput> inputsOf(Plan plan) {
  final inputs = RoomInputs(plan.doc);
  addTearDown(inputs.dispose);
  return [for (final h in inputs.placedIn(everywhere)) inputs.inputOf(h)!];
}

/// Asserts that [ring] is the cycle [expected] (plan points, in its order)
/// at [plan]'s placement, from some start, each point within 1e-3 mm.
void expectCycle(Plan plan, List<Vector2> ring, List<(double, double)> expected,
    String why) {
  expect(ring, hasLength(expected.length), reason: '$why: $ring');
  final want = [for (final (x, y) in expected) plan.at(x, y)];
  final n = want.length;
  final starts = [
    for (var k = 0; k < n; k++)
      if ([
        for (var i = 0; i < n; i++) (ring[i] - want[(k + i) % n]).length < 1e-3
      ].every((e) => e))
        k,
  ];
  expect(starts, isNotEmpty, reason: '$why: $ring is not $expected');
}

/// Asserts that each edge of [ring] carries exactly the sources [expected]
/// gives for the plan midpoint it has (within 1e-3 mm).
void expectSources(Plan plan, List<Vector2> ring, List<Set<Handle>> sources,
    Map<(double, double), Set<Handle>> expected, String why) {
  expect(sources, hasLength(ring.length), reason: why);
  final mids = {
    for (final MapEntry(key: (x, y), value: s) in expected.entries)
      plan.at(x, y): s,
  };
  for (var i = 0; i < ring.length; i++) {
    final m = (ring[i] + ring[(i + 1) % ring.length]) * 0.5;
    final hit = [
      for (final k in mids.keys)
        if ((k - m).length < 1e-3) k,
    ];
    expect(hit, hasLength(1), reason: '$why: edge $i, midpoint $m');
    expect(sources[i].toList(), mids[hit.single]!.toList(),
        reason: '$why: edge $i\'s sources, ascending');
  }
}

/// Ruling 10-7 read back: every ring anticlockwise from its least vertex
/// relative to [seed], the holes in the order of their first vertex.
void expectCanonical(Vector2 seed, Traced r, String why) {
  int lex(Vector2 a, Vector2 b) {
    final c = a.x.compareTo(b.x);
    return c != 0 ? c : a.y.compareTo(b.y);
  }

  for (final (k, ring) in [r.ring, ...r.holes].indexed) {
    final rel = [for (final p in ring) p - seed];
    for (final p in rel) {
      expect(lex(rel.first, p), lessThanOrEqualTo(0),
          reason: '$why: ring $k starts at its least vertex');
    }
    expect(shoelace(rel), greaterThan(0), reason: '$why: ring $k');
  }
  for (var k = 1; k < r.holes.length; k++) {
    expect(
        lex(r.holes[k - 1].first - seed, r.holes[k].first - seed), lessThan(0),
        reason: '$why: holes ordered by their first vertex');
  }
}

/// The box and [column], with [seps], at [place], a page attached.
Plan tied(Placement place, List<S> seps, {List<W> more = const [column]}) {
  final plan = buildPlan([...boxWalls, ...more], seps: seps, place: place);
  attachPage(plan.doc, PageComponent());
  return plan;
}

/// The distance from world point [p] to the rectangle of plan [corners]'
/// boundary at [plan]'s placement.
double toRect(Plan plan, Vector2 p, List<(double, double)> corners) {
  var d = double.infinity;
  for (var i = 0; i < corners.length; i++) {
    final (ax, ay) = corners[i];
    final (bx, by) = corners[(i + 1) % corners.length];
    final e = distToSegment(p, plan.at(ax, ay), plan.at(bx, by));
    if (e < d) d = e;
  }
  return d;
}

/// [doc] as saved, nodes sorted, less its handle seed (an undo does not
/// take back a handle it allocated).
String stateOf(DraftDocument doc) =>
    canon(doc, sortNodes: true).replaceFirst(RegExp(r'"handleSeed":\d+'), '');

/// The distance from [q] to [pts]' nearest point.
double nearest(Vector2 q, Iterable<Vector2> pts) =>
    pts.map((p) => (p - q).length).reduce((a, b) => a < b ? a : b);

void main() {
  test(
      'DE1 a doubled edge is split out of the walk: the island it ties is a '
      'hole, the area unchanged, the ties in no source set, at six '
      'placements', () {
    for (final place in placements) {
      // The box's inner faces: 7,800 × 3,800 = 29,640,000. A 400 × 400
      // column, 160,000: 29,640,000 − 160,000 = 29,480,000.
      for (final (label, seps) in <(String, List<S>)>[
        ('one tie', const [tie]),
        (
          'a chain of two collinear separators',
          const [(5200.5, 100, 5200.5, 900.25), (5200.5, 900.25, 5200.5, 1800)]
        ),
        (
          'a tie with a T-branch',
          const [tie, (5200.5, 900.25, 6200.25, 900.25)]
        ),
        // Two different inputs overlapping: merged into one edge that
        // carries both, walked out and back like one.
        ('the tie drawn twice', const [tie, tie]),
      ]) {
        final what = '$label at $place';
        final plan = tied(place, seps);
        final seed = plan.at(seedXY.$1, seedXY.$2);
        final r = traceRoom(seed, inputsOf(plan));
        expect(r, isA<Traced>(), reason: what);
        r as Traced;
        expect((r.area - 29480000).abs(), lessThanOrEqualTo(1e-2),
            reason: '$what: ${r.area}');
        expect((r.outerArea - 29640000).abs(), lessThanOrEqualTo(1e-2),
            reason: what);
        expectCycle(plan, r.ring, box, '$what: the ring');
        expect(r.holes, hasLength(1), reason: what);
        expectCycle(plan, r.holes.single, columnCorners, '$what: the hole');
        expect((r.holeAreas.single - 160000).abs(), lessThanOrEqualTo(1e-2),
            reason: what);
        final [south, east, north, west, col] = plan.walls;
        expectSources(
            plan,
            r.ring,
            r.ringSources,
            {
              (4000, 100): {south},
              (7900, 2000): {east},
              (4000, 3900): {north},
              (100, 2000): {west},
            },
            '$what: the ring');
        expectSources(
            plan,
            r.holes.single,
            r.holeSources.single,
            {
              (5200, 1800): {col},
              (5400, 2000): {col},
              (5200, 2200): {col},
              (5000, 2000): {col},
            },
            '$what: the hole');
        expectCanonical(seed, r, what);
      }

      // Not a doubled edge: a separator lying along the south face, from
      // x 1,000.5 to 2,000.5 (two different inputs overlapping, walked
      // once). The ring keeps it, merged into the south edge with the wall;
      // the tie beside it still splits.
      var what = 'a separator along the south face at $place';
      var plan = tied(place, const [(1000.5, 100, 2000.5, 100), tie]);
      var r =
          traceRoom(plan.at(seedXY.$1, seedXY.$2), inputsOf(plan)) as Traced;
      expect((r.area - 29480000).abs(), lessThanOrEqualTo(1e-2), reason: what);
      expectCycle(plan, r.ring, box, what);
      expectSources(
          plan,
          r.ring,
          r.ringSources,
          {
            (4000, 100): {plan.walls[0], plan.seps[0]},
            (7900, 2000): {plan.walls[1]},
            (4000, 3900): {plan.walls[2]},
            (100, 2000): {plan.walls[3]},
          },
          what);
      expect(r.holes, hasLength(1), reason: what);

      // Two ties, wall → column → wall: no doubled edge, the box is split.
      // The seed's side: x 100..5,200.5 less the column's west part, x
      // 5,000..5,200.5, y 1,800..2,200: 5,100.5 × 3,800 = 19,381,900, less
      // 200.5 × 400 = 80,200: 19,301,700.
      what = 'wall → column → wall at $place';
      plan = tied(place, const [tie, tieNorth]);
      r = traceRoom(plan.at(seedXY.$1, seedXY.$2), inputsOf(plan)) as Traced;
      expect((r.area - 19301700).abs(), lessThanOrEqualTo(1e-2), reason: what);
      expect(r.holes, isEmpty, reason: what);
      expectCycle(
          plan,
          r.ring,
          const [
            (100, 100),
            (5200.5, 100),
            (5200.5, 1800),
            (5000, 1800),
            (5000, 2200),
            (5200.5, 2200),
            (5200.5, 3900),
            (100, 3900),
          ],
          what);
      expect(r.ringSources.where((s) => s.contains(plan.seps[0])), hasLength(1),
          reason: what);
      expect(r.ringSources.where((s) => s.contains(plan.seps[1])), hasLength(1),
          reason: what);

      // Two islands tied to each other, then also to the wall: two holes
      // either way (the tie between them is split out of the islands'
      // contour, or out of the ring's walk). 29,640,000 − 2 × 160,000 =
      // 29,320,000.
      for (final seps in const [
        [(5400.0, 2000.5, 6500.0, 2000.5)],
        [tie, (5400.0, 2000.5, 6500.0, 2000.5)],
      ]) {
        what = 'two islands tied, ${seps.length} separators, at $place';
        plan = tied(place, seps, more: const [column, column2]);
        final seed = plan.at(seedXY.$1, seedXY.$2);
        r = traceRoom(seed, inputsOf(plan)) as Traced;
        expect((r.area - 29320000).abs(), lessThanOrEqualTo(1e-2),
            reason: what);
        expectCycle(plan, r.ring, box, what);
        expect(r.holes, hasLength(2), reason: what);
        // Either order: Ruling 10-7 orders them in the seed-relative
        // frame, which the turn changes.
        final first =
            r.holes.indexWhere((h) => nearest(plan.at(5000, 1800), h) < 1e-3);
        expect(first, isNot(-1), reason: what);
        expectCycle(plan, r.holes[first], columnCorners, what);
        expectCycle(plan, r.holes[1 - first], column2Corners, what);
        for (final (k, h) in [
          (first, plan.walls[4]),
          (1 - first, plan.walls[5])
        ]) {
          expect(r.holeSources[k], everyElement(equals({h})), reason: what);
        }
        for (final s in [...r.ringSources, ...r.holeSources.expand((e) => e)]) {
          expect(s.intersection(plan.seps.toSet()), isEmpty, reason: what);
        }
        expectCanonical(seed, r, what);
      }

      // A triangle of three separators tied to the south wall by a fourth
      // at x 5,500.5, which ends on the triangle's base: the triangle is a
      // hole, each edge carrying its own separator. Base 1,000, height
      // 1,000: 500,000; 29,640,000 − 500,000 = 29,140,000.
      what = 'a triangle of separators tied at $place';
      plan = tied(place, const [
        (5000, 1000, 6000, 1000),
        (6000, 1000, 5500, 2000),
        (5500, 2000, 5000, 1000),
        (5500.5, 100, 5500.5, 1000),
      ], more: const []);
      final seed = plan.at(seedXY.$1, seedXY.$2);
      r = traceRoom(seed, inputsOf(plan)) as Traced;
      expect((r.area - 29140000).abs(), lessThanOrEqualTo(1e-2), reason: what);
      expectCycle(plan, r.ring, box, what);
      expect(r.holes, hasLength(1), reason: what);
      expectCycle(plan, r.holes.single,
          const [(5000, 1000), (6000, 1000), (5500, 2000)], what);
      expectSources(
          plan,
          r.holes.single,
          r.holeSources.single,
          {
            (5500, 1000): {plan.seps[0]},
            (5750, 1500): {plan.seps[1]},
            (5250, 1500): {plan.seps[2]},
          },
          what);
      expectCanonical(seed, r, what);

      // An island pinched at a vertex, tied: [column] and [cornerColumn]
      // touch at (5,400, 2,200) only, so the loop between the tie's halves
      // passes that vertex twice. It is one hole, pinched: 29,640,000 − 2 ×
      // 160,000 = 29,320,000.
      what = 'a pinched island tied at $place';
      plan = tied(place, const [tie], more: const [column, cornerColumn]);
      r = traceRoom(plan.at(seedXY.$1, seedXY.$2), inputsOf(plan)) as Traced;
      expect((r.area - 29320000).abs(), lessThanOrEqualTo(1e-2), reason: what);
      expectCycle(plan, r.ring, box, what);
      expect(r.holes, hasLength(1), reason: what);
      expectCycle(
          plan,
          r.holes.single,
          const [
            (5000, 1800),
            (5400, 1800),
            (5400, 2200),
            (5800, 2200),
            (5800, 2600),
            (5400, 2600),
            (5400, 2200),
            (5000, 2200),
          ],
          what);
      expect((r.holeAreas.single - 320000).abs(), lessThanOrEqualTo(1e-2),
          reason: what);
    }

    // A star (Task 19's audit; rv14b-splitOnce): one freestanding column
    // with 1,002 small columns each tied straight to it by a separator. The
    // hole's walk holds 1,002 doubled pairs, one per tie, so splitting it
    // leaves more than 1,000 loops. Traced from crafted inputs (the tracer
    // alone, as RT6's pinch), their world points placed at each of the six
    // placements (the own-groups ones place a crafted input as their plain
    // twins do): about 0.3 s each, 1.9 s for all six in this container.
    for (final place in placements) {
      const n = 1002;
      const w = 1000.0 + n * 60 + 1000, h = 10000.0; // 62,120 × 10,000
      var next = 10;
      RoomInput band(List<(double, double)> xy) =>
          RoomInput(Handle(next++), [for (final (x, y) in xy) place.at(x, y)],
              closed: true);
      RoomInput sep((double, double) a, (double, double) b) => RoomInput(
          Handle(next++), [place.at(a.$1, a.$2), place.at(b.$1, b.$2)],
          closed: false);
      final inputs = [
        // Four mitred 200 mm bands: inner faces x 100..62,020, y 100..9,900.
        band([(-100, -100), (w + 100, -100), (w - 100, 100), (100, 100)]),
        band([
          (w + 100, -100),
          (w + 100, h + 100),
          (w - 100, h - 100),
          (w - 100, 100)
        ]),
        band([
          (w + 100, h + 100),
          (-100, h + 100),
          (100, h - 100),
          (w - 100, h - 100)
        ]),
        band([(-100, h + 100), (-100, -100), (100, 100), (100, h - 100)]),
        // The column: x 1,000..61,120, y 4,950..5,050.
        band([
          (1000, 4950),
          (1000.0 + n * 60, 4950),
          (1000.0 + n * 60, 5050),
          (1000, 5050)
        ]),
        for (var k = 0; k < n; k++) ...[
          // A 20 × 20 column at x 1,020 + 60k, y 5,990..6,010, tied from
          // its south face to the column's north face.
          band([
            (1020.0 + 60 * k, 5990),
            (1040.0 + 60 * k, 5990),
            (1040.0 + 60 * k, 6010),
            (1020.0 + 60 * k, 6010),
          ]),
          sep((1030.0 + 60 * k, 5050), (1030.0 + 60 * k, 5990)),
        ],
      ];
      final what = 'the star at $place';
      final r = traceRoom(place.at(500.5, 500.25), inputs);
      expect(r, isA<Traced>(), reason: what);
      r as Traced;
      // By hand: the inner faces 61,920 × 9,800 = 606,816,000; less the
      // column 60,120 × 100 = 6,012,000 and 1,002 × 400 = 400,800:
      // 600,403,200. The ties add nothing.
      expect(r.holes, hasLength(n + 1), reason: '$what: every island a hole');
      expect((r.area - 600403200).abs(), lessThanOrEqualTo(1e-2),
          reason: '$what: ${r.area}');
      expect((r.outerArea - 606816000).abs(), lessThanOrEqualTo(1e-2),
          reason: what);
    }
  });

  test(
      'DE2 a room with a tied island keeps its fill: step 1, its area, no '
      'room.tint, its label clear of the island, at six placements', () {
    for (final place in placements) {
      // The review's reproduction: one tie. 29,480,000 (29.48, 0.005 from
      // 29.475 and 29.485).
      var what = 'one tie at $place';
      var plan = tied(place, const [tie]);
      var room = addRoom(plan.doc, plan.at(seedXY.$1, seedXY.$2), 'Room 1');
      expect(
          kindsOf(plan.doc, room),
          [
            EntityKind.fill,
            EntityKind.polyline,
            EntityKind.text,
            EntityKind.text,
          ],
          reason: '$what: a region, then the labels');
      expect(labelStrings(plan.doc, room), ['Room 1', '29.48 m²'],
          reason: what);
      expect(codedAs(diagnosticsOf(plan.doc), 'room.'), isEmpty, reason: what);
      expect(driftOf(plan.doc), isEmpty, reason: what);
      // Step 1: the keyholed ring, the box's four corners and the
      // column's, and the slit's two points, 0.5 mm off a corner each.
      var tint = worldTintOf(plan.doc, room);
      var corners = [
        for (final (x, y) in [...box, ...columnCorners]) plan.at(x, y),
      ];
      expect(tint, hasLength(corners.length + 2), reason: what);
      for (final c in corners) {
        expect(nearest(c, tint), lessThan(1e-5), reason: '$what: corner $c');
      }
      expect([
        for (final q in tint)
          if (nearest(q, corners) > 1e-5) nearest(q, corners),
      ], [
        closeTo(kSlit, 1e-6),
        closeTo(kSlit, 1e-6)
      ], reason: '$what: the slit');
      // The label clear of the column: the pole of the box less the column
      // is 1,900 from the boundary (the half-height, 3,800 / 2), within its
      // 10 mm precision, so at least 1,890 from the column's faces.
      final anchor = anchorOf(plan.doc, room);
      final face = faceAt(plan.doc, plan.at(seedXY.$1, seedXY.$2)) as Traced;
      expect(poleOfInaccessibility(face.ring, face.holes).distance,
          closeTo(1900, 10),
          reason: what);
      expect(toRect(plan, anchor, columnCorners), greaterThan(1890),
          reason: '$what: the label at $anchor');
      expect(pointInRing(anchor, face.ring), isTrue, reason: what);

      // Two islands tied to each other and to the wall: step 1, two
      // keyholes. 29,320,000 (29.32, 0.005 from the ties).
      what = 'two islands tied at $place';
      plan = tied(place, const [tie, (5400.0, 2000.5, 6500.0, 2000.5)],
          more: const [column, column2]);
      room = addRoom(plan.doc, plan.at(seedXY.$1, seedXY.$2), 'Room 1');
      expect(kindsOf(plan.doc, room).first, EntityKind.fill, reason: what);
      expect(labelStrings(plan.doc, room), ['Room 1', '29.32 m²'],
          reason: what);
      expect(codedAs(diagnosticsOf(plan.doc), 'room.'), isEmpty, reason: what);
      expect(driftOf(plan.doc), isEmpty, reason: what);
      tint = worldTintOf(plan.doc, room);
      corners = [
        for (final (x, y) in [...box, ...columnCorners, ...column2Corners])
          plan.at(x, y),
      ];
      expect(tint, hasLength(corners.length + 4), reason: what);
      for (final c in corners) {
        expect(nearest(c, tint), lessThan(1e-5), reason: '$what: corner $c');
      }

      // What remains: a tied island pinched at a vertex is one pinched
      // hole, and the keyholed ring through it does not triangulate. The
      // outer ring alone does: step 2, reported, the area exact. As a free
      // pinched island would be; no longer step 3.
      what = 'a pinched island tied at $place';
      plan = tied(place, const [tie], more: const [column, cornerColumn]);
      room = addRoom(plan.doc, plan.at(seedXY.$1, seedXY.$2), 'Room 1');
      expect(
          kindsOf(plan.doc, room),
          [
            EntityKind.fill,
            EntityKind.polyline,
            EntityKind.text,
            EntityKind.text,
          ],
          reason: what);
      expect(labelStrings(plan.doc, room), ['Room 1', '29.32 m²'],
          reason: what);
      tint = worldTintOf(plan.doc, room);
      expect(tint, hasLength(4), reason: '$what: the outer ring alone');
      expect(
          codedAs(diagnosticsOf(plan.doc), 'room.'),
          [
            Diagnostic(
              severity: DiagnosticSeverity.warning,
              code: 'room.tint',
              message: 'room ${room.toHex()} ("Room 1"): its tint covers its '
                  'holes: the keyholed ring does not triangulate',
              handles: [room],
            ),
          ],
          reason: what);
      expect(driftOf(plan.doc), isEmpty, reason: what);
    }
  });

  test(
      'DE3 the Separator tool\'s transient: wall → column keeps the fill, '
      'column → wall splits the room; same handles; undone step by step', () {
    for (final place in const [origin, corpus, corpusGroups]) {
      final plan = tied(place, const []);
      final doc = plan.doc;
      final seed = plan.at(seedXY.$1, seedXY.$2);
      final room = addRoom(doc, seed, 'Room 1');
      final children = kids(doc, room);
      final start = stateOf(doc);
      // The column stands free: a hole. 29.48 m², as DE2.
      expect(labelStrings(doc, room), ['Room 1', '29.48 m²'], reason: '$place');
      expect(kindsOf(doc, room).first, EntityKind.fill, reason: '$place');

      // Each separator in its own turned, translated group in own groups
      // (not buildPlan's sequence).
      Transform2? group(int k) => place.groups
          ? place.m
              .multiply(Transform2.translation(-217.75 * k, 131.5 * k))
              .multiply(Transform2.rotation(0.45 + 0.8 * k))
          : null;

      // The first click pair: wall → column. The fill stays, with its
      // handles; the area too; one hole.
      addSeparator(doc, plan.at(tie.$1, tie.$2), plan.at(tie.$3, tie.$4),
          at: group(1));
      var what = 'wall → column at $place';
      expect(kids(doc, room), children, reason: '$what: same handles');
      expect(kindsOf(doc, room).first, EntityKind.fill, reason: what);
      expect(labelStrings(doc, room), ['Room 1', '29.48 m²'], reason: what);
      expect(codedAs(diagnosticsOf(doc), 'room.'), isEmpty, reason: what);
      expect(driftOf(doc), isEmpty, reason: what);
      expect((faceAt(doc, seed) as Traced).holes, hasLength(1), reason: what);
      expect(worldTintOf(doc, room), hasLength(10), reason: what);
      final tied1 = stateOf(doc);

      // The second: column → wall. The box splits; the room keeps the
      // west side, walking round the column's west half: 19,301,700 (DE1;
      // 19.30, 0.0033 from 19.295 and 19.305). No hole; the fill stays.
      addSeparator(doc, plan.at(tieNorth.$1, tieNorth.$2),
          plan.at(tieNorth.$3, tieNorth.$4),
          at: group(2));
      what = 'column → wall at $place';
      expect(kids(doc, room), children, reason: '$what: same handles');
      expect(kindsOf(doc, room).first, EntityKind.fill, reason: what);
      expect(labelStrings(doc, room), ['Room 1', '19.30 m²'], reason: what);
      expect(codedAs(diagnosticsOf(doc), 'room.'), isEmpty, reason: what);
      expect(driftOf(doc), isEmpty, reason: what);
      expect((faceAt(doc, seed) as Traced).holes, isEmpty, reason: what);
      final tint = worldTintOf(doc, room);
      expect(tint, hasLength(8), reason: what);
      for (final (x, y) in const [
        (100.0, 100.0),
        (5200.5, 100.0),
        (5200.5, 1800.0),
        (5000.0, 1800.0),
        (5000.0, 2200.0),
        (5200.5, 2200.0),
        (5200.5, 3900.0),
        (100.0, 3900.0),
      ]) {
        expect(nearest(plan.at(x, y), tint), lessThan(1e-5),
            reason: '$what: corner ($x, $y)');
      }

      doc.commands.undo();
      expect(stateOf(doc), tied1, reason: 'undo 1 at $place');
      expect(labelStrings(doc, room), ['Room 1', '29.48 m²'], reason: '$place');
      doc.commands.undo();
      expect(stateOf(doc), start, reason: 'undo 2 at $place');
      expect(driftOf(doc), isEmpty, reason: '$place');
    }
  });
}
