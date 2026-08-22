# Plan 3f mutation log — text ownership, the split cache, and level of detail

The fifteen mutants Section 3 of
`docs/superpowers/specs/2026-08-22-jet-cad-2d-plan-3f-text-design.md` names,
every one fired on `main` at `645b027`'s parent tree unless a row says
otherwise, plus the one mutation the spec records as **unmeasurable** rather
than listing it with a killer that cannot kill it.

Every mutation, its test and its restore ran in **one shell call**, in the
shape the plan's brief pins:

```bash
cp target.dart $SCRATCH/mN.bak && \
  python3 mut.py target.dart '<exact old text>' '<exact new text>' && \
  (cd packages/jet_cad_2d_flutter && CI=true flutter test > $SCRATCH/mN.out 2>&1; echo "EXIT=$?") ; \
  cp $SCRATCH/mN.bak target.dart
```

`mut.py` is a three-line helper that refuses to write unless its anchor
matches **exactly once** in the file, so a mutation that silently missed its
site cannot be reported as applied. No mutation was reverted with
`git checkout`. `git diff --stat <target>` was read after every restore and
was empty in all seventeen runs; `git status --short` after the last one shows
only the three pre-existing `apps/dev_harness` `flutter pub get` artefacts.

## Tally

| Category | Count | Which |
|---|---:|---|
| Killed | 14 | 1–9, 11–15 |
| Killed only after a test was added this task | 1 | 7 (see its row) |
| Restatement — structurally unreachable by the named killer | 1 | 10 |
| Unmeasurable, with the reason | 1 | the metrics-probe key allocation (not one of the fifteen; the spec lists it under Accepted gaps) |

Fifteen named mutants: **14 killed, 1 recorded as a restatement.** Mutant 7 is
counted among the fourteen and is flagged, because it **survived the suite as
it stood** and was only killed after a test was written for it in `645b027`.
That is a result about the suite, not a formality — see its row.

---

## 1 — move the LOD test after `measure()`

**Target:** `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart`,
`_drawText`.

```diff
-    if (layout.height * chain.scaleMagnitude < minTextCapPixels) {
-      _culledText++;
-      return;
-    }
-    final metrics = document.textMeasurer.measure(text: text, style: record);
+    final metrics = document.textMeasurer.measure(text: text, style: record);
+    if (layout.height * chain.scaleMagnitude < minTextCapPixels) {
+      _culledText++;
+      return;
+    }
```

**Command:** `CI=true flutter test test/text_lod_test.dart` from
`packages/jet_cad_2d_flutter`.

```
00:00 +0: text below the threshold is culled and never measured
00:00 +0 -1: text below the threshold is culled and never measured [E]
  Expected: <1>
    Actual: <2>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/text_lod_test.dart 85:5                        main.<fn>

00:00 +0 -1: the same text at the same camera draws once LOD is off
00:00 +1 -1: readable text at the same threshold is not culled
00:00 +2 -1: the threshold is exclusive at exactly kMinTextCapPixels
00:00 +3 -1: culledTextCount is a per-frame figure, not a running total
00:00 +4 -1: doc.extents is bit-identical whichever threshold the painter runs at
00:00 +5 -1: painter and oracle cull the same text under a non-identity placement
00:00 +6 -1: Some tests failed.

Failing tests:
  test/text_lod_test.dart: text below the threshold is culled and never measured
```

**Verdict: KILLED.** The failing line is `expect(m.layoutCount, baseline)` —
the assertion the test's own comment calls "the load-bearing half". The
counter reads 2 against a baseline of 1: the cull still fires, so
`culledTextCount` is right, but a layout was paid for text nobody drew, which
is the entire saving the row-1 claim rests on.

## 2 — `<` to `<=` at the threshold

**Target:** `draft_painter.dart`, `_drawText`.

```diff
-    if (layout.height * chain.scaleMagnitude < minTextCapPixels) {
+    if (layout.height * chain.scaleMagnitude <= minTextCapPixels) {
```

**Command:** `CI=true flutter test test/text_lod_test.dart`.

