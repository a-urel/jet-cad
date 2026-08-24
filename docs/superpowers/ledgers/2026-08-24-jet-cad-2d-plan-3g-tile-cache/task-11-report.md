# Task 11 report: the harness, and the tile-size sweep

**Verdict: `kTileDevicePixels = 512`.** The blit column is flat across all three
sizes and decides nothing; the bake column and the overdraw column both point
the same way, and the pan regime -- criterion 11 -- is decided by a margin of
more than twenty to one at p95.

---

## 1. Machine state

Read immediately before the control run and again before the sweep. Both
readings identical.

```
$ pmset -g | grep -i lowpowermode
 lowpowermode         0
$ pmset -g ps | head -2
Now drawing from 'AC Power'
 -InternalBattery-0 (id=22282339)	100%; charged; 0:00 remaining present: true
```

Low Power Mode is off and the machine is on AC. Plan 3c's contamination on this
corpus was +30% on build and +47% on raster; nothing below is within an order of
magnitude of that displacement.

Every `flutter drive` invocation ran in the **foreground**, per
`frame_timing_test.dart:28-32`. No run stalled.

## 2. The control, against Plan 3d's clean `50,000 / vertices` row

**Run against an uncommitted development snapshot of the harness, not
against a checkout this command can reproduce.** The transcript below prints
`tiles=off` (so `TILES` already existed) but carries no `mean=` column (so
`report()`'s mean addition did not yet exist) -- and both landed together in
`96cdd56`, so no commit's tree can print exactly this shape: checking out
`96cdd56` reproduces `tiles=off` but adds `mean=` that this transcript does
not have, and any commit before it drops `tiles=off` too. This is not a
synthesised transcript -- the numbers below were pasted verbatim from a real
run mid-development -- but re-running the pasted command against any git ref
will not reproduce this exact line shape; the sweep transcripts in section 4
onward, all taken after `96cdd56` landed, do carry `mean=` and are
reproducible against that commit.

Plan 3d: build **7.07 ms `[7.06, 7.38]`** / raster **8.53 ms `[8.22, 8.63]`**.

```sh
CI=true flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart --profile -d macos \
  --dart-define=TEXT=true --dart-define=ENTITIES=50000 \
  --dart-define=RIG=pan --dart-define=BACKEND=vertices
```

Three samples, verbatim:

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
| 3 | 6.99 | **no**, -0.07 (-1.0%) | 8.28 | yes |
| **median** | **7.17** | **yes** | **8.48** | **yes** |

**The control reproduces.** Sample 2 lands inside both intervals on its own;
the median of three lands inside both. The two misses are 1.5% and 1.0% on
opposite sides of opposite columns, and the sample spread (0.30 ms on build,
0.48 ms on raster) is of the same order as Plan 3d's own interval widths (0.32
and 0.41) -- this is the rig's ordinary variance, not a displacement.

**But it is not a quiet machine, and the sweep numbers must be read with that.**
During sample 1 `uptime` read a load average of 4.53, with a browser burning
~33% CPU across three helpers, a `VTDecoderXPCService` decoding video and a
`Virtualization.framework` VM at 7.3%. Sample 1's high raster is consistent with
GPU/WindowServer contention from that. Load ranged 2.65-5.32 across the whole
session. **What this costs the sweep is stated in section 7.**

Full control block (sample 3), verbatim:

```
flutter: R2 (50000) frames=243
flutter:   build  p50=6.99ms p95=8.73ms max=317.42ms
flutter:   raster p50=8.28ms p95=19.06ms max=152.14ms
flutter:   total  p50=15.14ms p95=31.33ms max=485.48ms
flutter:   lineweightScale=1.0
flutter:   screenSpaceLeafCount=2170 dashSpans=48323 collapsed=334 canvasCalls=23
flutter:   fills=0 skippedFills=0
flutter:   tiles=off
flutter:   backend=vertices triangles=217758 drawVerticesCalls=20
flutter:   text: corpus=on draw=on minTextCapPixels=3.0 textOps=23 skippedText=0 culledText=0
flutter:   paragraphs: newLayouts=0 newParagraphEvictions=0 newMetricsEvictions=0 liveParagraphs=512 liveMetrics=4020
```

