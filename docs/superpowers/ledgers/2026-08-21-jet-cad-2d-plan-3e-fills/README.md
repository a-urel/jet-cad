# Plan 3e ledger — solid fills

Archived on 2026-08-22, at the close of the plan, from
`.superpowers/sdd/2026-08-21-jet-cad-2d-plan-3e-fills/` — a git-ignored scratch
directory that does not survive `git clean -fdx`.

**Why this is kept rather than deleted.** The conclusions live in
[`../../notes/2026-08-22-plan-3e-results.md`](../../notes/2026-08-22-plan-3e-results.md)
and [`../../notes/plan-3e-mutation-log.md`](../../notes/plan-3e-mutation-log.md).
What lives *only* here is the working record: `progress.md` with the
per-task rulings, the seventeen task briefs and reports, the final fix report,
and every review package the reviewers actually read. A results note says what
was concluded; this says what was tried, what was measured, and what was
decided when the plan and the tree disagreed.

## What is here

- `progress.md` — the ledger. Pre-flight conflict scan, every task's dispatch,
  report, review verdict and fix round, and every `Ruling:` made during
  execution with what it costs if wrong.
- `task-N-brief.md` / `task-N-report.md` — the requirements each implementer
  was given, and what it reported back, with verbatim transcripts.
- `task-3-mutations.md`, `task-8-fix-matrix.md` — mutation transcripts the
  controller ran when an implementer could not.
- `final-fix-report.md` — the wave that closed the whole-branch review's
  Critical and two Importants.
- `review-*.diff` — the exact package each reviewer read.

## The two things worth reading first

**The Critical the seventeen per-task reviews all missed**, in `progress.md`'s
final section: `AddEntityCommand` never linked a fill, and it was
`RemoveEntityCommand`'s inverse for one. It survived because every fill-removal
fixture removed the *boundary* — the degenerate fixture, one level up.

**Three times a measuring harness, not the code, produced a confident wrong
answer**: a half-mutated test file made every run fail to *load* and read as
four kills; a guard matched `dart test`'s own `loading test/...` progress line;
and a shell array indexed from 0 in zsh, where arrays are 1-based, shifted five
verdicts by one. All three are recorded where they happened.
