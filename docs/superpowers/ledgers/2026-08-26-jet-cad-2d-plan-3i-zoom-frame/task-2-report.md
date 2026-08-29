# Task 2 report: A moving frame draws the composite and nothing else

## What changed

`packages/jet_cad_2d_flutter/lib/src/tile_cache.dart` — `paintFrame` gains a
rest gate: two new private fields (`_lastQuantised`, `_restGateSteps`) and a
public `debugRestGateSteps` getter, plus a `resting` computation right after
`_lastCamera = quantised;` and an early return right after the carry-over
blit block, before the visible-key loop. The brief's code is landed
essentially verbatim, with one substantive deviation, explained below.

`packages/jet_cad_2d_flutter/test/tile_regime_test.dart` — Step 1's test and
harness (`TiledHarness`, `pumpTiled`, `settle`) added verbatim, per the two
pre-flight rulings: `TiledHarness` carries only `cache`, `camera`,
`document` (no `moveOneEntityOntoDisjointTiles`/`kMovableHandle`), and the
getter is `debugRestGateSteps`.

**Deviation from the brief, and why.** The brief's exact guard is
`final resting = _restGateSteps >= 1 && !_viewportCovered;`. Landed literally,
this reddened **36 pre-existing tests** across five files. Two independent
defects, both found by tracing the actual failures rather than assumed:

1. **The very first frame a cache ever paints has `_lastQuantised == null`**,
   so `_restGateSteps` computes to `0` on it — indistinguishable from a
   genuinely moving frame. Gated, a brand-new `TileCache`'s first paint draws
   nothing at all: no bake (gated) and no composite (nothing has ever been
   retired to make one). Every test that does `TileRig(...).paintOnce()` as
   its very first call broke this way (e.g. `tile_cache_test.dart`: "a first
   frame bakes up to its budget and draws the rest live" — expected
   `bakeCount: 3`, got `0`).
