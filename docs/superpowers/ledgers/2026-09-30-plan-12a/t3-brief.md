# Task 3 brief — app: the set-up helper, the default page, the registration (plan 12a, spec D4, D8)

You are the implementer for **Task 3** of plan 12a on branch
`plan-12a/document-lifecycle`, worktree
`/home/user/jet-cad/.claude/worktrees/plan-12a`. Work only there.

Read, in order: `CLAUDE.md`; the plan
`docs/superpowers/plans/2026-09-30-document-lifecycle.md` (the header,
"Rulings made here" P-2, "Global constraints", "Gates", and **Task 3**);
the spec `docs/superpowers/specs/2026-09-30-document-lifecycle-design.md`
D4 and D8 ("Register", S-1), spec 10 D3 on the DASHED record, and the
Testing entries for launch/New. Then `apps/floor_planner/lib/startup_plan.dart`,
`parametric/catalog.dart`, `parametric/separator.dart` (`ensureDashedLinetype`),
`packages/jet_cad_2d/lib/src/.../page_component.dart` and
`apps/floor_planner/test/startup_plan_test.dart`.

Do exactly Task 3's checklist. App only; no engine or render file. Tasks 1
and 2 are below you (f8e296d, 1fce8b7, 06c9c44); another agent reviews in
a separate worktree — do not touch it. Confirm `startupPlan`'s bytes are
unchanged by encoding it before and after your change (report the byte
counts and equality), without adding a test for it.

Procedure (binding): mutants by `cp` to a backup under
`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/p12t3-`
(yours alone), mutate, run, `cp` back, `diff` (exit 0). NEVER `git checkout --`
a .dart file. `CI=true` on every test command; `export PATH=/root/flutter/bin:$PATH`.
Never synthesize output. Never commit `analysis_options.yaml`. Commit; do
NOT push.

Run all three packages' gates (the plan's Gates block); engine +1106 -2 and render
+974 ~1 -7 must be unchanged; app 514 + your new tests.

Commit message from the plan, ending with the two trailers. Write
`.superpowers/sdd/plan-12a/t3-report.md` and return it: hash; the API as
landed; every test with what it pins; every mutant with its red test and
line; gates with summaries and exit codes; deviations; anything found
outside scope (reported, not fixed).