`tiles=off` on the control line is deliberate instrumentation: a transcript
with no tile line is indistinguishable from one whose `TILES` define never
reached the canvas, and the control is exactly the run that must be *provably*
untiled.

## 3. What was built

Three defines in `apps/dev_harness_2d/lib/main.dart`, all following `kBackend`'s
rule at `main.dart:142-149` -- a `String.fromEnvironment` that **throws on an
unrecognised value rather than falling back**:

- `TILES` (`off`/`on`) -> `DraftCanvas.tiles`
- `TILE_PX` (int >= 1) -> `DraftCanvas.tileDevicePixels`
- `TILE_BAKE` (int >= 0) -> `TileCache.tilesBakedPerFrame`

`TILE_PX` and `TILE_BAKE` are **not** `int.fromEnvironment`, and that is the
same rule stated for an integer: `int.fromEnvironment` silently yields its
default for anything it cannot parse, so `TILE_PX=256px` would run at
`kTileDevicePixels` and be written into the table under whichever size the
command line claimed. Two rows of the same run is precisely the failure Plan
3c's `TEXT` define committed.

`TILE_BAKE`'s floor is zero, not one: a budget of zero is the value the
zoom-path tests take away to prove a frame blitted the composite rather than a
tile.

`printInvariants` gained the counters (`printTileCounters`): `tilePx`,
`bakePerFrame`, `liveTiles`, `generation`, `carryOver`, `bakes`, `blits`,
`carryOverBlits`, `liveDraws`, `blitDests`, `evictions`, `invalidations`,
`tileBytes`.

`runR2Rig` gained a tile tail (`runTilePhases`), run only when the canvas built
a cache, so the untiled rigs report byte-for-byte what they reported before:

- **warm** -- hold the camera until `bakeCount` stops rising, so the hold regime
  measures a full generation and not a refill.
- **hold** (60 frames, `panBy(Offset.zero)`) -- the blit column. Verified
  `bakes=0` and `liveDraws=0` on every run.
