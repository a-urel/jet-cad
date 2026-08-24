# Task 11a report: applying Task 11's decision, and the units it invalidated

Task 11 owned the harness and the sweep only, and recorded its decision
without landing it. This task applies it: `kTileDevicePixels` becomes 512,
the bake budget is re-expressed as a device-pixel area because the old
tile-count unit stopped being safe at the new tile size, and the harness's
per-frame counters are made honest about what they report under `TILES=on`.

## 1. `kTileDevicePixels = 512`

`packages/jet_cad_2d_flutter/lib/src/tile_cache.dart:53`. The doc comment was
replaced wholesale with Task 11's measured table (blit / bake / whole-generation
walk / pan p95 / live-walk fallbacks / overdraw, all three tile sizes) and the
corrected overdraw explanation: the area factor `4.000/2.250/1.563` that
`kTileSlack`'s padding predicts is real and matches the tree, but it is the
*smaller* term. Measured leaf overdraw is `17.983/6.888/4.185`, and the
residue the area factor does not explain — `4.50x/3.06x/2.68x` — is crossing
multiplicity: an entity larger than a tile is walked once per tile it
crosses, independent of any pad, and it shrinks as tiles grow because a
stroke of fixed world length crosses fewer larger tiles. No numbers here were
re-measured; they are copied from
`.superpowers/sdd/2026-08-23-jet-cad-2d-plan-3g-tile-cache/task-11-report.md`.

## 2. `kBakeBudgetDevicePixels = 262144`, replacing `kTilesBakedPerFrame`

**The arithmetic.** One 512 px tile is `512 x 512 = 262,144` device pixels
and Task 11 measured **12.56 ms** to bake one at that size
(`ENTITIES=500000`, `RIG=pan`, frame-level `(pan mean - hold mean) /
bakesPerFrame`). One tile's bake plus the hold-frame blit cost (measured
1.52 ms at 512 px) is 14.08 ms, under the 16.67 ms frame budget; two tiles'
bake alone is 25.12 ms and blows it outright. So one tile is the most a
frame can afford to bake at the production tile size, and 262,144 is exactly
one tile's worth. This is stated as pinned to the 512 px measurement, not
derived from `kTileDevicePixels` at read time — the doc comment says
explicitly that the next tile-size change must re-check the arithmetic
against a fresh bake-cost number, because nothing enforces it automatically.

**The mechanism.** `TileCache.bakeBudgetDevicePixels` (renamed from
`tilesBakedPerFrame`) is still consulted once per frame in `paintFrame`, but
as `bakeBudgetDevicePixels ~/ _tileDevicePixelArea` (a new private getter,
`tileDevicePixels * tileDevicePixels`) rather than as a raw tile count. The
number of tiles a frame may bake now falls out of the budget divided by
whatever `tileDevicePixels` currently is, so a future tile-size change no
longer silently multiplies (or divides) the frame's bake cost the way the
tile-count budget did when 256 became 512.

**The harness (`apps/dev_harness_2d/lib/main.dart`).** `kTileBake` (the
`TILE_BAKE` define) now forwards directly to `bakeBudgetDevicePixels` in the
same unit — device pixels, matching `TILE_PX` — rather than a tile count. Its
doc comment gives the conversion for a sweep that wants "N tiles at this
run's TILE_PX": `TILE_BAKE=$((N * TILE_PX * TILE_PX))`. The default fallback
changed from `kTilesBakedPerFrame` (8, a tile count) to
`kBakeBudgetDevicePixels` (262144, one tile at 512 px) — this is a real
behaviour change from Task 11's own default sweep arm (`TILE_BAKE` at its old
default of 8 tiles), but Task 11's numbers were measured explicitly and are
not affected by the harness's *default* changing after the fact; nothing in
this task re-ran the sweep, and nothing here contradicts what Task 11
published.

**Every call site.** `TileCache`'s only production construction site,
`packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart:246`, does not pass
this parameter at all (uses the class default) and needed no change.

## 3. Every test that set the old constant

