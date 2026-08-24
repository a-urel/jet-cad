# Task 12 report — criteria 10 and 11 on device, and M7

**No source change is in the tree.** `tile_cache.dart` was mutated for M7 and
restored from a copy-aside; the restore proof is in section 5. Goldens
untouched. There is no commit — this file is git-ignored.

Date: 2026-08-24. Every number below is pasted from a run made in this session.

---

## 1. The machine

Checked immediately before every measurement block, not once at the start.

Before the control (2026-08-24 19:59):

```
 lowpowermode         0
Now drawing from 'AC Power'
 -InternalBattery-0 (id=22282339)	100%; charged; 0:00 remaining present: true
```

Before criterion run 1, run 2, run 3, the M7 red run and the M7 confirmation
run — five further checks, each printed as the first lines of its own command,
all reading identically:

```
 lowpowermode         0
Now drawing from 'AC Power'
 -InternalBattery-0 (id=22282339)	100%; charged; 0:00 remaining present: true
```

Low Power Mode never engaged and the charger never came out. The +30% build /
+47% raster contamination figure did not need to be applied to anything.

---

## 2. The control — reproduced, and inside Plan 3d's intervals

```sh
cd apps/dev_harness_2d
CI=true flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart --profile -d macos \
  --dart-define=TEXT=true --dart-define=ENTITIES=50000 \
  --dart-define=RIG=pan --dart-define=BACKEND=vertices
```

Verbatim:

```
flutter: R2 (50000) frames=242
flutter:   build  p50=7.26ms p95=8.57ms max=313.67ms mean=8.61ms
flutter:   raster p50=8.56ms p95=18.83ms max=114.72ms mean=9.35ms
flutter:   total  p50=15.13ms p95=31.45ms max=436.54ms mean=20.34ms
flutter:   lineweightScale=1.0
flutter:   screenSpaceLeafCount=2170 dashSpans=48323 collapsed=334 canvasCalls=23
flutter:   fills=0 skippedFills=0
flutter:   tiles=off
flutter:   backend=vertices triangles=217758 drawVerticesCalls=20
flutter:   text: corpus=on draw=on minTextCapPixels=3.0 textOps=23 skippedText=0 culledText=0
flutter:   paragraphs: newLayouts=0 newParagraphEvictions=0 newMetricsEvictions=0 liveParagraphs=512 liveMetrics=4020
```

| column | this run | Plan 3d clean row | inside? |
|---|---|---|---|
| build p50 | **7.26 ms** | 7.07 `[7.06, 7.38]` | yes |
| raster p50 | **8.56 ms** | 8.53 `[8.22, 8.63]` | yes |

`tiles=off` on the control arm, as required — the control is provably untiled.
The machine is not talking. Everything below stands on this.

---

## 3. Criteria 10 and 11 — three runs

```sh
CI=true flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart --profile -d macos \
  --dart-define=TEXT=true --dart-define=ENTITIES=500000 \
  --dart-define=RIG=pan --dart-define=BACKEND=vertices --dart-define=TILES=on
```

Shipped constants, confirmed in every transcript by the rig's own line:

```
tiles=on tilePx=512 bakeBudgetPx=262144 bakeBudgetTiles=1
```

**Which line is which criterion.** Criterion 10 is the `tile hold` phase — 60
frames at a fixed camera against a warm generation, `bakeFrames=0/60`, so the
frame is blits and nothing else. Criterion 11 is the `tile pan` phase; only
`14/120` of its frames bake, so its `p50` is a pure-blit frame and the criterion
— *"a pan frame that is baking a newly exposed strip"* — is read from `p95`
(rank 114 of 120 sits inside the top 14) with `max` reported beside it.

### Run 1, verbatim

