# Slice 2, Task 3 report: `designChanges` (E-5)

Commit `69d56fc` on `claude/exciting-pasteur-9m22jv` (parent `a148b51`), pushed.
Flutter `/root/sdk/flutter/bin`, `CI=true`. No `analysis_options.yaml` changed or staged (`git status` checked before the commit).
The engine (`jet_cad_2d`) and `jet_cad_2d_flutter` are not edited. The only existing test edited is `barrel_test.dart`'s B1, which gains the five names. B6 is a new test in that file.

## What was built (all in `packages/jet_cad_floor_plan`)

- `lib/src/host/design_changes.dart` (new, 129 lines)
  - `sealed class FloorPlanDesignChange` (:17), `@immutable`, const constructor.
  - `final class FloorPlanTableAdded(table)` (:24), `FloorPlanTableRemoved(table)` (:43), `FloorPlanTableChanged(before, after)` (:63) and `FloorPlanPlanReplaced()` (:88). Each has a const positional constructor, `==`, a `hashCode` that includes the type and `toString` in the barrel's style: `FloorPlanTableAdded(<detail>)`, `FloorPlanTableChanged(<before>, <after>)`, `FloorPlanPlanReplaced()`.
  - `diffTableDetails(beforeInstances, before, afterInstances, after)` (:106). It is internal and not exported. It merge-walks two lists that are each ascending by instance. An instance found only in `before` is `Removed`, one found only in `after` is `Added`, and one in both whose details differ by `==` is `Changed`. Output is in ascending instance order, O(n + m).
- `lib/jet_cad_floor_plan.dart`: exports the five names through a `show` list.
- `lib/src/host/floor_plan_controller.dart`
  - `_DesignBaseline` (:160) holds the document, `stateId`, layer `mutationRevision`, instances and details. `isAt(d)` says whether the design has not moved since the baseline was taken.
  - `_detailsOf(d, survey, instances)` (:1163) now takes the survey it reads. `tableDetails` passes `_tables` (:1139), so its behaviour is unchanged.
  - `_designChanges` (:1269) is a broadcast `StreamController` with `onListen: _watchDesign` (takes the baseline) and `onCancel: _unwatchDesign` (drops it).
  - `Stream<FloorPlanDesignChange> get designChanges` (:1304), with its doc comment.
  - `@visibleForTesting int get designScans` (:1282) counts every read of the design's tables for the diff.
  - `_designNow()` (:1315) builds the design's list. While the design is active it uses the cached `tableDetails` and `_detailInstances`. Otherwise it calls `_detailsOf(d, TableSurvey.of(d), …)` on the design's own survey.
  - `_reportDesign()` (:1336) does nothing when there is no baseline (no listener), after dispose, or when `isAt` holds (a second event from one synchronous step). Otherwise it reads the design's list, diffs it against the baseline, `add`s each change and makes the new list the baseline.
  - `_attach`'s change listener calls `_reportDesign()` only when `identical(plan, _design)` (:1656). A service plan never feeds it.
  - `_replaceDesign`:
    - It first calls `_reportDesign()` (:951), before `_drop`. That synchronously flushes an edit whose change event is still queued on the old plan's subscription, which is about to be cancelled.
    - After the new design and, in selection mode, the new copy are attached, and while there is a listener, it emits `FloorPlanPlanReplaced` and takes the new design as the baseline (:966). This happens in either mode.
  - `dispose` clears the baseline and closes the stream controller (:1718). The change listener already returns once `_disposed` is set, and the plans are detached, so nothing is added after dispose.

## Tests

`test/host/design_changes_test.dart` (new, 605 lines) runs on `embeddingPlanJson`. DC1–DC9 are in the group "with the design view mounted": `FloorPlanView` at 1440×900, so the shell's `TableLabelSystem` and the Delete expander run. Expected centres come from the fixture's transforms by the forward transform (box centre (700, 100)), `closeTo` 1e-12 relative.

