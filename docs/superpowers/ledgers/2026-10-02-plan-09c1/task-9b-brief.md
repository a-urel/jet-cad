You are the IMPLEMENTER of Task 9b (review fixes for Task 9) of plan 09c-1 in the jet-cad repository. Work ONLY in /home/user/jet-cad/.worktrees/plan-09c1-t9b (branch wip/09c1-t9b, at a073fb5; the controller cherry-picks your commit onto the plan branch). Do not touch other worktrees, except to write your report into the ledger directory /home/user/jet-cad/.worktrees/plan-09c1/.superpowers/sdd/plan-09c1/ (git-ignored).

Read: CLAUDE.md; the plan docs/superpowers/plans/2026-10-02-wall-attach.md (Global constraints, Gates, Task 9); spec D10; the ledger's task-9-report.md and task-9-review.md; the reviewer's probe test /tmp/claude-0/-home-user-jet-cad/05cf1abe-1171-54e2-83cf-ffde1eb9cfc8/scratchpad/review9/zz_review_probe_test.dart (adapt it, do not commit it as is).

Apply the review's three findings in apps/floor_planner/test/symbols/symbol_placer_test.dart (test-only; no production change unless a real defect appears — then stop and report):
1. (major) Add an x-only moved-base-point edit (or x and y); fire both half-mutants on symbol_placer.dart:~199 (compare only y; compare only x): both red.
2. (major) A test where the document's slots are freed (two slots, in ascending order) before the first placement, so the copied definition's leaves sit in slots out of handle order; assert that premise (slot order differs from handle order); place twice; expect ONE definition (reuse). Fire: the sort at :~206-207 removed — must go red.
3. (minor) Two leaf-equal definitions with the same key/version: the lookup picks the lower handle (as the doc comment claims). Fire: `break` removed (last match wins) — must go red.

Rules: `export PATH=/root/flutter/bin:$PATH`; `CI=true` on every command. Never `git checkout --` a .dart file; mutants by cp backup / cp back / diff exit 0. Never stage analysis_options.yaml. Never synthesize output. Gates in your worktree: app full suite, analyze, format. Commit: `test(app): pin leaf-equal reuse's pairing, base point and first match` with trailers:
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017Jpc94HDwBboPTaZBjjAFr
Do not push. Write /home/user/jet-cad/.worktrees/plan-09c1/.superpowers/sdd/plan-09c1/task-9b-report.md (SHA, changes, gate counts, mutants with real output) and return it.
Scratch: /tmp/claude-0/-home-user-jet-cad/05cf1abe-1171-54e2-83cf-ffde1eb9cfc8/scratchpad/task9b/
