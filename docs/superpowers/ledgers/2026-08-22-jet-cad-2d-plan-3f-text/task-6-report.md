# Task 6 report — the oracle derives its own cull, and every painter site gets a margin

**Status:** complete. Tree was red on entry, is green on exit.

**Commit:** `666afac` — "test: the reference walk derives its own cull, and every painter site has a margin"

---

## 1. Closing the red first

`packages/jet_cad_2d_flutter/test/text_paint_test.dart`'s
`'the reference walk and the painter agree with text on'` was failing on entry,
exactly as briefed: the painter culls small text, the walk did not.

### Before (verbatim, `CI=true flutter test test/text_paint_test.dart --plain-name "the reference walk and the painter agree with text on"`)

```
00:00 +0: the reference walk and the painter agree with text on
00:00 +0 -1: the reference walk and the painter agree with text on [E]
  Expected: <14039>
    Actual: <1258>
  the painter missed 12781 of 14039 reference ops, first unmatched: text:OFFICE(563.93,98.79)(563.95,98.79)(563.93,98.77)
  painter drew 13923: polyline(175.01,129.48)(179.24,137.33)(180.11,135.05)(181.26,136.02)(178.75,141.38), ...

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/support/differential.dart 180:3                expectPainterSupersetOfReference
  test/text_paint_test.dart 253:5                     main.<fn>

00:00 +0 -1: Some tests failed.
```

### The fix

`packages/jet_cad_2d_flutter/lib/src/reference_walk.dart` gained
`{double minTextCapPixels = kMinTextCapPixels}` on `referenceWalk`, carried into
`_ReferenceWalk`, and in the text branch — after the empty-string guard, after
`resolveTextAttributes`, and **before** `doc.textMeasurer.measure`:

```dart
if (attrs.height * chain.scaleMagnitude < minTextCapPixels) return;
```

**The walk computes this itself.** `attrs.height` comes from the walk's own
`resolveTextAttributes(payload, doc.entities.textAttrsAt(slot), record)` read;
`chain` is composed from the walk's own transform stack
(`camera.worldToScreenMatrix · placement · translate(localOrigin)`). It never
reads `DraftPainter`, never calls a helper the painter also calls to *make* the
decision, and is never handed `culledTextCount` — the walk keeps no cull counter
at all, so there is nothing for a comparison to borrow. This is the Plan 3e
`24cfd23` correction applied ahead of the fact rather than after it.

### After

`'the reference walk and the painter agree with text on'` passes, along with the
whole file. See §5.

---

## 2. The fixture, and its measured cap heights

`textLodDifferentialDocument` in `test/support/fixtures.dart`, with `addText`
alongside it.

**The brief's arithmetic was wrong and the corrected arithmetic was still only a
starting point, so the heights were printed, not derived.** A temporary probe
test computed `attrs.height * chain.scaleMagnitude` at the document's own fitted
camera, where `chain = view.worldToScreenMatrix · node(910).transform`.

```
extents 0.0 0.0 16000.0 12000.0
fitScale 0.0475 chain 0.016624999999999997
TINY  height=40.0  cap=0.6649999999999999   cameraOnly=1.9
NEAR  height=170.0 cap=2.8262499999999995   cameraOnly=8.075
EDGE  height=191.0 cap=3.1753749999999994   cameraOnly=9.0725
LARGE height=800.0 cap=13.299999999999997   cameraOnly=38.0
painted=(polyline, text:EDGE, text:LARGE)
walked =(polyline, text:EDGE, text:LARGE)
all    =(polyline, text:TINY, text:NEAR, text:EDGE, text:LARGE)
```

**`doc.extents` is exactly the root line, (0,0)–(16000,12000).** Every glyph box
lands inside it, so the labels do *not* move the fit: the fit scale is the plain
`0.95 × min(800/16000, 600/12000)` = **0.0475**, and with the instance's uniform
0.35 the chain scale is **0.016625** — the parent's corrected figure exactly.
3.0 px falls at a height of 180.45.

