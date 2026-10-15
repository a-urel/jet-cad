# Task 9 report: the unit API, design side

Status: DONE_WITH_CONCERNS. Commit `d8774732 feat(plan): the unit API, design side (2b S3)` (base c612fa1b).

## What I implemented

- `lib/src/units/unit_detail.dart`: `PlanUnit`, `PlanUnitDetail`, `unitDetailOf`, `unitDetailWithoutGeometry`, `PlanUnitChange` + `PlanUnitAdded`/`PlanUnitRemoved`/`PlanUnitChanged`/`PlanUnitsReplaced`, `diffUnitDetails`. This is the brief's code exactly as written.
- `lib/src/controller/plan_camera.dart`: `PlanCamera`, ported from `host/floor_plan_camera.dart`. The doc comments say `PlanController.cameraValue`/`canvasRect` and "the service mode".
- `lib/src/units/unit_fit.dart`: `kUnitFitMarginMm`, `kUnitFitMinSpanMm`, `frameUnits`. It defaults to `kPlanMinScale`/`kPlanMaxScale`.
- `lib/src/units/unit_writes.dart`: `unitLabelCommand`, as the brief has it.
- `plan_controller.dart`:
  - `_FitTarget` is now sealed, with `_Centre`/`_Units`. Also added: `_PlanCameraValue`, `_UnitBaseline`, and the new `framingFor`.
  - Task 6's `unitIndex` getter is deleted and declared once over `_activeUnits`.
  - The unit API section from the brief went in verbatim, with the seams `_activeUnits`, `_activeDocument`, `_activeSelection`, `_inDesign`, `_requireDesign`, `_expandLabels` and `_selectedUnits`.
  - Also added: `revision`, `cameraValue`, `worldToGlobal`/`globalToWorld`, `units`, `unitDetails`, `unitDetailInstances`, `labelWarnings`, `unitAt`, `select`, `editorSelectedUnits`, `fitToUnits`, `setUnitData(s)`, `setUnitColour(s)`, `setUnitLabel(s)`, `unitChanges`, `debugUnitScans`.
  - `_open`/`_replace`/`dispose` are wired as the brief's Step 8.4 says.
- Barrel: adds `PlanCamera`, the `PlanUnit*` types, `UnitLabelProblem`, `BadLabel`, `DuplicateLabel`, `Unlabelled` and `UnitLabelWarning`. ED-9's set grows to match.

## Files

- New lib files: `unit_detail.dart`, `unit_fit.dart`, `unit_writes.dart` (in `units/`), `controller/plan_camera.dart`.
- Modified lib files: `plan_controller.dart`, `jet_cad_2d_plan.dart`.
- New tests: `test/support/unit_embedding_fixture.dart`, `test/units/unit_api_test.dart`, `test/units/unit_fit_test.dart`, and in `test/controller/`: `unit_detail_test.dart`, `unit_data_test.dart`, `unit_colour_test.dart`, `unit_changes_test.dart`, `unit_camera_test.dart`, `non_finite_unit_test.dart`.
- Modified tests: `test/barrel_test.dart`, `test/editor/units_only_select_test.dart` (T5-c, T5-d), `test/l10n/value_words_test.dart` (VW4).

## Tests

**RED: not observed as the brief's Step 4 describes.** I wrote the lib files before the new tests, so I never saw the compile-error RED. The first run of `unit_api_test.dart` failed 7 of 10 with:

```
Binding has not yet been initialized.
...
package:jet_cad_2d_plan/src/controller/plan_controller.dart 1561:18  PlanController.settlePendingInput
```

That was the brief's test using `test(...)` while `settlePendingInput` reads `FocusManager.instance`. I added `TestWidgetsFlutterBinding.ensureInitialized();` as `main`'s first line. The named mutations below are the evidence that each UA test goes red.

**GREEN**, each run with `flutter test <file>` in `packages/jet_cad_2d_plan`:

| File | Quoted result |
|---|---|
| `unit_api_test.dart` | `00:00 +10: All tests passed!` |
| `unit_detail_test.dart` | `00:00 +16: All tests passed!` |
| `unit_data_test.dart` | `00:01 +11: All tests passed!` |
| `unit_colour_test.dart` | `00:01 +7: All tests passed!` |
| `unit_changes_test.dart` | `00:02 +15: All tests passed!` |
| `unit_fit_test.dart` | `00:00 +4: All tests passed!` |
| `non_finite_unit_test.dart` | `00:01 +2: All tests passed!` |
| `unit_camera_test.dart` | `00:00 +5: All tests passed!` |
| `units_only_select_test.dart` | `00:04 +13: All tests passed!` |
| `value_words_test.dart` | `00:00 +6: All tests passed!` |

## Gates (`packages/jet_cad_2d_plan`)

- `dart format .`: `Formatted 220 files (0 changed)`.
- `flutter analyze`: `No issues found! (ran in 3.0s)`.
- `flutter test`: `00:43 +929: All tests passed!`. No new failures; nothing from `standing_failures.txt` appeared.
- `dart format --output=none --set-exit-if-changed .`: `Formatted 220 files (0 changed) ... exit 0`.
- `git status --short` after pub: only this task's files. No `analysis_options.yaml` was touched.

## Mutations

All run after the commit, with `flutter test test/units/unit_api_test.dart`. After each one: `git checkout -- <file>`, then `git diff --quiet -- <file>` printed `diff-quiet exit 0`.

