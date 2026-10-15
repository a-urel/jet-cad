// Ported from jet_cad_floor_plan/test/invariants/pick_allocation_test.dart; assertions unchanged.
// What a pick allocates (host embedding API spec E-4, Slice 2's final
// review F-2): a hover picks at every mouse move, so `TablePicker.pick`
// must allocate nothing per table. Measured, not inferred: the Dart VM's
// own allocation profiler, through `AllocationMeter` (a copy of the
// engine's, `vm_allocation_meter.dart`), the mechanism of the engine's
// `query_allocation_test.dart`.
//
// **Under `flutter test` the profiler needs `--enable-vmservice`**: CI runs
// this package's tests with it. Without it every test here skips with
// [vmServiceUnavailableReason], and CI's standing comparison
// (`tool/ci/lib/standing.dart`) reads such a skip as red, listed or not.
//
// **What it catches.** Before the fix the JIT boxed doubles on every pick:
// the review measured about two `_Double`s per table (120,055 per 1,000
// picks over 60 tables, 2,055 over one), and this file's tests read up to
// 62,058 per 1,000 picks on that code, one or two of the three red on each
// of three runs. Two calls carried doubles the JIT may leave out of line,
// boxing them: the `x` and `y` getters of the picked point (two per pick),
// and the dynamic `TableTop.contains` (two per table). The pick now reads
// the point's storage and hands a top its local point in a list it keeps
// (`TableTop.containsAt`); the same measure reads 59 or 60 `_Double`s per
// 1,000 picks, and 5 `Vector2`s, whatever the pass: the meter's own round
// trip, not the picks. The budget below, half an object per pick, is two
// orders of magnitude under one per table on this 60-table floor.
//
// **The fixture is not degenerate:** 60 tables 40 m off the origin, each
// turned 37 degrees and mirrored, polygon tops and circle tops interleaved,
// so both tops' `containsAt` run in the measured picks. The JIT may inline
// the call to a top, and an inlined call boxes nothing: handing the local
// point back to `contains` as two doubles, with the storage read kept, reads
// clean here (it survives this file). `containsAt` makes the absence of
// boxing hold whatever the inliner chooses; this file proves the whole pick.
//
// A clean reading proves the JIT boxed no double and made no `Vector2` on
// this run's picks, as the engine's test's comment says of its own; it
// proves nothing of AOT or the web, which this repository does not measure.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/service/unit_picker.dart';
import 'package:jet_cad_2d_plan/src/units/unit_index.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/service_rig.dart' show hallController;
import '../support/unit_fixtures.dart';
import 'vm_allocation_meter.dart';

/// What a per-table regression makes: a boxed double, a point.
const _watched = {'_Double', 'Vector2'};

/// The hall's watch (2b Task 14): [_watched] and the transform a per-seat
/// inverse would make (M-PA-hall: `Transform2` holds its doubles unboxed,
/// so [_watched] alone misses it). The hall's live transforms (its
/// candidates' inverses, its nodes') read in every epoch, picks or none
/// (the meter's failure mode 1: some 3,500 measured), so the hall's
/// picks are held to their excess over an epoch with none, as RB16's
/// frames are.
const _hallWatched = {..._watched, 'Transform2'};

/// Instances per pick admitted: the meter's own noise (0.055 measured) but
/// not one object per pick, let alone one per table.
const double _perPickBudget = 0.5;

const int _tableCount = 60;