2. **`&& !_viewportCovered` also gates a frame whose camera hasn't changed
   but whose generation is already fully covered.** That frame still has to
   run the visible-key loop — every key already holds an image, so baking is
   a no-op, but the loop is also what *blits* those images onto the canvas.
   Gating it skips the blit too, so a repeated call at an unchanged, settled
   camera draws nothing (e.g. "a warm frame bakes nothing and blits the whole
   visible set" — expected `blitCount > 30`, got `0`).

The landed guard is `final resting = previous == null || _restGateSteps >= 1;`
— the first-ever frame is exempted, and the coverage term is dropped (the
loop's own per-tile coverage check already makes baking a no-op once covered,
so nothing needs to gate the loop itself). This does not touch Task 2's own
test: its 8 zoom frames are continuously moving (`_restGateSteps` stays `0`
throughout), so the coverage term was never load-bearing there. The full diff
and reasoning are in the code comment at the guard.

**Ripple in pre-existing tests, fixed rather than left red.** Beyond the two
defects above, introducing the gate genuinely changes behaviour Plan 3i
intends to change: a single pan or zoom followed by one `paintOnce()` no
longer bakes/blits/evicts on that call — it takes a second, camera-unchanged
call to reach the resting state. Nine pre-existing tests in
`tile_budget_test.dart`, `tile_cache_test.dart` and (via the shared
`measureFallbackAgreement` helper in `test/support/tile_comparison.dart`)
`tile_fallback_test.dart` asserted immediate post-pan/zoom effects and needed
a settle call inserted at the point each test's own comment already
described as "the frame that actually bakes." None of these files were in
the brief's stated scope (`tile_cache.dart` + `tile_regime_test.dart` only),
but "the task ends green" runs the whole package, so they had to be brought
forward. Each insertion is commented in place with why. No assertion values
were changed — only extra settle calls were added, and where a test's own
comment already described a two-frame sequence (`tile_cache_test.dart`'s
"criterion 1: a settled frame equals the live frame after a zoom"), a third
frame was added and the comment updated to match.

A previous, uncommitted attempt at this task was found already in the
working tree at the start of this session (visible in `git status`/`git
diff` before any edits). It had the right instinct (the same `previous ==
null` exemption, and a partial start on `tile_budget_test.dart`) but was
incomplete — the full suite was red with 10 failures under it — and it also
carried an unrequested change (`_viewportCovered = false` on doomed-tile
eviction) not needed once the guard above is corrected. That attempt was
discarded (via `Edit`, not `git checkout`, since destructive git commands
were unavailable) and this task was implemented fresh from the brief plus
the corrections above.

## Files touched

- `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart` (the guard)
- `packages/jet_cad_2d_flutter/test/tile_regime_test.dart` (Step 1's test)
- `packages/jet_cad_2d_flutter/test/invariants/tile_budget_test.dart` (settle
  calls, 6 tests)
- `packages/jet_cad_2d_flutter/test/tile_cache_test.dart` (settle calls, 3
  tests)
- `packages/jet_cad_2d_flutter/test/support/tile_comparison.dart` (one settle
  call in `measureFallbackAgreement`, shared by 2 tests in
  `tile_fallback_test.dart`)
- `docs/superpowers/notes/plan-3i-mutation-log.md` (created, M1)

## RED — Step 2 (before the guard existed)

Confirmed at the start of this session's work: the pre-existing WIP's own
recorded RED transcript for the same test (before the guard was added) reads:

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
...
00:00 +4 -1: a moving frame bakes nothing and walks nothing [E]
  Test failed. See exception logs above.
00:00 +4 -1: Some tests failed.
```

(This is the same transcript now recorded as M1 below — see the note there
about why `512` appears rather than the brief's illustrative `8`.) This
session independently re-derived the same failure shape while diagnosing the
brief's literal formula before landing the corrected guard.

## GREEN — Step 4

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_regime_test.dart
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart
00:00 +0: the same camera compares same
00:00 +1: a scale change compares different
00:00 +2: a translation change compares different
00:00 +3: the skew terms are compared too
00:00 +4: a moving frame bakes nothing and walks nothing
00:00 +5: All tests passed!
```

## M1 mutation

**Diff:** deleted, from `paintFrame`:

```dart
    if (!resting) {
      // Nothing else this frame. The composite is already down; a zoom out
      // leaves its ring as background until the gesture ends (spec D3).
      return;
    }
```

leaving `resting` computed but unused.

**Procedure:** copied `tile_cache.dart` to the session scratchpad, edited the
working file in place to delete the block, ran the test, then restored the
working file from the scratchpad copy. `git checkout` was never used (and is
also unavailable to this session — attempted for an unrelated cleanup step
and blocked by the sandbox's classifier).

**Verbatim RED output:**

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

`bakeCount` reads `512` rather than the brief's illustrative "8, one per
frame": with the guard gone, every one of the 8 zoom frames bakes as many
tiles as its budget permits over a viewport this size, not one each — but
the failure mode (baking resumes on a moving frame) is exactly the one the
test is chartered to catch. Restored from the scratchpad copy immediately
after; confirmed green again (`+5: All tests passed!`) before proceeding.

## Full gate

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test
...
00:05 +379 ~1: All tests passed!

$ CI=true flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.4s)

$ dart format --output=none --set-exit-if-changed .
Formatted 67 files (0 changed) in 0.12 seconds.
```

379 tests pass (378 baseline + 1 new). `git status` confirms
`analysis_options.yaml` was not touched by `flutter pub get`.

## Anything surprising

The brief's own file scope (`tile_cache.dart` + `tile_regime_test.dart`
only) undersold the blast radius: landing the gate literally broke 36 tests
across five files, not zero. The two root causes (first-frame gating,
already-covered-frame gating) look like genuine gaps in the brief's exact
code rather than intended behaviour — nothing in "The behaviour" section or
Task 3's note about raising the threshold to 2 anticipates a brand-new cache
painting nothing, or a settled cache going blank on a repeated call at the
same camera. The remaining ripple (pan/zoom loops needing a second,
settling `paintOnce()`) is real and intended — it's the whole point of Plan
3i — and the fix was to bring the affected tests forward to the new
two-frame contract rather than to weaken the gate.

---

# Fix round 1

## Finding addressed

`packages/jet_cad_2d_flutter/lib/src/tile_cache.dart:848` (per the review):
the early return's premise — "the composite is already down" — was never
checked. A moving frame with `_carryOver == null` painted nothing at all.
The reviewer ruled the fix as a third disjunct:

```dart
final resting = previous == null || _carryOver == null || _restGateSteps >= 1;
```

and that a moving frame with no composite falls through to the ordinary
bake-and-live-walk path.

## What changed

- `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart` — landed the ruled
  formula verbatim, and rewrote the comment above the guard to name the
  third condition and the three ways to reach `_carryOver == null` on a
  moving frame (first-ever frame, already exempted; an outgoing generation
  that never covered; and `applyChange`/`_dropGeneration`/`_dropEverything`
  dropping a standing composite before a rested frame). Rewrote the comment
  on the early-return block itself, since its old wording ("the composite is
  already down") was exactly the unchecked premise the review named.
- `packages/jet_cad_2d_flutter/test/tile_regime_test.dart` — added
  `'a moving frame with no composite falls through and draws something'`.
- **Ripple, discovered by running the full suite rather than assumed.**
  The new disjunct makes every *pure pan* fall through unconditionally,
  because a pan never changes scale and so never retires a generation into
  a composite — `_carryOver` is null for the whole life of a pan-only
  history (this is already documented at the top of
  `tile_budget_test.dart`'s "and the destination count is a live reading"
  test: "the two cap tests only pan, so no generation is ever retired and
  `_carryOver` stays null through every assertion they make"). Every
  `settle()` call I had added in fix round 0 to a *pan-only* loop was
  therefore now double-running work that had already stopped being gated,
  which was itself skewing counts (e.g. over-evicting). Removed `settle()`
  from the four pan-only loops it no longer applies to (three tests in
  `tile_budget_test.dart`, one loop in a fourth) and from
  `measureFallbackAgreement` in `test/support/tile_comparison.dart` (also
  pan-only), updating each site's comment to say why. Left `settle()` in
  place everywhere a composite is genuinely standing (from a zoom) — those
  frames are still correctly gated by `_restGateSteps`, unaffected by the
  new disjunct. Also removed the now-unnecessary "moving frame absorber"
  `paintOnce()` I had inserted in `tile_cache_test.dart`'s "the settle
  spreads its bakes across frames": that frame's outgoing generation never
  covered (budget of four tiles), so it has no composite either and now
  falls through on its own — the absorber was making it bake an extra,
  uncounted four tiles.

## Test covering the amended code, and its verbatim output

Command:

```
cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_regime_test.dart
```

Verbatim output:

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart
00:00 +0: the same camera compares same
00:00 +1: a scale change compares different
00:00 +2: a translation change compares different
00:00 +3: the skew terms are compared too
00:00 +4: a moving frame bakes nothing and walks nothing
00:00 +5: a moving frame with no composite falls through and draws something
00:00 +6: All tests passed!
```

**Confirmed non-vacuous.** Before landing the fix, reverted the guard in a
scratch copy to `previous == null || _restGateSteps >= 1` (fix round 0's
formula) and re-ran the same command; the new test dies exactly on its
final assertion:

```
Expected: a value greater than <0>
  Actual: <0>
   Which: is not a value greater than <0>
a moving frame with no composite to show must still draw something -- the ordinary
bake-and-live-walk path -- rather than leave the viewport blank for the length of the gesture
...
00:00 +5 -1: a moving frame with no composite falls through and draws something [E]
  Test failed. See exception logs above.
00:00 +5 -1: Some tests failed.
```

Restored the ruled formula from the scratch copy afterward (never
`git checkout`) and reconfirmed green before proceeding.

## Full package gate

Command and verbatim output:

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test
...
00:06 +380: All tests passed!

$ CI=true flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.2s)

$ dart format --output=none --set-exit-if-changed .
Formatted 67 files (0 changed) in 0.13 seconds.
```

380 tests pass (379 after the initial task + 1 new). `git status` confirms
`analysis_options.yaml` was not touched.

## Files covering the amended code

- `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart` (the guard and its
  comments)
- `packages/jet_cad_2d_flutter/test/tile_regime_test.dart` (the new test)
- `packages/jet_cad_2d_flutter/test/invariants/tile_budget_test.dart`
  (settle-call cleanup, ripple from the new disjunct)
- `packages/jet_cad_2d_flutter/test/tile_cache_test.dart` (settle-call
  cleanup, ripple from the new disjunct)
- `packages/jet_cad_2d_flutter/test/support/tile_comparison.dart`
  (settle-call cleanup in `measureFallbackAgreement`, ripple from the new
  disjunct)
