# Fix wave A — report

**Base:** `9206743`. **Commits:** `1a46886`, `ca0638f`, `c5794d7`.
Scope respected: `packages/jet_cad_2d_flutter/` and
`docs/superpowers/notes/plan-3i-mutation-log.md` only. `apps/dev_harness_2d/`
was run and never edited; `packages/jet_cad_2d` untouched. No
`analysis_options.yaml` staged, no `git checkout`, no `git add -A`; every
mutation restored by `cp` from a scratchpad copy with an empty `diff`.

**One collision worth knowing about up front:** the parallel wave commits to
this same branch and to this same mutation log. It had already landed an
**M20** (`7567619`, "the settle reads the frame before the one that covered")
before I wrote mine, so my ceiling mutant is numbered **M21** and the log now
carries a note that numbering in that file is shared between the two waves.

---

## MAJOR 1 — a pan straight after a zoom drew only the stale composite

**Confirmed, and the chain in the brief is exactly right.** One correction to
the mechanism, which changed the shape of the fix:

`grid.matchesScale(quantised)` **cannot** be consulted where `resting` is
computed, because it is true by construction there. `_gridFor` returns the
standing grid when the scale matched and otherwise anchors a fresh grid *at
this camera* — so after it returns, `matchesScale` holds on every frame,
moving or not. D1's question ("does the quantised scale fail `matchesScale`
against the **current generation's** anchor") can only be asked against the
generation the frame *arrived at*. So the frame now captures `_grid` before
the call and derives:

```dart
final incoming = _grid;
final grid = _gridFor(quantised, devicePixelRatio, viewport);
final scaleChanged = !identical(incoming, grid);
```

Identity, not `matchesScale`, so a device-pixel-ratio or tile-size change —
which also re-anchors — counts as the scale change it is.

**The fix**, one disjunct in `resting`:

```dart
final resting = previous == null ||
    _carryOver == null ||
    (!scaleChanged && _restGateSteps == 0) ||   // <- new
    _restGateSteps >= kRestGateFrames;
```

**Why the condition is not `!carryOverCovers`, which is how the brief phrases
it.** Falling through whenever the composite fails to cover would break D3: a
zoom *out* shrinks the composite, `carryOverCovers` is false, `uncovered`
bounds to the whole viewport, and every zoom-out frame would pay the
31.5–41.6 ms full-viewport live walk that D3 exists to refuse. The property
that separates "the accepted zoom-out ring" from "an unfilled pan" is not
coverage — it is whether the scale changed. So the fall-through is keyed on
`!scaleChanged`, which is D1's own definition of *moving*, and the zoom-out
frame keeps its early return with its ring.

**Why `_restGateSteps == 0` is in there.** D1's third frame kind — matched
once, not yet twice — must keep drawing what a moving frame draws, or a wheel
notch lands one full-viewport live walk per notch (the spec says so in as many
words). That frame is one whose camera did *not* change, so it carries a count
of at least 1; a pan frame changed the camera and reset the count to 0.
Reading the count rather than the camera keeps the wheel's in-between frame
cheap. `repaintOnce`'s zero pan is likewise a count of ≥ 1, not a pan.

Costs of the fix, stated plainly: a same-scale pan over an **empty**
generation (i.e. straight after a zoom out) now pays a live walk over the
uncovered region while it fills, which is exactly what the pre-3i path paid
and what the brief asks for — expensive, correct pixels. A pan over a covered
generation is unchanged: thin strip, one tile bake, D8 intact.

**Test:** `tile_regime_test.dart` → `a pan after a zoom fills the region the
composite slides off`. Settle, one `zoomAt(1.3)` (asserting the composite was
minted and every tile retired), then four `panBy(-40, 0)` frames at the same
scale. Asserts `bakeCount > 0` and `liveTileCount > 0`, then captures the
tiled frame and asserts **ink** in the strip the composite has slid off —
`Rect.fromLTRB(324, 0, 400, 300)`, derived from `120 + 1.3 * 280 - 160 = 324`
— with the live capture's ink in the same strip as the non-vacuity clause. New
helper `inkInsideCapture` in `support/tile_comparison.dart` (the existing
`inkInside` works on a `TileRig`'s `Uint8List`, not on a widget capture's
`ByteData`).

