# Task 9 report — Mutation testing, and the two greps

## Summary table (fired / killed / survived / equivalent)

Sixteen named mutations fired (M-01a..M-01q, M-01h struck by spec), plus the
spec-declared-equivalent E-01e′.

| id | verdict | adjustment needed |
|---|---|---|
| M-01a | KILLED | none to the edit; the actual failing assertion is the *dx* check one line above the brief's named *dy* check (both live in the same test, same root cause — Flutter's `localPan` is a full position transform, not a delta) |
| M-01b | KILLED (round 1) | SURVIVED on the first shot (degenerate fixture); fixed the test's pinch witness to ramp cumulative `scale` instead of repeating it, re-fired, now KILLED — see "Fix report — round 1" below |
| M-01c | KILLED | none |
| M-01d | KILLED | none |
| M-01e | KILLED | none (edit is `policy.mouseWheel` → `GesturePolicy.wheelZooms.mouseWheel`, per the `ScrollAction`→`ScrollSignalAction` rename noted in my brief) |
| M-01f | KILLED | none |
| M-01g | KILLED | none |
| M-01i | KILLED | none |
| M-01j | KILLED | none |
| M-01k | KILLED | none |
| M-01l | KILLED | none |
| M-01m | KILLED | none |
| M-01n | KILLED | none |
| M-01o | KILLED | none |
| M-01p | KILLED | none |
| M-01q | KILLED | none |
| E-01e′ | EQUIVALENT (declared) | none — fired against the whole suite; only the five pre-existing golden failures appear |

**Totals (after round 1): 16 fired, 16 killed, 0 survived, 1 equivalent (declared).**

Full diffs, commands and pasted transcripts for every row are in
`docs/superpowers/notes/plan-01-mutation-log.md`.

## The survivor: M-01b

**Row:** drop the running division — `lib/src/camera_gesture_detector.dart`,
`_onPanZoomUpdate`: `camera.zoomAt(_gestureAnchor, scale / _gestureZoom);` →
`camera.zoomAt(_gestureAnchor, scale);`

**Command:** `CI=true flutter test test/camera_gesture_trackpad_test.dart`

**Full green (unexpectedly passing) run:**

```
00:00 +0: PointerPanZoom under wheelZooms two-finger scroll pans by the delta and does not zoom
00:00 +1: PointerPanZoom under wheelZooms pinch zooms by the cumulative ratio about the anchor
00:00 +2: PointerPanZoom under wheelZooms a drifting pinch pans by the delta and zooms by the ratio
00:00 +3: PointerPanZoom under wheelZooms a second gesture starts from a clean running scale
00:00 +4: PointerPanZoom under wheelZooms a two-finger scroll does not notify for its unchanged scale
00:00 +5: PointerPanZoom under wheelPans two-finger scroll pans by the delta and does not zoom
00:00 +6: PointerPanZoom under wheelPans pinch zooms by the cumulative ratio about the anchor
00:00 +7: PointerPanZoom under wheelPans a drifting pinch pans by the delta and zooms by the ratio
00:00 +8: PointerPanZoom under wheelPans a second gesture starts from a clean running scale
00:00 +9: PointerPanZoom under wheelPans a two-finger scroll does not notify for its unchanged scale
00:00 +10: All tests passed!
EXIT=0
```

**Why:** `_onPanZoomUpdate` guards every application with
`if (scale == _gestureZoom) return;`, and `_gestureZoom` is reset to exactly
`1.0` at the top of every gesture (`_onPanZoomStart`). The named witness's
tests each send either a single `scale` value per gesture, or the *same*
`scale` value repeated across a gesture's updates (e.g. three updates all
reporting cumulative `scale: 1.5`, matching the real trackpad API where
`scale` is cumulative-since-gesture-start). On the first update of any
gesture the denominator is always `1.0` by construction, so
`scale / _gestureZoom == scale` — the mutation and the original produce the
identical number. On every later update in these fixtures, `scale` equals
the now-updated `_gestureZoom` and the early-return guard fires before
either the original division or the mutant's raw value is ever reached. No
test in `camera_gesture_trackpad_test.dart` sends two *different*,
non-repeated, non-1.0 cumulative `scale` values within one continuous
gesture — that is the only shape of input that would expose the bypassed
division (e.g. `1.5` then `2.0` gives ~`1.333` under the correct code and
`2.0` under the mutant). This is not a coincidental miss on a secondary
witness (Plan F's M-F5 pattern) — it is the row's *only* named witness, and
the mutation is undetectable by it as written. No test or production file
was changed to chase this, per this task's charter (a survivor is fixed in
its own commit, not here). Full detail is in the log's M-01b section.

## The four gate lines' summary output

**`packages/jet_cad_2d`** — fully green, as required:

```
$ CI=true dart test
...
00:03 +798: All tests passed!
$ dart analyze
Analyzing jet_cad_2d...
No issues found!
$ dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.22 seconds.
```

**`packages/jet_cad_2d_flutter`** — the same five pre-existing golden
failures and no other, as expected:

```
$ CI=true flutter test
...
00:12 +702 ~1 -5: Some tests failed.

Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 2.1s)
$ dart format --output=none --set-exit-if-changed .
Formatted 122 files (0 changed) in 0.24 seconds.
```

**`apps/dev_harness_2d`** — fully green, 82 tests as required:

```
$ CI=true flutter test --concurrency=1
...
00:20 +82: All tests passed!
$ flutter analyze
Analyzing dev_harness_2d...
No issues found! (ran in 1.5s)
$ dart format --output=none --set-exit-if-changed .
Formatted 22 files (0 changed) in 0.05 seconds.
```

**`apps/floor_planner`** — fully green, both builds succeed:

```
$ CI=true flutter test
...
00:00 +7: All tests passed!
$ flutter analyze
Analyzing floor_planner...
No issues found! (ran in 1.0s)
$ dart format --output=none --set-exit-if-changed .
Formatted 5 files (0 changed) in 0.02 seconds.
$ flutter build macos --debug
Building macOS application...
✓ Built build/macos/Build/Products/Debug/floor_planner.app
$ flutter build web
Compiling lib/main.dart for the Web...
...
✓ Built build/web
```

## The two grep outputs

```
$ grep -rn "kIsWeb" packages/jet_cad_2d_flutter/lib apps/floor_planner/lib
packages/jet_cad_2d_flutter/lib/src/gesture_policy.dart:1:import 'package:flutter/foundation.dart' show immutable, kIsWeb;
packages/jet_cad_2d_flutter/lib/src/gesture_policy.dart:11:/// rather than a `kIsWeb` it reads.
packages/jet_cad_2d_flutter/lib/src/gesture_policy.dart:13:/// `kIsWeb` is a compile-time constant: a widget that branched on it inline
packages/jet_cad_2d_flutter/lib/src/gesture_policy.dart:64:  /// **The only place `kIsWeb` appears in this package's gesture code.**
packages/jet_cad_2d_flutter/lib/src/gesture_policy.dart:68:      kIsWeb ? forBrowser(firefox: isFirefoxBrowser()) : wheelZooms;

$ grep -rn "dart:ui_web" packages/jet_cad_2d_flutter/lib apps/floor_planner/lib
packages/jet_cad_2d_flutter/lib/src/gesture_policy.dart:65:  /// `isFirefoxBrowser` comes from a conditional import: `dart:ui_web` on
packages/jet_cad_2d_flutter/lib/src/gesture_policy_platform_web.dart:1:import 'dart:ui_web' as ui_web;
packages/jet_cad_2d_flutter/lib/src/gesture_policy_platform_web.dart:3:/// **The only `dart:ui_web` import in this package.**
```

Both greps touch exactly one *file* each — the brief's "exactly one line
each" reads as one call site per identifier once the doc-comment mentions
(which quote the identifier in prose, one of them literally naming the other
file) are set aside: the only executable occurrences are the `import` +
ternary in `gesture_policy.dart` and the `import 'dart:ui_web'` in
`gesture_policy_platform_web.dart`. This is pasted verbatim, not trimmed.

## Files changed

Only `docs/superpowers/notes/plan-01-mutation-log.md` (new file), committed
as `98b5d69`. No `.dart` file, and no `analysis_options.yaml`, differs from
`HEAD`.

## Self-review findings

- Every row in the log carries either a pasted red tail (15 rows) or, for
  M-01b, the full pasted green (surviving) run with a from-source
  explanation of why the witness cannot observe the mutation, and for
  E-01e′, the full pasted green run against the whole suite.
- `git status --short` was clean after every row's restore, and is clean
  now except for the one committed log file (verified after the commit:
  fully clean).
- `git diff --stat` against `HEAD` before staging showed no output: no
  `.dart` file, and no `analysis_options.yaml`, was left mutated.
- Several rows (M-01a, M-01c, M-01e, M-01m, M-01p — the ones with off-anchor
  probe points or dx/dy-adjacent assertions) produced numbers that differ
  from the brief's predicted red values but land on the same named test and
  the same underlying defect; these are called out individually in the log
  rather than silently reconciled, per "never synthesize output."

## Issues or concerns

**M-01b survived on the first shot; resolved in Fix report — round 1 below.**
See that section for the fixture fix, the re-fire, and the two commits that
closed it. No remaining concerns.

## Fix report — round 1