- **pan** (120 frames, `panBy(Offset(-7, -3))`, R2's own step) -- criterion 11's
  regime.
- **probe** -- one live full-viewport walk and one walk per covering tile,
  reproducing `TileCache`'s bake geometry exactly: a real `TileGrid` anchored at
  `quantiseCamera`'s output, `TileGrid.bakeCameraFor` for the camera, `kTileSlack`
  for the pad, the same hard unantialiased clip, the same frame-global
  `rebaseOriginFor` and the same `toImageSync`. This is the overdraw column.

`report()` gained a **mean**. That is not taste: a pan frame either bakes a whole
entering strip or bakes nothing, so the per-tile bake cost is invisible to `p50`
(the median pan frame is a pure blit) and `p95` reads whatever the burst size
happened to be at that quantile. Only the mean satisfies
`mean = blit + bakesPerFrame x bakePerTile`, and `bakesPerFrame` is a number the
cache reports exactly.

**Criteria 10 and 11 are read off `totalSpan`, not `rasterDuration`.** The
transcripts below show why in this very tree: at `TILE_PX=256` the R2 line reads
`raster p50=1.50ms` against `build p50=41.74ms` -- the raster column reports a
frame that is *not* cheap, because `Picture.toImageSync` returns before the GPU
work it schedules. `total` is the column quoted everywhere below.

## 4. The sweep

`ENTITIES=500000`, `BACKEND=vertices`, `RIG=pan`, `TEXT=true`, `TILES=on`,
`TILE_BAKE` at its default of 8.

```sh
CI=true flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart --profile -d macos \
  --dart-define=TEXT=true --dart-define=ENTITIES=500000 \
  --dart-define=RIG=pan --dart-define=BACKEND=vertices \
  --dart-define=TILES=on --dart-define=TILE_PX=<128|256|512>
```

1024 was excluded before the sweep started, per the brief.

**The viewport is 800x600 logical at `dpr` 2.0 -- 1600x1200 device.** Measured,
printed by the probe on every run, and **not** the 3200x2400 reference viewport
the plan's MiB arithmetic assumes. Section 6 converts.

### TILE_PX = 128

```
flutter: R2 (500000) frames=243
flutter:   build  p50=35.83ms p95=46.65ms max=1236.03ms mean=29.75ms
flutter:   raster p50=11.35ms p95=47.37ms max=196.42ms mean=16.55ms
flutter:   total  p50=55.52ms p95=88.59ms max=1526.18ms mean=53.51ms
flutter:   lineweightScale=1.0
flutter:   screenSpaceLeafCount=4612 dashSpans=146358 collapsed=345 canvasCalls=136
flutter:   fills=0 skippedFills=0
flutter:   tiles=on tilePx=128 bakePerFrame=8 liveTiles=16 generation=122 carryOver=true
flutter:   bakes=1304 blits=16583 carryOverBlits=121 liveDraws=148 blitDests=32818 evictions=0(life) invalidations=0(life) tileBytes=8728576
flutter:   backend=vertices triangles=1061712 drawVerticesCalls=52
flutter:   text: corpus=on draw=on minTextCapPixels=3.0 textOps=74 skippedText=0 culledText=0
flutter:   paragraphs: newLayouts=1 newParagraphEvictions=1 newMetricsEvictions=0 liveParagraphs=512 liveMetrics=4020
flutter:   tile warm: frames=16 liveTiles=130 tileBytes=8519680 evictions=0(life)
flutter:   tile hold frames=60
flutter:   build  p50=0.27ms p95=0.67ms max=1.03ms mean=0.33ms
flutter:   raster p50=0.74ms p95=2.16ms max=2.40ms mean=0.91ms
flutter:   total  p50=1.20ms p95=3.15ms max=3.79ms mean=1.45ms
flutter:     bakeFrames=0/60 maxBakesInAFrame=0
flutter:     bakes=0 perFrame=0.000 blits=7800 carryOverBlits=0 liveDraws=0 newEvictions=0 liveTiles=130 tileBytes=8519680
flutter:   tile pan frames=124
flutter:   build  p50=0.28ms p95=52.92ms max=70.90ms mean=8.70ms
flutter:   raster p50=0.57ms p95=10.08ms max=12.04ms mean=1.96ms
flutter:   total  p50=1.15ms p95=65.19ms max=79.53ms mean=11.05ms
flutter:     bakeFrames=34/120 maxBakesInAFrame=8
flutter:     bakes=202 perFrame=1.683 blits=16617 carryOverBlits=0 liveDraws=18 newEvictions=0 liveTiles=332 tileBytes=21757952
flutter:   tile probe: tilePx=128 dpr=2.0 viewport=800x600 tileLogical=64.0 pad=32.0
flutter:     tiles=130 liveLeaves=4350 tileLeaves=78228 overdraw=17.983 areaFactor=4.000
flutter:     liveWalkMs=24.86 tileWalkMsTotal=265.53 walkMsPerTile=2.043 visibleSetBytes=8519680
```

### TILE_PX = 256

```
flutter: R2 (500000) frames=242
flutter:   build  p50=41.74ms p95=47.80ms max=1240.61ms mean=29.45ms
flutter:   raster p50=1.50ms p95=35.41ms max=187.89ms mean=11.00ms
flutter:   total  p50=53.84ms p95=83.02ms max=1514.88ms mean=47.47ms
flutter:   lineweightScale=1.0
flutter:   screenSpaceLeafCount=4612 dashSpans=146358 collapsed=345 canvasCalls=174
flutter:   fills=0 skippedFills=0
flutter:   tiles=on tilePx=256 bakePerFrame=8 liveTiles=16 generation=122 carryOver=true
flutter:   bakes=1066 blits=5867 carryOverBlits=121 liveDraws=119 blitDests=9339 evictions=0(life) invalidations=0(life) tileBytes=11874304
flutter:   backend=vertices triangles=1323099 drawVerticesCalls=69
flutter:   text: corpus=on draw=on minTextCapPixels=3.0 textOps=74 skippedText=0 culledText=0
flutter:   paragraphs: newLayouts=1 newParagraphEvictions=1 newMetricsEvictions=0 liveParagraphs=512 liveMetrics=4020
flutter:   tile warm: frames=4 liveTiles=35 tileBytes=9175040 evictions=0(life)
flutter:   tile hold frames=60
flutter:   build  p50=0.30ms p95=0.53ms max=0.62ms mean=0.29ms
flutter:   raster p50=0.95ms p95=1.58ms max=1.66ms mean=0.94ms
flutter:   total  p50=1.46ms p95=2.45ms max=2.55ms mean=1.44ms
flutter:     bakeFrames=0/60 maxBakesInAFrame=0
flutter:     bakes=0 perFrame=0.000 blits=2100 carryOverBlits=0 liveDraws=0 newEvictions=0 liveTiles=35 tileBytes=9175040
flutter:   tile pan frames=121
flutter:   build  p50=0.17ms p95=43.71ms max=83.20ms mean=3.65ms
flutter:   raster p50=0.46ms p95=1.36ms max=9.24ms mean=0.70ms
flutter:   total  p50=0.94ms p95=47.42ms max=92.62ms mean=4.75ms
flutter:     bakeFrames=9/120 maxBakesInAFrame=8
flutter:     bakes=55 perFrame=0.458 blits=4908 carryOverBlits=0 liveDraws=1 newEvictions=0 liveTiles=90 tileBytes=23592960
flutter:   tile probe: tilePx=256 dpr=2.0 viewport=800x600 tileLogical=128.0 pad=32.0
flutter:     tiles=35 liveLeaves=4350 tileLeaves=29964 overdraw=6.888 areaFactor=2.250
flutter:     liveWalkMs=46.11 tileWalkMsTotal=105.31 walkMsPerTile=3.009 visibleSetBytes=9175040
```

### TILE_PX = 512

```
flutter: R2 (500000) frames=242
flutter:   build  p50=49.84ms p95=73.40ms max=1803.29ms mean=42.79ms
flutter:   raster p50=1.56ms p95=10.98ms max=127.85ms mean=5.80ms
flutter:   total  p50=58.61ms p95=86.50ms max=2050.34ms mean=58.48ms
flutter:   lineweightScale=1.0
flutter:   screenSpaceLeafCount=1402 dashSpans=33205 collapsed=58 canvasCalls=83
flutter:   fills=0 skippedFills=0
flutter:   tiles=on tilePx=512 bakePerFrame=8 liveTiles=12 generation=122 carryOver=true
flutter:   bakes=998 blits=2588 carryOverBlits=121 liveDraws=114 blitDests=3197 evictions=0(life) invalidations=0(life) tileBytes=20262912
flutter:   backend=vertices triangles=676147 drawVerticesCalls=33
flutter:   text: corpus=on draw=on minTextCapPixels=3.0 textOps=21 skippedText=0 culledText=0
flutter:   paragraphs: newLayouts=10 newParagraphEvictions=10 newMetricsEvictions=0 liveParagraphs=512 liveMetrics=4020
flutter:   tile warm: frames=1 liveTiles=12 tileBytes=12582912 evictions=0(life)
flutter:   tile hold frames=60
flutter:   build  p50=0.32ms p95=0.49ms max=0.53ms mean=0.30ms
flutter:   raster p50=1.12ms p95=1.65ms max=1.69ms mean=1.01ms
flutter:   total  p50=1.62ms p95=2.52ms max=2.94ms mean=1.52ms
flutter:     bakeFrames=0/60 maxBakesInAFrame=0
flutter:     bakes=0 perFrame=0.000 blits=720 carryOverBlits=0 liveDraws=0 newEvictions=0 liveTiles=12 tileBytes=12582912
flutter:   tile pan frames=122
flutter:   build  p50=0.12ms p95=0.45ms max=63.22ms mean=1.80ms
flutter:   raster p50=0.38ms p95=1.30ms max=1.72ms mean=0.62ms
flutter:   total  p50=0.69ms p95=2.31ms max=88.44ms mean=2.99ms
flutter:     bakeFrames=4/120 maxBakesInAFrame=4
flutter:     bakes=14 perFrame=0.117 blits=1600 carryOverBlits=0 liveDraws=0 newEvictions=0 liveTiles=26 tileBytes=27262976
flutter:   tile probe: tilePx=512 dpr=2.0 viewport=800x600 tileLogical=256.0 pad=32.0
flutter:     tiles=12 liveLeaves=4350 tileLeaves=18204 overdraw=4.185 areaFactor=1.563
flutter:     liveWalkMs=45.93 tileWalkMsTotal=71.97 walkMsPerTile=5.998 visibleSetBytes=12582912
```

### The three columns

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
| **bake cost per tile**, frame-level `(pan mean - hold mean) / bakesPerFrame` | 5.70 ms | **7.23 ms** | 12.56 ms |
| bake cost per tile, probe walk only | 2.04 ms | 3.01 ms | 6.00 ms |
| whole-generation walk (probe total) | 265.53 ms | 105.31 ms | **71.97 ms** |
| **measured overdraw factor** | **17.983** | **6.888** | **4.185** |
| area factor (re-derived, section 5) | 4.000 | 2.250 | 1.563 |
| visible-set bytes, this viewport | 8,519,680 | 9,175,040 | 12,582,912 |

## 5. The overdraw factors, re-derived -- and the plan's table is wrong twice over

**The plan's and the spec's 4.00x / 2.25x / 1.56x are stale, and I did not quote
them. I measured, and then re-derived the arithmetic from what the tree does
today.**

**What the tree does today.** `_bake` (`tile_cache.dart:1301-1319`) sets
`const pad = kTileSlack`, translates the canvas by `-pad`, and hands the painter
a viewport of `Size(side + 2 * pad, side + 2 * pad)` -- so the **cull** is
padded, not only the screen clip. `kTileSlack = kScreenClipInflate = 32.0`
logical pixels (`tile_cache.dart:63`, `draft_painter.dart:50`). At `dpr` 2.0 a
tile of T device pixels is `T/2` logical, so the padded area ratio is
`((T/2 + 64) / (T/2))^2`:

| TILE_PX | tile logical | padded logical | area factor |
|---|---|---|---|
| 128 | 64.0 | 128.0 | 4.000 |
| 256 | 128.0 | 192.0 | 2.250 |
| 512 | 256.0 | 320.0 | 1.563 |

Those are the plan's numbers. **They now describe a real code path -- and they
are still wrong, because they were never the whole factor.** The measurement:

| TILE_PX | live leaves (1 frame) | tile leaves (all covering tiles) | **measured overdraw** | area factor | unexplained residue |
|---|---|---|---|---|---|
| 128 | 4350 | 78228 | **17.983** | 4.000 | **4.50x** |
| 256 | 4350 | 29964 | **6.888** | 2.250 | **3.06x** |
| 512 | 4350 | 18204 | **4.185** | 1.563 | **2.68x** |

**How I obtained them.** `_probeBake` in `measurement_rig.dart` walks the live
full viewport once at the settled camera and reads
`DraftPainter.screenSpaceLeafCount` (the denominator, 4350 -- *identical across
all three runs and across a repeat of the 256 run*, which is what makes the
ratio a ratio of one drawing), then walks every key
`TileGrid.visibleKeys` yields at that camera, through
`TileGrid.bakeCameraFor`, with `kTileSlack` of pad, the same hard clip, the
same frame-global rebase origin and the same `toImageSync`, summing
`screenSpaceLeafCount` per tile. Deterministic: the 256 run was executed twice
and printed `overdraw=6.888` both times.

**The residue is the finding, and it is not the pad.** An entity larger than a
tile is walked once for every tile it crosses, and no amount of pad reduction
touches that. Decomposing multiplicatively, `measured / area` isolates the
crossing term: **4.50x at 128, 3.06x at 256, 2.68x at 512**. It grows as the
tile shrinks, for the obvious reason -- a stroke of fixed world length crosses
more small tiles -- and it is the *larger* of the two terms at every size.

**Therefore: do not introduce `kTileClipInflate`.** A tile-specific slack
smaller than `kTileSlack` can only attack the area term. Even taking the pad to
zero at 512 -- the maximum possible win -- moves 4.185 to about 2.68, a 36%
reduction of the bake walk, and it does so by reopening defect F1: the padded
cull is what stopped a whole stroke column vanishing at 6 of 41 swept zoom
factors, and a hit-rate saving is not worth a correctness regression. Recorded
as a finding for a later plan, per the brief. The cheaper lever on the same
quantity is the tile size itself, which buys 17.983 -> 4.185 with no correctness
exposure at all.

## 6. The decision: `kTileDevicePixels = 512`

**Blit cost decides nothing, and that is itself a result.** 1.45 / 1.44 / 1.52 ms
of `totalSpan` across a 16x range of tile count (130 / 35 / 12 blits per frame).
A blit is corpus-independent and, on this evidence, very nearly tile-count
independent too. **A sweep that had read this column alone would have found a
0.08 ms spread, called it noise or called it a win for the smallest tile, and
lost criterion 11.** That is the whole justification for the brief's three
columns, confirmed by measurement.

**Bake cost per tile rises with the tile, but sub-linearly, and that is what
picks the large tile.** 4x the area between 128 and 512 costs only 2.2x per tile
(5.70 -> 12.56 ms at the frame level, 2.04 -> 6.00 ms of walk), because the
fixed 32-logical-pixel slack is a shrinking fraction of a growing tile. So the
cost of baking a *whole generation* falls hard: **265.53 -> 105.31 -> 71.97 ms**
of walk. 512 bakes the same pixels for 27% of what 128 charges.

**Criterion 11 -- a pan frame -- is decided by more than twenty to one.**

| TILE_PX | pan `total` mean | pan `total` **p95** | under the 16.67 ms budget at p95? |
|---|---|---|---|
| 128 | 11.05 ms | 65.19 ms | no, by 3.9x |
| 256 | 4.75 ms | 47.42 ms | no, by 2.8x |
| **512** | **2.99 ms** | **2.31 ms** | **yes, with 7.2x of headroom** |

The mechanism is visible in the counters. The pan step is `(-7, -3)` logical =
`(-14, -6)` device per frame, so a tile column enters every `T/14` frames and is
`ceil(1200/T)` tiles tall:

- **128**: a column is 11 tiles, entering every ~9 frames. The budget is 8, so
  the column is *never* baked in the frame it enters -- `liveDraws=18` over 120
  frames, and each of those is a full live walk of a 500,000-entity viewport.
  That is what puts the mean at 11.05 ms and the p95 at 65.19.
- **256**: a column is 5 tiles, entering every ~18 frames, and the budget covers
  it -- `liveDraws=1`. But it covers it *all in one frame*: `bakeFrames=9/120`,
  `maxBakesInAFrame=8`, and that frame costs 47 ms. The stall this plan exists
  to remove has been made rarer, not smaller.
- **512**: a column is 3 tiles, entering every ~37 frames. `bakeFrames=4/120`,
  `maxBakesInAFrame=4`, `liveDraws=0`. p95 is 2.31 ms because 116 of 120 frames
  are pure blits and the four that are not are still small.

**Memory fits.** `visibleSetBytes` at 512 is **12,582,912** on this 1600x1200
device viewport, 48% above 128's 8,519,680 -- and both are small because this
window is a quarter of the plan's reference area. On the 3200x2400 reference
viewport the plan's own arithmetic gives 512 a **48.0 MiB** visible set, which
with the 29.3 MiB carry-over composite is **77.3 MiB against the 96 MiB
`kTileCacheBytes` cap**. It fits, and it is the reason 1024 (80.0 MiB + 29.3 =
109.3) does not. No run in this sweep evicted: `evictions=0(life)` on all three.

**Not changed in this task.** `kTileDevicePixels` in
`packages/jet_cad_2d_flutter/lib/src/tile_cache.dart:25` still reads 256. The
task brief's file list is `main.dart` and `measurement_rig.dart` only, and Step 4
is "decide, and record the decision"; landing the constant and writing the
three columns into the results note is Task 13's step. **The decision is 512 and
the numbers above are what chose it.**

## 7. Concerns and deviations

1. **The bake budget is expressed in tiles, and at 512 it should not be.**
   `kTilesBakedPerFrame = 8` permits eight 512-px bakes -- roughly 100 ms -- in
   one frame. The sweep never hit that ceiling at 512 (`maxBakesInAFrame=4`),
   but `max=88.44 ms` shows what a burst costs when it comes. A budget expressed
   in *device pixels baked per frame* rather than tile count would be
   tile-size-invariant; 8 tiles at 256 is 2 tiles at 512. The `max` column is
   bad at every size (79.53 / 92.62 / 88.44), so this is not a regression 512
   introduces -- but 512 is the size at which the count-based budget stops
   meaning anything. **A finding for a later plan, not changed here.**

2. **`printInvariants` is not comparable across tiled runs, and I did not use
   it.** With `TILES=on` the last painter invocation of a frame is a *bake*, not
   the frame, so `screenSpaceLeafCount` reports one tile: the 512 run prints
   `screenSpaceLeafCount=1402` where 128 and 256 print `4612`. The same applies
   to `triangles` and `canvasCalls`. Every leaf figure in this report comes from
   the probe's `liveLeaves`, which read **4350 on all four sweep runs**. The
   invariant line should probably carry a warning, or the rig should force a
   final live frame before reading it.

3. **The probe's `walkMs` is Dart-side only, and is labelled so.**
   `toImageSync` schedules the rasterisation and returns, so the stopwatch sees
   the walk and the recording and not the GPU. That is exactly the Probe D
   hazard the brief names. It is reported as `walkMs`, and the *frame-level*
   bake cost in the table comes from `totalSpan` mean-differencing over the pan
   regime, which does include the GPU. The two agree in shape (both roughly
   double from 128 to 256 to 512) and the frame-level number is 2-3x the walk,
   which is the rasterisation the walk cannot see.

4. **`liveWalkMs` moved 24.86 / 46.11 / 45.93 / 35.82 ms across four runs of
   identical work** (`liveLeaves=4350` every time). That is a 1.85x spread on a
   single-sample stopwatch, and it is the clearest measure of what this
   machine's background load is doing. It is why no conclusion above rests on a
   single-sample timing: the decision rests on the pan p95 (120 frames), the
   pan mean (120 frames), the hold mean (60 frames) and the leaf counts, which
   are exact integers and reproduced identically on a repeat.

5. **Phase boundaries bleed by two to four frames.** `addTimingsCallback`
   reports a frame after it rasterised, so the rig swaps the collecting bucket
   rather than re-registering the callback (re-registering would *drop* the tail
   of a phase instead of moving it), and pumps two throwaway frames at each
   boundary. The pan phase therefore reports 121-124 frames for a 120-frame loop,
   with the extras being cheap blit frames -- which biases the pan mean *down* by
   at most 2-3%, in the direction that flatters the smaller tiles, not 512.

6. **Deviation from the brief's file list.**
   `apps/dev_harness_2d/integration_test/frame_timing_test.dart` was modified as
   well as `lib/`. `HarnessApp.onReady` had to hand the rig the `TileCache` the
   canvas actually built -- the resolved object, not the define, for the same
   reason `printBackend` prints the resolved backend -- and `boot()` destructures
   that callback. R4a and R4b now print the tile line too, so no rig can produce
   a transcript that is silent about tiles.

7. **The control's first sample missed the raster interval by 1.5%.** Reported
   in full in section 2 rather than dropped. The median of three is inside both
   intervals and the run publishes, but this was a machine with a load average
   between 2.65 and 5.32 throughout, and every absolute number here should be
   read as carrying that. **The decision is unaffected**: it turns on ratios
   between three runs on the same machine within nine minutes of each other, and
   on a 20x separation in pan p95 that no plausible contamination closes.

## 8. Green

```
packages/jet_cad_2d:         797 tests pass, analyze clean, format clean
packages/jet_cad_2d_flutter: 361 tests pass, analyze clean, format clean
apps/dev_harness_2d:         analyze clean, format clean
git diff --stat aa21ee8 -- packages/jet_cad_2d_flutter/test/golden   # empty
```

`apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj` was rewritten by
every `flutter drive` invocation and is **not** staged, per the global
constraint. No `analysis_options.yaml` is staged.
