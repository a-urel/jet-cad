You are the IMPLEMENTER of Task 5b (review fixes for Task 5) of plan 09c-1 in the jet-cad repository, working in /home/user/jet-cad/.worktrees/plan-09c1 (branch plan-09c/wall-attach). Other implementers work concurrently in the same worktree: Task 3b (furniture_library_test, symbol_library_test, a fixture, maybe the catalog/asset momentarily during mutants), Task 4b (wall_faces_test, wall_attach_fixture, maybe wall_attach.dart momentarily during mutants) and Task 10 (main.dart, symbol_panel.dart, symbol_panel_test, symbol_shell_test). Do not touch their files; stage only your own by explicit path; if a full-suite run fails in their files, re-run your own test files and say so.

Read: CLAUDE.md; the plan (Global constraints, Gates, Task 5); spec D5; .superpowers/sdd/plan-09c1/task-5-report.md and task-5-review.md.

Apply:
1. (major) Add to apps/floor_planner/test/symbols/symbol_place_tool_test.dart the review's test: a touch press at pA with no hover, then assert `ghostPlacement` equals the transform at gridOf(pA) (or the snapped point the tool resolves) and that one paint computes once; then drag to pMid, release at pB, assert `ghostPlacement` equals the transform at the release point. Keep the fixture non-degenerate (camera scale != 1, far from the origin, a rotated/mirrored placement if the test can turn it with R/M). Fire: delete `_syncPlacement()` on pointer down (lib/symbols/symbol_place_tool.dart:~182) and, separately, on pointer up (~:207): both must go red.
2. (note) Fix the doc comment at lib/symbols/symbol_ghost.dart:~101-102 that says the tool computes the placement on "camera events" (no camera listener exists until Task 8): say pointer and key events (Task 8 will add camera events).

Rules: `export PATH=/root/flutter/bin:$PATH`; `CI=true` on every command. Never `git checkout --` a .dart file; mutants by cp backup / cp back / diff exit 0. Never stage analysis_options.yaml. Never synthesize output. Gates: the app (test, analyze, format). Commit: `test(app): pin the ghost's placement at press and release` with trailers:
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017Jpc94HDwBboPTaZBjjAFr
Do not push. Write .superpowers/sdd/plan-09c1/task-5b-report.md (SHA, changes, gate counts, mutants with real output) and return it.
Scratch: /tmp/claude-0/-home-user-jet-cad/05cf1abe-1171-54e2-83cf-ffde1eb9cfc8/scratchpad/task5b/
