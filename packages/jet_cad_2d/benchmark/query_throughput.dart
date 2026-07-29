// The query-throughput gate (task-18-brief.md).
//
// Not part of `dart test` -- run manually:
//
//   cd packages/jet_cad_2d && dart run benchmark/query_throughput.dart
//
// Adding a 500k-entity document to the test suite would make it unusable for
// its real job (it runs in a few seconds today); this lives here instead, and
// is the durable, by-hand gate on the index design the plan's own notes say
// it must clear before Plan 3 builds anything on top of it.
//
// Every measurement runs twice: on a freshly built index, and with the dirty
// list at its rebuild threshold. At 500k that threshold is 25k linearly
// scanned entries on *every* query, including pick and snap at pointer-move
// rate. A fresh index is the state a document is in least often -- every
// editing session leaves the dirty list populated -- so measuring only a
// fresh index would let a threshold pass this gate and then fail in real use.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

const int _kWarmupIterations = 20;
const int _kMeasuredIterations = 120; // >= 100, per the brief

/// Half the side of the `forEachInRect` query rectangle. Chosen against
/// [kFloorWidth] x [kFloorHeight] and the default document's entity density
/// so a 500k-entity document returns on the order of 2,000 visible entities
/// -- the brief's own "~2k visible from 500k" description of the scenario
/// being measured, not a value tuned after the fact against this run's
/// actual output.
const double _kQueryHalfWidth = 1550.0;

const double _kPickRadius = 60.0;
const double _kSnapRadius = 100.0;

const double _kRectThresholdMs = 2.0;
const double _kPickThresholdMs = 1.0;
const double _kSnapThresholdMs = 1.0;

/// Only the 500k rows are the brief's actual gate. The 50k rows run the same
/// battery for a second, smaller data point -- useful for sanity-checking
/// that latency scales the way the design predicts -- but are not
/// separately thresholded by the brief's table.
const int _kGatedCount = 500000;

class _Row {
  _Row(this.label, this.count, this.p50Ms, this.p95Ms, this.thresholdMs,
      this.gated);
  final String label;
  final int count;
  final double p50Ms;
  final double p95Ms;
  final double thresholdMs;
  final bool gated;
  bool get pass => p95Ms < thresholdMs;
}

final List<_Row> _rows = [];

void main() {
  _definitionBoundsProbe();

  for (final count in [50000, _kGatedCount]) {
    _runBattery(count);
  }

  _printSummary();
}

// --- the carried-forward definitionBounds measurement -----------------
//
// Not one of the three gated rows. `ContainerIndex.build`'s own memo
// (`definitionBoundsCache`) stops a *repeated* definition from paying twice
// in one build, but with many *distinct* definitions each one's first call
// still cost a full entity-store scan before `DraftDocument.definitionBounds`
// accepted a shared `leavesByOwner` map -- see its doc comment and
// `container_index.dart`'s `boundsOfDefinition`. 2,000 is the case the Task 5
// review recorded as ~35s; see task-18-report.md for this run's own
// before/after numbers, captured by toggling that fix with `git stash`.
void _definitionBoundsProbe() {
  print('--- definitionBounds build-time probe (not a gated row) ---');
  // instanceCount == definitionCount: one instance per definition is enough
  // to make `rebuildAll`'s root-container build visit every distinct
  // definition at least once, which is what makes the per-build memo
  // powerless and the per-call cost of `leavesByOwner()` the whole story.
  final doc =
      generateDocument(32000, definitionCount: 2000, instanceCount: 2000);
  final stopwatch = Stopwatch()..start();
  final index = SpatialIndex(doc);
  stopwatch.stop();
  print('2,000 definitions / 32,000 entities: SpatialIndex(doc) build took '
      '${stopwatch.elapsedMilliseconds}ms (containers=${index.containerCount})');
  print('');
}

// --- the three gated measurements, fresh and at the dirty threshold -----

