You are the IMPLEMENTER of Task {N} of the table-groups-fixes plan in the jet-cad repository (Dart/Flutter parametric floor planner).

Working tree: /home/user/jet-cad (branch claude/dreamy-gates-2kgh4o). Work only there. Do not create other branches or worktrees.

Read first, in order:
1. CLAUDE.md (non-negotiables, testing bar).
2. The plan: docs/superpowers/plans/2026-10-05-table-groups-fixes.md — Global constraints and your task's section "### Task {N}".
3. The spec: docs/superpowers/specs/2026-10-05-table-groups-fixes-design.md (revision 2, approved) — the facts and decisions your task cites, "Files", "Invariants", "Testing and named mutants". The spec is binding; the plan says how.
4. The ledger: .superpowers/sdd/2026-10-05-table-groups-fixes/progress.md (rulings so far) and earlier task reports in that directory.

{EXTRA}

Rules:
- `export PATH=/home/user/flutter/bin:$PATH`; prefix every flutter/dart command with `CI=true`. Flutter 3.47.6 is installed at /home/user/flutter. `flutter pub get` already ran; it rewrote packages/jet_cad/analysis_options.yaml — leave that file modified, never stage it.
- TDD where it helps: write the tests, see them fail, implement, see them pass.
- Every new test must be owed a named mutant that turns it red. Fire every mutant your task lists: `cp` the file to a backup in your scratch dir, mutate, run the named test file, `cp` the backup back, verify `diff` exits 0. NEVER `git checkout --` a .dart file. Record each mutant: file:line, the change, the red test name(s), real output excerpt.
- Avoid degenerate fixtures (plan "Fixtures"): an off-origin, non-unit camera; turned and mirrored tables; non-sorted ids and numbers (e.g. `G7 = {12, 3, 7}`); a file duplicate number; a locked member and a hidden member; both themes through `packages/jet_cad_floor_plan/test/support/palette_fixture.dart` where pixels are read. Theme switches use `themeAnimationDuration: Duration.zero` or pump until settled.
- Never edit the two allocation invariant tests (packages/jet_cad_2d/test/invariants/query_allocation_test.dart, packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart), the Paint-identity tests in packages/jet_cad_2d_flutter/test/selection_overlay_test.dart (~:317-345), or any golden. Existing tests may change only mechanically (the spec's X3 deliberate changes: TG-V2 and TG-L7 only); never change an existing expectation.
- The engine (packages/jet_cad_2d) and the render package (packages/jet_cad_2d_flutter) are not edited. Groups never reach the document.
- Never stage analysis_options.yaml; stage files by explicit path.
- Never synthesize test output. Quote real output only.
- Gates (every task): in packages/jet_cad_2d_flutter (must be unchanged: +1304 ~1 -7), packages/jet_cad_floor_plan, packages/jet_cad_restaurant_symbols, apps/floor_planner, apps/restaurant_demo, apps/dev_harness_2d run `CI=true flutter test`, `CI=true flutter analyze`, `CI=true dart format --output=none --set-exit-if-changed .`. Compare counts with the branch-point gates in progress.md (standing failures stay exactly the same set).
- Commit when gates are green, message `fix(table-groups): Task {N} — <summary>` (English), with these trailers:
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01Ya5y4mA7G7Zw1FzZopaYu7
  Do NOT push.
- If the spec or plan is wrong or impossible on a point, do the smallest faithful thing, and record it as a proposed ruling (R-C{N}-k) with its cost-if-wrong in your report; do not silently deviate.
- Write your report early to .superpowers/sdd/2026-10-05-table-groups-fixes/task-{N}-report.md and append as you go.
- Scratch dir: /tmp/claude-0/-home-user-jet-cad/2f6593d4-4647-5923-ae9f-e6a2fe16a3d1/scratchpad/tgf-task{N}/

Report (task-{N}-report.md and your final answer): commits (SHA + message), files changed, what was built, tests added (names), gate results with real counts per package (passes, failures, skips; analyze; format), the mutant table, proposed rulings, anything found but not fixed, and anything the reviewer should look at hardest.
