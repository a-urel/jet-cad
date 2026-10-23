# Task 5 report

Status: DONE. Commit: see `git log -1` (feat(plan): PlanGuideSettings and the guide theme fields).

## What
- lib/src/guides/guide_settings.dart: `PlanGuideSettings` (on, userOn, allowed, toggle; @internal `allowed` setter, frame-safe like snappingAllowed, `_disposed` check).
- PlanController: `alignmentGuides`, @internal `alignmentGuidesAllowed` (forwards), @internal `guideStrokePixels = 1.0`; settings disposed with the controller.
- PlanTheme: guideOnLight, guideOnDark, guideWidth through constructor, fields, copyWith, merge, lerp, ==, hashCode, _fields/toString, validation; `planPaperPaletteFor` applies withSelection then withGuide, returns the const set when neither colour is set.
- Export in jet_cad_2d_plan.dart; barrel_test name list gained 'PlanGuideSettings' (ED-9 failed otherwise); CHANGELOG first bullet.

## TDD
Red first: both new test files failed to compile (no alignmentGuides / guide fields). Green after implementation: 1684 tests pass (was 1669).

## Mutations (flutter test test/guides/guide_settings_test.dart test/theme/plan_theme_guide_test.dart), each reverted
- `on` ignoring allowed: "Expected: false Actual: <true>" in "the allowance changes at once and notifies after the frame".
- Allowance notified synchronously: "Expected: <0> Actual: <1>" there, and "Expected: <1> Actual: <2>" in "the same allowance twice notifies once".
- lerp dropping guideWidth: "Expected: <4> Actual: <2.0>" in "lerp at 0.5 ...".
- Light colour on dark paper: Expected 0xFF6A1B9A-ish vs Actual green in "planPaperPaletteFor gives each paper its own guide colour" and "a dark guide colour alone...".
- Validation removed: "Expected: Instance of 'ArgumentError' with name: 'guideWidth' Actual: <null>".

## Gate (packages/jet_cad_2d_plan)
`+1684: All tests passed!`; `No issues found!`; format 331 files, 0 changed.

## Concerns
- Mode-switch test uses `setMode(PlanMode.service)` (the controller's API).
- No colour literals added to lib; test colours are in tests only.
