# Slice 4, Task 5: capabilities II — the select tool and the panels (implementer's report)

- **Branch:** `claude/exciting-pasteur-9m22jv`, from `c65a3a0` (Tasks 1 to 4 and their review fixes).
- **Commit:** `62926cb`. Pushed as `c65a3a0..62926cb`.
- **Environment:** Flutter 3.47.6 at `/root/sdk/flutter/bin`, `CI=true`. Scratch: `/tmp/claude-0/-home-user/428cafca-0083-5012-a7ac-5456349e70a8/scratchpad/s4t5-impl/`:
  - `mut.py`, the mutant runner (applies, runs the killer by `--plain-name`, reads the log for a real expectation and not a compile error, restores from a copy, checks byte-equal with `filecmp`);
  - `mutants.log` and `logs/`: the final round on the committed tree; `mutants-mh42b.log`: M-H42b's compiling form; `mutants-round1.log` and `logs1/`: the first round;
  - `gates.sh`, `gates.out` and the per-package `*.json`, `*.test.log`, `*.cmp.log`, `*.analyze.log`, `*.format.log`;
  - `zz_probe_test.dart`: the probes that read the fixture's geometry and the index's picks on the base (run in the package, moved out before the mutants and the gates).
- **`analysis_options.yaml`:** none touched or committed; `git status` before the commit showed the task's eight files only, after it a clean tree.
- **Scope:** Task 5's Builds and Tests. The engine and `jet_cad_2d_flutter` are not edited (the render mutant M-H42b was applied to `select_tool.dart` and restored; `cmp` against `HEAD` afterwards). No existing test, golden, counter or allocation test is edited.

## Files

| File | What |
|---|---|
| `lib/src/planner_shell.dart` | `_CapabilityGates extends SelectGates`, reading `widget.capabilities` live through a closure: `restrictsPick` = `selectTablesOnly`; `pick` = a `TablePicker(_document, skipLocked: true)` made at the first pick (reach `e.reachRadiusWorld` for a touch, 0 for a mouse, as the selection mode's tool); `bandAccepts` = not `selectTablesOnly`, or a table key (`_isTableKey`: no chain, a root-level instance of a live definition with a `SeatingComponent`, `TableSurvey`'s rule); `move`, `rotate`, `reshape`, `delete` = the flags; `idleKeys` inherited (true; Task 6's). **One object** on `SelectTool(gates:)` and `GripCache(gates:)` (Task 3 finding 4). `didUpdateWidget`, on a capabilities change: a change **to** `selectTablesOnly` removes every non-table key from the design selection (S-9 g; no table leaves it, so the controller's `selectedTables` does not move and no host listener is dirtied mid-build), then `_grips.gatesChanged()`, then Task 4's fallback. The right column: built only while one of `selectionPanel`, `layerPanel`, `pagePanel` holds; each panel in `_keptPanel` = `Visibility(visible:, maintainState: true)` (offstage, state kept, and out of the focus order: `Visibility`'s `maintainFocusability` is false by default, see Finding 3); the Selection panel gets `capabilities`, the Layer panel `editable: editLayers`, the Page panel `editable: editPage`. |
| `lib/src/selection_panel.dart` | Optional `capabilities` (`full`). `_editable` first asks `_capable(kind, target)`: the number by `renumber`, the rotation by `rotate`, any other field by `reshape` unless its target is a tool's settings (the Wall tool's or an opening tool's: no document edit). `_dimensionEditable` ANDs `reshape`. Shown only by their flag: Mirror (`mirror`), ±90 (`rotate`), a door's flips (`reshape`), the Size menu (`reshape`), the layer picker (`changeLayer`). Value fields read-only by the same rule (Rotation `turnable && rotate`). The action methods (`_rotateTable`, `_mirrorSymbol`, `_changeSize`, `_setJustification`, `_flip`) check their flag too. |
| `lib/src/layers/layer_panel.dart` | Optional `editable` (true), ANDed into `_allowed`: every control disabled as a refused `structure` disables it; the list shown, the header still collapses. |
| `lib/src/page_panel.dart` | Optional `editable` (true): with false the preset and unit dropdowns, the orientation and separator segments, the grid, snap and page-breaks checkboxes and the swatches are disabled (`null` callbacks), the scale field `enabled: false`; the values shown. |
| `lib/src/service/table_picker.dart` | Optional constructor parameter `skipLocked` (false): `pick` passes over a table on a locked layer in each of its three passes, so the table under it may answer. A constructor parameter, not a `pick` parameter: see Finding 2. |
| `lib/src/host/editor_capabilities.dart` | Doc only: what each panel and edit flag does now (hidden vs read-only, kept state, the tables-only pick, the prune, a drag across a change). |
| `test/host/editor_select_test.dart` (new, 11 tests) | Through `FloorPlanView` on the editor fixture under `editorCamera()`, with `editor_tools_test.dart`'s host (`t.mountEditor`, a runtime `h.caps`). |
| `test/host/editor_panels_test.dart` (new, 12 tests) | The same. |

