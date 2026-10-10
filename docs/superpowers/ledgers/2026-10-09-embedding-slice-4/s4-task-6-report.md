# Slice 4, Task 6: keyboard, focus and the inspector (implementer's report)

- **Branch:** `claude/exciting-pasteur-9m22jv`, from `62926cb` (Tasks 1 to 5; Task 5's review runs in parallel).
- **Commit:** `305285f`. Pushed as `62926cb..305285f`.
- **Environment:** Flutter 3.47.6 at `/root/sdk/flutter/bin`, `CI=true`. Scratch: `/tmp/claude-0/-home-user/428cafca-0083-5012-a7ac-5456349e70a8/scratchpad/s4t6-impl/`:
  - `mut.py` is the mutant runner. It applies a mutant (one edit or several files), runs each killer by `--plain-name`, counts a run red only on a failed expectation (not on a compile error, and not on "no tests"), restores from a copy and checks the file byte-equal with `filecmp`.
  - `mutants-round1.log` and `mutants-round1b.log` hold the results, with one log per killer run in `logs/`. `lib_pre_mut/` is the `lib` before the mutants; it was compared with `diff -r` after each round and is identical.
  - `gates.sh`, `gates.out` and the per-package `*.json`, `*.test.log`, `*.cmp.log`, `*.analyze.log` and `*.format.log` are the gate runs.
  - `zz_probe_taps_test.dart` is the probe behind finding 1. It was run in the package and moved out before the mutants and the gates.
- **`analysis_options.yaml`:** none was touched or committed. Before the commit, `git status` showed the task's eight files only; after it, the tree was clean.
- **Scope:** Task 6's Builds and Tests. The engine and `jet_cad_2d_flutter` are not edited. Task 3's `SelectGates.idleKeys` and `SelectTool.deleteSelection` are used as they are. No existing test, golden, counter or allocation test is edited. Task 6 adds no type name, so B1 is unedited.

## Files

| File | What |
|---|---|
| `lib/src/host/floor_plan_view.dart` | **`tableInspectorBuilder`**, **`shortcuts = true`** and **`autofocus = true`** are documented with C-6's and C-7's sentences and S-16's list. `shortcuts` and `autofocus` go to `ServiceView` and `PlannerShell` at each build. The shell gets `tableInspector: builder == null ? null : _inspect` and `onDelete: c.registerDelete`. `_inspect(context, instance)`, the adapter, reads the builder now (design mode only). It finds the instance in `tableDetailInstances`, takes the same index of `tableDetails`, and calls the host only for a numbered table. |
| `lib/src/host/service_view.dart` | Optional **`shortcuts`** and **`autofocus`** (both true). Every chord group (undo, redo, export, print) is bound only under `shortcuts`. The `Focus` and the canvas's `PlannerView` take `autofocus`. The table tool is given `idleKeys: () => widget.shortcuts`. |
| `lib/src/service/table_select_tool.dart` | Optional `idleKeys` (`bool Function()`, default always true). The idle Escape clears the selection only while it answers true; otherwise the key is `ignored` and bubbles. |
| `lib/src/planner_view.dart` | Optional **`PlannerView.autofocus`** (true), handed to `InteractionLayer.autofocus` (Task 3). |
| `lib/src/planner_shell.dart` | Optional `shortcuts`, `autofocus`, `tableInspector` (`ShellTableInspector`) and `onDelete` (`ShellDeleteRegistrar`). The two typedefs are new; `lib/editor.dart` exports the shell's file whole, as with Task 4's `ShellToolRegistrar`. Under `!shortcuts`, every binding entry is off: the command chords, F3, the letters, F and Escape. The map stays and the tree is unchanged. `_CapabilityGates.idleKeys` reads `widget.shortcuts` live. `_deleteByHost` is `_select.deleteSelection(_context)`, registered in `initState` and withdrawn in `dispose`. `_inspected()` returns the selection's single key when it is a root-level table (`_isTableKey`, Task 5's rule). See "The inspector slot" below for `_documentChanged` and `_TableInspector`. |
| `lib/src/host/floor_plan_controller.dart` | **`ValueListenable<Set<String>> editorSelectedTables`** is set in `_refreshSelected`: `selectedTables`' value in the design mode, `const {}` in the selection mode, and assigned only when `setEquals` says it changed. It is disposed with the controller. **`bool deleteSelection()`** answers false outside the design mode, with no editor registered, or while the editor is mid-shape (`_editorMidShape`, S-4's probe). Otherwise it settles (`_settle`, as `undo()` does) and calls the editor's delete. `@internal registerDelete` withdraws only its own registration, as `registerSettle` does. |
| `test/host/keyboard_focus_test.dart` (new, 16 tests) | Described under Tests. |
| `test/host/inspector_test.dart` (new, 6 tests) | Described under Tests. |

