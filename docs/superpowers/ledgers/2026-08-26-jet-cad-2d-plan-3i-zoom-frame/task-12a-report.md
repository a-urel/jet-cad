# Task 12a — report

**Status: DONE_WITH_CONCERNS.**

Commits, both on `main`, both green on their own:

- `2f90f15` — `feat(tiles): runtime seams for criterion 4's and criterion 8's interleaved arms`
- `50445e4` — `test(harness): runInterleaved alternates whole arms, never blocks them`

Baseline was `0cca785`; the tree was clean at that commit when this task
started and is clean at `50445e4` now.

No measurement number was produced, no `flutter run` was executed, and
`packages/jet_cad_2d` was not touched. The wiring of `runInterleaved` into
`main.dart` is **deliberately left to the device half**, per the brief: the
two arms' bodies do not exist yet, and a driver whose callbacks are not
written would be untested code on the run path.

---

## What changed, and where

### `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`

Two public mutable fields, both defaulting to `false`, each with a doc comment
at the depth this file uses.

**`debugRestBakeDisabled`** — placed immediately after `debugRestGateSteps`,
which is the state it modifies, following the file's convention of putting a
debug member next to what it describes. The gate at what is now line 1055:

```dart
    if (_restGateSteps >= kRestGateFrames && !debugRestBakeDisabled) {
      _restBake(grid, quantised, viewport, painter, sink, vertices, origin);
    }
```

**`debugFullViewportQuery`** — placed immediately after `debugLastStrip` /
`_lastStrip`, which is the state it modifies. The query at what is now line
1147:

```dart
    final strip = debugFullViewportQuery
        ? Offset.zero & viewport
        : stripFor(uncovered, viewport);
    _lastStrip = strip;
```

The `canvas.clipRect(uncovered, doAntiAlias: false)` on the line above is
untouched, and the doc comment says why in as many words.

### `packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart` (new)

Three tests. See "Which test file, and why" below.

### `docs/superpowers/notes/plan-3i-mutation-log.md`

M13 and M14 appended, in the format M1–M12 use: task, why the mutant, the
diff, the procedure, the result, the verbatim output, the verified restore.
M14's entry also names one thing it does **not** gate.

### `apps/dev_harness_2d/lib/measurement_rig.dart`

`runInterleaved` appended at the end of the file, at the pinned signature,
unchanged. Nine lines of body, twenty-odd of doc comment.

### `apps/dev_harness_2d/test/interleaved_arms_test.dart` (new)

Three tests on the call *sequence*.

---

## The two flags' rationale

Both flags exist for the same structural reason and it is worth stating once:
**a criterion that is defined as a ratio between two arms run interleaved in
one session cannot be measured unless one binary can be both arms.** Two
binaries can each hold one arm, but they cannot alternate, and a blocked
ordering puts all of the session's drift on whichever arm ran last. Plan 3h's
own results file records that happening — its M4 arm ran last, in a visibly
noisier session, on a phase M4 is inert on, so the arm ordering and not the
mutation moved the numbers. That is the bias Tasks 12 and 13 exist to remove,
and it is removable only with a runtime switch per criterion.

**`debugRestBakeDisabled` (criterion 4).** The denominator arm of criterion
4's ratio is not a configuration of the rest bake — it is *this cache before
the rest bake landed*, an earlier revision of `paintFrame`. There is no
existing knob that reaches it: `bakeBudgetDevicePixels` rations the per-tile
path but the rest bake is not rationed by it (that is precisely why
`tile_regime_test.dart` had to add `cacheBytes` alongside the budget in Task
8), and `cacheBytes` reaches the arm only by starving it, which changes
eviction behaviour as well. So a flag, or a rig that reimplements the
per-tile arm for itself — and the second option is the mistake Plan 3g made
with `_probeBake`, publishing an overdraw column that described the rig
instead of the code that ships. It is not a correctness switch: both paths
walk the same painter over the same scene into the same tile lattice; only
how many frames coverage takes changes, and that is the quantity criterion 4
scores. Measured in the test below: one resting frame slices all 130 tiles;
with the flag set the same viewport is covered by the budgeted path in 130
per-tile bakes across several frames.

