# Plan 3d — the vertices sink

Archived on merge. A snapshot of what was true when `spike/vertices-sink`
landed; nothing appends to it afterwards.

## What is here

- `progress.md` — the controller's ledger for all fifteen tasks: every
  finding, every deferred minor, and **fourteen rulings**, each with what it
  would cost if wrong.
- `task-<N>-brief.md` — the task text each implementer worked from, extracted
  from the plan.
- `task-<N>-report.md` — what each implementer did, its TDD evidence, and the
  fix reports appended after each review round.
- `final-fix-report.md` — the fix wave from the whole-branch review.
- `review-<from>..<to>.diff` — the exact package each of the twenty-six
  reviews was taken against, commit list and full diff.

## What is deliberately not here

`task-13-raw/` held the web measurement's raw capture and its retrieval
scripts. Those are **committed to the repository proper**, at
`docs/superpowers/notes/2026-08-21-plan-3d-web-raw/`, because the published
web rows cannot be re-taken from the committed harness path and a row nobody
can check is not a measurement. They are not duplicated here.

## Reading it

The results of record are in `docs/superpowers/notes/`:
`2026-08-21-plan-3d-results.md` (the eight exit criteria, the desktop and web
rows, and what failed) and `plan-3d-mutation-log.md` (forty-one mutants, with
the survivors and the unreachable branches named as such).

This directory is the working record those were drawn from. The place to
start is `progress.md`.