```
00:00 +3: the threshold is exclusive at exactly kMinTextCapPixels
00:00 +3 -1: the threshold is exclusive at exactly kMinTextCapPixels [E]
  Expected: <0>
    Actual: <1>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/text_lod_test.dart 153:5                       main.<fn>

00:00 +3 -1: culledTextCount is a per-frame figure, not a running total
00:00 +4 -1: doc.extents is bit-identical whichever threshold the painter runs at
00:00 +5 -1: painter and oracle cull the same text under a non-identity placement
00:00 +6 -1: Some tests failed.

Failing tests:
  test/text_lod_test.dart: the threshold is exclusive at exactly kMinTextCapPixels
```

**Verdict: KILLED**, by the boundary test the spec named, and by that test
alone — the six other tests in the file are unmoved, which is what a boundary
fixture is supposed to look like.

## 3 — drop `chain.scaleMagnitude`, cull on world height alone

**Target:** `draft_painter.dart`, `_drawText`.

```diff
-    if (layout.height * chain.scaleMagnitude < minTextCapPixels) {
+    if (layout.height < minTextCapPixels) {
```

**Command:** `CI=true flutter test` (whole suite), from
`packages/jet_cad_2d_flutter`.

```
00:00 +60 -1: test/text_paint_test.dart: the reference walk and the painter agree with text on [E]
  Expected: true
    Actual: <false>
  the painter drew text:OFFICE(563.93,98.79)(563.95,98.79)(563.93,98.77) inside the view and the reference did not — that is a wrong drawing, not loose culling

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/support/differential.dart 189:5                expectPainterSupersetOfReference
  test/text_paint_test.dart 254:5                     main.<fn>

══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following assertion was thrown while running async test code:
Golden "text_lod_ladder_1.png": Pixel test failed, 0.02%, 96px diff detected.
Failure feedback can be found at
test/golden/failures

00:00 +87 -2: test/golden/text_lod_ladder_golden_test.dart: text lod ladder rung 1 (RenderBackend.canvas) [E]
  Test failed. See exception logs above.
  The test description was: text lod ladder rung 1 (RenderBackend.canvas)

00:01 +182 ~1 -3: test/text_lod_test.dart: painter and oracle cull the same text under a non-identity placement [E]
  Expected: <3>
    Actual: <5>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/text_lod_test.dart 256:5                       main.<fn>

Failing tests:
  test/golden/text_lod_ladder_golden_test.dart: text lod ladder rung 1 (RenderBackend.canvas)
  test/text_lod_test.dart: painter and oracle cull the same text under a non-identity placement
  test/text_paint_test.dart: the reference walk and the painter agree with text on
00:03 +294 ~1 -3: Some tests failed.
```

**Verdict: KILLED**, three times over — and **not by the killer the spec
named.** The spec expected row 5, `culledTextCount` at the working-set camera.
Fired at rig scale
(`--tags rig --run-skipped ... --name 'text paint at 50000$'`), row 5 does not
see it:

```
  -- whole drawing --
    LOD MARGIN: smallest drawn cap height 79.9980 px  (threshold 3.0 px, 26.6660x)  culled: 0
      textOps: 4928  culledText: 0  skippedText: 0
  -- working set --
    LOD MARGIN: smallest drawn cap height 79.9980 px  (threshold 3.0 px, 26.6660x)  culled: 0
      textOps: 19  culledText: 0  skippedText: 0
01:50 +1: All tests passed!
```

Row 5 wants **0** at the working-set camera and gets 0 — passing. Every text
entity the corpus carries is at least 80 world units tall, so a comparison
against the raw height culls nothing anywhere and the "smallest drawn cap
height" print collapses to the same 79.998 px on both cameras. The rig row
that *does* catch it is **row 4**, `culledTextCount > 0` at the whole-drawing
camera: 414 shipped, **0** here. The spec's expected killer for this mutant is
corrected to row 4 rather than reported as having fired.

What actually reddens a test is the pair of differential oracles — the walk
keeps multiplying by its own `scaleMagnitude`, so painter and oracle disagree
the moment a placement is not at unit scale — and the golden ladder, whose
middle rung at 3.42 px of cap height turns back on.

## 4 — drop `_culledText++`

**Target:** `draft_painter.dart`, `_drawText`.

```diff
     if (layout.height * chain.scaleMagnitude < minTextCapPixels) {
-      _culledText++;
       return;
     }
```

