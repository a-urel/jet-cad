You are the independent REVIEWER of Task 6 of plan 09c-1 in the jet-cad repository (Dart/Flutter parametric floor planner). You did not write this code. Assume the implementer's claims are wrong until you verify them.

Set up a DETACHED review worktree at the reviewed commit:
  cd /home/user/jet-cad && git worktree remove --force .worktrees/plan-09c1-review-t6 2>/dev/null; git worktree add --detach .worktrees/plan-09c1-review-t6 e188ef1
Work ONLY in /home/user/jet-cad/.worktrees/plan-09c1-review-t6. Do not modify the implementer's worktree (.worktrees/plan-09c1) or commit anything anywhere. When done, leave the review worktree in place (the controller removes it).
Note: run `CI=true flutter pub get` at the review worktree root first (it is a pub workspace); pub get may rewrite analysis_options.yaml — ignore that, never commit.

Read: CLAUDE.md; the plan docs/superpowers/plans/2026-10-02-wall-attach.md (Rulings, Global constraints, Gates, "### Task 6"); the spec docs/superpowers/specs/2026-10-02-wall-aware-symbols-design.md (the decisions the task cites, Testing, Named mutants); the implementer's report /home/user/jet-cad/.worktrees/plan-09c1/.superpowers/sdd/plan-09c1/task-6-report.md; the ledger progress.md there.

Diff under review: `git diff 54eab37..e188ef1`.

Do:
1. Check the implementation against the spec decision(s) and the plan task, line by line. Look for real defects (geometry, sign, ordering, exact-vs-tolerance, allocation on the frame path, draw order, permissions, undo/redo).
2. Re-run the task's gates yourself (`export PATH=/root/flutter/bin:$PATH`, `CI=true` prefix) and report real counts. Compare with the implementer's.
3. Re-fire the task's named mutants yourself (cp backup, mutate, run, cp back, `diff` exit 0; never git checkout a .dart file). Also invent 2-4 mutants of your own on the riskiest lines. Report which are red and which survive.
4. Check the tests for degenerate fixtures (identity, origin, axis-aligned, unmirrored, default style) per the plan's P-2.
5. Check: allocation invariant tests unedited; no analysis_options.yaml committed; purity rules (no Flutter/dart:ui in wall_attach.dart, symbol_box.dart).
6. Never synthesize output.

Verdict: "Approved", or "Needs fixes" with numbered findings (severity blocking/major/minor/note, file:line, evidence, the fix). Surviving mutants that matter are findings.
Write the review to /home/user/jet-cad/.worktrees/plan-09c1/.superpowers/sdd/plan-09c1/task-6-review.md (this one file only in that worktree) and return it as your final answer.
Scratch dir: /tmp/claude-0/-home-user-jet-cad/05cf1abe-1171-54e2-83cf-ffde1eb9cfc8/scratchpad/review6/

Task 6 extra focus (the attachment rule, be adversarial): verify attachToWall against spec D4 rev 4 step by step (candidate window −w/2 ≤ s ≤ capture and the u window; ranking |s|, distance from u to [0,L], wall handle, left face, a·t — and R-C6-2: ties within wallJoin.linear, judge whether that is a decision tolerance consistent with CLAUDE.md "Tolerance for decisions"; W ≤ L + wallJoin.linear; R from t, cos = t.x, sin = t.y; edge snaps incl. neighbours, smallest shift wins; clamp with u = L/2 when W ≥ L; the transform = placementTransform(at: q, basePoint: back-centre, rotation: (t.x,t.y), mirrored)). Write your own differential/property check if you can: for random scenes (30°/−112.5°, mirrored/scaled groups, every justification) and random pointers, assert the attached symbol's transformed back edge lies on the face line (≤1e-9 relative to the coordinates' magnitude), its front is in the room, its footprint lies within the run, and the mirror does not move the footprint. Neighbour rule (R-C6-1, R-C6-5: engine FilterEvaluator picking filter, closed overlap, front-centre on the room side). WallFaces caching (generation keyed; box memo cleared; no allocation per run per pointer query — inspect for hidden allocations like closures/lists/Vector2 in the hot path). Re-fire the plan's mutants M-09c-b, -c, -d, -h, -i, -j, -m, -n, -af, -ah (both), -aq, -au and 'WallFaces not keyed on the generation'. R-C6-3 (the deleted -0.0 lines), R-C6-4 (imports symbol_placer.dart; check its import closure is Flutter-free), R-C6-6. This commit is on branch wip/09c1-t6 (parent 54eab37), to be cherry-picked onto the plan branch; review `git diff 54eab37..e188ef1`. Gate: the app incl. web build.