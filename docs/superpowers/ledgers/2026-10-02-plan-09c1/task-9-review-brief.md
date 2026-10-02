You are the independent REVIEWER of Task 9 of plan 09c-1 in the jet-cad repository (Dart/Flutter parametric floor planner). You did not write this code. Assume the implementer's claims are wrong until you verify them.

Set up a DETACHED review worktree at the reviewed commit:
  cd /home/user/jet-cad && git worktree remove --force .worktrees/plan-09c1-review-t9 2>/dev/null; git worktree add --detach .worktrees/plan-09c1-review-t9 a073fb5
Work ONLY in /home/user/jet-cad/.worktrees/plan-09c1-review-t9. Do not modify the implementer's worktree (.worktrees/plan-09c1) or commit anything anywhere. When done, leave the review worktree in place (the controller removes it).
Note: run `CI=true flutter pub get` at the review worktree root first (it is a pub workspace); pub get may rewrite analysis_options.yaml — ignore that, never commit.

Read: CLAUDE.md; the plan docs/superpowers/plans/2026-10-02-wall-attach.md (Rulings, Global constraints, Gates, "### Task 9"); the spec docs/superpowers/specs/2026-10-02-wall-aware-symbols-design.md (the decisions the task cites, Testing, Named mutants); the implementer's report /home/user/jet-cad/.worktrees/plan-09c1/.superpowers/sdd/plan-09c1/task-9-report.md; the ledger progress.md there.

Diff under review: `git diff 54eab37..a073fb5`.

Do:
1. Check the implementation against the spec decision(s) and the plan task, line by line. Look for real defects (geometry, sign, ordering, exact-vs-tolerance, allocation on the frame path, draw order, permissions, undo/redo).
2. Re-run the task's gates yourself (`export PATH=/root/flutter/bin:$PATH`, `CI=true` prefix) and report real counts. Compare with the implementer's.
3. Re-fire the task's named mutants yourself (cp backup, mutate, run, cp back, `diff` exit 0; never git checkout a .dart file). Also invent 2-4 mutants of your own on the riskiest lines. Report which are red and which survive.
4. Check the tests for degenerate fixtures (identity, origin, axis-aligned, unmirrored, default style) per the plan's P-2.
5. Check: allocation invariant tests unedited; no analysis_options.yaml committed; purity rules (no Flutter/dart:ui in wall_attach.dart, symbol_box.dart).
6. Never synthesize output.

Verdict: "Approved", or "Needs fixes" with numbered findings (severity blocking/major/minor/note, file:line, evidence, the fix). Surviving mutants that matter are findings.
Write the review to /home/user/jet-cad/.worktrees/plan-09c1/.superpowers/sdd/plan-09c1/task-9-review.md (this one file only in that worktree) and return it as your final answer.
Scratch dir: /tmp/claude-0/-home-user-jet-cad/05cf1abe-1171-54e2-83cf-ffde1eb9cfc8/scratchpad/review9/

Task 9 extra focus: isLeafEqual against spec D10 (rev 4, W-11): base point, child nodes, live leaf count, pairwise record equality except handle/owner/geomIndex (R-C9-1: via the record's own == after normalising — check EntityRecord's == really covers every field in packages/jet_cad_2d/lib/src/document/entity_store.dart, and GeometryPayload's == covers coords and scalars exactly; if either == is identity or partial, that is a defect), pairing order (R-C9-2), R-C9-3. Check that each of the 12 style mutants turns exactly the matching test red; the leaf-count mutant. Placement cost (isLeafEqual scans every live slot per candidate) is off the frame path — confirm. The stale comment the implementer found (`the library entry is read-only to a placement` group) — note for Task 11. Review only `git diff 54eab37..a073fb5`. Gate: the app incl. web build.