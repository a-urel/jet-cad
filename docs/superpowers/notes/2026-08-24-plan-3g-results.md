# Plan 3g — results of record

Written 2026-08-24, at `37918c5` — the plan's last code-changing commit — after
Tasks 1 through 12. (Task 12's own results, added three commits after this
note was first written, are docs-only: the code tree this note describes has
not moved since `37918c5`.)

- Spec: `docs/superpowers/specs/2026-08-23-jet-cad-2d-plan-3g-tile-cache-design.md`
- Plan: `docs/superpowers/plans/2026-08-23-jet-cad-2d-plan-3g-tile-cache.md`
- Mutation log: `docs/superpowers/notes/plan-3g-mutation-log.md`
- The measurement that justified the plan existing at all:
  `docs/superpowers/notes/2026-08-23-picture-cache-price-spike.md`

**Both suites are green at this commit, verified rather than assumed, and no
golden PNG moved:**

```
packages/jet_cad_2d          797 tests, All tests passed! / analyze clean / format 113 files (0 changed)
packages/jet_cad_2d_flutter  363 tests + 1 skip, All tests passed! / analyze clean / format 63 files (0 changed)
packages/jet_cad_2d_flutter  35 golden tests, All tests passed!
git diff --stat 37918c5 -- packages/jet_cad_2d_flutter/test/golden   (empty)
```

---

## The thirteen criteria

| # | criterion | verdict |
|---|---|---|
| 1 | a settled tiled frame equals the live frame, at a non-identity camera | **PASS** |
| 2 | the same, with a fixture crossing tile boundaries | **PASS**, qualified by G1 and G5 |
| 3 | the same, with a fixture carrying text | **PASS** |
| 4 | the same, with overlapping translucent strokes | **PASS** |
| 5 | a geometry edit inside one tile invalidates no other tile | **PASS** |
| 6 | a definition-owned edit drops the generation, and nothing less does | **PASS** |
| 7 | a table mutation drops the generation | **PASS** |
| 8 | a scale change drops the generation; a pan drops nothing | **PASS** |
| 9 | all five `DocChange` arms, none omitted | **PASS** |
| 10 | 500,000-entity settled frame from `totalSpan` ≤ 4.00 ms | **PASS** — 1.58 ms |
| 11 | a pan frame baking a newly exposed strip ≤ 16.67 ms | **MISS** — 35.67 ms, 2.1× over |
| 12 | peak live cache bytes under `kTileCacheBytes = 96 MiB` | **PASS** |
| 13 | frame-path allocation: nothing per entity, viewport-bounded per frame | **PASS** |

**Eleven of thirteen.** Criterion 11 is the miss, it is named rather than tuned
away, and its cause is isolated below. And one criterion passing is not the same
as one criterion gating: **criterion 10 passes and is structurally blind to M7**
— see G7, which is the largest gap in this plan.

### Criterion 10 — PASS at 1.58 ms, a 26× reduction

**The machine was verified first.** `lowpowermode 0` on AC power, checked
immediately before the control and before each of the five measurement runs —
six checks, all reading identically, each printed as the first lines of its own
command. The charger never came out.

**The control reproduced Plan 3d's clean `50,000 / vertices` row**, with
`tiles=off` on the control arm so it is provably untiled:

```
flutter: R2 (50000) frames=242
flutter:   build  p50=7.26ms p95=8.57ms max=313.67ms mean=8.61ms
flutter:   raster p50=8.56ms p95=18.83ms max=114.72ms mean=9.35ms
flutter:   total  p50=15.13ms p95=31.45ms max=436.54ms mean=20.34ms
flutter:   tiles=off
flutter:   backend=vertices triangles=217758 drawVerticesCalls=20
```

build p50 **7.26** inside `[7.06, 7.38]`; raster p50 **8.56** inside
`[8.22, 8.63]`. Everything below stands on that.

Shipped constants confirmed by the rig's own line in every transcript:
`tiles=on tilePx=512 bakeBudgetPx=262144 bakeBudgetTiles=1`.

Criterion 10 is the `tile hold` phase — 60 frames at a fixed camera against a
warm generation, `bakeFrames=0/60`, so the frame is blits and nothing else.

| `totalSpan` | run 1 | run 2 | run 3 | **median** |
|---|---|---|---|---|
| p50 | 1.64 | 1.58 | 0.91 | **1.58 ms** |
| p95 | 2.40 | 1.85 | 1.96 | **1.96 ms** |
| max | 30.77 | 1.93 | 33.44 | 30.77 ms |

**PASS: 1.58 ms median against a ≤ 4.00 ms threshold**, and **26×** below the
same runs' untiled 500,000-entity `totalSpan` of 41.09 ms.

**The `max` column is a bucket-boundary artefact, recorded rather than dropped.**
The two runs showing it (30.77, 33.44) are exactly the two whose hold phase
reports `frames=59` for 60 pumped frames: a `FrameTiming` is delivered after its
frame rasterised, so the phase's own last frame landed in the next bucket and a
frame from before the swap landed in this one. It cannot be a hold frame — the
phase reports `bakeFrames=0/60`, `liveDraws=0` and 720 blits for 60 frames, and
no frame that only blits twelve tiles costs 30 ms when the same phase's p95 is
1.96. **Its most likely origin is the settle that precedes the phase**, which
matters below.

### Criterion 11 — MISS by 2.1×. The threshold was not moved.

Criterion 11 is the `tile pan` phase. Only **14 of 120** frames bake, so the
phase's p50 is a pure-blit frame and the criterion — *"a pan frame that is
baking a newly exposed strip"* — is read from p95 (rank 114 of 120 sits inside
the top 14), with `max` beside it.

| `totalSpan` | run 1 | run 2 | run 3 | **median** |
|---|---|---|---|---|
| p95 (a baking frame) | 37.38 | 35.67 | 35.00 | **35.67 ms** |
| max | 65.77 | 66.86 | 65.22 | **65.77 ms** |
| mean | 4.96 | 5.08 | 5.20 | 5.08 ms |
| p50 (a pure-blit frame) | 0.83 | 1.29 | 1.48 | 1.29 ms |