```
flutter: R2 (500000) frames=242
flutter:   build  p50=23.10ms p95=27.39ms max=1149.03ms mean=19.33ms
flutter:   raster p50=10.04ms p95=40.91ms max=168.49ms mean=13.51ms
flutter:   total  p50=41.09ms p95=70.42ms max=1359.21ms mean=39.86ms
flutter:   screenSpaceLeafCount=4612 dashSpans=146358 collapsed=345 canvasCalls=97 (…)
flutter:   fills=0 skippedFills=0
flutter:   tiles=on tilePx=512 bakeBudgetPx=262144 bakeBudgetTiles=1 liveTiles=2 generation=122 carryOver=true
flutter:   bakes=148 blits=1651 carryOverBlits=121 liveDraws=135 blitDests=3197 evictions=0(life) invalidations=0(life) tileBytes=9777152
flutter:   backend=vertices triangles=734442 drawVerticesCalls=32
flutter:   text: corpus=on draw=on minTextCapPixels=3.0 textOps=74 skippedText=0 culledText=0
flutter:   paragraphs: newLayouts=0 newParagraphEvictions=0 newMetricsEvictions=0 liveParagraphs=512 liveMetrics=4020
flutter:   tile warm: frames=11 liveTiles=12 tileBytes=12582912 evictions=0(life)
flutter:   tile hold frames=59
flutter:   build  p50=0.32ms p95=0.51ms max=0.53ms mean=0.32ms
flutter:   raster p50=1.08ms p95=1.51ms max=1.54ms mean=1.03ms
flutter:   total  p50=1.64ms p95=2.40ms max=30.77ms mean=2.11ms
flutter:     bakeFrames=0/60 maxBakesInAFrame=0
flutter:     bakes=0 perFrame=0.000 blits=720 carryOverBlits=0 liveDraws=0 newEvictions=0 liveTiles=12 tileBytes=12582912
flutter:   tile pan frames=120
flutter:   build  p50=0.17ms p95=28.21ms max=55.33ms mean=3.28ms
flutter:   raster p50=0.50ms p95=8.55ms max=12.22ms mean=1.33ms
flutter:   total  p50=0.83ms p95=37.38ms max=65.77ms mean=4.96ms
flutter:     bakeFrames=14/120 maxBakesInAFrame=1
flutter:     bakes=14 perFrame=0.117 blits=1582 carryOverBlits=0 liveDraws=10 newEvictions=0 liveTiles=26 tileBytes=27262976
flutter:   tile probe: tilePx=512 dpr=2.0 viewport=800x600 tileLogical=256.0 pad=32.0
flutter:     tiles=12 liveLeaves=4350 tileLeaves=18204 overdraw=4.185 areaFactor=1.563
flutter:     liveWalkMs=38.92 tileWalkMsTotal=70.11 walkMsPerTile=5.843 visibleSetBytes=12582912
```

### Run 2, verbatim

```
flutter: R2 (500000) frames=243
flutter:   build  p50=23.32ms p95=27.18ms max=1162.73ms mean=19.35ms
flutter:   raster p50=9.85ms p95=37.01ms max=133.54ms mean=12.96ms
flutter:   total  p50=40.86ms p95=67.17ms max=1345.88ms mean=39.00ms
flutter:   screenSpaceLeafCount=4612 dashSpans=146358 collapsed=345 canvasCalls=97 (…)
flutter:   tiles=on tilePx=512 bakeBudgetPx=262144 bakeBudgetTiles=1 liveTiles=2 generation=122 carryOver=true
flutter:   bakes=148 blits=1651 carryOverBlits=121 liveDraws=135 blitDests=3197 evictions=0(life) invalidations=0(life) tileBytes=9777152
flutter:   backend=vertices triangles=734442 drawVerticesCalls=32
flutter:   tile warm: frames=11 liveTiles=12 tileBytes=12582912 evictions=0(life)
flutter:   tile hold frames=60
flutter:   build  p50=0.32ms p95=0.38ms max=0.40ms mean=0.31ms
flutter:   raster p50=1.06ms p95=1.23ms max=1.32ms mean=1.01ms
flutter:   total  p50=1.58ms p95=1.85ms max=1.93ms mean=1.53ms
flutter:     bakeFrames=0/60 maxBakesInAFrame=0
flutter:     bakes=0 perFrame=0.000 blits=720 carryOverBlits=0 liveDraws=0 newEvictions=0 liveTiles=12 tileBytes=12582912
flutter:   tile pan frames=124
flutter:   build  p50=0.24ms p95=26.77ms max=55.94ms mean=3.26ms
flutter:   raster p50=0.76ms p95=8.41ms max=12.31ms mean=1.47ms
flutter:   total  p50=1.29ms p95=35.67ms max=66.86ms mean=5.08ms
flutter:     bakeFrames=14/120 maxBakesInAFrame=1
flutter:     bakes=14 perFrame=0.117 blits=1582 carryOverBlits=0 liveDraws=10 newEvictions=0 liveTiles=26 tileBytes=27262976
flutter:   tile probe: tilePx=512 dpr=2.0 viewport=800x600 tileLogical=256.0 pad=32.0
flutter:     tiles=12 liveLeaves=4350 tileLeaves=18204 overdraw=4.185 areaFactor=1.563
flutter:     liveWalkMs=31.48 tileWalkMsTotal=68.35 walkMsPerTile=5.696 visibleSetBytes=12582912
```

