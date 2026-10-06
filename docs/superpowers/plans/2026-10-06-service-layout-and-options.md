# Plan 14d-2 — the service layout and the service options

**Spec:** [2026-10-06-pos-readiness-design.md](../specs/2026-10-06-pos-readiness-design.md),
revision 2, approved by the human (2026-10-06: *"Q0 evet, diğerleri de
önerdiğin gibi, plana geç"*): S1–S9 of slice 14d-2 as revision 2 amends
them (S1, S2, S4, S5, S6, S7, S9 amended; V-1, V-2, V-3, V-8, V-15), and
the mutants M-14d-l, -m, -n, -o, -p, -r and M-14d-t's S1 and S7 parts.
**Branch:** `claude/exciting-pasteur-9m22jv`, at `main`'s `243cee5` plus
the spec commits. **Order:** the first slice of 14d (Q4).

## Global constraints

- `CLAUDE.md` non-negotiables. **The engine and the render package are
  not touched** (V-1: the secondary click is the service view's own
  `Listener`); the two allocation invariants and the goldens untouched;
  no schema change.
- Every task ends with the planner, app and demo gates green (tests,
  analyze, format). Engine and render are run once, at the exit, to show
  them unchanged (2 standing and 7 + 1 skip standing).
- **Transforms compare by stored value**: `Transform2` has no `==` by
  design (`transform2.dart:123-126`); S1's "differs" and S2's match use a
  private six-double exact comparison, never `equals(…, Tolerance)` (I-5).
- 14c S8 stands: `onLayoutChanged` once per drag. Callbacks carry
  numbers, never handles (D18).
- Every fixture's tables are turned, mirrored and off the origin; layout
  values off-grid.

## Tasks

### Task 1 — the layout codec (S1, S2; pure Dart)

New `lib/src/host/service_layout.dart`, no Flutter import:

- `ServiceLayoutEntry(handle, number, from, to)` and
  `List<ServiceLayoutEntry> serviceLayoutOf(DraftDocument design,
  DraftDocument copy)`: for each table of `TableSurvey.of(copy).tables`
  (ascending by handle) whose instance exists in `design` and whose copy
  transform differs from the design's by stored value. `encodeServiceLayout`
  writes S1's JSON (`format`, `version: 1`, handles by `toHex()`,
  `from`/`to` by `Transform2.toJson()`).
- `decodeServiceLayout(String)`: a `FormatException` unless the format
  and version match, `tables` is a list, each handle parses
  (`Handle.parseHex`), each `number` is a string or null, `from` and `to`
  are six numbers read as `(v as num).toDouble()` (V-21), and no handle
  repeats (V-8).
- `ServiceLayoutMatch matchServiceLayout(DraftDocument design,
  List<ServiceLayoutEntry>)`: an entry applies iff its handle is a table
  of the design's survey, an `InstanceNode` at the root, on a layer that
  is visible and unlocked, its number equals, its transform equals `from`,
  `to`'s linear part equals `from`'s and all twelve values are finite
  (S2 as amended). Returns the applied and dropped entries.

Tests `test/host/service_layout_test.dart`: round trip; byte-equal twice
and after an encode–decode of the design; ascending by handle with
tables moved in **descending** order (M-14d-n); each refusal; each drop
— moved, renumbered, deleted, locked, hidden in the design since, `to`
turning the table, a NaN (M-14d-l, two mutants: by handle only, by
number only); a `1` and a `1.0` read alike.

### Task 2 — the controller (S1–S4)

`FloorPlanController`:

- `String? serviceLayoutJson()` — `null` in the design mode (M-14d-t).
- `ServiceLayoutRestore restoreServiceLayout(String json)` — a
  `StateError` in the design mode; decode first (a `FormatException`
  changes nothing); then a fresh `_copyOf(_design)`, on which
  `installParametric` and a `TableLabelSystem` are installed (as the
  service view does, 14c R-4), the applied entries executed as one
  `CompoundCommand` of `TransformNodeCommand(h, to)`, the systems
  disposed last-in first-out, `clearHistory()`; only then `_attach`, the
  old copy dropped, the selection re-applied by number, flags, `revision`
  and listeners, as `resetLayout` does. `ServiceLayoutRestore` (new, in
  `floor_plan_types.dart`, exported): `applied` and `dropped`, each a list
  of `(String? number)` entries plus counts.
