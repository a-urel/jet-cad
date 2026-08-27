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
