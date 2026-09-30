# Task 9b brief — the narrow-window floor and DC12b's premise (plan 12a)

You are the implementer for **Task 9b** of plan 12a on branch
`plan-12a/document-lifecycle`, worktree
`/home/user/jet-cad/.claude/worktrees/plan-12a` (HEAD `2d57d22`). Work only
there. Read `CLAUDE.md`; spec D7 and its "Amended at execution" D7 line
(`docs/superpowers/specs/2026-09-30-document-lifecycle-design.md`);
`.superpowers/sdd/plan-12a/t9-report.md` (item 5) and `t9-review.md`
(m-1, m-2) and the last entries of `progress.md`.

You do not edit `docs/`, `roadmap/` or `STATUS.md`.

## m-1 — the bar must be no worse than before in a narrow window

Task 9's layout (`apps/floor_planner/lib/main.dart`, the `chrome-top` Row,
~`:684-720`) first overflows at 622 px wide; the `5998504` bar first
overflowed at 590 px. Causes (the reviewer's probe): a fixed
`SizedBox(width: 16)` before OSNAP replaced a `Spacer` (min 0), and the
name's `maxWidth: constraints.maxWidth / 2` plus its fixed 16 px gap
overflows once the shared width is below 32 px.

Fix so that, with a titled document with a long name and a long status,
the bar's first overflow is at **or below 590 px** (the old floor), while
keeping Task 9's intent at 800 × 600 and 1440 × 900 (the name capped at
half of the shared width and taking only what it needs, the status the
rest; DC12, DC12b unchanged in what they assert). Suggested (the
reviewer's): cap the name at `max(0, (W - 16) / 2)` where W is the shared
width, and give the gaps a way to shrink — your choice of mechanism, but
keep the 16 px gaps at ordinary widths (DC12b asserts
`status.left - name.right == 16`).

Pin it: a test (in `document_commands_test.dart`, next to DC12b, name it
DC12c) that sets the surface to the old floor width (590 × 600 or the
exact floor you measure, say which), a titled long name, a status line,
and asserts `tester.takeException()` is null and the row lays out (OSNAP
and zoom visible). Fire: (a) the Task 9 layout as it is at `2d57d22`
(copy `main.dart` to a backup first) — DC12c red; (b) the fixed OSNAP gap
restored alone and (c) the uncapped `/ 2` restored alone — each red if the
fix addresses it (if one of them is not observable at the floor you pin,
say so and why). Re-fire the reviewer's "old layout" and "halves" mutants
(t9-review.md item 5) — still red at DC12b.

Report the measured first-overflow width on your final tree (a temporary
probe that steps the width down; do not commit it).

## m-2 — DC12b's premise must measure the text

`document_commands_test.dart:927-928`: `paragraph(status).size.width` is
the Expanded slot's width, not the text's. Make the premise read the
text's own width (e.g. `paragraph(status).getMaxIntrinsicWidth(double.infinity)`,
or a `TextPainter` with the same style) and confirm it holds on the final
tree. Show that it now can go red: a mutant of the fixture (a short room
name, e.g. `'den'`) turns the premise red at that line.

## Procedure (binding)

Mutants by `cp` to a backup under
`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/p12t9b-`
(yours alone), mutate, run, `cp` back, `diff` (exit 0); restore in a
`finally`. NEVER `git checkout --` a .dart file. `export
PATH=/root/flutter/bin:$PATH`; `CI=true` on every test command. Never
synthesize output. Never commit `analysis_options.yaml`. One commit
`fix(app): the top bar lays out down to the old narrow-window floor` with
the trailers:

    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
    Claude-Session: https://claude.ai/code/session_013XiH3QE4FtMMNUjbASxiEv

Do NOT push. Gates: the app package (`flutter test`, `flutter analyze`,
`dart format --output=none --set-exit-if-changed .`) and `flutter build
web --release`; the engine and render packages are untouched (say so via
`git diff --stat`). Write `.superpowers/sdd/plan-12a/t9b-report.md` and
return it.
