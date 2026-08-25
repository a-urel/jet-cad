# Plan 3h ledger — the pan frame

Archived 2026-08-26, on merge, from `.superpowers/sdd/2026-08-25-jet-cad-2d-plan-3h-pan-frame/`.
Never appended to after this point.

**Plan:** [../../plans/2026-08-25-jet-cad-2d-plan-3h-pan-frame.md](../../plans/2026-08-25-jet-cad-2d-plan-3h-pan-frame.md)
**Spec:** [../../specs/2026-08-25-jet-cad-2d-plan-3h-pan-frame-design.md](../../specs/2026-08-25-jet-cad-2d-plan-3h-pan-frame-design.md)
**Results:** [../../notes/2026-08-25-plan-3h-results.md](../../notes/2026-08-25-plan-3h-results.md)
**Mutation log:** [../../notes/plan-3h-mutation-log.md](../../notes/plan-3h-mutation-log.md)

## What is here

`progress.md` is the controller's ledger: the pre-flight conflict scan,
**nineteen numbered rulings** each with what it would cost if wrong, and the
notes each task carried to the next. `task-N-brief.md` is what each
implementer was given; `task-N-report.md` is what it returned. Task **8a**
and **8b** have reports and no separate briefs of their own — see below.
`final-fix-report.md` covers the whole-branch review's single fix wave;
`record-fix-report.md` covers a second, later dispatch that touched only
prose and test doc comments, never code — see Ruling 18.

## What is unusual about this record

**Task 1 dissolved, Task 8 split — both for the same reason.** The plan was
written as eight tasks, but the machine spent much of the run on battery with
Low Power Mode auto-enabling itself mid-session (Ruling 6, Ruling 9). Task 1
was blocked at its first step and never ran as its own task: Ruling 6 folded
its device baseline into Task 7's M4 arm (measured in the same session as the
narrowed arm — methodologically stronger than a separate baseline anyway),
and Ruling 8 then dissolved what was left of it (a `STATUS.md` renumbering)
into Tasks 7 and 8, because every one of its remaining steps already belonged
to a later task. Task 8 itself later split into **8a** (everything
machine-independent — four of the five mutants, the full-suite verification)
and **8b** (the device-bound remainder), for the identical reason: mains
power was the user's to restore, and stalling the whole plan on it bought
nothing. Read Rulings 4, 6, 8 and 9 in sequence for the full chain.

**Six mutants, four killed clean, two survivors, one found by a reviewer
after the plan was written.** M1 and M3 killed as designed; M2 is a
pre-committed survivor (Ruling 5 records why weakening the fixture to force
it dead would be worse than leaving it). **M5 does not appear in the plan at
all** — a reviewer found, while reviewing Task 5, that the sweep could catch
a narrowed query shrinking but not growing, which would have silently let
the plan's entire headline change (the fallback walks a strip, not the whole
viewport) regress to a no-op with every test green (Ruling 7). The gate built
to kill it — a triangle-count-ratio check — turned out, in Task 7, to also be
the thing that caught **M4**, even though the plan and the mutation log had
both asserted M4 had no unit witness. `progress.md`'s Task 7 entry and
Ruling 10 both flag the contradiction as it was found.

**Ruling 15, a correction, was itself wrong and had to be withdrawn.**
The final review found two suite counts in the mutation log it could not
reproduce and Ruling 15 corrected them. The implementer's own re-fire of M2
then disagreed with the re-reviewer's count, and rather than paper over the
discrepancy it recorded both and stopped. The controller broke the tie by
firing the mutant itself and by arithmetic — passed + failed + skipped must
equal the suite's fixed size, and only the log's original figure satisfies
that identity. **Ruling 19 withdraws Ruling 15**, restores the log's original
numbers, and closes the discrepancy notes as resolved rather than open. It is
the only ruling in this plan's record that reverses an earlier one on hard
evidence rather than superseding it by circumstance.

**The headline criterion missed, and the controller ruled the miss stands.**
Criterion 3 (the fallback should cost ≤ 2.4× the unnarrowed walk) measured
**2.35**. Ruling 10 holds three things true at once: the criterion as written
was not met; the measurement cannot settle it either way at n=3, where a
19.7%-CV denominator puts the pairwise ratios anywhere from 1.82 to 2.84; and
the gate itself was mis-derived — 2.4 traced back to a cross-session baseline
from an earlier spike, which is exactly the kind of comparison the spec had
switched to a ratio to avoid. The mean is recorded in the note as evidence
the effect is real and large, explicitly labelled as evidence and never as a
gate. Re-measuring properly is deferred to Plan 3i.

**The final whole-branch review found a production line with no witness at
all.** `canvas.translate(strip.left, strip.top)` — half the branch's
correctness argument for actually drawing the narrowed strip in the right
place — could be deleted without reddening a single test. The root cause,
measured rather than guessed: the sweep fixture only cleared the visible box
by 9–13 screen pixels while panning it 37–71, so the only two offsets where
the translate isn't a no-op never carried ink into the sampled band. Ruling
12 fixes this rather than recording it as a gap, on the reasoning that the
codebase's own testing bar — a test only counts if a named mutation makes it
red — applies with full force to a line the plan itself added. The fix wave
that gave it a witness also exposed a self-inflicted defect in the fix's own
documentation: the anti-vacuity clause written to catch exactly this class of
gap actually measures `debugLastStrip`, the **padded** strip, not `uncovered`,
the rectangle the fallback is clipped to — so it would not have caught this
finding even after being written to guard against it. Ruling 14 corrects the
wording in three places rather than re-pointing the clause (which would need
a production accessor the plan never argued for) and records the limitation
as gap **H7**. `record-fix-report.md` is the dispatch that carries this and
three smaller corrections out as one record-only pass, per Ruling 18.

## The one thing worth reading if you read nothing else

Ruling 19, read against Ruling 15 just above it in `progress.md`. The
controller corrected the mutation log, the correction disagreed with an
independent re-fire, and rather than trust either measurement over the other
it settled the question with an identity that doesn't depend on re-running
anything — then reversed its own ruling in writing. That reversal, not any of
the six mutants, is the clearest demonstration in this ledger of the
project's rule that a reviewer's claim is not evidence until it is
independently reproduced.
