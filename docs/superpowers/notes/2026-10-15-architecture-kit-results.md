# The architecture kit (sub-project 3a): results of record

Branch `feat/architecture-kit`, head at the exit gate:
`20d592d96745c965466ff3802fe738cb3ef8c914` (the commit that adds this note
sits on top of it); 48 commits over `main` (local `main` at
`7e65905bf1e05852efa85f4afc50d6f789ceb955`, an ancestor of the head:
`git merge-base --is-ancestor main HEAD` exit 0; `origin/main` at
`651e3d09dd803a1e8e4239b9f98ede4c2adb7018`, behind local `main`:
`git log main..origin/main` prints nothing, `origin/main..main` holds the
2b follow-ups' merge).
Plan: `docs/superpowers/plans/2026-10-15-architecture-kit.md`. Spec:
`docs/superpowers/specs/2026-10-15-architecture-kit-design.md` (revision 2).
Transcripts copied from the terminal on 2026-10-16, last lines only.

Two kinds of evidence, each named: **this run** (a command run by Task 29 on
the head above, its output quoted) and **report** (what a task report in
`.superpowers/sdd/2026-10-15-architecture-kit/` recorded, not re-run here).

The human delegated every open decision of 3a to the controller (*"kararları
sana bırakıyorum. hemen başla."*, 2026-10-15). A line a plan or task marked
"human" is therefore a controller's decision, recorded in the ledger
(`progress.md`) as a `Ruling:` line.

## Gates (this run)

`git status --short`: nothing, before and after every gate.
`git log --name-only --format= main..HEAD | grep analysis_options`:
`packages/jet_cad_2d_integration/analysis_options.yaml`,
`packages/jet_cad_2d_kit_architecture/analysis_options.yaml`, each once
(Task 9's commit).

### `packages/jet_cad_2d_kit`, `jet_cad_2d_plan`, `jet_cad_2d_kit_architecture`, `jet_cad_2d_integration`

| Package | `flutter test` (exit 0 each) | `flutter analyze` | format |
|---|---|---|---|
| `jet_cad_2d_kit` | `00:04 +400: All tests passed!` | `No issues found! (ran in 3.4s)` | `Formatted 92 files (0 changed)`, exit 0 |
| `jet_cad_2d_plan` (`--enable-vmservice`) | `01:58 +1549: All tests passed!` | `No issues found! (ran in 4.4s)` | `Formatted 299 files (0 changed)`, exit 0 |
| `jet_cad_2d_kit_architecture` | `00:20 +650: All tests passed!` | `No issues found! (ran in 3.2s)` | `Formatted 136 files (0 changed)`, exit 0 |
| `jet_cad_2d_integration` (`--enable-vmservice`) | `00:55 +226: All tests passed!` | `No issues found! (ran in 3.1s)` | `Formatted 79 files (0 changed)`, exit 0 |

No skip in any of the four (`grep -rn "skip:"` over their `test/` prints
nothing).

The invariants on their own:
- `cd packages/jet_cad_2d_plan && flutter test --enable-vmservice test/invariants`
  (band_allocation, canvas_paint_allocation, contract_names,
  pick_allocation, theme_colours): `00:09 +15: All tests passed!`
- IA-alloc, `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice test/invariants/paint_allocation_test.dart`:
  `00:00 +0: IA-alloc a rebuilt steady-state PlanCanvas frame over the sample flat allocates O(1) per flush, the kit loaded (M-IA-alloc)`
  then `00:00 +1: All tests passed!`

The kit's cost prints (printed, not asserted). **This run**: each test run
on its own in `packages/jet_cad_2d_kit_architecture` (`flutter test <file>
--plain-name <id>`, each `+1: All tests passed!`), the full lines
transcribed in `task-29-report.md`'s fix report 1:
- `WT12 n=600: median per hover 75.06 us (whole pointer move), band scan alone 73.22 us`
- `OT4 n=600: median per hover over no wall 96.84 us (whole pointer move), host scan alone 92.32 us; over a wall, with the preview, 106.02 us`
- `GE5b 612 walls: end-grip preview along a face line: first 7199 us, median 109 us, worst 7199 us, over 1 ms 1/61 (printed, not asserted)`
- `TT6 600 walls, a courtyard among 600 free walls: median per Unbounded hover 143.8 us; the first, which builds the contours, 12519 us`
- `TT6 636 walls, outside a connected 636-wall plan: median per Unbounded hover 155.4 us; the first, which builds the contours, 7524 us`
- `TL8 612 walls, 0.3 px/mm: median per move over the band path 116.0 us idle, 111.0 us with two points placed (the preview rebuilt each move); on the face line 1481 us, on the centreline 124 us; a Shift slide along a face line 95.0 us per move (worst 190 us); budget 1000 us per move (D12; printed, not asserted)`

**Reports** (the same prints when the task ran them; timing varies between
runs and machines' load, so the numbers differ):
- Task 12 (fix report): `WT12 n=600: median per hover 38.04 us (whole pointer move), band scan alone 35.86 us`; without the liveness check `... 4.16 us ..., band scan alone 1.88 us`.
- Task 15: `OT4 n=600: median per hover over no wall 43.68 us (whole pointer move), host scan alone 41.64 us; over a wall, with the preview, 50.52 us`.
- Task 21: GE5b "a median of 102 us per preview among 612 walls".
- Task 19: TT6 median per Unbounded hover 137.5 us (600 free walls) and 147.5 us (connected 636-wall plan); today's line 19.2 us and 12.3 us.
- Task 22: TL8 band path idle 104-116 µs with the check, 44 µs without, today's 38 µs; Shift slide 96 µs.

This run's TL8 prints a face-line move of 1481 us, over D12's 1,000 µs
budget; the line is printed, not asserted, and Task 22's report quotes no
face-line figure. Recorded for the final review.

### Tools

As CI's `ci-tools` job runs them:
- `cd tool/ci && dart test`: `00:44 +118: All tests passed!`
- `dart analyze --fatal-infos lib test expect_failures.dart check_guide.dart check_host_lock.dart package_root.dart check_screenshots.dart check_readmes.dart check_kit_deps.dart`: `No issues found!`, exit 0.
- `dart format --output=none --set-exit-if-changed lib test ... ../readme_probe/lib`: `Formatted 24 files (0 changed)`, exit 0; `dart format --language-version=3.6 --output=none --set-exit-if-changed host_probe/lib`: `Formatted 1 file (0 changed)`, exit 0.
- `cd tool/readme_probe && flutter analyze`: `No issues found! (ran in 3.1s)`.
- From the root, `dart run tool/ci/check_kit_deps.dart`: `kit dependencies: 2 package(s) checked, none names the plan library or another kit`, exit 0. The two are the contract and `jet_cad_2d_kit_architecture` (`tool/ci/lib/kit_deps.dart:12`, `RegExp(r'^jet_cad_2d_kit_[a-z0-9_]+$')`); report: Task 9's M-SC-deps made the check print `jet_cad_2d_kit_architecture: test/scaffold/kit_test.dart imports jet_cad_2d_plan`, `exit=1`.
- `dart run tool/ci/check_guide.dart`: `docs/host-guide.md: all 56 code blocks are in the host probe`, exit 0. `dart run tool/ci/check_readmes.dart`: `package READMEs: all 6 code blocks are in the probes`, exit 0. `dart run tool/ci/check_screenshots.dart`: `screenshots: every rule holds`, exit 0.

### CLAUDE.md's gates

- `jet_cad_2d`: `dart test`: `00:06 +1337 -2: Some tests failed.`, the two
  failing:
  `test/testing/generate_document_test.dart: the default document is the one Plan 2 measured, byte for byte [E]` and
  `test/testing/generate_document_test.dart: both text fractions default to zero and change nothing [E]`.
  Against `tool/ci/standing_failures.txt`: exactly its two
  `packages/jet_cad_2d` lines, nothing else. `dart analyze`: `No issues found!`;
  format: `Formatted 187 files (0 changed)`, exit 0.
- `jet_cad_2d_flutter`: `flutter test`: `00:25 +1450 ~1 -5: Some tests failed.`,
  the five failing: `test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas) [E]`
  through `rung 5`. Against `standing_failures.txt`: its five
  `text_ladder` lines; its two `text_lod_ladder` lines (rungs 1, 2) pass on
  this machine. They are the Linux-only goldens (the file's header, "fail
  on CI's Linux runner by design"; plan 07's results note, line 78:
  "`text_lod_ladder` rungs 1–2 (Linux-only goldens, Ruling 07-7 ...)").
  Nothing else fails. The one skip is the standing rig test (`Skip: run
  explicitly: flutter test --tags rig --run-skipped`). `flutter analyze`:
  `No issues found! (ran in 4.3s)`; format: `Formatted 234 files (0 changed)`,
  exit 0.
- `jet_cad_2d_gpu`: `00:02 +20: All tests passed!`; `No issues found! (ran in 3.1s)`;
  `Formatted 10 files (0 changed)`, exit 0.
- `cd packages/jet_cad_2d && dart test test/invariants/query_allocation_test.dart`: `00:05 +6: All tests passed!`
- `cd packages/jet_cad_2d_flutter && flutter test test/invariants/paint_allocation_test.dart`: `00:00 +3: All tests passed!`
- The old line, once (A12; the branch changes nothing under them, Hand checks below):
  - `cd packages/jet_cad_floor_plan && flutter test --enable-vmservice`: `01:52 +2012: All tests passed!`
  - `cd packages/jet_cad_restaurant_symbols && flutter test`: `00:00 +97: All tests passed!`
  - `cd apps/floor_planner && flutter test`: `00:33 +212: All tests passed!`

### Dry runs

At the head above, before this task's CHANGELOG lines (this run): the
three `dart pub publish --dry-run` (kit, plan, architecture kit) each exit
0 with `Package has 0 warnings.` (Task 29's report, Step 5).

At `13fb4933` (this task's first commit; this run, fix round 1, every
printed line transcribed in `task-29-report.md`'s fix report 1):
- `cd packages/jet_cad_2d_kit && dart pub publish --dry-run`: exit 0,
  `Total compressed archive size: 120 KB.`, `Package has 0 warnings.`
- `cd packages/jet_cad_2d_plan && dart pub publish --dry-run`: exit 0,
  `Total compressed archive size: 938 KB.`, `Package has 0 warnings.`
- `cd packages/jet_cad_2d_kit_architecture && dart pub publish --dry-run`:
  exit 0, `Total compressed archive size: 536 KB.`, `Package has 0 warnings.`
  The printed list holds `CHANGELOG.md (1 KB)`, `LICENSE (11 KB)`,
  `README.md (<1 KB)`, `assets/library/furniture.jetlib (65 KB)` (and
  `furniture.snapshot.json (17 KB)`), `example/main.dart (1 KB)`,
  `lib/jet_cad_2d_kit_architecture.dart (<1 KB)` and `pubspec.yaml (<1 KB)`,
  besides `analysis_options.yaml (<1 KB)`, `lib/src/...`, `test/...` and
  `tool/generate_furniture_library.dart (1 KB)`.
- `cmp LICENSE packages/jet_cad_2d_kit_architecture/LICENSE`: prints nothing, exit 0.

After this task's CHANGELOG lines, before its commit (this run): each of
the three exits 65 with `Package has 1 warning.`, the one warning being
`* 1 checked-in file is modified in git.` / `Modified files:` /
`CHANGELOG.md`, the uncommitted edit itself; no other issue (Task 29's
report, Step 5).

`jet_cad_2d_integration` is `publish_to: none`, not dry-run.

### Hand checks (this run, each from the root)

- `git diff --stat main -- packages/jet_cad_floor_plan packages/jet_cad_restaurant_symbols packages/jet_cad_2d_gpu packages/jet_cad_2d packages/jet_cad_2d_flutter apps`: prints nothing.
- `grep -n "^version:" ...`: `packages/jet_cad_2d_kit/pubspec.yaml:5:version: 0.1.0`,
  `packages/jet_cad_2d_plan/pubspec.yaml:5:version: 0.8.0`,
  `packages/jet_cad_2d_kit_architecture/pubspec.yaml:6:version: 0.1.0`,
  `packages/jet_cad_2d_integration/pubspec.yaml:6:version: 0.0.0`;
  `grep -n "publish_to" packages/jet_cad_2d_integration/pubspec.yaml`: `5:publish_to: none`;
  `git diff main -- packages/jet_cad_2d_kit/pubspec.yaml packages/jet_cad_2d_plan/pubspec.yaml | grep "^[-+][^-+]"`: prints nothing.
- The kit's `dependencies:` block: `flutter` (sdk), `jet_cad_2d: ^0.7.2`,
  `jet_cad_2d_flutter: ^0.7.2`, `jet_cad_2d_kit: ^0.1.0`, `meta: ^1.18.0`,
  `vector_math: ^2.2.0`, nothing else.
  `grep -rn "jet_cad_2d_plan\|jet_cad_2d_kit_[a-z]" packages/jet_cad_2d_kit_architecture --include=*.dart --include=*.yaml | grep -v "jet_cad_2d_kit_architecture"`: prints nothing.
- `grep -rn "package:jet_cad_2d_plan/src\|package:jet_cad_2d_kit_architecture/src\|package:jet_cad_2d_kit/src" packages/jet_cad_2d_integration`: prints nothing.
  `grep -rln "invalid_use_of_internal_member" packages/jet_cad_2d_integration/test`:
  20 files, each named by its task's report (R-P9): `controller/zone_room_test` (28);
  `dimension/dimension_panel_test` (21), `dimension/dimension_shell_test` (26);
  `l10n/determinism_test` (27, a line-level ignore), `l10n/leak_test`,
  `l10n/locale_separator_test`, `l10n/numbered_names_test` (27, D7);
  `opening/opening_frozen_test`, `opening_grips_test`, `opening_kink_test`,
  `opening_paint_test`, `opening_panel_test`, `opening_symbol_test`,
  `support/opening_support.dart` (14, R14-8), `opening/opening_tool_test` (15);
  `panels/wall_section_test` (27, WS9-open); `room/room_grips_test`,
  `room/room_panel_test` (18), `room/room_paint_test` (26);
  `wall/wall_grips_test` (12). Task 28's report counts the same 19 plus its own.
- `grep -n "jet_cad_2d_kit_architecture\|jet_cad_floor_plan\|jet_cad_restaurant_symbols" packages/jet_cad_2d_kit/pubspec.yaml packages/jet_cad_2d_plan/pubspec.yaml`: prints nothing.
  `grep -rn "import 'package:jet_cad_floor_plan\|import 'package:jet_cad_2d_kit_architecture" packages/jet_cad_2d_plan packages/jet_cad_2d_kit`: prints nothing.
- `cd packages/jet_cad_2d_kit && flutter test test/invariants/purity_test.dart`: `00:00 +10: All tests passed!`
- `grep -rn "import 'dart:io'" packages/jet_cad_2d_plan/lib packages/jet_cad_2d_kit/lib packages/jet_cad_2d_kit_architecture/lib`: prints nothing.
- `cd packages/jet_cad_2d_kit_architecture && dart run tool/generate_furniture_library.dart`:
  `wrote assets/library/furniture.jetlib: 67083 bytes, 41 symbols`; then
  `git diff --quiet -- packages/jet_cad_2d_kit_architecture/assets/library`: exit 0.
- `grep -n "jet_cad_2d_kit_architecture\|jet_cad_2d_integration" .github/workflows/ci.yml`:
  `50: - package: packages/jet_cad_2d_kit_architecture`,
  `52: - package: packages/jet_cad_2d_integration` (its entry carries
  `test_flags: --enable-vmservice`), `188: - packages/jet_cad_2d_kit_architecture`
  (the `publishable` matrix). Both in the test matrix; the kit publishable, as C2 has it.
- `git status --short`: nothing after all of the above (before this task's own edits).

## Appendix A, closed

Built from the plan's "Appendix A coverage" table and the task reports; every
test name below was found by `grep -rln` over
`packages/{jet_cad_2d_kit_architecture,jet_cad_2d_integration,jet_cad_2d_plan,jet_cad_2d_kit}/test`
in this run. K = `jet_cad_2d_kit_architecture/test`, I = `jet_cad_2d_integration/test`,
P = `jet_cad_2d_plan/test`, C = `jet_cad_2d_kit/test`.

| Row | Owner | State | Evidence |
|---|---|---|---|
| D-01 | 24, 28 | ported | `wall_faces_test` → K `attach/wall_faces_test.dart` (WF1-WF9); `wall_attach_test` (23) → K `attach/wall_attach_test.dart` (WA1-WA18, WK0-WK4) and `wall_attach_property_test` (2) → K `attach/wall_attach_property_test.dart` (WP1, WP2), in the kit by R-P1/R-P3 (they call `placeSymbol`); `symbol_move_test` (6) → I `attach/symbol_move_test.dart` (MV1-MV6) |
| D-02 | 28 | ported | `symbol_place_tool_test.dart:1372-1716` → I `attach/wall_attach_tool_test.dart` (12 cases, "a tagged symbol attaches on hover and on release" ...); lines dropped: IA-R4 (below) |
| D-03 | 28 | ported | `host/against_wall_rotate_test` (3) → I `attach/against_wall_rotate_test.dart` ("rotate: false", R-1, R-3) |
| D-04 | 28 | ported | WE1 → I `attach/wall_attach_end_to_end_test.dart`; SS16, SS17 → I `attach/symbol_shell_test.dart`; WE2 not ported (C7, decision 9) |
| D-05 | 28 | ported | I `attach/editor_tools_review_test.dart`: "a symbol against the north wall: M under full, then mirror false", O13a, O13b |
| D-06 | 24 | ported | `WallFaces` compares `stateId`: K `attach/wall_face_provider_test.dart` WF-state, WF-hidden-toggle (M-WF8, M-WF14) |
| D-07 | 24 | ported | The provider's own hysteresis, not the plan test kit's: K WF-hysteresis (M-WF4, M-WF4b), WF-keep |
| D-08 | 24, 28 | ported | `wallFaceProvider` is an `AttachmentProvider`; `mayRotate: false` keeps the current face: K WF-keep (M-WF3), I `against_wall_rotate_test` "rotate: false" (M-IA-2) |
| D-09 | 1 | ported | One owner in the contract: P `invariants/contract_names_test.dart` SB-one-owner (M-SB-owner) |
| D-10 | 1 | ported | The stale `WallFaces` doc comment (the plan's old `symbol_box.dart:153`, "belongs to the caller (`WallFaces`, ...)") rewritten in the move: the contract's `lib/src/model/symbol_box.dart:153-159` now reads "A caller that asks often keeps its own memo and drops it when the document changes (its `commands.stateId`)" (this run, `sed`; no `WallFaces` left in the file) |
| D-11 | 23 | ported | `furniture_library_test` → K `furniture/furniture_library_test.dart` ("the committed bytes equal the built library", "ships 41 symbols in six categories", ...); C7's not-ported and dropped groups listed below |
| D-12 | 28 | ported | `symbol_search_test.dart:76-164, :189-267` (12) → I `symbols/symbol_search_test.dart` ("the name alone finds a symbol", ...) |
| D-13 | 28 | ported | `symbol_box_test.dart:321-339, :391-410` (3) → K `furniture/symbol_box_asset_test.dart` ("every catalog symbol's box equals its hand-derived literal", "reads the live leaves: a removed leaf no longer counts"); in the kit by R-P1 (the spec's "C6" amended by that ruling) |
| D-14 | 28 | ported | `symbol_end_to_end_test` (2) → K `furniture/symbol_end_to_end_test.dart` (R-P1) |
| D-15 | 23 | ported / carried | PA2, PA3 → K `furniture/package_assets_test.dart`; PA4 carried to sub-project 4 |
| D-16 | — | carried | Sub-project 4: RL15, SC1-SC2, SNL over the furniture library |
| D-17 | 8 | ported / dropped | SE8 → P `symbols/unit_copy_test.dart` (M-PN-SE8); SE10, SE10b, SE11 dropped on the human's word (spec decision 7) |
| D-18 | 9 | ruled | The old `example_test` replaced by K `example_test.dart` SC-example (plan writers' ruling, Task 9) |
| D-19 | 10-22, 26 | ported | The 54 files: the table "The six types' files" below |
| D-20 | 27 | ported | WS1-WS11 → I `panels/wall_section_test.dart` (WS9 → WS9-open); SE13, SE15, SE16 (and SE11, SE12) → I `panels/selection_page_test.dart` |
| D-21 | 27 | ported | CP2, CP1's separator line → I `panels/colour_row_test.dart` |
| D-22 | 26 | ported | TD1 → I `canvas/touch_tools_test.dart` |
| D-23 | 26 | ported | I `shell/planner_shell_test.dart`: "a click on a wall selects it", "cmd+Z undoes a Delete", "ctrl+Z after deleting two walls" |
| D-24 | 27 | ported | DT1 (I `l10n/determinism_test`), LK2 (`leak_test`), OV-H (`overflow_test`), PW1/PW2 (`panel_words_test`), NN3 (`numbered_names_test`), VW3 (K `words/value_words_test`), NS3 (I `l10n/locale_separator_test`) |
| D-25 | 3, 9 | ported | `text:` words (C `model/kit_text_test`, `kit/kit_words_test`); the architecture words: K `scaffold/words_test.dart` SC-words, SC-text, SC-conformance |
| D-26 | 26 | ported | I `editor/architecture_palette_test.dart`: A12b (the eight rows), IT-letters, IT-ids, IT-guard |
| D-27 | 4, 19, 22 | ported | P `editor/editor_notice_test` TN-status, TN-relocale; K `room/room_tool_test` RT-notice, I `room/room_tool_test` RT-notice-locale; K `dimension/dimension_notice_test` DT-notice, I `dimension/dimension_tool_test` DT-notice-locale |
| D-28 | 5, 9, 17 | ported | P `controller/new_plan_test.dart` ND1, ND3, ND4 (generic lines); I `scaffold/prepare_test.dart` SC-prepare; DASHED lines: I `separator/separator_dashed_test.dart` ND1, ND3, ND4 (live case), SP-dashed-open; K `separator/separator_plan_test.dart` ND2. ND2's plan half not ported (premise absent, below) |
| D-29 | 26 | ported | K `layers/tools_layer_test.dart` (9), `layers/opening_host_layer_test.dart` (6), `layers/attach_layer_test.dart` (3); I `layers/placer_layer_test.dart` (the placer's case), I `layers/layer_picker_wall_test.dart` (the app's wall case) |
| D-30 | 17 | ported | K `separator/separator_plan_test.dart` SP-type (`exported: false`); I `separator/separator_export_test.dart` SP-export-png, SP-export-pdf |
| D-31 | 18 | ported | K `room/room_color_test.dart` (fixture case, RC1-RC7), I `room/room_color_test.dart` RC8; K `room/room_tint_test.dart` TN1; K `room/room_plan_test.dart` RM-colour |
| D-32 | 27 | ported | Q0-S1, Q0-S2 → K `room/decimal_separator_test.dart`; Q0-E1, Q0-E2, Q0-E3, Q0-E3b → I `panels/decimal_separator_test.dart` |
| D-33 | 26 | ported | P-1, P-2, P-3 → I `controller/delete_components_test.dart` |
| D-34 | 25, 26 | ported | `startup_plan_test` (14) → K `sample/sample_flat_test.dart` (12: SP1-SP9 ...) and I `sample/sample_flat_test.dart` (2, plus SF-controller); `intersection_snap_test` (1) → K `intersection_snap_test.dart` (Task 26 put it in the kit: no plan-library name, C7) |
| D-35 | 28 | ported | TF1's and TF7's room and tint lines → I `service/room_fill_test.dart` TF1-room, TF7-tint |
| D-36 | 28 | ported | I `service/room_fill_test.dart:159`: `expect(spy.fills, hasLength(6), reason: 'A, B, C, U, K and R');` (one line, this run); the plan's P `service/paint/unit_fill_test.dart:535` keeps `hasLength(5), reason: 'A, B, C, U and K'` (C6: the plan's tests stay domain-free) |
| D-37 | 28 | ported | I `export/room_export_test.dart`: the premises' key list with R, EX2-room, EX3-room, EX5-room |
| D-38 | 28 | ported | I `controller/zone_room_test.dart` CZ1 (the zone fixture's room named `7`, `support/zone_plan.dart`) |
| D-39 | 27 | ported | 2a's room cases over real rooms: I `panels/colour_row_test.dart` fixture case, CP1, CP3, CP4, CP5, CP6b |
| D-40 | 6 | ruled | Not added (`isLocked`, `allows`, a settings listenable; spec C1.5, no user today): the contract spec's amendment line 452 ("Not added: ...") |
| D-41 | 2 | ported | `PlanSection` (C `kit/object_view_test.dart` PO-section; P `panels/object_view_panel_test.dart` PO-section) |
| D-42 | — | carried | Sub-project 4 (the wave): the `jet_cad_2d: ^0.7.2` floors |
| D-43 | 7 | ported / ruled | P `kits/grip_refusal_test.dart` GR-1, GR-drag-refuse, GR-drop-refuse, GR-drop-hook; P `kits/guarded_tool_test.dart` F-T7; the `_first` catch-all's probe kept, its cost recorded (plan writers' ruling, Task 7) |
| D-44 | 8 | ported | P `shortcuts/plan_shortcuts_test.dart` PN-remount (M-PN-1, M-PN-2) |
| D-45 | 8 | ported | P `attach/attachment_registry_test.dart` PN-kind, PN-dispose; P `tools/move_resolver_test.dart` MV-2, PN-MV-nested, PN-MV-node, PN-MV-live; P `controller/attachment_controller_test.dart` PN-open |
| D-46 | 2, 14, 18, 21, 27 | ported / ruled | Titles by `title`: I `panels/titles_test.dart` IP-title; `ActionProperty` and `visible`: IP-door-actions, I `editor/editor_panels_test.dart` T5-f; `TextDisplay` through the kit: Q0-E1, RM-area, PN1-PN4. `ValueDisplay`'s units: the kit uses none (plan Task 27, line 20148; C1.1 chose `TextDisplay`), 2a's tests keep it |
| D-47 | 9, 23 | ported | K `scaffold/words_test.dart` SC-conformance over the furniture catalog, its committed library and snapshot |
| D-48 | 26 | ported | "D-48: the closed lists" below, every test found |
| D-49 | — | carried | Sub-project 3b (decision 1): `apps/architecture_demo` |
| D-50 | — | carried | Sub-project 4: 2b's host-API differences |
| A.2 six types' files | 10-22, 26 | ported | the table below |
| A.2 `planner_grips_test` A1-A4 | 26 | ported | I `canvas/planner_grips_test.dart` (A1 M-03au, A2 M-03x, A3 M-03af, A4 M-03aa, and M-03ao) |
| A.2 `editor_panels_test`'s remainder | 26 | ported | I `editor/editor_panels_test.dart`: T5-f, the Wall tool's settings case, V-5 "each selectable", R-3, R-4 |
| A.2 `keyboard_focus_test`'s wall cases | 26 | ported | I `shortcuts/keyboard_focus_test.dart`: "a gesture's keys stay: the Wall tool", DS2, DS5, R-3 RP5 |
| A.2 rows to sub-project 4 | — | carried | listed by name below |
| A.3 WE1, SS16, SS17 | 28 | ported | see D-04 |
| A.3 the layer picker's wall case | 26 | ported | I `layers/layer_picker_wall_test.dart` ("in the app: below the Selection section's type section for a wall; ...") |
| A.3 the rest of `apps/floor_planner/test` | — | carried | Sub-project 3b, below |

### The six types' files (A.2, D-19)

`ls packages/jet_cad_floor_plan/test/*_test.dart` filtered to `box_`,
`wall_`, `opening_`, `separator`, `room_`, `dimension_`, `planner_box`: 54
files (this run). Each has a destination; none rests on a ruling alone.

| Source | Task | Destination(s) | Cases (report) |
|---|---|---|---|
| `box_test` | 10 | K `box/box_test.dart` | BT1-BT6 |
| `planner_box_test` | 10 | I `box/planner_box_test.dart` | BX1-BX6 |
| `wall_params_test` | 11 | K `wall/wall_params_test.dart` | WP1-WP5 |
| `wall_geometry_test` | 11 | K `wall/wall_geometry_test.dart` | WG1-WG21 |
| `wall_bands_test` | 11 | K `wall/wall_bands_test.dart` | WB1, WB2 |
| `wall_regen_test` | 11, 25 | K `wall/wall_regen_test.dart` | WR1-WR13 (WR9's sample line restored in Task 25) |
| `wall_grips_test` | 12, 17, 21 | K `wall/wall_grips_test.dart` (EG1-k, EG3-k, EG4-k, EG6-k, EG8-k, EG9-k, EG10-k); I `wall/wall_grips_test.dart` (EG1-EG10, WG-refuse-short) | 10 |
| `wall_paint_test` | 12 | I `wall/wall_paint_test.dart` | WP5 |
| `wall_tool_test` | 12 | K `wall/wall_tool_test.dart` (WT10-WT13, WT15-WT18, WT20), K `wall/wall_joint_kinds_test.dart` (WT3-k, WT9-k); I `wall/wall_tool_test.dart` (WT1-WT9, WT14, RF2, WT19) | 21 |
| `opening_params_test` | 13 | K `opening/opening_params_test.dart` | OP1 |
| `opening_geometry_test` | 13 | K `opening/opening_geometry_test.dart` | 9 |
| `opening_cut_test` | 13 | K `opening/opening_cut_test.dart` | 6 |
| `opening_obstacle_test` | 13 | K `opening/opening_obstacle_test.dart` | 8 |
| `opening_cost_test` | 13 | K `opening/opening_cost_test.dart` | RC3 |
| `opening_kink_test` | 13, 14, 15 | K `opening/opening_kink_test.dart` (KJ1, KJ1 1e-6°, KJ2, KJ6); I `opening/opening_kink_test.dart` (KJ3, KJ4, KJ5) | 7 |
| `opening_symbol_test` | 13, 14 | K `opening/opening_symbol_test.dart` (OG7, OG10, OR7); I `opening/opening_symbol_test.dart` (OR8) | 4 |
| `opening_object_test` | 14 | K `opening/opening_object_test.dart` | OR1, OR2, OR4, OR5, DF1 |
| `opening_end_drag_test` | 14 | K `opening/opening_end_drag_test.dart` | EP1-EP9, EP5 (start) |
| `opening_grips_test` | 14 | K `opening/opening_grips_test.dart` (7); I `opening/opening_grips_test.dart` (SG1 shell, SG2, SG4) | 10 |
| `opening_paint_test` | 14 | I `opening/opening_paint_test.dart` | RD1 |
| `opening_panel_test` | 14, 15 | I `opening/opening_panel_test.dart` | OS1, OS1 (runtime), OS2, OS3, OS4 |
| `opening_tool_test` | 15 | K `opening/opening_tool_test.dart` (16 + OT1 (preview)); I `opening/opening_tool_test.dart` (OT1 (shell), rv9-guardDNG) | 18 |
| `separator_test` | 16 | K `separator/separator_test.dart` | SR1, SR2, SR4, SR5 |
| `separator_tool_test` | 17, 18 | K `separator/separator_tool_test.dart` (ST1 tool half, ST2-ST6); I `separator/separator_shell_test.dart` (ST1 (editor)) | 6 |
| `room_trace_test` | 16 | K `room/room_trace_test.dart` | RT1-RT4, RT6-RT9 |
| `room_inputs_test` | 16 | K `room/room_inputs_test.dart` | RI1, RI2, RT5 |
| `room_label_test` | 16 | K `room/room_label_test.dart` | RL1, RL2, RA1, Q0-RA1 |
| `room_localise_test` | 16 | K `room/room_localise_test.dart` | LZ1, LZ2, LZ4 |
| `room_tie_test` | 16, 18 | K `room/room_tie_test.dart` | DE1-DE3 |
| `room_object_test` | 18 | K `room/room_object_test.dart` | 10 |
| `room_tint_test` | 18 | K `room/room_tint_test.dart` | TN1 |
| `room_diagnostics_test` | 18 | K `room/room_diagnostics_test.dart` | DG1-DG4 |
| `room_dissolve_test` | 18 | K `room/room_dissolve_test.dart` | RG2, RD1-RD8 |
| `room_follow_test` | 18 | K `room/room_follow_test.dart` | RG3, RS1-RS6, DF1, FZ1 |
| `room_cost_test` | 18, 26 | K `room/room_cost_test.dart` | RK1, RK2, LZ3 |
| `room_color_test` | 18 | K `room/room_color_test.dart` (fixture case, RC1-RC7); I `room/room_color_test.dart` (RC8) | 9 |
| `room_grips_test` | 18 | K `room/room_grips_test.dart` (GR1, GR5 ×2, GR6); I `room/room_grips_test.dart` (GR1-GR5 shell cases) | 9 |
| `room_panel_test` | 18 | I `room/room_panel_test.dart` | fixture case, RN1-RN6; RN5 → RN5-open + RN5-refused |
| `room_paint_test` | 26 | I `room/room_paint_test.dart` | RR1-RR4, SR3, OL4 |
| `room_tool_test` | 19, 20 | K `room/room_tool_test.dart` (TT1 tool, TT2-TT6, TT4b, TT8-TT10); I `room/room_tool_test.dart` (TT1 editor, TT7, SG1) | 13 |
| `dimension_params_test` | 20 | K `dimension/dimension_params_test.dart` | DP1 |
| `dimension_format_test` | 20 | K `dimension/dimension_format_test.dart` | DF1-DF3, Q0-DF1 |
| `dimension_layout_test` | 20 | K `dimension/dimension_layout_test.dart` | DL1, DL2, DL2b, DL3-DL5 |
| `dimension_attach_test` | 20 | K `dimension/dimension_attach_test.dart` | AM1-AM7, AM2 (scaled group), AM6b |
| `dimension_attach_points_test` | 20 | K `dimension/dimension_attach_points_test.dart` | AP1-AP3 |
| `dimension_follow_test` | 20 | K `dimension/dimension_follow_test.dart` | DN1-DN4 |
| `dimension_rotate_test` | 20 | K `dimension/dimension_rotate_test.dart` | DR1-DR5 |
| `dimension_fuzz_test` | 20 | K `dimension/dimension_fuzz_test.dart` | DZ1 |
| `dimension_object_test` | 21 | K `dimension/dimension_object_test.dart` | DO1-DO6, DD1-DD5 |
| `dimension_grips_test` | 21 | K `dimension/dimension_grips_test.dart` | GE1-GE5, GE5b (GE1's no-index line: DM-R1) |
| `dimension_panel_test` | 21 | I `dimension/dimension_panel_test.dart` | PN1-PN5; PN5's refused edit → PN5-open |
| `dimension_tool_test` | 22 | K `dimension/dimension_tool_test.dart` (TL1-TL3, TL5, TL6, TL8, M-DT-8, TL4k, TL5k); I `dimension/dimension_tool_test.dart` (TL4, TL5 status line, TL7) | 13 + twins |
| `dimension_paint_test` | 26 | I `dimension/dimension_paint_test.dart` | RR1-RR3 |
| `dimension_shell_test` | 26 | I `dimension/dimension_shell_test.dart` | SL1, SL2, TL9 |

The brief's port-comment grep
(`grep -rln "Ported from jet_cad_floor_plan/test/\|Ported to jet_cad_2d_kit_architecture\|Ported for jet_cad_2d_integration"`)
lists 86 files. Ported test files that carry no line naming their
`jet_cad_floor_plan` source (they keep today's header): K
`dimension/dimension_{attach_points,attach,follow,format,fuzz,grips,layout,object,params,rotate}_test.dart`
(Tasks 20, 21) and K `attach/wall_faces_test.dart` (Task 24). A provenance
comment only; every such file is named in its task report's accounting.
For the final review (Minor).

### Carried to sub-project 3b

D-49, `apps/architecture_demo`. Of `apps/floor_planner/test`, everything
but WE1, SS16, SS17 and the layer picker's wall case: the document
commands, exit, files, host, open (DO3 included), replace, save,
separator, settle, export and print flows, `symbol_library_loader_test`,
`symbol_shell_test` SS1-SS15, the end-to-end tests (WE2 is not ported at
all: C7), `app_words_test`, `export_font_test` EF1-EF3, EF9-EF12.

### Carried to sub-project 4

D-16 (RL15, SC1-SC2, SNL over the furniture library), D-42 (the
`jet_cad_2d: ^0.7.2` floors), D-50 (2b's host-API differences), and A.2's
parity rows by name: `host/camera_test` CM8-CM14, CM16, CR1-CR6, UC1, UC2;
`host/controller_test` CZ2-CZ6, CV1-CV3, CS1-CS4; `host/page_flows_test`
PF1; `host/editor_tools_test` T4-c, T4-d, T4-h, T4-i;
`host/editor_capabilities_test` EC3, EC4, EC6, EC7, PC8;
`host/editor_panels_test` T5-h; `host/seams_test` SM1-SM3;
`widget_theme_test` (7); `symbols/symbol_component_test` SC7-SC12;
`package_assets_test` PA4.

### Lines dropped, decided by the controller (delegated)

Every line below is decided; none is pending. The plan's 19 rows were
accepted by the controller under the human's delegation before execution
(ledger: "Ruling: the 19 dropped/instrument-changed ported assertion lines
(plan appendix) accepted"); the lines decided while executing are the
controller's rulings, as listed.

From the plan (decided before execution, by the controller, delegated):
1. Task 5, ND2 (whole case): not ported, premise absent (no page-less set-up in the plan library). Its DASHED half is K ND2.
2. Task 5, ND4: `hasLength(10)` walls → `hasLength(2)` slabs, `liveObjectsOf<WallParams>` → `objectsOf<SlabComponent>` (the generic fixture).
3. Task 9, D-18 `example_test`: replaced by SC-example.
4. Task 14, KJ4: `hostFrameInDocument(doc, hA)!.uE` → `OpeningOracle(c.document).span(hA).$2` (R14-9; instrument only).
5. Task 15, OS3 / OT1: the settings width read through `settingsText` (R15-3).
6. Task 18, GR4 (shell): the trace area read from the drawn tint.
7. Task 21, GE1 (DM-R1): `ObjectGrips(edgeAperture: () => null).gripsOf(doc, dim2)` isEmpty, premise impossible.
8. Task 21, PN1, PN2 (DM-R2): the `bruteCandidates` premises (kit internals).
9. Task 22, TL5 status line (DT-R3): canvas width `== 896` → `greaterThan(4690 * 0.12)`.
10. Task 23: the pre-09c group (4) and "the 14 new symbols ... == 27" (decision 9); the seating group's two seat-count tests (decision 7).
11. Task 8, SE10, SE10b, SE11: dropped by the spec's decision 7 (the human's, taken in the brainstorm).
12. Task 26, SL1 (IT-R13): `:345-349`, `:359`, `:427` (`oracleFailures`), kit internals.
13. Task 27, WS3, WS10 (IP-R2): the `WallTool.settings` reads.
14. Task 27, `decimal_separator` notice cases (IP-R3): `tool.points` hasLength 2, `tool.hoverKind` isNull.
15. Task 27, CP3 (IP-R7): the `recolorCommand` lines.
16. Task 28, MV1, MV3 (IA-R3), decided by the controller (delegated): MV1's marker line (`symbol_move_test.dart:167`), MV3's "before the library is ready" (`:191-195`).
17. Task 28, the D-02 group (IA-R4), decided by the controller (delegated): the ghost's repaint count (`rig.notifications`), `rig.tool.faces` null, and "a tool given no wall faces never attaches" (premise impossible). The marker glyph's paint calls, first listed here, were ported in Task 28's fix round through the tool's own `paintOverlay`.
18. Task 28, WE1 (IA-R5), decided by the controller (delegated): the hover ghost (`bedAt.hovered`, `tool.ghostVisible`). WE2 not ported (decision 9).
19. Task 26, SR3 (IT-R14) and Task 25, SP5/SP9: diagnostics and drift from a fresh or the installed engine system (instrument only).

Decided while executing (the ledger's rulings):
20. Task 28, W-5's and the permissions case's `bands.generation` lines, decided by the controller (delegated): not ported, no public read of the kit's bands under R-P1; the behaviour is pinned in the kit (WL4, WB, WT-frozen, WF-frozen-first, the provider's steady-state step).
21. Task 28, the hidden re-arm's two lines (IA-R4, fix round): "Not ported (IA-R4: the read needs a pointer event, which re-resolves)"; `_onArmed`'s `_attached = null` stays unpinned (parked Minor).
22. Task 15, OS3's `expect(position, findsNothing)` (`opening_panel_test.dart:334`): changed by the binding 2a spec (PlanPropertyPanel row, design-mode spec :345: the settings, and below them the object's section). Now: the settings width row present, `property-position` present and below it.
23. Task 18, RN5 "a refused edit": **Decided: premise impossible under C1.10's freeze at open** (the engine `StateError` cannot reach a live room's panel; the room is frozen at open). Split into RN5-open (A frozen, no section, raw rename `PlanLocked`, B's rename lands) and RN5-refused (an empty or blank name on a live room reverts and re-pins; M-RM-2).
24. Task 21, PN5's refused edit: **Decided: premise impossible** (frozen at open); PN5-open ported; no live kind switch can be refused.
25. Task 27, WS9: **Decided: premise impossible under C1.10's freeze at open**. WS9-open asserts the lock set `{A}`, the hookFailed diagnostic, no section for A, `PlanLocked` on A, and the old intent on the document-level refusal of live C and B through the panel (field reverts, `canon` unchanged), the box's edit landing as control. The old "C is sound: its edit lands" lines are dropped: the malformed fixture's A fill names B's outline, so an edit reaching B would change frozen A's fill (root cause in the ledger). WS9-refused removed (repeated WS3/WS11).
26. Task 26, P-1: `.data isNotNull` (vacuous: `PlanUnitDetail.data` is non-nullable) → `equals(hostData())` (C7 class 3; M-P1a, M-P1b red; the old matcher green under M-P1a).
27. Task 27, LK2: a `text:` template that is only placeholders is left out of the allowlist (the brief's `^(.+)$` matched every string), with a positive control; a plan-text correction.

## D-48: the closed lists, each through the kit's hooks

Task 26's Step 12 table (report), every test found in this run:

| Today's closed list | The kit's hook | Tests (file) |
|---|---|---|
| `isParametricObject` | `PlanType` registered, `typeIdOf` (E1) | I `layers/layer_picker_wall_test.dart`; T5-f (I `editor/editor_panels_test.dart`) |
| `ObjectGrips._of` | `PlanType.grips` | O13a, O13b (I `attach/editor_tools_review_test.dart`); WG-refuse-short (I `wall/wall_grips_test.dart`) |
| `FloorPlanTool` enum | `PlanTool.id` | IT-ids (I `editor/architecture_palette_test.dart`) |
| palette `_entries` and letters | `PlanTool.letter`, `icon`, `needs` | A12b, IT-letters (same file) |
| `kShellLetterKeys` | the letters in use (`planLetterKeys`) | IT-guard (same file) |
| per-tool strings | `tool:` words | IT-letters; PW1 (I `l10n/panel_words_test.dart`); Q0-E3b (I `panels/decimal_separator_test.dart`) |
| the Selection panel's per-type sections | `PlanType.properties`, `title`, `section` | T5-f; WS1 (I `panels/wall_section_test.dart`); IP-title (I `panels/titles_test.dart`) |
| `pickedColors` | `PlanType.colour` | CP1, CP2 (I `panels/colour_row_test.dart`) |
| `exportOmitOwners` | `PlanType(exported: false)` | SP-export-png, SP-export-pdf (I `separator/separator_export_test.dart`) |
| the room inputs | `RoomInputs` over `shared` and `liveTypeIdOf` | RR-live (K `room/room_inputs_services_test.dart`); TD1 (I `canvas/touch_tools_test.dart`); RR1-RR4 (I `room/room_paint_test.dart`); RT-frozen-wall (K `room/room_tool_test.dart`) |

## Ported tests (A12)

Every assertion unchanged except where a ruling is named (the list above).
Change classes: C1 ids, C2 tags to fields, C3 widget form; F a fixture
change the task names. All counts are the reports'.

| Source (`jet_cad_floor_plan/test/…`, `apps/floor_planner/test/…`) | Destination(s) | Tests | Assertions |
|---|---|---|---|
| the six types' 54 files | the table above | 353 (spec D-19) | unchanged but OS3 (2a spec), RN5, PN5 (premise impossible), GE1 (DM-R1), PN1/PN2 premises (DM-R2), KJ4 (R14-9), GR4 shell, TL5 (DT-R3), SL1 (IT-R13) |
| `new_document_test` ND1, ND3, ND4 | P `controller/new_plan_test.dart` (generic); I `separator/separator_dashed_test.dart`, K `separator/separator_plan_test.dart` (DASHED) | 4 + 4 | ND2 not ported; ND4 rewritten (plan rows 1, 2) |
| `seating_test` SE8 | P `symbols/unit_copy_test.dart` | 1 | C1 (2b's unit) |
| `example_test` | K `example_test.dart` SC-example | 1 | replaced (D-18) |
| `symbols/furniture_library_test` | K `furniture/furniture_library_test.dart` | 150 runs (report, Task 23) | C1 (`version == 1`), C2 (`attachTo`, `family`); groups not ported/dropped (plan row 10) |
| `package_assets_test` PA2, PA3 | K `furniture/package_assets_test.dart` | 2 | unchanged |
| `symbols/wall_faces_test` | K `attach/wall_faces_test.dart` | 9 | F (`liveOf`) |
| `symbols/wall_attach_test`, `wall_attach_property_test` | K `attach/wall_attach_test.dart`, `wall_attach_property_test.dart` | 23 + 2 | C1; F (`placeEntry`, `liveOf`) |
| `symbols/symbol_box_test:321-339, 391-410` | K `furniture/symbol_box_asset_test.dart` | 3 | C1; F |
| `symbols/symbol_end_to_end_test` | K `furniture/symbol_end_to_end_test.dart` | 2 | C1; F (`placeEntry` with `style:`) |
| `tools/symbol_move_test` | I `attach/symbol_move_test.dart` | 6 | IA-R1, IA-R2, IA-R3 |
| `symbol_place_tool_test:1372-1716` | I `attach/wall_attach_tool_test.dart` | 12 | IA-R4 |
| `host/against_wall_rotate_test` | I `attach/against_wall_rotate_test.dart` | 3 | IA-R4 reads |
| `editor_tools_review_test` (north wall, O13a, O13b) | I `attach/editor_tools_review_test.dart` | 3 | `Caps.snapping` → `PlanEditor.snapping` |
| apps `wall_attach_end_to_end_test` WE1 | I `attach/wall_attach_end_to_end_test.dart` | 1 | IA-R5 |
| apps `symbol_shell_test` SS16, SS17 | I `attach/symbol_shell_test.dart` | 2 | SS17's premise as the layer's flags |
| `symbol_search_test` (12) | I `symbols/symbol_search_test.dart` | 12 | C1 |
| `startup_plan_test` | K `sample/sample_flat_test.dart` (12), I `sample/sample_flat_test.dart` (2) | 14 | F; SP5/SP9 instrument (plan row 19) |
| `selection_panel_test` WS1-WS11 | I `panels/wall_section_test.dart` | 12 | IP-R1, IP-R2; WS9 → WS9-open |
| 2a's `selection_page_test` SE13, SE15, SE16; SE11, SE12 | I `panels/selection_page_test.dart` | 5 | Wall lines restored (D-20) |
| `color_picker_test` (fixture case, CP1-CP6b) | I `panels/colour_row_test.dart` | 7 | IP-R1, IP-R7 |
| `decimal_separator_test` | K `room/decimal_separator_test.dart` (Q0-S1, Q0-S2); I `panels/decimal_separator_test.dart` (Q0-E1-E3b) | 2 + 4 | IP-R3 |
| `l10n/` DT1, LK2, OV-H, PW1, PW2, NN3; VW3's room line; NS3 | I `l10n/*`; K `words/value_words_test.dart` | 9 | IP-R4, IP-R5 (+ LK2's exclusion), IP-R6 |
| `touch_tools_test` TD1 | I `canvas/touch_tools_test.dart` | 1 | IT-R5 |
| `planner_shell_test` (3), `planner_grips_test` (5), `planner_draw_test` A12b | I `shell/`, `canvas/`, `editor/architecture_palette_test.dart` | 9 | IT-R3, IT-R4, IT-R9 |
| `editor_panels_test` (5), `keyboard_focus_test` (4) | I `editor/editor_panels_test.dart`, `shortcuts/keyboard_focus_test.dart` | 9 | IT-R6, IT-R7, IT-R8 |
| `layers/tools_layer_test` (10), `opening_host_layer_test` (6), `attach_layer_test` (3); apps `layer_picker_test` wall case | K `layers/*` (18), I `layers/placer_layer_test.dart` (1), I `layers/layer_picker_wall_test.dart` (1) | 20 | IT-R10 |
| `intersection_snap_test` | K `intersection_snap_test.dart` | 1 | imports only |
| `delete_components_test` P-1-P-3 | I `controller/delete_components_test.dart` | 3 | IT-R2, IT-R11; P-1's matcher (above) |
| `dimension_paint_test`, `dimension_shell_test`, `room_paint_test`, `room_cost_test` LZ3 | I `dimension/*`, I `room/room_paint_test.dart`, K `room/room_cost_test.dart` | 3 + 3 + 6 + 1 | IT-R12, IT-R13, IT-R14, IT-R15 |
| 2b's TF1, TF3, TF7, EX2, EX3, EX5, CZ1 (their room lines, R-16) | I `service/room_fill_test.dart`, `export/room_export_test.dart`, `controller/zone_room_test.dart` | 3 + 4 + 1 | R-P18, IA-R6: the table halves stay 2b's |

## Mutations of Tasks 1-28

From the task reports; every mutation was applied to committed code, run
red and reverted (`git checkout -- <file>`, `git diff --quiet` exit 0), as
each report records. "eq." = the report ran the intended equivalent of a
plan text that did not compile.

| ID | Task | File | The change | Red test |
|---|---|---|---|---|
| M-SB-ortho | 1 | C `model/symbol_box.dart` | drop the a·c+b·d term | SB-ortho |
| M-SB-export | 1 | C `model/model.dart` | delete the export | `symbol_box_test` (compile) |
| M-SB-pure | 1 | C `symbol_box.dart` | import flutter/foundation | purity P1 |
| M-SB-arc | 1 | C `symbol_box.dart` | delete the k<4 loop | `boxOfLeaves` arc group |
| M-SB-clean | 1 | C `symbol_box.dart` | drop `clean()` | `placement_transform_test` P3, P23 |
| M-SB-owner | 1 | P `panels/symbol_section.dart` | add `_isOrthonormal` | SB-one-owner |
| M-PO-world | 2 | C `kit/properties.dart` | `world` wrong | PO-object |
| M-PO-null | 2 | `properties.dart` | a null read visible | PO-display; P PO-panel-display |
| M-PO-no-object | 2 | `properties.dart` | no `object` check | PO-display-no-object |
| M-PO-range | 2 | `properties.dart` | range ignored | PO-range, PO-fields; P PO-range, PO-G-range |
| M-PO-range-null | 2 | `properties.dart` | null range accepts | PO-range; P PO-range |
| M-PO-visible | 2 | `properties.dart` | `visible` ignored | PO-visible, PO-hidden, PO-G-visible |
| M-PO-fields | 2 | C `kit/plan_type.dart` | no object bound | PO-fields, PO-words |
| M-PO-section | 2 | `plan_type.dart` | section builder wrong | PO-section |
| M-PO-words | 2 | `plan_type.dart` | words dropped | PO-words |
| M-PO-object-words | 2 | `properties.dart` | object without the words | PO-object, PO-words, PO-section |
| M-PO-pure | 2 | `properties.dart` | a Flutter import | purity P9 |
| M-PO-validate | 2 | C `kit/plan_kit.dart` | no `settingsNeedObject` | PO-validate, PO-validate-cov |
| M-PO-cov (eq.) | 2 | `plan_kit.dart` | `LengthProperty<Object>` read | PO-validate-cov |
| M-PO-panel-words | 2 | P `panels/plan_property_panel.dart` | the plan's words | PO-panel-display |
| M-PO-panel-row | 2 | `plan_property_panel.dart` | no `TextDisplay` row | PO-panel-display, PO-G-display, PO-G-visible |
| M-PO-hidden | 2 | `plan_property_panel.dart` | hidden fields shown | PO-panel-display, PO-hidden |
| M-PO-gate-hidden | 2 | `plan_property_panel.dart` | refused action shown | PO-gate-hidden |
| M-PO-services | 2 | `plan_property_panel.dart` | services missing | P PO-section |
| M-PO-G-display, -G-visible, -G-range | 2 | `properties.dart` | lazy reads outside the guard | PO-G-display, PO-G-visible, PO-G-range |
| M-KW-missing, -first, -placeholders, -eq, -export, -pure | 3 | C `model/kit_text.dart`, `model.dart` | fill, placeholders, equality, export, purity | KW-fill, KW-placeholders, KW-text, compile, purity P1 |
| M-KW-first-pattern, -fold | 3 | C `model/numbered_names.dart` | first pattern, fold | KW-numbered; P W-NN4 |
| M-KW-args, -separator, -sep-object, -plan-words | 3 | C `kit/plan_services.dart`, `plan_words.dart` | args, separator late/fixed, getter moved | KW-words, KW-separator, PO-words-separator, compile |
| M-KW-validate, -validate-en, -host | 3 | C `plan_kit.dart`, `host_words.dart` | `text:` namespace, English | KW-validate, KW-host; P KW-plan-host |
| M-KW-conf-placeholders, -conf-complete | 3 | C `authoring/conformance.dart` | the placeholder and completeness checks | KW-conf-placeholders, KW-conf-complete |
| M-KW-plan-separator | 3 | P `controller/plan_controller.dart` | no separator passed | KW-plan-separator |
| M-TN-export | 4 | C `kit/plan_tool.dart` | rename `ToolNotice` | `tool_notice_test` (compile) |
| M-TN-forward, -guard-getter, -guard-value, -then-null | 4 | P `kits/guard.dart` | the guard's forwarding | TN-forward, TN-guard, TN-guard-value, TN-controller, TN-boundary |
| M-TN-active, -copy, -textOf-host, -textOf-locale | 4 | P `plan_controller.dart` | rebind, copy, host words, locale | TN-controller, TN-textOf, TN-boundary |
| M-TN-order, -relocale | 4 | P `editor/plan_editor.dart` | order, a cached text | TN-status, TN-relocale |
| M-TN-unbind-switch, -unbind-dispose, -unbind-swap | 4 | `plan_controller.dart` | a stale listener | TN-unbind, TN-unbind-dispose, TN-controller |
| M-PB-1 … M-PB-16 | 5 | P `plan_controller.dart` | prepare/build order, history, words, unrestricted, undo loop, locale | PB1-PB11 |
| M-ND-1, -2, -3 | 5 | P `controller/new_plan.dart` | units, page origin, history | ND1, ND3, C1 |
| M-LS-1 | 6 | P `controller/services.dart` | no frozen check | LS-frozen |
| M-LS-fake-1a … -6, X-reentry, X-after-dispose | 6 | C `testing/fake_plan_services.dart` | index, camera, snap, locale, separator, settings, shared, frozen, catalog | LS-fake-1 … LS-fake-6 |
| M-GR-1a, -1b | 7 | P `kits/guard.dart` | drag/preview `on ArgumentError` deleted | GR-1, GR-drag-refuse |
| M-GR-2a, -2b, -2c | 7 | `plan_controller.dart`, `guard.dart` | the drop's refusal | GR-drop-refuse; L-11 |
| M-L11a, -b, -d | 7 | `plan_controller.dart` | `_refusal` cases | L-11 |
| M-FL-1 … -6, -5b | 7 | `guard.dart`, `plan_controller.dart`, `service/service_session.dart` | the frozen references' lock | FL-edit, FL-delete, FL-throw, FL-service |
| M-F-T7a (+ onKey, onPointerMove variants), -T7b | 7 | `guard.dart` | refusal beyond the drop / not at it | F-T7, GR-drop-refuse |
| M-GR-3 | 7 | `plan_controller.dart` | KitHookFailure without the report | GR-drop-hook |
| M-PN-1, -2 | 8 | P `shortcuts/plan_shortcuts.dart` | dispose gives keys back; `_leave` reopens | PN-remount |
| M-PN-kind (eq.), -dispose, -ortho, -nested, -node, -live, -open, -SE8 | 8 | P registry, move resolver, `_open`, unit copy | the parked pins | PN-kind, PN-dispose, MV-2, PN-MV-*, PN-open, SE8 |
| M-SC-1, -2, -ver, -ids, -3, -4, -5, -live-1..3, -10, -7, -perm, -8, -9, -deps | 9 | K `kit.dart`, `separator_linetype.dart`, words, `live.dart`, `example/main.dart`; I lib; `ci.yml` | the scaffold | SC-ids, SC-example, SC-prepare, SC-words, SC-text, SC-conformance, SC-live, SC-smoke, SC20c, SC16, `check_kit_deps` |
| M-BX-1 … M-BX-6 (M-BX-4 eq.) | 10 | K `box/*`, `kit.dart` | bounds, gate, letter, clipping, registration, id | BX-props, BX-kit, BT1, BT3, BX1, BX2 (M-BX-4 green on BX4, ruled) |
| M-WL-1 … M-WL-7 | 11 | K `wall/wall_bands.dart`, `wall_geometry.dart`, `wall.dart` | liveness, sharing, `Disposable`, id | WL1-WL3, WP1 |
| M-WT-1 … M-WT-12, M-WG-1, -2 | 12 | K `wall/wall_plan.dart`, `wall_grips.dart`, `wall_tool.dart`, `kit.dart` | thickness, gate, settings, bands, live, grips, letter, joins, refusal | WT-type, WT-settings, WT-bands, WT-frozen, WT-kit, WT3-k, WT9-k, EG1-k, WG-refuse-short; I WT1, WT2, WT7 |
| M-WB-live | 12 | K `wall_bands.dart` | the read-time liveness check | WL4, WT-frozen-hover |
| M-OG-1 … M-OG-8 | 13 | K `opening/opening.dart`, `opening_geometry.dart`, `wall/wall_geometry.dart`, `wall/wall.dart` | id, the adapters' liveness, the cut, ties, empty pieces | OP1, OG-live, HF9, `opening_cut_test` (all six), HF6, KJ1 |
| M-OT-1 … M-OT-19 (M-OT-14 eq., in P `kits/guard.dart`) | 14 | K `opening/opening_plan.dart`, `opening_grips.dart`, `wall_grips.dart`, `kit.dart` | title, width, range, flips, gate, aperture, references, keptPut | OT-title … OT-range-live, OS1, OT-panel-range, OT-frozen-host, EP1-EP9, SG3 |
| M-OL-1 … M-OL-9, -9b, M-OS3 | 15 | K `opening/opening_plan.dart`, `opening_tool.dart`, `wall_bands.dart`, `kit.dart`; P panel | letters, widths, live frames, the memo-hit refresh, the panel's order | OL-tools, OL-settings, OL-frozen, OL-frozen (memo), OT1, OT2, OS3 |
| M-RR-1 … M-RR-17 (M-RR-15b) | 16 | K `room/room_inputs.dart`, `live.dart`, `separator/separator.dart`, `room_label.dart` | liveness, sharing, every reader's freeze check | RR-live, RR-shared, RR-freeze, SR1, SR2, LZ1 |
| M-SP-1 … M-SP-10, -8b | 17 | K `separator/separator_plan.dart`, `separator_tool.dart`, `kit.dart`; P `plan_controller.dart` | exported, snap, letter, order, invalidate, prepare, load/open path, omit | SP-type, SP-grips, SP-order, ST2, ND1-ND3, SP-dashed-open, SP-export-png/-pdf |
| M-RM-1 … M-RM-13 | 18 | K `room/room_plan.dart`, `room.dart`, `kit.dart` | trim, empty name, '—', memo, area line, colour, aperture, movable, id, registration, separator | RM-*, RC2, RC5, RP1, GR2, GR4, GR6, RN6, RN5-refused |
| M-RT-1 … M-RT-13 (M-RT-7, -10 in Task 20) | 19 | K `room/room_tool.dart`, `room_inputs.dart`, `room_plan.dart` | notice, words, patterns, live inputs, letter, order, cancel, freeze memos | RT-notice, RT-words, RT-tool, RT-frozen-wall, RT-frozen-room, TT4b; I TT1, TT7, RT-notice-locale |
| M-DG1 … M-DG7, M-RT-7, M-RT-10 (eq.) | 20 | K `dimension/dimension_attach.dart`, `dimension.dart`, `dimension_geometry.dart`, `room_plan.dart`, `room_tool.dart` | live walls/openings, id, separator, references, live rooms | DG-frozen, DG-id, AM7, Q0-DF1, DP1, TT10 |
| M-DM1 … M-DM11, M-P-choice-focus, -b | 21 | K `dimension/dimension_plan.dart`, `dimension_grips.dart`; P `plan_property_panel.dart` | gate, end words, memo, separator, face, snap, live, drag, flag, freeze memo; the focus hand-back | DM-*, GE2, DO1, DM-freeze, P-choice-focus; I PN1, PN2, PN4 |
| M-DT1 … M-DT8, -8b | 22 | K `dimension/dimension_tool.dart`, `dimension_plan.dart` | notice, id, live, letter, ortho, aligned, separator, the memo's freeze check | DT-notice, DT-plan-tool, DT-notice-separator, DT-freeze, TL1, TL2, TL5; I TL5, TL7, DT-notice-locale |
| M-FU1 … M-FU9 (M-FU8 eq.) | 23 | K `furniture/furniture_catalog.dart`, `furniture_source.dart`, words, pubspec | wall face, tags, unit, geometry, key, asset key, words, pubspec | against-wall set, FU-tags, FU-plain-tables, the committed bytes, SC-conformance, FU-keys, PA2/PA3/FU-asset-key |
| M-WF1 … M-WF14, -4b | 24 | K `attach/wall_face_provider.dart`, `wall_faces.dart`, `wall_attach.dart`, `kit.dart` | front/back, marker, keep, hysteresis, exclude, accept, stateId, live, attachments, symbols, the freeze read, `_state` | WF-query, WF-keep, WF-hysteresis, WF-exclude, WF-hidden(-toggle), WF-state, WF-frozen(-first), WF7; I WF-offered, FU-load |
| M-SF1 … M-SF5 | 25 | K `sample/sample_flat.dart`; I lib | separator, words, order, page, `build:` | SF-words, SP2, SP5, SF-controller, the page case |
| M-IT-1 … M-IT-9, M-P1a, -P1b | 26 | K `wall_plan.dart`, `kit.dart`, `room_tool.dart`, `opening_tool.dart`, `opening_plan.dart`; P `plan_shortcut_guard.dart`, `plan_controller.dart` | letters, a tool, the guard, layers, hosts, gates, prepare, seed; P-1's data | IT-letters, IT-ids, IT-guard, A12b, tools_layer, opening_host_layer, T5-f, R-3, SR3, TD1, P-1 |
| M-IP-1 … M-IP-7, M-WS9-r, WS9 (a), (b), DT1/LK2 probes | 27 | K `opening_plan.dart`, `wall_plan.dart`, `room_plan.dart`, `dimension_tool.dart`, `words/tr.dart`; P `kits/locks.dart`, `plan_property_panel.dart`, `plan_symbol_tool.dart` | title, flips, visible, thickness, colour, separator, Turkish word; the lock's covers hit, the panel's revert | IP-title, IP-door-actions, WS3, CP1, Q0-E2, VW3, WS9-open, DT1, LK2 |
| M-IA-alloc, M-IA-1, -2, -4, -5; the four re-resolve mutations of the fix round | 28 | P `plan_canvas.dart`, `plan_symbol_tool.dart`; K `wall_face_provider.dart`, `wall_faces.dart`, `room.dart` | a fresh resolver per build, kind, keep, accept, transparency; the camera listener, `gatesChanged`, `_onArmed`, the key handler's re-resolve | IA-alloc, wall_attach_tool, WE1, MV1, MV4, SS16, SS17, against_wall_rotate, TF1-room, EX2/EX3-room, TF7-tint, the zoom case, R-3, the re-arm case, M while attached |

Named mutations that stayed green, with their resolution:
- M-BX-4 (Task 10) on BX4: the old line's blind spot (corner-only overlap); clipping pinned by the kit's BT3 (ruling).
- M-IA-3 (Task 28) on SS16: the pumps deliver the change stream, so the stateId check never decides; pinned by the kit's `wall_face_provider_test` (M-WF8, M-WF14) (ruling).
- `_onArmed`'s `_attached = null` (Task 28 fix round): decides only on the hidden path, unreadable without a pointer event; recorded "Not ported (IA-R4)"; parked Minor.
- Task 7's extra probe, `_referencesOf`'s live-referent filter: defensive, unreachable (the engine refuses a dangling reference first); parked Minor.
- Task 4's single swap routes: redundant by design; their joint removal is M-TN-unbind-swap (red).

## Planning rulings and plan decisions

The controller's planning rulings (plan appendix):
- R-P1: the integration package imports public libraries only; a case needing kit internals runs in the kit, with test-local fixtures (`place_entry.dart`).
- R-P2: `furnitureSource` joins `architectureKit.symbols` with the provider (Task 24).
- R-P3: shared kit test support; `faceRunsOf`, `WallFaces` take a `LiveTypeOf`.
- R-P4: `PlanObject.words`; `fieldsOf`/`commitField` take the words last.
- R-P5: the dimension cases on the sample flat are Task 26's.
- R-P6: the kit test catalog; the kit lists `vector_math`; the integration package lists the engine, the Flutter layer, the contract and `vector_math`.
- R-P7: a pure `PlanWords`, which `KitWords` implements.
- R-P8: the wall/opening/room split across Tasks 11, 13, 14, 16.
- R-P9: `@internal` reads in integration tests under `invalid_use_of_internal_member`.
- R-P10: sample-flat cases (LZ3, `room_paint_test`) are Task 26's.
- R-P11: the kit lists `meta` and `vector_math`.
- R-P12: `FakePlanServices.settingsOf` reads its map live.
- R-P13: one kit test catalog (`test/support/catalog.dart`).
- R-P14: one integration rig (`test/support/editor_rig.dart`).
- R-P15: a refused drop commits nothing; C1.8(2) through one private `_refusal` shared by `execute` and plan.select's `GuardedTool`.
- R-P16: 2b's renames are C7 class 1; ND2 not ported.
- R-P17: R-P15 corrected (the preview at a refused point is empty); `wallsInDocument`'s positional `live`; `liveOf(doc, {frozen})`.
- R-P18: R-16's table halves stay 2b's; the integration package carries the room lines.
- R-P19: the opening's range decides "is the host a wall" over a kit-internal naming catalog (`type_naming.dart`).

The writers' rulings, in task order (each in its task): Task 5 (ND2, ND4);
Task 6 (D-40 not added); Task 7 (`_first` kept; `_refusal` shared); Task 8
(SE8 as 2b's unit); Task 9 (D-18 replaced); Task 10 (grid snap on);
R11-1; R12-1, R12-2, R12-3; R13-1 … R13-5; R14-1 … R14-10; R15-1 … R15-5;
R17-1, R17-2; Task 18 (GR4 from the tint); DM-R1, DM-R2, DM-R3; DT-R1 …
DT-R4; Task 23 (version 1); IT-R1 … IT-R15; IP-R1 … IP-R8; IA-R1 … IA-R6;
the reconcile's EG8-k/EG9-k/EG10-k, WR9 and TT10 lines. Each one line in
the plan's appendix table.

The controller's rulings while executing (ledger, in order), beyond the
dropped lines above:
- Task 9: each new package's `analysis_options.yaml` committed once (2a's precedent).
- Task 7: plan.select's refusal at the drop only (`onPointerUp`); `onKey` keeps 2a's rethrow.
- Task 10: M-BX-4 pinned by BT3 only.
- Task 12: the FREEZE RULE. A freeze emits no document change, so the kit's caches re-check liveness on read (allocation-free, indexed): `WallBands._stillLive` first, then every cache and memo of Tasks 15-24, each with a first-reader test step and a named mutation. Its cost accepted (WT12, below).
- Task 14: after a lock-refused edit, compare with `canon`, not encoded bytes (slot order is history, 06 D11); M-OT-14's file is `guard.dart`.
- Task 15: OS3 changed by the binding 2a spec; the tool's one bands re-check per pointer event accepted (~43 µs at 600 walls).
- Task 16: no contract liveness revision mid-plan (the follow-up proposal below); `RoomInputs` reuses `liveObjectsOf` (the plan's duplication overruled).
- Task 18: RN5 (premise impossible) split; no `skip` in the tree.
- Task 19: TT6's cost kept; the rig's teardown order parked.
- Task 21: PN2's focus defect fixed in the plan library (a choice row hands the focus back; 2a: "Focus rules are today's", design-mode spec :393); PN5 confirmed.
- Task 22: TL8's cost accepted (inside D12's 1,000 µs).
- Task 24: D-06's steady state pinned (M-WF14).
- Task 26: TL9 through `toolFor` (R-P9); never a second `SpatialIndex` over the editor's document (the mutation-hook slot); A12b re-pumps; P-1's matcher.
- Task 27: WS9 (premise impossible, then the document-level refusal on C and B); LK2's exclusion; `layerPanel` on `planEditorApp`/`pumpEditor`; `fxKit` gets `fxNames`.
- Task 28: `bands.generation` lines; M-IA-3 green accepted; the resting-ghost reads through the tool's own overlay; the lines marked "human" decided by the controller (delegated).

## Amendment lines

Checked by `grep` in this run:
- Umbrella (`docs/superpowers/specs/2026-10-13-kit-architecture-design.md`):
  no amendment line carried it (`grep -n "architecture_demo"` found only
  A13's text at `:356`); **this task appended it** to `## Amendments`
  (`:520-526`): "**2026-10-15, sub-project 3 split** (the human: *"3a kit,
  3b demo"*; ... decision 1): ... A13's "the demos" and A11's
  `apps/floor_planner` → `apps/architecture_demo` are 3b's for the
  architecture demo; `apps/restaurant_demo` stays sub-project 4's."
- Contract spec (`2026-10-13-kit-contract-design.md`, "Amendments from
  sub-project 3a", `:412`): the symbol box family and `placementTransform`
  (`:418`); `PlanObject`, `DocumentPlanObject`, `TextDisplay`, `range`,
  `visible`, `PlanSection`, `settingsNeedObject` (`:424`); K4's `text:`
  namespace and placeholders, `KitWords.text` (`:433`); `KitText`,
  `fillText`, `placeholdersOf`, `numberedNameIndex`, `PlanWords.text` and
  `decimalSeparator` inherited by `KitWords` (`:440`); `ToolNotice`
  (`:445`); `PlanKit.prepare` and `PlanBuild` (`:448`);
  `PlanServices.liveTypeIdOf` and `testing.dart` with `FakePlanServices`,
  D-40's not-added list (`:452`). Every name of the spec's list is there
  (Tasks 1-6).
- 2a spec (`2026-10-14-plan-library-design-mode-design.md`, `## Amendments`,
  `:827`): P3's property specs and section builder (`:833`); P2's status
  line and tool notices (`:844`); P4's new plan and `prepare` (`:852`); P2's
  `build` (`:858`); P4's grips row (`:864`); P4's lock set (`:869`)
  (Tasks 2, 4, 5, 7).
- 2b spec: `git diff main -- docs/superpowers/specs/2026-10-14-plan-library-service-mode-design.md`
  prints nothing; none expected, none written.

## The CHANGELOGs

Written by this task from the code (each name checked with `grep` over the
package's `lib`): `jet_cad_2d_kit` (one bullet appended under `## 0.1.0`:
the contract's 3a surface, `PlanWords` and the words on `PlanObject`,
`fieldsOf`, `commitField` included); `jet_cad_2d_plan` (ten "Sub-project 3a" bullets appended
under `## 0.8.0 (unreleased)`: a grip drop is refused by the rule `execute`
uses, not through `execute`; the choice row's focus hand-back; the
shortcuts' remount); `jet_cad_2d_kit_architecture` (the `## 0.1.0
(unreleased)` body: six types, eight tools, the furniture library with 41
symbols, six size families and 30 wall-attached ones, the provider, the
caches' read-time liveness checks, `buildSampleFlat`, the words). These
close the ledger's CHANGELOG items (Tasks 17, 21, 24).

## Spec gaps and interface problems found while executing

The plan's `#### Interface problem` sections were all resolved by rulings
before execution (R-P1 … R-P19 and the writers' rulings: Tasks 2, 7, 9,
12, 13, 14, 16, 17, 18, 20, 21, 22, 23, 24, 26, 28; Tasks 15 and 27 had
none open). Found while executing, with their resolution:
- Task 7: plan.select's refusal covered every event, not only the drop (review, Important) → narrowed to `onPointerUp` (ruling).
- Tasks 11-12: a freeze emits no document change, so a cache of live objects kept a frozen object → the FREEZE RULE (ruling); every later cache and memo carries it.
- Task 14: a lock-refused edit is not byte-identical afterwards (slot order) → compare `canon` (ruling).
- Task 15: OS3 against the binding 2a panel row → assertion changed by the binding spec (ruling).
- Task 16: the plan's `RoomInputs._live` duplicated `liveObjectsOf` → overruled (ruling).
- Tasks 18, 21, 27: a ported premise impossible under C1.10's freeze at open (RN5, PN5, WS9) → split, "Decided: premise impossible" (rulings).
- Task 21: a choice row kept the focus (a 2a defect against "Focus rules are today's") → fixed in the plan library (`fix(plan)`, 90417584).
- Task 26: the plan's tools are all guarded; a second `SpatialIndex` steals the document's mutation hook; P-1's vacuous matcher → rulings.
- Task 27: LK2's allowlist vacuous; `fxKit` without words; `reportLocale` `@internal` → rulings.
- Task 28: the IA-R4 click reads re-resolved on pointer events (review, Important) → the resting ghost read through the tool's own overlay (ruling).

## For the human

Open items; none blocks the merge. Wording from the ledger.

1. **A spec question (C1.5, C1.10).** "In a WELL-FORMED plan a frozen wall's
   spatial neighbour silently un-joins its corner when an edit's closure
   reaches it, and the edit lands (C1.5 accepts frozen walls absent from
   generate; C1.10 locks references only). Closing it needs a spec
   decision ("a frozen wall locks its spatial neighbours"), not a code
   fix." (ledger, Task 27).
2. **A follow-up proposal: a liveness revision on `PlanServices`** (e.g. a
   revision that moves when the frozen set grows), so the kit's freeze
   re-checks become O(1) instead of O(n) per read. Every kit cache takes a
   bare `LiveTypeOf` today (shared interfaces of Tasks 9-16), so the change
   was not made mid-plan (ledger, Task 16). Measured costs (reports): WT12
   band scan at 600 walls 35.86 µs with the check vs 1.88 µs without
   (Task 12); TT6 Room-tool hover about 137-147 µs vs today's 12-19 µs
   (Task 19); the opening tool about 43 µs per hover at 600 walls (Task 15,
   OT4 43.68 µs with the per-event flag); TL8 dimension tool band path
   about 104-116 µs vs 44 µs without the check (today's 38 µs), inside
   D12's 1,000 µs (Task 22). All allocation-free and well inside a frame.
3. **A possible 2a defect** (Task 28): plan.select's drag object-snaps to
   the dragged unit's own old edge midpoint (a mid-edge press of a unit
   released 30 mm from its own old right-edge midpoint snaps there; the
   ported MV cases press elsewhere, Task 28's deviation 6). Surfaced for
   the final review.
4. **A one-frame notice re-word lag on a locale switch** (Task 4, accepted):
   it comes from `PlanLocaleScope` reporting the locale after the frame
   (pre-existing); the kit tool's label lags identically, so the line
   never mixes languages.

Parked Minor findings: 28 `Ruling:` lines of the ledger (Tasks 1-28 and the
rig's teardown order), not fixed here; they are the final review's fix
wave. Of them, the CHANGELOG items (Tasks 17, 21, 24) are written by this
task. One more for that wave, found here: the ported dimension files and
`wall_faces_test` carry no 3a port line (Appendix A section above).

## Final fix wave

The final whole-branch review (`7e65905b..945502cb`) found no Critical or
Important issue. This wave closed its actionable Minors and a curated set of
the parked ones (`fix-wave-brief.md`, `fix-wave-report.md` in
`.superpowers/sdd/2026-10-15-architecture-kit/`). Every new pin was proven
with a named mutation that was run on the committed code, went red and was
reverted. No ported assertion was weakened or dropped. The figures above
are unchanged.

Items closed:
- **A1** (review M3): `RoomInputs` gains a `beginEvent`/`endEvent` bracket.
  The Room and Separator tools wrap each pointer event in it, so one hover
  runs one liveness pass. `debugLivenessPasses` pins this (RT-one-pass,
  ST-one-pass).
- **A2** (review M4): `newPlan` and `load` now drop the replaced plan's
  prepare and build `hookFailed` entries (`DiagnosticsLog.removeWhere`).
  PB12 pins it.
- **A3**: the room area memo's `stateId` limit after an E3 rebuild is
  documented.
- **B1-B9**: doc and comment accuracy.
- **C1-C7, C9, C10**: the vacuous or unpinned tests named in the brief.
- **D1**: the rig unmounts the editor before the controller is disposed.
- **D2**: line-level internal-member ignores. Before the wave there were 19
  file-level ignores. After it there are 2, in the grip tests, with 7 and
  14 reads.
- **D3**: one copy each of `clickAt`, `dragWorld`, `undoKey`, `select` and
  `addSeparator`. `frameOn` and `pumpEditor` now share `centreCamera`.

Skipped: **C8**. Every word id is namespaced under its own kit, and
`validateKitSet` refuses a foreign one: a scratch kit carrying
`tool:test.slab` made the controller throw `KitSetError` with the message
`foreignWordId: prep: en: "tool:test.slab" is not under the kit "prep"`.
So two loaded kits' words never conflict, and `kits.reversed` in
`_buildWords` is an equivalent mutant.

Gates (this run, at `bc8abbc6`, last lines):

| Package | test | analyze | format |
|---|---|---|---|
| `jet_cad_2d_kit` | `00:06 +403: All tests passed!` | `No issues found! (ran in 3.0s)` | `Formatted 92 files (0 changed)`, exit 0 |
| `jet_cad_2d_plan` (`--enable-vmservice`) | `01:55 +1551: All tests passed!` | `No issues found! (ran in 3.5s)` | `Formatted 299 files (0 changed)`, exit 0 |
| `jet_cad_2d_kit_architecture` | `00:19 +655: All tests passed!` | `No issues found! (ran in 3.1s)` | `Formatted 136 files (0 changed)`, exit 0 |
| `jet_cad_2d_integration` (`--enable-vmservice`) | `00:55 +227: All tests passed!` | `No issues found! (ran in 3.1s)` | `Formatted 79 files (0 changed)`, exit 0 |

- The plan's invariants, `flutter test --enable-vmservice test/invariants`:
  `00:09 +15: All tests passed!`
- IA-alloc, `flutter test --enable-vmservice test/invariants/paint_allocation_test.dart`:
  `00:00 +1: All tests passed!`
- `dart run tool/ci/check_kit_deps.dart`: `kit dependencies: 2 package(s)
  checked, none names the plan library or another kit`, exit 0.
- The three `dart pub publish --dry-run` runs each exit 0 with `Package has
  0 warnings.`:
  - kit: `Total compressed archive size: 121 KB.`
  - plan: `940 KB`
  - architecture kit: `539 KB`
- `git log --name-only --format= 945502cb..HEAD | grep -c analysis_options`
  prints `0`.

Commits (on `945502cb`, oldest first):
- `ddc44e76` fix(architecture): one RoomInputs liveness pass per Room and
  Separator tool event
- `017480eb` fix(plan): a failed build or prepare is reported again on a
  later plan
- `53743d55` docs: comment and doc accuracy (3a final wave A3, B1-B9)
- `a1114f4c` test(integration): TT7 reads the Room tool's own notice;
  OT-frozen-host's delete half resets the hint
- `946b4cac` test(kit): DT-freeze split into four tests, one per freeze step
- `81f9e247` test(kit): DG-frozen probes the candidate set before any wall
  is laid out
- `c39b9d57` test(integration): P-choice-focus gains an Esc step and a
  tool-settings choice row
- `2424d954` test(kit): WR9's empty sample diagnostics paired with its ten
  live walls
- `d80ff0fa` test(kit): contract words: a foreign kit's text is not held to
  the locales; fillText fills once
- `8c8599eb` test(kit): FakePlanServices.dispose releases the camera and the
  symbols state
- `5d27b59b` test(plan): the notice guard catches a throwing addListener and
  removeListener
- `55aa1bb3` test(integration): the rig unmounts the editor before the
  controller is disposed
- `2bb541ee` test(integration): line-level internal-member ignores where a
  file has few reads
- `bc8abbc6` test(integration): one copy each of the rig's click, drag, undo
  and select helpers

This section's commit sits on top of them.