**Command:** `CI=true flutter test`.

```
00:01 +166 ~1 -1: test/text_lod_test.dart: text below the threshold is culled and never measured [E]
  Expected: <1>
    Actual: <0>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/text_lod_test.dart 81:5                        main.<fn>

00:01 +171 ~1 -2: test/text_lod_test.dart: culledTextCount is a per-frame figure, not a running total [E]
  Expected: <1>
    Actual: <0>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/text_lod_test.dart 171:5                       main.<fn>

Failing tests:
  test/text_lod_test.dart: culledTextCount is a per-frame figure, not a running total
  test/text_lod_test.dart: text below the threshold is culled and never measured
00:03 +295 ~1 -2: Some tests failed.
```

**Verdict: KILLED.** Row 4's claim (`culledTextCount > 0` at the whole-drawing
camera) is a rig print with no assertion behind it, so the kill comes from the
unit tests that assert the same counter, which is the stronger evidence of the
two.

## 5 — reference walk reads the painter's decision

**Target:** `packages/jet_cad_2d_flutter/lib/src/reference_walk.dart`,
`_ReferenceWalk._leaf`. The walk stops reading the threshold it was handed and
reads the painter's constant instead — the *shape* of "the oracle asks the
subject", expressed at the one line where this walk makes the decision.

```diff
-      if (attrs.height * chain.scaleMagnitude < minTextCapPixels) return;
+      if (attrs.height * chain.scaleMagnitude < kMinTextCapPixels) return;
```

**Command:** `CI=true flutter test`.

```
00:00 +60 -1: test/text_paint_test.dart: the reference walk and the painter agree with text on [E]
  Expected: true
    Actual: <false>
  the painter drew text:OFFICE(563.93,98.79)(563.95,98.79)(563.93,98.77) inside the view and the reference did not — that is a wrong drawing, not loose culling

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/support/differential.dart 189:5                expectPainterSupersetOfReference
  test/text_paint_test.dart 273:5                     main.<fn>

00:01 +171 ~1 -2: test/text_lod_test.dart: painter and oracle cull the same text under a non-identity placement [E]
  Expected: <5>
    Actual: <3>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/text_lod_test.dart 288:5                       main.<fn>

Failing tests:
  test/text_lod_test.dart: painter and oracle cull the same text under a non-identity placement
  test/text_paint_test.dart: the reference walk and the painter agree with text on
00:03 +295 ~1 -2: Some tests failed.
```

**Verdict: KILLED**, and by the two lines that were put there for it. Both
failures are the **LOD-off control arm**, not the LOD-on comparison:
`text_lod_test.dart:288` is
`expect(flatten(referenceToRecording(doc, view, 0.0)).length, all.length)` and
`text_paint_test.dart:273` is the third arm with the threshold at 0.0 on both
sides. That is the whole point of a steerable threshold on the oracle: a walk
that ignores what it is handed and reuses the painter's number agrees with the
painter perfectly on the on-arm and can only be caught where the two are told
to differ. Without those arms this mutant survives.

## 6 — merge the two maps back into one

**Target:** `packages/jet_cad_2d_flutter/lib/src/flutter_text_measurer.dart`,
`measure`. Metrics are read off the paragraph cache under the wide
`(text, styleHandle, argb)` key at `kMetricsProbeArgb`; the metrics map goes
unused.

```diff
-    _metricsProbe
-      ..text = text
-      ..styleHandle = style.handle;
-    final hit = _metrics[_metricsProbe];
-    if (hit != null) {
-      _metrics.remove(hit.key);
-      _metrics[hit.key] = hit;
-      return hit.metrics;
-    }
-    final probe = _layOut(text, style, kMetricsProbeArgb);
-    final metrics = _metricsOf(probe);
-    probe.dispose();
-    debugLastProbe = probe;
-    if (_metrics.length >= metricsLimit) _evictOldestMetrics();
-    final key = _MetricsKey(text, style.handle);
-    _metrics[key] = _MetricsEntry(key, metrics);
-    return metrics;
+    // MUTANT 6: the two maps merged back into one.
+    final probe = paragraphFor(text, style.handle, style, kMetricsProbeArgb);
+    debugLastProbe = probe;
+    return _metricsOf(probe);
```

