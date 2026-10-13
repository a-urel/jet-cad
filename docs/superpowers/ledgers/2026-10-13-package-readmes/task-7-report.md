# Task 7 report: 0.7.2

Commit: 4ba29d0f "chore: jet_cad_2d, jet_cad_2d_flutter and jet_cad_floor_plan 0.7.2"

## RED (tests first, tool/ci `dart test`, 92 run)
Failing tests:
  test/dependency_lines_test.dart: DL2 every such dependency is the caret of D1
  test/guide_test.dart: GD3 a pubspec line the probe does not have is named
## GREEN
tool/ci `dart test`: "+94: All tests passed!"; check_guide: "all 56 code blocks are in the host probe"; check_readmes: "all 6 code blocks are in the probes".
- jet_cad_2d: dart test + expect_failures "1291 tests; the standing failures and skips, exactly"; analyze no issues; format 0 changed.
- jet_cad_2d_flutter: expect_failures printed only "standing failure passed or did not run" for text_lod_ladder rung 1 and rung 2 (canvas), the known R7 macOS difference; analyze clean; format 0 changed.
- jet_cad_floor_plan (--enable-vmservice): "2012 tests; the standing failures and skips, exactly"; analyze clean; format 0 changed.
- Dry-runs (after commit; tree clean):
  - jet_cad_2d: "Total compressed archive size: 229 KB." / "Package has 0 warnings."
  - jet_cad_2d_flutter: "Total compressed archive size: 813 KB." / "Package has 0 warnings."
  - jet_cad_floor_plan: "Total compressed archive size: 781 KB." / "Package has 0 warnings."

## Files changed
- Versions 0.7.2: packages/{jet_cad_2d,jet_cad_2d_flutter,jet_cad_floor_plan}/pubspec.yaml.
- ^0.7.1 -> ^0.7.2: those packages' constraints, jet_cad_restaurant_symbols, jet_cad_2d_gpu, apps/{floor_planner,dev_harness_2d,restaurant_demo}, tool/screenshots, tool/readme_probe, tool/ci/host_probe/pubspec.yaml.in.
- docs/host-guide.md: lines 7, 24, 33, schema 10 paragraph (lines 2271, 2275 list 0.7.2).
- tool/ci/test/dependency_lines_test.dart (DL2 '^0.7.2', DL3 example), guide_test.dart (GD3 ^0.7.2 -> ^0.7.3).
- Three package CHANGELOGs get "## 0.7.2" above 0.7.1; root CHANGELOG.md gets a "Latest releases" paragraph naming the 0.7.2 of each package.
- host_lock_test.dart fixture left alone. No analysis_options.yaml or lockfile staged.

## CHANGELOG entries
Engine: docs/funding only, README links renderer, planner, guide and says a host adds only the planner; funding links; no code change; plans as in 0.7.1.
Renderer: RulerFrame passes ambient DefaultTextStyle font family to ruler labels and unit symbol (no family: as 0.7.1); screenshots (canvas light/dark, grips, crossing band, symbol gallery); README package table and guide link; funding; jet_cad_2d ^0.7.2.
Planner: exports SymbolLibraryState (Loading/Ready/Failed) and TableNumberProblem (R-10); rulers use the app's font via the renderer change; screenshots (editor light/dark, service view); README package table; funding; deps ^0.7.2; schema 10.
(Full text in the three files.)

## Self-review / concerns
- The brief mentions "each package's CLAUDE.md gate"; only the root CLAUDE.md exists, so I used its gate plus the standing comparison.
- The root CHANGELOG had no per-package index of versions; I added a short "Latest releases" section.
- Task 8's README/funding/screenshots fields are described in the CHANGELOGs but not yet present; check_screenshots stays red until then (R3).
