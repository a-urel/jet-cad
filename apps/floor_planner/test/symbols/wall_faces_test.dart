// Spec 09c D3: the wall faces a symbol stands against, as face runs in
// world. Every scene is `wall_attach_fixture.dart`'s (plan P-2, P-3): walls
// at 30° and −112.5°, each in its own rotated group near (1e5, −7e4); the
// expected points are hand arithmetic on world offset lines (an L's
// corners from its turn and its two thicknesses) or `wall_fixture.dart`'s
// Cramer oracle, never the code under test.
import 'dart:math' as math;

import 'package:floor_planner/parametric/opening_geometry.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/parametric/wall_geometry.dart';
import 'package:floor_planner/symbols/wall_attach.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/dimension_fixture.dart' show c11, docOfWalls, scaledGroups;
import '../support/wall_attach_fixture.dart';
import '../support/wall_fixture.dart';

/// 07 D2's face offsets `(left, right)` along the left normal, by hand.
(double, double) offsetsBy(Justification j, double t) => switch (j) {
      Justification.centre => (t / 2, -t / 2),
      Justification.left => (t, 0),
      Justification.right => (0, -t),
    };

Vector2 unit(double deg) =>
    Vector2(math.cos(deg * math.pi / 180), math.sin(deg * math.pi / 180));

Vector2 leftNormal(Vector2 d) => Vector2(-d.y, d.x);

/// The run's other end, `a + t·L`.
Vector2 endOf(FaceRun r) => r.a + r.t * r.length;

const double tol = 1e-7;

/// D3's frame of a run: `m` and `t` unit, `t = (−m.y, m.x)` exactly, and
/// `a` the end with the smaller `(·)·t`.
void expectRunFrame(FaceRun r, String why) {
  expect(r.m.length, closeTo(1, 1e-12), reason: '$why: |m|');
  expect([r.t.x, r.t.y], [-r.m.y, r.m.x], reason: '$why: t = (−m.y, m.x)');
  expect(r.length, greaterThan(wallJoin.linear), reason: why);
}

/// [r]'s two ends are [p] and [q] (in either order), and [r.a] is the one
/// with the smaller `(·)·t`.
void expectEnds(FaceRun r, Vector2 p, Vector2 q, String why) {
  final lo = p.dot(r.t) <= q.dot(r.t) ? p : q, hi = identical(lo, p) ? q : p;
  expect((r.a - lo).length, lessThan(tol),
      reason: '$why: a ${r.a}, want $lo (other end $hi)');
  expect((endOf(r) - hi).length, lessThan(tol),
      reason: '$why: a + t·L ${endOf(r)}, want $hi');
}

/// The perpendicular distance from [p] to the line through [a] along [d].
double offLine(Vector2 p, Vector2 a, Vector2 d) {
  final u = d.normalized();
  final v = p - a;
  return (v.x * u.y - v.y * u.x).abs();
}

/// The runs on [side].
List<FaceRun> onSide(List<FaceRun> runs, FaceSide side) => [
      for (final r in runs)
        if (r.side == side) r
    ];

/// The `u` (along [d] from [p0]) of the point where the line through
/// [q0], [q1] crosses the line through [p0] along [d]: Cramer's oracle.
double crossU(Vector2 p0, Vector2 d, (Vector2, Vector2) other) {
  final x = oracleMeet(p0, p0 + d * 1000, other.$1, other.$2);
  return (x - p0).dot(d);
}

