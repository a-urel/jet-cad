# Review brief — plan 12a, Task 9 (code part) (c6c3445 (with e678183 below it))

You are the independent reviewer of Task 9 (code part) of plan 12a. Review in the
detached worktree `/home/user/jet-cad/.claude/worktrees/plan-12a-review`
(HEAD = the commit under review). Do not commit, do not push, do not touch
the branch worktree `/home/user/jet-cad/.claude/worktrees/plan-12a` except to
write your review file into its `.superpowers/sdd/plan-12a/`.

Read `CLAUDE.md`; the plan `docs/superpowers/plans/2026-09-30-document-lifecycle.md`
(Task 9 (code part) and its global sections); the spec
`docs/superpowers/specs/2026-09-30-document-lifecycle-design.md` (the
decisions Task 9 (code part) implements); the task brief `t9-brief.md` and the
implementer's `t9-report.md` in the ledger directory. The report's claims are
not evidence: verify each one yourself.

Check: the diff does what the plan's Task 9 (code part) says and nothing else; spec
conformance; tests non-degenerate (CLAUDE.md's testing bar) and each named
mutant really red where claimed — re-fire at least the task's named mutants
yourself and add your own at seams they miss; no regression (gates);
anything the implementer missed. Procedure (binding): mutants by `cp` to a
backup under `/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/p12r9-`,
mutate, run, `cp` back, `diff` exit 0. NEVER `git checkout --` a .dart
file. `CI=true` on every test command; `export PATH=/root/flutter/bin:$PATH`.
pub get may be needed; leave no tracked change but the known
`analysis_options.yaml` rewrites. Never synthesize output.

Write `t9-review.md` in the ledger directory and return it: verdict
(Approved / Needs fixes), Important and minor findings with evidence,
mutants fired with red test and line, gates run.
Scope: 5998504..c6c3445 (two commits). Check each of the brief's 13 carried items landed and is pinned by a mutant; re-fire a sample of the sweep's mutants (at least M-12a-2, 10, 13, 19, 24, 26, 28 and the carried items' R3/R7/R6/Y1/Y2/Y8/Y9/old-layout) and run the greps yourself; judge deviations (item 3 pubspec, item 5 layout, item 6, DF7). Include `CI=true flutter build web --release`. The controller edits docs/ in the branch worktree meanwhile — touch nothing there but your review file.
