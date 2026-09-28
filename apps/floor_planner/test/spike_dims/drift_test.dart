// SPIKE 11 -- throwaway. Q2: which edits must rebuild a dimension. The
// neighbour case (B's edit moves A's cleaned corner while A is not edited),
// a seeded fuzz comparing every dimension with a from-scratch oracle after
// every edit, the wall-deletion cascade and its undo.
import 'dart:math' as math;

import 'package:floor_planner/parametric/dimension.dart';
import 'package:floor_planner/parametric/dimension_geometry.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support.dart';

const l = WallSide.left, c = WallSide.centre, r = WallSide.right;

PageComponent get mmPage =>
    PageComponent().copyWith(displayUnit: DisplayUnit.millimeters);

/// Every dimension of [doc] checked against the oracle: the stored text is
/// [formatDimension] of the oracle's value, and the stored dimension line
/// lies within 1e-6 mm of the oracle's layout. Returns the failures.
List<String> oracleFailures(DraftDocument doc) {
  final out = <String>[];
  final page = pageOf(doc);
  for (final h in doc.components.withComponent<DimensionParams>()) {
    if (doc.tree[h] == null) continue;
    final p = doc.components.get<DimensionParams>(h)!;
    final p0 = oracleEnd(doc, h, p.a), p1 = oracleEnd(doc, h, p.b);
    final m = doc.tree.accumulatedTransform(h);
    final axis = m.transformDirection(
        p.kind == DimKind.vertical ? Vector2(0, 1) : Vector2(1, 0));
    final want = layoutDimension(p0, p1, p.kind, axis,
        p.offset * m.scaleMagnitude, page.scaleDenominator);
    final text = dimText(doc, h);
    final wantText = formatDimension(want.value, page.displayUnit);
    if (text != wantText) out.add('${h.value}: text $text, want $wantText');
    final (a, b) = dimLines(doc, h).first;
    final err = math.max((a - want.q0).length, (b - want.q1).length);
    if (!(err < 1e-6)) out.add('${h.value}: line off by $err');
  }
  return out;
}

/// An L at [place]: A (0,0) -> (4000,0) and B (4000,0) -> (4000,3000),
/// 200 centred, and a dimension on A's left face, A/0/left -> A/1/left,
/// which references A only.
({Plan plan, Handle a, Handle b, Handle dim}) lPlan(Placement place) {
  final plan = buildPlan(
      const [W(0, 0, 4000, 0, 200), W(4000, 0, 4000, 3000, 200)],
      place: place);
  attachPage(plan.doc, mmPage);
  final [a, b] = plan.walls;
  final dim = addDimension(plan.doc, AttachedEnd(a, 0, l), AttachedEnd(a, 1, l),
      offset: 800);
  return (plan: plan, a: a, b: b, dim: dim);
}

