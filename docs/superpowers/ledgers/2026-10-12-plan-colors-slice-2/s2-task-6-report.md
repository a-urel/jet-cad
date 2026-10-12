# Task 6 report: the guide, the CHANGELOG, STATUS and the exit

Status: DONE. Commit `fcdda26c28e47eae9b90f2ccbd4e3010ea83adb9`
("docs: plan colours Slice 2 in the guide, the CHANGELOG and STATUS"), on top of `20dd1ba`. No source or test code touched.

## Doc edits

docs/host-guide.md
- New "### Colours on the plan" under section 7, before "### Table groups": palette (eight hues, stored by name, unknown name read as null and saved back), `detail.color`, `setTableColor` / `setTablesColor` and `setTableData`'s rules restated (design mode only with a StateError, ambiguous or unknown numbers refused with false, one undo step "Table colour", hidden or locked tables take one, null removes), the Colour row (also under tablesOnly, `recolor`), the internal `jetcad.table_color` component, `table.invalid_color`, "a status covers a colour" (group status too) and clearing shows it again, dark canvas toning like a room's tint, `tableColorOpacity` (null 0.35), export and print (view at its theme's opacity; `exportPlan` / `printPlan` at 0.35 or the given value, ArgumentError outside [0, 1]), `designChanges` reporting `FloorPlanTableChanged`.
- Theme section: "sixteen" became "seventeen" fields; a table row for `tableColorOpacity` (since 0.6.0); a new "Table colours" bullet in "What each field does"; "the two opacities" became "the three opacities" (the view checks the range, verified in floor_plan_theme.dart); the "Never stored" bullet notes the view's own export draws a table colour at the look's opacity.
- Section 7 "The design's changes": before/after can differ in "the colour" too. Editor capabilities `recolor` bullet: "rooms and tables".
- Section 11: no statement moved (schema 10 text already covers 0.6.0).

tool/ci/host_probe/lib/main.dart: the five new code blocks added verbatim: `colourOf` / `markVip` / `clearColour`, `colourSection`, `exportStrong`, `colourChanged` (methods of `_FloorScreenState`, before `designChanged`) and the top-level `strongTableColours` const (after `posDarkTheme`, so the existing light/dark theme block stays contiguous; my first placement broke it and check_guide caught that).

CHANGELOG.md: Unreleased intro now "Plan colours (two slices, released together as 0.6.0)"; bullets for the table colour (as worded in the brief), the `underlay` of `exportPagePdf` / `exportPagePng`, and `isTable(doc, handle)` exported by `editor.dart` (an addition beyond the brief, so the public API change is recorded).

STATUS.md: In flight (Slice 2 implemented and reviewed on `feat/plan-colors-slice-2`, awaiting the human's merge word, then 0.6.0), Owed to the human (a look at coloured tables in both modes, light and dark, and in an export; earlier items kept), Resume here rewritten. The stale "pin the Colour row's tool-mode visibility" paragraph was dropped: Task 5's CP1 Wall-tool leg covers it.

## Gate (all run from the worktree, in sequence)

- `check_guide` (also run after the first edit; first failed on block placement, then fixed): `docs/host-guide.md: all 53 code blocks are in the host probe`
- packages/jet_cad_2d: `dart test` (json run) then expect_failures: `packages/jet_cad_2d: 1290 tests; the standing failures and skips, exactly`; `dart analyze`: `No issues found!`; format: `Formatted 175 files (0 changed)`.
- packages/jet_cad_2d_flutter: `flutter test` json run; expect_failures printed only
  `standing failure passed or did not run: ...text_lod_ladder_golden_test.dart :: text lod ladder rung 1 (RenderBackend.canvas)` and `... rung 2 ...` and exited 1: the recorded macOS standing difference, nothing else. analyze: `No issues found! (ran in 3.6s)`; format: `Formatted 230 files (0 changed)`.
- packages/jet_cad_2d_gpu: `00:00 +20: All tests passed!`; expect_failures: `packages/jet_cad_2d_gpu: 20 tests; the standing failures and skips, exactly`, exit 0; analyze `No issues found!`; format `Formatted 10 files (0 changed)`.
- packages/jet_cad_floor_plan (`flutter test --enable-vmservice`): `02:22 +1983: All tests passed!`, exit 0; analyze `No issues found! (ran in 4.7s)`; format `Formatted 293 files (0 changed)`.
- packages/jet_cad_restaurant_symbols: `+97: All tests passed!`; analyze clean; format `Formatted 15 files (0 changed)`.
- apps/floor_planner: `+212: All tests passed!`; analyze `No issues found!`; format `Formatted 47 files (0 changed)`.
- apps/restaurant_demo: `+68: All tests passed!`; analyze `No issues found!`; format `Formatted 9 files (0 changed)`.
- tool/ci: `dart test` `+64: All tests passed!`; analyze `No issues found!`; format `Formatted 11 files (0 changed)`.
- Host probe (`tool/ci/host_probe.sh file:///Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-colors-2 fcdda26c...`): analyze `No issues found! (ran in 3.7s)`, exit 0, last line `host probe: no GPU renderer, no build hook; build/web is  42M`.
- Old-host probes v0.3.0, v0.4.0, v0.5.1: each exit 0, `No issues found!`, last line `old host probe: <tag>'s main.dart analyses against fcdda26c28e47eae9b90f2ccbd4e3010ea83adb9`.

`git status` clean after the probes (no analysis_options.yaml, no probe leftovers).

## Deviations and concerns

- The engine's `dart test` exit code was not captured (my pipeline reported tail's); the expect_failures comparison is the gate and said "exactly".
- The guide says the Colour row and `recolor` apply to tables; verified against the CHANGELOG/brief wording, not by running the editor here.
- STATUS says "Reviewed per task" per the brief; I did not check the ledger.
