# Task 4 report: sections

Status: DONE. Commit: 1f4fd331 `feat(plan): a unit's section, and its change events` (on 5b697929).

## What
- `lib/src/objects/sections.dart`: `PlanSectionChange{byLabel}`, `SectionArea` (shoelace area, point-in-polygon, boundary inside by `Tolerance.standard`), `SectionFinder` (smallest area; tie -> lower handle).
- `PlanUnitDetail.section` (`PlanObjectDetail?`), in `==`/hash/toString; `sameBesidesSection` and `withSection` are `@internal`. `diffUnitDetails` compares with `sameBesidesSection`, so a section change alone is NOT a `PlanUnitChanged` (decision; sectionChanges covers it).
- Controller: `_detailsOf` asks every root group whose kit type `hasArea` for `areaOf(doc, group, _buildWords)` (library names no kit type), finds each unit's section from its centre, once per unit-index rebuild (cached with `unitDetails`). `sectionChanges` (broadcast, async, baseline on listen, nothing read without a listener) reports from `_onDesignChange`, `_onServiceChanged` (R2: the service copy's own document/index, so SC7 works) and the end of `setMode`. `_replace` (load/newPlan) re-baselines silently. Only units present before and after count (added/removed are PlanUnitAdded/Removed).
- Barrel exports `PlanSectionChange`; barrel test updated; CHANGELOG line.

## Decisions
- Leaving service reports the section changes of the discarded moves (the host is told the truth).
- Units without a label are not reported in `byLabel`; duplicate labels collapse (last wins).
- Area ties use `Tolerance.compare` on area (mm^2).

## R4
Room area memo is per document (Expando) + stateId; `load()` builds a new document, so sections after load are fresh. SC10 (plan test with the zone kit, and integration test with real rooms, including load back) passes with no fix; no kit change made.

## Tests
- `jet_cad_2d_plan/test/objects/sections_test.dart` (12 tests, test kit `test/support/zone_kit.dart`: SC1-SC3, SC4 (smaller/tie/save-load), SC5, SC6, SC7, SC8, SC9-as-cache-invariant, SC10, equality, finder).
- `jet_cad_2d_integration/test/sections/sections_rooms_test.dart` (4 tests, real architecture rooms: SC1/2/4 separator, SC4 tie, SC8 deleted wall + undo, SC10 load).
- SC9: the engine's allocation invariants live in engine packages (not touched). Here SC9 asserts the area capability is not re-run on reads/`unitAt`/frames and runs once per zone per index rebuild (`zoneAreaCalls`). Existing plan invariants (pick/canvas allocation) pass in the full run.

## Gates (real last lines)
- plan: `+1600: All tests passed!`; analyze: No issues found; format: `Formatted 314 files (0 changed)`.
- integration: `+232: All tests passed!` (before two test-only lint fixes; sections subset re-run `+4`, analyze clean, format 0 changed).
- `dart run tool/ci/check_kit_deps.dart`: `3 package(s) checked, none names the plan library or another kit`.

## Mutations (each on committed code, reverted by git checkout, git diff --quiet)
- smallest -> largest (`compare < 0` to `> 0`): SC3, SC4, finder red (plan); SC1/2/4, SC10 red (integration).
- centre -> box first corner: SC4, SC5 red.
- tie keeps higher handle (`<= 0`): SC4, finder red.
- boundary check removed: SC4, finder red.
- service hook `_reportSections` removed from `_onServiceChanged`: SC7 red.
- `_replace` re-baseline removed: SC10 red.
- `diffUnitDetails` uses `==` (section changes emit PlanUnitChanged): SC8 red.
- `setMode` report removed: SC7 red.
- hash without section: no test red (hash need only be consistent with ==; accepted).

## Concerns
- Tie test relies on axis-aligned placement: for rotated equal rooms, float noise on areas beyond 1e-9 mm^2 could decide a tie arbitrarily.
- Frozen walls still bound rooms (R3).
- The unit's section data is a snapshot of the room's object detail; a change of the room's host data alone changes `PlanUnitDetail.section` equality but is not reported by sectionChanges (ref compare only).

## Fix round 1: equal areas
SC4b (two equal 37 deg rooms sharing a separator, table on the boundary) FAILED on the old code (picked the higher handle by float noise). Fix: `SectionArea.perimeter`; a candidate wins only if strictly smaller by more than `tolerance.linear * (perimeterA + perimeterB)`; otherwise the lower handle keeps it. Added SC4b (integration, real rooms, plan and save/load) and a SectionFinder case (10 m squares differing by 5e-5 mm^2 equal; 1e-2 x 1e4 real difference wins).
Mutation: plain `area.size < best.size` -> SC4b and the finder test red; reverted, git diff clean.
Gates: plan +1600 all passed, analyze/format clean; integration sections +5 passed, analyze/format clean. Commit: fix(plan): equal section areas within the tolerance's squared band.
Remaining concern removed: rotated ties no longer decided by noise.