| Mutation | Edit | Red test and failing line (verbatim) |
|---|---|---|
| M-UA0 | `generatedBy: u.ownerType` → `null` | UA-units: `Expected: an object with length of <1>` / `Actual: WhereIterable<PlanUnit>:[` / `Which: has length of <12>` |
| M-UA1 | `get<UnitData>(u.instance)` → `(u.definition)` | UA-shrink-data: `Expected: {'pos': 'a1'}` / `Actual: {}`. UA-seat-data also went red. |
| M-UA1x | regeneration.dart:787, `existing = const <InstanceNode>[]` | UA-shrink-data red at `unit_api_test.dart 86:5`: `Expected: true` / `Actual: <false>`. That is `setUnitsData` refusing after the regenerated seats; the brief expected a changed-handle compare instead. UA-changes-row also went red: `Expected: an object with length of <2>` ... `has length of <8>`. |
| M-UA2 | regeneration.dart:922, `: now != seat)` → `: true)` | UA-seat-data: `GeneratedGeometryError: 2D is generated by a parametric object and cannot be edited directly` at `unit_api_test.dart 123:14`. UA-shrink-data also went red at 87:11. |
| M-UA3 | `locks.covers` line deleted in `_setUnitComponents` | UA-locked-write: `Expected: false` / `Actual: <true>` at `unit_api_test.dart 148:5`. That is `expect(c.lockHint.value, isFalse)`: the hint shows. |
| M-UA4 | inner `withLabel(next)` loop deleted | UA-label-used: `Expected: false` / `Actual: <true>` at 161:5. UA-labels-swap also went red at 188:5. |
| M-UA5 | `u.generated \|\|` dropped | UA-label-seat: `GeneratedGeometryError: 1F is generated by a parametric object and cannot be edited directly` at 177:14 |
| M-UA6 | `if (other.instance != h)` | UA-labels-swap: `Expected: true` / `Actual: <false>` at 191:5 |
| M-UA7 | `placedOnly && u.generated` line deleted | UA-select-design: `Expected: Set:[SelectionKey:SelectionKey( 18)]` / `Actual: Set:[SelectionKey:SelectionKey( 1E), SelectionKey:SelectionKey( 18)]` |
| M-UA8 | `if (c.unit.generated) continue;` first in `_unitsBounds` loop | UA-fit-seat: `Expected: true` / `Actual: <false>` at 215:5 |
| M-UA9 | `diffUnitDetails` matched by label (compareTo) | UA-changes-row: `Expected: an object with length of <6>` / `Which: has length of <22>` at 243:5 |

The engine file (`packages/jet_cad_2d/lib/src/parametric/regeneration.dart`) was reverted after M-UA1x and after M-UA2, and was clean both times.

## Deviations, findings and concerns (for the controller's rulings)

1. **Service-mode parts trimmed from ported tests, beyond what the brief lists.** A comment marks each cut "Task 11". These are assertion removals, so they need a ruling:
   - TD8's tail: `setMode(selection)`, then `identical` is false and the list is equal.
   - HD6's middle block: the service copy decodes the invalid data the same way.
   - TC7's middle block: the service copy reads the colours.

   The brief's moves were carried out as listed: TA3, HD4, TC6, DC7/10/15/16 to Tasks 11/14, and TC1 to Task 6.
2. **Diagnostic codes follow Task 6's renames.** Not in R-13's list.
   - `'table.invalid_data'` → `'unit.invalid_data'` (HD6, HD9).
   - `'table.invalid_color'` → `'unit.invalid_colour'` (TC7).
   - `TableDiagnosticCodes.invalidColor` → `UnitProblem.invalidColour`.
   - `tableDiagnostics(doc)` → `UnitIndex.of(doc, …).diagnostics()`.
3. **TC9's `toString` checks follow the brief-mandated `colour:` field.** `contains('color: ')` → `contains('colour: ')`, and `isNot(contains('color'))` → `isNot(contains('colour'))`. Left as `color`, the second check would pass vacuously.
4. **Other harness changes, no assertion change:**
   - NT2 is `testWidgets` with `tester.runAsync`, since export needs the binding. It exports through `c.export('plan.pdf', PlanExportChoice.initial)`.
   - HD1 casts `(jsonDecode(saved) as Map)['schemaVersion']` for the `avoid_dynamic_calls` lint.
   - `unit_api_test` drops `dart:async` (the analyzer flagged it as unnecessary) and initialises the binding.
   - `unit_embedding_fixture` imports `embeddingBox` without `show`ing it, which removes the unused_shown_name warning. It is still re-exported (R-19).
   - The camera tests run in design, because today's `controller()` defaulted to the selection mode. `hostOf` is `PlanCanvas(rulers: false)` in a 1440x856 `SizedBox`.
   - TC9's wider size symbol is a `CatalogSymbol` with key `fx.embedding.wide`, through 2b's `changeSizeCommand` (`panels/symbol_section.dart`).
   - T5-d finds the north wall as the root line starting at `editorNorthWall.$1`, and checks it still lives with `isLine`.
5. **M-UA1x goes red on a different line than the brief predicted:** the refused data write at line 86, not a handle compare. It is still red on UA-shrink-data.
6. **Undo labels "Unit data" and "Unit colour"** (HD8, TC2) and the `toString` texts with the kind token (TD10, DC13) are applied under R-13.
