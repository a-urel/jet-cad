# Task 7 report

Status: DONE. Commit 3ca02d83b1ccecdffebfd340fe09c388a5c97d55 (one commit, amended twice before handback to fix self-references in the note; not pushed).

## What changed
- CHANGELOG.md: preamble + Unreleased replaced by the index text; `## 0.7.0` down is byte-identical (one hunk in `git diff`).
- STATUS.md: rulings "The engine's own version" (Decision 4, D10, D1 lower bound) and "The host packages go to pub.dev too" (points at spec and plan, steps 2-3 prepared on the branch; restaurant-symbols and licence bullets kept); In flight (new bullet); Resume here (the human's checklist per package, D7, D11); Commands (dry runs for the three); "Where the project stands" first bullet (git sentence, probe description now overrides).
- docs/superpowers/notes/2026-10-13-publish-host-packages-results.md: new, in the engine note's shape.
- packages/jet_cad_2d/README.md: "Where it comes from" rewritten (R-5); no version bump, no CHANGELOG change.

## Gates (macOS, Flutter 3.47.6)
- jet_cad_2d: dart test +1289 -2; expect_failures "1291 tests; the standing failures and skips, exactly"; analyze clean; format 177/0.
- jet_cad_2d_flutter: +1447 ~1 -5; expect_failures exit 1 with exactly text lod ladder rungs 1-2 "passed or did not run" and the five text-ladder goldens failing (R-1); analyze clean; format 234/0.
- jet_cad_floor_plan (--enable-vmservice): +2011; expect_failures "2011 tests; the standing failures and skips, exactly"; analyze clean; format 298/0.
- gpu +20, restaurant_symbols +97, floor_planner +212, restaurant_demo +69; all analyze/format clean; dev_harness_2d analyze clean.
- tool/ci: dart test +77; analyze (CI file list) clean; format 13/0; check_guide "all 56 code blocks are in the host probe".
- git status: no analysis_options.yaml modified.

## Dry runs (committed state)
- jet_cad_2d: exit 0, 229 KB, 0 warnings (after README rewrite).
- jet_cad_2d_flutter: exit 0, 226 KB, 0 warnings.
- jet_cad_floor_plan: exit 0, 462 KB, 0 warnings.
(Three packages; the engine run is the "fourth" of the brief's wording.)

## Barrel audit
Method: python script in scratchpad (audit.py): public libraries' `export` lines (show-aware, package: exports ignored), type names declared in lib/ but not exported, matched as whole words on lines of exported files at indent <= 4, then each hit read by hand. Result: engine 0, render 0, planner 14 raw hits, 2 real: `SymbolLibraryLoader.state` -> `SymbolLibraryState` (and Loading/Ready/Failed) unexported; `FloorPlanStrings.tableNumberProblem(TableNumberProblem)` unexported enum. `ExportChoice` is @internal. Labelled rough in the note.

## Deviations
- Brief said "four dry runs": there are three packages; the engine's was re-run for R-5, so three runs total.
- Note's mutant/pana/probe numbers quoted from the reports; Task 4's archive sizes "not recorded".
- STATUS: the old "Open for the brainstorm" and "Order" bullets of the second ruling were folded into the new text (they are resolved by the spec).

## Self-review
Numbers checked against reports; the engine's `dart doc` claim corrected (11 -> 0 in its own record). No reviewer dispatched; no push/tag/merge/publish.

## Fix round 1
Docs only. (1) Results note D4: both "real" bullets now say the types are exported only by editor.dart (internal, outside semver), not by the host-facing barrels; consequence added, checked against code: strings.dart:50 declares tableNumberProblem abstract, so a class that implements or directly extends FloorPlanStrings must write it; a subclass of a built-in language inherits it. (2) STATUS: stale "The guide names 0fa649e in §1." removed. (3) Note header: ledger "archived on the branch as its last commit". (4) STATUS Resume: branch CI (Linux) must be green; merge waits for the human's word. Guide untouched. `git diff --check` clean.
