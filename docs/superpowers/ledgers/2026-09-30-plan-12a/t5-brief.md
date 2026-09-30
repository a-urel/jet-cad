# Task 5 brief — app: the session, the host, the swap, Open and Save (plan 12a, spec D2, D5, D8, D13)

You are the implementer for **Task 5** of plan 12a on branch
`plan-12a/document-lifecycle`, worktree
`/home/user/jet-cad/.claude/worktrees/plan-12a`. Work only there.

Read, in order: `CLAUDE.md`; the plan
`docs/superpowers/plans/2026-09-30-document-lifecycle.md` (the header,
"Rulings made here" P-2, "Global constraints", "Gates", and **Task 5**, P-3, P-4, P-5, P-6);
the spec `docs/superpowers/specs/2026-09-30-document-lifecycle-design.md`
**whole** (D1, D2, D5, D8, D13 in full; the Testing section's entries this
task owns; M-12a-1, 2 (save half), 3, 4, 7, 7b, 8, 13, 16, 17, 18, 19, 20,
21). Then `apps/floor_planner/lib/main.dart`, `planner_view.dart`,
`new_document.dart`, `document_files.dart`, `test/support/fake_document_files.dart`,
`test/planner_shell_test.dart`, and the ledger's `t3-review.md` (m1) and
`t4-report.md`.

Do exactly Task 5's checklist. This is the largest task: keep the shell's
existing behaviour for a bare `PlannerShell(document: doc)` (ten test files
depend on it) and prove it by the full app suite. Notes from earlier
reviews: `main.dart:64`'s fallback must switch from `startupPlan` to
`newDocument` (Task 3 review m1); `startup_plan.dart:26-28` still calls the
sample "the fixture a human looks at every session" — correct it.
Settle (Task 7) and the replace dialog (Task 8) are later: leave a
`settle` hook that is a no-op here, and replace unconditionally. Flows
that need a name prompt on web get it from the host (a simple dialog is
enough here; Task 6/8 may restyle). Earlier tasks are below you; another
agent reviews Task 4 in a separate worktree — do not touch it. **Also run
`CI=true flutter build web --release`.**

Procedure (binding): mutants by `cp` to a backup under
`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/p12t5-`
(yours alone), mutate, run, `cp` back, `diff` (exit 0). NEVER `git checkout --`
a .dart file. `CI=true` on every test command; `export PATH=/root/flutter/bin:$PATH`.
Never synthesize output. Never commit `analysis_options.yaml`. Commit; do
NOT push.

Run all three packages' gates (the plan's Gates block); engine +1106 -2 and render
+974 ~1 -7 must be unchanged; app 526 + your new tests (minus none: every
existing test stays, planner_shell_test migrated per the plan).

Commit message from the plan, ending with the two trailers. Write
`.superpowers/sdd/plan-12a/t5-report.md` and return it: hash; the API as
landed; every test with what it pins; every mutant with its red test and
line; gates with summaries and exit codes; deviations; anything found
outside scope (reported, not fixed).
