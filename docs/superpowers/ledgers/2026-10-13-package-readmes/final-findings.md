# Final review findings to fix (one wave)

Source: the final whole-branch review of 51125b6..d8ccf7c (opus), with the controller's rulings R8-R10 (progress.md).

1. (I1, Ruling R8) Run, locally, the CI gates no task ran, and record each final line in the results note's gate table (docs/superpowers/notes/2026-10-13-package-readmes-results.md):
   - `flutter test --file-reporter "json:<scratch>"` then `dart run tool/ci/expect_failures.dart --package <dir> --root <dir> <json>` from the root, then `flutter analyze` and the format check, for apps/floor_planner, apps/restaurant_demo, packages/jet_cad_restaurant_symbols (as .github/workflows/ci.yml's `package` job does).
   - The host-probe job: from the root, `tool/ci/host_probe.sh "file://$(pwd)" "$(git rev-parse HEAD)"` after your last commit (it needs committed state), then `tool/ci/old_host_probe.sh v0.3.0`, `v0.4.0`, `v0.5.1`, `v0.6.0` (read the scripts first; they write only git-ignored files; leave the tree clean afterwards, `git status --short`).
   - Note in the results note that no CI run has happened on the branch and that a PR to main would run it (the human's word).
   If any of these is red, stop and report it with the output (do not fix code beyond this list).
2. (I2) STATUS.md "Resume here" release checklist:
   (a) add a step 0: the human merges, `git push origin main`, CI green on the merge commit — before any publish;
   (b) steps for the renderer and planner: give the pana lower-bounds command, by pointing at (or quoting) the recipe in docs/superpowers/notes/2026-10-13-publish-host-packages-results.md, section "pana (0.23.19), on each archive's file set" (around line 171);
   (c) write each `cd` as `cd "$(git rev-parse --show-toplevel)/packages/<pkg>"` so steps 2 and 3 work after step 1;
   (d) STATUS.md:3 — one sentence: main carries 0.7.0 and its tag history; the three packages are on pub.dev at 0.7.1; 0.7.2 is in flight (below). Line ~581: drop "R-10's exports as a 0.x candidate for the planner's next release" (this branch delivers them).
3. packages/jet_cad_floor_plan/README.md:87 — replace "a host asks for them in its theme" with a sentence naming `FloorPlanTheme.statusCaptionStyle` and `groupChipTextStyle` and the host guide's theme section (find its heading in docs/host-guide.md and link it); wrap the paragraph at 80 columns.
4. packages/jet_cad_floor_plan/CHANGELOG.md:9-11 — drop "(R-10)"; say: a host that implements `FloorPlanStrings` names `TableNumberProblem`, and a host that watches its `SymbolLibraryLoader` names its states, without importing `editor.dart`.
5. The README version example: in packages/jet_cad_2d/README.md:65, packages/jet_cad_2d_flutter/README.md:76, packages/jet_cad_floor_plan/README.md:119 the patch example becomes `0.7.3` (the minor example stays `0.8.0`).
6. packages/jet_cad_floor_plan/test/example_test.dart:5 — delete the stale comment "The loaded state is not host API: the test reads it from src/."; correct the note's reference to it (it cites :79-80).
7. The results note: remove the Task 8 deferred item claiming R3's hover is indistinguishable (the hover is visible: the sofa's grip-less outline and the rulers' pointer marks).
8. The results note: state the regeneration command `cd tool/screenshots && UPDATE_SCREENSHOTS=1 flutter test` in its fonts/ratio/pictures section (spec D4). tool/screenshots/README.md: separate its sentences into paragraphs (blank lines).
9. tool/screenshots/test/support/shots.dart `settle`: bound the wait by elapsed real time (a Stopwatch, 10 s limit) rather than 40 rounds, keeping the `until` expectation; run `cd tool/screenshots && flutter test` (no UPDATE_SCREENSHOTS) green; do not regenerate PNGs.
10. README.md (root): give the packages table the heading "## The jet-cad packages" as in the package READMEs (spec D1); rewrap the OCCT paragraph at 80 columns; end the file with a newline.
11. (Ruling R10) packages/jet_cad_2d_flutter/lib/src/ruler_frame.dart: one dartdoc sentence on RulerFrame that the labels take the ambient DefaultTextStyle's family (under a Material/Scaffold the app's font; directly under a MaterialApp, the debug fallback's). Run the renderer's ruler tests and analyze.
12. docs/host-guide.md, the theme section: one sentence that since 0.7.2 the editor's rulers follow the ambient DefaultTextStyle's font family. Prose only, no code block (or, if a code block is added, the host probe gets the same code and check_guide stays green).
13. The results note: add a "Final review" section — the verdict, the findings and what was done for each (this list), and rulings R8-R10 with their costs.

After all edits: `cd tool/ci && dart test`; `dart run tool/ci/check_guide.dart`, `check_readmes.dart`, `check_screenshots.dart`; `cd tool/readme_probe && flutter analyze`; the three published packages' `dart pub publish --dry-run` (0 warnings) after committing; `git status --short` clean; never stage analysis_options.yaml.
