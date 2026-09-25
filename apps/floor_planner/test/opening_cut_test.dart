// Spec 08 D9: a wall cut at its openings — its band split into pieces, its
// centreline split with it, the cap-vertex snap — through the real
// ParametricSystem. Every wall is at the far origin in its own rotated group
// (`groupAt`), no host is axis-aligned, and no opening is central. Expected
// coordinates come from `support/opening_fixture.dart`'s oracles, which
// never call `opening_geometry.dart`; the tiling oracle's band is what 07
// stores for the same wall in a twin document with every opening deleted.
import 'dart:math' as math;

import 'package:floor_planner/parametric/opening.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/opening_fixture.dart';
import 'support/wall_fixture.dart';

const centre = Justification.centre;
const left = Justification.left;
const right = Justification.right;

const hA = Handle(1300), hB = Handle(2600);
const hD = Handle(4000), hW = Handle(4100), hG = Handle(4200);

const Map<String, int> noViolations = {
  'overlap': 0,
  'hole': 0,
  'pieceInGap': 0,
  'pieceOutside': 0,
  'gapOutside': 0,
};

/// Executes [c] and checks the differential oracle: nothing drifts.
void run(DraftDocument doc, DraftCommand c) {
  doc.commands.execute(c);
  expect(driftOf(doc), isEmpty, reason: 'drift after ${c.label}');
}

/// OG1's wall: 5,000 mm, 200 left-justified, drawn with `plan()` at 23° in
/// its own group at the far origin, and a door at 1,400 (900), hinged at
/// the end and swinging right: non-central, its gap `[950, 1850]`.
DraftDocument doorWall() {
  final doc = wallDoc();
  run(doc, addWall(doc, hA, plan(-2500, 0), plan(2500, 0), 200, left));
  run(
      doc,
      addOpening(
          doc,
          hD,
          const OpeningParams(hA, 1400, 900, OpeningKind.door,
              hinge: HingeEnd.end, swing: SwingSide.right)));
  return doc;
}

/// The `u` of every point of [ring] in [f].
List<double> usOf(OracleFrame f, List<Vector2> ring) =>
    [for (final q in ring) oracleU(f, q)];

/// Whether [ring] has a vertex within 1e-6 of [p].
bool hasVertex(List<Vector2> ring, Vector2 p) => nearestIn(ring, p) < 1e-6;

/// The 67° L of spike Q3a at justifications [ja]/[jb]: A 200 into the node,
/// B 115 out of it; a door in A at 900 (800), a window in B at 1,700
/// (1,000), and a door in A stored at 2,950 (700), past the node, so drawn
/// clamped at A's mitre.
DraftDocument lPlan(Justification ja, Justification jb) {
  final doc = wallDoc();
  final hub = plan(0, 0);
  run(doc, addWall(doc, hA, plan(-3000, 0), hub, 200, ja));
  run(doc, addWall(doc, hB, hub, polar(hub, 180 - 67 + 23, 2500), 115, jb));
  run(doc,
      addOpening(doc, hD, const OpeningParams(hA, 900, 800, OpeningKind.door)));
  run(
      doc,
      addOpening(
          doc, hW, const OpeningParams(hB, 1700, 1000, OpeningKind.window)));
  run(
      doc,
      addOpening(
          doc, hG, const OpeningParams(hA, 2950, 700, OpeningKind.door)));
  return doc;
}