/// [_tableCount] tables in rows 40 m off the origin, each turned 37 degrees
/// about its place and mirrored: stools (circle tops) at the even places,
/// the first included, trapezoids (polygon tops) at the odd ones.
DraftDocument _floor() {
  final doc = unitPlan();
  for (var i = 0; i < _tableCount; i++) {
    final at = Vector2(40000.0 + 2500 * (i % 10), -27000.0 - 2500 * (i ~/ 10));
    placeAt(doc, i.isEven ? stoolSymbol : trapezoidTable, at, mirrored: true);
    final node = doc.tree.nodes
        .whereType<InstanceNode>()
        .reduce((a, b) => a.handle.value > b.handle.value ? a : b);
    final turn = Transform2.translation(at.x, at.y)
        .multiply(Transform2.rotation(kDeg37))
        .multiply(Transform2.translation(-at.x, -at.y));
    doc.commands.execute(
        TransformNodeCommand(node.handle, turn.multiply(node.transform)));
  }
  return doc;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AllocationMeter? meter;

  setUpAll(() async {
    meter = await AllocationMeter.connect();
  });

  tearDownAll(() async {
    await meter?.dispose();
  });

  late UnitPicker picker;
  late List<PickCandidate> list;
  late PickCandidate first;
  late Transform2 toWorld;
  late CircleTop circle;
  late Vector2 topPoint;
  late Vector2 boxPoint;
  final floorPoint = Vector2(-9000, 13000);

  setUpAll(() {
    final doc = _floor();
    picker = UnitPicker(doc, unitsOf(doc));
    list = picker.candidates;
    // The lowest handle: every pass visits every table before it.
    first = list.first;
    toWorld = first.inverse.invert();
    circle = first.top! as CircleTop;
    topPoint = toWorld.transformPoint(Vector2(circle.cx, circle.cy));
    // Inside the stool's box, off its round top: its box's corner, nudged
    // in.
    boxPoint = toWorld
        .transformPoint(Vector2(first.box.minX + 10, first.box.minY + 10));
  });

  /// [picks] picks of [world] with [reach], warmed first, measured by
  /// [meter]; [expected] the premise each pick must answer.
  Future<void> measure(Vector2 world,
      {required double reach, required UnitInfo? expected}) async {
    final m = meter;
    if (m == null) {
      markTestSkipped(vmServiceUnavailableReason);
      return;
    }
    expect(list, hasLength(_tableCount), reason: 'premise: every table');
    expect(list.map((c) => c.top.runtimeType).toSet(), {CircleTop, PolygonTop},
        reason: 'premise: both kinds of top at the one call site');
    expect(identical(picker.pick(world, reach: reach), expected), isTrue,
        reason: 'premise: the pick answers');
    // Warm: the JIT optimises the pick and the tops before the count, as
    // the engine's test warms its queries (20,000 calls).
    for (var i = 0; i < 20000; i++) {
      picker.pick(world, reach: reach);
    }
    await m.reset();
    const picks = 1000;
    for (var i = 0; i < picks; i++) {
      picker.pick(world, reach: reach);
    }
    final accumulated = await m.accumulatedInstances(_watched);
    expect(identical(picker.candidates, list), isTrue,
        reason: 'premise: the candidates were not rebuilt');
    for (final MapEntry(key: name, value: count) in accumulated.entries) {
      expect(count / picks, lessThan(_perPickBudget),
          reason: '$name: $count over $picks picks of $_tableCount tables '
              '(${count / picks} per pick): one per table would be '
              '$_tableCount per pick');
    }
  }

  test(
      'PA1 a pick on the floor, with a finger\'s reach, allocates nothing '
      'per table: every table visited by all three passes', () async {
    await measure(floorPoint, reach: 150, expected: null);
  });

  test(
      'PA2 a pick on the lowest table\'s top allocates nothing per table: '
      'every top visited', () async {
    await measure(topPoint, reach: 0, expected: first.unit);
  });

  test(
      'PA3 a pick in the lowest table\'s box, off its top, allocates nothing '
      'per table: every top, then every box visited', () async {
    await measure(boxPoint, reach: 0, expected: first.unit);
  });

  // 2b Review Focus 5: a dense hall, 500 generated seats in 25 rows (even
  // rows turned 37 degrees, odd rows curved), 40 m off the origin.
  group('the hall', () {
    late PlanController hall;
    late UnitPicker hallPicker;
    late List<PickCandidate> hallList;

    setUpAll(() {
      hall = hallController();
      hallPicker = hall.serviceSession!.picker;
      hallList = hallPicker.candidates;
    });

    tearDownAll(() => hall.dispose());

    Future<void> measureHall(Vector2 world,
        {required double reach, required UnitInfo? expected}) async {
      final m = meter;
      if (m == null) {
        markTestSkipped(vmServiceUnavailableReason);
        return;
      }
      expect(hallList.where((c) => c.unit.generated), hasLength(500),
          reason: 'premise: every seat a candidate');
      expect(identical(hallPicker.pick(world, reach: reach), expected), isTrue,
          reason: 'premise: the pick answers');
      for (var i = 0; i < 20000; i++) {
        hallPicker.pick(world, reach: reach);
      }
      await m.reset();
      final baseline = await m.accumulatedInstances(_hallWatched);
      await m.reset();
      const picks = 1000;
      for (var i = 0; i < picks; i++) {
        hallPicker.pick(world, reach: reach);
      }
      final accumulated = await m.accumulatedInstances(_hallWatched);
      expect(identical(hallPicker.candidates, hallList), isTrue,
          reason: 'premise: the candidates were not rebuilt');
      for (final MapEntry(key: name, value: count) in accumulated.entries) {
        expect((count - baseline[name]!) / picks, lessThan(_perPickBudget),
            reason: '$name: $count over $picks picks of 500 seats, '
                '${baseline[name]} with none');
      }
    }

    test(
        'PA4 a pick on the hall\'s floor, with a finger\'s reach, allocates '
        'nothing per seat: every seat visited by all three passes', () async {
      await measureHall(Vector2(-9000, 13000), reach: 150, expected: null);
    });

    test(
        'PA5 a pick on the lowest seat\'s top allocates nothing per seat: '
        'every top above it visited', () async {
      final first = hallList.firstWhere((c) => c.unit.generated);
      final t = first.unit.top;
      final world = first.unit.toWorld.transformPoint(
          Vector2((t.minX + t.maxX) / 2, (t.minY + t.maxY) / 2));
      await measureHall(world, reach: 0, expected: first.unit);
    });
  });
}
