# Plan 3i — the zoom frame: archived ledger

**Archived on 2026-08-29, at the plan's exit gate (Task 14). Not maintained.**
This is a verbatim snapshot of `.superpowers/sdd/2026-08-26-jet-cad-2d-plan-3i-zoom-frame/`,
which is git-ignored and does not survive. Nothing appends to it afterwards.

## What is here

- **`progress.md`** — the working record, with **21 numbered rulings**, each
  with its cost-if-wrong. Rulings 14, 15, 17, 20 and 21 are the ones a later
  reader must not mistake for drift; those five are summarised in `STATUS.md`,
  the other sixteen live only here.
- **`task-N-brief.md` / `task-N-report.md`** — the dispatch and the result for
  each of the fourteen tasks (Tasks 12 and 13 split into code and device
  halves per Ruling 14).
- **`fix-*-report.md`** — eight fix waves, A through H, run after the
  whole-branch review and before the device measurements.
- **`review-<from>..<to>.diff`** — the diff package each review was taken
  against, and the review packages themselves.
- **`measurement-logs/`** — **not part of the original ledger directory.**
  The eight raw device transcripts behind every figure in
  `notes/2026-08-26-plan-3i-results.md`, copied here so the evidence outlives
  the scratch directory they were written to. They include
  **`KEEP_c8_DEGENERATE_run.log`**, the criterion-8 run that was taken, read
  and discarded under Ruling 21 — kept deliberately, because a discarded
  measurement is part of the record.

## What was committed to the repository proper instead

- The results of record:
  `docs/superpowers/notes/2026-08-26-plan-3i-results.md`.
- The mutation log, thirty-six entries and a summary table:
  `docs/superpowers/notes/plan-3i-mutation-log.md`.
- The reconciled `STATUS.md` entry, which carries the exit-gate tally, the
  accepted gaps and the gaps this plan produced.
