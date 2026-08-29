# Does an arm's settle leave the next arm's settle trivially covered?

**Answer: (b) — no. The concern is closed by evidence, and
`packages/jet_cad_2d_flutter/test/tile_zoom_warmth_test.dart` is the
regression that keeps it closed.**

Two independent mechanisms make it impossible, and the test pins both.

## 1. The excursion destroys the warm generation on its *first* frame

`TileCache.paintFrame` calls `_gridFor(quantised, dpr, viewport)` every frame
(`tile_cache.dart:942`). `_gridFor` reuses the standing `TileGrid` only when
`grid.matchesScale(quantised)` (`:1514`), and `matchesScale` compares the four
linear terms with exact `==` (`:274-278`). A zoom step multiplies the scale
term, so the very first frame of an arm's gesture fails that check, and
`_gridFor` calls `_retireGeneration(viewport)` before anchoring a fresh grid.
`_retireGeneration` ends unconditionally in `_disposeTiles()` (`:1580`), which
disposes every tile image, clears `_tiles`, `_baked` and `_lastUsedFrame`, and
sets `_viewportCovered = false` (`:1584-1592`).

Nothing during the remaining 79 frames can refill it. Every gesture frame is a
*moving* frame: `sameQuantisedCamera(previous, quantised)` is false, so
`_restGateSteps` resets to 0, `resting` is false (a composite exists to blit,
so the `_carryOver == null` escape hatch does not apply), and `paintFrame`
takes the early return at `:1041` after the carry-over blit — no bake, no live
walk, no slice.

Measured on the `pumpTiled` harness (400x300 logical at dpr 2, 64 px tiles,
130 tiles, `fillingGrid`):

```
after settle0: covered=true tiles=130 gen=1
arm 0 after reset: covered=true tiles=130 gen=1 carry=false
arm 0 after first zoom frame: covered=false tiles=0 gen=2 carry=true
arm 0 gesture end: covered=false tiles=0 gen=81 carry=true scheduled=true
arm 0 settle: frames=2 covered=true tiles=130 bakes=10 scheduled=false
arm 1 after reset: covered=false tiles=0 gen=82 carry=true
arm 1 after first zoom frame: covered=false tiles=0 gen=83 carry=true
arm 1 gesture end: covered=false tiles=0 gen=162 carry=true scheduled=true
arm 1 settle: frames=2 covered=true tiles=130 bakes=10 scheduled=false
```

(from an exploratory print-only version of the test, replaced by the assertions
that are committed. `gen` advances once per gesture frame — 80 retirements an
arm — which is the mechanism above, counted.)

Both arms settle **identically and non-trivially**: 2 idle frames, 10 band
bakes, 130 tiles. Neither is covered before its first idle frame.

## 2. The round trip does not return to the starting camera anyway

`CameraController.zoomAt` composes `about.multiply(m)`
(`camera_controller.dart:64`); for a camera with no skew term that is a plain
scalar multiply of the scale term, once per step. So 40 multiplies by `1.03`
followed by 40 by `1 / 1.03` accumulate 80 roundings:

```
1.4  ->  1.4000000000000017
```

`matchesScale` is exact `==`, so the grid that ends the excursion is not the
grid that began it. The translation *does* come back — `quantiseCamera` snaps
`e` and `f` onto the same device pixel (`e -37.0 -> -37.0`, `f 323.0 -> 323.0`)
— which is asserted too, so a reader knows the difference is the scale term and
not a translation they might assume away.