void main() {
  tearDown(() => debugDimensionReadsPlaces = false);

  for (final place in [origin, corpusGroups, km1000Groups]) {
    test('Q2a the neighbour case: B thickened, A untouched, $place', () {
      final (:plan, :a, :b, :dim) = lPlan(place);
      final doc = plan.doc;
      // A's inner face from its free start (0, 100) to the mitre
      // (4000 - 100, 100): 3900.
      expect(dimText(doc, dim), '3900');
      expect(driftOf(doc), isEmpty);
      final aBefore = doc.components.get<WallParams>(a);
      final gens = debugDimensionGenerates;
      // B 200 -> 300: B's left face x = 4000 - 150, so A's mitre corner
      // moves to (3850, 100); A's parameters are unchanged.
      doc.commands.execute(SetComponentCommand<WallParams>(
          b, doc.components.get<WallParams>(b)!.copyWith(thickness: 300)));
      expect(doc.components.get<WallParams>(a), aBefore);
      expect(dimText(doc, dim), '3850');
      expect(debugDimensionGenerates - gens, 1);
      expect(driftOf(doc), isEmpty);
      expect(oracleFailures(doc), isEmpty);
      // A new wall C joined at A's free start moves the other corner: C
      // north from (0, 0), 200: A/0/left = (100, 100). 3850 - 100 = 3750.
      final cH = doc.handleSeed.next();
      final g = place.groups ? groupFor(place, 7) : Transform2.identity();
      final s = g.invert().transformPoint(place.at(0, 0));
      final e = g.invert().transformPoint(place.at(0, 3000));
      doc.commands.execute(CompoundCommand([
        AddNodeCommand(GroupNode(
            handle: cH,
            parent: doc.rootHandle,
            transform: g,
            children: const [])),
        SetComponentCommand<WallParams>(
            cH, WallParams(s.x, s.y, e.x, e.y, 200, Justification.centre)),
      ], label: 'Add wall'));
      expect(dimText(doc, dim), '3750');
      expect(driftOf(doc), isEmpty);
      // C deleted: back to 3850, one step.
      doc.commands.execute(deleteObject(doc, cH));
      expect(dimText(doc, dim), '3850');
      expect(driftOf(doc), isEmpty);
      expect(oracleFailures(doc), isEmpty);
    });
  }

  test('Q2b the T: the through wall thickened moves the stem\'s corner', () {
    final plan = buildPlan(
        const [W(0, 0, 6000, 0, 200), W(2500, 0, 2500, 3000, 100)],
        place: corpusGroups);
    final doc = plan.doc;
    attachPage(doc, mmPage);
    final [cw, s] = plan.walls;
    // S's left face x = 2450, from C's near face (2450, 100) to its free
    // end (2450, 3000): 2900.
    final dim = addDimension(doc, AttachedEnd(s, 0, l), AttachedEnd(s, 1, l));
    expect(dimText(doc, dim), '2900');
    // C 200 -> 400: its near face y = 200; 3000 - 200 = 2800.
    doc.commands.execute(SetComponentCommand<WallParams>(
        cw, doc.components.get<WallParams>(cw)!.copyWith(thickness: 400)));
    expect(dimText(doc, dim), '2800');
    expect(driftOf(doc), isEmpty);
    // C's group moved 50 mm along its own normal (a select-tool move of
    // the through wall): S's start is no longer on C's centreline, so the
    // T is gone (07 D4.1) and S's start squares at its own end, (2450, 0):
    // 3000. S itself is not edited.
    final m = doc.tree[cw]!.transform;
    final nrm = plan.at(0, 50) - plan.at(0, 0);
    doc.commands.execute(TransformNodeCommand(
        cw, Transform2.translation(nrm.x, nrm.y).multiply(m)));
    expect(dimText(doc, dim), '3000');
    expect(driftOf(doc), isEmpty);
    expect(oracleFailures(doc), isEmpty);
  });

  test(
      'Q2c deleting a referenced wall deletes the dimension, one step; '
      'undo restores both, handles and draw order intact', () {
    final (:plan, :a, :b, :dim) = lPlan(corpusGroups);
    final doc = plan.doc;
    // A second dimension on B only: B/0/right -> B/1/right (B's outer
    // face, from the mitre (4100, -100) to (4100, 3000): 3100). It must
    // survive A's deletion.
    final other = addDimension(doc, AttachedEnd(b, 0, r), AttachedEnd(b, 1, r),
        offset: -600);
    expect(dimText(doc, other), '3100');
    final before = canon(doc, sortNodes: true);
    final entities = [
      for (final s in doc.entities.liveSlots)
        (doc.entities.handleAt(s).value, doc.entities.ownerAt(s).value)
    ]..sort((x, y) => x.$1.compareTo(y.$1));
    final depth = doc.commands.undoDepth;
    doc.commands.execute(deleteObject(doc, a));
    expect(doc.commands.undoDepth, depth + 1);
    expect(doc.tree[a], isNull);
    expect(doc.tree[dim], isNull);
    expect(doc.components.get<DimensionParams>(dim), isNull);
    // B's start is free now: its outer face from (4100, 0) to (4100,
    // 3000): 3000.
    expect(dimText(doc, other), '3000');
    expect(driftOf(doc), isEmpty);
    doc.commands.undo();
    expect(canon(doc, sortNodes: true), before);
    final after = [
      for (final s in doc.entities.liveSlots)
        (doc.entities.handleAt(s).value, doc.entities.ownerAt(s).value)
    ]..sort((x, y) => x.$1.compareTo(y.$1));
    expect(after, entities);
    expect(dimText(doc, dim), '3900');
    expect(dimText(doc, other), '3100');
    expect(driftOf(doc), isEmpty);
    // ignore: avoid_print
    print('Q2c cascade: ${entities.length} entities restored with their '
        'handles and owners; undo depth ${depth + 1} -> $depth');
  });

  test('Q2d save -> load -> save is byte-identical, references intact', () {
    final (:plan, :a, b: _, :dim) = lPlan(corpusGroups);
    final s1 = enc(plan.doc);
    final back = reloadWithPage(s1);
    expect(enc(back), s1);
    expect(driftOf(back), isEmpty);
    expect(back.components.get<DimensionParams>(dim),
        plan.doc.components.get<DimensionParams>(dim));
    expect(
        (back.components.get<DimensionParams>(dim)!.a as AttachedEnd).wall, a);
  });

  for (final readsPlaces in [false, true]) {
    test(
        'Q2e fuzz: every dimension equals the oracle after every edit '
        '(${readsPlaces ? 'option (b): references + reads places' : 'option (a): references, today\'s closure'})',
        () {
      debugDimensionReadsPlaces = readsPlaces;
      final report = fuzz(seed: 11, edits: 300);
      // ignore: avoid_print
      print('Q2e ${readsPlaces ? '(b)' : '(a)'}: $report');
      expect(report.failures, isEmpty);
    });
  }
}