### Run 3, verbatim

```
flutter: R2 (500000) frames=242
flutter:   build  p50=23.05ms p95=26.25ms max=1146.08ms mean=19.07ms
flutter:   raster p50=9.64ms p95=36.72ms max=123.09ms mean=13.07ms
flutter:   total  p50=39.95ms p95=70.23ms max=1307.56ms mean=38.90ms
flutter:   screenSpaceLeafCount=4612 dashSpans=146358 collapsed=345 canvasCalls=97 (…)
flutter:   tiles=on tilePx=512 bakeBudgetPx=262144 bakeBudgetTiles=1 liveTiles=2 generation=122 carryOver=true
flutter:   bakes=148 blits=1651 carryOverBlits=121 liveDraws=135 blitDests=3197 evictions=0(life) invalidations=0(life) tileBytes=9777152
flutter:   backend=vertices triangles=734442 drawVerticesCalls=32
flutter:   tile warm: frames=11 liveTiles=12 tileBytes=12582912 evictions=0(life)
flutter:   tile hold frames=59
flutter:   build  p50=0.14ms p95=0.39ms max=0.44ms mean=0.21ms
flutter:   raster p50=0.53ms p95=1.20ms max=1.36ms mean=0.69ms
flutter:   total  p50=0.91ms p95=1.96ms max=33.44ms mean=1.65ms
flutter:     bakeFrames=0/60 maxBakesInAFrame=0
flutter:     bakes=0 perFrame=0.000 blits=720 carryOverBlits=0 liveDraws=0 newEvictions=0 liveTiles=12 tileBytes=12582912
flutter:   tile pan frames=117
flutter:   build  p50=0.30ms p95=26.27ms max=54.66ms mean=3.35ms
flutter:   raster p50=0.95ms p95=8.72ms max=12.33ms mean=1.49ms
flutter:   total  p50=1.48ms p95=35.00ms max=65.22ms mean=5.20ms
flutter:     bakeFrames=14/120 maxBakesInAFrame=1
flutter:     bakes=14 perFrame=0.117 blits=1582 carryOverBlits=0 liveDraws=10 newEvictions=0 liveTiles=26 tileBytes=27262976
flutter:   tile probe: tilePx=512 dpr=2.0 viewport=800x600 tileLogical=256.0 pad=32.0
flutter:     tiles=12 liveLeaves=4350 tileLeaves=18204 overdraw=4.185 areaFactor=1.563
flutter:     liveWalkMs=41.64 tileWalkMsTotal=76.91 walkMsPerTile=6.409 visibleSetBytes=12582912
```

### Criterion 10 — the settled frame, `totalSpan`

| | run 1 | run 2 | run 3 | **median** |
|---|---|---|---|---|
| p50 | 1.64 | 1.58 | 0.91 | **1.58 ms** |
| p95 | 2.40 | 1.85 | 1.96 | **1.96 ms** |
| max | 30.77 | 1.93 | 33.44 | 30.77 ms |

**Criterion 10: PASS at 1.58 ms median (p95 1.96 ms), threshold ≤ 4.00 ms.**
Against the untiled 500,000-entity frame's 41.09 ms `totalSpan` measured in the
same run's R2 block, that is a **26× reduction** on the settled frame.