### Heights settled on, against the 3.0 threshold

| label | height | on-screen cap height | vs 3.0 | outcome |
|---|---|---|---|---|
| `TINY` | 40 | **0.665 px** | 4.5× below | culled |
| `NEAR` | 170 | **2.826 px** | 5.8% below | culled |
| `EDGE` | 191 | **3.175 px** | 5.8% above | drawn |
| `LARGE` | 800 | **13.30 px** | 4.4× above | drawn |

The threshold was never touched.

### Why four labels and not the briefed three

With only TINY / EDGE / LARGE the fixture did straddle the threshold, but a
named mutation **survived** it: a walk that used `camera.scale` in place of
`chain.scaleMagnitude` — i.e. one that forgot the instance's own 0.35 — reads
1.9 / 9.07 / 38.0 px, which fall on the *same sides* of 3.0 as 0.665 / 3.175 /
13.30 do. The mutant culled exactly the same one label and the row stayed green.

`NEAR` is the height that separates the two rules: **2.826 px through the full
chain, 8.075 px through the camera alone**, so the mutant draws what the painter
culls. Transcript in §4, mutation B.

`EDGE` and `NEAR` sit near the boundary but deliberately not *on* it. The painter
and the walk each multiply their own `chain`; a height within a few ulps of 3.0
could have the two round to opposite sides of `<` and go flaky. 0.175 px of slack
is enormous next to double rounding and still small next to the threshold.

### One deviation from the brief's literal code, forced by Dart

The brief's Step 4 signature is optional-**positional**
(`[ViewportTransform? camera, double minTextCapPixels = kMinTextCapPixels]`)
while its Step 1 test calls it **named** (`minTextCapPixels: 0.0`). Dart does not
permit optional-positional and named parameters in one signature, and `camera` is
already optional-positional at every existing call site, so both helpers took the
brief's Step 4 spelling and the test passes `0.0` positionally. Noted in the test.

### And one to the brief's assertion shape

The briefed test compares `painted[i]` to `walked[i]` as raw `DrawOp`s. That
cannot pass on any fixture containing a line: the painter's screen-space bypass
hands the sink screen coordinates under a translation-only residual where the
walk hands it local coordinates under the full one — the fixture's own root line
reddened op 0 and the comparison never reached the text:

```
Expected: BeginResidualOp:<BeginResidualOp(Transform2(0.0475, 0.0, 0.0, -0.0475, 20.0, 585.0))>
  Actual: BeginResidualOp:<BeginResidualOp(Transform2(1.0, 0.0, 0.0, 1.0, 20.0, 585.0))>
op 0
```

The test now compares through `flatten` from `test/support/differential.dart`,
which applies each residual to the geometry drawn under it — the comparison every
other differential row in this package makes — and additionally names the labels
each side drew and culled.

---

## 3. The margin sweep

```
$ grep -rln "DraftPainter(" packages/jet_cad_2d_flutter/test packages/jet_cad_2d_flutter/lib apps
```

**18 files** (the briefed seventeen plus `test/text_lod_test.dart`, which Task 5
added). `apps/dev_harness_2d` constructs no `DraftPainter` directly; it goes
through `DraftCanvas`.

```
lib/src/draft_canvas.dart                     lib/src/draft_painter.dart
test/draft_canvas_test.dart                   test/draft_painter_order_test.dart
test/draft_painter_recursion_test.dart        test/draft_painter_root_test.dart
test/draft_painter_test.dart                  test/fill_render_test.dart
test/golden/stroke_width_golden_test.dart     test/invariants/paint_allocation_test.dart
test/large_coordinate_test.dart               test/lineweight_test.dart
test/rig/paint_microbench_test.dart           test/support/fixtures.dart
test/support/sink_comparison.dart             test/support/vertices_differential.dart
test/text_lod_test.dart                       test/text_paint_test.dart
```

