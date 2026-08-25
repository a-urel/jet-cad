# Plan 3h — the pan frame's fallback walk

**Date:** 2026-08-25. **Base:** `main` at `dfeb240`. **Revised** the same day
after three reviews; §8 records what was removed and why.

**Goal.** Make a panning frame at 500,000 entities clear its 16.67 ms budget
**repeatably** — every run of a three-run set, not a median that straddles it.

**Inherited from Plan 3g:** criterion 11 missed by 2.1x and its remedy was
recorded as spent. **That diagnosis is superseded by a measurement**, and this
spec argues from the measurement.

**Prior art this spec depends on:**

- [2026-08-25-fallback-walk-width-spike.md](../notes/2026-08-25-fallback-walk-width-spike.md)
  — the fallback walked the whole viewport; narrowing it is 2.6x.
- [2026-08-25-vertex-buffer-high-water.md](../notes/2026-08-25-vertex-buffer-high-water.md)
  — the vertex buffer is 192.00 MiB in every configuration and tiles do not
  change it.
- [2026-08-24-plan-3g-results.md](../notes/2026-08-24-plan-3g-results.md) — the
  tile cache this plan modifies, and gaps G1-G5.

### Scope, including one renumbering a reader of Plan 3g will not expect

This plan is **the narrowing and its instrument, and nothing else.**

