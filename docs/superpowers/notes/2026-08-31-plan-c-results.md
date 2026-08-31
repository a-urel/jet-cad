# Plan C — dashes in the shader: results

**Plan:** [2026-08-31-gpu-backend-plan-c-shaded-dashes.md](../plans/2026-08-31-gpu-backend-plan-c-shaded-dashes.md).
**Spec:** [2026-08-29-gpu-resident-render-backend-design.md](../specs/2026-08-29-gpu-resident-render-backend-design.md)
(revision 4), section *"Dashes are shaded, with the conversion the painter
actually uses"*.
**Mutation log:** [plan-c-mutation-log.md](plan-c-mutation-log.md).
**Branch:** `plan-c/shaded-dashes`, cut from `main` at `d52d2a9`.

---

## The headline: the plan's own premise was wrong, and the measurement says so

Plan C's "What is wrong today" section says a buffer with dash spans baked in
at collection time *"still shows eight dashes at 4x zoom instead of the
thirty-two the reference draws, each four times too long."*

**That is false. The reference draws eight too.**

`DraftPainter._dashScale` is `style.linetypeScale x
header.globalLinetypeScale x toScreen.scaleMagnitude`
(`draft_painter.dart:651-654`), and the points it hands `Dasher` are already
in screen space. So the period and the distance along the entity **both**
scale with the camera, and their quotient — the number of dashes — does not
move. **Dash patterns are anchored in world space, not screen space.**
Zooming in makes each dash longer on screen and leaves their number alone.

Measured three independent ways:

1. `Dasher.dashPolyline` on one segment with points and rate both scaled by
   `k`: **5 spans at every one of k = 1, 2, 4, 8.**
2. The algebra above.
3. A `DraftPainter` probe at four cameras: `dashSpans` reads 80 / 80 / 37 /
   22, and the fall is entirely **viewport culling** — fewer entities in view
   — not a per-entity change.

### What actually was frozen, and what this plan therefore delivers

The same probe reads `collapsed = 1, 1, 0, 0` across those four cameras.
**`kDashCollapsePx` is a screen-space threshold**, so whether a pattern draws
solid is a live, camera-dependent decision — and a buffer that made it once
at collection time drew dashes where the reference had collapsed to solid, or
the reverse. **That is the defect Plan C removes**, and it now has its own
gate:

```
PLAN-C collapse: period=66.32752990722656 collapsedRuns=1 openRuns=6
```

One buffer: below the threshold it draws a single solid run, which is what
the reference draws when `dashPolyline` returns false; above it, six dashes.