**`debugFullViewportQuery` (criterion 8).** This one ships a known defect
behind a flag, which the doc comment says plainly. It reproduces Plan 3h's
mutant M4 — `plan-3h-mutation-log.md` §"M4 — narrow the clip but not the
query" — by handing the fallback's query the whole viewport while leaving the
clip narrow. The clip is the load-bearing half of that definition: M5, in the
same log, arrives at the same end state from the other direction, and a flag
that also widened the clip would publish an "M4" arm that is not M4. The
defect is pixel-invisible by construction — the narrow clip discards the
surplus, so every pixel lands correctly and only the amount of geometry
tessellated changes — which is exactly why the gate that kills it counts
triangles rather than pixels.

---

## Which test file, and why

**A new file, `test/tile_measurement_seam_test.dart`.** The brief offered
`tile_regime_test.dart` or a new file. Neither existing file fits both tests,
and splitting them across the two files that fit one each would put half of a
single purpose in each and leave neither able to say why its half is there:

- `tile_regime_test.dart` is about the rest *gate* predicate — four of its
  seven tests are pure-Dart `sameQuantisedCamera` comparisons with no canvas
  at all. `debugFullViewportQuery` has nothing to do with regimes; it is on
  the fallback path.
- `tile_fallback_test.dart` is a pixel-agreement sweep, and its own header
  states, as a deliberate decision, that it names **no symbol** from
  `jet_cad_2d_flutter` because `unused_import` is an error in this package.
  Both flag tests name several.

The new file's header says all of this, and says the thing that actually
justifies grouping them: they are one subject — the measurement seams — and a
reader asking "does the flag actually switch anything" should find both
answers in one place. Mutants M13 and M14 are named in the header so the
mutation log and the tests point at each other.

Nothing was copied out of `support/tile_harness.dart`. The one local helper,
`_restFromEmptyGeneration`, is `settleFromBands` **minus its two promises**,
and its doc comment says why that is the point rather than a shortcut: that
helper asserts `slices == liveTileCount` and `viewportCovered`, which is
exactly the claim `debugRestBakeDisabled` is built to falsify, so a shared
helper cannot both promise the band settle and be the vehicle for proving it
did not happen. The unflagged arm restates the equality at its own call site.
`settle` itself — and therefore the pump bound that has to stay in step with
`kRestGateFrames` — is **called, not copied**, which is what the harness
file's own header warns against duplicating.

### The measured numbers behind the assertions

Read out of the running tests before they were pinned, so no assertion here
is satisfied by a degenerate fixture:

| arm | observable | value |
|---|---|---|
| rest bake, flag off | slices / `liveTileCount` | 130 / 130 |
| rest bake, flag on | slices / bakes / `liveTileCount` | 0 / 260 / 130 |
| fallback, flag off | `debugLastStrip` / triangles | `Rect.fromLTRB(0,0,400,85)` / 60 |
| fallback, flag on | `debugLastStrip` / triangles | `Rect.fromLTRB(0,0,400,300)` / 80 |

The flagged rest arm's `260` bakes is the initial 130-tile fill plus the 130
the budgeted path re-baked after the generation drop — the tiles the band
path was not allowed to cut. That number, together with `viewportCovered ==
true`, is what separates "the bake was suppressed" from "the frame did
nothing", which would also slice zero.

The fallback arm's pan is `Offset(0, 53)` and it was not chosen freely:
`kTriangleBudgetRatio`'s doc comment identifies it as the offset in
`kFallbackOffsets` where the shipped narrowing's tiled/live ratio is *worst*
(0.9375) — the tightest sample in that sweep, so a switch that failed to
widen the walk has the least room to hide there. It is also single-axis, so
`uncovered` stays a genuine strip instead of bounding to the whole viewport
the way a diagonal pan's does.

No assertion reads a flag's own value.

---

## M13 — the rest bake ignores `debugRestBakeDisabled`

