// SPIKE 11 -- throwaway. Q1: a wall's six attach points (decision 4) from
// 07's geometry, against coordinates worked out by hand, at six placements.
import 'dart:math' as math;

import 'package:floor_planner/parametric/dimension_geometry.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/parametric/wall_geometry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support.dart';

const l = WallSide.left, c = WallSide.centre, r = WallSide.right;
const jl = Justification.left, jc = Justification.centre;
const jr = Justification.right;

/// One expected point: wall index (0-based), end k, side, plan (x, y).
typedef Want = (int, int, WallSide, double, double);

/// A named fixture: its walls and the points worked out by hand.
typedef Case = (String, List<W>, List<Want>);

/// sqrt(3), for the 120° node: a wedge corner of two 200 mm walls meeting
/// at 120° lies 100 / sin 60° = 115.470 mm from the hub on the bisector,
/// that is at (100 / tan 60°, 100) = (57.735, 100) for the 60° bisector.
final double s3 = math.sqrt(3);

List<Case> cases() {
  final y = 100 / s3; // 57.735...: 100 / tan 60°
  final q = 200 / s3; // 115.470...: 100 / sin 60°
  return [
    // C1: one free wall, (0,0) -> (4000,0), 200 centred: faces y = ±100.
    (
      'C1 free',
      const [W(0, 0, 4000, 0, 200)],
      const [
        (0, 0, l, 0, 100), (0, 0, c, 0, 0), (0, 0, r, 0, -100), //
        (0, 1, l, 4000, 100), (0, 1, c, 4000, 0), (0, 1, r, 4000, -100),
      ]
    ),
    // C2: an L, A east then B north, 200 each. A's left face y = 100, B's
    // left face x = 4000 - 100 = 3900 (B's left normal is (-1, 0)); the
    // inner corner (3900, 100), the outer (4100, -100). The corner at the
    // far ends is free.
    (
      'C2 L mitre',
      const [W(0, 0, 4000, 0, 200), W(4000, 0, 4000, 3000, 200)],
      const [
        (0, 1, l, 3900, 100), (0, 1, c, 4000, 0), (0, 1, r, 4100, -100),
        (1, 0, l, 3900, 100), (1, 0, c, 4000, 0), (1, 0, r, 4100, -100),
        (0, 0, l, 0, 100), (0, 0, r, 0, -100), //
        (1, 1, l, 3900, 3000), (1, 1, r, 4100, 3000),
      ]
    ),
    // C3: the L with A 300 and B 100: A's faces y = ±150, B's x = 4000 ∓ 50.
    (
      'C3 L 300/100',
      const [W(0, 0, 4000, 0, 300), W(4000, 0, 4000, 3000, 100)],
      const [
        (0, 1, l, 3950, 150),
        (0, 1, r, 4050, -150),
        (1, 0, l, 3950, 150),
        (1, 0, r, 4050, -150),
      ]
    ),
    // C4: the L, every justification pair, A 200 and B 120. A's (left,
    // right) offsets: centre (100, -100), left (200, 0), right (0, -200);
    // B's: (60, -60), (120, 0), (0, -120). B's face at offset o is
    // x = 4000 - o. Left corner (4000 - lB, lA), right (4000 - rB, rA).
    for (final (ja, la, ra) in const [
      (jc, 100.0, -100.0),
      (jl, 200.0, 0.0),
      (jr, 0.0, -200.0)
    ])
      for (final (jb, lb, rb) in const [
        (jc, 60.0, -60.0),
        (jl, 120.0, 0.0),
        (jr, 0.0, -120.0)
      ])
        (
          'C4 L ${ja.name}/${jb.name}',
          [W(0, 0, 4000, 0, 200, ja), W(4000, 0, 4000, 3000, 120, jb)],
          [
            (0, 1, l, 4000 - lb, la), (0, 1, r, 4000 - rb, ra),
            (1, 0, l, 4000 - lb, la), (1, 0, r, 4000 - rb, ra),
            (0, 1, c, 4000, 0), (1, 0, c, 4000, 0),
            // A's free start: (0, la), (0, ra).
            (0, 0, l, 0, la), (0, 0, r, 0, ra),
          ]
        ),
    // C5: a T. The through wall C (0,0) -> (6000,0), 200: its ends are
    // free, the butt changes nothing of its six. The stem S from (2500, 0)
    // north, 100 centred: S's left face x = 2450, right x = 2550, cut at
    // C's near face y = 100. S's centre stays (2500, 0), on C's centreline.
    (
      'C5 T, stem starts on the through wall',
      const [W(0, 0, 6000, 0, 200), W(2500, 0, 2500, 3000, 100)],
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
    // C5b: the stem drawn the other way, ending (k = 1) on C: direction
    // (0, -1), left normal (1, 0), so its left face is x = 2550, right
    // 2450 — the swap at k = 1.
    (
      'C5b T, stem ends on the through wall',
      const [W(0, 0, 6000, 0, 200), W(2500, 3000, 2500, 0, 100)],
      const [
        (1, 1, l, 2550, 100),
        (1, 1, c, 2500, 0),
        (1, 1, r, 2450, 100),
      ]
    ),
    // C5c: the stem south of C, left-justified (offsets (100, 0)): the
    // near face is y = -100; S runs (2500,0) -> (2500,-3000), direction
    // (0, -1), left normal (1, 0): left face x = 2600, right x = 2500.
    (
      'C5c T from below, stem left-justified',
      const [
        W(0, 0, 6000, 0, 200),
        W(2500, 0, 2500, -3000, 100, Justification.left)
      ],
      const [
        (1, 0, l, 2600, -100),
        (1, 0, r, 2500, -100),
        (1, 0, c, 2500, 0),
      ]
    ),
    // C6: an X, two walls crossing mid-span: no joint, every end free.
    // B (2000,-2000) -> (2000,2000): left normal (-1, 0), left x = 1900.
    (
      'C6 X crossing',
      const [W(0, 0, 4000, 0, 200), W(2000, -2000, 2000, 2000, 200)],
      const [
        (0, 0, l, 0, 100),
        (0, 1, r, 4000, -100),
        (1, 0, l, 1900, -2000),
        (1, 0, r, 2100, -2000),
        (1, 1, l, 1900, 2000),
        (1, 1, r, 2100, 2000),
      ]
    ),
    // C7: a Y, three 200 mm walls out of (0, 0) at 0°, 120°, 240°. Each
    // wedge is 120°; its corner is on its bisector (60°, 180°, 300°) at
    // 100 / sin 60° = 115.470: (57.735, 100), (-115.470, 0),
    // (57.735, -100). A (0°): left = its wedge to B, (57.735, 100);
    // right = C's wedge to A, (57.735, -100). B (120°): left = B->C
    // (-115.470, 0), right = A->B (57.735, 100). C (240°): left = C->A
    // (57.735, -100), right = B->C (-115.470, 0).
    (
      'C7 Y node, 3 walls',
      [
        const W(0, 0, 3000, 0, 200),
        W(0, 0, 3000 * math.cos(2 * math.pi / 3),
            3000 * math.sin(2 * math.pi / 3), 200),
        W(0, 0, 3000 * math.cos(4 * math.pi / 3),
            3000 * math.sin(4 * math.pi / 3), 200),
      ],
      [
        (0, 0, l, y, 100),
        (0, 0, r, y, -100),
        (0, 0, c, 0, 0),
        (1, 0, l, -q, 0),
        (1, 0, r, y, 100),
        (2, 0, l, y, -100),
        (2, 0, r, -q, 0),
      ]
    ),
    // C8: a + node, four 200 mm walls out of (0, 0) at 0°, 90°, 180°,
    // 270°: every wedge 90°, corners (±100, ±100). A (east): left
    // (100, 100), right (100, -100); B (north): left (-100, 100), right
    // (100, 100); C (west): left (-100, -100), right (-100, 100); D
    // (south): left (100, -100), right (-100, -100).
    (
      'C8 + node, 4 walls',
      const [
        W(0, 0, 3000, 0, 200),
        W(0, 0, 0, 3000, 200),
        W(0, 0, -3000, 0, 200),
        W(0, 0, 0, -3000, 200),
      ],
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
    // C9: 07's fallback. A short base A (0,0) -> (100,0), 200, between B
    // north from its end and C north from its start. A's joined caps are
    // end [(200,-100), (0,100)] (mitre with B: B's faces x = 0 and 200)
    // and start [(100,100), (-100,-100)] (mitre with C: C's faces
    // x = ±100); the ring's edges (200,-100)->(0,100) (x + y = 100) and
    // (100,100)->(-100,-100) (y = x) cross at (50, 50): not simple, so A
    // falls back to its free caps, (0, ±100) and (100, ±100). B keeps
    // its mitre: (0, 100) and (200, -100); C keeps (100, 100) and
    // (-100, -100).
    (
      'C9 fallback',
      const [
        W(0, 0, 100, 0, 200),
        W(100, 0, 100, 3000, 200),
        W(0, 0, 0, 3000, 200),
      ],
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
    // C10: degenerate walls (07 D2): a zero thickness and a zero length.
    // No outline: every side is the centreline end.
    (
      'C10 degenerate',
      const [W(0, 0, 4000, 0, 0), W(0, 1000, 0, 1000, 200)],
      const [
        (0, 0, l, 0, 0),
        (0, 0, r, 0, 0),
        (0, 1, l, 4000, 0),
        (1, 0, l, 0, 1000),
        (1, 1, r, 0, 1000),
      ]
    ),
  ];
}

/// The walls of the case whose name starts with [prefix].
List<W> wallsOf(String prefix) =>
    cases().firstWhere((x) => x.$1.startsWith(prefix)).$2;

void main() {
  for (final place in placements) {
    test('Q1 every case against hand arithmetic, $place', () {
      var worst = 0.0;
      for (final (name, walls, wants) in cases()) {
        final all = worldWalls(walls, place);
        for (final (i, k, side, x, y) in wants) {
          final got = wallEndPoint(all[i], othersOf(all[i], all), k, side);
          final want = place.at(x, y);
          final err = (got - want).length;
          worst = math.max(worst, err);
          expect(err, lessThan(1e-6),
              reason: '$name: wall $i end $k ${side.name}: got $got, '
                  'want $want (plan ($x, $y))');
        }
      }
      // ignore: avoid_print
      print('Q1 worst error at $place: $worst mm');
    });
  }

  test('Q1 C9 falls back and C2 does not (07 fellBack)', () {
    final u = worldWalls(wallsOf('C9'), origin);
    expect(capsOf(u[0], othersOf(u[0], u))!.fellBack, isTrue);
    expect(capsOf(u[1], othersOf(u[1], u))!.fellBack, isFalse);
    final lw = worldWalls(wallsOf('C2'), origin);
    expect(capsOf(lw[0], othersOf(lw[0], lw))!.fellBack, isFalse);
  });

  test('Q1 the corner is a vertex of the stored outline, every case', () {
    // What a snap finds: each face point is a vertex of 07's outline ring
    // (the ring the wall stores), except a degenerate wall's.
    for (final (name, walls, _) in cases()) {
      final all = worldWalls(walls, corpusGroups);
      for (final w in all) {
        if (w.degenerate) continue;
        final ring = outline(w, othersOf(w, all)).ring;
        for (final (k, side, p) in wallEndPoints(w, othersOf(w, all))) {
          if (side == WallSide.centre) continue;
          final d = ring.map((q) => (q - p).length).reduce(math.min);
          expect(d, lessThan(1e-9),
              reason: '$name ${w.handle.value}/$k/${side.name}');
        }
      }
    }
  });

  test('Q1 an L corner is bitwise one point for both walls', () {
    // 07 D5.2: a wedge corner is computed once per wedge, so both walls hold
    // the same bits (in world, before the local map).
    final all = worldWalls(wallsOf('C2'), corpusGroups);
    final a = wallEndPoint(all[0], othersOf(all[0], all), 1, l);
    final b = wallEndPoint(all[1], othersOf(all[1], all), 0, l);
    expect([a.x, a.y], [b.x, b.y]);
    // ignore: avoid_print
    print('Q1 L inner corner, corpus own groups: A/1/left $a, B/0/left $b');
  });

  test('Q1 the Y owner walks the lobe: a ring vertex not among its six', () {
    final all = worldWalls(wallsOf('C7'), origin);
    for (final w in all) {
      final ring = outline(w, othersOf(w, all)).ring;
      final six = wallEndPoints(w, othersOf(w, all)).map((e) => e.$3);
      final foreign = [
        for (final q in ring)
          if (six.every((p) => (p - q).length > 1e-6)) q
      ];
      // ignore: avoid_print
      print('Q1 Y: wall ${w.handle.value} ring ${ring.length} points, '
          'not its own: $foreign');
    }
  });

  test('Q1 ring index is not an identity: A/1/left moves in the ring', () {
    // A free wall, then the same wall in the Y (the owner, walking the
    // lobe): the index of its left point in its ring changes.
    const free = [W(0, 0, 3000, 0, 200)];
    final ws = worldWalls(free, origin);
    int indexOf(List<Vector2> ring, Vector2 p) =>
        ring.indexWhere((q) => (q - p).length < 1e-9);
    final lone = outline(ws[0], const []).ring;
    final y = worldWalls(wallsOf('C7'), origin);
    final inY = outline(y[0], othersOf(y[0], y)).ring;
    final i0 = indexOf(lone, wallEndPoint(ws[0], const [], 0, WallSide.right));
    final i1 =
        indexOf(inY, wallEndPoint(y[0], othersOf(y[0], y), 0, WallSide.right));
    // ignore: avoid_print
    print('Q1 A/0/right ring index: free $i0 of ${lone.length}, '
        'in the Y $i1 of ${inY.length}');
    expect(i0, isNot(i1));
  });
}
