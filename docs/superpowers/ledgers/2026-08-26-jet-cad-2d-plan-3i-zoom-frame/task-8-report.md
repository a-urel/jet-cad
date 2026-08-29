# Task 8 report — wire the rest bake into `paintFrame`

## 1. What changed

### `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`

- **`debugOnSliceForTest`** — a `@visibleForTesting` `void Function()?` field
  beside `debugSetBand`, called once per sliced tile while the band image is
  resident. The only point at which the byte ceiling can be observed at its
  peak.
- **`paintFrame`** — after the `if (!resting) { ... return; }` guard, a call
  to the new `_restBake`, gated on `_restGateSteps >= kRestGateFrames` rather
  than on `resting`. See §2 for why the literal gate and not `resting`.
- **`_restBake`** — the resting branch. Walks `grid.bandsFor`, bakes one band
  image at a time via `_bakeBand`, assigns it to `_band` (so `liveBytes` sees
  it on the real path, which Task 4's seam could not prove), slices its keys
  out with `_sliceTile`, nulls `_band` and disposes the image before the next
  band starts. One image alive at a time.
- **`_recordOwners(List<int> visited, DraftDocument document)`** — `_bake`'s
  owner climb applied once per band. §3.
- **`_bandBytesOf(TileBand)`** — one band image's RGBA footprint.
- **`_makeRoomForBytes(int wanted)`** — `_makeRoomForOneTile` generalised to an
  allocation that is not a tile; `_makeRoomForOneTile()` is now
  `=> _makeRoomForBytes(_tileBytes)`. The eviction loop, the victim policy and
  the blitted-this-frame guard are byte-for-byte the previous body with
  `_tileBytes` replaced by `wanted`.

**`debugBakeBand` and `debugSliceTile` are kept.** Their doc comments say they
exist because the private methods they wrap had no production caller and
`unused_element` is an error in this package. That justification is now gone —
`_bakeBand` and `_sliceTile` are both called from `_restBake`. They are kept
because Tasks 6 and 7's tests reference them, and their doc comments are now
mildly stale on that one point. Flagged here rather than edited, since a later
task may want to decide whether those tests should go through the real path
instead.

### Test files

- **new** `test/support/tile_harness.dart` — `TiledHarness`, `pumpTiled` and
  `settle` moved verbatim out of `test/tile_regime_test.dart`, which is where
  they lived and where the brief's two new tests could not reach them. No
  behaviour change; `tile_regime_test.dart` imports them now, and its
  `flutter/widgets.dart` and `support/tile_fixture.dart` imports went with the
  moved code (both became unused, and `unused_import` is an error here).
- `test/tile_settle_test.dart` — the brief's `the settle completes in one
  frame`, verbatim.
- `test/invariants/tile_bytes_test.dart` — the brief's `the ceiling holds at
  every point inside the rest frame`, verbatim.
- Five pre-existing tests repaired: §6.

## 2. Two design decisions the brief's sketch does not carry

Both were forced by the suite, and both are stated in the code.

**(a) The band bake is gated on `_restGateSteps >= kRestGateFrames`, not on
`resting`.** `resting` is true on two frames that are not at rest: the very
first frame the cache paints (`previous == null`) and any moving frame with no
composite to fall back on (`_carryOver == null`). `paintFrame`'s own comment
says what those two disjuncts are for — they "fall through to the ordinary
bake-and-live-walk path" so the viewport is never blank. That path is budgeted;
the band bake is not. Handing those frames to the band bake spends a
full-viewport walk on the first frame of a still-moving gesture, which is the
zoom-regime cost this cache exists to refuse. Gating on `resting` left **21**
pre-existing tests red; the literal gate left **5**, and the fifth is
accounted for in §6.

**(b) The rest bake is priced whole before it starts, and that is what
licenses dropping the composite.** `bandBytes + visibleTiles * _tileBytes >
cacheBytes` returns before touching anything. Without it, a ceiling too small
for the fill would evict the rest bake's own output slice by slice, arrive
covering nothing, and have thrown the composite away to do it — stale pixels
replaced by a live walk, every frame, forever. This is
`_makeRoomForOneTile`'s "bakes nothing rather than overrun" arm at band scale,
and it is what keeps `tile_budget_test`'s two composite-under-a-tight-ceiling
fixtures alive.

## 3. The owner climb, and what was verified about it

`_bake`'s `onVisit` does three things per visited handle: records the handle,
then — for a leaf — climbs `document.entities.ownerAt(slot)` to the root, or —
for an instance node the painter descended into — climbs `node.parent`. The
climb memoises through a `containers` set that doubles as the termination guard
("once a node is in, every ancestor of it is in too"), which is what keeps it
linear in visits and what makes a cyclic parent chain terminate.

`_bakeBand`'s `onVisit` is `(handle) => visitedInto.add(handle.value)` and
records the direct visit only. `_recordOwners` reproduces the rest, once per
band:

- it reads only the prefix of `visited` that was there on entry (`final direct
  = visited.length` before the loop), so the owners it appends are not
  re-climbed — they cannot add anything, because `climb` already walks each
  chain to its root;
- `containers` is band-scoped, so the memo works across the band's handles the
  same way `_bake`'s works across a tile's;
- the leaf arm, the instance-node arm, the `node == null` definition-handle
  early return and the `node.parent.isNone` root stop are the same four
  branches, in the same order.

**Verified, not asserted.** A throwaway probe (written, run, then deleted —
Task 10 is the task chartered to gate this) drove `pumpTiled` → `settle` →
`zoomAt` → three pumps and read `TileCache.tilesHolding`:

```
PROBE afterSettle=475
PROBE moving=0
PROBE between=0
PROBE liveTiles=475 tilesHoldingRoot=425 tilesHoldingLeaf=75
PROBE bakeCount=166 gen=2
00:00 +1: All tests passed!
```

Every one of the 75 tiles that recorded leaf `Handle(1000)` also recorded the
document root. The 50 tiles that hold no root record hold nothing at all —
`fillingGrid` does not reach the far right and bottom of an 800x600 logical
viewport, and an empty band records an empty visit list exactly as an empty
tile does under `_bake`.

Then, with `_recordOwners(visited, painter.document);` commented out and
nothing else changed:

```
PROBE afterSettle=475
PROBE moving=0
PROBE between=0
PROBE liveTiles=475 tilesHoldingRoot=0 tilesHoldingLeaf=75
PROBE bakeCount=166 gen=2
Expected: empty
  Actual: Set:[
every tile that recorded a leaf recorded its owner chain
00:00 +0 -1: Some tests failed.
```

425 tiles holding the root becomes 0. The climb is load-bearing and it works.
The source was restored from the copy afterwards, never by `git checkout`.

## 4. RED — the two new tests before the implementation

`cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_settle_test.dart test/invariants/tile_bytes_test.dart`

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
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_settle_test.dart
test/invariants/tile_bytes_test.dart:36:13: Error: The setter 'debugOnSliceForTest' isn't defined for the type 'TileCache'.
 - 'TileCache' is from 'package:jet_cad_2d_flutter/src/tile_cache.dart' ('lib/src/tile_cache.dart').
Try correcting the name to the name of an existing setter, or defining a setter or field named 'debugOnSliceForTest'.
    h.cache.debugOnSliceForTest = () {
            ^^^^^^^^^^^^^^^^^^^
test/invariants/tile_bytes_test.dart:40:31: Error: The setter 'debugOnSliceForTest' isn't defined for the type 'TileCache'.
 - 'TileCache' is from 'package:jet_cad_2d_flutter/src/tile_cache.dart' ('lib/src/tile_cache.dart').
Try correcting the name to the name of an existing setter, or defining a setter or field named 'debugOnSliceForTest'.
    addTearDown(() => h.cache.debugOnSliceForTest = null);
                              ^^^^^^^^^^^^^^^^^^^
00:00 +0 -1: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart [E]
  Failed to load "/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart":
  Compilation failed for testPath=/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart: test/invariants/tile_bytes_test.dart:36:13: Error: The setter 'debugOnSliceForTest' isn't defined for the type 'TileCache'.
   - 'TileCache' is from 'package:jet_cad_2d_flutter/src/tile_cache.dart' ('lib/src/tile_cache.dart').
  Try correcting the name to the name of an existing setter, or defining a setter or field named 'debugOnSliceForTest'.
      h.cache.debugOnSliceForTest = () {
              ^^^^^^^^^^^^^^^^^^^
  test/invariants/tile_bytes_test.dart:40:31: Error: The setter 'debugOnSliceForTest' isn't defined for the type 'TileCache'.
   - 'TileCache' is from 'package:jet_cad_2d_flutter/src/tile_cache.dart' ('lib/src/tile_cache.dart').
  Try correcting the name to the name of an existing setter, or defining a setter or field named 'debugOnSliceForTest'.
      addTearDown(() => h.cache.debugOnSliceForTest = null);
                                ^^^^^^^^^^^^^^^^^^^
  .
00:00 +0 -2: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_settle_test.dart [E]
  Error: The Dart compiler exited unexpectedly.
  package:flutter_tools/src/base/common.dart 34:3  throwToolExit
  package:flutter_tools/src/compile.dart 1024:11   DefaultResidentCompiler._compile.<fn>
  dart:async/zone_root.dart 48:47                  _rootRunUnary
  dart:async/zone.dart 816:35                      _CustomZone.runUnary
  dart:async/future_impl.dart 948:45               Future._propagateToListeners.handleValueCallback
  dart:async/future_impl.dart 977:13               Future._propagateToListeners
  dart:async/future_impl.dart 862:9                Future._propagateToListeners
  dart:async/future_impl.dart 720:5                Future._completeWithValue
  dart:async/future_impl.dart 804:7                Future._asyncCompleteWithValue.<fn>
  dart:async/zone_root.dart 35:13                  _rootRun
  dart:async/zone.dart 810:35                      _CustomZone.run
  dart:async/zone.dart 702:7                       _CustomZone.runGuarded
  dart:async/zone.dart 743:23                      _CustomZone.bindCallbackGuarded.<fn>
  dart:async/schedule_microtask.dart 40:35         _microtaskLoop
  dart:async/schedule_microtask.dart 49:5          _startMicrotaskLoop
  dart:isolate-patch/isolate_patch.dart 127:13     _runPendingImmediateCallback
  dart:isolate-patch/isolate_patch.dart 193:5      _RawReceivePort._handleMessage
  
00:00 +0 -2: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_settle_test.dart: a frame that left tiles unbaked asks for another
00:00 +1 -2: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_settle_test.dart: the settle finishes, and then stops asking
00:00 +2 -2: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_settle_test.dart: the settle completes in one frame
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
00:00 +2 -3: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_settle_test.dart: the settle completes in one frame [E]
  Test failed. See exception logs above.
  The test description was: the settle completes in one frame
  
00:00 +2 -3: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_settle_test.dart: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_settle_test.dart
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_settle_test.dart: the settle completes in one frame

```

`tile_bytes_test.dart` fails to compile — `debugOnSliceForTest` does not exist
— and `the settle completes in one frame` fails on `viewportCovered`, which is
the tiled fill taking one frame per tile.

## 5. GREEN

Whole package:

```
00:06 +392 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: curves cannot be bypassed a conformal circle is not counted
00:06 +393 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: curves cannot be bypassed the threshold is exclusive, so a circle exactly at 2.0 is not counted
00:06 +394 ~1: All tests passed!
```

The two new tests alone:

```
  test_core 0.6.18 (0.6.19 available)
  vm_service 15.2.0 (15.3.0 available)
Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`!
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_settle_test.dart
00:00 +0: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_settle_test.dart: a frame that left tiles unbaked asks for another
00:00 +1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_settle_test.dart: a frame that left tiles unbaked asks for another
00:00 +2: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart: the ceiling holds at every point inside the rest frame
00:00 +3: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart: the ceiling holds at every point inside the rest frame
00:00 +4: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart: the ceiling holds at every point inside the rest frame
00:00 +5: All tests passed!
```

## 6. Pre-existing tests that changed, and why

Every value below is stated before and after. Nothing was relaxed: two numbers
went **up**, one fixture was **split into two** so that both of its claims keep
the numbers they had, and two setups changed which knob produces the state they
were always about.

### 6.1 `test/tile_cache_test.dart` — `the blit hands drawImageRect the same Paint object every time, not a call-site-local one`

The frame under the `SpyCanvas` is the rest frame after a zoom. It used to
carry one composite blit and four tile blits (a crippled
`bakeBudgetDevicePixels`); the rest bake is not rationed by that field, so it
now carries one composite blit and the whole visible set.

| assertion | before | after |
|---|---|---|
| `zoomed.cache.carryOverBlitCount` | `1` | `1` (unchanged) |
| `zoomed.cache.blitCount` | `4` | `130` |
| `zoomedCalls.length` | `5` | `131` |

The property under test — two distinct `Paint` objects, the composite's first
and every tile's after it, in one frame containing both kinds of blit — is
unchanged and is now made over 130 tile blits instead of 4. The
`bakeBudgetDevicePixels = 4 * 64 * 64` line is kept: it still rations the two
frames *before* the spy's, which is what stops them covering early and retiring
the composite out from under the assertion.

### 6.2 `test/tile_cache_test.dart` — `the settle spreads its bakes across frames` → `the settle spreads its bakes across frames, until it rests`

The loop ran three frames at a four-tile ration. `kRestGateFrames` is two, so
the third of those is now the resting frame and does not ration. The ration
itself is untouched — still four tiles per frame — and the loop now covers the
two frames where it is still the thing that decides.

| assertion | before | after |
|---|---|---|
| loop length | 3 frames | 2 frames |
| `bakeCount` | `12` ("four per frame, three frames") | `8` ("four per frame, two frames") |
| `liveTileCount` | `12` | `8` |
| `hasCarryOver` | `isFalse` | `isFalse` (unchanged) |
| `liveDrawCount` | `3` | `2` |
| — | — | **added:** third frame, `viewportCovered` `isTrue` and `liveTileCount > 8` |

Per-frame ration before: 12/3 = 4. After: 8/2 = 4. The two added assertions are
the new behaviour the removed third frame used to cover, stated as its own
claim so that "the budget throttles" and "the rest frame finishes" are no
longer conflated in one loop.

### 6.3 `test/tile_regime_test.dart` — `a moving frame with no composite falls through and draws something`

Setup only. The test needs a generation that never covers, so that no composite
is ever minted. It produced that with `bakeBudgetDevicePixels = 64 * 64` (one
tile per frame); the rest bake ignores that field, so the ceiling is now what
has to refuse. Added one line:

```dart
h.cache.cacheBytes = 8 * 64 * 64 * 4;
```

Eight tiles cannot hold a thirteen-tile band plus the visible set, so
`_restBake` declines and the one-tile budget goes on bounding the frames it
declines. **No assertion in this test changed** — `hasCarryOver isFalse`,
`viewportCovered isFalse`, and `blitCount + liveDrawCount + carryOverBlitCount
> 0` are all as they were.

### 6.4 `test/invariants/tile_budget_test.dart` — `criterion 12: eviction disposes what it reclaims`

Setup only, second half. The `zoomed` rig ran at the production ceiling, where
the rest bake now covers and therefore drops the composite. Moved to the
ceiling this file already defines for exactly this state:

| | before | after |
|---|---|---|
| rig | `TileRig(64, 1000)` | `TileRig(64, 1000, cacheBytes: _capWithComposite)` |
| `hasCarryOver` | `isTrue` | `isTrue` (unchanged) |
| `debugImagesAlive` | `liveTileCount + 1` | `liveTileCount + 1` (unchanged) |
| — | — | **added:** `liveTileCount > 0`, so the equality is about more than the composite alone |

At 138 tiles of ceiling a band (13 tiles) plus a covering generation (130) does
not fit, `_restBake` declines, the composite stands, and the budgeted loop
fills what is left of the ceiling beside it — which is the same state the
`eviction runs with a composite standing` test in this file exercises, and that
test passes unmodified.

### 6.5 `test/invariants/tile_budget_test.dart` — `criterion 12: a ceiling smaller than the composite bakes nothing rather than overrun it`

**This is the one that could not be repaired by adding a frame, and it is the
one finding a reviewer should look at hardest.** It is reported rather than
quietly adjusted.

The test made two claims over one journey, and that journey passed through a
state that no longer exists: *a composite standing beside a covering
generation*. It is not merely harder to reach — it is arithmetically gone. A
composite is one viewport-sized image, 117 tiles' worth at this fixture; a band
is 13. Any ceiling large enough to hold a covering generation beside a
composite is large enough to hold a band beside one, so at a rest frame the
band bake always runs and always drops the composite first. There is no
`cacheBytes` between the two.

Rather than weaken `greaterThan(30)` or `greaterThan(50)`, the test now runs
its two claims on two rigs, **keeping every number it asserted**:

| assertion | before | after |
|---|---|---|
| **claim one** (`rig`, production ceiling) | | |
| `hasCarryOver` after zoom + settle | `isTrue` | *removed* — the settle now covers and drops it; the claim below never needed a composite |
| `liveTileCount` after zoom + settle | `> 30` | `> 30` (unchanged; it is 130) |
| `cacheBytes` squeeze | `4 * _tileBytes` | `4 * _tileBytes` (unchanged) |
| `evictionCount - beforeSqueeze` | `> 50` | `> 50` (unchanged) |
| **claim two** (`squeezed`, new rig) | | |
| `hasCarryOver` at the squeeze | `isTrue` | `isTrue` (unchanged) — now taken on the *moving* frame, where the composite has just been minted and the incoming generation is still empty |
| `hasCarryOver` after the pan + settle | `isTrue` | `isTrue` (unchanged) |
| `liveBytes` | `_compositeBytes` | `_compositeBytes` (unchanged) |
| `liveTileCount` | `0` | `0` (unchanged) |
| `bakeCount` | `0` | `0` (unchanged) |
| `liveDrawCount` | `1` | `1` (unchanged) |

Claim two is now also a witness for design decision (b) in §2: at four tiles of
ceiling the rest bake refuses band and all, which is why `bakeCount` is still
`0` rather than ten band bakes discarded slice by slice.

**What was lost:** nothing that another test does not assert. The unique
content of the removed `hasCarryOver isTrue` in claim one was "a composite can
stand beside a covering generation", which is the state the design deliberately
removes.

## 7. Mutations

Both were fired by copying `lib/src/tile_cache.dart` aside, editing, running,
and restoring from the copy. **No `git checkout` was used at any point.** Both
are appended verbatim, with output, to
`docs/superpowers/notes/plan-3i-mutation-log.md` beside M1, M4 and M4b.

### M2 — the slice loop emits only the first tile of each band

```diff
--- /private/tmp/claude-501/-Users-ahmeturel-Projects-oss-jet-cad/d5e851c1-248d-41da-b1c1-19632c9b5179/scratchpad/tile_cache.dart.good	2026-08-27 20:39:40
+++ lib/src/tile_cache.dart	2026-08-27 20:39:48
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

Result: **red**, the one-frame settle test.

```
  test 1.31.1 (1.31.2 available)
  test_api 0.7.12 (0.7.13 available)
  test_core 0.6.18 (0.6.19 available)
  vm_service 15.2.0 (15.3.0 available)
Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`!
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
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

### M6 — the band image is never disposed

The brief spells this as deleting `image.dispose();` and the `_imagesAlive--;`
beside it. The shipped code routes both through `_disposeImage`, "the single
door every `ui.Image` this cache owns leaves by", so deleting that one call is
the same mutation — it removes the `dispose()` and the decrement together.

```diff
--- /private/tmp/claude-501/-Users-ahmeturel-Projects-oss-jet-cad/d5e851c1-248d-41da-b1c1-19632c9b5179/scratchpad/tile_cache.dart.good	2026-08-27 20:39:40
+++ lib/src/tile_cache.dart	2026-08-27 20:40:00
@@ -1193,7 +1193,6 @@
         _lastUsedFrame[key] = _frameSerial;
       }
       _band = null;
-      _disposeImage(image);
       _bakes++;
     }
   }
```

Result: **red**, the images-alive assertion. 38 leaked band images — 19 bands
across the two rest frames this test drives.

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

## 8. The gate

`cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && dart format --output=none --set-exit-if-changed .`

```
00:06 +393 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: the corpus draws the same picture twice in a row
00:06 +394 ~1: All tests passed!
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.3s)
Formatted 70 files (0 changed) in 0.14 seconds.
GATE OK (exit=0)
```

The other two gates in the plan's global constraints, unchanged by this task
but run anyway:

```
$ cd packages/jet_cad_2d && CI=true dart test && CI=true dart analyze
00:03 +797: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +797: All tests passed!
Analyzing jet_cad_2d...
No issues found!

$ cd apps/dev_harness_2d && CI=true flutter test && CI=true flutter analyze && dart format --output=none --set-exit-if-changed lib test
00:13 +18: All tests passed!
Analyzing dev_harness_2d...
No issues found! (ran in 1.3s)
Formatted 5 files (0 changed) in 0.01 seconds.
HARNESS OK
```

`git status` before staging shows no `analysis_options.yaml`, and
`packages/jet_cad_2d` is untouched.

## 9. Concerns for the reviewer

1. **§6.5 is the one to check.** A pre-existing fixture's state became
   arithmetically unreachable. It was split rather than relaxed, but a reviewer
   should confirm the split is honest and that claim one really does not need a
   composite.
2. **`debugBakeBand` / `debugSliceTile` doc comments are now stale** — they say
   the wrapped method "has no production caller yet". It does. Left in place
   because Tasks 6 and 7's tests reference the wrappers.
3. **`bakeCount` now mixes units.** `_bakes++` fires once per *band* on the
   rest path and once per *tile* on the budgeted path. The brief specifies it;
   Task 10 reads `invalidationCount` and not this, so nothing downstream is
   affected, but any future assertion on `bakeCount` has to know which path
   produced it.
4. **The band bake bypasses `bakeBudgetDevicePixels` entirely**, by design (the
   spec: "the ration exists *because* tiling made a single tile expensive, and
   removing the tiling is what makes the ration unnecessary"). The field is now
   consulted only on non-resting frames.


---

# Fix round 1 — three Important, one Minor

All four addressed. No assertion was weakened; two were added and two reason
strings were corrected to say what their assertions actually witness.

## Covering test files

| file | covers |
|---|---|
| `packages/jet_cad_2d_flutter/test/invariants/tile_budget_test.dart` | findings 1 and 2 |
| `packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart` | finding 3, and M6b |
| `packages/jet_cad_2d_flutter/test/tile_settle_test.dart` | unchanged, re-run against the amended `_restBake` |
| `packages/jet_cad_2d_flutter/test/tile_cache_test.dart` | unchanged, exercises the amended `carryOverCovers` assert on its zoom-gesture and fallback arms |
| `packages/jet_cad_2d_flutter/test/tile_regime_test.dart` | unchanged, drives the moving/in-between/resting classifier the assert sits behind |

## Finding 1 — claim one's state is now pinned

`tile_budget_test.dart`, `criterion 12: a ceiling smaller than the composite
bakes nothing rather than overrun it`, the `rig` arm. The reviewer is right:
removing `hasCarryOver isTrue` left the mass eviction running in a state
nothing asserted either way. It genuinely has no composite — the settle now
covers the viewport, so `_restBake` released it — and that is now said out
loud rather than left to chance:

```dart
expect(rig.cache.hasCarryOver, isFalse,
    reason: 'setup: the settle covered the viewport, so the rest bake '
        'released the composite -- this claim is about evicting tiles, '
        'and it is measured with no composite in the total');
```

with a comment above it recording that this assertion read `isTrue` before
Task 8, what changed, and where the intersection of "eviction runs" and "a
composite stands" is still covered (the `eviction runs with a composite
standing, and never takes it` test in the same file, which passes unmodified).

**Assertion values:** none changed. One assertion added, `isFalse`, which
passes.

## Finding 2 — claim two's reason strings corrected

The stale phrase was on the `liveBytes` assertion, and the `liveTileCount, 0`
assertion had no reason string at all. Both fixed; **neither assertion
changed**.

| | before | after |
|---|---|---|
| `liveBytes == _compositeBytes` reason | "and it is all the cache holds -- **every tile went**, and the ceiling stayed a ceiling rather than being quietly exceeded" | "and it is all the cache holds -- **nothing was added beside it**, and the ceiling stayed a ceiling rather than being quietly exceeded" |
| `liveTileCount == 0` reason | *(none)* | "the ceiling admitted no tile at all: not one was baked beside the composite, which is what 'bakes nothing rather than overrun' means on a frame whose generation starts empty" |

A comment above the second states the distinction — this arm witnesses a
**refusal to allocate**, not a reclaim, because the ceiling is imposed on the
moving frame where the generation is already empty.

**I agree with the reviewer that no coverage is lost.** The
reclaim-a-populated-cache-down-to-the-composite-alone state is exercised by
`criterion 12: eviction runs with a composite standing, and never takes it`,
which pans six times under `_capWithComposite` and asserts on every pan that
the composite stands, that `liveBytes` is under the ceiling, and that
`liveBytes > _compositeBytes` so tiles really are live beside it — then that
`evictionCount` rose and `debugImagesAlive == liveTileCount + 1`. That is the
reclaim half, at a ceiling where `_restBake` declines and so the state
survives. The two arms are now complementary rather than one being a weakened
copy of the other.

## Finding 3 — `_band` is now observed on the production path

This was the real gap and the reviewer is right that it survived round 1.
Added inside `debugOnSliceForTest`, alongside the existing ceiling:

```dart
expect(h.cache.liveBytes,
    greaterThan(h.cache.liveTileCount * tileBytes),
    reason: 'the band image is in the total, not merely permitted by '
        'it: a rest frame that never assigned _band would read exactly '
        'the tile sum here');
```

with `const tileBytes = 64 * 64 * 4` named from `pumpTiled`'s tile size rather
than left as a literal. **Fired as M6b, and it goes red** — §M6b below and in
`docs/superpowers/notes/plan-3i-mutation-log.md`.

## Minor — `carryOverCovers` measured before the composite may be dropped

The reachability argument is now at the line instead of only in this report,
as prose *and* as an `assert`, so a future change to `_restBake`'s pricing
fails loudly rather than shipping an intermittently blank viewport:

```dart
assert(
    !carryOverCovers || hasCarryOver,
    'a frame that released the composite must have covered the viewport, '
    'or this return leaves neither stale pixels nor a live walk');
if (carryOverCovers) return;
```

The comment above it states the mechanism: `_restBake` releases the composite
only after pricing one band plus **every visible tile** against `cacheBytes`,
and `_makeRoomForOneTile` can then always find room because the only tiles
carrying this frame's serial are ones the same rest bake just cut — so a frame
that dropped the composite is a frame that filled every visible key,
`uncovered` is null, and control took the covered return above without ever
reaching this line.

## Minor — stale doc comments corrected

`debugBakeBand` and `debugSliceTile` both claimed the wrapped private method
had no production caller. Both now open by saying `_restBake` calls it on the
frame path, record that the `unused_element` justification is gone, and state
the reason each wrapper is kept anyway (Task 6's tests check what the band bake
*decides* without rasterising; Task 7's tests slice a band they built
themselves rather than one a whole frame produced).

## M6b — the band image is never assigned to `_band`

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

Red on the new lower bound, on the first slice of the first band, where
`liveTileCount` is still 0 and `liveBytes` reads 0 instead of the resident
band's bytes:

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

The second failure in that transcript is a knock-on and not an independent
signal: the assertion throws out of the slice loop, so `_disposeImage(image)`
never runs and one band image is left alive. Restored from the copy; no
`git checkout`.

## Commands and verbatim output

The five covering files:

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/invariants/tile_bytes_test.dart test/invariants/tile_budget_test.dart test/tile_settle_test.dart test/tile_cache_test.dart test/tile_regime_test.dart
00:00 +50: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: stripFor clamps to the viewport rather than growing past it
00:00 +51: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: stripFor clamps one edge at a time
00:00 +52: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: stripFor a strip touching the bottom-right clamps there and pads inward
00:00 +53: All tests passed!
```

The gate, whole package:

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && dart format --output=none --set-exit-if-changed .
00:06 +393 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_differential_test.dart: the comparison is not vacuous
00:06 +394 ~1: All tests passed!
No issues found! (ran in 1.3s)
Formatted 70 files (0 changed) in 0.13 seconds.
gate exit=0
```

## Concerns after this round

1. **The lower bound is weakest on the call it fires on.** On the first slice
   of the first band `liveTileCount` is 0, so the bound reduces to
   `liveBytes > 0`. It kills M6b there, which is what it is for, but a reader
   should know the strong form of the claim — band bytes on top of a growing
   tile sum — is what the later calls in the same frame check.
2. Nothing else outstanding. The four items in §9 of the round-1 report are now
   two: `bakeCount` mixes units across the two paths, and the band bake bypasses
   `bakeBudgetDevicePixels` by design. The two stale doc comments are fixed.
