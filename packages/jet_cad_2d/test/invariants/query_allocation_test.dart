// Measures the Global Constraint's own words: "Zero allocation on the frame
// path. `forEachInRect`, `forEachInstanceInRect`, `pickInto` and `snapInto`
// must not allocate in steady state -- after the result scratch has grown
// once. Growing the scratch is permitted; allocating per call is not."
//
// **Mechanism:** `AllocationMeter` (`vm_allocation_meter.dart`), which wraps
// the Dart VM's own allocation profiler via `package:vm_service`, started at
// runtime with `dart:developer`'s `Service.controlWebServer` rather than a
// `--enable-vm-service` CLI flag -- see that file's doc comment for why this
// mechanism, and what its own two failure modes were and how they are
// designed around. **Every test in this file skips itself, with a stated
// reason, if the profiler cannot be reached** (`AllocationMeter.connect()`
// returns `null`) rather than reporting a false pass -- see
// [vmServiceUnavailableReason].
//
// **What "steady state" means here, and how it is made a checked
// precondition rather than an assumption:** every query below is warmed
// before its accumulator is reset, because the result scratch (`_scratch`,
// `_instanceScratch`) grows exactly once and that growth is allowed, not
// forbidden. [SpatialIndex.entityScratchCapacity] and
// [SpatialIndex.instanceScratchCapacity] are read before and after the
// timed loop and asserted equal, so "the scratch did not regrow during
// measurement" is checked by the test itself rather than inferred from
// having warmed "enough".
//
// **What is asserted, and what it deliberately is not.** Every test watches
// [_candidateScalingClasses] at a tight, near-zero budget
// ([_perCallBudget]): `Vector2` is the class [SpatialIndex._considerLeaf],
// `_considerSnapLeaf` and `_considerSnapCandidate` construct one of *per
// candidate* for the narrow-phase distance math (see
// `_scratchA`/`_scratchB` and friends in `spatial_index.dart`), and `Aabb2`
// is the other half of the exact bug class this task found and fixed in
// `SpatialIndex._descend` (see below) -- watching one without the other,
// after finding a bug that produced both, would be an unexplained gap, not
// a decision. Neither is expected to appear at all on `forEachInRect`'s or
// `forEachInstanceInRect`'s call path, since neither of those two descends
// into an instance; both are measured near zero there (see the task-17
// report's round-2 section for the numbers).
//
// `pickInto` and `snapInto` do **not** use [_candidateScalingClasses] for
// `Aabb2`, and do not use it at all for `Transform2`. Both share `_descend`,
// whose own doc comment documents two *pre-existing* costs bounded by
// nesting **depth** (times branching), not by candidate count: one `Aabb2`
// per recursion level (the widened local query box `_descend` builds before
// inverting -- `searchLeaves`/`searchInstances` take an `Aabb2` throughout
// this package, so removing this last one would mean widening that API,
// out of this task's scope) and one `Transform2` per instance actually
// descended into (`toWorld.multiply(...)` -- `Transform2` is immutable, so
// composing one can only ever hand back a fresh object; a pre-existing
// closure-pair cost, from Task 12, is the same shape and already documented
// there). Watching either at [_perCallBudget] would fail a correct
// three-level-deep pick for a reason unrelated to what this file exists to
// catch -- a per-*candidate* allocation, the kind that scales with document
// size, not with how deep one instance happens to be nested inside another.
//
// That is an argument for *tolerating* the cost, not a license to leave it
// unbounded: [_depthBoundClasses] gives both a real ceiling, watched by the
// `pickInto`/`snapInto` tests at [_depthBoundBudgets] instead of
// [_perCallBudget] -- wide enough to comfortably admit the current, measured
// cost. **This ceiling is not confirmed, by mutation, to catch a doubling
// of either class.** Attempting that mutation is what found the trap
// documented on `AllocationMeter.accumulatedInstances` (a second read per
// reset epoch silently returns near-zero) -- fixing it stopped the ceiling
// from reading a false near-zero unconditionally, but a *separate* effect
// remained: a genuine, ground-truth-counter-confirmed second Transform2
// construction placed in the same hot loop as the pre-existing one was
// only partially visible to the profiler (roughly +1 per call measured,
// against +3 confirmed by an independent execution counter, for a
// mutation placed to run three times per call). See
// [_depthBoundBudgets]'s own doc comment and the task-17 report's round-2
// section for the numbers and what this does and does not mean for the
// budget below. The budget is real and admits the true, measured cost; it
// is not proven, the way this file's four candidate-scaling assertions are
// proven by mutation, to fail on a doubling specifically.
//
// A clean reading proves the JIT observed no such per-candidate `Vector2`
// or `Aabb2` on this run, on this machine, and no more than the documented,
// bounded depth cost of either on `pickInto`/`snapInto`; it does not prove
// the same holds under AOT, nor that no allocation of some entirely
// different, unwatched class occurred -- see `vm_allocation_meter.dart`'s
// file comment for the full statement of that caveat.
//
// **Runtime added:** roughly 1-2 seconds when the VM service is reachable
// (four allocation tests, each warming ~20,000 calls and timing 1,000 more,
// plus one connect per test file), well under a second when it is not (every
// test skips after one failed connect attempt). The differential corpus this
// sits beside runs in about 2.1s on its own.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'vm_allocation_meter.dart';

