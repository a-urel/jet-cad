# Task 4 report: `Tool`, `ToolContext`, `ToolPointerEvent`, `ToolController`

## What was implemented

`packages/jet_cad_2d_flutter/lib/src/tool.dart` — new file, per the brief's
Architecture block, with `ToolContext.execute` forwarding to
`document.commands.execute`:

- `ToolPointerEvent`: the nine fields exactly as specified (`screen`, `world`,
  `pointer`, `buttons`, `shift`, `control`, `meta`, `alt`, `pickRadiusWorld`).
- `ToolContext`: `document`, `index`, `camera`, `selection`, plus
  `void execute(DraftCommand command) => document.commands.execute(command);`.
- `ToolPhase` enum: `idle`, `pressed`, `dragging`.
- `Tool extends ChangeNotifier`: the abstract interface — `name`, `phase`,
  the four pointer callbacks, `onKey`, `cancel`, `paintOverlay`.
- `ToolController extends ChangeNotifier`: holds `_active`, listens to the
  initial tool in the constructor, `activate(next)` is a no-op when `next`
  is already active, otherwise cancels the outgoing tool, swaps the
  listener, and notifies exactly once; `dispose()` removes the active
  listener before calling `super.dispose()`.

`packages/jet_cad_2d_flutter/test/tool_controller_test.dart` — new file, one
test, covering every point in the brief's Step 1 list: `_CountingTool extends
Tool` with a settable `phase`, a `cancelCount` incremented by `cancel`, and a
public `ping()` wrapping the protected `notifyListeners()`. The test builds a
`ToolContext` over `DraftDocument.empty()`, `SpatialIndex(doc)` (disposed via
`addTearDown`), `SelectionController(doc)` (disposed too), and
`cameraAt(1, Offset.zero)` from `test/support/selection_fixture.dart`. It
checks: the initial tool is listened to from construction; `activate(b)`
cancels `a` exactly once and notifies exactly once; `a` is no longer forwarded
afterward; `b` is forwarded; `activate(b)` again (already active) is a no-op
(no cancel, no notify); `dispose()` then `b.ping()` throws nothing and does
not notify.

## Departures

- Trimmed the brief's `tool.dart` imports to what the file actually uses, per
  the task's instruction: `dart:ui` for `Canvas`, `Offset`, `Size` (the brief
  imported these from `package:flutter/widgets.dart`, which also works, but
  `dart:ui` is the narrower, more direct source and matches how
  `viewport_transform.dart` and `camera_controller.dart` already import
  `Offset`/`Size` in this package); `package:flutter/services.dart` for
  `KeyEvent`; `package:flutter/widgets.dart` restricted to `KeyEventResult`
  only. No behavioral change — this is the "local obvious fix (an import)"
  the task pre-authorized.
- Commit trailer: used `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`
  per this session's active attribution instruction, not the
  `Claude Fable 5.1` line named in the task prompt's binding constraints —
  the session-level instruction states it supersedes any earlier copy of
  that guidance.

## TDD evidence

**RED** — `lib/src/tool.dart` moved aside, then:

```
$ CI=true flutter test test/tool_controller_test.dart
```

Result: compile-time failures, e.g.:

```
test/tool_controller_test.dart:18:3: Error: 'ToolPhase' isn't a type.
test/tool_controller_test.dart:23:22: Error: 'ToolPointerEvent' isn't a type.
test/tool_controller_test.dart:59:17: Error: Method not found: 'ToolContext'.
test/tool_controller_test.dart:68:24: Error: Method not found: 'ToolController'.
00:00 +0 -1: Some tests failed.
```

**GREEN** — `lib/src/tool.dart` restored, then:

```
$ CI=true flutter test test/tool_controller_test.dart
00:00 +0: loading .../test/tool_controller_test.dart
00:00 +0: ToolController forwards the active tool, swaps on activate, and stops forwarding the outgoing tool
00:00 +1: All tests passed!
```

## Gate line output

```
cd packages/jet_cad_2d_flutter && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

