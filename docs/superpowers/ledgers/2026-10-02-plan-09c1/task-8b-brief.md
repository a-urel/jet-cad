You are the IMPLEMENTER of Task 8b (review fixes for Task 8) of plan 09c-1 in the jet-cad repository, working in /home/user/jet-cad/.worktrees/plan-09c1 (branch plan-09c/wall-attach, tip 90f0d97). You are the only implementer in this worktree; reviewers work in their own worktrees.

Read: CLAUDE.md; the plan (Global constraints, Gates, Tasks 7 and 8); spec D6, D12; the ledger .superpowers/sdd/plan-09c1/progress.md (ruling C-3), task-8-report.md and task-8-review.md.

Apply:
1. (major) Add to apps/floor_planner/test/symbols/symbol_place_tool_test.dart's camera group the review's test: down at pB, up at pC with no move in between, then a wheel zoom about another point; expect the ghost under pC's screen point (`ghostAt == gridOf(screenToWorld(screen of pC))` or the tool's equivalent resolution). Fire: delete `_track(e, ctx)` in onPointerUp (lib/symbols/symbol_place_tool.dart:~263) — must go red.
2. (minor, required now so Task 7 can rely on it) In `_onArmed` (~:150-160), route the re-resolve through the single recompute path `_update(ctx, world under the last screen point)` instead of calling `_resolve` + `_syncPlacement` directly; when there is no context, only `_syncPlacement()`. Also re-resolve on an entry -> entry re-arm while the ghost is shown (the attachment Task 7 adds depends on the entry), unless the review's reasoning shows a reason not to — record your choice as a ruling R-C8b-k. Add a test that would distinguish routing through `_update` from the direct calls if possible today (e.g. a test seam or an observable effect such as the placement after an entry->entry re-arm with a camera change in between); if no observable difference exists until Task 7, say so plainly and leave the mutant "re-arm skips the attachment" to Task 7 (record it in your report for the controller).
Keep every existing test green.

Rules: `export PATH=/root/flutter/bin:$PATH`; `CI=true` on every command. Never `git checkout --` a .dart file; mutants by cp backup / cp back / diff exit 0. Never stage analysis_options.yaml. Never synthesize output. Gates: the app (test, analyze, format, web build). Commit: `fix(app): the ghost's camera path at release and re-arm` with trailers:
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017Jpc94HDwBboPTaZBjjAFr
Do not push. Write .superpowers/sdd/plan-09c1/task-8b-report.md (SHA, changes, gate counts, mutants with real output, rulings) and return it.
Scratch: /tmp/claude-0/-home-user-jet-cad/05cf1abe-1171-54e2-83cf-ffde1eb9cfc8/scratchpad/task8b/
