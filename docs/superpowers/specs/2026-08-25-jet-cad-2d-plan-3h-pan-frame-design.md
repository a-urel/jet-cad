# Plan 3h — the pan frame

**Date:** 2026-08-25. **Base:** `main` at `dfeb240`.

**Goal.** A panning frame at 500,000 entities that clears its 16.67 ms budget
**with margin**, and holds that across a band of pan speeds rather than at the
one speed the rig happens to use.

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

**Explicitly out of scope**, each its own plan: **G3 / zoom and level-of-detail
geometry (3i)**, and **the 192 MiB vertex buffer (3j)**. The high-water note
established that memory is not a consequence of the pan frame, which is what
makes the split legitimate rather than convenient.

**`packages/jet_cad_2d` is not touched by this plan.**

---

## 1. What Plan 3g got wrong, and how

Plan 3g recorded:

> The cause is not the bake — a bake walk is 5.7-6.4 ms per tile, and the
> frame's ~32 ms of excess is the **live fallback drawing the still-uncovered
> strip**. The spec's own prescribed remedy is spent: it said the answer was a
> smaller bake budget, and the budget is already one tile.

The attribution is correct. The conclusion is not, because **the fallback was
never drawing a strip**. `TileCache.paintFrame` clipped to the uncovered union
and handed `DraftPainter` the **whole viewport**, and the painter derives its
index query from exactly that (`draft_painter.dart:338`). Every fallback
tessellated the entire frame and the clip discarded most of it.

The comment above the call names the right unit and the code below it uses
another: "One walk for the union, not one per tile" is a sound argument against
48 painter invocations, and the walk was over the viewport.

**Measured, three runs, 500,000 entities, `TILES=on`, one machine, one day:**

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
16.67 ms threshold. **That reaches the threshold; it does not pass it.** Two of
three runs land under and one lands over, which is why this plan's own target
is not 16.67.

---

## 2. Decisions

**D1. The narrowing lands, and it lands first.** 2.6x on the criterion this
plan exists to fix.

**D2. It is padded by `kTileSlack`.** A stroke whose centreline is outside the
strip still inks pixels inside it. `_bake` pads for this reason; F1 is what an
unpadded query cost in Plan 3g.

**D3. It is then clamped to the viewport.** Padding a union that already spans
the frame asks for 464 x 364 logical pixels where the untiled path asks for
400 x 300. Measured: the vertex buffer doubled to 384.00 MiB on a run whose
every other counter matched. **The pad belongs on interior edges; on the
viewport's own edge the full-frame walk is the ceiling.**

**D4. The strip computation is a pure function, `stripFor(uncovered, viewport)`.**
This splits the narrowing's gatable half from its ungatable half: D3 becomes a
unit assertion instead of a device observation.

**D5. Nothing lands before an instrument that can see a wrong narrowing.**
See §3.

**D6. The instrument asserts zero on an axis-aligned arm and a measured bound
on a near-axis arm.** The strip's `canvas.translate` is applied in Skia's
`Float32` device space while the camera's offset is applied in `Float64` before
the sink's `Float32` store — the same asymmetry that produced gap G5.
Asserting bit-equality on every slope would rediscover G5 and misattribute it
to the narrowing.

**D7. The instrument is controlled by a named mutant, not a production knob.**
`TileCache` already carries two test-only mutable knobs and the implementer's
bar was that a third should trigger revisiting the design. A "cripple the
query" knob would be that third.

**D8. Idle-ring prefetch, direction-agnostic.** A settled frame reads
`total p50 = 1.59 ms` against a 16.67 ms budget and `bakeFrames = 0/60`: it
spends a tenth of its budget and bakes nothing. Prefetch spends that idle
budget baking the ring outside the viewport, so a pan finds tiles already warm
and `uncovered` stays empty.

**D9. Direction-agnostic, not velocity-directed.** A velocity model misses on
every direction reversal and buys only tiles and memory, both of which measure
comfortable. It is the natural follow-on once D8 is measured, not part of this
plan.

**D10. Prefetch runs only on a settled frame**, defined as
`_viewportCovered && quantised == _lastCamera && baked == 0`. Never during a
gesture: prefetching inside the frame this plan exists to speed up would defeat
the plan.

