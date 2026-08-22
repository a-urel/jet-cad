## Task 3: every reader of the eviction counter moves with it

**Files:**
- Modify: `apps/dev_harness_2d/lib/measurement_rig.dart:145-159`, `:218`
- Modify: `apps/dev_harness_2d/integration_test/frame_timing_test.dart:265`, `:323`
- Modify: `packages/jet_cad_2d_flutter/test/rig/paint_microbench_test.dart:150-160`, `:285-305`
- Audit: `packages/jet_cad_2d_flutter/test/canvas_draw_sink_test.dart:98-99`

**Interfaces:**
- Consumes: `paragraphEvictionCount`, `metricsEvictionCount`, `liveMetricsCount` from Task 2.
- Produces: `printTextCounters(DraftPainter painter, CanvasDrawSink sink, {required bool textCorpus, required bool drawText, required int layoutsBefore, required int paragraphEvictionsBefore, required int metricsEvictionsBefore})` — Task 8 adds `culledText=` to the same function.

**The `paint_microbench_test.dart` case is not mechanical.** Its fixture builds two measurers on purpose and explains why in a comment that this plan makes false. That comment is the design's own falsified premise and must be rewritten, not deleted.

- [ ] **Step 1: Update the rig printer**

In `apps/dev_harness_2d/lib/measurement_rig.dart`, replace the signature and second print of `printTextCounters`:

```dart
void printTextCounters(DraftPainter painter, CanvasDrawSink sink,
    {required bool textCorpus,
    required bool drawText,
    required int layoutsBefore,
    required int paragraphEvictionsBefore,
    required int metricsEvictionsBefore}) {
  final m = sink.measurer;
  print('  text: corpus=${textCorpus ? "on" : "off"} '
      'draw=${drawText ? "on" : "off"} '
      'textOps=${painter.textOpCount} '
      'skippedText=${painter.skippedTextCount}');
  // Two eviction numbers, not one. A paragraph eviction released native glyph
  // memory and guarantees a future re-layout; a metrics eviction dropped four
  // doubles. Ruling 54: a blended number hides which half moved.
  print('  paragraphs: newLayouts=${m.layoutCount - layoutsBefore} '
      'newParagraphEvictions=${m.paragraphEvictionCount - paragraphEvictionsBefore} '
      'newMetricsEvictions=${m.metricsEvictionCount - metricsEvictionsBefore} '
      'liveParagraphs=${m.liveParagraphCount} '
      'liveMetrics=${m.liveMetricsCount}');
}
```

- [ ] **Step 2: Update every caller of it in the same file**

At `measurement_rig.dart:217-218` and at every other `evictionsBefore` capture in the file, replace the single capture with two and pass both through:

```dart
    final layoutsBefore = sink.measurer.layoutCount;
    final paragraphEvictionsBefore = sink.measurer.paragraphEvictionCount;
    final metricsEvictionsBefore = sink.measurer.metricsEvictionCount;
```

```dart
    printTextCounters(painter, sink,
        textCorpus: textCorpus,
        drawText: drawText,
        layoutsBefore: layoutsBefore,
        paragraphEvictionsBefore: paragraphEvictionsBefore,
        metricsEvictionsBefore: metricsEvictionsBefore);
```

Run `grep -n "evictionCount\|evictionsBefore" apps/dev_harness_2d/lib/measurement_rig.dart` and confirm every hit is one of the new names.

- [ ] **Step 3: Update the integration test**

In `apps/dev_harness_2d/integration_test/frame_timing_test.dart`, at both `:265` and `:323`, replace

```dart
    final evictionsBefore = app.sink.measurer.evictionCount;
```

with

```dart
    final paragraphEvictionsBefore = app.sink.measurer.paragraphEvictionCount;
    final metricsEvictionsBefore = app.sink.measurer.metricsEvictionCount;
```

and pass both to `printTextCounters`.

- [ ] **Step 4: Collapse the microbench to one measurer and rewrite its comment**

In `packages/jet_cad_2d_flutter/test/rig/paint_microbench_test.dart`, replace the two-measurer block and its comment with:

```dart
      // One measurer, because production has one. The document owns it and
      // `DraftCanvas` borrows it for the sink, so the painter's metrics
      // requests and the sink's drawn paragraphs land in the same object —
      // metrics in its colour-free map, paragraphs in its coloured one. Before
      // Plan 3f these were two `FlutterTextMeasurer`s with two caches, and this
      // rig built two to match; that wiring is gone.
      final measurer = FlutterTextMeasurer();
```

Replace every `sinkMeasurer` and `docMeasurer` in the file with `measurer`, and replace the counter prints at `:298-305` with:

```dart
          print('      newLayouts=${measurer.layoutCount - layoutsBefore} '
              'newParagraphEvictions='
              '${measurer.paragraphEvictionCount - paragraphEvictionsBefore}');
          print('      cache: layouts=${measurer.layoutCount} '
              'paragraphEvictions=${measurer.paragraphEvictionCount} '
              'metricsEvictions=${measurer.metricsEvictionCount} '
              'liveParagraphs=${measurer.liveParagraphCount} '
              'liveMetrics=${measurer.liveMetricsCount}');
```

with the captures above the measured region updated to match.

- [ ] **Step 5: Audit the sink test**

Run:

```bash
grep -n "layoutCount\|liveParagraphCount\|evictionCount" packages/jet_cad_2d_flutter/test/canvas_draw_sink_test.dart
```

Expected: `:98` reads `layoutCount` and `:99` reads `liveParagraphCount`. Both keep their names and meanings, so **no change**. Say so in the report rather than leaving it unmentioned.

- [ ] **Step 6: Verify everything compiles, including the tagged rig**

Run:

```bash
cd packages/jet_cad_2d_flutter && flutter analyze && CI=true flutter test --tags rig --run-skipped test/rig/paint_microbench_test.dart --plain-name "text paint at 50000"
cd ../../apps/dev_harness_2d && flutter analyze
```

Expected: analyze clean in both, and the microbench prints one cache's numbers.

- [ ] **Step 7: Commit**

```bash
git add apps/dev_harness_2d/lib/measurement_rig.dart \
        apps/dev_harness_2d/integration_test/frame_timing_test.dart \
        packages/jet_cad_2d_flutter/test/rig/paint_microbench_test.dart
git commit -m "refactor: report paragraph and metrics evictions apart"
```

---

