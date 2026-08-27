# Plan 3i — mutation log

> **Note: mutant numbering is per-plan, and `M4`/`M5` collide with
> `plan-3h-mutation-log.md`.** This file's own `M4` (§"M4 — the wheel clause")
> and `M5` name different mutations from Plan 3h's `M4` ("narrow the clip but
> not the query") and `M5` ("grow the query and leave the clip untouched").
> `TileCache.debugFullViewportQuery`, its doc comment and this file's `M14`
> entry all say "Plan 3h's M4" explicitly for exactly this reason. Any
> citation of `M4` or `M5` from either log must name the plan it belongs to.

> **Note, added once the batch-minors pass understood the discrepancy below:**
> M2, M6 and M6b were all measured under Task 8, before Task 9's `Center` fix
> to `pumpTiled` (`support/tile_harness.dart`, commit `1e2f891`) landed.
> Before that fix, `pumpWidget` handed the canvas its surface's *tight*
> constraints and the un-centred `SizedBox` was inert against them, so the
> canvas those three mutants ran on was 800x600 logical -- 1600x1200 device
> pixels at `kTileDpr`, 25 x 19 = 475 tiles, ~19 one-tile-row bands -- not the
> 400x300 logical / 130 tile / ~10 band canvas the fix made every later entry
> in this file true of. The kills stand and are **not re-run**: each mutation
> still produces exactly the failure its own entry describes, on whatever
> canvas the suite ran against that day, and a canvas size does not decide
> whether a band image leaks or a slice loop drops eleven tiles. What the note
> is for is the raw counts those three entries print -- `475`, `513`, `38`,
> `19 bands`, and the `800x600`/`BoxConstraints(w=800.0, h=600.0)` seen in one
> stack trace -- so a reader does not mistake them for the fixed canvas's
> figures (130 tiles, ~10 bands) or wonder why they disagree with every later
> entry.

## M1

**Task:** Task 2, "A moving frame draws the composite and nothing else."

**Mutation:** In `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`'s
`paintFrame`, deleted the guard block

```dart
    if (!resting) {
      // Nothing else this frame. The composite is already down; a zoom out
      // leaves its ring as background until the gesture ends (spec D3).
      return;
    }
```

leaving `resting` computed but unused, and the visible-key loop (and
therefore the bake and the live walk) running on every frame regardless of
whether the frame is moving.

**Procedure:** copied `tile_cache.dart` aside to the scratchpad, edited the
working file to delete the block above, ran the test, then restored the
working file from the copy. **Never `git checkout`.**

**Result:** red, as expected — the moving-frame test in
`test/tile_regime_test.dart` fails because baking resumes on every frame.

**Verbatim output:**

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart
00:00 +0: the same camera compares same
00:00 +1: a scale change compares different
00:00 +2: a translation change compares different
00:00 +3: the skew terms are compared too
00:00 +4: a moving frame bakes nothing and walks nothing
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <512>
a moving frame must bake nothing

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart:108:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart line 108
The test description was:
  a moving frame bakes nothing and walks nothing
════════════════════════════════════════════════════════════════════════════════════════════════════
00:00 +4 -1: a moving frame bakes nothing and walks nothing [E]
  Test failed. See exception logs above.
  The test description was: a moving frame bakes nothing and walks nothing
  
00:00 +4 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart: a moving frame bakes nothing and walks nothing
```

`bakeCount` is 512 rather than the brief's illustrative "8, one per frame" —
with the guard gone, every one of the 8 zoom frames bakes as many tiles as
its budget permits over a viewport this size, not one each — but the failure
mode (baking resumes on a moving frame) is exactly the one the test is
chartered to catch.

## M4

**Task:** Task 3, "The wheel clause — two unchanged frames, not one."

**Mutation:** In `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`'s
`paintFrame`, replaced the `resting` guard:

```dart
    final resting = previous == null || _carryOver == null || _restGateSteps >= kRestGateFrames;
```

with:

```dart
    final resting = !_viewportCovered;
```

This breaks the rest gate and causes the cache to bake on every frame where
the viewport is not fully covered, even if the camera is moving.

**Procedure:** copied `tile_cache.dart` aside to the scratchpad, edited the
working file to replace the resting expression with `!_viewportCovered`, ran
the test, then restored the working file from the copy. **Never `git checkout`.**

**Result:** red, as expected — both "a moving frame bakes nothing and walks
nothing" and "a steadily spun wheel never arms the rest gate" tests fail:

**Verbatim output:**

```
00:00 +4 -1: a moving frame bakes nothing and walks nothing [E]
  Test failed. See exception logs above.
Expected: <0>
  Actual: <512>
a moving frame must bake nothing

00:00 +5 -2: a steadily spun wheel never arms the rest gate [E]
  Test failed. See exception logs above.
Expected: <0>
  Actual: <768>
a wheel that keeps turning must never reach two consecutive unchanged frames, so it must never bake
```

## M4b — the rest gate at one frame instead of two

**Task:** Task 3, "The wheel clause — two unchanged frames, not one."

**Mutation:** In `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`,
changed the constant:

```dart
const int kRestGateFrames = 1;
```

(instead of 2)

This tests whether the threshold itself is correct, independent of the guard's
other terms. M4 proved the gate is load-bearing; M4b proves the threshold must
be 2.

**Procedure:** copied `tile_cache.dart` aside, edited the constant from 2 to 1,
ran the tests, then restored from the copy. **Never `git checkout`.**

**Result:** red, as expected — both affected tests fail:

**Verbatim output:**

```
00:00 +6 -1: a steadily spun wheel never arms the rest gate [E]
Expected: <0>
  Actual: <384>
a wheel that keeps turning must never reach two consecutive unchanged frames,
so it must never bake

00:00 +6 -2: the gate needs two unchanged frames, not one [E]
Expected: <2>
  Actual: <1>
```

With kRestGateFrames = 1, the wheel test bakes on every other notch (384 tiles
instead of 0), confirming the threshold of 2 is necessary to meet the spec.

---

## M2 — the slice loop emits only the first tile of each band

> Measured at the pre-fix 800x600-logical canvas -- see the note at the top
> of this file. The kill stands; it is not re-run.

**Task 8.** A band is walked and rasterised in full, but only its leftmost tile
is cut out of it. Every other visible key is left to the budgeted tile loop, so
a resting frame no longer covers the viewport in one frame — which is the whole
claim Task 8 lands.

**Mutation:**

```diff
--- a/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
+++ b/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
@@ -1172,7 +1172,7 @@
       // band-coarse, which is right because a band is exactly the unit a
       // rebake walks.
       final record = Uint32List.fromList(visited);
