# Fix wave A — the tile cache, its instruments, and the mutation log

Two Major production defects from Plan 3i's final whole-branch review, plus the
test-side findings in the same package. **Everything here is confined to
`packages/jet_cad_2d_flutter/` and `docs/superpowers/notes/plan-3i-mutation-log.md`.**
A parallel wave is working in `apps/dev_harness_2d/` — do not touch that
directory, and do not touch `packages/jet_cad_2d` at all.

All findings below were **independently verified from source by the
controller**. They are real. Do not re-litigate whether they exist; if your own
reading disagrees with one, say so in your report and fix the others.

## Binding constraints

- **Never commit `analysis_options.yaml`** — `flutter pub get` rewrites three of
  them in this workspace. Stage named paths only; never `git add -A` at the
  repo root.
- **Never synthesize test output.** Paste only transcripts you actually ran.
- **Never `git checkout` a file** — blocked here. Revert by `cp` from a backup,
  and `diff` to prove the restore is clean.
- **Prefix every test command with `CI=true`** — otherwise Dart's analytics
  phone-home blocks the runner for minutes at ~0% CPU.
- **`package:jet_cad_2d` is pure Dart** — no Flutter, no `dart:ui`. Do not touch it.
- `unused_import` and `unused_element` are **ERRORS** in `packages/jet_cad_2d_flutter`.
- **No pre-existing golden PNG may be regenerated.**
- **The frame path allocates nothing per entity in steady state, and O(1) per
  flush** — `test/invariants/paint_allocation_test.dart` measures it.
- **Geometric *decisions* use `Tolerance`; *stored value* comparisons are exact `==`.**
- Code and comments in English.

---

## MAJOR 1 — a pan straight after a zoom draws only the stale composite, for the whole pan

**This is a behavioural regression against the spec's D8 ("the pan path is
untouched"), and it is the most important thing in this brief.**

The verified chain:

1. `tile_cache.dart:1026-1028` computes `resting` from `_restGateSteps` alone.
   It never consults `grid.matchesScale(quantised)` — which is what spec D1
   defines *moving* by.
2. `tile_cache.dart:1068-1075` then returns unconditionally, **without
   consulting `carryOverCovers`** — unlike the resting path at `:1161`, which
   does.
3. `CameraController.panBy` (`camera_controller.dart:40-46`) copies `a,b,c,d`
   bit-identically, so `TileGrid.matchesScale` holds and `_gridFor`
   (`:1541-1558`) returns the existing grid **without retiring**. So
   `_carryOver`, minted by the preceding zoom step, **survives the pan**.
4. Camera changed ⇒ `_restGateSteps = 0` ⇒ `resting == false` ⇒ the composite
   is blitted at the panned position and the method returns. No tile blit, no
   live walk. `_tiles` stays empty for the whole pan.

Frame sequence at production defaults: settled generation covers → one zoom
step (composite minted, tiles disposed) → **pan at the same scale** → the
composite translates off the leading edge and nothing fills behind it. It
self-heals only once the camera holds still for `kRestGateFrames` frames. A
macOS trackpad reaches this directly: any stretch of a gesture where the pan
continues after the scale stops changing.

Before Plan 3i, the same frame took `uncovered` = the whole viewport, found
`carryOverCovers == false`, and paid a full-viewport live walk — expensive, but
**correct pixels**.

**Fix it so a moving frame whose composite does not cover the viewport falls
through to the ordinary bake-and-live-walk path**, the same way the two
`resting` disjuncts at `:1026-1028` already do for the "nothing to show" cases.
The spec's D3 accepts a background ring **for zoom-out only**; it does not
accept an unfilled pan. Do not weaken the zoom-out behaviour to get there — a
zoom *in* magnifies the composite past the viewport edges, `carryOverCovers` is
true, and that frame must stay cheap.

**Prove it with a test and a mutant.** Write a widget test that drives exactly
the sequence above — settle, one `zoomAt`, then `panBy` at the same scale for
several frames — and asserts the revealed region is not background: assert on
ink or on `liveDrawCount`/tile coverage, not on a flag. Fire it as **M17**:
restore the unconditional early return, watch the test go RED, restore by `cp`,
watch it go GREEN. Paste both real transcripts.

## MAJOR 2 — one missing tile makes `_restBake` walk *every* band and discard all but the ones it needed

`tile_cache.dart:1228-1235` computes a single **frame-global** `missing`
boolean over all visible keys. The loop at `:1274` then calls `_bakeBand`
(`:1285`) unconditionally for each band. The per-key
`if (_tiles.containsKey(key)) … continue` at `:1309` skips only the **slice** —
so a band whose keys are all already held still pays a full painter walk,
`_recordOwners` over its whole visit list, a `toImageSync`, and a `_bakes++`,
and then throws the image away at `:1324`.