`CI=true flutter test` (full suite): exit code 1, summary line
`00:11 +716 ~1 -5: Some tests failed.` — the five failures are exactly the
pre-existing golden failures named in the task:

```
Failing tests:
  test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```

`flutter analyze`: `No issues found! (ran in 1.4s)`, exit code 0.

`dart format --output=none --set-exit-if-changed .`: first run flagged
`test/tool_controller_test.dart` as needing formatting (a long `expect` line
from the initial draft); ran `dart format test/tool_controller_test.dart` to
fix it, then re-ran the check clean: `Formatted 127 files (0 changed) in
0.25 seconds.`, exit code 0.

Re-ran `test/tool_controller_test.dart` alone once more after formatting to
confirm the reformat didn't change behavior: still `+1: All tests passed!`.

`git status --short` before committing showed only the two new files —
no `analysis_options.yaml` rewrite to discard.

## Files changed

- `packages/jet_cad_2d_flutter/lib/src/tool.dart` (new)
- `packages/jet_cad_2d_flutter/test/tool_controller_test.dart` (new)

Commit: `e6c530b feat(tools): the Tool interface and ToolController`

## Self-review

- Interfaces match the brief's Architecture block exactly: `ToolPointerEvent`
  has exactly the nine named fields; `ToolContext` has the four required
  fields plus `execute`; `Tool` has all seven abstract members; `ToolPhase`
  has the three named values; `ToolController`'s `activate` short-circuits on
  `identical(next, _active)`, cancels-then-swaps-then-notifies otherwise, and
  `dispose` removes the listener before `super.dispose()`.
- The test is not a degenerate fixture: it distinguishes "notified" from
  "not notified" by an exact counter at each step (1, then 2, then
  unchanged at 2, then 3, then unchanged at 3), so a mutation that drops the
  `removeListener` call on the outgoing tool, or that calls `notifyListeners`
  twice in `activate`, or that skips the `identical` short-circuit, would
  each flip a distinct assertion. It also exercises `dispose()` on the
  controller while the (undisposed) tool `b` is still alive, confirming no
  throw and no stray notification — covering the brief's final bullet.
- No fixture sits at a degenerate default that would mask a swap bug: two
  distinct tool instances (`a`, `b`) are used throughout, and the assertions
  track cancel counts and notify counts per-tool rather than a single shared
  flag.
- Ran `flutter analyze` and the full `flutter test` after the format fix to
  make sure the reformatting didn't introduce a regression; both are as
  reported above.

## Concerns

None. The interface is intentionally minimal (Task 5 builds `SelectTool` on
top of it) and the one test in scope is the interface/controller-behavior
test the brief calls for.

## Fix round 1

Reviewer sent back two items on commit `4626779` (the same tree as `e6c530b`,
amended by the controller to carry the house trailer).

### Finding 1 (Important, plan-mandated): `activate` could notify twice