**Command:** `CI=true flutter test`.

```
00:01 +131 -1: test/flutter_text_measurer_test.dart: a repeat request lays out nothing and allocates no metrics [E]
  Expected: true
    Actual: <false>
  ... test/flutter_text_measurer_test.dart 29:5

00:01 +136 -2: test/flutter_text_measurer_test.dart: measure disposes its probe and leaves no paragraph entry [E]
  Expected: <0>
    Actual: <1>
  ... test/flutter_text_measurer_test.dart 155:5

00:01 +136 -3: test/flutter_text_measurer_test.dart: a metrics sweep does not evict drawn paragraphs [E]
  Expected: <0>
    Actual: <200>
  ... test/flutter_text_measurer_test.dart 175:5

00:01 +136 -4: test/flutter_text_measurer_test.dart: the metrics map evicts on its own bound, and it is not the paragraph one [E]
  Expected: <1>
    Actual: <0>
  ... test/flutter_text_measurer_test.dart 193:5

00:01 +136 -5: test/flutter_text_measurer_test.dart: clear empties both maps [E]
  Expected: <1>
    Actual: <2>
  ... test/flutter_text_measurer_test.dart 202:5

Failing tests:
  test/flutter_text_measurer_test.dart: a metrics sweep does not evict drawn paragraphs
  test/flutter_text_measurer_test.dart: a repeat request lays out nothing and allocates no metrics
  test/flutter_text_measurer_test.dart: clear empties both maps
  test/flutter_text_measurer_test.dart: measure disposes its probe and leaves no paragraph entry
  test/flutter_text_measurer_test.dart: the metrics map evicts on its own bound, and it is not the paragraph one
00:03 +292 ~1 -5: Some tests failed.
```

(The `[E]` blocks are elided at the stack frames only, marked `...`; the
`Expected`/`Actual` pairs and the failing list are verbatim.)

**Verdict: KILLED**, five tests, `a metrics sweep does not evict drawn
paragraphs` — row 10 at unit scale — among them, with 200 paragraph evictions
where the split cache has none.

**But row 10 at *corpus* scale does not kill it**, and that is recorded here
rather than left implied. Fired against the rig's new row-10 block
(`--tags rig --run-skipped ... --name 'text paint at 50000$'`):

```
  -- row 10: extents-sweep non-interference --
    sweep (66522.34207401797 x 48478.932530765655 world units): layouts=12 paragraphEvictions=12 metricsEvictions=0
    repeat frame after the sweep: newLayouts=0 newParagraphEvictions=0 newMetricsEvictions=0 liveParagraphs=512 liveMetrics=0
02:07 +1: All tests passed!
```

The repeat frame reads zero anyway. Two reasons, both measured: `doc.extents`
is not the 4,020-key sweep the spec assumed (`_computeExtents` caches bounds
per *definition*, so 20,000 instances over 200 definitions measure **12**
distinct strings), and LRU evicts the oldest entries while the working-set
camera's 18 keys are the newest with 512 slots to sit in. The unit-scale
fixture — `paragraphLimit: 4`, a 200-key sweep — is the one that leaves the
drawn set no margin. See `paint_microbench_test.dart`'s row-10 comment.

## 7 — `metricsLimit` defaulted to `kParagraphCacheLimit`

**Target:** `flutter_text_measurer.dart`, the constructor.

```diff
   FlutterTextMeasurer({
     this.paragraphLimit = kParagraphCacheLimit,
-    this.metricsLimit = kMetricsCacheLimit,
+    this.metricsLimit = kParagraphCacheLimit,
   });
```

### First firing — **SURVIVED**

**Command:** `CI=true flutter test`.

```
EXIT=0
00:03 +297 ~1: All tests passed!
```

Nothing red. Every other test in `flutter_text_measurer_test.dart` constructs
the measurer with **both** limits given explicitly — `FlutterTextMeasurer(paragraphLimit: 4, metricsLimit: 1024)`,
`(paragraphLimit: 512, metricsLimit: 2)` — so the defaults themselves were
never exercised by anything that could fail.

### What the rig showed, and what it did not