**The bridge: `TileRig` (`test/support/tile_fixture.dart`) keeps its own
`tilesBakedPerFrame` constructor parameter, spelled and typed exactly as
before — a tile count — and converts it internally:**

```dart
cache = TileCache(
    tileDevicePixels: tileDevicePixels,
    bakeBudgetDevicePixels:
        tilesBakedPerFrame * tileDevicePixels * tileDevicePixels,
    cacheBytes: cacheBytes);
```

Every `TileRig` in this test suite is built at `tileDevicePixels: 64` (the
file's own doc comment calls this anti-degenerate clause 1, deliberately not
the production size), so the conversion is exact and lossless for all of
them: `64 * 64 = 4096` divides every tile count used with no remainder. This
is why the overwhelming majority of call sites — every `TileRig(...)` that
only ever set `tilesBakedPerFrame` at construction — needed **zero source
changes** to preserve their exact intent:

- `tilesBakedPerFrame: 1000` (≈25 call sites across `tile_cache_test.dart`,
  `test/invariants/tile_budget_test.dart`, `tile_invalidation_test.dart`):
  intent "budget effectively unbounded, never the limiting factor for this
  fixture." Now `bakeBudgetDevicePixels = 4,096,000`. Unaffected: this is a
  free-standing constant threaded through the cache, not derived from
  `kBakeBudgetDevicePixels`, so it does not track production defaults and
  needed no adjustment beyond the bridge.
