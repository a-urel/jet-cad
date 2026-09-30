# Review brief — plan 12a, Task 7 (725ff74)

You are the independent reviewer of Task 7 of plan 12a. Review in the
detached worktree `/home/user/jet-cad/.claude/worktrees/plan-12a-review`
(HEAD = the commit under review). Do not commit, do not push, do not touch
the branch worktree `/home/user/jet-cad/.claude/worktrees/plan-12a` except to
write your review file into its `.superpowers/sdd/plan-12a/`.

Read `CLAUDE.md`; the plan `docs/superpowers/plans/2026-09-30-document-lifecycle.md`
(Task 7 and its global sections); the spec
`docs/superpowers/specs/2026-09-30-document-lifecycle-design.md` (the
decisions Task 7 implements); the task brief `t7-brief.md` and the
implementer's `t7-report.md` in the ledger directory. The report's claims are
not evidence: verify each one yourself.

Check: the diff does what the plan's Task 7 says and nothing else; spec
conformance; tests non-degenerate (CLAUDE.md's testing bar) and each named
mutant really red where claimed — re-fire at least the task's named mutants
yourself and add your own at seams they miss; no regression (gates);
anything the implementer missed. Procedure (binding): mutants by `cp` to a
backup under `/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/p12r7-`,
mutate, run, `cp` back, `diff` exit 0. NEVER `git checkout --` a .dart
file. `CI=true` on every test command; `export PATH=/root/flutter/bin:$PATH`.
pub get may be needed; leave no tracked change but the known
`analysis_options.yaml` rewrites. Never synthesize output.

Write `t7-review.md` in the ledger directory and return it: verdict
(Approved / Needs fixes), Important and minor findings with evidence,
mutants fired with red test and line, gates run.
Read spec D2 whole (the settle and pending-input rules). Also fire the Task 6 review's R1 (ShellShortcutGuard also lists kFileChords, so Cmd+S in a panel field would be swallowed) against ST1 — it must go red now. Judge the route-scope fix in text_entry_overlay.dart (does it reproduce the framework's platform rule exactly, see editable_text.dart's tap-outside action) and the six deviations. Include `CI=true flutter build web --release`. Pointer-path tests must follow P-6 (macOS, mouse). Another agent (Task 8) works in the branch worktree — touch nothing there but your review file.
