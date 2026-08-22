# Task 8 report: the harness measures LOD, and the threshold ladder

## Low Power Mode

```
$ pmset -g | grep lowpowermode
 lowpowermode         0
```

Recorded **before** the first timed run, per the task's Ruling. Off. Every
timing below (the widget-rig `R1`/`R3` stats and the device `flutter drive`
rows) carries this mark: this was not a Low Power Mode-contaminated run.

## What changed

1. `apps/dev_harness_2d/lib/main.dart` — added `kMinTextCap`, a
   `String.fromEnvironment('LOD', ...)` (not `bool.fromEnvironment`, for the
   reason the doc comment states: that reads `--dart-define=LOD=1` as
   `false`), forwarded to `DraftCanvas(minTextCapPixels: kMinTextCap)`.
   Throws on any value other than `"true"`/`"false"` — at first read, since
   this is a lazy top-level `final`, not at process startup literally (Fix
   round 1 corrected the doc comment's wording on this point).
2. `apps/dev_harness_2d/lib/measurement_rig.dart` — `printTextCounters`'s
   first line now also prints `culledText=${painter.culledTextCount}` and
   (Fix round 1) `minTextCapPixels=${painter.minTextCapPixels}`.
3. `packages/jet_cad_2d_flutter/lib/src/flutter_text_measurer.dart` —
   `kMetricsCacheLimit`'s doc comment now states the measured count (4,020)
   instead of "derived from the corpus generator, not yet measured."
4. (Fix round 1) `packages/jet_cad_2d_flutter/test/rig/paint_microbench_test.dart`
   — the threshold-ladder loop now lives in the file itself, gated behind a
   `LADDER` dart-define (`kLadderThresholds`), so it is a no-op by default
   and reproduces this report's exact table when set.

Commits:
- `4a66f13` feat: the dev harness forwards a LOD define to the painter
- `d069067` docs: kMetricsCacheLimit's distinct-key count is measured, not derived
- `ad3d6d1` fix: measure the true distinct-key count, land the ladder in-tree, and show LOD's threshold in device transcripts (Fix round 1)

The threshold ladder itself (Step 4) was **first** produced by a temporary,
unreproducible loop, transcribed and then reverted — flagged in review as a
cost this repository has paid for before ("not reproducible from what was
committed"). Fix round 1 replaced that with the gated, permanent loop in
commit `ad3d6d1`, described above. The table in the next section is from
that permanent loop, run with `--dart-define=LADDER=...` as shown, and is
reproducible from the committed tree by anyone who runs the same command.

## The threshold ladder (50,000-entity corpus, `textRigCorpus`)

Ladder command (widget-level rig, JIT/`PictureRecorder`, not profile-mode —
a **relative** signal only, per the file's own header) — this now reproduces
**exactly**, from the committed tree, with no local patch required:

```
cd packages/jet_cad_2d_flutter && CI=true flutter test --tags rig --run-skipped \
  test/rig/paint_microbench_test.dart --plain-name "text paint at 50000" \
  --dart-define=LADDER=0.0,1.0,2.0,3.0,4.0,6.0,10.0
```

`kLadderThresholds` (`test/rig/paint_microbench_test.dart`) parses the
`LADDER` define into the threshold list; empty (the default) leaves the new
loop a no-op, confirmed by running the plain command with no `LADDER` define
and grepping the transcript for `threshold ladder` — absent. Three readings
per row, from **three** different objects, on purpose:

- **`distinctKeys`** — the number this table exists to produce, and the one
  Ruling 4's single permitted `kParagraphCacheLimit` raise needs recorded
  beside it. A query-only `TextKeySink` pass at that (threshold, camera):
  draws nothing, lays nothing out, and counts the true number of distinct
  `(text, styleHandle, argb)` triples visible. This is **not** the same
  thing as `layouts` below, and the first version of this report conflated
  them — see "Fix round 1".
- **`layouts`/`paragraphEvictions`/`liveParagraphs`** — a *fresh*
  `FlutterTextMeasurer` per iteration, passed as the `CanvasDrawSink`'s
  `measurer:`, the object `paragraphFor` (the drawn, coloured cache) writes
  to. Fresh each time so `layouts` reports what one cold paint at that
  threshold costs, not a number contaminated by whichever keys the
  *previous* threshold's paint happened to leave live in a shared cache.
- **`metricsEvictions`/`liveMetrics`** — the corpus's own
  `document.textMeasurer` (the object `textRigCorpus` built the document
  with). `DraftPainter._drawText`'s LOD check calls `.measure()` on *that*
  object (`draft_painter.dart:873`), not on the sink's measurer, so it is
  the only one that means anything for this column. `resetCounters()` was
  called on it before each paint to isolate that paint's eviction delta.

Raw stdout of the reproducible run (`--dart-define=LADDER=...` above),
unedited:

```
  -- threshold ladder --
    threshold=0.0 whole drawing: distinctKeys=4140 layouts=4140 paragraphEvictions=3628 metricsEvictions=0 culledText=0 liveParagraphs=512 liveMetrics=4020
    threshold=0.0 working set: distinctKeys=18 layouts=18 paragraphEvictions=0 metricsEvictions=0 culledText=0 liveParagraphs=18 liveMetrics=4020
    threshold=1.0 whole drawing: distinctKeys=4140 layouts=4140 paragraphEvictions=3628 metricsEvictions=0 culledText=0 liveParagraphs=512 liveMetrics=4020
    threshold=1.0 working set: distinctKeys=18 layouts=18 paragraphEvictions=0 metricsEvictions=0 culledText=0 liveParagraphs=18 liveMetrics=4020
    threshold=2.0 whole drawing: distinctKeys=4140 layouts=4140 paragraphEvictions=3628 metricsEvictions=0 culledText=0 liveParagraphs=512 liveMetrics=4020
    threshold=2.0 working set: distinctKeys=18 layouts=18 paragraphEvictions=0 metricsEvictions=0 culledText=0 liveParagraphs=18 liveMetrics=4020
    threshold=3.0 whole drawing: distinctKeys=3876 layouts=3876 paragraphEvictions=3364 metricsEvictions=0 culledText=414 liveParagraphs=512 liveMetrics=4020
    threshold=3.0 working set: distinctKeys=18 layouts=18 paragraphEvictions=0 metricsEvictions=0 culledText=0 liveParagraphs=18 liveMetrics=4020
    threshold=4.0 whole drawing: distinctKeys=1123 layouts=1123 paragraphEvictions=611 metricsEvictions=0 culledText=3368 liveParagraphs=512 liveMetrics=4020
    threshold=4.0 working set: distinctKeys=18 layouts=18 paragraphEvictions=0 metricsEvictions=0 culledText=0 liveParagraphs=18 liveMetrics=4020
    threshold=6.0 whole drawing: distinctKeys=94 layouts=94 paragraphEvictions=0 metricsEvictions=0 culledText=4751 liveParagraphs=94 liveMetrics=4020
    threshold=6.0 working set: distinctKeys=18 layouts=18 paragraphEvictions=0 metricsEvictions=0 culledText=0 liveParagraphs=18 liveMetrics=4020
    threshold=10.0 whole drawing: distinctKeys=0 layouts=0 paragraphEvictions=0 metricsEvictions=0 culledText=4928 liveParagraphs=0 liveMetrics=4020
    threshold=10.0 working set: distinctKeys=18 layouts=18 paragraphEvictions=0 metricsEvictions=0 culledText=0 liveParagraphs=18 liveMetrics=4020
```

| threshold | camera | distinctKeys | layouts | paragraphEvictions | metricsEvictions | culledText | liveParagraphs | liveMetrics |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| 0.0 | whole drawing | 4140 | 4140 | 3628 | 0 | 0 | 512 | 4020 |
| 0.0 | working set | 18 | 18 | 0 | 0 | 0 | 18 | 4020 |
| 1.0 | whole drawing | 4140 | 4140 | 3628 | 0 | 0 | 512 | 4020 |
| 1.0 | working set | 18 | 18 | 0 | 0 | 0 | 18 | 4020 |
| 2.0 | whole drawing | 4140 | 4140 | 3628 | 0 | 0 | 512 | 4020 |
| 2.0 | working set | 18 | 18 | 0 | 0 | 0 | 18 | 4020 |
| 3.0 | whole drawing | 3876 | 3876 | 3364 | 0 | 414 | 512 | 4020 |
| 3.0 | working set | 18 | 18 | 0 | 0 | 0 | 18 | 4020 |
| 4.0 | whole drawing | 1123 | 1123 | 611 | 0 | 3368 | 512 | 4020 |
| 4.0 | working set | 18 | 18 | 0 | 0 | 0 | 18 | 4020 |
| 6.0 | whole drawing | 94 | 94 | 0 | 0 | 4751 | **94** | 4020 |
| 6.0 | working set | 18 | 18 | 0 | 0 | 0 | 18 | 4020 |
| 10.0 | whole drawing | 0 | 0 | 0 | 0 | 4928 | 0 | 4020 |
| 10.0 | working set | 18 | 18 | 0 | 0 | 0 | 18 | 4020 |

**`distinctKeys` equals `layouts` on every one of the fourteen rows,
measured independently by two unrelated mechanisms (a query-only sink vs. a
cold-cache paint's miss count).** They are not the same quantity by
definition — `layouts` would exceed `distinctKeys` if any key's repeat draw
inside one frame were separated by 512+ other distinct keys and evicted
before that repeat, forcing a second miss. The agreement says that never
happens in this corpus at this camera: every distinct key's repeats are
drawn close enough together in traversal order that none of them are ever
evicted-then-redrawn within a single frame, even at threshold 0.0 where
4,140 distinct keys chase a 512-entry cache. That is a real, checked fact
about this corpus's traversal order, not an assumption carried over from
the first draft of this report — see "Fix round 1" for the wording error it
replaces. Because the two numbers agree on every row here, nothing below
this point needs revising: every place this report already used `layouts`
to reason about feasibility was, on this corpus, also correct as a
statement about the true distinct-key count.

At threshold 10.0 every whole-drawing candidate is culled (`culledText=4928`,
`layouts=0`) — 4,928 is therefore the total candidate pool at that camera.
`culledText` rises monotonically toward that ceiling as the threshold climbs;
the exact intermediate arithmetic is not load-bearing, the shape is.

**Working-set camera: flat across the whole ladder.** Every threshold from
0.0 to 10.0 gives identical numbers (18 layouts, 18 distinct keys, 0
culled, 18 live paragraphs). The earlier margin print in this same test run
reports the working set's smallest surviving cap height at 53.67 px — over
5x the widest threshold tried — so this camera cannot show a step inside
the range asked for. This is expected, not a gap in the ladder: it is the
camera a frame budget is actually about, and it is nowhere near the cliff.

**Whole-drawing camera: a step, not a curve, landing between 3.0 and 6.0.**
`culledText` is flat at 0 through threshold 2.0, jumps to 414 at 3.0 (the
shipped default — LOD MARGIN print in the same run: smallest surviving cap
height 3.0005 px, 0.02% clear — see "Fix round 1" for a discrepancy against
a different pinned figure elsewhere in the file), then to 3,368 at 4.0, then
to 4,751 at 6.0, then to the full 4,928 at 10.0. `generate_document.dart`'s
fixed-height-80.0
attributes (about 4,000 of the ~4,928 candidates here) are the mass behind
this: at a small enough camera scale their pixel cap heights cluster tightly
around a few pixels, so a handful of threshold values sweep nearly all of
them. It is **not a single-point cliff** the way the brief's idealization
suggested, though — the corpus's `mirroredFraction`/`nonUniformFraction`
placement transforms give per-instance `scaleMagnitude` some spread even at
one fixed logical height, so the mass crosses over about a 3-unit-wide band
(3.0 → 6.0) rather than one exact threshold value. Reporting this rather than
smoothing it, per the brief's instruction.

**Feasibility of 3.0 (the shipped default), read off `distinctKeys` and
`liveParagraphs`:** at 3.0 the whole-drawing camera needs 3,876 distinct
`(text, styleHandle, argb)` keys in one frame against a 512-entry cache —
the true count, from the query-only `TextKeySink` pass, not a proxy. The
paragraph cache is thrashing at that threshold: `liveParagraphs=512` (at
the cap) and `paragraphEvictions=3364` in that one cold paint. The **steady
state** is worse than one cold paint suggests, and is not something the
ladder's cold-cache methodology can show by itself — it comes from the
*non-ladder* part of the same test run (the `[text on]` block, one shared
measurer already warm from twenty prior paints), quoted verbatim:

```
    [text on]
      ...
      newLayouts=3876 newParagraphEvictions=3876
      cache: layouts=224808 paragraphEvictions=224296 metricsEvictions=0 liveParagraphs=512 liveMetrics=4020
```

`newLayouts=3876` on an **already-warm** cache — the same 3,876 as the
cold-paint figure — means every one of that frame's distinct keys misses
again on a frame that changed nothing, which is the zero-cache-hit,
every-repeated-frame-relayouts-everything reading the report's first draft
described in prose without pasting. This line is what makes that claim a
measurement rather than an inference. The committed test's own
instrumentation confirms the same number independently, from a third,
unrelated mechanism (a `TextKeySink` count taken before any of this, at the
shipped default, with nothing warmed):

```
    DISTINCT CACHE KEYS: 3876   (limit 512) OVER
```

Three independent readings — the ladder's own `TextKeySink` pass, the
warm-cache `newLayouts` delta, and the pre-existing `DISTINCT CACHE KEYS`
print — all land on 3,876. The thrashing does not clear until the camera
crosses into the 4.0-6.0 band: at 6.0, `distinctKeys=liveParagraphs=94` —
comfortably under 512, matching `paragraphEvictions=0`. So **3.0 is not
feasible against the current 512-entry paragraph cache on the whole-drawing
camera**; the zero-new-layouts gate at that camera would need either a
higher threshold (into the step) or Ruling 4's one permitted raise of
`kParagraphCacheLimit` spent — and 3,876 is the number to record beside
that raise if it is spent, now that it is measured rather than inferred.
The working-set camera, the one the frame budget is actually about, is fine
at every threshold tried, including 0.0.

## The measured count written into `kMetricsCacheLimit`

`liveMetrics=4020` at **every** threshold and **both** cameras in the table
above — the metrics cache is untouched by level of detail entirely. This
follows from where it is filled: `entityBounds` (`extents.dart:66`) calls
`measurer.measure()` once per text/attrib entity while the document is being
built (and again for `SpatialIndex` construction, also a full, unfiltered
sweep), before any camera exists. `DraftPainter`'s LOD check
(`draft_painter.dart:873`) only ever touches keys already resident from that
sweep. So "the camera it was measured at" is, honestly, **none** — the count
is camera-independent by construction, confirmed empirically by it reading
identically on both the whole-drawing and working-set cameras across all
seven thresholds. The doc comment states this. The number (4,020) matches
the pre-existing estimate in the comment exactly (4,000 `ATTRnnnnn` strings +
20 distinct labels), which is unsurprising for a deterministic generator but
is now a measured fact rather than an assumption.

## Device runs (`flutter drive --profile -d macos`)

**Superseded by Fix round 1 below — see that section for the transcripts
that actually distinguish the two arms, and for the one attempt that hung
and had to be killed.** The pair reproduced here originally showed
`culledText=0` in both and, critically, printed no field that would have
shown the two runs were even given different thresholds — a gap the review
caught. Fix round 1 added `minTextCapPixels=` to the `text:` line and reran
both.

## Full test suite, green

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test
...
+297: All tests passed!

$ cd packages/jet_cad_2d && dart test
...
+777: All tests passed!
```

`flutter analyze` and `dart format --output=none --set-exit-if-changed .`
were also run on `jet_cad_2d_flutter` after the doc-comment edit: no issues,
no formatting diff.

## Final `git status` — no trap file, no PNG staged

```
On branch main
Your branch is ahead of 'origin/main' by 22 commits.
  (use "git push" to publish your local commits)

Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
	modified:   apps/dev_harness/analysis_options.yaml
	modified:   apps/dev_harness/macos/Podfile
	modified:   apps/dev_harness/macos/Runner.xcodeproj/project.pbxproj

no changes added to commit (use "git add" and/or "git commit -a")
```

The three modified files are the pre-existing `flutter pub get` artefacts in
`apps/dev_harness` (a different app from `dev_harness_2d`) that were already
showing as modified before this task began, per the brief's own note — left
untouched, not staged, not committed. `apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj`
shows clean (reverted). `packages/jet_cad_2d_flutter/test/rig/paint_microbench_test.dart`
shows clean (the ladder loop was never committed). No `.png` appears anywhere
in this status.

## Commits made this task

```
4a66f13 feat: the dev harness forwards a LOD define to the painter
d069067 docs: kMetricsCacheLimit's distinct-key count is measured, not derived
```

---

## Fix round 1 (review response)

Four items, addressed in commit `ad3d6d1` plus this appendix. Also folded
directly into the sections above where that made the report internally
consistent, rather than left to contradict a correction appended only here.

### 1. The whole-drawing repeat-frame line, pasted verbatim

From a fresh run of the plain rig command (no `LADDER` define — this line
comes from the pre-existing, non-ladder part of the test), reproduced twice
more since, always identical:

```
    [text on]
      R1 paint          p50=544.026ms p95=564.592ms min=526.763ms (n=37)
      R3 query-only     p50=134.071ms p95=149.646ms min=131.743ms (n=120)
      ops/frame: 2066358  canvasCalls: 688786
      textOps: 4514  culledText: 414  skippedText: 0
      newLayouts=3876 newParagraphEvictions=3876
      cache: layouts=224808 paragraphEvictions=224296 metricsEvictions=0 liveParagraphs=512 liveMetrics=4020
      screen-space leaves: 358415  dashSpans: 0  collapsed: 239256
```

`newLayouts=3876` on a measurer already warm from twenty prior paints
(`measure()`'s own warm-up loop) plus the earlier "text on" repetitions —
i.e. a repeated, unchanged frame relaying out its entire visible text every
time. That is the zero-cache-hit steady state the first draft described in
prose without a citation. It is now cited.

### 2. "Distinct paragraph keys" corrected

The first draft's feasibility paragraph said "3,876 distinct paragraph keys"
where it meant `layouts` — a cold-paint miss count, not a key count. Fixed
in place in "The threshold ladder" section above: the ladder now carries a
`distinctKeys` column read from a query-only `TextKeySink` pass (draws
nothing, lays nothing out), independent of `layouts`. The two happen to
agree on all fourteen rows in this corpus, which is reported as a checked
fact, not assumed. The pre-existing instrumentation's own independent
measurement of the same quantity, quoted verbatim from the same run as
item 1:

```
    DISTINCT CACHE KEYS: 3876   (limit 512) OVER
```

Three unrelated mechanisms — the ladder's `TextKeySink`, the warm-cache
`newLayouts` delta, and this pre-existing print — all read 3,876. That is
the number recorded for Ruling 4's single permitted `kParagraphCacheLimit`
raise, if it is ever spent: measured, not inferred from a proxy.

### 3. Device runs: the wiring claim, and one hang

**First attempt (this round): `LOD=true` hung.** Run in the background per
this session's normal pattern, it sat at 0% CPU for about fifteen minutes
against a harness that normally finishes in under a minute. The coordinator
killed it and reverted `project.pbxproj`. Lesson taken: a background job in
this environment cannot reliably deliver its completion notification back
into a session turn boundary, so a hang here reads as silence rather than
failure — the fix is running the pair in the foreground with a
self-enforced wall-clock kill, not trusting the backgrounding path for a
`flutter drive` invocation.

**Second attempt: both completed cleanly**, each in under a minute, run in
the foreground with a 300-second hard kill that never triggered:

```
$ cd apps/dev_harness_2d && flutter drive --profile -d macos --driver=test_driver/integration_test.dart \
    --target=integration_test/frame_timing_test.dart \
    --dart-define=TEXT=true --dart-define=DRAW_TEXT=true --dart-define=LOD=true
...
flutter: 00:00 +0: R2 pan and zoom
flutter: R2 (50000) frames=242
flutter:   build  p50=7.12ms p95=8.95ms max=295.71ms
flutter:   raster p50=7.92ms p95=17.52ms max=83.25ms
flutter:   lineweightScale=1.0
flutter:   screenSpaceLeafCount=2170 dashSpans=48323 collapsed=334 canvasCalls=23
flutter:   fills=0 skippedFills=0
flutter:   backend=vertices triangles=217758 drawVerticesCalls=20
flutter:   text: corpus=on draw=on minTextCapPixels=3.0 textOps=23 skippedText=0 culledText=0
flutter:   paragraphs: newLayouts=0 newParagraphEvictions=0 newMetricsEvictions=0 liveParagraphs=512 liveMetrics=4020
flutter: 00:09 +1: R4a leaf edit per frame
flutter: R4a (50000) frames=202
flutter:   build  p50=8.56ms p95=9.00ms max=285.75ms
flutter:   raster p50=4.25ms p95=5.09ms max=77.17ms
flutter:   command p50=0.08ms p95=0.12ms max=0.20ms
flutter:   overlay=1 threshold=2540 rebuilds=0 handles burned=201
flutter:   screenSpaceLeafCount=2023 dashSpans=46197 collapsed=294 canvasCalls=18
flutter:   fills=0 skippedFills=0
flutter:   backend=vertices triangles=206747 drawVerticesCalls=16
flutter:   text: corpus=on draw=on minTextCapPixels=3.0 textOps=18 skippedText=0 culledText=0
flutter:   paragraphs: newLayouts=0 newParagraphEvictions=0 newMetricsEvictions=0 liveParagraphs=512 liveMetrics=4020
flutter: 00:18 +2: R4b instance drag per frame
flutter: R4b (50000) frames=202
flutter:   build  p50=6.63ms p95=7.17ms max=286.79ms
flutter:   raster p50=3.46ms p95=3.63ms max=55.76ms
flutter:   command p50=82.08ms p95=86.30ms max=98.47ms
flutter:   rebuilds=200 over 200 frames
flutter:   screenSpaceLeafCount=2079 dashSpans=47745 collapsed=260 canvasCalls=18
flutter:   fills=0 skippedFills=0
flutter:   backend=vertices triangles=211514 drawVerticesCalls=12
flutter:   text: corpus=on draw=on minTextCapPixels=3.0 textOps=18 skippedText=0 culledText=0
flutter:   paragraphs: newLayouts=0 newParagraphEvictions=0 newMetricsEvictions=0 liveParagraphs=512 liveMetrics=4020
flutter: 00:42 +3: (tearDownAll)
...
flutter: 00:42 +4: All tests passed!
All tests passed.
```

```
$ cd apps/dev_harness_2d && flutter drive --profile -d macos --driver=test_driver/integration_test.dart \
    --target=integration_test/frame_timing_test.dart \
    --dart-define=TEXT=true --dart-define=DRAW_TEXT=true --dart-define=LOD=false
...
flutter: 00:00 +0: R2 pan and zoom
flutter: R2 (50000) frames=242
flutter:   build  p50=7.00ms p95=9.01ms max=310.83ms
flutter:   raster p50=8.18ms p95=16.72ms max=87.20ms
flutter:   lineweightScale=1.0
flutter:   screenSpaceLeafCount=2170 dashSpans=48323 collapsed=334 canvasCalls=23
flutter:   fills=0 skippedFills=0
flutter:   backend=vertices triangles=217758 drawVerticesCalls=20
flutter:   text: corpus=on draw=on minTextCapPixels=0.0 textOps=23 skippedText=0 culledText=0
flutter:   paragraphs: newLayouts=0 newParagraphEvictions=0 newMetricsEvictions=0 liveParagraphs=512 liveMetrics=4020
flutter: 00:09 +1: R4a leaf edit per frame
flutter: R4a (50000) frames=202
flutter:   build  p50=8.52ms p95=8.88ms max=284.02ms
flutter:   raster p50=4.22ms p95=4.94ms max=84.31ms
flutter:   command p50=0.07ms p95=0.12ms max=0.15ms
flutter:   overlay=1 threshold=2540 rebuilds=0 handles burned=201
flutter:   screenSpaceLeafCount=2023 dashSpans=46197 collapsed=294 canvasCalls=18
flutter:   fills=0 skippedFills=0
flutter:   backend=vertices triangles=206747 drawVerticesCalls=16
flutter:   text: corpus=on draw=on minTextCapPixels=0.0 textOps=18 skippedText=0 culledText=0
flutter:   paragraphs: newLayouts=0 newParagraphEvictions=0 newMetricsEvictions=0 liveParagraphs=512 liveMetrics=4020
flutter: 00:18 +2: R4b instance drag per frame
flutter: R4b (50000) frames=202
flutter:   build  p50=6.59ms p95=7.10ms max=286.92ms
flutter:   raster p50=3.45ms p95=3.62ms max=55.31ms
flutter:   command p50=81.95ms p95=88.45ms max=93.69ms
flutter:   rebuilds=200 over 200 frames
flutter:   screenSpaceLeafCount=2079 dashSpans=47745 collapsed=260 canvasCalls=18
flutter:   fills=0 skippedFills=0
flutter:   backend=vertices triangles=211514 drawVerticesCalls=12
flutter:   text: corpus=on draw=on minTextCapPixels=0.0 textOps=18 skippedText=0 culledText=0
flutter:   paragraphs: newLayouts=0 newParagraphEvictions=0 newMetricsEvictions=0 liveParagraphs=512 liveMetrics=4020
flutter: 00:42 +3: (tearDownAll)
...
flutter: 00:42 +4: All tests passed!
All tests passed.
```

**The two arms now visibly differ**: `minTextCapPixels=3.0` throughout the
first transcript, `minTextCapPixels=0.0` throughout the second — everything
else (frame counts, triangle counts, `textOps`, `culledText=0`) is identical
between them, because this device rig's camera stays well above both
thresholds (consistent with the widget-rig ladder's working-set row, which
never culls anywhere in 0.0–10.0). That identity is now visibly a fact
about the camera, not an artefact of the define failing to reach the
painter — the one field the review asked for is what makes that
distinction legible. The claim that the wiring itself works rests, as
before, on the widget-level rig above (`test/rig/paint_microbench_test.dart`),
which does exercise a camera where the cull fires (`culledText=414` at the
shipped default, `culledText=0` at `LOD=false`'s effective `0.0`) — the
device pair corroborates that the define reaches this far without
contradicting it, on a camera that cannot itself show the delta.

`project.pbxproj` was reverted with `git checkout --` after each of the
three device attempts (the hung one included, by the coordinator) and is
confirmed clean below.

### 4. Ladder reproducibility

The loop now lives permanently in
`packages/jet_cad_2d_flutter/test/rig/paint_microbench_test.dart`, gated
behind `kLadderThresholds` (parsed from a `LADDER` dart-define; empty and a
no-op by default — confirmed by running the plain command with no `LADDER`
define and finding no `-- threshold ladder --` section in the transcript).
The exact command in "The threshold ladder" section above was re-run from
the committed tree, after commit `ad3d6d1`, and reproduced the table
byte-for-byte against the two prior runs of the same loop. No patch file,
no manual re-application — anyone who checks out this repository at
`ad3d6d1` or later gets the same table from the same command.

### Minor items

- **3.0005 px vs. 3.0006 px.** Three independent runs this session — the
  original ladder measurement, this round's plain-command rerun, and the
  reproducibility check in item 4 — all measured the whole-drawing camera's
  smallest surviving cap height as **3.0005 px**, byte-for-byte identical
  each time. The pinned figure of **3.0006 px** at
  `test/rig/paint_microbench_test.dart:313` predates this task (committed
  in `666afac`, an earlier task in this plan) and was not touched here — it
  belongs to that task's own narrative, and rewriting someone else's pinned
  measurement from a different task on a guess about its cause would be its
  own kind of unverified claim. The two values differ only in the fifth
  significant digit, inside the bisection's declared 1e-4 relative
  tolerance, and both round to the same reported margin ("0.02% clear").
  Left as a visible discrepancy rather than silently reconciled by editing
  either number.
- **`kMinTextCap`'s "throws at startup" wording.** Corrected in
  `apps/dev_harness_2d/lib/main.dart`: it is a lazy top-level `final`, so an
  unrecognised `LOD` value throws at `_HarnessAppState.build()`'s first
  read of it, not literally at process startup, though for an ordinary
  `flutter run`/`flutter drive` invocation that is loud and immediate
  enough to be the same thing in practice.

### Full suite, real counts

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test
...
00:03 +297 ~1: All tests passed!

$ cd packages/jet_cad_2d && dart test
...
00:02 +777: All tests passed!
```

`jet_cad_2d_flutter`: **297 passed, 1 skipped, 0 failed.** The one skip is
the rig test file's own tag gate (`@Tags(['rig'])`) — an ordinary `flutter
test` run does not pass `--tags rig --run-skipped`, so
`test/rig/paint_microbench_test.dart` (including the new, gated ladder
loop) is skipped rather than run, which is the intended behaviour for a
rig that costs minutes. `jet_cad_2d`: **777 passed, 0 skipped, 0 failed.**
`flutter analyze` / `dart analyze` and `dart format
--output=none --set-exit-if-changed .` are clean on both packages after
this round's edits.

### Final `git status`, this round

```
 M ../../apps/dev_harness/analysis_options.yaml
 M ../../apps/dev_harness/macos/Podfile
 M ../../apps/dev_harness/macos/Runner.xcodeproj/project.pbxproj
```

(paths relative to `packages/jet_cad_2d`, where this was last checked; same
three files as `git status` from the repository root). Only the three
pre-existing `apps/dev_harness` artefacts remain modified — the same three
noted at the start of this task, untouched throughout. No
`apps/dev_harness_2d` pbxproj diff. No `.png` anywhere in the status. No
uncommitted change to any file this task is responsible for.

### Commits, Fix round 1

```
ad3d6d1 fix: measure the true distinct-key count, land the ladder in-tree, and show LOD's threshold in device transcripts
```

No further commit was needed for the device-run transcripts or the suite
counts above — they are measurements appended to this report, not code
changes.
