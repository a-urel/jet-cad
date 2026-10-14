## Global Constraints

- **Names.** Dart type names carry no `2d`. The service mode's names are the spec's S3-S5 names exactly (`PlanMode`, `ServiceSession`, `UnitIndex`, `PlanUnit`, `PlanServiceView`, …); a table in "Shared interfaces" below is binding.
- **Versions.** No package version changes. `jet_cad_2d_plan` stays `0.8.0` (unreleased) and `jet_cad_2d_kit` `0.1.0`. The engine's `CHANGELOG.md` gains E5 under its existing `## Unreleased` section, as a feature, with the refused group add noted (spec S1 "Version"). `jet_cad_2d_kit`'s and `jet_cad_2d_plan`'s CHANGELOGs gain their 2b additions in their unreleased sections. No dependency constraint changes, except one dev dependency: `jet_cad_2d_plan` gains `vm_service: ^15.2.0` in `dev_dependencies` in Task 14, for the ported VM allocation meter (ruling R-23; the engine and `jet_cad_floor_plan` carry the same).
- **Dependencies.** `jet_cad_2d_kit` never depends on `jet_cad_2d_plan` or a kit (`tool/ci/check_kit_deps.dart`). `jet_cad_2d_plan` never depends on `jet_cad_floor_plan` or `jet_cad_restaurant_symbols`.
- **The old packages are untouched** (A12). No change under `packages/jet_cad_floor_plan`, `packages/jet_cad_restaurant_symbols`, `packages/jet_cad_2d_gpu`, `packages/jet_cad_2d_flutter` or `apps/`.
  - `packages/jet_cad_2d` changes only in Tasks 1 and 2 (E5).
  - Logic and tests from `jet_cad_floor_plan` are **ported by copying and adapting**, never imported.
- **Ported tests keep their assertions** (A12). Fixtures, names and imports may change. A ported test whose assertion must change is a finding: stop and report it; a test is retired only when its premise is impossible, by a ruling in the ledger (2a's practice).
- **Today's code is the oracle** for every "today" in the spec (A12). Where `docs/host-guide.md` and the code disagree, the code wins (spec Facts, the locked table).
- **Non-negotiables (CLAUDE.md):**
  - the frame path allocates nothing per entity in steady state (Task 15 extends `canvas_paint_allocation_test`; Task 14 ports `pick_allocation_test` and `band_allocation_test`);
  - draw order is ascending handle value;
  - geometric decisions use `Tolerance`; stored-value comparisons are exact `==` (transforms: `Transform2.equals(…, const Tolerance(linear: 0, angular: 0))`).
- **`analysis_options.yaml`.** Never stage one. No new package is created in 2b.
- **Stage files by explicit path only.** Never `git add -A` or `git add .`. Run `git status --short` after every pub operation.
- **Never synthesize test output.** Quote what commands print; reviewers re-run every claim.
- **Mutations.**
  - Run them on committed files only, and revert each with `git checkout -- <file>`; then `git diff --quiet -- <file>` must exit 0.
  - **In every task, run the Commit step before the Mutation step.**
  - Never restore from a `/tmp` copy, and never `git checkout --` a file with uncommitted work.
- **Language and commits.** Code, comments and commit messages are in English. Every commit message ends with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Never run `dart pub publish` without `--dry-run`, and never push, tag or merge.** The human does all of these.
- **Every task ends green.** Run the gates of every package the task touched:
  - `cd packages/<pkg> && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` (for `jet_cad_2d`: `dart test && dart analyze && dart format --output=none --set-exit-if-changed .`);
  - plus `cd tool/ci && dart test` when `tool/ci` or `.github/` changed, and `dart run tool/ci/check_kit_deps.dart` when a pubspec or `jet_cad_2d_kit` changed.

  The packages' language version is 3.6, so `dart format` uses the short style: run `dart format .` before the gate. **Run the format gate locally, every time.**
- **Known environmental failures.** The engine's local hash tests and the renderer's goldens fail on clean `main` on this machine as well. Compare against `tool/ci/standing_failures.txt`; never "fix" them.
- **Testing bar (CLAUDE.md).**
  - Every behaviour or refusal test names the mutation that turns it red. Positive controls and fixture-sanity tests are exempt.
  - Each task has a Mutation step: apply each named mutation, run the named test, see it red, revert.
  - Fixtures are not degenerate (spec Tests): the table turned and mirrored, two rows with different prefixes off the origin, one turned, one curved. A test standing at the identity alone does not count.
- **Session limit.** Worktree-guarded sessions refuse bash loops and `$VAR` pipelines: run commands one by one.

## Review Focus

1. **A row shrunk from 12 seats to 10 while its seats carry host data, a status and a group in service.**
   - Expected: seats 1-10 keep their handles, data, colour, status and group membership; seats 11-12 vanish; the group keeps their labels as members naming no unit (today's `setTableGroups` rule); undo brings 11-12 back with their data.
   - Pinned in Task 1 (E5-shrink), Task 9 (UA-shrink-data) and Task 12 (SS-shrink-group).
2. **A service record saved, the design edited (one table renumbered), the record restored.**
   - Expected: moves of unchanged tables apply; the renumbered table's move drops; a group naming its old label drops whole and is reported; the history of the copy is cleared.
   - Pinned in Task 13 (SR-design-edited).
3. **Two rows placed one after the other with the row tool.**
   - Expected: distinct prefixes, no `unit.duplicate_label`, every seat served.
   - Pinned in Task 5 (TK-two-rows).
4. **A plan with rows whose kit is missing.**
   - Expected: the seats are units, served and locked: tapped and reported, grouped and painted, never selected or dragged; a record's move of a locked unit drops.
   - Pinned in Task 6 (UI-missing-kit) and Task 14 (ST-locked-seat).
5. **Hover and band across a dense hall (500 seats in 25 rows).**
   - Expected: no per-unit allocation while hovering or banding; picking stays O(units) per event with a cached index.
   - Pinned in Task 14 (the ported `pick_allocation_test` and `band_allocation_test`, extended with generated units).

---