**Fired as M17.** Transcript below.

## MAJOR 2 — one missing tile made `_restBake` walk every band

**Confirmed.** The probe is per band now. A band all of whose keys are present
is skipped entirely: no `_makeRoomForBytes`, no `_bakeBand`, no `_bakes++`.
The frame-global probe is **kept** ahead of `bandsFor`, as the brief allows —
it answers the common case (a rest frame over a whole generation) without
building the band list — and its comment now says explicitly that it is not
the probe that decides what bakes.

**Why the ceiling proof still holds, re-derived.** The proof is "at band `i`
the un-evictable set is exactly the keys of bands `0..i-1`", and it holds
because every key of those bands carries this frame's serial — written either
by a slice or by the `containsKey` branch that touches recency. A band skipped
*without* that touch would leave its keys evictable by a later band's
`_makeRoomForBytes`, and the frame would blit a hole in a row it had already
decided it owned. **So a skipped band still stamps every one of its keys with
`_frameSerial`** — one map write per key and nothing else. With that, the
un-evictable set at band `i` is bit-for-bit what it was before, the up-front
pricing (`bandBytes + visibleTiles * _tileBytes > cacheBytes`) is unchanged
and still conservative, and the peak is strictly *lower* than the proof
assumes, because a skipped band's image is never allocated. The
all-or-nothing reasoning around `_dropCarryOver()` is likewise unaffected: the
pricing that licenses the drop covers every visible tile whether its band
bakes or is skipped, and a skipped band's tiles are already resident, which is
the strongest form of "covered".

**Test:** `tile_regime_test.dart` → `an edit inside one band rebakes that band
alone`. It measures its own control first — a whole-generation drop at the
same camera bakes `allBands` (10) — then does one edit and asserts 3.

**Three, not one, and the three are derivable.** Direction one of invalidation
condemns every tile whose `_baked` record names the handle, and a sliced
tile's record is its whole band's (D6). A band's query is padded by
`kTileSlack`, which is `kScreenClipInflate` = 32 logical pixels = **exactly
one tile row** at this harness (64 device px, dpr 2). So a leaf resting in row
4 is visited by the walks for rows 3, 4 and 5 and named in all three records.
Measured: 39 tiles condemned = 3 × 13. The assertion is stated twice on
purpose — the exact `3` pins the pad's reach, and a second
`lessThan(allBands)` clause is the one that fails if the frame-global probe
ever comes back. New harness helper `moveOneEntityWithinOneBand()` (screen
(300, 144), same row as `kMovableHandle`'s resting position).

A second test, `a skipped band keeps its tiles out of the ceiling's reach`,
pins the recency touch: zero evictions across the edit, and `liveTileCount`
back to exactly what it was.

**Fired as M18.**

## MINOR — a throw inside the band loop leaked the band and stranded `_band`

Fixed. The body from `_recordOwners` through the slice loop is wrapped so that
`_band = null; _disposeImage(image);` runs on every exit, throw included.
`dispose()` also clears `_band` — belt and braces, and stated as such in the
comment, since the `finally` already guarantees it; the reason it is worth the
line is that `liveBytes` *reads the field*, so a disposed cache would
otherwise still report a band's worth of bytes. Not separately mutated: no
non-throwing path reaches it, so any mutant would be equivalent under test.

## MAJOR — criterion 7's headline assertion could not fail

**Confirmed, and worse than "43x headroom": no cap can make that clause catch
M6.** `liveBytes` sums `_tiles`, `_carryOver` and the image currently in
`_band` — and `_band` is reassigned at the top of every band iteration, so an
image the loop failed to dispose stops being counted the moment the next band
starts. M6 is invisible to `liveBytes` at any cap; `debugImagesAlive` is its
gate and always was. That is recorded in M6's section as a finding rather than
as a gate.

**New arm:** `the ceiling binds inside the rest frame, and eviction holds it`.
Settle (130 tiles), pan by (-96, -96) so the map holds the visible set *plus*
a tail of stale keys (190), two `repaintOnce`es to arm the rest gate (a
three-tile pan is covered by the budgeted loop on the pan frame itself, so the
canvas stops asking for frames with the gate at zero — asserted, not assumed),
one edit, one pump for the change to reach the cache, then the cap is priced
off what the cache is *then* holding: `cap = bandBytes + tilesHeld *
tileBytes`. Large enough that `_restBake`'s pricing (one band plus the
*visible* set) proceeds; tight enough that the first `_makeRoomForBytes` must
reclaim before the band image can exist and every slice must reclaim again
before its tile can. Measured: **12 slices, 12 evictions, and a peak of
exactly `cap`** (3,031,040). The ceiling is asserted inside
`debugOnSliceForTest` — during the frame, which is what criterion 7 says — and
a `peak > cap - 2 * tileBytes` clause asserts that the cap is one the frame
actually reaches, so the ceiling clause cannot silently go slack again.