**The `max` column is a bucket-boundary artefact, not a hold frame, and it is
recorded rather than dropped.** The two runs showing it (30.77, 33.44) are
exactly the two whose hold phase reports `frames=59` for 60 pumped frames — a
`FrameTiming` is delivered after its frame rasterised, so the phase's own last
frame landed in the next bucket and a frame from before the swap landed in this
one. It cannot be a hold frame: the phase reports `bakeFrames=0/60`,
`liveDraws=0` and 720 blits for 60 frames, and no frame that only blits twelve
tiles costs 30 ms when the same phase's p95 is 1.96. Its most likely origin is
the settle that precedes the phase — see section 6, where that reading matters.

### Criterion 11 — a pan frame baking a newly exposed strip, `totalSpan`

| | run 1 | run 2 | run 3 | **median** |
|---|---|---|---|---|
| p95 (a baking frame) | 37.38 | 35.67 | 35.00 | **35.67 ms** |
| max | 65.77 | 66.86 | 65.22 | **65.77 ms** |
| mean | 4.96 | 5.08 | 5.20 | 5.08 ms |
| p50 (a pure-blit frame) | 0.83 | 1.29 | 1.48 | 1.29 ms |

**Criterion 11: MISS. 35.67 ms median against a 16.67 ms threshold — 2.1× over
at p95, 3.9× over at `max`.** Reproduced in all three runs, spread 35.00–37.38,
so this is not noise.

The threshold does not move, and this report does not move it.

**Where the cost is, by the rig's own differencing identity.** Using
`mean = blit + bakesPerFrame × bakeFrameCost` on run 2: `(5.08 − 1.29) × 120 /
14 = 32.5 ms` of excess per baking frame. The tile probe puts the bake's *walk*
at **5.7–6.4 ms per tile**, so the walk is under a fifth of it. The rest is the
frame's other work: the same 120 frames report `liveDraws=10` — a frame whose
newly exposed strip is not yet baked draws the uncovered remainder **live**, and
the probe measures a full live viewport walk at **31.5–41.6 ms**. The pan
criterion is missed by the live fallback, not by the bake.

**This matters for the spec's stated remedy.** The spec says that if 16.67 ms is
unreachable the answer is a smaller bake budget. **The budget is already floored
at one tile per frame** (`bakeBudgetTiles=1`, printed in every transcript
above), so that lever is spent — and it points the wrong way regardless: baking
*fewer* tiles per frame leaves the exposed strip uncovered for *more* frames,
each of which then pays the live fallback. A `kTileClipInflate` does not help
either; the overdraw column already reads 4.185 against an area factor of 1.563.
Reporting only, per the brief: no fix attempted.

---

## 4. M7 — fired on device

The mutation, applied to `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`
(`git diff` before the restore):

```diff
@@ -724,7 +724,7 @@ class TileCache {
       if (image == null && budget > 0 && _makeRoomForOneTile()) {
-        image = _bake(key, grid, painter, sink, vertices, origin);
+        image = _bake(key, grid, painter, sink, vertices, origin, viewport);
@@ -1353,6 +1353,7 @@ class TileCache {
     Vector2 origin,
+    Size viewport,
   ) {
@@ -1365,7 +1366,10 @@ class TileCache {
-    into.clipRect(Rect.fromLTWH(0, 0, side, side), doAntiAlias: false);
+    // M7: clip each tile to the viewport instead of to its own rect.
+    into.clipRect(
+        Rect.fromLTWH(0, 0, viewport.width, viewport.height),
+        doAntiAlias: false);
@@ -1407,7 +1411,7 @@ class TileCache {
     _drawInto(
         into,
-        Size(side + 2 * pad, side + 2 * pad),
+        Size(viewport.width + 2 * pad, viewport.height + 2 * pad),
```

**Both expressions of "its own rect" had to change, and the reason is worth
recording.** The clip alone is not the mutant the spec describes. `_drawInto`'s
`Size` argument is what the painter culls against; leaving it at `side + 2·pad`
while widening only the clip would have left every bake walking the same leaves
it walks today — a no-op that would have reported "M7 does not collapse
anything" for the wrong reason. Widening both makes each tile draw a viewport's
worth of content and lets `toImageSync(512, 512)` crop it, which is exactly the
mutant's premise: the display is unchanged, the work is done.