**MISS: 35.67 ms median against a 16.67 ms threshold — 2.1× over at p95, 3.9×
at `max`.** Reproduced in all three runs, spread 35.00–37.38, so it is not
noise. **The threshold does not move and this note does not soften the miss.**
This repository records misses rather than tuning them away: Plan 3f shipped 11
of 13 and Plan 3f.1 shipped 16 of 17, both with the misses named.

#### And the cause is not the bake

This is the part that changes what the miss means. By the rig's own differencing
identity `mean = blit + bakesPerFrame × bakeFrameCost`, run 2 gives
`(5.08 − 1.29) × 120 / 14 = 32.5 ms` of excess per baking frame. The tile probe
puts a bake's **walk at 5.7–6.4 ms per tile** — under a fifth of it.

**The rest is the live fallback.** The same 120 frames report `liveDraws=10`: a
frame whose newly exposed strip is not yet baked draws the uncovered remainder
**live**, and the probe measures a full live viewport walk at **31.5–41.6 ms**.
**Criterion 11 is missed by the live fallback, not by the bake.**

#### The spec's own prescribed remedy is spent

The spec says that if 16.67 ms proves unreachable the answer is a smaller bake
budget, **not** a larger threshold. **The budget is already floored at one tile
per frame** — `bakeBudgetTiles=1`, printed in every transcript — so that lever
is spent. And it points the wrong way regardless: baking *fewer* tiles per frame
leaves the exposed strip uncovered for *more* frames, each of which then pays the
live fallback. `kTileClipInflate` does not help either; the overdraw column
already reads 4.185 against an area factor of 1.563, and Task 11 established that
crossing multiplicity, not the pad, is the larger term.

**So this is a design question for Plan 3h, not a tuning one.** A pan frame that
exposes more than one tile falls back to a live walk for the remainder, and no
value of any existing constant removes that. It is handed over as such below.

### The one-tile budget's settle, which nobody had measured

`kBakeBudgetDevicePixels` was floored at one 512 px tile *after* Task 11's sweep,
which ran at eight. **The settle takes 11 frames** — `tile warm: frames=11` in
all five 500,000-entity runs, clean and mutated, five for five with no variance.
The rig warms until a frame bakes nothing, and it takes 11 to refill the 12-tile
visible set after the zoom phase drops the generation.

**Whether those frames miss the budget is an inference, and it stays labelled as
one.** The rig does not report per-frame timings for the warm loop — its frames
land in a bucket already reported — so this is not promoted to a measurement.
Its three supports:

1. A settle frame does strictly more work than a pan frame that bakes: after a
   zoom the generation is empty, so each of the 11 frames bakes its one permitted
   tile **and** draws the uncovered remainder live, and a full live viewport walk
   measures **31.5–41.6 ms**.
2. A pan frame baking one tile with a *mostly covered* viewport already costs
   **35.67 ms**. A settle frame's viewport is not mostly covered.
3. The direct sighting: two of three clean runs put a **30.77 ms** and a
   **33.44 ms** frame in the hold bucket — a phase with `bakeFrames=0/60`,
   `liveDraws=0` and p95 1.96 ms. That frame is not a hold frame, and the settle
   is what immediately precedes it. 30–33 ms is exactly what a settle frame
   predicts.

On that evidence, the one-tile budget converts what an eight-tile budget would
have made a short expensive burst into **roughly 11 consecutive frames of 30–40 ms
— about 350–450 ms of visible catch-up after every zoom**, each missing the
budget by 2× or more. **The budget change removed the single-frame hiccup
criterion 11 was written against and spread the same work across a settle no
criterion in the exit gate measures.** Reporting only; no fix attempted.

### What backs each PASS

- **1, 2, 3, 4** — `tile_cache_test.dart`, ink comparison at zero stray, zero
  uncovered, zero differing, at `tileCamera()` (never `ViewportTransform.fit`).
  Criterion 1 also holds after twenty-three awkward pans and after a zoom-settle
  over a factor list that includes the six factors defect F1 used to break.
  Killed by M15 (both 1 and 2), M4 (1 after a zoom), M14 (3), M-N (4), M18 and
  M-D (1).
- **5** — `tile_invalidation_test.dart`: a leaf edit, a dragged instance, a
  dragged group, the undo of an instance transform, and a stroke reaching into a
  tile its geometry misses. Every direction test asserts at runtime that the old
  and new tile sets are **disjoint** before it asserts anything else. Killed by
  M1, M2, M16, M-J, M18, M19.
- **6** — a definition edit, and a group and an instance nested inside a
  definition. Killed by M5, M-K.
- **7** — a layer edit repaints **and** drops the generation, asserted as two
  separable facts. Killed by M8 (the frame half) and M8b (the drop half) —
  neither of which the other can see.
- **8** — a pan drops nothing, a scale change drops everything. Killed by M4.
- **9** — apply, undo, **redo**, load and purge. Killed by M12b (redo alone) and
  M-L (purge alone). M12, the literal deletion, is a compile error.
- **12** — `test/invariants/tile_budget_test.dart`, eight tests. Killed by M6,
  M-B, M-C, M-D, M-F, M-G.
- **13** — the blit `Paint`'s identity read through `SpyCanvas` at the actual
  `drawImageRect` call, plus a per-frame destination count pinned against the
  blit count with the composite's own blit included. Killed by M13, M-E, M-H,
  M-Q. **Not** killed by the identity getter, which is a tautology.
- **10** — three device runs behind a reproduced control, `tile hold` phase,
  `bakeFrames=0/60`. **Killed by no mutant.** M7 is the mutant it was chartered
  against and the phase bakes nothing, so the clip M7 breaks never executes in
  the frame this criterion measures. A PASS with no killing mutant is a reading,
  not a gate — G7.

---

## The chosen constants, and the measurement that chose them

### `kTileDevicePixels = 512`

`packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`. Chosen by Task 11's
sweep, applied in Task 11a.

