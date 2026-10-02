You are the independent REVIEWER of Task 7 of plan 09c-1 in the jet-cad repository (Dart/Flutter parametric floor planner). You did not write this code. Assume the implementer's claims are wrong until you verify them.

Set up a DETACHED review worktree at the reviewed commit:
  cd /home/user/jet-cad && git worktree remove --force .worktrees/plan-09c1-review-t7 2>/dev/null; git worktree add --detach .worktrees/plan-09c1-review-t7 2a1f8c2
Work ONLY in /home/user/jet-cad/.worktrees/plan-09c1-review-t7. Do not modify the implementer's worktree (.worktrees/plan-09c1) or commit anything anywhere. When done, leave the review worktree in place (the controller removes it).
Note: run `CI=true flutter pub get` at the review worktree root first (it is a pub workspace); pub get may rewrite analysis_options.yaml — ignore that, never commit.

Read: CLAUDE.md; the plan docs/superpowers/plans/2026-10-02-wall-attach.md (Rulings, Global constraints, Gates, "### Task 7"); the spec docs/superpowers/specs/2026-10-02-wall-aware-symbols-design.md (the decisions the task cites, Testing, Named mutants); the implementer's report /home/user/jet-cad/.worktrees/plan-09c1/.superpowers/sdd/plan-09c1/task-7-report.md; the ledger progress.md there.

Diff under review: `git diff b3284f1..2a1f8c2`.

Do:
1. Check the implementation against the spec decision(s) and the plan task, line by line. Look for real defects (geometry, sign, ordering, exact-vs-tolerance, allocation on the frame path, draw order, permissions, undo/redo).
2. Re-run the task's gates yourself (`export PATH=/root/flutter/bin:$PATH`, `CI=true` prefix) and report real counts. Compare with the implementer's.
3. Re-fire the task's named mutants yourself (cp backup, mutate, run, cp back, `diff` exit 0; never git checkout a .dart file). Also invent 2-4 mutants of your own on the riskiest lines. Report which are red and which survive.
4. Check the tests for degenerate fixtures (identity, origin, axis-aligned, unmirrored, default style) per the plan's P-2.
5. Check: allocation invariant tests unedited; no analysis_options.yaml committed; purity rules (no Flutter/dart:ui in wall_attach.dart, symbol_box.dart).
6. Never synthesize output.

Verdict: "Approved", or "Needs fixes" with numbered findings (severity blocking/major/minor/note, file:line, evidence, the fix). Surviving mutants that matter are findings.
Write the review to /home/user/jet-cad/.worktrees/plan-09c1/.superpowers/sdd/plan-09c1/task-7-review.md (this one file only in that worktree) and return it as your final answer.
Scratch dir: /tmp/claude-0/-home-user-jet-cad/05cf1abe-1171-54e2-83cf-ffde1eb9cfc8/scratchpad/review7/

Task 7 extra focus: spec D6 (rev 4) end to end in the tool and the shell. Rulings to judge: R-C7-1 (the controller verified drawSnapMarker draws nothing for SnapKind.nearest; an app-side hourglass is drawn instead — check its geometry, paint, and that it allocates nothing per paint beyond what the existing marker path does), R-C7-2 (R/M re-run only the attachment with the stored query, not a re-snap), R-C7-3, R-C7-4. Check: the attachment lives in the single `_update` path (pointer, camera, re-arm) per C-3/R-C8b-1; no Transform2 built in a paint; the release uses `transform: attached` and the bytes match attachToWall; `bands.invalidate()` after a commit only; main.dart's WallFaces wiring and lifetime vs document replacement (the host keys the shell by document); the permission check before allocation; 09b behaviour unchanged without faces (the 09b tests untouched?). Re-fire the plan's Task 7 mutants (M-09c-a, -e, -j, -k, -l, -ap, -ak, the re-arm-skips-attachment mutant, marker at raw point, release ignoring the attached transform) and 2-4 of your own (e.g. attachment computed with the resolved instead of the raw pointer; mirror applied twice; the stored scale stale after a zoom). Review `git diff b3284f1..2a1f8c2`. Gate: the app incl. web build.