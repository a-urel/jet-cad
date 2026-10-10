# Slice 4, Task 6: keyboard, focus and the inspector (independent review)

- **Commit under review:** `305285f` (parent `62926cb`), branch `claude/exciting-pasteur-9m22jv`.
- **Reviewer's clones:** `/home/user/review-s4t6` (gates) and `/home/user/review-s4t6-m` (probes, mutants), both at `305285f`, both deleted at the end. Nothing was edited, committed or pushed in `/home/user/jet-cad` except this file.
- **Scratch:** `/tmp/claude-0/-home-user/428cafca-0083-5012-a7ac-5456349e70a8/scratchpad/rv-s4t6/`. It holds `gates.sh` and `gates.out`, the per-package `*.json`, `*.test.log`, `*.cmp.log`, `*.an.log` and `*.fmt.log`, the mutant runner `mut.py`, `mutants.py` and `mutants.out` (with one log per mutant per suite in `mlogs/`), and the probe files `zz_review_s4t6_probe_test.dart` (RP1 to RP12) and `zz_review_s4t6_probe2_test.dart` (RP13).
- **Environment:** Flutter `/root/sdk/flutter/bin`, `CI=true`.

## Verdict

**Approve, with fixes.** The code does what Task 6 asks, in both modes, and every gate is green. I found no defect in the key handling, the focus or `deleteSelection()`. These are the open items:

- One spec reading needs a ruling: an inspector for a table whose number another table shares (R-1, Medium).
- Two killers are missing: R-2 and R-3 are mutants that survive the task's own suite.
- Two doc sentences overclaim (R-4).

None of them blocks Task 7. R-1 needs the controller's ruling before the guide documents the inspector.

## Findings

### R-1 (Medium): the inspector shows for a table whose number another table shares, and the host's link is refused there

**Evidence:**
- Selecting ` 7 ` alone shows the inspector with `table.number == '7'`. The task's own M-H45 test asserts this: `inspector_test.dart`, "` 7 ` alone is one numbered table".
- In that state the host's natural link, `c.setTableData(d.table.number!, …)`, answers **false**. `setTableData` refuses a trimmed number that names more than one table (`floor_plan_controller.dart:1475-1482`).
- Probe RP7 shows both. C-6's own example is "Monépro links a drawn table to a `pos_tables` row here, with Slice 2's `setTableData`", and that link fails silently for exactly this table.
- The view's doc (`floor_plan_view.dart:118-124`) says "two tables sharing a number … show none". A host reads that as covering this case, but the code covers only the two-key selection.
- S-18's sentence is ambiguous. It puts "two tables sharing a number" under "the selection holds exactly one key".

**Fix (controller to rule).** I recommend **(a)**:
- **(a) Hide the inspector when the selected table's number names more than one table.** This follows P-2 (the number is the identity) and C-6's "exactly one numbered table". It is the behaviour `setTableData` already enforces. My candidate fix (the `R17-…` row below: the adapter returns null when `tableDetails` holds the number more than once) turns exactly one existing assertion red: M-H45's last block, which would change to "` 7 ` alone → none". Add ` 7 ` alone to the M-H45 "none" cases. The view doc then holds as written.
- **(b) Keep it shown.** Then the view doc must say so: "a table whose number another table shares is shown, but `setTableData` refuses that number; renumber it first". Add a test that pins the refusal. RP7 is the model.

### R-2 (Low): `shortcuts: false` in the design mode — the Export and Print chords have no killer

**Evidence:**
- Mutant `R1-fileChordsUngated` binds the shell's file-command chords (Export and Print, the only file commands the view gives the shell) whatever `shortcuts` says, and keeps the edit chords gated.
- It survives the task's whole suite (`keyboard_focus_test.dart` and `inspector_test.dart`, green). T6-b presses only Ctrl+Z among the design mode's chords, and M-H41b is the selection mode's.
- My RP1 kills it: Ctrl/Cmd+E and Ctrl/Cmd+P do not reach the host.
- T6-b also presses only W of the sixteen letters. The `T6-b-letters` mutant is killed, but a per-letter slip (for example, one entry left bound) would pass.

