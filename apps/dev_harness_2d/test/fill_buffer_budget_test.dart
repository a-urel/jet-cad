// Plan D, Task 9 -- the resident geometry buffer's size, measured on the CPU.
//
// **This is not a device run.** `GeometryCollector` builds the buffer that
// would be uploaded to the GPU entirely on the CPU -- the upload itself
// (`ResidentGeometry.create`) is the only step this test does not take, and
// it does not change the buffer's byte length, only where the bytes live.
// So `flutter test` measures the exact number `--dart-define=RUN_GPU_SPIKE`
// would report on a device, without a device: this test's own corpus, camera
// and collector calls are the same three lines `GpuSpikeState
// ._buildResidentGeometry` in `gpu_arm.dart` makes.
//
// ignore_for_file: avoid_print -- the measurement below is meant to be read
// off a `flutter test` transcript, the same convention `gpu_arm.dart`'s
// GSPIKE lines use.

import 'dart:typed_data';

import 'package:dev_harness_2d/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

/// Mirrors `packages/jet_cad_2d_flutter/lib/src/gpu/instance_record.dart`'s
/// wire format, which that file's own barrel comment keeps unexported
/// deliberately -- "`GeometryCollector`'s own wire format, not something a
/// caller writes." A reader belongs there for anything that changes the
/// layout; this is a read-only copy for one measurement, not a second
/// producer of instances.
///
/// `kFloatsPerInstance = 16` and the four kind tags (`0` stroke, `1` join,
/// `2` point, `3` fill) are declared `const` in that file and are exactly
/// the numbers this task's own brief cites ("16 floats x 4 bytes per
/// instance").
const int _kFloatsPerInstance = 16;
const int _kKindOffset = 0;
const double _kKindStroke = 0;
const double _kKindJoin = 1;
const double _kKindPoint = 2;
const double _kKindFill = 3;

/// One entity count the whole task's measurement is taken at -- Step 2's own
/// number, and the one Plan C's 105,076-instance / 6.41 MB figure is compared
/// against.
const int _kMeasuredEntities = 10000;

void main() {
  test(
      'the resident buffer at 10,000 entities with fills, measured on the '
      'CPU', () {
    // The same corpus `spikeDocument()` builds for a real
    // `--dart-define=RUN_GPU_SPIKE=true --dart-define=ENTITIES=10000
    // --dart-define=SPIKE_FILLS=true` run -- entity count and
    // `fillsEnabled` passed directly rather than through a define, so this
    // number is fixed by the test rather than by however the binary happened
    // to be launched. `SPIKE_DEFS` and `SPIKE_INSTANCES` are left at their
    // own defaults (20, 200), matching an unqualified run of the command
    // above.
    final doc =
        spikeDocument(entityCount: _kMeasuredEntities, fillsEnabled: true);
    final liveEntities = doc.entities.liveSlots.length;

    // The same three calls `GpuSpikeState._buildResidentGeometry` makes in
    // `gpu_arm.dart`, up to and not including `ResidentGeometry.create` --
    // the CPU-side buffer this test measures is `collector.data`, the exact
    // bytes that call would upload.
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final camera = ViewportTransform.fit(doc.extents, kMeasurementViewport);
    final painter = DraftPainter(
      document: doc,
      index: index,
      resolver: DocumentStyleResolver(doc),
      drawText: true,
    );
    final collector = GeometryCollector(
      pixelsPerPaperMm: kLogicalPixelsPerMm,
      devicePixelRatio: 1.0,
      lineweightScale: 1.0,
    );
    painter.paint(collector, camera, kMeasurementViewport);

    final data = collector.data;
    final instances = collector.instanceCount;
    expect(data.length, instances * _kFloatsPerInstance,
        reason: 'the buffer must hold exactly one record per instance, no '
            'slack past _instances');

    var strokes = 0, joins = 0, points = 0, fills = 0, other = 0;
    for (var i = 0; i < instances; i++) {
      final kind = data[i * _kFloatsPerInstance + _kKindOffset];
      if (kind == _kKindStroke) {
        strokes++;
      } else if (kind == _kKindJoin) {
        joins++;
      } else if (kind == _kKindPoint) {
        points++;
      } else if (kind == _kKindFill) {
        fills++;
      } else {
        other++;
      }
    }
    expect(other, 0,
        reason: 'every instance must carry one of the four '
            'known kind tags');
    expect(fills, greaterThan(0),
        reason: 'fillsEnabled: true must actually reach the collector as '
            'fill instances, or this measurement is vacuous for the one '
            'thing Task 9 adds');

    final bytes = instances * _kFloatsPerInstance * Float32List.bytesPerElement;
    const budgetBytes = 8 * 1024 * 1024;
    final mb = bytes / (1024 * 1024);

    print('PLAN-D buffer: entities=$liveEntities (requested '
        '$_kMeasuredEntities) instances=$instances '
        '(strokes=$strokes joins=$joins points=$points fills=$fills) '
        'skippedOps=${collector.skippedOps} '
        'bytes=$bytes (${mb.toStringAsFixed(2)} MB) '
        'budget=${(budgetBytes / (1024 * 1024)).toStringAsFixed(2)} MB '
        'margin=${(budgetBytes - bytes)} bytes');

    // **Not gated against 8 MB here.** The brief is explicit: "if it exceeds
    // 8 MB, record a miss with its number -- the threshold does not move to
    // make a criterion pass." A `flutter test` assertion that failed past the
    // budget would make the criterion self-enforcing rather than measured
    // and reported, which is the opposite of what a miss is supposed to look
    // like in this project. The PASS/MISS verdict is written by hand into
    // `docs/superpowers/notes/2026-09-01-plan-d-results.md` from the number
    // printed above.
  });
}
