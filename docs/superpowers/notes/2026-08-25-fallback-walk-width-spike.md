# The live fallback walks the whole viewport — a Plan 3h spike

**Date:** 2026-08-25. **Tree:** `main` at `52f37c5`, plus a throwaway change
that has been reverted. **Machine:** macOS, `flutter drive --profile -d macos`,
Low Power Mode `0`.

**Status: spike. Its output is this answer; the code is gone from the tree.**
It exists so Plan 3h's spec can argue from a measurement instead of from the
diagnosis Plan 3g handed forward.

## What Plan 3g handed forward, and why it is not quite right

> **Criterion 11 MISSES by 2.1x**: a baking pan frame reads 35.67 ms against
> 16.67. The cause is not the bake — a bake walk is 5.7-6.4 ms per tile, and
> the frame's ~32 ms of excess is the **live fallback drawing the still-
> uncovered strip**. The spec's own prescribed remedy is spent: it said the
> answer was a smaller bake budget, and the budget is already one tile.

The attribution is right and the conclusion does not follow. **The fallback was
never drawing a strip.** `TileCache.paintFrame` clipped to the uncovered union
and then handed the painter the **whole viewport**:

```dart
canvas.clipRect(uncovered, doAntiAlias: false);
_drawInto(canvas, viewport, quantised, painter, sink, vertices, origin, null);
```

`DraftPainter.paint` derives its index query from `camera.visibleWorld(viewport)`
(`draft_painter.dart:338`) and feeds that rect to both `forEachInstanceInRect`
and `forEachInRect`. So every fallback tessellated the entire frame and the clip
discarded most of it. The results note's own figure says as much without
drawing the conclusion: it recorded the fallback as "a full live walk at
31.5-41.6 ms" — full-frame cost, because it was a full-frame walk.

**The comment above it names the right unit and the code below uses another:**
"One walk for the union, not one per tile" is a sound argument against 48
painter invocations, but the walk was over the viewport, not over the union.

## The change that was measured, and then reverted

Walk the uncovered union instead: clip as before, translate the canvas to the
strip's corner, offset the camera by the same amount, and pass the strip's
size. This is `_bake`'s own technique — it already does exactly this for a
tile, pad included.

Two properties are not optional, and the second was found by measuring:

1. **Pad by `kTileSlack`.** A stroke whose centreline is outside the strip
   still inks pixels inside it. `_bake` pads for this reason and F1 is what an
   unpadded query cost last time.
2. **Then clamp to the viewport.** Padding a union that already spans the frame
   asks for 464 x 364 logical pixels where the untiled path asks for 400 x 300
   — a third more area than the baseline this is meant to undercut.

## Numbers

`tile pan` p95, 500,000 entities, `TILES=on`, same machine, same day. Every run
below reports `bakes=14 liveDraws=10 blits=1582 bakeFrames=14/120` — **the work
composition is identical across all three columns and only its cost moves.**

| `tile pan` p95 | clean | narrowed, unclamped | narrowed + clamped |
|---|---|---|---|
| `build` | 32.50 ms | 22.12 ms | **14.65 ms** |
| `raster` | 10.34 ms | 5.91 ms | **2.42 ms** |
| **`total`** | **43.13 ms** | 30.83 ms | **16.66 ms** |
| `max` | 67.97 ms | 53.36 ms | 38.23 ms |
| vertex buffer | 192.00 MiB | **384.00 MiB** | 192.00 MiB |

Three runs of the clamped arm: **16.66, 15.26, 17.40**, median **16.66**.

**Criterion 11's threshold is 16.67 ms, and this reaches it rather than passing
it.** Two of three runs land under, one lands over. The honest statement is the
effect, not the verdict: **43.13 to 16.66, a 2.6x reduction, leaving the frame
inside the threshold's noise band instead of 2.6x outside it.**

## The unclamped run is evidence for something else

The middle column doubled the vertex buffer's high-water mark, 192.00 to 384.00
MiB, on a run whose every other counter was identical. **That is the first
direct evidence for what
[the high-water note](2026-08-25-vertex-buffer-high-water.md) could only
infer**: the mark is driven by the *rectangle a walk is given*, not by the
corpus. Widening one walk by a third of its area was enough to cross a
doubling. Whatever Plan 3j does about the 192 MiB, that is where the lever is.

## What this spike could NOT establish, and the reason matters

**Nothing in the suite can tell a correct narrowing from an incorrect one.**

The narrowed fallback was run against the full widget suite and it stayed green
— and that green means nothing here. Every pixel comparison in
`tile_cache_test.dart` runs at `tilesBakedPerFrame: 1000`, where the first
frame bakes the whole visible set, `uncovered` is null, and **the live fallback
never executes under any pixel gate at all**. The two restricted-budget tests
that do reach it assert counters.

This was not reasoned. A gate was written for the partly-baked frame and then
its instrument was checked by deliberately breaking the thing it was supposed
to catch:

| narrowing | differing pixels |
|---|---|
| padded by `kTileSlack` | 0 |
| unpadded (`pad = 0`) | 0 |
| **shrunk 20 logical px inside the strip** | **0** |

A query crippled by 20 pixels changed no pixel. Three fixtures were tried — a
cold cache at a small budget, a pan, and a zoom-then-pan — and none produced a
loss the comparison could see. The cold-budget arrangement fails because the
uncovered union is then very nearly the whole viewport, so its boundary *is*
the viewport edge, where nothing outside can be lost; the panned arrangements
fail because `crossingGrid` does not fill the viewport, so the strip that
enters lands outside the drawing.

**So this spike ends with a measured speed-up and an unmeasured correctness.**
Not "the change is wrong" — "the suite cannot see whether it is", which is a
different sentence and the one Plan 3g's thirteen disguises were all built out
of losing.

## Recommendation to Plan 3h

1. **Take the narrowing, and take it first** — it is 2.6x on the criterion the
   plan exists to fix, and the counters prove it removes waste rather than
   work.
2. **Its blocking prerequisite is an instrument, not code.** Something that
   compares a partly-baked frame against a live one *and can be shown to detect
   a deliberately crippled query*. A single clever fixture did not do it; the
   shape that has worked in this repository is a **camera sweep** measuring a
   **bounded** disagreement rather than asserting zero — `nearAxisDiagonals`
   is the precedent.
3. **The design question survives, at a smaller size.** A pan frame still has
   no covered path; what changed is that the gap to close is about 1.0x rather
   than 2.6x, and the cheap part is already priced.
