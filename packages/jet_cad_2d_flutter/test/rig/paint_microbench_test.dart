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

/// Threshold ladder for Task 8's step-locator measurement: `minTextCapPixels`
/// values to probe, one full pass each, at the 50,000-entity text corpus.
///
/// **Gated behind an environment define, not always-on.** An ordinary rig
/// run already costs minutes; this loop is fourteen additional full paints
/// (seven thresholds, two cameras) and belongs only to the run that is
/// actually measuring the ladder. Comma-separated pixel values; unset (the
/// default) leaves the list empty and the loop below a no-op.
///
/// Reproduces the Task 8 report's ladder table exactly:
/// ```sh
/// cd packages/jet_cad_2d_flutter && CI=true flutter test --tags rig \
///   --run-skipped test/rig/paint_microbench_test.dart \
///   --plain-name "text paint at 50000" \
///   --dart-define=LADDER=0.0,1.0,2.0,3.0,4.0,6.0,10.0
/// ```
final List<double> kLadderThresholds = const String.fromEnvironment('LADDER')
    .split(',')
    .where((s) => s.isNotEmpty)
    .map(double.parse)
    .toList();

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

/// The smallest on-screen cap height, in pixels, among the text this camera
/// actually draws at [kMinTextCapPixels].
///
/// **Recovered from outside the painter, on purpose — but not because the
/// inside was forbidden.** The obvious alternative is a `double` field on
/// `DraftPainter`, updated once per drawn text entity. That technique is
/// available: `DraftPainter` already keeps `_arcCx`, `_arcCy` and `_arcR`
/// (`draft_painter.dart:275`) and writes all three per dashed circle and per
/// dashed arc on the same frame path (`:750-752`, `:793-795`). A `double` field
/// assignment is not an allocation in Dart, and the package's
/// nothing-per-entity rule is about allocation — so a per-entity `double` write
/// would not have breached it.
///
/// It was passed over for a plainer reason: this number is a **rig
/// diagnostic**. It is read once per printed row, by a human reading a
/// transcript, and never by the renderer. Exposing it from `DraftPainter` would
/// put a field and a public getter into production API whose only purpose is to
/// be printed, and every later reader of that class would have to work out that
/// nothing depends on it. Recovering it here keeps the painter's surface to
/// what the frame actually needs.
///
/// The recovery is exact rather than approximate. The cull rule is
/// `cap < minTextCapPixels`, so a label of cap height `m` survives a threshold
/// `t` exactly when `t <= m` — the bound is achieved, not approached. The
/// largest `t` at which the frame still draws all [baseline] of its labels is
/// therefore `m` for the smallest surviving one. Bisecting for it costs a
/// handful of query-only paints — about 380 ms each at 500,000 entities,
/// fifteen of them, against a rig that already runs for minutes — and every one
/// of them is a throwaway probe into a `NullDrawSink`, outside every timed
/// block.
///
/// Returns `double.nan` when nothing was drawn; the caller has already refused
/// that case.
double smallestDrawnCapPixels(DraftDocument doc, SpatialIndex index,
    StyleResolver resolver, ViewportTransform camera, int baseline) {
  if (baseline == 0) return double.nan;
  int drawnAt(double threshold) {
    final probe = DraftPainter(
        document: doc,
        index: index,
        resolver: resolver,
        minTextCapPixels: threshold);
    probe.paint(NullDrawSink(), camera, kRigViewport);
    return probe.textOpCount;
  }

  // Bracket: `lo` keeps every label, `hi` loses at least one. 24 doublings
  // reaches 50 million pixels of cap height, which no camera survives.
  var lo = kMinTextCapPixels, hi = kMinTextCapPixels * 2;
  var bracketed = false;
  for (var i = 0; i < 24; i++) {
    if (drawnAt(hi) != baseline) {
      bracketed = true;
      break;
    }
    lo = hi;
    hi *= 2;
  }
  if (!bracketed) return double.infinity;
  // Bisect to a relative 1e-4, which is four significant figures on a number
  // printed to four decimal places.
  for (var i = 0; i < 32 && hi - lo > lo * 1e-4; i++) {
    final mid = (lo + hi) / 2;
    if (drawnAt(mid) == baseline) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return lo;
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
      addTearDown(measurer.clear);

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
      // rig built two to match; that wiring is gone. The threshold ladder
      // near the end of this test builds a second `FlutterTextMeasurer` of
      // its own (`paragraphs`, below) — that is not a relapse into this
      // production topology; see the comment at its construction for why.
      final measurer = FlutterTextMeasurer();
      addTearDown(measurer.clear);

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
        // Emptying is not the realistic failure — drift is. This camera's
        // smallest survivor sits 0.02% above the threshold, so a small
        // threshold rise would take thousands of labels away while `textOps`
        // stayed comfortably non-zero, and every row below would go on
        // printing plausible numbers for a frame that no longer resembles the
        // one it is supposed to measure. The margin is therefore printed, so a
        // human reading this transcript sees how close it is on the run in
        // front of them rather than on the run this comment was written from.
        final smallest = smallestDrawnCapPixels(
            doc, index, resolver, camera, painter.textOpCount);
        print('    LOD MARGIN: smallest drawn cap height '
            '${smallest.toStringAsFixed(4)} px  '
            '(threshold ${painter.minTextCapPixels} px, '
            '${(smallest / painter.minTextCapPixels).toStringAsFixed(4)}x)  '
            'culled: ${painter.culledTextCount}');
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

      // Exit-gate row 10 — extents-sweep non-interference, at corpus scale.
      //
      // `flutter_text_measurer_test.dart`'s 'a metrics sweep does not evict
      // drawn paragraphs' makes the same claim at unit scale, with both cache
      // bounds handed in explicitly. This is the claim against the real
      // corpus, at the shipped defaults, over the ~4,020 distinct strings the
      // sweep actually walks — which is the number that decides whether
      // `kMetricsCacheLimit` is sized right, and the thing a unit fixture
      // with `metricsLimit: 1024` cannot say anything about.
      //
      // The procedure is the plan's, in order: paint one frame at the
      // working-set camera warm; `invalidateDerived()` then read
      // `doc.extents` in full; repaint at the same camera; read the *repeat
      // frame's* new paragraph layouts and paragraph evictions. Both are
      // expected to be 0. A merged cache fails it by construction — the sweep
      // walks 4,020 keys through 512 slots and evicts everything the repaint
      // asks for again.
      //
      // **Measured, and it does not do what the spec assumed — read this
      // before trusting the row.** The design document justified row 10 with
      // "step 2 walks 4,020 keys through 512 slots". `doc.extents` does not:
      // `_computeExtents` is `_boundsOfContainer` over the tree with a
      // per-*definition* bounds cache, so a corpus of 20,000 instances over
      // 200 definitions measures each definition's strings once, not once per
      // instance. The 4,020 figure belongs to `ContainerIndex.build`, which is
      // a genuinely per-entity sweep and runs once when the index is built.
      // Fired at 50,000 entities on 2026-08-22, this sweep laid out **12**
      // strings under a merged cache and 12 under `metricsLimit` cut to the
      // paragraph bound — not 4,020.
      //
      // The consequence is that this row **passes under both of the mutations
      // it was written to catch**, and is recorded as non-discriminating on
      // this corpus rather than as evidence. Under mutant 6 (one merged map)
      // the sweep evicted 12 paragraphs and the repeat frame still read
      // `newLayouts=0`: LRU drops the *oldest* entries, and the 18 keys this
      // camera had just drawn were the newest, with 512 slots for 18 keys.
      // The discriminating version of this claim is the unit-scale one in
      // `flutter_text_measurer_test.dart`, where `paragraphLimit: 4` against a
      // 200-key sweep leaves the drawn set no such margin — mutants 6 and 12
      // both redden it.
      //
      // The sweep's own deltas are printed separately for that reason: at the
      // shipped defaults they read zero, which is the designed outcome (the
      // metrics map was filled at index-build time and `kMetricsCacheLimit` is
      // above the corpus's distinct-key count), and any run where they do not
      // is the one worth looking at. `liveMetrics` below shows whether the map
      // still holds the whole corpus or a truncated part of it — that field,
      // not the repeat frame, is what moved under both mutations.
      {
        final ws = workingSetCamera(doc);
        CanvasDrawSink freshSink(PictureRecorder r) => CanvasDrawSink(
            canvas: Canvas(r),
            pixelsPerPaperMm: kLogicalPixelsPerMm,
            measurer: measurer,
            textStyleOf: doc.textStyleOf);

        final warm = PictureRecorder();
        painter.paint(freshSink(warm), ws, kRigViewport);
        warm.endRecording().dispose();

        measurer.resetCounters();
        doc.invalidateDerived();
        final swept = doc.extents;
        final sweepLayouts = measurer.layoutCount;
        final sweepParagraphEvictions = measurer.paragraphEvictionCount;
        final sweepMetricsEvictions = measurer.metricsEvictionCount;

        measurer.resetCounters();
        final repeat = PictureRecorder();
        painter.paint(freshSink(repeat), ws, kRigViewport);
        repeat.endRecording().dispose();

        print('  -- row 10: extents-sweep non-interference --');
        print('    sweep (${swept.maxX - swept.minX} x '
            '${swept.maxY - swept.minY} world units): '
            'layouts=$sweepLayouts '
            'paragraphEvictions=$sweepParagraphEvictions '
            'metricsEvictions=$sweepMetricsEvictions');
        print('    repeat frame after the sweep: '
            'newLayouts=${measurer.layoutCount} '
            'newParagraphEvictions=${measurer.paragraphEvictionCount} '
            'newMetricsEvictions=${measurer.metricsEvictionCount} '
            'liveParagraphs=${measurer.liveParagraphCount} '
            'liveMetrics=${measurer.liveMetricsCount}');
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

      // Task 8's threshold ladder — see kLadderThresholds' doc comment for
      // the command that reproduces the report's table. A no-op unless
      // `LADDER` is set: `kLadderThresholds` is then empty and this loop
      // does not run.
      //
      // Two independent readings per row, from two different objects, on
      // purpose:
      //
      // `distinctKeys` is the **true** distinct `(text, styleHandle, argb)`
      // count visible at this threshold and camera — a `TextKeySink` pass,
      // which draws nothing and costs no layout at all. This is the number
      // Ruling 4's single permitted raise of `kParagraphCacheLimit` needs
      // recorded beside it, and it is not the same thing as `layouts` below:
      // `layouts` counts *cache misses* in one paint, which only equals the
      // true distinct-key count when the paint's own eviction pressure
      // happens not to force a second miss on a key already seen earlier in
      // that same pass. Above the 512-entry limit that coincidence cannot be
      // assumed, so this rig measures the real thing instead of reasoning
      // about whether the coincidence held.
      //
      // `layouts`/`paragraphEvictions`/`liveParagraphs` come from a *fresh*
      // `FlutterTextMeasurer` built fresh each iteration and passed as the
      // `CanvasDrawSink`'s `measurer:` — the object `paragraphFor` (the
      // drawn, coloured cache) writes to. Fresh each time so this reports
      // what one cold paint at that threshold costs, not a number
      // contaminated by whichever keys the *previous* threshold's paint
      // happened to leave live.
      //
      // `metricsEvictions`/`liveMetrics` are read from `measurer` — this
      // test's own `document.textMeasurer`, the object `textRigCorpus` built
      // the document with. `DraftPainter._drawText`'s LOD check calls
      // `.measure()` on *that* object (`draft_painter.dart:873`), never on
      // the sink's measurer, so it is the only one this column can mean
      // anything read from. `resetCounters()` isolates each iteration's
      // eviction delta without clearing the map itself.
      if (entityCount == 50000 && kLadderThresholds.isNotEmpty) {
        print('  -- threshold ladder --');
        for (final threshold in kLadderThresholds) {
          for (final (label, camera) in [
            ('whole drawing', wholeDrawingCamera(doc)),
            ('working set', workingSetCamera(doc)),
          ]) {
            final p = DraftPainter(
                document: doc,
                index: index,
                resolver: resolver,
                minTextCapPixels: threshold);

            final keySink = TextKeySink();
            p.paint(keySink, camera, kRigViewport);
            final distinctKeys = keySink.drawsPerKey.length;
            final culled = p.culledTextCount;

            // A second `FlutterTextMeasurer`, deliberately — and not the
            // two-measurer topology the comment on `measurer` above warns
            // against. That one was a production wiring bug: the painter and
            // the sink held two different objects, so a paint could look
            // healthy while metrics and paragraphs silently disagreed. This
            // one is a throwaway confined to the `LADDER`-gated branch above,
            // which production and every ordinary test run never reach.
            //
            // It exists because a ladder row needs a cold cache: sharing the
            // outer `measurer` here would carry paragraph-cache state from
            // one threshold into the next, so every row after the first
            // would read however warm the previous threshold's paint left
            // the cache, not what a cold paint at *this* threshold costs.
            // Built fresh every iteration for exactly that reason — see the
            // "Two independent readings" comment above this loop for the
            // rest of the split between this object and `measurer`.
            // Cleared at the end of this iteration rather than via
            // `addTearDown`: this loop runs up to fourteen times (seven
            // thresholds times two cameras) inside one test, and
            // `addTearDown` only fires once the whole test body returns, so
            // it would let all fourteen measurers' native paragraphs pile up
            // live together instead of bounding the population to one
            // measurer's worth at a time.
            final paragraphs = FlutterTextMeasurer();
            measurer.resetCounters();
            final recorder = PictureRecorder();
            p.paint(
                CanvasDrawSink(
                    canvas: Canvas(recorder),
                    pixelsPerPaperMm: kLogicalPixelsPerMm,
                    measurer: paragraphs,
                    textStyleOf: doc.textStyleOf),
                camera,
                kRigViewport);
            recorder.endRecording().dispose();

            print('    threshold=${threshold.toStringAsFixed(1)} '
                '$label: distinctKeys=$distinctKeys '
                'layouts=${paragraphs.layoutCount} '
                'paragraphEvictions=${paragraphs.paragraphEvictionCount} '
                'metricsEvictions=${measurer.metricsEvictionCount} '
                'culledText=$culled '
                'liveParagraphs=${paragraphs.liveParagraphCount} '
                'liveMetrics=${measurer.liveMetricsCount}');
            paragraphs.clear();
          }
        }
      }

      index.dispose();
    }, timeout: const Timeout(Duration(minutes: 20)));
  }
}
