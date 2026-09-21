# Task 4 report: Scroll signals — modifier, then `kind`, then policy; and `PointerScaleEvent`

## What I implemented

- `packages/jet_cad_2d_flutter/lib/src/camera_gesture_detector.dart`: added
  the `_onSignal(PointerSignalEvent event)` handler to
  `_CameraGestureDetectorState`, transcribed from the brief's Step 3 verbatim,
  and wired `onPointerSignal: _onSignal` into the `Listener` in `build`.
  Rule order exactly as specified: `PointerScaleEvent` → `zoomAt(localPosition,
  event.scale)` raw and return; otherwise (for a `PointerScrollEvent`) a held
  Control/Meta modifier zooms; else `kind == trackpad` pans; else
  `policy.mouseWheel` decides.
- `packages/jet_cad_2d_flutter/test/camera_gesture_signal_test.dart`: new
  file, transcribed from the brief's Step 1 verbatim (then reformatted by
  `dart format`, whitespace only — see Deviations).

## Deviation from the brief's literal text (required to compile)

The brief's Step 3 code, pasted as-is into `camera_gesture_detector.dart`,
does not compile:

```
lib/src/camera_gesture_detector.dart:94:11: Error: 'ScrollAction' is imported
from both 'package:flutter/src/widgets/scrollable_helpers.dart' and
'package:jet_cad_2d_flutter/src/gesture_policy.dart'.
```

Diagnosis: `package:flutter/widgets.dart` (imported unrestricted since Task 3)
exports the framework's own `class ScrollAction extends Action<ScrollIntent>`,
defined in `packages/flutter/lib/src/widgets/scrollable_helpers.dart` (Flutter
3.27.3, confirmed by reading that file directly). This is unrelated to and
collides with `GesturePolicy`'s `enum ScrollAction` from `gesture_policy.dart`
(Task 2), which the brief's handler references unqualified
(`ScrollAction.zoom`, `ScrollAction.pan`, and the `switch` cases). Task 3
never referenced `ScrollAction` in this file, so the collision was latent
until this task's code used the symbol.

This is a compile-time symbol-visibility collision, not a disagreement about
behaviour between the test and the widget code, and the fix does not touch
any test assertion or any runtime logic: I narrowed the Flutter import to
hide the unrelated framework class:

```dart
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart' show HardwareKeyboard;
// `widgets.dart` exports its own `ScrollAction` (an `Action<ScrollIntent>`
// for keyboard scrolling), which collides with `GesturePolicy`'s
// `ScrollAction` enum used unqualified below.
import 'package:flutter/widgets.dart' hide ScrollAction;
```

The `_onSignal` method body is otherwise identical, character for character,
to the brief's Step 3 code. Flagging as a self-review finding / concern per
the task instructions rather than treating it as silently in-scope.

## What I tested and the results (pasted, not synthesized)

### TDD — RED

Command:
```
cd packages/jet_cad_2d_flutter && CI=true flutter test test/camera_gesture_signal_test.dart
```

Result (tail): all 12 tests failed with the camera unmoved, matching the
brief's expectation exactly (`closeTo(1.1)` against `1.0`,
`closeTo(1.728)` against `1.0`, etc.):

```
This was caught by the test expectation on the following line:
  .../camera_gesture_signal_test.dart line 129
The test description was:
  Meta Left + mouse scroll zooms about the pointer under wheelPans
════════════════════════════════════════════════════════════════════
00:00 +0 -9: modifier held Meta Left + mouse scroll zooms about the pointer under wheelPans [E]
...
00:00 +0 -10: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) zooms by the event scale about the pointer, compounding, under wheelZooms
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞═════════════════════
The following TestFailure was thrown running a test:
Expected: a numeric value within <1e-9> of <1.728>
  Actual: <1.0>
   Which:  differs by <0.728>
...
00:00 +0 -12: Some tests failed.

Failing tests:
  .../camera_gesture_signal_test.dart: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) a scale below 1 zooms out
  .../camera_gesture_signal_test.dart: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) zooms by the event scale about the pointer, compounding, under wheelPans
  .../camera_gesture_signal_test.dart: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) zooms by the event scale about the pointer, compounding, under wheelZooms
  .../camera_gesture_signal_test.dart: modifier held Control Left + mouse scroll zooms about the pointer under wheelPans
  ... and 8 more
```

All 12 of the brief's tests failed, none passed — RED confirmed before any
implementation code was added.

### TDD — GREEN (after adding the handler, with the import-collision fix)