**Plan 3g assigned G3 — zoom — to this plan** ("G3 — zoom stays where it is.
OPEN. It is Plan 3h"). **It moves to 3i.** The high-water measurement is what
licenses the split: memory turned out not to be a consequence of the pan frame,
so the pan frame can be finished without settling zoom or level-of-detail
geometry. Out of scope, each its own plan: **G3 / zoom and LOD (3i)**, and
**the 192 MiB vertex buffer (3j)**.

**`packages/jet_cad_2d` is not touched by this plan.**

Throughout, a criterion or mutant belonging to an earlier plan is written
**"Plan 3g's criterion 11"**, never bare — the two numbering spaces overlap.

---

## 1. What Plan 3g got wrong, and how

Plan 3g recorded:

> The cause is not the bake — a bake walk is 5.7-6.4 ms per tile, and the
> frame's ~32 ms of excess is the **live fallback drawing the still-uncovered
> strip**. The spec's own prescribed remedy is spent: it said the answer was a
> smaller bake budget, and the budget is already one tile.

The attribution is correct. The conclusion is not, because **the fallback was
never drawing a strip**. `TileCache.paintFrame` clips to the uncovered union
and hands `DraftPainter` the **whole viewport** (`tile_cache.dart:779-783`),
and the painter derives its index query from exactly that
(`draft_painter.dart:338`). Every fallback tessellates the entire frame and the
clip discards most of it.

The comment above the call names the right unit and the code below it uses
another: "One walk for the union, not one per tile" is a sound argument against
48 painter invocations, and the walk is over the viewport.

**Measured, 500,000 entities, `TILES=on`, one machine, one day:**

| `tile pan` p95 | clean | narrowed, unclamped | narrowed + clamped |
|---|---|---|---|
| `build` | 32.50 ms | 22.12 ms | **14.65 ms** |
| `raster` | 10.34 ms | 5.91 ms | **2.42 ms** |
| **`total`** | **43.13 ms** | 30.83 ms | **16.66 ms** |
| vertex buffer | 192.00 MiB | **384.00 MiB** | 192.00 MiB |

Every run reports `bakes=14 liveDraws=10 blits=1582 bakeFrames=14/120` — the
work composition is identical and only its cost moves. **What was removed is
waste, not work.**

Clamped arm, three runs: 16.66 / 15.26 / 17.40, median **16.66**, against a
16.67 ms threshold. **That reaches the threshold; it does not pass it**, and
one run of three lands over. Criterion 3 is written against exactly that.

---

## 2. Decisions

**D1. The narrowing lands.** 2.6x on the criterion this plan exists to fix.

**D2. It is padded by `kTileSlack`, and the existing clip stays.** A stroke
whose centreline is outside the strip still inks pixels inside it; `_bake` pads
for this reason and F1 is what an unpadded query cost in Plan 3g.

**The `clipRect(uncovered)` at `tile_cache.dart:783` is not removed**, and this
is stated because it is invisible to every gate below. `_bake` states the rule
for itself at `:1404` — "The query is padded; the clip is not." Drop the clip
and the pad becomes overdraw onto tiles already blitted: **criterion 2 still
reads zero**, because the overdrawn geometry is the same geometry at the same
camera, and the near-axis arm would charge the difference to H3's bound. It
would cost exactly the milliseconds this plan exists to save, silently.

**D3. The strip is then clamped to the viewport.** Padding a union that already
spans the frame asks for 464 x 364 logical pixels where the untiled path asks
for 400 x 300. Measured: the vertex buffer doubled to 384.00 MiB on a run whose
every other counter matched. **The pad belongs on interior edges; on the
viewport's own edge the full-frame walk is the ceiling.**

**D4. The strip computation is a pure function, `stripFor(uncovered, viewport)`.**
This splits the narrowing's gatable half from its ungatable half: D3 becomes a
unit assertion instead of a device observation.

**D5. Nothing lands before an instrument that can see a wrong narrowing.**
See §3. This is the plan's ordering constraint, not a preference.

**D6. The instrument asserts zero on an axis-aligned arm and a bounded
disagreement on a near-axis arm.** The strip's `canvas.translate` is applied in
Skia's `Float32` device space while the camera's offset is applied in `Float64`
before the sink's `Float32` store — the same asymmetry that produced Plan 3g's
gap G5. Asserting bit-equality on every slope would rediscover G5 and
misattribute it to the narrowing.

**D7. The instrument is controlled by a named mutant, not a production knob.**
`TileCache` already carries two mutable fields documented as test-only
(`:319`, `:333` — by convention, not by `@visibleForTesting`) and the
implementer's bar was that a third should trigger revisiting the design. A
"cripple the query" knob would be that third.

**D8. The pan speed becomes a rig define, `PAN_STEP`,** with four properties
that are each a defect if omitted:

- **A magnitude in logical pixels per frame, not a component.** The rig's step
  is `Offset(-7, -3)`, magnitude 7.616. `PAN_STEP` scales that vector:
  `Offset(-7, -3) * (PAN_STEP / sqrt(58))`. **The direction is preserved**, so
  every arm meets the tile lattice at the angle every prior number was taken
  at; an axis-aligned fast pan would measure a different interaction.
- **It applies to the tile phase only** (`measurement_rig.dart:523`), **not to
  R2's own pan** (`:357`). Taking both would make every prior plan's R2 row
  incomparable.
- **A throwing parse.** `bool.fromEnvironment('TEXT')` cost Plan 3c a full
  device run and `TILE_PX=1024` silently disabled tiling in Plan 3g. `main.dart`
  already has `_intDefine` for this (`:179`); **this needs its `double`
  sibling**, since a magnitude is not an integer.
- **The resolved offset and magnitude are printed** in the transcript, so a run
  is readable without the command line that produced it.

**D9. Every mutant is named with the layer it dies in.** Plan 3g's most
expensive error was firing its M7 on device only and reasoning that the widget
suite passed "by construction"; it does not, and four of Plan 3g's criterion-5
tests catch it.

---

## 3. The correctness instrument

**Nothing in the suite today can distinguish a correct narrowing from an
incorrect one.** Every pixel comparison in `tile_cache_test.dart` runs at
`tilesBakedPerFrame: 1000`, where the first frame bakes the whole visible set,
`uncovered` is null, and the live fallback **never executes under any pixel
gate**. The two restricted-budget tests that reach it assert counters.

This was established by breaking the thing a gate was supposed to catch:

| narrowing | differing pixels |
|---|---|
| padded by `kTileSlack` | 0 |
| unpadded (`pad = 0`) | 0 |
| shrunk 20 logical px inside the strip | **0** |

Three fixtures failed to produce a visible loss, and their failures share one
cause: **a loss is only visible where the uncovered union's boundary is
interior to the drawing.**

- A cold cache at a small budget makes the union very nearly the whole
  viewport, so its boundary *is* the viewport edge and nothing outside it can
  be lost.
- A pan and a zoom-then-pan both fail because `crossingGrid` spans world x
  10..200, which at `tileCamera`'s 1.4 is screen **-23..243** inside a 400 px
  viewport: the left edge is off-viewport and the right edge is interior, so
  the drawing does not fill the frame and the strip that enters lands outside
  it.

### The design

**`fillingGrid`, a new fixture.** The visible world box at `tileCamera` is
x ∈ [26.4, 312.1], y ∈ [16.4, 230.7]; the grid spans world 20..320 by 10..240,
so every edge strip is interior to the drawing. **No existing fixture fills the
viewport**, and that single fact is why all three attempts above failed.

**Each sample is an independent cache, and this is the instrument's own
anti-vacuity rule.** A sequential sweep that pans one rig across offsets
inherits tiles from the previous offset and quietly becomes a warm-tile
comparison — the same failure the three attempts above already demonstrate. So
each sample:

1. builds its own rig, covers the viewport at a large budget;
2. resets counters and drops the budget to one tile;
3. sets the **absolute** pan offset for this sample;
4. renders exactly one comparison frame;
5. **asserts `bakeCount == 1` and `liveDrawCount == 1` before its pixel report
   is accepted.**

Step 5 is what makes an M2 or M3 failure attributable to the narrowing rather
than to a fallback that never ran.

**A sweep of offsets, not one fixture.** Where the boundary falls relative to
the geometry is incidental in any single pan. The sweep steps the offset on
both axes by amounts that are not multiples of the tile size, so the boundary
never aligns with the lattice, and reports the worst case.

**Two arms, two claims.**

- **Axis-aligned** (`fillingGrid`): **exactly zero** stray, uncovered and
  differing pixels. A gate.
- **Near-axis** (`nearAxisDiagonals`, the ten-line fan): a bound, with a stated
  reference. The tiled path's existing gate for that fixture is
  `differingPixels <= 60` against a measured 36 of 10342 ink, 0.348%
  (`tile_cache_test.dart:869-875`). **The fallback arm is compared against that
  same bound**, and any increase is a tripwire requiring an explanation rather
  than a silent record. Plan 3g's worst single slope measured 2.381%.

`nearAxisDiagonals` is a fixture (`tile_fixture.dart:250`); the in-suite
sweep is a ten-line fan plus a two-slope follow-up, and the 82-slope sweep
behind H3's bound was done offline.

---

## 4. Criteria

| # | criterion | threshold | layer |
|---|---|---|---|
| 1 | the sweep reddens under a query shrunk 20 logical px | must fail | unit |
| 2 | partly baked frame equals live, axis-aligned arm, every sample | 0 stray, 0 uncovered, 0 differing | unit |
| 2b | near-axis arm | `differingPixels <= 60`, ratio < 0.01 | unit |
| 2c | every sample proved its own fallback | `bakeCount == 1`, `liveDrawCount == 1` | unit |
| 3 | `tile pan` p95 at 7.6 px/frame, **three runs of three** | **every run ≤ 16.67 ms** | device |
| 4 | `tile pan` p95 at 30 px/frame | **recorded, not a gate** | device |
| 5 | `tile pan` p95 at 60 px/frame | **recorded, not a gate** | device |
| 6 | `tile hold` p50 and p95 do not regress | p50 ≤ 2.0 ms, p95 ≤ 2.5 ms | device |
| 7 | peak tile bytes | ≤ 96 MiB | unit + device |

**Criterion 3 asks for repeatability, not margin, and that is the honest
target.** The spike read 16.66 / 15.26 / 17.40 — a median under the threshold
and one run over it. Requiring all three under is a real gate: **the current
code fails it**, at 17.40. It also cannot be met by tuning a threshold, only by
finding the remaining milliseconds.

**A 12.0 ms target was considered and dropped.** It was silently a bet on
prefetch closing 4.7 ms, and prefetch left this plan (§8). No measurement
supports 12.0 for the narrowing alone, so writing it would be a threshold
without evidence.

**Criteria 4 and 5 are recorded, not gates, and for two reasons.** No
measurement exists at those speeds, so any threshold would be invented. And
**the three arms are not distance-matched**: 120 frames at 7.6 / 30 / 60 px per
frame travel 913 / 3600 / 7200 logical pixels, so they sweep three different
stretches of corpus. This plan characterises the band for the first time; a
later plan that wants to gate it should hold distance constant by shortening
the faster arms.

**Criterion 6 gates a percentile as well as the median.** A gate on p50 alone
cannot see a cost that lands on a minority of frames — the same structural
blindness that made Plan 3g's criterion 10 unable to see its M7. Nothing in
this plan is expected to move the hold phase at all, which is exactly why a
tail gate is cheap here.

---

## 5. Mutants

| # | mutant | dies in |
|---|---|---|
| M1 | drop the clamp — strip is union + pad, unbounded | **unit**, via `stripFor` |
| M2 | drop the pad (`pad = 0`) | **unit**, the sweep |
| M3 | shrink the query 20 logical px | **unit**, the sweep (criterion 1) |
| M4 | narrow the clip but **not** the query | **device only**, criterion 3 |

**M4 is the original defect this plan fixes, and it is the one the new
instrument still cannot kill.** Its pixels are correct — only the cost moves.
Naming it with "device only" is the point of D9: after §3's work it would be
easy to believe the narrowing is fully unit-gated, and only its **arithmetic**
is.

---

## 6. Accepted gaps

**H1. Criteria 4 and 5 are unmeasured today and ungated by this plan.** Per §4.

**H2. The arms are not distance-matched.** Per §4.

**H3. G5 in the fallback strip.** The strip's translate reintroduces the
`Float32` / `Float64` asymmetry that makes a tiled frame non-bit-identical on
some slopes. Bounded on the near-axis arm against the tiled path's existing
number; not eliminated.

**H4. M4 has no unit witness.** Per §5.

---

## 7. Files

| file | change |
|---|---|
| `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart` | the narrowing, `stripFor` |
| `packages/jet_cad_2d_flutter/test/support/tile_fixture.dart` | `fillingGrid` |
| `packages/jet_cad_2d_flutter/test/support/tile_comparison.dart` | the fallback sweep |
| `packages/jet_cad_2d_flutter/test/tile_cache_test.dart` | the sweep's tests |
| `apps/dev_harness_2d/lib/measurement_rig.dart` | `PAN_STEP` at the tile phase |
| `apps/dev_harness_2d/lib/main.dart` | `_doubleDefine`, `PAN_STEP` |

`packages/jet_cad_2d` is not touched.

---

## 8. What was removed after review, and why

The first draft added **idle-ring prefetch**: a settled frame spending its idle
budget baking a one-tile ring outside the viewport. Three reviews and a check
against the rig removed it. The reasons are recorded because the idea is likely
to come back, and it should come back knowing these.

**1. Its central claim was false for this rig.** The draft said prefetch would
take `tile hold` from `bakeFrames = 0/60` to about 18/60. It would not. The
rig's warm loop pumps `panBy(Offset.zero)` until `bakeCount` stops moving
(`measurement_rig.dart:465-471`); those frames satisfy the settled predicate
exactly, so the ring would fill **there**, before the hold phase starts, and
the hold phase would bake zero as it does today. A second-order effect: the
warm loop would run ~18 extra iterations against its bound of 400, and
`warmFrames` would jump in the printout.

**2. The ring is one-shot, and nothing refills it.** Prefetch was forbidden
during a gesture, and a pan has no settled frames. At 7.6 px/frame a column
enters every ~34 frames, so across a 120-frame pan the ring covers the first of
about 3.5 column entries. **The spike already showed the narrowed fallback
absorbs a column entry in 16.66 ms**, so the ring's measurable value was close
to zero while its cost was certain: 18 MiB, and `_invalidateTouched` is
`O(|_baked| x |touched|)` (`tile_cache.dart:1084-1090`), so taking `_baked`
from 12 to 30 tiles is **2.5x on every edit**.

**3. Nothing falsified it.** The only mutant that would — ring depth 0 — was
marked device-only with no criterion bound to it. If depth 0 and depth 1 both
passed, prefetch would have shipped as unmeasured work. That is the shape the
draft's own honesty clause named and then walked into.

**4. Its settled predicate was not implementable as written.**
`quantised == _lastCamera` compares an object with itself: `paintFrame` assigns
`_lastCamera = quantised` at `:684`, before the bake loop at `:724` and the
fallback at `:783`. A correct version needs a snapshot taken before `_gridFor`
and a component-wise comparison, and `_lastCamera` must still be assigned where
it is because `_retireGeneration` reads it at `:962`.

**What a future prefetch plan needs first**, and it is a design question rather
than a tuning one: **a mechanism that refills during a gesture.** Direction-
agnostic depth-1 is a step spent rather than a step taken. The velocity-directed
variant may be the design that works, since the real constraint is not
direction but replenishment.
