// Spec 11 D5's drift fuzz and the Differential check: 300 seeded edits of
// the sample plan's nine walls and fourteen dimensions, each followed by
// `drift()` and the all-walls oracle (`oracleFailures`), with neighbour-only
// rebuilds known to occur; then the saved bytes loaded into a fresh
// document agree with the live one. Ported from the spike's
// `drift_test.dart` (`Q2e`, option (a)), its edit mix widened by D5's new
// dimension edits (a kind switched, an offset set, an end re-attached or
// made fixed, a page change).
import 'dart:math' as math;

import 'package:floor_planner/parametric/dimension.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/dimension_fixture.dart';

/// The fuzz's outcome.
typedef FuzzReport = ({
  int edits,
  List<String> failures,
  int generates,
  int neighbourOnly,
  int neighbourOnlyDims,
  Map<String, int> mix,
  int liveDims,
  int fewestLiveDims,
  double meanLiveDims,
  DraftDocument doc,
  List<Handle> dims,
});

/// Whether [doc] has [h] as a live object: a root-level group.
bool isLive(DraftDocument doc, Handle h) {
  final n = doc.tree[h];
  return n is GroupNode && n.parent == doc.tree.root;
}

/// D5's fuzz: `sampleWalls()` (nine walls, no column; S-9) at [place], a
/// millimetres page, and fourteen dimensions from `Random(seed)` (random
/// wall end points, a fifth of the ends fixed, all three kinds, a third of
/// the groups turned further than the placement). Then [edits] random edits
/// from D5's list; after each, `drift()` and [oracleFailures].
FuzzReport fuzz(
    {required int seed, required int edits, Placement place = corpusGroups}) {
  final rnd = math.Random(seed);
  final plan = buildPlan(sampleWalls(), place: place);
  final doc = plan.doc;
  attachPage(doc, mmPage);
  final walls = [...plan.walls];
  List<Handle> liveWalls() => [
        for (final w in walls)
          if (isLive(doc, w)) w,
      ];
  double frac() => rnd.nextDouble();

  /// A random end: a fifth fixed, at a fractional point of the flat taken
  /// back through [at]; the rest a random live wall's random end point.
  DimEnd randomEnd(Transform2 at) {
    if (rnd.nextInt(5) == 0) {
      return fixedAt(
          place.at(12000 + frac() * 14000, 8000 + frac() * 9000), at);
    }
    final live = liveWalls();
    return AttachedEnd(live[rnd.nextInt(live.length)], rnd.nextInt(2),
        WallSide.values[rnd.nextInt(3)]);
  }

  final dims = <Handle>[];

  /// Dimension number [i], as the Dimension tool commits one: a random kind
  /// and offset, its group at the placement, every third turned further by
  /// a fractional angle.
  Handle newDimension(int i) {
    final kind = DimKind.values[rnd.nextInt(3)];
    final at = i % 3 == 0
        ? place.m.multiply(Transform2.rotation(0.37 + 0.1 * i))
        : place.m;
    return addDimension(doc, randomEnd(at), randomEnd(at),
        kind: kind, offset: (frac() - 0.4) * 1500, at: at);
  }

  for (var i = 0; i < 14; i++) {
    dims.add(newDimension(i));
  }
  List<Handle> liveDims() => [
        for (final h in dims)
          if (isLive(doc, h)) h,
      ];

  final failures = <String>[];
  final mix = <String, int>{};
  var neighbourOnly = 0, neighbourOnlyDims = 0;
  var fewest = liveDims().length, liveSum = 0;
  final gens0 = debugDimensionGenerates;
  Map<Handle, String> texts() => {
        for (final h in liveDims())
          if (kids(doc, h).isNotEmpty) h: dimText(doc, h),
      };

  for (var step = 0; step < edits; step++) {
    final live = liveWalls();
    final w = live[rnd.nextInt(live.length)];
    final p = doc.components.get<WallParams>(w)!;
    final before = texts();
    // The walls this edit touches, for the neighbour-only count; empty for
    // an edit that is not a wall edit.
    var edited = <Handle>{};
    String what;
    switch (rnd.nextInt(14)) {
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
        edited = {w};
      case 2:
        doc.commands.execute(SetComponentCommand<WallParams>(w,
            p.copyWith(justification: Justification.values[rnd.nextInt(3)])));
        what = 'justification';
        edited = {w};
      case 3 || 4:
        // An end moved by up to ±400 mm (local), making or breaking joints.
        final dv = Vector2((frac() - 0.5) * 800, (frac() - 0.5) * 800);
        doc.commands.execute(SetComponentCommand<WallParams>(
            w,
            rnd.nextBool()
                ? p.copyWith(start: p.start + dv)
                : p.copyWith(end: p.end + dv)));
        what = 'end';
        edited = {w};
      case 5:
        // The wall's group moved and turned a little (a select-tool move),
        // about its world start.
        final m = doc.tree[w]!.transform;
        final piv = doc.tree.accumulatedTransform(w).transformPoint(p.start);
        final t = Transform2.translation(piv.x, piv.y)
            .multiply(Transform2.rotation((frac() - 0.5) * 0.2))
            .multiply(Transform2.translation(
                -piv.x + frac() * 200, -piv.y + frac() * 200));
        doc.commands.execute(TransformNodeCommand(w, t.multiply(m)));
        what = 'wall group';
        edited = {w};
      case 6:
        // A new wall from one of w's world ends to a random point, 150
        // centred, at the identity (as the Wall tool commits it).
        final a = doc.tree
            .accumulatedTransform(w)
            .transformPoint(rnd.nextBool() ? p.start : p.end);
        final b = a + Vector2((frac() - 0.5) * 6000, (frac() - 0.5) * 6000);
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
        what = 'wall added';
        edited = {h};
      case 7:
        if (live.length > 4) {
          doc.commands.execute(deleteObject(doc, w));
          what = 'wall deleted';
          edited = {w};
        } else {
          what = 'none';
        }
      case 8:
        if (doc.commands.canUndo) {
          doc.commands.undo();
          what = 'undo';
        } else {
          what = 'none';
        }
      default:
        final ld = liveDims();
        // A wall's deletion takes its dimensions with it (the cascade), and
        // the fuzz would drain: while fewer than fourteen are live, a third
        // of the dimension edits add one (not in D5's list; it keeps the
        // edits above acting on dimensions).
        if (ld.length < 14 && (ld.isEmpty || rnd.nextInt(3) == 0)) {
          dims.add(newDimension(dims.length));
          what = 'dimension added';
          break;
        }
        final d = ld[rnd.nextInt(ld.length)];
        final dp = doc.components.get<DimensionParams>(d)!;
        final m = doc.tree[d]!.transform;
        switch (rnd.nextInt(6)) {
          case 0:
            // Its group moved (fixed ends follow; attached ends do not).
            doc.commands.execute(TransformNodeCommand(
                d,
                Transform2.translation(
                        (frac() - 0.5) * 600, (frac() - 0.5) * 600)
                    .multiply(m)));
            what = 'dimension moved';
          case 1:
            // Its group turned about a point of the flat (its linear axes
            // turn with it, decision 17).
            final piv = place.at(12000 + frac() * 14000, 8000 + frac() * 9000);
            doc.commands.execute(TransformNodeCommand(
                d,
                Transform2.translation(piv.x, piv.y)
                    .multiply(Transform2.rotation((frac() - 0.5) * 1.2))
                    .multiply(Transform2.translation(-piv.x, -piv.y))
                    .multiply(m)));
            what = 'dimension turned';
          case 2:
            final others = [
              for (final k in DimKind.values)
                if (k != dp.kind) k,
            ];
            doc.commands.execute(SetComponentCommand<DimensionParams>(
                d, dp.copyWith(kind: others[rnd.nextInt(2)])));
            what = 'kind';
          case 3:
            doc.commands.execute(SetComponentCommand<DimensionParams>(
                d, dp.copyWith(offset: (frac() - 0.4) * 1500)));
            what = 'offset';
          case 4:
            // One end re-attached to a random wall end point, or made fixed
            // (randomEnd: a fifth fixed), through the group as it is now.
            final e = randomEnd(doc.tree.accumulatedTransform(d));
            doc.commands.execute(SetComponentCommand<DimensionParams>(
                d, rnd.nextBool() ? dp.copyWith(a: e) : dp.copyWith(b: e)));
            what = 'end re-attached';
          default:
            // A page change, the unit and the scale.
            doc.commands.execute(SetComponentCommand<PageComponent>(
                doc.rootHandle,
                pageOf(doc).copyWith(
                    displayUnit: DisplayUnit
                        .values[rnd.nextInt(DisplayUnit.values.length)],
                    scaleDenominator: const [
                      20.0,
                      50.0,
                      100.0,
                      200.0
                    ][rnd.nextInt(4)])));
            what = 'page';
        }
    }
    mix[what] = (mix[what] ?? 0) + 1;
    final drift = driftOf(doc);
    if (drift.isNotEmpty) failures.add('step $step ($what): drift $drift');
    for (final f in oracleFailures(doc)) {
      failures.add('step $step ($what): $f');
    }
    // A rebuild no reference explains: a dimension whose text changed
    // though it references none of the walls this edit touched.
    if (edited.isNotEmpty) {
      final after = texts();
      var any = false;
      for (final h in before.keys) {
        if (!after.containsKey(h) || after[h] == before[h]) continue;
        final dp = doc.components.get<DimensionParams>(h)!;
        final refs = {
          if (dp.a case AttachedEnd(:final wall)) wall,
          if (dp.b case AttachedEnd(:final wall)) wall,
        };
        if (refs.intersection(edited).isEmpty) {
          neighbourOnlyDims++;
          any = true;
        }
      }
      if (any) neighbourOnly++;
    }
    fewest = math.min(fewest, liveDims().length);
    liveSum += liveDims().length;
  }
  return (
    edits: edits,
    failures: failures,
    generates: debugDimensionGenerates - gens0,
    neighbourOnly: neighbourOnly,
    neighbourOnlyDims: neighbourOnlyDims,
    mix: mix,
    liveDims: liveDims().length,
    fewestLiveDims: fewest,
    meanLiveDims: liveSum / edits,
    doc: doc,
    dims: dims,
  );
}