| Test | What it checks |
|---|---|
| DC1 | One edit, several changes in ascending instance order. `setTablesData` with keys in the order `L`, `4`, ` 1 ` gives exactly `Changed(1)`, `Changed(4)`, `Changed(L)`, each changing the data only (locked `L` included). |
| DC2 | Locking layer `0` gives exactly one `Changed` per table on it (8 tables: 1, 2, 3, 4, both 7s, the unnumbered one, 9), with `locked` the only change. Undo gives the reverse. Showing the hidden layer gives one `Changed` for `5`: before has no geometry, after is visible with its centre by the forward transform. |
| DC3 | Renumbering `1` to `21` with data on it gives exactly one `Changed`: the number changes and the data is kept. |
| DC4 | `setTableData` gives one data-only `Changed`. The same data again gives nothing. Undo and redo give the reverse and then the same change. |
| DC5 | **M-H25.** `3` carries data. Deleting it (`select` plus the Delete key) gives exactly `[Removed(3)]`. Undo gives exactly `[Added(3)]`, equal to the removed detail, data included. Redo gives `Removed` again. |
| DC6 | **M-H25.** Moving ` 7 ` (mirrored) gives exactly one `Changed` whose before is that table's and whose after has the forward-transformed new centre. Then moving `7` does the same for `7`. |
| DC7 | **M-H29(service moves).** In selection mode under `embeddingCamera()`: a real drag of `1` through `TestGesture`, its Undo, its Redo, `resetLayout` and `restoreServiceLayout` emit nothing. Each step's premise is checked. A mode switch emits nothing. Back in design mode a `setTableData` is reported, so the listener is live and the design never moved. |
| DC8 | `newPlan` gives exactly `[FloorPlanPlanReplaced()]`, with no `Removed` per table. A `load` after it gives the same. |
| DC9 | In one synchronous block: `setTableData('2')`, `load`, then `setTableData('L')` on the loaded plan. The result is exactly `[Changed(2), PlanReplaced(), Changed(L of the new plan)]`. |
| DC10 | **M-H29(PlanReplaced in the selection mode).** In selection mode, `load(embeddingPlanJson())` gives exactly `[FloorPlanPlanReplaced()]`, and so does `newPlan`. |
| DC11 | See below. |
| DC12 | `dispose` closes the stream (`onDone` fires). An edit made just before `dispose` is not reported. |
| DC13 | `==`, `hashCode` and exact `toString` of the four classes, on a hand-built non-default detail and on an equal but non-identical copy. Before and after are ordered, and `Added` ≠ `Removed` for the same table. |
| DC14 | The pure diff: one table removed, one renumbered to the removed table's number, one unchanged, one added, one moved to another layer. The result is by instance and ascending. Empty lists give nothing. |
| B6 (`barrel_test.dart`) | Through the barrel alone: `designChanges` on a fresh controller, `newPlan` gives `PlanReplaced`, and an exhaustive `switch` over the five types builds each one. |

DC11 covers the scan counter:
- With no listener, `setTableData`, a layer lock, undo, redo, `load`, `newPlan` and `load` again leave `designScans` at 0.
- The first listen takes 1 scan, and a second listener takes none.
- Two edits in one synchronous step take 1 scan and give 1 report, and both listeners hear it.
- With one listener cancelled, the other still hears.
- After the last cancel, an edit, undo, `load` and `newPlan` take no scan.
- An edit made just before a new listen is not reported. The next edit is.

## Mutants

Each mutant was applied by script (`scratchpad/mut/mutate.py`) and run against `design_changes_test.dart` and `barrel_test.dart`. Each was reverted by copying the saved original back (no `git checkout`), with `cmp` confirming the original afterwards.

