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
