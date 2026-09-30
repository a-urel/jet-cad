# Review brief — plan 12a, Task 5b (15cdbea)

You are the independent reviewer of Task 5b of plan 12a. Review in the
detached worktree `/home/user/jet-cad/.claude/worktrees/plan-12a-review2`
(HEAD = the commit under review). Do not commit, do not push, do not touch
the branch worktree `/home/user/jet-cad/.claude/worktrees/plan-12a` except to
write your review file into its `.superpowers/sdd/plan-12a/`.

Read `CLAUDE.md`; the plan `docs/superpowers/plans/2026-09-30-document-lifecycle.md`
(Task 5b and its global sections); the spec
`docs/superpowers/specs/2026-09-30-document-lifecycle-design.md` (the
decisions Task 5b implements); the task brief `t5b-brief.md` and the
implementer's `t5b-report.md` in the ledger directory. The report's claims are
not evidence: verify each one yourself.

Check: the diff does what the plan's Task 5b says and nothing else; spec
conformance; tests non-degenerate (CLAUDE.md's testing bar) and each named
mutant really red where claimed — re-fire at least the task's named mutants
yourself and add your own at seams they miss; no regression (gates);
anything the implementer missed. Procedure (binding): mutants by `cp` to a
backup under `/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/p12r5b-`,
mutate, run, `cp` back, `diff` exit 0. NEVER `git checkout --` a .dart
file. `CI=true` on every test command; `export PATH=/root/flutter/bin:$PATH`.
pub get may be needed; leave no tracked change but the known
`analysis_options.yaml` rewrites. Never synthesize output.

Write `t5b-review.md` in the ledger directory and return it: verdict
(Approved / Needs fixes), Important and minor findings with evidence,
mutants fired with red test and line, gates run.
Also read t5-review.md (I-1, m-1, m-2, m-4). Scope: the two test files; confirm R3, R1, R10 red, and whether Task 5 (efb8700 + 15cdbea together) can now be Approved. Another reviewer uses .claude/worktrees/plan-12a-review and an implementer the branch worktree — touch neither.