**D11. One tile per settled frame.** 1.59 + 6.4 = ~8.0 ms, half the budget.
Two tiles would fit at 14.4 ms with no margin, and criterion 6 exists to
protect exactly that margin. At one tile a depth-1 ring of 18 tiles fills in
about 18 frames, roughly 300 ms.

**D12. Ring depth 1.** `visibleKeys`' rectangle grown by one tile in each
direction, minus the visible set. At the measured 4x3 visible set that is
6x5 - 12 = **18 tiles, about 18.9 MB**, against a measured 12.58 MB visible and
a 96 MiB ceiling the panning frame already takes to 27.3 MB.

**D13. Ring tiles are stamped `_lastUsedFrame` at bake time.** They are never
blitted, so an LRU keyed on blits would rank them infinitely old and evict
precisely the tiles about to be needed — prefetch cancelling itself.

**D14. Prefetch never triggers an eviction.** It is skipped unless
`liveBytes + _tileBytes` stays under **75% of `cacheBytes`**. This is the
stronger of the two eviction rules and the real protection: it removes the
state in which churn is possible instead of correcting an ordering.
**Prefetch may do useless work; it may never undo anyone else's.**

**D15. The pan speed becomes a rig define, `PAN_STEP`**, and criteria 3-5 are
read at 7.6 / 30 / 60 logical pixels per frame. A `String.fromEnvironment` that
**throws** on an unparseable value: `bool.fromEnvironment('TEXT')` cost Plan 3c
a full device run and `TILE_PX=1024` silently disabled tiling in Plan 3g.

**D16. Every mutant is named with the layer it dies in.** Plan 3g's most
expensive error was firing M7 on device only and reasoning that the widget
suite passed "by construction"; it does not, and four criterion-5 tests catch
it. A mutant table without that column reproduces the error.

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
  10..200, which at `tileCamera`'s 1.4 is screen 0..243 inside a 400 px
  viewport: the drawing does not fill the frame, so the strip that enters lands
  outside it.

### The design

**`fillingGrid`, a new fixture.** The visible world box at `tileCamera` is
x ∈ [26.4, 312.1], y ∈ [16.4, 230.7]; the grid spans world 20..320 by 10..240,
so every edge strip is interior to the drawing. **No existing fixture fills the
viewport**, and that single fact is why all three attempts above failed.

**The arrangement.** Cover the viewport at a large budget, drop the budget to
one tile, pan by more than one tile. The column that enters has an interior
boundary and ink across it.

**A camera sweep, not one fixture.** Where the boundary falls relative to the
geometry is incidental in any single pan. The sweep steps the pan offset on
both axes by amounts that are not multiples of the tile size, so the boundary
never aligns with the lattice, and reports the worst case. `nearAxisDiagonals`
is the precedent for measuring a bounded disagreement over a sweep rather than
asserting a point.

**Two arms, two claims.** Axis-aligned fixture: **exactly zero** differing
pixels, and this is a gate. Near-axis slopes: a **measured bound**, recorded,
not a gate — per D6.

---

## 4. Idle-ring prefetch

Runs only when `_viewportCovered && quantised == _lastCamera && baked == 0`.
Budget one tile (D11), ring depth 1 (D12), skipped unless the cache stays under
75% of its ceiling (D14), stamped at bake (D13).

**What comes for free, and why.** The ring is not a separate structure — it is
extra keys in the same cache:

| concern | why it is already handled |
|---|---|
| invalidation | ring tiles enter `_tiles` and `_baked` like any other, so `applyChange` and generation drops cover them |
| carry-over composite | `_compositeOf` iterates `visibleKeys` (`tile_cache.dart:980`), so the ring is excluded by construction |
| scale change | a generation is keyed by scale, so a zoom drops the ring with everything else |

**New counters:** `prefetchCount` and `ringTileCount`, which criteria 6 and 7
read.

### One consequence this plan must not discover late

**Prefetch changes what criterion 10 measures.** Today `tile hold` reads
`bakeFrames = 0/60`: the settled frame bakes nothing, so the per-tile clip that
Plan 3g's mutant M7 breaks is **never executed** in the frame criterion 10
times. That is precisely why criterion 10 was structurally blind to M7 and why
gap G7 was recorded.