The plan's second claimed benefit **does** hold: shading removes the
span-per-dash instance blowup, since a dashed primitive now costs *D*
instances (its pattern's drawn-element count) rather than one per dash.

**This correction is the most important line in this note.** A reader who
believes the original sentence will look for the wrong defect in the window.

---

## What was measured in `flutter test`

| quantity | value |
|---|---|
| straight-geometry pixel differential, resident vs `VerticesDrawSink` | **differing = 0** (referenceInk 2232, residentInk 2232) |
| control, fragment dash test disabled | differing = **433**, exactly the 433-pixel gap the dash test cuts |
| four-scale dash count, resident, one buffer | **6, 6, 6, 6** at ratios 0.5, 1, 2, 4 |
| four-scale dash count, engine `Dasher` | **5, 5, 5, 5** — invariant, see below |
| collapse, live | 1 solid run below `kDashCollapsePx`, 6 above |
| dashed circle 911 | 621 / 3758 differing = **16.5%** |
| dashed arc 912 | 365 / 2153 differing = **17.0%** |
| record differential, polyline corpus | 12 instances, exact match to the declarative oracle |
| mutations | **14 fired, 13 killed, 1 survivor** (M-C11, pre-declared) |

### Criterion 1, split by what the measurement supports

**On straight geometry the resident arm is pixel-EXACT** — not "within 1%",
but zero differing pixels. For a segment the dash coordinate is a
collection-space length ratio and the fragment test is a half-open compare on
`fract(t)`; there is no approximation anywhere in the chain, so a budget
would have accepted a real defect.

**On curves it is not, and the plan expected otherwise. That is a MISS
against criterion 1 as written, recorded as one.** Plan C's Ruling C4
anticipated a divergence that grows as `0.25 x ratio` with the sagitta and
said the ratio-1.0 reading "must be at the criterion-1 level". It is not, and
the cause is not the sagitta: **the reference emits every dash span as its
own `arc()` op and re-chords each one independently**
(`vertices_draw_sink.dart`), so its chord vertices sit in different places
from the resident arm's, which chords the whole sweep once. Different
vertices at the same camera — a divergence that does not vanish at ratio 1.0
and never could. Reproducing it means choosing chord counts per span from a
span set that exists only at one camera, i.e. baking exactly what this plan
unbakes. Recorded, gated only by a loose 25% tripwire that says in its own
`reason` that it is a tripwire and not a criterion.

### The four-scale counts differ by one, and why that is the probe

The resident arm reads 6 where `Dasher` cuts 5, consistently, at every ratio.
**The authority on whether the arms agree is the pixel differential —
`differing == 0` on exactly this geometry, identical ink pixel for pixel.** A
count taken by walking a centreline and a count of spans `Dasher` emits treat
a segment's last, clipped element differently, and reconciling them means
re-implementing the clip. Bounded at `<= 1` in the test and recorded here
rather than tuned away.

---

## The device run

macOS, `--profile`, 10,000 entities, `DASHED=0.35`, viewport 1400x900, 30
frames, **three interleaved repeats**. Raw log archived beside this note at
[2026-08-31-plan-c-device-run.log](2026-08-31-plan-c-device-run.log).

> **macOS Low Power Mode was ON for this run** (`pmset -g` reports
> `lowpowermode 1`), and it could not be turned off from this session. **Every
> timing below is contaminated.** This project requires that statement on any
> device note -- Plan 3b's entire results note is compromised for lacking it,
> and the contamination was later measured at roughly 24% on raster and build.
> The direction matters for how to read the gesture rows: contamination
> *inflates* times, so arm C clearing its budgets **under** contamination is
> the stronger reading, not the weaker one. It does not rescue the rebuild
> row, which misses anyway.

### Buffer and instance count — the clearest win in the plan

```
GSPIKE collect+upload: walk 9.5 ms, total 115.0 ms,
                       instances=105076, buffer=6.41 MB, skippedOps=0
```

| quantity | Plan B | Plan C | |
|---|---|---|---|
| instances | 109,068 | **105,076** | **down 3,992** |
| floats per instance | 12 | 16 | +33% |
| buffer | 4.99 MB | **6.41 MB** | **PASS** against 8 MB |
| `skippedOps` | fills, text | **0** | this corpus has neither |

`105,076 x 16 x 4 = 6,724,864` bytes = 6.41 MB, exact.

**The instance count went DOWN while the record got 33% wider**, which is
Ruling C2's claim measured: a dashed primitive costs *D* instances -- its
pattern's drawn-element count -- instead of one instance per dash. On a
corpus that is 35% dashed, that saving outweighs four extra floats on every
record. The buffer still grew, because the widening applies to all 105,076
records and the saving only to the dashed ones.

### Gesture frames — all three criteria PASS

Median of three interleaved per-repeat p50s, the project's stated
aggregation rule.

| phase | build p50 | raster p50 | raster p95 |
|---|---|---|---|
| hold | 0.18 | 0.70 | 1.24 |
| pan | 0.43 | 0.57 | 0.86 |
| zoom | 0.17 | 0.18 | 0.36 |
| **budget** | **<= 1.2** | **<= 2.0** | **<= 3.0** |

**Every row passes, with `discard` live in the fragment shader.** The spec's
budget discussion named the shaded-dash `discard` as a consumer of the raster
margin, since it defeats early-Z; on this corpus it did not consume enough to
matter. Antialiasing has still not landed (Plan B's Ruling B3), which the
same discussion named as the other consumer -- so the margin here is not
evidence that both would fit.

`gpu submits=0 of 30` on every hold phase, `30 of 30` on every pan and zoom.
That is the arm working: a frame whose camera did not change re-renders
nothing.

### Rebuild — MISS, and the same miss Plan B recorded

`total 115.0 ms` against the spec's **16.67 ms** budget. Plan B measured
79.6 ms and named cold pipeline creation as a hypothesis it could not test,
because only one rebuild happened in that session. **The same is true here:
one rebuild, no warm figure, so the cause remains a hypothesis and the
criterion is scored as a MISS, not excused.** The walk itself reads 9.5 ms
against Plan B's 5.7 ms and Plan A's 14.7 ms on a nominally comparable
corpus; the three figures have never been reconciled and this run does not
reconcile them either.

---

## A defect this plan found in `packages/jet_cad_2d` and did NOT fix

**Saving and loading a drawing silently resets `globalLinetypeScale` to 1.0,
so every dashed entity in it changes its dash length.**

`DraftDocumentCodec.encode` writes the field, and `DocumentHeader.fromJson`
parses it back correctly. Then `json_codec.dart`'s `_loadHeader` copies only
`units`, `scale`, `importedExtents` and `customVariables` onto the target
document — a one-line omission two lines below the `fromJson` call that read
the value.

```
encoded header: {units: unitless, scale: 1.0, globalLinetypeScale: 1.7,
                 importedExtents: null, customVariables: {}}
decoded globalLinetypeScale: 1.0
```

Nothing caught it before because **no save/load test in the engine's own
suite ever set the field to anything but 1.0** — the degenerate fixture, in
the suite whose own project doc names that as the dominant failure mode.

`packages/jet_cad_2d` is untouched by this plan, so it is recorded rather
than repaired. `dash_differential_test.dart` **pins** it: the test asserts
the decoded value is 1.0, restores 1.7 by hand, and its `reason` tells
whoever fixes `_loadHeader` that the expectation going red means deleting the
hand-restore.

---

## Instrument defects found in this plan's own gates

1. **A run counter read 92 runs where the truth was 5.** It sampled a single
   rounded pixel along a one-to-two-pixel-wide stroke, so the sample drifted
   off the quad and back — speckle counted as dashes. Fixed with a 3x3
   neighbourhood.
2. **The 3x3 probe then read 6 where a segment has 5**, at every ratio,
   because the segment shares its endpoints with its neighbours and a 3x3
   window there reaches into the adjacent segment's ink. Fixed by trimming
   four device pixels off each end.
3. **The corpus contained no solid multi-segment run at all**, so Ruling C3's
   "a dashed run emits no joins" was indistinguishable from "this collector
   never emits joins". Found by the record differential's own vacuity check,
   not by review; entity 917 is the control it was missing.
4. **The `writePoint` dash-zeroing test allocated a zero buffer and asserted
   zeros** — it was testing `Float32List`'s initialisation, not the writer.
5. **A claim was reasoned and committed as fact.** Task 9's comment said the
   `w0<->w1` transposition was unkillable by its test; a reviewer computed
   the barycentrics at the test's own sample point and showed it dies. The
   equidistance identity behind the claim was true; it only defeats a window
   *symmetric* around `tb`, and the shipped window is anchored at it. Fired,
   corrected, and the original reasoning kept and marked superseded.

---

## What was NOT measured

- **No human has looked at the running window.** See the exit gate below.
- No web run (Plan G), no fills (Plan D), no text (Plan E).
- **No per-channel colour comparison.** `TriangleRasterizer.inked` is
  boolean; colour is gated at the record level instead, and this plan did not
  change that.
- **The instrument's standing structural blind spot**: geometry added inside
  a footprint already inked by something else moves no pixel — proven in Plan
  B by M-B7 and M-B15 reading identically. A dash *gap* removes ink and is
  visible; a fragment wrongly *kept* inside another primitive's footprint is
  not.
- **The record-level oracle covers polyline ops only.** Deriving a curve's
  expected instances means knowing the chord count, and the only way to know
  it is to reimplement `_flattenSteps` — transcription, the failure the
  oracle exists to avoid. It throws on a `CircleOp` so the scope cannot widen
  silently. Curves are covered by the collector's own arc tests and by the
  pixel differential.
- **Gates that still run only on `differentialFixture`** and therefore see no
  dashes at all, per Ruling C5's stated cost: `differential_test.dart`,
  `vertices_differential_test.dart`, `draft_canvas_test.dart`,
  `large_coordinate_test.dart`, `tile_invalidation_test.dart`.

---

## Exit gate — 10 of 11

Pre-committed in the plan. **A miss is recorded as a miss with its number. No
threshold was moved.**

| # | criterion | verdict |
|---|---|---|
| 1 | pixel differential, resident vs `VerticesDrawSink` | **SPLIT — PASS on straight geometry in its strongest form (`differing == 0`), MISS on curves (16.5% / 17.0%)** |
| 2 | the gate can fail: control exceeds its budget by > 4x | **PASS** — control differs by exactly the 433-pixel gap |
| 3 | the dash count follows the camera at ratios 0.5/1/2/4 | **PASS, with the premise corrected** — the count is *invariant* on both arms, and the resident arm reads 6,6,6,6 from one buffer |
| 4 | `t` is scale-free across device scales | **PASS** |
| 5 | emission order survives undo, redo, save, load, purge | **PASS**, with a `packages/jet_cad_2d` codec defect pinned (below) |
| 6 | collapse is live and single | **PASS** — 1 solid run below the threshold, 6 above; exactly one representative per primitive |
| 7 | Ruling C3 in pixels: dashed corner and dashed circle notched, solid circle not | **PASS** at the record level; the pixel half is inside criterion 1's curve miss |
| 8 | resident geometry <= 8 MB | **PASS — 6.41 MB**, instances 105,076 (down from 109,068) |
| 9 | gesture p50 <= 1.2 build / <= 2.0 raster, p95 raster <= 3.0 | **PASS** — 0.43 / 0.57 / 0.86 worst medians, `discard` live, under Low Power Mode contamination |
| 10 | >= 10 of 14 mutations red, survivors declared | **PASS — 14 fired, 13 killed**, one survivor pre-declared |
| 11 | a human has looked at the running window | **UNMET** |

### Criterion 11 is UNMET, in those words

The device run happened and produced every number above. **No human has
looked at what it drew.** Plan 3h's session made looking at the window this
project's third instrument, alongside mutation and differential testing, and
it was the only one of the three that caught any of that session's four
defects. A passing gate on the other ten criteria is not evidence for this
one.

**Plan B's criterion 11 is also still owed** and has been since its merge at
`72b162d`.

Command:

```sh
cd apps/dev_harness_2d
flutter run -d macos --profile --dart-define=RUN_GPU_SPIKE=true \
  --dart-define=ENTITIES=10000 --dart-define=DASHED=0.35 \
  --dart-define=SPIKE_DEFS=20 --dart-define=SPIKE_INSTANCES=150 \
  --dart-define=SPIKE_FRAMES=30 --dart-define=SPIKE_REPEATS=3
```

**What to look for, Plan C's five:**

1. **Zoom in two stops.** The dashes must get *longer*, and there must be the
   same number of them. **This is the opposite of what the plan originally
   said to look for** — see the premise correction at the top of this note.
2. **Zoom out until the dashes disappear into solid.** That is the collapse
   branch, and it must happen at the same zoom on arm C as on arm A. Flip
   between the arms and watch the transition, not the endpoints.
3. **A dashed corner must be notched, not filled.** Ruling C3: the reference
   leaves it open, and a filled corner means the join suppression was lost.
4. **A dashed circle must be notched at its start angle** — the opposite of
   the solid circle's requirement. The pair is the check.
5. **Pan slowly along a long dashed line.** The dashes must move *with* the
   line. A pattern that slides along its own line under a pan means the phase
   is anchored to the screen rather than to the geometry.

**Plan B's four, still owed:** corners filled, a circle **not** notched at its
start angle, a square dot, nothing thickening as you zoom.