**The inspector slot** (`planner_shell.dart`):
- When the builder is given and `caps.selectionPanel` holds, a keyed `_TableInspector(key: Key('table-inspector'))` is the next child after the Selection panel's `Visibility`. Because it is keyed, adding or removing it keeps the Layer and Page panels' elements.
- `_TableInspector` listens to `_selectionRelay` (Task 4's frame-safe relay) and to `_documentChanged`. `_documentChanged` is a notifier bumped in the existing `_history` listener; the dispatcher's stream is asynchronous, so it never notifies during a build.
- It rebuilds when the inspected instance changes. A hover, a selection change that keeps the table, and the camera build nothing.
- It also rebuilds at each document change while it shows a table, and at each new widget, which is every shell build and so every host rebuild.
- While the selection panel is hidden there is no slot and the builder is not called.

## Tests

`test/host/keyboard_focus_test.dart` puts a host `CallbackShortcuts` above the view. It counts Ctrl and Cmd + Z, Ctrl and Cmd + Shift + Z, Ctrl+Y, Ctrl and Cmd + E, Ctrl and Cmd + P, Escape, Delete, Backspace, W, F and F3. The host also gives a counting `onExportDialog`, `onExport` and a counting printer. `shortcuts` can change at runtime, so each test carries its own control under `shortcuts: true` and shows the layout can go red. Both modes run on `embeddingPlanJson` under `embeddingCamera()`, and the editor's keys on the editor fixture under `editorCamera()`, in `kEditorSurface`.

- **M-H41b** (selection mode, canvas clicked and focused, `1` moved by a command):
  - each of the nine chords reaches the host once, and the move stays (encoding equal, `canUndo`);
  - no dialog, no export, no print;
  - the control (`shortcuts` → true): Ctrl+Z undoes and Ctrl+Y redoes without the host hearing them, and Ctrl+E asks the export hook.
- **T6-g:** `1` selected; Escape keeps it and the host's Escape fires. The control: Escape clears it and the host hears nothing.
- **T6-b:**
  - **Setup:** design mode, data on `1`, `1` selected.
  - **Each key:** W, F3, F, Escape and Ctrl+Z each reach the host once.
  - **Kept:** the tool stays select, and OSNAP, Fill, the selection and the data are unchanged.
  - **The control:** the tool's Escape clears the selection, W selects Wall, the shell's Escape returns to select, F3 and F toggle, and Ctrl+Z undoes. The host hears nothing more.
- **"A gesture's keys stay"**:
  - `selectTool(wall)` answers true; the idle Escape reaches the host and the tool stays Wall;
  - one click puts a wall part-way; `undo()` then waits (S-4) and the wall's own Escape is not the host's;
  - after that Escape, `undo()` acts and the next Escape is the host's.
- **T6-c:** `tablesOnly`, `1` selected. Delete and Backspace change nothing and reach the host. The control: Delete removes `1`.
- **"Shortcuts false: undo() and exportPlan act in each mode"**: on `finitePlanJson`, in each mode, a move is undone by `undo()` and `exportPlan(PNG at 96)` gives the page's pixel size.
- **DS1:**
  - Delete deletes nothing and reaches the host.
  - `deleteSelection()` answers true; `1` and its data are gone, the selection is empty and the undo depth is +1.
  - A second call answers false (nothing selected).
  - `undo()` restores every table's detail, the data included, and the undo depth. `redo()` deletes again.
- **DS2:** `1`, `2` (with data) and a wall are selected. The call (under `shortcuts: false`) and the key (under `shortcuts: true`) give the same encoding, one step each, and the same encoding after their undo.
- **DS3:** under `readOnly`, `1` selected: false, the encoding unchanged, `canUndo` false.
- **DS4:**
  - `setMode(selection)` then `select({'1'})`, before any frame: false; after the frames: false, and the design (`designJson`) unchanged;
  - back in the design mode, the view unmounted: false, design unchanged.
- **DS5:** a wall part-way and `select({'1'})` by the host: false. After Escape: true, and `1` is gone.
- **DS6:** a rotation of 75 typed into `symbol-rotation` and not committed, then `deleteSelection()`. One undo brings `1` back at 75° (the settled step); a second undo gives 30°.
- **DS7:** after a `load`, and after a mode round trip, the new editor's delete answers true.
- **T6-a (design) and T6-a (selection):**
  - **The layout:** `Column[FloorPlanView, TextField(autofocus: true)]`, the view first in one frame.
  - **The control** (`autofocus: true`): the view takes the focus.
  - **`autofocus: false`:** the field keeps it.
  - **A click:** a click on the canvas focuses the canvas (see finding 1 for the field's `onTapOutside`).
- **T6-a (the field focused, the view in a `FocusScope` of its own):** the steps are `setMode(selection)`, `resetLayout`, `load` (selection), `setMode(design)` and `load` (design).
  - With `autofocus: true` (the control), each remount takes the focus from the field.
  - With `false`, the field keeps it at every step, and a final click focuses the canvas.

`test/host/inspector_test.dart` runs on the editor fixture. The host's builder records every detail it gets. It returns a `Column` with a text (a host label, the number, `pos`) and a field whose submission calls `setTableData`.

- **M-H45:**
  - none of these shows the inspector, and the builder is never called: `1` and `2`; `7` and ` 7 `; `1` and a wall; the unnumbered table alone; a wall alone; `select({'7'})` (two keys, `selectedTables == {7}`);
  - `1` alone shows the host's widget with `1`'s detail. Its `center` is within 1e-6 of the fixture's transform of the box's centre, its rotation is 30°, and its data is `{pos: a1}`;
  - the widget sits below `selection-panel` and above `layers-panel`;
  - ` 7 ` alone shows `7` with another centre.
- **T6-d:**
  - `1` selected gives one call;
  - 50 camera changes give no further call. They are `panBy`, `zoomBy` and the user's wheel (`PointerScrollEvent`), a third each;
  - three hovers (over `2`, `1` and the TEXT; three distinct hover keys, asserted) give no call;
  - `2` gives +1; `2` again gives +0; `1` gives +1; `{1, 2}` gives +0.
- **T6-f:** under `full.copyWith(selectionPanel: false)`, `1` selected: no `table-inspector`, no host widget, no call. Under `full` at runtime the widget is shown, after one call.
- **"The inspector reaches the host's state"**:
  - W typed in the inspector's field leaves the tool at select (the guard);
  - `b7` submitted: `revision` moves and the inspector shows `b7`;
  - `undo()` shows `-` again;
  - a host rebuild (the label) shows the new label.
- **"None without a builder; none in the selection mode"**:
  - no slot without a builder;
  - in the selection mode with a builder, `1` selected: no slot, no call;
  - back in the design mode: shown.
- **T6-e** (through the barrel):
  - `{1}`, after one notification;
  - `{1, wall}` keeps `{1}` with no notification;
  - the selection mode: empty, after one notification;
  - `select({1, 2})` there: `selectedTables` is `{1, 2}`, the editor's set stays empty with no notification;
  - back in the design mode: `{1, 2}`, after one notification;
  - the value is unmodifiable.

## Mutants

Every row was seen red on its killer at an expectation (`mutants-round1.log`, `mutants-round1b.log`, `logs/`). The file was restored and compared byte for byte, and `lib` was `diff -r`-identical to `lib_pre_mut` after each round.

| Mutant | Applied as | Killer (test name) | Seen red at |
|---|---|---|---|
| **M-H41b** (undo) | the service's Undo chords bound whatever `shortcuts` says | M-H41b … | the host's count: expected 1, got 0 |
| M-H41b (redo) | same, the Redo chords | M-H41b | same |
| M-H41b (export) | `if (flows.canExport)` | M-H41b | same |
| M-H41b (print) | same, the Print chords | M-H41b | same |
| M-H41b (view) | the view omits `shortcuts` to `ServiceView` | M-H41b; T6-g | 0 for 1; `{}` for `{1}` |
| **M-H45** (the rule read as `selectedTables.length == 1`) | the shell: any table key among the keys; the adapter: `selectedTables.value.length == 1` | M-H45 … | `host-inspector` found |
| M-H45b (task-local) | the shell's single-key rule removed (the first table key) | M-H45 | `host-inspector` found |
| M-H45c (task-local) | the adapter calls the host for an unnumbered table | M-H45 | `host-inspector` found |
| **T6-a** (service `Focus`) | `autofocus: true` | T6-a (3 tests) | `focused(field)` false |
| T6-a (service canvas) | the service's `PlannerView` without `autofocus` | T6-a | same |
| T6-a (editor canvas) | the shell's `PlannerView` without `autofocus` | T6-a | same |
| T6-a (`PlannerView`) | `InteractionLayer` without `autofocus` | T6-a | same |
| T6-a (view → service) | the view omits `autofocus` to `ServiceView` | T6-a | same |
| T6-a (view → shell) | the view omits `autofocus` to the shell | T6-a | same |
| **T6-b** (chords) | the shell's command chords bound whatever `shortcuts` says | T6-b … | expected 1, got 0 |
| T6-b (F3) | `if (caps.snapping)` | T6-b | same |
| T6-b (letters) | the letters bound whatever `shortcuts` says | T6-b | same |
| T6-b (F) | `if (_fillOffered)` | T6-b | same |
| T6-b (Escape) | the shell's Escape always bound | T6-b; a gesture's keys stay | same |
| T6-b (`idleKeys`) | `_CapabilityGates.idleKeys => true` | T6-b; T6-c; DS1 | 0 for 1; the encoding differs |
| T6-b (view → shell) | the view omits `shortcuts` to the shell | T6-b; T6-c | same |
| **T6-c** | = T6-b (`idleKeys`) and (view → shell) | T6-c … | the encoding differs after Delete |
| **T6-d** | the inspector also listens to the camera | T6-d … | calls: expected 1, got 51 |
| T6-d2 (task-local) | the inspector rebuilds at every selection notification | T6-d | expected 1, got 4 (the hovers) |
| T6-d3 (task-local) | no rebuild on a document change | the inspector reaches the host's state … | `'host 1 -'`, expected `'host 1 b7'` |
| **T6-e** | the editor's set filled in the selection mode | T6-e … | `{1}`, expected empty |
| T6-e2 (task-local) | a new set assigned at every refresh | T6-e | notifications: 2, expected 1 |
| **T6-f** | the slot without `when caps.selectionPanel` | T6-f … | `table-inspector` found |
| **T6-g** (tool) | the table tool's Escape without `idleKeys()` | T6-g … | `{}`, expected `{1}` |
| T6-g (wiring) | `ServiceView` does not pass `idleKeys` | T6-g | same |
| DS-m1 | `deleteSelection` without its mode check | DS4 | true, expected false (before the frame) |
| DS-m2 | without the mid-shape check | DS5 | true, expected false |
| DS-m3 | without the settle | DS6 | 30°, expected 75° |
| DS-m4 | the shell does not register | DS1 | false, expected true |
| DS-m5 | the shell does not withdraw on dispose | DS4 | true, expected false (no view) |
| DS-m6 | the withdrawal clears whatever is registered | DS7 | false, expected true (after a load) |
| DS-m7 | the gate's `delete => true` | DS3 | true, expected false |
| DS-m8 | the view passes no `onDelete` | DS1 | false, expected true |

**Equivalent, no killer:**
- **M-H45d:** `_inspected` without `_isTableKey`, so any single key passes. The adapter finds no table detail for a non-table key and returns null, so nothing shows. The shell's clause is defence.
- **P-slot:** the adapter's design-mode check removed. In the selection mode no shell exists to call it. The check is defence too: the copy's handles equal the design's.

**The first round** stopped at the M-H45 row because of a malformed tuple in `mut.py`. Every row up to DS-m8 had run. `lib` was checked identical, and the remaining eleven rows ran in round 1b.

## Gates (on the committed tree's content, before the commit; `gates.out`)

| Package | Test | Standing comparison | Analyze | Format |
|---|---|---|---|---|
| `packages/jet_cad_floor_plan` (`flutter test --enable-vmservice`) | `06:22 +1854: All tests passed!` (1832 + 22) | `1854 tests; the standing failures and skips, exactly` | No issues | 276 files, 0 changed |
| `apps/restaurant_demo` | `+60: All tests passed!` | | No issues | 0 changed |
| `apps/floor_planner` | `+212: All tests passed!` | | No issues | 0 changed |
| `packages/jet_cad_2d` (`dart test`) | exit 1: its 2 standing failures | `1258 tests; … exactly` | No issues (`--fatal-infos`) | 0 changed |
| `packages/jet_cad_2d_flutter` | exit 1: its 7 standing failures | `1415 tests; … exactly` | No issues | 0 changed |
| `packages/jet_cad_2d_gpu` | `+20: All tests passed!` | `20 tests; … exactly` | No issues | 0 changed |

The planner run includes PA1 to PA3 (run, not skipped), both allocation invariants and the painters' counter tests. The plan's *Unedited and green* list ran unedited: view_test V8 and V15, `planner_shell_test`, `selection_panel_test`, `service/table_select_tool_test`, `service_events_test`, `service_options_test`, `view_events_test`, `controller_test`, `table_groups_gesture_test`, `table_groups_context_test`, and render's `interaction_layer_test` and its siblings.

## Findings

1. **A focused Material `TextField` takes the focus back from a canvas click** (Flutter's behaviour; pre-existing; `autofocus` true or false alike). Its default `onTapOutside` unfocuses the field on a mouse press elsewhere, after the canvas's `requestFocus`, so the route's scope ends up with the primary focus, not the canvas. The probe (`zz_probe_taps_test.dart`) shows it for both values of `autofocus`; with `onTapOutside: (_) {}` the canvas gets the focus. The tests' host fields carry `onTapOutside: keepFocus` and say why. A host with a search field beside the plan should know that one click on the plan after typing leaves the keys with no node of the plan's. This is worth a sentence in the guide (Task 7).
2. **An undo of a delete re-inserts the node last among the root's children** (Task 3's engine finding, seen here for a single table too: `…,671,673,…` became `…,673,675,…,671`). DS1 therefore compares every table's detail after the undo, and DS2 compares the call's undo with the key's byte for byte. The engine is not edited.
3. **`deleteSelection()` deletes whichever tool is active, if idle.** With the Wall tool idle, a selection the host made with `select` is deleted. A part-way shape answers false (DS5). The settle runs first, as for `undo()`, so a typed value lands as its own step before the delete (DS6).
4. **Autofocus is read at mount only** (Flutter's `Focus`). A runtime change of `autofocus` takes effect at the next remount (a mode switch, `resetLayout`, `load`). The view's doc says "Read at each mount".
5. **New internal names beyond the plan's list**, all optional or `@internal`, with nothing new in the barrel:
   - `PlannerShell.shortcuts`, `autofocus`, `tableInspector` and `onDelete`;
   - the typedefs `ShellTableInspector` and `ShellDeleteRegistrar`;
   - `ServiceView.shortcuts` and `autofocus`;
   - `TableSelectTool.idleKeys`;
   - `FloorPlanController.registerDelete`.

   `PlannerView.autofocus` is the plan's.
6. **The inspector's builder is not called while the Selection panel is hidden.** The slot is absent, not offstage, so a host's widget state there is not kept across a hide. The host keeps its state in its own objects, as G-5 asks of overlays.

## Fixes

Applied after the review (`s4-task-6-review.md`) as ruled by the controller, in commit `c2fa7f5` on `claude/exciting-pasteur-9m22jv` (after Task 5's fixes, `d966e67`). Scratch: `/tmp/claude-0/-home-user/428cafca-0083-5012-a7ac-5456349e70a8/scratchpad/s4-fix567/` (`t6_mutants.py`, `mutants.log`, `mlogs/`, `t6run.log`, `pre6/`).

**Code:**
- **R-1 (a)** (`host/floor_plan_view.dart`, `_inspect`): the adapter returns null when another entry of `tableDetails` has the selected table's number (numbers are trimmed, so `7` and ` 7 ` share one). The inspector then shows none, as Slice 2's F-3 read rule and `setTableData`'s refusal have it. The view's doc names the case ("a table whose number another table shares (alone or with it)"); so do the guide's inspector paragraph (with "renumber it first") and the CHANGELOG's bullet. The probe's `tableInspector` block is unchanged, so `check_guide` holds.
- **R-4:** the autofocus docs (`FloorPlanView.autofocus`, `PlannerShell.autofocus`, `PlannerView.autofocus`, `ServiceView.autofocus`, and the guide's sentence) drop "a press on the canvas takes the focus either way". They now say a press asks for the focus, and a focused Material text field keeps it from the canvas on that press unless its `onTapOutside` lets go: the default unfocuses after the canvas asked, so the focus lands on neither; `(_) {}` gives it to the canvas. Render's `InteractionLayer` doc ("requests the focus") was already right and is not edited. `FloorPlanController.deleteSelection`'s doc and the guide: "as the select tool's idle Delete key does, whichever tool is active, while it is idle".

**Tests** (the task's own files):
- `inspector_test.dart` M-H45, as the ruling changes it:
  - `7` alone and ` 7 ` alone join the "none" cases (the builder is never asked);
  - the last block, "` 7 ` alone is one numbered table", is now "` 7 ` alone: none", and `setTableData('7', …)` answers false there;
  - `2` alone shows `2`'s own detail. This keeps R6 (`details[0]`) red, since `1` is the first detail.
- `keyboard_focus_test.dart`:
  - **T6-b** presses Ctrl+E, Cmd+E, Ctrl+P and Cmd+P under `shortcuts: false`. Its host already gives `onExport`, so the shell would bind Export. Each reaches the host once, with no dialog, export or print. In the control, Ctrl+E asks the export dialog and the host hears nothing.
  - New group "the review's killers":
    - **RP1** for `full` and `tablesOnly` (every letter the shell binds, F3, Escape, Delete, Backspace and every chord reach an intent-based `Shortcuts`/`Actions`/`Focus` host, the canvas keeps the focus, the plan is unchanged; control: with the shortcuts the shell takes Ctrl+E and Ctrl+P);
    - **RP12** (`tablesOnly`, a round table armed: R is the tool's, M bubbles, W and Escape reach the host, the tool stays symbol);
    - **RP5** for R-3 (`shortcuts: true`: `delete: false` refuses the call; the Wall tool idle with the host's selection: the key deletes nothing, the call deletes).
  - All three are landed as the reviewer wrote them, with the helpers renamed to `mountIntentHost`, `kIntentKeys` and `sendActivator`.

**Mutants** (`mutants.log`; both Task 6 files; file restored and compared byte-equal):

| Mutant | Result | Killer |
|---|---|---|
| F6-1 the shared-number check removed (the review's R17 inverse) | RED (1) | M-H45 |
| F6-1b the check counts the table itself | RED (5) | M-H45, T6-d and others |
| R6 the adapter reads `details[0]` | RED (3) | M-H45 (2 alone), T6-d |
| R1 the design mode's file chords ungated | RED (3) | T6-b; RP1 full; RP1 tablesOnly |
| R14 `onDelete` registered only under `shortcuts: false` | RED (1) | R-3 (RP5) |

**Gates before the commit** (`pre6/`): planner `flutter test --enable-vmservice` `05:01 +1873: All tests passed!` (1869 + 4); standing comparison "1873 tests; the standing failures and skips, exactly"; analyze "No issues found!"; format "276 files (0 changed)"; demo `00:37 +68: All tests passed!`. The full gates ran after the last commit (see `s4-task-7-report.md`, Fixes).