| Mutant | Change | Red killers |
|---|---|---|
| M-H25 (index) | Diff keyed by list index | **DC5** (and DC14) |
| M-H25 (number) | Diff keyed by `table.number` (a map, last wins) | **DC6** (the move of `7`: no change reported), DC2, DC3, DC14 |
| M-H25 (value) | Diff by value: `Removed` for each before not in after, `Added` for each after not in before | **DC6**, DC1, DC2, DC3, DC4, DC7, DC9, DC11, DC14 |
| M-H29(service moves) | The diff fed by the active plan: listener on `identical(plan, _active)`, `_designNow` reading `_active`, the skip keyed on `_active.document` | **DC7** |
| M-H29(PlanReplaced in the selection mode) | `PlanReplaced` emitted only when `_mode.value == FloorPlanMode.design` | **DC10** |
| extra: no flush | `_replaceDesign` without the leading `_reportDesign()` | **DC9** |
| extra: always scanning | `onCancel` keeps the baseline | **DC11** |

## Gates (this tree, real runs)

| Package | Result |
|---|---|
| `packages/jet_cad_floor_plan` | `flutter test`: +1556 All tests passed (Task 2's 1541, plus DC1–DC14 and B6). `flutter analyze`: No issues found. `dart format --set-exit-if-changed`: exit 0. |
| `apps/restaurant_demo` | `flutter test`: +47 All tests passed. analyze: No issues found. format: exit 0. |
| `apps/floor_planner` | `flutter test`: +212 All tests passed. analyze: No issues found. format: exit 0. |
| `packages/jet_cad_2d` (not edited) | `dart test --file-reporter json:…` (exits 1, the standing set), then `dart run tool/ci/expect_failures.dart --package packages/jet_cad_2d --root packages/jet_cad_2d <json>`: "1258 tests; the standing failures and skips, exactly" (exit 0). |
| `packages/jet_cad_2d_flutter` (not edited) | Same comparison: "1374 tests; the standing failures and skips, exactly" (exit 0). |

## Findings and deviations

1. **The plan's DC1 fixture as written cannot work.** The plan says "a `setTablesData` on `1` and ` 7 `". ` 7 ` trims to `7`, which two tables carry, so `setTablesData` refuses it and returns false (E-6, M-H22, Task 2's HD3). DC1 uses `L`, `4` and ` 1 ` instead, in descending instance order, so a report in edit order is seen out of order.
2. **The plan's DC6 killer alone did not kill the number mutant.** "A move of ` 7 `" passes under a last-wins map keyed by number, because ` 7 ` is the second 7 and wins. DC6 now also moves `7`, which kills either variant (first-wins or last-wins).
3. **The plan's M-H29(service moves) mutant needed its full form.** Changing only the listener's condition to the active plan survives, because the diff reads the design, which never moved, and the `isAt` skip keys on the design. The mutant recorded is the whole "fed by the active plan" change: the trigger, the list read and the skip key. DC7 kills it.
4. **Delivery is asynchronous** (a default broadcast controller), as the dispatcher's own stream is. A host is never called back from inside `load` or an edit, and `designChanges` documents this. A consequence is that several edits made in one synchronous step arrive as one report. For example, two `setTableData` calls on `1` give one `Changed` from the first state to the last (DC11).
5. **An edit made just before `dispose` is not reported** (DC12). Dispose detaches the plans, so the queued event is dropped, and nothing is flushed. Not flushing was my choice, because a disposed controller has no listener worth serving. Recorded so a reviewer can object.
6. **Test harness note.** Awaiting `StreamSubscription.cancel()` inside `testWidgets` left the next `tester.pump()` hanging until the 10-minute timeout, which I saw while writing DC11. DC11 calls `unawaited(sub.cancel())`, and the shared `listen` helper cancels in `addTearDown`. This does not affect the code under test.
7. **Purge is not handled specially.** `DocumentPurged` compacts handles, so a diff across a purge would report changed instances as remove plus add. The controller never purges a design (no `purge(` call in the planner's `lib`), so nothing was done about it.
8. **`hashCode` includes the type** (`Object.hash(FloorPlanTableAdded, table)`), so `Added(t)` and `Removed(t)` do not collide. No test asserts hash inequality, because that is not a contract.

## Fixes

Review: `s2-task-3-review.md` (R-1 to R-5), with the controller's rulings. Only Task 3's files were touched: `packages/jet_cad_floor_plan/test/host/design_changes_test.dart` and the `designChanges` doc comment in `packages/jet_cad_floor_plan/lib/src/host/floor_plan_controller.dart`. No code changed.

### Changes

| Finding | Change |
|---|---|
| R-1 | **DC15** (from probe P2). Unmounted controller. Read `2`'s and `1`'s design details. `setMode(selection)`, then a service move of `1` (`TransformNodeCommand` on the copy, shifted by (1200, -700)). Premises: `serviceEdited`, and `1`'s centre in the copy is the shifted box centre. Then listen, `setMode(design)` and pump: nothing, and `1` in the design is unmoved. Then `setTableData('2', hostData())`: exactly `[Changed(b2, b2 with the data)]`. |
| R-2 | **DC16** (from probe P10). Listen. In one synchronous step, `setTableData('2', hostData())` then `setMode(selection)`. Nothing before the pump. After one pump: exactly `[Changed(b2, b2 with the data)]`, still in selection mode. |
| R-3 | **DC17** (from probe P1). Listen. `setTableData('1', hostData())`, then `load('not json')` and `load('{"x": 1}')`, both `throwsFormatException`. After a pump: exactly `[Changed(1)]`, with no `PlanReplaced`. Another failed load reports nothing. A later edit is reported from the edit's state (same plan, same baseline). |
| R-4 | The doc's last paragraph is reworded and split in two. (1) Delivery is asynchronous: one report per synchronous step, from before the first edit to after the last. (2) Nothing is sent on listen: the host reads the starting tables itself, from `tableDetails` in design mode (in selection mode it is the service copy's). The first listener starts from the design as it is when it listens. A listener added while another listens starts where that one is, so its first report may include an edit made just before it listened. Closed by `dispose`: changes not yet delivered then are dropped. |
| R-5 | No change. |

