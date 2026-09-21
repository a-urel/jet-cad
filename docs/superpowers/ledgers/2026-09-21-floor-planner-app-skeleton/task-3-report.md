# Task 3 report: `CameraGestureDetector` — the desktop trackpad path

## What I implemented

- `packages/jet_cad_2d_flutter/lib/src/camera_gesture_detector.dart` — new
  `CameraGestureDetector` `StatefulWidget`, transcribed verbatim from the
  brief's Step 4. Wraps `child` in a `Listener` wiring only
  `onPointerPanZoomStart` / `onPointerPanZoomUpdate` (opaque hit-test
  behaviour). Tracks `_gestureZoom` (reset on start) and `_gestureAnchor`
  (`event.localPosition` at start); on update, applies `event.localPanDelta`
  via `camera.panBy`, then if `event.scale` is finite, positive, and not
  equal to the running `_gestureZoom`, calls
  `camera.zoomAt(_gestureAnchor, scale / _gestureZoom)` and updates the
  running value. `onPointerSignal` / `onPointerMove` deliberately not added
  (Tasks 4 and 5).
- `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart` — added
  `export 'src/camera_gesture_detector.dart';` immediately before
  `export 'src/canvas_draw_sink.dart';`, as specified.
- `packages/jet_cad_2d_flutter/test/support/gesture_fixture.dart` — new
  shared fixture: `kDetectorSize`, `kDetectorTopLeft`, `kWorldProbe`,
  `kLocalFocus`, `fitOffOrigin()`, `pumpDetector()`, `screenOf()`,
  `globalFocus()`. Transcribed verbatim from the brief's Step 1.
- `packages/jet_cad_2d_flutter/test/camera_gesture_trackpad_test.dart` — new
  test file, transcribed verbatim from the brief's Step 2: 5 tests x 2
  policies (`GesturePolicy.wheelZooms`, `GesturePolicy.wheelPans`) = 10
  tests, covering two-finger scroll (pan-only, delta not cumulative,
  scale-1.0 no-zoom), pinch (cumulative-ratio zoom about the fixed anchor),
  a drifting pinch (pan applied before the zoom, both from one event), a
  second gesture starting from a clean running scale, and no spurious
  notification for an unchanged scale.

Both files' formatting needed `dart format` to pass the format gate (the
brief's transcribed source wrapped a handful of long lines differently than
`dart format` in this workspace does — six lines in the test file, one
signature line in the fixture). No semantic change; see "Issues or concerns"
below.

## TDD evidence

**RED** — `cd packages/jet_cad_2d_flutter && CI=true flutter test test/camera_gesture_trackpad_test.dart`, run after Steps 1–2 (fixture + test file) but before Step 4 (widget):

```
test/support/gesture_fixture.dart:38:14: Error: Method not found: 'CameraGestureDetector'.
      child: CameraGestureDetector(
             ^^^^^^^^^^^^^^^^^^^^^
00:00 +0 -1: loading .../test/camera_gesture_trackpad_test.dart [E]
  Failed to load "...": Compilation failed for testPath=...: test/support/gesture_fixture.dart:38:14: Error: Method not found: 'CameraGestureDetector'.
```

Expected per the brief's Step 3 (compile error, `CameraGestureDetector`
undefined) — matches exactly.

