// SPIKE 08 -- throwaway. Q3: the band split and the straight span, through
// the real ParametricSystem, at the far origin, every wall in its own
// rotated group.
import 'dart:math' as math;

import 'package:floor_planner/parametric/opening.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';

import '../support/wall_fixture.dart';
import 'support.dart';

void run(DraftDocument doc, DraftCommand c) {
  doc.commands.execute(c);
  expect(driftOf(doc), isEmpty, reason: 'drift after ${c.label}');
}

/// The oracle's straight span of [wall]: past every vertex of its uncut
/// outline on the start half, short of every vertex on the end half,
/// measured along the centreline by [oracleFrame].
(double, double) oracleSpan(DraftDocument doc, Handle wall) {
  final f = oracleFrame(doc, wall);
  final us = [for (final q in uncutOutline(doc, wall)) (q - f.s).dot(f.d)];
  return (
    us.where((u) => u < f.len / 2).fold(-double.infinity, math.max),
    us.where((u) => u >= f.len / 2).fold(double.infinity, math.min),
  );
}

/// The oracle's cut for [o]: clamped into [oracleSpan], or null (no fit).
(double, double)? oracleCut(DraftDocument doc, OpeningParams o) {
  final (s, e) = oracleSpan(doc, o.host);
  if (o.width > e - s) return null;
  final a = math.min(math.max(o.position - o.width / 2, s), e - o.width);
  return (a, a + o.width);
}

/// Checks every wall in [walls] against its openings in [doc]: the piece
/// count, the tiling oracle, triangulation of every stored piece, and that
/// no uncut outline vertex lies strictly inside a gap. Returns the total
/// tiling violations (for mutant runs that should not throw early).
int checkWalls(DraftDocument doc, List<Handle> walls, String why,
    {bool expectOk = true}) {
  var total = 0;
  for (final w in walls) {
    final cuts = <(double, double)>[
      for (final h in doc.components.withComponent<OpeningParams>())
        if (doc.components.get<OpeningParams>(h)!.host == w)
          if (oracleCut(doc, doc.components.get<OpeningParams>(h)!)
              case final c?)
            c,
    ]..sort((x, y) => x.$1.compareTo(y.$1));
    final merged = <(double, double)>[];
    for (final c in cuts) {
      if (merged.isNotEmpty && c.$1 <= merged.last.$2 + 1e-6) {
        merged.last = (merged.last.$1, math.max(merged.last.$2, c.$2));
      } else {
        merged.add(c);
      }
    }
    final pieces = worldPieces(doc, w);
    final v = tiling(uncutOutline(doc, w), pieces,
        [for (final (a, b) in merged) gapRect(doc, w, a, b)]);
    total += violations(v);
    if (!expectOk) continue;
    expect(v.values.every((x) => x == 0), isTrue, reason: '$why wall $w: $v');
    for (final k in kids(doc, w)) {
      if (kindOf(doc, k) == EntityKind.fill) {
        final b = Handle(payloadOf(doc, k).scalars[0].toInt());
        expect(doc.fills.trianglesFor(b), isNotEmpty, reason: '$why $w');
      }
    }
    final f = oracleFrame(doc, w);
    for (final q in uncutOutline(doc, w)) {
      final u = (q - f.s).dot(f.d);
      for (final (a, b) in merged) {
        expect(u > a + 1e-6 && u < b - 1e-6, isFalse,
            reason: '$why $w: a cap vertex at u=$u inside gap [$a, $b]');
      }
    }
  }
  return total;
}

/// Only the left face: 1 mm inside it, across the middle of each gap, no
/// piece. The probe a one-face test would write (M-08e survives it).
void expectLeftFaceOpen(DraftDocument doc, Handle w, double a, double b) {
  final f = oracleFrame(doc, w);
  final pieces = worldPieces(doc, w);
  for (var u = a + 10; u < b - 10; u += (b - a - 20) / 9) {
    final p = f.s + f.d * u + f.n * (f.lo - 1);
    expect(pieces.where((r) => insideRing(p, r)), isEmpty,
        reason: 'left face at u=$u');
  }
}

const hA = Handle(1300), hB = Handle(2600), hC = Handle(3000);

