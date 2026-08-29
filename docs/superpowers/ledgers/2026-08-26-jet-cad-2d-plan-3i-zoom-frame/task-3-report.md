# Task 3 Report: The wheel clause — two unchanged frames, not one

## Summary

Task 3 raises the rest gate threshold from one unchanged frame to two, so a continuously spinning mouse wheel never reaches two consecutive unchanged frames and therefore never bakes during the spin.

## What Changed

1. **Added constant** in `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`:
   - `const int kRestGateFrames = 2;` with explanatory doc comment

2. **Updated guard** in `paintFrame` method (line 844):
   - From: `_restGateSteps >= 1`
   - To: `_restGateSteps >= kRestGateFrames`
   - The full guard remains: `final resting = previous == null || _carryOver == null || _restGateSteps >= kRestGateFrames;`

3. **Added two tests** to `packages/jet_cad_2d_flutter/test/tile_regime_test.dart`:
   - "a steadily spun wheel never arms the rest gate" - verifies bakeCount == 0 with wheel pattern
   - "the gate needs two unchanged frames, not one" - constant check

## Test Results

### GREEN Output (Final)

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart
00:00 +0: the same camera compares same
00:00 +1: a scale change compares different
00:00 +2: a translation change compares different
00:00 +3: the skew terms are compared too
00:00 +4: a moving frame bakes nothing and walks nothing
00:00 +5: a moving frame with no composite falls through and draws something
00:00 +6: a steadily spun wheel never arms the rest gate
00:00 +7: the gate needs two unchanged frames, not one
00:00 +8: All tests passed!
```

### Mutation M4 Test

**Mutation:** Replaced resting guard with `final resting = !_viewportCovered;`

**Expected:** RED - both moving-frame and wheel tests should fail

**RED Output:**

```
00:00 +4 -1: a moving frame bakes nothing and walks nothing [E]
Expected: <0>
  Actual: <512>
a moving frame must bake nothing

00:00 +5 -2: a steadily spun wheel never arms the rest gate [E]
Expected: <0>
  Actual: <768>
a wheel that keeps turning must never reach two consecutive unchanged frames, so it must never bake
```

Both tests fail as expected when the rest gate is completely removed. The mutation confirms the gate is essential to the behavior being tested.

## Gate Logic

The resting condition now requires:
- No previous frame (first frame), OR
- No carry-over composite, OR
- **Two or more consecutive unchanged frames** ← The new threshold

A continuously spinning wheel delivers one scale change per notch and one unchanged frame between notches, so `_restGateSteps` never reaches 2, and the gate never arms. This costs ~16.7 ms of latency per gesture (one frame) and eliminates per-notch baking.

## Analysis

- No issues found in static analysis
- All formatting passed
- Commit: 2eebb1a
- Test summary: 8/8 tests pass in tile_regime_test.dart; new wheel test verifies no bakes during continuous wheel spin

## Concerns

None. The change is minimal, the gate logic is correct, and mutation testing confirms the threshold is effective.

---

# Fix Round 1

## Findings Addressed

**Finding 1:** Added `hasCarryOver == true` assertion after first notch in wheel test to prove the composite exists and the rest gate's threshold term is under test.

**Finding 2:** Added M4b mutation testing to isolate the threshold from the guard's other terms.

**Minor:** Rewrapped guard comment from 91 to ~80 characters.

## Changes

1. **test/tile_regime_test.dart** — Enhanced wheel test with hasCarryOver assertion and explanatory comment.
2. **lib/src/tile_cache.dart** — Rewrapped comment line 813 to fit convention.
3. **docs/superpowers/notes/plan-3i-mutation-log.md** — Added M4b mutation.

## Test Coverage

**Files tested:** `packages/jet_cad_2d_flutter/test/tile_regime_test.dart`

**Command:**
```
cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_regime_test.dart && CI=true flutter analyze && dart format --output=none --set-exit-if-changed .
```

**Verbatim output:**

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart
00:00 +0: the same camera compares same
00:00 +1: a scale change compares different
00:00 +2: a translation change compares different
00:00 +3: the skew terms are compared too
00:00 +4: a moving frame bakes nothing and walks nothing
00:00 +5: a moving frame with no composite falls through and draws something
00:00 +6: a steadily spun wheel never arms the rest gate
00:00 +7: the gate needs two unchanged frames, not one
00:00 +8: All tests passed!

Resolving dependencies...
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.2s)

Formatted 67 files (1 changed) in 0.13 seconds.
Formatted 67 files (0 changed) in 0.13 seconds.
Format check passed
```

## M4b Mutation Result

M4b mutation (kRestGateFrames = 1) correctly goes red:
- Wheel test fails with bakeCount 384 (expected 0)
- Threshold test fails with value 1 (expected 2)