-      for (final key in band.keys) {
+      for (final key in band.keys.take(1)) {
         // A key this frame's tile map already serves keeps its own image and
         // its own, narrower record. Overwriting it would leak the image it
         // replaced -- `_tiles[key] = tile` disposes nothing -- and a pan
```

**Procedure:** copied `tile_cache.dart` aside, applied the edit, ran
`CI=true flutter test test/tile_settle_test.dart`, then restored from the copy.
**Never `git checkout`.**

**Result:** red, as expected.

**Verbatim output:**

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_settle_test.dart
00:00 +0: a frame that left tiles unbaked asks for another
00:00 +1: the settle finishes, and then stops asking
00:00 +2: the settle completes in one frame
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: true
  Actual: <false>
one rest frame covers the viewport; the tiled fill it replaces took one frame per tile

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_settle_test.dart:101:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_settle_test.dart line 101
The test description was:
  the settle completes in one frame
════════════════════════════════════════════════════════════════════════════════════════════════════
00:00 +2 -1: the settle completes in one frame [E]
  Test failed. See exception logs above.
  The test description was: the settle completes in one frame
  
00:00 +2 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_settle_test.dart: the settle completes in one frame
```

---

## M6 — the band image is never disposed

> Measured at the pre-fix 800x600-logical canvas -- see the note at the top
> of this file. `475`, `513` and `19 bands` below are that canvas's counts,
> not the fixed canvas's 130 tiles / ~10 bands. The kill stands; it is not
> re-run.

**Task 8.** The band image is dropped from `_band` but its native memory is
never released. The brief spells this mutation as deleting `image.dispose();`
and the `_imagesAlive--;` beside it; the shipped code routes both through
`_disposeImage`, "the single door every `ui.Image` this cache owns leaves by",
so deleting that one call is exactly the same mutation — it removes the
`dispose()` and the decrement together.

**Mutation:**

```diff
--- a/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
+++ b/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
@@ -1193,7 +1193,6 @@
         _lastUsedFrame[key] = _frameSerial;
       }
       _band = null;
-      _disposeImage(image);
       _bakes++;
     }
   }
```

**Procedure:** copied `tile_cache.dart` aside, applied the edit, ran
`CI=true flutter test test/invariants/tile_bytes_test.dart`, then restored from
the copy. **Never `git checkout`.**

**Result:** red, as expected — 38 leaked band images (19 bands across the two
rest frames this test drives) show up as `debugImagesAlive` exceeding
`liveTileCount`.

**Verbatim output:**

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart
00:00 +0: a live band image is counted in liveBytes
00:00 +1: the ceiling holds at every point inside the rest frame
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: <475>
  Actual: <513>
no band image outlives its band, and the composite was dropped before the bake

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart:47:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart line 47
The test description was:
  the ceiling holds at every point inside the rest frame
════════════════════════════════════════════════════════════════════════════════════════════════════
00:00 +1 -1: the ceiling holds at every point inside the rest frame [E]
  Test failed. See exception logs above.
  The test description was: the ceiling holds at every point inside the rest frame
  
00:00 +1 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart: the ceiling holds at every point inside the rest frame
```

---

## M6b — the band image is never assigned to `_band`

> Measured at the pre-fix 800x600-logical canvas -- see the note at the top
> of this file (the `BoxConstraints(w=800.0, h=600.0)` in the transcript
> below is that canvas). The kill stands; it is not re-run.

**Task 8, fix round 1.** The band is baked, sliced and disposed correctly, but
`_band` is never set, so `liveBytes` cannot see the one image the whole banding
design exists to bound.

**Why it needed its own mutant.** Task 4 landed `_band` and `debugSetBand` and
proved `liveBytes` counts a band *handed to the seam*. It could not prove the
production path puts one there. Task 8 assigns `_band` on the real path, but
the ceiling assertion it shipped with -- `liveBytes <= kTileCacheBytes` inside
the slice -- is one-sided: with `_band` unassigned `liveBytes` reads the tile
sum, which is smaller still and satisfies it, and
`debugImagesAlive == liveTileCount` is indifferent to `_band` either way. The
gap Task 4 opened therefore stayed open through Task 8's first round, closed
only by reading. The lower bound added in this round is what closes it, and
this mutant is what proves the lower bound is load-bearing.

**Mutation:**

```diff
@@ -1176,7 +1176,6 @@
       final visited = <int>[];
       final image = _bakeBand(
           band, grid, quantised, painter, sink, vertices, origin, visited);
-      _band = image;
       // [_bakeBand]'s `onVisit` records only what the painter visited
       // directly; [_bake]'s climbs owners so that a *container's* transform
       // reaches the tile through invalidation's direction one. This is where
```

**Procedure:** copied `tile_cache.dart` aside, applied the edit, ran
`CI=true flutter test test/invariants/tile_bytes_test.dart`, then restored from
the copy. **Never `git checkout`.**

**Result:** red, as expected. The new lower bound fires on the first slice of
the first band, where `liveTileCount` is still 0 and `liveBytes` reads 0
instead of the resident band's bytes. The second failure in the transcript is a
knock-on and not an independent signal: the assertion throws out of the slice
loop, so `_disposeImage(image)` never runs and one band image is left alive.

**Verbatim output:**

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart
00:00 +0: a live band image is counted in liveBytes
00:00 +1: the ceiling holds at every point inside the rest frame
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following TestFailure was thrown during paint():
Expected: a value greater than <0>
  Actual: <0>
   Which: is not a value greater than <0>
the band image is in the total, not merely permitted by it: a rest frame that never assigned _band
would read exactly the tile sum here

The relevant error-causing widget was:
  CustomPaint
  CustomPaint:file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart:359:16

When the exception was thrown, this was the stack:
#0      fail (package:matcher/src/expect/expect.dart:187:31)
#1      _expect (package:matcher/src/expect/expect.dart:182:3)
#2      expect (package:matcher/src/expect/expect.dart:65:3)
#3      expect (package:flutter_test/src/widget_tester.dart:473:18)
#4      main.<anonymous closure>.<anonymous closure> (file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart:47:7)
#5      TileCache._restBake (package:jet_cad_2d_flutter/src/tile_cache.dart:1204:30)
#6      TileCache.paintFrame (package:jet_cad_2d_flutter/src/tile_cache.dart:983:7)
#7      _DraftCustomPainter.paint (package:jet_cad_2d_flutter/src/draft_canvas.dart:427:13)
#8      RenderCustomPaint._paintWithPainter (package:flutter/src/rendering/custom_paint.dart:593:13)
#9      RenderCustomPaint.paint (package:flutter/src/rendering/custom_paint.dart:641:7)
#10     RenderObject._paintWithContext (package:flutter/src/rendering/object.dart:3580:7)
#11     PaintingContext.paintChild (package:flutter/src/rendering/object.dart:265:13)
#12     RenderProxyBoxMixin.paint (package:flutter/src/rendering/proxy_box.dart:143:13)
#13     RenderObject._paintWithContext (package:flutter/src/rendering/object.dart:3580:7)
#14     PaintingContext._repaintCompositedChild (package:flutter/src/rendering/object.dart:180:11)
#15     PaintingContext.repaintCompositedChild (package:flutter/src/rendering/object.dart:125:5)
#16     PipelineOwner.flushPaint (package:flutter/src/rendering/object.dart:1325:31)
#17     PipelineOwner.flushPaint (package:flutter/src/rendering/object.dart:1335:15)
#18     AutomatedTestWidgetsFlutterBinding.drawFrame (package:flutter_test/src/binding.dart:2438:31)
#19     RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:558:5)
#20     SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1430:15)
#21     SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1345:9)
#22     AutomatedTestWidgetsFlutterBinding.pump.<anonymous closure> (package:flutter_test/src/binding.dart:2261:9)
#25     TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#26     AutomatedTestWidgetsFlutterBinding.pump (package:flutter_test/src/binding.dart:2250:27)
#27     WidgetTester.pump.<anonymous closure> (package:flutter_test/src/widget_tester.dart:652:53)
#30     TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#31     WidgetTester.pump (package:flutter_test/src/widget_tester.dart:652:27)
#32     main.<anonymous closure> (file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart:57:13)
<asynchronous suspension>
#33     testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#34     TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 5 frames from dart:async and package:stack_trace)

The following RenderObject was being processed when the exception was fired: RenderCustomPaint#2342a:
  creator: CustomPaint ← RepaintBoundary ← DraftCanvas ← SizedBox ← Directionality ← MediaQuery ←
    _FocusInheritedScope ← _FocusScopeWithExternalFocusNode ← _FocusInheritedScope ← Focus ←
    FocusTraversalGroup ← MediaQuery ← ⋯
  parentData: <none> (can use size)
  constraints: BoxConstraints(w=800.0, h=600.0)
  size: Size(800.0, 600.0)
  painter: _DraftCustomPainter#c6044(Listenable.merge([CameraController#36307(Instance of
    'ViewportTransform'), Instance of 'DocChangeNotifier', Instance of '_TableListenableAdapter',
    Instance of '_SettleNotifier']))
  preferredSize: Size(Infinity, Infinity)
This RenderObject has no descendants.
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <1>
no band image outlives its band, and the composite was dropped before the bake

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart:59:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart line 59
The test description was:
  the ceiling holds at every point inside the rest frame
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following message was thrown:
Multiple exceptions (2) were detected during the running of the current test, and at least one was
unexpected.
════════════════════════════════════════════════════════════════════════════════════════════════════
00:00 +1 -1: the ceiling holds at every point inside the rest frame [E]
  Test failed. See exception logs above.
  The test description was: the ceiling holds at every point inside the rest frame
  
00:00 +1 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart: the ceiling holds at every point inside the rest frame
```

## M3 — the slice rectangle is always the band's first tile

**Task 9.** `TileGrid.sliceSourceRect` returns `Rect.fromLTWH(0, 0, tile, tile)`
whatever key it is asked about, so every tile in a band is cut from the band's
leftmost 64 device pixels.

**Mutation:**

```diff
@@ -339,7 +339,7 @@
   /// numbered. Integral by construction -- [deviceDeltaFrom] rounds, and a
   /// tile side is `tileDevicePixels` exactly.
   Rect sliceSourceRect(TileBand band, TileKey key) => Rect.fromLTWH(
-        key.x * tileDevicePixels.toDouble() - band.deviceRect.left,
+        0,
         0,
         tileDevicePixels.toDouble(),
         tileDevicePixels.toDouble(),
```

**Procedure:** copied `tile_cache.dart` aside, applied the edit, ran the
whole package suite with `CI=true flutter test`, then restored from the copy.
**Never `git checkout`.**

**Result:** red on **four of the five differential arms** and on Task 7's
`sliceSourceRect` unit test. The counts are the whole point: 58,424 to 78,387
differing pixels out of 480,000 on the three whole-frame arms, and 10,684 on
the tile-edge sweep alone. Arm 3's number (68,370) is smaller than arm 1's
because its band's first key is `-3`, so a fixed `(0, 0)` source happens to be
right for that one column.

**Verbatim output:**

```
The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <58424>
a band is queried with a pad and clipped without one, and the tiles cut out of it have to hold what
the live frame draws

  [stack trace elided]
The test description was:
  a settled generation is identical to a live frame

The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <68370>
rebasing is frame-global: every band must be walked against the frame origin, not one it derived for
itself

  [stack trace elided]
The test description was:
  and at a camera on a power-of-two rebase boundary

The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <59892>
an edge tile sliced from a viewport-sized source blits its transparent overhang here, and costs the
same as an opaque one, so no timing gate can see it

  [stack trace elided]
The test description was:
  and stays identical after a pan smaller than one tile

The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <78387>
a grid-space slice rectangle reads off the wrong part of the band image as soon as the visible key
range moves

  [stack trace elided]
The test description was:
  and when a pan lands between the scale change and the bake

The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <10684>
a seam lives on the boundary, and a whole-frame count buries it under 62 interior columns out of
every 64

  [stack trace elided]
The test description was:
  tile boundaries carry no difference of their own

00:06 +392 ~1 -7: Some tests failed.
Failing tests:
  test/tile_band_test.dart: the band bake a slice rectangle is band-local and integral
  test/tile_cache_test.dart: criterion 1: a settled frame equals the live frame after a zoom
  test/tile_slice_differential_test.dart: a settled generation is identical to a live frame
  test/tile_slice_differential_test.dart: and at a camera on a power-of-two rebase boundary
  ... and 3 more
```

## M7 — `bandsFor` clamps its band rectangles to the viewport

**Task 9.** A band is cut to the viewport instead of to the tiles it holds, so
the last row's band image is 24 device pixels tall where its tiles are 64. The
slice then reads 40 rows that are not in the image and gets transparency.

**Why arm 2 is its only pixel gate, and why that mattered.** Task 5's overhang
test asserts `greaterThanOrEqualTo`, so a band truncated exactly *to* the
viewport edge satisfies it. The truncated rows also sit outside the viewport at
the camera the band was cut at, so arm 1 cannot see them either: a transparent
blit costs exactly what an opaque one costs, which is why Plan 3h's p95 pan
gate is blind to this as well. It takes a pan smaller than one tile -- 7
logical, 14 device pixels here -- to drag those rows inside the viewport, and
that is arm 2.

**Mutation:**

```diff
@@ -368,11 +368,18 @@
             row * tileDevicePixels.toDouble(),
             byRow[row]!.length * tileDevicePixels.toDouble(),
             tileDevicePixels.toDouble(),
-          ),
+          ).intersect(_viewportDeviceRect(camera, viewport)),
         ),
     ];
   }
 
+  /// M7: the viewport in the grid's own device space.
+  Rect _viewportDeviceRect(ViewportTransform camera, Size viewport) {
+    final (dx, dy) = deviceDeltaFrom(camera);
+    return Rect.fromLTWH(-dx.toDouble(), -dy.toDouble(),
+        viewport.width * devicePixelRatio, viewport.height * devicePixelRatio);
+  }
+
   /// Floor division that stays correct for negative numerators.
   ///
   /// Dart's `~/` truncates toward zero, so `-1 ~/ 64` is `0` and the tile to
```

**Procedure:** copied `tile_cache.dart` aside, applied the edit, ran the
whole package suite with `CI=true flutter test`, then restored from the copy.
**Never `git checkout`.**

**Result:** red on arm 2 (3,780 differing pixels -- 14 device rows across 270
columns of the bottom edge) and on arm 3 (8,692). Arm 1, arm 5 and the tile-edge
sweep are all green under it, which is the measurement Task 5's `>=` bound
predicted.

**Verbatim output:**

```
The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <8692>
an edge tile sliced from a viewport-sized source blits its transparent overhang here, and costs the
same as an opaque one, so no timing gate can see it

  [stack trace elided]
The test description was:
  and stays identical after a pan smaller than one tile

The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <3780>
a grid-space slice rectangle reads off the wrong part of the band image as soon as the visible key
range moves

  [stack trace elided]
The test description was:
  and when a pan lands between the scale change and the bake

00:07 +395 ~1 -4: Some tests failed.
Failing tests:
  test/tile_band_test.dart: a band is one tile tall and the full union width
  test/tile_band_test.dart: the band bake a slice rectangle is band-local and integral
  test/tile_slice_differential_test.dart: and stays identical after a pan smaller than one tile
  test/tile_slice_differential_test.dart: and when a pan lands between the scale change and the bake
```

## M9 — the band query is not padded

**Task 9.** `const pad = 0.0` in `_bakeBand`, so the band walks exactly its own
rectangle and drops every entity whose *bounds* fall outside it. A stroke is
wider than its geometry: an entity whose centreline sits just outside a band
still inks pixels inside it, and the painter's index query is an exact rect
intersection on bounds -- measured, a line 0.1 world units outside a query rect
is not returned.

**The fixture is what makes this visible, and its first arrangement did not.**
`bandCrossingGrid` places one 2.00 mm stroke (3.780 logical pixels of
half-width) one logical pixel outside each band boundary, so it inks 2.780
logical pixels -- 5.56 device rows -- into the band on the far side. The
arrangement that shipped first placed a stroke on *both* sides of every
boundary; those two centrelines are 2 logical pixels apart against a 3.780
half-width, so the inner stroke's ink covers exactly what the outer one's loss
would have exposed and **M9 changed zero pixels at `tileCamera`**. One stroke a
boundary, alternating sides, is what makes the loss reachable. Recorded on
`_sideFor` in `tile_fixture.dart`.

**Mutation:**

```diff
@@ -2006,7 +2006,7 @@
     // uses -- padding one alone makes them disagree. The canvas is pulled back
     // by the same amount, so the padded viewport's origin lands where the
     // band's own origin was.
-    const pad = kTileSlack;
+    const pad = 0.0;
     into.save();
     into.translate(-pad, -pad);
```

**Procedure:** copied `tile_cache.dart` aside, applied the edit, ran the
whole package suite with `CI=true flutter test`, then restored from the copy.
**Never `git checkout`.**

**Result:** red on all five differential arms and on both of Task 6's band-query
unit tests. 30,160 differing pixels on arms 1 and 5, 8,196 and 9,170 on arms 2
and 3, 3,475 on the tile-edge sweep.

**Verbatim output:**

```
The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <30160>
a band is queried with a pad and clipped without one, and the tiles cut out of it have to hold what
the live frame draws

  [stack trace elided]
The test description was:
  a settled generation is identical to a live frame

The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <3475>
rebasing is frame-global: every band must be walked against the frame origin, not one it derived for
itself

  [stack trace elided]
The test description was:
  and at a camera on a power-of-two rebase boundary

The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <30160>
an edge tile sliced from a viewport-sized source blits its transparent overhang here, and costs the
same as an opaque one, so no timing gate can see it

  [stack trace elided]
The test description was:
  and stays identical after a pan smaller than one tile

The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <9170>
a grid-space slice rectangle reads off the wrong part of the band image as soon as the visible key
range moves

  [stack trace elided]
The test description was:
  and when a pan lands between the scale change and the bake

The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <8196>
a seam lives on the boundary, and a whole-frame count buries it under 62 interior columns out of
every 64

  [stack trace elided]
The test description was:
  tile boundaries carry no difference of their own

00:06 +391 ~1 -8: Some tests failed.
Failing tests:
  test/tile_band_test.dart: the band bake the band camera puts a world point at the band-local pixel
  test/tile_band_test.dart: the band bake the padded query reaches kTileSlack past the band on every side
  test/tile_cache_test.dart: criterion 1: a settled frame equals the live frame after a zoom
  test/tile_slice_differential_test.dart: a settled generation is identical to a live frame
  ... and 4 more
```

## M9b — the band pad is applied to the camera but not to the canvas

**Task 9.** `into.translate(-pad, -pad)` is dropped from `_bakeBand` while the
band camera keeps its `+pad`. The query still reaches `kTileSlack` past the
band on every side -- Task 6's two unit tests both stay green -- but every pixel
the band draws lands 32 logical pixels down and right of where it belongs.

**Why it needs its own mutant beside M9.** M9 removes the pad from both halves
at once, which is a *consistent* mistake: the band is then simply narrower than
it should be. This one is the inconsistent half, and it is the failure mode the
pad's own comment warns about ("The canvas is pulled back by the same amount, so
the padded viewport's origin lands where the band's own origin was"). No
query-side assertion can see it.

**Mutation:**

```diff
@@ -2008,7 +2008,6 @@
     // band's own origin was.
     const pad = kTileSlack;
     into.save();
-    into.translate(-pad, -pad);
 
     final m = grid.anchor.worldToScreenMatrix;
     final bandCamera = ViewportTransform(
```

**Procedure:** copied `tile_cache.dart` aside, applied the edit, ran the
whole package suite with `CI=true flutter test`, then restored from the copy.
**Never `git checkout`.**

**Result:** red on all five differential arms, at the largest counts of any
mutant here -- 140,032 to 227,695 differing pixels of 480,000, because every
band's whole content is displaced rather than a few rows of it lost.

**Verbatim output:**

```
The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <140032>
a band is queried with a pad and clipped without one, and the tiles cut out of it have to hold what
the live frame draws

  [stack trace elided]
The test description was:
  a settled generation is identical to a live frame

The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <192258>
rebasing is frame-global: every band must be walked against the frame origin, not one it derived for
itself

  [stack trace elided]
The test description was:
  and at a camera on a power-of-two rebase boundary

The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <140060>
an edge tile sliced from a viewport-sized source blits its transparent overhang here, and costs the
same as an opaque one, so no timing gate can see it

  [stack trace elided]
The test description was:
  and stays identical after a pan smaller than one tile

The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <227695>
a grid-space slice rectangle reads off the wrong part of the band image as soon as the visible key
range moves

  [stack trace elided]
The test description was:
  and when a pan lands between the scale change and the bake

The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <8469>
a seam lives on the boundary, and a whole-frame count buries it under 62 interior columns out of
every 64

  [stack trace elided]
The test description was:
  tile boundaries carry no difference of their own

00:07 +393 ~1 -6: Some tests failed.
Failing tests:
  test/tile_cache_test.dart: criterion 1: a settled frame equals the live frame after a zoom
  test/tile_slice_differential_test.dart: a settled generation is identical to a live frame
  test/tile_slice_differential_test.dart: and at a camera on a power-of-two rebase boundary
  test/tile_slice_differential_test.dart: and stays identical after a pan smaller than one tile
  ... and 2 more
```

## M10 — the slice rectangle is measured in grid space, not band space

**Task 9.** `sliceSourceRect` drops `- band.deviceRect.left`, so a key's source
rectangle is measured from the generation's anchor rather than from the band
image's own origin.

**Why arm 3 is its only pixel gate.** `TileBand.deviceRect.left` is
`keys.first.x * tileDevicePixels` by definition, so it is **zero exactly when
the visible key range starts at column 0** -- and then band-local and
grid-space arithmetic are the same arithmetic and this mutation is the identity.
Every arm that does not move the key range is therefore blind to it, and the
plan's pinned pure-zoom script never moves it: a zoom re-anchors the grid on the
camera it zoomed to, so the range starts at 0 again. Arm 3 takes the pan
**between** the scale change and the rest bake -- `Offset(90, 60)`, 180 x 120
device pixels -- which drives the range to `x0 = -3`, `y0 = -2` and
`deviceRect.left` to -192. Verified on the shipped code, not assumed:
`bands.first.keys.first.x = -3`, `deviceRect = Rect.fromLTRB(-192.0, -128.0,
640.0, -64.0)`.

**Mutation:**

```diff
@@ -339,7 +339,7 @@
   /// numbered. Integral by construction -- [deviceDeltaFrom] rounds, and a
   /// tile side is `tileDevicePixels` exactly.
   Rect sliceSourceRect(TileBand band, TileKey key) => Rect.fromLTWH(
-        key.x * tileDevicePixels.toDouble() - band.deviceRect.left,
+        key.x * tileDevicePixels.toDouble(),
         0,
         tileDevicePixels.toDouble(),
         tileDevicePixels.toDouble(),
```

**Procedure:** copied `tile_cache.dart` aside, applied the edit, ran the
whole package suite with `CI=true flutter test`, then restored from the copy.
**Never `git checkout`.**

**Result:** red on arm 3 (132,650 differing pixels) and on Task 7's
`sliceSourceRect` unit test. Green on arms 1, 2, 4 and 5, exactly as the
`deviceRect.left == 0` degeneracy predicts.

**Verbatim output:**

```
The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <132650>
a grid-space slice rectangle reads off the wrong part of the band image as soon as the visible key
range moves

  [stack trace elided]
The test description was:
  and when a pan lands between the scale change and the bake

00:07 +397 ~1 -2: Some tests failed.
Failing tests:
  test/tile_band_test.dart: the band bake a slice rectangle is band-local and integral
  test/tile_slice_differential_test.dart: and when a pan lands between the scale change and the bake
```

## M11 — the band derives its own rebase origin — **survives every pixel arm**

**Task 9.** `_bakeBand` calls `rebaseOriginFor` on its own padded band viewport
instead of using the frame-global origin handed in. Killed by Task 6's
`every band is rebased against the origin handed in`, which observes the origin
directly. **Not killed by any of the five differential arms, including the one
built for it**, and that is a measurement rather than an omission.

**The arm that was supposed to kill it, and why it cannot.**
`rebaseBoundaryCamera` puts the view span at 133.333 world units -- `floor(log2)
= 7`, step 128 -- with the view centre at 128.1667, one device pixel past the
128 cell boundary, and the visible world y running 78.167 to 178.167 so that
bands genuinely fall on both sides of it. Under M11 the bands therefore *do*
take different origins from the frame: `(128, 128)` for some rows, `(128, 0)`
for others. The frame still comes out **pixel-identical** -- `differingPixels`
reads 0 -- and the reason is in `DraftPainter._emitScreenSpace`: it computes
`p_screen - _screenOrigin` in `float64` and hands the sink
`beginResidual(translation(_screenOrigin))`, and `VerticesDrawSink` adds the
residual back in `float64` before storing an **absolute** screen coordinate in
its `Float32List`. The origin cancels algebraically before anything is rounded
to `float32`, so at this fixture's magnitudes the residual difference is around
`1e-13` device pixels -- fourteen orders of magnitude below the `1.1e-05` that
Task 6a measured as the threshold for flipping a single pixel on a near-axis
slope, and this fixture is axis-aligned by construction.

**What this means for the origin argument.** A pixel comparison is the wrong
instrument for it at ordinary world magnitudes; the direct observation Task 6
ships is the right one, and it is the gate of record. The origin's value is
paid for at 4.5e6-scale coordinates (`large_coordinate_test.dart`), where the
`float64` cancellation above is no longer exact -- a fixture at those
magnitudes could plausibly make a pixel arm see it, and none of this plan's
fixtures is at those magnitudes.

**Mutation:**

```diff
@@ -1988,6 +1988,7 @@
         grid.matchesScale(quantised),
         'a band belongs to one generation, so the frame camera and the grid '
         'anchor must agree on scale');
+    assert(origin.x == origin.x);
     final dpr = grid.devicePixelRatio;
     final width = band.deviceRect.width / dpr;
     final height = band.deviceRect.height / dpr;
@@ -2029,11 +2030,9 @@
       painter,
       sink,
       vertices,
-      // **The viewport's origin, never the band's.** Rebasing is frame-global
-      // by construction: a per-band origin gives each band its own
-      // quantisation step and `float32` residuals the live frame does not
-      // have, and can cross a power-of-two step between one row and the next.
-      origin,
+      // ignore: dead_code
+      rebaseOriginFor(bandCamera
+          .visibleWorld(Size(width + 2 * pad, height + 2 * pad))),
       (handle) => visitedInto.add(handle.value),
     );
     into.restore();
```

**Procedure:** copied `tile_cache.dart` aside, applied the edit, ran the
whole package suite with `CI=true flutter test`, then restored from the copy.
**Never `git checkout`.**

**Result:** red on Task 6's origin test only. The differential arms are green.

**Verbatim output:**

```
00:06 +398 ~1 -1: Some tests failed.
Failing tests:
  test/tile_band_test.dart: the band bake every band is rebased against the origin handed in
```

## M8 — the slice blits through a `FilterQuality.low` paint — **a declared survivor**

**Task 9, and green by design.** `_sliceTile` blits through a paint with
`filterQuality = FilterQuality.low` instead of `none`. Recorded here as a
**declared survivor**, not as a gate's failure: `sliceSourceRect` is integral by
construction and the destination is the same size, so a bilinear sample and a
nearest sample read the same texels and the only difference is that a sampler
was paid for. Plan 3h's M6 had this shape and was recorded as gap H6.

**It dying would have been the finding.** A death here would mean the source
rectangles are *not* integral -- that a slice is resampling -- and the whole
"texture copy, not a raster" claim would be wrong. The full suite is green under
it, which is the positive statement the mutation makes: the rectangles are
integral.

**Mutation:**

```diff
@@ -2080,6 +2080,9 @@
   /// from the rejected Approach B. `FilterQuality.none`: the source rectangle
   /// is integral and the destination is the same size, so there is nothing to
   /// interpolate and a sampler would be pure cost.
+  final Paint _sliceFilterPaint = Paint()
+    ..filterQuality = FilterQuality.low;
+
   Image _sliceTile(Image band, TileBand from, TileKey key, TileGrid grid) {
     final recorder = PictureRecorder();
     final into = Canvas(recorder);
@@ -2088,7 +2091,7 @@
       grid.sliceSourceRect(from, key),
       Rect.fromLTWH(
           0, 0, tileDevicePixels.toDouble(), tileDevicePixels.toDouble()),
-      _blitPaint,
+      _sliceFilterPaint,
     );
     final picture = recorder.endRecording();
     final image = picture.toImageSync(tileDevicePixels, tileDevicePixels);
```

**Procedure:** copied `tile_cache.dart` aside, applied the edit, ran the
whole package suite with `CI=true flutter test`, then restored from the copy.
**Never `git checkout`.**

**Result:** green, as declared. 399 passed, 1 skipped.

**Verbatim output:**

```
00:06 +399 ~1: All tests passed!
```

---

## M5 — the sliced tile is never given the band's `_baked` record

**Task 10.** `_invalidateTouched` condemns tiles by iterating `_baked` in both
directions: what a handle *was* baked into, and what its new geometry
*reaches*. A tile sliced out of a band shares one `Uint32List` record with
every other tile the band cut, written by `_baked[key] = record;` inside the
slice loop. Deleting that one line leaves every sliced tile absent from
`_baked` entirely — invisible to both directions of invalidation — while the
tile's pixels stay resident and keep blitting.

**Fixture note.** The test drives its first settle through
`settleFromBands`, not a plain `settle`. Measured directly: at this harness's
budget (`kBakeBudgetDevicePixels`, 64 tiles of 64 device pixels per frame) a
plain `settle` over `bandCrossingGrid` bakes 128 of the viewport's 130 tiles
through the ordinary per-tile `_bake` path across its first two frames, before
the rest gate ever arms, and slices only the 2 tiles the rest bake finds
missing — confirmed by instrumenting `debugOnSliceForTest` on a throwaway
probe (`plain settle: liveTileCount=130 slices=2`; `settleFromBands:
liveTileCount=130 slices=130`). `kMovableHandle`'s resting tile (column 2, row
4) is nowhere near that bottom-right corner, so a test built on a plain
`settle` exercises the ordinary `_bake` path's own (separate) `_baked[key] =
...` write and never reaches the line this mutant deletes — the mutation
would survive for a reason unconnected to the code under test. `settleFromBands`
forces a table edit that drops every tile at the same, unmoved camera, so the
next frame's rest bake slices the whole viewport (130 of 130, asserted in the
test as `slices == tilesBefore`), and `kMovableHandle`'s tile is necessarily
among them.

**Mutation:**

```diff
--- a/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
+++ b/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
@@ -1209,7 +1209,7 @@
         if (!_makeRoomForOneTile()) break;
         final tile = _sliceTile(image, band, key, grid);
         _tiles[key] = tile;
-        _baked[key] = record;
+        // M5, deliberately absent: _baked[key] = record;
         _lastUsedFrame[key] = _frameSerial;
       }
       _band = null;