void main() {
  test(
      'WF1 a free wall has two runs, one per face, on its drawn face lines: '
      'm away from the other face, t = (−m.y, m.x), a the lower end along t, '
      'L its length and w its thickness; every justification (the '
      'zero-offset face included), at 30° and −112.5° near (1e5, −7e4), '
      'mirrored and not', () {
    var n = 0;
    for (final deg in attachAngles) {
      for (final j in Justification.values) {
        for (final mirrored in const [false, true]) {
          final why = '$deg° ${j.name}${mirrored ? ' mirrored' : ''}';
          final sc = freeWallScene(deg, j, mirrored: mirrored);
          final h = sc.walls.single;
          final w = worldWallOf(sc.doc, h);
          expect(w.toWorld.determinant < 0, mirrored, reason: why);
          final runs = faceRunsOf(sc.doc, h);
          expect(
              [for (final r in runs) r.side], [FaceSide.left, FaceSide.right],
              reason: why);
          // The faces by hand: the stored centreline offset along the
          // frame's (local) left normal by 07 D2's offsets, to world.
          final p = w.params;
          final dl = (p.end - p.start).normalized(), nl = leftNormal(dl);
          final (lo, ro) = offsetsBy(j, 150);
          final g = w.toWorld;
          final ls = g.transformPoint(p.start + nl * lo),
              le = g.transformPoint(p.end + nl * lo),
              rs = g.transformPoint(p.start + nl * ro),
              re = g.transformPoint(p.end + nl * ro);
          final mLeft = (ls - rs).normalized();
          for (final r in runs) {
            final left = r.side == FaceSide.left;
            final rw = '$why ${r.side.name}';
            expectRunFrame(r, rw);
            expect(r.wall, h, reason: rw);
            expect(r.thickness, closeTo(150, 1e-9), reason: rw);
            expect(r.length, closeTo(3600, 1e-9), reason: rw);
            final m = left ? mLeft : -mLeft;
            expect((r.m - m).length, lessThan(1e-12), reason: '$rw: m');
            expectEnds(r, left ? ls : rs, left ? le : re, rw);
            // The zero-offset face lies on the world centreline.
            if ((left ? lo : ro) == 0) {
              expect(offLine(r.a, w.s, w.d), lessThan(tol), reason: rw);
              expect(offLine(endOf(r), w.s, w.d), lessThan(tol), reason: rw);
            }
            // m points into the room: away from the other face's line.
            final other = runs.firstWhere((x) => x.side != r.side);
            expect((r.a - other.a).dot(r.m), closeTo(150, 1e-9), reason: rw);
          }
          // Which of ±d a face's t is depends on the mirror (D3).
          final leftRun = runs.first;
          expect(leftRun.t.dot(w.d), closeTo(mirrored ? 1 : -1, 1e-12),
              reason: why);
          n++;
        }
      }
    }
    expect(n, 12);
  });

  test(
      'WF2 an L of 100 and 240 mm: each face ends at the drawn corner, so '
      'the inside face is shorter than the centreline and the outside face '
      'longer, by the hand-derived amounts; every justification pair, both '
      'turns, at 30° and −112.5°', () {
    var n = 0;
    for (final deg in attachAngles) {
      for (final turn in const [75.0, -75.0]) {
        for (final ja in Justification.values) {
          for (final jb in Justification.values) {
            final why = '$deg° turn $turn ${ja.name}/${jb.name}';
            final sc = lScene(deg, turn, ja: ja, jb: jb);
            for (final h in sc.walls) {
              expect(hostFrameInDocument(sc.doc, h)!.fellBack, isFalse,
                  reason: '$why: the L is joined');
            }
            final th = turn * math.pi / 180;
            final c = math.cos(th), s = math.sin(th);
            final d1 = unit(deg), d2 = unit(deg + turn);
            final n1 = leftNormal(d1), n2 = leftNormal(d2);
            final aStart = lCorner - d1 * lLengthA;
            final bEnd = lCorner + d2 * lLengthB;
            final (al, ar) = offsetsBy(ja, lThickA);
            final (bl, br) = offsetsBy(jb, lThickB);
            final runsA = faceRunsOf(sc.doc, sc.walls[0]);
            final runsB = faceRunsOf(sc.doc, sc.walls[1]);
            expect(runsA, hasLength(2), reason: why);
            expect(runsB, hasLength(2), reason: why);
            for (final (side, oa, ob) in [
              (FaceSide.left, al, bl),
              (FaceSide.right, ar, br),
            ]) {
              // A's face at offset oa meets B's at offset ob: along A from
              // the corner x = (oa·cos θ − ob)/sin θ, along B
              // y = (oa − ob·cos θ)/sin θ.
              final x = (oa * c - ob) / s, y = (oa - ob * c) / s;
              final ra = onSide(runsA, side).single;
              final rb = onSide(runsB, side).single;
              expect(ra.length, closeTo(lLengthA + x, 1e-6),
                  reason: '$why A ${side.name}');
              expect(rb.length, closeTo(lLengthB - y, 1e-6),
                  reason: '$why B ${side.name}');
              expectEnds(ra, aStart + n1 * oa, lCorner + n1 * oa + d1 * x,
                  '$why A ${side.name}');
              expectEnds(rb, lCorner + n2 * ob + d2 * y, bEnd + n2 * ob,
                  '$why B ${side.name}');
              expect(ra.thickness, closeTo(lThickA, 1e-9), reason: why);
              expect(rb.thickness, closeTo(lThickB, 1e-9), reason: why);
            }
            // The inside face (the turn's side) is shorter than the
            // centreline, the outside face longer.
            if (ja == Justification.centre && jb == Justification.centre) {
              final inside = turn > 0 ? FaceSide.left : FaceSide.right;
              for (final (runs, len) in [
                (runsA, lLengthA),
                (runsB, lLengthB),
              ]) {
                for (final r in runs) {
                  expect(r.length < len, r.side == inside,
                      reason: '$why ${r.side.name}: ${r.length} vs $len');
                  expect((r.length - len).abs(), greaterThan(10), reason: why);
                }
              }
            }
            n++;
          }
        }
      }
    }
    expect(n, 36);
  });

  test(
      'WF3 a T cuts only the face the stem butts, by the range where the '
      'stem\'s two drawn face lines cross that face line; the other face '
      'is whole; every host justification, a stem on either side, drawn '
      'from or towards the host, at 30° and −112.5°', () {
    var n = 0;
    for (final deg in attachAngles) {
      for (final hostJ in Justification.values) {
        for (final (stemTurn, butted) in const [
          (70.0, FaceSide.left),
          (-110.0, FaceSide.right),
        ]) {
          for (final inward in const [false, true]) {
            final why = '$deg° ${hostJ.name} stem $stemTurn'
                '${inward ? ' inward' : ''}';
            final sc = teeScene(deg, stemTurn,
                hostJ: hostJ, stemJ: Justification.left, inward: inward);
            final host = worldWallOf(sc.doc, sc.walls[0]);
            final stem = worldWallOf(sc.doc, sc.walls[1]);
            final runs = faceRunsOf(sc.doc, sc.walls[0]);
            final (hl, hr) = offsetsBy(hostJ, teeThickHost);
            final (sl, sr) = stem.offsets;
            final d = host.d;
            for (final side in FaceSide.values) {
              final off = side == FaceSide.left ? hl : hr;
              final p0 = face(host, off).$1;
              final mine = onSide(runs, side);
              final rw = '$why ${side.name}';
              for (final r in mine) {
                expectRunFrame(r, rw);
              }
              if (side != butted) {
                expect(mine, hasLength(1), reason: '$rw: whole');
                expectEnds(mine.single, p0, face(host, off).$2, rw);
                continue;
              }
              final u1 = crossU(p0, d, face(stem, sl)),
                  u2 = crossU(p0, d, face(stem, sr));
              final lo = math.min(u1, u2), hi = math.max(u1, u2);
              // The premise: an oblique stem's cut is wider than it.
              expect(hi - lo, greaterThan(teeThickStem), reason: rw);
              expect(mine, hasLength(2), reason: '$rw: split');
              mine.sort(
                  (x, y) => (x.a - p0).dot(d).compareTo((y.a - p0).dot(d)));
              expectEnds(mine[0], p0, p0 + d * lo, '$rw before the stem');
              expectEnds(mine[1], p0 + d * hi, p0 + d * teeHostLength,
                  '$rw after the stem');
            }
            n++;
          }
        }
      }
    }
    expect(n, 24);
  });

  test(
      'WF4 an X at 60° cuts each face by its own crossings with the other '
      'wall\'s drawn face lines, not by their union, at 30° and −112.5°', () {
    var n = 0;
    for (final deg in attachAngles) {
      for (final (hostJ, crossJ) in const [
        (Justification.centre, Justification.centre),
        (Justification.left, Justification.right),
      ]) {
        final why = '$deg° ${hostJ.name}/${crossJ.name}';
        final sc = crossScene(deg, 60, hostJ: hostJ, crossJ: crossJ);
        final host = worldWallOf(sc.doc, sc.walls[0]);
        final b = worldWallOf(sc.doc, sc.walls[1]);
        final runs = faceRunsOf(sc.doc, sc.walls[0]);
        final (hl, hr) = host.offsets;
        final (bl, br) = b.offsets;
        final d = host.d;
        final cuts = <(double, double)>[];
        for (final (side, off) in [(FaceSide.left, hl), (FaceSide.right, hr)]) {
          final p0 = face(host, off).$1;
          final u1 = crossU(p0, d, face(b, bl)),
              u2 = crossU(p0, d, face(b, br));
          final lo = math.min(u1, u2), hi = math.max(u1, u2);
          cuts.add((lo, hi));
          final mine = onSide(runs, side)
            ..sort((x, y) => (x.a - p0).dot(d).compareTo((y.a - p0).dot(d)));
          final rw = '$why ${side.name}';
          expect(mine, hasLength(2), reason: '$rw: split');
          expectEnds(mine[0], p0, p0 + d * lo, '$rw before');
          expectEnds(mine[1], p0 + d * hi, p0 + d * 4200, '$rw after');
        }
        // The premise for "not the union": the two faces' cuts are shifted
        // by w·cot 60° ≈ 115 mm.
        expect((cuts[0].$1 - cuts[1].$1).abs(), greaterThan(100), reason: why);
        n++;
      }
    }
    expect(n, 4);
  });

  test(
      'WF5 (S-3) in a mirrored group a centre-justified T cuts the face on '
      'the stem\'s side, decided in the host\'s local frame: the frame\'s '
      'right face for a stem on the world left, where the world normal '
      'would cut the other face', () {
    var n = 0;
    for (final deg in attachAngles) {
      for (final stemTurn in const [70.0, -110.0]) {
        for (final inward in const [false, true]) {
          final why = '$deg° stem $stemTurn${inward ? ' inward' : ''}';
          final sc = teeScene(deg, stemTurn, inward: inward, mirrored: true);
          final host = worldWallOf(sc.doc, sc.walls[0]);
          final stem = worldWallOf(sc.doc, sc.walls[1]);
          expect(host.toWorld.determinant, lessThan(0), reason: why);
          // The stem's body direction at its foot, and which world side of
          // the host it is on.
          final k = inward ? 1 : 0;
          final into = End(stem, k).a;
          final worldLeft = into.dot(leftNormal(host.d)) > 0;
          expect(worldLeft, stemTurn > 0, reason: why);
          // The premise: the local and world tests disagree.
          final frame = hostFrameInDocument(sc.doc, sc.walls[0])!;
          final localLeft =
              host.toWorld.invert().transformDirection(into).dot(frame.n) > 0;
          expect(localLeft, !worldLeft, reason: why);

          final runs = faceRunsOf(sc.doc, sc.walls[0]);
          final butted = localLeft ? FaceSide.left : FaceSide.right;
          // The butted face's world line: on the stem's side, ±100.
          final off = worldLeft ? 100.0 : -100.0;
          final p0 = face(host, off).$1;
          final (sl, sr) = stem.offsets;
          final u1 = crossU(p0, host.d, face(stem, sl)),
              u2 = crossU(p0, host.d, face(stem, sr));
          final lo = math.min(u1, u2), hi = math.max(u1, u2);
          final mine = onSide(runs, butted)
            ..sort((x, y) =>
                (x.a - p0).dot(host.d).compareTo((y.a - p0).dot(host.d)));
          expect(mine, hasLength(2), reason: '$why: the butted face split');
          expectEnds(mine[0], p0, p0 + host.d * lo, '$why before');
          expectEnds(mine[1], p0 + host.d * hi, p0 + host.d * teeHostLength,
              '$why after');
          final other = onSide(runs, FaceSide.values[1 - butted.index]);
          expect(other, hasLength(1), reason: '$why: the far face whole');
          expectEnds(other.single, face(host, -off).$1, face(host, -off).$2,
              '$why far');
          n++;
        }
      }
    }
    expect(n, 8);
  });

  test(
      'WF6 (S-2) in a scaled group the face lines are the drawn ones, not '
      'the frame\'s offsets: w is the drawn thickness and every run end is '
      'a vertex of the outline the wall stores, joined (an L), fallen back '
      'in world (a short base) and fallen back in local space (C11)', () {
    // Each run end is within 1e-6 of a stored outline vertex, in world.
    void onOutline(DraftDocument doc, Handle h, String why) {
      final ring = worldOutline(doc, h);
      expect(ring, isNotEmpty, reason: why);
      for (final r in faceRunsOf(doc, h)) {
        for (final p in [r.a, endOf(r)]) {
          expect(nearestIn(ring, p), lessThan(1e-6),
              reason: '$why ${r.side.name}: $p not on $ring');
        }
      }
    }

    // The frame's own offsets, taken to world: what M-09c-at would use.
    double frameThickness(DraftDocument doc, Handle h) {
      final f = hostFrameInDocument(doc, h)!;
      final g = worldWallOf(doc, h).toWorld;
      return (g.transformPoint(f.left(0)) - g.transformPoint(f.right(0)))
          .length;
    }

    for (final deg in attachAngles) {
      // Joined: 07 joins in world, so the drawn L is 100 and 240 thick
      // while the frame's offsets, scaled 1.5, are 150 and 360.
      final l = lScene(deg, 75, scale: 1.5);
      for (final (i, t) in [(0, lThickA), (1, lThickB)]) {
        final h = l.walls[i];
        final why = '$deg° scaled L wall $i';
        expect(
            worldWallOf(l.doc, h).toWorld.scaleMagnitude, closeTo(1.5, 1e-12));
        expect(hostFrameInDocument(l.doc, h)!.fellBack, isFalse, reason: why);
        expect(frameThickness(l.doc, h), closeTo(1.5 * t, 1e-6), reason: why);
        final runs = faceRunsOf(l.doc, h);
        expect(runs, hasLength(2), reason: why);
        for (final r in runs) {
          expect(r.thickness, closeTo(t, 1e-6), reason: why);
        }
        onOutline(l.doc, h, why);
      }

      // Fallen back in world: the base's caps are 07's free caps, 200
      // thick in world (the frame's offsets would give 300).
      final u = shortBaseScene(deg, scale: 1.5);
      final base = u.walls[0];
      final why = '$deg° scaled short base';
      final uw = [for (final h in u.walls) worldWallOf(u.doc, h)];
      expect(capsOf(uw[0], uw.sublist(1))!.fellBack, isTrue, reason: why);
      expect(frameThickness(u.doc, base), closeTo(300, 1e-6), reason: why);
      final runs = faceRunsOf(u.doc, base);
      expect(runs, hasLength(2), reason: why);
      for (final r in runs) {
        expect(r.thickness, closeTo(200, 1e-6), reason: why);
        expect(r.length, closeTo(100, 1e-6), reason: why);
      }
      for (final h in u.walls) {
        onOutline(u.doc, h, '$why wall ${h.value}');
      }
    }

    // Fallen back in local space (spec 11's C11 scaled 1.5, turned 143°,
    // `dimension_attach_points_test.dart`'s AP2 premises): the stored
    // rectangle is the local free one, 300 thick in world.
    final (doc, hs) = docOfWalls(scaledGroups(c11(turn: 143)));
    final a = hs[0];
    expect(hostFrameInDocument(doc, a)!.fellBack, isTrue);
    final ws = [for (final h in hs) worldWallOf(doc, h)];
    expect(capsOf(ws[0], [ws[1]])!.fellBack, isFalse);
    final runs = faceRunsOf(doc, a);
    expect(runs, hasLength(2));
    for (final r in runs) {
      expect(r.thickness, closeTo(300, 1e-6));
    }
    onOutline(doc, a, 'C11 scaled');
  });

  test(
      'WF7 a degenerate wall, a handle that is no wall, and a wall the '
      'accept predicate refuses give no runs; accept is asked only for a '
      'live wall', () {
    final sc = freeWallScene(30, Justification.right);
    final doc = sc.doc;
    final h = sc.walls.single;
    final thin = doc.handleSeed.next(), short = doc.handleSeed.next();
    doc.commands.execute(addWallLocal(
        doc,
        thin,
        WallParams(10, 20, 3000, 40, 0, Justification.centre),
        attachGroup(thin.value)));
    doc.commands.execute(addWallLocal(
        doc,
        short,
        WallParams(10, 20, 10 + 5e-7, 20, 200, Justification.centre),
        attachGroup(short.value)));
    expect(worldWallOf(doc, thin).degenerate, isTrue);
    expect(worldWallOf(doc, short).degenerate, isTrue);
    expect(faceRunsOf(doc, thin), isEmpty);
    expect(faceRunsOf(doc, short), isEmpty);
    expect(faceRunsOf(doc, const Handle(999999)), isEmpty);

    final asked = <Handle>[];
    bool refuse(DraftDocument _, Handle w) {
      asked.add(w);
      return false;
    }

    bool allow(DraftDocument _, Handle w) => true;
    expect(faceRunsOf(doc, h), hasLength(2));
    expect(faceRunsOf(doc, h, accept: allow), hasLength(2));
    expect(faceRunsOf(doc, h, accept: refuse), isEmpty);
    expect(faceRunsOf(doc, const Handle(999999), accept: refuse), isEmpty);
    expect(asked, [h]);
  });

  test(
      'WF8 a piece no longer than wallJoin.linear is dropped, a longer one '
      'kept: a square stem whose far face line meets the host face 5e-7 '
      'and 3e-6 short of its end, at 30° and −112.5°', () {
    for (final deg in attachAngles) {
      for (final (gap, kept) in const [(5e-7, false), (3e-6, true)]) {
        final why = '$deg° gap $gap';
        // The stem at 90° to the host: its faces cross the host's left
        // face at foot ∓ 60 along it, so the piece after it is `gap` long.
        final sc =
            teeScene(deg, 90, foot: teeHostLength - teeThickStem / 2 - gap);
        final left = onSide(faceRunsOf(sc.doc, sc.walls[0]), FaceSide.left);
        final host = worldWallOf(sc.doc, sc.walls[0]);
        final p0 = face(host, teeThickHost / 2).$1;
        final us = [
          for (final r in left)
            for (final q in [r.a, endOf(r)]) (q - p0).dot(host.d),
        ]..sort();
        expect(left, hasLength(kept ? 2 : 1), reason: '$why: $left');
        if (kept) {
          final sliver = left.firstWhere((r) => r.length < 1);
          expect(sliver.length, closeTo(gap, 1e-9), reason: why);
        }
        expect(us.first.abs(), lessThan(tol), reason: why);
        expect(us.last - teeHostLength,
            closeTo(kept ? 0 : -teeThickStem - gap, tol),
            reason: why);
      }
    }
  });
}
