# Task 1 brief — engine: the state identity (plan 12a, spec D3)

You are the implementer for **Task 1** of plan 12a on branch
`plan-12a/document-lifecycle`, worktree
`/home/user/jet-cad/.claude/worktrees/plan-12a`. Work only there.

Read, in order: `CLAUDE.md`; the plan
`docs/superpowers/plans/2026-09-30-document-lifecycle.md` (the header,
"Rulings made here" P-2, "Global constraints", "Gates", and **Task 1**);
the spec `docs/superpowers/specs/2026-09-30-document-lifecycle-design.md`
D3 (and its Testing/Named mutants entries M-12a-5, 6, 14). Then
`packages/jet_cad_2d/lib/src/document/undo.dart` and every caller of
`UndoStack` (grep the whole repo, tests included).

Do exactly Task 1's checklist. Engine only: no render or app file changes
(if an app/render test calls a removed primitive, stop and report).

Procedure (binding): mutants by `cp` to a backup under
`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/p12t1-`
(yours alone), mutate, run, `cp` back, `diff` (exit 0). NEVER `git checkout --`
a .dart file. `CI=true` on every test command; `export PATH=/root/flutter/bin:$PATH`.
Never synthesize output. Never commit `analysis_options.yaml`. Commit; do
NOT push.

Run all three packages' gates (the plan's Gates block); render and app must
be unchanged in count (render 940 + 1 skip + 7 standing, app 514).

Commit message from the plan, ending with the two trailers. Write
`.superpowers/sdd/plan-12a/t1-report.md` and return it: hash; the API as
landed; every test with what it pins; every mutant with its red test and
line; gates with summaries and exit codes; deviations; anything found
outside scope (reported, not fixed).