**The mutant was live.** Independent of any timing, the forced-repaint block
changed on fields that count actual drawing: `triangles` **734442 → 1183035**
(+61%) and `canvasCalls` **97 → 150**, identically in both M7 runs.

### M7 run A, verbatim (see the deviation in section 7)

```
flutter: R2 (500000) frames=242
flutter:   build  p50=38.47ms p95=44.59ms max=1462.95ms mean=30.39ms
flutter:   raster p50=9.17ms p95=42.76ms max=144.74ms mean=13.92ms
flutter:   total  p50=56.76ms p95=89.36ms max=1721.78ms mean=53.09ms
flutter:   screenSpaceLeafCount=4612 dashSpans=146358 collapsed=345 canvasCalls=150 (…)
flutter:   tiles=on tilePx=512 bakeBudgetPx=262144 bakeBudgetTiles=1 liveTiles=2 generation=122 carryOver=true
flutter:   bakes=148 blits=1651 carryOverBlits=121 liveDraws=135 blitDests=3197 evictions=0(life) invalidations=0(life) tileBytes=9777152
flutter:   backend=vertices triangles=1183035 drawVerticesCalls=42
flutter:   tile warm: frames=11 liveTiles=12 tileBytes=12582912 evictions=0(life)
flutter:   tile hold frames=60
flutter:   build  p50=0.30ms p95=0.40ms max=0.44ms mean=0.26ms
flutter:   raster p50=0.97ms p95=1.17ms max=1.38ms mean=0.85ms
flutter:   total  p50=1.47ms p95=1.75ms max=2.05ms mean=1.30ms
flutter:     bakeFrames=0/60 maxBakesInAFrame=0
flutter:     bakes=0 perFrame=0.000 blits=720 carryOverBlits=0 liveDraws=0 newEvictions=0 liveTiles=12 tileBytes=12582912
flutter:   tile pan frames=123
flutter:   build  p50=0.24ms p95=40.65ms max=72.55ms mean=4.92ms
flutter:   raster p50=0.90ms p95=8.78ms max=11.27ms mean=1.43ms
flutter:   total  p50=1.37ms p95=49.90ms max=89.13ms mean=7.00ms
flutter:     bakeFrames=14/120 maxBakesInAFrame=1
flutter:     bakes=14 perFrame=0.117 blits=1582 carryOverBlits=0 liveDraws=10 newEvictions=0 liveTiles=26 tileBytes=27262976
flutter:   tile probe: tilePx=512 dpr=2.0 viewport=800x600 tileLogical=256.0 pad=32.0
flutter:     tiles=12 liveLeaves=4350 tileLeaves=18204 overdraw=4.185 areaFactor=1.563
flutter:     liveWalkMs=38.84 tileWalkMsTotal=74.00 walkMsPerTile=6.167 visibleSetBytes=12582912
```

### M7 run B, verbatim (foreground, confirmation)

```
flutter: R2 (500000) frames=242
flutter:   build  p50=39.04ms p95=47.14ms max=1591.95ms mean=31.36ms
flutter:   raster p50=10.69ms p95=37.55ms max=147.71ms mean=13.54ms
flutter:   total  p50=58.19ms p95=84.51ms max=1833.17ms mean=53.80ms
flutter:   screenSpaceLeafCount=4612 dashSpans=146358 collapsed=345 canvasCalls=150 (…)
flutter:   tiles=on tilePx=512 bakeBudgetPx=262144 bakeBudgetTiles=1 liveTiles=2 generation=122 carryOver=true
flutter:   bakes=148 blits=1651 carryOverBlits=121 liveDraws=135 blitDests=3197 evictions=0(life) invalidations=0(life) tileBytes=9777152
flutter:   backend=vertices triangles=1183035 drawVerticesCalls=42
flutter:   tile warm: frames=11 liveTiles=12 tileBytes=12582912 evictions=0(life)
flutter:   tile hold frames=60
flutter:   build  p50=0.28ms p95=0.50ms max=0.54ms mean=0.28ms
flutter:   raster p50=0.71ms p95=1.47ms max=1.51ms mean=0.80ms
flutter:   total  p50=1.24ms p95=2.32ms max=2.44ms mean=1.32ms
flutter:     bakeFrames=0/60 maxBakesInAFrame=0
flutter:     bakes=0 perFrame=0.000 blits=720 carryOverBlits=0 liveDraws=0 newEvictions=0 liveTiles=12 tileBytes=12582912
flutter:   tile pan frames=122
flutter:   build  p50=0.20ms p95=51.70ms max=69.98ms mean=5.83ms
flutter:   raster p50=0.50ms p95=10.83ms max=14.49ms mean=1.46ms
flutter:   total  p50=0.93ms p95=63.62ms max=90.03ms mean=8.02ms
flutter:     bakeFrames=14/120 maxBakesInAFrame=1
flutter:     bakes=14 perFrame=0.117 blits=1582 carryOverBlits=0 liveDraws=10 newEvictions=0 liveTiles=26 tileBytes=27262976
flutter:   tile probe: tilePx=512 dpr=2.0 viewport=800x600 tileLogical=256.0 pad=32.0
flutter:     tiles=12 liveLeaves=4350 tileLeaves=18204 overdraw=4.185 areaFactor=1.563
flutter:     liveWalkMs=34.21 tileWalkMsTotal=89.63 walkMsPerTile=7.469 visibleSetBytes=12582912
```