/// Watched by `forEachInRect` and `forEachInstanceInRect`, at
/// [_perCallBudget]: the shape of a per-*candidate* allocation. See the
/// file doc comment for why `Vector2` and `Aabb2`, and not `Transform2` or
/// a generic collection class such as `List`.
///
/// **Not used by `pickInto`/`snapInto`**, which watch
/// [_recursiveCandidateScalingClasses] (`Vector2` alone) at the same tight
/// budget instead: both share `SpatialIndex._descend`, which allocates one
/// `Aabb2` per recursion level regardless of candidate count (see
/// [_depthBoundClasses]) -- including `Aabb2` here for those two methods
/// would fail a correct three-level-deep pick on the pre-existing,
/// depth-bound cost, not on a per-candidate regression.
const _candidateScalingClasses = {'Vector2', 'Aabb2'};

/// Watched by `pickInto`/`snapInto` at [_perCallBudget] -- see
/// [_candidateScalingClasses]'s own doc comment for why those two use this
/// narrower set instead of it.
const _recursiveCandidateScalingClasses = {'Vector2'};

/// A per-call instance count admitting real JIT/VM-service noise (measured
/// at roughly 0.02 `Vector2` and 0.002 `Aabb2` per call on this machine,
/// well over an order of magnitude below this) but not a per-candidate or
/// per-call object: even the smallest fixture in this file has enough
/// candidates that a genuine violation shows up at 1 or more per call, not
/// a fraction of one.
const double _perCallBudget = 0.5;

/// Watched only by the `pickInto`/`snapInto` tests, at [_depthBoundBudgets]
/// rather than [_perCallBudget] -- see the file doc comment for why `Aabb2`
/// and `Transform2` are real, pre-existing, depth-bound (not
/// candidate-bound) costs of `SpatialIndex._descend` on those two methods
/// specifically, not a per-candidate allocation this file's tight budget
/// targets elsewhere.
const _depthBoundClasses = {'Aabb2', 'Transform2'};

