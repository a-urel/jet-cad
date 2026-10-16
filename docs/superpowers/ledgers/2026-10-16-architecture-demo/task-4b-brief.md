# Task 4b: the library's settle reaches the open text entry and the panel focus; Task 4's skips and DC12 width

Added by the controller under spec decision 10 (a library gap found by a ported app test). Task 4 left four app cases skipped (`apps/architecture_demo/test/document_settle_test.dart` lines ~212, 248, 315, 454: ST2, ST3, ST8, ST4-focus) because `PlanController.settlePendingInput` (packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart:2345) runs only the registered settles and `applyFocusChangesIfNeeded`. The old shell's settle (packages/jet_cad_floor_plan/lib/src/planner_shell.dart:845-865, read it) did four things:

1. **The text entry, open:** the Text tool's `finish` commits its typed text as one step, as Enter would, and closes it; the entry hands the focus back to the canvas.
2. **A panel field with the focus:** handed back to the canvas (its focus-loss listener commits a Selection panel value as its own step).
3. **The page scale:** re-synced to the stored scale.
4. Then `applyFocusChangesIfNeeded`.

The new library already does (3)-(4) and part of (2) through registered settles (Task 4 found: the Selection panel fields and the Page panel scale register). What is missing: (1) nothing finishes an open text entry, and the Page panel's settle leaves the focus in the scale field instead of handing it back to the canvas.

## Part A: the library (packages/jet_cad_2d_plan)

- Find where the plan library's text tool keeps its open entry (grep `isPending`, `finish`, the text tool's class under `lib/src/tools/` or the engine tool it wraps) and where the editor/canvas could register a settle with `controller.registerSettle` (it is `@internal`; the editor or canvas in the same package may call it). Register one settle that, while the active tool's text entry is open, finishes it as Enter would (one undo step) and hands focus back to the canvas. Unregister on dispose.
- The Page panel's settle hands the focus back to the canvas after its re-sync, as the old `PanelFieldFocusNode.handBack()` did. Find the new counterpart (grep `handBack`).
- Library tests in `packages/jet_cad_2d_plan/test` (beside the existing settle tests; grep `settlePendingInput` in test/): (a) typed text in an open entry, then `controller.save()`: the saved plan holds the text, one undo step, the entry closed; (b) focus in the page scale field, then settle: focus is on the canvas. Each with a named mutation (drop the new settle registration; drop the hand-back) that turns it red. Run, revert with `git checkout --`, show `git diff --quiet`.
- Read the 2a spec line on settling (docs/superpowers/specs/2026-10-14-plan-library-design-mode-design.md:266) and keep within it.
- Gates: `cd packages/jet_cad_2d_plan && flutter test --enable-vmservice && flutter analyze && dart format --output=none --set-exit-if-changed .`; and `packages/jet_cad_2d_integration` `flutter test --enable-vmservice` (it runs the library with the kit).
- Commit: `fix(plan): settling finishes an open text entry and hands panel focus back` (+ the test in the same or a `test(plan):` commit).

## Part B: the app

- Remove the four `skip:` lines in `document_settle_test.dart`; the cases must pass unchanged (never weaken them). If one still fails, report the output.
- **DC12 / DC12c width:** Task 4 moved DC12 from the old 800 px to 900 px and DC12c's range to 1000→856 px because the bar's fixed part with a long name is 856 px (a 240 px name widget plus the Open sample button). That weakens the old assertion. Restore DC12 at 800×600 and DC12c's old range (read the old cases in apps/floor_planner/test/document_commands_test.dart), and make them pass by narrowing the name widget's `maxWidth` in `lib/document_host.dart` (`_DocumentTitle`) to the width that fits 800 px with the other bar items (measure; state the number and how you measured it). If the old range's floor cannot fit by narrowing alone, report it with the measurements.
- Gates for the app. Commit: `fix(demo): the document name fits the bar at 800 px; the settle cases run`.

Rules: .superpowers/sdd/2026-10-16-architecture-demo/dispatch-notes.md in full.
