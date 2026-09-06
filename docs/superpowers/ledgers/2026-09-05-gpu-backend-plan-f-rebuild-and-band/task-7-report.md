# Task 7 report — the band measured (criterion 2), the zoom defects (criterion 12)

**Status: NEEDS_CONTEXT.** Nothing is committed. All four steps of instrument
work are built and validated; three of the four `zoom_defect_test.dart` tests
pass, including **both criterion-12 reproductions, at the probe's exact
numbers**. The band sweep's edge assertions are red, and the investigation
below shows the cause is **the criterion the plan chose to measure the band
with, not the band constants** — so Ruling F6's constant move was NOT applied.
That decision needs the coordinator.

---

## 1. What was implemented

**Step 1 — the instrument** (`test/support/gpu_comparison.dart`, modified):
`CompositedAgreement` gains a sixth positional field `uncovered` (reference ink
the resident arm left blank — the zoom-out defect's own unit) and a
`toString`. `measureCompositedAgreement` gains `Size? collectionViewport`,
used as `painter.paint(collector, collectionCamera, collectionViewport ??
size)`; the pixel loop counts `if (inkA && !inkB) uncovered++`.

**Step 2 — the rig** (`test/support/resident_zoom_rig.dart`, new): verbatim
from the brief. `ResidentZoomRig` holds the collection frame, re-collects when
a frame's ratio leaves the band, counts `rebuilds` / `staleFrames`.

**Step 3 — the band sweep** (`test/gpu/band_sweep_test.dart`, new): verbatim
from the brief.

**Step 5 — the zoom defects** (`test/gpu/zoom_defect_test.dart`, new): verbatim
from the brief, less the `dart:ui` import (unnecessary — `flutter_test`
re-exports `Offset`; the analyzer flags it as an info, which this workspace
treats as a failure).

**Not modified:** `lib/src/gpu/text_patches.dart`. The band constants stay
`kBandLowerScale = 0.5` / `kBandUpperScale = 2.0`. See §4.

---

## 2. The printed rows of record

### BAND (all 27 rows, verbatim)

```
BAND curves@fit ratio=0.25 FAIL CompositedAgreement(agreement=0.90605 withinTwo=434 union=479 overEight=45 uncovered=23 referenceInk=457 patches=0)
BAND curves@fit ratio=0.35 FAIL CompositedAgreement(agreement=0.89680 withinTwo=617 union=688 overEight=71 uncovered=38 referenceInk=655 patches=0)
BAND curves@fit ratio=0.5 FAIL CompositedAgreement(agreement=0.92731 withinTwo=893 union=963 overEight=70 uncovered=41 referenceInk=934 patches=0)
BAND curves@fit ratio=0.7 FAIL CompositedAgreement(agreement=0.93443 withinTwo=1254 union=1342 overEight=88 uncovered=47 referenceInk=1301 patches=0)
BAND curves@fit ratio=1.0 PASS CompositedAgreement(agreement=1.00000 withinTwo=1873 union=1873 overEight=0 uncovered=0 referenceInk=1873 patches=0)
BAND curves@fit ratio=1.4 FAIL CompositedAgreement(agreement=0.90128 withinTwo=2182 union=2421 overEight=239 uncovered=115 referenceInk=2297 patches=0)
BAND curves@fit ratio=2.0 FAIL CompositedAgreement(agreement=0.84739 withinTwo=1477 union=1743 overEight=266 uncovered=140 referenceInk=1617 patches=0)
BAND curves@fit ratio=2.8 FAIL CompositedAgreement(agreement=0.82645 withinTwo=1381 union=1671 overEight=290 uncovered=137 referenceInk=1518 patches=0)
BAND curves@fit ratio=4.0 FAIL CompositedAgreement(agreement=0.80822 withinTwo=767 union=949 overEight=182 uncovered=90 referenceInk=857 patches=0)
BAND curves@8x ratio=0.25 FAIL CompositedAgreement(agreement=0.89142 withinTwo=1527 union=1713 overEight=186 uncovered=90 referenceInk=1617 patches=0)
BAND curves@8x ratio=0.35 FAIL CompositedAgreement(agreement=0.92303 withinTwo=1463 union=1585 overEight=122 uncovered=55 referenceInk=1518 patches=0)
BAND curves@8x ratio=0.5 FAIL CompositedAgreement(agreement=0.96441 withinTwo=840 union=871 overEight=31 uncovered=17 referenceInk=857 patches=0)
BAND curves@8x ratio=0.7 PASS CompositedAgreement(agreement=1.00000 withinTwo=569 union=569 overEight=0 uncovered=0 referenceInk=569 patches=0)
BAND curves@8x ratio=1.0 FAIL CompositedAgreement(agreement=0.98747 withinTwo=473 union=479 overEight=6 uncovered=0 referenceInk=473 patches=0)
BAND curves@8x ratio=1.4 PASS CompositedAgreement(agreement=1.00000 withinTwo=497 union=497 overEight=0 uncovered=0 referenceInk=497 patches=0)
BAND curves@8x ratio=2.0 PASS CompositedAgreement(agreement=1.00000 withinTwo=248 union=248 overEight=0 uncovered=0 referenceInk=248 patches=0)
BAND curves@8x ratio=2.8 FAIL CompositedAgreement(agreement=1.00000 withinTwo=0 union=0 overEight=0 uncovered=0 referenceInk=0 patches=0)
BAND curves@8x ratio=4.0 FAIL CompositedAgreement(agreement=1.00000 withinTwo=0 union=0 overEight=0 uncovered=0 referenceInk=0 patches=0)
BAND text-lod@fit ratio=0.25 FAIL CompositedAgreement(agreement=0.93919 withinTwo=834 union=888 overEight=45 uncovered=0 referenceInk=835 patches=2)
BAND text-lod@fit ratio=0.35 PASS CompositedAgreement(agreement=1.00000 withinTwo=1364 union=1364 overEight=0 uncovered=0 referenceInk=1364 patches=2)
BAND text-lod@fit ratio=0.5 PASS CompositedAgreement(agreement=1.00000 withinTwo=2356 union=2356 overEight=0 uncovered=0 referenceInk=2356 patches=2)
BAND text-lod@fit ratio=0.7 PASS CompositedAgreement(agreement=1.00000 withinTwo=4048 union=4048 overEight=0 uncovered=0 referenceInk=4048 patches=2)
BAND text-lod@fit ratio=1.0 PASS CompositedAgreement(agreement=1.00000 withinTwo=7398 union=7398 overEight=0 uncovered=0 referenceInk=7398 patches=2)
BAND text-lod@fit ratio=1.4 FAIL CompositedAgreement(agreement=0.98879 withinTwo=13315 union=13466 overEight=148 uncovered=153 referenceInk=13466 patches=2)
BAND text-lod@fit ratio=2.0 FAIL CompositedAgreement(agreement=0.98671 withinTwo=21600 union=21891 overEight=289 uncovered=293 referenceInk=21891 patches=2)
BAND text-lod@fit ratio=2.8 FAIL CompositedAgreement(agreement=0.97226 withinTwo=19100 union=19645 overEight=540 uncovered=545 referenceInk=19645 patches=2)
BAND text-lod@fit ratio=4.0 FAIL CompositedAgreement(agreement=0.53611 withinTwo=1247 union=2326 overEight=1071 uncovered=1081 referenceInk=2326 patches=1)
```

No `BAND … run=[…]` line printed on any corpus: all three tests fail at the
edge assertion, which precedes the `passingRun` print. Computed by hand from
the rows above, with the brief's own `passingRun` definition:

| corpus | passing run containing 1.0 | width |
| --- | --- | --- |
| `curves@fit` | `[1.0, 1.0]` | **1.00x** |
| `curves@8x` | `[0.7, 2.0]` (but 1.0 itself FAILs) | 2.86x |
| `text-lod@fit` | `[0.35, 1.0]` | 2.86x |

Intersection: **`[1.0, 1.0]` = 1.00x**.

### ZOOM-OUT / ZOOM-IN (verbatim)

```
ZOOM-OUT tiled uncovered: gesture=[1656, 2833, 3586, 2949, 2330, 4322, 4375, 4204, 4456, 2836, 5730, 4893] settle=[4893, 0, 0, 0, 0, 0]
ZOOM-OUT resident uncovered=[0, 0, 2, 2, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0] rebuilds=1 stale=1
ZOOM-IN tiled differing over the settle: [25275, 16681, 0, 0, 0, 0]
```

**Criterion 12's reproduction half is exact.** The tiled zoom-out peaks at
**5,730** and still reads **4,893** one frame after the gesture — the probe's
two recorded numbers, to the pixel. The tiled zoom-in settle reads
**25,275 / 16,681 / 0** — the probe's three numbers, to the pixel. Both tiled
tests PASS.

The resident zoom-in test PASSES outright: uncovered 0 and agreement >= 0.995
at all 18 frames, `rebuilds == 0` (1.02^12 = 1.27, inside the band). The
resident zoom-out test carries `rebuilds == 1`, `stale == 1` exactly as the
plan predicted (0.94^12 = 0.476 leaves the band at the last step), and its
uncovered count is **0 on 14 of 18 frames, and 1 or 2 on the other four** —
against the tiled arm's 1,656–5,730. It fails only the literal
`everyElement(0)`.

---

## 3. Investigation: is the instrument sound?

Three diagnostics, run in a scratch test file since deleted.

**(a) `collectionViewport` reaches the collector — proven.** On `crossingGrid`
at ratio 1.0, with the collection frame's camera:

```
DIAG no-viewport ratio=1.0 CompositedAgreement(agreement=0.95731 withinTwo=9374 union=9792 overEight=418 uncovered=418 referenceInk=9792 patches=0)
DIAG lines    ratio=1.0 CompositedAgreement(agreement=0.99918 withinTwo=9784 union=9792 overEight=8 uncovered=8 referenceInk=9792 patches=0)
```

Without the parameter the shifted collection camera culls to 800x600 and
**418** pixels go uncovered; with it, 8. Step 1's plumbing works and is
load-bearing. The brief's "check `collectionViewport` reached the collector"
is answered yes.

**(b) The affine path is pixel-exact at every ratio — on straight lines.**

```
DIAG lines ratio=0.25 agreement=1.00000 union=2399 overEight=0 uncovered=0
DIAG lines ratio=0.5  agreement=1.00000 union=4876 overEight=0 uncovered=0
DIAG lines ratio=0.7  agreement=1.00000 union=6844 overEight=0 uncovered=0
DIAG lines ratio=1.0  agreement=0.99918 union=9792 overEight=8 uncovered=8
DIAG lines ratio=1.4  agreement=1.00000 union=10244 overEight=0 uncovered=0
DIAG lines ratio=2.0  agreement=1.00000 union=8270 overEight=0 uncovered=0
DIAG lines ratio=4.0  agreement=1.00000 union=3992 overEight=0 uncovered=0
```

A 16x range, perfect agreement throughout. The collection frame, the
`collectionToDevice` composition, `expandInstances` and the compositor
reproduce the reference exactly under an arbitrary scale ratio. **The
instrument is sound and the band sweep's failures are not an arrangement bug.**
This also bounds the resident zoom-out's stray pixels: the same corpus shows
the same signature (8 pixels at ratio 1.0, 0 elsewhere) — a sub-pixel float
tie-break between the two arms' independent float paths, not a coverage gap.

**(c) The decisive one: criterion 1 on a curve corpus is a step function, not
a drift curve.** `differentialFixture`, collection at fit, ratios near 1.0:

```
DIAG curves ratio=1.0   agreement=1.00000 union=1873 overEight=0   uncovered=0
DIAG curves ratio=1.001 agreement=1.00000 union=1844 overEight=0   uncovered=0
DIAG curves ratio=1.01  agreement=0.96616 union=1921 overEight=65  uncovered=35
DIAG curves ratio=1.05  agreement=0.93576 union=2008 overEight=129 uncovered=57
DIAG curves ratio=1.1   agreement=0.92279 union=2124 overEight=164 uncovered=78
DIAG curves ratio=0.99  agreement=1.00000 union=1845 overEight=0   uncovered=0
DIAG curves ratio=0.95  agreement=0.97789 union=1764 overEight=39  uncovered=21
```

**A 1% zoom already fails criterion 1** (0.966 against the 0.995 clause), while
0.1% is perfect. Then the curve is nearly flat: 0.966 at 1.01, 0.923 at 1.1,
0.901 at 1.4, 0.847 at 2.0. That is not drift accumulating with distance from
the reference scale. It is the moment the live scale crosses a tessellation
refinement threshold and the two arms stop choosing the same chord count.

At ratio exactly 1.0 the resident arm's frozen chords ARE the reference's
chords, so the two agree bit-for-bit and criterion 1 reads 1.00000. At any
other ratio they are two independent, individually-correct polygonal
approximations of the same curve, differing by a fraction of a pixel along the
outline. On a corpus that is almost entirely curve outline, a fraction of a
pixel moves ~7-10% of the ink pixels by more than 8 per channel.

**So on a curve corpus, criterion 1 as coded measures tessellation identity,
not picture drift.** No choice of band constants can widen that past 1.0x,
because the only ratio at which two independent tessellations coincide is 1.0.

---

## 4. Ruling F6: which outcome, and why the constants did not move

Read mechanically, the rows give **outcome 3**: edge assertions are red and the
intersection of the runs (1.00x) is narrower than 2x. Outcome 3 directs
outcome 2's constant move (`0.5 -> 0.7`, `2.0 -> 1.4`) plus a note recording
criterion 2 as the design failure the spec names.

**I did not make that move, for two reasons.**

**It does not reach green, so it is not the fix F6 was written to be.** With
the constants at 0.7 / 1.4, the edge assertions check ratios 0.7, 1.0 and 1.4:

- `curves@fit`: 0.7 FAIL, 1.0 PASS, 1.4 FAIL — still red
- `curves@8x`: 0.7 PASS, 1.0 **FAIL**, 1.4 PASS — still red
- `text-lod@fit`: 0.7 PASS, 1.0 PASS, 1.4 FAIL — still red

All three tests stay red at the moved constants. F6's three outcomes each
presuppose the failure is a fact about band *width*; here it is not, so the
ruling has no branch that terminates.

**And the measurement does not support moving a production constant.** §3(c)
shows the curve corpora fail at a 1% zoom. A constant chosen from that says
"rebuild whenever the user zooms 1%", which is not a band — it is the
criterion refusing any tessellation difference at all. Moving
`kBandLowerScale` / `kBandUpperScale` in `text_patches.dart` on that evidence
would change how the shipped rebuilder triggers, on a number that does not
mean what the constant means. Per the brief's own framing of F6 — the failing
row must be *a band result* — this one is not.

Two further facts argue the curve corpora are the wrong instrument here:

- **The brief's own anti-vacuity floor fails on both.** It asserts
  `referenceInk > 5000` at ratio 1.0; `curves@fit` inks **1,873** and
  `curves@8x` inks **473**. (The 5,000 figure appears to be carried over from
  Plan E's `resident_pixel_differential_test.dart`, which measures a different
  corpus — `_corpus`, at dpr 2.0 — not `differentialFixture` at dpr 1.0.)
- **`curves@8x` is degenerate.** Zooming the fit camera 8x about the viewport
  centre puts most of the drawing off-screen: ratios 2.8 and 4.0 read
  `union=0`, ink nothing at all, and the PASS/FAIL pattern
  (0.5 FAIL, 0.7 PASS, **1.0 FAIL**, 1.4 PASS, 2.0 PASS) is decided by single
  pixels on a 248-569 pixel union — 6 differing pixels out of 479 is what
  fails ratio 1.0. A non-monotone band with a failing centre is noise, not a
  measurement.

**`text-lod@fit` is the only corpus here with enough ink for criterion 1's
99.5% clause to mean anything** (7,398 at ratio 1.0, up to 21,891), and it
gives a clean monotone result: PASS at 0.35, 0.5, 0.7, 1.0; FAIL from 1.4 up.
Band **[0.35, 1.0] = 2.86x** — wider than 2x, but **asymmetric**: it holds
through a 2.9x zoom-out and fails on the first zoom-in step past 1.0. That is
a real and reportable result, and notably it is the corpus whose ink is
dominated by text patches, which the compositor re-renders from the live
paragraph rather than from frozen triangles.

**What I recommend the coordinator decide** (any of these is above a task
implementer's authority):

1. Whether criterion 2's band should be measured with criterion 1's
   per-channel pixel-exactness clause at all, given §3(c) — or with a
   perceptual/coverage measure that does not treat two valid tessellations of
   one curve as a disagreement.
2. Whether the curve corpora should be re-arranged so they satisfy the
   brief's own `referenceInk > 5000` floor and stay on-screen at every swept
   ratio, before any constant moves.
3. Whether the reported band is `text-lod@fit`'s `[0.35, 1.0]`, and whether an
   asymmetric band (wide on zoom-out, tight on zoom-in) is acceptable to the
   design or is itself the criterion-2 design failure.

---

## 5. TDD evidence

- The instrument's new `collectionViewport` has a witness before it has a
  user: §3(a), 418 uncovered pixels without it against 8 with it, on the same
  frame. Removing the parameter's use is a mutation this measurement catches.
- The new `uncovered` field is the unit the whole zoom-out claim is stated in;
  it reads 1,656-5,730 on the tiled arm and 0-2 on the resident arm at the
  same gesture, so it discriminates the two arms by three orders of magnitude.
- `zoom_defect_test.dart` carries the brief's M-F5 mutation note: collecting
  under the live camera and `kTileViewport` instead of the collection frame
  reveals uncovered rim ink on the first zoom-out step. §3(a) is that mutation
  run in isolation (418 pixels), so the note is verified, not asserted.
- The band sweep's anti-vacuity assertion (`rows[4.0].agreement <
  rows[1.0].agreement`, 0.80822 < 1.00000) holds on `curves@fit`: the
  instrument is not comparing the resident arm to itself. It was not reached
  by the runner (the edge assertion precedes it) but is satisfied by the rows.

## 6. The three gates

```
$ cd packages/jet_cad_2d_flutter && flutter test
00:07 +658 ~1 -4: Some tests failed.

Failing tests:
  .../test/gpu/band_sweep_test.dart: solid curves at a working zoom: Float32 at 8x the fit scale holds criterion 1 at the band's edges
  .../test/gpu/band_sweep_test.dart: solid curves: criterion 1 holds at the band's edges and at 1.0, and the divergence past the band is real
  .../test/gpu/band_sweep_test.dart: text with level of detail on: criterion 1 holds at the band's edges and at 1.0
  .../test/gpu/zoom_defect_test.dart: zoom out, twelve steps of 0.94 the resident arm leaves nothing uncovered at any frame
EXIT != 0
```

**658 passing, 4 failing — every failure is one of this task's own
pre-committed assertions.** No pre-existing test regressed. Verified
separately:

```
$ flutter test test/gpu/text_order_test.dart test/gpu/resident_pixel_differential_test.dart test/gpu/resident_text_test.dart
00:00 +22: All tests passed!
```

Plan E's `text_order_test.dart` and `resident_pixel_differential_test.dart`
stay green under the six-argument `CompositedAgreement`, as does
`resident_text_test.dart`'s "the band constants and the pad are what the spec
says" (`expect(kBandLowerScale, 0.5); expect(kBandUpperScale, 2.0);`) — which
it does because the constants were not moved.

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.8s)
EXIT=0

$ dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.16 seconds.
FORMAT_EXIT=0
```

Two of three gates are green. `flutter test` is not, which is why nothing is
committed.

## 7. Files changed (uncommitted, in the worktree)

```
 M packages/jet_cad_2d_flutter/test/support/gpu_comparison.dart
 ?? packages/jet_cad_2d_flutter/test/gpu/band_sweep_test.dart
 ?? packages/jet_cad_2d_flutter/test/gpu/zoom_defect_test.dart
 ?? packages/jet_cad_2d_flutter/test/support/resident_zoom_rig.dart
```

No `analysis_options.yaml`. No production file touched — `text_patches.dart`
is unmodified. `packages/jet_cad_2d`, `vertices_draw_sink.dart`,
`canvas_draw_sink.dart` untouched; no shader change; `DraftPainter` gained no
API.

## 8. Self-review

- **The `passingRun` helper the brief specifies does not check its own
  centre.** It seeds `lo = hi = 1.0` and walks outward without testing
  `rows[1.0]`, so on `curves@8x` it reports `[0.7, 2.0]` although ratio 1.0
  inside that interval FAILs. Any run it reports should be read against the
  rows, not on its own. I left it verbatim rather than fix a briefed helper
  mid-task; it is worth correcting before these numbers are quoted anywhere.
- The band sweep prints its `run=` line only after the edge assertions, so a
  failing corpus prints no run at all — exactly the corpus whose run one wants
  to read. Moving the print above the assertions would make the file more
  useful as an instrument.
- I did not verify *where* the resident zoom-out's 1-2 stray pixels land
  (endpoint caps versus outline). The evidence that they are float tie-breaks
  is circumstantial but consistent: same corpus and same magnitude as the
  8-pixel reading at ratio 1.0 in §3(b), no trend across the gesture, and 0 on
  every settle frame. A pixel-position dump would settle it.
- `ResidentZoomRig` counts a frame out of band as `staleFrames` and rebuilds
  for the next frame, per the brief. On the zoom-out gesture that fires once,
  at the last step, and the six settle frames that follow are all in band —
  so the rig's re-collection ordering is exercised but its *stale* frame is
  only ever the one. A gesture that left the band mid-way would test it
  harder.

## 9. Concerns

1. **The headline: criterion 2 cannot be measured with criterion 1 on curve
   geometry** (§3(c)). This is the finding that blocks the task, and it is a
   spec/plan question, not an implementation one.
2. The band constants remain `0.5` / `2.0`, deliberately. If the coordinator
   wants F6 applied mechanically despite §4, that is one edit plus the named
   test updates — but the sweep stays red either way.
3. Both curve corpora violate the brief's own ink floor, and `curves@8x` inks
   nothing at two swept ratios. Any band quoted from them is quoted from a
   few hundred pixels.

---

# Fix report — rulings F6-a, F6-b, F13-a applied

**Status: NEEDS_CONTEXT again, on one row, and it is the row the ruling told
me to stop on.** `zoom_defect_test.dart` is fully green under F13-a. Four of
the five rewritten band tests are green. **Test 1 (`straight geometry meets
criterion 1 at every ratio of the sweep`) fails at exactly one ratio — 1.0 —
by 8 pixels out of 9,792**, and test 5 fails only as its consequence. Per the
ruling's closing instruction I stopped rather than loosening it. Nothing is
committed.

## What was rewritten

`band_sweep_test.dart`: five tests as specified; `sweep`, `criterionOne`,
`kRatios` kept; `passingRun` now takes a corpus name, requires `rows[1.0]` to
pass, and prints `run=[1.0, 1.0] = 1.00x (ratio 1.0 itself fails criterion 1,
so there is no run)` when it does not. `zoom_defect_test.dart`: the resident
zoom-out's `everyElement(0)` is replaced by the two per-frame bounds of Ruling
F13-a, with the ruling's comment; the tiled reproductions are untouched.

## The blocking row

```
BAND straight@fit ratio=0.25 PASS CompositedAgreement(agreement=1.00000 withinTwo=2399 union=2399 overEight=0 uncovered=0 referenceInk=2399 patches=0)
BAND straight@fit ratio=0.35 PASS CompositedAgreement(agreement=1.00000 withinTwo=3392 union=3392 overEight=0 uncovered=0 referenceInk=3392 patches=0)
BAND straight@fit ratio=0.5 PASS CompositedAgreement(agreement=1.00000 withinTwo=4876 union=4876 overEight=0 uncovered=0 referenceInk=4876 patches=0)
BAND straight@fit ratio=0.7 PASS CompositedAgreement(agreement=1.00000 withinTwo=6844 union=6844 overEight=0 uncovered=0 referenceInk=6844 patches=0)
BAND straight@fit ratio=1.0 FAIL CompositedAgreement(agreement=0.99918 withinTwo=9784 union=9792 overEight=8 uncovered=8 referenceInk=9792 patches=0)
BAND straight@fit ratio=1.4 PASS CompositedAgreement(agreement=1.00000 withinTwo=10244 union=10244 overEight=0 uncovered=0 referenceInk=10244 patches=0)
BAND straight@fit ratio=2.0 PASS CompositedAgreement(agreement=1.00000 withinTwo=8270 union=8270 overEight=0 uncovered=0 referenceInk=8270 patches=0)
BAND straight@fit ratio=2.8 PASS CompositedAgreement(agreement=1.00000 withinTwo=6584 union=6584 overEight=0 uncovered=0 referenceInk=6584 patches=0)
BAND straight@fit ratio=4.0 PASS CompositedAgreement(agreement=1.00000 withinTwo=3992 union=3992 overEight=0 uncovered=0 referenceInk=3992 patches=0)
```

**Eight of nine ratios are bit-exact over a 16x sweep. The one that is not is
the reference scale itself**, by 8 pixels (0.082% of live ink) — `overEight=8`
is what fails `criterionOne`, whose `overEight == 0` clause admits no jitter
at all. The ruling's premise ("the resident arm is exact wherever nothing is
frozen") is confirmed everywhere except at the identity, which is the opposite
of where one would expect it to break, so I diagnosed it before stopping.

## Diagnosis (scratch test since deleted)

```
DIAG frame translation e=10.409090909090907 f=623.5909090909091 fracE=0.4090909090909065 fracF=0.5909090909091219
DIAG frame-shift   ratio=1.0   CompositedAgreement(agreement=0.99918 withinTwo=9784 union=9792 overEight=8 uncovered=8 referenceInk=9792 patches=0)
DIAG no-shift      ratio=1.0   CompositedAgreement(agreement=0.99918 withinTwo=9784 union=9792 overEight=8 uncovered=8 referenceInk=9792 patches=0)
DIAG frame-shift   ratio=0.999 CompositedAgreement(agreement=1.00000 withinTwo=9776 union=9776 overEight=0 uncovered=0 referenceInk=9776 patches=0)
DIAG frame-shift   ratio=1.001 CompositedAgreement(agreement=1.00000 withinTwo=9791 union=9791 overEight=0 uncovered=0 referenceInk=9791 patches=0)
DIAG rounded-shift ratio=1.0   CompositedAgreement(agreement=0.99918 withinTwo=9784 union=9792 overEight=8 uncovered=8 referenceInk=9792 patches=0)
```

Three candidate causes are eliminated: the count is **identical** with the
collection frame's fractional shift, with **no shift at all** (Plan E's
arrangement, collection camera == live camera, `collectionToLogical` the
identity), and with the shift **rounded to whole device pixels**. So it is not
`collectionFrameFor`'s translation, and rounding that translation would not
fix it. Moving the scale by one part in a thousand — 0.999 or 1.001 — makes it
vanish in both directions.

**The cause is exact pixel-boundary ties.** `crossingGrid` is axis-aligned
lines; at ratio exactly 1.0 their stroke edges land on device-pixel
boundaries, where a 1-ulp difference between the resident arm's float32
vertices (plus the offscreen-image round-trip the compositor adds and the
reference does not) and the reference's float64 direct draw flips the pixel to
the other side. Off the identity the same edges land mid-pixel, both arms
compute the same antialiased coverage, and the disagreement disappears. This
is the F13-a jitter class exactly — two exact rasterisations of one drawing —
showing up at its worst where the geometry is most axis-aligned.

**Note for the ruling:** F13-a's own bound does not cover this row.
`uncovered * 2000 < referenceInk` is 16,000 < 9,792 — false. The next round
number, `uncovered * 1000 < referenceInk` (0.1% of live ink), is 8,000 < 9,792
— true. So a single consistent jitter allowance across both files would need
to be 0.1%, not 0.05%; or `criterionOne`'s `overEight == 0` clause would need
a bounded-pixel-count form for this instrument. Both are criterion changes,
which is why I did not make either.

## The other four band tests, all green

```
BAND text-lod@fit ratio=1.0 PASS CompositedAgreement(agreement=1.00000 withinTwo=7398 union=7398 overEight=0 uncovered=0 referenceInk=7398 patches=2)
BAND text-lod@fit ratio=1.4 FAIL CompositedAgreement(agreement=0.98879 withinTwo=13315 union=13466 overEight=148 uncovered=153 referenceInk=13466 patches=2)
BAND text-nolod@fit ratio=1.4 PASS CompositedAgreement(agreement=1.00000 withinTwo=13466 union=13466 overEight=0 uncovered=0 referenceInk=13466 patches=2)
```

**The decomposition is proven.** The same corpus at the same ratio 1.4: with
the level-of-detail cull on, 153 pixels of reference ink are uncovered and
criterion 1 fails; with the cull off, the identical measurement is
`agreement=1.00000, overEight=0, uncovered=0`. Text and geometry are exact
across the band, and the frozen cull is the entire failure. That is criterion
2's text half, decomposed as F6-a asks.

The curve step is asserted in both directions (0.90128 at 1.4 and 0.93443 at
0.7, against 1.00000 at 1.0), and the 8x working-zoom test holds
`agreement >= 0.98` on a 479-pixel union — Ruling F2's float32 cost, measured
at 6 pixels.

```
BAND reported: [1.0, 1.0] = 1.00x  (curves and text-lod limit it; straight: [1.0, 1.0])
```

The reported band is **1.00x**, criterion 2's design failure as F6-a records
it. The `straight: [1.0, 1.0]` in that line is the blocking row's doing — with
it resolved the straight run reads `[0.25, 4.0]` and the parenthetical becomes
the control it was meant to be.

## Zoom defects: green

```
ZOOM-OUT tiled uncovered: gesture=[1656, 2833, 3586, 2949, 2330, 4322, 4375, 4204, 4456, 2836, 5730, 4893] settle=[4893, 0, 0, 0, 0, 0]
ZOOM-OUT resident uncovered=[0, 0, 2, 2, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0] rebuilds=1 stale=1
ZOOM-IN tiled differing over the settle: [25275, 16681, 0, 0, 0, 0]
```

`flutter test test/gpu/zoom_defect_test.dart` → **All tests passed! (4)**.
Both reproductions at the probe's exact numbers; the resident arm bounded to
<= 4 px and <= 0.05% of live ink per frame under F13-a, with `rebuilds == 1`
and `agreement >= 0.995` throughout.

## Gates

```
$ cd .../packages/jet_cad_2d_flutter && flutter test test/gpu/band_sweep_test.dart test/gpu/zoom_defect_test.dart test/gpu/text_order_test.dart test/gpu/resident_pixel_differential_test.dart
00:00 +19 -2: Some tests failed.
Failing tests:
  .../test/gpu/band_sweep_test.dart: straight geometry meets criterion 1 at every ratio of the sweep
  .../test/gpu/band_sweep_test.dart: the reported band is the intersection of the passing runs
TEST_EXIT=1
```

19 passing, 2 failing — both from the one row above (test 5 fails only because
`straight` collapses to `(1.0, 1.0)` instead of `(0.25, 4.0)`). Plan E's
`text_order_test.dart` and `resident_pixel_differential_test.dart` are among
the 19.

```
$ flutter analyze
No issues found! (ran in 0.8s)
ANALYZE_EXIT=0

$ dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.16 seconds.
FORMAT_EXIT=0

$ git status --short
 M test/support/gpu_comparison.dart
?? test/gpu/band_sweep_test.dart
?? test/gpu/zoom_defect_test.dart
?? test/support/resident_zoom_rig.dart
```

No `analysis_options.yaml`. `text_patches.dart` unmodified — the constants
stay 0.5 / 2.0 per F6-a.

## What is needed

One decision on the `straight@fit ratio=1.0` row, which is a criterion
question, not a measurement one:

1. Give `criterionOne` a bounded jitter allowance in place of
   `overEight == 0` (e.g. `overEight * 1000 < referenceInk`), applied to the
   whole sweep and named as the float32-plus-round-trip jitter of F13-a; or
2. Keep `criterionOne` literal and assert the straight corpus at the eight
   non-identity ratios, with ratio 1.0 asserted under the F13-a bound instead
   — the identity being where axis-aligned geometry ties on pixel boundaries;
   or
3. Something else.

Under 1 or 2 both red tests go green with no other change, and the commit goes
in as instructed.

---

# Fix report 2 — Ruling F13-b applied; DONE, committed

**Status: DONE.** All three gates green, everything committed as
`b4fd795`. The blocking row of fix report 1 is resolved exactly as F13-b
directs: `criterionOne` stays the spec's literal criterion 1, the straight
corpus asserts it at the eight non-identity ratios, and ratio 1.0 alone is
bounded by the tie-jitter clause.

## What changed under F13-b

`passingRun` gains `{bool Function(double ratio, CompositedAgreement m)?
passes}`, defaulting to criterion 1. Two named predicates carry the override
so test 1 and test 5 cannot drift apart:

```dart
bool straightPasses(double ratio, CompositedAgreement m) =>
    ratio == 1.0 ? straightTieJitter(m) : criterionOne(m);

bool straightTieJitter(CompositedAgreement m) =>
    m.agreement >= 0.999 && m.uncovered * 1000 < m.referenceInk;
```

Test 1 asserts `criterionOne` at the eight non-identity ratios (and
`referenceInk > 1000` at all nine), then `straightTieJitter(rows[1.0]!)`
alone at the identity, under a comment naming the cause and the three
eliminated candidates. It then asserts `passingRun(..., passes:
straightPasses) == (0.25, 4.0)`. Test 5 passes the same predicate for the
straight corpus; the other two corpora keep `criterionOne` untouched.

The measured row is unchanged and still printed as `FAIL` by `sweep`, which
prints criterion 1 verbatim — the row is on the record exactly as measured,
and only the assertion around it is qualified:

```
BAND straight@fit ratio=1.0 FAIL CompositedAgreement(agreement=0.99918 withinTwo=9784 union=9792 overEight=8 uncovered=8 referenceInk=9792 patches=0)
BAND straight@fit run=[0.25, 4.0] = 16.00x
```

8 px of 9,792: `agreement 0.99918 >= 0.999` and `8 * 1000 = 8,000 < 9,792`.

## Every printed row of the final run, verbatim

`flutter test <band_sweep> <zoom_defect> <text_order> <resident_pixel_differential>`
(absolute paths), **TEST_EXIT=0, "All tests passed!" (21)**. Rows in emission
order; tests 1-4 sweep once each and test 5 re-sweeps the three corpora it
intersects, so `straight@fit`, `text-lod@fit` and `curves@fit` each appear
twice, identically.

```
BAND straight@fit ratio=0.25 PASS CompositedAgreement(agreement=1.00000 withinTwo=2399 union=2399 overEight=0 uncovered=0 referenceInk=2399 patches=0)
BAND straight@fit ratio=0.35 PASS CompositedAgreement(agreement=1.00000 withinTwo=3392 union=3392 overEight=0 uncovered=0 referenceInk=3392 patches=0)
BAND straight@fit ratio=0.5 PASS CompositedAgreement(agreement=1.00000 withinTwo=4876 union=4876 overEight=0 uncovered=0 referenceInk=4876 patches=0)
BAND straight@fit ratio=0.7 PASS CompositedAgreement(agreement=1.00000 withinTwo=6844 union=6844 overEight=0 uncovered=0 referenceInk=6844 patches=0)
BAND straight@fit ratio=1.0 FAIL CompositedAgreement(agreement=0.99918 withinTwo=9784 union=9792 overEight=8 uncovered=8 referenceInk=9792 patches=0)
BAND straight@fit ratio=1.4 PASS CompositedAgreement(agreement=1.00000 withinTwo=10244 union=10244 overEight=0 uncovered=0 referenceInk=10244 patches=0)
BAND straight@fit ratio=2.0 PASS CompositedAgreement(agreement=1.00000 withinTwo=8270 union=8270 overEight=0 uncovered=0 referenceInk=8270 patches=0)
BAND straight@fit ratio=2.8 PASS CompositedAgreement(agreement=1.00000 withinTwo=6584 union=6584 overEight=0 uncovered=0 referenceInk=6584 patches=0)
BAND straight@fit ratio=4.0 PASS CompositedAgreement(agreement=1.00000 withinTwo=3992 union=3992 overEight=0 uncovered=0 referenceInk=3992 patches=0)
BAND straight@fit run=[0.25, 4.0] = 16.00x
BAND text-lod@fit ratio=0.25 FAIL CompositedAgreement(agreement=0.93919 withinTwo=834 union=888 overEight=45 uncovered=0 referenceInk=835 patches=2)
BAND text-lod@fit ratio=0.35 PASS CompositedAgreement(agreement=1.00000 withinTwo=1364 union=1364 overEight=0 uncovered=0 referenceInk=1364 patches=2)
BAND text-lod@fit ratio=0.5 PASS CompositedAgreement(agreement=1.00000 withinTwo=2356 union=2356 overEight=0 uncovered=0 referenceInk=2356 patches=2)
BAND text-lod@fit ratio=0.7 PASS CompositedAgreement(agreement=1.00000 withinTwo=4048 union=4048 overEight=0 uncovered=0 referenceInk=4048 patches=2)
BAND text-lod@fit ratio=1.0 PASS CompositedAgreement(agreement=1.00000 withinTwo=7398 union=7398 overEight=0 uncovered=0 referenceInk=7398 patches=2)
BAND text-lod@fit ratio=1.4 FAIL CompositedAgreement(agreement=0.98879 withinTwo=13315 union=13466 overEight=148 uncovered=153 referenceInk=13466 patches=2)
BAND text-lod@fit ratio=2.0 FAIL CompositedAgreement(agreement=0.98671 withinTwo=21600 union=21891 overEight=289 uncovered=293 referenceInk=21891 patches=2)
BAND text-lod@fit ratio=2.8 FAIL CompositedAgreement(agreement=0.97226 withinTwo=19100 union=19645 overEight=540 uncovered=545 referenceInk=19645 patches=2)
BAND text-lod@fit ratio=4.0 FAIL CompositedAgreement(agreement=0.53611 withinTwo=1247 union=2326 overEight=1071 uncovered=1081 referenceInk=2326 patches=1)
BAND text-nolod@fit ratio=1.4 PASS CompositedAgreement(agreement=1.00000 withinTwo=13466 union=13466 overEight=0 uncovered=0 referenceInk=13466 patches=2)
BAND curves@fit ratio=0.25 FAIL CompositedAgreement(agreement=0.90605 withinTwo=434 union=479 overEight=45 uncovered=23 referenceInk=457 patches=0)
BAND curves@fit ratio=0.35 FAIL CompositedAgreement(agreement=0.89680 withinTwo=617 union=688 overEight=71 uncovered=38 referenceInk=655 patches=0)
BAND curves@fit ratio=0.5 FAIL CompositedAgreement(agreement=0.92731 withinTwo=893 union=963 overEight=70 uncovered=41 referenceInk=934 patches=0)
BAND curves@fit ratio=0.7 FAIL CompositedAgreement(agreement=0.93443 withinTwo=1254 union=1342 overEight=88 uncovered=47 referenceInk=1301 patches=0)
BAND curves@fit ratio=1.0 PASS CompositedAgreement(agreement=1.00000 withinTwo=1873 union=1873 overEight=0 uncovered=0 referenceInk=1873 patches=0)
BAND curves@fit ratio=1.4 FAIL CompositedAgreement(agreement=0.90128 withinTwo=2182 union=2421 overEight=239 uncovered=115 referenceInk=2297 patches=0)
BAND curves@fit ratio=2.0 FAIL CompositedAgreement(agreement=0.84739 withinTwo=1477 union=1743 overEight=266 uncovered=140 referenceInk=1617 patches=0)
BAND curves@fit ratio=2.8 FAIL CompositedAgreement(agreement=0.82645 withinTwo=1381 union=1671 overEight=290 uncovered=137 referenceInk=1518 patches=0)
BAND curves@fit ratio=4.0 FAIL CompositedAgreement(agreement=0.80822 withinTwo=767 union=949 overEight=182 uncovered=90 referenceInk=857 patches=0)
BAND curves@fit run=[1.0, 1.0] = 1.00x
BAND curves@8x ratio=0.25 FAIL CompositedAgreement(agreement=0.89142 withinTwo=1527 union=1713 overEight=186 uncovered=90 referenceInk=1617 patches=0)
BAND curves@8x ratio=0.35 FAIL CompositedAgreement(agreement=0.92303 withinTwo=1463 union=1585 overEight=122 uncovered=55 referenceInk=1518 patches=0)
BAND curves@8x ratio=0.5 FAIL CompositedAgreement(agreement=0.96441 withinTwo=840 union=871 overEight=31 uncovered=17 referenceInk=857 patches=0)
BAND curves@8x ratio=0.7 PASS CompositedAgreement(agreement=1.00000 withinTwo=569 union=569 overEight=0 uncovered=0 referenceInk=569 patches=0)
BAND curves@8x ratio=1.0 FAIL CompositedAgreement(agreement=0.98747 withinTwo=473 union=479 overEight=6 uncovered=0 referenceInk=473 patches=0)
BAND curves@8x ratio=1.4 PASS CompositedAgreement(agreement=1.00000 withinTwo=497 union=497 overEight=0 uncovered=0 referenceInk=497 patches=0)
BAND curves@8x ratio=2.0 PASS CompositedAgreement(agreement=1.00000 withinTwo=248 union=248 overEight=0 uncovered=0 referenceInk=248 patches=0)
BAND curves@8x ratio=2.8 FAIL CompositedAgreement(agreement=1.00000 withinTwo=0 union=0 overEight=0 uncovered=0 referenceInk=0 patches=0)
BAND curves@8x ratio=4.0 FAIL CompositedAgreement(agreement=1.00000 withinTwo=0 union=0 overEight=0 uncovered=0 referenceInk=0 patches=0)
BAND straight@fit ratio=0.25 PASS CompositedAgreement(agreement=1.00000 withinTwo=2399 union=2399 overEight=0 uncovered=0 referenceInk=2399 patches=0)
BAND straight@fit ratio=0.35 PASS CompositedAgreement(agreement=1.00000 withinTwo=3392 union=3392 overEight=0 uncovered=0 referenceInk=3392 patches=0)
BAND straight@fit ratio=0.5 PASS CompositedAgreement(agreement=1.00000 withinTwo=4876 union=4876 overEight=0 uncovered=0 referenceInk=4876 patches=0)
BAND straight@fit ratio=0.7 PASS CompositedAgreement(agreement=1.00000 withinTwo=6844 union=6844 overEight=0 uncovered=0 referenceInk=6844 patches=0)
BAND straight@fit ratio=1.0 FAIL CompositedAgreement(agreement=0.99918 withinTwo=9784 union=9792 overEight=8 uncovered=8 referenceInk=9792 patches=0)
BAND straight@fit ratio=1.4 PASS CompositedAgreement(agreement=1.00000 withinTwo=10244 union=10244 overEight=0 uncovered=0 referenceInk=10244 patches=0)
BAND straight@fit ratio=2.0 PASS CompositedAgreement(agreement=1.00000 withinTwo=8270 union=8270 overEight=0 uncovered=0 referenceInk=8270 patches=0)
BAND straight@fit ratio=2.8 PASS CompositedAgreement(agreement=1.00000 withinTwo=6584 union=6584 overEight=0 uncovered=0 referenceInk=6584 patches=0)
BAND straight@fit ratio=4.0 PASS CompositedAgreement(agreement=1.00000 withinTwo=3992 union=3992 overEight=0 uncovered=0 referenceInk=3992 patches=0)
BAND straight@fit run=[0.25, 4.0] = 16.00x
BAND text-lod@fit ratio=0.25 FAIL CompositedAgreement(agreement=0.93919 withinTwo=834 union=888 overEight=45 uncovered=0 referenceInk=835 patches=2)
BAND text-lod@fit ratio=0.35 PASS CompositedAgreement(agreement=1.00000 withinTwo=1364 union=1364 overEight=0 uncovered=0 referenceInk=1364 patches=2)
BAND text-lod@fit ratio=0.5 PASS CompositedAgreement(agreement=1.00000 withinTwo=2356 union=2356 overEight=0 uncovered=0 referenceInk=2356 patches=2)
BAND text-lod@fit ratio=0.7 PASS CompositedAgreement(agreement=1.00000 withinTwo=4048 union=4048 overEight=0 uncovered=0 referenceInk=4048 patches=2)
BAND text-lod@fit ratio=1.0 PASS CompositedAgreement(agreement=1.00000 withinTwo=7398 union=7398 overEight=0 uncovered=0 referenceInk=7398 patches=2)
BAND text-lod@fit ratio=1.4 FAIL CompositedAgreement(agreement=0.98879 withinTwo=13315 union=13466 overEight=148 uncovered=153 referenceInk=13466 patches=2)
BAND text-lod@fit ratio=2.0 FAIL CompositedAgreement(agreement=0.98671 withinTwo=21600 union=21891 overEight=289 uncovered=293 referenceInk=21891 patches=2)
BAND text-lod@fit ratio=2.8 FAIL CompositedAgreement(agreement=0.97226 withinTwo=19100 union=19645 overEight=540 uncovered=545 referenceInk=19645 patches=2)
BAND text-lod@fit ratio=4.0 FAIL CompositedAgreement(agreement=0.53611 withinTwo=1247 union=2326 overEight=1071 uncovered=1081 referenceInk=2326 patches=1)
BAND text-lod@fit run=[0.35, 1.0] = 2.86x
BAND curves@fit ratio=0.25 FAIL CompositedAgreement(agreement=0.90605 withinTwo=434 union=479 overEight=45 uncovered=23 referenceInk=457 patches=0)
BAND curves@fit ratio=0.35 FAIL CompositedAgreement(agreement=0.89680 withinTwo=617 union=688 overEight=71 uncovered=38 referenceInk=655 patches=0)
BAND curves@fit ratio=0.5 FAIL CompositedAgreement(agreement=0.92731 withinTwo=893 union=963 overEight=70 uncovered=41 referenceInk=934 patches=0)
BAND curves@fit ratio=0.7 FAIL CompositedAgreement(agreement=0.93443 withinTwo=1254 union=1342 overEight=88 uncovered=47 referenceInk=1301 patches=0)
BAND curves@fit ratio=1.0 PASS CompositedAgreement(agreement=1.00000 withinTwo=1873 union=1873 overEight=0 uncovered=0 referenceInk=1873 patches=0)
BAND curves@fit ratio=1.4 FAIL CompositedAgreement(agreement=0.90128 withinTwo=2182 union=2421 overEight=239 uncovered=115 referenceInk=2297 patches=0)
BAND curves@fit ratio=2.0 FAIL CompositedAgreement(agreement=0.84739 withinTwo=1477 union=1743 overEight=266 uncovered=140 referenceInk=1617 patches=0)
BAND curves@fit ratio=2.8 FAIL CompositedAgreement(agreement=0.82645 withinTwo=1381 union=1671 overEight=290 uncovered=137 referenceInk=1518 patches=0)
BAND curves@fit ratio=4.0 FAIL CompositedAgreement(agreement=0.80822 withinTwo=767 union=949 overEight=182 uncovered=90 referenceInk=857 patches=0)
BAND curves@fit run=[1.0, 1.0] = 1.00x
BAND reported: [1.0, 1.0] = 1.00x  (curves and text-lod limit it; straight: [0.25, 4.0])
ZOOM-OUT tiled uncovered: gesture=[1656, 2833, 3586, 2949, 2330, 4322, 4375, 4204, 4456, 2836, 5730, 4893] settle=[4893, 0, 0, 0, 0, 0]
ZOOM-OUT resident uncovered=[0, 0, 2, 2, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0] rebuilds=1 stale=1
ZOOM-IN tiled differing over the settle: [25275, 16681, 0, 0, 0, 0]
ZOOM-IN tiled differing over the settle: [25275, 16681, 0, 0, 0, 0]
```

(The last line appears twice: the tiled zoom-in test emits it, and the run's
final line is the same test's own trailing output. Both are the same
measurement.)

## The result of record

**The reported band is `[1.0, 1.0] = 1.00x`** — criterion 2's design failure,
as Ruling F6-a records it, decomposed into the two frozen watermark rows:

| corpus | frozen decision under test | run | width |
| --- | --- | --- | --- |
| `straight@fit` | none | `[0.25, 4.0]` | **16.00x** |
| `text-lod@fit` | level-of-detail cull | `[0.35, 1.0]` | 2.86x |
| `curves@fit` | chord count | `[1.0, 1.0]` | 1.00x |

The control is what makes the other two rows mean something: **where nothing
is frozen the resident arm is bit-exact over a 16x sweep** (eight ratios at
`agreement=1.00000, overEight=0, uncovered=0`; the ninth is the 8-pixel
identity tie). So neither narrow band is an artifact of the frame transform,
`expandInstances` or the compositor — each is its named frozen row and
nothing else.

The text half is proven by construction rather than inferred: the same corpus
at the same ratio 1.4 reads `uncovered=153, FAIL` with the cull on and
`agreement=1.00000, overEight=0, uncovered=0, PASS` with it off.

## Gates, verbatim, with exit codes

```
$ cd /Users/ahmeturel/Projects/oss/jet-cad/.worktrees/plan-f-rebuild-and-band/packages/jet_cad_2d_flutter && flutter test
00:08 +664 ~1: All tests passed!
FLUTTER_TEST_EXIT=0

$ flutter analyze
No issues found! (ran in 1.2s)
FLUTTER_ANALYZE_EXIT=0

$ dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.16 seconds.
DART_FORMAT_EXIT=0

$ git status --short          # before the commit
 M packages/jet_cad_2d_flutter/test/support/gpu_comparison.dart
?? packages/jet_cad_2d_flutter/test/gpu/band_sweep_test.dart
?? packages/jet_cad_2d_flutter/test/gpu/zoom_defect_test.dart
?? packages/jet_cad_2d_flutter/test/support/resident_zoom_rig.dart
```

**664 passing, 0 failing, 1 skipped.** No `analysis_options.yaml` staged or
modified.

## The commit

```
b4fd795 test(gpu): the band is measured -- a step at every frozen decision -- and both zoom defects reproduce on tiles and vanish on the resident arm
 .../test/gpu/band_sweep_test.dart                  | 299 +++++++++++++++++++++
 .../test/gpu/zoom_defect_test.dart                 | 135 ++++++++++
 .../test/support/gpu_comparison.dart               |  25 +-
 .../test/support/resident_zoom_rig.dart            |  61 +++++
 4 files changed, 516 insertions(+), 4 deletions(-)
```

Working tree clean afterwards. `lib/src/gpu/text_patches.dart` is not in the
commit: the band constants stay `0.5` / `2.0` per F6-a.

## Residual concerns

1. `curves@8x` remains a thin measurement — 248-569 ink pixels, and `union=0`
   at ratios 2.8 and 4.0 where the drawing is off screen. Test 4 asserts only
   the float32 precision claim it can carry (`agreement >= 0.98` on a
   479-pixel union) and prints the rest; nothing quotes a band from it. If
   Ruling F2's precision is to be gated harder later, that corpus needs a
   camera that keeps the drawing in view across the sweep.
2. The identity tie-jitter clause is corpus-specific by design (`straightPasses`
   applies it to the straight sweep only). If another axis-aligned corpus is
   added to this file it will hit the same 1.0 tie, and the predicate should
   be reused rather than the row re-diagnosed.

---

# Fix report 3 — review round 1 of 5; DONE, committed `ed94773`

All four items taken. One Important, three minors, no behaviour change to any
assertion — the Important and minor 2 correct claims that overstated what the
rows say; minors 1 and 3 put the measurement on the record.

## Important — the M-F5 note carries its measured number

`test/gpu/zoom_defect_test.dart`. The note asserted a magnitude nothing had
measured ("in the thousands of pixels"). The only run of that mutation is
fix report 1 §3(a), which read **418**. Replaced with the measured number,
the arrangement it was measured under, and the second observable the mutation
changes:

```dart
// MUTATION (M-F5): collect under the live camera and kTileViewport ->
// the first zoom-out step reveals uncovered ink at the viewport's rim
// -- 418 pixels on the first zoom-out step when measured, against <= 4
// here -- and `rebuilds` reads 0 because the ratio is 1.0 every frame.
```

The `rebuilds` half matters as much as the pixel count: under the mutation the
collection camera IS the live camera every frame, so the ratio never leaves
the band and `expect(rig.rebuilds, 1)` goes red independently of the pixel
bounds. The note now names both of the test's own assertions that the mutation
trips.

## Minor 1 — test 1's name says what it measures

`'straight geometry meets criterion 1 at every ratio of the sweep'` ->
`'straight geometry meets criterion 1 at every ratio but the identity, where
two exact rasterisations tie'`. The old name contradicted the test's own
ratio-1.0 branch; a reader hitting the F13-b comment had to reconcile it
against the title first.

## Minor 2 — the text comment says what the rows say

`band_sweep_test.dart`. "text and geometry are pixel-exact across the band"
was wrong in the direction that matters: 1.4 and 2.0 are inside the
constants' band (0.5-2.0) and they FAIL. Replaced with:

```
// The decomposition, and the whole of criterion 2's text half: text and
// geometry are pixel-exact wherever the frozen cull does not fire -- inside
// [0.35, 1.0] on this corpus; 1.4 and 2.0 sit inside the constants' band
// and FAIL, which is the criterion-2 finding.
```

## Minor 3 — the `* 2000` gate's denominator is on the record

The resident zoom-out printed `uncovered` counts but never `referenceInk`, so
the fraction the gate tests could not be checked from the transcript. The
first gesture frame's full `CompositedAgreement` now prints beside the list
(`CompositedAgreement? first; first ??= m;`), and
`test/support/gpu_comparison.dart` is imported for the type.

## The covering runs, verbatim

`flutter test <band_sweep_test.dart> <zoom_defect_test.dart>` (absolute
paths) — **TEST_EXIT=0, "All tests passed!" (9)**.

New and changed lines:

```
ZOOM-OUT resident uncovered=[0, 0, 2, 2, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0] rebuilds=1 stale=1
ZOOM-OUT resident frame 0: CompositedAgreement(agreement=1.00000 withinTwo=20410 union=20410 overEight=0 uncovered=0 referenceInk=20410 patches=0)
```

**`referenceInk=20410`.** The gate is `uncovered * 2000 < referenceInk`, so at
this corpus and viewport it admits at most 10 pixels by the fraction and 4 by
the absolute clause — the absolute clause binds, as intended — and the
measured worst frame is 2. The margin is now readable off the transcript
rather than taken on trust.

The test-1 rename shows in the runner:

```
band_sweep_test.dart: straight geometry meets criterion 1 at every ratio but the identity, where two exact rasterisations tie
```

Unchanged, and re-confirmed in the same run:

```
BAND straight@fit run=[0.25, 4.0] = 16.00x
BAND text-lod@fit run=[0.35, 1.0] = 2.86x
BAND curves@fit run=[1.0, 1.0] = 1.00x
BAND text-nolod@fit ratio=1.4 PASS CompositedAgreement(agreement=1.00000 withinTwo=13466 union=13466 overEight=0 uncovered=0 referenceInk=13466 patches=2)
BAND reported: [1.0, 1.0] = 1.00x  (curves and text-lod limit it; straight: [0.25, 4.0])
ZOOM-OUT tiled uncovered: gesture=[1656, 2833, 3586, 2949, 2330, 4322, 4375, 4204, 4456, 2836, 5730, 4893] settle=[4893, 0, 0, 0, 0, 0]
ZOOM-IN tiled differing over the settle: [25275, 16681, 0, 0, 0, 0]
```

Every measured number is identical to `b4fd795`; this round changed comments,
one test name and one print.

## Gates, verbatim, with exit codes

```
$ cd /Users/ahmeturel/Projects/oss/jet-cad/.worktrees/plan-f-rebuild-and-band/packages/jet_cad_2d_flutter && flutter test
00:10 +664 ~1: All tests passed!
FLUTTER_TEST_EXIT=0

$ flutter analyze
No issues found! (ran in 1.2s)
FLUTTER_ANALYZE_EXIT=0

$ dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.16 seconds.
DART_FORMAT_EXIT=0

$ git status --short          # before the commit
 M packages/jet_cad_2d_flutter/test/gpu/band_sweep_test.dart
 M packages/jet_cad_2d_flutter/test/gpu/zoom_defect_test.dart
```

664 passing, 0 failing, 1 skipped. No `analysis_options.yaml`. Working tree
clean after the commit.

## The commit

```
ed94773 test(gpu): the M-F5 note carries its measured number; the band comments say what the rows say
 packages/jet_cad_2d_flutter/test/gpu/band_sweep_test.dart  | 10 ++++++----
 packages/jet_cad_2d_flutter/test/gpu/zoom_defect_test.dart | 11 ++++++++---
 2 files changed, 14 insertions(+), 7 deletions(-)
```