**Command:** `CI=true flutter test --tags rig --run-skipped test/rig/paint_microbench_test.dart --plain-name "text paint at 50000"`
(matched 500,000 too — `--plain-name` is a substring).

```
  -- whole drawing --
      cache: layouts=817938 paragraphEvictions=208792 metricsEvictions=608634 liveParagraphs=512 liveMetrics=512
  -- working set --
      cache: layouts=17 paragraphEvictions=17 metricsEvictions=0 liveParagraphs=512 liveMetrics=512
...
04:40 +2: All tests passed!
```

Against the shipped `liveMetrics=4020 metricsEvictions=0`. The mutant is
glaring on the transcript — 608,634 metrics evictions where there should be
none — and the rig **asserts nothing**, so it prints and passes. Nor does the
corpus-scale row-10 block catch it, for the same LRU reason as mutant 6:

```
  -- row 10: extents-sweep non-interference --
    sweep (66522.34207401797 x 48478.932530765655 world units): layouts=12 paragraphEvictions=0 metricsEvictions=12
    repeat frame after the sweep: newLayouts=0 newParagraphEvictions=0 newMetricsEvictions=0 liveParagraphs=512 liveMetrics=512
02:05 +1: All tests passed!
```

### The test that closes it, and the second firing — **KILLED**

`the default metrics bound is not the paragraph bound`, added to
`flutter_text_measurer_test.dart` in commit `645b027`: measure
`kParagraphCacheLimit + 1` distinct strings on a **default-constructed**
measurer and assert no metrics eviction. The behavioural assertions come
first, deliberately — a test whose only failing line is
`expect(m.metricsLimit, kMetricsCacheLimit)` restates the mutation instead of
observing it.

**Command:** `CI=true flutter test test/flutter_text_measurer_test.dart`, same
mutation re-applied.

```
00:00 +10: the default metrics bound is not the paragraph bound
00:00 +10 -1: the default metrics bound is not the paragraph bound [E]
  Expected: <0>
    Actual: <1>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/flutter_text_measurer_test.dart 218:5          main.<fn>

00:00 +10 -1: clear empties both maps

Failing tests:
  test/flutter_text_measurer_test.dart: the default metrics bound is not the paragraph bound
00:00 +11 -1: Some tests failed.
```

**Verdict: KILLED, after a test was written for it.** Recorded as a survivor
first because that is what the run said. The finding it carries is about the
suite's shape, not this constant: a file that always passes both limits
explicitly cannot see a wrong default, and the same hole would hide a wrong
`paragraphLimit` default just as well.

## 8 — remove the `DraftCanvas` guard

**Target:** `packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart`,
`_requireMeasurer`. The widget quietly builds its own measurer, which is what
it did before Plan 3f.

```diff
     if (measurer is! FlutterTextMeasurer) {
-      throw ArgumentError.value(
-          measurer,
-          'document.textMeasurer',
-          'DraftCanvas requires a FlutterTextMeasurer. Build the measurer '
-              'first and pass it to the document:\n\n'
-              '    final measurer = FlutterTextMeasurer();\n'
-              '    final doc = DraftDocument.empty(measurer: measurer);\n');
+      return FlutterTextMeasurer();
     }
     return measurer;
```

**Command:** `CI=true flutter test`.

```
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: <Instance of 'ArgumentError'>
  Actual: <null>
   Which: is not an instance of 'ArgumentError'

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///.../test/draft_canvas_test.dart:401:5)

00:01 +154 ~1 -1: test/draft_canvas_test.dart: refuses a document whose measurer cannot lay out paragraphs [E]
  Test failed. See exception logs above.
  The test description was: refuses a document whose measurer cannot lay out paragraphs

Failing tests:
  test/draft_canvas_test.dart: refuses a document whose measurer cannot lay out paragraphs
00:03 +296 ~1 -1: Some tests failed.
```

**Verdict: KILLED**, by row 8's own test and nothing else.

## 9 — `measure()` does not store metrics

**Target:** `flutter_text_measurer.dart`, `measure`.

```diff
-    final key = _MetricsKey(text, style.handle);
-    _metrics[key] = _MetricsEntry(key, metrics);
     return metrics;
```

**Command:** `CI=true flutter test`.