**The control that validated the machine first.** Before any sweep number was
taken, Plan 3d's clean `50,000 / vertices` row was reproduced:
build **7.07 ms `[7.06, 7.38]`** / raster **8.53 ms `[8.22, 8.63]`**.

```sh
CI=true flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart --profile -d macos \
  --dart-define=TEXT=true --dart-define=ENTITIES=50000 \
  --dart-define=RIG=pan --dart-define=BACKEND=vertices
```

```
### sample 1
flutter:   build  p50=7.29ms p95=8.71ms max=331.05ms
flutter:   raster p50=8.76ms p95=18.98ms max=85.66ms
flutter:   total  p50=15.41ms p95=32.17ms max=419.98ms
### sample 2
flutter:   build  p50=7.17ms p95=8.77ms max=338.33ms
flutter:   raster p50=8.48ms p95=18.74ms max=87.72ms
flutter:   total  p50=15.12ms p95=31.14ms max=431.72ms
### sample 3
flutter:   build  p50=6.99ms p95=8.73ms max=317.42ms
flutter:   raster p50=8.28ms p95=19.06ms max=152.14ms
flutter:   total  p50=15.14ms p95=31.33ms max=485.48ms
```

| sample | build p50 | in `[7.06, 7.38]`? | raster p50 | in `[8.22, 8.63]`? |
|---|---|---|---|---|
| 1 | 7.29 | yes | 8.76 | **no**, +0.13 (+1.5%) |
| 2 | 7.17 | yes | 8.48 | yes |
| 3 | 6.99 | **no**, −0.07 (−1.0%) | 8.28 | yes |
| **median** | **7.17** | **yes** | **8.48** | **yes** |

Machine state read immediately before the control and again before the sweep,
both readings identical: `lowpowermode 0`, AC power, battery 100% charged. Every
`flutter drive` ran in the foreground.