This has a visible consequence in the rig's own arm reset: `main.dart` sets
`camera.value = fittedCamera` before each arm, and because the previous arm
settled at `1.4000000000000017` and the fitted camera is `1.4`, **that reset
itself retires the previous arm's generation** (`arm 1 after reset: tiles=0
gen=82` above). Arm N+1 therefore starts cold twice over.

## What this means for criterion 4

**No state reset between arms is required.** The measurement's
`settleFrames` for arm N+1 is not inherited from arm N — it is re-earned by a
full rest bake over an empty generation, exactly as arm N's was. The two arms
are comparable, and a ratio between them measures the flag and not cache
warmth.

## Findings (reported, not acted on)

1. **`ZoomReport.settleFrames` will read 2, not 1.** `runTileZoomPhase`'s doc
   comment says criterion 3 asserts "1 if the very first idle frame after the
   gesture already covers", and that is structurally unreachable as the code
   stands. The last gesture frame changes the camera, so `_restGateSteps` is 0
   entering the idle loop; idle frame 1 raises it to 1, which is below
   `kRestGateFrames` (2), so that frame takes the moving-frame early return and
   covers nothing; idle frame 2 is the first rest bake and covers. Measured
   above: `frames=2` in both arms. Criterion 3's threshold should be read as
   "2" (one gate frame plus one rest bake) rather than "1", or the criterion
   will fail on healthy code. **No production change made** — this is a
   statement about the criterion's wording, not about the cache.
2. **No new public seam on `TileCache` was needed.** `generation`,
   `liveTileCount`, `viewportCovered`, `bakeCount` and `hasCarryOver` are all
   already public and were sufficient.

## The test

`packages/jet_cad_2d_flutter/test/tile_zoom_warmth_test.dart`, two tests:

* `a zoom round trip leaves the next arm nothing warm to settle on` — a widget
  test that reproduces the rig's two-arm sequence against one cache: settle,
  then for each arm `camera.value = fitted`, two throwaway no-op pans, 40 zoom
  steps at 1.03, 40 at 1/1.03, then an idle loop that counts frames to
  coverage. It asserts, at the *first* frame of each arm's excursion, that the
  generation advanced, that `liveTileCount` is 0 and that `viewportCovered` is
  false; at the gesture's end that both are still 0/false; and then that both
  arms' settles agree (frames, bakes, tiles) and that neither reports 0 frames
  — 0 being reserved for "already covered before a single idle frame", i.e.
  the trivial case. The absolute figures 2 / 10 / 130 are pinned too.
* `the zoom round trip does not return to the starting scale` — a pure unit
  test over `CameraController` and `quantiseCamera` pinning
  `1.4 -> 1.4000000000000017`, `sameQuantisedCamera(start, end) == false`, and
  `closeTo(1.4, 1e-14)` — the last so that a future implementation comparing
  scales with a `Tolerance` is visibly the thing that would break this.

## M15 — the mutation that proves the test is not degenerate

Recorded in full in `docs/superpowers/notes/plan-3i-mutation-log.md`
(section `## M15 — a retired generation keeps its tiles`), including both
verbatim transcripts. Summary:

```diff
--- a/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
+++ b/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
@@ -1577,7 +1577,7 @@
       picture.dispose();
     }
-    _disposeTiles();
+    // M15: _disposeTiles();
   }
```

`cp` aside to the scratchpad, edit, run, restore by `cp`, `diff` empty. Never
`git checkout`. **Red** at
`tile_zoom_warmth_test.dart:109` — `Expected: <0>  Actual: <130>` on
`liveTileCount` at the first frame of arm A's excursion: the settled
generation's 130 tiles are still live, which is precisely the leftover warmth
the concern described. **Green** after restore, 2/2.

## Gate

`packages/jet_cad_2d_flutter`:

```
00:06 +404 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart: debugFullViewportQuery grows the fallback walk to the whole viewport
00:06 +405 ~1: All tests passed!
```

```
Analyzing jet_cad_2d_flutter...                                 
No issues found! (ran in 0.8s)
Formatted 73 files (0 changed) in 0.13 seconds.
FORMAT CLEAN
```

`apps/dev_harness_2d`:

```
00:15 +21: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/zoom_script_test.dart: the pinned script is 40 in, 40 out, at 1.03
00:15 +22: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/zoom_script_test.dart: the focal point is off-centre
00:15 +23: All tests passed!
Analyzing dev_harness_2d...                                     
No issues found! (ran in 1.1s)
Formatted 9 files (0 changed) in 0.07 seconds.
FORMAT CLEAN
```

403 + 2 = **405** in `jet_cad_2d_flutter` (1 skip, unchanged); **23** in
`apps/dev_harness_2d`, unchanged. `packages/jet_cad_2d` was not touched.