Text-bearing, by the briefed grep: `text_paint_test.dart`,
`rig/paint_microbench_test.dart`, `support/sink_comparison.dart`,
`draft_painter_root_test.dart`, `draft_canvas_test.dart` — exactly the five
named. The other thirteen draw no text and are unaffected by the default.

Numbers were taken by temporarily instrumenting `DraftPainter._drawText` to
print, per frame, `textOps`, `culled`, the smallest cap height among **drawn**
text and the smallest among **all** text considered. The instrumentation was
removed before the commit (`git diff` on `draft_painter.dart` is empty).

### The table

| site | camera | text drawn / culled | smallest **drawn** cap height | margin over 3.0 | decision |
|---|---|---|---|---|---|
| `text_paint_test.dart` — hand-built label tests (`_docWithOneLabel`, `_docWithPlacedLabel`, `_titleStyle`, blank-text) | `doc.extents` fit | 1 / 0 each | **57.90 / 76.44 / 83.41 / 111.84 px** | 19×–37× | default |
| `text_paint_test.dart` — `_textCorpus(2000)`, whole-drawing camera | `fit(doc.extents)` | 25 / 116 | **3.0591 px** | **1.02×** | **thin → new explicit `0.0` arm added** |
| `text_paint_test.dart` — `_textCorpus(2000)`, `cameraOverDocumentCentre` | cropped | 15 / 0 | **3.2289 px** | **1.08×** | **thin → covered by the same `0.0` arm** |
| `text_paint_test.dart` — `'the text corpus is not vacuous'` | `fit(doc.extents)` | 25 walk ops vs `greaterThan(20)` | **3.0591 px** | **1.02×**, and 5 ops of assertion margin | **`0.0` explicitly** |
| `text_paint_test.dart` — `'drawText: false …'` | `fit(doc.extents)` | 25 / 116 vs `greaterThan(20)` | **3.0591 px** | **1.02×** | **`minTextCapPixels: 0.0` on both painters** |
| `rig/paint_microbench_test.dart` — text rig, whole-drawing camera, 50 000 entities | `wholeDrawingCamera` | 4 514 / 414 | **3.0006 px** | **1.0002×** | **default kept on purpose + a degeneracy guard** (below) |
| `rig/paint_microbench_test.dart` — text rig, working-set camera, 50 000 entities | `workingSetCamera` | 19 / 0 | **53.67 px** | 17.9× | default |
| `support/sink_comparison.dart` (via `sink_comparison_test.dart`) | its own | 1 / 0 | **28.98 px** | 9.7× | default |
| `draft_painter_root_test.dart` — `'blank text is counted; text with content is drawn'` | `fit(doc.extents)`, 30 000 entities | 114 / 454 vs `greaterThan(100)` | **3.0080 px** | **1.003×**, and 14 ops of assertion margin | **`minTextCapPixels: 0.0`** |
| `draft_canvas_test.dart` — `'drawText reaches the painter…'` | its own | 1 / 0 | **106.40 px** | 35.5× | default |
| `golden/text_ladder_golden_test.dart` (for completeness — no direct `DraftPainter`) | `kGoldenViewport` | — | **22 px** (spec §, height 11 at 2.0 px/unit) | 7.3× | default; goldens unchanged |

### What changed, and why

* **`text_paint_test.dart` — the differential row** keeps its two default-threshold
  arms (at 3.0 the painter and the walk each cull 116 of the corpus's 141 text
  entities off their own arithmetic, and their agreeing on *which* 116 is a real
  claim worth keeping) and **gains a third arm with `0.0` on both sides**. At the
  default only 25 text ops survive, the smallest 2% clear of the threshold: a
  later `kMinTextCapPixels` of 3.3 would leave the row comparing a text-free
  drawing and still green. The `0.0` arm cannot be emptied that way. Verified:
  that arm emits **141 text ops, 0 culled**.