void main() {
  test(
      'DZ1 300 seeded edits keep every dimension equal to the all-walls '
      'oracle, with neighbour-only rebuilds; a reload agrees', () {
    final watch = Stopwatch()..start();
    final report = fuzz(seed: 11, edits: 300);
    watch.stop();
    // ignore: avoid_print
    print('DZ1: (edits: ${report.edits}, failures: '
        '${report.failures.length}, generates: ${report.generates}, '
        'neighbourOnly: ${report.neighbourOnly} edits '
        '(${report.neighbourOnlyDims} dimensions), live dimensions: '
        '${report.liveDims} at the end, ${report.fewestLiveDims} at the '
        'fewest, ${report.meanLiveDims.toStringAsFixed(1)} on average, mix: ${report.mix}, ${watch.elapsedMilliseconds} ms)');
    expect(report.failures.take(20).toList(), isEmpty,
        reason: '${report.failures.length} failures');
    expect(report.neighbourOnly, greaterThan(0));

    // The reload (the Differential check): the saved bytes in a fresh
    // document and system. drift() is empty, it saves the same bytes, and
    // every dimension's children are the live document's, compared by
    // their records' bytes.
    final doc = report.doc;
    final saved = enc(doc);
    final back = reloadWithPage(saved);
    expect(driftOf(back), isEmpty);
    expect(oracleFailures(back), isEmpty);
    expect(enc(back), saved);
    var compared = 0;
    for (final h in report.dims) {
      expect(isLive(back, h), isLive(doc, h), reason: h.toHex());
      if (!isLive(doc, h)) continue;
      final ks = kids(doc, h);
      expect(kids(back, h), ks, reason: h.toHex());
      for (final k in ks) {
        expect(recordOf(back, k).toJson(), recordOf(doc, k).toJson(),
            reason: k.toHex());
        final p = payloadOf(doc, k), q = payloadOf(back, k);
        expect(q.coords, p.coords, reason: k.toHex());
        expect(q.scalars, p.scalars, reason: k.toHex());
        compared++;
      }
    }
    expect(compared, greaterThan(0));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
