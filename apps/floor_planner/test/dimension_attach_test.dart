// Spec 11 D10: which wall end point a dimension's end is. `AM3` is decision
// 19's choice among the candidates, with decision 22's timing (the committed
// kind's measuring direction, D6). The candidates are the brute-force
// oracle's (`bruteCandidates`), and each set's contents are asserted as a
// premise. Task 4 adds the candidates through the index (`AM1`, `AM2`,
// `AM4`–`AM6`).
import 'dart:math' as math;

import 'package:floor_planner/parametric/dimension_attach.dart';
import 'package:floor_planner/parametric/dimension_geometry.dart';
import 'package:floor_planner/parametric/opening_geometry.dart'
    show wallsInDocument;
import 'package:floor_planner/parametric/wall.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/dimension_fixture.dart';

const l = WallSide.left, c = WallSide.centre, r = WallSide.right;

/// Wall [h]'s point at end [k] on [side] in [doc], among every other live
/// wall (the document adapter).
Vector2 pointOf(DraftDocument doc, Handle h, int k, WallSide side) {
  final ws = wallsInDocument(doc, h)!;
  return wallEndPoint(ws.host, ws.walls, k, side);
}

/// `σ_W = |u × d_W|` restated for a printout: wall [h]'s world direction in
/// [doc] against [u].
double sigmaOf(DraftDocument doc, Handle h, Vector2 u) {
  final ws = wallsInDocument(doc, h)!;
  final d = ws.host.e - ws.host.s;
  final dw = d / d.length;
  return (u.x * dw.y - u.y * dw.x).abs();
}