This confirms the threshold of 2 is necessary and 1 is insufficient.

---

# Fix Round 2 (four red tests on `main`)

## Diagnosis, verified by reading `paintFrame`

`_restGateSteps` now must reach `kRestGateFrames` (2, was 1) before `resting`
can be true on a frame whose camera matches the previous one and whose
composite is non-null (`tile_cache.dart`, the `resting` computation and the
surrounding comment block). Every test below used to reach the resting frame
one unchanged-camera `paintOnce()` after the moving (zoom/pan) frame; now it
takes two. Each test was one frame short of where it used to settle. No
production code was touched (`kRestGateFrames` and the guard are exactly as
Task 3 left them); only the frame counts the tests pump were adjusted.

## Assertion values, `31399ed` vs now — nothing relaxed

### `test/tile_cache_test.dart` — "criterion 1: a settled frame equals the live frame after a zoom"

| | `31399ed` | now |
|---|---|---|
| frames pumped after `zoomBy` | `rig.paintOnce(); rig.paintOnce(); rig.paintOnce();` (3) | same 3, plus one more `rig.paintOnce();` (4) |
| `hasCarryOver` after the loop | `isFalse` | `isFalse` (unchanged) |
| `expectTiledEqualsLive` checks (`liveInk`/`tiledInk` > threshold, `strayPixels`/`uncoveredPixels`/`differingPixels` == 0) | unchanged | unchanged |
| factors swept | `[0.74, 0.83, 1.10, 1.16, 1.22, 1.30]` | unchanged |

Only the frame count changed (3 → 4); every expectation is byte-identical to
`31399ed`.

### `test/tile_cache_test.dart` — "the blit hands drawImageRect the same Paint object every time, not a call-site-local one"

| | `31399ed` | now |
|---|---|---|
| frames pumped after `zoomBy(1.19)` before the spy call | `zoomed.paintOnce();` (1) | `zoomed.paintOnce(); zoomed.paintOnce();` (2) |
| `bakeBudgetDevicePixels` | `4 * 64 * 64` | unchanged |
| `carryOverBlitCount` | `1` | `1` |
| `blitCount` | `4` | `4` |
| `zoomedCalls.length` | `5` | `5` |
| composite Paint identity, tile Paint identity | `identical(...)` assertions, unchanged | unchanged |
| `debugBlitPaint.filterQuality` | `FilterQuality.none` | unchanged |
| `debugCarryOverPaint.filterQuality` | `FilterQuality.low` | unchanged |
| `debugCarryOverPaint.blendMode` | `BlendMode.srcOver` | unchanged |
| first-phase cold-frame assertions (`calls.length > 30`, all Paints `identical`) | unchanged | unchanged |

Only the frame count changed (1 → 2); every expectation is byte-identical to
`31399ed`.

### `test/invariants/tile_budget_test.dart` — "criterion 12: eviction runs with a composite standing, and never takes it"

This test never calls `rig.paintOnce()` directly around the rest gate — it
calls the file-local `settle(rig)` helper, which itself changed:

| | `31399ed` | now |
|---|---|---|
| `settle(TileRig rig)` body | `=> rig.paintOnce();` (1 frame) | loops `rig.paintOnce()` `kRestGateFrames` times (2 frames) |
| `covering` (tile count after first paint) | `> 30` | unchanged |
| `liveTileCount` after zoom+settle | `< covering` and `> 0` | unchanged |
| pan loop (6 iterations): `hasCarryOver` | `isTrue` each iteration | unchanged |
| pan loop: `liveBytes <= _capWithComposite` | unchanged | unchanged |
| pan loop: `liveBytes > _compositeBytes` | unchanged | unchanged |
| `evictionCount` after loop | `greaterThan(baseline)` | unchanged |
| `debugImagesAlive` | `liveTileCount + 1` | unchanged |

No assertion in the test body itself changed; only the shared `settle()`
helper now pumps 2 frames instead of 1.

### `test/invariants/tile_budget_test.dart` — "criterion 12: a ceiling smaller than the composite bakes nothing rather than overrun it"

Also relies solely on `settle()`, changed as above.

| | `31399ed` | now |
|---|---|---|
| `hasCarryOver` after zoom+settle | `isTrue` | unchanged |
| `liveTileCount` after zoom+settle | `greaterThan(30)` | unchanged |
| `cacheBytes` squeeze | `4 * _tileBytes` | unchanged |
| `evictionCount - beforeSqueeze` after pan+paintOnce+settle | `greaterThan(50)` | unchanged |
| after second pan+paintOnce+settle: `hasCarryOver` | `isTrue` | unchanged |
| `liveBytes` | `_compositeBytes` (exact) | unchanged |
| `liveTileCount` | `0` | unchanged |
| `bakeCount` | `0` | unchanged |
| `liveDrawCount` | `1` | unchanged |

