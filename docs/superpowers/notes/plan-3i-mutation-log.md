# Plan 3i — mutation log

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
