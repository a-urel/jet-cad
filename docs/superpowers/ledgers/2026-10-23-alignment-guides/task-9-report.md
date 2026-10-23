# Task 9 report: view options, allowance and stroke

Status: DONE. Commit: see `git log -1` (feat(plan): alignment guide options on the views).

## Built
- `PlanCanvas.alignmentGuides`, `PlanServiceView.alignmentGuides`, `PlanEditor.alignmentGuides` (default true, documented).
- Canvas: writes `alignmentGuidesAllowed` in initState and didUpdateWidget; on controller swap resets the old one to true beside `snappingAllowed`; dispose does not reset.
- Service view: same (initState, didUpdateWidget, swap reset of the old controller).
- Editor passes the value to both canvas sites and to `_serviceView()`. `_service` is nulled on every didUpdateWidget, so a changed value reaches the rebuilt view (pinned by M-GV-2).
- Stroke: `controller.guideStrokePixels = theme?.guideWidth ?? 1.0` in each view's build, next to the selectionWidth use (plain double field).

## TDD
Test file first: compile errors (`alignmentGuides` not a parameter/getter on PlanServiceView/PlanCanvas/PlanEditor), "Some tests failed" at loading. Then implemented: +5 pass.

## Mutations (flutter test test/guides/guide_views_test.dart), each reverted
- A, dispose reset added to PlanCanvas: `Expected: false Actual: <true>` x2; failing: M-GV-1 (editor mode switch), M-GV-3 (canvas dispose).
- B, PlanEditor not passing to the service view: `Expected: false Actual: <true>` x2; failing: M-GV-1, M-GV-2.
- C, stroke from selectionWidth (both views): `Expected: <3.0> Actual: <1.0>`; failing: M-GV-5.
- D1, canvas swap reset removed: `Expected: true Actual: <false>`; failing M-GV-3.
- D2, service swap reset removed: `Expected: true Actual: <false>`; failing M-GV-4.
- Clean tree afterwards: +5 All tests passed.

## Gate (packages/jet_cad_2d_plan)
- `flutter test --enable-vmservice`: `02:41 +1739: All tests passed!` (1734 + 5)
- `flutter analyze`: `No issues found!`
- `dart format --output=none --set-exit-if-changed .`: `Formatted 337 files (0 changed)`, exit 0.

## Concerns
- Two earlier full runs (while I still had unused-import lint to fix, tests otherwise identical) showed "did not complete" failures (first: 216+ in barrel_test etc.; second: editor_modes_test F-3 at +1722). editor_modes_test alone passed 36/36, and the third full run passed fully. Looks like a load flake of the vmservice suite, not caused by this change; worth knowing.
- No CHANGELOG entry (not in the brief's file list; presumably the final task).
- Test M-GV-1 pins `userOn` surviving the switch only when set false by `toggle()`.
