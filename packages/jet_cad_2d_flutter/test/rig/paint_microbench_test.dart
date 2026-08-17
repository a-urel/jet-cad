@Tags(['rig'])
library;

// R1 — paint microbench, and R3 — query-only.
//
// R1 runs under `flutter test`: debug JIT, and `PictureRecorder` records
// without rasterising. It is a RELATIVE regression signal only. It is not
// comparable to R2's profile-mode numbers and cannot see raster cost. Do not
// mix the two in the results note.
//
// These print; they do not assert. A rig that fails the build on a slow
// machine teaches people to ignore it.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'rig_support.dart';

class Stats {
  Stats(this.p50, this.p95, this.min, this.n);
  final double p50;
  final double p95;
  final double min;
  final int n;

  @override
  String toString() => 'p50=${p50.toStringAsFixed(3)}ms '
      'p95=${p95.toStringAsFixed(3)}ms min=${min.toStringAsFixed(3)}ms (n=$n)';
}

/// 20 warm-up iterations then up to 120 measured, the same shape as
/// `benchmark/query_throughput.dart` so the two are read the same way.
///
/// Capped by a wall-clock budget as well, and the sample count is printed. A
/// paint over the whole 500k document takes about a second, so 140 of them is
/// three minutes for one row; a rig nobody runs measures nothing. Below 12
/// samples a p95 is one reading, so the floor is enforced over the budget.
Stats measure(void Function() body,
    {Duration budget = const Duration(seconds: 20)}) {
  for (var i = 0; i < 20; i++) {
    body();
  }
  final samples = <double>[];
  final clock = Stopwatch()..start();
  for (var i = 0; i < 120; i++) {
    final sw = Stopwatch()..start();
    body();
    sw.stop();
    samples.add(sw.elapsedMicroseconds / 1000.0);
    if (samples.length >= 12 && clock.elapsed > budget) break;
  }
  samples.sort();
  return Stats(samples[(samples.length * 0.50).floor()],
      samples[(samples.length * 0.95).floor()], samples.first, samples.length);
}

void main() {
  for (final entityCount in [50000, 500000]) {
    test('paint and query at $entityCount', () {
      final build = Stopwatch()..start();
      final doc = rigCorpus(entityCount);
      final docMs = build.elapsedMilliseconds;
      final index = SpatialIndex(doc);
      final indexMs = build.elapsedMilliseconds - docMs;

      final painter = DraftPainter(
          document: doc, index: index, resolver: DocumentStyleResolver(doc));

      print('=== $entityCount entities ===');
      print('  corpus: doc=${docMs}ms index=${indexMs}ms '
          'entities=${doc.entities.liveCount} nodes=${doc.tree.nodes.length} '
          'definitions=${doc.tree.definitions.length}');

      // Two cameras, because one of them answers a different question. `fit`
      // draws the whole drawing and is the worst case; the working set is what
      // a frame budget is actually about.
      for (final (label, camera) in [
        ('whole drawing', wholeDrawingCamera(doc)),
        ('working set', workingSetCamera(doc)),
      ]) {
        final paint = measure(() {
          final recorder = PictureRecorder();
          painter.paint(
              CanvasDrawSink(
                  canvas: Canvas(recorder),
                  pixelsPerPaperMm: kLogicalPixelsPerMm),
              camera,
              kRigViewport);
          recorder.endRecording().dispose();
        });

        final sink = NullDrawSink();
        final before = sink.opCount;
        final query = measure(() => painter.paint(sink, camera, kRigViewport));
        final opsPerFrame = (sink.opCount - before) ~/ (query.n + 20);

        // One more, untimed: a single CanvasDrawSink run, alongside the
        // NullDrawSink one above, so canvasCalls and the dash counters
        // describe the same frame this row's other counters came from.
        final canvasRecorder = PictureRecorder();
        final canvasSink = CanvasDrawSink(
            canvas: Canvas(canvasRecorder),
            pixelsPerPaperMm: kLogicalPixelsPerMm);
        painter.paint(canvasSink, camera, kRigViewport);
        canvasRecorder.endRecording().dispose();

        print('  -- $label --');
        print('    R1 paint          $paint');
        print('    R3 query-only     $query');
        print('    ops/frame: $opsPerFrame');
        print('    screen-space leaves: ${painter.screenSpaceLeafCount}  '
            'anisotropic curves: ${painter.anisotropicCurveCount}');
        print('    skipped text: ${painter.skippedTextCount}  '
            'skipped deep instances: ${painter.skippedDeepInstanceCount}');
        print('    canvasCalls: ${canvasSink.canvasCallCount}  '
            'dashSpans: ${painter.dashSpanCount}  '
            'collapsed: ${painter.collapsedDashCount}');
      }

      index.dispose();
    }, timeout: const Timeout(Duration(minutes: 10)));
  }
}
