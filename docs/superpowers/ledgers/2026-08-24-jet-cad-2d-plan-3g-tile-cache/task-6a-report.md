# Task 6a report — the diagonal disagreement: cause, and why it is a gap

## Outcome

**MEASURED, not fixed.** The controller's hypothesis is **wrong**, and so is
Task 6's reading of the symptom. The real cause is one `Float32` rounding step
that **no arrangement of this repository's code can remove**, because every
tiling scheme must express a tile-local coordinate and that value passes
through a `Float32` somewhere. I built the hypothesised fix, measured it, and
it changed **not one pixel**; it is reverted and no production file carries a
diff.

Three corrections to the record, each measured below:

1. It is not `Float64` ulp loss in `bakeCameraFor`. The `Float64` coordinates
   the painter emits are **bit-identical** between the two paths — 1368
   comparisons, 0 mismatches.
2. It is not about crossing a tile seam. `crossingGrid` crosses seams and
   agrees exactly; so do **ten parallel diagonals at slope 0.6**, which cross
   just as many seams and give `differing: 0`.
3. It is not about being diagonal. Slopes 0.2, 1.0, 5.0 and 16.7 all give
   `differing: 0` at this camera. The sensitive band is **near-axis**, and the
   sensitivity is sporadic within it.

## 1. Reproduction

Ten diagonals `(20, 30 + i*6)` to `(220, 150 - i*6)`, `transparency: 0`, the
standard 64-device-pixel rig:

```
DIAGONAL InkReport(live: 10342, tiled: 10344, stray: 19, uncovered: 17, differing: 36)
```

Matches Task 6's opaque measurement exactly (`differing: 36`).

## 2. The hypothesis, tested and rejected

`TileGrid.bakeCameraFor` folds the tile offset into `e`/`f`, and the
hypothesis was that `(A - k) - (B - k)` loses an ulp against `A - B` in
`Float64`. I recorded every emitted point from both paths through
`RecordingDrawSink`, added the tile offset back, and compared bit for bit
across every visible tile:

```
comparisons=1368 mismatches=0 worstUlpX=0 worstUlpY=0
```

**Zero.** The `Float64` arithmetic cancels exactly — `key.x * tileLogical` is
an exact small multiple of 32 at this rig, and `e - k` then `+ k` round-trips
without loss. The hypothesis is dead at this line.

## 3. Where the paths actually diverge

`VerticesDrawSink` applies the residual in `Float64` and stores the absolute
position into a **`Float32List`** (`_positions`). Capturing the submitted
buffers through `VerticesDrawSink.observer` for one diagonal, per tile:

```
key=TileKey(7, 5) diffs=9 worstLogical=0.00000762939453125 worstDevicePx=0.0000152587890625 | i=0 tile+off=-8.756927490234 live=-8.756931304932
key=TileKey(0, 6) diffs=3 worstLogical=0.00000762939453125 worstDevicePx=0.0000152587890625 | i=1 tile+off=281.405113220215 live=281.405120849609
...
```

One `Float32` ulp — **1.53e-05 device pixels**. Not a `Float64` defect: a
`Float32` one, and it happens *after* the tile offset is folded in, so the two
paths round different numbers.

## 4. The hypothesised fix, built and measured

I implemented exactly the direction the brief proposed, preserving per-tile
culling (so **not** mutant M7):

- `ViewportTransform.visibleWorldOf(Rect)`, with `visibleWorld(Size)`
  delegating to it.
- `DraftPainter.paint(..., {Rect? screenRegion})` — the region defaults to the
  whole viewport, drives `visibleWorldOf`, `_screenSpaceClip` and
  `_rebasedClip`, and **does not touch the camera**. Culling stays per tile.
- `TileGrid.screenRegionFor(key)` replacing `bakeCameraFor`; `_bake` draws with
  `grid.anchor` and applies `into.translate(-region.left, -region.top)` — an
  exact integral device-pixel translate.

The vertex buffers then became **bit-identical**: the same per-tile comparison
that printed diffs for every tile printed nothing at all.

The pixels did not move:

