# Task 3 report: every reader of the eviction counter moves with it

## Summary

All nine red call sites are fixed:

- `apps/dev_harness_2d/lib/measurement_rig.dart` — `printTextCounters` signature
  (`:145-159`) and its one caller in `runR2Rig` (`:217-236`).
- `apps/dev_harness_2d/integration_test/frame_timing_test.dart` — both R4a
  (`:265`) and R4b (`:323`) call sites.
- `packages/jet_cad_2d_flutter/test/rig/paint_microbench_test.dart` — the
  two-measurer block and its comment (`:150-160`), and the counter prints
  (`:285-305`).
- `packages/jet_cad_2d_flutter/test/canvas_draw_sink_test.dart` — audited,
  no change needed (see Step 5 below).

Commit: `08b778515e120fbaa56995a9d328b7124f1cb1e6` —
"refactor: report paragraph and metrics evictions apart".

## Step 1 & 2 — measurement_rig.dart

`printTextCounters` now takes `paragraphEvictionsBefore` and
`metricsEvictionsBefore` instead of `evictionsBefore`, and its second print
line reports `newParagraphEvictions`, `newMetricsEvictions`,
`liveParagraphs`, and `liveMetrics` — no more blended "evictions" total. The
new comment above the print:

```dart
  // Two eviction numbers, not one. A paragraph eviction released native glyph
  // memory and guarantees a future re-layout; a metrics eviction dropped four
  // doubles. Ruling 54: a blended number hides which half moved.
```

`runR2Rig`'s one call site now captures both `paragraphEvictionsBefore` and
`metricsEvictionsBefore` before the forced repaint and passes both through.

Verification:

```
$ grep -n "evictionCount\|evictionsBefore" apps/dev_harness_2d/lib/measurement_rig.dart
149:    required int paragraphEvictionsBefore,
150:    required int metricsEvictionsBefore}) {
160:      'newParagraphEvictions=${m.paragraphEvictionCount - paragraphEvictionsBefore} '
161:      'newMetricsEvictions=${m.metricsEvictionCount - metricsEvictionsBefore} '
223:    final paragraphEvictionsBefore = sink.measurer.paragraphEvictionCount;
224:    final metricsEvictionsBefore = sink.measurer.metricsEvictionCount;
236:        paragraphEvictionsBefore: paragraphEvictionsBefore,
237:        metricsEvictionsBefore: metricsEvictionsBefore);
```

Every hit is one of the new names, as required.

## Step 3 — frame_timing_test.dart

Both R4a (`:264-282`) and R4b (`:321-337`) now capture
`paragraphEvictionsBefore`/`metricsEvictionsBefore` from
`app.sink.measurer` and pass both to `printTextCounters`. No other
`evictionCount`/`evictionsBefore` references remain in the file.

## Step 4 — paint_microbench_test.dart: the non-mechanical part

The "text paint at $entityCount" test used to build two measurers
(`sinkMeasurer` for the `CanvasDrawSink`, `docMeasurer` passed into
`textRigCorpus` to build the document) with a comment explaining that
production had two caches because `DraftCanvas` built its own measurer for
the sink and never touched `document.textMeasurer`. Plan 3f removes exactly
that wiring — the document now owns one `FlutterTextMeasurer` that
`DraftCanvas` borrows for the sink — so that comment's premise is false in
the tree and the rig's two-measurer shape no longer matches production.

Collapsed to one `measurer` used both to build the corpus
(`textRigCorpus(entityCount, measurer: measurer)`) and to build every
`CanvasDrawSink` in the test. The rewritten comment, verbatim:

```dart
      // One measurer, because production has one. The document owns it and
      // `DraftCanvas` borrows it for the sink, so the painter's metrics
      // requests and the sink's drawn paragraphs land in the same object —
      // metrics in its colour-free map, paragraphs in its coloured one. Before
      // Plan 3f these were two `FlutterTextMeasurer`s with two caches, and this
      // rig built two to match; that wiring is gone.
      final measurer = FlutterTextMeasurer();
```

This states explicitly that the file changed because the design changed
(not a tidy-up), and that a second measurer here would silently measure a
wiring that no longer exists — which is the constraint Task 8/Task 14 (the
two later editors of this file) must not violate.