## Tests

`editor_select_test.dart`:
- **M-H42** tablesOnly: a window band and a crossing band over the whole canvas (walls, rooms and their edges, the overall depth's dimension, the free line, the group, the TEXT, the chair, every table) select exactly the five visible unlocked tables (`1`, `2`, `7`, ` 7 `, the unnumbered one); a crossing band over the north wall, its inner face (a room edge), the parquet, the chair and `1`, `2` selects exactly `{1, 2}`; one over the group, the free line and the TEXT selects nothing.
- **M-H42 S-15** under `full` first (the control): a click inside `1`'s top selects one key that is **not** `1` (the index's topmost hit there is a parquet hairline, `212`, read on the base by the probe), and a click on the north wall selects the wall; switched to `tablesOnly` the wall is pruned (S-9 g); clicks on the north wall, the column, the free line and the TEXT select nothing; inside `1`'s top selects `1`; inside `2`'s box off its top selects `2`.
- **S-15 finger:** 40 mm (≈15 px) beyond `1`'s box: a mouse click selects nothing, a finger's tap selects `1`.
- **Hidden and locked:** a click on `5` (hidden) and on `L` (locked) selects nothing; a crossing band over the canvas holds neither; ` 7 ` moved under `L` (a lower handle, drawn under it) → a click on `L`'s top selects ` 7 ` (passed over, not blocking).
- **T5-a** readOnly: `1` clicked on its top's edge (the index pick), a body drag → the encoding unchanged, `canUndo` false; tablesOnly: a drag of (80, −40) px moves `1`'s centre by (216, 108) mm within the grid's 50 mm.
- **T5-b** readOnly, `1` selected: `rotatable` false, no ±90, the Rotation field read-only and a typed `75` (into its controller, focus lost) not committed, a drag at the rotation grip's place (computed by the test: the screen box of the top's corners, its top middle, 24 px up; checked against the cache at distance 0 by the probe) changes nothing; tablesOnly: `rotatable`, ±90 shown, the field editable, the grip's drag turns `1`.
- **T5-c** readOnly: `setTableData('1')` succeeds (V-5); `1` selected; Delete and Backspace change nothing; tablesOnly: Delete removes `1` and its data; `undo()` restores both.
- **T5-d** full, a wall and `1` selected → tablesOnly → `{1}`, `selectedTables` unchanged; Delete removes `1` and the wall stays.
- **S-9 h** a body drag of `1` started under tablesOnly, switched to `tablesOnly.copyWith(move: false)` before its up → encoding unchanged, `canUndo` false; kept under tablesOnly → it moves.
- **M-H43c** `full.copyWith(reshape: false)`: the free line selected → `leafGripsLive` true, `stretchGripsLive` false, `hitTest` at its end −1; a drag from its end keeps its length (it moves whole: a body move); the column's end grip the same (length kept); with `move: false` too, both drags leave the encoding byte-identical; under `full` both reshape (lengths change).
- **gatesChanged:** the free line's end grip hot under a resting mouse; switched to `reshape: false` → `hot` −1 and the grip cache notified, no pointer event.