void _runBattery(int count) {
  final gated = count == _kGatedCount;
  print('=== count = $count ${gated ? '(GATED)' : '(comparison only)'} ===');
  final doc = generateDocument(count);
  final index = SpatialIndex(doc);
  final bounds = index.rootIndex.bounds;

  _reportVisitedCount(index, bounds);

  _reportRect('forEachInRect fresh', count, index, bounds, gated);
  _reportPick('pick fresh', count, index, bounds, gated);
  _reportSnap('snap fresh', count, index, bounds, gated);

  final rebuildBefore = index.rebuildCount;
  final threshold = index.rootIndex.rebuildThreshold;
  _fillDirtyToThreshold(index, doc, threshold);
  // The whole point of this pairing is a dirty list at threshold *without*
  // a rebuild -- a helper that silently tripped one would measure a fresh
  // index twice and report a pass that means nothing. Checked, not assumed.
  if (index.rebuildCount != rebuildBefore) {
    throw StateError('dirty-list filler triggered a rebuild ($rebuildBefore -> '
        '${index.rebuildCount}); the "at threshold" rows below would not '
        'be measuring what they claim to.');
  }
  if (index.rootIndex.dirty.length != threshold) {
    throw StateError('dirty-list filler reached '
        '${index.rootIndex.dirty.length}, expected exactly $threshold.');
  }
  print('dirty list filled to threshold=$threshold; rebuildCount unchanged '
      'at $rebuildBefore.');

  _reportRect('forEachInRect at dirty threshold', count, index, bounds, gated);
  _reportPick('pick at dirty threshold', count, index, bounds, gated);
  _reportSnap('snap at dirty threshold', count, index, bounds, gated);
  print('');
}

/// Fills the root container's dirty list to exactly [threshold] entries by
/// adding new entities through the real command path -- the same way a live
/// editing session accumulates dirty entries after an index has been built.
///
/// A newly added entity's slot was never in the packed tree `rebuildAll`
/// built, so `SpatialIndex._reconcile` routes it onto the dirty overlay
/// rather than finding an unchanged box to compare against — see
/// `_reconcileEntity`'s final branch. `RemoveEntityCommand`/structural edits
/// were considered and rejected: a structural touch (`TransformNodeCommand`
/// and friends) always calls `rebuildAll()` rather than populating the dirty
/// list at all, which is the opposite of what this needs.
void _fillDirtyToThreshold(
    SpatialIndex index, DraftDocument doc, int threshold) {
  final random = math.Random(0xDEED);
  for (var i = 0; i < threshold; i++) {
    final x = kDefaultOriginX + random.nextDouble() * kFloorWidth;
    final y = kOriginY + random.nextDouble() * kFloorHeight;
    final handle = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
      record: EntityRecord(
        handle: handle,
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
        coords: Float64List.fromList([x, y, x + 50.0, y + 50.0]),
        scalars: Float64List(0),
      ),
    ));
  }
}

void _reportVisitedCount(SpatialIndex index, Aabb2 bounds) {
  _visitCount = 0;
  final cx = (bounds.minX + bounds.maxX) / 2;
  final cy = (bounds.minY + bounds.maxY) / 2;
  index.forEachInRect(
      Aabb2.raw(cx - _kQueryHalfWidth, cy - _kQueryHalfWidth,
          cx + _kQueryHalfWidth, cy + _kQueryHalfWidth),
      const QueryFilter.rendering(),
      _countVisit);
  print('  (sample forEachInRect at document centre visited $_visitCount '
      'entities)');
}

int _visitCount = 0;
void _countVisit(int slot) => _visitCount++;

void _reportRect(
    String label, int count, SpatialIndex index, Aabb2 bounds, bool gated) {
  final total = _kWarmupIterations + _kMeasuredIterations;
  final cx = _randomAxis(bounds.minX, bounds.maxX, _kQueryHalfWidth, total, 11);
  final cy = _randomAxis(bounds.minY, bounds.maxY, _kQueryHalfWidth, total, 12);
  const filter = QueryFilter.rendering();
  final samples = _timeMs(total, (i) {
    index.forEachInRect(
        Aabb2.raw(cx[i] - _kQueryHalfWidth, cy[i] - _kQueryHalfWidth,
            cx[i] + _kQueryHalfWidth, cy[i] + _kQueryHalfWidth),
        filter,
        _countVisit);
  });
  _report(label, count, samples, _kRectThresholdMs, gated);
}