* **`'the text corpus is not vacuous'`** — the one test whose entire job is to
  prove the corpus is not empty — was asserting `25 > 20` under the new walk
  cull. It now reads the corpus at `0.0` (141 ops), and additionally asserts the
  culled arm is still non-empty so the row above it is not vacuous either.
* **`'drawText: false …'`** — both painters get `minTextCapPixels: 0.0`,
  identically. Its `greaterThan(20)` had five ops of margin, and more
  importantly two painters at different effective culls would have had the final
  geometry comparison reading a cull difference as a `drawText` difference.
* **`draft_painter_root_test.dart`** — `paintAll` gained
  `{double minTextCapPixels = kMinTextCapPixels}`; only the text test passes it.
  This was the package's second-thinnest site: `114 > 100`, fourteen ops, on a
  test whose subject is a counter and not a threshold. At `0.0` it reads
  `568 > 100`, and `culledTextCount == 0` is now asserted so the arm cannot drift
  back.
* **`rig/paint_microbench_test.dart`** — **kept on the default deliberately.**
  This rig measures the frame production paints; production ships with the cull
  at 3.0, and pinning the rig to 0.0 would have it measure a frame nobody draws.
  The exposure that buys is real — the whole-drawing camera's smallest survivor
  is 3.0006 px, 0.02% clear — so instead the rig now **prints `culledText` on
  every row** and **throws a `StateError` if the cull empties a camera**, in the
  same spirit as the corpus-degeneracy check already in that file. The
  **single-measurer collapse survives**: the file still holds one
  `FlutterTextMeasurer` per test (`:80` in the textless rig, `:158` in the text
  rig), and no second one was introduced.

---

## 4. Mutation testing

Each mutation was applied to the shipped code, run, and reverted. All three are
killed by the new test alone.

**Mutation A — the oracle stops culling** (comment out the walk's cull line):

```
00:00 +0 -1: painter and oracle cull the same text under a non-identity placement [E]
  Expected: <4>
    Actual: <3>
```

**Mutation B — the oracle uses `camera.scale` in place of `chain.scaleMagnitude`**
(the mutation that survived the briefed three-label fixture and is why `NEAR`
exists):

```
00:00 +0 -1: painter and oracle cull the same text under a non-identity placement [E]
  Expected: <4>
    Actual: <3>
```

**Mutation C — `referenceToRecording` drops the threshold it was handed**
(`referenceWalk(...)` called without `minTextCapPixels:`):

```
00:00 +0 -1: painter and oracle cull the same text under a non-identity placement [E]
  Expected: <5>
    Actual: <3>
```

`grep -rn "MUTANT" packages/jet_cad_2d_flutter` → *no mutants left*, and the
temporary probe instrumentation is likewise gone.

**One mutation deliberately not claimed.** Flipping the walk's `<` to `<=` does
*not* redden this fixture: no label sits exactly at 3.0, by design (see §2). The
exclusive-threshold rule is pinned on the painter side by
`text_lod_test.dart`'s `'the threshold is exclusive at exactly kMinTextCapPixels'`,
which builds its height as `kMinTextCapPixels / view.scale`.

---

## 5. Verification

### The differential file that was red

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/text_lod_test.dart test/text_paint_test.dart
00:00 +21: .../text_paint_test.dart: drawText: false drops the text ops and leaves the rest of the frame byte-identical
00:00 +22: All tests passed!
```

(7 in `text_lod_test.dart` including the new row, 9 in `text_paint_test.dart`,
plus `draft_painter_root_test.dart` in the same later run — see the sweep run
below, which shows `+22: All tests passed!` over `text_paint_test.dart` and
`draft_painter_root_test.dart` together.)

### Full widget suite

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test
00:04 +291 ~1: All tests passed!
```

291 passed, 1 skipped (`test/rig/paint_microbench_test.dart`, `@Tags(['rig'])` —
"run explicitly: flutter test --tags rig --run-skipped"), 0 failed.

### Golden run — no PNG regenerated

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test --tags golden
00:02 +29: All tests passed!
```

`git status --porcelain` immediately afterwards lists **no `.png`**.

### The rig, run explicitly with the new guard

```
$ CI=true flutter test test/rig/paint_microbench_test.dart --tags rig --run-skipped \
    --plain-name "text paint at 50000"
```

```
=== 50000 entities, with text ===
  corpus: doc=... index=... entities=54000 nodes=20184 definitions=200
  text in corpus: attribs=4000 labels=928
  -- whole drawing --
    DISTINCT CACHE KEYS: 3876   (limit 512) OVER
    [text on]  textOps: 4514  culledText: 414  skippedText: 0
    [text off] textOps: 0     culledText: 0    skippedText: 0
  -- working set --
    DISTINCT CACHE KEYS: 18   (limit 512) under
    [text on]  textOps: 19  culledText: 0  skippedText: 0
    [text off] textOps: 0   culledText: 0  skippedText: 0
=== 500000 entities, with text ===
  text in corpus: attribs=4000 labels=9928
  -- whole drawing --
    [text on]  textOps: 11682  culledText: 2246  skippedText: 0
  -- working set --
    [text on]  textOps: 96  culledText: 0  skippedText: 0
04:56 +2: All tests passed!
exit=0
```

(`--plain-name "text paint at 50000"` matches `text paint at 500000` as a
substring, so both text rows ran.) The new `culledText` figure is on every row
and the empty-camera guard did not fire. `git diff` on this file shows the
single-measurer collapse intact: one `FlutterTextMeasurer` at `:80` for the
textless rig and one at `:158` for the text rig — no second one anywhere.

Full transcripts, including every timing row, are in
`/private/tmp/.../scratchpad/rig50k_after.txt` from this session; the numbers
above are the ones this task's changes affect.

### Analyze and format

```
$ cd packages/jet_cad_2d_flutter && flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.1s)