**M6 re-fired against the new arm: red there too**, on `debugImagesAlive`
(176 against 172 — four leaked band images), recorded in M6's section as an
added gate rather than a rewrite. **And the new arm has its own mutant, M21**
— delete `if (!_makeRoomForOneTile()) break;` from the slice loop — which dies
on the ceiling clause itself, one tile over the cap, thrown from inside
`paint()`.

## MAJOR — `a` and `d` in `sameQuantisedCamera` each individually deletable

Confirmed and closed with `the two scale terms are compared independently`, an
anisotropic fixture (`d != -a`) with one arm per term plus an equality clause
for non-vacuity. Fired as **M19a** and **M19b**; both red, and — the point —
`a scale change compares different` stays green under both.

**`TileGrid.matchesScale` had the same degeneracy and it is now closed too.**
The `sameQuantisedCamera` fixture does *not* reach it (different function,
different callers), so it needed its own: `awkwardCamera` has `d == -a` and
`b == c == 0`, and the existing arm nudges `a` alone, so deleting the `b`, `c`
or `d` comparison killed nothing. Added `every scale term is compared, one at
a time` in `tile_grid_test.dart` — anisotropic *and* skewed, one arm per
field, plus the clause that a pan is **not** in this comparison. Fired as
**M19c** (`d`), **M19d** (`b`) and **M19e** (`c`); all three red.

## MINOR — arm 4 of the slice differential did not pin the slice path

Fixed: `slices` is counted around the final settle and asserted `> 0`.
Measured **66 of 130** — the other 64 are the pan frame's own budgeted bakes,
which is a consequence of Major 1's fix (before it, that pan frame baked
nothing and the settle sliced the lot). The arm still exercises the slice path
over half the viewport at the negative key range M10 needs.

## MINOR — a test that asserts a constant's own value

Renamed `the gate needs two unchanged frames, not one` →
**`the gate is two unchanged frames, and the constant says so`**, with a
comment pointing at `a steadily spun wheel never arms the rest gate` as the
behavioural gate (the one that reddens under M4b). The rename is recorded in
M4b's log entry so its transcript stays findable.

## MINOR — mutation log record-integrity

All three done, no transcript fabricated.

1. **M4b** annotated: `384` was tiles, at Task 3, before `_restBake` existed;
   re-derived at HEAD it is 6 notches × 10 bands = **60**, and the unit is
   bands. The mutation still kills. (Fix wave A's per-band probe does not move
   the number either: after a retire the generation is empty, so every band is
   missing and every band bakes.)
2. **The staleness note** gained a second paragraph covering M1, M4 and M4b:
   M1's `512` and M4's `512`/`768` re-derive **unchanged**, because both are
   `budgetedTilesPerFrame` × frames (64 × 8 and 64 × 12) and 475 tiles and 130
   tiles both exceed 64, so both canvases are budget-limited. M4b's does not,
   per (1).