```
00:01 +131 -1: test/flutter_text_measurer_test.dart: a repeat request lays out nothing and allocates no metrics [E]
  Expected: <1>
    Actual: <2>
  ... test/flutter_text_measurer_test.dart 26:5

00:01 +136 -2: test/flutter_text_measurer_test.dart: measure disposes its probe and leaves no paragraph entry [E]
  Expected: <1>
    Actual: <0>
  ... test/flutter_text_measurer_test.dart 156:5

00:01 +137 -3: test/flutter_text_measurer_test.dart: the metrics map evicts on its own bound, and it is not the paragraph one [E]
  Expected: <1>
    Actual: <0>
  ... test/flutter_text_measurer_test.dart 193:5

00:01 +137 -4: test/flutter_text_measurer_test.dart: clear empties both maps [E]
  Expected: <1>
    Actual: <0>
  ... test/flutter_text_measurer_test.dart 203:5

Failing tests:
  test/flutter_text_measurer_test.dart: a repeat request lays out nothing and allocates no metrics
  test/flutter_text_measurer_test.dart: clear empties both maps
  test/flutter_text_measurer_test.dart: measure disposes its probe and leaves no paragraph entry
  test/flutter_text_measurer_test.dart: the metrics map evicts on its own bound, and it is not the paragraph one
00:03 +293 ~1 -4: Some tests failed.
```

**Verdict: KILLED**, four tests. The first one is the row-1 mechanism at unit
scale: a repeat `measure()` lays the string out a second time.

## 10 — apply LOD inside `entityBounds`

**Target:** `packages/jet_cad_2d/lib/src/document/extents.dart` — the **engine**
package, which this plan does not otherwise touch. Copied aside before editing
and restored from the copy.

### The mutation has no exactly-reachable site

`entityBounds` is a pure function of stored document data. Its parameters are
`kind`, `payload`, `measurer`, `textStyle`, `textAttrs`, `text`,
`boundaryKind`, `boundaryPayload` — no camera, no screen scale, no reference to
any `DraftPainter`. Its three call sites are `draft_document.dart`'s
`_computeExtents`, `container_index.dart`'s index build and
`spatial_index.dart`'s incremental bound check; `DraftPainter._drawText` never
calls it at all. So "compare against a painter's `minTextCapPixels`" cannot be
written there. The nearest reachable form compares the raw world-space height
against a literal matching the constant's value — the mistake someone would
make forgetting the check needs a scale this function cannot perform:

```diff
       final attrs = resolveTextAttributes(payload, textAttrs, textStyle);
       final metrics = measurer.measure(text: text, style: textStyle);
+      if (payload.scalars[0] < 3.0) return Aabb2.empty();
       return textLocalBounds(attrs, metrics).transformedBy(
```

**Command:** `CI=true flutter test test/text_lod_test.dart` from
`packages/jet_cad_2d_flutter`, against the mutated engine package.

```
00:00 +0 -1: text below the threshold is culled and never measured [E]
  Expected: <1>
    Actual: <0>
  ... test/text_lod_test.dart 81:5

00:00 +0 -2: the same text at the same camera draws once LOD is off [E]
  Expected: <1>
    Actual: <0>
  ... test/text_lod_test.dart 108:5

00:00 +2 -3: culledTextCount is a per-frame figure, not a running total [E]
  Expected: <1>
    Actual: <0>
  ... test/text_lod_test.dart 171:5

00:00 +2 -3: doc.extents is bit-identical whichever threshold the painter runs at
00:00 +3 -3: painter and oracle cull the same text under a non-identity placement
00:00 +4 -3: Some tests failed.

Failing tests:
  test/text_lod_test.dart: culledTextCount is a per-frame figure, not a running total
  test/text_lod_test.dart: text below the threshold is culled and never measured
  test/text_lod_test.dart: the same text at the same camera draws once LOD is off
```

**Verdict: RESTATEMENT — the named killer cannot fire, and did not.** Row 6's
test, `doc.extents is bit-identical whichever threshold the painter runs at`,
**passed**. It reads `doc.extents` after a painter at 0.0 and again after one
at 1000.0, with `invalidateDerived()` between. `entityBounds` has no channel to
either painter's threshold, so it recomputes identically both times, and two
identical wrong answers compare equal. Criterion 6 is therefore **structurally
guaranteed rather than testable**: the invariant it states is true and worth
stating, and no fixture can distinguish "`entityBounds` is right" from
"`entityBounds` is uniformly wrong in a way no painter can trigger", because no
painter can trigger anything there at all.