`editor_panels_test.dart`:
- **M-H43 / M-H43b** `1` selected: `symbol-mirror` and `layer-picker` under `full`; neither under `tablesOnly`; no picker under `readOnly`; both back under `full`.
- **tablesOnly and T5-e:** readOnly: `table-number` read-only, a typed `12` not committed (the field reverts to `1`); tablesOnly: both fields editable, `12` committed, ±90 turns `12` by 90°, a typed rotation 45 commits.
- **T5-f** `full.copyWith(reshape: false)`: wall thickness read-only and a typed 300 not committed, justification disabled; a door (selected by hand: none is on screen): flips absent, width and position read-only; a room's name read-only; the dimension kind disabled; a placed `sofa.two` (a family): no Size menu, Mirror shown. Under `full`: the Size menu, thickness 300 commits, justification enabled, Flip hinge flips, the kind switches to vertical.
- **A tool's settings:** the Wall tool active under `reshape: false` → its thickness and justification edit.
- **readOnly, each selectable by a click:** `1` (number and rotation read-only; no ±90, Mirror, layer picker), the north wall (thickness read-only, justification disabled), the living room by its label (name read-only), the overall depth by its line (kind disabled), the east window (width read-only, no picker).
- **readOnly, the scripted run:** `1` clicked, body-dragged, its rotation grip's place dragged, Delete, Backspace; the free line's body and both ends dragged, Delete; the column's end dragged, Backspace; W, L, F; Ctrl+Z → the encoding byte-identical, `canUndo` false, the tool select.
- **V-5:** under readOnly `setTableData('2')` edits, `undo()` restores the encoding, `load` replaces the plan (2's data, set again, gone; history empty).
- **T5-g (show):** `layers-panel`, `page-preset`, `selection-panel` each hidden by its flag; all three hidden → no `chrome-right`; the Layers section closed by the user stays closed across a hide and show.
- **A hidden panel out of the focus order:** the page scale focused, `pagePanel: false` → no focus; shown again → the same field (its focus node identical: state kept).
- **T5-g (edit):** `editLayers: false`: `layers-add`, the locked layer's eye, lock and make-current disabled, its colour menu disabled, the list shown; `editPage: false`: preset, orientation, scale, unit, separator, grid, snap, page breaks and the four swatches disabled; taps on a swatch, the grid and the eye change nothing; `full` → all enabled.
- **T5-h** tablesOnly, `1` selected: no `DropdownButton`, `PopupMenuButton` or `MenuAnchor` on stage under the view (under `full` there are); a second test mounts a fresh controller under `Theme(data: ThemeData.from(colorScheme: <hand-built>))`: the ±90 icons' colour is that scheme's `primary`, and no menu.

## Mutants

Every row seen red on its killer, on the committed tree (`mutants.log`, `mutants-mh42b.log`; each log read for its expectation), the file restored and compared byte for byte.

| Mutant | Applied as | Killer | Seen red at |
|---|---|---|---|
| **M-H42** (shell) | `bandAccepts` → `true` | M-H42 tablesOnly: a window and a crossing band … | the band's set holds non-table keys |
| **M-H42** (tool, render) | `if (g.bandAccepts(doc, key) \|\| true) key,` in `select_tool.dart` | same | same |
| **M-H43** | `if (caps.mirror)` → `if (true)` | M-H43 1 selected … | `symbol-mirror` found |
| **M-H43b** | the picker's `changeLayer` clause removed | M-H43 1 selected …; T5-h tablesOnly … no dropdown | `layer-picker` found; one menu under the view |
| **M-H43c** | the gate's `reshape` → `true` | M-H43c … | `stretchGripsLive` true |
| **T5-a** | the gate's `move` → `true` | T5-a …; readOnly scripted run | the encoding differs |
| **T5-b** (gate) | the gate's `rotate` → `true` | T5-b … | `rotatable` true |
| T5-b (field shown) | the Rotation field built with `turnable` alone | T5-b | `readOnly` false |
| T5-b (commit) | `_capable` rotation → `true` | T5-b | the typed 75 committed (encoding) |
| T5-b (±90) | `if (_rotatable)` alone | T5-b | `table-rotate-left` found |
| **T5-c** | the gate's `delete` → `true` | T5-c … | the encoding differs after Delete |
| **T5-d** | the prune's condition `false` | T5-d … | `{12, 29F}`, expected `{29F}` |
| T5-d (prunes tables) | every key dropped | T5-d | `{}`, expected `{29F}` |
| **T5-e** | `_capable` number → `true` | tablesOnly … T5-e … | the typed 12 committed |
| **T5-f** (fields) | `_capable` other → `true` | T5-f … | thickness `readOnly` false |
| T5-f (flips) | the flips' `reshape` clause removed | T5-f | `opening-flip-hinge` found |
| T5-f (kind) | `_dimensionEditable` without `reshape` | T5-f | `onSelectionChanged` not null |
| T5-f (Size menu) | `members.isNotEmpty` alone | T5-f | `symbol-size-menu` found |
| P-tool-settings (task-local) | `_capable` without the tool-target exemption | a tool's settings are no edit … | thickness `readOnly` true |
| **T5-g** (layers shown) | `_keptPanel(true, LayerPanel…)` | T5-g layerPanel false … | `layers-panel` found |
| T5-g (page shown) | `_keptPanel(true, PagePanel…)` | same | `page-preset` found |
| T5-g (selection shown) | `_keptPanel(true, SelectionPanel…)` | same | `selection-panel` found |
| T5-g (column) | the column always built | same | `chrome-right` found |
| T5-g (state) | `shown ? panel : SizedBox.shrink()` | same | `layers-list` found (reopened) |
| T5-g (focus) | `maintainFocusability: true` | a hidden panel is out of the focus order … | `hasFocus` true |
| T5-g (editLayers) | `editable: true` passed | T5-g editLayers false … | `layers-add` enabled |
| T5-g (editPage) | `editable: true` passed | same | preset enabled |
| T5-g (layer panel) | `_allowed` without `editable` | same | `layers-add` enabled |
| T5-g (swatches) | the swatches' `editable` check removed | same | swatch enabled |
| T5-g (scale) | `enabled: editable` removed | same | scale enabled |
| **T5-h** (menus) | = M-H43b | T5-h tablesOnly … no dropdown | a menu found |
| T5-h (theme) | each panel under `Theme(data: ThemeData())` | T5-h under a local Theme … | the default scheme's primary, expected the host's |
| S15-a (task-local) | `restrictsPick` → `false` | M-H42 S-15 a click on a wall line … | the wall `1A` selected |
| S15-b | reach 0 for a finger | S-15 a finger reaches … | `{}`, expected `{29F}` |
| S15-c | `TablePicker(_document)` (no skip) | the tables on the hidden and the locked layers … | `L` (`2AA`) selected |
| S15-d | no skip, and a locked hit answers null | same | `{}`, expected ` 7 ` (`2A5`) |
| S15-e | the tops' pass without the skip | same | `L` selected |
| S-9 h (task-local) | the gates read the capabilities the shell was created with | S-9 h … | the encoding differs |
| P-gatesChanged | `_grips.gatesChanged()` removed | a runtime change reaches the grips at once … | `hot` 0, expected −1 |

**The first round** (`mutants-round1.log`) had three rows that were not red: M-H42 (tool) did not compile in the first two forms (flow analysis does not promote `g` past `g == null || true`), now applied in the band list's condition; T5-g (focus) survived because the `ExcludeFocus` I had added is redundant (Finding 3), so it is gone and the mutant is `maintainFocusability: true`; S15-d was applied with the skip still on (an equivalent mutant), now applied with both edits.

**Equivalent, no killer:** `_isTableKey`'s `node.parent == root` clause: a band's and the selection's keys are root keys and a servable instance in a group is reachable by no pick, so no UI path hands it a nested instance.

## Gates (on the final tree, before the commit; `gates.out`)

| Package | Test | Standing comparison | Analyze | Format |
|---|---|---|---|---|
| `packages/jet_cad_floor_plan` (`flutter test --enable-vmservice`) | `04:49 +1832: All tests passed!` (1809 + 23) | `1832 tests; the standing failures and skips, exactly` | No issues | 274 files, 0 changed |
| `apps/restaurant_demo` | `+60: All tests passed!` | | No issues | 0 changed |
| `apps/floor_planner` | `+212: All tests passed!` | | No issues | 0 changed |
| `packages/jet_cad_2d_flutter` | exit 1: its 7 standing failures | `1415 tests; … exactly` | No issues | 0 changed |
| `packages/jet_cad_2d_gpu` | `+20: All tests passed!` | `20 tests; … exactly` | No issues | 0 changed |
| `packages/jet_cad_2d` (`dart test`) | exit 1: its 2 standing failures | `1258 tests; … exactly` | No issues (`--fatal-infos`) | 0 changed |

No render edit (none expected). The planner run includes PA1–PA3 (run, not skipped), every test of the plan's *Unedited and green* list for this task (unedited), and Task 4's suites.

## The edit-path table (R-4: F-15 and S-9, each path with its flag, its enforcing code and its killer)

| Path | Flag | Enforced by | Killer (test name, file) |
|---|---|---|---|
| **F-15** the 15 tools and their letters | `tools` | `_allows` / `_activate`, the letter bindings (Task 4) | M-H41; T4-a; T4-b; M-H47(runtime tool) (`editor_tools_test`) |
| F-15 the Symbols tab | `symbolPalette`, `symbol`, `symbolFilter` | `_leftPanel`, `SymbolPanel.filter` / `placeable`, `_offers` (Task 4) | M-H47(symbolFilter); T4-c; "the Symbols tab without the symbol tool" (`editor_tools_test`); O22 (`editor_tools_review_test`) |
| F-15 SelectTool body drag (with wall attach) | `move` | `_CapabilityGates.move` → `SelectTool._beginDrag`, the up's re-read | T5-a; readOnly scripted run (`editor_panels_test`) |
| F-15 the rotation grip | `rotate` | `_CapabilityGates.rotate` → tool and grip cache (`rotatable`) | T5-b |
| F-15 reshape grips (every object grip: wall ends, opening slide, room label, separator ends, dimension grips; leaf stretch grips) | `reshape` | `_CapabilityGates.reshape` → tool and grip cache (`stretchGripsLive`, `hitTest`) | M-H43c |
| F-15 the rubber band | `selectTablesOnly` (a band is a selection, no edit: allowed under every profile) | `_CapabilityGates.bandAccepts` → `SelectTool._bandKeys` | M-H42 (two forms) |
| F-15 Delete / Backspace | `delete` | `_CapabilityGates.delete` → `SelectTool.onKey` / `deleteSelection` | T5-c; T5-d |
| F-15 the Table section's number | `renumber` | `SelectionPanel._capable` in `_editable` (field read-only, commit refused) | tablesOnly … T5-e (`editor_panels_test`) |
| F-15 the Rotation field | `rotate` | `_capable` + the field's `turnable && rotate` | T5-b (field and commit forms) |
| F-15 ±90 | `rotate` | not shown; `_rotateTable` checks it | T5-b (±90 form); tablesOnly … T5-e (turns `12`) |
| F-15 Mirror | `mirror` | not shown; `_mirrorSymbol` checks it | M-H43 |
| F-15 Change size (the Size menu) | `reshape` (S-10) | not shown; `_changeSize` checks it | T5-f (Size menu form) |
| F-15 the wall, opening, room and box fields | `reshape` (S-10) | `_capable` (read-only, commit refused); a tool's settings exempt | T5-f (fields form); "a tool's settings are no edit" (exemption) |
| F-15 the layer picker | `changeLayer` | not shown | M-H43b; T5-h (menus) |
| F-15 the Layer panel | `layerPanel`, `editLayers` | `_keptPanel`; `LayerPanel.editable` → `_allowed` | T5-g layerPanel false …; T5-g editLayers false … |
| F-15 the Page panel | `pagePanel`, `editPage` | `_keptPanel`; `PagePanel.editable` per control | T5-g layerPanel false …; T5-g editLayers false … |
| F-15 Undo and Redo | `undo` | the shell's edit commands and chords (Task 4) | T4-e |
| F-15 Export and Print | `export`, `print` | the shell's file commands and chords (Task 4) | T4-e; RV9 / O23 (`editor_tools_review_test`) |
| F-15 F3 (snap) | `snapping` | the F3 binding, the read-out, `_CapabilitySnap` (Task 4) | T4-f |
| F-15 F (fill) | a fill tool among `tools` | `_fillOffered` (Task 4) | M-H41 (P-fill-key); T4-a |
| **S-9 a** the centre (move-role) grip | `move` | the same `_CapabilityGates.move` (render maps the role, Task 3) | render T3-c, RV-1 (`select_gates_test`); the fixture has no arc or circle, so no shell-level centre grip (see Finding 5) |
| S-9 b the symbol tool's R, Shift+R, M | `rotate`, `mirror` | `SymbolPlaceTool.canRotate` / `canMirror` (Task 4) | T4-d; P-rotate; RV1–RV3 |
| S-9 c an armed symbol newly refused | `symbol`, `symbolPalette`, `symbolFilter` | `didUpdateWidget`'s fallback (Task 4) | T4-c; RV4–RV6 |
| S-9 d a door's Flip hinge / Flip swing | `reshape` | not shown; `_flip` checks `_editable` | T5-f (flips form) |
| S-9 d a wall's justification | `reshape` | disabled (`wallEditable`); `_setJustification` checks it | T5-f (asserted; shares the fields form's clause) |
| S-9 d the dimension kind | `reshape` | disabled (`_dimensionEditable`); `_setKind` checks it | T5-f (kind form) |
| S-9 e the Layer panel's make current, visibility, lock, colour, rename, add, delete | `editLayers` | `LayerPanel._allowed` → every `LayerRow` control, + and delete | T5-g editLayers false … (add, eye, lock, current, colour asserted; rename and delete read the same `allowed`) |
| S-9 e the Page panel's preset, orientation, scale, unit, separator, grid, snap, page breaks, swatches | `editPage` | `PagePanel.editable`, each control | T5-g editLayers false … (every control asserted; swatches and scale forms) |
| S-9 f the Fill row beside F | a fill tool among `tools` | `ToolPalette.showFill` (Task 4) | T4-a; RV7 |
| S-9 g a selection held across a change to `selectTablesOnly` | `selectTablesOnly` | `didUpdateWidget`'s prune | T5-d (both forms); M-H42 S-15 (the wall pruned) |
| S-9 h a drag in progress across a change | the drag's flag | the gates read live; render's re-read at the up (Task 3 T3-h) | S-9 h (and its "first capabilities" form) |
| S-15 the tables-only pick (a top, a box, a finger's reach, a locked table passed over, a hidden one absent) | `selectTablesOnly` | `_CapabilityGates.restrictsPick` / `pick`, `TablePicker.skipLocked` | M-H42 S-15 …; S-15 a finger …; the tables on the hidden and the locked layers … |
| A runtime change reaching the grips | every gate | `didUpdateWidget` → `gatesChanged()` | "a runtime change reaches the grips at once" |
| C-8 Material menus under `tablesOnly` | `layerPanel`, `pagePanel`, `changeLayer`, `reshape` | hidden as above | T5-h (both tests) |

## Findings

1. **M-H43c as written cannot hold.** "A drag from its end grip leaves the document unchanged" under `full.copyWith(reshape: false)`: the end grip is not there, so the press falls to the line's (or the wall's) body, which `move` lets move. This is Task 3 review's ruling on T3-e. The killer asserts **no reshape** (the length kept, and for the line that it moved whole), and with `move: false` added, the document byte-identical; under `full` both reshape.
2. **`TablePicker.pick` cannot gain a parameter:** `test/service/service_events_test.dart:38`'s `CountingPicker` overrides `pick(Vector2, {double reach})`, so a new named parameter is an invalid override (analyzer error) and that test may not be edited. `skipLocked` is an optional **constructor** parameter instead (default false: the selection mode still picks a locked table, S9). An edit of `service/table_picker.dart` the plan's Builds do not list; additive; PA1–PA3 green.
3. **`Visibility` already excludes focus.** In Flutter 3.47, `Visibility(maintainState: true)` has `maintainFocusability: false` by default, which wraps an `ExcludeFocus(excluding: !visible)`. The plan's "focus excluded" holds with no extra widget; my first `ExcludeFocus` was redundant (its mutant survived) and is removed. The killer pins it through `maintainFocusability: true`.
4. **The right column is not built when all three panels are hidden** (as the plan says), so in that one case their state is not kept (the Layers section's open state, the Selection panel's typed text). Hiding one or two keeps it. The page panel's `GlobalKey` is then empty and `_settlePendingInput`'s `resyncScale` already reads it null-safely.
5. **The centre grip at the shell level:** the editor fixture has no arc or circle (only those have a `GripRole.move` grip), so no shell test drags one. The shell has a single `move` getter for both; the role mapping is Task 3's (T3-c, RV-1).
6. **A box:** the fixture has no box; the box fields share `_capable`'s `reshape` clause with the wall, opening and room fields (killed through the wall's thickness).
7. **A capability change that adds or removes the left column moves the canvas on the screen** (`tablesOnly` ↔ `readOnly`): a test that keeps screen points across such a change must recompute them (T5-b does). S-9 h therefore switches to `tablesOnly.copyWith(move: false)`, which keeps the layout, so the drag's up lands where it started.
8. **Mounting a second `FloorPlanView` on the same controller** (a new tree replacing the old) throws "the dispatcher already has an expander" while both shells exist for one frame. Pre-existing, not this task's; T5-h's theme test mounts a fresh controller.
9. **Under `editLayers: false` the Layers section's delete tooltip reads the permission's words** ("Layers cannot be changed in this document", `layersLocked`). Reused as is; a separate wording would be a new string in three languages.
10. **The select tool's cursor after a runtime change** stays stale until the next pointer move (Task 3's accepted R-4.3); `gatesChanged()` repaints the grips at once.
11. **Bands under `readOnly`** still select (a selection is no edit), as Task 3's RV-7 pins.

