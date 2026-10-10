# Slice 4, Task 5: capabilities II, the select tool and the panels (independent review)

- **Commit under review:** `62926cb` (parent `c65a3a0`), branch `claude/exciting-pasteur-9m22jv`.
- **Reviewer's clones:** `/home/user/review-s4t5` (gates, untouched at `62926cb`) and `/home/user/review-s4t5-mut` (probes, the differential, mutants). Both deleted after the review.
- **Scratch:** `/tmp/claude-0/-home-user/428cafca-0083-5012-a7ac-5456349e70a8/scratchpad/rv-s4t5/`. It holds `gates.sh` and `gates.out` with the per-package logs and JSON; `mut.py`, `mut.out` and `mutants.log`; `diff-base.log` and `diff-head.log` (the differential's traces); and the two probe files `zz_review_probe_test.dart` and `zz_full_diff_test.dart`, copied out of the clone and never committed.
- Flutter 3.47.6 at `/root/sdk/flutter/bin`, `CI=true`. Nothing was edited, committed or pushed in `/home/user/jet-cad` except this file.

## Verdict

**Approve with fixes.** The task does what the plan asks. Every gate is green and the standing sets match exactly. Every named and task-local mutant I re-applied went red, and `full` behaves as the base editor in a 32-step scripted differential. My own R-4 re-enumeration, though, found **two edit paths that edit the plan where the flags forbid it**. Both are races: the gesture or menu starts before a runtime capability change and finishes after it.

- **R-1:** a body drag or a rotation-grip drag started under `full` still commits after the host switches to `tablesOnly`. That is the S-9 h path, and it moves or turns a non-table under `selectTablesOnly`.
- **R-2:** a Layer panel colour menu opened under `full` still recolours a layer after the host switches to `readOnly` or `tablesOnly`.

Each has a two-line fix, which I tested in the scratch clone (below). The tests also hold six flag pairs that never vary apart, so six flag-swap mutants survive (R-3), and three smaller gaps (R-4).

## Gates (reviewer's run, on `62926cb`, `gates.out`)

| Package | Test | Standing comparison | Analyze | Format |
|---|---|---|---|---|
| `jet_cad_floor_plan` (`flutter test --enable-vmservice`) | `05:14 +1832: All tests passed!` | `1832 tests; the standing failures and skips, exactly` | No issues | 274 files, 0 changed |
| `apps/restaurant_demo` | `+60: All tests passed!` | | No issues | 0 changed |
| `apps/floor_planner` | `+212: All tests passed!` | | No issues | 0 changed |
| `jet_cad_2d_flutter` | exit 1 (its standing failures) | `1415 tests; … exactly` | (not edited by this task) | |
| `jet_cad_2d_gpu` | `+20: All tests passed!` | `20 tests; … exactly` | | |
| `jet_cad_2d` | exit 1 (its standing failures) | `1258 tests; … exactly` | | |

`git status` was clean after the run. The implementer's gate claims hold. The commit touches only the eight files it lists: no existing test, golden, counter or allocation test is edited (`git diff --stat c65a3a0 62926cb`), and the engine and render packages are unchanged.

## `full` is today's editor: a scripted differential against `c65a3a0`

`zz_full_diff_test.dart` mounts the editor fixture through `t.mountEditor` (`full`) and runs 32 steps. After each step it prints:
- the encoding's hash;
- the selection;
- the active tool;
- the grip count and `rotatable`;
- `canUndo` and `canRedo`;
- the canvas rect;
- every keyed widget under the view, with its enabled, read-only or selected state.

The steps cover:
- clicking, dragging and undoing the north wall;
- the column's end grip and Backspace;
- table `1`: click, body drag, +90, Mirror, number `12`, Rotation `33`, Delete, undo;
- a window band, a crossing band, Delete of the band selection and its undo;
- the room's name, the dimension kind, the wall's thickness and justification;
- `layers-add`, `page-grid` and a swatch;
- a line drawn with L, then F3, F and V.

I ran the same file on `c65a3a0` and on `62926cb` and diffed the traces (2,580 lines). They are **identical except one widget property**: `page-scale`'s `TextField.enabled` reads `null` on the base and `true` now, which behaves the same (`enabled ?? decoration.enabled ?? true`). Every document hash, selection, grip count, canvas rect and control state is equal. A mutant that made the band accept tables only under `full` (R20) is red in the existing suite (RR1, SL1, OR8), so `full` is also pinned by the unedited tests.

## R-4: the reviewer's own edit-path enumeration (from the code at `62926cb`)

I enumerated these from the code, not from the report's table. Sources:
- every `commands.execute`, `ctx.execute`, `.undo()` and `.redo()` in `packages/jet_cad_floor_plan/lib`;
- every key binding in `planner_shell.dart`, `shell_commands.dart` and `select_tool.dart`;
- every `onPressed`, `onTap`, `onChanged`, `onSelected`, `onDoubleTap` and `onSubmitted` in the right column's panels;
- every `Draggable`, `DragTarget`, `onSecondaryTap`, `showMenu` and double-tap in the editor (none, except the layer rename).

**"Probe"** means a scripted run in `zz_review_probe_test.dart`; each has a control where the outcome needs one. **"Mut"** names a mutant from the table below.

| # | Path | Flag | `tablesOnly` | `readOnly` | Evidence |
|---|---|---|---|---|---|
| 1 | 15 palette rows and letters V L P R B W D N G M S I C A T | `tools` | Select row and V only; other letters bubble | Select only (no left column) | Task 4 (M-H41, T4-a/b); differential (`full` unchanged) |
| 2 | Fill row and F | a fill tool in `tools` | absent, unbound | absent, unbound | Task 4 (T4-a, RV7) |
| 3 | Symbols tab: a cell arms, a click places | `symbol`, `symbolPalette`, `symbolFilter` | tables only (a placement is allowed) | no tab | Task 4 (M-H47(symbolFilter), T4-c) |
| 4 | Symbol tool's R, Shift+R and M | `rotate`, `mirror` | R turns (allowed); M bubbles | n/a | Task 4 (T4-d, RV1–3) |
| 5 | Shell Escape, idle select Escape | none (no edit) | selection only | selection only | |
| 6 | Select tool click / Shift-click | `selectTablesOnly` (pick) | tables only: top, box, finger reach; locked passed over, hidden absent | anything (no edit) | M-H42 S-15 tests; mutants S15-a/b/c/e, R08, R11 red |
| 7 | Hover | `selectTablesOnly` | tables only | (no edit) | render T3-b; shell pick shared |
| 8 | Band (window, crossing, Shift) | `selectTablesOnly` | tables only, also for a band started under `full` and released under `tablesOnly` (PROBE-11: 5 keys, all tables) | anything (no edit) | M-H42a/b red; PROBE-11 |
| 9 | **Body drag** (selected / unselected, wall attach) | `move` | tables move; a **drag started before a switch to tablesOnly moves a wall** | refused, byte-identical | T5-a red; **PROBE-1: R-1** |
| 10 | Centre (move-role) grip | `move` | no arc or circle is selectable | refused | render T3-c; shell shares the `move` getter |
| 11 | **Rotation grip** | `rotate` | tables turn; a **drag started before a switch to tablesOnly turns the chair** | no grip | T5-b red; **PROBE-2: R-1** |
| 12 | Leaf stretch grips; object grips (wall ends, opening slide, room label, separator ends, dimension grips) | `reshape` | none; also a drag started under `full` (PROBE-6: unchanged) | none | M-H43c red; PROBE-6 |
| 13 | Idle Delete / Backspace | `delete` | removes tables and their data; undo restores | nothing | T5-c, T5-d red |
| 14 | Undo / Redo (buttons and Ctrl+Z, Ctrl+Shift+Z, Ctrl+Y) | `undo` | allowed (the history may hold pre-switch non-table steps: Observation O-1) | hidden and unbound | Task 4 T4-e; readOnly scripted run |
| 15 | Export / Print (buttons, Ctrl+E, Ctrl+P) | `export`, `print` (no edit) | allowed; the settle commits a focused field only through its own gates | allowed | Task 4 |
| 16 | F3, OSNAP | `snapping` (no document edit) | bound | bound | Task 4 T4-f |
| 17 | Table number | `renumber` | edits | read-only, a typed `12` reverts | T5-e red (but see R-3) |
| 18 | Rotation field (table or symbol) | `rotate` | edits (tables only selectable) | read-only | T5-b2/b3 red (see R-3) |
| 19 | ±90 | `rotate` | shown | hidden; `_rotateTable` re-checks | T5-b4 red (see R-3) |
| 20 | Mirror | `mirror` | hidden | hidden; `_mirrorSymbol` re-checks | M-H43, R01 red |
| 21 | Size menu (Change size) | `reshape` | hidden (tables have none) | hidden; `_changeSize` re-checks | T5-f4 red |
| 22 | Box width / height | `reshape` | read-only (no box selectable) | read-only | shares `_capable` with the wall (T5-f red); no box in the fixture (implementer's Finding 6) |
| 23 | Wall thickness, justification | `reshape` | not selectable | read-only / disabled | T5-f, T5-f5, R10 red |
| 24 | Opening width, position; door Flip hinge / Flip swing | `reshape` | not selectable | read-only / hidden | T5-f, T5-f2 red |
| 25 | Room name | `reshape` | not selectable | read-only | T5-f red |
| 26 | Dimension kind | `reshape` | not selectable | disabled | T5-f3 red |
| 27 | Layer picker (popup) | `changeLayer` | hidden; a menu opened under `full` and picked after the switch does nothing (the button unmounted: PROBE-9, with a control that moves) | hidden | M-H43b red; PROBE-9 |
| 28 | A focused panel field across a switch | its own flag at commit | a number typed under tablesOnly, switched to readOnly before focus loss: not committed (PROBE-5); the chair's Rotation typed under full, switched to tablesOnly: dropped (PROBE-12, control commits) | — | PROBE-5, PROBE-12 |
| 29 | Tool settings (Wall, Door, Window, Gap) | none (no document edit) | tools refused | tools refused | T5-f5 and R10 red; **R09 survives (R-4)** |
| 30 | Layer panel: make current, eye, lock, add, delete, rename (double-tap) | `editLayers` (`layerPanel` shows) | hidden, kept mounted offstage | disabled | T5-g7/g9 red |
| 31 | **Layer panel colour menu (popup)** | `editLayers` | **a menu opened under full and picked after the switch recolours the layer** | **same** | **PROBE-3: R-2** |
| 32 | Layer rename field open across a switch | `editLayers` | `_editing` cleared, `LayerRow` sets `_open = false`, no commit (by reading) | same | code `layer_panel.dart:236`, `layer_row.dart:128` |
| 33 | Page panel: preset, orientation, scale (submit), unit, separator, grid, snap, page breaks, swatches | `editPage` (`pagePanel` shows) | hidden offstage, disabled | disabled | T5-g8/10/11, R15, R16 red |
| 34 | Page preset / unit dropdown open across a switch | `editPage` | `DropdownButton` reads the current `onChanged` (null): nothing (PROBE-8, control changes) | same | PROBE-8 |
| 35 | Keys typed in panel text fields | ShellShortcutGuard; the canvas Focus is no ancestor | letters and Delete stay in the field; read-only fields do not edit | same | code; readOnly suite |
| 36 | Undo restoring a deleted wall into the selection | — | not re-selected (PROBE-4); Delete removes nothing | — | PROBE-4 |
| 37 | Context menu, drag-and-drop from the palette, double-click on the canvas | — | none exist in the editor (`onTableContextMenu` and `onTableDoubleTap` are the selection mode's) | — | grep |
| 38 | Host calls `setTableData`, `undo()`, `load` (V-5) | — | allowed | allowed | the implementer's readOnly host-call test, green |
| 39 | Host `select(numbers)` | — | tables only (selection, no edit) | — | `floor_plan_controller.dart:1663-1679` |
| 40 | Selection mode | `serviceBar`, `serviceMoves` (S-22) | unchanged; `TablePicker` default `skipLocked: false` at `service_view.dart:118` and `floor_plan_controller.dart:1613` | unchanged | the unedited S9 tests green |

## Findings

### R-1 (Important): a drag started before a change to `tablesOnly` edits a non-table

**Path:** S-9 h, "a drag in progress across a change". Spec C-5 says *"Changing it at runtime takes effect at the next build"*, and the plan's S-9 h says *"its gate re-read at the up, a closed one cancels"*. Under `tablesOnly`, `move` and `rotate` stay open, so a body drag or rotation-grip drag of a wall, chair, line or group started under `full` passes the re-read at its up. It then commits through `GripDrag`, which captured the old selection. The prune at `planner_shell.dart:961-967` empties `_selection`, but it does not touch the drag in flight.

**Evidence** (PROBE-1, PROBE-2, `zz_review_probe_test.dart`; same fixture, mouse drags of 8 steps, `setCaps(tablesOnly)` after the last move and before the up):

```
PROBE-1 isWall=true selectedAfterSwitch={} changed=true canUndo=true ends ([25875.0,16875.0], [12125.0,16875.0]) -> ([25875.0,17025.0], [12125.0,17025.0])
PROBE-2 chairSelected={SelectionKey( 2B4)} isInstance=true hitsRotationGrip=true changed=true turn 10.0 -> -53.26657321810889
```

Under `tablesOnly` the north wall moved 150 mm, and the chair turned from 10° to −53°. A reshape grip drag across the same change is cancelled correctly (PROBE-6 `changed=false`), because `reshape` closes. The implementer's S-9 h test uses `tablesOnly.copyWith(move: false)` (Finding 7) and so never reaches this case.

**Fix:** in `didUpdateWidget`, inside the change to `selectTablesOnly`, cancel the select tool's gesture before pruning:

```dart
if (caps.selectTablesOnly && !old.selectTablesOnly) {
  if (_select.phase != ToolPhase.idle) _select.cancel(_context);
  ...
```

I applied this in the scratch clone. PROBE-1 and PROBE-2 then read `changed=false canUndo=false`, and all 23 Task 5 tests stay green. A cancel is not a render edit, and Escape already does the same. A killer: PROBE-1's body drag and PROBE-2's rotation grip, with the encoding byte-identical and `canUndo` false; it is red on `62926cb`.

### R-2 (Important): a Layer panel colour menu open across a change to `editLayers: false` recolours the layer

**Path:** `layers/layer_row.dart:239-244`. The colour `PopupMenuButton` is disabled by `enabled: enabled` but keeps `onSelected: widget.onColour`. Flutter's `PopupMenuButtonState.showButtonMenu` (`material/popup_menu.dart:1715-1726`) checks only `mounted` before calling the current widget's `onSelected`. Under `readOnly` the Layer panel stays mounted (shown, disabled). Under `tablesOnly` it is kept offstage (`Visibility(maintainState: true)`), so it is still mounted. `LayerPanel._update` → `_execute` (`layer_panel.dart:169-177`) never re-checks `_allowed`.

**Evidence** (PROBE-3: colour menu tapped under `full`, `setCaps`, then `layer-colour-item-1` tapped):

```
PROBE-3 target=…(readOnly)… itemsFound=1 changed=true canUndo=true
PROBE-3 target=…(tablesOnly)… itemsFound=1 changed=true canUndo=true
```

The other open-menu paths are safe and probed:
- the page `DropdownButton`s read the current, nulled `onChanged` (PROBE-8: `control=true changed=true`, `control=false changed=false`);
- the layer picker and the Size menu unmount when refused (PROBE-9: control `changed=true`, switched `changed=false`);
- the layer rename field closes without a commit.

**Fix:** guard the panel's one choke point, `void _execute(DraftCommand command) { if (!_allowed) return; … }`. This covers colour, eye, lock, make current, rename, add and delete. Pass `onSelected: enabled ? widget.onColour : null` in `LayerRow` as well. I applied the `_execute` guard in the scratch clone: PROBE-3 reads `changed=false` for both profiles, and the Task 5 tests stay green. A killer: PROBE-3 under `readOnly` and `tablesOnly`.

### R-3 (Minor, testing bar): six flag pairs never vary apart, so swapped flags survive

The three profiles keep `renumber == rotate`, `changeLayer == reshape`, `delete == move` and `editLayers == editPage`. The tests use the profiles, plus `full.copyWith(reshape: false)` and `tablesOnly.copyWith(move: false)`. These flag-swap mutants therefore stay green on both task suites:
- **R02:** the layer picker shown by `reshape`;
- **R03:** the number gated by `rotate`;
- **R04:** the Rotation field gated by `renumber`;
- **R05:** ±90 shown by `renumber`;
- **R06:** the select tool's `delete` gate reading `move`;
- **R17:** the Layer panel given `editPage`.

R17 survives because T5-g's edit test sets both `editLayers` and `editPage` false in one run. This is the degenerate-fixture failure CLAUDE.md names; the plan's fixture rule asks for "a capabilities value that is not a profile".

**Fix:** add one test per pair:
- `tablesOnly.copyWith(renumber: false)`: the number is read-only and a typed `12` is not committed, while ±90 and the Rotation field still edit (kills R03, R05);
- `tablesOnly.copyWith(rotate: false)`: the number still commits, ±90 is absent and the Rotation field is read-only (kills R04);
- `full.copyWith(changeLayer: false)`: no `layer-picker` while the wall's thickness still edits; and under `full.copyWith(reshape: false)` the picker is still present (kills R02);
- `tablesOnly.copyWith(delete: false)`: Delete removes nothing while a body drag still moves `1` (kills R06);
- T5-g split in two, each with the other panel enabled: `editLayers: false` alone and `editPage: false` alone (kills R17).

### R-4 (Minor, testing bar): three behaviours no test pins

- **R09:** `openingEditable = _editable(_Kind.openingWidth)`, without the target, survives. Under `full.copyWith(reshape: false)` the Door tool's width setting would become read-only, against S-11's "a tool's settings stay editable". Only the Wall tool's exemption is tested. **Fix:** "a tool's settings are no edit" also arms D and types a width.
- **R12:** the table picker's reach pass, without `skipLocked`, survives. A finger near `L`, beyond every unlocked table, is untested. **Fix:** a finger tap within reach of `L`'s box, outside its box, selects nothing.
- **R14:** the right column built only for the Selection or Layer panel survives the whole planner suite. **Fix:** `full.copyWith(selectionPanel: false, layerPanel: false)` shows `chrome-right` and `page-preset`.

### R-5 (Nit): the tables-only pick gives a mouse no tolerance

`_CapabilityGates.pick` passes `reach: 0` for a mouse. The index pick it replaces uses `kPickRadiusPixels` for a mouse, so a click a few pixels outside a table's box edge selects the table under `full` but not under `tablesOnly`. The mutant `reach: e.reachRadiusWorld` (R13: `pickRadiusWorld` for a mouse, `tool.dart:51`) survives the whole planner suite. **Fix:** either pass `e.reachRadiusWorld` for both kinds (a mouse then gets its pick radius), or keep 0 and pin it with a test 2 px outside `1`'s box. My recommendation is the former, for parity with `full`.

### R-6 (Nit): `page-scale` is `enabled: true` where the base had null

The differential's only difference. It behaves the same; `enabled: editable ? null : false` would make it structurally identical. No action needed.

### Observations (no change asked)

- **O-1:** under `tablesOnly`, Undo and Redo walk a history that may hold non-table steps made before the switch. A wall moved under `full`, then the host switches to `tablesOnly`: Ctrl+Z undoes the wall move. That is S-12's `undo: true` working as written. The guide should say so, because a host may expect `tablesOnly` to mean that only tables change. Clearing the history on the switch is the host's call (it can `load` the plan).
- **O-2:** the action methods' own guards (`_rotateTable`, `_mirrorSymbol`, `_changeSize`) are unreachable while their buttons are hidden, so their mutants (R18, R19) are equivalent. They are kept as defence in depth. Fine.

## Mutants

All were applied by `mut.py` to the scratch clone. Each ran with both Task 5 files (`editor_select_test.dart`, `editor_panels_test.dart`) through the JSON reporter, which recorded the failing tests by name. Each file was restored from a copy and compared byte-equal (`True` on every row). `git status` was clean afterwards.

**Re-applied, named and task-local (37, all red):**

| Mutant | Result | First killers |
|---|---|---|
| M-H42 (shell `bandAccepts` true) | RED (1) | M-H42 tablesOnly band |
| M-H42 (render band filter removed, `select_tool.dart`) | RED (1) | same |
| M-H43 (Mirror shown) | RED (2) | M-H43 1 selected; readOnly sections |
| M-H43b (picker shown) | RED (4) | M-H43; T5-h |
| M-H43c (gate `reshape` true) | RED (2) | M-H43c; readOnly scripted run |
| T5-a (gate `move` true) | RED (4) | T5-a; readOnly scripted run |
| T5-b gate / field / commit / ±90 | RED (2/2/1/2) | T5-b |
| T5-c (gate `delete` true) | RED (2) | T5-c |
| T5-d no prune / prune drops tables | RED (2/4) | T5-d; M-H42 S-15 |
| T5-e (`renumber` commit) | RED (2) | T5-e |
| T5-f fields / flips / kind / Size menu / tool-settings exemption | RED (2/1/2/1/1) | T5-f; tool settings |
| T5-g layers / page / selection shown, column, state, focus, editLayers, editPage, `_allowed`, swatches, scale | all RED (3/4/1/1/2/1/1/1/1/1/1) | T5-g tests |
| T5-h (panels under a default Theme) | RED (1) | T5-h Theme |
| S15-a / b / c / e | RED (5/1/1/1) | S-15 tests |
| S-9 h (gates read the first capabilities) | RED (6) | S-9 h and others |
| P-gatesChanged removed | RED (1) | gatesChanged |

S15-d, the implementer's compound form, was not re-applied; S15-c and S15-e cover the same skip.

**The reviewer's own (22):**

| Id | Mutant | Result |
|---|---|---|
| R01 | Mirror shown by `reshape` | RED (T5-f: the sofa's Mirror) |
| R02 | picker shown by `reshape` | **SURVIVED** (R-3) |
| R03 | number gated by `rotate` | **SURVIVED** (R-3) |
| R04 | Rotation gated by `renumber` | **SURVIVED** (R-3) |
| R05 | ±90 shown by `renumber` | **SURVIVED** (R-3) |
| R06 | gate `delete` reads `move` | **SURVIVED** (R-3) |
| R07 | gate `move` reads `rotate` | RED (S-9 h; M-H43c) |
| R08 | `_isTableKey`: any root instance (no seats) | RED (M-H42 band: the chair) |
| R09 | opening tool settings gated (no target) | **SURVIVED** (R-4) |
| R10 | wall tool settings field gated (no target) | RED (tool settings) |
| R11 | picker box pass without `skipLocked` | RED (hidden and locked) |
| R12 | picker reach pass without `skipLocked` | **SURVIVED** (R-4) |
| R13 | mouse given the reach radius | **SURVIVED**, also the whole planner suite (R-5) |
| R14 | column ignores `pagePanel` | **SURVIVED**, also the whole planner suite (R-4) |
| R15 | page orientation ignores `editPage` | RED (T5-g) |
| R16 | page breaks ignore `editPage` | RED (T5-g) |
| R17 | Layer panel given `editPage` | **SURVIVED** (R-3) |
| R18 | `_rotateTable` capability guard removed | SURVIVED, equivalent (button hidden; O-2) |
| R19 | `_mirrorSymbol` capability guard removed | SURVIVED, equivalent (O-2) |
| R20 | band accepts tables only, under `full` too | RED in the full suite (RR1, SL1, OR8); survives the two Task 5 files |
| R21 | `SelectionPanel` not given the capabilities | RED (7) |
| R22 | `_isTableKey` chain check removed | SURVIVED, equivalent (no UI path selects a chained key; a nested instance fails the `parent == root` clause) |

For R13, R14 and R20, the whole-suite runs also included my probe file, whose PROBE-7, since removed, failed on its own fixture lookup. Each row is read by its other failing names: R20 red by RR1, SL1 and OR8; R13 and R14 red by PROBE-7 alone, which means survived.

## Rulings on the implementer's findings

1. **M-H43c's "unchanged" cannot hold under `move: true`.** **Accepted.** This agrees with Task 3's review ruling on T3-e: without the end grip, the press is a body press. The killer pins "no reshape" (length kept) and, with `move: false`, byte-identity. The plan's M-H43c killer text should be amended in the results note.
2. **`skipLocked` as a constructor parameter.** **Accepted.** It is additive with a default of false, and `CountingPicker`'s override makes a `pick` parameter impossible. I checked the lib constructions: the selection mode's `service_view.dart:118` and the controller's `tableAt` at `floor_plan_controller.dart:1613` keep the default. PA1–PA3 run green under `--enable-vmservice`, and S15-c, S15-e and R11 are red. The plan's Builds should list the file.
3. **`Visibility` already excludes focus.** **Accepted.** T5-g6 (`maintainFocusability: true`) is red on its killer.
4. **No column means no kept state when all three panels are hidden.** **Accepted as the plan's own rule** (Builds: "the column itself not built when all three are hidden"). It contradicts C-5's unqualified "a hidden panel's state is kept", so the guide must name the exception. Otherwise the controller amends C-5, or the column is kept built offstage at zero width. That is the controller's call; I recommend documenting it.
5. **No shell-level centre-grip killer.** **Accepted with a note.** One `move` getter serves both paths, and the role mapping is render's T3-c. A shell killer needs an arc or circle in the editor fixture, which is Task 4's, so it is worth adding when Task 6 touches the fixture.
6. **No box in the fixture.** **Accepted.** The box fields share `_capable`'s `reshape` clause, which is red through the wall (T5-f). R-3's added tests are a natural place to place one box.
7. **A switch that adds or removes the left column moves the canvas.** **Accepted** as a test note. It is also why the S-9 h test switches to `tablesOnly.copyWith(move: false)` and missed R-1: the hole lives exactly on the profile switch that test avoided.
8. **Two `FloorPlanView`s on one controller throw.** Pre-existing and out of scope. **Accepted**; it should be recorded for Task 7's notes.
9. **The delete tooltip reuses `layersLocked`.** **Accepted.** No new strings in this task.
10. **A stale cursor until the next move.** **Accepted** (Task 3's R-4.3).
11. **Bands select under `readOnly`.** **Accepted.** A selection is no edit (Task 3 RV-7).

## Other claims verified

- **`selectTablesOnly`'s pick, band and prune:**
  - pick: the M-H42 S-15 tests and the S15 and R08/R11 mutants are red;
  - band: PROBE-11, a band begun under `full` and released under `tablesOnly`, holds the five unlocked visible tables only;
  - prune: T5-d and T5-d2 are red.
- **Hidden panels keep state:** the Layers open state and the page scale's focus node survive a hide and show (T5-g5 red); a hidden panel is out of the focus order (T5-g6 red). The exception is all three hidden (Finding 4).
- **`readOnly` still allows the host's own calls:** `setTableData`, `undo()` and `load` work (the implementer's test, green in my run). It pins V-5.
- **`TablePicker(skipLocked:)` is additive and the selection mode unchanged:** the default is false at every other construction site, and the selection mode's suites are unedited and green.
- **C-8:** under `tablesOnly` no `DropdownButton`, `PopupMenuButton` or `MenuAnchor` is on stage (T5-h; M-H43b red).

## Asked of the implementer

1. **R-1:** cancel the select tool's gesture on a change to `selectTablesOnly`; add PROBE-1 and PROBE-2 as killers.
2. **R-2:** guard `LayerPanel._execute` with `_allowed` (and null the colour menu's `onSelected` when disabled); add PROBE-3 as a killer.
3. **R-3 and R-4:** add the listed tests; each named mutant (R02–R06, R09, R12, R14, R17) must then be seen red.
4. **R-5:** choose the mouse reach and pin it.
5. **Findings 4 and O-1:** route both to the guide (Task 7) or to a spec amendment, the controller's call.
