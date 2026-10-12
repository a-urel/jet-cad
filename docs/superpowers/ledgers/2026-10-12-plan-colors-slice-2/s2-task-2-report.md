# Report: plan colours Slice 2, Task 2 (the table colour component and the host API)

Status: DONE (one deviation, below). Commit: `ebd5d1a4` on `feat/plan-colors-slice-2`.

## Implemented

- `lib/src/tables/table_color_component.dart` (new): `FloorPlanTableColor`
  (`jetcad.table_color`), modelled on `FloorPlanTableData`: `name`, `kept`,
  `isKept`, `colorValue`, `toJson`, `fromJson` (never throws), `==`/`hashCode`
  by the encoded payload. No Flutter import.
- `parametric/catalog.dart`: registered after `FloorPlanTableData`.
- `tables/table_index.dart`: `TableSurvey._invalidColor`, the
  `table.invalid_color` warning (message verbatim from the brief),
  `TableDiagnosticCodes.invalidColor`.
- `host/table_detail.dart`: `FloorPlanTableDetail.color` in `==`, `hashCode`,
  `toString`; `tableDetailOf` / `tableDetailWithoutGeometry` take `color`.
- `host/floor_plan_controller.dart`: `_detailsOf`/`_detailOf` read the colour;
  `setTableColor`, `setTablesColor`; the shared private
  `_setTableComponents<T extends Component>(wanted, label, who)`;
  `setTablesData` validates its maps then calls it; a small `_requireDesign(who)`
  throws the `StateError` (`'setTableData needs the design mode (P-5)'` for
  data, `'setTableColor needs the design mode (P-5)'` for colour).
- `test/host/table_color_test.dart` (new): TC1-TC9.

## TDD evidence

RED: with the four modified lib files put back to HEAD (`git show HEAD:...`),
`flutter test --enable-vmservice test/host/table_color_test.dart` ended
`00:00 +0 -1: Some tests failed.` with compile errors such as
`The getter 'color' isn't defined for the type 'FloorPlanTableDetail'`
(the file fails to load). The implementation was written before the tests were
run, then reverted for the RED run (not a strict test-first order; said plainly).

GREEN: lib restored, `flutter test --enable-vmservice test/host/table_color_test.dart`
-> `00:01 +9: All tests passed!`.

## Gates

- `packages/jet_cad_floor_plan`: `flutter test --enable-vmservice` ->
  `01:58 +1957: All tests passed!`; `flutter analyze` -> `No issues found!`;
  `dart format --output=none --set-exit-if-changed .` -> `Formatted 290 files (0 changed)`.
  After the final test re-ordering (TC3), `test/host test/tables` ->
  `00:55 +682: All tests passed!`, analyze and format clean again (lib is
  byte-identical to the full-suite run).
- `apps/floor_planner`: `flutter test` -> `00:35 +212: All tests passed!`;
  analyze clean; format `Formatted 47 files (0 changed)`.
- `apps/restaurant_demo`: `flutter test` -> `00:18 +68: All tests passed!`;
  analyze clean; format `Formatted 9 files (0 changed)`.
- Existing table-data tests (`table_data_test.dart`, `tables/table_data_test.dart`)
  pass unedited. No `analysis_options.yaml` or `pubspec.lock` in the commit.
- `jet_cad_2d` and `jet_cad_2d_flutter` untouched, so their suites were not re-run.

## Mutants (each applied, killer run, red seen, reverted with `git show HEAD:path > path`)

Command for each: `flutter test --enable-vmservice test/host/table_color_test.dart`
(M-PC11-a also with `test/host/table_data_test.dart`).

- **M-C1 (tables)**: `fromJson` throws `FormatException` for an unknown name and
  for an ill-typed/other-shape payload. Red: TC1 and TC7 (`Not a floor plan:
  FormatException: bad table colour` when loading the plan). Reverted.
- **M-C2**: `toJson` returns `{'color': name}` always. Red: TC1
  (`Expected: {'color': 7}  Actual: {'color': null}`) and TC7's save
  (`Expected: ... :{"color":7},"24":{" ...  Actual: ... :{"color":null},"24" ...`). Reverted.
