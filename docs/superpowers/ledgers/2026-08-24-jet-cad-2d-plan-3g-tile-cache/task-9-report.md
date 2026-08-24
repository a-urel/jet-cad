# Task 9 report — the generation, the carry-over composite, and the zoom path

**Files changed**
- `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`
- `packages/jet_cad_2d_flutter/test/tile_cache_test.dart`
- `packages/jet_cad_2d_flutter/test/support/tile_fixture.dart` (deviation D2)

Produces `TileCache.hasCarryOver` and `TileCache.carryOverBlitCount`, as the
brief's interface line requires.

---

## 1. The failing run

Step 1's tests written, implementation untouched. The failure is a compile
error, which is the honest first state: `hasCarryOver`, `carryOverBlitCount`
and a settable `tilesBakedPerFrame` do not exist.

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_cache_test.dart
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart
test/tile_cache_test.dart:390:22: Error: The getter 'hasCarryOver' isn't defined for the type 'TileCache'.
 - 'TileCache' is from 'package:jet_cad_2d_flutter/src/tile_cache.dart' ('lib/src/tile_cache.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'hasCarryOver'.
    expect(rig.cache.hasCarryOver, isTrue,
                     ^^^^^^^^^^^^
test/tile_cache_test.dart:405:15: Error: The setter 'tilesBakedPerFrame' isn't defined for the type 'TileCache'.
 - 'TileCache' is from 'package:jet_cad_2d_flutter/src/tile_cache.dart' ('lib/src/tile_cache.dart').
Try correcting the name to the name of an existing setter, or defining a setter or field named 'tilesBakedPerFrame'.
    rig.cache.tilesBakedPerFrame = 0;
              ^^^^^^^^^^^^^^^^^^
test/tile_cache_test.dart:412:22: Error: The getter 'carryOverBlitCount' isn't defined for the type 'TileCache'.
 - 'TileCache' is from 'package:jet_cad_2d_flutter/src/tile_cache.dart' ('lib/src/tile_cache.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'carryOverBlitCount'.
    expect(rig.cache.carryOverBlitCount, 8,
                     ^^^^^^^^^^^^^^^^^^
test/tile_cache_test.dart:440:15: Error: The setter 'tilesBakedPerFrame' isn't defined for the type 'TileCache'.
 - 'TileCache' is from 'package:jet_cad_2d_flutter/src/tile_cache.dart' ('lib/src/tile_cache.dart').
Try correcting the name to the name of an existing setter, or defining a setter or field named 'tilesBakedPerFrame'.
    rig.cache.tilesBakedPerFrame = 0;
              ^^^^^^^^^^^^^^^^^^
test/tile_cache_test.dart:489:24: Error: The getter 'hasCarryOver' isn't defined for the type 'TileCache'.
 - 'TileCache' is from 'package:jet_cad_2d_flutter/src/tile_cache.dart' ('lib/src/tile_cache.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'hasCarryOver'.
```

---

## 2. The passing run

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_cache_test.dart
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart
00:00 +0: a first frame bakes up to its budget and draws the rest live
00:00 +1: a warm frame bakes nothing and blits the whole visible set
00:00 +2: the blit Paint is one instance for the life of the cache
00:00 +3: the blit hands drawImageRect the same Paint object every time, not a call-site-local one
00:00 +4: criterion 1: a warm tiled frame equals the live frame exactly
00:00 +5: criterion 1: and it still holds after twenty-three awkward pans
00:00 +6: criterion 2: a fixture crossing tile boundaries still matches
00:00 +7: M17 regression: a bake hands the sink a residual, not a raw site-plan-magnitude coordinate
00:00 +8: criterion 3: text survives the tile round trip
00:00 +9: criterion 4: overlapping translucent strokes composite identically
00:00 +10: M11 regression: the blit composites with srcOver, so a tile leaves what is beneath it alone wherever it has no ink of its own
00:00 +11: criterion 8: a pan drops nothing and a scale change drops everything
00:00 +12: a zoom gesture blits the carry-over and bakes nothing
00:00 +13: the gesture frame the carry-over serves is not blank
00:00 +14: the settle spreads its bakes across frames
00:00 +15: criterion 1: a settled frame equals the live frame after a zoom
00:00 +16: defect F1: a stroke centreline just outside a tile is culled from it the loss is one stroke column, and it is ink lost rather than moved
00:00 +17: a whole-document change clears the carry-over as well as the tiles
00:00 +18: a table edit drops the generation without minting a carry-over
00:00 +19: accepted gap: near-axis strokes displace a bounded number of pixels the ten-line fan stays inside the bound
00:00 +20: accepted gap: near-axis strokes displace a bounded number of pixels the worst single slope measured stays inside the bound
00:00 +21: accepted gap: near-axis strokes displace a bounded number of pixels the same camera and tile size agree exactly on axis-aligned ink
00:00 +22: All tests passed!
```

Both packages, the whole gate:

```
$ cd packages/jet_cad_2d       && CI=true dart test        -> 00:02 +797: All tests passed!
                                  dart analyze             -> No issues found!
                                  dart format --set-exit-if-changed .
                                                           -> Formatted 113 files (0 changed)
$ cd packages/jet_cad_2d_flutter && CI=true flutter test   -> 00:05 +349 ~1: All tests passed!
                                  flutter analyze          -> No issues found! (ran in 1.1s)
                                  dart format --set-exit-if-changed .
                                                           -> Formatted 62 files (0 changed)
                                  CI=true flutter test --tags golden
                                                           -> 00:05 +35: All tests passed!
```

---

## 3. What was built, and why the tests demanded that shape

### The composite

`_retireGeneration(Size viewport)` (R2's argument) records every live tile into
one `Picture` at viewport size, `toImageSync`es it at `ceil(viewport * dpr)`
device pixels, disposes the tiles, and stores the image with the screen space
it was recorded in.

Three things the tests forced that the brief did not spell out:

**(a) The composite is anchored to `_lastCamera`, not to `grid.anchor.`** A
generation outlives many pans; the anchor describes the camera the *first*
frame of that generation ran at, and its viewport rectangle need not hold
anything the user can currently see. Criterion 8 pans twelve times before it
zooms, so a composite recorded against the anchor would have been a picture of
somewhere else. `_lastCamera` is the quantised camera of the last `paintFrame`,
which is exactly what was on screen.

**(b) A composite is minted only from a generation that covered the viewport**
(`_viewportCovered`, set from `uncovered == null` at the end of every frame and
cleared by `_disposeTiles`). A half-filled generation flattens to an image that
is transparent wherever it never baked; blitting that in front of the live
fallback shows a *blank* strip rather than a stale one. `the settle spreads its
bakes across frames` runs at a budget of 4 over a ~130-tile visible set and
would have produced exactly that image.

**(c) A gesture frame carries the existing composite forward rather than
re-flattening it.** With `_tiles` empty there is nothing to composite, so the
guard falls through and `_carryOver` is left alone. This is what makes `a zoom
gesture blits the carry-over and bakes nothing` reach `carryOverBlitCount == 8`
from a single composite, and it is also the property that stops eight gesture
frames bilinear-filtering the same pixels eight times over. The composite is
never a resample of a resample.

### The blit

`_carryOverDestRect` maps the recorded rectangle out of `_carryOverAnchor`'s
screen space into world space and back in through the new camera — two opposite
corners, `Rect.fromPoints` to normalise the y flip. Through the world rather
than through a scale ratio, so a camera that also panned between the two frames
is carried correctly instead of being assumed away.

It is the one blit that is **not** snapped: the source is stale by
construction and the destination is a fractional multiple of it, so snapping
would buy nothing and would make the drawing jump by a pixel as the factor
swept. It is the one blit that **does** want a filter, and it has its own
`Paint` at `FilterQuality.low` with the reasoning on the field: every other
blit is a 1:1 texel-to-pixel copy where a sampler is pure cost, and
nearest-neighbour on an arbitrary-subpixel rescale is aliasing — dropped and
doubled stroke rows, crawling as the factor sweeps.

The composite is blitted **first**, so an incoming tile and a live walk both
win over it. When its destination contains the viewport (`dest.left <= 0 && ...
`) the live fallback is skipped — that is `liveDrawCount == 0` in the zoom
test, and it is why the gesture is cheap. The containment is *asserted* rather
than assumed from the gesture's direction: a zoom **out** shrinks the composite
and leaves a genuine ring that the live fallback still owes.

### The drop

`if (baked == 0) _dropCarryOver();` on the covered path. The brief's second
clause is load-bearing and I confirmed it empirically: with `uncovered == null`
alone, criterion 8 went red at `hasCarryOver`, because a budget of 1000 fills
the whole incoming generation in the same frame that anchors it — the composite
would be minted and destroyed inside one `paintFrame`, unobservable from
outside, and the next scale change of the same gesture would have nothing to
blit while its own generation was still empty.

The cost is one frame of stale ink underneath antialiased tile edges. That is
why `criterion 1: a settled frame equals the live frame after a zoom` paints
**twice** after the zoom: frame one fills and keeps the composite, frame two
bakes nothing and retires it, and only the comparison's own third frame is a
clean generation. The test asserts `hasCarryOver` is false before it compares a
single pixel, so "the composite was still on screen" cannot masquerade as a
pass.

### Disposal, per path

| path | what drops the composite |
| --- | --- |
| a scale change that mints a new one | `_retireGeneration` calls `_dropCarryOver()` before assigning, so the outgoing image is released rather than orphaned |
| the incoming generation covers the viewport | `paintFrame`, `if (baked == 0) _dropCarryOver()` |
| `DocumentLoaded` / `DocumentPurged` / empty `touched` | `_dropEverything` -> `_dropCarryOver()`; also nulls `_lastCamera` |
| teardown | `dispose()` -> `_disposeTiles()` + `_dropCarryOver()` |
| a definition or table edit | **deliberately not dropped** — `_dropGeneration` keeps it (see below) |

`_dropCarryOver` is idempotent and nulls the anchor and the rect with the
image. `a whole-document change clears the carry-over as well as the tiles`
asserts the `_dropEverything` arm on both subclasses, with a floor assertion
first so "there was nothing to clear" cannot pass as "it was cleared".

### `_dropGeneration` is not `_retireGeneration`

Split into `_disposeTiles()` (frees images, clears `_baked`, clears
`_viewportCovered`) plus the compositing wrapper. `_dropGeneration` calls
`_disposeTiles` directly and **mints nothing**: a definition or table edit is
not a scale change, and the tiles it throws away hold the *wrong* colour rather
than merely stale-scale pixels. Compositing them would put the pre-edit colour
straight back on screen for the whole of the refill, while `liveTileCount` read
zero and every existing invalidation gate stayed green. `a table edit drops the
generation without minting a carry-over` closes that: it takes the budget to
zero for the frame after the edit so the drop cannot be papered over by an
immediate refill, and asserts `liveDrawCount > 0` — the uncovered viewport is
drawn live at the *new* table values, which a composite standing in front of it
would hide.

The composite is **not** cleared by `_dropGeneration`, per the brief's ruling.
It is stale by construction anyway (it is the old scale), and it lives only
until the incoming generation covers.

---

## 4. Mutants

### M4 — `TileGrid.matchesScale` returns `true` always

```
   bool matchesScale(ViewportTransform camera) {
-    final a = anchor.worldToScreenMatrix;
-    final b = camera.worldToScreenMatrix;
-    return a.a == b.a && a.b == b.b && a.c == b.c && a.d == b.d;
+    return true; // M4
   }
```

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart
00:00 +0: a first frame bakes up to its budget and draws the rest live
00:00 +1: a warm frame bakes nothing and blits the whole visible set
00:00 +2: the blit Paint is one instance for the life of the cache
00:00 +3: the blit hands drawImageRect the same Paint object every time, not a call-site-local one
00:00 +4: criterion 1: a warm tiled frame equals the live frame exactly
00:00 +5: criterion 1: and it still holds after twenty-three awkward pans
00:00 +6: criterion 2: a fixture crossing tile boundaries still matches
00:00 +7: M17 regression: a bake hands the sink a residual, not a raw site-plan-magnitude coordinate
00:00 +8: criterion 3: text survives the tile round trip
00:00 +9: criterion 4: overlapping translucent strokes composite identically
00:00 +10: M11 regression: the blit composites with srcOver, so a tile leaves what is beneath it alone wherever it has no ink of its own
00:00 +11: criterion 8: a pan drops nothing and a scale change drops everything
00:00 +11 -1: criterion 8: a pan drops nothing and a scale change drops everything [E]
  Expected: <2>
    Actual: <1>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_cache_test.dart 389:5                     main.<fn>
  
00:00 +11 -1: a zoom gesture blits the carry-over and bakes nothing
00:00 +11 -2: a zoom gesture blits the carry-over and bakes nothing [E]
  Expected: <8>
    Actual: <0>
  one composite blit per gesture frame
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_cache_test.dart 412:5                     main.<fn>
  
00:00 +11 -2: the gesture frame the carry-over serves is not blank
00:00 +11 -3: the gesture frame the carry-over serves is not blank [E]
  Expected: <0>
    Actual: <130>
  the new generation holds nothing, so the ink below cannot have come from a tile
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_cache_test.dart 443:5                     main.<fn>
  
00:00 +11 -3: the settle spreads its bakes across frames
00:00 +11 -4: the settle spreads its bakes across frames [E]
  Expected: <12>
    Actual: <16>
  and every bake was kept, so 12 is a throttle rather than a recount of four tiles rebaked three times
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_cache_test.dart 465:5                     main.<fn>
  
00:00 +11 -4: criterion 1: a settled frame equals the live frame after a zoom
00:00 +11 -5: criterion 1: a settled frame equals the live frame after a zoom [E]
  Expected: <0>
    Actual: <19471>
  InkReport(live: 16310, tiled: 19903, stray: 19471, uncovered: 15878, differing: 35349)
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/support/tile_comparison.dart 139:3             expectTiledEqualsLive
  
00:00 +11 -5: defect F1: a stroke centreline just outside a tile is culled from it the loss is one stroke column, and it is ink lost rather than moved
00:00 +12 -5: a whole-document change clears the carry-over as well as the tiles
00:00 +12 -6: a whole-document change clears the carry-over as well as the tiles [E]
  Expected: true
    Actual: <false>
  Instance of 'DocumentLoaded': the floor -- there must be a composite to clear
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_cache_test.dart 585:7                     main.<fn>
  
00:00 +12 -6: a table edit drops the generation without minting a carry-over
00:00 +13 -6: accepted gap: near-axis strokes displace a bounded number of pixels the ten-line fan stays inside the bound
00:00 +14 -6: accepted gap: near-axis strokes displace a bounded number of pixels the worst single slope measured stays inside the bound
00:00 +15 -6: accepted gap: near-axis strokes displace a bounded number of pixels the same camera and tile size agree exactly on axis-aligned ink
00:00 +16 -6: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: a whole-document change clears the carry-over as well as the tiles
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: a zoom gesture blits the carry-over and bakes nothing
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: criterion 1: a settled frame equals the live frame after a zoom
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: criterion 8: a pan drops nothing and a scale change drops everything
  ... and 2 more
```

Six tests red. The two the brief names:

- **criterion 8** — `Expected: <2> Actual: <1>`: a scale change no longer
  starts a generation, so `hasCarryOver` never becomes true either.
- **criterion 1 after a zoom** — `InkReport(live: 16310, tiled: 19903, stray:
  19471, uncovered: 15878, differing: 35349)`. The generation is replayed at
  the old scale: old stroke widths, old dash phase, wrong destinations.
  **35,349 of 480,000 pixels**, against a criterion that demands zero. No pan
  test in this repository can see this, because a pan cannot change a scale.

Restored from a copy and proved by `diff` (no diff), then green again at
`00:00 +22: All tests passed!`.

### M9 — the bake budget is ignored

```
       var image = _tiles[key];
-      if (image == null && budget > 0) {
+      if (image == null) { // M9: the budget is ignored
```

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart
00:00 +0: a first frame bakes up to its budget and draws the rest live
00:00 +0 -1: a first frame bakes up to its budget and draws the rest live [E]
  Expected: <3>
    Actual: <130>
  the budget, not the visible set
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_cache_test.dart 65:5                      main.<fn>
  
00:00 +0 -1: a warm frame bakes nothing and blits the whole visible set
00:00 +1 -1: the blit Paint is one instance for the life of the cache
00:00 +2 -1: the blit hands drawImageRect the same Paint object every time, not a call-site-local one
00:00 +3 -1: criterion 1: a warm tiled frame equals the live frame exactly
00:00 +4 -1: criterion 1: and it still holds after twenty-three awkward pans
00:00 +5 -1: criterion 2: a fixture crossing tile boundaries still matches
00:00 +6 -1: M17 regression: a bake hands the sink a residual, not a raw site-plan-magnitude coordinate
00:00 +7 -1: criterion 3: text survives the tile round trip
00:00 +8 -1: criterion 4: overlapping translucent strokes composite identically
00:00 +9 -1: M11 regression: the blit composites with srcOver, so a tile leaves what is beneath it alone wherever it has no ink of its own
00:00 +10 -1: criterion 8: a pan drops nothing and a scale change drops everything
00:00 +11 -1: a zoom gesture blits the carry-over and bakes nothing
00:00 +11 -2: a zoom gesture blits the carry-over and bakes nothing [E]
  Expected: <0>
    Actual: <1040>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_cache_test.dart 411:5                     main.<fn>
  
00:00 +11 -2: the gesture frame the carry-over serves is not blank
00:00 +11 -3: the gesture frame the carry-over serves is not blank [E]
  Expected: <0>
    Actual: <130>
  the new generation holds nothing, so the ink below cannot have come from a tile
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_cache_test.dart 443:5                     main.<fn>
  
00:00 +11 -3: the settle spreads its bakes across frames
00:00 +11 -4: the settle spreads its bakes across frames [E]
  Expected: <12>
    Actual: <130>
  four per frame, three frames
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_cache_test.dart 464:5                     main.<fn>
  
00:00 +11 -4: criterion 1: a settled frame equals the live frame after a zoom
00:00 +12 -4: defect F1: a stroke centreline just outside a tile is culled from it the loss is one stroke column, and it is ink lost rather than moved
00:00 +13 -4: a whole-document change clears the carry-over as well as the tiles
00:00 +14 -4: a table edit drops the generation without minting a carry-over
00:00 +14 -5: a table edit drops the generation without minting a carry-over [E]
  Expected: <0>
    Actual: <130>
  the generation is dropped
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_cache_test.dart 624:5                     main.<fn>
  
00:00 +14 -5: accepted gap: near-axis strokes displace a bounded number of pixels the ten-line fan stays inside the bound
00:00 +15 -5: accepted gap: near-axis strokes displace a bounded number of pixels the worst single slope measured stays inside the bound
00:00 +16 -5: accepted gap: near-axis strokes displace a bounded number of pixels the same camera and tile size agree exactly on axis-aligned ink
00:00 +17 -5: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: a first frame bakes up to its budget and draws the rest live
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: a table edit drops the generation without minting a carry-over
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: a zoom gesture blits the carry-over and bakes nothing
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: the gesture frame the carry-over serves is not blank
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: the settle spreads its bakes across frames
```

`the settle spreads its bakes across frames` — **`Expected: <12> Actual:
<130>`**. The whole visible set in one frame: the ~60 ms stall this cache
exists to remove, moved rather than removed.

The brief says to note that this mutant is invisible to every correctness
criterion, and that is right — criteria 1 to 8 all pass a cache that bakes
everything at once, because the *pixels* are correct. It is not, however,
invisible to every test in the file: `a first frame bakes up to its budget and
draws the rest live` (Task 4) catches it too, as do the two zero-budget gesture
tests added here. Criterion 11 is still the one that names the property.

Restored and proved by `diff` (no diff), then green.

---

## 5. Finding F1 — a stroke centreline just outside a tile is culled from it

**This is a defect in shipped code, it is not Task 9's, and it is not fixed
here.** It is recorded as a measured group in `tile_cache_test.dart` so it
cannot be rediscovered.

**How it was found.** Criterion 1 has never been asked about a *scale*. Every
existing case runs at the rig's one camera, scale 1.4, and a pan cannot change
a scale — the camera was the degenerate fixture, in the dimension this whole
task is about. The first zoom factor I picked, 1.17, reddened
`expectTiledEqualsLive` at `InkReport(live: 17807, tiled: 17270, stray: 0,
uncovered: 537, differing: 537)`.

**It is not the carry-over.** A cold cache, no generation change, no composite,
camera set straight to the zoomed value: identical 537. Confirmed before
anything else.

**Where.** The uncovered pixels form a single device column, `(191, 50)` to
`(191, 599)` — one whole vertical stroke absent from the drawing.

**Why, measured.** At factor 1.17 the quantised camera is `a = 1.638, e =
-77.5`. `crossingGrid`'s vertical line at world x 106 lands at device x
**192.256**, 0.256 px right of the tile boundary at 192. Its stroke is 2 device
pixels wide, so it covers pixel centres 191.5 and 192.5 and the live frame inks
both (`x=191 live=255 tiled=0  x=192 live=255 tiled=255`). Pixel 191 belongs to
tile column 2, device `[128, 192)`. `cache.tilesHolding(Handle(1009))` returns
**`[3]`** — column 2 never received the entity at all.

`DraftPainter.paint` derives its index query from
`camera.visibleWorld(viewport)` with no slack whatsoever
(`draft_painter.dart:338`). Only its *screen* clip carries
`kScreenClipInflate`, which is defined in as many words as "half the widest
stroke the frame can draw, so a stroke whose centreline is just outside still
contributes its visible edge" (`draft_painter.dart:41-50`). A tile bake passes
the tile as the viewport, so the tile's world rect ends 0.08 world units left
of the centreline, and the half of the stroke reaching back inside is drawn by
nobody: the neighbouring tile owns different pixels, and a device column can
only be written by the tile that contains it.

**Scope, measured.** Sweeping the factor from 0.70 to 1.50 in steps of 0.02, 41
cameras, tile 64 device px:

| factor | InkReport |
| --- | --- |
| 0.72 | live 15917, uncovered 370 |
| 0.78 | live 18064, uncovered 415 |
| 0.82 | live 18988, uncovered 436 |
| 1.06 | live 17225, uncovered 527 |
| 1.10 | live 17447, uncovered 484 |
| 1.22 | live 18146, uncovered 561 |

Six of 41, always `stray: 0` — ink lost, never moved. The other 35 are exactly
zero. At 1.17 with the tile size swept instead: 32 px and 64 px lose the
column, 128 px and 256 px are clean, because the boundary lands elsewhere.

**The fix, built and measured, then reverted.** Padding `_bake`'s viewport by
`kScreenClipInflate` and pulling the canvas back by the same amount:

```dart
    const pad = kScreenClipInflate;
    final bake = grid.bakeCameraFor(key).worldToScreenMatrix;
    into.save();
    into.translate(-pad, -pad);
    _drawInto(
        into,
        Size(side + 2 * pad, side + 2 * pad),
        ViewportTransform(
            worldToScreenMatrix: Transform2(
                bake.a, bake.b, bake.c, bake.d, bake.e + pad, bake.f + pad)),
        painter, sink, vertices, origin, (handle) { ... });
    into.restore();
```

The same 41-factor sweep goes to **0 of 41**, and `tile_cache_test.dart` is
green at all nine factors including the six killers. This is also the design
that `tile_cache.dart`'s own header already prices — "bakes **4.00x** its own
area, because `kScreenClipInflate` is 32 *logical* pixels and a 128 px tile is
only 64 logical wide" is `(64 + 2*32)^2 / 64^2 = 4.00`. The inflate was the
documented intent; the line was missing.

**Why it is not landed here.** It widens every tile's `_baked` record by a
one-tile ring at the test tile size, and four direction-two assertions in
`tile_invalidation_test.dart` go red:

```
criterion 5: a leaf edit invalidates its own tiles and no others
  fixture guard ... Actual: Set:[TileKey(2, 6), TileKey(2, 7), TileKey(2, 8), TileKey(2, 9)]
criterion 5: a dragged instance drops the tiles it left      stale arrival at TileKey(4, 6)
criterion 5: a dragged group leaves no ghost either          stale arrival at TileKey(0, 0)
criterion 5: the undo of an instance transform ...           stale arrival at TileKey(0, 2)
```

Those are not fixture noise. The arrival oracle (`tilesFor`, which reads
`tilesHolding`) starts over-reporting while `_invalidateTouched`'s own
direction-two geometry (`_worldRectOf`, exact tile rect) does not inflate — the
two halves of invalidation disagree by one ring. Making them agree is a
decision about how much over-invalidation is acceptable and how the record
should be trimmed, across a file outside this brief, and it belongs to a task
of its own with its own mutants.

**What is landed instead.** `group('defect F1: ...')` in `tile_cache_test.dart`
runs the six killer factors on every run and asserts the damage is bounded
(`uncoveredPixels <= 600`), that it is a cull and not a displacement
(`strayPixels == 0`), and that no pixel disagrees on colour
(`differingPixels == uncoveredPixels`). The bounds hold both before and after
the fix, so landing the fix will not redden them; the mechanism, the sweep and
the patch are written out above the group. Criterion 1's zoom factors are drawn
from the clean 35 with the exclusion stated in the test and cross-referenced to
F1 — disclosed, not tuned into silence.

---

## 6. Deviations

**D1 — the zoom-gesture test warms at a real budget and then takes it away.**
The brief builds the rig with `tilesBakedPerFrame: 0`, with the comment "Budget
0 after the first frame". A rig constructed at zero never bakes a *first*
generation either: `_tiles` is empty forever, nothing is ever retired, no
composite is ever minted, and `bakeCount == 0`, `carryOverBlitCount == 0` and
`liveDrawCount == 0` all read zero against zero — green for the one reason that
makes the test worthless, and precisely the "gate that cannot see what it
claims to measure" shape this plan keeps finding. `TileCache.tilesBakedPerFrame`
is therefore a mutable field, documented as such on the field itself, and the
test warms at 1000 before setting it to 0. Three added assertions close the
remaining vacuity: `blitCount == 0` (no tile blitted either), `generation >= 9`
(eight scale changes really happened, so these are gesture frames and not eight
repeats of one warm frame), and the separate pixel test below.

**D2 — `TileRig.zoomBy` now scales about the viewport centre**
(`test/support/tile_fixture.dart`). It multiplied `a` and `d` alone, which pins
whichever world point sits at screen `(e, f)` — here `(-37, 323)`, outside the
viewport and below it. A zoom *in* therefore slid the whole drawing right and
down, and the composite landed `e * (1 - factor)` short of the left edge: at
factor 1.03 the destination's left was `+1.11`, so `carryOverCovers` was false
and `liveDrawCount` read 8 instead of 0. That is a fact about the rig, not
about the carry-over. No zoom gesture behaves that way — a real one keeps the
point under the cursor still — and the old version also left `b` and `c`
unscaled, which is not a scale at all under a skewed camera. Both fixed.

**D3 — an added pixel test, `the gesture frame the carry-over serves is not
blank`.** `carryOverBlitCount` counts calls, and a `drawImageRect` into a
degenerate destination counts the same as one that puts the outgoing generation
on screen: a carry-over that is never actually *visible* presents as green.
This one takes the budget to zero, zooms, and reads the frame back: it asserts
`liveTileCount == 0` and `liveDrawCount == 0` first — so the ink cannot have
come from a tile or from the painter — and then that the frame carries more
than 5000 non-transparent pixels against a warm frame measured in the same
test. Under a carry-over that never reaches the canvas it reads 0.

**D4 — the settle test gets two anti-vacuity assertions.**
`liveTileCount == 12` (every bake was kept, so 12 is a throttle rather than
four tiles rebaked three times) and `liveDrawCount == 3` (all three frames
still left ink uncovered, so the visible set is larger than 12 and the budget
is what bounded the count — 130 tiles, as M9's transcript shows).

**D5 — criterion 1 after a zoom is a new test the brief did not list.** The
brief's M4 step requires "criterion 1 after a zoom must go red", and no such
test existed. It is written above; it is the test that found F1.

---

## 7. Constraints

- **No golden moved.** `git diff --stat eb3f800 -- packages/jet_cad_2d_flutter/test/golden`
  is empty. `CI=true flutter test --tags golden` -> `00:05 +35: All tests passed!`
- **No `analysis_options.yaml` staged.** `git status --short` before staging:
  three files, all of them the ones listed at the top. Explicit paths only.
- Every test command prefixed with `CI=true`.
- No mutation reverted with `git checkout`: both mutants were applied to a copy
  taken beforehand, restored from that copy, and the restore proved with `diff`
  producing no output.
- No test output synthesized; every transcript above is pasted from a run.
- Anti-degenerate: no fixture fits in one tile (`crossingGrid`'s lines span
  about eight), no camera is `ViewportTransform.fit`, no viewport is one tile
  (`blitCount > 30` is asserted, and the real figure is 130).
- The frame path's per-frame carry-over cost is O(1): one `drawImageRect`, one
  `Rect`, two `Vector2` round trips. Nothing per entity.

## 8. Open

- **F1 needs a task.** The patch is above and the sweep is measured; what it
  needs is the invalidation-precision decision, not more diagnosis.
- **No instrument sees a leaked `ui.Image`.** The disposal table in section 3
  is argued from the code and gated only indirectly, through `hasCarryOver`
  transitions. `STATUS.md`'s trap 5 already records that there is no heap-level
  instrument on this side.


---

# Fix round 1

Two findings against Task 9, one Critical. Both closed. Defect F1 is closed by
Task 9a's `kTileSlack` and is no longer mine to carry.

## C1 (Critical) — an edit while a composite stands showed pre-edit pixels

### The probe, before the fix

A scratch probe, run against the committed code at `1d55659`, with the layer
edit the reviewer describes. `tilesBakedPerFrame` is taken to zero first so the
incoming generation cannot quietly refill and hide the effect:

```
after zoom: hasCarryOver=true
after edit: hasCarryOver=true liveTileCount=0 liveDrawCount=0 carryOverBlitCount=1 blitCount=0
ten frames later: hasCarryOver=true liveDrawCount=0 carryOverBlitCount=11
```

The whole frame is the stale composite, and it does not heal: eleven frames,
eleven composite blits, not one live walk.

**And it is no better at a production-shaped budget**, which I probed second
because "budget zero" is an artificial state and the severity claim should not
rest on it. Same fixture, `tilesBakedPerFrame = 4`:

```
after zoom: hasCarryOver=true
after edit: hasCarryOver=true liveTileCount=4 liveDrawCount=0 carryOverBlitCount=1 blitCount=4
ten frames later: hasCarryOver=true liveDrawCount=0 carryOverBlitCount=11
```

Four tiles rebake per frame at the new colour, `liveDrawCount` stays at **0**
for all eleven frames because the covering composite suppresses the walk, and
every pixel the refill has not yet reached is still the pre-edit drawing — for
the whole of a settle, which at 130 tiles and a budget of 4 is about
thirty-three frames.

### The same probe after the fix

```
after zoom: hasCarryOver=true
after edit: hasCarryOver=false liveTileCount=4 liveDrawCount=1 carryOverBlitCount=0 blitCount=4
ten frames later: hasCarryOver=false liveDrawCount=11 carryOverBlitCount=0
```

The composite is gone on the edit frame and never reaches the canvas again; the
uncovered remainder is walked live, at the post-edit document, every frame until
the generation refills.

### The fix — two calls, not one

`_dropGeneration` gains `_dropCarryOver()`, as the coordinator says. That alone
is **not sufficient**, and the second half is the part that would have been
missed: `_invalidateTouched`'s ordinary per-tile path removes tiles one at a
time and never reaches `_dropGeneration` at all, so an ordinary leaf edit — the
commonest edit there is — would still have left the composite standing. The
second call is hoisted above `applyChange`'s switch, for the same reason the
switch is written without a `default`: a sixth `DocChange` subclass must not be
able to arrive without it.

Both are independently proved load-bearing. Backing out both:

```
00:00 +18 -1: an edit while a composite stands drops it, and the frame repaints [E]
  Expected: false
    Actual: <true>
  a table edit, which reaches no command at all: a composite is a picture of the document before the edit
  test/tile_cache_test.dart 727:7                     main.<fn>
```

Restoring `_dropGeneration`'s call and backing out only `applyChange`'s — so
the table arm passes and only the per-tile arm is exposed:

```
00:00 +18 -1: an edit while a composite stands drops it, and the frame repaints [E]
  Expected: false
    Actual: <true>
  a leaf edit, which takes the per-tile path: a composite is a picture of the document before the edit
```

Each backing-out was a `python` edit against a copy taken beforehand, restored
by copying the copy back and proved with `diff` producing no output. No
`git checkout`.

### The test, and why it was blind

`a table edit drops the generation without minting a carry-over` asserted
`liveDrawCount > 0` with the comment "which a composite standing in front of it
would hide" — the right claim, in the one state where the hazard cannot occur,
because the test never zooms and no composite ever exists. The blindness is in
the setup, not in the instrument or the assertion.

It is now two tests, because there are two claims and collapsing them would
lose one:

- **`an edit while a composite stands drops it, and the frame repaints`** —
  warm, budget to zero, **zoom**, then assert `hasCarryOver` is true *and*
  `liveTileCount` is zero as a floor, so the frame under test really is nothing
  but the composite. Then the edit, then `hasCarryOver` false,
  `carryOverBlitCount` 0 (it must not have reached the canvas even on the way
  out) and `liveDrawCount > 0`. Run twice, once per invalidation path — the
  table revision `paintFrame` reads for itself, and the per-tile leaf arm.
- **`a table edit drops the generation without minting a carry-over`** — kept
  in its original shape, because its precondition is the opposite one: the
  outgoing generation *covers the viewport*, which is what
  `_retireGeneration` mints on. It gates a `_dropGeneration` that composites
  instead of disposing. The C1 test cannot catch that mutant and this one
  cannot catch C1.

Green after:

```
00:00 +18: an edit while a composite stands drops it, and the frame repaints
00:00 +19: a table edit drops the generation without minting a carry-over
00:00 +23: All tests passed!
```

## The sweep — is there another test whose fixture excludes the state its comment is about?

The answer is **yes, one more, plus two implicit cases worth pinning.** I asked
the question of all twenty-three tests in the file.

**First, a scope result that matters.** `grep -rn zoomBy test/` returns nothing
outside `tile_cache_test.dart` — not `tile_invalidation_test.dart`, not
`draft_canvas_test.dart`. Neither of those files can change a scale, so
`_carryOver` is null in every test in both of them. That is why C1 was invisible
to the entire invalidation suite: the whole suite runs in a world without a
composite. The sweep is therefore correctly confined to this one file.

### The one real find — criterion 13's `SpyCanvas` Paint test

`the blit hands drawImageRect the same Paint object every time` enumerates every
`drawImageRect` in a frame and asserts they all carry the *same* `Paint`. In a
world with a composite that statement is not merely untested, it is **false**: a
frame that blits a composite and some tiles legitimately hands `drawImageRect`
two different long-lived objects. The test passed only because its fixture — one
cold frame — excludes the state, so a mutation that built the composite's
`Paint` at the call site had nowhere to be caught.

A second phase now runs the same claim in that state: warm, budget to four,
zoom, one frame under the spy that contains **both** kinds of blit. It asserts
`carryOverBlitCount == 1`, `blitCount == 4` and exactly five `drawImageRect`
calls, so the phase cannot degenerate into a second cold frame; that the first
call carries `debugCarryOverPaint` (the composite goes first, so tiles and the
live walk composite on top of it); and that every other call carries
`debugBlitPaint`. `TileCache.debugCarryOverPaint` is exposed for it, the same
way and for the same reason as `debugBlitPaint`.

The phase also pins two properties nothing else in this plan gates:
`debugBlitPaint.filterQuality == none` against
`debugCarryOverPaint.filterQuality == low` — the ruling that the carry-over is
the one blit that is not a 1:1 texel-to-pixel copy — and
`debugCarryOverPaint.blendMode == srcOver`. That last one closes a second
setup-blind case: `M11 regression` pins the *tile* Paint's blend mode against a
red backdrop, and cannot see the composite's, which is drawn underneath
everything and would clobber the backdrop to transparent under `src`.

Mutant M18, the composite `Paint` built at the call site:

```
       canvas.drawImageRect(carryOver, ..., dest,
-          _carryOverPaint);
+          Paint()..filterQuality = FilterQuality.low); // M18: call-site-local
```

```
00:00 +3 -1: the blit hands drawImageRect the same Paint object every time, not a call-site-local one [E]
  Expected: true
    Actual: <false>
  the composite goes first and with its own field, so an incoming tile and a live walk both composite on top of it
```

Restored from a copy, `diff` clean, green again.

### Two implicit cases, now pinned

Neither was wrong, but both asserted `liveDrawCount` as a statement about
*coverage* when a composite would make the same number mean *suppression*. One
line each:

- `a warm frame bakes nothing and blits the whole visible set` —
  `liveDrawCount == 0, 'nothing left uncovered'` now carries
  `hasCarryOver isFalse` above it.
- `the settle spreads its bakes across frames` — `liveDrawCount == 3` is the
  anti-vacuity assertion that proves the visible set is larger than 12, and it
  would read 0 if a composite stood. Now says so, and asserts it.

### The tests that are not blind, and why

- `a first frame bakes up to its budget` — a composite cannot exist on a first
  frame (`_grid` is null, `_viewportCovered` false), so its claims are about the
  only state it can be in.
- `the blit Paint is one instance for the life of the cache` — a claim about
  field identity across frames, which a composite does not touch; the test above
  now carries the composite half.
- `criterion 1 warm`, `criterion 1 after 23 pans`, `criteria 2, 3, 4`,
  `M17`, both `accepted gap` tests and `defect F1 stays closed` — none changes a
  scale, so none can reach a composite, and each is a claim about the settled or
  cold frame it does set up. `criterion 1 after a zoom` is the one that *can*,
  and it asserts `hasCarryOver isFalse` before it compares a single pixel.
- `criterion 8`, `a zoom gesture blits the carry-over`, `the gesture frame the
  carry-over serves is not blank`, `a whole-document change clears the
  carry-over` — all four set up a composite deliberately.

## M2 (Minor) — the 133-character doc line

`tile_cache.dart:22` rewrapped to 80 columns. The remaining seven lines that
`awk length>80` reports at 81-83 are pre-existing em-dash lines that `dart
format` accepts unchanged; none was touched.

## Not addressed, deliberately

The over-drop table (15→32, 8→28) and the 2.25x padded bake cost at the
production 256 px tile are ungated, as the coordinator says, and belong to the
later sweep that already owes a bake-cost column. Untouched.

## Fix-round gate

```
$ cd packages/jet_cad_2d        && CI=true dart test      -> 00:02 +797: All tests passed!
                                   dart analyze           -> No issues found!
                                   dart format --set-exit-if-changed .
                                                          -> Formatted 113 files (0 changed)
$ cd packages/jet_cad_2d_flutter && CI=true flutter test  -> 00:05 +351 ~1: All tests passed!
                                   flutter analyze        -> No issues found! (ran in 1.0s)
                                   dart format --set-exit-if-changed .
                                                          -> Formatted 62 files (0 changed)
                                   CI=true flutter test --tags golden
                                                          -> 00:03 +35: All tests passed!
$ git diff --stat eb3f800 -- packages/jet_cad_2d_flutter/test/golden
                                                          -> empty
```

`git status --short` before staging listed exactly two files, both staged by
explicit path. No `analysis_options.yaml`. The scratch probe
(`test/zz_c1_probe_test.dart`) was deleted before the gate ran; it appears in no
commit.
