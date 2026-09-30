# Review brief — plan 12a, Task 5 (efb8700)

You are the independent reviewer of Task 5 of plan 12a. Review in the
detached worktree `/home/user/jet-cad/.claude/worktrees/plan-12a-review`
(HEAD = the commit under review). Do not commit, do not push, do not touch
the branch worktree `/home/user/jet-cad/.claude/worktrees/plan-12a` except to
write your review file into its `.superpowers/sdd/plan-12a/`.

Read `CLAUDE.md`; the plan `docs/superpowers/plans/2026-09-30-document-lifecycle.md`
(Task 5 and its global sections); the spec
`docs/superpowers/specs/2026-09-30-document-lifecycle-design.md` (the
decisions Task 5 implements); the task brief `t5-brief.md` and the
implementer's `t5-report.md` in the ledger directory. The report's claims are
not evidence: verify each one yourself.

Check: the diff does what the plan's Task 5 says and nothing else; spec
conformance; tests non-degenerate (CLAUDE.md's testing bar) and each named
mutant really red where claimed — re-fire at least the task's named mutants
yourself and add your own at seams they miss; no regression (gates);
anything the implementer missed. Procedure (binding): mutants by `cp` to a
backup under `/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/p12r5-`,
mutate, run, `cp` back, `diff` exit 0. NEVER `git checkout --` a .dart
file. `CI=true` on every test command; `export PATH=/root/flutter/bin:$PATH`.
pub get may be needed; leave no tracked change but the known
`analysis_options.yaml` rewrites. Never synthesize output.

Write `t5-review.md` in the ledger directory and return it: verdict
(Approved / Needs fixes), Important and minor findings with evidence,
mutants fired with red test and line, gates run.
Task 5 is the plan's largest task: read spec D2, D5, D8, D13 whole. Confirm the Task 3 review's m1 (a bare shell's fallback is `newDocument`) and the Task 4 review's n-1 (web Save passes a location) and n-2 (main.dart imports document_files.dart; the web build compiles `_web`). Judge the nine deviations. Include `CI=true flutter build web --release`. Look hard at the keyed swap (old-document disposal timing, measurer clearing, settle registrar release), the busy span, and whether any existing test was weakened by the migration.