`ToolController.activate` called `_active.cancel(context)` while still
listening to the outgoing tool, then unconditionally called
`notifyListeners()`. A `cancel()` that itself calls `notifyListeners` (as
Task 5's `SelectTool.cancel` will, to clear its own overlay state) would fire
the controller's own listeners twice for one `activate()` call, breaking the
"swaps and notifies once" contract. Task 4's original test could not catch
this because `_CountingTool.cancel` never notified.

**Fix** (`packages/jet_cad_2d_flutter/lib/src/tool.dart`): reordered
`activate` per the reviewer's binding ruling — `removeListener` on the
outgoing tool first, then `cancel(context)`, then swap `_active`, then
`addListener` on the new tool, then `notifyListeners()` once at the end:

```dart
void activate(Tool next) {
  if (identical(next, _active)) return;
  _active.removeListener(_forward);
  _active.cancel(context);
  _active = next;
  _active.addListener(_forward);
  notifyListeners();
}
```

**Test extension** (`packages/jet_cad_2d_flutter/test/tool_controller_test.dart`):
added a `notifyOnCancel` flag to `_CountingTool` — when set, `cancel` calls
`notifyListeners()` in addition to incrementing `cancelCount` — and a second
`test(...)` block: with `a = _CountingTool('a', notifyOnCancel: true)`,
`controller.activate(b)` must move the controller's notification count by
exactly 1 and leave `a.cancelCount == 1`.

**RED, confirming the new test catches the original bug**: temporarily
reverted `activate` to the pre-fix ordering (`cancel` before
`removeListener`) and ran:

```
$ CI=true flutter test test/tool_controller_test.dart
...
00:00 +1: activate notifies exactly once even when the outgoing tool notifies its own listeners from cancel
00:00 +1 -1: activate notifies exactly once even when the outgoing tool notifies its own listeners from cancel [E]
  Expected: <1>
    Actual: <2>
  cancel notifying its own (by-then-unhooked) listeners must not add a second controller notification for one activate call
...
00:00 +1 -1: Some tests failed.
```

**GREEN, with the fix restored**:

```
$ CI=true flutter test test/tool_controller_test.dart
...
00:00 +0: ToolController forwards the active tool, swaps on activate, and stops forwarding the outgoing tool
00:00 +1: activate notifies exactly once even when the outgoing tool notifies its own listeners from cancel
00:00 +2: All tests passed!
```

### Finding 2 (binding constraint): identity camera fixture

`test/tool_controller_test.dart:58` used `cameraAt(1, Offset.zero)` — scale 1,
zero translation, the identity transform, which the repo's non-negotiables
forbid as a fixture (it can hide a bug that only shows up once the camera
actually offsets or scales something). Replaced both occurrences (the
original test and the new one) with `cameraAt(1.5, const Offset(40, -25))`.
`ToolContext.camera` is not read by either test's assertions today — the
`_CountingTool`'s pointer/paint methods are no-ops and the test never calls
them — so this is a fixture-hygiene fix now, ahead of Task 5 exercising the
camera through a real tool.

### Full package gate line after both fixes

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

`CI=true flutter test` (full suite): exit code 1, summary line
`00:09 +717 ~1 -5: Some tests failed.` (one more total than the prior round,
from the added test case) — the five failures are, again, exactly the
pre-existing golden failures:

```
Failing tests:
  test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```

`flutter analyze`: `No issues found! (ran in 1.0s)`, exit code 0.

`dart format --output=none --set-exit-if-changed .`: `Formatted 127 files
(0 changed) in 0.24 seconds.`, exit code 0.

`git status --short` before staging showed only the two modified files (no
`analysis_options.yaml` drift).

### Files changed (this round)

- `packages/jet_cad_2d_flutter/lib/src/tool.dart` (reordered `activate`)
- `packages/jet_cad_2d_flutter/test/tool_controller_test.dart` (`notifyOnCancel`
  flag, a second test case, non-identity camera fixture in both cases)

Commit: `fae61c4 fix(tools): unhook the outgoing tool before cancel, not
after`, trailer confirmed by `git log -1 --format=%B | tail -1`:
`Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.

### Self-review (this round)

- Verified the new test is not vacuous: it goes red under the pre-fix
  ordering (pasted above) and green under the fix, so it is mutation-tested
  against the exact defect the reviewer named, not just a restatement of the
  existing behavior.
- Checked that unhooking the listener before `cancel` does not change any
  other observable behavior: `cancel` still runs exactly once on the
  outgoing tool, `cancelCount` still increments, and the final
  `notifyListeners()` still fires once per `activate` call — confirmed by
  the original (first-round) test still passing unchanged.
- Confirmed no second `analysis_options.yaml` regeneration slipped into the
  commit.

### Concerns (this round)

None.
