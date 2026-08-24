# Plan 3g ledger — the rasterised tile cache

Archived 2026-08-24, on merge, from `.superpowers/sdd/2026-08-23-jet-cad-2d-plan-3g-tile-cache/`.
Never appended to after this point.

**Plan:** [../../plans/2026-08-23-jet-cad-2d-plan-3g-tile-cache.md](../../plans/2026-08-23-jet-cad-2d-plan-3g-tile-cache.md)
**Spec:** [../../specs/2026-08-23-jet-cad-2d-plan-3g-tile-cache-design.md](../../specs/2026-08-23-jet-cad-2d-plan-3g-tile-cache-design.md)
**Results:** [../../notes/2026-08-24-plan-3g-results.md](../../notes/2026-08-24-plan-3g-results.md)
**Mutation log:** [../../notes/plan-3g-mutation-log.md](../../notes/plan-3g-mutation-log.md)
**Why the plan exists at all:** [../../notes/2026-08-23-picture-cache-price-spike.md](../../notes/2026-08-23-picture-cache-price-spike.md)

## What is here

`progress.md` is the controller's ledger: the pre-flight conflict scan, **twenty-two
numbered rulings** each with what it would cost if wrong, every deferred minor with
its triage, and the notes each task carried to the next. It is the record of every
decision taken on the human's behalf while the plan ran.

`task-N-brief.md` is what each implementer was given; `task-N-report.md` is what it
returned, including every mutation transcript. Tasks **6a, 9a and 11a** have reports
and no briefs: they did not exist in the plan and were inserted mid-flight — 6a and
9a because a task found something that touched the scope of a criterion, 11a because
a measurement's answer invalidated a neighbouring constant.

`final-fix-report.md` covers the whole-plan review's single fix wave and its
follow-up.

## The one thing worth reading if you read nothing else

The results note's closing section. The dominant finding of this execution was not
any single defect: **thirteen times a gate turned out unable to see what it claimed
to measure**, each in a different disguise, and the note carries the taxonomy and the
questions that find them. The thirteenth was the controller's own — writing a
reviewer's claim into this ledger as verified fact.
