# Task 17 report: the exit gate

Status: DONE_WITH_CONCERNS (every gate green; one unplaced oracle file found, see Concerns).

Commit: `e7b7ceb6 docs: the plan library in service mode, results of record` (on 2ca9c84f).
Files: `docs/superpowers/notes/2026-10-14-plan-library-2b-results.md` (new),
`STATUS.md` (In flight's 2b paragraph, Resume here's first paragraph, Last updated 2026-10-15).
No code change. Nothing pushed, tagged, merged or published; the ledger is not archived.

## Gates (this run, on 2ca9c84f; quoted in full in the note)

- Step 1: `git status --short` empty; `git log --name-only --format= main..HEAD | grep analysis_options` printed nothing (exit 1); 42 commits over main; HEAD 2ca9c84fd9a0c7092f71005107a5469e9053c765; main = origin/main = 651e3d09 (also by `git ls-remote origin main`); `merge-base --is-ancestor` exit 0.
- Kit: `00:05 +340: All tests passed!`; `No issues found! (ran in 3.2s)`; `Formatted 74 files (0 changed)`.
- Plan, `flutter test --enable-vmservice`: `01:54 +1498: All tests passed!` (no skip; BT1's `skip:` gone); `No issues found! (ran in 4.0s)`; `Formatted 284 files (0 changed)`. canvas_paint_allocation `+3`, pick_allocation `+5`, band_allocation `+2`, all passed.
- tool/ci: `00:41 +117: All tests passed!`; analyze --fatal-infos `No issues found!`; check_kit_deps `kit dependencies: 1 package(s) checked, none names the plan library or another kit`; check_guide `all 56 code blocks`; check_readmes `all 6 code blocks`; check_screenshots `screenshots: every rule holds` (exit 0 each).
- Engine: `00:06 +1337 -2: Some tests failed.`, the two failures exactly standing_failures.txt's two jet_cad_2d lines; analyze and analyze --fatal-infos `No issues found!`; format 0 changed; query_allocation `+6`; test/parametric `+184`; generate_document_test `+16 -2` (the same two).
- Renderer: `00:20 +1450 ~1 -5: Some tests failed.`, the five text_ladder rungs 1-5 (standing lines); the two standing text_lod_ladder lines passed here (as Task 1's and Task 2's reports recorded before and after E5; the package is untouched). No other failure. paint_allocation `+3`; analyze clean; format 0 changed.
- GPU: `+20: All tests passed!`, analyze clean, format 0 changed.
- floor_plan (`--enable-vmservice`): `01:49 +2012: All tests passed!`; restaurant_symbols `+97`, floor_planner `+212`, restaurant_demo `+69`, tool/screenshots `+14`, all passed.
- Dry runs: jet_cad_2d, jet_cad_2d_flutter, jet_cad_2d_kit, jet_cad_2d_plan, jet_cad_floor_plan: each exit 0, `Package has 0 warnings.`; the plan library's list holds the seven files Step 5 names; the five `cmp LICENSE` printed nothing.
- Hand checks: old packages diff empty; engine commits only 1012413b, 4ef4a8d4 (Task 1 and its fix), bcf4d6b8 (Task 2); import, A1, purity and dart:io greps empty (188 unfiltered comment citations); versions 0.7.2 / 0.7.2 / 0.1.0 / 0.8.0; pubspec diff exactly `+  vm_service: ^15.2.0`; engine CHANGELOG has one `## Unreleased` with E5's two bullets; kit (+9) and plan (+29) CHANGELOGs changed; rooms spec line 1078 and 2a spec line 668 present; sample kit regenerates (`sample kit: 4 symbols written`, `git diff --quiet` exit 0); tree clean after everything.

## The note's tables

- Spec coverage: every row has ids found by this run's grep of test-name first tokens over the four test trees (1847 distinct tokens extracted); no row `missing`. Renamed/added ids used: E5-move, PB-def-top-poly, DS-layer, SM-copy-damage, SM-copy-unreadable, SM-tool-reset, SR-state-kept, SR-edited-after-load, UL-turn-row, CP13/CP14, CV-alloc-colour/-service, RB16-hall, PA4/PA5, UW-runtime-unit, UW-order. S5 rows mapped one by one (my mapping from test names; the reports give none).
- Ported tests: from the reports, counts as they give them ("not counted in the report" otherwise); port comments checked by grep (`jet_cad_floor_plan('s)?[ /]test/...`), every listed destination carries one.
- Mutations: every task's recorded ids with file, edit and red test; "brief" where a report gives the id and red test but not the file or edit (Tasks 1-4, 7, 8 partly). Survivors listed with resolution (M-PB9c unreachable, M-14l equivalent then re-worded, M-SV-R2 → F-3, M-SR24 → SR-edited-after-load, M-PA-hall → Transform2 watch, M-UL-number → bare-plan assertion).
- Execution rulings that changed a premise or ported assertion: listed one per line with reason; also the spec amendment dc2a5d70, the 21-test 2a-deferral gap (ported in 10, 11, 13, 14, 15, 16b; DS4's last two lines ruled impossible; F-1 unported for the human), and the S5 differences as built with their tests.

## Concerns

1. **Finding: `jet_cad_floor_plan/test/host/view_palette_test.dart` has no 2b destination and no ruling.** It holds service-mode tests (`M-DT-11 (${viewMode.name} mode)` two views, three `ServiceView` palette tests incl. `M-DT-10, ServiceView: no page …`). No 2a/2b plan, report, ledger line, 2a note or port comment names it. Recorded as open in the note (Ported tests and Spec gaps); for the coordinator to rule (port into 16b's area or retire with a reason).
2. The renderer's two standing text_lod_ladder lines pass on this machine; the run is a subset of standing_failures.txt, not an exact match. Same as Tasks 1 and 2 recorded; the package is untouched.
3. STATUS's In-flight 2a paragraph still says "One host-API difference awaits the human's word (A14)"; Step 10 changes only the "Next: 2b" sentence there, so I left it. Resume here now says decision 9 settled A14. The coordinator may want that In-flight sentence updated too.
4. The engine CHANGELOG's Unreleased section has a blank line between the earlier bullets and E5's two (cosmetic; not touched, no code change in this task).
5. `selectTool` true with no view and `unitsOnly` not hiding the panels have no 2b test (the first was 2a's ruling to retire RV6's second half); noted as such in the differences list.