Reachable on the ordinary edit path, not an edge case: after any `applyChange`
the camera is unchanged, so `_restGateSteps >= kRestGateFrames` still holds and
`_carryOver` was just dropped, so the next frame rest-bakes. `_invalidateTouched`
typically condemns tiles in one band; the other bands are walked and discarded.
A drag pays this every frame — roughly one whole-viewport walk (~32 ms at
500,000 entities, the spec's own figure) where the pre-3i path paid one tile
bake plus a strip walk.

`_restBake`'s own doc comment at `:1211-1218` states exactly this reasoning
("Rebaking those would replace good images with identical ones … and pay a full
walk for nothing") — but applies it only at whole-frame granularity.

**Fix: make the probe per-band.** A band all of whose keys are present is
skipped entirely — no `_makeRoomForBytes`, no `_bakeBand`, no `_bakes++`.
Keep the frame-global early-out as well if it still helps; the point is the
per-band one. **Careful:** the up-front budget arithmetic at `:1259` and the
"all-or-nothing" reasoning around `_dropCarryOver()` at `:1272` were written
assuming every band bakes. Re-derive that reasoning for the skipping version
and say in your report why the ceiling still holds — the reviewer confirmed the
current proof is "at band *i* the un-evictable set is exactly the keys of bands
`0..i-1`". Do not break it.

**Prove it with a test and a mutant.** Assert that a rest bake following an
edit that touches one band bakes **one** band, not all of them — assert on
`bakeCount` (band units on this path) or on a per-band probe, and make the
fixture span several bands so the assertion has room to fail. Fire as **M18**:
restore the frame-global probe, watch it go RED, restore, GREEN. Paste both.

## MINOR — a throw inside the band loop leaks the band and strands `_band`

`tile_cache.dart:1287` assigns `_band = image`; `:1323-1324` clears and disposes
it, with no `try`/`finally` between. Anything throwing in `_recordOwners`
(`:1294`) or `_sliceTile` (`:1318`) leaks the image **and** strands `_band`
non-null, so `liveBytes` (`:731-737`) overstates by a band for the cache's life
and `_makeRoomForBytes` over-evicts forever. `dispose()` (`:2251-2256`) does not
clear `_band` either. Not reachable through any non-throwing path today.

Wrap the body so the band is always released, and clear `_band` in `dispose()`.

## MAJOR — criterion 7's headline assertion cannot fail

`test/invariants/tile_bytes_test.dart:39-40`:
`expect(h.cache.liveBytes, lessThanOrEqualTo(kTileCacheBytes))` runs on a
fixture whose entire peak is 130 tiles × 16 KiB + one 832×64 band =
**2,342,912 bytes** against `kTileCacheBytes` = **100,663,296** — 43× headroom.
No mutation to the rest bake can move `liveBytes` far enough to trip it.
**M6** (delete `_disposeImage(image)` in `_restBake`) leaves ten band images
alive, ~4.2 MB — still three orders below the cap; the log confirms M6 died on
`debugImagesAlive` at `:59`, not on this clause.

The lower bound at `:47` (M6b) and the `debugImagesAlive` equality at `:59` are
the only load-bearing clauses. The ceiling clause is decoration, and no test
anywhere observes the rest-frame ceiling at a cap that could bind:
`tile_regime_test.dart:93` sets `cacheBytes = 8 * 64 * 64 * 4` precisely so the
rest bake *declines*, and `tile_budget_test.dart`'s small-cap arms never reach a
rest frame.

**Fix: give the ceiling a cap that can actually bind.** Add an arm at a
`cacheBytes` large enough that the rest bake proceeds but small enough that the
band plus the tiles approaches it, and assert the ceiling there — inside
`debugOnSliceForTest`, so it is observed *during* the frame, which is what
criterion 7 says ("at every point inside the rest frame"). Then **re-fire M6
against your new arm** and confirm it dies there too; record that in M6's log
section as an added gate rather than rewriting its history.

## MAJOR — `a` and `d` in `sameQuantisedCamera` are each individually deletable

`tile_cache.dart:239-245` compares six fields. `test/tile_regime_test.dart:8-9`'s
`at()` helper builds `Transform2(scale, 0, 0, -scale, e, f)`, so **every fixture
in the file ties `d` to `-a`**; the only other caller,
`tile_zoom_warmth_test.dart:221`, compares two `zoomAt` results where both terms
move together. Deleting `x.a == y.a &&` leaves the `d` comparison firing;
deleting `x.d == y.d &&` is symmetric. The suite stays green in both cases.

This is the **M12 defect one field over** — recorded as a Task 1 deferred minor
("`a` and `d` are correlated in every fixture (`d == -a`), so deleting either
check alone survives") and never closed by either batch pass.

**Fix: add a fixture where `a` and `d` are independent** (an anisotropic scale,
`d != -a`) and assert both directions. Fire as **M19a** (delete `x.a == y.a &&`)
and **M19b** (delete `x.d == y.d &&`); both must go RED. Paste both transcripts.

The same degeneracy holds for `TileGrid.matchesScale` at `:274-278`, where `b`
and `c` are 0 in every tiled fixture. **Close that one too if the same fixture
reaches it**; if it does not, say so in your report rather than leaving it
silently open.

## MINOR — arm 4 of the slice differential does not pin the slice path

`test/tile_slice_differential_test.dart:77-123`. Arms 1, 2 and 5 go through
`settleFromBands`, which pins `slices == liveTileCount`. Arm 4's **second**
settle (after the zoom and the pan) asserts only `hasCarryOver isFalse` and
`differingPixels == 0`. It is sound today only because `_restBake` runs ahead of
the budgeted loop at `tile_cache.dart:1088` — a property of statement order in
`paintFrame`, not of anything this test checks. If the budgeted loop ever filled
first, arm 4 would go green with zero tiles cut from a band and **M10**
(`sliceSourceRect` dropping `- band.deviceRect.left`) would survive silently.

Add a `slices` count around the final settle.

## MINOR — a test that asserts a constant's own value

`test/tile_regime_test.dart:162-166`: `expect(kRestGateFrames, 2)`. Harmless —
the behaviour is genuinely gated by "a steadily spun wheel never arms the rest
gate" at `:135-160`, which reddens under M4b — but it is a restatement, not an
instrument, and its name ("the gate needs two unchanged frames, not one") claims
more than it measures. Either rename it to what it asserts or fold it into the
behavioural test.

## MINOR — mutation log record-integrity fixes

`docs/superpowers/notes/plan-3i-mutation-log.md`:

1. **M4b (`:144-183`) carries a stale kill number, in value and in unit.** It
   was fired at Task 3, before Task 8 introduced `_restBake`, so `bakeCount`
   then meant *tiles* and the transcript reads `Actual: <384>` (6 notches × the
   64-tile budget), with prose "384 tiles". Re-derived against HEAD: with the
   constant at 1, `_restBake` runs after each notch and `_bakes` increments
   **once per band** — 6 × 10 = **60**, and bands, not tiles. **The mutation
   still kills**, so this is a record-integrity correction, not a dead gate.
   Annotate; do not fabricate a new transcript for it.
2. **The staleness note at `:11-27` annotates only M2, M6 and M6b.** M1, M4 and
   M4b also predate both the `Center` fix and the band bake. M1's `512` and
   M4's `512`/`768` re-derive **unchanged** (both budget-limited on either
   canvas) — state that, because a reader currently cannot tell which of the
   three survived the refactor.
3. **M7 (`:697-701`) and M9 (`:735-737`) attribute their pixel counts to the
   wrong arms.** M7's prose says "arm 2 (3,780…) and arm 3 (8,692)", while its
   own transcript shows 8,692 against *"and stays identical after a pan smaller
   than one tile"* and 3,780 against *"and when a pan lands between the scale
   change and the bake"* — swapped. M9's prose says "3,475 on the tile-edge
   sweep", while the transcript shows 3,475 against *"and at a camera on a
   power-of-two rebase boundary"* and 8,196 against the tile-edge sweep. The
   kills stand; the attributions do not. Correct the prose to match the
   transcripts, which are the record.

Add sections for **M17, M18, M19a, M19b** in the format the existing entries
use — read two of them first.

---

## Gate — run every command and paste the real tail of each

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && dart format --output=none --set-exit-if-changed .
cd packages/jet_cad_2d && CI=true dart test && CI=true dart analyze && dart format --output=none --set-exit-if-changed .
cd apps/dev_harness_2d && CI=true flutter test --concurrency=1
```

Baselines at HEAD `9206743`: `packages/jet_cad_2d` **797**, `packages/jet_cad_2d_flutter`
**405** with **1 skip**, `apps/dev_harness_2d` **23**. Analyze and format clean.
A count that drops is a regression. The harness suite is run only to prove you
did not break it — a parallel wave owns that directory, so if it is red because
of *their* in-flight change, say so rather than fixing it.

**The two Majors change production behaviour in the paint path.** Expect
existing tests to move, and treat any assertion value that changes as a finding
to explain in your report, not a number to update quietly.

Commit in logical pieces, each green on its own.