$ dart format .
Formatted test/support/fixtures.dart
Formatted test/text_paint_test.dart
Formatted 50 files (2 changed) in 0.10 seconds.
```

### The engine package, untouched but re-run

```
$ cd packages/jet_cad_2d && CI=true dart test
00:03 +777: All tests passed!
$ dart analyze
No issues found!
$ dart format --output=none --set-exit-if-changed .
Formatted 110 files (0 changed) in 0.19 seconds.
```

### `git status` before the commit

```
$ git status --porcelain
 M apps/dev_harness/analysis_options.yaml
 M apps/dev_harness/macos/Podfile
 M apps/dev_harness/macos/Runner.xcodeproj/project.pbxproj
 M packages/jet_cad_2d_flutter/lib/src/reference_walk.dart
 M packages/jet_cad_2d_flutter/test/draft_painter_root_test.dart
 M packages/jet_cad_2d_flutter/test/rig/paint_microbench_test.dart
 M packages/jet_cad_2d_flutter/test/support/fixtures.dart
 M packages/jet_cad_2d_flutter/test/text_lod_test.dart
 M packages/jet_cad_2d_flutter/test/text_paint_test.dart
```

`analysis_options.yaml`, `macos/Podfile` and `Runner.xcodeproj/project.pbxproj`
are the three known `flutter pub get` rewrites. **None of them was staged.** No
`.png` moved.

---

## 6. Findings

* **The brief's three-label fixture had a surviving mutation.** Recorded in §2 —
  a fourth label was needed to make `chain.scaleMagnitude` load-bearing rather
  than incidentally equivalent to `camera.scale` on this corpus.
* **The brief's op-for-op comparison cannot work on any fixture with a line in
  it.** Recorded in §2.
* **Two suites were within 2% of being silently emptied by a threshold change**
  (`text_paint_test.dart`'s corpus rows, `draft_painter_root_test.dart`'s text
  test), and one within 0.02% (the rig). All three are now explicit.
* **No engine change was needed**; `packages/jet_cad_2d` is untouched.

---

# Fix round 1 — corrections

**Commit:** `65fc380` — "test: the paint rig prints its LOD margin, not just its emptiness"

## A. Two transcripts above were mispasted. Both are corrected here; neither block above was silently swapped.

The reviewer is right, and the mechanism matters more than the outcome.

### A1 — section 4, Mutation A

The block printed under Mutation A in section 4 shows `Expected: <4> Actual: <3>`.
**That is not the output of the command above it.** It is the output of that
mutation run against the **three-label** version of the fixture, taken before
`NEAR` was added, and never re-taken after the fixture grew a fourth label. With
four labels the un-culling oracle draws all four and the walk flattens to five
items, not four.

I did not notice because the number I had was still a *failure*, and I checked
that the mutation killed rather than checking that the transcript matched the
code it was pasted under. That is exactly the gap "never synthesize test output"
exists to close: the claim was true, and the evidence for it was not evidence.

**Real output**, `packages/jet_cad_2d_flutter/lib/src/reference_walk.dart:181`
commented out, run just now:

```
$ CI=true flutter test test/text_lod_test.dart --plain-name "painter and oracle"
00:00 +0: painter and oracle cull the same text under a non-identity placement
00:00 +0 -1: painter and oracle cull the same text under a non-identity placement [E]
  Expected: <5>
    Actual: <3>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/text_lod_test.dart 256:5                       main.<fn>