Backup to the scratchpad, `cp` restore, `diff` verified empty. **Never `git
checkout`.** Both mutants were fired twice: once before `dart format` touched
the new test file, and again after, because formatting shifted the file by one
line and the first transcripts' stack-trace line numbers would have been stale
in the log. The transcripts below and in the mutation log are the **post-format
ones**, and they match the committed source.

```diff
-    if (_restGateSteps >= kRestGateFrames && !debugRestBakeDisabled) {
+    if (_restGateSteps >= kRestGateFrames) {
       _restBake(grid, quantised, viewport, painter, sink, vertices, origin);
     }
```

`CI=true flutter test test/tile_measurement_seam_test.dart` (the `flutter pub
get` preamble is trimmed; everything from the first `00:00` line is verbatim):

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

Note that the *other* two tests stay green under M13, and that is the design:
the unflagged arm is still true when the switch is gone, so what M13 removes
is the difference between the arms, not the bake. Restore, `diff` empty,
same file re-run:

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart
00:00 +0: the rest bake fires, and debugRestBakeDisabled suppresses it
00:00 +1: debugRestBakeDisabled slices nothing and still covers
00:00 +2: debugFullViewportQuery grows the fallback walk to the whole viewport
00:00 +3: All tests passed!
```

## M14 — the live fallback ignores `debugFullViewportQuery`

```diff
-    final strip = debugFullViewportQuery
-        ? Offset.zero & viewport
-        : stripFor(uncovered, viewport);
+    final strip = stripFor(uncovered, viewport);
     _lastStrip = strip;
```

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

Under M14 the M4 arm collapses onto the narrow arm exactly — same strip, same
60 triangles — which is the 1.00 reading the test refuses. Restore, `diff`
empty, `git status --porcelain` showing only this task's own paths, same file
re-run:

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart
00:00 +0: the rest bake fires, and debugRestBakeDisabled suppresses it
00:00 +1: debugRestBakeDisabled slices nothing and still covers
00:00 +2: debugFullViewportQuery grows the fallback walk to the whole viewport
00:00 +3: All tests passed!
```

---