## Fixes

Applied after the review (`s4-task-5-review.md`) as ruled by the controller, in commit `d966e67` on `claude/exciting-pasteur-9m22jv`. Scratch: `/tmp/claude-0/-home-user/428cafca-0083-5012-a7ac-5456349e70a8/scratchpad/s4-fix567/` (`mut.py`, `t5_mutants.py`, `mutants.log`, `mlogs/`, `pre5/` the planner run before the commit).

**Code:**
- **R-1** (`planner_shell.dart`, `didUpdateWidget`): a capabilities change cancels a non-idle select gesture (`_select.cancel(_context)`) when `selectTablesOnly` changes (either way: a press, a drag or a band read under the old value), or when the gate the running drag needs closes (`DragKind.move` → `move`, `rotate` → `rotate`, `reshape` → `reshape`; a band needs none). It runs before the S-9 g prune. The cancel is the Escape path: the document byte-identical.
- **R-2** (`layers/layer_panel.dart`, `layers/layer_row.dart`): `_execute` returns while `!_allowed`; a disabled row's colour `PopupMenuButton` gets `onSelected: null`.
- **R-5** (`planner_shell.dart`, `_CapabilityGates.pick`): `reach: e.isTouch ? e.reachRadiusWorld : e.pickRadiusWorld`: a mouse gets the index pick's 6 px, a finger its 24 px reach.
- Docs: `editor_capabilities.dart` (the pick's mouse tolerance; a change of `selectTablesOnly` cancels a gesture under way; a refused drag is cancelled) and `_CapabilityGates`' doc.

**Tests** (the task's own files; no existing test edited):
- `editor_select_test.dart`, group "the review's killers":
  - R-1 the north wall's body drag started under `full`, `tablesOnly` before the up → encoding byte-identical, `canUndo` false, wall pruned; control: the same drag under `full` moves it (PROBE-1).
  - R-1 the chair's rotation-grip drag (premise: `hitsRotationGrip`), same switch → byte-identical; control turns it (PROBE-2).
  - R-1 a gate closed mid-drag and reopened before the up (`move`, `rotate`, `reshape` under `full`): each drag executes nothing (undo depth unchanged); never closed, each executes (depth +1). This pins the closed-gate arms, which the render's re-read at the up alone would not.
  - R-3 `tablesOnly.copyWith(delete: false)`: Delete and Backspace remove nothing, a body drag still moves `1`.
  - R-5 `tablesOnly`: a mouse click 3 px outside `1`'s box selects `1`; 15 px outside selects nothing.
  - R-4 `tablesOnly`: a finger 40 mm (≈15 px) beyond the locked `L`'s box selects nothing; at the same offset from `1` it selects `1`.
- `editor_panels_test.dart`, group "the review's killers":
  - R-2 the locked layer's colour menu opened under `full`, then `readOnly` / `tablesOnly`, colour 1 chosen → byte-identical, `canUndo` false; control (no switch) → recoloured (PROBE-3).
  - R-3 `tablesOnly.copyWith(renumber: false)`: number read-only, a typed `12` not committed; ±90 turns `1`; Rotation 45 commits.
  - R-3 `tablesOnly.copyWith(rotate: false)`: no ±90, Rotation read-only (typed 75 not committed); the number `12` commits.
  - R-3 `full.copyWith(changeLayer: false)`: no picker for `1`, the wall's thickness 300 commits; `full.copyWith(reshape: false)`: the picker shown, the thickness read-only.
  - R-3 `editLayers: false` alone: Layer panel disabled, Page enabled; `editPage: false` alone: the reverse.
  - R-4 the Door tool under `full.copyWith(reshape: false)`: its width editable, `1000` submitted shows `1000`, the design unchanged.
  - R-4 `full.copyWith(selectionPanel: false, layerPanel: false)`: `chrome-right` and `page-preset` present.

**Docs:**
- Guide § 8 *The editor's capabilities*: the pick's mouse tolerance; a switch of `selectTablesOnly` cancels a click, drag or band under way; a refused drag is cancelled at once even if the flag comes back; **Limits** gain O-1 (Undo under `tablesOnly` still undoes edits made before the switch; `load` to start afresh) and finding 4 (all three panels hidden drops the column and their state).
- Plan: M-H43c's killer amended (a hidden end grip makes the press a body move; the length kept; with `move: false` byte-identical); Task 5's Builds list `service/table_picker.dart` (`skipLocked`); the pick's bullet names the mouse's 6 px.

**Mutants** (`mutants.log`; each applied to the working tree, both Task 5 files run with the JSON reporter, the file restored from a copy and compared byte-equal):

| Mutant | Result | Killer |
|---|---|---|
| F1 the R-1 cancel removed | RED (3) | R-1 wall; R-1 chair; R-1 gate closed mid-drag |
| F1b only the `selectTablesOnly` clause removed | RED (2) | R-1 wall; R-1 chair |
| F1c only the closed-gate clause removed | RED (1) | R-1 gate closed mid-drag |
| F1d / F1e / F1f the move / rotate / reshape arm false | RED (1 each) | R-1 gate closed mid-drag |
| F2 both R-2 guards removed | RED (2) | R-2 readOnly; R-2 tablesOnly |
| F2a the `_execute` guard alone removed | SURVIVED | equivalent while the row's `onSelected` is null: every other `_execute` path is a disabled control or the rename, which closes without a commit on the switch (review row 32). Kept as defence. |
| F2b the row's `onSelected` alone kept | SURVIVED | equivalent while `_execute` refuses. Kept as defence. |
| F5 a mouse's reach 0 (the pre-fix pick) | RED (1) | R-5 |
| R02 picker by `reshape` | RED (1) | R-3 changeLayer |
| R03 number by `rotate` | RED (2) | R-3 renumber; R-3 rotate |
| R04 Rotation by `renumber` | RED (2) | same |
| R05 ±90 by `renumber` | RED (2) | same |
| R06 gate `delete` reads `move` | RED (1) | R-3 delete |
| R09 opening tool settings gated | RED (1) | R-4 Door tool |
| R12 reach pass without `skipLocked` | RED (2) | R-4 finger near L; the hidden and locked test |
| R13 a mouse given `reachRadiusWorld` | SURVIVED, equivalent | after R-5 it **is** the fix: `InteractionLayer` gives a mouse event no reach, so its `reachRadiusWorld` is its `pickRadiusWorld`. The behaviour R-5 asked for is pinned through F5 (the pre-fix form), red. |
| R14 column ignores `pagePanel` | RED (1) | R-4 Page panel alone |
| R17 Layer panel gets `editPage` | RED (1) | R-3 editLayers alone |

**Gates before the commit** (`pre5/`): planner `flutter test --enable-vmservice` `05:04 +1869: All tests passed!` (1854 + 15); standing comparison "1869 tests; the standing failures and skips, exactly"; analyze "No issues found!"; format "276 files (0 changed)". The full gates ran after the last commit (see `s4-task-7-report.md`, Fixes).
