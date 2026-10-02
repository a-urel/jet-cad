You are the IMPLEMENTER of Task 5 of plan 09c-1 in the jet-cad repository (Dart/Flutter parametric floor planner).

Working tree: /home/user/jet-cad/.worktrees/plan-09c1 (branch plan-09c/wall-attach). Work ONLY there. Do not touch the main checkout at /home/user/jet-cad.

Read first, in order:
1. CLAUDE.md (non-negotiables, testing bar).
2. The plan: docs/superpowers/plans/2026-10-02-wall-attach.md — its Rulings (P-1..P-8), Global constraints, Gates, and your task's section "### Task 5".
3. The spec: docs/superpowers/specs/2026-10-02-wall-aware-symbols-design.md — the decisions your task cites, and the Testing / Named mutants sections. The spec is binding; the plan says how.
4. The ledger: .superpowers/sdd/plan-09c1/progress.md (rulings so far) and earlier task reports in .superpowers/sdd/plan-09c1/.

Task 5 specifics (app only): lib/symbols/symbol_placer.dart (`placementTransform` gains `rotation: (double, double)?`, mutually exclusive with `quarterTurns` — throw ArgumentError in release too, not only an assert; `placeSymbol` gains `Transform2? transform`), lib/symbols/symbol_ghost.dart (`GhostMatrix.update(placement: Transform2)` comparing the six doubles exactly; `computations` kept), lib/symbols/symbol_place_tool.dart only as far as needed to call the new `GhostMatrix.update` signature (compute the placement transform on pointer/key events into a field, pass it in paintWorldOverlay; no Transform2 built in a paint — spec D5/W-15; the attachment itself is Task 7, not yours). Tests: test/symbols/symbol_placer_test.dart, symbol_ghost_test.dart, symbol_place_tool_test.dart (09b's ghost tests move to the new signature with the same counts, plan P-6; name each changed assertion with old and new lines). Use a 30° rotation vector far from the origin with a non-origin base point, mirrored and not; the quarter-turn path must stay bitwise identical (09b's P1-P4, P14 pass unchanged). Mutants: M-09c-n (in the generalised form; note M-09c-n is only killable on an axis-aligned vector such as (0,1)·... producing -0.0 — the spec's named exception), M-09c-o, the transform argument ignored, plus a "Transform2 built in paintWorldOverlay" check if you can make one observable (e.g. computations count under repeated paints).

CONCURRENCY: another implementer works in the same worktree at the same time (Task 4: lib/parametric/wall_bands.dart, lib/symbols/wall_attach.dart, test/wall_bands_test.dart, test/symbols/wall_faces_test.dart, test/support/wall_attach_fixture.dart). Stage and commit ONLY your own files by explicit path. If a full-suite run fails in the other task's files, re-run your own test files and say so; do not edit the other task's files. Run the full app suite once more after your commit.

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
- If the spec or plan is wrong or impossible on a point, do the smallest faithful thing, and record it as a proposed ruling (R-C5-k) with its cost-if-wrong in your report; do not silently deviate.
- Container restarts happen: write your report early to .superpowers/sdd/plan-09c1/task-5-report.md and append as you go.
- Scratch dir: /tmp/claude-0/-home-user-jet-cad/05cf1abe-1171-54e2-83cf-ffde1eb9cfc8/scratchpad/task5/

Report (task-5-report.md and your final answer): commits (SHA + message), files changed, what was built, tests added (names), gate results with real counts (engine/render/app passes, failures, skips; analyze; format; web build when required), the mutant table, proposed rulings, anything found but not fixed, and anything the reviewer should look at hardest.
