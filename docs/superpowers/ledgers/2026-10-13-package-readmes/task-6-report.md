# Task 6 report: tool/readme_probe and check_readmes.dart

Commit: 34cb012f "feat(ci): the package READMEs' code is analysed in tool/readme_probe"

## TDD
- RED: `cd tool/ci && dart test test/readmes_test.dart` failed to load: "Error: Method not found: 'readmeProblems'." (4 call sites), "Some tests failed. ... loading test/readmes_test.dart".
- GREEN: after readmes.dart + probe: RM1-RM4 "+4: All tests passed!".

## README edits (Step 1 forms only, plus R2 sentence)
- Renderer last line: `DraftCanvas(document: document, index: index, camera: camera)` -> `final canvas = DraftCanvas(document: document, index: index, camera: camera);`
- Planner: `MaterialApp(` ... `)` -> `final app = MaterialApp(` ... `);`
- Planner: `SymbolLibraryLoader(sources: [furnitureSymbolSource, mySymbolSource])` -> `final loader = SymbolLibraryLoader(\n  sources: [furnitureSymbolSource, mySymbolSource],\n);` (wrapped for 80 cols; whitespace collapses).
- R2 APPLIED: jet_cad_2d_flutter.dart does not re-export the engine. Renderer probe imports both; README sentence added after "...how its text is measured.": "The snippet uses both packages, so add both: `dart pub add jet_cad_2d jet_cad_2d_flutter`."

## Mutations (copy aside, edit, run, restore, cmp)
- M-RM-a: `circlePayload` -> `circlePayloadX` in jet_cad_2d README: check_readmes exit 1, "jet_cad_2d: dart: import 'package:jet_cad_2d/jet_cad_2d.dart';" restored, cmp ok.
- M-RM-b: planner probe's barrel import deleted: flutter analyze "13 issues found", exit 1; restored, cmp ok.
- M-RM-c: `missingBlocks(...)` replaced by `<String>[]` in readmes.dart: RM2 and RM4 failed (+2 -2); restored, cmp ok.

## Gate
- `cd tool/ci && dart test`: +94 all passed (DL2 now 21 = 15 + 3 screenshots + 3 readme_probe).
- ci-tools analyze (with check_readmes.dart): No issues found. Format lines as CI (incl. host_probe/lib, ../readme_probe/lib): 0 changed.
- check_guide: all 56 blocks ok. check_readmes: "package READMEs: all 6 code blocks are in the probes".
- tool/readme_probe: `flutter analyze` No issues found! (no analysis_options needed); format 0 changed.
- check_screenshots: red as expected (R3), untouched.
- git status: no analysis_options.yaml staged or present untracked.

## Files
Created: tool/readme_probe/{pubspec.yaml,lib/engine.dart,lib/renderer.dart,lib/planner.dart}, tool/ci/{lib/readmes.dart,check_readmes.dart,test/readmes_test.dart}.
Modified: packages/jet_cad_2d_flutter/README.md, packages/jet_cad_floor_plan/README.md, pubspec.yaml (workspace), .github/workflows/ci.yml (ci-tools analyze/format lists, two steps, ../readme_probe/lib), tool/ci/test/dependency_lines_test.dart.

## Self-review / concerns
- Brief says DL2 "+3"; the three published deps of the probe make 21. Reason text updated.
- Probe pins ^0.7.1 per brief; Task 7 must bump it to ^0.7.2 (DL1 enforces).
- Task 8 adding images to READMEs does not affect dart/yaml blocks.
- Planner README YAML block is checked against the host probe's pubspec.yaml.in (RM4).