/// Per-class ceilings for [_depthBoundClasses], on this file's own
/// three-instance-deep, 64-candidate fixture (`_deepNestedDocument`).
///
/// Measured directly on this machine, by setting each budget to a value
/// nothing can pass and reading the number the failure reports back:
///
/// | | `pickInto` | `snapInto` |
/// |---|---|---|
/// | `Aabb2` | 4.004 | 0.484 |
/// | `Transform2` | 7.007 | 0.836 |
///
/// `pickInto`'s numbers are the derivation exactly: `Aabb2` is one widened
/// query box per recursion level (four containers on this fixture's path:
/// root, D1, D2, D3); `Transform2` is one `toWorld.invert()` per level
/// (four) plus one `toWorld.multiply(...)` per instance actually descended
/// into (three), for seven. The budgets below sit at roughly 1.4-1.7x that.
///
/// **`snapInto` reads an order of magnitude lower than `pickInto` for the
/// same walk, and that is a profiler artefact, not a saving.** The two share
/// `_descend` and construct the same objects at the same points; the
/// difference appeared when the query-box construction moved into
/// `_localQueryBox` and the snap path started handing the box to a fused
/// search, which evidently lets the VM scalar-replace what it could not
/// before. It is the same class of mis-attribution this file already records
/// under "what is not confirmed by mutation" below -- the profiler is
/// trustworthy for catching an order-of-magnitude regression and is not a
/// precise object counter. Do not read `snapInto`'s 0.484 as a guarantee.
///
/// **These numbers moved once already, for a real reason.** `snapInto`
/// previously measured 5.004 `Aabb2`/call: four depth-bound boxes plus one
/// flat per-call box built by `_considerIntersections`, which is now built
/// from four loose doubles instead. An earlier version of this doc comment
/// claimed "roughly 3.2-4.5 `Aabb2`" and was outside its own stated range
/// for that method the whole time, because nothing re-measured it after the
/// intersection pass was added.
///
/// **What this budget is, and is not, confirmed to catch.** A regression
/// that turns either cost from depth-bound into candidate-bound -- the
/// realistic failure mode, and the one this budget exists for -- is
/// *expected* to read in the dozens or hundreds per call against a
/// 64-candidate fixture, far past either ceiling, by the same reasoning
/// this file's four candidate-scaling mutations demonstrate directly (see
/// the task-17 report's mutation table). That expectation is **not**
/// itself confirmed by a mutation placed at this exact depth-bound site,
/// for the same reason the doubling attempt below was inconclusive: this
/// investigation found that a *second* allocation of an already-counted
/// class, placed in the same hot loop as the first, can be undercounted by
/// this profiler. A per-candidate mutation here was not separately tried
/// to rule that out. What is **not** confirmed by mutation is a clean
/// doubling of either class specifically: attempting that (see the
/// task-17 report's round-2 section) surfaced a real trap in
/// `AllocationMeter.accumulatedInstances` (now fixed -- see its own doc
/// comment) and, after fixing it, a second effect that was not: a second
/// `Transform2` construction added to the same hot loop as the pre-existing
/// one, confirmed by an independent execution counter to run three times
/// per call, showed up in the allocation profile as only roughly one extra
/// instance per call, not three. The object was genuinely constructed each
/// time (confirmed by reading it back) but the profiler did not attribute
/// all of it. This budget is real and the measured baseline is real;
/// "doubles the per-level cost specifically" is not a mutation this file's
/// table can honestly claim to have caught.
const _depthBoundBudgets = {'Aabb2': 7.0, 'Transform2': 10.0};

/// A document of [count] line entities on a grid near the origin, root
/// level only. Matches the task-17 brief's own `largeDocument` fixture,
/// used here for [forEachInRect] and the over-wide-broad-phase check.
DraftDocument _largeFlatDocument(int count) {
  final doc = DraftDocument.empty();
  final side = math.sqrt(count).ceil();
  for (var i = 0; i < count; i++) {
    final x = (i % side).toDouble();
    final y = (i ~/ side).toDouble();
    doc.commands.execute(AddEntityCommand(
      record: EntityRecord(
        handle: doc.handleSeed.next(),
        owner: doc.rootHandle,
        kind: EntityKind.line,
        layer: ReservedHandles.layerZero,
        linetype: ReservedHandles.byLayerLinetype,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: const ByLayerColor(),
        lineweight: kByLayer,
        transparency: kByLayer,
        flags: 0,
      ),
      payload: GeometryPayload(
        coords: Float64List.fromList([x, y, x + 0.5, y + 0.5]),
        scalars: Float64List(0),
      ),
    ));
  }
  return doc;
}

