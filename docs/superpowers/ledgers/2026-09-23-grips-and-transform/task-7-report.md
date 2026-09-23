# Task 7 report: SelectTool press classes, drags, camera listener, keys, cancel paths

Status: DONE_WITH_CONCERNS
Commit: 433fe9c feat(render): SelectTool drags -- press classes, move, rotate, reshape

## What was implemented
- `lib/src/select_tool.dart`: blocks A and B from the brief, used verbatim. Original lines 111–194 (`_bandKeys`, `_everyLeafIn`, `_topmostGroup`) and 238–386 (`_deleteSelection`, `_groupCascade`, `paintOverlay`, `_drawDashedRect`) kept unchanged. `dart format` applied.
  - `enum PressClass`, `pressClass`, `dragKind`, `cursor`, `selectionPreviewTransform`. `bandMode`, `bandScreen` and `bandStart` now answer only for a band.
- `test/support/grip_fixture.dart`: rewritten from the brief. Task 4's section is verbatim; added the rig and the helpers `GripRig`, `gripRig`, `pointerAt`, `pressAndMove`, `release`, `click`, `kGripLayerSize`, `pumpGripLayer`, `globalAt`. `grip_cache_test.dart` and `grip_drag_test.dart` import this file, and both still compile and pass.
- `test/select_tool_test.dart`: the D12 test replaced whole (Ruling 03-21), plus the `DragKind` import.
- `test/select_tool_drag_test.dart`: T1–T17 (no T7) and W1–W3, verbatim from the brief. It contains 19 tests.
- **Not in the brief:** `lib/src/interaction_layer.dart`. W3 could not pass without this change; see "Deviations".

## TDD evidence
RED (before implementation): `CI=true flutter test test/select_tool_drag_test.dart test/select_tool_test.dart` → exit 1. It fails to compile, as the brief predicts:
```
test/select_tool_drag_test.dart:68:33: Error: Undefined name 'PressClass'.
test/select_tool_drag_test.dart:68:21: Error: The getter 'pressClass' isn't defined for the type 'SelectTool'.
test/select_tool_test.dart:239:22: Error: The getter 'dragKind' isn't defined for the type 'SelectTool'.
... (same three errors at every use site)
```

The first GREEN attempt used the brief's code only. `CI=true flutter test test/select_tool_drag_test.dart test/select_tool_test.dart test/interaction_layer_test.dart test/selection_overlay_test.dart` gave:
```
00:00 +40 -1: .../select_tool_drag_test.dart: removing the layer mid-drag cancels byte-identically (M-03ao) [E]
00:00 +61 -1: Some tests failed.
```
The cause was a `FlutterError` assertion: `setState() or markNeedsBuild() called during build`. The call chain was:
1. `ToolController._forward`, called from
2. `SelectTool.cancel`, called from
3. `_InteractionLayerState._release`, called from
4. `_InteractionLayerState.deactivate`.

The listener that asserted belongs to the `ListenableBuilder` that Task 5 put around the `MouseRegion`.

After the `interaction_layer.dart` fix, `CI=true flutter test` on those four files plus `interaction_cursor_test.dart`, `grip_cache_test.dart`, `grip_drag_test.dart` and `outline_cache_test.dart`:
```
00:00 +93: All tests passed!
exit 0
```

## Gate line (jet_cad_2d_flutter)
- `CI=true flutter test`: exit 1. `00:11 +836 ~1 -5: Some tests failed.` The five failures are exactly `test/golden/text_ladder_golden_test.dart` text ladder rungs 1–5 (RenderBackend.canvas), the standing five.
  - 836 = 817 + 19 new drag tests. The D12 test is a replacement, so it adds nothing to the count.
- `flutter analyze`: `No issues found!`, exit 0.
- `dart format --output=none --set-exit-if-changed .`: `Formatted 156 files (0 changed)`, exit 0.
- `git status --short` before the commit showed only the five task files. No `analysis_options.yaml` changed.

## Deviations from the brief
1. **`lib/src/interaction_layer.dart` modified** (file not listed in the brief). This is the smallest change that let W3 pass.
   - **Cause:** `_release()` runs from `deactivate`. Cancelling a live drag makes `SelectTool` notify. `ToolController` then forwards the notification to Task 5's `ListenableBuilder`, which sits inside the subtree being deactivated. By then `deactivateChild` has already detached that subtree from its parent, so `markNeedsBuild` asserts.
   - **Why 02 never hit it:** 02 had no builder under the layer, so the band cancel was fine. This is a latent Task 5 regression that W3 exposes. It would also fire in the app, in debug builds, whenever the planner view is removed mid-drag or mid-press.
   - **Fix:** the state mirrors `tools.active.cursor` into a `ValueNotifier<MouseCursor>` through its own `_onTools` listener. `_release()` sets `_leaving = true` before it cancels, so that listener goes quiet. `activate()` clears `_leaving` and re-syncs the cursor. `didUpdateWidget` moves the listener when `tools` changes, keeping the auto-resubscribe the `ListenableBuilder` used to give. `dispose` removes the listener and disposes the notifier.
   - **Build change:** `build` now uses `ValueListenableBuilder<MouseCursor>` in place of `ListenableBuilder`. It still rebuilds only the `MouseRegion`, and now only when the cursor value actually changes.
   - **Test results:** I1 (`interaction_cursor_test.dart`) and every `interaction_layer_test.dart` test still pass.
   - **Mutation check:** deleting `_leaving = true;` turns W3 red (`removing the layer mid-drag cancels byte-identically (M-03ao) [E]`). The file was restored from a `cp` backup, and `diff` showed no difference.
