# Review, Tasks 1-2

## Verdicts
1. Spec compliance: Approved. 2. Quality: Approved (0 Critical, 0 Important, 3 Minor).

## Deviations
- plan ^0.8.0 (real pubspec version): acceptable, ^0.1.0 would not resolve.
- loader owned by app: acceptable; plan_controller.dart:340/2786 confirms the controller disposes only a loader it created.
- no Roboto family: acceptable; the library registers it via ensurePlanFonts; brief allowed this.
- rewritten AS-dispose: acceptable and better; I confirmed the deactivate-dispose mutation goes red.
- Task 1 also edits the barrel name-set pin in barrel_test.dart: necessary (ED-9), acceptable.

## Checks run
- app: flutter test "+5: All tests passed!"; flutter analyze "No issues found!"; format "Formatted 3 files (0 changed)".
- Mutations (committed code, reverted, git diff --quiet clean each time): `// jet_cad_restaurant_symbols` in main.dart -> N1 red; dispose in deactivate -> AS1 and both CH-consume red (AS-dispose in implementer's run); drop chord bindings -> both CH-consume red.
- Boundary test passes with cwd = app dir (flutter test); relative paths, plus a files.length guard.
- analysis_options.yaml in commits since main: only apps/architecture_demo/analysis_options.yaml.
- Only floor_planner hit under apps/architecture_demo: pubspec.yaml:11 comment (text taken from the brief).

## Findings
### Critical
none
### Important
none
### Minor
1. apps/architecture_demo/pubspec.yaml:11: comment says "floor_planner", so the brief's own grep (must print nothing) is not clean. Reword to "the old app's bounds".
2. Mutation `symbols: null` (controller owns the loader, app's _symbols never used) survives all tests: the app-owned loader/dispose order in main.dart:44-60 is untested. Optional: assert the loader is disposed after unmount.
3. N1 (boundary_test.dart) skips only its own file by suffix and ignores macos/web and sub-dir pubspecs; fine for spec B6, noting the scope.