**Fix:** in T6-b, give the host an `onExport` (without it `canExport` is false and no Export chord exists), then press Ctrl+E, Cmd+E, Ctrl+P and Cmd+P under `shortcuts: false` and count each at the host. Loop over every letter the shell binds under `full`. RP1 does both, with an intent-based host and for `full` and `tablesOnly`; it can be landed as is.

Optional: land RP12 as well. At the floor-plan level only the Wall tool's Escape is pinned as "a gesture's key stays". RP12 pins the armed symbol tool's R, and M bubbling under `tablesOnly`, where mirroring is refused.

### R-3 (Low): `deleteSelection()` is never called under `shortcuts: true`

**Evidence:**
- Every DS test mounts through `mountKeys`, whose default is `shortcuts: false`. DS2 uses `shortcuts: true` only for the key's half.
- Mutant `R14-deleteRegisteredOnlyWithoutShortcuts` (the view passes `onDelete` only when `shortcuts` is false) survives the whole suite. My RP5 kills it.
- C-3 makes the command independent of the keys: "the commands stay callable" is about `shortcuts: false`, but the call must work with the default too.

**Fix:** one assertion under `shortcuts: true`. In DS1, for example, run the control path through the call as well, or add RP5's second half.

### R-4 (Low): two doc sentences overclaim

1. **`FloorPlanView.autofocus`** (`floor_plan_view.dart:153-161`; and `PlannerShell.autofocus`, `PlannerView.autofocus`, `ServiceView.autofocus`) says "A press on the canvas takes the focus either way".
   - **Evidence:** this is false in the parameter's own use case, a default Material `TextField` focused beside the view. RP10 measured it: after the first click the canvas is not focused (`first click canvas focused: false; second: true`).
   - The same holds for a host field **inside the inspector**. RP13: `first click canvas focused: false; second: true`. jet-cad's own panel fields avoid it with `PanelFieldFocusNode.handBack`, but a host field in jet-cad's panel does not.
   - The task's tests pass only because their host fields set `onTapOutside: keepFocus`, as the report says.
   - **Fix:** qualify the sentence now: "a press on the canvas requests the focus; a Material `TextField` that had it unfocuses on that press (its default `onTapOutside`), so give it an `onTapOutside` that keeps or hands back the focus". Carry the advice into the guide in Task 7, for fields beside the view and in the inspector.
2. **`FloorPlanController.deleteSelection`** says "exactly as the select tool's idle Delete key does".
   - **Evidence:** with a drawing tool active and idle, and a selection the host made with `select`, the call deletes and the Delete key deletes nothing. The active tool is not the select tool, the Wall tool ignores Delete and the shell binds none. RP5 shows both, and DS5 pins the call's half.
   - **Fix:** add "whichever tool is active, while it is idle" to the public doc. The shell's private comment already says so. See the ruling on finding 3.

### R-5 (Info): mutants with no killer in the task's suite, judged acceptable

- **`R5-didUpdateNoRecompute`:** `_TableInspector.didUpdateWidget` no longer recomputes `_shown`. It survives everything. I judge it equivalent in practice:
  - every change of what `_inspected` answers comes with a selection notification (through the relay) or a document notification;
  - a remount (a load, or a mode switch) makes a new state.

  The recompute is defence; no change is asked.
- **`R11-dragEscapeGated`:** a drag's Escape gated by `idleKeys`, in `jet_cad_2d_flutter`. It is green at the floor-plan level and red at the render level (`select_gates_test.dart` T3-g, Task 3's killer). Acceptable: the gate lives in the render package and is pinned there.

## Verified independently

1. **Scope, P-1 and P-6:**
   - `git diff 62926cb 305285f --name-status` lists six `lib` files and two **new** test files. No existing test is touched, and neither are the barrel or `barrel_test`.
   - Every new parameter is named and optional, with today's default: `FloorPlanView.shortcuts` and `autofocus` default to true, `tableInspectorBuilder` to null; the same holds for the `ServiceView`, `PlannerShell`, `PlannerView` and `TableSelectTool` parameters.
   - With the defaults, every binding entry is present and `idleKeys` reads true. With no builder the slot is absent.
   - `editor.dart` (the internal library) now carries the two new typedefs, as Task 4's `ShellToolRegistrar` did. No new host name.