/// The 67° L of 07 (A into the node, B out of it) at justifications
/// [ja]/[jb], A 200 and B 115; a door in A at 900 (non-central), a window
/// in B at 1,700, and a door in A near the node (clamped at the mitre).
DraftDocument lPlan(Justification ja, Justification jb) {
  final doc = wallDoc();
  final hub = plan(0, 0);
  run(doc, addWall(doc, hA, plan(-3000, 0), hub, 200, ja));
  run(doc, addWall(doc, hB, hub, polar(hub, 180 - 67 + 23, 2500), 115, jb));
  run(
      doc,
      addOpening(doc, const Handle(5000),
          const OpeningParams(hA, 900, 800, OpeningKind.door)));
  run(
      doc,
      addOpening(doc, const Handle(5100),
          const OpeningParams(hB, 1700, 1000, OpeningKind.window)));
  run(
      doc,
      addOpening(doc, const Handle(5200),
          const OpeningParams(hA, 2950, 700, OpeningKind.door)));
  return doc;
}

void main() {
  test(
      'Q3a L at 67°, 200 against 115, all nine justification pairs: two '
      'openings in A (one clamped at the mitre), one in B', () {
    for (final ja in Justification.values) {
      for (final jb in Justification.values) {
        final doc = lPlan(ja, jb);
        checkWalls(doc, [hA, hB], '$ja/$jb');
        expect(worldPieces(doc, hA), hasLength(3), reason: '$ja/$jb');
        expect(worldPieces(doc, hB), hasLength(2), reason: '$ja/$jb');
        expect(
            diagnosticsOf(doc)
                .where((d) => d.code == 'opening.clamped')
                .map((d) => d.handles.single.value),
            [5200],
            reason: '$ja/$jb');
      }
    }
  });

  test(
      'Q3b T: a stem clamped at its butt, the through wall cut away from '
      'the stem; the 3-way node: one clamped opening per spoke', () {
    final doc = wallDoc();
    run(doc, addWall(doc, hA, plan(-3000, 0), plan(3000, 0), 300, right));
    run(doc, addWall(doc, hC, plan(700, 2600), plan(700, 0), 115, centre));
    run(
        doc,
        addOpening(doc, const Handle(5000),
            const OpeningParams(hC, 2500, 800, OpeningKind.door)));
    run(
        doc,
        addOpening(doc, const Handle(5100),
            const OpeningParams(hA, 1300, 900, OpeningKind.door)));
    checkWalls(doc, [hA, hC], 'T');
    // Clamped against the stem's square butt: the end piece is dropped.
    expect(worldPieces(doc, hC), hasLength(1));

    final hub = plan(9000, 4000);
    const spokes = [
      (Handle(6000), 0.0, 200.0, left),
      (Handle(6100), 120.0, 115.0, centre),
      (Handle(6200), 250.0, 150.0, right),
    ];
    for (final (h, deg, t, j) in spokes) {
      run(doc, addWall(doc, h, hub, polar(hub, deg + 23, 2400), t, j));
    }
    for (final (i, (h, _, _, _)) in spokes.indexed) {
      run(
          doc,
          addOpening(doc, Handle(7000 + 100 * i),
              OpeningParams(h, 200, 700, OpeningKind.window)));
    }
    checkWalls(doc, [for (final s in spokes) s.$1], '3-way');
    expect(
        diagnosticsOf(doc)
            .where((d) => d.code == 'opening.clamped')
            .map((d) => d.handles.single.value)
            .toList(),
        [5000, 7000, 7100, 7200]);
  });

  test(
      'Q3c overlap (merged), clamped at a free square cap (start piece '
      'dropped), no fit (uncut)', () {
    final doc = wallDoc();
    run(doc, addWall(doc, hA, plan(-2500, 0), plan(2500, 0), 200, left));
    run(
        doc,
        addOpening(doc, const Handle(5000),
            const OpeningParams(hA, 1400, 900, OpeningKind.door)));
    run(
        doc,
        addOpening(doc, const Handle(5100),
            const OpeningParams(hA, 1900, 800, OpeningKind.window)));
    run(
        doc,
        addOpening(doc, const Handle(5200),
            const OpeningParams(hA, 4600, 1000, OpeningKind.gap)));
    checkWalls(doc, [hA], 'overlap + cap');
    // [950, 2300] merged; [4000, 5000] against the free end: the end piece
    // is dropped. Two pieces.
    expect(worldPieces(doc, hA), hasLength(2));
    final codes = [
      for (final d in diagnosticsOf(doc))
        '${d.code} ${[for (final h in d.handles) h.value]}'
    ];
    expect(
        codes,
        containsAll([
          'opening.overlap [5000, 5100]',
          'opening.overlap [5100, 5000]',
          'opening.clamped [5200]'
        ]));

    run(doc,
        addWall(doc, hB, plan(-2500, 4000), plan(-1500, 4000), 200, centre));
    run(
        doc,
        addOpening(doc, const Handle(5300),
            const OpeningParams(hB, 500, 1200, OpeningKind.door)));
    checkWalls(doc, [hB], 'no fit');
    expect(worldPieces(doc, hB), hasLength(1));
    expect(worldPoints(doc, const Handle(5300), EntityKind.line), hasLength(1),
        reason: 'the symbol still shows');
    expect(diagnosticsOf(doc).map((d) => d.code), contains('opening.nofit'));
  });

  test('Q3d1 the degenerate fixture: a centred opening in a free symmetric '
      'wall, full oracle', () {
    final doc = wallDoc();
    run(doc, addWall(doc, hA, plan(-2500, 0), plan(2500, 0), 200, centre));
    run(
        doc,
        addOpening(doc, const Handle(5000),
            const OpeningParams(hA, 2500, 900, OpeningKind.door)));
    checkWalls(doc, [hA], 'centred');
  });

  test('Q3d2 the one-face probe: the non-central opening, left face only',
      () {
    final doc = wallDoc();
    run(doc, addWall(doc, hB, plan(-2500, 3000), plan(2500, 3000), 200, left));
    run(
        doc,
        addOpening(doc, const Handle(5100),
            const OpeningParams(hB, 1400, 900, OpeningKind.door)));
    expectLeftFaceOpen(doc, hB, 950, 1850);
  });

  test('Q3e the full oracle on the non-central fixture', () {
    final doc = wallDoc();
    run(doc, addWall(doc, hB, plan(-2500, 3000), plan(2500, 3000), 200, left));
    run(
        doc,
        addOpening(doc, const Handle(5100),
            const OpeningParams(hB, 1400, 900, OpeningKind.door)));
    checkWalls(doc, [hB], 'non-central');
  });

  test('Q3f random property run: 2-4-way nodes, random openings', () {
    final rnd = math.Random(808);
    var walls = 0, pieces = 0, openings = 0, clamped = 0, nofit = 0;
    var overlap = 0, bad = 0, refused = 0;
    for (var trial = 0; trial < 300; trial++) {
      final doc = wallDoc();
      final hub = plan(rnd.nextDouble() * 5000, rnd.nextDouble() * 5000);
      final n = 2 + rnd.nextInt(3);
      final hs = <Handle>[];
      var deg = rnd.nextDouble() * 360;
      for (var i = 0; i < n; i++) {
        final h = Handle(1000 + 100 * i);
        final t = [115.0, 150.0, 200.0, 300.0][rnd.nextInt(4)];
        final j = Justification.values[rnd.nextInt(3)];
        final len = 800 + rnd.nextDouble() * 3000;
        final out = rnd.nextBool();
        final tip = polar(hub, deg, len);
        run(
            doc,
            out
                ? addWall(doc, h, hub, tip, t, j)
                : addWall(doc, h, tip, hub, t, j));
        hs.add(h);
        deg += 50 + rnd.nextDouble() * (300 / n);
      }
      var oh = 5000;
      for (final h in hs) {
        final len = oracleFrame(doc, h).len;
        for (var k = rnd.nextInt(4); k > 0; k--) {
          final o = OpeningParams(h, rnd.nextDouble() * len,
              300 + rnd.nextDouble() * 1200, OpeningKind.values[rnd.nextInt(3)],
              hinge: HingeEnd.values[rnd.nextInt(2)],
              swing: SwingSide.values[rnd.nextInt(2)]);
          try {
            doc.commands.execute(addOpening(doc, Handle(oh += 10), o));
            openings++;
          } on ArgumentError {
            refused++;
          }
        }
      }
      expect(driftOf(doc), isEmpty, reason: 'trial $trial');
      bad += checkWalls(doc, hs, 'trial $trial', expectOk: false);
      walls += hs.length;
      for (final h in hs) {
        pieces += worldPieces(doc, h).length;
      }
      for (final d in diagnosticsOf(doc)) {
        if (d.code == 'opening.clamped') clamped++;
        if (d.code == 'opening.nofit') nofit++;
        if (d.code == 'opening.overlap') overlap++;
      }
      if (bad == 0) checkWalls(doc, hs, 'trial $trial');
    }
    // ignore: avoid_print
    print('Q3f: $walls walls, $openings openings ($refused refused), '
        '$pieces pieces, $clamped clamped, $nofit no-fit, '
        '$overlap overlap entries, $bad tiling violations');
    expect(refused, 0);
    expect(bad, 0);
  });
}
