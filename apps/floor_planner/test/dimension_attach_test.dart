// Spec 11 D10: which wall end point a dimension's end is. `AM3` is decision
// 19's choice among the candidates, with decision 22's timing (the committed
// kind's measuring direction, D6); its candidates are the brute-force
// oracle's (`bruteCandidates`), each set's contents asserted as a premise.
// `AM1`, `AM2`, `AM4`–`AM6` are the candidates through the index
// (`attachCandidates`: the two rect queries, the opening hosts, the line
// test), against the same oracle and against hand values.
import 'dart:math' as math;

import 'package:floor_planner/parametric/catalog.dart' show installParametric;
import 'package:floor_planner/parametric/dimension_attach.dart';
import 'package:floor_planner/parametric/dimension_geometry.dart';
import 'package:floor_planner/parametric/opening.dart'
    show OpeningKind, OpeningParams, SwingSide;
import 'package:floor_planner/parametric/opening_geometry.dart'
    show wallsInDocument;
import 'package:floor_planner/parametric/separator.dart'
    show ensureDashedLinetype;
import 'package:floor_planner/parametric/wall.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/dimension_fixture.dart';
import 'support/wall_fixture.dart' show far;

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

/// Plan vector ([x], [y]) turned by [place]'s rotation: a plan direction in
/// world.
Vector2 turnedBy(Placement place, double x, double y) {
  final rad = place.deg * math.pi / 180;
  return Vector2(x * math.cos(rad) - y * math.sin(rad),
      x * math.sin(rad) + y * math.cos(rad));
}

/// Decision 19's rule (spec 11 D10, R-17), restated over the candidate
/// [set] for a measuring direction [u], by a loop and not by `decideEnd`:
/// each wall's `σ = |u × d_W|` (1 for a wall no longer than 1e-6 mm), the
/// candidates within 1e-9 of the least σ, then the lowest handle, a face
/// before the centre, the lower k, left before right. Null for no
/// candidates.
AttachedEnd? rule19(DraftDocument doc, List<AttachedEnd> set, Vector2 u) {
  double sigma(Handle h) {
    final ws = wallsInDocument(doc, h)!;
    final d = ws.host.e - ws.host.s;
    if (!(d.length > 1e-6)) return 1;
    final dw = d / d.length;
    return (u.x * dw.y - u.y * dw.x).abs();
  }

  var least = double.infinity;
  for (final e in set) {
    least = math.min(least, sigma(e.wall));
  }
  int rank(AttachedEnd e) => e.side == c ? 1 : 0;
  final kept = [
    for (final e in set)
      if (sigma(e.wall) <= least + 1e-9) e,
  ]..sort((x, y) {
      final h = x.wall.value.compareTo(y.wall.value);
      if (h != 0) return h;
      final f = rank(x).compareTo(rank(y));
      if (f != 0) return f;
      final k = x.k.compareTo(y.k);
      if (k != 0) return k;
      return x.side.index.compareTo(y.side.index);
    });
  return kept.isEmpty ? null : kept.first;
}

/// The root-level group owning the entity [res] hit (no instance above it:
/// the premise `chainLength == 0` is the caller's).
Handle ownerOf(DraftDocument doc, SnapResult res) =>
    doc.entities.ownerAt(doc.entities.slotOf(res.entity)!);

/// One `snapInto` at world [raw] with the spike's 50 mm aperture and the
/// drag mask; null when nothing snaps.
SnapResult? snapAt(SpatialIndex index, Vector2 raw, {double aperture = 50}) {
  final res = SnapResult();
  index.snapInto(raw, aperture, kDragSnapMask, res);
  return res.found ? res : null;
}

/// Every stored world vertex of wall [h]'s children (its ring pieces and
/// centreline pieces), through its group's transform.
List<Vector2> storedVertices(DraftDocument doc, Handle h) => [
      for (final k in kids(doc, h)) ...worldPoints(doc, k),
    ];

/// The distance from [p] to the nearest of [ps].
double nearestOf(List<Vector2> ps, Vector2 p) =>
    ps.map((x) => (x - p).length).reduce(math.min);

