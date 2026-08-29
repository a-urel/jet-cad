# Vector gesture replay — a throwaway spike, and its negative result

**Date:** 2026-08-29. **Branch:** `spike/vector-gesture-replay`, cut from
`1d71d61`, **deleted after this note was written.** Its two commits were
`26236d9` (`TileCache.debugVectorGestureReplay`, `VECTOR_REPLAY=on|off`,
`ZOOM_MODE=vector`) and `a533c46` (the instruments). They are recoverable from
the reflog for as long as git keeps it; nothing else references them.

**Status: answered, negative.** The idea is rejected on per-frame cost, before
its aesthetics get a vote.

---

## The question

Plan 3i's moving frame blits the carry-over composite and returns, so during a
zoom gesture the screen shows the previous generation's tiles, magnified and
bilinearly filtered. That is a map application's behaviour, and the human
asked whether it is right for a CAD drawing.

The probe: **during a zoom gesture, is a sharp-but-wrong-lineweight vector
replay better to look at than a blurry-but-correct-proportion bitmap?**

## What had to be corrected before it could be built

The obvious framing — "keep the `Picture` instead of the `Image`" — does not
work, and understanding why is most of what this spike is worth.

`_retireGeneration`'s picture is a list of `drawImageRect` calls onto tile
bitmaps. Replaying **that** under a new transform still scales bitmaps and is
exactly as blurry as blitting the composite. Sharpness requires recording the
painter's own walk — `_drawInto` — so the replay carries real geometry.

That is what the spike built.

## The result: per-frame cost rules it out

Gesture frames, interleaved arms in one session, blit versus replay:

| | 50,000 entities | 500,000 entities |
|---|---|---|
| p50 | 1.23 → 6.49 ms (**5.3x**) | 1.16 → **26.61 ms** (**22.9x**) |
| p95 | 1.97 → 13.07 ms | 1.82 → 31.56 ms |
| extra settle walk (median) | +12.08 ms | +29.57 ms |
| picture memory | 10.07 MB (composite 20.16) | **23.01 MB** (composite 20.16) |

The extra settle walk is +34.8 ms in-frame at 500,000, a 33% longer settle.

### Why it is structural, not tunable

Impeller must transform and re-rasterise **every vertex of the recorded
viewport, every frame** — 1.9 M vertices at 500,000 entities. `clipRect`
discards fragments; it does not discard vertex work. And the geometry is at its
worst at the top of a zoom-in, where roughly 90% of the recording is off screen
and still transformed.

Stated as complexity: **the composite blit is O(viewport); the replay is
O(visible geometry) per frame.** That is precisely the complexity the tile
cache exists to remove from the gesture path, put back.

### Memory inverts with corpus size

At 50,000 the picture is half the composite's cost; at 500,000 it is 14% more,
and it keeps growing while the composite stays fixed at the viewport's size.
The saving argument runs backwards exactly where it would have mattered.

## The lineweight error, measured

The replay draws at the recording camera's lineweight, so the error was
expected. What it actually is:

- **Uniform 3.26x on the vertices backend**, confirmed by two independent
  statistics: 3.25 from stroke widths, 3.096 from total ink.
- **Dash spacing stays correct** — `DraftPainter._dashScale` multiplies the
  pattern by `toScreen.scaleMagnitude`, so the pattern is world-proportional
  and survives the transform.
- **The canvas backend behaves differently, and worse to look at.** Its
  minimum-width floor escapes the transform: hairline strokes measured 2 px
  before and 2 px after, ratio 1.00, while the thicker strokes around them are
  3.26x wrong. A **mixed population** reads as stranger than a uniform error.

## Gates

With the flag off, on the spike branch: **797** engine, **414** widget with
1 pre-existing skip, **72** harness. Analyze and format clean in all three.
The flag is default false with no `lib/` writer.

## The caveat that must travel with these numbers

**The machine regressed to `lowpowermode 1` and Battery Power during the
spike** (98%, discharging). Every absolute millisecond here is therefore **not
comparable** to the tables in Plans 3d through 3i, which were taken on AC with
low power mode off. The **interleaved ratios survive** — both arms ran in one
session under the same conditions — and the ratios are what the decision rests
on. Anyone wanting the absolutes must re-run on AC.

## Verdict, and the next idea

Rejected. The cost is structural and arrives before the question the spike was
asked to answer.

**The next thing to test is re-rasterising a *coarse* picture — the
level-of-detail geometry Plan 3i's spec declined, gap G3 — not the full walk.**
The measurement says the expensive thing is replaying *all* the geometry every
frame; a coarse recording could buy the same sharpness at a fraction of the
vertex count. That is a different spike and it is not scheduled.

Gap G3 remains open on the terms `STATUS.md` already records: it becomes
necessary the day the target changes to correct geometry while the fingers are
still moving.