### What M7 did, and did not, do

| reading | clean (median of 3) | M7 run A | M7 run B | verdict |
|---|---|---|---|---|
| criterion 10, hold p50 | 1.58 | 1.47 | 1.24 | **unchanged** |
| criterion 10, hold p95 | 1.96 | 1.75 | 2.32 | **unchanged** |
| criterion 11, pan p95 | 35.67 | 49.90 | 63.62 | 1.4×–1.8× worse |
| criterion 11, pan max | 65.77 | 89.13 | 90.03 | 1.35× worse |
| R2 build p50 | 23.10 | 38.47 | 39.04 | 1.67× worse |
| R2 total p50 | 41.09 | 56.76 | 58.19 | 1.4× worse |

**M7 did not collapse criterion 10, and it cannot.** The settled frame bakes
nothing — `bakeFrames=0/60` in every run, clean and mutated alike — so the clip
M7 breaks is never executed in the frame criterion 10 measures. The hold column
under M7 is inside the clean run-to-run spread. **Criterion 10 is structurally
blind to M7**, and no threshold change would fix that: the criterion measures a
frame in which no bake occurs.

**M7 degraded criterion 11 but did not turn it red, because it was already
red.** 35.67 ms clean → 49.90/63.62 ms mutated, against a 16.67 ms threshold
that the shipped code misses by 2.1× before any mutation. A criterion that fails
on clean source does not distinguish the mutant from the original; there is no
green-to-red transition anywhere.

**So: nothing in Plan 3g gates per-tile clipping.** Criteria 1–9, 12 and 13
pass under M7 by construction (the blit shows only a tile's own rect and
`toImageSync` crops the rest). Criterion 10 cannot see it. Criterion 11 is red
either way. The mutation *is* visible on this rig — R2 `build p50` moves 23.10 →
38.47 and the forced repaint's triangle count moves 734442 → 1183035, both
reproduced twice — but no criterion in the exit gate reads either of those.
Saying this plainly, as the brief asks: **M7 is unkilled, and the spec's claim
that "criteria 10 and 11 collapse" is half wrong — 10 is blind by construction,
11 is already failing.**

