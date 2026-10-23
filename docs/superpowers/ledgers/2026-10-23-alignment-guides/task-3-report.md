# Task 3 report: the alignment-guide solver

Status: DONE_WITH_CONCERNS. Commit: see `git log -1` (`feat(plan): alignment guide solver`).

## Built
- `packages/jet_cad_2d_plan/lib/src/guides/guide_solver.dart`: constants, `GuideReferences`, `GuideKind`, `GuideSolution`, `solveGuides` with the brief's signatures. Imports only `dart:typed_data` and `package:jet_cad_2d` (`Handle`, `Tolerance`).
- Allocation-free by construction: best-candidate state is typed lists sized once in `GuideSolution`; neighbour search results are int fields; helpers return primitives (NaN for "none"), no records/closures/collections in the solve.
- `packages/jet_cad_2d_plan/test/guides/guide_solver_test.dart`: 19 tests, fixtures shifted by (5000, -3200), non-zero fallbacks (0.75, -0.25) so the identity is not hidden.

## TDD
Red first: `flutter test test/guides/guide_solver_test.dart` -> `Error: Method not found: 'solveGuides'.` / `Some tests failed.` Then implemented; the first green run needed my test arithmetic fixed (the final box includes y's fallback shift, so expected line extents and mark `at` carry it); no solver change.

## Mutations (each applied to the file, test run, reverted; file confirmed identical afterwards)
Real failing lines (`flutter test test/guides/guide_solver_test.dart`):
- M1 `ao > aperture` -> `ao >= aperture`: `edges an offset exactly on the aperture captures (<=, not <) [E]`
- M2 edge/centre tie flipped (`kind < ` -> `kind >`): `ties an edge beats a centre pair of equal offset [E]`
- M3 `g <= eps` / `gap <= eps` filters removed: `equal spacing between is refused when a gap would be <= epsilon [E]`, `equal spacing touching neighbours never give a continuing capture or a mark [E]`
- M4 `freeX` ignored: `edges a non-free axis never captures and draws nothing [E]`
- M5 recheck removed: `a spacing capture whose row is lost after y snaps falls back [E]`, `a spacing capture with no other candidate falls to the fallback [E]`
- M7 recheck reads the raw box instead of the provisional one: same two tests red as M5.
- M8 moving-set skip removed: `edges a reference in the moving set is skipped [E]`
- M9 line merge removed: `ties two references at one position ...`, `limits far zoomed out ...`, `a spacing capture whose row is lost ...` all `[E]`
- **M6 recheck done sequentially (y's recheck reads the rechecked x): SURVIVES (19 pass).** See concerns.

## Gate (packages/jet_cad_2d_plan)
`flutter test --enable-vmservice`: `+1657: All tests passed!` (baseline 1638 + 19). `flutter analyze`: `No issues found!`. `dart format --output=none --set-exit-if-changed .`: `Formatted 326 files (0 changed)`, exit 0. `git status --short` showed only the two new directories before commit.

## Concerns
1. **M6 is unkillable (equivalent mutant), I believe.** A spacing capture on axis y with offset o_y can only break x's row if the shift o_y exceeds the overlap of some row member with the moving box; but then the edge candidate that aligns that member's end has |o| = the overlap < |o_y| and wins on the smallest-|o| rule, so y would not be a spacing capture. Symmetrically x. So whenever a recheck fails, the other axis is non-spacing and is never rechecked, and sequential equals simultaneous. The "Recheck" test in the brief is realised with an edge capture on y that reduces the overlap to zero (and the same via fallback).
2. **Capacity test cannot reach 16.** The brief says 40 references on one line at scale 0.05 gives `lineCount == 16`. With the spec's step 6 (only zero-offset candidates drawn, same-coordinate lines merged) at most 3 lines per axis are possible, so 16 is unreachable. My test asserts the real behaviour: the x lines of 40 stacked references merge into one spanning all of them, counts stay <= `kGuideCapacity`. The capacity guards are untested by any mutation (they cannot be hit).
3. **Centre-kind classification is my reading.** The spec ranks "edges, then centres" but nine pairs include mixed ones; I classify a pair as `centre` if either side is the centre, `edge` only edge-to-edge. Pair index is `3*m + r` (min, centre, max).
4. For `between`, the `R.min - L.max >= hi - lo` fit test is implied by "each resulting gap > eps" and is not coded separately. For `continuing`, the recheck covers the neighbour (L or R) only, and `refX` is the lower handle of the pair (A/L or R/R2).
5. Marks are drawn from a neighbour search on the final box; if a failed axis moved the final box so another spacing capture's row no longer holds there, that axis stays captured but draws no marks (spec says nothing is re-solved).

## Fix round 1
- **F2 done.** New test `continuing needs A to overlap L perpendicularly` (A left of L on x but in y 100..160 vs L's 10..50: no capture, no marks; same layout with A in L's row captures `continuing`). Mutation: the overlap test removed in `_outer` -> `equal spacing continuing needs A to overlap L perpendicularly [E]`, `+19 -1: Some tests failed.` Reverted (file identical to the committed one).
- **F1 unreachable with distinct handles, so no test added.** The last tie-break compares candidates equal in |o|, kind, pair index, handle and second handle. One (reference, m, r) gives one offset, so an edge/centre tie needs the same handle twice. Spacing candidates: `between` is one per axis; `continuing` low has the pair (A, L) with L left of the box, high has (R, R2) with R right of it, so equal handle sets would need a handle on both sides. Only duplicate handles (invalid input) reach it. Mutation `o < ` -> `o >` stays green (+20), as expected. A duplicate-handle fixture would kill it but pins invalid input; awaiting the controller's ruling.
- Gate (plan package): `+1658: All tests passed!`, `No issues found!`, `Formatted 326 files (0 changed)`, format exit 0.
