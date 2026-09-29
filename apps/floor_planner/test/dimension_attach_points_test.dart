// Spec 11 D4: a wall's six attach points, from 07's drawn joint geometry,
// against coordinates worked out by hand (AP1), under 07's local-ring
// fallback (AP2), and against the ring the wall stores (AP3). Ported from
// the spike's `corner_test.dart` (Q1), with `drawnCapsOf` in place of
// `capsOf` alone.
import 'dart:math' as math;

import 'package:floor_planner/parametric/dimension_geometry.dart';
import 'package:floor_planner/parametric/wall_geometry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/dimension_fixture.dart';
import 'support/wall_fixture.dart' show far, worldOutline;

const l = WallSide.left, c = WallSide.centre, r = WallSide.right;

/// One expected point: wall index (0-based), end k, side, plan (x, y).
typedef Want = (int, int, WallSide, double, double);

/// A named fixture: its walls and the points worked out by hand.
typedef Case = (String, List<W>, List<Want>);

/// D4's table. A wall's left normal is `(−d.y, d.x)`: +y for a wall running
/// east, −x for one running north, +x for one running south. A face at
/// offset `o` is the centreline moved `o` along it; a corner is where two
/// face lines meet.
List<Case> cases() {
  final y60 = 100 / math.sqrt(3); // 57.735: 100 / tan 60°
  final q = 200 / math.sqrt(3); // 115.470: 100 / sin 60°
  return [
    // C1: A east, 200 centred: faces y = ±100 (left +100). Free both ends:
    // the square end at x = 0 and x = 4000.
    (
      'C1 free',
      c1Walls,
      const [
        (0, 0, l, 0, 100), (0, 0, c, 0, 0), (0, 0, r, 0, -100), //
        (0, 1, l, 4000, 100), (0, 1, c, 4000, 0), (0, 1, r, 4000, -100),
      ]
    ),
    // C2: A east (faces y = ±100), B north from A's end (left normal
    // (−1, 0): left face x = 4000 − 100 = 3900, right x = 4100). Inner
    // corner: A's left y = 100 ∩ B's left x = 3900 → (3900, 100); outer:
    // A's right y = −100 ∩ B's right x = 4100 → (4100, −100). The centre is
    // the node (4000, 0). A's start and B's end are free: (0, ±100);
    // (3900, 3000), (4100, 3000).
    (
      'C2 L',
      c2Walls,
      const [
        (0, 1, l, 3900, 100), (0, 1, c, 4000, 0), (0, 1, r, 4100, -100),
        (1, 0, l, 3900, 100), (1, 0, c, 4000, 0), (1, 0, r, 4100, -100),
        (0, 0, l, 0, 100), (0, 0, r, 0, -100), //
        (1, 1, l, 3900, 3000), (1, 1, r, 4100, 3000),
      ]
    ),
    // C3: A 300 (faces y = ±150), B 100 (left x = 4000 − 50 = 3950, right
    // 4050): inner (3950, 150), outer (4050, −150).
    (
      'C3 L 300/100',
      c3Walls,
      const [
        (0, 1, l, 3950, 150),
        (0, 1, r, 4050, -150),
        (1, 0, l, 3950, 150),
        (1, 0, r, 4050, -150),
      ]
    ),
    // C4: the L, every justification pair, A 200 and B 120. A's left face is
    // y = lA, its right y = rA; B's face at offset o along (−1, 0) is
    // x = 4000 − o. The left corner is A's left ∩ B's left: (4000 − lB, lA);
    // the right corner A's right ∩ B's right: (4000 − rB, rA). A's start is
    // free: (0, lA), (0, rA). Both centres stay the node (4000, 0).
    for (final (ja, la, ra) in c4A)
      for (final (jb, lb, rb) in c4B)
        (
          'C4 L ${ja.name}/${jb.name}',
          c4Walls(ja, jb),
          [
            (0, 1, l, 4000 - lb, la),
            (0, 1, r, 4000 - rb, ra),
            (1, 0, l, 4000 - lb, la),
            (1, 0, r, 4000 - rb, ra),
            (0, 1, c, 4000, 0),
            (1, 0, c, 4000, 0),
            (0, 0, l, 0, la),
            (0, 0, r, 0, ra),
          ]
        ),
    // C5: a T. The through wall C east, 200: faces y = ±100, both ends free.
    // The stem S north from (2500, 0), 100 centred: left normal (−1, 0),
    // left face x = 2450, right x = 2550, both cut at C's near face y = 100.
    // S's centre stays its stored end (2500, 0), on C's centreline.
    (
      'C5 T',
      c5Walls,
      const [
        (1, 0, l, 2450, 100),
        (1, 0, c, 2500, 0),
        (1, 0, r, 2550, 100),
        (0, 0, l, 0, 100),
        (0, 0, r, 0, -100),
        (0, 1, l, 6000, 100),
        (0, 1, r, 6000, -100),
      ]
    ),
    // C5b: the stem drawn south, ending (k = 1) on C: direction (0, −1),
    // left normal (1, 0), so its left face is x = 2550 and its right 2450,
    // cut at y = 100: the swap at k = 1.
    (
      'C5b T, stem ends on C',
      c5bWalls,
      const [
        (1, 1, l, 2550, 100),
        (1, 1, c, 2500, 0),
        (1, 1, r, 2450, 100),
      ]
    ),
    // C5c: the stem south of C from (2500, 0), 100 left-justified (offsets
    // (100, 0)): direction (0, −1), left normal (1, 0), so its left face is
    // x = 2600 and its right x = 2500 (the centreline), cut at C's near face
    // y = −100.
    (
      'C5c T from below, stem left-justified',
      c5cWalls,
      const [
        (1, 0, l, 2600, -100),
        (1, 0, c, 2500, 0),
        (1, 0, r, 2500, -100),
      ]
    ),
    // C6: an X, crossing mid-span: no joint, every end free. A: (0, ±100),
    // (4000, ±100). B north: left x = 1900, right x = 2100.
    (
      'C6 X',
      c6Walls,
      const [
        (0, 0, l, 0, 100),
        (0, 1, r, 4000, -100),
        (1, 0, l, 1900, -2000),
        (1, 0, r, 2100, -2000),
        (1, 1, l, 1900, 2000),
        (1, 1, r, 2100, 2000),
      ]
    ),
    // C7: a Y, 200 mm walls at 0°, 120°, 240°. Each wedge is 120°, and its
    // corner lies on its bisector (60°, 180°, 300°) at 100 / sin 60° =
    // 115.470 from the hub: (57.735, 100), (−115.470, 0), (57.735, −100).
    // A (0°): left is its wedge to B (57.735, 100), right C's wedge to A
    // (57.735, −100). B (120°): left B→C (−115.470, 0), right A→B
    // (57.735, 100). C (240°): left C→A (57.735, −100), right B→C
    // (−115.470, 0).
    (
      'C7 Y',
      c7Walls,
      [
        (0, 0, l, y60, 100),
        (0, 0, c, 0, 0),
        (0, 0, r, y60, -100),
        (1, 0, l, -q, 0),
        (1, 0, r, y60, 100),
        (2, 0, l, y60, -100),
        (2, 0, r, -q, 0),
      ]
    ),
    // C8: a + node, every wedge 90°, corners (±100, ±100). A (east): left
    // (100, 100), right (100, −100); B (north): left (−100, 100), right
    // (100, 100); C (west, left normal (0, −1)): left (−100, −100), right
    // (−100, 100); D (south, left normal (1, 0)): left (100, −100), right
    // (−100, −100).
    (
      'C8 +',
      c8Walls,
      const [
        (0, 0, l, 100, 100),
        (0, 0, r, 100, -100),
        (1, 0, l, -100, 100),
        (1, 0, r, 100, 100),
        (2, 0, l, -100, -100),
        (2, 0, r, -100, 100),
        (3, 0, l, 100, -100),
        (3, 0, r, -100, -100),
      ]
    ),
    // C9: 07's short-wall fallback. A (0,0)→(100,0) 200 between B north
    // from its end (faces x = 0 and 200) and C north from its start (faces
    // x = ±100). A's joined caps would be end [(200, −100), (0, 100)] and
    // start [(100, 100), (−100, −100)]; the edges (200,−100)→(0,100)
    // (x + y = 100) and (100,100)→(−100,−100) (y = x) cross at (50, 50), so
    // the ring is not simple and A squares both ends: (0, ±100),
    // (100, ±100). B keeps its mitre with A: left x = 0 ∩ y = 100 → (0, 100),
    // right x = 200 ∩ y = −100 → (200, −100). C keeps (100, 100) (its right
    // x = 100 ∩ A's left y = 100) and (−100, −100).
    (
      'C9 short-wall fallback',
      c9Walls,
      const [
        (0, 0, l, 0, 100),
        (0, 0, r, 0, -100),
        (0, 1, l, 100, 100),
        (0, 1, r, 100, -100),
        (1, 0, l, 0, 100),
        (1, 0, r, 200, -100),
        (2, 0, l, -100, -100),
        (2, 0, r, 100, 100),
      ]
    ),
    // C10: degenerate walls (07 D2), a zero thickness, a zero length and a
    // length of 5e-7 mm (at or below wallJoin.linear): no outline, so every
    // side is the stored centreline end. The third wall's ends are (0, 2000)
    // and (5e-7, 2000); a free cap there would be ±100 off in y.
    (
      'C10 degenerate',
      c10Walls,
      const [
        (0, 0, l, 0, 0),
        (0, 0, c, 0, 0),
        (0, 0, r, 0, 0),
        (0, 1, l, 4000, 0),
        (0, 1, c, 4000, 0),
        (0, 1, r, 4000, 0),
        (1, 0, l, 0, 1000),
        (1, 0, c, 0, 1000),
        (1, 0, r, 0, 1000),
        (1, 1, l, 0, 1000),
        (1, 1, c, 0, 1000),
        (1, 1, r, 0, 1000),
        (2, 0, l, 0, 2000),
        (2, 0, c, 0, 2000),
        (2, 0, r, 0, 2000),
        (2, 1, l, 5e-7, 2000),
        (2, 1, c, 5e-7, 2000),
        (2, 1, r, 5e-7, 2000),
      ]
    ),
  ];
}

