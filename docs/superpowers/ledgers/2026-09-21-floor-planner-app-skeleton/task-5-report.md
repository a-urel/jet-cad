# Task 5 Report: Buttons, the cross-policy consistency test, and the allocation invariant

## What I implemented

- `packages/jet_cad_2d_flutter/lib/src/camera_gesture_detector.dart`: added
  `_onMove(PointerMoveEvent event)` to `_CameraGestureDetectorState` — a drag
  with a pan button held (`event.buttons & widget.policy.panButtons != 0`)
  pans the camera by `event.delta`; any other button does nothing. Wired
  `onPointerMove: _onMove` into the `Listener` in `build`. Transcribed
  verbatim from the brief's Step 3.
- `packages/jet_cad_2d_flutter/test/camera_gesture_button_test.dart`: new
  file, transcribed verbatim from the brief's Step 1 (then reformatted by
  `dart format`, whitespace only — see below). Covers, for both
  `GesturePolicy.wheelZooms` and `GesturePolicy.wheelPans`:
  - middle-button drag pans by the pointer delta, scale unchanged
  - left-button drag moves nothing
  - right-button drag moves nothing
  - the cross-policy consistency test: a desktop trackpad's `localPanDelta`,
    a Chromium/WebKit trackpad-kind scroll under `wheelZooms`, and a Firefox
    mouse-kind scroll under `wheelPans` all move three independent cameras
    identically.

The widget is now complete per the brief.

## TDD evidence

**RED** — `cd packages/jet_cad_2d_flutter && CI=true flutter test test/camera_gesture_button_test.dart` (before Step 3, widget with no `_onMove`/`onPointerMove`):

```
00:00 +0: middle-button drag pans by the pointer delta under wheelZooms
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════
The following TestFailure was thrown running a test:
Expected: a numeric value within <1e-9> of <33>
  Actual: <0.0>
   Which:  differs by <33.0>
...
00:00 +0 -1: middle-button drag pans by the pointer delta under wheelZooms [E]
00:00 +1 -1: left-button drag moves nothing under wheelZooms
00:00 +2 -1: right-button drag moves nothing under wheelZooms
00:00 +2 -2: middle-button drag pans by the pointer delta under wheelPans [E]
00:00 +3 -2: left-button drag moves nothing under wheelPans
00:00 +4 -2: right-button drag moves nothing under wheelPans
00:00 +5 -2: the three pan arms move the camera identically
00:00 +5 -2: Some tests failed.

Failing tests:
  .../camera_gesture_button_test.dart: middle-button drag pans by the pointer delta under wheelPans
  .../camera_gesture_button_test.dart: middle-button drag pans by the pointer delta under wheelZooms
```

Exactly as the brief predicted: the two middle-button tests fail with the
camera unmoved (0.0 instead of 33.0/‑21.0); the other five pass vacuously
(nothing moved the camera under any button, and the three-arm test doesn't
touch buttons at all).

**GREEN** — after adding `_onMove` and wiring `onPointerMove`:

```
$ CI=true flutter test test/camera_gesture_button_test.dart
00:00 +0: middle-button drag pans by the pointer delta under wheelZooms
00:00 +1: left-button drag moves nothing under wheelZooms
00:00 +2: right-button drag moves nothing under wheelZooms
00:00 +3: middle-button drag pans by the pointer delta under wheelPans
00:00 +4: left-button drag moves nothing under wheelPans
00:00 +5: right-button drag moves nothing under wheelPans
00:00 +6: the three pan arms move the camera identically
00:00 +7: All tests passed!
```

## What I tested and the results (pasted, not synthesized)

### Allocation invariant (Step 4, run on its own)

```
$ CI=true flutter test test/invariants/paint_allocation_test.dart
00:00 +0: loading .../test/invariants/paint_allocation_test.dart
00:00 +0: a steady-state frame allocates O(1) per flush, not O(entities)
00:00 +1: flush hands drawVertices the same Paint object every time, not a call-site-local one
00:00 +2: load-time triangulation cost, recorded
LOAD fills=5000 elapsed=67ms
00:00 +3: All tests passed!
```

As the brief notes, this widget is not on the frame path, so this run is a
record that Task 5 did not move the invariant, not a new exercise of the
widget.

### Full suite

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
```

702 passed, 1 skipped, 5 failed — the 5 failures are exactly the
pre-existing golden-pixel-drift failures in
`test/golden/text_ladder_golden_test.dart` named out of scope in the task
context; no other failure. (The brief's context stated a prior baseline of
689 passing; 702 includes this task's 7 new tests plus whatever the
baseline actually was at HEAD 36711e5 — I did not independently re-derive
689, but confirmed by direct comparison that the only failures present are
the 5 named golden ones and nothing else regressed.)

### Analyze

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.4s)
```

### Format

`dart format --output=none --set-exit-if-changed .` initially reported one
file needing reformatting:

```
Changed test/camera_gesture_button_test.dart
Formatted 122 files (1 changed) in 0.24 seconds.
```

This is whitespace-only reformatting of the brief's transcribed code (two
lines were slightly over the line-length the local `dart format` prefers:
the `final name = ...` ternary and the last `testWidgets(...)` header),
which the task brief explicitly allows. I ran `dart format
test/camera_gesture_button_test.dart` to apply it, re-ran the focused test
(still 7/7 green) and re-ran `flutter analyze` (still clean), then
confirmed:

```
$ dart format --output=none --set-exit-if-changed .
Formatted 122 files (0 changed) in 0.26 seconds.
```

(exit 0)

## Files changed

- `packages/jet_cad_2d_flutter/lib/src/camera_gesture_detector.dart` — added
  `_onMove` and wired `onPointerMove` (11 lines added, brief's code verbatim).
- `packages/jet_cad_2d_flutter/test/camera_gesture_button_test.dart` — new
  file, brief's code verbatim, then reformatted by `dart format`
  (whitespace only, no semantic change).

No `analysis_options.yaml` was rewritten by `flutter test`/`pub get` in this
run; `git status --short` before commit showed only the two files above.

## Self-review

- **Completeness:** all five steps done — failing tests written and run
  (RED confirmed with the exact failure mode the brief predicted), handler
  added, full gates run including the standalone allocation-invariant run,
  committed with the exact Step 5 message plus the required
  co-author trailer.
- **Exact code:** both the widget diff and the test file (pre-format) are
  byte-for-byte the brief's code blocks; the only deviation is
  `dart format`'s whitespace reflow of two over-length lines in the test
  file, explicitly sanctioned by the task instructions.
- **Both policies:** the parametrized `for` loop covers `wheelZooms` and
  `wheelPans` for all three button cases; the cross-policy test itself spans
  both policies by construction (desktop/chromium under `wheelZooms`,
  firefox under `wheelPans`).
- **Discipline:** no other files touched; no restructuring; no extra
  helpers, comments, or exports beyond the brief's.
- **Testing hygiene:** every pasted transcript above came from an actual
  command run in this session, nothing synthesized. The RED run was
  captured before any handler code existed; the GREEN run after.

## Issues or concerns

None. The brief's tests pass exactly as specified against the brief's own
widget code — no discrepancy to report.