### Mutants re-applied

The reviewer's exact forms were applied by script (`scratchpad/s2t3fix/mut.py`). Each was run against `design_changes_test.dart` and `barrel_test.dart`. The original was copied back afterwards, with a byte-for-byte compare (`filecmp`, shallow=False) passing each time. No `git checkout`.

| Mutant | Form | Result | Killer |
|---|---|---|---|
| O7 | `_designNow`: `if (identical(plan, _active))` becomes `if (true)` | RED | **DC15** only. Its first report is a `Changed` for `1` (the service move leaking) |
| M-H29(service moves), trigger only | `_attach`: `identical(plan, _design)` becomes `identical(plan, _active)` before `_reportDesign()` | RED | **DC16** only. `Actual: []` |
| O10 | `load`'s catch adds `PlanReplaced` when listened | RED | **DC17** only. `at location [0] is FloorPlanPlanReplaced()` |

On the unmutated code DC15–DC17 pass (the file is +17, all passed).

### Gates (this tree, real runs)

| Package | Result |
|---|---|
| `packages/jet_cad_floor_plan` | `flutter test`: +1585 All tests passed! (includes Task 4's tests at HEAD). `flutter analyze`: No issues found. `dart format --set-exit-if-changed`: 257 files, 0 changed, exit 0. |
| `apps/restaurant_demo` | +47 All tests passed! No issues found. Format exit 0. |
| `apps/floor_planner` | +212 All tests passed! No issues found. Format exit 0. |
| `packages/jet_cad_2d` | First run: the comparison reported one new failure, `draft_document_test.dart :: extents cost scales with entities, not containers x entities`. It is a wall-clock ratio: "20 containers took 971us and 400 took 6089us", against a bound of 5826. It ran under load (load average about 5.3, with a review running beside this one). The engine has no diff. Second full run: "packages/jet_cad_2d: 1258 tests; the standing failures and skips, exactly" (exit 0). |
| `packages/jet_cad_2d_flutter` | "packages/jet_cad_2d_flutter: 1379 tests; the standing failures and skips, exactly" (exit 0). |