- `serviceEdited` = the copy's layout is not empty (S3).
- `Listenable serviceLayoutChanges`: bumped by the copy's own change
  stream (a drag, Undo, Redo in the selection mode), by `resetLayout` and
  by `restoreServiceLayout`; never by `setMode`, `load` or `newPlan`
  (S4 as replaced).

Tests in `test/host/controller_test.dart`: M-14d-m's three discriminating
cases (a restore then Undo: nothing, edited; a move dragged back exactly:
not edited, depth 1; restore, move, Undo: edited); M-14d-r's controller
half (fires on drag, undo, redo, reset, restore; never on `setMode`,
`load`); restore under the design mode; a malformed text changes
nothing; the restored table's number upright and its status drawn (the
label system ran). Existing `serviceEdited` tests follow S3.

### Task 3 — the service options (S5–S7)

- `FloorPlanView` gains `serviceMoves = true`,
  `onTableContextMenu(String number, Offset globalPosition)`,
  `longPress = FloorPlanLongPress.toggleSelection`; the enum is new in
  `floor_plan_types.dart`, exported. `ServiceCallbacks` carries the three,
  read at each call (14c R-5).
- `TableSelectTool`: on the move past the slop with a hit, `serviceMoves`
  false → panning, locked or not (S5). Under `contextMenu`, the
  long-press timer also starts on a locked hit; `_longPress` then
  applies the context selection rule and reports through a
  `void Function(String number, Offset screen)` the view supplies, which
  converts by its canvas render box (`GlobalKey`, S7). One helper,
  `contextSelect(hit, selection)`, holds S6's rule for both paths:
  unselected and unlocked → selected alone; selected → kept; locked →
  unchanged; returns the number or null.
- `ServiceView` wraps its `PlannerView` in a `Listener` for the
  secondary button (mouse, stylus): the down recorded unless the tool's
  phase is not idle or a touch is live; the up within `kTouchSlop` picks
  through `_picker.pick(world)` at the up and, on a hit, `contextSelect`
  and `onTableContextMenu(number, event.position)`. Modifiers change
  nothing; `onTableTap` never fires for it.

Tests `test/service/service_options_test.dart`, all through
`FloorPlanView`: M-14d-o (a drag on a selected table pans, the dispatcher
spy sees nothing; the flag switched after mount); M-14d-p (secondary
`tapAt` on an unselected, a selected among three, a locked and an
unnumbered table; empty floor; Ctrl+primary still toggles; a touch long
press under `contextMenu` reports at 500 ms from contact and toggles
nothing, M-14d-t; under the default it still toggles).

### Task 4 — the demo (S8, S9)

`apps/restaurant_demo/lib/main.dart`:

- per area, `layout` (the last `serviceLayoutJson()`), kept on
  `serviceLayoutChanges`; entering Service restores it and logs
  `restored N, dropped M`; Revert in Service restores after the load;
- the discard dialog removed (S9 as amended); **Reset layout** clears;
- a **Moves** switch (S5) and a **Long press: menu** switch (S7);
- `onTableContextMenu` opens a `showMenu` at the position: the number as
  a disabled title, *Select only this*, then the four statuses applied to
  `selectedTables`;
- on the web, `BrowserContextMenu.disableContextMenu()` in `main` (S8).

Tests `apps/restaurant_demo/test/demo_test.dart`: the dialog tests become
the round trip (move, Design, Service: moved again; Reset layout: back),
M-14d-r's demo half (start-up and a Revert in Service keep the stored
layout), the menu sets a status, the Moves switch.

### Task 5 — the exit

Every gate (engine, render, planner, restaurant symbols, app, demo,
`dev_harness_2d` analyze, both web builds); a Chromium smoke of the
demo's web build (right click on a table opens the menu and sets a
status; Moves off pans; a moved table survives Design → Service; Reset
layout); the results note `docs/superpowers/notes/2026-10-06-plan-14d2-results.md`
with the mutants fired; `STATUS.md` and the roadmap's 14 row.

## Exit gate

All of Task 5 green, every named mutant red, and the human's look owed
(a touch device for S7).
