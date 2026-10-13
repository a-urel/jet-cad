# Task 1 report: hosted dependency lines (D1)

Implemented: 15 path deps on jet_cad_2d / jet_cad_2d_flutter / jet_cad_floor_plan in 7 pubspecs replaced by `^0.7.1`; jet_cad_2d_flutter and jet_cad_floor_plan `version: 0.7.0` -> `0.7.1`. New tool/ci/test/dependency_lines_test.dart (DL2 count set to 15, counted from the pubspecs: flutter 1, gpu 2, floor_plan 2, harness 2, symbols 2, planner 3, demo 3).

TDD: RED `cd tool/ci && dart test test/dependency_lines_test.dart`: DL1 failed (`Actual: ['jet_cad_2d: path: ../jet_cad_2d']` ...), DL2 failed (`Expected: <15> Actual: <0>`), DL3 passed. GREEN after rewrite: `+3: All tests passed!`.
`flutter pub get`: "Got dependencies!"; package_config `"rootUri": "../packages/jet_cad_2d"` (F-1). No analysis_options.yaml modified.

Mutant M-DL1 (restaurant_demo jet_cad_2d back to path): DL1 FAILED naming `../../apps/restaurant_demo/pubspec.yaml` (Actual: ['jet_cad_2d: path: ../../packages/jet_cad_2d']); DL2 also failed (Expected 15, Actual 14). Restored from scratchpad copy, cmp clean.

Gates: engine dart test + expect_failures "1291 tests; the standing failures and skips, exactly", analyze/format clean. Render package: analyze/format clean; expect_failures reported only "standing failure passed or did not run" for text lod ladder rungs 1 and 2 (R-1); the five text-ladder goldens failed as listed. gpu 19 pass; floor_plan +2006 ~4 pass; restaurant_symbols 97 pass; restaurant_demo 69 pass; floor_planner (--enable-vmservice) 212, expect_failures "standing failures and skips, exactly"; dev_harness analyze clean; tool/ci dart test 67 pass, analyze --fatal-infos and format clean; check_guide "all 54 code blocks are in the host probe". All analyze/format clean.

Files: the 7 pubspecs + dependency_lines_test.dart. Self-review: diff is only dependency lines + two version lines; comments kept; no concerns.
