# Slice 4, Task 7: the demo, the guide, the probe, the CHANGELOG, the gates (implementer's report)

- **Branch:** `claude/exciting-pasteur-9m22jv`, from `305285f` (Tasks 1 to 6 and the fixes of Tasks 1 to 4; Tasks 5 and 6 under review elsewhere).
- **Commits** (pushed as `305285f..24af8f7`):
  - `9c24a85` feat(demo): the host's own chrome and keys (Slice 4, Task 7)
  - `2328aa6` docs: the host guide's bars, capabilities and keys, and their probe (Slice 4, Task 7)
  - `24af8f7` docs: the CHANGELOG's Unreleased gains Slice 4 (Task 7)
- **Environment:** Flutter 3.47.6 at `/root/sdk/flutter/bin`, `CI=true`. Scratch: `/tmp/claude-0/-home-user/428cafca-0083-5012-a7ac-5456349e70a8/scratchpad/s4t7/` (`demo_mut/` the demo mutant runner `mut.py`, `mutants-final.log`, `logs/`; `gates/` `gates.sh`, `gates.out` and the per-package logs and JSON runs; `host_probe.log`, `old_host_probe.log`, `probe_mutant.out`; `build-*.log`; `smoke/` the Playwright scripts, `smoke.out`, `focus_nosem.out`, `shots/`; `web/` the demo's web build the smoke served).
- **Scope:** no edit of the planner's `lib/` or its tests, of `jet_cad_2d_flutter`, or of the engine. No `analysis_options.yaml` touched or committed (`git status` clean after each commit). Not written, as instructed: the results note, STATUS, the roadmap row.

## 1. The demo (`apps/restaurant_demo`, `9c24a85`)

Files: `lib/main.dart`, `lib/demo_strings.dart` (en, de, tr), `test/host_chrome_test.dart` (new).

- **Editor switch** (side panel, design mode): `Full` (default), `Tables`, `Read only` → `editorCapabilities` through `enum DemoEditor` (each holding its profile). Under `Read only` the editor bar is `kReadOnlyEditorBar` = `FloorPlanEditorBar(actions: [print, export, zoom])` (a real use of `FloorPlanEditorBar` / `FloorPlanEditorAction`: no OSNAP where nothing is drawn).
- **Table inspector** (`tableInspectorBuilder`, under `Tables` only): `PosIdField`, a "POS id" field; Enter writes `setTableData(number, {...data, 'id': id})` (other data kept; empty unlinks), logged `Salon: table 2 is salon-2` / `unlinked`.
- **Service bar:** the planner's bar carries the area's name as `leading` (`FloorPlanServiceBar(leading: [...])`); **Own bar** switch → `FloorPlanServiceBar(visible: false)` and the demo's row above the view: Undo/Redo by `canUndo`/`canRedo`, Merge by `mergeCandidate`, Split by `selectedGroup`, Export by the demo's dialog + `exportPlan`, Print by `printPlan`, labelled with the planner's own `FloorPlanStrings`.
- **Own export dialog** switch → `onExportDialog: showDemoExportDialog` (a `SimpleDialog` of PDF / PNG 96 / 150 / 300, the initial marked); `onPageFlowError` logs `Salon: export or print failed (…)`.
- **Find a table** field in the app bar: Enter selects the table and `centerOn`s it, keeping the focus (`onEditingComplete: () {}`); `onTapOutside: (_) {}` so a press on the app's buttons leaves it focused.
- **The plan's keys** switch (default on): off → `shortcuts: false`, `autofocus: false`, and the demo's keys on a `Focus(onKeyEvent:)` around the view: Ctrl/Cmd+Z → `undo()`, Ctrl+Y and Ctrl/Cmd+Shift+Z → `redo()`, Delete/Backspace → `deleteSelection()`, Escape → `selectTool(select)` (when another tool is active) else `select({})`; each logged `Salon: Delete, the demo's key`. Skipped while a text field inside the view has the focus.
- `RestaurantDemo` / `DemoHome` take an optional `printer` (tests).

**Deviations from the plan's demo list (each to keep the existing demo tests unedited):**
1. The export hook sits behind its own switch (`Own export dialog`, default off): always on, it would replace the Material dialog D8 (`demo_test.dart:270`) drives by its keys.
2. `autofocus` follows the Keys switch instead of being `false` always: `events_test.dart` DE7 presses Delete relying on the canvas's start-up focus.
3. Not used by the demo: `activeTool` is read (Escape), `selectTool` used; `editorSelectedTables` and `FloorPlanServiceAction` are not used by the demo (the guide and the probe use them).

With every switch at its default the demo is today's but for the area's name at the service bar's start. **The 60 existing demo tests pass unedited**: `01:06 +60: All tests passed!` with the new `lib` before the new test file existed, and inside the final gate run (68 with the new 8).

**Tests** (`test/host_chrome_test.dart`, Salon sample, screen points from `tableDetails` + `worldToGlobal`):

| Test | What |
|---|---|
| DH1 | Full: `tool-wall`, `layers-panel` present, no `pos-id` for a selected table. Tables: no wall row, `tool-select`, `tab-symbols`, no `layers-panel` / `page-preset`; the inspector writes `salon-2` beside `seats_note` (other data kept); another table's field empty; emptied → unlinked. |
| DH2 | Full control: a drag moves 4. Read only: no `toolbar-undo`, no `osnap-text`, `zoom-text`, Print left of Export; a click selects; drag, Delete, W change `designJson()` nothing, `canUndo` false, `deleteSelection()` false. |
| DH3 | `bar-area` "Salon" inside `service-bar`; the planner's Merge as reference; Own bar: `service-bar` gone, `own-bar-row` bottom = `canvasRect.top`; own Merge disabled for one table, then for {1,2} gives the same groups and log line as the planner's; Split disabled for a table in no group, then splits G1; own Undo/Redo of a service drag. Off: the planner's bar back. |
| DH4 | Own dialog at `toolbar-export` (no `export-dialog`), PDF marked; PNG 300 → `lastExport` `salon.png`, bytes **equal** to `exportPlan(PNG 300, name: 'salon')`, size ≈ 300/96 of a PNG 96 (±2 px); selection mode Ctrl+E → the demo's dialog with PNG 300 remembered; Cancel exports nothing; own bar's Export → dialog → PNG 96 export; switch off → the Material dialog. |
| DH5 | A `JammedPrinter` (page format typed `Object`, so no `pdf` import): the editor's Print and the own bar's Print each log `Salon: export or print failed (Bad state: jam)`, no uncaught error. |
| DH6 | Keys on control: the plan's Delete, no demo line. Off: Delete (via `deleteSelection`), Ctrl+Z, Ctrl+Y are the demo's (log + effect); W leaves Select; `selectTool(wall)` then Escape → select, Escape again → no selection; under Tables, Backspace typed in `pos-id` edits the text and deletes no table. |
| DH7 | The view focused at start; a mode switch re-focuses the view (control); keys off: after the plan had the focus, a switch leaves it unfocused both ways; the field focused, a **mouse** press on the mode toggle keeps it in both settings; Enter on `7` selects and centres 7 (< 1 px from the canvas centre), keeps the focus; `99` logs not found. |
| DH8 | The new words in German and Turkish. |

**Demo mutants** (each applied in `lib/main.dart`, killer by `--plain-name`, file restored and byte-compared; final round on the committed tree, `demo_mut/mutants-final.log`), all red:

| Mutant | Killer | Seen |
|---|---|---|
| DM1 readOnly mapped to `full` | DH2 | `designJson` differs (the drag moved 4) |
| DM2 inspector under every profile | DH1 | `pos-id` found under Full |
| DM3 tables mapped to `full` | DH1 | `tool-wall` found |
| DM4 own Merge always enabled with `selectedTables` | DH3 | onPressed not null for one table |
| DM5 Own bar keeps the planner's bar | DH3 | `service-bar` found |
| DM6 no `onExportDialog` | DH4 | `export-dialog` found |
| DM7 no `onPageFlowError` | DH5 | the uncaught `Bad state: jam` fails the test |
| DM8 `shortcuts: true` always | DH6 | no demo Delete line |
| DM9 `autofocus: true` always | DH7 | `planFocused` true, expected false |
| DM10 no text-field guard | DH6 | table 5 deleted by Backspace |
| DM11 default `onTapOutside` | DH7 | the field unfocused by the mouse press |
| DM12 Read only keeps today's bar | DH2 | `osnap-text` found |
| DM13 own Undo calls `redo` | DH3 | table 3 not back |
| DM14 search without `centerOn` | DH7 | 173.7 px off the centre |
| DM15 inspector drops other data | DH1 | `{id: salon-2}` only |
| DM16 Escape never returns to Select | DH6 | tool stays wall |

DM11 first survived: flutter_test taps are touch, and the default `onTapOutside` unfocuses only for a mouse off the web; DH7's toggle presses were made `PointerDeviceKind.mouse`, then red.

## 2. The host guide (`2328aa6`, marked *Unreleased on `main`*)

- § 8 gains **The bars**, **The editor's capabilities**, **Keyboard and focus** (C-1 to C-8, S-1 to S-24 with S-16 as ruled): `visible`, `actions` order, gaps and today's rules, host items; actions never the keys (S-20); which keys a host field in a bar keeps; a host-built bar from `canUndo`/`canRedo`/`undo()`/`redo()` (S-4's idle wait), `mergeCandidate` (S-5), `selectedGroup`, `exportPlan`/`printPlan` (one at a time per controller, null/false cases, errors in the Future, S-7) with `FloorPlanExportChoice`/`Format`/`Dpi`; `onExportDialog` at every entry point; `onPageFlowError` and its absence (S-8). The three profiles as a table and every field (S-9 to S-15), `copyWith` and its null, the filter by `==`, a run-time change (fallback, left column, a rulers toggle cancelling a pending shape), `activeTool`/`selectTool`, the inspector (S-18) and `editorSelectedTables` (S-17), Material inside the editor (C-8), limits (a refused R/M bubbles while a symbol is armed; `selectTool(symbol)` only re-arms). `shortcuts: false` and what a gesture keeps, `deleteSelection()` and when it answers false, `autofocus` read at each mount and Flutter's rule that autofocus never takes the focus from a focused field; **a host's keys above the view also see the planner's panel fields' keys** (found while building the demo: skip them while a text field has the focus); a Material `TextField`'s `onTapOutside` after a press on the plan (Task 6 finding 1).
- § 4's view block gains the eight parameters and names them; § 8's list points to the subsections; § 11 gains "capabilities are not a security boundary" (V-5) and "with `shortcuts: false` nothing deletes in the editor but `deleteSelection()`". Two positional references ("the last four") reworded since eight arguments now follow.
- **Probe** (`tool/ci/host_probe/lib/main.dart`, `FloorScreen`): every new block verbatim: `serviceBar`/`editorBar` statics, `posServiceBar`, `exportPng`/`printFloor`, the own bar shown in the selection mode by a `ValueListenableBuilder` on the mode, `askExport`, `arrangeTables` (`tablesOnly.copyWith(rotate: false, symbolFilter: roundTables)`, a static filter), the run-time `Switch`, `toolStrip`, `tableInspector`, the `editorSelectedTables` line, `posKey` on a `Focus` around the body (moved there so § 9's existing `Expanded(Theme(FloorPlanView(` block still matches).
- `check_guide`: "all 48 code blocks are in the host probe". **Mutant:** `roundTables`' `'.round'` → `'.square'` in the probe → exit 1, "not in the host probe: dart: /// The manager arranges the tables but never turns them, …"; restored from a copy (`cmp` equal) → exit 0 (`probe_mutant.out`).

## 3. CHANGELOG (`24af8f7`)

Unreleased: the intro names Slices 1 to 4, no stored format change in Slices 3 and 4; bullets The bars, A bar of the host's own, The editor's capabilities, The table inspector, Keyboard and focus; **A fix a 0.3.0 host may notice** (S-4: `undo()`/`redo()` idle mid-shape; one page-flow guard per controller; the flows read `exportName`/`printer` at their start, Task 1 finding 2); `jet_cad_2d_flutter`: `SelectGates`, `SelectTool.gates` and `deleteSelection`, `GripCache(gates:)` with `moveGripsLive`, `stretchGripsLive`, `gatesChanged()` ("give the tool and the cache the same gates object"), `InteractionLayer.autofocus`; `editor.dart`'s additions, each optional; known limits extended.

## 4. Gates (real results, at `24af8f7`; `gates/gates.out`)

| Package | Tests (standing comparison, CI's form) | Analyze | Format |
|---|---|---|---|
| `packages/jet_cad_2d` (`dart test`) | exit 1 (its 2 standing); "1258 tests; the standing failures and skips, exactly" | `--fatal-infos`: No issues | 170 files, 0 changed |
| `packages/jet_cad_2d_flutter` | exit 1 (its 7 standing); "1415 tests; … exactly" | No issues | 227 files, 0 changed |
| `packages/jet_cad_2d_gpu` | `+20: All tests passed!`; "20 tests; … exactly" | No issues | 10 files, 0 changed |
| `packages/jet_cad_floor_plan` (`--enable-vmservice`) | `05:48 +1854: All tests passed!`; "1854 tests; … exactly" | No issues | 276 files, 0 changed |
| `packages/jet_cad_restaurant_symbols` | `+97: All tests passed!`; "97 tests; … exactly" | No issues | 15 files, 0 changed |
| `apps/floor_planner` | `01:35 +212: All tests passed!`; "212 tests; … exactly" | No issues | 47 files, 0 changed |
| `apps/restaurant_demo` | `00:37 +68: All tests passed!`; "68 tests; … exactly" | No issues | 9 files, 0 changed |
| `tool/ci` | `dart test` `+63: All tests passed!` | CI's paths, `--fatal-infos`: No issues | CI's paths incl. `host_probe/lib`: 11 files, 0 changed |

- `check_guide`: exit 0, all 48 blocks.
- **Host probe:** pushed, then `tool/ci/host_probe.sh file:///home/user/jet-cad 24af8f754e36703a517501e19edd6ee2047ae8f6` (HEAD = origin): lock "40 packages, none of flutter_scene, flutter_gpu, flutter_gpu_shaders, scene, jet_cad_2d_gpu", analyze "No issues found!", "✓ Built build/web", "host probe: no GPU renderer, no build hook; build/web is 42M", exit 0.
- **v0.3.0's probe:** `tool/ci/old_host_probe.sh v0.3.0`: "No issues found!", "old host probe: v0.3.0's main.dart analyses against 24af8f7…", exit 0.
- **Web builds** (`rm -rf build && flutter build web`): restaurant demo ✓, 42M, `main.dart.js` 3,795,707 B (Slice 3: 3,752,103); floor planner ✓, 42M, 3,601,704 B (Slice 3: 3,590,019); both `assets/packages` = jet_cad_floor_plan, jet_cad_restaurant_symbols, no flutter_scene, `cad.shaderbundle` 0 times in `main.dart.js`. The build dirs were removed after measuring (the demo's `build/web` copied to the scratch for the smoke), as was the probe's.
- Note: plain `dart analyze` over all of `tool/ci` reports errors in `host_probe/lib/main.dart` when the probe's package config is stale (it resolves the probe against the last `host_probe.sh` SHA); CI analyses only its named paths, which are clean. Not a defect; worth knowing when gating locally.

## 5. Web smoke check (Chromium 1194 via Playwright, `locale: 'en-US'`, 1600×1000, canvaskit served locally; `smoke/smoke.out`, `shots/`)

All checks PASS, **no console error** in either run:
- `01`: the design, every switch default: the editor bar is today's (Export, Print, Undo, Redo, OSNAP, zoom), the full palette, Layers and Page panels.
- `02`: the service: the planner's bar with "Salon" at its start, then its icon buttons.
- `03`–`05`: table 7 found (centred), dragged (`Salon: moved {7}`); Own bar on: the row "Salon Undo Redo Merge Split Export… Print…" replaces the planner's bar; its Undo put 7 back and enabled Redo.
- `06`: tables 1 and 2 selected, own Merge → `Salon: Merged {1, 2} as G1` (the group frame "1+2" drawn).
- `07`: own Export → the demo's dialog (PDF ✓, PNG 96/150/300, Cancel); PNG 96 → `Salon: exported salon.png, 43628 bytes`.
- `08`: Own export dialog on, Ctrl+E on the canvas → the demo's dialog, not the Material one (its initial PDF: `exportPlan` leaves the remembered choice alone, as S-7 says); Cancel.
- `09`–`12`: Tables: only the Select row and the Tools/Symbols tabs, no Layer or Page panel; the Symbols tab offers tables only; a "Square table, 2 seats" placed and numbered 12 (`table 12 added`), turned 90° right (rotation 270 shown), renumbered 21, linked from the inspector → `Salon: table 21 is salon-21`; no Mirror, no layer picker in the Selection panel.
- `13`, `13a`: Read only: no left column, the bar "Print, Export, zoom" with no Undo and no OSNAP, the Layers and Page panels disabled, table 7's Number and Rotation read only with no ±90; a drag, Delete and W left the canvas pixel-identical and logged no move or removal.
- `14`, `15`: The plan's keys off: W leaves Select; Delete → `Salon: Delete, the demo's key` and `table 7 removed`; Ctrl+Z → `Salon: Ctrl+Z, the demo's key` and `table 7 added`.
- **The search field across a mode switch:** for a mouse user (`focus_nosem.js`, no semantics tree), typing 7, clicking Service, typing 5, clicking Design, typing 3 left "753" in the focused field (`17-focus-nosemantics-*.png`): it keeps the focus. **With the semantics tree on** (how `smoke.js` finds widgets), clicking the toggle's DOM node blurs the input and the engine closes the text connection (`EditableText.connectionClosed` unfocuses), so the field lost the focus (`INFO` line). Flutter web behaviour in its accessibility mode, independent of jet-cad; recorded, not fixed.

## Findings

1. **A host's keys above the view see the planner's own text fields' keys.** Bindings on an ancestor of `FloorPlanView` receive Delete/Backspace typed in the Selection panel's fields (and in a host inspector) before the app-level text shortcuts, so a naive host Delete binding deletes tables while staff type. `ShellShortcutGuard` guards only the planner's own bindings. The demo and the probe skip their keys while an `EditableText` has the focus; the guide says so. A possible follow-up (not this task's): guard Delete/Backspace for host ancestors in the panels' fields.
2. **Web, semantics on:** a click on a button's semantics node unfocuses a focused text field (above). Mouse users without the semantics tree are unaffected.
3. The demo's deviations listed in § 1 (the own dialog behind a switch, `autofocus` on the Keys switch), each forced by an existing demo test that must pass unedited.
4. No defect found in the planner's `lib` during this task.

## Owed to the human (from the plan's exit gate)

A look at the demo's three editor profiles and its own bar on a tablet and a terminal; the German and Turkish read of the demo's new strings (Host / Editor / Voll / Tische / Nur lesen / Eigene Leiste / Eigener Exportdialog / Tasten des Plans / Tisch suchen / Kassen-ID; Ana uygulama / Düzenleyici / Tam / Masalar / Salt okunur / Kendi çubuğu / Kendi dışa aktarma penceresi / Planın tuşları / Masa bul / Kasa kimliği, and the log lines).

## Fixes

Finding 1 is fixed in the planner, as ruled, by commit `8f45473` on `claude/exciting-pasteur-9m22jv`. It follows Task 5's review fixes (`d966e67`) and Task 6's (`c2fa7f5`), and the three were pushed as `24af8f7..8f45473`.

Scratch: `/tmp/claude-0/-home-user/428cafca-0083-5012-a7ac-5456349e70a8/scratchpad/s4-fix567/`. It holds:
- `t7_mutants.py`, `mutants.log` and `mlogs/`;
- `t7-before.log`, the new test on the unfixed planner;
- `t7-demo-mut.log`;
- `gates/gates.sh` and `gates/gates.out`, with the per-package logs and JSON;
- `host_probe.log`.

**Why it happened.** Flutter binds the text-editing keys once, through `WidgetsApp`'s `DefaultTextEditingShortcuts`, at the top of the app. A key typed into a field bubbles through every ancestor before it gets there. A host's `Shortcuts` above `FloorPlanView` therefore took Delete, Backspace, Space and any letter the shell's own `ShellShortcutGuard` does not list, such as K or a digit. The field never saw those keys.

**The fix** (`shortcut_guard.dart`, `host/floor_plan_view.dart`):
- `PlannerTextKeys` wraps the whole view, always, in both modes, outside the theme scope. It is two layers:
  - **Inner:** `DefaultTextEditingShortcuts` again, nearer than any host binding. An editing key in an editable field is handled by the field's own actions: Backspace, Delete, the arrows, select all, copy and paste. Enter and Space are stopped there for the text input, as Flutter's own map does.
  - **Outer:** a `Shortcuts` that maps three kinds of key to `DoNothingAndStopPropagationTextIntent`:
    - a key-down or repeat that types a printable character, with no Control or Meta held;
    - Delete;
    - Backspace.
- Only a focused `EditableText` answers that intent, with `DoNothingAction(consumesKey: false)`. In any field inside the view the key therefore stops and goes to the platform's text input. That includes a read-only field, whose own delete actions refuse the key.
- With the focus on the canvas or on a button no action is found, so the key bubbles to the host as before.
- The shell's chords, letters and Escape, and `ShellShortcutGuard`, sit nearer the fields, so jet-cad's own key behaviour is unchanged. Ctrl+Z in a panel field is still stopped by the guard, not given to the field's text undo.
- A chord with Control or Meta held that no field takes still reaches the host.

**Test** (`test/host/host_text_keys_test.dart`, new, 7 tests). A host `Shortcuts` + `Actions` + `Focus` sits above a `FloorPlanView` on the editor fixture. It binds Delete, Backspace, W, K, 1, Space, Enter and the chord Ctrl+K. A host `TextField` sits in the service bar's `leading`.
- **Design mode, with `shortcuts: false` and with `true`.** The fields tested are the table number, the page scale, a layer's rename (opened by a double tap) and the Symbols search. In each:
  - `123` with the cursor at 2: Backspace leaves `13` and Delete leaves `1`;
  - W, K, 1, Space and Enter are not handled, so they go to the text input;
  - no host intent fires and the field keeps the focus;
  - Ctrl+K still reaches the host.
- **`readOnly`.** In the read-only table number, Backspace, Delete and K edit nothing and fire no host intent.
- **Selection mode, both `shortcuts` values.** The host's bar field behaves the same.
- **Both modes, `shortcuts: false`, the canvas focused.** Delete, Backspace, W, K, 1, Space and Enter each fire the host's intent once. The plan and the selection are unchanged and the canvas keeps the focus.

On the unfixed planner (`t7-before.log`), five of the seven tests were red: Backspace left `123`, and the host's Delete, Backspace and K fired. The two canvas tests, which are the control, were green.

**Mutants** (`mutants.log`; each run on the new file; every file restored and compared byte-equal):

| Mutant | Result |
|---|---|
| T7-a the view not wrapped | RED (5) |
| T7-b `DefaultTextEditingShortcuts` not re-established | RED (4) |
| T7-c the outer stop layer removed | RED (5) |
| T7-d the typing activator removed | RED (5) |
| T7-e Delete and Backspace not stopped | RED (1): the read-only field |
| T7-f a chord counted as typing (the Control/Meta check dropped) | RED (4): Ctrl+K from a field |
| T7-g a key-up accepted | SURVIVED. It is equivalent for a host's `SingleActivator`, which fires on key-down only. Kept, so a key-up is never swallowed. |

**Guide, probe, demo and CHANGELOG:**
- **Guide § 8, *Keyboard and focus*.** "Your keys above the view see the planner's fields too" is replaced by "A field inside the view keeps its keys". It covers both modes, whatever `shortcuts` says, and names the panel fields, the Symbols search, a layer's rename, the TEXT entry and a host field in a bar or in the inspector. `posKey` needs no guard for them. A new paragraph, "A field of yours outside the view", keeps the advice for the host's own fields and gives the `EditableText` check inline.
- **`posKey`.** It loses its `typing` lines, both in the guide's block and in the probe (`tool/ci/host_probe/lib/main.dart`), which stay in step. `check_guide` reports "all 48 code blocks are in the host probe".
- **Demo.** `_demoKey` (`apps/restaurant_demo/lib/main.dart`) loses its `typing` guard. Its `Focus` wraps only the view, so no field of the demo's own sits under it.
  - The demo's DH6 ("a key typed in the inspector stays the field's") passes unedited and now pins the planner's fix. With T7-a applied, DH6 is red: table 5 is deleted by Backspace in `pos-id` (`t7-demo-mut.log`).
  - Task 7's demo mutant DM10 ("no text-field guard") is now the code itself and no longer applies.
- **CHANGELOG.** The *Keyboard and focus* bullet gains one sentence.

**Gates after the last commit** (`gates/gates.out`, HEAD `8f4547376dc8ddf32dc81fb98798d527dbb5c4ad`):

| Package | Tests (standing comparison) | Analyze | Format |
|---|---|---|---|
| `packages/jet_cad_2d` (`dart test`) | exit 1 (its standing failures); "1258 tests; the standing failures and skips, exactly" | `--fatal-infos`: No issues found! | 170 files, 0 changed |
| `packages/jet_cad_2d_flutter` | exit 1 (its standing failures); "1415 tests; … exactly" | No issues found! | 227 files, 0 changed |
| `packages/jet_cad_2d_gpu` | `00:00 +20: All tests passed!`; "20 tests; … exactly" | No issues found! | 10 files, 0 changed |
| `packages/jet_cad_floor_plan` (`--enable-vmservice`) | `05:02 +1880: All tests passed!` (1854 + 15 + 4 + 7); "1880 tests; … exactly" | No issues found! | 277 files, 0 changed |
| `packages/jet_cad_restaurant_symbols` | `00:02 +97: All tests passed!`; "97 tests; … exactly" | No issues found! | 15 files, 0 changed |
| `apps/floor_planner` | `01:17 +212: All tests passed!`; "212 tests; … exactly" | No issues found! | 47 files, 0 changed |
| `apps/restaurant_demo` | `00:36 +68: All tests passed!`; "68 tests; … exactly" | No issues found! | 9 files, 0 changed |
| `tool/ci` | `dart test` `00:05 +63: All tests passed!` | CI's paths, `--fatal-infos`: No issues found! | CI's paths incl. `host_probe/lib`: 11 files, 0 changed |

- `check_guide`: exit 0, "all 48 code blocks are in the host probe".
- **Host probe** (pushed first; `tool/ci/host_probe.sh file:///home/user/jet-cad 8f4547376dc8ddf32dc81fb98798d527dbb5c4ad`, `host_probe.log`): exit 0. The lock has "40 packages, none of flutter_scene, flutter_gpu, flutter_gpu_shaders, scene, jet_cad_2d_gpu"; analyze reports "No issues found!"; the build reports "✓ Built build/web" and "host probe: no GPU renderer, no build hook; build/web is 42M". The probe's `build/` was removed afterwards.
- `git status` was clean after the gates and after the probe. No `analysis_options.yaml` was touched or committed.