No assertion value changed anywhere in this file; the fix is entirely
confined to the `settle()` helper (see diff below), which every call site in
the file already used, so every other test in `tile_budget_test.dart` was
re-verified against the same helper change and remains green.

```
$ diff <(git show 31399ed:packages/jet_cad_2d_flutter/test/invariants/tile_budget_test.dart) packages/jet_cad_2d_flutter/test/invariants/tile_budget_test.dart
60c60,61
< /// One more frame at the same camera `rig` just painted.
---
> /// Enough more frames at the same camera `rig` just painted for the rest
> /// gate to arm and a resting frame to actually bake.
65,68c66,78
< /// frame; now that frame is the moving one, and this second, unchanged-camera
< /// call is the one that actually bakes, blits and evicts, matching this
< /// file's pre-Plan-3i counts again.
< void settle(TileRig rig) => rig.paintOnce();
---
> /// frame; now that frame is the moving one, and one more, unchanged-camera
> /// call used to be the one that actually bakes, blits and evicts, matching
> /// this file's pre-Plan-3i counts again.
> ///
> /// Plan 3i Task 3 then raised the threshold from one unchanged frame to
> /// [kRestGateFrames] (two), so a single extra call now lands on the frame
> /// *in between* -- still not resting, so it also only blits the composite --
> /// and it takes `kRestGateFrames` of them to reach the one that bakes.
> void settle(TileRig rig) {
>   for (var i = 0; i < kRestGateFrames; i++) {
>     rig.paintOnce();
>   }
> }
```

## Commands run and verbatim output

### Whole-package gate (as specified)

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && dart format --output=none --set-exit-if-changed .
```

Exit code: `0`. Tail of `flutter test` output:

```
00:05 +377 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_differential_test.dart: the comparison is not vacuous
00:05 +378 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: a bypassed leaf gets the exact paper width
00:05 +379 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: curves cannot be bypassed an anisotropic circle stays on the residual path and is counted
00:05 +380 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: curves cannot be bypassed an anisotropic arc is counted too
00:05 +381 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: curves cannot be bypassed a conformal circle is not counted
00:05 +382 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: curves cannot be bypassed the threshold is exclusive, so a circle exactly at 2.0 is not counted
00:05 +383 ~1: All tests passed!
```

`flutter analyze`:

```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.2s)
```

`dart format --output=none --set-exit-if-changed .`:

```
Formatted 68 files (0 changed) in 0.13 seconds.
```

383 tests, `+383`, one pre-existing skip (`~1`, unrelated to this fix,
present before these edits too). All green, exit code 0 for the whole
compound command.

### Targeted verbatim confirmation of the four previously-red tests, expanded reporter

```
$ CI=true flutter test --reporter expanded --plain-name "criterion 12: a ceiling smaller than the composite bakes nothing rather than overrun it" test/invariants/tile_budget_test.dart
...
00:00 +0: loading .../test/invariants/tile_budget_test.dart
00:00 +0: criterion 12: a ceiling smaller than the composite bakes nothing rather than overrun it
00:00 +1: All tests passed!

$ CI=true flutter test --reporter expanded --plain-name "criterion 12: eviction runs with a composite standing, and never takes it" test/invariants/tile_budget_test.dart
...
00:00 +0: criterion 12: eviction runs with a composite standing, and never takes it
00:00 +1: All tests passed!

$ CI=true flutter test --reporter expanded --plain-name "criterion 1: a settled frame equals the live frame after a zoom" test/tile_cache_test.dart
...
00:00 +0: criterion 1: a settled frame equals the live frame after a zoom
00:00 +1: All tests passed!

$ CI=true flutter test --reporter expanded --plain-name "the blit hands drawImageRect the same Paint object every time, not a call-site-local one" test/tile_cache_test.dart
...
00:00 +0: the blit hands drawImageRect the same Paint object every time, not a call-site-local one
00:00 +1: All tests passed!
```

## Files touched

- `packages/jet_cad_2d_flutter/test/tile_cache_test.dart`
- `packages/jet_cad_2d_flutter/test/invariants/tile_budget_test.dart`

`git status --short` after the fix shows only these two files modified;
`analysis_options.yaml` was not touched or staged. `packages/jet_cad_2d` was
not touched. `kRestGateFrames` and the `resting` guard in `tile_cache.dart`
were not touched.

## Conclusion

All four tests were repairable by adding exactly one more unchanged-camera
frame (directly, or through the shared `settle()` helper both budget tests
already used). No assertion value, matcher, or expected count was changed
from `31399ed` anywhere. The contract change from Task 3 is sound; the tests
were simply stale by one frame.
