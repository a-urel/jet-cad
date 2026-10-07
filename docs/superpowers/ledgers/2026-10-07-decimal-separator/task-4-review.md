# Task 4 review (Q0, commit f100a11)

Reviewer: independent; clone `/tmp/q0-t4-review/repo` at `f100a11`, `flutter pub get` at the root. Nothing run in `/home/user/jet-cad`.

## Verdict: **Approved**

Two nits and one minor test gap below. None blocks the task.

## Gates (run in the clone)

| Run | Last line |
|---|---|
| planner `flutter test test/host test/l10n` | `01:25 +157: All tests passed!` |
| `apps/floor_planner` `flutter test` (full, includes `document_separator_test.dart` and the launch/New tests) | `02:16 +212: All tests passed!` |
| `apps/restaurant_demo` `flutter test` | `00:33 +37: All tests passed!` |
| `tool/ci` `dart test` | `00:04 +32: All tests passed!` |
| `flutter analyze` (planner / floor_planner / demo) | `No issues found!` ×3 |
| `dart format --set-exit-if-changed` (same three) | `0 changed` ×3 |

## Settling machinery: verified

### Executing a command from `didChangeDependencies`

This is safe.
- `CommandDispatcher.execute` (`jet_cad_2d/lib/src/document/undo.dart`) notifies synchronously only through:
  - `expander`, which the shell's `TableLabelSystem` installs;
  - `onAfterMutate`, which the `SpatialIndex` installs.
- Neither exists at the first report. `didChangeDependencies` runs before the view's first build, so no shell or canvas has been built over that document yet.
- Everything else is asynchronous. That covers `changes`, `PageNotifier`, `SelectionController`, the controller's `_attach` listener (which runs `_refreshFlags` and `revision++`) and `_announceLayout`.
- `reportLanguage` sets no `ValueNotifier` and calls no `notifyListeners`.

Probe in the clone (not landed): a host modelled on the probe's `FloorScreen`, under `tr`.
- It listens to `controller`, `revision`, `dirty`, `canUndo`, `canRedo`, `selectedTables`, `mode` and `serviceLayoutChanges`, each calling `setState` synchronously.
- It has `ValueListenableBuilder`s over `revision`, `dirty` and `canUndo` above the view.
- Its `openDesign` loads asynchronously from the store.

Results:
- **P1, empty store:**
  - `tester.takeException()` is null.
  - Output: `log=[revision] rev=1 rev0=0 dirty=false canUndo=false canRedo=false sep=DecimalSeparator.comma`. Only the asynchronous `revision` fires, which the spec allows as a redraw.
- **P2, stored point design:** it loads after the settling and stays `point`, clean, with no exception.
- **P5, selection mode first, under `de`:** the host's log is `[]`. Then `serviceLayoutJson` and `restoreServiceLayout`, then design mode: `comma`, clean.
- **Locale switch while the shell is mounted:** this cannot settle a plan, because the plan is already settled or touched. I forced it with mutant X11 below. The demo then settled a plan with its shell mounted, during a locale switch, and the log shows no framework error other than the test's expectation failure. So the path is robust even where it is unreachable.

### Dirty and clean state

After settling:
- `dirty`, `canUndo` and `canRedo` are all false, both synchronously and after the microtask;
- `undoDepth` is 0;
- `serviceLayoutChanges` fires 0 times;
- `revision` moves once, and only in the design mode;
- the save point is re-baselined, so an edit and its Undo end clean (NS1).

### Untouched detection

- **Edit, undo to the start, then clear history:** this cannot be reached. `clearHistory`, `notifyLoaded` and `notifyPurged` are never called on the design outside `reportLanguage`. `grep` finds only `new_document`, `startup_plan`, `build_library`, and the service copy at `floor_plan_controller.dart:526`. Any `execute` moves `stateId`, and an undo back to the start leaves a Redo.
- **`markSaved` without `designJson`:** no bytes were handed out, and the re-baseline keeps the plan clean. Consistent with N1.
- **`setMode`, `restoreServiceLayout` and `serviceLayoutJson` before the settling:** an untouched plan is `newDocument`, so it has no tables. Any stored layout is therefore empty, and the settling changes only the page. There is no harm, and this matches N1's "a service copy taken before … is not changed".
- **The second and later reports:** they only update `_reported`, which `newPlan` uses. A settled or touched plan is never converted (N2). Probe P4 (edit then undo before the view, `tr` then `de`) stays `point`. This is the desired behaviour.
- **Two views on one controller:** this is not a supported setup. The second view throws `Bad state: the dispatcher already has an expander (spec 06 D2)`. That is pre-existing and unrelated to this task, so the language question does not arise.

### Other points checked

