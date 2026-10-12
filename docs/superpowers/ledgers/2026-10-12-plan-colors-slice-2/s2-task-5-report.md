# Slice 2, Task 5 report: tables in the Colour row, the tool-mode pin

Commit: `b31fc5c5` feat(floor-plan): the Colour row colours tables (on f0be47c).
Status: DONE (one concern, below).

## Implemented
- `lib/src/colors/color_picker.dart`: `_tables` (key order, each once, via `tablesOf(doc)` instances), `_keptMarker = '\u0001'`;
  `pickedColors` = rooms then tables (null / marker / stored name); `recolorCommand` appends one
  `SetComponentCommand<FloorPlanTableColor>(h, wanted)` per table whose component `!= wanted`
  (`wanted` = `FloorPlanTableColor(color)` or null, so None removes a colour or a kept payload);
  `colorPickerBlocked` unchanged; file comment updated.
- `lib/src/selection_panel.dart`: only the `colors` flag's comment ("a room or a table").
- `test/colors/color_picker_test.dart`: CP1 leg rewritten; CP7-CP11 added.

## Files
packages/jet_cad_floor_plan/{lib/src/colors/color_picker.dart, lib/src/selection_panel.dart, test/colors/color_picker_test.dart}

## TDD evidence
- RED (after writing tests, before implementing): `flutter test --enable-vmservice test/colors/color_picker_test.dart`
  -> `00:06 +8 -5: Some tests failed.` CP7, CP8, CP9, CP10, CP11 failed, all with
  "Found 0 widgets with key [<'color-picker'>]" (the row absent for a table) or the resulting null colour.
  The 8 older tests (incl. rewritten CP1) passed.
- GREEN: same command after implementing -> `00:13 +13: All tests passed!`

## CP1's Wall-tool leg (old -> new)
- Old: select room A, press W, expect `wall-section` and no picker. Vacuous: pressing W clears the selection
  (planner_shell.dart), so the row was absent for lack of a selection.
- New: press W, expect `wall-section`; then `rig.select([r.a])` (the rig's `view.selection.replace`, the
  panel-level equivalent of `controller.select`), premises `{...rig.view.selection.keys} == {k(r.a)}` and
  `wall-section` still present; then the picker is absent.
- CP11 (new) is the table version through `FloorPlanView`: `selectTool(FloorPlanTool.wall)`, then
  `controller.select({'1'})`; premises: `activeTool.value == wall`, selection is exactly table 1,
  `wall-section` present; picker absent; back on the select tool the picker shows. Both selecting and the
  tool survive, so the mutant is NOT equivalent: the state is reachable.

## Mutants (each applied, run, seen red, reverted by copying the saved good file back)
Command for each: `cd packages/jet_cad_floor_plan && flutter test --enable-vmservice test/colors/color_picker_test.dart`
- M-C12 (tables): deleted the `for (final h in _tables ...)` loop in `recolorCommand`.
  Red: `00:06 +9 -4`; CP7 (`Expected: FloorPlanColor.teal  Actual: <null>`, line 666), CP8
  (`Expected FloorPlanTableColor(teal), Actual FloorPlanTableColor({"color":7})`), CP9
  (`Expected ['Colour'] Actual []`), CP10 (`Expected purple, Actual teal`). Killer: CP7 (also CP8-10).
- M-PC9-t: kept payload listed as `null` instead of `_keptMarker`.
  Red: `00:05 +12 -1`; CP8 `Expected: null  Actual: 'none'` (line 745, kept table alone marks `none`).
- M-PC9-tool: `colors = pickedColors(...).isNotEmpty` (both conjuncts dropped).
  Red: `00:06 +11 -2`; CP1 (line 358, "Expected: no matching candidates ... Found 1 widget with key 'color-picker'")
  and CP11 (line 868, same). Killer: CP1's rewritten leg and CP11.
All three reverted (`cp` of the saved copies); the final diff holds only the intended change.

