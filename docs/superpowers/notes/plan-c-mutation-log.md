# Plan C — mutation log

Fourteen mutations were pre-committed in
[the plan](../plans/2026-08-31-gpu-backend-plan-c-shaded-dashes.md).
**All fourteen were fired. Thirteen died. One survived, and it was declared a
likely survivor before it was fired.**

**Every firing in this log was run.** Where an earlier task's *review*
derived that a mutation would be caught, that derivation is not counted here:
M-C3 and M-C7 were argued in Task 6's review and only actually fired in Task
11, and they are recorded against Task 11. Plan C had one incident of a claim
being reasoned and then written into a committed comment as fact (Task 9's
`w0<->w1` transposition, corrected once the reviewer computed it), which is
why this distinction is drawn explicitly rather than assumed.

Every mutation was applied to a file backed up with `cp` and restored from
that copy. **`git checkout --` is never used to revert a mutation** — a Plan A
implementer did that once and destroyed a round of uncommitted fix work.

## Summary

| id | mutation | verdict | gate that caught it | fired in |
|---|---|---|---|---|
| M-C1 | `beginDash` takes the cycle from `pattern.totalLength` instead of summing `\|d\|` | **killed** | the collector's period test, against a dishonest-`totalLength` pattern | Task 5 |
| M-C2 | a polyline's segments accumulate phase instead of restarting at 0 | **killed** | the record differential | Task 11 |
| M-C3 | an arc's chords all carry phase 0 | **killed** | *a dashed arc carries a running phase…* | Task 11 |
| M-C4 | `factor` is `residual.scaleMagnitude` instead of the per-primitive ratio | **killed** | the anisotropic polyline test, and the anisotropic arc test | Tasks 5, 6 |
| M-C5 | `factor` divides by the chord's local length, not its local **arc** length | **killed** | *a dashed arc carries a running phase…* | Task 11 |
| M-C6 | `_suppressJoins` is never set for a dashed run | **killed** | *a dashed polyline emits… no joins at all* | Task 11 |
| M-C7 | the seam join is emitted on a dashed closed run | **killed** | *a dashed circle emits no seam join* | Task 11 |
| M-C8 | every element carries a negative period, not only `k == 0` | **killed** | the record differential | Task 11 |
| M-C9 | the collapse branch is deleted | **killed** | *the collapse rule is LIVE…* | Task 11 |
| M-C10 | `dashScale` comes from `collectionToDevice` instead of `collectionToLogical` | **killed** | `dashScaleFor`, at `dpr` 2 (6.0 expected, 12.0 mutated) | Task 7 |
| M-C11 | the fragment test is closed, `f <= fracEnd` | **SURVIVED** | — | Task 11 |
| M-C12 | `along` is measured in device space instead of collection space | **killed** | *t is measured in COLLECTION units, so the camera cancels* | Task 8 |
| M-C13 | every element is written with `fracStart = 0, fracEnd = 1` | **killed** | the pixel differential | Task 11 |
| M-C14 | the rasterizer's barycentric correspondence is rotated | **killed** | the off-centroid interpolation test | Task 9 |

Two further mutations were fired that the plan did not pre-commit, both to
prove an instrument rather than the code:

| mutation | verdict | gate |
|---|---|---|
| the dash element fan is disabled (`n = 1`) | **killed** — expected 12, actual 11 | the record differential, before it was trusted green |
| `writePoint`'s `_writeDash` call is deleted | **killed** — expected 0.0, actual 18.0 | the point-is-never-dashed test, after it was rewritten to be killable |

## M-C11 — the survivor, declared before it was fired

**The plan pre-declared this one.** M-C11 changes `f >= fracEnd` to
`f > fracEnd` in the fragment stage, so it differs from correct code on
exactly the fragments where `fract(t)` lands within one float ULP of a drawn
element's end. The measure of that set is zero in the continuum and vanishing
in float32, so no pixel gate can be expected to see it, and the plan said so
in advance rather than explaining it afterwards.

**It is a survivor, not an equivalent mutation.** The two programs are
distinguishable in principle — a fragment landing exactly on `fracEnd` inks
under the mutant and not under the original — so the honest label is "no gate
in this suite can reach it", which is what the plan predicted.

## M-C5 — a predicted survivor that died

The plan also pre-declared M-C5 as a likely survivor, reasoning that dividing
by the chord's length rather than its arc length changes the phase advance by
`1 - chord/arc ~ theta^2/24`, a fraction of a percent at this flattener's
chord counts. **It died.** The arc phase test asserts a *constant* advance per
chord against the arc-length value, and the systematic per-chord error is
enough to break that equality even though it is small.

**A prediction that turns out wrong in the direction of a stronger gate is
worth recording as loudly as one that turns out right.** The plan's estimate
of the size was right; its estimate of what the gate would tolerate was not.