First attempt (brief's code verbatim, no import fix) failed to *compile*
(the "Deviation" error above) — this is what surfaced the collision.

After the `hide ScrollAction` fix:

Command:
```
cd packages/jet_cad_2d_flutter && CI=true flutter test test/camera_gesture_signal_test.dart
```

Output:
```
00:00 +0: loading .../camera_gesture_signal_test.dart
00:00 +0: mouse-kind scroll, no modifier wheelZooms: zooms 1.1 per notch up about the pointer
00:00 +1: mouse-kind scroll, no modifier wheelZooms: a notch down zooms out by 1/1.1
00:00 +2: mouse-kind scroll, no modifier wheelPans: pans by -scrollDelta and does not zoom
00:00 +3: trackpad-kind scroll (a Chromium/WebKit browser trackpad) pans by -scrollDelta under wheelZooms
00:00 +4: trackpad-kind scroll (a Chromium/WebKit browser trackpad) pans by -scrollDelta under wheelPans
00:00 +5: modifier held Control Left + mouse scroll zooms about the pointer under wheelZooms
00:00 +6: modifier held Control Left + mouse scroll zooms about the pointer under wheelPans
00:00 +7: modifier held Meta Left + mouse scroll zooms about the pointer under wheelZooms
00:00 +8: modifier held Meta Left + mouse scroll zooms about the pointer under wheelPans
00:00 +9: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) zooms by the event scale about the pointer, compounding, under wheelZooms
00:00 +10: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) zooms by the event scale about the pointer, compounding, under wheelPans
00:00 +11: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) a scale below 1 zooms out
00:00 +12: All tests passed!
```

Note on Step 4's named risk: the `HardwareKeyboard.instance.isControlPressed`
/ `isMetaPressed` state under `tester.sendKeyDownEvent` worked correctly in
this SDK (Flutter 3.27.3) — the modifier tests (group "modifier held", 4
tests) passed on the first green run. No switch to `simulateKeyDownEvent`
was needed.

### Full package suite

Command:
```
cd packages/jet_cad_2d_flutter && CI=true flutter test
```

Summary line:
```
00:12 +695 ~1 -5: Some tests failed.

Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```

695 total, 1 skip, exactly the 5 pre-existing golden failures and no other —
matches the expected result stated in the task ("the previous pass count plus
your new tests, 1 skip, those 5 golden failures and no other").

### Analyze

Command:
```
cd packages/jet_cad_2d_flutter && flutter analyze
```

Output:
```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 2.1s)
```

### Format

Command:
```
cd packages/jet_cad_2d_flutter && dart format --output=none --set-exit-if-changed .
```

First run reported `Changed test/camera_gesture_signal_test.dart` (the
brief's Step 1 code needed whitespace-only reformatting, as flagged as
possible in the task instructions — same as Task 3). Ran
`dart format test/camera_gesture_signal_test.dart` to apply it, then:

```
Formatted 121 files (0 changed) in 0.24 seconds.
```

clean, exit 0.

### `analysis_options.yaml`

`git status --short` after `flutter test`/`pub get` runs showed no modified
`analysis_options.yaml` files this run — nothing to restore.

## Files changed

- `packages/jet_cad_2d_flutter/lib/src/camera_gesture_detector.dart` (modified)
- `packages/jet_cad_2d_flutter/test/camera_gesture_signal_test.dart` (new)

## Self-review findings

- Completeness: all four test groups present (mouse-kind no modifier,
  trackpad-kind, modifier held x2 keys x2 policies, `PointerScaleEvent` x2
  policies + below-1 case) — 12 tests total, matching the brief's file
  exactly.
- Quality: `_onSignal` transcribed character-for-character from the brief
  except for the necessary import-collision fix (documented above); no
  `onPointerMove` added (out of scope, Task 5); no other files touched.
  the docstring comment on `_onSignal` transcribed verbatim including the
  cross-platform ctrl/cmd/browser rationale.
  the `switch` uses Dart's non-`break`-needed enum-switch statement form
  exactly as given.
- Discipline: nothing extra added; no restructuring outside the task; the
  only source line not present in the brief's literal text is the one
  import-hide clause plus its explanatory comment.
- Testing: full suite output is pristine aside from the 5 known golden
  failures — no stray key-event warnings or other noise observed in the
  `flutter test` output for the modifier-key tests.

## Issues or concerns

- The `hide ScrollAction` import fix (see Deviation section) was necessary
  for the brief's exact widget code to compile in this Flutter SDK (3.27.3);
  I judged it in-scope because it is a pure symbol-visibility fix with zero
  effect on behaviour or on any test, but flagging it explicitly per the
  task's instruction to report rather than silently change when the brief's
  code doesn't work for a precisely-named reason.

## Fix report — round 1: rename `ScrollAction` to `ScrollSignalAction`

### Finding and ruling

Reviewer finding: the `hide ScrollAction` workaround only fixed the compile
error inside `camera_gesture_detector.dart`; any *consumer* of this package
that imports `material.dart` (or another `widgets.dart`-exporting Flutter
library) alongside `jet_cad_2d_flutter.dart` and writes
`GesturePolicy(mouseWheel: ScrollAction.zoom)` unqualified would hit the same
ambiguous-import error, because `ScrollAction` is part of this package's
public API (exported from `lib/jet_cad_2d_flutter.dart` via
`export 'src/gesture_policy.dart';`).

Controller's ruling: rename the enum `ScrollAction` → `ScrollSignalAction`
throughout the package and drop the `hide ScrollAction` workaround, restoring
the plain `import 'package:flutter/widgets.dart';`.

### What changed

- `lib/src/gesture_policy.dart`: `enum ScrollAction { pan, zoom }` →
  `enum ScrollSignalAction { pan, zoom }`; the `mouseWheel` field's type and
  the `wheelZooms`/`wheelPans` constants' `ScrollAction.zoom`/`.pan`
  arguments updated to `ScrollSignalAction.zoom`/`.pan`. The doc comment
  ("What a bare scroll signal does to the camera.") is unchanged.
- `lib/src/camera_gesture_detector.dart`: dropped
  `import 'package:flutter/widgets.dart' hide ScrollAction;` and its
  explanatory comment, restored to the plain
  `import 'package:flutter/widgets.dart';`; every `ScrollAction.zoom` /
  `ScrollAction.pan` in `_onSignal` (the ternary and both `switch` cases)
  renamed to `ScrollSignalAction.zoom` / `ScrollSignalAction.pan`.
- `test/gesture_policy_test.dart`: both `expect(p.mouseWheel, ScrollAction....)`
  assertions renamed to `ScrollSignalAction....`.
- `test/camera_gesture_signal_test.dart` and
  `test/camera_gesture_trackpad_test.dart`: no occurrences of the bare
  `ScrollAction` identifier existed in either file (they only reference
  `GesturePolicy.wheelZooms` / `GesturePolicy.wheelPans`), so nothing to
  change there; both are covering tests and were run to confirm no
  regression.

Verification: `grep -rn "ScrollAction" packages/jet_cad_2d_flutter/ --include="*.dart"`
now shows zero occurrences of the bare name; `grep -rn "ScrollSignalAction" ...`
shows all ten expected occurrences (2 in `lib/src/gesture_policy.dart`'s
declaration/field/constants... actually 4 there, 4 in the detector, 2 in the
policy test).

### Covering tests — command and pasted output

Command:
```
cd packages/jet_cad_2d_flutter && CI=true flutter test test/gesture_policy_test.dart test/camera_gesture_signal_test.dart test/camera_gesture_trackpad_test.dart
```

Output (tail):
```
00:00 +0: loading .../test/gesture_policy_test.dart
00:00 +0: .../test/gesture_policy_test.dart: wheelZooms: a mouse-kind scroll zooms, 1.1 per notch, middle drag
00:00 +1: .../test/gesture_policy_test.dart: wheelPans: a mouse-kind scroll pans; the rest is the same
00:00 +2: .../test/gesture_policy_test.dart: forBrowser: Firefox gets wheelPans, every other engine wheelZooms
00:00 +3: .../test/gesture_policy_test.dart: forPlatform on the VM is wheelZooms
00:00 +4: .../test/camera_gesture_signal_test.dart: mouse-kind scroll, no modifier wheelZooms: zooms 1.1 per notch up about the pointer
00:00 +5: .../test/camera_gesture_trackpad_test.dart: PointerPanZoom under wheelZooms two-finger scroll pans by the delta and does not zoom
...
00:00 +21: .../test/camera_gesture_signal_test.dart: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) zooms by the event scale about the pointer, compounding, under wheelZooms
00:00 +23: .../test/camera_gesture_signal_test.dart: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) zooms by the event scale about the pointer, compounding, under wheelPans
00:00 +25: .../test/camera_gesture_signal_test.dart: PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux) a scale below 1 zooms out
00:00 +26: All tests passed!
```

All 26 covering tests pass (4 policy + 12 signal + 10 trackpad).

Gates:
```
cd packages/jet_cad_2d_flutter && flutter analyze
```
```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.7s)
```

```
cd packages/jet_cad_2d_flutter && dart format --output=none --set-exit-if-changed .
```
```
Formatted 121 files (0 changed) in 0.24 seconds.
```

Full package suite re-run for regression safety:
```
cd packages/jet_cad_2d_flutter && CI=true flutter test
```
```
00:11 +695 ~1 -5: Some tests failed.

Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```
Unchanged: 695 total, 1 skip, the same 5 pre-existing golden failures, no
other failures, no regression from the rename.

`git status --short` after `flutter test`/`flutter analyze` runs showed no
rewritten `analysis_options.yaml` files this round; nothing to restore.

### Commit

```
36711e5 refactor(gestures): rename ScrollAction to ScrollSignalAction, clear of Flutter's class
```
Files: `lib/src/camera_gesture_detector.dart`, `lib/src/gesture_policy.dart`,
`test/gesture_policy_test.dart` (3 files changed, 11 insertions, 14
deletions).

Spec/plan documents were not edited, per the ruling; this deviation
(`ScrollAction` → `ScrollSignalAction`) is recorded by the controller.
