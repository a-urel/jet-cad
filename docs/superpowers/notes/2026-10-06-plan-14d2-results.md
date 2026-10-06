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
| 5 The exit (this note, STATUS, roadmap) | in progress |

**Process, stated plainly:** as in 09c-2, the tasks were implemented by
the controller itself, without a fresh implementer or a per-task
reviewer; every mutant below was fired by the controller against its
own tests. The spec had an independent review (revision 1 → 2); the
code has had none yet.

## Gates (Linux container, Flutter 3.47.6 / Dart 3.13.5)

**Pending:** the exit's gates are running; this section is filled in
by the next commit, with the web build and the Chromium smoke.

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