```

**Procedure:** copied `tile_cache.dart` aside to
`/private/tmp/claude-501/-Users-ahmeturel-Projects-oss-jet-cad/d5e851c1-248d-41da-b1c1-19632c9b5179/scratchpad/tile_cache.green.dart`,
applied the edit, ran `CI=true flutter test test/tile_invalidation_test.dart`,
then restored from the copy and diffed to confirm the restore was exact.
**Never `git checkout`.**

**Result:** red, as expected — and red for the intended reason: the movable
entity is unfindable in the settled cache at all, because its tile carries no
`_baked` record for anything.

**Verbatim output:**

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart
00:00 +0: criterion 5: a leaf edit invalidates its own tiles and no others
00:00 +1: criterion 5: a dragged instance drops the tiles it left
00:00 +2: criterion 5: a dragged group leaves no ghost either
00:00 +3: criterion 6: a group and an instance nested inside a definition
00:00 +4: criterion 5: the undo of an instance transform invalidates both ends
00:00 +5: criterion 6: a definition edit drops the generation, and less does not
00:00 +6: criterion 9: all five change arms, none omitted
00:00 +7: criterion 9: a load starts a new generation, an edit does not
00:00 +8: criterion 5 / gap G6: a stroke reaching into a tile its geometry misses invalidates it
00:00 +9: criterion 7: a layer edit repaints and drops the generation
00:00 +10: an edit after a sliced settle condemns the sliced tiles
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: non-empty
  Actual: Set:[]
the movable entity must be findable in the settled cache

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart:690:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart line 690
The test description was:
  an edit after a sliced settle condemns the sliced tiles
════════════════════════════════════════════════════════════════════════════════════════════════════
00:00 +10 -1: an edit after a sliced settle condemns the sliced tiles [E]
  Test failed. See exception logs above.
  The test description was: an edit after a sliced settle condemns the sliced tiles
  
00:00 +10 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: an edit after a sliced settle condemns the sliced tiles
```