/// [count] root-level instances of one shared definition, spread on a grid
/// -- unlike [_largeFlatDocument], `forEachInstanceInRect` reports
/// *instances*, not entities, so its fixture needs to actually contain some.
DraftDocument _manyRootInstancesDocument(int count) {
  final doc = DraftDocument.empty();
  final defHandle = doc.handleSeed.next();
  doc.tree.addDefinition(Definition(
    handle: defHandle,
    name: 'Shared',
    basePoint: Vector2.zero(),
    children: const [],
  ));
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: doc.handleSeed.next(),
      owner: defHandle,
      kind: EntityKind.line,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByLayerColor(),
      lineweight: kByLayer,
      transparency: kByLayer,
      flags: 0,
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList([0, 0, 1, 1]),
      scalars: Float64List(0),
    ),
  ));

  final side = math.sqrt(count).ceil();
  for (var i = 0; i < count; i++) {
    final x = (i % side) * 5.0;
    final y = (i ~/ side) * 5.0;
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: doc.handleSeed.next(),
      parent: doc.rootHandle,
      transform: Transform2.translation(x, y),
      definition: defHandle,
      layer: ReservedHandles.layerZero,
    )));
  }
  return doc;
}

/// Three instance boundaries deep -- root -> instance(D1) -> instance(D2) ->
/// instance(D3) -> leaf -- the same shape as `deepInstances` in
/// `corpus.dart`, right down to mixing a rotation into the composition
/// (translations alone commute, so an all-translation chain cannot
/// distinguish a correct composition order from a reversed one -- see that
/// fixture's own comment). This harness does not reuse `corpus.dart`'s
/// builder directly: that fixture places exactly one leaf entity, which is
/// enough to pin the *correctness* of a three-level composition but not
/// enough to distinguish a **per-recursion** cost from a **per-candidate**
/// one -- with only one candidate ever presented to the narrow phase, the
/// two are the same number. [leafCount] entities at the deepest level, laid
/// out so a single pick/snap query at the shared centre point sees more
/// than one of them as a broad-phase candidate, is what makes that
/// distinction observable: a deliberately-reintroduced per-candidate
/// allocation (see this file's mutation table in the task-17 report) scales
/// with [leafCount], while the pre-existing, depth-bound closure/Transform2
/// cost documented on `SpatialIndex._descend` does not.
({DraftDocument doc, Vector2 point, double radius}) _deepNestedDocument(
    int leafCount) {
  final doc = DraftDocument.empty();

  final d3 = doc.handleSeed.next();
  doc.tree.addDefinition(Definition(
      handle: d3, name: 'D3', basePoint: Vector2.zero(), children: const []));
  final side = math.sqrt(leafCount).ceil();
  for (var i = 0; i < leafCount; i++) {
    final x = (i % side) * 2.0;
    final y = (i ~/ side) * 2.0;
    doc.commands.execute(AddEntityCommand(
      record: EntityRecord(
        handle: doc.handleSeed.next(),
        owner: d3,
        kind: EntityKind.line,
        layer: ReservedHandles.layerZero,
        linetype: ReservedHandles.byLayerLinetype,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: const ByLayerColor(),
        lineweight: kByLayer,
        transparency: kByLayer,
        flags: 0,
      ),
      payload: GeometryPayload(
        coords: Float64List.fromList([x, y, x + 1, y + 1]),
        scalars: Float64List(0),
      ),
    ));
  }

  final d2 = doc.handleSeed.next();
  doc.tree.addDefinition(Definition(
      handle: d2, name: 'D2', basePoint: Vector2.zero(), children: const []));
  doc.commands.execute(AddNodeCommand(InstanceNode(
    handle: doc.handleSeed.next(),
    parent: d2,
    transform: Transform2.rotation(0.6).multiply(Transform2.translation(4, 0)),
    definition: d3,
    layer: ReservedHandles.layerZero,
  )));

  final d1 = doc.handleSeed.next();
  doc.tree.addDefinition(Definition(
      handle: d1, name: 'D1', basePoint: Vector2.zero(), children: const []));
  doc.commands.execute(AddNodeCommand(InstanceNode(
    handle: doc.handleSeed.next(),
    parent: d1,
    transform: Transform2.translation(0, 4),
    definition: d2,
    layer: ReservedHandles.layerZero,
  )));

  doc.commands.execute(AddNodeCommand(InstanceNode(
    handle: doc.handleSeed.next(),
    parent: doc.rootHandle,
    transform:
        Transform2.scale(1.5, 1.5).multiply(Transform2.translation(10, 10)),
    definition: d1,
    layer: ReservedHandles.layerZero,
  )));

  // Centre of D3's own leaf grid, mapped through the same three transforms
  // by hand (scale ∘ translate(10,10)) ∘ translate(0,4) ∘ (rotate(0.6) ∘
  // translate(4,0)) applied to the grid centre, matching Transform2
  // .multiply's own "argument applied first" convention -- rather than
  // trusting a single big pick to land, the composition itself is spelled
  // out so a mistake here reads as a wrong `point`, not a mysterious "no
  // hit" from the query under test.
  final gridCentre = Vector2((side - 1) * 1.0, (side - 1) * 1.0);
  final whole = Transform2.scale(1.5, 1.5)
      .multiply(Transform2.translation(10, 10))
      .multiply(Transform2.translation(0, 4))
      .multiply(
          Transform2.rotation(0.6).multiply(Transform2.translation(4, 0)));
  final point = whole.transformPoint(gridCentre);
  // Wide enough to reach every leaf in D3's grid from its centre, so the
  // narrow phase actually has [leafCount] candidates to consider, not one.
  final radius = side * 3.0;
  return (doc: doc, point: point, radius: radius);
}

