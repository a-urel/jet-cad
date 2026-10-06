# Plan 14d-2 results — the service layout and the service options

**Branch:** `claude/exciting-pasteur-9m22jv`, on `main`'s `243cee5`.
**Spec:** [2026-10-06-pos-readiness-design.md](../specs/2026-10-06-pos-readiness-design.md),
revision 2 (S1–S9 as amended; V-1, V-2, V-3, V-8, V-15). **Plan:**
[2026-10-06-service-layout-and-options.md](../plans/2026-10-06-service-layout-and-options.md).
**Approval:** the spec at revision 2 and the plan by the human
(2026-10-06: *"Q0 evet, diğerleri de önerdiğin gibi, plana geç"*, then
*"evet, başla"*). **Not merged.**

A host can now keep the selection mode's table moves across a restart:
`serviceLayoutJson()` gives the moved tables as a small versioned JSON,
`restoreServiceLayout(json)` puts them back on a fresh service copy as
its floor (no Undo removes them), dropping every entry whose table the
design has since moved, renumbered, deleted, locked or hidden, or which
would turn the table. `serviceLayoutChanges` tells the host when to save
— never on a mode switch or a load, which would overwrite the stored
layout with an empty one. A view can forbid service moves
(`serviceMoves: false`: a drag from a table pans), reports a secondary
click on a table (`onTableContextMenu`, at the pointer's global
position, after selecting the table alone unless it is already
selected), and can make a long press do the same
(`longPress: FloorPlanLongPress.contextMenu`). The demo keeps each
area's layout, so Design and back shows the moves again; its discard
question is gone, Reset layout drops them; a right click opens a table
menu; a Moves switch and a Long press switch show the options.

## Commits

| Task | Commit |
|---|---|
| Spec rev 1, rev 2, approval and plan | `82942ea`, `bd30e9f`, `4371f20` |
| 1 The layout codec and its strict match | `c5c37ec` |
| 2 The controller: save, restore, `serviceEdited`, `serviceLayoutChanges` | `2a48a62` |
| 3 The service options | `0f11c38` |
| 4 The demo | `fad3ce8` |
| 5 The exit (this note, STATUS, roadmap) | this commit |

**Process, stated plainly:** as in 09c-2, the tasks were implemented by
the controller itself, without a fresh implementer or a per-task
reviewer; every mutant below was fired by the controller against its
own tests. The spec had an independent review (revision 1 → 2); the
code has had none yet.

## Gates (Linux container, Flutter 3.47.6 / Dart 3.13.5)

| Package | Result |
|---|---|
| engine `packages/jet_cad_2d` | **1,241 passed** + 2 standing (`generate_document_test`); analyze, format clean; untouched |
| render `packages/jet_cad_2d_flutter` | **1,240 passed** + 1 skip + 7 standing (the text ladders); analyze, format clean; untouched |
| planner `packages/jet_cad_floor_plan` | **1,183 passed** (+18: LC1–LC5's 10, C16–C19, SO1–SO4); analyze, format clean |
| restaurant symbols | **94 passed**; analyze, format clean |
| app `apps/floor_planner` | **201 passed**; analyze, format clean |
| demo `apps/restaurant_demo` | **20 passed** (+3: D16–D18; D3 and D10 rewritten for S9); analyze, format clean |
| `apps/dev_harness_2d` | analyze clean |
| web builds | `apps/restaurant_demo` and `apps/floor_planner`: `✓ Built build/web` |

The two allocation invariant tests and the goldens are untouched.

**Smoke (Chromium, tr-TR, the demo's web build at `fad3ce8`):** in
Service, a right click on table 2 opens the demo's menu (*Table 2*,
*Select only this*, the four statuses) with table 2 selected and no
browser menu; *Bill* colours it. Table 1 dragged down, then Design (no
question; the editor shows table 1 at its designed place) and Service
again: table 1 is moved, the log reads *layout restored, 1 moved, 0
dropped*. Reset layout puts it back. Moves off: a drag from table 3 pans
the whole plan and logs no layout change. No page or console error.

## Mutants fired

All red unless listed under *Survive*. Each was applied to a copy of the
file, the named tests run, and the file restored and compared.

- **Task 1** (`test/host/service_layout_test.dart`): **M-14d-l** by
  handle only, by number only, the number ignored, `from` ignored, the
  layer ignored, the lock ignored, the linear part unchecked, finiteness
  unchecked; duplicate handles allowed; **M-14d-n** entries in reverse
  (selection) order; a table moved back exactly still listed; numbers
  read as `double` only (the web's `1`).
- **Task 2** (`test/host/controller_test.dart`): **M-14d-m** history kept
  after a restore, `serviceEdited` by undo depth; **M-14d-r** a bump on
  `setMode`, a bump on `load`, none on `resetLayout`, none on an edit,
  none on a restore; **M-14d-t** a layout in the design mode; the
  selection not re-applied after a restore; every entry applied
  regardless of the match; a restore allowed in the design mode.
- **Task 3** (`test/service/service_options_test.dart`, through
  `FloorPlanView`): **M-14d-o** the flag ignored, the options read once;
  **M-14d-p** the context gesture selecting nothing, replacing a
  selection that holds the table, selecting a locked table, the long
  press still toggling under `contextMenu`, a locked table's long press
  unreported, the long press's local point, the click's local point, a
  slide past the slop reported, the listener removed.
- **Task 4** (`apps/restaurant_demo/test/demo_test.dart`): the layout
  kept on `revision` (overwritten by a mode switch), no restore on
  entering the service, no restore after a Revert there, Moves not
  passed, the menu not wired, the menu's status ignored.

**Survive, recorded:** none left. One survived and its code was removed:
installing the parametric and table-label systems for the restore's
edit. A restore only translates (S2), a translation re-stamps no table
label (`restampedTableLabel` returns null, 14a T12) and no parametric
object reads a table, so the systems could not change the result; the
restore now executes without them (`2a48a62`).

## Amended at execution

- **`ServiceLayoutRestore`** carries the applied and dropped entries'
  numbers as two `List<String?>` (null for an unnumbered table), whose
  lengths are the counts (S2 as amended: "counts and entries").
- **The secondary click's selection rule is one function**,
  `contextSelect`, shared by the view's `Listener` and the tool's long
  press.
- **`ServiceOptions`** is a second record beside 14c's
  `ServiceCallbacks`, so the existing tool tests did not change.
- **The barrel test** reads a `show` list the formatter wrapped onto
  several lines (whitespace collapsed before its `' show '` check).

## Found, not fixed

- **The restore drops a stale entry for good:** after a restore,
  `serviceLayoutChanges` saves the layout without the dropped entries
  (they no longer match the design). A host wanting them back must keep
  the older text itself.
- **A secondary click during a two-finger pinch** is ignored only through
  the tool's phase; the interaction layer's touch session is private.
  Not reachable with one mouse and one hand.
- **No device was measured** for the long press as a context menu.

## For the human

- **Look owed (macOS and web), in the demo's Service:** move a table,
  go to Design and back (the table is still moved), Reset layout (it
  goes back); right click a table (the menu, its status); turn Moves off
  and drag a table (the plan pans); on a tablet, turn *Long press: menu*
  on and hold a table.