**One caveat on that transcript's provenance, recorded rather than smoothed
over.** It prints `tiles=off` (so `TILES` existed) and carries no `mean=` column
(so `report()`'s mean addition did not), and both landed together in `96cdd56` —
so no commit's tree reproduces exactly this line shape. It is not a synthesised
transcript; the numbers were pasted from a real mid-development run. **The sweep
transcripts below, all taken after `96cdd56`, are reproducible against that
commit.**

### The three columns

`ENTITIES=500000`, `BACKEND=vertices`, `RIG=pan`, `TEXT=true`, `TILES=on`,
`TILE_BAKE` at its then-default of 8 tiles. Viewport 800×600 logical at dpr 2.0
— **1600×1200 device**, measured and printed on every run, and *not* the
3200×2400 reference viewport the spec's MiB arithmetic assumes. 1024 was excluded
before the sweep started.

| | **128** | **256** | **512** |
|---|---|---|---|
| tiles covering the viewport | 130 | 35 | 12 |
| **blit cost per frame** (hold, `total` mean) | **1.45 ms** | **1.44 ms** | **1.52 ms** |
| hold `total` p50 / p95 | 1.20 / 3.15 | 1.46 / 2.45 | 1.62 / 2.52 |
| hold blits per frame | 130 | 35 | 12 |
| pan `total` mean | 11.05 ms | 4.75 ms | **2.99 ms** |
| pan `total` p50 / p95 / max | 1.15 / 65.19 / 79.53 | 0.94 / 47.42 / 92.62 | **0.69 / 2.31** / 88.44 |
| bakes per pan frame | 1.683 | 0.458 | 0.117 |
| pan frames that baked | 34 / 120 | 9 / 120 | 4 / 120 |
| max bakes in one frame | 8 (the budget) | 8 (the budget) | 4 |
| pan frames that fell back to a live walk | **18** | 1 | **0** |
| **bake cost per tile**, `(pan mean − hold mean) / bakesPerFrame` | 5.70 ms | **7.23 ms** | 12.56 ms |
| bake cost per tile, probe walk only | 2.04 ms | 3.01 ms | 6.00 ms |
| whole-generation walk (probe total) | 265.53 ms | 105.31 ms | **71.97 ms** |
| **measured overdraw factor** | **17.983** | **6.888** | **4.185** |
| area factor (re-derived) | 4.000 | 2.250 | 1.563 |
| visible-set bytes, this viewport | 8,519,680 | 9,175,040 | 12,582,912 |

**512 is the only size whose pan p95 fits 16.67 ms** — 2.31 ms against 47.42 at
256 and 65.19 at 128 — and the only one with **zero** live-walk fallbacks,
against 1 and 18.

**The three-column requirement earned itself.** Blit cost is flat — 1.45 / 1.44 /
1.52 ms across a **16× range of tile count**. A sweep reading only the column the
spike had measured would have found a 0.08 ms spread, called it noise or called
it a win for the smallest tile, **and lost criterion 11.**

**And the overdraw model was wrong.** The area factors came out as predicted
(4.000 / 2.250 / 1.563 — the padded-cull ratio `((T/2 + 64)/(T/2))²` at dpr 2
with `kTileSlack = 32` logical), but measured leaf overdraw is 17.983 / 6.888 /
4.185, leaving residues of **4.50× / 3.06× / 2.68×**. The cause is not the pad:
**an entity larger than a tile is walked once per tile it crosses**, and crossing
multiplicity is the *larger* of the two terms at every size. Deterministic — the
256 arm was run twice and printed `overdraw=6.888` both times, and the
denominator (`screenSpaceLeafCount = 4350`) was identical across all three runs.

**Therefore `kTileClipInflate` is withdrawn.** The spec invited it if the
overdraw column justified it; the measurement closes the question. A tile-specific
slack smaller than `kTileSlack` attacks only the area term, and taking the pad to
zero at 512 — the maximum possible win — moves 4.185 to about 2.68 while
reopening defect F1's vanishing stroke column. The cheaper lever on the same
quantity is the tile size itself, which buys 17.983 → 4.185 with no correctness
exposure at all.

### `kBakeBudgetDevicePixels = 262144`, replacing `kTilesBakedPerFrame`

**Choosing 512 invalidated the old constant's unit, and this was caught by the
implementer rather than by the plan.** Eight tiles at 128 px is a modest strip;
eight at 512 px is 8 × 12.56 ms = **~100 ms in one frame** — six frame budgets.

One 512 px tile is 512 × 512 = **262,144 device pixels**, and Task 11 measured
**12.56 ms** to bake one at that size. One tile's bake plus the measured
1.52 ms hold-frame blit is **14.08 ms, inside the 16.67 ms budget**; two tiles'
bake alone is **25.12 ms** and blows it outright. So one tile is the most a frame
can afford at the production tile size, and 262,144 is exactly one tile's worth.

`TileCache` divides the budget by `tileDevicePixels²` at runtime, so the tile
count now *follows* the tile size instead of being independent of it — which is
precisely the coupling whose absence caused the problem.

**Three qualifications carried on the constant's own doc comment:**

1. The figure is **pinned to the 512 px measurement**, not derived at read time.
   The next tile-size change must re-check the arithmetic against a fresh
   bake-cost number; nothing enforces it automatically.
2. **12.56 ms rests on fourteen bake events** (`bakes=14 perFrame=0.117` from the
   512 arm), the repeat run that confirmed reproducibility was taken at 256 and
   never at 512, and the margin to 16.67 ms is 2.59 ms — about 16%.
3. The budget floors at **one tile** whenever it is positive, so a valid
   `TILE_PX` whose area exceeds the budget cannot silently truncate the feature
   to nothing. `0` stays reachable, because that is the zoom-path tests'
   deliberate "bake nothing" configuration. See M-R.

**A measurement that does not carry its own configuration is how two
incomparable runs end up in one table.** Applying the new constant moved the
harness default from 8 tiles to 1, which would have made Task 12's device runs
silently incomparable with Task 11's sweep. Closed by naming
`kBakeBudgetDevicePixels` in `main.dart` and by having the rig **print the budget
it ran with**, in device pixels *and* in tiles, beside its counters.

**Answered by Task 12, and the answer is a finding of its own.** The 1-tile
default's pan-settle behaviour had not been re-verified against Task 11's sweep,
which ran at 8. It has been now: the settle is **11 frames**, five for five
across every 500,000-entity run, and on the evidence most of them miss the frame
budget. See "The one-tile budget's settle" above.

### Memory, at the reference viewport

512's visible set is **48.0 MiB** on the 3200×2400 reference viewport, which with
the 29.3 MiB carry-over composite is **77.3 MiB against the 96 MiB
`kTileCacheBytes` cap** — 18.7 MiB of ring. Tight but inside, and Task 10's cap
tests gate it. It is also why 1024 (80.0 + 29.3 = 109.3 MiB) does not fit. No run
in the sweep evicted: `evictions=0(life)` on all three arms.

---

## Accepted gaps, and what each still owes

### G1 — the seam is not settled on device. **OPEN.**

`drawvertices_antialiasing_test.dart` pins that **`flutter_test`'s software Skia
does not antialias `drawVertices` at all** — that file's own words are "a fact
about `flutter_test`'s software Skia, not about this codebase". So the instrument
**cannot produce an antialiased seam**, and M3 — the mutant that would create one
— could not be fired at all. It is recorded in the mutation log as unfired, with
its reason, and it is **not** counted toward coverage.

**Criterion 2 is proven complete geometrically, and it is not proven free of
antialiasing artefacts on device.** Those are the words. A green criterion 2 is
**not** a settled seam.

**Still owed:** a device-side check that Impeller honours a non-antialiased clip
exactly on the device pixel grid. Not delivered by this plan.

### G2 — no table record may gain a setter. **OPEN, as a rule.**

Every table record is `@immutable` with all-final fields (the contract at
`tables.dart:16`, the six records — `LayerRecord`, `LinetypeRecord`,
`TextStyleRecord`, `PatternRecord`, `DimStyleRecord`, `AppIdRecord` — at
`:138, :234, :278, :405, :451, :511`), and `TableSection.add` throws
`DuplicateHandleError` on a
handle it already holds — so changing a layer's colour is necessarily a `remove`
followed by an `add`, and both bump the revision.

**The gap is a rule, not a risk: no table record may gain a setter.** If one
ever does, the mutation is invisible to the revision counter and the tiled frame
goes stale with nothing to notice. The reason is recorded where the counter
lives, so the next person to add a setter reads it first.

### G3 — zoom stays where it is. **OPEN. It is Plan 3h.**

Under a continuous zoom gesture this plan shows stale pixels cheaply; it does not
make a correct zoom frame faster. 500,000 entities under zoom remains a 32–40 ms
frame.

### G4 — the web whole-drawing abort's re-run. **OPEN. Still owed.**

`STATUS.md` records that Plan 3g is owed a back-to-back same-session re-run of
the web whole-drawing abort. It was out of scope for the spike and it was out of
scope here. **Still owed, and this plan did not deliver it.**

### G5 — a tiled frame is not bit-identical for every slope. **OPEN, bounded, measured.**

Added during execution, from Task 6a. **This qualifies criteria 1 and 2 and it is
the most important entry in this section.**

Criteria 1 and 2 demand **zero** stray, uncovered and differing pixels, and they
hold for the fixtures that gate them. **The general claim does not.**

**The cause, established to the bit.** `VerticesDrawSink` stores positions in a
`Float32List`. A tile's whole-device-pixel offset moves a coordinate into a
**coarser `Float32` binade**: device x `-17.943408966064453` is exactly
representable (binade 2⁴, ulp 1.907e-06), while the same point expressed against
the frame origin, `-401.94340896606445`, lands in binade 2⁸ where the ulp is
3.052e-05 and it stores as `-401.94342041015625` — an error of **1.144e-05 px**.
Where a stroke's device slope makes its edge graze sample points at a regular
period — the reproduction's slope is exactly 3/50, and its differing pixels are
exactly 50 apart — that error decides the tie and one pixel flips.

**It is not this codebase's.** Reproduced with `Canvas.drawVertices` alone, with
no jet-cad code in the path.

**The measured bound**, over an 82-slope sweep:

| case | differing pixels, as a fraction of ink |
|---|---|
| worst case across all slopes | **2.38%** |
| a ten-line drawing | 0.39% |
| axis-aligned, and slopes 0.2 / 1.0 / 5.0 / 16.7 | **0.000%** |

A permanent test asserts that bound rather than zero, and reddens under a
one-pixel `destRectFor` error at 53× the bound (M-M).

**Two diagnoses that looked right and were not**, recorded because both were
believed before being tested:

- *"It is the slope."* Ten **parallel** diagonals at slope 0.6 cross just as many
  seams and give zero, while a single **near-axis** line gives seven on its own.
- *"It is `Float64` cancellation in `bakeCameraFor`."* Refuted by measurement:
  the `Float64` coordinates the two paths emit are **bit-identical**, 1368
  comparisons, 0 mismatches.

**No fix exists, and this was tested rather than argued.** The remedy the refuted
hypothesis implied — region-based culling with an exact canvas translate,
per-tile culling preserved, so **not** mutant M7 — was built. The emitted
vertices became bit-identical and **the pixels moved zero**. The change was
reverted.

**Still owed:** this is a software-Skia bound, and **G1's reservation applies to
it in both directions.** It does not transfer to a GPU backend; Impeller may show
more, less or none. Owed alongside G1's device seam check.

### G6 — invalidation's second direction is geometric. **CLOSED by Task 9a.**

**Closed, with a measured cost, not carried forward.** It is recorded closed here
so that no successor re-opens it as an unresolved item.

It was closed together with **defect F1**, a *visible* bug that shares its cause:
at **6 of 41 swept zoom factors a whole stroke column vanished** from the tiled
frame. `DraftPainter.paint` derives its index query from
`camera.visibleWorld(viewport)` with **no slack** (`draft_painter.dart:338`, used
raw at `:357` and `:369`) while inflating the *screen clip* by
`kScreenClipInflate` at `:345-351` — and a clip only **keeps**, so it cannot
return an entity the query never yielded. On a full frame the missed entities are
off-screen; **on a tile the edge is interior to the drawing.**

One constant closes both: `kTileSlack = kScreenClipInflate`. `_bake` widens its
cull by it; `_worldRectOf` grows the tile rect by it in screen space before
inverting. The clip is untouched, so a tile still keeps only its own pixels.
Padding only one side makes the two halves disagree by a ring — the record
over-reports against a rule that under-condemns — **which is why F1 and G6 were
one task and not two.** M18 (slack removed) and M19 (bake padded only) are the
two mutants that hold it there.

**Measured: the sweep goes 6 of 41 to 0 of 41.** Three of the four direction-two
assertions Task 9's bake-only patch reddened went green with **no test change** —
they had reddened only because the arrival oracle over-reported against an
unpadded rule. F1's group tightened from `<= 600` uncovered pixels to `== 0`, and
criterion 1's zoom list stopped excluding the six killers.

**The over-drop cost, measured rather than argued.** At the 64 device-pixel tile
the tests use — the worst case, because the ring is a whole tile there:

| edit | before | after | extra |
| --- | --- | --- | --- |
| leaf move, five columns | 15 of 130 | **32 of 130** | +17 |
| leaf nudge, two world units | 6 of 130 | **12 of 130** | +6 |
| dragged instance | 8 of 130 | **28 of 130** | +20 |
| dragged group | 8 of 130 | **24 of 130** | +16 |

The ring is a fixed 32 logical pixels, so it shrinks against a larger tile:

| tile | edit | before | after |
| --- | --- | --- | --- |
| 128 device px | leaf move | 6 of 35 | **10 of 35** |
| 128 device px | dragged instance | 6 of 35 | **8 of 35** |
| 256 device px | leaf move | 4 of 12 | **6 of 12** |
| 256 device px | dragged instance | 4 of 12 | **4 of 12** |

**It is a hit-rate cost, never a correctness one.** A tile dropped that need not
have been is rebaked at the next frame's budget; a tile kept that should have
been dropped is a visible defect. Note that the second table's rig holds only
twelve tiles at 256, so those rows are a *trend*, not a production figure — and
the production tile is now 512, where the ring is an eighth of a tile's width
rather than a quarter.

### G7 — per-tile clipping. **CLOSED 2026-08-24. The claim below was measured on the wrong suite; read the correction at the end of this section.**

**Added 2026-08-24, from Task 12.** M7 — clip each tile to the viewport instead
of to its own rect — was fired on device, twice, and **killed nothing.**

The spec named M7 **"the mutation that passes every correctness gate and
destroys the plan's entire reason for existing"** and said **"a suite that
cannot kill it is not gating this plan"**. That sentence stands, and this suite
does not kill it.

**The mutant was demonstrably live**, on fields that count actual drawing and
independently of any timing: `triangles` **734442 → 1183035** (+61%),
`canvasCalls` **97 → 150**, and R2 `build p50` **23.10 → 38.47**, all reproduced
in two runs.

| reading | clean (median of 3) | M7 run A | M7 run B | verdict |
|---|---|---|---|---|
| criterion 10, hold p50 | 1.58 | 1.47 | 1.24 | **unchanged** |
| criterion 10, hold p95 | 1.96 | 1.75 | 2.32 | **unchanged** |
| criterion 11, pan p95 | 35.67 | 49.90 | 63.62 | 1.4×–1.8× worse |
| criterion 11, pan max | 65.77 | 89.13 | 90.03 | 1.35× worse |

**Criterion 10 is structurally blind to M7, and no threshold change could fix
it.** The settled frame bakes nothing — `bakeFrames=0/60` in every run, clean and
mutated alike — so **the clip M7 breaks is never executed in the frame criterion
10 measures.** The mutated hold column sits inside the clean run-to-run spread.

**Criterion 11 degraded but did not turn red, because it was already red.** A
criterion that fails on clean source cannot distinguish the mutant from the
original. **There is no green-to-red transition anywhere in this suite.**

Criteria 1–9, 12 and 13 pass under M7 **by construction**: the blit shows only a
tile's own rect and `toImageSync` crops the rest, so the pixels are identical and
only the work differs.

**What is owed: a bake-time assertion that a tile's geometry is bounded by its
own rect** — the command-time-assertion shape trap 5 already recommends for this
repository — **not another frame-path timing.** Two device timings were the
plan's answer for M7 and both turned out unable to deliver: one blind by
construction, the other red on clean source. A third timing would be a fourth
attempt at the same wrong instrument.

---

#### Correction, 2026-08-24, after the plan closed

**"There is no green-to-red transition anywhere in this suite" is false, and the
sentence above it — "Criteria 1–9, 12 and 13 pass under M7 by construction" —
is where it came from.** That line was *reasoned*, not run. M7 was fired on
device and nowhere else; the widget suite was never executed under it.

It was, on 2026-08-24. **M7 reddens five tests.** Four of them already existed:

```
Failing tests:
  test/invariants/tile_containment_test.dart: no tile bakes geometry from beyond its own rect
  test/tile_invalidation_test.dart: criterion 5: a dragged group leaves no ghost either
  test/tile_invalidation_test.dart: criterion 5: a dragged instance drops the tiles it left
  test/tile_invalidation_test.dart: criterion 5: a leaf edit invalidates its own tiles and no others
  test/tile_invalidation_test.dart: criterion 5: the undo of an instance transform invalidates both ends
```

Clean: 365 pass, 1 skip. Restored from a copy, not by `git checkout`.

**The mechanism, and why criterion 5 sees what criteria 1–13 could not.**
Criterion 5 does not assert that an edit invalidates its own tiles; it asserts
that it invalidates its own tiles **and no others**. Under M7 every tile's bake
walks the whole viewport, so every tile records every visited handle, so every
edit invalidates every tile. The containment claim is reachable from the
invalidation side, and it was already gated there — by a criterion nobody was
looking at while two timings were failing to deliver.

**So G7 was never the largest gap here.** It was a gap in what had been *run*.
The two device timings are still unable to kill M7 and everything this section
says about them stands; what does not stand is the conclusion drawn from them
about the suite as a whole.

**What is owed was still built**, at `1b7ea04`:
`test/invariants/tile_containment_test.dart` states the containment claim
directly rather than as a consequence of invalidation precision. Nine short
segments 90 world units apart, each 6 long; a bake queries its own tile grown by
`kTileSlack` on every side, which at the rig's 64-device-pixel tile is 96
logical pixels and so 68.57 world units, while two neighbouring segments span 96
world units. No bake can see two. Clean reads one segment per tile; M7 reads
nine on tile (0,0). It adds no production API and no fourth knob — it inverts
the existing `TileCache.tilesHolding`.

**Why it is worth landing beside the four.** The four state that invalidation is
precise; this one states that a bake is bounded. If a later plan loosens
invalidation precision as a deliberate design change — and Plan 3h may, since
the pan-frame question is about covering more ground per bake — the four can be
rewritten in good faith and the containment claim would vanish with them,
unnamed and unnoticed.

**The disguise, for the taxonomy below.** Every entry in that list is a gate
that could not see what it claimed to measure. This is its inverse: **a gate
that could see, recorded as blind because a different instrument was the only
one fired.** The question it adds to the seven: *did I run this, or did I reason
that it passes?*

---

## Two things owed to `draft_painter.dart`'s owner, not to this plan

Both were found by 3g and neither belongs to it. They are recorded here so they
are not lost, and so the next person in that file does not have to rediscover
them.

1. **`kScreenClipInflate`'s doc comment says "device pixels" and the code uses it
   as logical.** Usage is consistent throughout and errs safe, so nothing is
   wrong today — **the comment is.** `kTileSlack` inherits the value and
   therefore the ambiguity.

2. **The painter's index query has no slack of its own.**
   `DraftPainter.paint` derives its query from `camera.visibleWorld(viewport)`
   raw at `:357` and `:369` while inflating only the *screen clip* at `:345-351`.
   That is a **pre-existing latent defect** — invisible on a full frame because
   the missed entities are off-screen, and visible the moment anything makes the
   viewport edge interior to the drawing. Tiling made it visible; `kTileSlack`
   works around it **from the cache side**, which leaves the painter's own query
   exactly as it was. Whoever owns that file should decide whether the painter
   should carry the slack itself.

---

## What Plan 3h inherits

- **Criterion 11's miss, with its cause isolated.** 35.67 ms against a 16.67 ms
  budget, 2.1× over, reproduced three times — **and the bake is under a fifth of
  it.** The excess is the live fallback drawing the still-uncovered strip
  (`liveDraws=10`, a full live walk at 31.5–41.6 ms). **The spec's prescribed
  remedy is spent**: the budget is already floored at one tile, and lowering it
  further leaves the strip uncovered for more frames, each paying the fallback
  again. A pan frame that exposes more than one tile has no covered path today.
  **That is a design question, not a tuning one, and it is 3h's.**
- **And its companion, the settle.** The one-tile budget removed the single-frame
  hiccup and spread the work across roughly 11 frames of 30–40 ms — about
  350–450 ms of catch-up after every zoom — which no criterion in this exit gate
  measures. Labelled an inference with three supports, not a measurement,
  because the rig cannot time warm frames.
- **G7: nothing here gates per-tile clipping**, and the fix is a bake-time
  assertion rather than a timing. If 3h changes what a tile contains, it changes
  the thing that has no gate.
- **A measured zoom problem with a number on it.** 32.06 ms at 500,000 entities
  with tiles on, against a 16.67 ms budget, and the knowledge that **no caching
  scheme touches it** because the triangles are genuinely being drawn. That is
  G3, and it is 3h's subject.
- **A tile cache that can hold a simplified bake.** Level-of-detail geometry has
  somewhere to live the moment it exists: it is a property of the generation,
  **and the generation is already keyed by scale**. Nothing new is needed to make
  a coarser bake legal — a scale change already drops the generation (criterion
  8, killed by M4), so a simplified bake can never outlive the scale it was
  simplified for.
- **The vertex-buffer consequence, still to be read.** Baking per tile flushes
  and rewinds the buffer between tiles, so the **96.00 MiB high-water mark
  `STATUS.md:1066` records** at 500,000 entities should fall to a single tile's
  geometry. **If it does, the tile budget replaces that memory rather than adding
  to it**, and 3h's budget starts from the new number rather than from 96 + 96.
  This is `debugCapacityVertices` with tiles on against tiles off at 500,000
  entities. **It was not read.** Task 12 measured criteria 10 and 11 and fired
  M7; this reading was not in its brief and remains owed. It needs a device.
- **G1's device seam check**, which 3h needs anyway if it changes what a tile
  contains — and with it **the standing lesson that this repository's software
  rasteriser cannot produce an antialiasing artefact, so no green result from it
  settles one.** G5's bound is subject to the same reservation.
- **`kTileClipInflate` is closed, not deferred.** The overdraw column answered
  the question the spec left open; do not re-litigate it without a new
  measurement.
- **Two test-only mutable knobs now sit on a production type** —
  `bakeBudgetDevicePixels` and `cacheBytes`. Accepted, with the implementer's own
  bar: **a third knob should trigger revisiting the design.**

---

# The section this plan owes its successor

The dominant finding of this execution was not any single defect.

**Twelve times, a gate turned out unable to see the thing it claimed to measure
— each time in a different disguise.** Every one was found by a person looking at
a green run and refusing to accept it. None was found by reading the code. The
twelfth was found on the last task of the plan, which is the honest note to end
on: the list was never going to close itself.

That is the part worth keeping, so here is the taxonomy, and then the questions
that produce it.

## The twelve disguises

**1. A getter reading its own field.** *(M13, Task 4.)* Criterion 13 asserted
`identical(cache.debugBlitPaint, first)`. `debugBlitPaint` returns the cache's own
`_blitPaint` field, and a mutant building a fresh `Paint` at the `drawImageRect`
call site never touches that field. **The assertion compares the field to
itself.** The spec had said this getter "is what makes M13 killable" — one
section after citing this exact trap. Closed with a canvas spy reading the `Paint`
that actually reached `dart:ui`.

**2. An algebraic cancellation.** *(M17, Task 5.)* The rebase origin was supposed
to be gated by criterion 1's pixel comparison. It cancels **exactly**: the painter
pushes the origin as the residual and `VerticesDrawSink` applies that residual in
`Float64` before its `Float32` store, so `(screen − origin) + origin = screen` at
any magnitude. **No pixel comparison on that backend can ever see it.** The
plan's fallback — "move the fixture out to 4.5e6" — was a wrong diagnosis of a
right observation, and following it would have produced a green run and a false
coverage claim. Closed with a wiring test reading the coordinate `_bake` hands the
sink.

**3. An instrument that cannot produce the artefact.** *(M3/G1; also M11, Task 6;
also M-E, Task 10.)* `flutter_test`'s software Skia antialiases no
`drawVertices`, so M3 cannot be fired at all. M11 (`BlendMode.src`) reddened
nothing because `_capture` always starts from a blank destination, where `src` and
`srcOver` are algebraically identical. M-E survived criterion 13 because its two
assertions — `first == second` and `first < 200` — are **both satisfied by a
counter stuck at zero.**

**4. A fixture whose effect was never verified.** *(Criterion 4, Task 6 fix
round.)* The fixture passed `transparency: 153` and **nothing asserted it took
effect.** `InkReport` counts ink and carries no colour, so a style resolver that
dropped transparency entirely would have drawn both arms opaque and the criterion
would still have read zero. Closed by asserting the ARGB **through the resolver**
(`0x66FFFFFF` — 255 − 153 = 102), which is a gate rather than a read-back of what
the fixture supplied.

**5. An API whose name promised otherwise.** *(Task 7 — the ledger's fifth
instance, and the most dangerous.)* Invalidation's second direction called
`definitionBounds(instanceHandle)`. An `InstanceNode` is neither a `GroupNode` nor
a definition, so `_childrenOf` falls through and the call **returns an empty box
with no error.** Direction two would have skipped every instance and dropped
nothing, silently, while direction one kept every test green. The name says it
returns the bounds of a definition; it accepts a handle for which it returns
nothing at all.

**6. A shape absent from every fixture.** *(Task 7 C1.)* `debugOnVisit` fires for
`InstanceNode` only. A dragged **group** therefore recorded nothing and left
ghosts — in shipped code, unmutated. Task 1's review had traced all four call
sites and confirmed "once per container descended", **which was true of the
fixture it traced**; no fixture in Task 1 or Task 7 contained a group. One
implementation and two reviews approved an unbounded claim because nothing
contradicted it. The third reviewer wrote a group fixture and ran it. The same
move found G5.

**7. An assertion measuring the wrong quantity.** *(Criterion 7, Task 8 — the
ledger's seventh instance.)* Criterion 7 asserted only the **frame count**. A
mutant that keeps the repaint and deletes the generation drop passes it while the
cache shows stale pixels forever. Closed with an exact `invalidationCount`
assertion, so the two halves became separable mutants — M8 kills the frame half,
M8b the drop half, and **neither can see the other's**. Criterion 3 had the same
shape in a different place: it read `textOpCount` after the wrong paint, because
the painter resets counters per call and the cache calls it per tile, so the
reading was the last tile's — usually text-free.

**8. A setup that never produced the state its own comment named.** *(Task 9 C1 —
the ledger's eighth.)* The test asserted exactly the right thing —
`liveDrawCount > 0`, with its own comment saying "which a composite standing in
front of it would hide" — **but it never zoomed, so no composite ever existed.**
The author saw the hazard, named it in prose, and built a fixture in which it
could not arise. The real defect was worse than the review reported: at the
production budget the frame never healed, showing pre-edit pixels for a whole
settle.

**9. An assertion a later task silently falsified.** *(Criterion 13 vs. the
carry-over, Task 9 — the ledger's ninth, and a new kind.)* "Every
`drawImageRect` shares one `Paint`" was **true the day it was written** and made
false by Task 9's own carry-over composite, which carries its own filtered
`Paint`. Invisible because no test entered that path with a composite standing.
**The defence is asking, when a new state is introduced, whether the old
assertions are still true in it.** The implementer only swept because the fix
dispatch asked; without the question, `debugCarryOverPaint` would not exist.

**10. Two states each covered alone, and never together.** *(Task 10.)* Dropping
the composite term from `liveBytes` left all three budget tests green, because
they only **pan** — and `_carryOver` is therefore always null. Composite-standing
was covered elsewhere; cap-pressure was covered here; **the rule between them was
covered nowhere.** The same shape appeared in Task 9's fix: `_dropGeneration` and
`_invalidateTouched` are two independent paths to a stale composite, each proved
load-bearing only by backing out the other. And in M16 versus M-J, where a group
is recovered through the owner chain and an instance only through the painter
callback — **two mechanisms, two mutants, neither masking the other, both
required.**

**11. A valid configuration value that turned the feature off inside a guard
built for invalid ones.** *(Task 11a I1.)* `TILE_PX=1024` is a number, inside the
declared range, accepted by `minimum: 1` — and it divided to a **zero** bake
budget, which would have run an entire sweep on the live-walk fallback while
still printing `tiles=on`: **publishing the untiled baseline under a tiled
heading.** The repository's throw-on-bad-define rule exists because Plan 3c lost a
device run to `TEXT=1` reading as false. That guard works at the string level.
**Same failure, numeric disguise, two years later. The guard's type was right;
its scope was not.**

**12. An instrument that reimplements what it measures.** *(Task 12.)* The rig's
`tile probe` reports **`overdraw=4.185` bit-for-bit identically in the clean and
the M7-mutated runs** — a mutation that moved the real triangle count by 61%.
`_probeBake` in `measurement_rig.dart` reimplements the bake geometry rather than
calling `TileCache._bake`, so **the overdraw column measures what the cache
should do, never what it does.** Anyone reading that column as evidence about the
shipped clip is reading a copy of the specification. This is not a defect in
`_probeBake` — a probe that called the real `_bake` could not sum per-tile leaf
counts the way this one does — but it is a boundary nobody had written down, and
the column that chose `kTileDevicePixels` is the same column.

It is distinct from disguise 1 (a getter reading its own field) in the way that
matters for finding it: a tautological getter is visible in one line of source,
while a reimplementation is a **second correct-looking implementation** that
agrees with the first for every input anyone tries. It is closest to disguise 3,
but where an instrument that cannot produce the artefact fails loudly the moment
you ask it to, this one answers confidently and wrongly.

## The questions, which are the part that transfers

A list of twelve defects is a curiosity. The method that produces them is the
asset, and Task 10's implementer demonstrated it: **given these questions in its
dispatch, it found three at once, in one task, each confirmed by firing a mutant
rather than by argument.** That is the difference.

Ask them in this order, of every assertion you are about to trust:

> **1. What would have to break for this to fail — and is that the thing it
> names?**
>
> Not "does it pass". Trace backwards from the assertion to the smallest change
> that reddens it, and compare that change to the sentence in the test's name. If
> the smallest change is "the field is reassigned" and the name says "the call
> site does not allocate", they are different claims. (Disguises 1, 3, 7.)

> **2. Is there a shape that would make the claim false — and does the fixture
> contain it?**
>
> The limit of a claim's coverage is harder to see than the claim. Enumerate the
> shapes the code can meet — a group, a nested definition, a near-axis slope, a
> negative key — and check the fixture for each. "No fixture in this repository
> has one" is an answer, and it means the claim is unproven, not proven.
> (Disguises 5, 6.)

> **3. Does the setup produce the state the assertion is about?**
>
> Read the arrange, not the assert. If the comment says "which a composite would
> hide", find the line that mints a composite. If it says "at the cap", find the
> line that reaches the cap. An assertion about a state the setup cannot reach is
> a sentence, not a gate. (Disguises 4, 8.)

> **4. If two states are each covered separately, what covers the rule between
> them?**
>
> Coverage of A and coverage of B is not coverage of "A and B interact
> correctly". Where two mechanisms can each produce the same symptom, prove each
> one load-bearing by removing the other. (Disguise 10.)

And two more that this execution earned the hard way:

> **5. When a new state is introduced, are the old assertions still true in it?**
>
> Assertions do not rot loudly. The carry-over composite falsified a criterion
> written three tasks earlier and nothing went red, because nothing entered that
> path in the new state. **Sweep the existing assertions whenever you add a state
> the code can be in.** (Disguise 9.)

> **6. Which valid inputs does this guard silently swallow?**
>
> Guards are written against the invalid. Check the *valid* end of the range for
> values that divide, truncate or clamp the feature into doing nothing — and make
> the failure loud or make the value work. (Disguise 11.)

> **7. Does this instrument observe the shipped path, or a copy of it?**
>
> Follow the measurement back to the production function it claims to be about.
> If the probe has its own implementation of the thing under test, it will agree
> with the specification forever and with the code never. Mutate the production
> path and check the instrument *moves*. (Disguise 12.)

**A closing note on cost, because it is the honest counterweight.** Chasing these
was not free: Task 5 spent 340k tokens and 139 tool uses on M17 alone, Task 6a
was an entire unplanned task that changed no production line, and Tasks 7, 9 and
10 each took fix rounds. What was bought is that **criteria 1 through 10, 12 and
13 mean what they say**, and that the places where they do not — G1's seam, G5's
slope bound, G7's unkilled M7 — are written down with numbers instead of being
implied by a green run.

**And the last one is the reason the method matters more than the list.**
Disguise 12 was found on the plan's final task, by firing a mutant nobody
expected to survive and then noticing that a *column in the report* had not
moved. Twelve tasks of practice did not exhaust the supply. **The tally is 11
of 13 criteria, with criterion 11's miss named and its cause isolated, and one
mutant the suite cannot kill.** That is what shipped, and it is written this way
so that the next plan starts from the truth rather than from a green run.
