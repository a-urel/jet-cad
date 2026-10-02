You are the independent REVIEWER of Task 4 of plan 09c-1 in the jet-cad repository (Dart/Flutter parametric floor planner). You did not write this code. Assume the implementer's claims are wrong until you verify them.

Set up a DETACHED review worktree at the reviewed commit:
  cd /home/user/jet-cad && git worktree remove --force .worktrees/plan-09c1-review-t4 2>/dev/null; git worktree add --detach .worktrees/plan-09c1-review-t4 e73621f
Work ONLY in /home/user/jet-cad/.worktrees/plan-09c1-review-t4. Do not modify the implementer's worktree (.worktrees/plan-09c1) or commit anything anywhere. When done, leave the review worktree in place (the controller removes it).
Note: run `CI=true flutter pub get` at the review worktree root first (it is a pub workspace); pub get may rewrite analysis_options.yaml — ignore that, never commit.

Read: CLAUDE.md; the plan docs/superpowers/plans/2026-10-02-wall-attach.md (Rulings, Global constraints, Gates, "### Task 4"); the spec docs/superpowers/specs/2026-10-02-wall-aware-symbols-design.md (the decisions the task cites, Testing, Named mutants); the implementer's report /home/user/jet-cad/.worktrees/plan-09c1/.superpowers/sdd/plan-09c1/task-4-report.md; the ledger progress.md there.

Diff under review: `git diff a6ef0bc..e73621f`.

Do:
1. Check the implementation against the spec decision(s) and the plan task, line by line. Look for real defects (geometry, sign, ordering, exact-vs-tolerance, allocation on the frame path, draw order, permissions, undo/redo).
2. Re-run the task's gates yourself (`export PATH=/root/flutter/bin:$PATH`, `CI=true` prefix) and report real counts. Compare with the implementer's.
3. Re-fire the task's named mutants yourself (cp backup, mutate, run, cp back, `diff` exit 0; never git checkout a .dart file). Also invent 2-4 mutants of your own on the riskiest lines. Report which are red and which survive.
4. Check the tests for degenerate fixtures (identity, origin, axis-aligned, unmirrored, default style) per the plan's P-2.
5. Check: allocation invariant tests unedited; no analysis_options.yaml committed; purity rules (no Flutter/dart:ui in wall_attach.dart, symbol_box.dart).
6. Never synthesize output.

Verdict: "Approved", or "Needs fixes" with numbered findings (severity blocking/major/minor/note, file:line, evidence, the fix). Surviving mutants that matter are findings.
Write the review to /home/user/jet-cad/.worktrees/plan-09c1/.superpowers/sdd/plan-09c1/task-4-review.md (this one file only in that worktree) and return it as your final answer.
Scratch dir: /tmp/claude-0/-home-user-jet-cad/05cf1abe-1171-54e2-83cf-ffde1eb9cfc8/scratchpad/review4/

Task 4 extra focus: this is the geometric core; be adversarial. Verify faceRunsAmong against spec D3 (rev 4) independently: the sign of the left normal m, `t = (−m.y, m.x)`, thickness measured at the start-cap points (is it right when the two faces' start caps are at different u, e.g. a node owner's lobe or a T?), the local side test for a T (WF5's premise: does the mirrored T really exercise local vs world disagreement, given mirrored frames always fall back?), the T cut from the stem's drawn faces vs D3's wording, X per-face cuts, sliver drop at wallJoin.linear. Write your own differential check if you can: e.g. for random wall scenes compare each run's endpoints against the wall's stored outline polygon edges (each run must lie on an outline edge and be covered by it). Re-fire M-09c-f, -g1, -g2, -g3, -ag, -as, -at, -ay and liveWalls-without-refresh. Rulings R-C4-1..4. Note the 'found, not fixed' that mirrored walls never draw joined corners — confirm it is pre-existing on main. Task 5 is being implemented concurrently in the same branch worktree; review only `git diff a6ef0bc..e73621f`. Gate: the app (engine and render unchanged).