2. **`shortcuts: false`:** the enumeration is below.
   - RP1 shows that every letter the shell binds, F3, Escape, Delete, Backspace and every chord reach a **`Shortcuts`/`Actions`/`Focus` host** (the `PosShortcutsHost` shape, intent-based rather than `CallbackShortcuts`), under `full` and under `tablesOnly`, with the canvas keeping the focus and the plan unchanged.
   - RP2 shows the same in the selection mode.
3. **`autofocus`:** both modes at mount, and after `setMode`, `resetLayout` and `load`, are covered by the task's T6-a tests. The `T6-a-*` mutants and my `R8` are red. `autofocus: true` is unchanged (the defaults, V8 and V15 green). See R-4.1.
4. **`deleteSelection()`:**
   - **Differential with the key (RP3):** a broad selection, `1` with data, `2`, a wall, the group of two lines, the free line, the TEXT and the chair, gives a byte-equal plan after the call (`shortcuts: false`) and after the key (`shortcuts: true`), and after each one's undo. Each is one step, and the data comes back.
   - **`designChanges` (RP4):** one `FloorPlanTableRemoved` for `1`, carrying `{pos: a1}`; the undo gives one `FloorPlanTableAdded` equal to it.
   - **Refusals:** under `delete: false` it answers false (RP5); under `readOnly` (DS3); with nothing selected, with no undo step (RP6); in the selection mode, before the frame too (DS4); with no view (DS4); mid-shape (DS5).
   - **Locked layers:** the call and the key share one path, `SelectTool.deleteSelection`. Locked and hidden tables cannot enter the selection through `select`, which skips them, or through the pick (`QueryFilter.picking`).
5. **The inspector:**
   - It shows for exactly one root-level numbered key, and for no other selection: two tables; `7` and ` 7 `; a table and a wall; the unnumbered table; a wall (M-H45).
   - A table **inside a group** gives none, whether the group or the nested instance is the key; `editorSelectedTables` stays empty (RP8).
   - **Rebuilds:** none for 50 pans and zooms or for hovers (T6-d). Exactly one at the drop of a 20-move drag of `1`, none during it (RP9). One at a document change (the "b7" test), and one at a host rebuild.
   - It is hidden with `selectionPanel: false` (T6-f).
   - `editorSelectedTables` behaves as specified: empty in the selection mode, notified once per change, and once at a `load` (RP11).
6. **Gates,** rerun on the committed tree (`gates.out`):

| Package | Test | Standing comparison | Analyze | Format |
|---|---|---|---|---|
| `jet_cad_floor_plan` (`--enable-vmservice`) | `07:47 +1854: All tests passed!` | `1854 tests; the standing failures and skips, exactly` | No issues found | 276 files, 0 changed |
| `apps/restaurant_demo` | `00:43 +60: All tests passed!` | `60 tests; … exactly` | No issues found | 0 changed |
| `apps/floor_planner` | `02:31 +212: All tests passed!` | `212 tests; … exactly` | No issues found | 0 changed |
| `jet_cad_2d_flutter` | exit 1 (its standing failures) | `1415 tests; … exactly` | No issues found | 0 changed |
| `jet_cad_2d_gpu` | `00:01 +20: All tests passed!` | `20 tests; … exactly` | No issues found | 0 changed |
| `jet_cad_2d` (`dart test`) | exit 1 (its standing failures) | `1258 tests; … exactly` | No issues found (`--fatal-infos`) | 0 changed |

## Key-handler enumeration (from the code at `305285f`)

