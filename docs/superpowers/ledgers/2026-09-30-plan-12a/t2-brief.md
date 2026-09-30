# Task 2 brief — render layer: Tool.isMidShape (plan 12a, spec D6, U-1)

You are the implementer for **Task 2** of plan 12a on branch
`plan-12a/document-lifecycle`, worktree
`/home/user/jet-cad/.claude/worktrees/plan-12a`. Work only there.

Read, in order: `CLAUDE.md`; the plan
`docs/superpowers/plans/2026-09-30-document-lifecycle.md` (the header,
"Rulings made here" P-2, "Global constraints", "Gates", and **Task 2**);
the spec `docs/superpowers/specs/2026-09-30-document-lifecycle-design.md`
D6 ("Mid-shape", U-1). Then `packages/jet_cad_2d_flutter/lib/src/tool.dart`,
`draw/placement_tool.dart`, `draw/text_tool.dart` and the render layer's
existing tool tests.

Do exactly Task 2's checklist. Render layer only: no engine or app file.
Task 1's engine change (f8e296d) is below you; another agent is reviewing
it in a separate worktree — do not touch that worktree.

Procedure (binding): mutants by `cp` to a backup under
`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/p12t2-`
(yours alone), mutate, run, `cp` back, `diff` (exit 0). NEVER `git checkout --`
a .dart file. `CI=true` on every test command; `export PATH=/root/flutter/bin:$PATH`.
Never synthesize output. Never commit `analysis_options.yaml`. Commit; do
NOT push.

Run all three packages' gates (the plan's Gates block); engine +1105 -2 and app 514
must be unchanged.

Commit message from the plan, ending with the two trailers. Write
`.superpowers/sdd/plan-12a/t2-report.md` and return it: hash; the API as
landed; every test with what it pins; every mutant with its red test and
line; gates with summaries and exit codes; deviations; anything found
outside scope (reported, not fixed).
