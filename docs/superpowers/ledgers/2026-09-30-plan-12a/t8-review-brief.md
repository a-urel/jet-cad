# Review brief — plan 12a, Task 8 (5998504)

You are the independent reviewer of Task 8 of plan 12a. Review in the
detached worktree `/home/user/jet-cad/.claude/worktrees/plan-12a-review`
(HEAD = the commit under review). Do not commit, do not push, do not touch
the branch worktree `/home/user/jet-cad/.claude/worktrees/plan-12a` except to
write your review file into its `.superpowers/sdd/plan-12a/`.

Read `CLAUDE.md`; the plan `docs/superpowers/plans/2026-09-30-document-lifecycle.md`
(Task 8 and its global sections); the spec
`docs/superpowers/specs/2026-09-30-document-lifecycle-design.md` (the
decisions Task 8 implements); the task brief `t8-brief.md` and the
implementer's `t8-report.md` in the ledger directory. The report's claims are
not evidence: verify each one yourself.

Check: the diff does what the plan's Task 8 says and nothing else; spec
conformance; tests non-degenerate (CLAUDE.md's testing bar) and each named
mutant really red where claimed — re-fire at least the task's named mutants
yourself and add your own at seams they miss; no regression (gates);
anything the implementer missed. Procedure (binding): mutants by `cp` to a
backup under `/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/p12r8-`,
mutate, run, `cp` back, `diff` exit 0. NEVER `git checkout --` a .dart
file. `CI=true` on every test command; `export PATH=/root/flutter/bin:$PATH`.
pub get may be needed; leave no tracked change but the known
`analysis_options.yaml` rewrites. Never synthesize output.

Write `t8-review.md` in the ledger directory and return it: verdict
(Approved / Needs fixes), Important and minor findings with evidence,
mutants fired with red test and line, gates run.
Read spec D10, D11, D12, D14 whole. The implementer reports an incident (an interrupted mutant run left a mutant in lib/document_host.dart, restored from its backup): read the full diff 725ff74..5998504 of document_host.dart line by line and confirm no mutant remains. Judge the differsFromSave fix (is dirty read anywhere else where it could be stale?), the three migrated tests (weakened?), the seven deviations. Include `CI=true flutter build web --release`. Review the Swift edit by reading (it cannot be built here).
