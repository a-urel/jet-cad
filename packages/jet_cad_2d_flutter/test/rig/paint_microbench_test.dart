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
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

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

      // One measurer for the whole rig, not one per iteration. A fresh
      // `FlutterTextMeasurer()` inside the timed body hands every frame an
      // empty paragraph cache, which for a corpus with text in it measures
      // cold layout over and over and never measures the steady state the
      // frame budget is about. Harmless on this corpus, which has no drawn
      // text; wrong on `textRigCorpus`, and the two rigs must not differ in
      // how they hold it.
      final measurer = FlutterTextMeasurer();

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
                  pixelsPerPaperMm: kLogicalPixelsPerMm,
                  measurer: measurer,
                  textStyleOf: doc.textStyleOf),
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
            pixelsPerPaperMm: kLogicalPixelsPerMm,
            measurer: measurer,
            textStyleOf: doc.textStyleOf);
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

  // R4 — the text rig, and the number Task 12 exists to take.
  //
  // `kParagraphCacheLimit` bounds the paragraph cache at 512 entries. The
  // zero-new-layouts gate row says a steady-state frame lays nothing out; that
  // is reachable only if the number of **distinct `(string, styleHandle, argb)`
  // triples visible at the working-set camera** fits under the limit. Above it
  // the cache evicts an entry the same frame asks for again, and the row is
  // unpassable no matter what the painter does. So this rig prints that count
  // before it prints anything else.
  for (final entityCount in [50000, 500000]) {
    test('text paint at $entityCount', () {
      // One measurer, because production has one. The document owns it and
      // `DraftCanvas` borrows it for the sink, so the painter's metrics
      // requests and the sink's drawn paragraphs land in the same object —
      // metrics in its colour-free map, paragraphs in its coloured one. Before
      // Plan 3f these were two `FlutterTextMeasurer`s with two caches, and this
      // rig built two to match; that wiring is gone.
      final measurer = FlutterTextMeasurer();

      final build = Stopwatch()..start();
      final doc = textRigCorpus(entityCount, measurer: measurer);
      final docMs = build.elapsedMilliseconds;
      final index = SpatialIndex(doc);
      final indexMs = build.elapsedMilliseconds - docMs;
      final resolver = DocumentStyleResolver(doc);

      final painter =
          DraftPainter(document: doc, index: index, resolver: resolver);
      final textless = DraftPainter(
          document: doc, index: index, resolver: resolver, drawText: false);

      // The corpus has to actually carry both kinds of text, or every number
      // below is a measurement of a drawing with no text in it that still
      // prints plausible figures. Checked here rather than in the normal suite
      // because building it costs about two seconds and the check only matters
      // at the moment the number is taken. `labelFraction` is drawn from the
      // *root* budget, which the 20,000 instances mostly consume — at small
      // entity counts it yields zero labels while `attributedInstanceFraction`
      // keeps producing its 4,000, so "there is text" is not one condition.
      // R2's forced-repaint guard in `frame_timing_test.dart` refuses a
      // plausible zero for the same reason.
      var attribs = 0, labels = 0;
      for (final slot in doc.entities.liveSlots) {
        final kind = doc.entities.kindAt(slot);
        if (kind == EntityKind.attrib) attribs++;
        if (kind == EntityKind.text && doc.entities.textAt(slot).isNotEmpty) {
          labels++;
        }
      }
      if (attribs < 100 || labels < 10) {
        throw StateError('textRigCorpus is degenerate: attribs=$attribs '
            'labels=$labels — the distinct-key number below would be a '
            'measurement of a drawing with no text in it');
      }

      print('=== $entityCount entities, with text ===');
      print('  corpus: doc=${docMs}ms index=${indexMs}ms '
          'entities=${doc.entities.liveCount} nodes=${doc.tree.nodes.length} '
          'definitions=${doc.tree.definitions.length}');
      print('  text in corpus: attribs=$attribs labels=$labels');

      for (final (label, camera) in [
        ('whole drawing', wholeDrawingCamera(doc)),
        ('working set', workingSetCamera(doc)),
      ]) {
        print('  -- $label --');

        // Step 2: the gate's feasibility number, taken first and on a sink that
        // materialises nothing but the keys.
        final keySink = TextKeySink();
        painter.paint(keySink, camera, kRigViewport);
        // This rig measures the frame production draws, so it runs at the
        // shipped `kMinTextCapPixels` rather than pinning the threshold to 0 —
        // a rig that measured a frame nobody paints is not a frame budget.
        // The exposure that buys is that a later threshold could cull this
        // camera's text away entirely and every row below would still print a
        // plausible number, which is the same failure the corpus check above
        // refuses. Measured at 50,000 entities on the whole-drawing camera:
        // 4,514 text ops drawn, 414 culled, the smallest survivor at 3.0006 px
        // of cap height — 0.02% clear of the 3.0 threshold. So the cull figure
        // is printed with every row, and an empty one is refused here.
        if (keySink.textOps == 0) {
          throw StateError('level of detail culled every text entity at this '
              'camera (${painter.culledTextCount} culled, threshold '
              '${painter.minTextCapPixels} px): the rows below would be a '
              'measurement of a drawing with no text in it');
        }
        final keyCount = keySink.drawsPerKey.length;
        final strings = keySink.keys.map((k) => (k.$1, k.$2)).toSet();
        final colours = keySink.keys.map((k) => k.$3).toSet();
        print('    DISTINCT CACHE KEYS: $keyCount   '
            '(limit $kParagraphCacheLimit) '
            '${keyCount > kParagraphCacheLimit ? "OVER" : "under"}');
        print('      text ops: ${keySink.textOps}  '
            'distinct (string, style): ${strings.length}  '
            'distinct argb: ${colours.length}');

        // Hit rate split by source. The two text sources have opposite cache
        // behaviour by construction and the spec asks for them separately: a
        // single blended figure hides that one of them is the entire pressure.
        var labelOps = 0, labelKeys = 0, attrOps = 0, attrKeys = 0;
        keySink.drawsPerKey.forEach((key, draws) {
          if (TextKeySink.isAttributeTag(key.$1)) {
            attrKeys++;
            attrOps += draws;
          } else {
            labelKeys++;
            labelOps += draws;
          }
        });
        String rate(int ops, int keys) => ops == 0
            ? 'n/a'
            : '${((1 - keys / ops) * 100).toStringAsFixed(1)}%';
        print('      hit rate  labels: ${rate(labelOps, labelKeys)} '
            '($labelOps ops / $labelKeys keys)   '
            'attributes: ${rate(attrOps, attrKeys)} '
            '($attrOps ops / $attrKeys keys)');
        // The classification is checked, not assumed: an attribute key that the
        // predicate missed would land in the label bucket and quietly flatten
        // its hit rate.
        if (attrOps > 0 && attrKeys != attrOps) {
          throw StateError('an attribute tag repeated: $attrOps draws over '
              '$attrKeys keys — every generated tag carries its own instance '
              'ordinal, so the classifier has mixed the two sources');
        }

        for (final (mode, p) in [
          ('text on', painter),
          ('text off', textless)
        ]) {
          measurer.resetCounters();
          final paint = measure(() {
            final recorder = PictureRecorder();
            p.paint(
                CanvasDrawSink(
                    canvas: Canvas(recorder),
                    pixelsPerPaperMm: kLogicalPixelsPerMm,
                    measurer: measurer,
                    textStyleOf: doc.textStyleOf),
                camera,
                kRigViewport);
            recorder.endRecording().dispose();
          });

          final sink = NullDrawSink();
          final before = sink.opCount;
          final query = measure(() => p.paint(sink, camera, kRigViewport));
          final opsPerFrame = (sink.opCount - before) ~/ (query.n + 20);

          // The counters below come from this one untimed frame, so they
          // describe a frame rather than an average over two different sinks.
          final canvasRecorder = PictureRecorder();
          final canvasSink = CanvasDrawSink(
              canvas: Canvas(canvasRecorder),
              pixelsPerPaperMm: kLogicalPixelsPerMm,
              measurer: measurer,
              textStyleOf: doc.textStyleOf);
          final layoutsBefore = measurer.layoutCount;
          final paragraphEvictionsBefore = measurer.paragraphEvictionCount;
          p.paint(canvasSink, camera, kRigViewport);
          canvasRecorder.endRecording().dispose();

          print('    [$mode]');
          print('      R1 paint          $paint');
          print('      R3 query-only     $query');
          print('      ops/frame: $opsPerFrame  '
              'canvasCalls: ${canvasSink.canvasCallCount}');
          print('      textOps: ${p.textOpCount}  '
              'culledText: ${p.culledTextCount}  '
              'skippedText: ${p.skippedTextCount}');
          print('      newLayouts=${measurer.layoutCount - layoutsBefore} '
              'newParagraphEvictions='
              '${measurer.paragraphEvictionCount - paragraphEvictionsBefore}');
          print('      cache: layouts=${measurer.layoutCount} '
              'paragraphEvictions=${measurer.paragraphEvictionCount} '
              'metricsEvictions=${measurer.metricsEvictionCount} '
              'liveParagraphs=${measurer.liveParagraphCount} '
              'liveMetrics=${measurer.liveMetricsCount}');
          print('      screen-space leaves: ${p.screenSpaceLeafCount}  '
              'dashSpans: ${p.dashSpanCount}  '
              'collapsed: ${p.collapsedDashCount}');
        }
      }

      // How much slack the working-set number has.
      //
      // "Under the limit" is not the same as "under the limit with room". The
      // working-set camera sees a few square kilometres of a drawing whose text
      // is spread over the whole site, so its key count says as much about how
      // little text is in frame as about the cache. This ladder zooms out about
      // the same centre and prints where the count crosses
      // `kParagraphCacheLimit`, which is the number Task 14 needs to state the
      // gate row's margin instead of asserting it has one.
      print('  -- key pressure, zooming out about the working-set centre --');
      final e = doc.extents;
      final cx = (e.minX + e.maxX) / 2;
      final cy = (e.minY + e.maxY) / 2;
      for (final factor in [1, 2, 4, 8, 16, 32]) {
        final halfW = 1500.0 * factor;
        final halfH = 1125.0 * factor;
        final camera = ViewportTransform.fit(
            Aabb2(Vector2(cx - halfW, cy - halfH),
                Vector2(cx + halfW, cy + halfH)),
            kRigViewport);
        final keys = TextKeySink();
        painter.paint(keys, camera, kRigViewport);
        print('    ${(factor * 3000).toString().padLeft(6)} world units wide: '
            '${keys.keys.length.toString().padLeft(5)} keys, '
            '${keys.textOps.toString().padLeft(5)} text ops  '
            '${keys.keys.length > kParagraphCacheLimit ? "OVER" : "under"}');
      }

      index.dispose();
    }, timeout: const Timeout(Duration(minutes: 20)));
  }
}
