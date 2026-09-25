// Spec 08 D7, D8, D17: obstacles, overlap, "a wall keeps a piece" and the
// openings' diagnostics, end to end through the real ParametricSystem. Every
// wall is at the far origin in its own rotated group (`groupAt`), no host is
// axis-aligned, and no opening is central. Expected cuts come from
// `support/opening_fixture.dart`'s oracles, which never call
// `opening_geometry.dart`; the tiling oracle's band is what 07 stores for the
// same wall in a twin document with every opening deleted.
import 'dart:math' as math;

import 'package:floor_planner/parametric/box.dart';
import 'package:floor_planner/parametric/opening.dart';
import 'package:floor_planner/parametric/opening_geometry.dart' show mergeCuts;
import 'package:floor_planner/parametric/wall.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/opening_fixture.dart';
import 'support/wall_fixture.dart';

const centre = Justification.centre;
const left = Justification.left;
const right = Justification.right;

const hA = Handle(1300), hB = Handle(2600);
const hD = Handle(4000), hM = Handle(4050), hW = Handle(4100);

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

/// Every diagnostic of [doc] as `code [handles]`, in the engine's order.
List<String> reports(DraftDocument doc) =>
    [for (final d in diagnosticsOf(doc)) '${d.code} ${d.handles}'];

/// The one diagnostic of [doc] with [code].
Diagnostic only(DraftDocument doc, String code) =>
    diagnosticsOf(doc).where((d) => d.code == code).single;

/// Whether [ring] has a vertex within 1e-6 of [p].
bool hasVertex(List<Vector2> ring, Vector2 p) => nearestIn(ring, p) < 1e-6;

/// The `u` of every point of [ring] in [f].
List<double> usOf(OracleFrame f, List<Vector2> ring) =>
    [for (final q in ring) oracleU(f, q)];

/// Wall [h]'s children are 07's three (fill, boundary, centreline), and its
/// boundary is, bit for bit, what 07 stores for it in [uncutTwin]: the wall
/// is uncut.
void expectUncut(DraftDocument doc, Handle h, {String? reason}) {
  expect([
    for (final k in kids(doc, h)) kindOf(doc, k)
  ], [
    EntityKind.fill,
    EntityKind.polyline,
    EntityKind.polyline
  ], reason: reason);
  final twin = uncutTwin(doc);
  expect(payloadOf(doc, boundaryOf(doc, fillsOf(doc, h).single)).coords,
      payloadOf(twin, boundaryOf(twin, fillsOf(twin, h).single)).coords,
      reason: reason);
}

/// Checks wall [h]'s cut at the oracle's gap `[a, b]` by coordinates: some
/// piece has both of the gap's corners at `a` and some piece both at `b`,
/// and no piece reaches into the gap.
void expectGapAt(DraftDocument doc, Handle h, double a, double b) {
  final f = oracleFrameOf(doc, h);
  final pieces = worldPieces(doc, h);
  for (final u in [a, b]) {
    expect(
        pieces.any((p) =>
            hasVertex(p, oracleAt(f, u, f.lo)) &&
            hasVertex(p, oracleAt(f, u, f.ro))),
        isTrue,
        reason: 'both corners at $u');
  }
  for (final p in pieces) {
    final us = usOf(f, p);
    expect(us.every((u) => u <= a + 1e-6) || us.every((u) => u >= b - 1e-6),
        isTrue,
        reason: 'a piece in the gap: $us');
  }
}

/// OG6's wall: 5,000 mm, 200 left-justified, at 23° in its own group at the
/// far origin, with openings [first] and [second] added in that order at
/// handles [hD] and [hW], and a 6,000 mm window, which fits nowhere, at the
/// handle between them, [hM] (so the diagnostics' order shows who reports).
DraftDocument overlapWall(OpeningParams first, OpeningParams second,
    {bool withNoFit = true}) {
  final doc = wallDoc();
  run(doc, addWall(doc, hA, plan(-2500, 900), plan(2500, 900), 200, left));
  run(doc, addOpening(doc, hD, first));
  if (withNoFit) {
    run(
        doc,
        addOpening(
            doc, hM, const OpeningParams(hA, 2600, 6000, OpeningKind.window)));
  }
  run(doc, addOpening(doc, hW, second));
  return doc;
}

