# Plan 3c results — text

**Date:** 2026-08-20. **Branch:** `plan-3c`. **Machine:** Apple Silicon macOS,
Flutter 3.27.3.

> ## macOS Low Power Mode was **ON** for this whole session.
>
> `pmset -g` reports `lowpowermode 1`. It was on for Plan 3b's session too and
> nobody recorded it until afterwards, which is why every `flutter drive` figure
> in `2026-08-11-plan-3b-results.md` is contaminated. **Every timing in this
> note is contaminated the same way** and is comparable only to other numbers
> taken in this same session.
>
> **No failable criterion in this plan is a timing.** All eight are counters —
> layouts, evictions, live paragraphs, `skippedTextCount` — or pass/fail on a
> test. Low Power Mode does not move any of them. The exit gate's verdict is
> therefore unaffected; only the informational time rows below are.

---

## Verdict

**The gate passes.** Every check ran, every failable criterion is met, and the
one benchmark failure is the known one carried from Plan 2.

One row had to be repaired before it could be trusted, and that repair is the
most useful thing in this note — see [The gate that was lying](#the-gate-that-was-lying).

---

## Step 1 — the checks

| Check | Result |
|---|---|
| engine suite | **720 pass** |
| engine analyze / format | clean |
| widget suite | **152 pass**, 1 pre-existing skip |
| goldens (`--tags golden`) | **13 pass**, **no existing PNG regenerated** |
| widget analyze / format | clean |
| harness analyze / format | clean |
| allocation harness | `query_allocation_test` 5 pass, with text in the corpus |
| query throughput | shape unchanged; `snap at dirty threshold` p95 **1.0800 ms** against `<1.0 ms` — the **known carried failure from Plan 2**, every other gated row passes |
| rigs | R1/R3 at 50,000 and 500,000; R2/R4a/R4b on macOS in profile mode |

Query throughput, gated rows at 500,000, for the record:

| row | p50 | p95 | threshold | |
|---|---|---|---|---|
| forEachInRect fresh | 0.7730 | 0.9250 | < 2.0 | PASS |
| pick fresh | 0.3610 | 0.5330 | < 1.0 | PASS |
| snap fresh | 0.5320 | 0.7280 | < 1.0 | PASS |
| forEachInRect at dirty threshold | 0.9470 | 1.1610 | < 2.0 | PASS |
| pick at dirty threshold | 0.4970 | 0.6210 | < 1.0 | PASS |
| snap at dirty threshold | 0.8780 | **1.0800** | < 1.0 | **FAIL (carried)** |

## Step 2 — the failable criteria

| Criterion | Threshold | Reading | |
|---|---|---|---|
| repeat frame, working-set camera | zero new layouts | **0** at 50k and 500k; **0** on device in R2, R4a and R4b | PASS |
| evictions per repeat frame, working set | zero | **0** at both sizes | PASS |
| peak live paragraphs | ≤ declared limit | **512** = `kParagraphCacheLimit` | PASS |
| `skippedTextCount` on `textRigCorpus` | 0 | **0**, both sizes, both cameras | PASS |
| differential + non-vacuity, text on | pass | `text_paint_test` 9 pass incl. *the reference walk and the painter agree with text on* and *the text corpus is not vacuous* | PASS |
| reference-query differential, text picking | pass | engine `differential_test` 72 pass incl. *textLaidOut snap matches brute force over 200 random points* | PASS |
| overlay-equals-rebuild, edited text | pass | `text_overlay_test` 4 pass | PASS |
| mutation log | every mutant killed or argued equivalent | 53 accounted, **52 killed, 1 not applicable**, none argued equivalent | PASS |

---

## The gate that was lying

`text_paint_allocation_test.dart` failed **one full-suite run in eleven** while
the code under test was correct. The failure text looked like evidence:

```
Expected: a value less than or equal to <0.9482>
  Actual: <1.00035>
  text Transform2 1.00 ... vs norm Transform2 0.60 ... per leaf
```

The subject read a healthy 1.00. The **control** read 0.60. `_norm` allocates
exactly one `Transform2` per iteration and returns it, so its true cost is
1.00 by construction; 0.60 is not a result, it is the VM allocation profiler's
low-read artefact. Ruling 31 had already seen that artefact and answered it by
making every assertion a ratio — which works when all three loops read low
**together**. This run is the other kind: only the control read low, and a
ratio makes that *worse*, because a smaller denominator tightens the bound.

The repair is a plausibility guard, not a wider bound. The norm and wrappers
loops are **controls with answers fixed by construction** — 1.00 and 9.00 — and
neither depends on anything the subject does. A reading materially below either
is a failed measurement, so the test re-takes it, up to four times, and fails
with *"this is a meter failure; nothing is known about the text path from this
run"* if it never gets a clean read. **Retrying cannot mask a text regression:
nothing `_drawText` could do would make the control loop under-report.**

Verified both ways. Fifteen consecutive full-suite runs after the repair: **0
failures**. And with the retry limit mutated to one attempt, the very first
read came back **0.70** — the artefact reproduced immediately, so the retry is
load-bearing and measured, not defensive decoration.

---

## What text costs

`textRigCorpus`: `rigCorpus`'s shape plus `labelFraction: 0.02` and
`attributedInstanceFraction: 0.2`. **R1 runs under `flutter test` — debug JIT,
`PictureRecorder` recording without rasterising. A relative signal only; not
comparable to the device rows.**

The text-on / text-off delta is **one branch apart on one document**
(`DraftPainter.drawText`), not two documents, so the entity mix, the extents
and both cameras are identical across each pair.

### 50,000 entities (54,000 with text: 4,000 attributes, 928 labels)

| camera | | paint p50 | query-only p50 | ops/frame | canvasCalls | textOps |
|---|---|---|---|---|---|---|
| working set | text on | 29.691 ms | 2.149 ms | 66,904 | 59,212 | 19 |
| working set | text off | 29.207 ms | 2.113 ms | 66,847 | 59,193 | 0 |
| whole drawing | text on | 956 ms | 432.7 ms | 2,067,600 | 689,200 | 4,928 |
| whole drawing | text off | 861 ms | 335.5 ms | 2,052,816 | 684,272 | 0 |

### 500,000 entities (504,000 with text: 4,000 attributes, 9,928 labels)

| camera | | paint p50 | query-only p50 | ops/frame | canvasCalls | textOps |
|---|---|---|---|---|---|---|
| working set | text on | 77.736 ms | 11.266 ms | 149,604 | 136,114 | 96 |
| working set | text off | 72.303 ms | 10.988 ms | 149,316 | 136,018 | 0 |
| whole drawing | text on | 1430.8 ms | 654.6 ms | 3,417,600 | 1,139,200 | 13,928 |
| whole drawing | text off | 1479.9 ms | 549.4 ms | 3,375,816 | 1,125,272 | 0 |

**At the working-set camera text is free within the noise.** 19 text ops cost
+0.5 ms of a 29 ms frame at 50k; 96 cost +5.4 ms of a 72 ms frame at 500k. The
op-count deltas are exact and confirm the flag does only what it claims: 57 ops
at 50k (19 leaves x begin/text/end) and 19 canvas calls; 288 and 96 at 500k.

**At the whole-drawing camera the reading is dominated by cache thrash, and at
500k it is inside the run-to-run variance** — text-off measured *slower* than
text-on there (1479.9 against 1430.8, n=14 and n=15, p95 1538.8 and 1609.9). Do
not read a text cost out of that pair.

**The query-only row pays for text even though it lays out nothing.** +97 ms at
50k, +105 ms at 500k, into a `NullDrawSink`. That is not the sink; it is
`document.textMeasurer.measure(...)` in `_drawText`, which runs whatever the
sink is. See [two caches](#there-are-two-paragraph-caches-not-one).

---

## The cache

### Distinct visible keys — the number the gate's feasibility rests on

The paragraph cache key is `(string, textStyle handle, ResolvedStyle.argb)`.
The number of **distinct** keys visible at a camera is the number of entries the
cache must hold for a steady-state frame to lay nothing out. `kParagraphCacheLimit`
is **512**.

| entities | camera | distinct keys | text ops | |
|---|---|---|---|---|
| 50,000 | working set | **18** | 19 | under, 28x margin |
| 50,000 | whole drawing | **4,140** | 4,928 | 8x over |
| 500,000 | working set | **72** | 96 | under, 7x margin |
| 500,000 | whole drawing | **4,140** | 13,928 | 8x over |

**`kParagraphCacheLimit` does not move and `attributedInstanceFraction` does not
move.** Ruling 4 allows the limit one raise, in Task 12, with the measured count
recorded beside it. The measurement says no raise is needed, so the raise stays
unspent.

The whole-drawing count is **4,140 at both entity counts** and that is not a
coincidence: 4,020 distinct `(string, style)` pairs — 4,000 unique attribute
tags plus the 20-word label vocabulary — times 7 resolved colours. It is bounded
by the corpus's *string* variety, not by its size.

### Hit rate, split by source

The spec asks for these separately because the corpus's two text sources have
opposite cache behaviour by construction, and a blended figure hides that one of
them is the entire pressure.

| entities | camera | labels | attributes |
|---|---|---|---|
| 500,000 | whole drawing | **98.6%** (9,928 ops / 140 keys) | **0.0%** (4,000 ops / 4,000 keys) |
| 500,000 | working set | 30.4% (79 ops / 55 keys) | **0.0%** (17 ops / 17 keys) |

**Room labels are essentially free and attributes are the entire cost.** 9,928
label draws are served by 140 entries — twenty vocabulary words across seven
colours — while every one of the 4,000 attributes carries a string built from
its own instance ordinal and can never hit. That is the shape of the real
payload too: a drawing's labels repeat and its tag values do not.

The rig cross-checks the classification against the entity-kind counts it reads
from the document and throws if an attribute tag ever repeats, so the split is
checked rather than assumed.

### Where the limit starts to bind

"Under the limit" is not "under the limit with margin", so the rig prints a
ladder, zooming out about the working-set centre:

| view width (world units) | keys @ 50k | keys @ 500k | |
|---|---|---|---|
| 3,000 (the working set) | 18 | 72 | under |
| 6,000 | 72 | 166 | under |
| 12,000 | 273 | 354 | under |
| 24,000 | 976 | 953 | **over** |
| 48,000 | 3,469 | 3,442 | over |
| 96,000 (whole drawing) | 4,140 | 4,140 | over |

**The limit begins to bind between 12,000 and 24,000 units wide — about five
times the working-set camera — and the crossover is the same at both entity
counts.** That is the margin, as a number, for whoever revisits it.

---

## Whole-drawing thrash — input to 3e's LOD decision

At the whole-drawing camera the cache does not merely miss, it **evicts an entry
the same frame asks for again**: 4,140 new layouts and 4,140 new evictions per
frame at both entity counts, in each of two caches (349,740 layouts in the
document's cache over the 500k run, 149,040 in the sink's).

This is the case for text LOD rather than a bigger cache. Raising the limit to
4,140 would hold one zoom level of one corpus; the count is bounded by string
variety, and a real site plan has more distinct tag values than this corpus, not
fewer. What actually removes the cost is **not drawing text that is too small to
read**, which is Plan 3e's decision to make. The working-set numbers say the
cache is the right mechanism for the frames a user actually renders, and the
whole-drawing numbers say it is not a mechanism for the frames they do not.

## There are two paragraph caches, not one

`DraftPainter` reads metrics from `document.textMeasurer`; `CanvasDrawSink` lays
paragraphs out through `DraftCanvas`'s own `FlutterTextMeasurer`. They are
different objects with different keys — the metrics probe is always built at
`kMetricsProbeArgb`, the drawn paragraph at the entity's colour — so **a text
leaf costs up to two layouts, not one**, and the metrics half runs even when the
sink is a `NullDrawSink`. That is the +97 ms / +105 ms on the query-only rows
above. Recorded, not fixed; it is a question about who owns the document's
measurer.

## Nothing outside the tests wires a real measurer into a document

`DraftDocument.empty` defaults to `InsertionPointMeasurer`, the zero metrics. On
it, `composeTransform`'s `height / metrics.capHeight` divides into zero — the
text transform is singular — and `entityBounds` collapses every glyph box to a
point. **An application that builds a document the ordinary way and draws text
gets nothing visible and no error.** No production path in this repository
passes a measurer; only tests, `textRigCorpus`, and the harness under
`--dart-define=TEXT=true` do.

Task 13 added the second piece of evidence: mutant S21 replaced the extents
walk's `measurer: textMeasurer` with a hard-coded default and **survived both
full suites**, because every text case in `extents_test.dart` passed
`entityBounds` an explicit measurer and so tested the function's parameter
rather than the document's field.

This is a real defect with no owner. It is out of Plan 3c's scope — the plan
specifies the seam, not who plugs it in — and it must be settled before text
ships to an application.

## `kCapHeightRatio` — the declared deviation

`dart:ui` exposes no cap height, so `FlutterTextMeasurer` returns
`kCapHeightRatio * kNominalTextPixels` = **70.0** for every font. Measured
against the vendored Roboto's own `OS/2.sCapHeight`:

| | value |
|---|---|
| Roboto-Regular `unitsPerEm` | 2048 |
| Roboto-Regular `sCapHeight` | 1456 |
| true ratio | **0.710938** |
| `kCapHeightRatio` | 0.700000 |
| deviation | **−1.54%** |

DXF height is cap height and the matrix scale is `effectiveHeight / capHeight`,
so under-stating cap height over-states the scale: **text drawn through this
engine is about 1.56% taller than DXF-nominal in Roboto.** Under a millimetre on
a 50 mm title. It is a constant, not a per-font lookup, so the deviation is a
different number in every other font — which is the reason it is declared here
rather than hidden.

---

## Device rows — R2/R4a/R4b, macOS, profile mode

`flutter drive --profile -d macos --dart-define=TEXT=true`, all three rigs in one
session. **Low Power Mode was on; see the banner.**

| rig | build p50 | raster p50 | canvasCalls | textOps | steady-state | run totals |
|---|---|---|---|---|---|---|
| R2 pan and zoom | 20.15 ms | 88.18 ms | 51,298 | 23 | **newLayouts 0** | 1,190 layouts, 678 evictions |
| R4a leaf edit per frame | 21.17 ms | 88.87 ms | 48,940 | 18 | **newLayouts 0** | 1,179 / 667 |
| R4b instance drag per frame | 24.07 ms | 85.24 ms | 50,510 | 18 | **newLayouts 0** | 1,165 / 653 |

Three independent camera scripts, three steady-state frames, zero new layouts in
all three. The run totals are near-identical because all three start from the
same working-set camera; the thrash they record is the ladder's crossover being
touched briefly during R2's zoom sweep, not a steady-state cost.

One more R2 pair, one define apart on one document:

| | build p50 | raster p50 | canvasCalls | textOps |
|---|---|---|---|---|
| `TEXT=true` | 20.19 ms | 89.03 ms | 51,298 | 23 |
| `TEXT=true DRAW_TEXT=false` | 20.13 ms | 81.59 ms | 51,275 | 0 |

+7.4 ms raster for 23 text ops, build unchanged. **Single runs; treat that gap as
suggestive rather than settled**, and remember Low Power Mode.

For comparison and *not* as a delta, `TEXT` unset — Plan 3b's own corpus —
reads build 20.76 ms, raster 79.28 ms, 54,164 canvas calls. It is a different
document and is here only to show the baseline was not disturbed.

---

## Reproducing

```sh
cd .claude/worktrees/plan-3c

(cd packages/jet_cad_2d         && dart test)                      # 720
(cd packages/jet_cad_2d         && dart analyze && dart format --output=none --set-exit-if-changed .)
(cd packages/jet_cad_2d_flutter && flutter test)                   # 152, 1 skip
(cd packages/jet_cad_2d_flutter && flutter test --tags golden)     # 13
(cd packages/jet_cad_2d_flutter && flutter analyze && dart format --output=none --set-exit-if-changed .)
(cd apps/dev_harness_2d         && flutter analyze)
(cd packages/jet_cad_2d         && dart run benchmark/query_throughput.dart)

# the text rig: both sizes, both cameras, on and off, plus the key ladder
(cd packages/jet_cad_2d_flutter && flutter test --tags rig --run-skipped \
   test/rig/paint_microbench_test.dart --plain-name "text paint")

# device rows (TEXT/DRAW_TEXT must be "true"/"false" -- 1/0 reads as false)
(cd apps/dev_harness_2d && flutter drive --profile -d macos \
   --driver=test_driver/integration_test.dart \
   --target=integration_test/frame_timing_test.dart \
   --dart-define=TEXT=true)

pmset -g | grep lowpowermode   # state this in any note carrying a timing
```

`flutter drive` rewrites `apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj`
(CocoaPods bumps `MACOSX_DEPLOYMENT_TARGET` 10.15 → 12.0). Revert it; do not
commit it.

## Carried forward

| # | Item | To |
|---|---|---|
| 1 | Nothing outside the tests wires a real measurer into a document; text draws nothing and reports no error | must be settled before text ships to an application |
| 2 | Two paragraph caches, so a text leaf costs up to two layouts and the query path pays for text | 3d/3e |
| 3 | The per-text-leaf allocation gate lives in the engine suite and measures the engine helpers in the painter's order, not the painter; closing it means moving `AllocationMeter` into `jet_cad_2d/lib/src/testing/` | 3d |
| 4 | Whole-drawing thrash: 4,140 layouts and 4,140 evictions per frame, bounded by string variety rather than entity count | 3e's text LOD decision |
| 5 | `snap at dirty threshold` p95 1.08 ms against < 1.0 ms | carried from Plan 2, unchanged |
| 6 | `DocumentTree._link` is quadratic in a parent's child count, which is why the rigs cap `instanceCount` at 20,000 | recorded in Plan 3b, unchanged |
