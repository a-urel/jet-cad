# Which settle defect — a throwaway probe, and a decisive answer

**Date:** 2026-08-29. **Branch:** `spike/flutter-gpu-backend`.
**Probe:** `packages/jet_cad_2d_flutter/test/settle_defect_probe_test.dart`,
**deleted after this note was written.** It is reproducible from the numbers
and the method below.

**Status: answered, in two passes, and the first pass was wrong by omission.**
The human reported a visible flicker **after every pan and zoom**; asked which,
they said **regions newly entering the screen are drawn late**. The measurement
says: **a zoom-out leaves up to 5,730 pixels of ink unpainted for the length of
the gesture plus one frame; a zoom-in shows the right ink at the wrong
resolution for three frames; a pan does neither; and none of the three is a
stale frame.**

---

## The question

`2026-08-29-gpu-resident-render-backend-design.md` opened with the flicker as
its motivation, which made "which defect is it?" the question that decides
whether the design is motivated at all. Two candidates:

1. **A stale frame** — the composite still on screen after the gesture ended,
   because nothing asked for another frame. `a79903b` fixed one arm of that and
   `tile_settle_test.dart:186` pins it at zero differing pixels.
2. **The resolution change itself** — the frames over which a magnified
   composite is replaced by freshly baked tiles. The cache working as designed,
   and still a visible flicker.

## Method, and the instrument that could not do it

Every frame is compared against a **live reference at the same camera**, never
against its predecessor. A predecessor comparison is the obvious instrument and
it is the wrong one: it fires on any frame that changes, including the correct
ones, and it would fire on a resident backend too.

**The widget-boundary instrument cannot read these states, and that is recorded
because it cost a first attempt.** `captureTiled` goes through
`RenderRepaintBoundary.toImage`, which asserts `!debugNeedsPaint` — and
`captureTiledFrame`'s own doc comment predicts exactly this: *"Precisely the
states this reads — an unsettled cache one frame after the camera stopped — are
the ones that leave it dirty."* The probe therefore uses the rig path, where
each `measureTiledAgreement(rig)` **is** a frame at the rig's current camera.

Fixture: `TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 64)` — the shipping
budget, `262144 / (64 * 64)`, over `kTileViewport`'s 13 x 10 = 130 tiles. Twelve
gesture steps, then six settle frames.

## The numbers

`differing` is `differingPixels` against the live reference; the percentage is
of the live frame's ink, which is why it can exceed 100% — a magnified
composite both puts ink where the reference has none and misses ink where it
has some.

### Zoom, twelve steps of 1.02 about the viewport centre

| frame | differing | live ink | of ink |
|---|---|---|---|
| at rest, before the gesture | **0** | 19,860 | 0.0% |
| last gesture frame | **25,275** | 17,831 | **141.7%** |
| settle frame 1 | **25,275** | 17,831 | **141.7%** |
| settle frame 2 | **16,681** | 17,831 | **93.6%** |
| settle frame 3 | **0** | 17,831 | 0.0% |
| settle frames 4-6 | 0 | 17,831 | 0.0% |

### Pan, twelve steps of 20 logical pixels

| frame | differing | live ink | of ink |
|---|---|---|---|
| every frame, gesture and settle | **0** | 12,602-21,702 | 0.0% |

**The pan distance is a fixture parameter and the first run got it wrong.**
Twelve steps of 4 px is 48 logical px — 96 device pixels, one and a half
64-pixel tiles — which the cache's slack ring absorbs, so the first probe read a
pan as flawless when it had barely panned. Re-run at 20 px per step (240 px,
480 device pixels, seven and a half tiles, past the ring and into territory
never baked) the answer is **unchanged: zero on every frame.**

## The correction: v1 asked half the question

**v1 zoomed only *in*, and a zoom-in can never expose anything new** — it
magnifies what is already on screen. When the human said the defect is that
**regions newly entering the screen are drawn late**, v1 had no arm that could
see it. That is the degenerate fixture `CLAUDE.md` names, authored by this
probe rather than inherited.

v2 adds a **zoom-out** arm — the gesture that pulls unseen document into the
viewport — and prints `uncoveredPixels`, live ink the tiled frame does not
have, rather than `differingPixels` alone.

### Zoom out, twelve steps of 0.94

