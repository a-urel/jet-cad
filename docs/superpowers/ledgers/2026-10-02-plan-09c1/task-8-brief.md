You are the IMPLEMENTER of Task 8 of plan 09c-1 in the jet-cad repository (Dart/Flutter parametric floor planner).

Working tree: /home/user/jet-cad/.worktrees/plan-09c1 (branch plan-09c/wall-attach). Work ONLY there. Do not touch the main checkout at /home/user/jet-cad.

Read first, in order:
1. CLAUDE.md (non-negotiables, testing bar).
2. The plan: docs/superpowers/plans/2026-10-02-wall-attach.md — its Rulings (P-1..P-8), Global constraints, Gates, and your task's section "### Task 8".
3. The spec: docs/superpowers/specs/2026-10-02-wall-aware-symbols-design.md — the decisions your task cites, and the Testing / Named mutants sections. The spec is binding; the plan says how.
4. The ledger: .superpowers/sdd/plan-09c1/progress.md (rulings so far) and earlier task reports in .superpowers/sdd/plan-09c1/.

Task 8 specifics (app only): spec D12 and plan Task 8, with the controller's ruling C-3 in the ledger: Task 7 (wall attachment in the tool) has NOT landed yet; implement the camera listener so that it re-resolves through the tool's single recompute path (the same `_resolve` + `_syncPlacement` sequence a pointer move uses), so Task 7 can add the attachment there; M-09c-ak is Task 7's, not yours. lib/symbols/symbol_place_tool.dart: keep the last pointer's SCREEN point (ToolPointerEvent.screen); while the ghost is visible, listen to ctx.camera and on change convert the screen point to world (`ctx.camera.value.screenToWorld(Vector2(...))`) and re-resolve; the listener is added when the ghost becomes visible and removed when it hides (pointer exit), on cancel, on a disarm (armed -> null), on a re-arm if appropriate, and on dispose. Pattern: packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart:258-279 (`_listening`, `_syncCamera`, `_onCamera`). Note the tool's ToolContext is only available in pointer/key callbacks: keep the context you listened with (as PlacementTool keeps `_listening`). Tests in test/symbols/symbol_place_tool_test.dart: a camera zoom about a point other than the pointer moves the ghost's placement to the new world point under the same screen point (camera scale != 1, far from the origin); after hide, cancel, disarm and dispose, a camera change does nothing and does not throw (dispose with a live camera). Mutants: M-09c-s (listener not added; not removed on dispose, with a live camera), M-09c-bb (not removed on hide; on cancel; on disarm — each). Gate: the app (engine and render unchanged). You are the only implementer in the plan worktree; Task 6 works in its own worktree; reviewers in theirs.

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
- If the spec or plan is wrong or impossible on a point, do the smallest faithful thing, and record it as a proposed ruling (R-C8-k) with its cost-if-wrong in your report; do not silently deviate.
- Container restarts happen: write your report early to .superpowers/sdd/plan-09c1/task-8-report.md and append as you go.
- Scratch dir: /tmp/claude-0/-home-user-jet-cad/05cf1abe-1171-54e2-83cf-ffde1eb9cfc8/scratchpad/task8/

Report (task-8-report.md and your final answer): commits (SHA + message), files changed, what was built, tests added (names), gate results with real counts (engine/render/app passes, failures, skips; analyze; format; web build when required), the mutant table, proposed rulings, anything found but not fixed, and anything the reviewer should look at hardest.