/// The fuzz's outcome.
typedef FuzzReport = ({
  int edits,
  int neighbourOnly,
  int generates,
  int readBoxCalls,
  List<String> failures,
});

/// The sample plan's nine walls at the corpus far origin, every wall in its
/// own rotated group, page in mm, and fourteen dimensions: random wall end
/// points, a few fixed ends, aligned and linear, some in rotated groups.
/// Then [edits] random edits; after each, `drift()` and [oracleFailures].
FuzzReport fuzz({required int seed, required int edits}) {
  final rnd = math.Random(seed);
  const place = corpusGroups;
  final plan = buildPlan(sampleWalls(), place: place);
  final doc = plan.doc;
  attachPage(doc, mmPage);
  final walls = [...plan.walls];
  DimEnd randomEnd() {
    if (rnd.nextInt(5) == 0) {
      return fixedAt(place.at(
          12000 + rnd.nextDouble() * 14000, 8000 + rnd.nextDouble() * 9000));
    }
    return AttachedEnd(walls[rnd.nextInt(walls.length)], rnd.nextInt(2),
        WallSide.values[rnd.nextInt(3)]);
  }

  final dims = <Handle>[];
  for (var i = 0; i < 14; i++) {
    final kind = DimKind.values[rnd.nextInt(3)];
    final at = i % 3 == 0
        ? place.m.multiply(Transform2.rotation(0.1 * i))
        : Transform2.identity();
    dims.add(addDimension(doc, randomEnd(), randomEnd(),
        kind: kind, offset: (rnd.nextDouble() - 0.4) * 1500, at: at));
  }
  final failures = <String>[];
  var neighbourOnly = 0;
  final gens0 = debugDimensionGenerates;
  final boxes0 = debugReadBoxCalls;
  Map<Handle, String> texts() => {
        for (final h in dims)
          if (doc.tree[h] != null) h: dimText(doc, h),
      };
  for (var step = 0; step < edits; step++) {
    final live = [
      for (final w in walls)
        if (doc.tree[w] != null) w
    ];
    final w = live[rnd.nextInt(live.length)];
    final p = doc.components.get<WallParams>(w)!;
    final before = texts();
    final choice = rnd.nextInt(10);
    String what;
    switch (choice) {
      case 0 || 1:
        final t = const [
          60.0,
          100.0,
          120.0,
          200.0,
          250.0,
          300.0,
          400.0
        ][rnd.nextInt(7)];
        doc.commands.execute(
            SetComponentCommand<WallParams>(w, p.copyWith(thickness: t)));
        what = 'thickness';
      case 2:
        doc.commands.execute(SetComponentCommand<WallParams>(w,
            p.copyWith(justification: Justification.values[rnd.nextInt(3)])));
        what = 'justification';
      case 3 || 4:
        // An end moved by up to ±400 mm (local), breaking or making joints.
        final dv = Vector2(
            (rnd.nextDouble() - 0.5) * 800, (rnd.nextDouble() - 0.5) * 800);
        doc.commands.execute(SetComponentCommand<WallParams>(
            w,
            rnd.nextBool()
                ? p.copyWith(start: p.start + dv)
                : p.copyWith(end: p.end + dv)));
        what = 'end';
      case 5:
        // The wall's group moved and turned a little (a select-tool move).
        final m = doc.tree[w]!.transform;
        final piv = doc.tree.accumulatedTransform(w).transformPoint(p.start);
        final t = Transform2.translation(piv.x, piv.y)
            .multiply(Transform2.rotation((rnd.nextDouble() - 0.5) * 0.2))
            .multiply(Transform2.translation(-piv.x + rnd.nextDouble() * 200,
                -piv.y + rnd.nextDouble() * 200));
        doc.commands.execute(TransformNodeCommand(w, t.multiply(m)));
        what = 'group';
      case 6:
        // A new wall from one of w's world ends to a random point.
        final a = doc.tree
            .accumulatedTransform(w)
            .transformPoint(rnd.nextBool() ? p.start : p.end);
        final b = a +
            Vector2((rnd.nextDouble() - 0.5) * 6000,
                (rnd.nextDouble() - 0.5) * 6000);
        final h = doc.handleSeed.next();
        doc.commands.execute(CompoundCommand([
          AddNodeCommand(GroupNode(
              handle: h,
              parent: doc.rootHandle,
              transform: Transform2.identity(),
              children: const [])),
          SetComponentCommand<WallParams>(
              h, WallParams(a.x, a.y, b.x, b.y, 150, Justification.centre)),
        ], label: 'Add wall'));
        walls.add(h);
        what = 'add';
      case 7:
        if (live.length > 4) {
          doc.commands.execute(deleteObject(doc, w));
          what = 'delete';
        } else {
          what = 'none';
        }
      case 8:
        if (doc.commands.canUndo) doc.commands.undo();
        what = 'undo';
      default:
        // A dimension's own group moved (fixed ends follow, attached do
        // not).
        final ld = [
          for (final h in dims)
            if (doc.tree[h] != null) h
        ];
        if (ld.isEmpty) {
          what = 'none';
          break;
        }
        final d = ld[rnd.nextInt(ld.length)];
        final m = doc.tree[d]!.transform;
        doc.commands.execute(TransformNodeCommand(
            d, Transform2.translation(rnd.nextDouble() * 300, 0).multiply(m)));
        what = 'dim move';
    }
    final drift = driftOf(doc);
    if (drift.isNotEmpty) failures.add('step $step ($what): drift $drift');
    for (final f in oracleFailures(doc)) {
      failures.add('step $step ($what): $f');
    }
    // A rebuild that no reference explains: a dimension whose text changed
    // though it references none of the edited walls.
    if (what == 'thickness' ||
        what == 'justification' ||
        what == 'end' ||
        what == 'group') {
      final after = texts();
      for (final h in before.keys) {
        if (!after.containsKey(h) || after[h] == before[h]) continue;
        final dp = doc.components.get<DimensionParams>(h)!;
        final refs = {
          if (dp.a case AttachedEnd(:final wall)) wall,
          if (dp.b case AttachedEnd(:final wall)) wall,
        };
        if (!refs.contains(w)) neighbourOnly++;
      }
    }
  }
  return (
    edits: edits,
    neighbourOnly: neighbourOnly,
    generates: debugDimensionGenerates - gens0,
    readBoxCalls: debugReadBoxCalls - boxes0,
    failures: failures,
  );
}