3. **M7 and M9** rewritten to name their arms instead of numbering them —
   the file's arms have been counted two different ways, which is how the
   swap survived — with a correction note in each saying what the prose said
   and what the transcript says. The kills stand; the attributions did not.

## Assertion values that moved

One, and it is Major 1's fix showing up where the brief predicted:

`tile_budget_test.dart`, `criterion 12: a ceiling smaller than the composite
bakes nothing rather than overrun it` — `liveDrawCount` **1 → 2**. The arm
does `panBy(-64, -32); paintOnce(); settle()` with a composite standing and a
four-tile ceiling. Before the fix the pan frame took the moving-frame early
return and drew nothing, leaving one live walk on the rest frame at the end.
The pan is a pan, not a zoom, so it now falls through and pays its own walk
over a viewport the shrunken ceiling cannot tile — which is the fix, and the
test's own comment already said "the pan is what owes the live walk". The
other assertions in that arm (`hasCarryOver`, `liveBytes == _compositeBytes`,
`liveTileCount == 0`, `bakeCount == 0`) are unchanged, so the "bakes nothing
rather than overrun" claim it exists for is untouched.

Nothing else moved. No golden PNG regenerated.

---

# Mutations fired

Nine, all red, all restored by `cp` with an empty `diff` and re-run green.
Full mutations, procedures and verbatim transcripts are in
`docs/superpowers/notes/plan-3i-mutation-log.md` under "Fix wave A opens
here"; the failure clauses are reproduced here.

| # | Mutation | Gate | Result |
|---|---|---|---|
| M17 | delete the pan disjunct from `resting` | `a pan after a zoom fills the region the composite slides off` | **died** |
| M18 | delete the per-band probe | `an edit inside one band rebakes that band alone` | **died** |
| M19a | delete `x.a == y.a &&` | `the two scale terms are compared independently` | **died** |
| M19b | delete `x.d == y.d &&` | same | **died** |
| M19c | drop `a.d == b.d` from `matchesScale` | `every scale term is compared, one at a time` | **died** |
| M19d | drop `a.b == b.b` | same | **died** |
| M19e | drop `a.c == b.c` | same | **died** |
| M21 | delete `_makeRoomForOneTile()` from the slice loop | `the ceiling binds inside the rest frame, and eviction holds it` | **died** |
| M6 (re-fire) | delete `_disposeImage(image)` | the new ceiling arm | **died**, on `debugImagesAlive` |

**M17**

```
00:00 +8: a pan after a zoom fills the region the composite slides off
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: a value greater than <0>
  Actual: <0>
   Which: is not a value greater than <0>
a pan is not a moving frame (spec D1 defines moving by the scale) and D8 leaves the pan path baking
at its edge

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart:231:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart line 231
The test description was:
  a pan after a zoom fills the region the composite slides off
════════════════════════════════════════════════════════════════════════════════════════════════════
00:00 +8 -1: a pan after a zoom fills the region the composite slides off [E]
  Test failed. See exception logs above.
  The test description was: a pan after a zoom fills the region the composite slides off
  
00:00 +8 -1: an edit inside one band rebakes that band alone
00:00 +9 -1: a skipped band keeps its tiles out of the ceiling's reach
00:00 +10 -1: the gate is two unchanged frames, and the constant says so
00:00 +11 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart: a pan after a zoom fills the region the composite slides off
```

Restored, `diff` empty, re-run:

```
00:00 +10: a skipped band keeps its tiles out of the ceiling's reach
00:00 +11: the gate is two unchanged frames, and the constant says so
00:00 +12: All tests passed!
```

**M18**