## Gates (all green)
- planner `flutter test --enable-vmservice`: `01:52 +1982: All tests passed!` (re-run after the last edit)
- planner `flutter analyze`: `No issues found!`; `dart format --output=none --set-exit-if-changed .`: `Formatted 293 files (0 changed)`
- apps/floor_planner: `+211: All tests passed!`; analyze clean; format 0 changed
- apps/restaurant_demo: `+68: All tests passed!`; analyze clean; format 0 changed
- `git status` before commit: only the three files; no analysis_options.yaml.

## Deviations
- The brief's CP1 route (`controller.select` after W) does not exist in CP1's PlannerShell rig (no controller);
  used the rig's `view.selection.replace` after W (the ledger's "re-select after W"), and put the table /
  controller form in CP11 on the editor fixture. Verified: selecting under the Wall tool neither cancels the tool
  nor is cleared.
- CP7-CP11 use the editor fixture (`test/host/editor_fixture.dart`, a non-test file) through a small local
  `mountEditor` in color_picker_test.dart rather than importing `editor_tools_test.dart`'s helper. Table `1`
  (turned 30 deg) and `2` (mirrored at 90 deg) off the origin, `7`/` 7 ` sharing a number, startup-plan room.
- No drawing is asserted in this task, so the fixture's circular-top / opacity / hidden-layer clauses were not needed.

## Self-review
- Selection panel `colors` flag already used `pickedColors(...).isNotEmpty`, so tables appear with no panel logic change.
- Kept payload: `None` removes it (kept != null), a swatch replaces it; tested in CP8.
- Locked-layer tables cannot be selected via `controller.select` (skipped), unchanged and out of scope.
- `SetComponentCommand<FloorPlanTableColor>(h, null)` removes the component; undo restores it (CP7).

## Concerns
- `tablesOf(doc)` (`TableSurvey.of`) runs on every panel build; it is cached on the document by the survey, and the
  frame-path allocation tests (untouched) stayed green, but I did not profile the panel build itself.

---

# Fix round 1: the Colour row checks tables per key, not by a survey

Issue (Important): `_tables` called `tablesOf(doc)` (`TableSurvey.of`, O(nodes + entities)), and the panel's
`colors` flag runs `pickedColors` on every build, so every hover notification rescanned the document (R-7).

## What changed
- `lib/src/tables/table_index.dart`: the survey's servable test is now one shared private predicate
  `_isServable` (definition live and carrying a `SeatingComponent`), used by `TableSurvey.of` (behaviour
  unchanged) and by a new public O(1) `isTable(doc, handle)` (live `InstanceNode`, parent is the root, servable).
  `TableSurvey.surveys` (`@visibleForTesting static int`) counts surveys, the hook the pin reads.
- `lib/src/colors/color_picker.dart`: `_tables` returns `const []` for empty keys and otherwise tests each
  distinct key target with `isTable`; no survey, no `tablesOf`.
- `test/colors/color_picker_test.dart`: CP12. No R-7 pin existed (no survey counter anywhere in the tests), so
  CP12 adds one: with two tables and a room selected, hovers over each key, over none, and back (13 `setHover`
  calls with pumps) leave `TableSurvey.surveys` unchanged; `pickedColors` (empty and full selection) and
  `recolorCommand` leave it unchanged; `isTable` is true for the fixture's tables (hidden `5`, locked `L`,
  both `7`s included) and false for a room, the root and a handle with no node.

## Mutant (the plan's original form)
`_tables` restored to `final tables = {for (final t in tablesOf(doc)) t.instance}; ... tables.contains(h)`:
`flutter test --enable-vmservice test/colors/color_picker_test.dart` ->
`Expected: <392>  Actual: <406>` (color_picker_test.dart line 896, "a hover rebuild rescanned the document"),
`+13 -1: Some tests failed.` (only CP12; 14 surveys over the hovers). Reverted by copying the fixed file back
(`grep -c tablesOf color_picker.dart` -> 0).

## Gates
- `flutter test --enable-vmservice test/colors/color_picker_test.dart test/selection_panel_test.dart`: `+45: All tests passed!`
- planner full suite: `01:56 +1983: All tests passed!`; `flutter analyze`: No issues found; `dart format ...`: 0 changed
- apps/floor_planner `+212` and apps/restaurant_demo `+68`: All tests passed.