---

## M12 — the skew term c is not compared

**Batch-minors pass, found by review of `tile_regime_test.dart`.** Every
fixture in that file — the `at()` helper and the skew test's own literals —
sets `c = 0`, including both sides of `'the skew terms are compared too'`.
Deleting `x.c == y.c` from `sameQuantisedCamera` therefore killed no test: `c`
never varied, so the field being ignored was indistinguishable from the field
being equal. Fixed by extending that test with a second pair that varies `c`
and holds every other field fixed.

**Mutation:**

```diff
--- a/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
+++ b/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
@@ -240,7 +240,6 @@
   return x.a == y.a &&
       x.b == y.b &&
-      x.c == y.c &&
       x.d == y.d &&
       x.e == y.e &&
       x.f == y.f;
```

**Procedure:** copied `tile_cache.dart` aside to the scratchpad, edited the
working file to delete `x.c == y.c &&`, ran
`CI=true flutter test test/tile_regime_test.dart`, confirmed red, then
restored the working file from the scratchpad copy. **Never `git checkout`.**

**Result:** red, as expected — the new `c1`/`c2` case in `'the skew terms are
compared too'` fails because two transforms differing only in `c` now compare
equal.

**Verbatim output:**

```
Resolving dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (105.0.0 available)
  analyzer 13.3.0 (14.1.0 available)
  code_assets 1.2.1 (2.0.0 available)
  hooks 2.1.0 (2.2.0 available)
  lucide_icons_flutter 3.1.15 (3.1.17 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  objective_c 9.5.0 (9.6.0 available)
  package_config 2.2.0 (3.0.0 available)
  record_use 1.1.0 (1.1.1 available)
  shadcn_ui 0.55.1 (0.56.2 available)
  source_maps 0.10.13 (0.10.14 available)
  test 1.31.1 (1.31.2 available)
  test_api 0.7.12 (0.7.13 available)
  test_core 0.6.18 (0.6.19 available)
  vm_service 15.2.0 (15.3.0 available)
Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`!
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart
00:00 +0: the same camera compares same
00:00 +1: a scale change compares different
00:00 +2: a translation change compares different
00:00 +3: the skew terms are compared too
00:00 +3 -1: the skew terms are compared too [E]
  Expected: false
    Actual: <true>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_regime_test.dart 43:5                     main.<fn>
  