/// The Ls of [cases], where the corner is one wedge point for both walls.
List<List<W>> lFixtures() => [
      c2Walls,
      c3Walls,
      for (final (ja, _, _) in c4A)
        for (final (jb, _, _) in c4B) c4Walls(ja, jb),
    ];

/// [w]'s point at end [k] on [side] read straight off [caps] by D4's rule:
/// what a joined corner is, for a comparison.
Vector2 capPoint(
    ({List<Vector2> endCap, List<Vector2> startCap, bool fellBack}) caps,
    int k,
    WallSide side) {
  final cp = k == 0 ? caps.startCap : caps.endCap;
  return (k == 0) == (side == l) ? cp.first : cp.last;
}

/// The smallest distance from [p] to a point of [ring].
double nearest(List<Vector2> ring, Vector2 p) =>
    ring.map((x) => (x - p).length).reduce(math.min);

/// Whether [w] falls back under [drawnCapsOf] (false for a degenerate
/// wall, as [localOutlineOf] reports it).
bool drawnFellBack(WorldWall w, List<WorldWall> others) =>
    drawnCapsOf(w, others)?.fellBack ?? false;

void main() {
  for (final place in placements) {
    test(
        'AP1 every wall end point of C1-C10 equals its hand value to 1e-6 mm, '
        'k = 1 and both faces included, at $place', () {
      var worst = 0.0, n = 0;
      for (final (name, walls, wants) in cases()) {
        final all = worldWalls(walls, place);
        if (name.startsWith('C10')) {
          // Premises: all three are degenerate, and the third has a
          // direction (a length above zero) at this placement.
          expect([for (final w in all) w.degenerate], [true, true, true]);
          expect((all[2].e - all[2].s).length, greaterThan(0));
        }
        for (final (i, k, side, x, y) in wants) {
          final got = wallEndPoint(all[i], othersOf(all[i], all), k, side);
          final want = place.at(x, y);
          final err = (got - want).length;
          worst = math.max(worst, err);
          n++;
          expect(err, lessThan(1e-6),
              reason: '$name: wall $i end $k ${side.name}: got $got, '
                  'want $want (plan ($x, $y))');
        }
        // wallEndPoints is the six, in (k, side) order.
        for (final w in all) {
          final six = wallEndPoints(w, othersOf(w, all));
          expect([for (final (k, s, _) in six) '$k${s.name}'],
              ['0left', '0centre', '0right', '1left', '1centre', '1right']);
          for (final (k, s, p) in six) {
            final one = wallEndPoint(w, othersOf(w, all), k, s);
            expect([p.x, p.y], [one.x, one.y], reason: '$name $k $s');
          }
        }
      }
      // The ruled points: at each L both walls hold a corner's bits, because
      // 07 computes a wedge corner once (D5.2).
      for (final walls in lFixtures()) {
        final all = worldWalls(walls, place);
        final a = all[0], b = all[1];
        for (final side in const [l, r]) {
          final pa = wallEndPoint(a, [b], 1, side);
          final pb = wallEndPoint(b, [a], 0, side);
          expect([pa.x, pa.y], [pb.x, pb.y],
              reason: 'A/1/${side.name} vs B/0/${side.name} of '
                  '${walls.map((w) => '${w.t} ${w.j.name}')}');
        }
      }
      // ignore: avoid_print
      print('AP1 worst error at $place over $n points: $worst mm');
    });
  }

  test(
      'AP2 under 07\'s local-ring fallback the face points are the stored '
      'free rectangle\'s corners, at any similarity; drawnCapsOf falls back '
      'exactly when localOutlineOf does', () {
    // C11's A, stored at the identity: (−2500, 678.25) → the hub
    // (1234.5, 678.25) from the far origin, running east (left normal +y),
    // right-justified (offsets (0, −200)): its left face is the centreline
    // y = 678.25 and its right face y = 478.25. So its free rectangle's
    // corners, before the turn: A/0/left (−2500, 678.25), A/0/right
    // (−2500, 478.25), A/1/left (1234.5, 678.25) = the hub, A/1/right
    // (1234.5, 478.25), each + the far origin. Under a group scaled 1.5
    // (the stored thickness kept, the centreline the same in world) the
    // rectangle is 300 thick in world: the right face y = 378.25.
    Map<String, Vector2> freeCorners(double turn, double thick) {
      final g = turnedAbout(c11Hub, turn);
      Vector2 at(double x, double y) => g.transformPoint(far(x, y));
      return {
        '0left': at(-2500, 678.25),
        '0right': at(-2500, 678.25 - thick),
        '1left': at(1234.5, 678.25),
        '1right': at(1234.5, 678.25 - thick),
      };
    }

    // Whether the local image of [a]'s world outline is simple.
    bool localSimple(WorldWall a, WorldWall b) {
      final toLocal = a.toWorld.invert();
      return isSimpleCcw([
        for (final p in outline(a, [b]).ring) toLocal.transformPoint(p)
      ]);
    }

    void expectLocalFallback(String name, List<WorldWall> ws, double turn,
        double thick, double scale) {
      final (doc, hs) = docOfWalls(ws);
      final all = allWorldWalls(doc);
      final a = all[0], b = all[1];
      expect(a.handle, hs[0]);
      expect(a.toWorld.scaleMagnitude, closeTo(scale, 1e-12), reason: name);
      // Premises: A's world outline is simple, its local image is not, and
      // the real system reports A's fallback.
      expect(outline(a, [b]).fellBack, isFalse, reason: name);
      expect(capsOf(a, [b])!.fellBack, isFalse, reason: name);
      expect(localSimple(a, b), isFalse, reason: name);
      expect(localOutlineOf(a, [b]).fellBack, isTrue, reason: name);
      expect([
        for (final d in diagnosticsOf(doc))
          if (d.code == 'wall.fallback') d.handles
      ], anyElement(equals([a.handle])), reason: name);

      final want = freeCorners(turn, thick);
      final stored = worldOutline(doc, a.handle);
      final local = [
        for (final p in localOutlineOf(a, [b]).ring) a.toWorld.transformPoint(p)
      ];
      expect(stored, hasLength(4), reason: '$name: the stored rectangle');
      final joined = capPoint(capsOf(a, [b])!, 1, l);
      var worst = 0.0;
      for (final (k, side, p) in wallEndPoints(a, [b])) {
        if (side == c) continue;
        final key = '$k${side.name}';
        final err = (p - want[key]!).length;
        worst = math.max(worst, err);
        expect(err, lessThan(dimAttach.linear),
            reason: '$name A/$k/${side.name}: $p, want ${want[key]}');
        expect(nearest(stored, p), lessThan(dimAttach.linear),
            reason: '$name A/$k/${side.name}: a stored corner');
        expect(nearest(local, p), lessThan(dimAttach.linear),
            reason: '$name A/$k/${side.name}: localOutlineOf\'s corner');
        // capsOf's joined corner at the hub (the acute L's left) is not
        // among A's points.
        expect((p - joined).length, greaterThan(1), reason: '$name $key');
      }
      // ignore: avoid_print
      print('AP2 $name: worst $worst mm; the joined A/1/left $joined is '
          '${(joined - want['1left']!).length} mm from the drawn one');
    }

    // C11 as 07's WR13 has it: turned 133°.
    expectLocalFallback('C11', c11(), 133, 200, 1);
    // C11 in groups scaled 1.5. At 133° its local image under the scale is
    // simple (rounding decides the fold), so the variant takes 143°, where
    // it folds at both scales: the premises are asserted inside.
    expectLocalFallback('C11 scaled 1.5, turned 143',
        scaledGroups(c11(turn: 143)), 143, 300, 1.5);

    // C9's A falls back in step 1 (in world), so M-11fallback's site is
    // reached.
    for (final place in placements) {
      final u = worldWalls(c9Walls, place);
      expect(capsOf(u[0], othersOf(u[0], u))!.fellBack, isTrue,
          reason: '$place');
      expect(capsOf(u[1], othersOf(u[1], u))!.fellBack, isFalse);
    }

    // drawnCapsOf's fellBack equals localOutlineOf's: every AP1 fixture at
    // six placements, C11 at both scales, and 07's WR13 sweep.
    // Two edges are counted: a joined ring simple in world whose local image
    // is not (step 2 decides), and the reverse, a joined ring not simple in
    // world whose local image is (step 1 decides; D4 expected no fixture to
    // reach it, and the WR13 sweep does).
    var walls = 0, localOnly = 0, reverse = 0;
    bool reverseEdge(WorldWall w, List<WorldWall> o) {
      if (w.degenerate) return false;
      final joined = outline(w, o, fallback: false).ring;
      final toLocal = w.toWorld.invert();
      return !isSimpleCcw(joined) &&
          isSimpleCcw([for (final p in joined) toLocal.transformPoint(p)]);
    }

    void agree(String name, List<WorldWall> ws) {
      for (final (i, w) in ws.indexed) {
        final o = othersOf(w, ws);
        walls++;
        if (reverseEdge(w, o)) {
          reverse++;
          // The reverse edge's points, not only its flag: through the real
          // system, each face point is a vertex of the outline the wall
          // stores, taken to world (07 falls back in world here, so that is
          // the world free rectangle; the joined caps lie ~87 mm off it).
          final (doc, _) = docOfWalls(ws);
          final all = allWorldWalls(doc);
          final dw = all[i], dwo = othersOf(dw, all);
          expect(reverseEdge(dw, dwo), isTrue,
              reason: '$name wall ${w.handle.value}: the premise in the '
                  'document');
          final ring = worldOutline(doc, dw.handle);
          expect(ring, hasLength(4), reason: '$name: the stored rectangle');
          for (final (k, side, p) in wallEndPoints(dw, dwo)) {
            if (side == c) continue;
            expect(nearest(ring, p), lessThan(dimAttach.linear),
                reason: '$name wall ${w.handle.value} $k ${side.name}: $p, '
                    'the stored ring $ring');
          }
        }
        final drawn = drawnFellBack(w, o);
        expect(drawn, localOutlineOf(w, o).fellBack,
            reason: '$name wall ${w.handle.value}');
        if (drawn && !capsOf(w, o)!.fellBack) localOnly++;
      }
    }

    for (final place in placements) {
      for (final (name, ws, _) in cases()) {
        agree('$name at $place', worldWalls(ws, place));
      }
    }
    agree('C11', c11());
    agree('C11 scaled', scaledGroups(c11(turn: 143)));
    final sweepBefore = localOnly, reverseBefore = reverse;
    for (final deg in acuteDegrees) {
      for (final (ja, jb) in acuteJustifications) {
        for (final turn in acuteTurns) {
          agree('acute L $deg° ${ja.name}/${jb.name} turned $turn°',
              acuteL(deg, turn, ja, jb));
        }
      }
    }
    // Premises: the sweep reaches the local-ring fallback (07's WR13 finds
    // it: 2° right/left turned 133°, A) and the reverse edge (3° right/left
    // turned 299°, A), so both steps of drawnCapsOf are decided here.
    expect(localOnly - sweepBefore, greaterThan(0));
    expect(reverse - reverseBefore, greaterThan(0));
    // ignore: avoid_print
    print('AP2 fellBack agreement over $walls walls, $localOnly local-only '
        'fallbacks (${localOnly - sweepBefore} in the WR13 sweep), '
        '$reverse reverse-edge walls (${reverse - reverseBefore} in the '
        'sweep)');
  });

  for (final place in placements) {
    test(
        'AP3 every face point of a wall with no flush opening is a vertex of '
        'its stored ring, in world, at $place', () {
      // The bound (Ruling 11-10, corrected): the face point is computed in
      // world, the stored vertex is that world corner taken to the group's
      // local space and back, two roundings apart.
      // - 1e-9 mm where no own group turns the ring: the origin and the
      //   corpus far origin at the identity (measured 0).
      // - 1e-8 mm at the corpus far origin in own groups, not the plan's
      //   1e-9: one ulp of x ≈ 4.5e6 is 9.3e-10 mm, and the round trip
      //   through a turned group is measured at 1.04e-9 mm (C5's stem), so
      //   the bound is about ten ulps.
      // - dimAttach.linear at +1e9 mm, where one ulp is 1.2e-7 mm.
      final bound = place.dx.abs() > 1e8
          ? dimAttach.linear
          : place.groups
              ? 1e-8
              : 1e-9;
      var worst = 0.0, n = 0;
      for (final (name, ws, _) in cases()) {
        if (name.startsWith('C10')) continue; // no outline to hold a vertex
        final plan = buildPlan(ws, place: place);
        expect(plan.openings, isEmpty);
        final all = allWorldWalls(plan.doc);
        expect(all, hasLength(ws.length));
        for (final w in all) {
          final ring = worldOutline(plan.doc, w.handle);
          expect(ring.length, greaterThanOrEqualTo(4),
              reason: '$name ${w.handle.value}: a stored ring');
          for (final (k, side, p) in wallEndPoints(w, othersOf(w, all))) {
            if (side == c) continue;
            final d = nearest(ring, p);
            worst = math.max(worst, d);
            n++;
            expect(d, lessThan(bound),
                reason: '$name wall ${w.handle.value} $k ${side.name}: $p');
          }
        }
      }
      // ignore: avoid_print
      print('AP3 worst distance to a stored vertex at $place over $n face '
          'points: $worst mm (bound $bound)');
    });
  }
}
