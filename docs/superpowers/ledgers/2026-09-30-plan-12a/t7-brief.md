# Task 7 brief — app: settling pending input (plan 12a, spec D2 settle, T-1, T-4, U-1, U-2)

You are the implementer for **Task 7** of plan 12a on branch
`plan-12a/document-lifecycle`, worktree
`/home/user/jet-cad/.claude/worktrees/plan-12a`. Work only there.

Read, in order: `CLAUDE.md`; the plan
`docs/superpowers/plans/2026-09-30-document-lifecycle.md` (the header,
"Rulings made here" P-2, "Global constraints", "Gates", and **Task 7**, P-3–P-6);
the spec `docs/superpowers/specs/2026-09-30-document-lifecycle-design.md`
**whole** (D2's settle and pending-input rules in full, with S-4, S-5,
S-19, T-1, T-4, T-13, U-1, U-2, R-5, R-9; the Testing entries this task
owns; M-12a-11, 22, 28, 29). Then the ledger's `t5-report.md`,
`t6-report.md` (the registrar, `debugOnSettle`, the Undo/Redo re-read,
the toolbar's `TextFieldTapRegion`), `t2-review.md` (m-1: the Text tool's
`isMidShape` never read after typing), and `apps/floor_planner/lib/main.dart`,
`document_host.dart`, `text_entry_overlay.dart`, `page_panel.dart`,
`selection_panel.dart`, `panel_focus.dart`, and
`packages/jet_cad_2d_flutter/lib/src/draw/text_tool.dart`.

Do exactly Task 7's checklist. Also, from the Task 6 report's findings:
**when the route scope (not the canvas) holds focus — for example after a
text entry's plain unfocus — the file chords are consumed above the
Navigator and run nothing**. Find whether any ordinary path leaves focus
there (a text entry committed or cancelled, a toolbar tap, a dialog
closed, a panel field handed back); if one does, the settle or the
hand-back must return focus to the canvas, with a test that Cmd+S after
that path saves; if none does, show it in the report. Decide whether
`debugOnSettle` stays (keep it only if a test still needs it). Earlier
tasks are below you; other agents review in separate worktrees — do not
touch them. **Also run `CI=true flutter build web --release`.**

Procedure (binding): mutants by `cp` to a backup under
`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/p12t7-`
(yours alone), mutate, run, `cp` back, `diff` (exit 0). NEVER `git checkout --`
a .dart file. `CI=true` on every test command; `export PATH=/root/flutter/bin:$PATH`.
Never synthesize output. Never commit `analysis_options.yaml`. Commit; do
NOT push.

Run all three packages' gates (the plan's Gates block); engine +1106 -2 and render
+974 ~1 -7 must be unchanged; app at the branch HEAD's count + your new
tests (every existing test stays green).

Commit message from the plan, ending with the two trailers. Write
`.superpowers/sdd/plan-12a/t7-report.md` and return it: hash; the API as
landed; every test with what it pins; every mutant with its red test and
line; gates with summaries and exit codes; deviations; anything found
outside scope (reported, not fixed).