00:00 +3 -1: a moving frame bakes nothing and walks nothing
00:00 +4 -1: a moving frame with no composite falls through and draws something
00:00 +5 -1: a steadily spun wheel never arms the rest gate
00:00 +6 -1: the gate needs two unchanged frames, not one
00:00 +7 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart: the skew terms are compared too
```

Restored from the scratchpad copy and re-ran the same file green (`+8: All
tests passed!`) before moving on.

---

## M13 — the rest bake ignores `debugRestBakeDisabled`

**Task:** Task 12a, "the two measurement seams" (Ruling 14). Gates
`test/tile_measurement_seam_test.dart`'s `'debugRestBakeDisabled slices
nothing and still covers'`.

**Why this mutant and not another.** `TileCache.debugRestBakeDisabled` is a
measurement switch: criterion 4's denominator arm is *this cache without the
rest bake*, and the only way to reach it inside one interleaved session is a
runtime flag. A flag that is declared, documented and read — but whose read
changes nothing the frame path does — fails silently and in the worst
possible place: both arms of the ratio would run identical code, the ratio
would read exactly **1.00**, and the number would be written into a document
of record with nothing to contradict it. M13 is that failure, applied on
purpose.

**Mutation**, applied to
`packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`:

```diff
--- a/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
+++ b/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
@@ -1055,7 +1055,7 @@
-    if (_restGateSteps >= kRestGateFrames && !debugRestBakeDisabled) {
+    if (_restGateSteps >= kRestGateFrames) {
       _restBake(grid, quantised, viewport, painter, sink, vertices, origin);
     }
```

