You are the IMPLEMENTER of Task 10 of plan 09c-1 in the jet-cad repository (Dart/Flutter parametric floor planner).

Working tree: /home/user/jet-cad/.worktrees/plan-09c1 (branch plan-09c/wall-attach). Work ONLY there. Do not touch the main checkout at /home/user/jet-cad.

Read first, in order:
1. CLAUDE.md (non-negotiables, testing bar).
2. The plan: docs/superpowers/plans/2026-10-02-wall-attach.md — its Rulings (P-1..P-8), Global constraints, Gates, and your task's section "### Task 10".
3. The spec: docs/superpowers/specs/2026-10-02-wall-aware-symbols-design.md — the decisions your task cites, and the Testing / Named mutants sections. The spec is binding; the plan says how.
4. The ledger: .superpowers/sdd/plan-09c1/progress.md (rulings so far) and earlier task reports in .superpowers/sdd/plan-09c1/.

Task 10 specifics (app only): spec D13. lib/main.dart (the shell, PlannerShell state around :353-:360 and the Symbols tab at ~:809) owns the search TextEditingController (create in initState, dispose in dispose) and passes it to SymbolPanel (lib/symbols/symbol_panel.dart, which today owns `_query` at ~:105 and adds/removes its listener at ~:120/:127). The panel must no longer create or dispose it, but keeps adding/removing its own listener. The panel is still removed on the Tools tab. Tests in test/symbols/symbol_panel_test.dart and test/symbols/symbol_shell_test.dart: type "bed", switch to Tools and back — the field reads "bed" and the gallery is filtered; a document replacement (see how symbol_shell_test or document tests replace the document) keeps it; the panel disposed does not dispose the controller (still usable: e.g. setting text after the panel is gone does not throw). Existing panel tests that construct SymbolPanel directly need a controller argument: give them one (owned by the test) and name each changed construction site in the report. Mutants: M-09c-t (the panel creates its own controller again, ignoring the given one), the shell recreating the controller per build, the panel disposing the given controller. Gate: the app (engine and render unchanged).
CONCURRENCY: Task 5's reviewer works in a separate worktree; no other implementer edits the plan worktree right now, but commit only your own files by explicit path anyway.

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
- If the spec or plan is wrong or impossible on a point, do the smallest faithful thing, and record it as a proposed ruling (R-C10-k) with its cost-if-wrong in your report; do not silently deviate.
- Container restarts happen: write your report early to .superpowers/sdd/plan-09c1/task-10-report.md and append as you go.
- Scratch dir: /tmp/claude-0/-home-user-jet-cad/05cf1abe-1171-54e2-83cf-ffde1eb9cfc8/scratchpad/task10/

Report (task-10-report.md and your final answer): commits (SHA + message), files changed, what was built, tests added (names), gate results with real counts (engine/render/app passes, failures, skips; analyze; format; web build when required), the mutant table, proposed rulings, anything found but not fixed, and anything the reviewer should look at hardest.