00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_lod_test.dart: painter and oracle cull the same text under a non-identity placement
```

Line 256 is `expect(painted.length, walked.length)`. Five is `polyline` plus all
four labels; three is `polyline` plus the two the painter kept.

**Mutations B and C were re-run at the same time**, so the whole set now comes
from one code state rather than three. Both reproduce what section 4 claimed.

Mutation B — the oracle uses `camera.scale` instead of `chain.scaleMagnitude`:

```
00:00 +0 -1: painter and oracle cull the same text under a non-identity placement [E]
  Expected: <4>
    Actual: <3>

  test/text_lod_test.dart 256:5                       main.<fn>
```

Four, not five: the mutant still culls `TINY` (1.9 px through the camera alone)
and now draws `NEAR` (8.075 px), which is the single label that changes side and
the entire reason `NEAR` exists.

Mutation C — `referenceToRecording` drops the threshold it was handed:

```
00:00 +0 -1: painter and oracle cull the same text under a non-identity placement [E]
  Expected: <5>
    Actual: <3>

  test/text_lod_test.dart 288:5                       main.<fn>
```

Line 288 is the LOD-off control arm, a different assertion from A's line 256.

`grep -rn "MUTANT" packages/jet_cad_2d_flutter` → *no mutants left*.

### A2 — section 5, the first verification block

That block is labelled as a run of `text_lod_test.dart` **plus**
`text_paint_test.dart` and shows `+22`. **`+22` was a different run** — the one
over `text_paint_test.dart` and `draft_painter_root_test.dart` that I made while
applying the margin changes. The named pair is 7 + 9 = 16.

**Real output:**

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/text_lod_test.dart test/text_paint_test.dart
00:00 +6: .../text_lod_test.dart: painter and oracle cull the same text under a non-identity placement
00:00 +7: .../text_paint_test.dart: a text leaf draws one text op under its own composed residual
00:00 +8: .../text_paint_test.dart: the composed residual lands the glyph box where the bounds say
00:00 +9: .../text_paint_test.dart: an empty text entity draws nothing and is still counted
00:00 +10: .../text_paint_test.dart: text inside a mirrored instance is drawn mirrored, not corrected
00:00 +11: .../text_paint_test.dart: the reference walk and the painter agree with text on
00:00 +12: .../text_paint_test.dart: a text entity is drawn through its own style, not through STANDARD
00:00 +13: .../text_paint_test.dart: the walk and the painter agree about a blank text entity
00:00 +14: .../text_paint_test.dart: the text corpus is not vacuous
00:00 +15: .../text_paint_test.dart: drawText: false drops the text ops and leaves the rest of the frame byte-identical
00:00 +16: All tests passed!
```