void main() {
  for (final place in const [origin, corpusGroups]) {
    test(
        'AM3 a shared corner is stored on the wall the committed kind runs '
        'along, then on the lowest handle, then face before centre, k, left '
        'before right, at $place', () {
      // The dimension's group sits at the placement, so "horizontal" runs
      // along the placement's x (A's direction) and "vertical" along its y
      // (B's), and every hand value below, in plan coordinates, holds at
      // every placement.
      AttachedEnd? decide(DraftDocument doc, List<AttachedEnd> cands,
              DimKind kind, Vector2 at, Vector2 other) =>
          decideEnd(doc, cands, kind: kind, at: at, other: other, m: place.m);
      final rad = place.deg * math.pi / 180;
      Vector2 turned(double x, double y) => Vector2(
          x * math.cos(rad) - y * math.sin(rad),
          x * math.sin(rad) + y * math.cos(rad));

      // -- The L. The vertical wall B is added first, so it has the lower
      // handle: B (4000, 0) -> (4000, 3000), then A (0, 0) -> (4000, 0),
      // both 200 centred. A's left normal is +y (left face y = 100), B's is
      // −x (left face x = 3900): the inner corner is A's left ∩ B's left,
      // (3900, 100), and the outer A's right ∩ B's right, (4100, −100).
      {
        final (doc, hs) = docOfWalls(worldWalls(const [
          W(4000, 0, 4000, 3000, 200),
          W(0, 0, 4000, 0, 200),
        ], place));
        final b = hs[0], a = hs[1];
        expect(b.value < a.value, isTrue, reason: 'premise: B is lower');

        final inner = place.at(3900, 100);
        final ci = bruteCandidates(doc, inner);
        expect(ci, [AttachedEnd(b, 0, l), AttachedEnd(a, 1, l)],
            reason: 'premise: the inner corner is B/0/left and A/1/left');
        // M-11nearest's premise (S-10): at the origin the corner is bitwise
        // one point for both walls, so "the nearest" ties.
        final pa = pointOf(doc, a, 1, l), pb = pointOf(doc, b, 0, l);
        if (place == origin) {
          expect(pa.x == pb.x && pa.y == pb.y, isTrue,
              reason: 'premise: one point, bitwise ($pa, $pb)');
        }
        // Aligned to A/0/left (0, 100): u runs along A, σ_A = 0, σ_B = 1.
        final a0 = place.at(0, 100);
        expect(
            decide(doc, ci, DimKind.aligned, inner, a0), AttachedEnd(a, 1, l),
            reason: 'aligned along A');
        // Horizontal: u is the group's x, along A.
        expect(decide(doc, ci, DimKind.horizontal, inner, a0),
            AttachedEnd(a, 1, l),
            reason: 'horizontal along A');
        // Vertical to (3900, 3000): u is the group's y, along B.
        expect(decide(doc, ci, DimKind.vertical, inner, place.at(3900, 3000)),
            AttachedEnd(b, 0, l),
            reason: 'vertical along B');

        // Decision 22's case. The outer corner (4100, −100) to (3000,
        // 3000): the pair's direction is (3000 − 4100, 3000 + 100) =
        // (−1,100, 3,100), |·| = sqrt(1,100² + 3,100²) = sqrt(10,820,000) =
        // 3,289.38, so u = (−0.33441, 0.94243). B runs along y: σ_B = |u.x|
        // = 1,100 / 3,289.4 = 0.334; A along x: σ_A = |u.y| = 3,100 /
        // 3,289.4 = 0.942. Aligned is decided on B. Committed horizontal,
        // u = x: σ_A = 0, σ_B = 1, so A. Decided at the second click (the
        // pair's u) it would be B/0/right; decision 22 decides at the
        // commit, with the committed kind: A/1/right.
        final outer = place.at(4100, -100), far = place.at(3000, 3000);
        final co = bruteCandidates(doc, outer);
        expect(co, [AttachedEnd(b, 0, r), AttachedEnd(a, 1, r)],
            reason: 'premise: the outer corner is B/0/right and A/1/right');
        final u = measuringDirection(DimKind.aligned, outer, far, place.m);
        final hand = turned(-1100 / 3289.3768, 3100 / 3289.3768);
        expect((u - hand).length, lessThan(1e-6),
            reason: 'premise: aligned u = (−1,100, 3,100) / 3,289.4 ($u)');
        expect(
            decide(doc, co, DimKind.aligned, outer, far), AttachedEnd(b, 0, r),
            reason: 'aligned: σ_B 0.334 < σ_A 0.942');
        expect(decide(doc, co, DimKind.horizontal, outer, far),
            AttachedEnd(a, 1, r),
            reason: 'horizontal (decision 22): σ_A 0 < σ_B 1');
      }

      // -- Two collinear walls end to end, A (0, 0) -> (4000, 0) and
      // C (4000, 0) -> (8000, 0), 200 each: both run along a horizontal u,
      // so both lie in the band and the lower handle wins, in either
      // order. At a placement in own groups the two σ differ by rounding;
      // one of the two orders then puts the lower handle on the larger σ.
      for (final aFirst in const [true, false]) {
        const wa = W(0, 0, 4000, 0, 200), wc = W(4000, 0, 8000, 0, 200);
        final (doc, hs) = docOfWalls(
            worldWalls(aFirst ? const [wa, wc] : const [wc, wa], place));
        final a = aFirst ? hs[0] : hs[1], cw = aFirst ? hs[1] : hs[0];
        final q = place.at(4000, 100);
        final cands = bruteCandidates(doc, q);
        final want = [AttachedEnd(a, 1, l), AttachedEnd(cw, 0, l)]
          ..sort((x, y) => x.wall.value.compareTo(y.wall.value));
        expect(cands, want,
            reason: 'premise: the shared left point is A/1/left and C/0/left');
        final u = measuringDirection(
            DimKind.horizontal, q, place.at(0, 100), place.m);
        // ignore: avoid_print
        print('AM3 collinear at $place, ${aFirst ? 'A' : 'C'} lower: '
            'σ_A = ${sigmaOf(doc, a, u)}, σ_C = ${sigmaOf(doc, cw, u)}');
        expect(decide(doc, cands, DimKind.horizontal, q, place.at(0, 100)),
            aFirst ? AttachedEnd(a, 1, l) : AttachedEnd(cw, 0, l),
            reason: 'collinear, ${aFirst ? 'A' : 'C'} lower: the lower '
                'handle');
      }

      // -- A left-justified free end: A (0, 0) -> (4000, 0), 200
      // left-justified, so its faces lie at offsets (200, 0) along its left
      // normal: the right face is the centreline, and at the free start
      // (0, 0) the points (0, right) and (0, centre) coincide. Face before
      // centre: right is stored.
      {
        final (doc, hs) = docOfWalls(worldWalls(
            const [W(0, 0, 4000, 0, 200, Justification.left)], place));
        final a = hs[0];
        final q = place.at(0, 0);
        final cands = bruteCandidates(doc, q);
        expect(cands, [AttachedEnd(a, 0, c), AttachedEnd(a, 0, r)],
            reason: 'premise: (0, centre) and (0, right) coincide');
        expect(decide(doc, cands, DimKind.horizontal, q, place.at(4000, 0)),
            AttachedEnd(a, 0, r),
            reason: 'face before centre');
      }

      // -- A degenerate wall (length 0) at a corner: D (4000, 0) ->
      // (4000, 0), 200, added first (the lower handle), and A (0, 0) ->
      // (4000, 0), 200. Every one of D's six points is its centreline end
      // (4000, 0), A's end centre. D has no direction: σ_D = 1.
      {
        final (doc, hs) = docOfWalls(worldWalls(const [
          W(4000, 0, 4000, 0, 200),
          W(0, 0, 4000, 0, 200),
        ], place));
        final d = hs[0], a = hs[1];
        final q = place.at(4000, 0);
        final cands = bruteCandidates(doc, q);
        expect(
            cands,
            [
              for (final k in const [0, 1])
                for (final side in WallSide.values) AttachedEnd(d, k, side),
              AttachedEnd(a, 1, c),
            ],
            reason: 'premise: D\'s six points and A/1/centre');
        // Horizontal: σ_A = 0 < σ_D = 1, so A although D is lower.
        expect(decide(doc, cands, DimKind.horizontal, q, place.at(0, 0)),
            AttachedEnd(a, 1, c),
            reason: 'the degenerate wall loses to the wall along u');
        // Vertical: σ_A = |(0, 1) × (1, 0)| = 1 = σ_D, both in the band, so
        // the lower handle D, then (0, left).
        expect(decide(doc, cands, DimKind.vertical, q, place.at(4000, 3000)),
            AttachedEnd(d, 0, l),
            reason: 'σ_D = 1 ties a perpendicular wall');
      }

      // -- Degenerate walls alone: D1 and D2, both (0, 1000) -> (0, 1000),
      // 200. Twelve coincident points; the lowest handle, then face before
      // centre, the lower k, left before right: D1/0/left.
      {
        final (doc, hs) = docOfWalls(worldWalls(const [
          W(0, 1000, 0, 1000, 200),
          W(0, 1000, 0, 1000, 200),
        ], place));
        final q = place.at(0, 1000);
        final cands = bruteCandidates(doc, q);
        expect(
            cands,
            [
              for (final h in hs)
                for (final k in const [0, 1])
                  for (final side in WallSide.values) AttachedEnd(h, k, side),
            ],
            reason: 'premise: twelve coincident points');
        for (final kind in DimKind.values) {
          expect(decide(doc, cands, kind, q, place.at(3000, 1000)),
              AttachedEnd(hs[0], 0, l),
              reason: '${kind.name}: the lowest handle, then (0, left)');
        }
      }
    });
  }
}