| fixture | before the fix | after the fix |
| --- | --- | --- |
| axis horizontal, slope 0 | 0 | 0 |
| axis vertical | 0 | 0 |
| near-axis, slope 0.06 | 7 of 1029 | 7 of 1029 |
| shallow, slope 0.2 | 0 | 0 |
| 45 degrees, slope 1.0 | 0 | 0 |
| steep, slope 5.0 | 0 | 0 |
| near-vertical, slope 16.7 | 0 | 0 |
| ten-line fan (the brief's) | 36 of 10342 | 36 of 10342 |
| ten near-axis parallels | 12 of 10288 | 12 of 10288 |

Every row identical, to the pixel. The fix removes a real `Float32`
discrepancy in *our* code and buys nothing, because an identical discrepancy of
the same magnitude then appears in Skia's. **Reverted.**

## 5. The real cause, with numbers

Bisection first. A single diagonal `(20,30)-(220,150)` (slope 0.6) gives
`differing: 0`. A single diagonal `(20,84)-(220,96)` (slope 0.06) gives
`differing: 7` **on its own**:

```
fan n=1 -> InkReport(live: 1192, tiled: 1192, stray: 0, uncovered: 0, differing: 0)
parallel n=10 -> InkReport(live: 11924, tiled: 11924, stray: 0, uncovered: 0, differing: 0)
line i=9 alone -> InkReport(live: 1029, tiled: 1028, stray: 3, uncovered: 4, differing: 7)
```

So it is neither multiplicity nor overlap nor seam-crossing. The differing
pixels for that one line:

```
(404,384) live=255,255,255,255 tiled=0,0,0,0
(419,385) live=0,0,0,0         tiled=255,255,255,255
(354,387) live=255,255,255,255 tiled=0,0,0,0
(369,388) live=0,0,0,0         tiled=255,255,255,255
(304,390) live=255,255,255,255 tiled=0,0,0,0
(319,391) live=0,0,0,0         tiled=255,255,255,255
(254,393) live=255,255,255,255 tiled=0,0,0,0
```

Every pair is a **staircase step landing one step early or late**, and the
groups are **exactly 50 device pixels apart** (404, 354, 304, 254). That
spacing is the tell: the device slope is `12*1.4*2 / (200*1.4*2)` = `33.6/560`
= **exactly 3/50**, so the stroke edge returns to the same sub-pixel phase
every 50 pixels and grazes a sample point at each of them. Those are exact
ties, and an arbitrarily small perturbation decides them.

**The perturbation, isolated from all jet-cad code.** Taking the exact
`Float32` vertices the sink submits and drawing them twice with plain
`Canvas.drawVertices` — once anchored, once translated by a whole number of
device pixels onto a surface of the *same* size:

```
isAntiAlias=true  total=7 tiles=(3,6)=1 (4,6)=2 (5,6)=2 (6,6)=2
isAntiAlias=false total=7 tiles=(3,6)=1 (4,6)=2 (5,6)=2 (6,6)=2
translated onto 800x600 surface: diff=7 | translated onto 64x64 surface: diff=7
```

The same 7 pixels. Not antialiasing (identical both ways, consistent with G1),
not the clip, not the surface bounds — the **translate itself**.

**Why the translate is not exact.** The offset is a whole number of device
pixels, but it moves a coordinate to a different binary exponent:

```
v (logical)          2v exact           2v-384 exact          f32(2v-384)          err (device px)
-8.971704483032227   -17.943408966064453  -401.94340896606445  -401.94342041015625  1.144e-05
-9.028295516967773   -18.056591033935547  -402.05659103393555  -402.05657958984375  1.144e-05
205.87159729003906   411.7431945800781    27.743194580078125   27.743194580078125   0.000e+00
271.0282897949219    542.0565795898438    158.05657958984375   158.05657958984375   0.000e+00
```

The two vertices whose magnitude *grows* lose their low bits; the ones whose
magnitude shrinks are exact. **1.144e-05 device pixels of error**, on an edge
that grazes a sample point every 50 pixels. That is the whole mechanism.

## 6. Why no fix preserves per-tile culling — or anything else

The offset has exactly two places to live, and both round:

- **In the camera** (`bakeCameraFor`, today): `VerticesDrawSink` rounds the
  shifted absolute position into its `Float32` vertex buffer.
- **On the canvas** (the fix in §4): Skia rounds when it applies its `Float32`
  CTM.

Measured, they are pixel-for-pixel identical (§4). There is no third place. A
scheme that avoided the offset entirely would have to rasterise the whole frame
into one surface and slice it — which is not a tile cache, and is mutant M7's
failure by another route. Snapping every vertex to a coarse grid so both
magnitudes are exact would change what the **live** path draws, which is a
worse trade than the gap. I did not force one.

## 7. The measured bound

64-device-pixel tiles, `tileCamera()`, `Size(400, 300)` viewport, `dpr` 2.
Every fixture spans ~200 world units = 560 device pixels = 8.75 tiles, so none
fits inside a tile.

**Discrete slopes, one line each:**

| slope | ink | differing | fraction |
| --- | --- | --- | --- |
| 0 (axis horizontal) | 1084 | 0 | 0.000% |
| ∞ (axis vertical) | 1120 | 0 | 0.000% |
| 0.06 | 1029 | 7 | 0.680% |
| 0.2 | 976 | 0 | 0.000% |
| 1.0 (45°) | 1627 | 0 | 0.000% |
| 5.0 | 846 | 0 | 0.000% |
| 16.7 | 1064 | 0 | 0.000% |

**Full sweep, 41 near-horizontal slopes** (`(20,84)` to `(220, 84+dy)`,
`dy = 0..40`) and **41 near-vertical** (`(84,20)` to `(84+dx, 220)`,
`dx = 0..40`). 24 of 82 disagree at all; the rest give exactly zero. Worst of
each family:

```
WORST single line:   dy=20 (slope 0.100) count=24 of 1030 ink = 2.330%
WORST near-vertical: dx=30 (slope 0.150) count=26 of 1092 ink = 2.381%
```

**Ten-line fans:**

```
fan dy=6   InkReport(live: 10254, tiled: 10254, stray: 4,  uncovered: 4,  differing: 8)  0.078%
fan dy=12  InkReport(live: 10288, tiled: 10268, stray: 3,  uncovered: 23, differing: 26) 0.253%
fan dy=24  InkReport(live: 10322, tiled: 10282, stray: 0,  uncovered: 40, differing: 40) 0.388%
brief fan  InkReport(live: 10342, tiled: 10344, stray: 19, uncovered: 17, differing: 36) 0.348%
```

**The bound, as measured: 2.38% of ink, worst case, on a single near-axis
stroke; 0.39% on a realistic ten-line drawing; 0.000% on everything
axis-aligned or of general slope.** Every differing pixel is ink moved, never
ink recoloured: `differing == stray + uncovered` in every row above.

## 8. What landed

Three test files, no production diff.

- `test/support/tile_fixture.dart` — new `nearAxisDiagonals` fixture carrying
  the mechanism in its doc comment; `translucentOverlap`'s comment corrected,
  since it blamed seam-crossing and that is now measured to be false.
- `test/tile_cache_test.dart` — a new `group` with three tests: the ten-line
  fan inside a bound of 60 and 1% of ink; the two worst swept slopes inside 45
  and 4%; and a control proving `crossingGrid` is still **exactly zero** at the
  same camera and tile size, so the slope is the variable. Every test also
  asserts `differing == stray + uncovered`. The comment states plainly what is
  and is not proven.
- `test/drawvertices_translation_test.dart` — the mechanism pinned with
  `Canvas.drawVertices` alone, in the idiom of the existing
  `drawvertices_antialiasing_test.dart`. Asserts non-zero **on purpose**: if a
  Skia upgrade closes this, the file goes red and the gap gets re-measured.

### The new tests redden under mutation

**Mutant: one device pixel of error in `TileGrid.destRectFor`**
(`key.x * tileDevicePixels + dx + 1`):

```
00:00 +0 -1: ... the ten-line fan stays inside the bound [E]
  Expected: a value less than or equal to <60>
    Actual: <3192>
  InkReport(live: 10342, tiled: 10344, stray: 1597, uncovered: 1595, differing: 3192)
00:00 +0 -2: ... the worst single slope measured stays inside the bound [E]
  Expected: a value less than or equal to <45>
    Actual: <136>
  near-horizontal: InkReport(live: 1030, tiled: 1014, stray: 60, uncovered: 76, differing: 136)
00:00 +0 -3: ... agree exactly on axis-aligned ink [E]
  Expected: <0>
    Actual: <11148>
```

All three red, at 53x the bound. Restored, `diff` against the pre-mutation copy
empty.

**Mutant: alpha on the blit paint** (`_blitPaint..color = Color(0x80FFFFFF)`),
to prove the `differing == stray + uncovered` clause pulls its weight — this is
the colour-defect shape the counts alone cannot see:

```
00:00 +0 -1: ... the ten-line fan stays inside the bound [E]
  Expected: <36>
    Actual: <10361>
  a pixel differing without being stray or uncovered is a colour defect, which this gap is not: InkReport(live: 10342, tiled: 10344, stray: 19, uncovered: 17, differing: 10361)
```

Red on the clause, with stray and uncovered unchanged at 19 and 17. Restored,
`diff` empty.

## 9. Exit gate

```
$ cd packages/jet_cad_2d && CI=true dart test && CI=true dart analyze && CI=true dart format --output=none --set-exit-if-changed .
00:03 +797: All tests passed!
Analyzing jet_cad_2d... No issues found!
Formatted 113 files (0 changed) in 0.20 seconds.

$ cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .
00:04 +330 ~1: All tests passed!
Analyzing jet_cad_2d_flutter... No issues found! (ran in 1.2s)
Formatted 61 files (0 changed) in 0.11 seconds.
```

330 tests, up from 325 (one pre-existing skip, unrelated). `git status` shows
`test/support/tile_fixture.dart`, `test/tile_cache_test.dart` and the new
`test/drawvertices_translation_test.dart` and nothing else — no
`analysis_options.yaml`, no production file. `lib/src/tile_cache.dart`,
`lib/src/draft_painter.dart` and `lib/src/viewport_transform.dart` are
byte-identical to their pre-task state (`diff` against the scratchpad backups
returns empty).

## 10. For the controller

- The gap is **accepted, bounded and now measured on every run**. Criteria 1
  and 2 keep their zero-tolerance claim for every fixture in the suite; the
  spec should say the claim holds **except for near-axis strokes, where it is
  bounded at 2.4% of ink** rather than exact.
- This is a **software-Skia** measurement. `flutter_test`'s CPU backend is the
  only instrument available here, and the same reservation G1 carries applies:
  a GPU backend has its own rasterisation rules and this bound is not
  transferable to one. That is unmeasurable from this repository.
- The `screenRegion` fix in §4 is *architecturally* the better shape — it makes
  the tiled path's Dart-side arithmetic bit-identical to the live path's — but
  it has **zero measured effect**, and landing production code no measurement
  supports is not this repository's bar. It is written up here in full so it
  can be revived cheaply if a GPU backend ever makes the `Float32` vertex
  buffer the dominant term.