void main() {
  test(
      'OG1 one cut, both faces, by coordinates: a door at 1,400 in a 5,000 '
      'wall at 23° gives two pieces whose gap corners are the oracle\'s; a '
      'window at 3,600 gives three; a gap clamped against the free start cap '
      'drops the start piece; the tiling gives 0 each time', () {
    final doc = doorWall();
    final f = oracleFrameOf(doc, hA);
    expect(f.len, closeTo(5000, 1e-6));
    // Not degenerate: the door is 1,100 off the wall's middle.
    expect((1400 - f.len / 2).abs(), greaterThan(1000));
    final oracle = OpeningOracle(doc);
    final cut = oracle.cut(doc.components.get<OpeningParams>(hD)!)!;
    expect(cut.a, closeTo(950, 1e-9));
    expect(cut.b, closeTo(1850, 1e-9));
    expect(cut.clamped, isFalse);

    final pieces = worldPieces(doc, hA);
    expect(pieces, hasLength(2));
    final [start, end] = pieces;
    for (final (name, p) in [
      ('R(a)', oracleAt(f, 950, f.ro)),
      ('L(a)', oracleAt(f, 950, f.lo)),
    ]) {
      expect(hasVertex(start, p), isTrue, reason: 'start piece: $name');
    }
    for (final (name, p) in [
      ('L(b)', oracleAt(f, 1850, f.lo)),
      ('R(b)', oracleAt(f, 1850, f.ro)),
    ]) {
      expect(hasVertex(end, p), isTrue, reason: 'end piece: $name');
    }
    // Nothing of either piece lies in the gap.
    expect(usOf(f, start).reduce(math.max), lessThan(950 + 1e-6));
    expect(usOf(f, end).reduce(math.min), greaterThan(1850 - 1e-6));
    expect(oracle.tilingOf(hA), noViolations);
    expect(storedPiecesTriangulate(doc, hA), isTrue);

    // A window at 3,600 (1,200): gaps [950, 1850] and [3000, 4200].
    run(
        doc,
        addOpening(
            doc, hW, const OpeningParams(hA, 3600, 1200, OpeningKind.window)));
    final three = worldPieces(doc, hA);
    expect(three, hasLength(3));
    expect(
        isRectNear(three[1], [
          oracleAt(f, 3000, f.ro),
          oracleAt(f, 3000, f.lo),
          oracleAt(f, 1850, f.lo),
          oracleAt(f, 1850, f.ro),
        ]),
        isTrue,
        reason: 'the middle piece is [1850, 3000] face to face');
    expect(hasVertex(three[2], oracleAt(f, 4200, f.lo)), isTrue);
    expect(hasVertex(three[2], oracleAt(f, 4200, f.ro)), isTrue);
    expect(OpeningOracle(doc).gaps(hA).length, 2);
    expect(OpeningOracle(doc).tilingOf(hA), noViolations);
    expect(storedPiecesTriangulate(doc, hA), isTrue);

    // A gap stored at 300 (1,000) on a 4,000 wall: [−200, 800], clamped
    // against the free start cap to [0, 1000]; the start piece is no longer
    // than the tolerance and is dropped.
    run(doc, addWall(doc, hB, plan(-2000, 1800), plan(2000, 1800), 200, left));
    run(
        doc,
        addOpening(
            doc, hG, const OpeningParams(hB, 300, 1000, OpeningKind.gap)));
    final g = oracleFrameOf(doc, hB);
    final gc = OpeningOracle(doc).cut(doc.components.get<OpeningParams>(hG)!)!;
    expect(gc.clamped, isTrue);
    expect(gc.a, closeTo(0, 1e-6));
    final one = worldPieces(doc, hB);
    expect(one, hasLength(1), reason: 'the start piece is dropped');
    expect(hasVertex(one.single, oracleAt(g, 1000, g.lo)), isTrue);
    expect(hasVertex(one.single, oracleAt(g, 1000, g.ro)), isTrue);
    expect(usOf(g, one.single).reduce(math.min), greaterThan(1000 - 1e-6));
    expect(worldCentrelines(doc, hB), hasLength(1));
    expect(OpeningOracle(doc).tilingOf(hB), noViolations);
    expect(storedPiecesTriangulate(doc, hB), isTrue);
  });

  test(
      'OG2 the 67° L (A 200, B 115), all nine justification pairs: two '
      'openings in A, one stored past the node and clamped at the mitre, one '
      'in B: 0 tiling violations, every piece triangulates, three pieces and '
      'two', () {
    for (final ja in Justification.values) {
      for (final jb in Justification.values) {
        final why = '${ja.name}/${jb.name}';
        final doc = lPlan(ja, jb);
        final oracle = OpeningOracle(doc);
        final fa = oracleFrameOf(doc, hA);
        // The clamp is at the mitre, well short of the node: clamping into
        // [0, L] instead would draw the cut into the corner cap (M-08s).
        // Only right/right has its inner corner at the node itself: both
        // left faces are the centrelines there.
        final (_, uE) = oracle.span(hA);
        if (ja == right && jb == right) {
          expect((fa.len - uE).abs(), lessThan(1e-6), reason: why);
        } else {
          expect(fa.len - uE, greaterThan(10), reason: why);
        }
        final clamped = oracle.cut(doc.components.get<OpeningParams>(hG)!)!;
        expect(clamped.clamped, isTrue, reason: why);
        expect(clamped.b, uE, reason: why);
        final pa = worldPieces(doc, hA);
        expect(pa, hasLength(3), reason: why);
        // The end piece is the corner: nothing of it lies before uE.
        expect(usOf(fa, pa[2]).reduce(math.min), greaterThan(uE - 1e-6),
            reason: why);
        expect(hasVertex(pa[1], oracleAt(fa, clamped.a, fa.lo)), isTrue,
            reason: why);
        expect(hasVertex(pa[1], oracleAt(fa, clamped.a, fa.ro)), isTrue,
            reason: why);
        expect(worldPieces(doc, hB), hasLength(2), reason: why);
        for (final w in [hA, hB]) {
          expect(oracle.tilingOf(w), noViolations, reason: '$why $w');
          expect(storedPiecesTriangulate(doc, w), isTrue, reason: '$why $w');
        }
      }
    }
  });

  test(
      'OG8 the split centreline: one open two-point polyline per piece, at '
      '[0, a₀] and [b₀, L]; none enters the gap; a pick in the doorway on '
      'the centreline misses the wall, the same pick in a piece hits it', () {
    final doc = doorWall();
    final f = oracleFrameOf(doc, hA);
    final lines = centrelineHandles(doc, hA);
    expect(lines, hasLength(worldPieces(doc, hA).length));
    expect(lines, hasLength(2));
    for (final k in lines) {
      final c = payloadOf(doc, k).coords;
      expect(c, hasLength(4), reason: 'two points, open');
      expect(c[0] == c[2] && c[1] == c[3], isFalse);
    }
    final [first, second] = worldCentrelines(doc, hA);
    expect((first[0] - f.s).length, lessThan(1e-6));
    expect((first[1] - oracleAt(f, 950, 0)).length, lessThan(1e-6));
    expect((second[0] - oracleAt(f, 1850, 0)).length, lessThan(1e-6));
    expect((second[1] - oracleEnd(f, 1)).length, lessThan(1e-6));
    for (final line in [first, second]) {
      final us = usOf(f, line);
      for (final u in us) {
        expect(u > 950 + 1e-6 && u < 1850 - 1e-6, isFalse, reason: '$u');
      }
      // Nor does a segment cross it.
      expect(
          us.every((u) => u <= 950 + 1e-6) || us.every((u) => u >= 1850 - 1e-6),
          isTrue,
          reason: '$us');
    }

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    Handle? pick(Vector2 p) {
      final hit = HitPath();
      if (!index.pickInto(p, 20, const QueryFilter.picking(), hit)) {
        return null;
      }
      return resolveHit(hit, doc)?.target;
    }

    // The door is a childless group until Task 6: nothing else lies there.
    expect(pick(oracleAt(f, 1400, 0)), isNot(hA), reason: 'the doorway');
    expect(pick(oracleAt(f, 850, 0)), hA, reason: 'control: in the piece');
  });

  test(
      'OG9 the random property run: 2–4-way nodes, a T stem and an X '
      'crossing wall, 0–3 openings per wall, every wall in its own rotated '
      'group at the far origin: 0 refused, 0 tiling violations, drift() '
      'empty, every stored piece triangulates', () {
    final sw = Stopwatch()..start();
    final rnd = math.Random(808);
    var walls = 0, openings = 0, pieces = 0, clamped = 0, nofit = 0;
    var overlapping = 0, refused = 0, bad = 0, untriangulated = 0;
    var tees = 0, crossings = 0, obstacles = 0;
    final failures = <String>[];
    for (var trial = 0; trial < 300; trial++) {
      final doc = wallDoc();
      bool attempt(DraftCommand c) {
        try {
          doc.commands.execute(c);
          return true;
        } on ArgumentError {
          refused++;
          failures.add('trial $trial: ${c.label} refused');
          return false;
        }
      }

      final hub = plan(rnd.nextDouble() * 5000, rnd.nextDouble() * 5000);
      final n = 2 + rnd.nextInt(3);
      final hs = <Handle>[];
      var deg = rnd.nextDouble() * 360;
      for (var i = 0; i < n; i++) {
        final h = Handle(1000 + 100 * i);
        final t = [115.0, 150.0, 200.0, 300.0][rnd.nextInt(4)];
        final j = Justification.values[rnd.nextInt(3)];
        final len = 800 + rnd.nextDouble() * 3000;
        final tip = polar(hub, deg, len);
        if (attempt(rnd.nextBool()
            ? addWall(doc, h, hub, tip, t, j)
            : addWall(doc, h, tip, hub, t, j))) {
          hs.add(h);
        }
        deg += 50 + rnd.nextDouble() * (300 / n);
      }

      // One T stem and one X crossing wall, each inside a random wall's
      // straight part (read off 07's stored outline by the oracle).
      final plain = OpeningOracle(doc);
      Vector2? inside(Handle w) {
        final (s, e) = plain.span(w);
        if (e - s < 400) return null;
        final u = s + 200 + rnd.nextDouble() * (e - s - 400);
        return oracleAt(oracleFrameOf(doc, w), u, 0);
      }

      double dirOf(Handle w) {
        final d = oracleFrameOf(doc, w).d;
        return math.atan2(d.y, d.x) * 180 / math.pi;
      }

      final extra = <Handle>[];
      final tw = hs[rnd.nextInt(hs.length)];
      if (inside(tw) case final p?) {
        const h = Handle(1500);
        final a = dirOf(tw) +
            (rnd.nextBool() ? 1 : -1) * (35 + rnd.nextDouble() * 110);
        final t = [115.0, 150.0, 200.0][rnd.nextInt(3)];
        final j = Justification.values[rnd.nextInt(3)];
        final far = polar(p, a, 800 + rnd.nextDouble() * 2000);
        if (attempt(rnd.nextBool()
            ? addWall(doc, h, p, far, t, j)
            : addWall(doc, h, far, p, t, j))) {
          extra.add(h);
          tees++;
        }
      }
      final xw = hs[rnd.nextInt(hs.length)];
      if (inside(xw) case final c?) {
        const h = Handle(1600);
        final a = dirOf(xw) + 35 + rnd.nextDouble() * 110;
        final t = [115.0, 150.0, 200.0][rnd.nextInt(3)];
        final j = Justification.values[rnd.nextInt(3)];
        if (attempt(addWall(
            doc,
            h,
            polar(c, a + 180, 400 + rnd.nextDouble() * 1500),
            polar(c, a, 400 + rnd.nextDouble() * 1500),
            t,
            j))) {
          extra.add(h);
          crossings++;
        }
      }

      final all = [...hs, ...extra];
      var oh = 5000;
      for (final h in all) {
        final len = oracleFrameOf(doc, h).len;
        for (var k = rnd.nextInt(4); k > 0; k--) {
          final o = OpeningParams(h, rnd.nextDouble() * len,
              300 + rnd.nextDouble() * 1200, OpeningKind.values[rnd.nextInt(3)],
              hinge: HingeEnd.values[rnd.nextInt(2)],
              swing: SwingSide.values[rnd.nextInt(2)]);
          if (attempt(addOpening(doc, Handle(oh += 10), o))) openings++;
        }
      }
      expect(driftOf(doc), isEmpty, reason: 'trial $trial');

      final oracle = OpeningOracle(doc);
      for (final h in all) {
        walls++;
        pieces += worldPieces(doc, h).length;
        obstacles += oracle.obstacles(h).length;
        final v = violations(oracle.tilingOf(h));
        if (v > 0) failures.add('trial $trial wall ${h.value}: $v violations');
        bad += v;
        if (!storedPiecesTriangulate(doc, h)) {
          untriangulated++;
          failures.add('trial $trial wall ${h.value}: a piece fails');
        }
        final cuts = [
          for (final o in oracle.openingsOn(h))
            oracle.cut(doc.components.get<OpeningParams>(o)!)
        ];
        for (final c in cuts) {
          if (c == null) {
            nofit++;
          } else if (c.clamped) {
            clamped++;
          }
        }
        final fit = [
          for (final c in cuts)
            if (c != null) c
        ];
        for (var i = 0; i < fit.length; i++) {
          for (var j = i + 1; j < fit.length; j++) {
            if (fit[i].a < fit[j].b - 1e-6 && fit[j].a < fit[i].b - 1e-6) {
              overlapping++;
            }
          }
        }
      }
    }
    // ignore: avoid_print
    print('OG9: $walls walls ($tees T stems, $crossings X walls, '
        '$obstacles obstacles), '
        '$openings openings ($refused refused), $pieces pieces, $clamped '
        'clamped, $nofit no-fit, $overlapping overlapping pairs, $bad tiling '
        'violations, $untriangulated walls with a piece that does not '
        'triangulate, ${sw.elapsedMilliseconds} ms');
    final first = failures.take(10).join('\n');
    expect(refused, 0, reason: first);
    expect(bad, 0, reason: first);
    expect(untriangulated, 0, reason: first);
  }, timeout: const Timeout(Duration(minutes: 10)));

  test(
      'OR3 editing the door\'s position regenerates its wall in the same '
      'undo step: the pieces move by coordinates; undo and redo are exact', () {
    final doc = doorWall();
    final f = oracleFrameOf(doc, hA);
    final before = canon(doc);
    final depth = doc.commands.undoDepth;
    final o = doc.components.get<OpeningParams>(hD)!;
    run(doc,
        SetComponentCommand<OpeningParams>(hD, o.copyWith(position: 2000)));
    expect(doc.commands.undoDepth, depth + 1);
    final [start, end] = worldPieces(doc, hA);
    expect(hasVertex(start, oracleAt(f, 1550, f.ro)), isTrue);
    expect(hasVertex(start, oracleAt(f, 1550, f.lo)), isTrue);
    expect(hasVertex(end, oracleAt(f, 2450, f.lo)), isTrue);
    expect(hasVertex(end, oracleAt(f, 2450, f.ro)), isTrue);
    expect(OpeningOracle(doc).tilingOf(hA), noViolations);
    final after = canon(doc);

    doc.commands.undo();
    expect(canon(doc), before);
    expect(driftOf(doc), isEmpty);
    expect(
        hasVertex(worldPieces(doc, hA).first, oracleAt(f, 950, f.lo)), isTrue);
    doc.commands.redo();
    expect(canon(doc), after);
    expect(driftOf(doc), isEmpty);
  });

  test(
      'OR6 deleting only the door makes the wall whole: 07\'s three '
      'children, the ring bit for bit the twin\'s uncut outline, the start '
      'piece\'s handles kept and the surplus the highest; one undo restores '
      'the pieces with their handles', () {
    final doc = doorWall();
    final f = oracleFrameOf(doc, hA);
    final twin = uncutTwin(doc);
    final before = canon(doc, sortNodes: true);
    final kidsBefore = kids(doc, hA);
    expect(kidsBefore, hasLength(6), reason: 'two pieces: 2 × 3 children');
    final fills = fillsOf(doc, hA);
    expect(fills, hasLength(2));
    // The start piece, found by coordinates (it reaches back to u = 0 and
    // stops at the gap), is the lower-handle region, and its centreline the
    // lower-handle centreline: pieces are rewritten in `u` order into the
    // existing children (D9).
    final pieces = worldPieces(doc, hA);
    final starts = [
      for (var i = 0; i < fills.length; i++)
        if (usOf(f, pieces[i]).reduce(math.min) < 1) fills[i]
    ];
    expect(starts, [fills.first], reason: 'the start piece is the lowest');
    expect(usOf(f, pieces.first).reduce(math.max), closeTo(950, 1e-6));
    final startFill = starts.single;
    final startBoundary = boundaryOf(doc, startFill);
    final firstLine = centrelineHandles(doc, hA).first;
    expect(usOf(f, worldCentrelines(doc, hA).first), [
      closeTo(0, 1e-6),
      closeTo(950, 1e-6),
    ]);

    final depth = doc.commands.undoDepth;
    run(doc, deleteLikeSelectTool(doc, hD));
    expect(doc.commands.undoDepth, depth + 1);
    expect(doc.tree[hD], isNull);
    final whole = kids(doc, hA);
    expect([for (final k in whole) kindOf(doc, k)],
        [EntityKind.fill, EntityKind.polyline, EntityKind.polyline]);
    expect(whole, [startFill, startBoundary, firstLine]);
    // The surplus is the highest handles.
    final gone = [
      for (final k in kidsBefore)
        if (!whole.contains(k)) k
    ];
    expect(gone, hasLength(3));
    expect(gone.every((g) => whole.every((k) => k.value < g.value)), isTrue,
        reason: 'kept $whole, removed $gone');
    // Bit for bit what 07 stores for the uncut wall.
    final twinFill = fillsOf(twin, hA).single;
    expect(payloadOf(doc, startBoundary).coords,
        payloadOf(twin, boundaryOf(twin, twinFill)).coords);
    final p = doc.components.get<WallParams>(hA)!;
    expect(payloadOf(doc, firstLine).coords, [p.sx, p.sy, p.ex, p.ey]);

    doc.commands.undo();
    expect(canon(doc, sortNodes: true), before);
    expect(kids(doc, hA), kidsBefore);
    expect(driftOf(doc), isEmpty);
  });
}