| # | Where | Keys | Mode | Under `shortcuts: false` |
|---|---|---|---|---|
| 1 | `service_view.dart:497-507` `CallbackShortcuts` | Undo (Cmd/Ctrl+Z), Redo (Cmd/Ctrl+Shift+Z, Ctrl+Y), Export (Cmd/Ctrl+E, when `canExport`), Print (Cmd/Ctrl+P) | selection | **unbound** (each group behind `keys`); M-H41b ×4 red |
| 2 | `service/table_select_tool.dart:535-543` `onKey` | idle Escape: clears the selection | selection | **ignored**, bubbles (`idleKeys`); T6-g red |
| 3 | `planner_shell.dart:1381-1405` `CallbackShortcuts` | file-command chords (Export, Print), edit chords (Undo, Redo), F3 (when `snapping`), the 15 tool letters (when allowed), F (when Fill is offered), Escape (back to select) | design | **all unbound** behind `keys`; Export and Print have no task killer (R-2) |
| 4 | `select_tool.dart:696-737` (render) `onKey`, through the shell's `_CapabilityGates.idleKeys` | idle Escape (clear), idle Delete and Backspace (delete) | design | **ignored**, bubble; T6-b(`idleKeys`), T6-c red |
| 5 | `select_tool.dart` (render), dragging | every key-down and repeat consumed; Escape cancels; Shift is ortho/15° | design | **stay** (a gesture); T3-g at the render level |
| 6 | `draw/placement_tool.dart:177-210` (render: line, polyline, rectangle, circle, arc, wall, room, door, window, dimension) | mid-shape: Escape cancels, Enter finishes, F3 and F bubble, every other key-down consumed; Shift tracked | design | **stay** (a gesture); the task's "a gesture's keys stay" test |
| 7 | `parametric/dimension_tool.dart:193-201` | Shift tracked, then #6 | design | stays |
| 8 | `symbols/symbol_place_tool.dart:415-452` | armed: R (rotate, when `rotate`), M (mirror, when `mirror`); pressed: Escape, F3 and F bubble, the rest consumed | design | **stay** (S-16's exception); RP12 |
| 9 | `shortcut_guard.dart` `ShellShortcutGuard` (right column, symbol search, top-bar host widgets) | letters, Undo and Redo chords, Escape → `DoNothingAndStopPropagationTextIntent` | design | unchanged; acts only with a text field focused (the field takes its keys). Correct for jet-cad's fields and for host fields in the inspector. |
| 10 | `symbols/symbol_panel.dart:292-295` | Escape in the search field: hand back | design | unchanged (the field's own key) |
| 11 | `layers/layer_row.dart:317-319` | Escape in the rename field: cancel | design | unchanged (the field's own key) |
| 12 | `text_entry_overlay.dart:136-138` | Escape in the TEXT entry: cancel | design | unchanged (a gesture's field) |
| 13 | `interaction_layer.dart:489-492` (render) `Focus(onKeyEvent)` | forwards to the active tool (#2, #4 to #8) | both | the carrier only |
| — | `camera_gesture_detector.dart`, `planner_view.dart`, `floor_plan_view.dart`, panels, bars | no key handler (the bars and palette sit in `ExcludeFocus`) | — | — |

Focus requests in `lib`:
- the canvas, on a press (`interaction_layer.dart:251, 314, 380, 404`);
- a layer row's rename, the TEXT entry, and the panel fields' hand-back.

None runs at mount except the two autofocus `Focus` nodes this task wires and the export dialog's own field.

## Mutants

37 applied by `mut.py`. For each one, the file was copied aside, the mutant applied, the suites run, the file restored and compared byte for byte. After the runs, `git status` in the mutant clone listed only the probe file.
- **"impl"** is the task's `keyboard_focus_test.dart` and `inspector_test.dart`.
- **"probe"** is my RP1 to RP12.
- Red means a failed expectation; no run was a compile error.

### Named and task-local, re-applied (21; all red on the task's suite)

| Mutant | impl | Killer (first red) | probe |
|---|---|---|---|
| M-H41b (undo) | RED | M-H41b | RED (RP2) |
| M-H41b (redo) | RED | M-H41b | RED |
| M-H41b (export) | RED | M-H41b | RED |
| M-H41b (print) | RED | M-H41b | RED |
| T6-a (service `Focus` true) | RED | T6-a (selection), T6-a (remounts) | green |
| T6-a (service canvas) | RED | same | green |
| T6-a (editor canvas) | RED | T6-a (design), T6-a (remounts) | green |
| T6-b (letters) | RED | T6-b | RED |
| T6-b (Escape) | RED | T6-b; a gesture's keys stay | RED |
| T6-b (`idleKeys => true`) | RED | T6-b; DS1 | RED |
| T6-g (tool) | RED | T6-g | RED |
| T6-g (wiring) | RED | T6-g | RED |
| M-H45b (the first key) | RED | M-H45 | green |
| M-H45c (unnumbered) | RED | M-H45 | green |
| T6-f | RED | T6-f | green |
| T6-d2 (every selection notification) | RED | T6-d; T6-f | green |
| T6-e | RED | T6-e | green |
| T6-e2 (a new set each refresh) | RED | T6-e | green |
| DS-m1 (no mode check) | RED | DS4 | green |
| DS-m2 (no mid-shape check) | RED | DS5 | green |
| DS-m3 (no settle) | RED | DS6 | green |

### The reviewer's own (16; 15 mutants and one candidate fix)

| Mutant | impl | probe | Note |
|---|---|---|---|
| R1 the design mode's Export and Print chords ungated | **green** | RED (RP1) | R-2 |
| R2 `SelectTool.deleteSelection` without its `delete` gate | RED (DS3) | RED (RP5) | |
| R3 the host's delete only with the select tool active | RED (DS5) | RED (RP5) | pins finding 3 |
| R4 `_onDocument` rebuilds only when the table changes | RED ("b7") | RED (RP9) | |
| R5 `didUpdateWidget` without the recompute | green | green | equivalent (R-5) |
| R6 the adapter reads `details[0]` | RED (M-H45) | RED (RP7) | |
| R7 `editorSelectedTables` not updated in the selection mode | RED (T6-e) | green | |
| R8 the shell's `autofocus` taken from `shortcuts` | RED (T6-a) | green | |
| R9 the shell's `shortcuts` taken from `autofocus` | RED (T6-b, DS1) | RED | |
| R10 `deleteSelection` also gated by `idleKeys` | RED (DS1, DS2) | RED (RP3, RP4) | |
| R11 a drag's Escape gated by `idleKeys` (render) | green | green | **RED** at render T3-g (R-5) |
| R12 the inspector listens to the camera (through `documentChanges`) | RED (T6-d) | green | |
| R13 no `_documentChanged` notification | RED ("b7") | RED (RP9) | |
| R14 `onDelete` registered only under `shortcuts: false` | **green** | RED (RP5) | R-3 |
| R15 the settle after the delete | RED (DS6) | green | |
| R17 *(candidate fix for R-1, not a mutant)* the inspector hidden for a shared number | RED (M-H45's ` 7 ` alone) | RED (RP7) | the one assertion that changes under R-1 (a) |

## Rulings on the implementer's findings

1. **A focused Material `TextField` takes the focus back from a canvas click.** Confirmed: RP10 for a field beside the view, RP13 for a field inside the inspector; the first click leaves the canvas unfocused and the second focuses it. This is Flutter's behaviour and predates the task. The `keepFocus` workaround in the tests is disclosed and acceptable. The doc sentence that contradicts it is R-4.1. The guide note belongs to Task 7, as the report proposes, and it should cover fields in the inspector too.
2. **An undo of a delete re-inserts the node last among the root's children.** This is the engine's pre-existing behaviour, Task 3's finding; the engine is not edited. Accepted. DS1 compares details, and DS2 and my RP3 compare the call's undo with the key's undo byte for byte (equal), which is the comparison that matters here.
3. **`deleteSelection()` deletes whichever tool is active, if idle.** Accepted as designed. A drawing tool clears the selection when it is activated (`_activate`), so the selection can be non-empty only because the host made it. Deleting what the host selected is the useful answer, and S-16's list of false cases does not include "another tool active". DS5 pins it, and my R3 mutant is red on it. The public doc's "exactly as the Delete key" must say so (R-4.2): the key does not delete there (RP5).
4. **`autofocus` is read at mount only.** Accepted. C-7 defines it as "taking focus on mount", Flutter's `Focus.autofocus` acts once per node, and the doc says "Read at each mount". P-3's "read at each build" does not apply to a property whose meaning is the mount.
5. **New internal names beyond the plan's list.** Accepted. All are optional or `@internal`. Nothing enters the barrel (R-1 of the spec holds). The typedefs reach only `editor.dart`, the explicitly internal library, with Task 4's precedent.
6. **The inspector's builder is not called while the Selection panel is hidden; the slot is absent, not offstage.** Accepted. T6-f requires no call while hidden, and an offstage slot would call the builder. The host's subtree is already discarded at every deselection, so a kept offstage slot would preserve nothing a host may rely on. The guide should say the host keeps its inspector state in its own objects, as G-5 asks of overlays.