This is not recorded as a kill and not as a failure. Plan 3c's log has two
mutants in the same position, both recorded as restatements; this is the third.

The mutation *is* caught, incidentally and by three other tests: a collapsed
bound drops the leaf out of the spatial index's query window, so the painter's
walk never reaches it and `culledTextCount` reads 0 where 1 was expected. That
is the real, if accidental, guard.

**Re-fired after `645b027`**, which added the row-7 pick test, the same
mutation reddens **four** tests — the new one through its non-vacuity guard:

```
00:00 +3 -4: picking a text entity gives the same hit at either threshold [E]
  Expected: true
    Actual: <false>
  the pick must land at threshold 0.0, or this row compares two misses

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/text_lod_test.dart 264:7                       main.<fn>.pickAfterPaintingAt
  test/text_lod_test.dart 273:19                      main.<fn>

Failing tests:
  test/text_lod_test.dart: culledTextCount is a per-frame figure, not a running total
  test/text_lod_test.dart: picking a text entity gives the same hit at either threshold
  test/text_lod_test.dart: text below the threshold is culled and never measured
  test/text_lod_test.dart: the same text at the same camera draws once LOD is off
```

Row 6's test still passes, for the reason above. The restatement stands.

## 11 — `culledTextCount` not reset per frame

**Target:** `draft_painter.dart`, `paint`.

```diff
     _skippedText = 0;
-    _culledText = 0;
     _textOps = 0;
```

**Command:** `CI=true flutter test`.

```
00:02 +171 ~1 -1: test/text_lod_test.dart: culledTextCount is a per-frame figure, not a running total [E]
  Expected: <1>
    Actual: <2>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/text_lod_test.dart 171:5                       main.<fn>

Failing tests:
  test/text_lod_test.dart: culledTextCount is a per-frame figure, not a running total
00:03 +296 ~1 -1: Some tests failed.
```

**Verdict: KILLED**, by the two-frame test and only that one.

## 12 — keep the metrics probe paragraph instead of disposing it

**Target:** `flutter_text_measurer.dart`, `measure`.

```diff
     final probe = _layOut(text, style, kMetricsProbeArgb);
     final metrics = _metricsOf(probe);
-    probe.dispose();
+    if (_paragraphs.length >= paragraphLimit) _evictOldestParagraph();
+    final probeKey = _ParagraphKey(text, style.handle, kMetricsProbeArgb);
+    _paragraphs[probeKey] = _ParagraphEntry(probeKey, probe);
     debugLastProbe = probe;
```

**Command:** `CI=true flutter test`.

```
00:01 +137 -1: test/flutter_text_measurer_test.dart: measure disposes its probe and leaves no paragraph entry [E]
  Expected: <0>
    Actual: <1>
  ... test/flutter_text_measurer_test.dart 155:5

00:01 +137 -2: test/flutter_text_measurer_test.dart: a metrics sweep does not evict drawn paragraphs [E]
  Expected: <0>
    Actual: <200>
  ... test/flutter_text_measurer_test.dart 175:5

00:01 +138 -3: test/flutter_text_measurer_test.dart: clear empties both maps [E]
  Expected: <1>
    Actual: <2>
  ... test/flutter_text_measurer_test.dart 202:5

Failing tests:
  test/flutter_text_measurer_test.dart: a metrics sweep does not evict drawn paragraphs
  test/flutter_text_measurer_test.dart: clear empties both maps
  test/flutter_text_measurer_test.dart: measure disposes its probe and leaves no paragraph entry
00:03 +294 ~1 -3: Some tests failed.
```

**Verdict: KILLED**, and by the unit suite rather than by the killer the spec
named. The spec expected the ladder's distinct-key column — a print, not an
assertion. Three unit tests fail instead, which is the better outcome: the
premise the probe-disposal decision rests on (ACI 7 resolves to white, so the
probe's black is almost never the drawn colour, so keeping it halves the
paragraph cache) is now defended by something that fails rather than by
something that has to be read.

