# Slice 4: the bars, the keyboard, the editor's capabilities (independent final review)

- **Range reviewed:** `4e3ed91..8f45473` (17 commits: the plan, Tasks 1 to 7 and their fixes), branch `claude/exciting-pasteur-9m22jv`.
- **Where:** my own clones, `/home/user/review-s4-final` at `8f45473` (gates, probes, mutants) and `/home/user/review-s4-final-base` at `4e3ed91` (the differential's base side). Both are deleted now. Nothing was edited, committed or pushed in `/home/user/jet-cad`; this file is the only one written there.
- **Scratch:** `/tmp/claude-0/-home-user/428cafca-0083-5012-a7ac-5456349e70a8/scratchpad/rv-s4-final/`:
  - `gates.sh`, `gates.out`, `gates/` (per-package logs, JSON runs, the host probes' logs);
  - the differential: `zz_s4f_diff_test.dart`, `diff-base.txt`, `diff-base2.txt` (a second base run), `diff-tip.txt`, `diff.out`, `diff.norm.out`; `zz_s4f_hostkeys_test.dart`;
  - the probes: `zz_s4f_probe_test.dart` (`probe.log`), `zz_s4f_frame_test.dart` (`frame.log`, `frame2.log`), `zz_s4f_swap_test.dart` (base form) and `zz_s4f_swap_test.tip.dart`;
  - the killers: `zz_s4f_killer_test.dart` (K1 to K3);
  - the mutants: `mutate.py`, `mutants.out`, `mutants2.out`, `mutants3.out`, `mut/` (one log and JSON run per mutant).
- **Environment:** Flutter 3.47.6 at `/root/sdk/flutter/bin`, `CI=true`.

## Verdict

**Approve with fixes.** The slice does what C-1 to C-8 and S-16 ask. Every gate is green with the standing sets exact. Invariant 1 holds, and the barrel gains exactly the ten names R-1 allows. With no new parameter the planner behaves and draws exactly as at `4e3ed91`: 70 traced steps and 62 key readings are identical, but for the one intended difference (S-4). Every edit path I re-enumerated is gated, including runtime changes with a field, a menu or a gesture open.

Two defects sit where the tasks meet, and both need a `lib` fix before merge:

- **F-1 (Medium):** a capability change that swaps or removes both side columns at once re-mounts the canvas. The plan then re-fits to the page, and the user's zoom and pan are lost.
- **F-2 (Medium):** with a bar hidden, a host that swaps the view's controller and disposes the old one in the same step gets a debug assertion. `4e3ed91` does not.

Each fix is small, and I tried the F-1 fix in my clone. F-3 and F-5 are doc corrections. F-4, F-6 and F-7 are small and may land in the same commit or be recorded. F-8 lists what the exit gate still owes.

## 1. P-1, invariant 1, R-1, tests edited

- **v0.3.0's probe:** `tool/ci/old_host_probe.sh v0.3.0`, run after `host_probe.sh` at the full SHA, reports `No issues found!` and `old host probe: v0.3.0's main.dart analyses against 8f4547376dc8ddf32dc81fb98798d527dbb5c4ad`, exit 0.
- **Signatures:** no existing signature, `==`, `hashCode` or `toString` changed. I checked the removed lines of `git diff 4e3ed91 8f45473` over the host barrel, `jet_cad_2d_flutter`'s `lib` and the planner's public files:
  - `GripCache(…, {this.objects})` and `SelectTool({this.moveResolver})` each gain one optional named parameter;
  - `InteractionLayer` gains `autofocus = true`;
  - `DocumentToolbar` keeps its constructor and adds `.groups`;
  - `FloorPlanView`'s constructor only appends;
  - the controller's one changed signature is `@internal canvasMeasured`, which gains an optional `{Offset? chrome}`;
  - `floorPlanCanvasSeeds` (`@visibleForTesting`) keeps its type;
  - `lib/editor.dart` is untouched, and the engine is untouched.
- **R-1:**
  - **The barrel** gains exactly `FloorPlanExportChoice`, `FloorPlanExportFormat`, `FloorPlanExportDpi`, `FloorPlanServiceBar`, `FloorPlanServiceAction`, `FloorPlanEditorBar`, `FloorPlanEditorAction`, `FloorPlanEditorCapabilities`, `FloorPlanSymbol` and `FloorPlanTool`. All are named by C-1, C-2, C-3 and C-5.
  - **The controller's** new public members are `mergeCandidate`, `activeTool`, `selectTool`, `editorSelectedTables`, `exportPlan`, `printPlan` (C-3, C-5, C-6) and `deleteSelection` (S-16, C-3 as amended). Its other new members (`pageFlowReady`, `isDisposed`, `registerIdle`, `registerTools`, `registerDelete`, `toolChanged`, `canvasAssumed`) are all `@internal`.
  - **The view** gains exactly the eight parameters.
  - `FloorPlanSymbol.of(SymbolEntry)` is `@internal`.
- **Tests edited:** `git diff --stat --diff-filter=M 4e3ed91 8f45473 -- '**/test/**'` lists one file, `barrel_test.dart`, with +10 lines, all in B1's name list (3 + 4 + 3). The plan allows exactly that.
  - No golden, allocation test or painter-counter test is touched.
  - Every other test file in the range is new.

## 2. The P-6 differential

`zz_s4f_diff_test.dart` uses only API present at `4e3ed91` (plus the editor fixture copied in as `zz_editor_fixture.dart`). It mounts a `FloorPlanView` with every 0.3.0 callback, a fake printer and `onExport`, and no Slice 4 parameter, on the editor fixture under `editorCamera()`.

It then scripts the following run and traces each step. A trace records the plan's codec hash, the service layout's hash, the selection, `selectedTables` and `selectedGroup`, `canUndo` and `canRedo`, `dirty`, `revision`, the scale, `canvasRect`, the primary focus, every callback and stream event, every keyed control's state, and an FNV hash of the view's RGBA pixels.

- **The editor:**
  - a click and a body drag on a wall;
  - Ctrl+Z, Ctrl+Y, Ctrl+Shift+Z and Cmd+Z;
  - the column's end-grip drag, Backspace, and two undos;
  - table 1 clicked and dragged, then ±90 and Mirror;
  - **the number field focused with `123`**: Backspace, Delete, the arrows, Home, End, W, K, 1, Space, F3, Ctrl+A, Ctrl+C, Ctrl+Z, Ctrl+Shift+Z, Ctrl+E (the dialog opened and cancelled) and Escape;
  - the number committed as 12, and a rotation of 33;
  - **with the canvas focused**: Tab, ArrowDown, Space, Enter, K and 1;
  - Delete and its undo;
  - a window band, a crossing band, Escape, and a band followed by Delete;
  - `controller.undo()`, then `redo()` and `undo()`;
  - a room's name, a dimension's kind, a wall's thickness and justification, a layer added, the page's grid and a page swatch;
  - **every tool letter** (V L P R B W D N G M S I C A T), each followed by two clicks and two Escapes, then F3 and F;
  - **a polyline part-way and `controller.undo()` / `redo()`**, the S-4 case;
  - Export through `toolbar-export` and the Material dialog (PNG at 96), then Ctrl+E with the remembered choice;
  - Print and Ctrl+P on the fake printer;
  - the Symbols tab: a table armed, then R, M and a placement.
- **The selection mode:**
  - the first frame after the switch;
  - a tap on a table, a tap on the floor and a double tap;
  - a mouse drag of a table;
  - `service-undo` and `service-redo`, then the three undo/redo chords;
  - a hover;
  - a Ctrl-click multiple selection, Merge (the host merges), a tap on a group member and Split;
  - a secondary click and Escape;
  - `service-export` and Ctrl+E (PDF);
  - `service-print` and Ctrl+P;
  - a touch drag, a long press and `resetLayout()`.
- **Then:**
  - four mode switches, each reading the first frame (`worldToGlobal` and the painted position) and the settled one;
  - `load(designJson())`;
  - design again.

**Result:**

- **The base is deterministic.** Two base runs are byte-identical.
- **Base against tip,** after normalising one known structural nit:
  - **All 70 traced steps are identical:** the plan, the layout, the selection, the events, the focus, the keyed states and **every pixel hash**.
  - **All 62 sub-step readings are identical:** each key's `handled`, the field's value and selection, the focus, and the status line.
  - **The first frame of every mode switch is exact** on both commits: before, frame 1, painted and settled are equal.
- **The only differences:**
  1. **S-4, the intended one.** At step #36, the base's `controller.undo()` with a polyline part-way undoes the step beneath the shape (the plan changes and `canRedo` becomes true). At the tip it does nothing. At #37 the base's `redo()` brings the plan back to the tip's hash. From there on `revision` reads 2 lower at the tip, because two notifications fewer were made; nothing else differs. The base's #36 also shows the bug S-4 fixed: the plan changed and the canvas did not (the pixel hash is unchanged).
  2. `page-scale`'s `TextField.enabled` reads `true` at the tip and `null` at the base. This is Task 5 review R-6: the same behaviour, structurally different.
- **The `PlannerTextKeys` wrapper,** for a 0.3.0 host with **no** `Shortcuts` above the view: the keys above, typed in the field and on the canvas, read the same on both commits. **It does change a 0.3.0 host that has bindings above the view.** `zz_s4f_hostkeys_test.dart` puts a host `Shortcuts` binding Delete, Backspace, K and Ctrl+A above the view, with `123` in the number field and the cursor at 2:

  | Key | `4e3ed91` | `8f45473` |
  |---|---|---|
  | Backspace | `123`, the host fires | `13`, the host is silent |
  | Delete | `123`, the host fires | `1`, the host is silent |
  | K | the host fires | not handled: the text input gets it |
  | Ctrl+A | the host fires | the field selects all |

  This is the intended fix (Task 7 finding 1), but it is a change a 0.3.0 host can notice: F-5.

## 3. Interplay: where the tasks meet

Probes in `zz_s4f_probe_test.dart` (`probe.log`), `zz_s4f_swap_test*.dart` and `zz_s4f_killer_test.dart`. All readings below are from real runs at `8f45473`.

| # | Case | Reading | Holds |
|---|---|---|---|
| PR1 | A capability change toggles one column (`full` to `readOnly`: the left column goes, the right stays) | PlannerView and canvas kept; camera unchanged; the plan moves 240 px left (486 to 246) | yes, but see F-3 for the docs |
| PR1 | **Left only ↔ right only** (`full` without panels ↔ `readOnly`) | **PlannerView and InteractionLayer re-mounted; camera `0.37, e = -7918` becomes `0.1296, e = -1413.7`: the page fit** | **no: F-1** |
| PR2 | A TEXT entry with `Hello` typed, then the host switches to `tablesOnly` | the fallback cancels it, no TEXT added (20 → 20); control `reshape: false`: committed (20 → 21) | yes |
| PR3 | The Material export dialog open, then `export: false`, then OK | `toolbar-export` gone, but `plan.pdf` is exported | F-4 |
| PR4 | `delete` × `shortcuts`, four combinations, `1` selected | (T,T): the key deletes, the call is true. (T,F): the key goes to the host, the call is true. (F,T) and (F,F): the key goes to the host, the call is false and nothing is removed | yes |
| PR5 | `readOnly` with the default editor bar | Export, Print, OSNAP and zoom; no Undo. Ctrl+Z and W reach the host. `c.undo()` undoes a host `setTableData`. F3 toggles OSNAP (`snapping` true) | yes (S-12) |
| PR6 | A hidden editor bar with `export` false or true; a hidden service bar | Ctrl+E reaches the host when refused and opens the dialog when allowed; in the selection mode it opens the dialog | yes (S-20) |
| PR7 | Selection mode, theme 60 px bar, overlays; bar hidden at runtime | overlay = `worldToGlobal` in frames 1 and 2; switch to design (no bar, no left column, no rulers) and back with a 72 px bar shown: frame 1 = settled = before | yes |
| PR8a | A service drag while `serviceBar.visible` flips | the table moves by the pointer's delta, no jump, no exception | yes |
| PR8b | An editor body drag while rulers, the bar, `shortcuts` or the left column change | rulers: cancelled (re-parent); the others commit; no exception | yes |
| PR8c | Fields typed under `full`, committed after the change (number → `readOnly`; Rotation → `rotate: false` then `exportPlan`'s settle; thickness → `tablesOnly`; page scale → `editPage: false`) | nothing committed in any case (`_editable` is read at commit) | yes |
| PR9 | `tablesOnly`, inspector, `setTableData`, Ctrl+Z, `setTableGroups` in design, `deleteSelection` | inspector `{}` → `{id: pos-1}` → `{}`; one `FloorPlanTableChanged` each; `mergeCandidate` null and `editorSelectedTables` `{1}` in design; delete true, then one `FloorPlanTableRemoved`, the inspector gone and the set `{}` | yes |
| SWAP | The view's controller swapped and the old one disposed in the same step, each mode, bars shown or hidden | base: no exception in any case. Tip with bars shown: none. **Tip with bars hidden: "A SelectionController was used after being disposed" (design) and "A ValueNotifier\<bool\> was used after being disposed" (selection)** | **no: F-2** |
| K2 | A layer rename open under `full`, Enter after a switch to `readOnly` | the name is kept | yes |
| K3 | After `load` in design: `selectTool(wall)` and `deleteSelection()` | true, and act | yes |

**The R-4 re-enumeration.** I checked every edit path against its flag:

- the paths of F-15 and S-9 (a to h);
- every file under the planner's `lib` that executes a command (`grep` for `TransformNodeCommand`, `SetComponentCommand` and the rest; the object grips are all `GripRole.stretch`, so they are `reshape`);
- the runtime races: drags (S-9 h, Task 5 R-1), menus (Task 5 R-2, PROBE-8 and PROBE-9), fields (PR8c), the TEXT entry (PR2) and the export dialog (PR3).

The only path still open across a change is F-4's export, which is not an edit, and F-7's wall attachment under `rotate: false`, read from the code.

**Monépro's path.** A POS hides jet-cad's bars, owns the keys with `shortcuts: false`, edits under `tablesOnly`, links tables in the inspector and exports through its own dialog. It works end to end in my probes: PR4, PR6, PR9, the hostkeys test, DH1 to DH8 of the demo (green), and RP1 of Task 6. It meets F-2 if it swaps floors in one view and disposes the old controller at once. It meets F-1 if its "view the floor" profile hides the panels and its "edit floor drawing" profile shows them. It meets F-3 at every view ↔ edit switch: the plan moves by the left column's width.

## 4. The frame path

- **The two allocation invariants,** in the gates' JSON:
  - `query_allocation_test`: 6 passed;
  - `paint_allocation_test`: 3 passed.
- **The planner's counters and the pick,** in the same run:
  - `pick_allocation_test` PA1 to PA3: 3 passed, under `--enable-vmservice`;
  - `table_status_painter_test` 12, `table_group_painter_test` 15, `table_focus_painter_test` 8, `table_theme_painter_test` 25 and `table_overlay_test` 33 passed;
  - render `selection_overlay_grips_test` 11 and `select_gates_test` 25 passed.
- **Pan and zoom with every new parameter set** (`zz_s4f_frame_test.dart`, `debugOnRebuildDirtyWidget` over 50 camera changes after a warm-up, table `1` selected). The parameters set: both bars reordered with leading and trailing widgets (a `TextField` among them), `tablesOnly` with a static filter, an inspector, `shortcuts: false`, `autofocus: false`, `onExportDialog` and `onPageFlowError`.
  - **Rebuilt:** design `[ListenableBuilder:50, Text:50]` (the zoom read-out, P-4's one exception) **with and without** the parameters; selection `[]` both ways.
  - **Allocations:** the VM's whole-isolate counts over the same 50 changes are of the same order with and without the parameters. They are noisy run to run (two runs: `Vector2` 2,284/3,943 without against 2,470/3,116 with). Nothing scales with the parameters or the tables.
  - Selection-mode `Offset`s read about 500 to 700 more over 50 frames with the parameters. That is O(1) per frame: the host's own `TextField` in the bar painting. It is not per table.

## 5. Docs against the code

- `check_guide`: `docs/host-guide.md: all 48 code blocks are in the host probe`, exit 0.
- **What matches the code:**
  - § 4's parameter list (the eight, named, "the last eight");
  - § 8's new bullets;
  - **The bars:** order, gaps, rules, chords (S-20), a host field's keys, the host-built bar, `exportPlan` / `printPlan`, the hook and errors;
  - **The editor's capabilities:** the profile table matches S-12 field by field, and so do `copyWith`, the filter, the panels, `selectTablesOnly`, the drags, R and M, the inspector and its shared-number rule, and the limits;
  - **Keyboard and focus:** `deleteSelection`'s false cases, `autofocus`, and a field inside the view keeping its keys (PR4, PR8c and the hostkeys test confirm these);
  - § 11's two bullets;
  - the CHANGELOG's Slice 4 bullets and its `jet_cad_2d_flutter` and `editor.dart` lists.
- **What does not:**
  - Three sentences promise the plan stays in place when the chrome changes in the mode shown (F-3).
  - The CHANGELOG's summary leaves out the key change for a 0.3.0 host with bindings (F-5).

## 6. Gates (my runs at `8f4547376dc8ddf32dc81fb98798d527dbb5c4ad`; `gates.out`)

| Package | Tests | Standing comparison | Analyze | Format |
|---|---|---|---|---|
| `jet_cad_floor_plan` (`--enable-vmservice`) | `05:34 +1880: All tests passed!` | `1880 tests; the standing failures and skips, exactly` | No issues found! | 277 files, 0 changed |
| `apps/restaurant_demo` | `00:42 +68: All tests passed!` | `68 tests; … exactly` | No issues found! | 9 files, 0 changed |
| `apps/floor_planner` | `01:23 +212: All tests passed!` | `212 tests; … exactly` | No issues found! | 47 files, 0 changed |
| `jet_cad_restaurant_symbols` | `00:02 +97: All tests passed!` | `97 tests; … exactly` | No issues found! | 15 files, 0 changed |
| `jet_cad_2d_flutter` | exit 1 (its standing failures) | `1415 tests; … exactly` | No issues found! | 227 files, 0 changed |
| `jet_cad_2d_gpu` | `00:01 +20: All tests passed!` | `20 tests; … exactly` | No issues found! | 10 files, 0 changed |
| `jet_cad_2d` (`dart test`) | exit 1 (its standing failures) | `1258 tests; … exactly` | `--fatal-infos`: No issues found! | 170 files, 0 changed |
| `tool/ci` | `dart test` `00:05 +63: All tests passed!` | — | CI's paths, `--fatal-infos`: No issues found! | CI's paths and `host_probe/lib`: 11 files, 0 changed |

- **`check_guide`:** exit 0.
- **The host probe:** `tool/ci/host_probe.sh file:///home/user/review-s4-final 8f45473…`, exit 0:
  - the lock: "40 packages, none of flutter_scene, flutter_gpu, flutter_gpu_shaders, scene, jet_cad_2d_gpu";
  - analyze: "No issues found!";
  - the build: "✓ Built build/web", then "host probe: no GPU renderer, no build hook; build/web is 42M".
- **v0.3.0's probe:** exit 0 (§ 1).
- **Not rerun by me:** the demo's and the floor planner's own web builds. The probe's web build is the host's.

## 7. Mutants (mine, 31; `mutate.py`, `mutants*.out`, `mut/`)

**Method:**

- Each mutant is an exact string replacement whose site must occur exactly once.
- It runs against the named test files with the JSON reporter, which records the failing tests by name.
- The file is then restored from a copy and compared byte-equal. `restored=True` holds on every row.
- `git status` was clean after every batch, but for my untracked `zz_` files.

| Id | Mutant (the seam) | Result | Red in / note |
|---|---|---|---|
| S01 | the inspector shown for a number another table shares (Task 6 R-1 (a)) | RED | inspector_test M-H45 |
| S02 | the design chrome origin ignores `editorBar.visible` (`canvasAssumed`) | RED | bars_test R-3 (3 tests) |
| S03 | the selection chrome origin ignores the theme's bar height | RED | bars_test R-3 (theme) |
| S04 | the view keeps the host's capabilities object (no copy) | RED | editor_tools_review R-4 |
| S05 | the first measure passes no chrome basis | **SURVIVED** the suite | **RED with my K1** (F-6) |
| S06 | `canvasAssumed` leaves `canvasRect`'s origin | RED | bars_test |
| S07 | `canvasAssumed` leaves a pending assumption | RED | bars_test |
| S08 | `deleteSelection` while a shape is part-way | RED | keyboard_focus DS5 |
| S09 | `deleteSelection` without the settle | RED | keyboard_focus DS6 |
| S10 | `exportPlan` / `printPlan` without the settle (Task 1 R-2) | RED | page_flows |
| S11 | `mergeCandidate` in the design mode | RED | bars_test M-H44 |
| S12 | a gesture survives a change of `selectTablesOnly` (Task 5 R-1) | RED | editor_select |
| S13 | `LayerPanel._execute` unguarded | SURVIVED the suite and my K2 | equivalent on the reachable paths: `LayerRow` nulls the colour menu's `onSelected`, the other controls are disabled, and the rename closes (K2). Defence in depth |
| S14 | the table tool's idle Escape under `shortcuts: false` | RED | T6-g |
| S15 | the select tool's idle keys under `shortcuts: false` | RED | T6-b / T6-c |
| S16 | F3 bound under `shortcuts: false` | RED | T6-b |
| S17 | the `print` capability ignored (the bar and the chord) | RED | editor_tools |
| S18 | the OSNAP read-out shown without `snapping` | RED | T4-f |
| S19 | the shell's `_inspected` answers any one instance (a chair) | SURVIVED | equivalent: the view's `_inspect` re-checks `tableDetailInstances` |
| S20 | the left column ignores `symbolPalette` | RED | editor_tools |
| S21 | `==` ignores `symbolFilter` | RED | editor_capabilities |
| S22 | `copyWith` keeps the host's modifiable set | RED | editor_capabilities |
| S23 | the Layer panel editable whatever `editLayers` says | RED | T5-g |
| S24 | the service view's `Focus` always autofocuses | RED | T6-a |
| S25 | a held key's repeat typed in a field reaches the host | **SURVIVED** | unpinned (F-6); the doc says "a key-down or repeat" |
| S26 | an old editor's withdrawal drops the new editor's tool selector (after a `load`) | **SURVIVED** the suite | **RED with my K3** (F-6) |
| S27 | the design file chords bound under `shortcuts: false` (Task 6 R-2) | RED | keyboard_focus |
| S28 | the table number gated by `rotate` (Task 5 R-3) | RED | editor_select / editor_panels |
| S29 | the view never passes the idle probe (Task 2 R-1) | RED | bars_test T2-c |
| S30 | `deleteSelection` registered only under `shortcuts: false` (Task 6 R-3) | RED | keyboard_focus |
| S31 | the tables-only pick gives a mouse no tolerance (Task 5 R-5) | RED | editor_select |

**Totals:**

- **26 red** on the committed suites.
- **5 survived:** S05, S13, S19, S25 and S26.
  - S05 and S26 are red with my killers K1 and K3, which are green on the unmutated tree in three runs.
  - S13 and S19 are equivalent on the reachable paths.
  - S25 is unpinned.
- S27 to S31 re-apply the task reviews' survivors. All are red now, so those reviews' test fixes landed.
- **A note on K1.** Its first form, with no host rebuild while the design mode is shown, did not kill S05: the view assumes the other mode's canvas only when it builds itself, not on a mode switch. K1 rebuilds the host in the design mode.

## Findings

### F-1 (Medium): a capability change that swaps or removes both side columns re-mounts the canvas and re-fits the camera

**Evidence (PR1).** The shell's row is `[left?, Expanded(canvas), right?]`, and none of the three has a key that matches across the change. When the columns change on **both** sides, `updateChildren`'s top and bottom scans both stop at the canvas, and the unkeyed `Expanded` in the middle is re-created. The cases are:

- left only → right only;
- right only → left only;
- `full` → no column at all.

The new `_PlannerViewState` starts with `fitOnStart` true and `_ownFit` true, so the plan's own first fit runs again, with no epoch:

```
PR1 left only -> right only: plannerView same=false layer same=false camera
  Transform2(0.37, 0, 0, -0.37, -7918.0, 6315.9) -> Transform2(0.1296, 0, 0, -0.1296, -1413.7, 2335.5)
PR1 right only -> left only: plannerView same=false … the same page fit
```

The user's zoom and pan are replaced by the page fit, and so is any `centerOn` or `fitToTables` the host made. The active tool's gesture is also cancelled.

- A one-sided change (`full` ↔ `readOnly`, `full` ↔ `tablesOnly`) keeps the canvas (`same=true`).
- Before Slice 4 the columns never changed, so this is new with Tasks 4 and 5.
- **A host reaches it** with a "view" profile that hides the panels (C-6's "a host that builds its own side panel", or a clean read-only view) and an edit profile that shows them.

**Fix.** Key the canvas, so it is matched in the middle scan: `Expanded(key: const ValueKey('chrome-canvas'), child: ColoredBox(… PlannerView(…)))` in `planner_shell.dart`'s row.

- **Tried in my clone:** all three PR1 cases read `plannerView same=true layer same=true`, with the camera unchanged. `bars_test`, `editor_tools_test` and `editor_panels_test` stay green (`+87: All tests passed!`). Restored afterwards.
- **Killer:** PR1's two crossing cases. Assert the `_PlannerViewState` is identical and the camera matrix unchanged. Mutant: remove the key, and they go red.

### F-2 (Medium, regression): a hidden bar makes the view's dispose subscribe to the controller, so a controller swapped and disposed at once asserts

**Evidence (SWAP).** A host swaps `FloorPlanView.controller` and disposes the old controller in the same step (a floor switch), then pumps:

| | `4e3ed91` | `8f45473`, bars shown | `8f45473`, bars hidden |
|---|---|---|---|
| design | none | none | **"A SelectionController was used after being disposed."** |
| selection | none | none | **"A ValueNotifier\<bool\> was used after being disposed."** |

**Cause.** Several fields are `late final` and are first made by the bar's build:

- in the service view: `_pageReady` (and `_canMerge` and `_canSplit`), each a `DerivedFlag` over the controller's notifiers;
- in the shell: the status line's `_status` relay over the selection.

With the bar hidden they are never made. Each `dispose()` then reads them to dispose them, which **makes** them and subscribes them to notifiers the host has already disposed. The same thing happened to my K1 when it failed mid-test, so the host's widget tests meet it too.

**Fix.** Make each of these lazies nullable (`DerivedFlag? _pageReady`, `_FrameSafeRelay? _status`, made at first use) and dispose them only when made. The alternative is to make them eagerly in `initState`, which is today's moment when the bar shows.

- **Killer:** `zz_s4f_swap_test.tip.dart`'s four cases, with `takeException()` null.
- **Mutant:** the current `late final`, which is red in two cases.

### F-3 (Low–Medium, docs, or a behaviour to rule): "the plan stays where it is on the screen" when the chrome changes in the mode shown

**Evidence.** In the mode shown, the canvas moves and the camera does not, so the plan moves with the canvas:

- the left column going under `full` → `readOnly` moves it 240 px left (PR1: 486 → 246);
- a 60 px service bar hidden moves it 60 px up (PR7: 344.9 → 284.9).

Mode switches are exact (PR7, and the differential's switches).

The docs promise otherwise:

- the guide, § 8 *The bars*, on `visible`: "The canvas takes its height and the plan stays where it is on the screen, from the first frame, in both modes";
- § 8 *At run time*: "When the left column … goes, and the canvas starts at the rulers; the plan stays where it is on the screen";
- the CHANGELOG's bars bullet: "A hidden bar gives the canvas its height, the plan kept in place from the first frame".

`FloorPlanView.serviceBar`'s own doc is right: it promises a **mode switch** in place.

**Fix: the controller's call.**

- **(a) Docs.** Write "a mode switch keeps the plan in place from its first frame; in the mode shown, the canvas grows or shrinks by the bar or the column and the plan moves with it" in the three places.
- **(b) Code.** In the view's `_canvasMoved`, when the shown mode's measured origin moved with the plan unchanged, pan the camera by the old origin minus the new. The plan then stays put, which is R-13's spirit and better for Monépro's view ↔ edit switch. The killer is PR1's first case and PR7's hide, asserting `worldToGlobal` unchanged after one frame.

I recommend (b), if the human wants profile switches to feel like mode switches. Otherwise (a).

### F-4 (Low): an Export started before `export: false` still exports

**Evidence (PR3).** `toolbar-export` opens the Material dialog. The host switches to `full.copyWith(export: false)`, and the bar's Export disappears. OK then exports `plan.pdf`.

This slice cancels a drag (S-9 h) and a menu (Task 5 R-2) that started under an allowed flag and finished under a refused one. The export flow is the one runtime path left open. It is not an edit (`export` is not an edit flag), so the severity is low.

**Fix.** Either:

- have the view pass a hook that `PageFlows.export` reads after the dialog answers. In the design mode it is the current `editorCapabilities.export`; it is always true in the selection mode (S-22). A refusal cancels. The killer is PR3, with no export; or
- record it in the guide's limits.

### F-5 (Low, CHANGELOG): the field-key change is not listed as a change a 0.3.0 host may notice

**Evidence (the hostkeys differential).** A 0.3.0 host whose `Shortcuts` above the view bind Delete, Backspace, a letter or Ctrl+A received those keys from the planner's own fields at `4e3ed91`, and the field did not edit. At `8f45473` the field keeps them.

The CHANGELOG's summary says that with no new argument "every pixel and key is 0.3.0's (but for the fix below)". Its *A fix a 0.3.0 host may notice* lists S-4, the shared guard and the read time, not this.

**Fix.** Add one sentence to that bullet: keys typed into the planner's text fields no longer reach the host's bindings above the view (Backspace, Delete, typing keys, and the text-editing chords the field takes, Ctrl+A among them).

### F-6 (Low, tests): three mutants the suite leaves alive

- **S05:** the first measurement's chrome basis. It matters when the view is first shown in a mode whose bar is hidden and the host rebuilds the view in the other mode before switching back: the switch's first frame is then 44 px off.
  - **Killer:** K1 in `zz_s4f_killer_test.dart`, green at the tip and red under S05 ("Actual: <44.0>").
- **S26:** `registerTools`' identity check. After a `load` in the design mode, the old shell's withdrawal would drop the new shell's tool selector, so `selectTool` would answer false. Task 2's O8 had the same shape for the idle probe.
  - **Killer:** K3 (`selectTool(wall)` and `deleteSelection()` after a `load`), red under S26.
  - The same killer covers `registerDelete`, which has the same check.
- **S25:** a key **repeat** typed in a field is unpinned. The doc says "A key-down or repeat".
  - **Killer:** in `host_text_keys_test`, a `KeyRepeatEvent` of K with a field focused; the host's K must not fire.

Land K1 and K3 (and a repeat case) in `bars_test.dart`, `editor_tools_test.dart` and `host_text_keys_test.dart`, with S05, S26 and S25 named as their mutants.

### F-7 (Info, read in the code, not run): a wall-attached move or placement can turn a table under `rotate: false`

- **On a move,** `SymbolMoveResolver.resolveMove` (`symbols/symbol_move.dart:31-52`) returns the wall attachment's whole transform, including a turn, and `SelectTool` commits it under the `move` gate alone.
- **On a placement,** `SymbolPlaceTool._place` passes `transform: _attached?.transform`, which bypasses `_turns`.

No bundled table carries `against-wall`: the desks do, but they have no seats. So the stock profiles are unaffected. A host library with a wall-tagged table under `tablesOnly.copyWith(rotate: false)` (the guide's own `arrangeTables`) could still have one turned by a drag near a wall.

**Fix.** Record it in the guide's limits, or skip the attachment while `rotate` is refused. `snapping: false` already turns it off.

### F-8 (Low, the exit gate's owed items)

- **The results note** `docs/superpowers/notes/2026-10-09-embedding-slice-4-results.md` is not written. It must carry R-4's table: each path, its flag, its enforcing code and its killer.
- **STATUS's resume point** still reads "Task 1"; the roadmap row is not yet updated.
- **The spec's text** still contradicts or omits rulings the Review paragraph records:
  - M-H46 names Ctrl+Shift+E (S-1);
  - C-3's `deleteSelection` lacks Task 6's "whichever tool is active, while it is idle";
  - C-5's "a hidden panel's state is kept" lacks the all-three-hidden exception (Task 5 finding 4);
  - C-6 lacks S-18 as ruled (a shared number shows none, Task 6 R-1 (a)).

  The plan's Task 7 asked for C-5, C-7, F-9, F-12, F-15 and M-H46 to be amended in place.

## The task reviews' claims, re-checked

- **Task 1.** R-1 to R-5 are landed: S10 is red, and the read-at-each-call and settle killers are in `page_flows_test`.
- **Task 2.** R-1 is landed (S29 red). R-2 (`lastFile`) is in the code. R-3 is done and goes further: `canvasAssumed` makes the first frame exact (S02, S03, S06 and S07 red; PR7). R-4's docs now say the file chords reach the plan.
- **Task 3.** R-2's `SelectTool.deleteSelection` is used by the controller, and render `select_gates_test` has 25 passing tests.
- **Task 4.**
  - R-1: `_turns` and `_mirror` are in the code (the differential's R/M placement is identical under `full`).
  - R-2: the relay is in the code (PR8b, rulers off with a drag: no exception).
  - R-4: the view copies the capabilities (S04 red).
- **Task 5.** R-1 is landed (S12 red), R-2 too (PR3's sibling: K2 holds), R-3 too (S28 red), R-5 too (S31 red).
- **Task 6.** R-1 (a) is landed (S01 red), R-2 too (S27 red), R-3 too (S30 red). The R-4 docs are reworded (the view's `autofocus` doc).
- **Task 7.** Finding 1's `PlannerTextKeys` is confirmed by the hostkeys differential, and is inert with no host bindings (§ 2).

## Asked of the fixer

1. **F-1:** key the shell's canvas `Expanded`, and land PR1's crossing cases as killers.
2. **F-2:** make the bar-only lazies nullable, or eager, and land the SWAP cases.
3. **F-3:** the controller rules on (a) docs or (b) the compensating pan; apply it in the guide's two places and the CHANGELOG (and in the code for (b)).
4. **F-5:** add the CHANGELOG sentence.
5. **F-6:** land K1, K3 and a repeat case.
6. **F-4 and F-7:** fix them or record them in the guide's limits.
7. **F-8:** before the merge, write the results note, STATUS, the roadmap row and the spec amendments.