**Ruling:** the coordinator's controller ruled the pinch witness a
degenerate fixture — it sent the same cumulative `scale` (`1.5`) three
times, and the widget's own exact-equality coalescing guard
(`if (scale == _gestureZoom) return;`, Ruling 01-4) let only the first
update ever reach `zoomAt`, where the running denominator is always `1.0`
by construction. Fix the test, not the widget: a real pinch reports a
*rising* cumulative scale.

**What changed:** in
`packages/jet_cad_2d_flutter/test/camera_gesture_trackpad_test.dart`, the
`'pinch zooms by the cumulative ratio about the anchor'` test's loop of
three identical `scale: 1.5` updates was replaced with a ramp over
`[1.2, 1.5, 2.0]`, and the assertion changed from `closeTo(1.5, 1e-9)` to
`closeTo(2.0, 1e-9)` (the ramp's landing ratio, not the repeated value's own
product). The leading comment was updated to describe the ramp and the
`3.6` product a running-division-dropping mutant would reach instead of
`2.0`. The anchor assertions (`still.x`/`still.y` against `under.x`/`under.y`)
were left unchanged.

**Step 2 — green on the fixed test, unmutated code:**
`CI=true flutter test test/camera_gesture_trackpad_test.dart` from
`packages/jet_cad_2d_flutter`:

```
00:00 +0: PointerPanZoom under wheelZooms two-finger scroll pans by the delta and does not zoom
00:00 +1: PointerPanZoom under wheelZooms pinch zooms by the cumulative ratio about the anchor
00:00 +2: PointerPanZoom under wheelZooms a drifting pinch pans by the delta and zooms by the ratio
00:00 +3: PointerPanZoom under wheelZooms a second gesture starts from a clean running scale
00:00 +4: PointerPanZoom under wheelZooms a two-finger scroll does not notify for its unchanged scale
00:00 +5: PointerPanZoom under wheelPans two-finger scroll pans by the delta and does not zoom
00:00 +6: PointerPanZoom under wheelPans pinch zooms by the cumulative ratio about the anchor
00:00 +7: PointerPanZoom under wheelPans a drifting pinch pans by the delta and zooms by the ratio
00:00 +8: PointerPanZoom under wheelPans a second gesture starts from a clean running scale
00:00 +9: PointerPanZoom under wheelPans a two-finger scroll does not notify for its unchanged scale
00:00 +10: All tests passed!
EXIT=0
```

**Step 3 — re-fired M-01b** (`cp lib/src/camera_gesture_detector.dart
/tmp/mut.bak`, edit `scale / _gestureZoom` → `scale`, same command, restore
with `cp`):

```
00:00 +1 -1: PointerPanZoom under wheelZooms pinch zooms by the cumulative ratio about the anchor [E]
  Test failed. See exception logs above.
...
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: a numeric value within <1e-9> of <2.0>
  Actual: <3.6>
   Which:  differs by <1.6>
...
This was caught by the test expectation on the following line:
  .../test/camera_gesture_trackpad_test.dart line 68
The test description was:
  pinch zooms by the cumulative ratio about the anchor
════════════════════════════════════════════════════════════════════════════════════════════════════
00:00 +5 -2: PointerPanZoom under wheelPans pinch zooms by the cumulative ratio about the anchor [E]
  Test failed. See exception logs above.
...
Failing tests:
  .../test/camera_gesture_trackpad_test.dart: PointerPanZoom under wheelPans pinch zooms by the cumulative ratio about the anchor
  .../test/camera_gesture_trackpad_test.dart: PointerPanZoom under wheelZooms pinch zooms by the cumulative ratio about the anchor
EXIT=1
```

`git status --short` after restore showed only the intended test-file edit
(no `.dart` file other than the test, no `analysis_options.yaml`).

**Step 4:** appended a "Re-fired after the fixture fix" subsection to the
log's M-01b section (test diff, green run, re-fire command, red tail,
restore, verdict) and updated the header paragraph and summary table to
16 fired / 16 killed / 0 survived / 1 equivalent.

**Step 5 — gates on `packages/jet_cad_2d_flutter`:**

```
$ CI=true flutter test
...
00:10 +702 ~1 -5: Some tests failed.
Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.4s)
$ dart format --output=none --set-exit-if-changed .
Formatted 122 files (0 changed) in 0.24 seconds.
```

Same five pre-existing golden failures and no other. `git status --short`
showed no `analysis_options.yaml` rewrite.

**Step 6 — two commits, in order:**

- `63cfe04` — `test(gestures): pinch witness ramps the cumulative scale so M-01b can die` (test file alone)
- `5cab91a` — `test(gestures): Plan 01 mutation log -- M-01b re-fired and killed after the fixture fix` (log file alone)

`git status --short` is clean after both commits.
