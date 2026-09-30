# Task 6 brief — app: the command table, the toolbar, the shortcuts (plan 12a, spec D6, D7)

You are the implementer for **Task 6** of plan 12a on branch
`plan-12a/document-lifecycle`, worktree
`/home/user/jet-cad/.claude/worktrees/plan-12a`. Work only there.

Read, in order: `CLAUDE.md`; the plan
`docs/superpowers/plans/2026-09-30-document-lifecycle.md` (the header,
"Rulings made here" P-2, "Global constraints", "Gates", and **Task 6**, P-3–P-6);
the spec `docs/superpowers/specs/2026-09-30-document-lifecycle-design.md`
**whole** (D6 and D7 in full with T-2, T-3, T-5, T-6, U-1, U-2, U-3, U-6,
S-7, S-8, S-26; the Testing entries this task owns; M-12a-9, 12, 15, 23,
24, 29, 30, 31). Then the ledger's `t5-report.md` (the session/host API as
landed: `DocumentSession`, `DocumentHost`, the flows, `ShellSettleRegistrar`,
`documentName`/`dirty`/`busy` on the shell) and `t2-report.md`
(`Tool.isMidShape`), and `apps/floor_planner/lib/main.dart`,
`document_host.dart`, `shortcut_guard.dart`, `tool_palette.dart`.

Do exactly Task 6's checklist. The settle itself is Task 7: Undo/Redo call
the registered settle hook (a no-op until Task 7) then re-read
`canUndo`/`canRedo` (U-2). Replace `main.dart`'s `_undo` binding and its
"There is no redo in 02" comment. Add the `TextFieldTapRegion` around the
toolbar here (Task 7 tests it). Earlier tasks are below you; another agent
reviews Task 5 in a separate worktree — do not touch it. **Also run
`CI=true flutter build web --release`.**

Procedure (binding): mutants by `cp` to a backup under
`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/p12t6-`
(yours alone), mutate, run, `cp` back, `diff` (exit 0). NEVER `git checkout --`
a .dart file. `CI=true` on every test command; `export PATH=/root/flutter/bin:$PATH`.
Never synthesize output. Never commit `analysis_options.yaml`. Commit; do
NOT push.

Run all three packages' gates (the plan's Gates block); engine +1106 -2 and render
+974 ~1 -7 must be unchanged; app 545 + your new tests (every existing
test stays green).

Commit message from the plan, ending with the two trailers. Write
`.superpowers/sdd/plan-12a/t6-report.md` and return it: hash; the API as
landed; every test with what it pins; every mutant with its red test and
line; gates with summaries and exit codes; deviations; anything found
outside scope (reported, not fixed).