**One more instrument that cannot see M7, worth recording:** the rig's `tile
probe` reports `overdraw=4.185` bit-for-bit identically in the clean and mutated
runs. `_probeBake` in `measurement_rig.dart` reimplements the bake geometry
rather than calling `TileCache._bake`, so the overdraw column measures what the
cache *should* do, never what it does. Anyone reading that column as evidence
about the shipped clip is reading a copy of the specification.

---

## 5. Restore proof

Copy-aside taken before the mutation, `shasum` matching the tree:

```
394f63ef67a6576e728eac7c5846f7caaff6bcbb  packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
394f63ef67a6576e728eac7c5846f7caaff6bcbb  <scratchpad>/tile_cache.dart.orig
```

Restored by `cp` from the copy-aside, never `git checkout`, then:

```
$ diff <scratchpad>/tile_cache.dart.orig packages/jet_cad_2d_flutter/lib/src/tile_cache.dart && echo "DIFF CLEAN"
DIFF CLEAN
$ shasum packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
394f63ef67a6576e728eac7c5846f7caaff6bcbb  packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
$ git status --short
$ git diff --stat
```

`git status --short` and `git diff --stat` both print nothing: the working tree
is clean, including `apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj`
and every `analysis_options.yaml`. There is no commit.

---

## 6. The one-tile budget's settle, which nobody had measured

`kBakeBudgetDevicePixels` was floored at one 512 px tile per frame *after* Task
11's sweep, which ran at eight. Every transcript above confirms the shipped
value took effect: `bakeBudgetTiles=1`, and `maxBakesInAFrame=1` in both phases
of all five 500,000-entity runs.

**How many frames the settle takes: 11.** `tile warm: frames=11` in run 1, run
2, run 3, M7 run A and M7 run B — five for five, no variance. The rig warms
until a frame bakes nothing; it takes 11 to refill the 12-tile visible set
(`liveTiles=12`) after the zoom phase drops the generation, which is the one
tile per frame the budget allows.

**Whether any frame in it misses the budget: yes — on the evidence, most of
them, and the settle is roughly a third of a second of missed frames.** The rig
does not report per-frame timings for the warm loop (its frames land in a bucket
already reported), so this is inference from three measurements, and it is
labelled as such:

1. A settle frame does strictly more work than a pan frame that bakes. After a
   zoom the generation is empty, so every one of the 11 frames bakes its one
   permitted tile *and* draws the uncovered remainder live. The measured cost of
   a single live viewport walk is **31.5–41.6 ms** (`liveWalkMs`, five runs),
   before the bake and before rasterisation.
2. A pan frame that bakes one tile with a *mostly covered* viewport already
   costs **35.67 ms** (section 3). A settle frame's viewport is not mostly
   covered.
3. The direct sighting: two of the three clean runs put a **30.77 ms** and a
   **33.44 ms** frame in the hold bucket, a phase with `bakeFrames=0/60` and
   `liveDraws=0` whose p95 is 1.96 ms. That frame is not a hold frame; it is a
   frame from before the bucket swap, and the settle is what immediately
   precedes it. 30–33 ms is precisely the cost a settle frame predicts.

So the one-tile budget converts what an eight-tile budget would have made a
short expensive burst into **11 consecutive frames of roughly 30–40 ms each —
about 350–450 ms of visible catch-up after every zoom**, each frame missing the
16.67 ms budget by 2× or more. The budget change removed the single-frame
hiccup criterion 11 was written against (`maxBakesInAFrame=1`, and M9 — "bake
the whole visible set in one frame" — is what it defends against) and spread the
same work across a settle no criterion in the exit gate measures. Reporting
only; no fix attempted.

---

## 7. Deviations

1. **M7 run A completed with its shell backgrounded.** The mutation forces a
   full macOS app rebuild, and the `flutter drive` command exceeded the 600 s
   tool timeout during it; the harness moved the shell to the background and
   the run finished there. The brief requires foreground runs because a
   *launched-in-background* run stalls at 0% CPU waiting for a frame the
   windowing system never requests. That failure did not occur here — the app
   was sampled at **42.6% CPU** mid-run, and the run completed with a full
   transcript. It was nonetheless re-run in the **foreground** (M7 run B, with
   the build already cached) and both agree: hold unchanged, pan p95 49.90 vs
   63.62, R2 `build p50` 38.47 vs 39.04. Both are published above; neither
   conclusion depends on run A alone.
2. **`Failed to foreground app; open returned 1`** is printed by `flutter drive`
   on every run in this environment, the control included. Every run still
   produced frames and a full transcript, and the control landed inside Plan
   3d's intervals, so it is a launcher message rather than a stalled run.
3. **Criterion 11 is read from the pan phase's `p95`**, with `max` reported
   beside it, because only 14 of 120 pan frames bake and the phase's `p50` is
   therefore a pure-blit frame. Both readings miss the threshold; the choice
   between them does not change the verdict.