void main() {
  AllocationMeter? meter;

  setUpAll(() async {
    meter = await AllocationMeter.connect();
  });

  tearDownAll(() async {
    await meter?.dispose();
  });

  test('forEachInRect does not allocate in steady state', () async {
    final m = meter;
    if (m == null) {
      markTestSkipped(vmServiceUnavailableReason);
      return;
    }
    final doc = _largeFlatDocument(50000);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    // Small enough to keep the warm-up loop fast (tens of matches, not the
    // thousands a rect spanning a tenth of the document would touch) while
    // still nonzero -- see the `count` assertion below.
    final rect = Aabb2(Vector2(0, 0), Vector2(10, 10));

    var count = 0;
    void visit(int _) => count++;

    // Warm: the result scratch grows here, once, and that growth is
    // allowed. 20,000 rather than the brief's illustrative 10: a JIT needs
    // real trip counts to reach its optimised tier, and measuring before it
    // gets there was observed (see vm_allocation_meter.dart) to pick up
    // ongoing recompilation noise unrelated to the query itself.
    for (var i = 0; i < 20000; i++) {
      index.forEachInRect(rect, const QueryFilter.rendering(), visit);
    }
    final capacityBefore = index.entityScratchCapacity;
    expect(count, greaterThan(0),
        reason: 'the fixture must actually match something, or this test '
            'would pass by never exercising the narrow phase at all');

    await m.reset();
    const iters = 1000;
    for (var i = 0; i < iters; i++) {
      index.forEachInRect(rect, const QueryFilter.rendering(), visit);
    }
    final accumulated = await m.accumulatedInstances(_candidateScalingClasses);

    expect(index.entityScratchCapacity, capacityBefore,
        reason: 'steady state is a checked precondition here: the scratch '
            'must not have regrown during the measured loop, or a capacity '
            'change rather than a per-call object could explain any '
            'allocation seen');
    for (final entry in accumulated.entries) {
      expect(entry.value / iters, lessThan(_perCallBudget),
          reason: '${entry.key}: ${entry.value} instances accumulated over '
              '$iters calls (${entry.value / iters} per call) -- a per-call '
              'or per-candidate allocation would scale with iteration count '
              'and candidate count, both far above this budget');
    }
  });

  test('forEachInstanceInRect does not allocate in steady state', () async {
    final m = meter;
    if (m == null) {
      markTestSkipped(vmServiceUnavailableReason);
      return;
    }
    final doc = _manyRootInstancesDocument(5000);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    // Small relative to the full grid (5000 instances spaced 5 units apart
    // spans roughly 350 units per side) so the warm-up loop stays fast.
    final rect = Aabb2(Vector2(0, 0), Vector2(20, 20));

    var count = 0;
    void visit(Handle _) => count++;

    for (var i = 0; i < 20000; i++) {
      index.forEachInstanceInRect(rect, const QueryFilter.rendering(), visit);
    }
    final capacityBefore = index.instanceScratchCapacity;
    expect(count, greaterThan(0),
        reason: 'the fixture must actually match something, or this test '
            'would pass by never exercising the narrow phase at all');

    await m.reset();
    const iters = 1000;
    for (var i = 0; i < iters; i++) {
      index.forEachInstanceInRect(rect, const QueryFilter.rendering(), visit);
    }
    final accumulated = await m.accumulatedInstances(_candidateScalingClasses);

    expect(index.instanceScratchCapacity, capacityBefore,
        reason: 'steady state is a checked precondition here: the scratch '
            'must not have regrown during the measured loop');
    for (final entry in accumulated.entries) {
      expect(entry.value / iters, lessThan(_perCallBudget),
          reason: '${entry.key}: ${entry.value / iters} per call over '
              '$iters calls');
    }
  });

  test('pickInto does not allocate in steady state, three instances deep',
      () async {
    final m = meter;
    if (m == null) {
      markTestSkipped(vmServiceUnavailableReason);
      return;
    }
    final fixture = _deepNestedDocument(64);
    final index = SpatialIndex(fixture.doc);
    addTearDown(index.dispose);
    final hit = HitPath(32);

    for (var i = 0; i < 20000; i++) {
      index.pickInto(
          fixture.point, fixture.radius, const QueryFilter.picking(), hit);
    }
    expect(hit.chainLength, 3,
        reason: 'this fixture exists specifically to exercise a pick that '
            'descends three instance boundaries deep -- see this file\'s '
            'own comment on _deepNestedDocument for why a root-only fixture '
            'cannot distinguish the per-recursion cost SpatialIndex._descend '
            'already documents from a per-candidate one');

    await m.reset();
    const iters = 1000;
    for (var i = 0; i < iters; i++) {
      index.pickInto(
          fixture.point, fixture.radius, const QueryFilter.picking(), hit);
    }
    // One combined call, not two: AllocationMeter.accumulatedInstances can
    // only be called once per reset() epoch -- see its own doc comment.
    // Every class this test needs a reading for, candidate-scaling and
    // depth-bound alike, is requested together here.
    final counts = await m.accumulatedInstances(
        {..._recursiveCandidateScalingClasses, ..._depthBoundClasses});

    // No entityScratchCapacity/instanceScratchCapacity assertion here,
    // unlike the two tests above: pickInto's own per-recursion-level scratch
    // (`_levelScratch`, `_instancePath`, `_containerPath` in
    // spatial_index.dart) is not exposed by any public getter, so "did the
    // scratch regrow" is not a checked precondition this test can state for
    // pickInto the way it can for the two rect queries above -- an honest
    // gap, not an oversight; see the task-17 report.
    for (final name in _recursiveCandidateScalingClasses) {
      final value = counts[name]!;
      expect(value / iters, lessThan(_perCallBudget),
          reason: '$name: ${value / iters} per call over $iters calls, '
              'against a fixture with 64 leaf candidates -- a per-candidate '
              'allocation here would be two orders of magnitude above this '
              'budget, not a fraction of an instance');
    }
    for (final name in _depthBoundClasses) {
      final value = counts[name]!;
      expect(value / iters, lessThan(_depthBoundBudgets[name]!),
          reason: '$name: ${value / iters} per call over $iters calls -- '
              'bounded, not zero-budgeted, because this is the depth-bound '
              'cost SpatialIndex._descend documents, not a per-candidate '
              'one; see this file\'s own doc comment and _depthBoundBudgets '
              'for the reasoning and the numbers');
    }
  });

  test('snapInto does not allocate in steady state, three instances deep',
      () async {
    final m = meter;
    if (m == null) {
      markTestSkipped(vmServiceUnavailableReason);
      return;
    }
    final fixture = _deepNestedDocument(64);
    final index = SpatialIndex(fixture.doc);
    addTearDown(index.dispose);
    final out = SnapResult(32);

    for (var i = 0; i < 20000; i++) {
      index.snapInto(fixture.point, fixture.radius, SnapMask.all, out);
    }
    expect(out.found, isTrue);
    expect(out.chainLength, 3,
        reason: 'same reasoning as the pickInto test above: this fixture '
            'must actually be reached three instances deep');

    await m.reset();
    const iters = 1000;
    for (var i = 0; i < iters; i++) {
      index.snapInto(fixture.point, fixture.radius, SnapMask.all, out);
    }
    // One combined call, not two -- see the pickInto test above.
    final counts = await m.accumulatedInstances(
        {..._recursiveCandidateScalingClasses, ..._depthBoundClasses});

    for (final name in _recursiveCandidateScalingClasses) {
      final value = counts[name]!;
      expect(value / iters, lessThan(_perCallBudget),
          reason: '$name: ${value / iters} per call over $iters calls -- '
              'SnapMask.all is the strictest mask, enabling the pairwise '
              'intersection pass on top of every per-candidate channel '
              'pickInto also runs');
    }
    for (final name in _depthBoundClasses) {
      final value = counts[name]!;
      expect(value / iters, lessThan(_depthBoundBudgets[name]!),
          reason: '$name: ${value / iters} per call over $iters calls -- '
              'bounded, not zero-budgeted; same reasoning as the pickInto '
              'test above');
    }
  });

  // --- over-wide broad phase --------------------------------------------

  test(
      'pickInto stays local: an over-wide broad phase would blow the time '
      'budget', () {
    // Requirement 4 of the task-17 brief: nothing before this test caught
    // `SpatialIndex._broadPhaseMargin` hard-coded to return a huge slack
    // regardless of document contents -- every one of the other 545 tests
    // in this suite passed against that mutation, because it only widens
    // the region pickInto/snapInto search, never what they *find*: the
    // narrow phase still filters correctly, so results stay right and only
    // the amount of tree walked balloons.
    //
    // No allocation-profiler mechanism catches that shape of regression --
    // it is not an allocation at all, it is wasted traversal -- so this one
    // test in the file is timing-based and needs no VM service; it runs
    // unconditionally.
    //
    // **Chosen over a candidate-count assertion** because nothing in this
    // package's public API exposes how many leaves a pick's broad phase
    // actually visits (only what it ultimately reports, which the mutation
    // does not change) or the composed margin `_broadPhaseMargin` computes
    // (private, and deliberately not the same thing as any single
    // container's own `ownNarrowPhaseSlack` -- the mutation replaces the
    // *composition*, not any one container's contribution to it). Timing is
    // what is left, and the gap it has to resolve is not subtle: on this
    // machine, a healthy pick against a 50,000-entity document averaged
    // roughly 3 microseconds; the same pick under the hard-coded-huge-slack
    // mutation averaged roughly 7,800 microseconds -- a ~2,500x difference,
    // because the mutation turns an O(log n + k) tree query into
    // effectively O(n) on every call. The budget below leaves roughly two
    // orders of magnitude of headroom on both sides of that gap.
    //
    // This is a performance regression check, not a correctness one, and it
    // sits here rather than in a future Task 18 throughput gate because it
    // is measuring the exact mechanism (`_broadPhaseMargin`) this task's
    // brief named by name as uncaught; a throughput gate would catch the
    // symptom (queries got slow) without pointing at this cause.
    final doc = _largeFlatDocument(50000);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final hit = HitPath(32);
    final point = Vector2(5000, 5000);

    for (var i = 0; i < 200; i++) {
      index.pickInto(point, 2.0, const QueryFilter.picking(), hit);
    }
    final stopwatch = Stopwatch()..start();
    const iters = 500;
    for (var i = 0; i < iters; i++) {
      index.pickInto(point, 2.0, const QueryFilter.picking(), hit);
    }
    stopwatch.stop();
    final perCallMicros = stopwatch.elapsedMicroseconds / iters;
    expect(perCallMicros, lessThan(500),
        reason: 'a pick against a 50,000-entity document, near one specific '
            'entity with a small radius, took $perCallMicros microseconds '
            'on average -- a healthy broad phase measured roughly 3us here; '
            'a broad phase widened to cover the whole document measured '
            'roughly 7,800us. This budget sits two orders of magnitude '
            'above the healthy number and more than an order of magnitude '
            'below the degenerate one.');
  });
}
