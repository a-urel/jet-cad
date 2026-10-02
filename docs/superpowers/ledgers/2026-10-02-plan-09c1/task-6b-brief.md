You are the IMPLEMENTER of Task 6b (review fixes for Task 6) of plan 09c-1 in the jet-cad repository. Work ONLY in /home/user/jet-cad/.worktrees/plan-09c1-t6 (branch wip/09c1-t6, tip e188ef1; the controller cherry-picks onto the plan branch). Do not touch other worktrees except to write your report into /home/user/jet-cad/.worktrees/plan-09c1/.superpowers/sdd/plan-09c1/ (git-ignored).

Read: CLAUDE.md; the plan (Global constraints, Gates, Task 6); spec D4; the ledger's task-6-report.md and task-6-review.md; the reviewer's property test /tmp/claude-0/-home-user-jet-cad/05cf1abe-1171-54e2-83cf-ffde1eb9cfc8/scratchpad/review6/review6_property_test.dart.

Apply the review's four findings:
1. Neighbour rule "both back-edge ends on the line" (lib/symbols/wall_attach.dart:~485-486): add to WA8 (test/symbols/wall_attach_test.dart) a toilet turned 10° about its back-left corner on the face; assert it is not a neighbour. Fire O7 (only one end checked): red.
2. isOrthonormal's |ac + bd| clause (~:356): add a sheared instance with unit-length columns (e.g. Transform2(1, 0, sin 20°, cos 20°, ...)) — direct test and/or as a non-neighbour in WA8. Fire O6 (the clause removed): red.
3. Edge-snap tie (~:298): build an exact tie with synthetic FaceNeighbour records at dyadic offsets around the u the test recovers bitwise (as the review describes); assert the smaller resulting u wins. Fire O1 (tie reversed): red. If an exact tie truly cannot be built, record it as an accepted untested branch with the evidence.
4. Allocation: the edge-snap step (~:291-312) uses a closure `consider` capturing mutable doubles — a Context + Closure per call and boxed doubles. Inline the comparison so the pointer query allocates O(1) and nothing per run/candidate (the result record is fine). Keep behaviour bitwise identical (all existing tests green).
5. Adopt the reviewer's property test as a committed test (test/symbols/wall_attach_property_test.dart), reduced so it runs in a few seconds (e.g. fewer queries per scene, fixed seed), keeping its discriminating power: confirm it still goes red on M-09c-b, M-09c-af, M-09c-i, M-09c-h and the reviewer's O16 (|s| ranked exactly).

Rules: `export PATH=/root/flutter/bin:$PATH`; `CI=true` on every command. Never `git checkout --` a .dart file; mutants by cp backup / cp back / diff exit 0. Never stage analysis_options.yaml. Never synthesize output. Gates in your worktree: app full suite, analyze, format, web build. Commit: `fix(app): pin the neighbour and snap rules, no closure in the snap step` with trailers:
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017Jpc94HDwBboPTaZBjjAFr
Do not push. Write /home/user/jet-cad/.worktrees/plan-09c1/.superpowers/sdd/plan-09c1/task-6b-report.md (SHA, changes, gate counts, mutants with real output) and return it.
Scratch: /tmp/claude-0/-home-user-jet-cad/05cf1abe-1171-54e2-83cf-ffde1eb9cfc8/scratchpad/task6b/