```
00:00 +9: an edit inside one band rebakes that band alone
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: <3>
  Actual: <10>
only the bands the edit condemned owe a walk; the other 7 hold every key they need, and rebaking
them replaces good images with identical ones -- a whole-viewport walk for three rows, on every
frame of a drag

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart:313:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart line 313
The test description was:
  an edit inside one band rebakes that band alone
════════════════════════════════════════════════════════════════════════════════════════════════════
00:00 +9 -1: an edit inside one band rebakes that band alone [E]
  Test failed. See exception logs above.
  The test description was: an edit inside one band rebakes that band alone
  
00:00 +9 -1: a skipped band keeps its tiles out of the ceiling's reach
00:00 +10 -1: the gate is two unchanged frames, and the constant says so
00:00 +11 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart: an edit inside one band rebakes that band alone
```

Restored, `diff` empty, `+12: All tests passed!` on the same file.

**M19a**

```
00:00 +3: the two scale terms are compared independently
00:00 +3 -1: the two scale terms are compared independently [E]
  Expected: false
    Actual: <true>
  x scale alone, with y held: a generation anchored at one x scale cannot blit at another
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_regime_test.dart 49:5                     main.<fn>
  
00:00 +3 -1: the skew terms are compared too
00:00 +4 -1: a moving frame bakes nothing and walks nothing
00:00 +11 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart: the two scale terms are compared independently
```

**M19b**

```
00:00 +3: the two scale terms are compared independently
00:00 +3 -1: the two scale terms are compared independently [E]
  Expected: false
    Actual: <true>
  y scale alone, with x held
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_regime_test.dart 53:5                     main.<fn>
  
00:00 +11 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart: the two scale terms are compared independently
```

Both restored, `diff` empty, `+12: All tests passed!`.

**M19c / M19d / M19e**

```
00:00 +7: TileGrid matchesScale is exact, not tolerant
00:00 +8: TileGrid every scale term is compared, one at a time
00:00 +8 -1: TileGrid every scale term is compared, one at a time [E]
  Expected: false
    Actual: <true>
  d: the y scale, which every tiled fixture ties to -a
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_grid_test.dart 193:7                      main.<fn>.<fn>
  
00:00 +8 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_grid_test.dart: TileGrid every scale term is compared, one at a time
```

```
  Expected: false
    Actual: <true>
  b: a generation baked without this shear cannot blit with it
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_grid_test.dart 182:7                      main.<fn>.<fn>
  
00:00 +8 -1: Some tests failed.
```

```
  Expected: false
    Actual: <true>
  c: the other shear term
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_grid_test.dart 188:7                      main.<fn>.<fn>
  
00:00 +8 -1: Some tests failed.
```

Each restored, `diff` empty, `+9: All tests passed!`.

**M21**

```
00:00 +2: the ceiling binds inside the rest frame, and eviction holds it
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following TestFailure was thrown during paint():
Expected: a value less than or equal to <3031040>
  Actual: <3047424>
   Which: is not a value less than or equal to <3031040>
criterion 7, at a cap that can be reached: the band image is resident here and the meter counts it

The relevant error-causing widget was:
  CustomPaint
  CustomPaint:file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart:359:16
[stack trace elided]
00:00 +2 -1: the ceiling binds inside the rest frame, and eviction holds it [E]
  Test failed. See exception logs above.
00:00 +2 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart: the ceiling binds inside the rest frame, and eviction holds it
```

Restored, `diff` empty:

```
00:00 +1: the ceiling holds at every point inside the rest frame
00:00 +2: the ceiling binds inside the rest frame, and eviction holds it
00:00 +3: All tests passed!
```

**M6, re-fired against the new arm** — red on both arms of the file, each on
its `debugImagesAlive` cross-check:

```
00:00 +1: the ceiling holds at every point inside the rest frame
The following TestFailure was thrown running a test:
Expected: <130>
  Actual: <141>
no band image outlives its band, and the composite was dropped before the bake
[stack trace elided]
The test description was:
  the ceiling holds at every point inside the rest frame

The following TestFailure was thrown running a test:
Expected: <172>
  Actual: <176>
no band image outlives its band here either
[stack trace elided]
The test description was:
  the ceiling binds inside the rest frame, and eviction holds it

00:00 +1 -2: Some tests failed.
Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart: the ceiling binds inside the rest frame, and eviction holds it
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart: the ceiling holds at every point inside the rest frame
```