final HitPath _hitOut = HitPath();
final Vector2 _pickWorld = Vector2.zero();

void _reportPick(
    String label, int count, SpatialIndex index, Aabb2 bounds, bool gated) {
  final total = _kWarmupIterations + _kMeasuredIterations;
  final cx = _randomAxis(bounds.minX, bounds.maxX, _kPickRadius, total, 21);
  final cy = _randomAxis(bounds.minY, bounds.maxY, _kPickRadius, total, 22);
  const filter = QueryFilter.picking();
  final samples = _timeMs(total, (i) {
    _pickWorld.setValues(cx[i], cy[i]);
    index.pickInto(_pickWorld, _kPickRadius, filter, _hitOut);
  });
  _report(label, count, samples, _kPickThresholdMs, gated);
}

final SnapResult _snapOut = SnapResult();
final Vector2 _snapWorld = Vector2.zero();

void _reportSnap(
    String label, int count, SpatialIndex index, Aabb2 bounds, bool gated) {
  final total = _kWarmupIterations + _kMeasuredIterations;
  final cx = _randomAxis(bounds.minX, bounds.maxX, _kSnapRadius, total, 31);
  final cy = _randomAxis(bounds.minY, bounds.maxY, _kSnapRadius, total, 32);
  final samples = _timeMs(total, (i) {
    _snapWorld.setValues(cx[i], cy[i]);
    // "All kinds": SnapMask.all, including `intersection`, the most
    // expensive channel -- the gate gets the worst case, not the common one.
    index.snapInto(_snapWorld, _kSnapRadius, SnapMask.all, _snapOut);
  });
  _report(label, count, samples, _kSnapThresholdMs, gated);
}

List<double> _randomAxis(
    double min, double max, double margin, int n, int seed) {
  final random = math.Random(seed);
  final span = (max - min) - 2 * margin;
  if (span <= 0) {
    // The document is smaller than the query shape on this axis -- centre
    // every sample rather than producing a negative-width range.
    final centre = (min + max) / 2;
    return List<double>.filled(n, centre);
  }
  return List<double>.generate(
      n, (_) => min + margin + random.nextDouble() * span);
}

List<double> _timeMs(int total, void Function(int i) run) {
  final samples = <double>[];
  for (var i = 0; i < total; i++) {
    final stopwatch = Stopwatch()..start();
    run(i);
    stopwatch.stop();
    if (i >= _kWarmupIterations) {
      samples.add(stopwatch.elapsedMicroseconds / 1000.0);
    }
  }
  samples.sort();
  return samples;
}

double _percentile(List<double> sorted, double p) {
  if (sorted.isEmpty) return double.nan;
  final index = ((sorted.length - 1) * p).round();
  return sorted[index];
}

void _report(String label, int count, List<double> samplesMs,
    double thresholdMs, bool gated) {
  final p50 = _percentile(samplesMs, 0.50);
  final p95 = _percentile(samplesMs, 0.95);
  final row = _Row(label, count, p50, p95, thresholdMs, gated);
  _rows.add(row);
  final verdict = gated ? (row.pass ? 'PASS' : 'FAIL') : '(not gated)';
  print('  $label: p50=${p50.toStringAsFixed(4)}ms '
      'p95=${p95.toStringAsFixed(4)}ms '
      '(n=${samplesMs.length}, threshold<${thresholdMs}ms) $verdict');
}

void _printSummary() {
  print('=== summary (gated rows only, count=$_kGatedCount) ===');
  var allPass = true;
  for (final row in _rows.where((r) => r.gated)) {
    final verdict = row.pass ? 'PASS' : 'FAIL';
    if (!row.pass) allPass = false;
    print('  ${row.label.padRight(32)} p50=${row.p50Ms.toStringAsFixed(4)}ms '
        'p95=${row.p95Ms.toStringAsFixed(4)}ms  threshold<'
        '${row.thresholdMs}ms  $verdict');
  }
  print('');
  print(allPass
      ? 'GATE: PASS -- every gated row is under its threshold.'
      : 'GATE: FAIL -- at least one gated row missed its threshold. Per '
          'task-18-brief.md, the index design returns to Plan 2.');
}
