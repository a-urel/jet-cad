You are the independent REVIEWER of Task 8 of plan 09c-1 in the jet-cad repository (Dart/Flutter parametric floor planner). You did not write this code. Assume the implementer's claims are wrong until you verify them.

Set up a DETACHED review worktree at the reviewed commit:
  cd /home/user/jet-cad && git worktree remove --force .worktrees/plan-09c1-review-t8 2>/dev/null; git worktree add --detach .worktrees/plan-09c1-review-t8 7150bd1
Work ONLY in /home/user/jet-cad/.worktrees/plan-09c1-review-t8. Do not modify the implementer's worktree (.worktrees/plan-09c1) or commit anything anywhere. When done, leave the review worktree in place (the controller removes it).
Note: run `CI=true flutter pub get` at the review worktree root first (it is a pub workspace); pub get may rewrite analysis_options.yaml — ignore that, never commit.

Read: CLAUDE.md; the plan docs/superpowers/plans/2026-10-02-wall-attach.md (Rulings, Global constraints, Gates, "### Task 8"); the spec docs/superpowers/specs/2026-10-02-wall-aware-symbols-design.md (the decisions the task cites, Testing, Named mutants); the implementer's report /home/user/jet-cad/.worktrees/plan-09c1/.superpowers/sdd/plan-09c1/task-8-report.md; the ledger progress.md there.

Diff under review: `git diff a073fb5..7150bd1`.

Do:
1. Check the implementation against the spec decision(s) and the plan task, line by line. Look for real defects (geometry, sign, ordering, exact-vs-tolerance, allocation on the frame path, draw order, permissions, undo/redo).
2. Re-run the task's gates yourself (`export PATH=/root/flutter/bin:$PATH`, `CI=true` prefix) and report real counts. Compare with the implementer's.
3. Re-fire the task's named mutants yourself (cp backup, mutate, run, cp back, `diff` exit 0; never git checkout a .dart file). Also invent 2-4 mutants of your own on the riskiest lines. Report which are red and which survive.
4. Check the tests for degenerate fixtures (identity, origin, axis-aligned, unmirrored, default style) per the plan's P-2.
5. Check: allocation invariant tests unedited; no analysis_options.yaml committed; purity rules (no Flutter/dart:ui in wall_attach.dart, symbol_box.dart).
6. Never synthesize output.

Verdict: "Approved", or "Needs fixes" with numbered findings (severity blocking/major/minor/note, file:line, evidence, the fix). Surviving mutants that matter are findings.
Write the review to /home/user/jet-cad/.worktrees/plan-09c1/.superpowers/sdd/plan-09c1/task-8-review.md (this one file only in that worktree) and return it as your final answer.
Scratch dir: /tmp/claude-0/-home-user-jet-cad/05cf1abe-1171-54e2-83cf-ffde1eb9cfc8/scratchpad/review8/

Task 8 extra focus: spec D12 and the controller's ruling C-3 in the ledger (Task 7, the wall attachment, comes after; M-09c-ak is Task 7's). Check the listener lifecycle on every path (pointer events, exit, cancel, disarm, re-arm, dispose), rulings R-C8-1 (a disarm removes the listener but does not hide the ghost; a re-arm with the ghost shown re-listens and re-resolves once), R-C8-2, R-C8-3 (_context vs _listening), the re-resolve condition in _onArmed (`ctx != null && !wasListening`) — e.g. a re-arm from one symbol to another while shown does not re-resolve: is that a defect?, the mid-press zoom and release, the one Vector2 per camera change (off the paint path). The camera swallows listener errors — check the tests do not rely on 'does not throw' alone. Review only `git diff a073fb5..7150bd1`. Gate: the app incl. web build.