**GREEN** — same command, after Step 4 (widget) + export:

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
```

Re-ran the same focused command after `dart format` reformatted the two new
test files — identical result (10/10 passing).

## Full-suite run

`CI=true flutter test` (with my changes staged, after `dart format`):

```
00:09 +683 ~1 -5: /Users/.../test/tile_measurement_seam_test.dart: debugFullViewportQuery grows the fallback walk to the whole viewport
00:09 +683 ~1 -5: Some tests failed.

Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```

683 pass, 1 skip, 5 fail (the pre-existing golden-pixel-drift failures named
in scope as out of scope) — no other failures.

To confirm this is exactly "baseline + 10" and not a coincidental
cancellation, I set my four new/changed files aside with
`git stash push -u -m "task3-wip-baseline-check" -- <the 4 files>` and reran
the full suite on the untouched tree:

```
00:10 +673 ~1 -5: Some tests failed.
Failing tests: (the same 5 golden tests)
```

Baseline is 673 pass / 1 skip / 5 fail — **not** the brief's stated "667
pass" (a pre-existing drift of +6 tests unrelated to this task; I did not
investigate further since it predates my changes and the task instructions
say to report *other* failures, not baseline-count mismatches). 673 + 10 =
683, matching the run with my changes restored exactly. I then reapplied the
stash (`git stash apply stash@{0}`) and dropped it
(`git stash drop stash@{0}`) — working tree confirmed identical to before the
detour via `git status --short`.

## Gates (final, in `packages/jet_cad_2d_flutter`)

`flutter analyze`:
```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.4s)
```

`dart format --output=none --set-exit-if-changed .`:
```
Formatted 120 files (0 changed) in 0.24 seconds.
```
(exit 0)

`git status --short` before commit — no `analysis_options.yaml` touched:
```
 M packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart
?? packages/jet_cad_2d_flutter/lib/src/camera_gesture_detector.dart
?? packages/jet_cad_2d_flutter/test/camera_gesture_trackpad_test.dart
?? packages/jet_cad_2d_flutter/test/support/gesture_fixture.dart
```

## Files changed

- `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart` (modified, +1 line)
- `packages/jet_cad_2d_flutter/lib/src/camera_gesture_detector.dart` (new)
- `packages/jet_cad_2d_flutter/test/support/gesture_fixture.dart` (new)
- `packages/jet_cad_2d_flutter/test/camera_gesture_trackpad_test.dart` (new)

Commit: `be97169` — "feat(gestures): CameraGestureDetector -- the desktop
trackpad path, pan by delta, zoom by ratio"

## Self-review findings

- Completeness: all of Steps 1–6 done; widget wires only
  `onPointerPanZoomStart`/`Update` (confirmed via `grep` that
  `onPointerSignal`/`onPointerMove` appear only in the doc comment, never
  wired); both `wheelZooms` and `wheelPans` exercised by every test via the
  outer `for` loop; export placed exactly where specified.
- Quality: widget and fixture code is the brief's code verbatim except for
  `dart format`'s own line-wrapping (see below) — no logic changes.
- Discipline: no files created beyond the four specified; nothing outside
  this task's scope touched; `analysis_options.yaml` never modified.
- Testing: RED and GREEN transcripts above are from actual command runs, not
  synthesized. Full-suite and baseline-comparison runs are real, pasted
  output. Stash-based baseline check used `apply` (not `pop`) and the exact
  SHA was captured before dropping, per the shared-stash-stack safety rule.

## Issues or concerns

- **Formatting drift, not a defect**: the brief's Step 1 and Step 2 code
  blocks, transcribed exactly, fail this workspace's
  `dart format --set-exit-if-changed .` gate — six statements in the test
  file (`group(...)`, four `screenToWorld`/`sendEventToBinding` chains) and
  the `fitOffOrigin` signature line in the fixture wrap differently under the
  installed `dart format` than as written in the brief. This is purely
  whitespace/line-break; I ran `dart format` on exactly those two files
  (confirmed via `diff` before/after) and re-ran the focused test to confirm
  no behavioural change, per "Fixing typos and formatting is fine."
- **Baseline test count**: the full package baseline (before this task's
  files) is 673 passing / 1 skipped / 5 failing, not the brief's stated
  "667 pass". This is pre-existing drift from earlier tasks or main, not
  something introduced here — flagging per the report-format instructions,
  since it's an "any other failure" of expectation, even though the actual
  gate (this task's tests are exactly +10, no new failures) is met.
