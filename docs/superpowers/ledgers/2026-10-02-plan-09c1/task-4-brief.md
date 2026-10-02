You are the IMPLEMENTER of Task 4 of plan 09c-1 in the jet-cad repository (Dart/Flutter parametric floor planner).

Working tree: /home/user/jet-cad/.worktrees/plan-09c1 (branch plan-09c/wall-attach). Work ONLY there. Do not touch the main checkout at /home/user/jet-cad.

Read first, in order:
1. CLAUDE.md (non-negotiables, testing bar).
2. The plan: docs/superpowers/plans/2026-10-02-wall-attach.md — its Rulings (P-1..P-8), Global constraints, Gates, and your task's section "### Task 4".
3. The spec: docs/superpowers/specs/2026-10-02-wall-aware-symbols-design.md — the decisions your task cites, and the Testing / Named mutants sections. The spec is binding; the plan says how.
4. The ledger: .superpowers/sdd/plan-09c1/progress.md (rulings so far) and earlier task reports in .superpowers/sdd/plan-09c1/.

Task 4 specifics (app only): add `WallBands.liveWalls(DraftDocument doc)` in lib/parametric/wall_bands.dart (+ test in test/wall_bands_test.dart) and create lib/symbols/wall_attach.dart with FaceRun and faceRunsOf per spec D3 (read D3 in full, including the S-2/S-3/T-2/T-3 amendments: drawn cap points, direction from toWorld.transformDirection(frame.d), local side test for a T, per-face X cuts from B's drawn face lines, Obstacle unchanged, never stretchesOf). Key code: lib/parametric/opening_geometry.dart (HostFrame, hostFrameOf, obstaclesOf ~:98-170, wallsInDocument ~:711), lib/parametric/wall_geometry.dart (WorldWall, End, cap, capsOf, drawnCapsOf, outline), lib/parametric/wall_bands.dart, lib/parametric/opening_tool.dart isUsableHost (~:447; it lives in a Flutter-importing file, so faceRunsOf/WallFaces take an accept predicate — plan P-4). Build test/support/wall_attach_fixture.dart (plan P-3: 30° and −112.5° walls in a group with non-identity transform far from the origin (1e5, −7e4); mirrored centre-justified group with a T; scaled group joined and fallen back; an L of 100/240 mm; an X at 60°) using the existing test/support/wall_fixture.dart helpers. New test file test/symbols/wall_faces_test.dart. Check (P-4) that opening_geometry.dart and wall_bands.dart import no Flutter. Only the app gate; engine and render unchanged: state it.

CONCURRENCY: another implementer works in the same worktree at the same time (Task 3: lib/symbols/furniture_catalog.dart, lib/symbols/symbol_library.dart, assets/library/furniture.jetlib, test/symbols/{furniture_library,symbol_library,symbol_box}_test.dart and any test whose 27-symbol count it updates). Stage and commit ONLY your own files by explicit path. If a full-suite run fails in a file that is the other task's (uncommitted, in progress), re-run your own test files and say so in your report; do not edit the other task's files. Run the full app suite once more after your commit.

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
- If the spec or plan is wrong or impossible on a point, do the smallest faithful thing, and record it as a proposed ruling (R-C4-k) with its cost-if-wrong in your report; do not silently deviate.
- Container restarts happen: write your report early to .superpowers/sdd/plan-09c1/task-4-report.md and append as you go.
- Scratch dir: /tmp/claude-0/-home-user-jet-cad/05cf1abe-1171-54e2-83cf-ffde1eb9cfc8/scratchpad/task4/

Report (task-4-report.md and your final answer): commits (SHA + message), files changed, what was built, tests added (names), gate results with real counts (engine/render/app passes, failures, skips; analyze; format; web build when required), the mutant table, proposed rulings, anything found but not fixed, and anything the reviewer should look at hardest.