With prefetch, a settled frame bakes. `bakeFrames` goes to roughly 18/60 and
criterion 10's frame begins exercising the bake path. **This is a side benefit,
not a gate** — but a threshold written without noticing it would be measuring a
different frame than the one it was calibrated against, and this plan's
criterion 6 exists partly to keep that visible.

---

## 5. Criteria

| # | criterion | threshold | layer |
|---|---|---|---|
| 1 | the sweep reddens under a query shrunk 20 logical px | must fail | unit |
| 2 | a partly baked frame equals the live frame, axis-aligned arm | 0 stray, 0 uncovered, 0 differing | unit |
| 2b | near-axis arm's disagreement | measured and recorded | unit |
| 3 | `tile pan` p95 at 7.6 px/frame | **≤ 12.0 ms** | device |
| 4 | `tile pan` p95 at 30 px/frame | ≤ 16.67 ms | device |
| 5 | `tile pan` p95 at 60 px/frame | **recorded, not a gate** | device |
| 6 | `tile hold` p50 does not regress | ≤ 2.0 ms | device |
| 7 | ring tiles are not evicted ahead of colder tiles | eviction test | unit |
| 8 | peak tile bytes | ≤ 96 MiB | unit + device |

**Criterion 3's 12.0 ms is derived, not chosen.** The spike's three runs read
16.66 / 15.26 / 17.40 — a spread of ±1.1 ms. Landing *on* 16.67 means red in
one run of three. 12.0 sits four spreads below the threshold.

**Criterion 5 is deliberately not a gate.** A depth-1 ring cannot be
speed-independent: at 256 logical pixels per tile a new column enters every ~34
frames at 7.6 px/frame and every ~4 frames at 60. One tile per settled frame
fills 18 tiles in ~18 frames. A fast pan therefore outruns the ring and falls
back to the narrowed walk. **That is graceful degradation, and writing it as a
gate would promise what the design cannot deliver.** Deepening the ring with
speed is D9's follow-on.

---

## 6. Mutants

| # | mutant | dies in |
|---|---|---|
| M1 | drop the clamp — strip is union + pad, unbounded | **unit**, via `stripFor` |
| M2 | drop the pad (`pad = 0`) | **unit**, the sweep |
| M3 | shrink the query 20 logical px | **unit**, the sweep (criterion 1) |
| M4 | prefetch during a gesture (drop the `_lastCamera` guard) | **unit**, `prefetchCount == 0` on a panning frame |
| M5 | ignore the 75% ceiling | **unit**, eviction counter |
| M6 | do not stamp ring tiles at bake | **unit**, criterion 7 |
| M7 | ring depth 0 | **device only** |

**M7's honesty clause.** Killing "the ring is empty" with `prefetchCount == 0`
restates the code — the shape that made Plan 3g's `debugBlitPaint` a tautology.
That the ring *helps* is a timing claim, and timings are device claims. D4
exists so the narrowing does not share this problem: its clamp is arithmetic
and arithmetic is unit-testable.

---

## 7. Accepted gaps

**H1. The ring depends on a settle preceding the gesture.** A user who pans
immediately after load finds it cold and falls back to the narrowed walk. The
rig's settle-then-pan sequence measures the best case and not the worst.
Measured and recorded; not gated.

**H2. Fast pan (criterion 5).** Per §5.

**H3. G5 in the fallback strip.** The strip's translate reintroduces the
`Float32` / `Float64` asymmetry that made a tiled frame non-bit-identical on
some slopes. Bounded on the near-axis arm; not eliminated.

**H4. Criterion 10's meaning shifts.** Per §4. A benefit, unmeasured by this
plan, and named so that Plan 3i does not read the new `bakeFrames` as a
regression.

---

## 8. Files

| file | change |
|---|---|
| `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart` | narrowing, `stripFor`, prefetch, two counters |
| `packages/jet_cad_2d_flutter/test/support/tile_fixture.dart` | `fillingGrid` |
| `packages/jet_cad_2d_flutter/test/support/tile_comparison.dart` | the fallback sweep |
| `packages/jet_cad_2d_flutter/test/tile_prefetch_test.dart` | new |
| `apps/dev_harness_2d/lib/measurement_rig.dart` | pan-speed sweep |
| `apps/dev_harness_2d/lib/main.dart` | `PAN_STEP` |

`packages/jet_cad_2d` is not touched.