**Procedure:** copied `tile_cache.dart` aside to the scratchpad
(`tile_cache_m13.bak`), edited the working file, ran
`CI=true flutter test test/tile_measurement_seam_test.dart`, confirmed red,
then restored the working file with `cp` from the scratchpad copy and
confirmed `diff` produced no output. **Never `git checkout`.**

**Result:** red, on the slice count and not on the flag's own value. The
flagged arm slices **130** — every visible tile — where correct code slices
**0**. The other two tests in the file stay green, which is the point of the
first one: `'the rest bake fires, and debugRestBakeDisabled suppresses it'`
is the unflagged arm, and under M13 it is still true, so a reader can see
that the mutation removed the *difference between the arms* rather than
breaking the bake.

**Verbatim output** (the `flutter pub get` preamble, identical to every other
entry in this file, is trimmed):

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart
00:00 +0: the rest bake fires, and debugRestBakeDisabled suppresses it
00:00 +1: debugRestBakeDisabled slices nothing and still covers
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <130>
with the rest bake disabled no tile may be cut from a band -- criterion 4's denominator arm is the
budgeted per-tile path, and an arm that still slices is the numerator arm under a different name,
which would put the ratio at 1.00

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart:169:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart line 169
The test description was:
  debugRestBakeDisabled slices nothing and still covers
════════════════════════════════════════════════════════════════════════════════════════════════════
00:00 +1 -1: debugRestBakeDisabled slices nothing and still covers [E]
  Test failed. See exception logs above.
  The test description was: debugRestBakeDisabled slices nothing and still covers
  
00:00 +1 -1: debugFullViewportQuery grows the fallback walk to the whole viewport
00:00 +2 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart: debugRestBakeDisabled slices nothing and still covers
```

**Restore, verified.** `cp` from the scratchpad copy, `diff` against it empty,
and the same file re-run green:

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart
00:00 +0: the rest bake fires, and debugRestBakeDisabled suppresses it
00:00 +1: debugRestBakeDisabled slices nothing and still covers
00:00 +2: debugFullViewportQuery grows the fallback walk to the whole viewport
00:00 +3: All tests passed!
```

---

## M14 — the live fallback ignores `debugFullViewportQuery`

**Task:** Task 12a (Ruling 14). Gates
`test/tile_measurement_seam_test.dart`'s `'debugFullViewportQuery grows the
fallback walk to the whole viewport'`.

**Why this mutant.** `TileCache.debugFullViewportQuery` reproduces **Plan
3h's M4** — see `plan-3h-mutation-log.md` §"M4 — narrow the clip but not the
query" — at runtime, so that criterion 8's "narrow" and "M4" arms can
interleave inside one session instead of being two binaries run
three-then-three. **Note the numbering collision:** this file's own M4 is a
different mutation entirely; the flag reproduces *3h's* M4.

A flag that is read but inert here is the same silent 1.00 as M13, with an
extra trap of its own: M4 is pixel-invisible by construction. The clip stays
narrow, so every pixel lands exactly where it belongs whether the query is
the strip or the viewport; only the *amount of geometry tessellated to
produce them* changes. So no pixel gate can see this switch fail, and the
test that gates it has to read the strip the frame actually walked
(`debugLastStrip`, written by `paintFrame` itself) and the triangles it
actually emitted (`VerticesDrawSink.frameTriangleCount`) — which is the same
instrument `kTriangleBudgetRatio` uses to kill 3h's M4 as a source edit.

**Mutation**, applied to
`packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`:

```diff
--- a/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
+++ b/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
@@ -1147,9 +1147,7 @@
-    final strip = debugFullViewportQuery
-        ? Offset.zero & viewport
-        : stripFor(uncovered, viewport);
+    final strip = stripFor(uncovered, viewport);
     _lastStrip = strip;
```

**Procedure:** copied `tile_cache.dart` aside to the scratchpad
(`tile_cache_m14.bak`), edited the working file, ran
`CI=true flutter test test/tile_measurement_seam_test.dart`, confirmed red,
then restored with `cp` and confirmed `diff` produced no output. **Never `git
checkout`.**

**Result:** red on the recorded strip. At the swept pan `Offset(0, 53)` on
`fillingGrid` — the offset `kTriangleBudgetRatio`'s doc comment identifies as
the tightest sample in that sweep — correct code produces

- narrow arm: strip `Rect.fromLTRB(0, 0, 400, 85)`, **60** triangles
- M4 arm: strip `Rect.fromLTRB(0, 0, 400, 300)`, **80** triangles

so the flag moves the walk by 215 logical rows and the geometry by a third.
Under M14 the M4 arm collapses onto the narrow arm exactly — same strip, same
60 triangles — which is the reading the test refuses.