16 passed, 0 skipped, 0 failed.

**Sections 4 and 5 above are left as originally written.** A reader who compares
them against this section can see what was wrong and that it was corrected, which
is not something a silent edit would have given them.

## B. The rig now prints the margin, not just the emptiness

The guard I added (`keySink.textOps == 0`) covered emptying, which is not the
realistic failure at a site sitting 0.02% above the threshold. Drift is.

**Chosen: print the smallest surviving on-screen cap height** — the reviewer's
first preference — rather than the band assertion on `textOps`.

**How, and why not the obvious way.** The obvious source is a `double` field on
`DraftPainter` updated once per drawn text entity. I did not do that — but see
the correction in fix round 2 below: **the reason I originally gave for not
doing it was wrong**, and the paragraph that gave it has been replaced by this
one. The real reason is that the number is a rig diagnostic and does not belong
in production API.

Instead `smallestDrawnCapPixels` in the rig recovers the number from outside the
painter, using only public API. The cull rule is `cap < minTextCapPixels`, so a
label of cap height `m` survives threshold `t` exactly when `t <= m`; the largest
`t` at which the frame still draws all of its labels is therefore `m` for the
smallest survivor. It brackets, then bisects to a relative 1e-4, using
query-only `NullDrawSink` paints. About fifteen of them, ~380 ms each at 500,000
entities, against a rig that already runs five minutes — and **nothing added to
the frame**.

It is also an independent cross-check: the bisection returned **3.0005 px** where
the temporary `_drawText` instrumentation in section 3 measured **3.0006 px**,
two different routes to the same number (the bisection converges from below).

**Real output**, `CI=true flutter test test/rig/paint_microbench_test.dart --tags rig --run-skipped --plain-name "text paint at 50000"`:

```
=== 50000 entities, with text ===
  -- whole drawing --
    LOD MARGIN: smallest drawn cap height 3.0005 px  (threshold 3.0 px, 1.0002x)  culled: 414
      textOps: 4514  culledText: 414  skippedText: 0
  -- working set --
    LOD MARGIN: smallest drawn cap height 53.6719 px  (threshold 3.0 px, 17.8906x)  culled: 0
      textOps: 19  culledText: 0  skippedText: 0
=== 500000 entities, with text ===
  -- whole drawing --
    LOD MARGIN: smallest drawn cap height 3.0000 px  (threshold 3.0 px, 1.0000x)  culled: 2246
      textOps: 11682  culledText: 2246  skippedText: 0
  -- working set --
    LOD MARGIN: smallest drawn cap height 51.4570 px  (threshold 3.0 px, 17.1523x)  culled: 0
      textOps: 96  culledText: 0  skippedText: 0
05:06 +2: All tests passed!
exit=0
```

The 500,000-entity whole-drawing row is the point: **1.0000x**, with 2,246
labels already culled. A reader of that transcript can now see that the row is
one rounding away from moving, which was invisible before. The working-set
cameras — the ones a frame budget is actually about — sit at 17.9x and 17.2x.

The rig stays on the shipped `kMinTextCapPixels`, unchanged: it must measure the
frame production paints. The single-measurer collapse is untouched — one
`FlutterTextMeasurer` per test, `:80` and `:158`; `smallestDrawnCapPixels`
constructs painters, never measurers.

## C. Full verification for this round

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test
00:04 +291 ~1: All tests passed!
```

**291 passed, 1 skipped, 0 failed.** The skip is `test/rig/paint_microbench_test.dart`
(`@Tags(['rig'])`, "run explicitly"), run separately above.

```
$ CI=true flutter test --tags golden
00:02 +29: All tests passed!

$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.8s)

$ dart format --output=none --set-exit-if-changed .
Formatted 50 files (0 changed) in 0.09 seconds.
```

```
$ cd packages/jet_cad_2d && CI=true dart test
00:03 +777: All tests passed!

