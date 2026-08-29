# Which settle defect — a throwaway probe, and a decisive answer

**Date:** 2026-08-29. **Branch:** `spike/flutter-gpu-backend`.
**Probe:** `packages/jet_cad_2d_flutter/test/settle_defect_probe_test.dart`,
**deleted after this note was written.** It is reproducible from the numbers
and the method below.

**Status: answered, and it corrects the report that prompted it.** The human,
using the running product, reported a visible flicker **after every pan and
zoom**. The measurement says: **zoom flickers, pan does not, and neither is a
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

## What this settles

1. **There is no stale-frame defect.** Both gestures reach zero differing
   pixels and stay there. `a79903b`'s fix holds and `tile_settle_test.dart`'s
   pin is honest.
2. **The zoom flicker is real, and it is the resolution change.** It spans
   **three frames** — two of them wrong by 141.7% and 93.6% of the frame's ink,
   then a snap to exact. At 60 Hz that is a ~50 ms two-step transition, which
   is comfortably visible.
3. **A pan does not flicker at all**, at any distance tested. This is
   structural rather than lucky: at constant scale the tile lattice is
   reusable and newly exposed tiles are baked, whereas a zoom changes the
   scale the lattice is anchored at and the composite must be magnified.

**The report that prompted this said "pan and zoom".** On this fixture, pan is
exact. Either the product observation includes something this fixture does not
model — a different corpus, a gesture that combines pan with zoom, a
device-pixel-ratio or window-size change mid-gesture — or the pan half of the
report is the zoom half misattributed. **That is not resolved here**, and the
design spec must not claim the pan case until it is.

## What this means for the GPU-resident backend spec

- **The motivation survives, narrowed to zoom.** A three-frame transition at
  141.7% of ink is exactly the defect a single-representation backend cannot
  have.
- **It also narrows the claim.** "No flicker after pan and zoom" is not
  supported; "no flicker after a zoom" is.
- **Criterion 12 now has its target numbers**: reproduce 25,275 / 16,681 / 0
  across the three settle frames on the tiled arm, and show the resident arm
  flat across the same gesture.

## Reproducing it

Rebuild the probe from `support/tile_fixture.dart` and
`support/tile_comparison.dart`:

```dart
final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 64);
for (var i = 0; i < 8; i++) await measureTiledAgreement(rig); // reach rest
final c = CameraController(rig.camera);
for (var i = 0; i < 12; i++) {
  c.zoomAt(Offset(kTileViewport.width / 2, kTileViewport.height / 2), 1.02);
  rig.camera = c.value;
  print(await measureTiledAgreement(rig));      // gesture frames
}
for (var i = 0; i < 6; i++) print(await measureTiledAgreement(rig)); // settle
```

## What was not measured

- **Anything on a device.** This is a widget-suite fixture at
  `kTileDpr = 2.0`, not the running application the report came from.
- **A combined pan-and-zoom gesture**, which is what a trackpad actually emits
  and which neither arm above isolates.
- **The perceptual question.** 141.7% of ink differing says the frames are very
  different; it does not say the transition reads as a flicker rather than as a
  sharpen. Only the human can answer that, and the answer decides whether the
  spec's motivation stands.
