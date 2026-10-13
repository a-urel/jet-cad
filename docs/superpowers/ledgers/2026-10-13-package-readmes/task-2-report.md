# Task 2 report: NEEDS_CONTEXT (nothing committed)

## Archive sizes before (Step 1, `dart pub publish --dry-run`)
- packages/jet_cad_2d: Total compressed archive size: 229 KB.
- packages/jet_cad_2d_flutter: Total compressed archive size: 226 KB.
- packages/jet_cad_floor_plan: Total compressed archive size: 462 KB.

## Implemented (uncommitted, in the worktree)
tool/screenshots/{pubspec.yaml,README.md,test/support/shots.dart,test/harness_test.dart} verbatim from the brief (dart format re-wrapped two lines);
root pubspec workspace entry; ci.yml matrix entry; dependency_lines_test.dart (pubspec added, DL2 count 15 -> 18, reason updated).
`flutter pub get` touched no analysis_options.yaml; `git status --short` shows only the 3 modified files + tool/screenshots/.

## Evidence
`flutter test` in tool/screenshots: "+3: All tests passed!" (FT1, FT2, SH3).
analyze: "No issues found!"; format --set-exit-if-changed: exit 0; `cd tool/ci && dart test`: "+77: All tests passed!".
Font route: manifest fonts held (no fallback needed).

## Mutations
- M-FT1 (comment out setUpAll(loadManifestFonts)): FT1 FAILS: "Expected: not <40.0>  Actual: <40.0>". FT2 and SH3 still pass.
- M-FT2: NOT KILLED. With setUpAll commented FT2 still passes (flutter_test already loads MaterialIcons itself). With uses-material-design: false, all three pass. I printed the inked fraction: real Icons.add = 0.0922; an Ahem tofu (Text '\u{e145}', fontFamily Ahem, setUpAll disabled) = 0.3332, which is inside the brief's bound (0.02, 0.6), so FT2 passes against tofu. FT2 as written cannot go red for a box.
- M-SH3 as written in the brief (`updating` => true) does not fail SH3: SH3 early-returns when `updating` (`if (updating) return;`), so it passes. Output: "All tests passed!".
  Sharper mutation used instead (`if (updating) {` in shoot -> `if (true) {`): SH3 FAILS (expect on probe.png existing, harness_test.dart:57). probe.png was written, deleted; packages/jet_cad_floor_plan/doc removed (confirmed absent). All files restored from copies, cmp identical.

## Concerns / question
1. FT2's upper bound 0.6 does not separate glyph (0.092) from Ahem box (0.333). Proposed fix: inExclusiveRange(0.02, 0.2); then tofu would fail it. May I change it? (This also means FT2 cannot distinguish routes; the font-manifest fallback of Step 5 was not triggered because FT2 never failed.)
2. M-SH3 in the brief is a non-mutation; I propose recording the `if (true)` mutation instead.
Awaiting direction, then I will commit with "feat(tool): the screenshots package, real fonts and the capture harness".

## Update after the coordinator's rulings (status now DONE)
FT2 rewritten: the icon and a Text of the same codepoint in family 'NoSuchFamily' (Ahem tofu) in keyed boundaries, one local `ink` helper;
expects icon > 0.02 and icon < 0.5 * tofu. Passing run: icon about 0.09, tofu about 0.33.
- M-FT2a (setUpAll commented): FT1 and FT2 FAIL; FT2: "Expected: a value less than <0.1601>  Actual: <0.3202>  icon 0.3202, tofu 0.3202".
- M-FT2b (uses-material-design: false): FT2 FAILS with the identical message. (FT1 passes there.)
- M-SH3 of record: `if (updating) {` -> `if (true) {` in shoot; SH3 fails; probe.png deleted; packages/jet_cad_floor_plan/doc absent. Files restored from copies, cmp identical.
Gate: tool/screenshots flutter test +3 pass, analyze no issues, format exit 0; tool/ci dart test all pass. Committed (see git log).