void main() {
  test(
      'OG3 (M-08o) a T obstacle: 07\'s 58° T, a 115 stem onto a 200 '
      'right-justified host; a door stored over the stem\'s butt is drawn in '
      'the nearest wide-enough stretch, by coordinates the oracle\'s cut; '
      'tiling 0; opening.clamped names [door, stem] and a wall moved it', () {
    final doc = wallDoc();
    run(doc, addWall(doc, hA, plan(-2000, 0), plan(3000, 0), 200, right));
    final p = plan(1200, 0);
    run(doc, addWall(doc, hB, polar(p, 58 + 23, 2400), p, 115, centre));
    run(
        doc,
        addOpening(
            doc,
            hD,
            const OpeningParams(hA, 3150, 900, OpeningKind.door,
                hinge: HingeEnd.end, swing: SwingSide.right)));
    final oracle = OpeningOracle(doc);
    final f = oracleFrameOf(doc, hA);
    // Not degenerate: 650 off the wall's middle, and the stem's butt under
    // the stored interval [2700, 3600].
    expect((3150 - f.len / 2).abs(), greaterThan(600));
    final [(o1, o2)] = oracle.obstacles(hA);
    expect(o1 > 2700 && o2 < 3600, isTrue, reason: '[$o1, $o2]');
    expect(o2 - o1, greaterThan(100));
    final cut = oracle.cut(doc.components.get<OpeningParams>(hD)!)!;
    expect(cut.clamped, isTrue);
    expect(cut.b, lessThanOrEqualTo(o1), reason: 'the nearer stretch');
    expect(cut.b, closeTo(o1, 1e-6), reason: 'clamped against the stem');
    expect(cut.b - cut.a, closeTo(900, 1e-9));

    expect(worldPieces(doc, hA), hasLength(2));
    expectGapAt(doc, hA, cut.a, cut.b);
    expect(oracle.tilingOf(hA), noViolations);
    expect(storedPiecesTriangulate(doc, hA), isTrue);
    expect(storedPiecesSimpleCcw(doc, hA), isTrue);

    expect(reports(doc), ['opening.clamped [$hD, $hB]']);
    final d = only(doc, 'opening.clamped');
    expect(d.severity, DiagnosticSeverity.warning);
    expect(d.message, contains('wall ${hB.toHex()}'));
    expect(d.message, isNot(contains('corner')));
  });

  test(
      'OG4 (M-08x) an X obstacle: a 150 wall crossing a 200 left host at '
      '71°; a door stored over the crossing is drawn in the nearest '
      'wide-enough stretch, by coordinates the oracle\'s cut; tiling 0; '
      'opening.clamped names [door, crossing wall]', () {
    final doc = wallDoc();
    run(doc, addWall(doc, hA, plan(-2000, 0), plan(2500, 0), 200, left));
    final c = plan(600, 0);
    run(
        doc,
        addWall(doc, hB, polar(c, 71 + 23 + 180, 1400), polar(c, 71 + 23, 1700),
            150, centre));
    run(
        doc,
        addOpening(
            doc,
            hD,
            const OpeningParams(hA, 2650, 900, OpeningKind.door,
                swing: SwingSide.right)));
    final oracle = OpeningOracle(doc);
    final f = oracleFrameOf(doc, hA);
    expect((2650 - f.len / 2).abs(), greaterThan(300));
    final [(o1, o2)] = oracle.obstacles(hA);
    expect(o1 < 2650 && o2 > 2650, isTrue, reason: '[$o1, $o2]');
    final cut = oracle.cut(doc.components.get<OpeningParams>(hD)!)!;
    expect(cut.clamped, isTrue);
    expect(cut.a, closeTo(o2, 1e-6), reason: 'clamped against the crossing');

    expect(worldPieces(doc, hA), hasLength(2));
    expectGapAt(doc, hA, cut.a, cut.b);
    expect(oracle.tilingOf(hA), noViolations);
    expect(storedPiecesSimpleCcw(doc, hA), isTrue);

    expect(reports(doc), ['opening.clamped [$hD, $hB]']);
    expect(
        only(doc, 'opening.clamped').message, contains('wall ${hB.toHex()}'));
  });

  test(
      'OG6 (M-08m, M-08q, M-08q2) a door [1,150, 2,050] and a window '
      '[1,500, 2,700] overlap: one merged gap, two pieces, tiling 0, one '
      'opening.overlap from the lower handle [lower, higher], whichever kind '
      'it is; a door nested in a window likewise; touching openings, and '
      'ones within the tolerance of touching, make one gap and no overlap', () {
    const door = OpeningParams(hA, 1600, 900, OpeningKind.door);
    const window = OpeningParams(hA, 2100, 1200, OpeningKind.window);
    for (final (name, first, second) in [
      ('door first', door, window),
      ('window first', window, door),
    ]) {
      final doc = overlapWall(first, second);
      final oracle = OpeningOracle(doc);
      final gaps = oracle.gaps(hA);
      expect(gaps, hasLength(1), reason: name);
      expect(gaps.single.$1, closeTo(1150, 1e-9), reason: name);
      expect(gaps.single.$2, closeTo(2700, 1e-9), reason: name);
      expect(oracle.cut(doc.components.get<OpeningParams>(hM)!), isNull);
      expect(worldPieces(doc, hA), hasLength(2), reason: name);
      expect(centrelineHandles(doc, hA), hasLength(2), reason: name);
      expectGapAt(doc, hA, 1150, 2700);
      expect(oracle.tilingOf(hA), noViolations, reason: name);
      // Reported once, by the lower handle, which comes before the no-fit
      // window's report in diagnostics()' ascending order.
      expect(
          reports(doc), ['opening.overlap [$hD, $hW]', 'opening.nofit [$hM]'],
          reason: name);
      final reporter = only(doc, 'opening.overlap').handles.first;
      expect(doc.components.get<OpeningParams>(reporter)!.kind, first.kind,
          reason: name);
    }

    // A door nested in a window: the window's gap, one report.
    {
      final doc = overlapWall(
          window, const OpeningParams(hA, 2000, 600, OpeningKind.door),
          withNoFit: false);
      final oracle = OpeningOracle(doc);
      expect(oracle.gaps(hA), [(1500, 2700)]);
      expect(worldPieces(doc, hA), hasLength(2));
      expectGapAt(doc, hA, 1500, 2700);
      expect(oracle.tilingOf(hA), noViolations);
      expect(reports(doc), ['opening.overlap [$hD, $hW]']);
    }

    // Touching: the door ends at 2,050 and the window starts there, bit for
    // bit; then 5e-7 later, and 5e-7 earlier: within the tolerance either
    // way, so one gap, and no overlap.
    for (final (name, at) in [
      ('touching', 2650.0),
      ('5e-7 apart', 2650 + 5e-7),
      ('5e-7 into', 2650 - 5e-7),
    ]) {
      final doc = overlapWall(
          door, OpeningParams(hA, at, 1200, OpeningKind.window),
          withNoFit: false);
      final oracle = OpeningOracle(doc);
      final a = oracle.cut(doc.components.get<OpeningParams>(hD)!)!;
      final b = oracle.cut(doc.components.get<OpeningParams>(hW)!)!;
      expect(a.b, 2050, reason: name);
      expect((b.a - 2050).abs(), lessThan(wallJoin.linear), reason: name);
      if (name == 'touching') expect(b.a, a.b);
      // D8's merge joins them (a sliver between them would be a piece no
      // longer than the tolerance: dropped, so only the merge shows it).
      expect(mergeCuts([(a.a, a.b), (b.a, b.b)]), hasLength(1), reason: name);
      expect(oracle.gaps(hA), hasLength(1), reason: name);
      expect(worldPieces(doc, hA), hasLength(2), reason: name);
      expectGapAt(doc, hA, 1150, b.b);
      expect(oracle.tilingOf(hA), noViolations, reason: name);
      expect(reports(doc), isEmpty, reason: name);
    }
  });

  // D8 as amended at execution: after merging, a wall with no piece longer
  // than wallJoin.linear makes its highest-handle fitting opening no-fit,
  // and cuts again. Each case below cut its wall into nothing before.
  test(
      'OG11 (a) a wall keeps a piece: a gap 2e-7 shorter than a free wall\'s '
      'whole span is no-fit (opening.nofit, not clamped); the wall is uncut',
      () {
    // (a) A free 3,000 wall, 150 left, and a gap 2e-7 shorter than its span.
    final doc = wallDoc();
    run(doc, addWall(doc, hA, plan(-1500, -700), plan(1500, -700), 150, left));
    final (uS, uE) = oracleSpan(doc, hA);
    final gap =
        OpeningParams(hA, (uS + uE) / 2, uE - uS - 2e-7, OpeningKind.gap);
    run(doc, addOpening(doc, hD, gap));
    final oracle = OpeningOracle(doc);
    expect(oracle.cut(gap), isNotNull, reason: 'it fits on its own');
    expect(oracle.cutsOn(hA), [(hD, null)]);
    expectUncut(doc, hA, reason: 'whole span');
    expect(reports(doc), ['opening.nofit [$hD]']);
  });

  test(
      'OG11 (b) a wall keeps a piece: two 1,000 windows at 500 and 1,500 on '
      'a free 2,000 wall each cut alone; together the higher-handle one is '
      'no-fit (opening.nofit, not clamped) and the lower one keeps its cut',
      () {
    // (b) A free centred 2,000 wall with windows at 500 and 1,500, 1,000
    // each: alone, each cuts and leaves one piece; together their cuts cover
    // the wall, so the higher-handle one yields and the lower one cuts.
    const w1 = OpeningParams(hA, 500, 1000, OpeningKind.window);
    const w2 = OpeningParams(hA, 1500, 1000, OpeningKind.window);
    DraftDocument twoWindows(List<(Handle, OpeningParams)> openings) {
      final doc = wallDoc();
      run(doc,
          addWall(doc, hA, plan(-1000, 2600), plan(1000, 2600), 200, centre));
      for (final (h, o) in openings) {
        run(doc, addOpening(doc, h, o));
      }
      return doc;
    }

    for (final (h, o) in [(hD, w1), (hW, w2)]) {
      final doc = twoWindows([(h, o)]);
      expect(kids(doc, hA), hasLength(3), reason: 'alone: ${o.position}');
      expect(OpeningOracle(doc).gaps(hA), hasLength(1));
      expect(worldPieces(doc, hA), hasLength(1));
    }
    final doc = twoWindows([(hD, w1), (hW, w2)]);
    final f = oracleFrameOf(doc, hA);
    expect(f.len, closeTo(2000, 1e-6));
    final oracle = OpeningOracle(doc);
    expect(oracle.cut(w2), isNotNull, reason: 'it fits on its own');
    expect([for (final (h, c) in oracle.cutsOn(hA)) (h, c != null)],
        [(hD, true), (hW, false)]);
    expect(kids(doc, hA), hasLength(3));
    final [piece] = worldPieces(doc, hA);
    expect(hasVertex(piece, oracleAt(f, 1000, f.lo)), isTrue);
    expect(hasVertex(piece, oracleAt(f, 1000, f.ro)), isTrue);
    expect(usOf(f, piece).reduce(math.min), greaterThan(1000 - 1e-6));
    expect(oracle.tilingOf(hA), noViolations);
    expect(storedPiecesSimpleCcw(doc, hA), isTrue);
    expect([
      for (final d in diagnosticsOf(doc))
        if (d.handles.first == hW) '${d.code} ${d.handles}'
    ], [
      'opening.nofit [$hW]'
    ]);
  });

  test(
      'OG11 (c) a wall keeps a piece: a gap 5e-7 shorter than a square T '
      'stem\'s span [100, 1500] leaves 2.5e-7 slivers: it is no-fit and the '
      'stem is uncut', () {
    // (c) A 1,500 stem teeing square into a 200 centre host: its span is
    // [100, 1500], and a gap 5e-7 shorter than it leaves end pieces of
    // 2.5e-7, both dropped.
    final doc = wallDoc();
    final p = plan(0, 4500);
    run(doc,
        addWall(doc, hA, plan(-2000, 4500), plan(2000, 4500), 200, centre));
    run(doc, addWall(doc, hB, p, polar(p, 23 - 90, 1500), 115, centre));
    final (uS, uE) = oracleSpan(doc, hB);
    expect(uS, closeTo(100, 1e-6));
    expect(uE, closeTo(1500, 1e-6));
    // ignore: avoid_print
    print('OG11 (c): the stem\'s span is [$uS, $uE]');
    final gap =
        OpeningParams(hB, (uS + uE) / 2, uE - uS - 5e-7, OpeningKind.gap);
    run(doc, addOpening(doc, hD, gap));
    final oracle = OpeningOracle(doc);
    expect(oracle.cut(gap), isNotNull, reason: 'it fits on its own');
    expect(oracle.cutsOn(hB), [(hD, null)]);
    expectUncut(doc, hB, reason: 'slivers only');
    expect(reports(doc), ['opening.nofit [$hD]']);
  });

  test(
      'OD1 only the accepted cases are reported: a clean L with fitting '
      'openings reports nothing; OG5\'s no-fit exactly opening.nofit; a host '
      'that is a box opening.orphan; a loaded width 0 only '
      'opening.degenerate; a loaded missing host only parametric.dangling', () {
    // A clean L: A 200 centre into the node, B 115 left out of it, a door
    // in A and a window in B, neither clamped.
    {
      final doc = wallDoc();
      final hub = plan(0, -4000);
      run(doc, addWall(doc, hA, plan(-3000, -4000), hub, 200, centre));
      run(doc, addWall(doc, hB, hub, polar(hub, 136, 2500), 115, left));
      run(
          doc,
          addOpening(
              doc, hD, const OpeningParams(hA, 1100, 800, OpeningKind.door)));
      run(
          doc,
          addOpening(doc, hW,
              const OpeningParams(hB, 1300, 1000, OpeningKind.window)));
      expect(worldPieces(doc, hA), hasLength(2));
      expect(worldPieces(doc, hB), hasLength(2));
      expect(diagnosticsOf(doc), isEmpty);
    }

    // OG5's configuration: a T splits the span into ~840 and ~3,040, and a
    // 3,200.5 door fits in neither.
    {
      final doc = wallDoc();
      run(doc,
          addWall(doc, hA, plan(-1500, 600), plan(2500, 600), 200, centre));
      final p = plan(-600, 600);
      run(doc, addWall(doc, hB, polar(p, 75 + 23, 2000), p, 115, centre));
      run(
          doc,
          addOpening(doc, hD,
              const OpeningParams(hA, 350.25, 3200.5, OpeningKind.door)));
      expect(OpeningOracle(doc).stretches(hA), hasLength(2));
      expect(OpeningOracle(doc).cutsOn(hA), [(hD, null)]);
      expectUncut(doc, hA);
      expect(reports(doc), ['opening.nofit [$hD]']);
      expect(only(doc, 'opening.nofit').severity, DiagnosticSeverity.warning);
    }

    // A box as host: accepted (a live object, D5), draws nothing, reported.
    {
      final doc = wallDoc();
      run(
          doc,
          CompoundCommand([
            AddNodeCommand(GroupNode(
                handle: hB,
                parent: doc.rootHandle,
                transform: groupAt(hB.value),
                children: const [])),
            SetComponentCommand<BoxParams>(hB, const BoxParams(1200, 800)),
          ], label: 'Add box'));
      final boxKids = [
        for (final k in kids(doc, hB)) '$k ${payloadOf(doc, k).coords}'
      ];
      expect(boxKids, hasLength(4));
      run(
          doc,
          addOpening(
              doc, hD, const OpeningParams(hB, 300, 600, OpeningKind.window)));
      expect(kids(doc, hD), isEmpty);
      expect(reports(doc), ['opening.orphan [$hD, $hB]']);
      expect(only(doc, 'opening.orphan').severity, DiagnosticSeverity.warning);
      // The box does not read its referrer: its children are unchanged.
      expect([for (final k in kids(doc, hB)) '$k ${payloadOf(doc, k).coords}'],
          boxKids);
    }

    // A loaded opening of width 0: only opening.degenerate, an error; its
    // host is uncut.
    {
      final doc = wallDoc();
      run(doc,
          addWall(doc, hA, plan(-2000, -900), plan(2000, -900), 200, right));
      run(
          doc,
          addOpening(
              doc, hD, const OpeningParams(hA, 1300, 0, OpeningKind.door)));
      final loaded = reload(enc(doc));
      expectUncut(loaded, hA);
      expect(reports(loaded), ['opening.degenerate [$hD]']);
      expect(only(loaded, 'opening.degenerate').severity,
          DiagnosticSeverity.error);
    }

    // A loaded opening whose host is missing: a file only (an edit is
    // refused, D5). Written with the planner detached, then reloaded.
    {
      final doc = wallDoc();
      run(doc,
          addWall(doc, hA, plan(-2000, -900), plan(2000, -900), 200, right));
      doc.commands.expander = null;
      const missing = Handle(0x7777);
      doc.commands.execute(addOpening(
          doc, hD, const OpeningParams(missing, 1300, 900, OpeningKind.door)));
      final loaded = reload(enc(doc));
      expect(loaded.tree[missing], isNull);
      expectUncut(loaded, hA);
      expect(reports(loaded), ['parametric.dangling [$hD, $missing]']);
    }
  });
}