2. `grip_fixture.dart`: I dropped the brief's first line, the header comment `// test/support/grip_fixture.dart`, which only named the path. The old file had no such line.
3. Formatting only: `dart format` reflowed the brief's blocks. There were no semantic edits.

## Self-review
- The brief's blocks are applied verbatim. The lines that had to stay the same were checked against the pre-change file.
- Spot-check mutants, each restored from a `cp` backup and confirmed with `diff`:
  - Drop `ctx.camera.addListener(_onCamera)`: T14 (M-03ac) goes red.
  - Consume only `KeyDownEvent` during a drag (repeat not consumed): T15 (M-03aa) goes red.
  - Drop `removeListener(_onCamera)` in `_endDrag`, leaking the listener: **survives**, 19/19 green. See concern 2.
- Every new test name carries its mutant ID.

## Concerns
1. **Task 10's M-03ab row needs updating.** Its text still says "replace the `ListenableBuilder(…)`". It should now say to replace the `ValueListenableBuilder<MouseCursor>(…)` with a bare `MouseRegion(cursor: _tool.cursor, …)`. The mutant's intent is unchanged.
2. **Ruling 03-7 overclaims.** It says T14 guards the listener's lifecycle, and it does not. After release, `_onCamera` returns early because `_drag == null`, so a leaked listener changes no observable behaviour. T14's final assertion is therefore not a witness for the leak. A leak mutant needs a listener-count probe, for example a `CameraController` subclass exposing `hasListeners`. Otherwise it is an equivalent mutant that should be logged as such.
3. **New `interaction_layer.dart` branches are not covered by any test.** `didUpdateWidget` (a `tools` swap on the same state) and `activate` (a GlobalKey reparent) are there for parity with the old `ListenableBuilder` behaviour. No test exercises them.
4. **Possible `RangeError` in `_beginDrag`, not tested.** `PressClass.grip` reads `grips.grips[_pressGrip]` at the slop crossing. If a document change rebuilds `GripCache` between the press and the slop crossing, the index could be stale. This is very unlikely under a mouse.

## Files changed
- packages/jet_cad_2d_flutter/lib/src/select_tool.dart
- packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart (deviation 1)
- packages/jet_cad_2d_flutter/test/support/grip_fixture.dart
- packages/jet_cad_2d_flutter/test/select_tool_test.dart
- packages/jet_cad_2d_flutter/test/select_tool_drag_test.dart (new)

---

# Fix round 1

Commit: b7de33a fix(render): SelectTool stale grip at the slop; kill listener mutants

Every mutant below was fired from a `cp` backup, restored from that backup, and confirmed with `diff` (no output, then "restored").

## Important 1: camera-listener leak (T14 extended)
**What changed.**
- File: `test/select_tool_drag_test.dart`, T14.
- After the release and the existing pan check, T14 now starts a second move drag on the moved line's body, at 30% along its new coordinates, and expects `DragKind.move`.
- It then counts `rig.tool` notifications across one `panBy` and expects exactly 1.

**RED.** Mutant: `_endDrag`'s `(_dragCtx ?? ctx).camera.removeListener(_onCamera);` replaced by a comment. Command: `CI=true flutter test test/select_tool_drag_test.dart`.
```
00:00 +12 -1: a camera change mid-drag re-resolves the target from the last screen point (M-03ac) [E]
  Expected: <1>
    Actual: <2>
00:00 +19 -1: Some tests failed.
```

**GREEN.** After restoring, the file passes in full (see the final GREEN below).

## Important 2: centre grip base
**What changed.**
- File: `test/select_tool_drag_test.dart`, the M-03at test.
- The press is now `screenOf(rig.camera, 7300, 3250) + const Offset(3, -4)`: 5 px off the grip, inside `kGripHitPixels`. `to` is that press point plus (−31, 17).
- The expected delta is unchanged: `worldOf(to) − (7300, 3250)`.

**RED.** Mutant: `drag!.base.setValues(ref.grip.x, ref.grip.y);` replaced by `_moveBase(ctx, drag!);`.
```
00:00 +6 -1: a centre grip moves the whole selection from the grip itself (M-03at, Ruling 03-9) [E]
  Expected: a numeric value within <1e-9> of <7280.141123215631>
    Actual: <7278.8260987531585>
00:00 +19 -1: Some tests failed.
```