Restored, `diff` empty, `+3: All tests passed!`.

---

# Gate — run at `c5794d7`, on the restored tree

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test
00:07 +410 ~1: .../test/tile_measurement_seam_test.dart: debugFullViewportQuery grows the fallback walk to the whole viewport
00:07 +411 ~1: All tests passed!

$ CI=true flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.2s)

$ dart format --output=none --set-exit-if-changed .
Formatted 73 files (0 changed) in 0.14 seconds.

$ cd packages/jet_cad_2d && CI=true dart test
00:03 +797: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +797: All tests passed!

$ CI=true dart analyze
Analyzing jet_cad_2d...
No issues found!

$ dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.20 seconds.

$ cd apps/dev_harness_2d && CI=true flutter test --concurrency=1
00:16 +40: .../test/zoom_script_test.dart: the focal point is off-centre
00:16 +41: All tests passed!
```

**Counts against the brief's baselines.** `packages/jet_cad_2d` **797**,
unchanged. `packages/jet_cad_2d_flutter` **405 → 411**, 1 skip throughout —
six added: the pan-after-zoom test, the one-band rest bake, the skipped band's
recency, the two scale terms, every scale term, and the binding-cap ceiling
arm. `apps/dev_harness_2d` **23 → 41**, none of them mine: the parallel wave
added them and the suite is green.

---

# Concerns

1. **The mutation log is a shared file and the two waves collided on it.**
   `M20` was taken by the parallel wave (`7567619`) while I was working, so my
   ceiling mutant is `M21`. My edits to that file were append-only after the
   three correction patches, and the file was clean in `git status` at each
   write, but a wave that read the file before mine landed and rewrites it
   wholesale will silently drop my sections. Worth a controller check that
   `c5794d7`'s additions survive to the merge.
2. **Major 1's fix does not restore pre-3i behaviour on one frame class, and
   that is deliberate.** A pan whose composite still covers the viewport
   (straight after a zoom *in*) falls through and bakes at one budgeted tile
   per frame with **no** live walk, because `if (carryOverCovers) return;`
   still stands below. That frame shows magnified stale pixels while it
   sharpens rather than paying a full walk. I judged that the right trade —
   it is cheap, it self-heals, and D3's ring argument does not apply because
   the composite covers — but it means "a pan after a zoom in" and "a pan
   after a zoom out" now heal at different speeds.
3. **`_restBake`'s per-band skip can no longer be read as all-or-nothing at
   band granularity if a *later* change adds a second reason to enter it.** The
   invariant I preserved is specifically the recency stamp on a skipped band's
   keys. It is one loop, three lines, and nothing in the type system holds it
   in place; `a skipped band keeps its tiles out of the ceiling's reach` is the
   only thing that does. It asserts zero evictions and a stable tile count,
   which is behavioural, not structural.
4. **The new ceiling arm's cap is derived from a measured tile count, so it
   moves with the fixture.** That is what makes it bind (a hard-coded number
   would drift into headroom the moment the harness viewport changed), but it
   also means the arm is sensitive to the pan distance and the two
   `repaintOnce`es in its setup: change either and the gate can quietly stop
   forcing eviction. The `evictionCount > evictedBefore` and `peak > cap - 2 *
   tileBytes` clauses exist to make that failure loud rather than silent, and
   they are the clauses to check first if this arm ever needs touching.
5. **The `bakeCount` unit is still overloaded.** `_bakes` counts tiles on the
   per-tile path and bands on the rest path, so `an edit inside one band
   rebakes that band alone` reads `3` meaning bands while
   `tile_regime_test`'s moving-frame test reads `0` meaning tiles. M4b's
   correction is a direct consequence of that overload. Not in scope here, and
   not worth churning the counter for one plan, but it will keep costing a
   paragraph per entry.
