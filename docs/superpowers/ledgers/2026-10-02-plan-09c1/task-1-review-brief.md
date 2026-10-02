You are the independent REVIEWER of Task 1 of plan 09c-1 in the jet-cad repository (Dart/Flutter parametric floor planner). You did not write this code. Assume the implementer's claims are wrong until you verify them.

Set up a DETACHED review worktree at the reviewed commit:
  cd /home/user/jet-cad && git worktree remove --force .worktrees/plan-09c1-review 2>/dev/null; git worktree add --detach .worktrees/plan-09c1-review 48c8d57
Work ONLY in /home/user/jet-cad/.worktrees/plan-09c1-review. Do not modify the implementer's worktree (.worktrees/plan-09c1) or commit anything anywhere. When done, leave the review worktree in place (the controller removes it).
Note: run `CI=true flutter pub get` at the review worktree root first (it is a pub workspace); pub get may rewrite analysis_options.yaml — ignore that, never commit.

Read: CLAUDE.md; the plan docs/superpowers/plans/2026-10-02-wall-attach.md (Rulings, Global constraints, Gates, "### Task 1"); the spec docs/superpowers/specs/2026-10-02-wall-aware-symbols-design.md (the decisions the task cites, Testing, Named mutants); the implementer's report /home/user/jet-cad/.worktrees/plan-09c1/.superpowers/sdd/plan-09c1/task-1-report.md; the ledger progress.md there.

Diff under review: `git diff 904970d..48c8d57`.

Do:
1. Check the implementation against the spec decision(s) and the plan task, line by line. Look for real defects (geometry, sign, ordering, exact-vs-tolerance, allocation on the frame path, draw order, permissions, undo/redo).
2. Re-run the task's gates yourself (`export PATH=/root/flutter/bin:$PATH`, `CI=true` prefix) and report real counts. Compare with the implementer's.
3. Re-fire the task's named mutants yourself (cp backup, mutate, run, cp back, `diff` exit 0; never git checkout a .dart file). Also invent 2-4 mutants of your own on the riskiest lines. Report which are red and which survive.
4. Check the tests for degenerate fixtures (identity, origin, axis-aligned, unmirrored, default style) per the plan's P-2.
5. Check: allocation invariant tests unedited; no analysis_options.yaml committed; purity rules (no Flutter/dart:ui in wall_attach.dart, symbol_box.dart).
6. Never synthesize output.

Verdict: "Approved", or "Needs fixes" with numbered findings (severity blocking/major/minor/note, file:line, evidence, the fix). Surviving mutants that matter are findings.
Write the review to /home/user/jet-cad/.worktrees/plan-09c1/.superpowers/sdd/plan-09c1/task-1-review.md (this one file only in that worktree) and return it as your final answer.
Scratch dir: /tmp/claude-0/-home-user-jet-cad/05cf1abe-1171-54e2-83cf-ffde1eb9cfc8/scratchpad/review1/

Task 1 extra focus (from the implementer's report): R-C1-4 (undoing a plain AddDefinitionCommand now needs `components`, since its inverse is a RemoveDefinitionCommand with static {structure, components}) — judge whether that is acceptable against the spec D11 / review W-1 and the dispatcher's undo path in packages/jet_cad_2d/lib/src/document/undo.dart (does undo check the inverse's capabilities? what permission sets exist, e.g. runtime?); the order guards -> restore -> addDefinition in AddDefinitionCommand.apply (a refused add must change nothing); the changed P13 setup in apps/floor_planner/test/symbols/symbol_placer_test.dart (R-C1-2); R-C1-1 (unknown payload order); the new public detachAll (R-C1-3). Gates: engine, app, dev_harness_2d analyze; render once.