## 13 — `DraftCanvas.dispose()` keeps calling `clear()`

**Target:** `draft_canvas.dart`, `dispose`.

```diff
   void dispose() {
     _changes.dispose();
+    _requireMeasurer().clear();
```

**Command:** `CI=true flutter test`.

```
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: <1>
  Actual: <0>

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///.../test/draft_canvas_test.dart:440:5)

00:01 +155 ~1 -1: test/draft_canvas_test.dart: disposing one canvas leaves a sibling cache warm [E]
  Test failed. See exception logs above.
  The test description was: disposing one canvas leaves a sibling cache warm

Failing tests:
  test/draft_canvas_test.dart: disposing one canvas leaves a sibling cache warm
00:03 +296 ~1 -1: Some tests failed.
```

**Verdict: KILLED**, by row 11's own test: the sibling's live paragraph count
drops from 1 to 0 when the other canvas is disposed.

## 14 — `minTextCapPixels` left out of `didUpdateWidget`

**Target:** `draft_canvas.dart`, `didUpdateWidget`.

```diff
         widget.drawText != oldWidget.drawText ||
-        widget.minTextCapPixels != oldWidget.minTextCapPixels ||
         widget.backend != oldWidget.backend) {
```

**Command:** `CI=true flutter test`.

```
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: <0.0>
  Actual: <3.0>

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///.../test/draft_canvas_test.dart:382:5)

00:01 +161 ~1 -1: test/draft_canvas_test.dart: changing minTextCapPixels rebuilds the painter [E]
  Test failed. See exception logs above.
  The test description was: changing minTextCapPixels rebuilds the painter

Failing tests:
  test/draft_canvas_test.dart: changing minTextCapPixels rebuilds the painter
00:03 +296 ~1 -1: Some tests failed.
```

**Verdict: KILLED**, by the prop-update test the spec named. The painter kept
the old 3.0 after the widget was rebuilt at 0.0.

## 15 — `DraftPainter.minTextCapPixels` defaulted to `0.0`

**Target:** `draft_painter.dart`, the constructor.

```diff
-    this.minTextCapPixels = kMinTextCapPixels,
+    this.minTextCapPixels = 0.0,
```

**Command:** `CI=true flutter test`.

```
00:02 +178 ~1 -1: test/text_lod_test.dart: text below the threshold is culled and never measured [E]
  Expected: <1>
    Actual: <0>
  ... test/text_lod_test.dart 81:5

00:02 +182 ~1 -2: test/text_lod_test.dart: culledTextCount is a per-frame figure, not a running total [E]
  Expected: <1>
    Actual: <0>
  ... test/text_lod_test.dart 171:5

Failing tests:
  test/text_lod_test.dart: culledTextCount is a per-frame figure, not a running total
  test/text_lod_test.dart: text below the threshold is culled and never measured
00:03 +295 ~1 -2: Some tests failed.
```

**Verdict: KILLED**, by the two tests in the file that construct a bare
`DraftPainter` and pass no knob — exactly the construction sites the spec said
would be needed, since the rig and the golden ladder both pass a threshold
explicitly and stay green under this mutation.

---

## The mutation that is not on the list: the metrics probe's key allocation

**Mutation that would be tested:** allocate a fresh `_MetricsKey` on every
`measure()` lookup instead of mutating the reusable `_metricsProbe`.

**Verdict: UNMEASURABLE on this side, with the reason.** `AllocationMeter`
lives in `packages/jet_cad_2d/test/invariants/vm_allocation_meter.dart` and
needs `vm_service`, which `jet_cad_2d_flutter` does not depend on — Plan 3c
carry-forward item 3. The split cache is Flutter-side, so no VM allocation
profile can watch it. `a repeat request lays out nothing and allocates no
metrics` asserts `identical(a, b)` on two `measure()` calls, which proves the
returned **value** is cached and says nothing about whether the lookup
allocated a key on the way to it. The mutation would therefore be green under
every test this package can run.

Recorded here rather than listed as a sixteenth mutant with a killer that
cannot kill it, per the spec's own instruction. Closing it means moving
`AllocationMeter` into `packages/jet_cad_2d/lib/src/testing/`, which is out of
scope for this plan.