## The gate — all three packages, at `50445e4`

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test
00:06 +400 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart: the rest bake fires, and debugRestBakeDisabled suppresses it
00:06 +401 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart: debugRestBakeDisabled slices nothing and still covers
00:06 +402 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart: debugFullViewportQuery grows the fallback walk to the whole viewport
00:06 +403 ~1: All tests passed!
$ CI=true flutter analyze
Analyzing jet_cad_2d_flutter...                                 
No issues found! (ran in 1.2s)
$ dart format --output=none --set-exit-if-changed .
Formatted 72 files (0 changed) in 0.13 seconds.
(exit 0)
```

```
$ cd apps/dev_harness_2d && CI=true flutter test --concurrency=1
00:11 +19: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/pointer_zoom_test.dart: a second gesture starts from a clean factor
00:12 +20: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/pointer_zoom_test.dart: mouse wheel still zooms through the signal path
00:14 +21: loading /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/zoom_script_test.dart
00:14 +21: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/zoom_script_test.dart: the pinned script is 40 in, 40 out, at 1.03
00:14 +22: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/zoom_script_test.dart: the focal point is off-centre
00:14 +23: All tests passed!
$ CI=true flutter analyze
Analyzing dev_harness_2d...                                     
No issues found! (ran in 1.0s)
$ dart format --output=none --set-exit-if-changed .
Formatted 9 files (0 changed) in 0.07 seconds.
(exit 0)
```

`--concurrency=1` per the brief's note, so the named files are reported. The
three new tests are visible in the earlier full run of the same command:

```
00:00 +0: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/interleaved_arms_test.dart: three arms alternate, never block
00:00 +1: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/interleaved_arms_test.dart: zero arms calls neither
00:00 +2: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/interleaved_arms_test.dart: each callback is awaited before the next arm starts
```

```
$ cd packages/jet_cad_2d && CI=true dart test
00:03 +796: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:03 +797: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +797: All tests passed!
$ CI=true dart analyze
Analyzing jet_cad_2d...
No issues found!
$ dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.19 seconds.
(exit 0)
```

**Against the brief's baselines at `0cca785`:** `jet_cad_2d` 797 → **797**
(untouched, as required). `jet_cad_2d_flutter` 400 ~1 → **403 ~1** (+3, the
new file; the one skip is pre-existing). `dev_harness_2d` 20 → **23** (+3, the
new file). No regression, no new skip, analyze and format clean in all three.

`git status --porcelain` is empty at `50445e4`. **No `analysis_options.yaml`
was staged or committed** — `git status` was checked before every `git add`,
every `git add` named explicit paths, and `git add -A` was never used.

**Each commit is green on its own.** `2f90f15` touches only
`packages/jet_cad_2d_flutter` and `docs/`; the flutter-package gate above was
run with exactly those changes present, and `apps/dev_harness_2d` depends on
that package rather than the reverse, so its baseline 20 is unaffected by
them. `50445e4` touches only `apps/dev_harness_2d`.

---

## Concerns

1. **`debugLastStrip`'s doc comment is now arithmetically stale, and I left it
   alone deliberately.** It says: "A getter, not a mutable field. `TileCache`
   already carries two mutable test-only fields and the standing bar is that a
   third triggers revisiting the design." This task adds two more public
   mutable fields, which is that bar being crossed twice. Ruling 14 *is* the
   revisit, and a getter genuinely cannot serve here — an arm switch must be
   *written* from outside, and there is no derivable state to read it from —
   but the sentence as written will read to the next person as though nobody
   noticed. I did not edit it because the brief scoped this task to exactly
   two switches and the controller asked for a third finding to be reported
   rather than built. It is a one-sentence fix if you want it.

2. **`M4` and `M5` now mean two different things in two mutation logs.**
   `plan-3i-mutation-log.md` has its own `## M4` and `## M5` (the rest gate at
   one frame, and the sliced tile's `_baked` record) which are unrelated to
   `plan-3h-mutation-log.md`'s M4 and M5 (the query/clip pair). The new flag's
   name, its doc comment and my M14 entry all say "Plan 3h's M4" explicitly
   and M14 calls the collision out in a bolded note, but a reader skimming the
   3i log will meet "M4" twice with two meanings. If criterion 8's arms are
   labelled "M4" in the published results, the results file should say *whose*
   M4.

3. **Nothing gates the clip staying narrow under the flag.** That is what
   makes `debugFullViewportQuery` M4 rather than M5, and it is held by the
   source (the ternary touches only `strip`) and by the doc comment, not by a
   test. A future edit that widened the clip under the flag would keep the new
   test green while publishing an "M4" arm that is not M4. Named in M14's log
   entry rather than hidden. Building a test for it was not in scope.

4. **A third thing the device half will need and which does not exist —
   reported, not built.** `TileCache` has no public way to drop its
   generation. `resetCounters()` zeroes counters and leaves the tiles,
   `_dropGeneration` is private, and the only routes to it are `applyChange`
   or a moved `tables.mutationRevision`. So when `runInterleaved` flips a flag
   between arms, the incoming arm starts over the *outgoing* arm's warm
   generation: criterion 4's per-tile arm would begin with the band arm's 130
   tiles already resident and bake almost nothing, and the ratio would be a
   measurement of cache warmth. The arms therefore need a state reset between
   them, and the honest options are a document mutation the arm bodies perform
   (the trick `settleFromBands` uses — a table edit at an unmoved camera), or
   a new cache/canvas per arm, or a public seam. This is a device-half
   decision with a device-half cost, so I have not chosen one; it is the
   single most likely way for Tasks 12 and 13 to produce a 1.00 that has
   nothing to do with these two switches.

5. **`runInterleaved` is unreferenced in `main.dart`, by instruction.** It
   compiles and is tested as a library function only. `apps/dev_harness_2d`
   does not treat unused top-level functions as errors, so this does not break
   the build; but it will sit unused until the device half wires it, and the
   device half will also need a define to select the interleaved mode
   (`kZoomArms` / `ZOOM_ARMS` drives the plain loop today and was not
   rewired, per the brief).
