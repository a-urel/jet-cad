You are the IMPLEMENTER of Task 1 of plan 09c-1 in the jet-cad repository (Dart/Flutter parametric floor planner).

Working tree: /home/user/jet-cad/.worktrees/plan-09c1 (branch plan-09c/wall-attach). Work ONLY there. Do not touch the main checkout at /home/user/jet-cad.

Read first, in order:
1. CLAUDE.md (non-negotiables, testing bar).
2. The plan: docs/superpowers/plans/2026-10-02-wall-attach.md — its Rulings (P-1..P-8), Global constraints, Gates, and your task's section "### Task 1".
3. The spec: docs/superpowers/specs/2026-10-02-wall-aware-symbols-design.md — the decisions your task cites, and the Testing / Named mutants sections. The spec is binding; the plan says how.
4. The ledger: .superpowers/sdd/plan-09c1/progress.md (rulings so far) and earlier task reports in .superpowers/sdd/plan-09c1/.

Task 1 specifics: this is the engine package (packages/jet_cad_2d, pure Dart: `CI=true dart test`, `dart analyze`). The component registry is packages/jet_cad_2d/lib/src/document/component.dart; RemoveDefinitionCommand is in packages/jet_cad_2d/lib/src/document/commands.dart (~:454-492); the dispatcher checks capabilities before apply in undo.dart (:187-193, :287-291). SC12 is in apps/floor_planner/test/symbols/symbol_component_test.dart (~:257-274). The placer's undo tests (P5, P9, P10, P17, P18) are in apps/floor_planner/test/symbols/symbol_placer_test.dart and must pass unchanged. Run the engine, app gates and `cd apps/dev_harness_2d && CI=true flutter analyze`; the render package is unchanged by this task but run it once since the engine changed (state the counts).

Rules:
- `export PATH=/root/flutter/bin:$PATH`; prefix every test/analyze/format command with `CI=true`.
- TDD where it helps: write the tests, see them fail, implement, see them pass.
- Every new test must be owed a named mutant that turns it red. Fire every mutant your task lists: `cp` the file to a backup in your scratch dir, mutate, run the named test file, `cp` the backup back, verify `diff` exits 0. NEVER `git checkout --` a .dart file. Record each mutant: file:line, the change, the red test name(s), real output excerpt.
- Avoid degenerate fixtures (identity transform, origin, axis-aligned walls, default attributes, unmirrored only) as the plan's P-2 says.
- Never edit the two allocation invariant tests (packages/jet_cad_2d/test/invariants/query_allocation_test.dart, packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart).
- Never stage analysis_options.yaml; stage files by explicit path.
- Never synthesize test output. Quote real output only.
- Run the task's gates (plan "Gates"); the standing failures at the branch point are recorded in the plan's Gates section — compare counts.
- Commit as soon as gates are green, with the plan's commit message and these trailers:
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_017Jpc94HDwBboPTaZBjjAFr
  Do NOT push. Do not touch other branches.
- If the spec or plan is wrong or impossible on a point, do the smallest faithful thing, and record it as a proposed ruling (R-C1-k) with its cost-if-wrong in your report; do not silently deviate.
- Container restarts happen: write your report early to .superpowers/sdd/plan-09c1/task-1-report.md and append as you go.
- Scratch dir: /tmp/claude-0/-home-user-jet-cad/05cf1abe-1171-54e2-83cf-ffde1eb9cfc8/scratchpad/task1/

Report (task-1-report.md and your final answer): commits (SHA + message), files changed, what was built, tests added (names), gate results with real counts (engine/render/app passes, failures, skips; analyze; format; web build when required), the mutant table, proposed rulings, anything found but not fixed, and anything the reviewer should look at hardest.