/// [walls], then 900 mm doors `(host index, centre, swing)` from
/// [openings], each object one command at [place] as `buildPlan` lays them
/// out (a wall in its own group `groupFor(place, k)` when [Placement.groups],
/// a door at the identity), with the groups indexed in [hiddenWalls] and
/// [hiddenOpenings] added hidden (`GroupNode.visible` false: only a file
/// makes one, no command hides a group), and with [hiddenLayerZero] layer 0,
/// where every generated child lies, hidden first. Returns the document, the
/// walls and the doors.
(DraftDocument, List<Handle>, List<Handle>) hiddenPlan(
    List<W> walls, List<(int, double, SwingSide)> openings, Placement place,
    {Set<int> hiddenWalls = const {},
    Set<int> hiddenOpenings = const {},
    bool hiddenLayerZero = false}) {
  final doc = DraftDocument.empty();
  if (hiddenLayerZero) {
    final z = doc.tables.layers[ReservedHandles.layerZero]!;
    doc.tables.layers
      ..remove(z.handle)
      ..add(LayerRecord(
          handle: z.handle,
          name: z.name,
          color: z.color,
          linetype: z.linetype,
          lineweight: z.lineweight,
          transparency: z.transparency,
          visible: false,
          locked: z.locked));
  }
  installParametric(doc);
  ensureDashedLinetype(doc);
  final wh = <Handle>[], oh = <Handle>[];
  for (final (k, w) in walls.indexed) {
    final h = doc.handleSeed.next();
    final g = place.groups ? groupFor(place, k) : Transform2.identity();
    final inv = g.invert();
    final s = inv.transformPoint(place.at(w.sx, w.sy));
    final e = inv.transformPoint(place.at(w.ex, w.ey));
    doc.commands.execute(CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: h,
          parent: doc.rootHandle,
          transform: g,
          visible: !hiddenWalls.contains(k),
          children: const [])),
      SetComponentCommand<WallParams>(
          h, WallParams(s.x, s.y, e.x, e.y, w.t, w.j)),
    ], label: 'Add wall'));
    wh.add(h);
  }
  for (final (k, (i, centre, swing)) in openings.indexed) {
    final h = doc.handleSeed.next();
    doc.commands.execute(CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: h,
          parent: doc.rootHandle,
          transform: Transform2.identity(),
          visible: !hiddenOpenings.contains(k),
          children: const [])),
      SetComponentCommand<OpeningParams>(
          h, OpeningParams(wh[i], centre, 900, OpeningKind.door, swing: swing)),
    ], label: 'Add opening'));
    oh.add(h);
  }
  expect(driftOf(doc), isEmpty, reason: 'premise: generated');
  return (doc, wh, oh);
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

      // -- The outer corner again, in both handle orders (Task 3's review:
      // with B lower, a band as wide as the whole σ range still picks B by
      // handle, so only the A-lower order tells the band's width). The
      // aligned pair (4100, −100) to (3000, 3000): σ_B = 0.334, σ_A = 0.942
      // (above), so B/0/right whichever wall is lower; horizontal, σ_A = 0,
      // σ_B = 1, so A/1/right.
      for (final bFirst in const [true, false]) {
        const wb = W(4000, 0, 4000, 3000, 200), wa = W(0, 0, 4000, 0, 200);
        final (doc, hs) = docOfWalls(
            worldWalls(bFirst ? const [wb, wa] : const [wa, wb], place));
        final b = bFirst ? hs[0] : hs[1], a = bFirst ? hs[1] : hs[0];
        final lower = bFirst ? 'B' : 'A';
        final outer = place.at(4100, -100), far = place.at(3000, 3000);
        final co = bruteCandidates(doc, outer);
        expect(
            co,
            [AttachedEnd(b, 0, r), AttachedEnd(a, 1, r)]
              ..sort((x, y) => x.wall.value.compareTo(y.wall.value)),
            reason: 'premise ($lower lower): the outer corner is B/0/right '
                'and A/1/right');
        expect(
            decide(doc, co, DimKind.aligned, outer, far), AttachedEnd(b, 0, r),
            reason: 'aligned, $lower lower: σ_B 0.334 < σ_A 0.942');
        expect(decide(doc, co, DimKind.horizontal, outer, far),
            AttachedEnd(a, 1, r),
            reason: 'horizontal, $lower lower: σ_A 0 < σ_B 1');
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

  for (final place in const [origin, corpusGroups, km1000Groups]) {
    test(
        'AM1 every one of the sample plan\'s 60 wall end points, snapped '
        'through snapInto from 5 mm away, has the brute-force candidate set '
        'and decision 19\'s end, at $place', () {
      final plan = samplePlan(place);
      final doc = plan.doc;
      final index = SpatialIndex(doc);
      addTearDown(index.dispose);
      final thickest = thickestWall(doc);
      // T: the column, 400 thick, every group rigid.
      expect(thickest, closeTo(400, 1e-9), reason: 'premise: T = 400');
      expect(plan.walls, hasLength(10), reason: 'premise: ten walls');
      // The pointer 5 mm off each point, along (3, 4) / 5 in plan terms.
      final off = turnedBy(place, 3, 4) * (5 / 5);
      // Horizontal and vertical measure along the placement's x and y (the
      // dimension group at place.m).
      final ux = turnedBy(place, 1, 0), uy = turnedBy(place, 0, 1);
      final kinds = <SnapKind, int>{};
      var worst = 0.0, points = 0;
      for (final h in plan.walls) {
        final ws = wallsInDocument(doc, h)!;
        for (final (k, side, p) in wallEndPoints(ws.host, ws.walls)) {
          points++;
          final want = AttachedEnd(h, k, side);
          final res = snapAt(index, p + off);
          expect(res, isNotNull, reason: '$want: a snap');
          kinds[res!.kind] = (kinds[res.kind] ?? 0) + 1;
          final q = Vector2.copy(res.point);
          worst = math.max(worst, (q - p).length);
          final got = attachCandidates(doc, index, q,
              objectSnap: true, thickest: thickest);
          final brute = bruteCandidates(doc, q);
          expect(got, contains(want), reason: '$want snapped at $q');
          expect(got, brute, reason: '$want snapped at $q');
          for (final (kind, u) in [
            (DimKind.horizontal, ux),
            (DimKind.vertical, uy),
          ]) {
            expect(
                decideEnd(doc, got,
                    kind: kind, at: q, other: place.at(0, 0), m: place.m),
                rule19(doc, brute, u),
                reason: '$want, ${kind.name}');
          }
        }
      }
      expect(points, 60);
      // ignore: avoid_print
      print('AM1 $place: $points points; snap kinds $kinds; worst '
          '|snapped − computed| $worst mm');
    });
  }

  for (final place in const [origin, corpusGroups]) {
    test(
        'AM2 a jamb is fixed, a Y lobe vertex finds both walls\' points, '
        'a T butt corner is the stem\'s, an X crossing gives no candidate; '
        'a degenerate wall and a left-justified wall\'s points are found, at '
        '$place', () {
      List<AttachedEnd> through(
              DraftDocument doc, SpatialIndex index, Vector2 q) =>
          attachCandidates(doc, index, q,
              objectSnap: true, thickest: thickestWall(doc));

      // -- The front door's jamb on the sample plan. The door in E1
      // (position 6375, width 1000) cuts from 6375 − 500 = 5875 to 6875
      // along E1 from its start x = 12,125: x = 18,000 and 19,000; E1's
      // inner face y = 8,125 + 125 = 8,250. A jamb corner is none of the
      // six points: fixed.
      {
        final plan = samplePlan(place);
        final index = SpatialIndex(plan.doc);
        addTearDown(index.dispose);
        final jamb = plan.at(18000, 8250);
        final res = snapAt(index, jamb + turnedBy(place, 3, -2))!;
        expect((res.point - jamb).length, lessThan(1e-5),
            reason: 'premise: the jamb snaps');
        final q = Vector2.copy(res.point);
        expect(bruteCandidates(plan.doc, q), isEmpty,
            reason: 'premise: no attach point at the jamb');
        expect(through(plan.doc, index, q), isEmpty, reason: 'the jamb');
      }

      // -- C7's Y: A 0°, B 120°, C 240°, 200 each, out of (0, 0). The lobe
      // vertex between B and C is B's left face (offset +100 along B's left
      // normal) meeting C's right face: by symmetry on the x axis at
      // x = −100 / sin 60° = −200 / √3 = −115.470. It is on A's ring (A
      // owns the lobe), but it is B/0/left and C/0/right.
      {
        final plan = buildPlan(c7Walls, place: place);
        final [a, b, cw] = plan.walls;
        final index = SpatialIndex(plan.doc);
        addTearDown(index.dispose);
        final lobe = plan.at(-200 / math.sqrt(3), 0);
        final res = snapAt(index, lobe + turnedBy(place, 1, 1))!;
        expect((res.point - lobe).length, lessThan(1e-5),
            reason: 'premise: the lobe vertex snaps');
        expect(res.chainLength, 0);
        // The premise M-11ownerring needs: the snap reports one wall, one
        // root-level group, so its owner alone cannot give both walls'
        // points.
        final owner = ownerOf(plan.doc, res);
        expect([a, b, cw], contains(owner),
            reason: 'premise: the snap reports one wall');
        // ignore: avoid_print
        print('AM2 $place: the lobe vertex snaps ${res.kind.name} on '
            '${owner == a ? 'A' : owner == b ? 'B' : 'C'}\'s child');
        final q = Vector2.copy(res.point);
        final got = through(plan.doc, index, q);
        expect(got, [AttachedEnd(b, 0, l), AttachedEnd(cw, 0, r)],
            reason: 'the lobe vertex');
        expect(got, bruteCandidates(plan.doc, q));
      }

      // -- C5's T: the butt corner (2450, 100), S's left face x = 2,450 on
      // C's left face y = 100, is S/0/left only (not a vertex of C's ring).
      {
        final plan = buildPlan(c5Walls, place: place);
        final s = plan.walls[1];
        final index = SpatialIndex(plan.doc);
        addTearDown(index.dispose);
        final butt = plan.at(2450, 100);
        final res = snapAt(index, butt + turnedBy(place, -2, 3))!;
        expect((res.point - butt).length, lessThan(1e-5),
            reason: 'premise: the butt corner snaps');
        final q = Vector2.copy(res.point);
        final got = through(plan.doc, index, q);
        expect(got, [AttachedEnd(s, 0, l)], reason: 'the T butt corner');
        expect(got, bruteCandidates(plan.doc, q));
      }

      // -- C6's X: A's left face y = 100 crosses B's left face x = 1,900
      // (B runs north, left normal −x). No vertex of either wall is there.
      // The engine's intersection snap finds the crossing at every
      // placement: it maps a root-level group's pieces to world before
      // intersecting them (post-11 found item (a); before that fix it read
      // stored coordinates as world and found nothing in own groups). The
      // point it reports is the crossing within rounding -- exactly q at
      // the origin, 1.2e-9 off it at the far turned placement -- so the
      // premise is an intersection within 1e-5 of the crossing. Neither
      // the crossing nor the resolved point matches an attach point: fixed.
      {
        final plan = buildPlan(c6Walls, place: place);
        final index = SpatialIndex(plan.doc);
        addTearDown(index.dispose);
        final q = plan.at(1900, 100);
        final res = snapAt(index, q);
        expect(
            res != null &&
                res.kind == SnapKind.intersection &&
                (res.point - q).length < 1e-5,
            isTrue,
            reason: 'premise: an intersection at the crossing '
                '(${res?.kind} ${res?.point}, q $q)');
        expect(bruteCandidates(plan.doc, q), isEmpty,
            reason: 'premise: no attach point at the crossing');
        expect(through(plan.doc, index, q), isEmpty, reason: 'the crossing');
        final resolved = Vector2.copy(res!.point);
        expect(bruteCandidates(plan.doc, resolved), isEmpty,
            reason: 'premise: no attach point at the resolved point');
        expect(through(plan.doc, index, resolved), isEmpty,
            reason: 'the resolved point');
      }

      // -- C10's degenerate walls: the zero-length wall at (0, 1000) and
      // the 5e-7 mm wall at (0, 2000). Each has no outline; all six of its
      // points are its centreline ends, which lie within 5e-7 of each
      // other, so at its start all six are candidates.
      {
        final plan = buildPlan(c10Walls, place: place);
        final index = SpatialIndex(plan.doc);
        addTearDown(index.dispose);
        for (final (i, y) in const [(1, 1000.0), (2, 2000.0)]) {
          final d = plan.walls[i];
          final q = plan.at(0, y);
          final got = through(plan.doc, index, q);
          expect(
              got,
              [
                for (final k in const [0, 1])
                  for (final side in WallSide.values) AttachedEnd(d, k, side),
              ],
              reason: 'the degenerate wall at y $y');
          expect(got, bruteCandidates(plan.doc, q));
        }
      }

      // -- 10's JM: A (0, 0) -> (6000, 0) 200 left-justified (faces at
      // offsets (200, 0): its right face is its centreline), B 100
      // right-justified, C 300 centred, D 250 right-justified drawn upwards.
      // Every one of the 24 attach points, taken exactly, has brute force's
      // candidate set through the index, and contains its own end: so the
      // line test keeps A's left face at offset +200.
      {
        final plan = buildPlan(jmWalls, place: place);
        final doc = plan.doc;
        final index = SpatialIndex(doc);
        addTearDown(index.dispose);
        expect(jmWalls[0].j, Justification.left,
            reason: 'premise: A is left-justified');
        var n = 0;
        for (final h in plan.walls) {
          final ws = wallsInDocument(doc, h)!;
          for (final (k, side, p) in wallEndPoints(ws.host, ws.walls)) {
            n++;
            final want = AttachedEnd(h, k, side);
            final got = through(doc, index, p);
            expect(got, contains(want), reason: 'JM $want at $p');
            expect(got, bruteCandidates(doc, p), reason: 'JM $want at $p');
          }
        }
        expect(n, 24);
      }
    });
  }

  test(
      'AM2 a wall group scaled 1.5 (C11, at its own far placement) has its '
      'free rectangle\'s corners found by the local-frame line test', () {
    // -- C11 in groups scaled 1.5, turned 143° about the hub (file only;
    // AP2's variant). A runs east from far(−2500, 678.25) into the hub
    // far(1234.5, 678.25), right-justified: its left face is the
    // centreline y = 678.25 and, stored 200 thick in a group scaled 1.5,
    // its free rectangle's right face lies 300 below in world, y =
    // 378.25. 07 stores that rectangle in local space (the local-ring
    // fallback), so A/0/right and A/1/right lie on no world line at A's
    // stored offsets (0, −200): only the local-frame line test finds
    // them.
    {
      final (doc, hs) = docOfWalls(scaledGroups(c11(turn: 143)));
      final a = hs[0];
      final index = SpatialIndex(doc);
      addTearDown(index.dispose);
      expect(
          doc.tree.accumulatedTransform(a).scaleMagnitude, closeTo(1.5, 1e-12),
          reason: 'premise: A\'s group is scaled');
      expect([
        for (final d in diagnosticsOf(doc))
          if (d.code == 'wall.fallback') d.handles
      ], anyElement(equals([a])),
          reason: 'premise: A takes the local-ring fallback');
      final g = turnedAbout(c11Hub, 143);
      final corners = {
        (0, l): g.transformPoint(far(-2500, 678.25)),
        (0, r): g.transformPoint(far(-2500, 378.25)),
        (1, l): g.transformPoint(far(1234.5, 678.25)),
        (1, r): g.transformPoint(far(1234.5, 378.25)),
      };
      for (final MapEntry(key: (k, side), value: q) in corners.entries) {
        final got = attachCandidates(doc, index, q,
            objectSnap: true, thickest: thickestWall(doc));
        expect(got, contains(AttachedEnd(a, k, side)),
            reason: 'C11 scaled A/$k/${side.name}');
        expect(got, bruteCandidates(doc, q),
            reason: 'C11 scaled A/$k/${side.name}');
      }
    }
  });

  for (final place in const [origin, corpusGroups]) {
    test(
        'AM4 decision 23: a grid point on the sample\'s outer corner '
        'attaches with F3 on and stays fixed with F3 off, at $place', () {
      final plan = samplePlan(place);
      final doc = plan.doc;
      final index = SpatialIndex(doc);
      addTearDown(index.dispose);
      final thickest = thickestWall(doc);
      // The outer corner (12,000, 8,000): E1's right face (y 8,125 − 125)
      // meets E4's right face (x 12,125 − 125). A fixed 500 mm grid whose
      // origin is the corner's world point, so the corner is a grid node at
      // every placement (the grid is laid in world axes from the origin).
      final corner = plan.at(12000, 8000);
      final page = PageComponent(
          originX: corner.x,
          originY: corner.y,
          gridStepMm: 500,
          snapToGrid: true);
      // The camera at 0.052 px/mm: the 10 px aperture is 10 / 0.052 =
      // 192.3 mm.
      const pxPerMm = 0.052;
      const aperture = kSnapAperturePixels / pxPerMm;
      expect(aperture, closeTo(192.3, 0.05));
      expect(dragGridStepMm(page, pxPerMm), 500);
      // The pointer (−170, −170) from the corner in the placement's frame:
      // |·| = 170 √2 = 240.4 mm, beyond the aperture; turned 23° it is
      // (−90.1, −222.9) in world, within 250 of the corner on both axes,
      // so it rounds to the corner on the 500 mm grid.
      final raw = corner + turnedBy(place, -170, -170);
      expect((raw - corner).length, closeTo(240.4, 0.05));
      expect(snapAt(index, raw, aperture: aperture), isNull,
          reason: 'premise: no snap point within the aperture');
      DragPoint resolve(bool objectSnap) {
        final out = DragPoint();
        resolveDragPoint(
            raw: raw,
            orthoBase: null,
            index: index,
            apertureWorld: aperture,
            objectSnap: objectSnap,
            page: page,
            gridStepMm: 500,
            scratch: SnapResult(),
            out: out);
        return out;
      }

      final [e1, _, _, e4, ...] = plan.walls;
      // F3 on: the grid resolves the pointer onto the corner, exactly, and
      // the corner attaches: E1/0/right and E4/1/right (E4 runs south, so
      // its right face is its west face x = 12,000), and a horizontal
      // dimension (u along E1: σ_E1 = 0, σ_E4 = 1) stores E1/0/right.
      final on = resolve(true);
      expect(on.objectKind, isNull, reason: 'premise: no object snap');
      expect(on.grid, isTrue, reason: 'premise: the grid');
      expect([on.point.x, on.point.y], [corner.x, corner.y],
          reason: 'premise: exactly the corner');
      final got = attachCandidates(doc, index, on.point,
          objectSnap: true, thickest: thickest);
      expect(got, [AttachedEnd(e1, 0, r), AttachedEnd(e4, 1, r)],
          reason: 'F3 on: the grid point attaches');
      expect(
          decideEnd(doc, got,
              kind: DimKind.horizontal,
              at: on.point,
              other: plan.at(15000, 8000),
              m: place.m),
          AttachedEnd(e1, 0, r),
          reason: 'horizontal: E1/0/right');
      // F3 off: the same grid point, and no candidate: the end is fixed.
      final off = resolve(false);
      expect(off.grid, isTrue);
      expect([off.point.x, off.point.y], [corner.x, corner.y]);
      expect(
          attachCandidates(doc, index, off.point,
              objectSnap: false, thickest: thickest),
          isEmpty,
          reason: 'F3 off: fixed');
    });
  }

  test('AM5 the attach search per click among 600 walls, printed', () {
    // 17 × 17 cells: 2 · 17 · 17 + 17 + 17 = 612 walls, the grid nearest
    // 600 (10's RK2).
    final walls = dimGridWalls(17, 17);
    expect(walls, hasLength(612));
    final plan = buildPlan(walls);
    final doc = plan.doc;
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    // A corner of the + node at (9,000, 9,000), four 200 mm walls: the
    // east wall's left face y = 9,100 meets the north wall's right face
    // x = 9,100.
    final q = plan.at(9100, 9100);
    final thickest = thickestWall(doc);
    List<AttachedEnd> once() =>
        attachCandidates(doc, index, q, objectSnap: true, thickest: thickest);
    expect(once(), isNotEmpty, reason: 'premise: the corner attaches');
    for (var i = 0; i < 20; i++) {
      once();
    }
    final runs = <double>[];
    for (var i = 0; i < 5; i++) {
      final sw = Stopwatch()..start();
      once();
      sw.stop();
      runs.add(sw.elapsedMicroseconds.toDouble());
    }
    final passes = debugLineTestPasses;
    final got = once();
    final passed = debugLineTestPasses - passes;
    final sw = Stopwatch()..start();
    thickestWall(doc);
    sw.stop();
    runs.sort();
    // ignore: avoid_print
    print('AM5 attach search per click, ${walls.length} walls: median '
        '${runs[2]} us of $runs (JIT); candidates $got, $passed walls '
        'past the line test; '
        'thickestWall ${sw.elapsedMicroseconds} us');
  });

  for (final place in placements) {
    test(
        'AM6 a door flush with a wall end leaves none of the end\'s three '
        'points stored, and each still attaches by position, and through the '
        'jamb\'s snap, at $place', () {
      // (name, plan, the host's index, the end's three points by hand).
      // The T: S/0/left is S's left face x = 2,500 − 50 on C's face y = 100,
      // S/0/right x = 2,550 there, S/0/centre S's start (2,500, 0) on C's
      // centreline. The free wall A: its start's faces y = ±100 and its
      // centreline end (0, 0).
      final cases = [
        for (final cut in const [450.0, 550.0])
          for (final swing in SwingSide.values)
            (
              'T c=$cut swing ${swing.name}',
              flushT(place, c: cut, swing: swing),
              1,
              swing,
              const {l: (2450.0, 100.0), c: (2500.0, 0.0), r: (2550.0, 100.0)},
            ),
        for (final swing in SwingSide.values)
          (
            'free swing ${swing.name}',
            flushFree(place, swing: swing),
            0,
            swing,
            const {l: (0.0, 100.0), c: (0.0, 0.0), r: (0.0, -100.0)},
          ),
      ];
      for (final (name, plan, i, swing, points) in cases) {
        final doc = plan.doc;
        final host = plan.walls[i];
        final door = plan.openings.single;
        final index = SpatialIndex(doc);
        addTearDown(index.dispose);
        final thickest = thickestWall(doc);
        expect(thickest, closeTo(200, 1e-9), reason: '$name: T');
        // Premise (the review's run): none of the end's three points is a
        // vertex of the host's stored children.
        final stored = storedVertices(doc, host);
        for (final MapEntry(key: side, value: (x, y)) in points.entries) {
          expect(nearestOf(stored, plan.at(x, y)), greaterThan(1),
              reason: '$name: ${side.name} is not stored');
        }
        // By position: each point attaches, and the set is brute force's.
        for (final MapEntry(key: side, value: (x, y)) in points.entries) {
          final q = plan.at(x, y);
          final got = attachCandidates(doc, index, q,
              objectSnap: true, thickest: thickest);
          expect(got, contains(AttachedEnd(host, 0, side)),
              reason: '$name: 0/${side.name} by position');
          expect(got, bruteCandidates(doc, q), reason: '$name: 0/${side.name}');
        }
        // Through the jamb's snap: the swing face's corner is the door's
        // jamb corner, and the door's own snap puts the click there.
        final face = swing == SwingSide.left ? l : r;
        final (jx, jy) = points[face]!;
        final jamb = plan.at(jx, jy);
        final res = snapAt(index, jamb + turnedBy(place, 3, 4))!;
        expect((res.point - jamb).length, lessThan(1e-5),
            reason: '$name: premise: the jamb corner snaps');
        expect(res.chainLength, 0);
        expect(ownerOf(doc, res), door,
            reason: '$name: premise: the door\'s own snap');
        expect(
            attachCandidates(doc, index, Vector2.copy(res.point),
                objectSnap: true, thickest: thickest),
            contains(AttachedEnd(host, 0, face)),
            reason: '$name: through the jamb\'s snap');
      }

      // -- The free wall in a group scaled 1.5 (file only): T is A's world
      // thickness 200 × 1.5 = 300, not its stored 200. 08 lays the cut out
      // in A's frame, so the door's jamb stands on the drawn swing face
      // 150 off the centreline (100 × 1.5), while A/0's three points are
      // 07's world caps at the stored offsets ±100 and 0. The far face's
      // corner lies 150 + 100 = 250 from the door's children: inside the box
      // grown by 300, outside one grown by 200.
      for (final swing in SwingSide.values) {
        final name = 'free scaled 1.5 swing ${swing.name}';
        final (doc, host, _) = flushFreeScaled(place, swing: swing);
        final index = SpatialIndex(doc);
        addTearDown(index.dispose);
        final thickest = thickestWall(doc);
        final stored = storedVertices(doc, host);
        for (final (side, (x, y)) in const [
          (l, (0.0, 100.0)),
          (c, (0.0, 0.0)),
          (r, (0.0, -100.0)),
        ]) {
          final q = place.at(x, y);
          expect(nearestOf(stored, q), greaterThan(1),
              reason: '$name: ${side.name} is not stored');
          final got = attachCandidates(doc, index, q,
              objectSnap: true, thickest: thickest);
          expect(got, contains(AttachedEnd(host, 0, side)),
              reason: '$name: 0/${side.name} by position');
          expect(got, bruteCandidates(doc, q), reason: '$name: 0/${side.name}');
        }
        expect(thickest, closeTo(300, 1e-9), reason: '$name: T');
      }
    });
  }

  for (final place in const [origin, corpusGroups]) {
    test(
        'AM6b only a drawn wall attaches: a hidden wall neither by its own '
        'children nor as the host of a visible flush door; a hidden door '
        'makes its host no candidate; a hidden layer 0 hides every wall, at '
        '$place', () {
      // Against the brute-force oracle, which knows no visibility: each
      // hidden point is a candidate there (the premise), and the index
      // leaves out exactly the hidden wall's (D10: the queries take
      // `rendering()`, what is drawn).
      List<AttachedEnd> got(DraftDocument doc, SpatialIndex index, Vector2 q) =>
          attachCandidates(doc, index, q,
              objectSnap: true, thickest: thickestWall(doc));

      // -- P1: the L (C2), A (0, 0) → (4000, 0) drawn, B (4000, 0) →
      // (4000, 3000) hidden, both 200 centred. The outer corner (4100,
      // −100) is A/1/right and B/0/right; B's far end (4000, 3000) its
      // centre, (4100, 3000) its right face, (3900, 3000) its left.
      {
        final (doc, [a, b], _) =
            hiddenPlan(c2Walls, const [], place, hiddenWalls: {1});
        final index = SpatialIndex(doc);
        addTearDown(index.dispose);
        final corner = place.at(4100, -100);
        expect(bruteCandidates(doc, corner),
            [AttachedEnd(a, 1, r), AttachedEnd(b, 0, r)],
            reason: 'premise: B\'s corner is a point');
        expect(got(doc, index, corner), [AttachedEnd(a, 1, r)],
            reason: 'P1: the shared corner is A\'s alone');
        for (final (side, x) in const [(c, 4000.0), (r, 4100.0), (l, 3900.0)]) {
          final q = place.at(x, 3000);
          expect(bruteCandidates(doc, q), [AttachedEnd(b, 1, side)],
              reason: 'premise: B/1/${side.name}');
          expect(got(doc, index, q), isEmpty,
              reason: 'P1: hidden B/1/${side.name} does not attach');
        }
      }

      // -- P2 and P3: spike C5's T with a 900 mm door flush with the
      // stem's butt end (flushT's c = 450): C (0, 0) → (6000, 0), 200, S
      // (2500, 0) → (2500, 3000), 100. S/0/left (2450, 100), S/0/centre
      // (2500, 0), S/0/right (2550, 100); none is stored on S (AM6), so
      // only the opening-host query reaches them.
      const ends = {l: (2450.0, 100.0), c: (2500.0, 0.0), r: (2550.0, 100.0)};
      for (final swing in SwingSide.values) {
        for (final (name, hiddenS, hiddenDoor) in const [
          ('P2 S hidden, its door drawn', true, false),
          ('P3 S drawn, its door hidden', false, true),
          ('control, both drawn', false, false),
        ]) {
          final (doc, [_, s], _) = hiddenPlan(
              c5Walls, [(1, 450.0, swing)], place,
              hiddenWalls: {if (hiddenS) 1},
              hiddenOpenings: {if (hiddenDoor) 0});
          final index = SpatialIndex(doc);
          addTearDown(index.dispose);
          for (final MapEntry(key: side, value: (x, y)) in ends.entries) {
            final q = place.at(x, y);
            final tag = '$name, swing ${swing.name}, S/0/${side.name}';
            expect(bruteCandidates(doc, q), [AttachedEnd(s, 0, side)],
                reason: 'premise: $tag is a point');
            expect(got(doc, index, q),
                hiddenS || hiddenDoor ? isEmpty : [AttachedEnd(s, 0, side)],
                reason: tag);
          }
        }
      }

      // -- A hidden layer 0: every generated child, the walls' and the
      // door's, lies on it, so nothing is drawn and nothing attaches.
      {
        final (doc, _, _) = hiddenPlan(
            c5Walls, [(1, 450.0, SwingSide.left)], place,
            hiddenLayerZero: true);
        final index = SpatialIndex(doc);
        addTearDown(index.dispose);
        for (final (x, y) in const [
          (2450.0, 100.0),
          (2500.0, 0.0),
          (0.0, 100.0)
        ]) {
          final q = place.at(x, y);
          expect(bruteCandidates(doc, q), isNotEmpty,
              reason: 'premise: ($x, $y) is a point of C or S');
          expect(got(doc, index, q), isEmpty,
              reason: 'layer 0 hidden: ($x, $y) does not attach');
        }
      }
    });
  }
}