- **M-C9**: each entry executed as it is found (no all-or-nothing). Red: TC3,
  `Expected: null  Actual: FloorPlanColor:<FloorPlanColor.teal>` with
  `reason: shared number` (table 1 was recoloured before the bad `7`). First attempt
  (an extra execute inside the loop) failed TC3's one-step assert first and masked
  the bad-entry loop, so TC3 was re-ordered (bad maps first) and the mutant re-run to
  fail on the intended assertion. Reverted.
- **M-C11**: owned by the engine's `RemoveNodeCommand` (node-components D-1), not by
  this task's code; no mutant of this task reaches it. **TC8 is its witness** for the
  table colour (a delete drops the component, `FloorPlanTableRemoved` carries
  `color == teal`, Undo restores the component and `FloorPlanTableAdded` carries teal).
- **M-C14**: `FloorPlanTableDetail.==` ignores `color`. Red: TC9 (`Expected: [ ...`
  `Actual: []` for the recolour `FloorPlanTableChanged`) and TC7's replace-magenta leg.
  Reverted.
- **M-PC11-a**: `_requireDesign` removed from the shared path. Red: TC6
  (`Expected: throws <Instance of 'StateError'>  Actual: <Closure: () => bool>`);
  `table_data_test` stays green (`setTablesData` has its own check). Reverted.
- **M-PC11-b**: `colorValue` = `floorPlanColorNamed(name)!`. Red: TC1 and TC7
  (`Null check operator used on a null value`). Reverted.

## Test helpers: brief vs real API

- `embeddingPlanJson`, `embeddingTables`: as in the brief. `table_data_test`'s helpers
  are file-private, so `table_color_test.dart` defines its own (`controller`, `mounted`,
  `instanceOf`, `detailsOf`, `fixtureWith` for raw `jetcad.table_color` payloads).
- Labels: read from `doc.changes` `CommandApplied.label` (the document's stream, as
  `table_data_test` does), not `doc.commands.changes`.
- Diagnostics: `tableDiagnostics(doc)` / `TableSurvey.of(doc).diagnostics()`.
- Delete in the editor: `c.select({'3'})` then the Delete key on a mounted `FloorPlanView`
  (as `table_data_test` HD12 and `design_changes_test` DC5).
- Change size: `changeSizeCommand(doc, instance, entryOf(otherSymbol))` from
  `symbols/symbol_section.dart` with a second hand-made servable symbol (6 seats).
- "canUndo false after a clearHistory" (TC3): each bad map runs on a fresh controller
  (canUndo is a flag refreshed by edits, `clearHistory` does not refresh it); asserts
  `undoDepth == 0`, `canUndo`/`dirty` false, `designJson` unchanged.
- Fixture note: table `L` starts with no colour, so `{'1': teal, ' 2 ': purple, 'L': null}`
  is two edits (L is the equal-skip).

## Deviations

1. **`FloorPlanTableDetail.toString` appends `, color: <color>` only when the colour is
   non-null.** The brief says `toString` adds `color`, but `design_changes_test.dart` (DC13)
   and `table_detail_test.dart` pin the exact string ending `data: {})`; an unconditional
   `color: null` would have forced edits to existing tests, which the Global Constraints
   forbid. A host's log line for an uncoloured table is unchanged. TC9 pins both sides.
   If the plan wants the unconditional form, those two assertions need the named exception.
2. `setTablesData` calls `_requireDesign('setTableData')` before validating its maps (kept
   from today: StateError before ArgumentError in the selection mode), and the shared path
   calls it again; the duplicate is intentional so M-PC11-a is killed by the colour path.

## Self-review

- Draw order, `Tolerance`, allocation tests untouched; no handle or component type crosses
  the host barrel (`FloorPlanTableColor` is internal; only `FloorPlanColor` is exported already).
- `setTableColor('x', null)` on a kept/unknown payload removes it (an edit, dirty) and
  reports no change (colour null before and after): TC7. Documented on the setter.
- The service copy reads the design's colour (TC6, TC7) because `_detailsOf` is shared.

## Concerns

- Schema: a plan now carries a new component type; `schemaVersion` untouched (the brief
  names no bump). Older releases keep it as preserve-unknown.
- TC9's Change-size leg uses a symbol not in any library; it exercises the real
  `changeSizeCommand` but not the Size menu widget.
