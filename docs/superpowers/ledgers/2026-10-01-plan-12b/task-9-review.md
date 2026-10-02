# Task 9 review — 8b + LayerPanel (1afcfdd, 7e83eae on 27db262)

Reviewer: independent, in the detached worktree `.claude/worktrees/plan-12b-review` at 7e83eae. Scratch: `scratchpad/r9-12b/`. Every mutant was restored by `cp` and checked with `diff` (exit 0). The two temporary probe tests were copied to scratch and removed from the worktree. `git status --short` was empty after every run, with no analysis_options rewrite left behind.

## Verdict: **Approved with notes**

The panel meets D9, D10 and D11. Each control dispatches exactly one command, and nothing writes a table or the header directly. The subscriptions are correct. The three named mutants and the implementer's P-mutants that I re-fired are all red. I found one real but narrow product defect (finding 1: a stale record in the row callbacks can silently undo a rename that has just been committed) and two test gaps (findings 2 and 3). None of them blocks Task 10, but finding 1 should be fixed in the 9b commit together with the gaps.

## What I checked in the diff

- **One command per control; no direct writes.** Every action goes through `_execute` → `document.commands.execute`. The mark sends `SetCurrentLayerCommand`; the eye, lock, colour and rename send `SetLayerCommand` (user form); + sends `AddLayerCommand`; delete sends `RemoveLayerCommand`. Neither file touches `tables.layers.add/remove` or `header`. A colour that is already the layer's colour is skipped as a no-op (O4 is red). The mark of a layer that is both stored and effective current is null, so it is never a no-op undo step.
- **Listeners.** `commands.changes` is a non-sync broadcast stream (`undo.dart:104`), cancelled in `_unsubscribe`. `tables.changes` gets an `addListener` / `removeListener` pair on the same tear-off, so they match. `didUpdateWidget` moves both only when the document is a different object (`identical`), and resets the selection and the open field. `dispose` unsubscribes from `widget.document`, which is the current one at that point. P2, P11 and the debugListenerCount test pin all of this.
- **`tables.changes` during SetLayerCommand's remove-then-add (Task 2 note).** `_refresh` only calls `setState`. It reads nothing. The build that reads `tables.layers` runs in the next frame, after the command has completed. The second notification marks the element dirty again, which is idempotent. So this is safe. A rebuild scheduled from that callback cannot observe the window where the record is missing.
- **+ handle.** It uses `handleSeed.next()`, which is what the placer, `box_tool` and `separator_tool` use. The codec raises the seed over every table record (`json_codec.dart:200-205`), so the new handle cannot collide with a loaded layer, entity or node. R-12b-3, a dangling stored current layer that is not seeded, still applies here: if + hands out that exact handle, the new layer becomes current at once. That is already recorded as a known limitation. The name is `Layer N` through `layerNameError` (case-folded), the colour is ACI 7, and the linetype, lineweight and transparency come from layer 0 (pinned by P9).
- **Delete.** It is enabled only when `_deleteBlocked(_selected) == null`. That check ends in `layerIsEmpty(_doc, layer)`, computed for the one selected row and only when that row is not layer 0 or the effective current layer. When the panel is disabled, `blocked` is not computed at all. Grip drags preview and commit once (`grip_drag.dart`), so the per-DocChange O(n) pass runs once per command, not per pointer move.
- **Effective current layer.** `drawingLayer(_doc)` drives the mark, the hide block, delete's reason and the S-5 follow. The only reads of `header.currentLayer` decide whether the mark is a no-op, which is correct (point 3).
- **ACI 7 swatch.** It is drawn in `foreground`. `main` passes `_resolver.foreground`, and `_onPage` (`main.dart:290-297`) replaces `_resolver` inside `setState` when the paper's foreground changes, so the panel follows a paper change.
- **Rename flows.** Enter calls `_enter`, which validates the trimmed text and either commits once or keeps the field open with `errorText`. Escape is bound nearer than the guard, so it reverts, dispatches nothing and hands focus back. On focus loss, an invalid name reverts and a valid one commits once. `_open` stops the focus listener from acting again after Enter or Escape has already handed focus back. Losing the permission while editing closes the field with nothing dispatched: `build` clears `_editing`, the row's `didUpdateWidget` clears `_open`, and the listener then returns early. Pressing + while another field is open commits the old field on blur, and `onEndRename`'s `_editing == r.handle` guard keeps the new row's field open. The `ShellShortcutGuard` plus `CallbackShortcuts` Escape follows the symbol search's pattern (P6 red).
- **Layout.** At 280 px each icon box is 28 px, so the name gets about 140 px and a row is 32 px. The list is capped at 6 × 32. A temporary probe opened a file with 10 layers and activated the Wall, Door and Window tools at 1440×900, 1280×720 and 1280×640. The panel came out 280×272 and the probe recorded no layout exception (`REVIEW Size(1280.0, 640.0) tool-window right=Size(280.0, 596.0) layers=Size(280.0, 272.0) exc=none`). I did not probe a tall selection (a selected wall's fields) at a small window, because `SelectionPanel` itself does not scroll (info 5).
- **8b.** Both tests follow the Task 8 review exactly: a dangling ObjectLayer with layer 0 hidden, and a Wall-tool join on a hidden C wall in a rotated group, compared bitwise. R2 and R3 are now red (below).

## Rulings on the implementer's points

1. **The extra `foreground` parameter: confirmed.** D9 cannot be met without the paper's colour. It follows a paper change because `_resolver` is replaced in `setState` (`main.dart:294-297`). The default of 0x000000 matches `foregroundFor(white)`. Record it in the spec's "Amended at execution" in Task 11.
2. **A blur with a valid name commits it: confirmed.** This is consistent with the panel number fields. The spec rules only the invalid case. Finding 1 is the hazard that makes this path matter.
3. **The current mark is disabled when the layer is already stored and effective current: confirmed.** A tap would be a no-op command on the undo stack. When the stored current layer is dangling or hidden, layer 0's mark stays live and stores 0, which is correct.
4. **Read-only leaves collapse and row selection live: confirmed.** Neither is a command. Double-click rename is off (`canRename` checks `enabled`), and the test pins it.
5. **Row sizing (28 px controls, 32 px rows): accepted.** It is below Material's 48 px touch target. For a desktop/web planner that is fine. Add it to the human's look list.
6. **Extra keys: accepted.** `layer-name-<hex>` stays the label and `layer-name-field-<hex>` is the field. Task 10 and Task 11 should use these keys.
7. **+ draws from `handleSeed` before executing, and undo does not rewind the seed: confirmed.** That is unchanged engine behaviour shared with every tool.
8. **No existing layout test needed an edit: confirmed.** The diff touches no existing test, and the full app suite is green (974).

## Findings

1. **Minor (product defect, narrow): the row callbacks write the record captured at the last build, so a second command in the same frame can silently revert the first.** The callbacks `onToggleVisible`, `onToggleLocked`, `onColour` and `onRename` all build `r.copyWith(...)` from the `r` of the last `build`. Reproduction (temporary test, `scratchpad/r9-12b/zz_review_tmp_test.dart`):
   - Open A's name field, type `Hall`, then `tester.tap` A's lock with no frame between pointer-down and pointer-up.
   - Pointer-down's `onTapOutside` hands focus back, and the blur commits `Hall`.
   - Pointer-up then calls the stale `onToggleLocked`, which runs `SetLayerCommand(A{name:'A', locked:true})` and reverts the rename.
   - Output: `REVIEW: name=A locked=true depth=2`, `Expected: 'Hall'`, `Actual: 'A'`.
   - With two 16 ms frames between down and up the result is correct: `REVIEW2: name=Hall locked=true depth=2`.

   A human click normally spans a frame. Under jank, though, down and up can be delivered back-to-back before the next frame, and the rename is then lost without any message (it can be recovered with two undos). The same applies to any external command that lands within one frame of a row tap.

   **Fix (9b):** have the panel read the live record at dispatch time, for example `void _update(Handle h, LayerRecord Function(LayerRecord) f) { final cur = _doc.tables.layers[h]; if (cur != null) _execute(SetLayerCommand(f(cur))); }`, and route the eye, lock, colour and rename through it. Add a test like the probe above, using a plain `tester.tap` on the lock while the field is open: the name must be `Hall` and `locked` must be true.

2. **Minor (test gap): a rename never asserts the rest of the record.** My mutants **O1** (`r.copyWith(name: name, locked: !r.locked)`) and **O2** (`..., color: const IndexedColor(7)`) at `layer_panel.dart:255` both survive with `00:05 +21: All tests passed!`. **Fix (9b):** in the Enter test, rename B (ACI 5, locked) instead of, or as well as, A, and assert the whole record equals `before.copyWith(name: 'Kitchen')`. The same full-record assertion is worth adding to the eye, lock and colour steps of the "each one command" test; today the trailing loop only compares names.

3. **Minor (test gap, S-5/D3 state): delete's "current" check is not pinned to `drawingLayer`.** Mutant **O3** (`layer_panel.dart:172` `drawingLayer(_doc)` → `_doc.header.currentLayer`) survives with `00:05 +21: All tests passed!`. In a file whose stored current layer H is hidden and empty, D3 says H "can be deleted when empty", but with O3 delete is disabled with "The current layer cannot be deleted". **Fix (9b):** add a test where `SetCurrentLayerCommand.restore(fx.c)` makes C the stored current layer while C is hidden and empty. Select C, check that delete is enabled, and check that one tap removes C. Note that `RemoveLayerCommand`'s user form also checks against `drawingLayer`, so a single tap must succeed.

4. **Info.** The in-app placement test asserts only `layersTop < pageTop`. It does not check that the panel sits below the Selection panel. Optional: also assert that `SelectionPanel`'s top is above `layersTop`.

5. **Info (look list).** The right column (`SelectionPanel`, then `LayerPanel` up to 272 px, then `Expanded(PagePanel)`) does not scroll as a whole. I saw no overflow at 1280×640 with tool settings shown. A tall selection on a short window should still go on the human's look list.

6. **Info.** Delete's tooltip reads "Delete layer" while the panel is disabled (read-only), because `blocked` is not computed in that state. That is harmless, but a "Read-only" reason would be clearer. No action needed in this plan.

## Gates (re-run at 7e83eae, CI=true, PATH=/root/flutter/bin)

- Engine: `00:15 +1225 -2: Some tests failed.` The 2 failures are the standing ones: `test/testing/generate_document_test.dart: both text fractions default to zero and change nothing` and `...: the default document is the one Plan 2 measured, byte for byte`. Also `No issues found!` and `Formatted 168 files (0 changed) in 0.55 seconds.`
- Render: `00:51 +1187 ~1 -7: Some tests failed.` (the 7 standing text-ladder goldens), `No issues found! (ran in 1.2s)`, `Formatted 208 files (0 changed) in 0.54 seconds.`
- App: `02:54 +974: All tests passed!`, `No issues found! (ran in 1.7s)`, `Formatted 172 files (0 changed) in 0.72 seconds.`
- dev_harness_2d: `No issues found! (ran in 0.9s)`.
- Web: `Compiling lib/main.dart for the Web... 44.3s` and `✓ Built build/web`.
- `git status --short` was empty afterwards.

## Mutants (scratchpad/r9-12b/mut.sh: one sed, the named test file in the foreground, cp back, `diff=0` for each)

| id | mutation | test | real output |
|---|---|---|---|
| R2 (8b) | dimension_attach.dart:143 `objectLayer(doc, host)` → `doc.components.get<ObjectLayer>(host)?.layer ?? ReservedHandles.layerZero` | attach_layer_test | `Expected: empty` `Actual: [AttachedEnd:19/0/left]` `00:00 +2 -1: Some tests failed.` |
| R3 (8b) | wall_bands.dart:98 `joinInto` filters by a visible object layer | tools_layer_test | `Expected: [4513416.841673297, 1206781.4717807919]` `Actual: [4513309.524512457, 1206779.6443538584]` `00:00 +9 -1: Some tests failed.` |
| M-12a | layer_panel.dart:136 `_allowed => true` | layer_panel_test | `Expected: false` `Actual: <true>` `00:05 +20 -1: Some tests failed.` (red at the disabled assertion; the test catches no PermissionDeniedError) |
| M-LP-18 | layer_row.dart:331 `onChanged` dispatches each valid trimmed text | layer_panel_test | `Expected: <0>` `Actual: <5>`; also `Expected: <1>` `Actual: <2>` (×2), `Expected: <0>` `Actual: <1>` |
| M-LP-26 | layer_row.dart:198 `r.visible && widget.current` → `widget.current` | layer_panel_test | `Expected: true` `Actual: <false>` `00:06 +20 -1: Some tests failed.` |
| P2 | layer_panel.dart:121 no `tables.changes` listener | layer_panel_test | `Expected: true` `Actual: <false>`; `Expected: <1>` `Actual: <0>` `00:06 +19 -2` |
| P7 | layer_row.dart:190 a blur never commits | layer_panel_test | `Expected: <1>` `Actual: <0>` `00:06 +20 -1` |
| P10 | layer_panel.dart:175 emptiness ignored | layer_panel_test | `Expected: false` `Actual: <true>` `00:06 +20 -1` |
| P11 | layer_panel.dart:104 didUpdateWidget never moves the subscriptions | layer_panel_test | `Expected: <0>` `Actual: <1>` `00:06 +20 -1` |
| P12 | layer_panel.dart:188 current = stored header value | layer_panel_test | `Expected: true` `Actual: <false>`; `Expected: false` `Actual: <true>` `00:06 +19 -2` |
| O4 (own) | layer_panel.dart:245 drop the same-colour no-op guard | layer_panel_test | `Expected: <0>` `Actual: <1>` `00:06 +20 -1: Some tests failed.` |
| O1 (own) | layer_panel.dart:255 rename also flips `locked` | layer_panel_test | **survives** `00:05 +21: All tests passed!` (finding 2) |
| O2 (own) | layer_panel.dart:255 rename also sets ACI 7 | layer_panel_test | **survives** `00:05 +21: All tests passed!` (finding 2) |
| O3 (own) | layer_panel.dart:172 delete's current check uses the stored header value | layer_panel_test | **survives** `00:05 +21: All tests passed!` (finding 3) |

## Non-degeneracy

- **Layers.** The fixture uses P-6's layers: A (ACI 1), B (ACI 5, locked), C (ACI 3, hidden; not layer 0). The only hidden layer 0 is in the S-6 file, which is about layer 0. ACI 7 appears only where the foreground is the point, and that test runs at both 0x000000 and 0xFFFFFF, so a hard-coded black or white swatch fails one of the two.
- **Order.** The order test mixes case (`alpha`, `Beta`, `Zed`) against creation order and code-unit order, which P3 kills.
- **+.** The + test gives layer 0 a non-default lineweight (35) and transparency (40), and pre-takes `Layer 1` and `layer 3` (lower case), so both the copying and the case-folded `Layer N` are observable.
- **Current layer.** The S-6 and S-5 tests separate `drawingLayer` from the stored value, and P12 kills that.
- **Read-only.** It is tested under both `readOnly` and `runtime`; `runtime` allows components but not structure.
- **Weak spots.** Findings 2 and 3 are the remaining places where the fixture is weak: a rename on an unlocked ACI 1 layer whose other fields are never compared, and no test of an empty, hidden, stored current layer being deleted.