The counter prints at the old `:298-305` are now:

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

Verification that no `sinkMeasurer`/`docMeasurer`/bare `evictionCount`
remain:

```
$ grep -n "sinkMeasurer\|docMeasurer\|evictionCount\|evictionsBefore" packages/jet_cad_2d_flutter/test/rig/paint_microbench_test.dart
(no output)
```

(Note: the first `test('paint and query at $entityCount', ...)` block,
lines 61-139, already used a single `measurer` and is untouched by this
task — it never had the two-measurer shape.)

## Step 5 — canvas_draw_sink_test.dart audit

```
$ grep -n "layoutCount\|liveParagraphCount\|evictionCount" packages/jet_cad_2d_flutter/test/canvas_draw_sink_test.dart
98:    expect(measurer.layoutCount, 1);
99:    expect(measurer.liveParagraphCount, 1);
```

Confirmed: `:98` reads `layoutCount`, `:99` reads `liveParagraphCount`.
Both keep their old names and meanings per Task 2's interface contract.
**No change made to this file.**

## Step 6 — verification

### `flutter analyze` — packages/jet_cad_2d_flutter

```
$ cd packages/jet_cad_2d_flutter && flutter analyze
Resolving dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (105.0.0 available)
  analyzer 13.3.0 (14.1.0 available)
  code_assets 1.2.1 (2.0.0 available)
  hooks 2.1.0 (2.2.0 available)
  lucide_icons_flutter 3.1.15 (3.1.17 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  objective_c 9.5.0 (9.6.0 available)
  package_config 2.2.0 (3.0.0 available)
  record_use 1.1.0 (1.1.1 available)
  shadcn_ui 0.55.1 (0.56.1 available)
  source_maps 0.10.13 (0.10.14 available)
  test 1.31.1 (1.31.2 available)
  test_api 0.7.12 (0.7.13 available)
  test_core 0.6.18 (0.6.19 available)
  vm_service 15.2.0 (15.3.0 available)
Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`!
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Analyzing jet_cad_2d_flutter...                                 
No issues found! (ran in 0.8s)
```

### `flutter analyze` — apps/dev_harness_2d

```
$ cd apps/dev_harness_2d && flutter analyze
Resolving dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (105.0.0 available)
  analyzer 13.3.0 (14.1.0 available)
  code_assets 1.2.1 (2.0.0 available)
  hooks 2.1.0 (2.2.0 available)
  lucide_icons_flutter 3.1.15 (3.1.17 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  objective_c 9.5.0 (9.6.0 available)
  package_config 2.2.0 (3.0.0 available)
  record_use 1.1.0 (1.1.1 available)
  shadcn_ui 0.55.1 (0.56.1 available)
  source_maps 0.10.13 (0.10.14 available)
  test 1.31.1 (1.31.2 available)
  test_api 0.7.12 (0.7.13 available)
  test_core 0.6.18 (0.6.19 available)
  vm_service 15.2.0 (15.3.0 available)
Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`!
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Analyzing dev_harness_2d...                                     
No issues found! (ran in 1.4s)
```

Both analyze clean, as expected — this covers all nine originally-red call
sites (the human's note that `apps/dev_harness_2d` was red too, beyond the
four in `jet_cad_2d_flutter`, is confirmed fixed here).

### Rig run — `text paint at 50000`

```
$ CI=true flutter test --tags rig --run-skipped test/rig/paint_microbench_test.dart --plain-name "text paint at 50000"
Resolving dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (105.0.0 available)
  analyzer 13.3.0 (14.1.0 available)
  code_assets 1.2.1 (2.0.0 available)
  hooks 2.1.0 (2.2.0 available)
  lucide_icons_flutter 3.1.15 (3.1.17 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  objective_c 9.5.0 (9.6.0 available)
  package_config 2.2.0 (3.0.0 available)
  record_use 1.1.0 (1.1.1 available)
  shadcn_ui 0.55.1 (0.56.1 available)
  source_maps 0.10.13 (0.10.14 available)
  test 1.31.1 (1.31.2 available)
  test_api 0.7.12 (0.7.13 available)
  test_core 0.6.18 (0.6.19 available)
  vm_service 15.2.0 (15.3.0 available)
Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`!
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/rig/paint_microbench_test.dart
00:00 +0: text paint at 50000
=== 50000 entities, with text ===
  corpus: doc=1589ms index=338ms entities=54000 nodes=20184 definitions=200
  text in corpus: attribs=4000 labels=928
  -- whole drawing --
    DISTINCT CACHE KEYS: 4140   (limit 512) OVER
      text ops: 4928  distinct (string, style): 4020  distinct argb: 7
      hit rate  labels: 84.9% (928 ops / 140 keys)   attributes: 0.0% (4000 ops / 4000 keys)
    [text on]
      R1 paint          p50=783.377ms p95=806.372ms min=765.792ms (n=26)
      R3 query-only     p50=194.826ms p95=206.338ms min=187.191ms (n=102)
      ops/frame: 2067600  canvasCalls: 689200
      textOps: 4928  skippedText: 0
      newLayouts=4140 newParagraphEvictions=4140
      cache: layouts=194580 paragraphEvictions=194068 metricsEvictions=0 liveParagraphs=512 liveMetrics=4020
      screen-space leaves: 358415  dashSpans: 0  collapsed: 239256
    [text off]
      R1 paint          p50=679.237ms p95=744.560ms min=661.936ms (n=30)
      R3 query-only     p50=191.920ms p95=200.472ms min=186.269ms (n=104)
      ops/frame: 2052816  canvasCalls: 684272
      textOps: 0  skippedText: 0
      newLayouts=0 newParagraphEvictions=0
      cache: layouts=0 paragraphEvictions=0 metricsEvictions=0 liveParagraphs=512 liveMetrics=4020
      screen-space leaves: 358415  dashSpans: 0  collapsed: 239256
  -- working set --
    DISTINCT CACHE KEYS: 18   (limit 512) under
      text ops: 19  distinct (string, style): 18  distinct argb: 7
      hit rate  labels: 11.1% (9 ops / 8 keys)   attributes: 0.0% (10 ops / 10 keys)
    [text on]
      R1 paint          p50=25.469ms p95=26.991ms min=25.168ms (n=120)
      R3 query-only     p50=1.948ms p95=2.850ms min=1.916ms (n=120)
      ops/frame: 66904  canvasCalls: 59212
      textOps: 19  skippedText: 0
      newLayouts=0 newParagraphEvictions=0
      cache: layouts=17 paragraphEvictions=17 metricsEvictions=0 liveParagraphs=512 liveMetrics=4020
      screen-space leaves: 2079  dashSpans: 56706  collapsed: 0
    [text off]
      R1 paint          p50=25.220ms p95=26.339ms min=25.052ms (n=120)
      R3 query-only     p50=1.939ms p95=2.731ms min=1.915ms (n=120)
      ops/frame: 66847  canvasCalls: 59193
      textOps: 0  skippedText: 0
      newLayouts=0 newParagraphEvictions=0
      cache: layouts=0 paragraphEvictions=0 metricsEvictions=0 liveParagraphs=512 liveMetrics=4020
      screen-space leaves: 2079  dashSpans: 56706  collapsed: 0
  -- key pressure, zooming out about the working-set centre --
      3000 world units wide:    18 keys,    19 text ops  under
      6000 world units wide:    72 keys,    73 text ops  under
     12000 world units wide:   273 keys,   287 text ops  under
     24000 world units wide:   976 keys,  1075 text ops  OVER
     48000 world units wide:  3469 keys,  4107 text ops  OVER
     96000 world units wide:  4140 keys,  4928 text ops  OVER
02:09 +1: text paint at 500000
=== 500000 entities, with text ===
  corpus: doc=2200ms index=1058ms entities=504000 nodes=20184 definitions=200
  text in corpus: attribs=4000 labels=9928
  -- whole drawing --
    DISTINCT CACHE KEYS: 4140   (limit 512) OVER
      text ops: 13928  distinct (string, style): 4020  distinct argb: 7
      hit rate  labels: 98.6% (9928 ops / 140 keys)   attributes: 0.0% (4000 ops / 4000 keys)
    [text on]
      R1 paint          p50=1252.486ms p95=1300.443ms min=1228.655ms (n=16)
      R3 query-only     p50=389.578ms p95=397.205ms min=386.105ms (n=52)
      ops/frame: 3417600  canvasCalls: 1139200
      textOps: 13928  skippedText: 0
      newLayouts=4140 newParagraphEvictions=4140
      cache: layouts=153180 paragraphEvictions=152668 metricsEvictions=0 liveParagraphs=512 liveMetrics=4020
      screen-space leaves: 689165  dashSpans: 0  collapsed: 393606
    [text off]
      R1 paint          p50=1140.156ms p95=1162.259ms min=1121.622ms (n=18)
      R3 query-only     p50=385.021ms p95=398.701ms min=381.443ms (n=52)
      ops/frame: 3375816  canvasCalls: 1125272
      textOps: 0  skippedText: 0
      newLayouts=0 newParagraphEvictions=0
      cache: layouts=0 paragraphEvictions=0 metricsEvictions=0 liveParagraphs=512 liveMetrics=4020
      screen-space leaves: 689165  dashSpans: 0  collapsed: 393606
  -- working set --
    DISTINCT CACHE KEYS: 72   (limit 512) under
      text ops: 96  distinct (string, style): 37  distinct argb: 7
      hit rate  labels: 30.4% (79 ops / 55 keys)   attributes: 0.0% (17 ops / 17 keys)
    [text on]
      R1 paint          p50=58.988ms p95=61.218ms min=57.947ms (n=120)
      R3 query-only     p50=4.730ms p95=5.244ms min=4.060ms (n=120)
      ops/frame: 149604  canvasCalls: 136114
      textOps: 96  skippedText: 0
      newLayouts=0 newParagraphEvictions=0
      cache: layouts=72 paragraphEvictions=72 metricsEvictions=0 liveParagraphs=512 liveMetrics=4020
      screen-space leaves: 4134  dashSpans: 131668  collapsed: 21
    [text off]
      R1 paint          p50=58.869ms p95=60.185ms min=57.848ms (n=120)
      R3 query-only     p50=4.714ms p95=5.429ms min=4.029ms (n=120)
      ops/frame: 149316  canvasCalls: 136018
      textOps: 0  skippedText: 0
      newLayouts=0 newParagraphEvictions=0
      cache: layouts=0 paragraphEvictions=0 metricsEvictions=0 liveParagraphs=512 liveMetrics=4020
      screen-space leaves: 4134  dashSpans: 131668  collapsed: 21
  -- key pressure, zooming out about the working-set centre --
      3000 world units wide:    72 keys,    96 text ops  under
      6000 world units wide:   166 keys,   262 text ops  under
     12000 world units wide:   354 keys,   829 text ops  under
     24000 world units wide:   953 keys,  2946 text ops  OVER
     48000 world units wide:  3442 keys, 11534 text ops  OVER
     96000 world units wide:  4140 keys, 13928 text ops  OVER
04:58 +2: All tests passed!

[exited with code 0]
```

Note: `--plain-name "text paint at 50000"` substring-matches both
"text paint at 50000" and "text paint at 500000", so both ran; both passed,
and both print the single-measurer counters (`newLayouts`,
`newParagraphEvictions`, `cache: ... metricsEvictions=... liveMetrics=...`)
exactly as specified in the brief.

### Widget suite — packages/jet_cad_2d_flutter (default tags, rig excluded)

```
$ CI=true flutter test
...
00:03 +277 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink the canvas sink leaves its paint on stroke afterwards
00:03 +278 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink fillPolygon closes the path
00:03 +279 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink fillPolygon with fewer than 3 points draws nothing
00:03 +280 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink fillCircle draws a filled circle
00:03 +281 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink fillCircle leaves the paint on stroke afterwards
00:03 +281 ~1: All tests passed!
```

281 passed, 1 skipped (`~1`, pre-existing, unrelated to this task), exit
code 0. Full log saved during the run at
`/tmp/widget_suite_output.txt` (not part of the repo).

### Format

```
$ cd packages/jet_cad_2d_flutter && dart format --output=none --set-exit-if-changed .
Formatted 49 files (0 changed) in 0.09 seconds.

$ cd apps/dev_harness_2d && dart format --output=none --set-exit-if-changed .
Formatted 4 files (0 changed) in 0.04 seconds.
```

Both clean, exit code 0.

## `git status` checked before committing

Before staging:

```
$ git status
On branch main
Your branch is ahead of 'origin/main' by 9 commits.
  (use "git push" to publish your local commits)

Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
	modified:   apps/dev_harness/analysis_options.yaml
	modified:   apps/dev_harness/macos/Podfile
	modified:   apps/dev_harness/macos/Runner.xcodeproj/project.pbxproj
	modified:   apps/dev_harness_2d/integration_test/frame_timing_test.dart
	modified:   apps/dev_harness_2d/lib/measurement_rig.dart
	modified:   packages/jet_cad_2d_flutter/test/rig/paint_microbench_test.dart

no changes added to commit (use "git add" and/or "git commit -a")
```

The three files listed in the global constraint
(`apps/dev_harness/analysis_options.yaml`, `apps/dev_harness/macos/Podfile`,
`apps/dev_harness/macos/Runner.xcodeproj/project.pbxproj`) were present as
pre-existing modifications (from `flutter pub get`/tooling, not from this
task) and were **not** staged or committed. Only the three files named in
the brief were added:

```
$ git add apps/dev_harness_2d/lib/measurement_rig.dart \
          apps/dev_harness_2d/integration_test/frame_timing_test.dart \
          packages/jet_cad_2d_flutter/test/rig/paint_microbench_test.dart
$ git status
On branch main
Changes to be committed:
	modified:   apps/dev_harness_2d/integration_test/frame_timing_test.dart
	modified:   apps/dev_harness_2d/lib/measurement_rig.dart
	modified:   packages/jet_cad_2d_flutter/test/rig/paint_microbench_test.dart

Changes not staged for commit:
	modified:   apps/dev_harness/analysis_options.yaml
	modified:   apps/dev_harness/macos/Podfile
	modified:   apps/dev_harness/macos/Runner.xcodeproj/project.pbxproj
```

## Commit

```
$ git commit -m "refactor: report paragraph and metrics evictions apart

Move every reader of FlutterTextMeasurer's now-split eviction counters
onto paragraphEvictionCount/metricsEvictionCount and liveMetricsCount.
Collapse paint_microbench_test's two measurers into the single one
production now uses, and rewrite the comment explaining why: the
document owns one FlutterTextMeasurer, DraftCanvas borrows it for the
sink, and metrics/paragraph requests land in that object's two maps
instead of two separate caches."
[main 08b7785] refactor: report paragraph and metrics evictions apart
 3 files changed, 42 insertions(+), 35 deletions(-)
```

After commit, `git status` shows only the three pre-existing modified
files (`analysis_options.yaml`, `Podfile`, `Runner.xcodeproj/project.pbxproj`),
untouched — confirmed with `git log -1 --stat`.

## What the rewritten comment now says, and why

Old (falsified) comment, in `paint_microbench_test.dart`:

> Two measurers, because production has two. `DraftCanvas` builds its own
> `FlutterTextMeasurer` for the sink and never touches
> `document.textMeasurer`, which is what the painter reads metrics from —
> so draw-colour paragraphs and metrics probes land in *different* caches,
> and only the sink's is the one `kParagraphCacheLimit` is about. Sharing
> one here would inflate the count with probe entries the real wiring
> keeps somewhere else.

New comment:

> One measurer, because production has one. The document owns it and
> `DraftCanvas` borrows it for the sink, so the painter's metrics
> requests and the sink's drawn paragraphs land in the same object —
> metrics in its colour-free map, paragraphs in its coloured one. Before
> Plan 3f these were two `FlutterTextMeasurer`s with two caches, and this
> rig built two to match; that wiring is gone.

The new comment states the *current* wiring (one measurer, owned by the
document, borrowed by `DraftCanvas` for the sink), names which cache each
kind of text request lands in (metrics vs. paragraphs, matching Task 2's
split), and explicitly flags that this is a design change from Plan 3f, not
incidental tidying — so a later editor of this same file (Task 8 adding a
threshold loop, Task 14 recording a measurement margin) sees the ruling and
does not reintroduce a second measurer.

## Concerns

None. All nine call sites are fixed, both `flutter analyze` runs are clean,
the tagged rig test passes and prints the split counters correctly, the
full widget suite passes (281 passed, 1 pre-existing skip), format is
clean in both packages, and only the intended three files were committed.
