# Plan 3f ledger — text wiring and level of detail

Archived on 2026-08-23, on `main`, before the working directory
`.superpowers/sdd/2026-08-22-jet-cad-2d-plan-3f-text/` was removed. That
ordering is deliberate: Plan 3e recorded that archiving after deleting the
workspace loses the record entirely.

- **Spec (binding authority):**
  [docs/superpowers/specs/2026-08-22-jet-cad-2d-plan-3f-text-design.md](../../specs/2026-08-22-jet-cad-2d-plan-3f-text-design.md)
- **Plan:**
  [docs/superpowers/plans/2026-08-22-jet-cad-2d-plan-3f-text.md](../../plans/2026-08-22-jet-cad-2d-plan-3f-text.md)
- **Results of record:**
  [docs/superpowers/notes/2026-08-22-plan-3f-results.md](../../notes/2026-08-22-plan-3f-results.md)
- **Mutation log:**
  [docs/superpowers/notes/plan-3f-mutation-log.md](../../notes/plan-3f-mutation-log.md)

## What is here

`progress.md` is the controller's ledger: the pre-flight conflict scan, every
ruling with what it would cost if wrong, every deferred minor, and one entry
recording where the controller was wrong and was corrected by an implementer.

`task-N-brief.md` is the task's requirements as extracted from the plan;
`task-N-report.md` is what the implementer wrote back, including its fix rounds.
`review-<base>..<head>.diff` is the package each reviewer was handed — the
commit list, the stat summary and the full diff with context.

## The shape of the run

Nine tasks, twenty-five commits from `2db538d` to `bce35c7`. Six tasks needed a
fix round; Task 6 and Task 8 needed two. The final whole-branch review found
**no Critical** — the cross-task defect that Plan 3e's whole-branch review caught
after seventeen clean per-task reviews has no counterpart here — and one
Important, which the single fix wave closed.

The exit gate closed **11 of 13**. Two criteria miss and were recorded rather
than tuned: at the shipped threshold the whole-drawing camera still re-lays out
3,876 paragraphs per repeat frame against a bar of zero. The threshold was
chosen from a readability argument, so moving it to make a row pass is the
failure the plan's stop clause exists to prevent, and the one permitted
`kParagraphCacheLimit` raise was left unspent as the human's decision.

Three agents were killed mid-run by infrastructure rather than by the work —
one machine sleep and two stream stalls, all on Task 7. None cost anything,
because nothing had been written when they died and the tree was verified clean
each time.