$ dart analyze
Analyzing jet_cad_2d...
No issues found!

$ dart format --output=none --set-exit-if-changed .
Formatted 110 files (0 changed) in 0.19 seconds.
```

```
$ git status --porcelain
 M apps/dev_harness/analysis_options.yaml
 M apps/dev_harness/macos/Podfile
 M apps/dev_harness/macos/Runner.xcodeproj/project.pbxproj
 M packages/jet_cad_2d_flutter/test/rig/paint_microbench_test.dart
```

No `.png` moved. The three modified files left unstaged are the known
`flutter pub get` rewrites; only the rig file is this round's change.

---

# Fix round 2 — a false justification, removed from the tree

**Commit:** `d7d4c04` — "docs: the rig's margin helper gave a false reason, and now gives the true one"

**No behaviour changed. One doc comment and one report paragraph did.**

## The claim that was wrong

`test/rig/paint_microbench_test.dart` said, of the decision not to expose the
smallest-cap-height figure from `DraftPainter`:

> this package's first non-negotiable is that the frame path allocates nothing
> per entity in steady state, so a new per-entity write on the hot text path is
> not a thing to add for a rig print

**That is false, and the counter-example is in the file the comment reasons
about.** Verified rather than taken on report:

```
$ grep -n "_arcCx\|_arcCy\|_arcR" packages/jet_cad_2d_flutter/lib/src/draft_painter.dart
275:  double _arcCx = 0, _arcCy = 0, _arcR = 0;
280:    _spanSink!.arc(_arcCx, _arcCy, _arcR, startAngle, sweep, _spanStyle!);
750:        _arcCx = coords[0] - ox;
751:        _arcCy = coords[1] - oy;
752:        _arcR = r;
...
793:        _arcCx = coords[0] - ox;
794:        _arcCy = coords[1] - oy;
795:        _arcR = r;
...
```

`DraftPainter` already holds three `double` fields and writes all three **per
dashed circle** (`:750-752`) and **per dashed arc** (`:793-795`), on the frame
path, a few lines from the cull the comment was about. A `double` field
assignment is not an allocation in Dart and this codebase relies on that. The
nothing-per-entity rule is about *allocation*; a per-entity `double` write does
not breach it.

## Why this was worth a round of its own

The decision was right; only the reasoning was wrong. But a false claim about
the project's **first non-negotiable**, sitting in the tree as a doc comment,
does more damage than an ordinary wrong comment: a later reader looking for a
cheap per-entity diagnostic would find it, believe the technique is ruled out,
and reach for something worse. This plan already spent a task repairing a
comment that had gone false when the design moved underneath it; this one was
false the day it was written.

## What it says now

`smallestDrawnCapPixels`'s doc comment now states the true argument — the number
is a **rig diagnostic**, read once per printed row by a human reading a
transcript and never by the renderer, so exposing it would put a field and a
public getter into production API whose only purpose is to be printed — and
explicitly records that the per-entity `double` write **was available and was
passed over**, citing `_arcCx`/`_arcCy`/`_arcR` with line numbers so the next
reader can check it in one grep.

The same paragraph in section B of fix round 1 above has been replaced, and says
there that the original justification was wrong even though the decision was
right.

## Verification

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test
00:04 +290 ~1: .../lineweight_test.dart: curves cannot be bypassed the threshold is exclusive, so a circle exactly at 2.0 is not counted
00:04 +291 ~1: All tests passed!
```

**291 passed, 1 skipped, 0 failed** — unchanged from fix round 1, as a
comment-only change should be.

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.8s)

$ dart format --output=none --set-exit-if-changed .
Formatted 50 files (0 changed) in 0.09 seconds.
```

```
$ git status --porcelain
 M apps/dev_harness/analysis_options.yaml
 M apps/dev_harness/macos/Podfile
 M apps/dev_harness/macos/Runner.xcodeproj/project.pbxproj
 M packages/jet_cad_2d_flutter/test/rig/paint_microbench_test.dart
```
