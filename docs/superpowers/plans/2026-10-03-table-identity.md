# Plan 14a — table identity

**Spec:** [2026-10-03-table-identity-design.md](../specs/2026-10-03-table-identity-design.md),
revision 2 (the human's rulings on Q-1 to Q-4; "bu branch'te devam
edebiliriz", 2026-10-03). Decisions T1–T16, facts F-1–F-17, mutants
M-14a-1 to M-14a-20.
**Branch:** `claude/exciting-pasteur-9m22jv` (spec at `c68df27`).
**Toolchain:** Flutter 3.47.6 / Dart 3.13.5 in the Linux container (floor
3.44.0).

## Global constraints

- `CLAUDE.md` non-negotiables; no rewritten `analysis_options.yaml`
  committed.
- **The engine (`packages/jet_cad_2d`) is not edited.** The render package
  (`packages/jet_cad_2d_flutter`) is edited in Task 1 only, in
  `selection.dart` and `select_tool.dart`.
- The two allocation invariant tests are untouched and green; no golden PNG
  changes; the palette's thumbnails unchanged.
- No schema bump; `furniture.jetlib` and `restaurant.jetlib` byte-equal.
- Fixtures off the origin, rotated 37°, mirrored, on a non-default layer;
  expected numbers written out by hand.
- Every task ends with its packages' gates green:
  `flutter test && flutter analyze && dart format --output=none
  --set-exit-if-changed .` (render: also the 7 standing failures stay
  exactly those 7).

## File structure (new and changed)

```
packages/jet_cad_2d_flutter/lib/src/selection.dart        T11
packages/jet_cad_2d_flutter/lib/src/select_tool.dart      T9
packages/jet_cad_floor_plan/lib/src/tables/
  table_label.dart          tag, height rule, tableLabelStamp, label record
  table_numbers.dart        validateTableNumber, nextTableNumber
  table_index.dart          TableInfo, tablesOf, tableDiagnostics
  table_label_system.dart   TableLabelSystem, TableLabelEdit (T12)
  table_rotate.dart         rotateTableCommand (T16)
packages/jet_cad_floor_plan/lib/src/symbols/symbol_placer.dart   T13
packages/jet_cad_floor_plan/lib/src/symbols/symbol_panel.dart    numbered: false
packages/jet_cad_floor_plan/lib/src/planner_shell.dart           install/dispose
packages/jet_cad_floor_plan/lib/src/selection_panel.dart         T14, T16
```

## Tasks

### Task 1 — render: the pick mapping and the delete cascade (T9, T11)

- `resolveHit`: a leaf owned by an `InstanceNode` maps to the topmost group
  above it, else the root-level node above the owner (the instance).
- `_deleteSelection` / `_groupCascade`: an instance's owned entities removed
  first, ascending, from `byOwner`, fills of removed boundaries skipped,
  de-duplicated through `names`/`named`.
- Tests (render package): an off-origin, 37°-rotated, mirrored instance with
  an ATTRIB away from every definition line — the pick on the ATTRIB's
  glyph box resolves to the instance key (M-14a-6); a drag starting there
  moves the instance (F-14); Delete leaves no `entity.owner_missing`, also
  inside a deleted group, and undo restores the ATTRIB's text (M-14a-5); a
  selection of the ATTRIB key and the instance key deletes in one step
  (M-14a-19).
- **Done:** render gate (only the 7 standing failures).

### Task 2 — the table model (T1–T8, T10, T15)

- `table_label.dart`: `kTableLabelTag = 'TABLE'`; `tableLabelHeight`
  (`min(200, 0.4 × min side)` of the first leaf's local box);
  `tableLabelStamp(Transform2)`; `tableLabelRecord(...)` building the
  `EntityRecord` and payload (T8, layer 0).
- `table_numbers.dart`: `validateTableNumber` (T4), `nextTableNumber` (T5,
  8 digits, the smallest-unused fallback).
- `table_index.dart`: `TableInfo(instance, label, number, seats,
  symbolKey)`, `tablesOf`, `tableDiagnostics` (four codes).
- Tests: M-14a-1, -3, -4 (equality rules), -7, -8 (stamp on a world map,
  numerically), -14, -18; the diagnostics on a hand-built document.
- **Done:** planner gate.

### Task 3 — placement numbers the table (T13)

- `placeSymbol(..., bool numbered = true)`: servable and numbered → label
  after the `AddNodeCommand`; `symbolThumbnailDocument` passes `false`.
- Tests: M-14a-13, -16, -17; SE8 extended (the label with the placement,
  one undo); the restaurant and app suites still green.
- **Done:** planner, restaurant and app gates.

### Task 4 — the table system (T12)

- `TableLabelSystem.install/dispose` (stacking, LIFO assert);
  `TableLabelEdit` (stamps by exact compare, replay inverse with inner's
  authority, all or nothing). Shell installs after the parametric system,
  disposes before.
- Tests: M-14a-9, -10 (undo and redo), -11 (both orders), -20; the render
  check (`DraftPainter` into a recording sink, screen and page camera:
  `k × camera` linear part).
- **Done:** planner and app gates (`document_host_test` slot pins green).

### Task 5 — the Table section and the rotate buttons (T14, T16)

- `table_rotate.dart`: `rotateTableCommand(doc, instance, quarterTurns)`
  (about the base point, exact linear part, `−0.0` cleaned, `Rotate`
  compound).
- `selection_panel.dart`: the Table section (Number, Seats, two rotate
  buttons, the error and duplicate lines, the enable rules, the per-change
  cache).
- Tests (widget): M-14a-2 (a deleted number is accepted), -4 at the field,
  the Q-2 ruling (`101` → next `102`), -12 (layer picker to a hidden layer
  hides the number), -15, a refused commit reverts and shows the error.
- **Done:** planner and app gates.

### Task 6 — the exit

- Every gate: engine (untouched, 2 standing), render (7 standing), planner,
  restaurant, app, `flutter build web`, dev harness analyze.
- A Chromium smoke on the web build: place two tables, rotate one, the
  numbers read upright; screenshot for the human.
- Results note `docs/superpowers/notes/2026-10-03-plan-14a-results.md`;
  STATUS head entry.

## Review

Tasks 1, 2–3 and 4–5 each get an independent reviewer (re-runs the gates in
its own worktree, fires its own mutants). Findings are applied before the
next task's review.
