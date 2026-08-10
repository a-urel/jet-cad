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
import 'package:jet_cad_2d/testing.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2, Colors;

const Size kRigViewport = Size(1600, 1200);

/// Root instances per document, held fixed across both entity counts.
///
/// **Not the plan's `definitionCount: entityCount ~/ 25`.** That asks for
/// 20,000 definitions and 500,000 root instances at the large size, and the
/// document never finishes building: `DocumentTree._link` scans and copies the
/// parent's `children` list on every add, so filling one parent is quadratic in
/// its child count. Measured on this machine, at 50,000 entities: 6,250
/// instances 236 ms, 12,500 → 532 ms, 25,000 → 2,684 ms, 50,000 → 15,767 ms —
/// four times the instances, thirty times the time. Loading a file does not go
/// through it (`DraftDocumentCodec` uses `addNodeUnchecked`), so this is the
/// command path only, and fixing it means changing how a node holds its
/// children. Recorded for a later plan; the rig works around it.
///
/// 200 definitions each placed 100 times is also the more honest floor plan.
/// A drawing with one definition per 25 entities has no reuse to measure.
const int kDefinitionCount = 200;
const int kInstanceCount = 20000;

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

/// A viewport-sized window over the document centre.
///
/// The fit camera draws the entire drawing, which is the worst case and not a
/// frame anyone renders. This is the one that speaks to a frame budget: the
/// working set a user actually looks at.
ViewportTransform workingSetCamera(DraftDocument doc) {
  final e = doc.extents;
  final cx = (e.minX + e.maxX) / 2;
  final cy = (e.minY + e.maxY) / 2;
  // 3000 x 2250 world units at 1600 x 1200 px: a room or two of a floor plan
  // whose whole extent is 60000 x 40000.
  return ViewportTransform.fit(
      Aabb2(Vector2(cx - 1500, cy - 1125), Vector2(cx + 1500, cy + 1125)),
      kRigViewport);
}

DraftDocument rigCorpus(int entityCount) => generateDocument(
      entityCount,
      definitionCount: kDefinitionCount,
      instanceCount: kInstanceCount,
      nestingDepth: 2,
      mirroredFraction: 0.1,
      nonUniformFraction: 0.2,
      groupCount: 50,
      layerCount: 8,
      byBlockFraction: 0.3,
      dashedFraction: 0.35,
    );

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
        ('whole drawing', ViewportTransform.fit(doc.extents, kRigViewport)),
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

        print('  -- $label --');
        print('    R1 paint          $paint');
        print('    R3 query-only     $query');
        print('    ops/frame: $opsPerFrame');
        print('    screen-space leaves: ${painter.screenSpaceLeafCount}  '
            'anisotropic curves: ${painter.anisotropicCurveCount}');
        print('    skipped text: ${painter.skippedTextCount}  '
            'skipped deep instances: ${painter.skippedDeepInstanceCount}');
      }

      index.dispose();
    }, timeout: const Timeout(Duration(minutes: 10)));
  }
}