## Minor 1: `InteractionLayer` lifecycle branches
Two new tests in `test/interaction_cursor_test.dart`. Each uses a bare `ToolController` over a `_CursorTool`, built by a new helper, `_cursorController()`.

**(a) `didUpdateWidget`.**
- The test pumps the layer with controller A, then re-pumps it with controller B.
- Driving B's cursor must show on the layer. Driving A's cursor afterwards must not.
- RED. Mutant: the four statements after `super.didUpdateWidget` deleted.
```
Expected: SystemMouseCursor:<SystemMouseCursor(grabbing)>
  Actual: _DeferringMouseCursor:<defer>
00:00 +1 -1: a layer re-pumped with another ToolController follows the new controller's cursor, not the old one's (didUpdateWidget) [E]
00:00 +2 -1: Some tests failed.
```

**(b) `activate`.**
- The test reparents the layer through a `GlobalKey`, moving it from under `Padding` to under `Align`.
- It asserts the `State` object is identical before and after, which proves this was a reparent and not a rebuild.
- Driving the cursor afterwards must show on the layer.
- RED. Mutant: the whole `activate` override deleted.
```
Expected: SystemMouseCursor:<SystemMouseCursor(move)>
  Actual: _DeferringMouseCursor:<defer>
00:00 +2 -1: a layer reparented through a GlobalKey still follows the cursor (activate unmutes what deactivate muted) [E]
00:00 +2 -1: Some tests failed.
```

## Minor 3: stale grip, box and pick before the slop
**Code change (`lib/src/select_tool.dart`).**
- The `int _pressGrip` field is replaced by `GripRef? _pressRef`, captured at press.
- At the slop crossing, the new `_liveIndexOf(grips, pressRef)` looks the grip up in the current list. A match needs the same key, the same ordinal and an equal `Grip` (exact `==`). If there is no match, the press becomes click-only.
- The found index is the one written to `grips.hot`.
- For the rotation class, a null `grips.box` makes the press click-only.
- New import: `grip_cache.dart show GripCache, GripRef`.

**New test.** "a grip or a box gone between the press and the slop leaves the press a click: no throw, no drag, no command" (`test/select_tool_drag_test.dart`). It has two parts:
1. **Stale grip.**
   - Select line and polyline, then press the line's end grip (ordinal 1).
   - `RemoveEntityCommand(line)`, then `await Future.delayed(Duration.zero)`. The test asserts the cache rebuilt without the line.
   - Cross the slop. Expect phase `pressed`, then release. Expect `undoDepth == 1` (the removal only).
2. **Null box.**
   - Select the circle, then press its rotation grip.
   - Remove the circle and flush. The test asserts `box` is null.
   - Cross the slop. Expect `pressed`, then release. Expect `undoDepth == 2`.

**RED against the pre-fix code (natural).**
- Command: `CI=true flutter test test/select_tool_drag_test.dart`.
- Output:
  ```
  00:00 +16 -1: a grip or a box gone between the press and the slop leaves the press a click: no throw, no drag, no command [E]
    Expected: ToolPhase:<ToolPhase.pressed>
      Actual: ToolPhase:<ToolPhase.dragging>
    the pressed grip is gone: the press stays a click
  00:00 +19 -1: Some tests failed.
  ```
- The stale index 1 named the polyline's vertex 1, so the old code started a reshape of another object.

**RED against the null-box guard.** Mutant: `final box = ctx.grips!.box;` replaced by `ctx.grips!.box!`.
```
00:00 +16 -1: a grip or a box gone between the press and the slop leaves the press a click: no throw, no drag, no command [E]
  Null check operator used on a null value
00:00 +19 -1: Some tests failed.
```

## GREEN
- `CI=true flutter test test/select_tool_drag_test.dart`: `00:00 +20: All tests passed!`
- `CI=true flutter test test/interaction_cursor_test.dart`: `00:00 +3: All tests passed!`

## Gate line (jet_cad_2d_flutter)
- `CI=true flutter test`: exit 1, `00:12 +839 ~1 -5: Some tests failed.`
  - The failures are exactly `test/golden/text_ladder_golden_test.dart` text ladder rungs 1–5 (RenderBackend.canvas).
  - 839 = 836 + 3 new tests: the stale-press test and the two cursor-lifecycle tests.
- `flutter analyze`: `No issues found!`, exit 0.
- `dart format --output=none --set-exit-if-changed .`: `Formatted 156 files (0 changed)`, exit 0.
- `git status --short` before the commit showed only the three changed files. No `analysis_options.yaml` was touched.

## Files changed in this round
- packages/jet_cad_2d_flutter/lib/src/select_tool.dart
- packages/jet_cad_2d_flutter/test/select_tool_drag_test.dart
- packages/jet_cad_2d_flutter/test/interaction_cursor_test.dart

## Remaining concerns
- Task 10's M-03ab row still names `ListenableBuilder` (concern 1 above); it is unchanged by this round.
- The release on a stale click still acts on a stale `_downKey` for a body press. That is 02's existing behaviour, and it was not in scope.
