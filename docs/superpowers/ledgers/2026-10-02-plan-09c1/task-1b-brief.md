You are the IMPLEMENTER of Task 1b (review fixes for Task 1) of plan 09c-1 in the jet-cad repository, working in /home/user/jet-cad/.worktrees/plan-09c1 (branch plan-09c/wall-attach). Another implementer (Task 2) is working concurrently in the same worktree on apps/floor_planner/lib/symbols/symbol_box.dart and its test: do not touch those files, stage only your own files by explicit path.

Read: CLAUDE.md; the plan docs/superpowers/plans/2026-10-02-wall-attach.md (Global constraints, Gates, Task 1); the Task 1 report and review in .superpowers/sdd/plan-09c1/task-1-report.md and task-1-review.md.

Apply exactly the review's three findings:
1. In packages/jet_cad_2d/test/document/definition_commands_test.dart (~:601-603), make a fixture register the test component type (Tally) BEFORE registerBuiltIns(), so the snapshot's type-id sort is exercised. Fire the mutant "delete `registered.sort`" in packages/jet_cad_2d/lib/src/document/component.dart (~:166): must go red (the review saw test #8 go red).
2. Test #7: its source registry gets registerBuiltIns() and also attaches ObjectLayer(kLayer) (or the equivalent the review describes) so that restore's all-or-nothing claim is exercised. Fire the mutant "restore writes each component as it validates" (component.dart ~:187-201): must go red, with nothing changed on refusal asserted.
3. Reword the stale comment at apps/floor_planner/lib/symbols/symbol_placer.dart:78-79 ("purge and definition removal never clear one") to say orphans come from files saved before 09c (D11 now clears a removed definition's components; purge still never touches components).

Rules: `export PATH=/root/flutter/bin:$PATH`; `CI=true` on every command. Mutants: cp backup, mutate, run, cp back, `diff` exit 0; never git checkout a .dart file. Never stage analysis_options.yaml. Never synthesize output. Gates: engine (`cd packages/jet_cad_2d && CI=true dart test; CI=true dart analyze && CI=true dart format --output=none --set-exit-if-changed .`), and the app's analyze + format + `CI=true flutter test test/symbols/symbol_placer_test.dart` (the comment change only). Commit: `test(engine): pin the snapshot's order and restore's atomicity` with trailers:
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017Jpc94HDwBboPTaZBjjAFr
Do not push. Write .superpowers/sdd/plan-09c1/task-1b-report.md (commit SHA, changes, gate counts, mutant results with real output) and return it.
Scratch: /tmp/claude-0/-home-user-jet-cad/05cf1abe-1171-54e2-83cf-ffde1eb9cfc8/scratchpad/task1b/