- **R-13 and the camera:** the page's geometry is unchanged, and `_placeNominally` and the fit are untouched.
- **The service copy:** NS5 holds.
- **Floor planner:**
  - Launch uses `basicLocaleListResolution(platformDispatcher.locales, floorPlanSupportedLocales)`, the same list the app's `MaterialApp` uses (`main.dart`, `supportedLocales: floorPlanSupportedLocales`, with no `locale` and no callbacks).
  - New reads its strings before the await.
  - Moving that read after the await is caught by the gate: `flutter analyze` reports `use_build_context_synchronously • lib/document_host.dart:449:68`.
- **Leak test:** the comment is accurate. LK2 builds its sample through `RecordingFloorPlanStrings(FloorPlanStringsTr())`.
- **DT1:** the extension is non-degenerate.
  - It runs under a Turkish UI on a `point` page.
  - The area `13.97 m²` and the dimension `4.68` both have nonzero fractions.
  - A leak mutant (M9, which settles loaded plans) goes red on DT1 alone: `Expected: '13.97 m²' Actual: '13,97 m²'`.

## Mutants re-applied (each restored by `git checkout`; tree clean after)

| Mutant | Result |
|---|---|
| M4: the view does not report | red: NS1, NS2, NS5; and DQ1, DQ2 in the demo |
| M5: no report on a controller swap | red: NS2 |
| Settling a touched plan (`_untouched` ignores `stateId` and redo) | red: NS4 |
| M7c: `designJson` does not clear the unsettled mark | red: NS4 |
| M8a: settling leaves history (`clearHistory` removed) | red: NS1, NS2, NS5 |
| M8b: settling leaves the plan dirty (`_savedState` not moved) | red: NS1, NS2, NS5 |
| M6: `newPlan` ignores the language (always `point`) | red: NS1 |
| X4 (own): `_reported` never stored | red: NS1 |
| X2 (own): `newPlan` always unsettled | red: NS1 |
| X1 (own): only the first report counts | red: NS1 |
| X3 (own): the constructor plan never unsettled | red: NS1, NS2, NS5 |
| X10 (own): settle `_active` instead of `_design` | red: NS5 |
| M9: loaded plans unsettled | red: DT1 |
| Launch reads `locales.first` | red: FS1 `[fr_FR, de_DE]` |
| Launch always `point` | red: FS1 `[de_DE]` and `[fr_FR, de_DE]` |
| New always `point` | red: FS2 |
| X11 (own): the first report on a page that already matches does not clear `_unsettledAt` | **green on all of `new_plan_separator_test.dart` and `determinism_test.dart`**; red only on demo DQ2 (`demo_test.dart:1204`, Expected `point`, Actual `comma`) |

## Findings

1. **Minor (test gap).**
   - **Problem:** X11 survives the planner package's own tests.
     - The mutant removes `_unsettledAt = null;` at `floor_plan_controller.dart:426`.
     - The constructor's plan, first shown in English (`point == point`, so the early return at `:429`), then stays unsettled.
     - A later switch to Turkish converts it to `comma` while the shell is mounted, which breaks N2.
     - Only the demo's DQ2 kills it. The planner package, which owns the machinery, does not pin its own guard.
   - **Fix:** add to NS1, or a new NS6: `FloorPlanController()` shown under `en`, then the same view under `tr` → still `point`, `undoDepth` 0, clean.

2. **Nit (robustness).**
   - **Problem:** when the first report finds the plan touched, `reportLanguage` returns before clearing `_unsettledAt` (`:425`).
     - So a touched plan stays "unsettled" for the controller's life.
     - It is protected only by the invariant that the design's history is never cleared at its creation state, which holds today (see above).
     - The comment on `_unsettledAt` (`:394-397`) says "while it is unsettled".
   - **Fix:** in `reportLanguage`, read `final untouched = _untouched; _unsettledAt = null; if (!untouched) return;`. Once a language is known, a plan is settled either way. This has no behavioural change today.

3. **Nit (document in Task 5).**
   - **Problem:** `newPlan()` uses the last language *reported*. If the host calls it while no view of that controller is mounted, after the app's language changed, the new plan takes the stale language and is settled at once.
   - This follows the spec's text ("uses the last language reported"), and the demo is unaffected because a swap reports before Revert. It is worth one clause in the host guide's sentence (D2).

## Claims in the report

The report's claims match what I checked: the mechanism, the "does not clear untouched" table, the mutant results I re-ran, and the gate results. Its own mutation note on M9 (it survives the demo and is killed by NS3 and DT1) is consistent with my M9 run.

## Disposition (controller)

- 1: fixed. NS6: the constructor's plan shown first in English stays point
  under a later Turkish view, no step, clean. X11 (the first report on a
  matching page not clearing the mark) is red in NS6 (`Expected:
  DecimalSeparator.point Actual: DecimalSeparator.comma`).
- 2: fixed. The first report clears the mark whether it settles or finds
  the plan touched.
- 3: the host guide says `newPlan()` takes the language a view last
  showed.