**Verbatim output** (preamble trimmed as above):

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart
00:00 +0: the rest bake fires, and debugRestBakeDisabled suppresses it
00:00 +1: debugRestBakeDisabled slices nothing and still covers
00:00 +2: debugFullViewportQuery grows the fallback walk to the whole viewport
00:00 +2 -1: debugFullViewportQuery grows the fallback walk to the whole viewport [E]
  Expected: Rect:<Rect.fromLTRB(0.0, 0.0, 400.0, 300.0)>
    Actual: Rect:<Rect.fromLTRB(0.0, 0.0, 400.0, 85.0)>
  with the flag set the query is the full viewport -- that is what Plan 3h's M4 is: _FallbackArm(strip: Rect.fromLTRB(0.0, 0.0, 400.0, 85.0), triangles: 60, liveDraws: 1)
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_measurement_seam_test.dart 211:5          main.<fn>
  
00:00 +2 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart: debugFullViewportQuery grows the fallback walk to the whole viewport
```

**Restore, verified.** `cp` from the scratchpad copy, `diff` against it empty,
`git status --porcelain` showing only this task's own two paths, and the file
re-run green:

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart
00:00 +0: the rest bake fires, and debugRestBakeDisabled suppresses it
00:00 +1: debugRestBakeDisabled slices nothing and still covers
00:00 +2: debugFullViewportQuery grows the fallback walk to the whole viewport
00:00 +3: All tests passed!
```

**One thing M14 does not gate, named rather than hidden.** The test asserts
the M4 arm's strip *equals* the full viewport and that its triangle count
*exceeds* the narrow arm's. It does not assert that the clip stayed narrow —
that is what makes the flag M4 rather than M5, and it is held by the source
(the flag's ternary touches only `strip`, and `canvas.clipRect(uncovered,
...)` is on the line above it) and by the flag's own doc comment, not by a
test. A future edit that widened the clip under the flag would keep this test
green while publishing an "M4" arm that is not M4.

---

## M15 — a retired generation keeps its tiles

**Task:** the criterion 4 warmth investigation. Gates
`test/tile_zoom_warmth_test.dart`'s `'a zoom round trip leaves the next arm
nothing warm to settle on'`.

**Why this mutant.** Criterion 4 runs two arms of `runTileZoomPhase` against
**one** `TileCache`, and each arm's script is symmetric: `kZoomSteps` steps at
`kZoomFactor` then the same number at `1 / kZoomFactor`, ending arithmetically
where it began. If a settled generation could survive an arm's gesture, the
next arm's settle would find the viewport already covered and report its
`settleFrames` **trivially**, in both arms, whatever the flag between them
did — the ratio would read cache warmth rather than the rest bake, and be
published as if it were the effect. That is exactly the degenerate fixture
`CLAUDE.md` names as this codebase's dominant failure mode, and M15 is that
failure applied on purpose: the one line that makes a retired generation
actually go away.

**Mutation**, applied to
`packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`:

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

**Procedure:** copied `tile_cache.dart` aside to the scratchpad
(`tile_cache_m15.bak`), edited the working file, ran
`CI=true flutter test test/tile_zoom_warmth_test.dart`, confirmed red, then
restored the working file with `cp` from the scratchpad copy and confirmed
`diff` produced no output. **Never `git checkout`.**

**Result:** red at the first frame of the first arm's excursion, on
`liveTileCount`. Correct code reads **0** there — one 3% zoom step is enough
to fail `TileGrid.matchesScale`, so `_gridFor` retires the generation and
`_retireGeneration` disposes its tiles — while under M15 all **130** tiles of
the settled generation are still live. That is the leftover warmth the
concern described, made real; the assertion that catches it is the one the
whole file exists for.

The assertion order matters and is deliberate: the test could have been
written to check only the second arm's `settleFrames`, and it does check that
too, but the *first frame of the first arm* is the only place where a single
scale step has to have been sufficient. By the end of an 80-frame excursion
"no tiles" is over-determined.

**Verbatim output** (the `flutter pub get` preamble, identical to every other
entry in this file, is trimmed):

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_zoom_warmth_test.dart
00:00 +0: a zoom round trip leaves the next arm nothing warm to settle on
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: <0>
  Actual: <130>
retiring the generation disposes its tiles -- the warm set the previous settle left behind cannot
survive into this arm

When the exception was thrown, this was the stack:
#4      main.runArm (file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_zoom_warmth_test.dart:109:9)
<asynchronous suspension>
#5      main.<anonymous closure> (file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_zoom_warmth_test.dart:164:18)
<asynchronous suspension>
#6      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#7      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_zoom_warmth_test.dart line 109
The test description was:
  a zoom round trip leaves the next arm nothing warm to settle on
════════════════════════════════════════════════════════════════════════════════════════════════════
00:00 +0 -1: a zoom round trip leaves the next arm nothing warm to settle on [E]
  Test failed. See exception logs above.
  The test description was: a zoom round trip leaves the next arm nothing warm to settle on
  
00:00 +0 -1: the zoom round trip does not return to the starting scale
00:00 +1 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_zoom_warmth_test.dart: a zoom round trip leaves the next arm nothing warm to settle on
```

**Restore, verified.** `cp` from the scratchpad copy, `diff` against it empty,
`git status --porcelain` showing only this task's own new test file, and the
file re-run green:

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_zoom_warmth_test.dart
00:00 +0: a zoom round trip leaves the next arm nothing warm to settle on
00:00 +1: the zoom round trip does not return to the starting scale
00:00 +2: All tests passed!
```

**The second, independent reason, which M15 does not touch.** The file's other
test pins that the round trip does not return to the starting camera at all:
`zoomAt` composes `about * m`, which for an unskewed camera is a scalar
multiply of the scale term once per step, so 40 multiplies by `1.03` followed
by 40 by `1 / 1.03` take **1.4 to 1.4000000000000017**, and `matchesScale` —
like every stored-value comparison in `tile_cache.dart` — is exact `==`. That
test is killed by a different mutant (`matchesScale` comparing with a
`Tolerance` instead of `==`), not by M15, and it is deliberately kept separate:
under M15 it stays green, which is what shows the two reasons are independent
rather than one reason asserted twice.

---

## M16 — the clip widens along with the query under `debugFullViewportQuery`

**Task:** the batch-minors pass, closing the gap M14's own log entry named:
"One thing M14 does not gate... It does not assert that the clip stayed
narrow... A future edit that widened the clip under the flag would keep this
test green while publishing an 'M4' arm that is not M4." Gates
`test/tile_measurement_seam_test.dart`'s `'debugFullViewportQuery grows the
fallback walk to the whole viewport'`, specifically its `debugLastClip`
assertions.

**Why this mutant.** `TileCache.debugFullViewportQuery` is Plan 3h's M4 and
not its M5 *precisely because* the clip stays narrow while the query widens —
the flag's own doc comment and `tile_cache.dart:1140`'s comment both say so.
Before this task, nothing in the test suite read the clip independently of
the strip: `debugLastStrip` sees only what the fallback *walked*. An edit that
widened `canvas.clipRect` under the flag would keep every existing assertion
green — the strip still reads the full viewport, the triangle count is still
higher — while publishing an "M4" arm that is neither 3h's M4 nor its M5. This
mutant is that edit, made on purpose, to prove the new `debugLastClip` read
and its assertions are not vacuous.

**Mutation**, applied to
`packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`:

```diff
--- a/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
+++ b/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
@@ -1169,7 +1169,9 @@
     // stay correct, so the sweep still reads zero, and the cost this whole
     // change exists to remove comes back silently.
-    canvas.clipRect(uncovered, doAntiAlias: false);
-    _lastClip = uncovered;
+    final clip =
+        debugFullViewportQuery ? Offset.zero & viewport : uncovered;
+    canvas.clipRect(clip, doAntiAlias: false);
+    _lastClip = clip;
     // **Walk the union, not the viewport.** The clip above only discards
```

**Procedure:** copied `tile_cache.dart` aside to the scratchpad
(`tile_cache_m16.bak`), edited the working file, ran
`CI=true flutter test test/tile_measurement_seam_test.dart`, confirmed red,
then restored the working file with `cp` from the scratchpad copy and
confirmed `diff` produced no output. **Never `git checkout`.**

**Result:** red on `debugLastClip`, not on the strip or the triangle count —
both of those stay exactly as M14's fix expects, because the mutation touches
only the clip. At the same swept pan `Offset(0, 53)` on `fillingGrid`:

- narrow arm: clip `Rect.fromLTRB(0.0, -11.0, 416.0, 53.0)` (the padded,
  viewport-clamped `uncovered`)
- M4 arm under the mutation: clip `Rect.fromLTRB(0.0, 0.0, 400.0, 300.0)` —
  the full viewport, identical to its own (correctly widened) strip

so under the mutation the clip moves with the flag and collapses onto the
strip, which is exactly the "M4 that is neither M4 nor M5" state the new
assertions exist to refuse.

**Verbatim output** (preamble trimmed as in every other entry in this file):

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart
00:00 +0: the rest bake fires: the unflagged arm slices every visible tile
00:00 +1: debugRestBakeDisabled slices nothing and still covers
00:00 +2: debugFullViewportQuery grows the fallback walk to the whole viewport
00:00 +2 -1: debugFullViewportQuery grows the fallback walk to the whole viewport [E]
  Expected: Rect:<Rect.fromLTRB(0.0, -11.0, 416.0, 53.0)>
    Actual: Rect:<Rect.fromLTRB(0.0, 0.0, 400.0, 300.0)>
  the clip must not move when the flag is set -- only the query does: narrow=_FallbackArm(strip: Rect.fromLTRB(0.0, 0.0, 400.0, 85.0), clip: Rect.fromLTRB(0.0, -11.0, 416.0, 53.0), triangles: 60, liveDraws: 1) m4=_FallbackArm(strip: Rect.fromLTRB(0.0, 0.0, 400.0, 300.0), clip: Rect.fromLTRB(0.0, 0.0, 400.0, 300.0), triangles: 80, liveDraws: 1)
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_measurement_seam_test.dart 229:5          main.<fn>
  
00:00 +2 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart: debugFullViewportQuery grows the fallback walk to the whole viewport
```

**Restore, verified.** `cp` from the scratchpad copy, `diff` against it empty,
`git status --porcelain` showing only this task's own paths, and the file
re-run green:

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart
00:00 +0: the rest bake fires: the unflagged arm slices every visible tile
00:00 +1: debugRestBakeDisabled slices nothing and still covers
00:00 +2: debugFullViewportQuery grows the fallback walk to the whole viewport
00:00 +3: All tests passed!
```

---

## M20 — the settle reads the frame before the one that covered

**Task:** fix wave B, the Blocking finding of Plan 3i's final whole-branch
review. Gates `apps/dev_harness_2d/test/settle_attribution_test.dart`.

**Why this mutant and not another.** `settleMs` is the only time value
criteria 3 and 4 are read off, and it named the wrong frame *systematically*,
not occasionally. A `FrameTiming` is delivered only after its frame has
rasterised; `pumpFrame` completes at `SchedulerBinding.endOfFrame`, the
frame's post-frame phase, *before* its scene rasterises. The idle loop
registered a fresh `collectIdle` callback around a single `await pumpFrame()`
and read `.last` out of it, so the timings it saw for idle frame *i* were
frame *i-1*'s, or none. On correct code coverage first reads true at idle
frame **2** (Ruling 15), so the published figure was idle frame 1: the
in-between composite blit that draws nothing and is essentially free. The
number would have looked exactly like the one-frame settle criterion 3 wants,
and would have been a measurement of a blit. M20 restores that attribution as
a one-ordinal shift, which is precisely what the old code did.

**Mutation**, applied to
`apps/dev_harness_2d/lib/measurement_rig.dart`, in `runSettlePhase`:

```diff
--- a/apps/dev_harness_2d/lib/measurement_rig.dart
+++ b/apps/dev_harness_2d/lib/measurement_rig.dart
@@ -876,1 +876,1 @@
-  final ms = log.msRange(firstOrdinal, firstOrdinal + frames);
+  final ms = log.msRange(firstOrdinal - 1, firstOrdinal + frames - 1);
```

**Procedure:** copied `measurement_rig.dart` aside to the scratchpad
(`measurement_rig_m20.bak`), edited the working file, ran
`CI=true flutter test --concurrency=1 test/settle_attribution_test.dart` from
`apps/dev_harness_2d`, confirmed red, then restored the working file with `cp`
from the scratchpad copy and confirmed `diff` produced no output. **Never
`git checkout`.**

**Result:** red, six of the nine tests, and the named mutation the brief asked
for dies on the figure moving: with the covering frame made arbitrarily
expensive, `coveringFrameMs` reads **4.0** -- the cheap frame before it -- in
both the 9 ms arm and the 900 ms arm. The settle figure is inert under the
mutant, which is the whole point: a number that cannot move is not a
measurement. Criterion 4's wall clock dies alongside it (**6.0** where the
three-frame settle is 5 + 6 + 90 = 101.0), and the drain test dies on the hole
rather than on a value, because a shifted window leaves the last frame
unattributed.

Two tests survive M20 and are meant to: `'the gesture window excludes the
warm-up frames and keeps its tail'` reads a different window (the gesture's,
not the settle's), and `'a frame that never reports is a hole, not a zero'`
asserts a shortfall that a shift by one does not change.

**Verbatim output** (the `flutter pub get` preamble, identical to every other
entry in this file, is trimmed):

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart
00:00 +0: the covering frame is the one reported, not the frame before it
00:00 +0 -1: the covering frame is the one reported, not the frame before it [E]
  Expected: <0>
    Actual: <1>
  both settle frames must have reported a timing
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/settle_attribution_test.dart 104:5             main.<fn>
  
00:00 +0 -1: the settle frame moves the reported figure
00:00 +0 -2: the settle frame moves the reported figure [E]
  Expected: a numeric value within <1e-9> of <9.0>
    Actual: <4.0>
     Which:  differs by <5.0>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/settle_attribution_test.dart 134:5             main.<fn>
  
00:00 +0 -2: wall clock over the settle is the sum, not the last frame
00:00 +0 -3: wall clock over the settle is the sum, not the last frame [E]
  Expected: a numeric value within <1e-9> of <90.0>
    Actual: <6.0>
     Which:  differs by <84.0>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/settle_attribution_test.dart 159:5             main.<fn>
  
00:00 +0 -3: the idle frames after coverage are not charged to the settle
00:00 +0 -4: the idle frames after coverage are not charged to the settle [E]
  Expected: a numeric value within <1e-9> of <11.0>
    Actual: <5.0>
     Which:  differs by <6.0>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/settle_attribution_test.dart 186:5             main.<fn>
  
00:00 +0 -4: the last idle frame is drained rather than dropped
00:00 +0 -5: the last idle frame is drained rather than dropped [E]
  Expected: <0>
    Actual: <1>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/settle_attribution_test.dart 211:5             main.<fn>
  
00:00 +0 -5: a settle that never covers says so
00:00 +0 -6: a settle that never covers says so [E]
  Expected: a numeric value within <1e-9> of <21.0>
    Actual: <14.0>
     Which:  differs by <7.0>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/settle_attribution_test.dart 234:5             main.<fn>
  
00:00 +0 -6: a frame that never reports is a hole, not a zero
00:00 +1 -6: the gesture window excludes the warm-up frames and keeps its tail
00:00 +2 -6: a short sample is counted, and length plus missing is the script
00:00 +3 -6: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart: a settle that never covers says so
  /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart: the covering frame is the one reported, not the frame before it
  /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart: the idle frames after coverage are not charged to the settle
  /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart: the last idle frame is drained rather than dropped
  ... and 2 more
```

**Restore, verified.** `cp` from the scratchpad copy, `diff` against it empty,
and the same file re-run green:

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart
00:00 +0: the covering frame is the one reported, not the frame before it
00:00 +1: the settle frame moves the reported figure
00:00 +2: wall clock over the settle is the sum, not the last frame
00:00 +3: the idle frames after coverage are not charged to the settle
00:00 +4: the last idle frame is drained rather than dropped
00:00 +5: a settle that never covers says so
00:00 +6: a frame that never reports is a hole, not a zero
00:00 +7: the gesture window excludes the warm-up frames and keeps its tail
00:00 +8: a short sample is counted, and length plus missing is the script
00:00 +9: All tests passed!
```