- `tilesBakedPerFrame: 2` (`test/invariants/tile_budget_test.dart:84` and
  `:273`, "criterion 12: a pan back to reclaimed tiles draws live, not
  blank" and "criterion 12: a frame at the cap still equals the live
  frame"): intent "a budget of exactly two tiles against a 130-tile
  viewport, so eviction and reclaim are forced early." Now
  `bakeBudgetDevicePixels = 8192`, still exactly two tiles at this rig's tile
  size.
- `tilesBakedPerFrame: 3` (`tile_cache_test.dart:60`, "a first frame bakes up
  to its budget and draws the rest live"): intent "budget of exactly three
  tiles, and `bakeCount == 3` is asserted directly." Now
  `bakeBudgetDevicePixels = 12288`, still exactly three tiles.
- `tilesBakedPerFrame: 4` (`tile_cache_test.dart:519`, "the settle spreads
  its bakes across frames"): intent "a small, exact per-frame cap so a
  multi-frame settle is observable." Now `bakeBudgetDevicePixels = 16384`,
  still exactly four tiles.

**Direct field mutations and one direct `TileCache(...)` construction bypass
the bridge and needed manual edits, all in `tile_cache_test.dart`:**

- Line 163, `'the blit hands drawImageRect the same Paint object every time,
  not a call-site-local one'`: `zoomed.cache.bakeBudgetDevicePixels = 4 * 64
  * 64;` (was `tilesBakedPerFrame = 4`). Intent: "exactly four tiles bake on
  the zoom frame under the spy, so the frame contains both a tile blit and
  the carry-over composite blit — two distinct `Paint` objects, not one."
  Preserved exactly: still four tiles at this rig's 64 px size.
- Line 274, `'M17 regression: a bake hands the sink a residual, not a raw
  site-plan-magnitude coordinate'`: `TileCache(tileDevicePixels: 64,
  bakeBudgetDevicePixels: 1000 * 64 * 64)` (was `tilesBakedPerFrame: 1000`).
  Intent: "budget never the limiting factor," same as the `1000` sites above
  — this is the one place a `TileCache` is built directly rather than
  through `TileRig`, for a fixture with a hand-built extreme-magnitude
  camera. Preserved exactly.
- Lines 469, 504, 652, 719, 765 — five occurrences of `rig.cache.tilesBakedPerFrame
  = 0;`, now `rig.cache.bakeBudgetDevicePixels = 0;`, across the tests
  `'a zoom gesture blits the carry-over and bakes nothing'`, `'the gesture
  frame the carry-over serves is not blank'`, `'a whole-document change
  clears the carry-over as well as the tiles'`, `'an edit while a composite
  stands drops it, and the frame repaints'` and `'a table edit drops the
  generation without minting a carry-over'`. Intent in every case: "take the
  budget away after the first frame so the incoming generation bakes
  nothing, isolating what the carry-over composite alone puts on screen."
  `0` is unit-independent — zero device pixels of budget bakes zero tiles
  regardless of tile size — so every one of these is an exact, not
  approximate, preservation.

No test's *number* changed under the rename; every one bakes the same count
of tiles per frame it baked before, verified by running the whole suite (see
section 5) rather than by inspection alone.

## 4. The harness counters (`apps/dev_harness_2d/lib/measurement_rig.dart`)

**Root cause, read from the code rather than assumed.** `DraftPainter.paint`
resets `_screenSpaceLeaves` and `_dashSpans` to zero at the top of every call
(`draft_painter.dart:334,342`); `DraftPainter.collapsedDashCount` reads
`_dasher.collapsedCount`, reset the same way. None of the three accumulate
across calls. Untiled, `paintFrame` never runs and there is exactly one
`paint()` call in the reported frame, so the fields are correct. Under
`TILES=on`, `TileCache.paintFrame` calls `painter.paint` once per tile it
bakes this frame and, when any tile is left uncovered, once more for the
live fallback over the uncovered remainder — and whichever of those ran last
is all three fields describe, not the frame's sum. A frame that bakes most
of its tiles and falls back for a small remainder (which is exactly what
happens at 512 px, where 8 of 12 needed tiles bake in one forced frame and
the live fallback covers only the other 4) therefore prints a leaf count
close to that small remainder — Task 11's `screenSpaceLeafCount=1402`, where
a direct probe of the same frame read the true 4612.

**What is *not* affected, verified by reading the counters' own increment
sites, not assumed by symmetry.** `CanvasDrawSink.canvasCallCount`
(`canvas_draw_sink.dart:83`) and `VerticesDrawSink.frameTriangleCount` /
`totalFlushCount` (`vertices_draw_sink.dart:246-248`) all reset only in their
own `resetCounters()`, called once per rig before the one forced frame that
gets reported — not per `paint()` call — so they correctly sum every bake
plus the live fallback within that frame. `printBackend`'s `triangles=`/
`drawVerticesCalls=` line was not touched, because it was not broken; only
`printInvariants`'s `screenSpaceLeafCount`/`dashSpans`/`collapsed` line
carries the caveat.

**The fix chosen.** Labelling, not accumulation: rewriting `DraftPainter` to
sum across calls would touch a class several other criteria depend on for
its per-call reset behaviour (steady-state allocation and paragraph-cache
tests read it as "this call's work"), which is out of this task's three-line
scope. `printInvariants` now appends a caveat to the
`screenSpaceLeafCount`/`dashSpans`/`collapsed`/`canvasCalls` line whenever a
`tileCache` is passed: `(leaf/dash figures: last paint() call only under
TILES=on, not the frame total -- see the tile probe for a frame figure)`. A
transcript can no longer read a partial number as if it meant the whole
frame.

`printTileCounters`'s own line was updated to match the rename:
`bakePerFrame=${cache.tilesBakedPerFrame}` became
`bakeBudgetPx=${cache.bakeBudgetDevicePixels}`.

## 5. Green

```
CI=true dart test                                                    # packages/jet_cad_2d
797 tests pass, analyze clean, format clean

CI=true flutter test                                                 # packages/jet_cad_2d_flutter
361 tests pass, analyze clean, format clean

CI=true flutter test --tags golden
35 pass

CI=true dart analyze / dart format --output=none --set-exit-if-changed .   # apps/dev_harness_2d
clean, clean

git diff --stat 96cdd56 -- packages/jet_cad_2d_flutter/test/golden
(empty)
```

`git status --short` at the end shows exactly five modified files:
`apps/dev_harness_2d/lib/main.dart`,
`apps/dev_harness_2d/lib/measurement_rig.dart`,
`packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`,
`packages/jet_cad_2d_flutter/test/support/tile_fixture.dart`,
`packages/jet_cad_2d_flutter/test/tile_cache_test.dart`. No
`analysis_options.yaml` and no
`apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj` appear —
neither was touched, and no `flutter drive` ran in this task (Task 11
already produced the sweep; this task was not asked to reproduce it).

## 6. Deviations and concerns

1. **The harness's `TILE_BAKE` default changed value (8 tiles → 1 tile at
   512 px), not just unit.** This is a genuine behaviour change for anyone
   running the harness with `TILE_BAKE` unset, not merely a re-spelling. It
   follows directly from section 2's arithmetic (one tile is the most a
   frame can spend under 16.67 ms at the measured 512 px bake cost), but it
   means a future sweep reproducing Task 11's exact pan-regime numbers must
   pass `TILE_BAKE=2097152` (`8 * 512 * 512`) explicitly rather than relying
   on the default, since the default no longer means "8 tiles."
2. **The new default budget (one tile per frame) was not verified against
   Task 11's pan regime.** Task 11 measured `maxBakesInAFrame=4` at 512 px
   under the *old* 8-tile-count default; this task's own arithmetic shows
   one tile fits comfortably under budget but does not re-run the pan sweep
   to confirm the settle still converges acceptably at one tile per frame
   rather than four. The task brief explicitly excludes re-running the
   device sweep, so this is recorded as an open question for whoever next
   measures the production default's pan behaviour, not as a finding this
   task settled.
3. **The harness counter fix is a label, not a repair.** `printInvariants`
   still cannot report a true per-frame leaf/dash total under `TILES=on`;
   it now says so instead of silently printing a partial number. A future
   task could make these fields genuinely cumulative across a frame (a
   `DraftPainter`-level change), which was judged out of scope here both by
   the task's own three-item brief and by the fields' shared reset
   mechanism serving other criteria that depend on the per-call reset.

## 7. Follow-up: the coordinator's two closing items

**1. Commit.** The five files above were staged explicitly (`git add` on each
path by name, not `-A`) and committed. See the commit message for the "unit
was wrong, not the value" framing the coordinator asked for.

**2. Concern 1 resolved by decision, per instruction — not by re-running the
sweep.**

- `apps/dev_harness_2d/lib/main.dart`'s `kTileBake` already read
  `kBakeBudgetDevicePixels` directly as its fallback (not an arithmetic
  expression derived from it) as of this task's first pass — re-checked and
  confirmed unchanged: `final int kTileBake = _intDefine('TILE_BAKE', ...,
  kBakeBudgetDevicePixels, minimum: 0);`. A reader of `main.dart` already
  sees the exact production constant a default run bakes against, spelled by
  name, not computed.
- **What was missing, and is now added:** the rig did not print the budget
  it ran with, so nothing in a transcript would flag two runs at different
  budgets as incomparable. `TileCache` gained a public getter,
  `budgetedTilesPerFrame` (`lib/src/tile_cache.dart`), computing exactly
  what `paintFrame` itself bakes against
  (`bakeBudgetDevicePixels ~/ (tileDevicePixels * tileDevicePixels)`) —
  `paintFrame` was changed to call this getter instead of duplicating the
  division, so the printed number cannot drift from the number the frame
  path actually used. `printTileCounters`
  (`apps/dev_harness_2d/lib/measurement_rig.dart`) now prints both units on
  the `tiles=on` line: `bakeBudgetPx=${cache.bakeBudgetDevicePixels}
  bakeBudgetTiles=${cache.budgetedTilesPerFrame}`, beside `tilePx=` and the
  rest of the counters it already printed. A transcript now carries its own
  configuration; two runs at different budgets can no longer land in one
  table without a line saying so.
- Verified green after this change: `jet_cad_2d` 797 tests / analyze /
  format clean; `jet_cad_2d_flutter` 361 tests + 35 golden / analyze /
  format clean; `dev_harness_2d` analyze / format clean; golden diff against
  `96cdd56` still empty; `git status --short` still names exactly the same
  five files as section 5, now including this getter and print-line change
  within them.
- Concern 2 (the 1-tile default's pan-settle behaviour, unverified against
  Task 11's sweep) is left exactly as recorded — the coordinator has it for
  the device task and this report does not re-open it. Concern 3 (labelling
  rather than repairing the harness leaf/dash counters) stands as accepted.

## 8. Fix round 1 (Tasks 11 and 11a)

Spec review passed the control's reproduction, `_probeBake`/`_bake` field
parity, and every converted call site's intent; five findings, all addressed.

**I1 — a numerically valid `TILE_PX` could silently disable tiling.**
`budgetedTilesPerFrame` (`tile_cache.dart`) truncated, so any
`tileDevicePixels` whose area exceeds `bakeBudgetDevicePixels` divided to
zero -- `TILE_PX=1024` under the harness's default budget, accepted by
`minimum: 1`, would run the whole life on the live-walk fallback while still
printing `tiles=on`. **Clamped, not rejected**: the getter now floors at one
tile whenever the budget is positive (`bakeBudgetDevicePixels > 0 && tiles ==
0 ? 1 : tiles`), leaving `0` alone -- that value is the zoom-path tests'
deliberate "bake nothing" configuration and must stay reachable. The doc
comment states the floor and its reason. Two new tests
(`tile_cache_test.dart`): `budgetedTilesPerFrame floors a nonzero budget at
one tile, never zero` (the getter, both branches) and `a tile larger than
the default budget still bakes one, not none` (a real `paintFrame` at
`tileDevicePixels: 1024` under `kBakeBudgetDevicePixels`, asserting
`bakeCount >= 1`). Both were run against the pre-fix getter and failed
(confirmed live, not asserted) before the fix landed, and pass after.

**I2 — the control transcript's tree was unnamed.** `task-11-report.md`
prints `tiles=off` (needs `TILES`) with no `mean=` (needs `report()`'s mean
column) in one transcript, and both features landed together in `96cdd56` --
so no single commit's tree reproduces that exact shape; it was run against
an uncommitted mid-development snapshot. Added one paragraph to section 2
naming this precisely, including that it is not a synthesised transcript and
that the sweep transcripts from section 4 on (all post-`96cdd56`) remain
reproducible against that commit.

**I3 — 12.56 ms rests on fourteen bake events.** Added to
`kBakeBudgetDevicePixels`'s doc comment: `bakes=14 perFrame=0.117` from the
512 arm of the pan phase, the repeat run that confirmed reproducibility was
taken at 256 and never at 512, and the 2.59 ms (about 16%) margin to the
16.67 ms budget. Not re-measured, per instruction.

**M4 — stale 256 px production-tile prose.** `kTileSlack`'s "what it costs"
paragraph: "a quarter of a tile wide" at the ring's width corrected to "an
eighth" (`kScreenClipInflate` 32 logical px / 256 logical px at 512 device px,
`dpr` 2). `kTileCacheBytes`'s "38.5 MiB at 256 px" corrected to "48.0 MiB at
512 px", matching the figure already cited in `kTileDevicePixels`'s own
comment.

**M5 — the caveat implicated `canvasCalls`.** `printInvariants`'s tiled
caveat (`measurement_rig.dart`) now names the three affected fields --
`screenSpaceLeafCount`/`dashSpans`/`collapsed` -- and states `canvasCalls` is
unaffected, rather than the ambiguous "leaf/dash figures".

Green after all five: `jet_cad_2d` 797 tests / analyze / format clean;
`jet_cad_2d_flutter` 363 tests (361 + 2 new) + 35 golden / analyze / format
clean; `dev_harness_2d` analyze / format clean; golden diff against
`96cdd56` empty. `git status --short` names exactly three tracked files this
round: `apps/dev_harness_2d/lib/measurement_rig.dart`,
`packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`,
`packages/jet_cad_2d_flutter/test/tile_cache_test.dart` (`task-11-report.md`
is git-ignored, per `.superpowers/sdd/`'s own rule, so its I2 edit carries no
tracked diff).