| frame | uncovered | stray | differing | live ink | tiled ink |
|---|---|---|---|---|---|
| at rest | 0 | 0 | 0 | 19,860 | 19,860 |
| gesture frame 9 | **2,836** | 1,030 | 12,420 | 12,460 | 10,654 |
| gesture frame 10 | **5,730** | 0 | 9,706 | 12,735 | 7,005 |
| gesture frame 11 (last) | **4,893** | 0 | 10,549 | 11,967 | 7,074 |
| settle frame 1 | **4,893** | 0 | 10,549 | 11,967 | 7,074 |
| settle frame 2 | **0** | 0 | 0 | 11,967 | 11,967 |

**That is the reported defect, measured.** Up to 5,730 device pixels of ink the
frame should be showing are simply not there, and the state persists **one full
frame after the gesture ends** before it fills in.

### Pan, on a fixture wide enough to pan within

The pan arms were re-run on a purpose-built `wideGrid` spanning world
-400..800 — screen -597..1083 against a 400-pixel viewport. **This mattered:
both shipped fixtures are sized against `kTileViewport`, so v1's fast pans ran
off the document entirely and `liveInk` went to zero. Two blank frames agree
perfectly, which is what v1's clean pan result was measuring.**

| pan step | live ink at the last gesture frame | uncovered, every frame |
|---|---|---|
| 20 px | 41,464 (fully in content) | **0** |
| 80 px | 4,246 | **0** |

**A pan does not lose regions**, at any speed where content is present. This is
structural: at constant scale the tile lattice is reusable and a newly exposed
strip is a bake, whereas a zoom changes the scale the lattice is anchored at
and invalidates everything.

## What this settles

1. **There is no stale-frame defect.** Every arm reaches zero and stays there.
   `a79903b`'s fix holds.
2. **A zoom-out leaves regions unpainted** — up to 5,730 pixels of missing ink,
   persisting one frame past the end of the gesture. **This is the defect the
   human reports.**
3. **A zoom-in flickers differently**: nothing is missing, but the frame is the
   wrong resolution — 141.7% then 93.6% of the frame's ink differing, over
   three frames.
4. **A pan does neither**, on any fixture where content exists to pan into.

**The report said "pan and zoom".** On the measurement, the pan half is not
reproducible and the zoom half is two distinct defects depending on direction.

## What this probe's granularity does not model

**The shipping tile is 512 device pixels and the bake budget is
`kBakeBudgetDevicePixels = 262144` — one tile per frame.** This probe ran 64
device-pixel tiles at 64 tiles per frame: the same area budget, a very
different granularity. With 512-pixel tiles, exposing ten pixels of new area
still costs a whole tile and still takes a frame, so **the shipping settle is
coarser than these numbers and plausibly worse.** The direction of the defect
is measured here; its magnitude in the running application is not.

## Reproducing it

Rebuild from `support/fixtures.dart`, `support/tile_fixture.dart` and
`support/tile_comparison.dart`. **Print the whole `InkReport`, not
`differingPixels`** — `uncoveredPixels` is the number that names this defect —
**and zoom out, not in.**

```dart
final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 64);
for (var i = 0; i < 8; i++) await measureTiledAgreement(rig); // reach rest
final c = CameraController(rig.camera);
for (var i = 0; i < 12; i++) {
  c.zoomAt(Offset(kTileViewport.width / 2, kTileViewport.height / 2), 0.94);
  rig.camera = c.value;
  print(await measureTiledAgreement(rig));      // gesture frames
}
for (var i = 0; i < 6; i++) print(await measureTiledAgreement(rig)); // settle
```

For the pan arms, build a grid spanning world -400..800 rather than using
`crossingGrid` or `fillingGrid`; both are sized against `kTileViewport` and a
pan runs off them.

## What was not measured

- **Anything on a device.** This is a widget-suite fixture at
  `kTileDpr = 2.0`, not the running application the report came from.
- **A combined pan-and-zoom gesture**, which is what a trackpad actually emits
  and which neither arm above isolates.
- **The perceptual question.** 141.7% of ink differing says the frames are very
  different; it does not say the transition reads as a flicker rather than as a
  sharpen. Only the human can answer that, and the answer decides whether the
  spec's motivation stands.
