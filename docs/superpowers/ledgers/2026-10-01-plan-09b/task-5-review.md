# Task 5 review (independent) — 637a429
Status: in progress
- Diff 3faabd4..637a429: 2 new app files only (lib/symbols/symbol_ghost.dart, test/symbols/symbol_ghost_test.dart).
- Matrix layout checked by hand: column-major, x' = m0 x + m4 y + m12, y' = m1 x + m5 y + m13; Transform2 x' = a x + c y + e, y' = b x + d y + f => m0=a, m1=b, m4=c, m5=d, m12=e-ox, m13=f-oy (symbol_ghost.dart:88-98). Correct.
- Hand case q=1 mirrored: placer P = T(at) R(90) S(-1,1) T(-base) (symbol_placer.dart:48-51). Local +x -> S (-1,0) -> R (0,-1); local +y -> (0,1) -> R (-1,0); base -> at-origin = (3250.5, -1810.25). Test expects m[0..1] = s*turned[1] = (0,-1), m[4..5] = turned[2] = (-1,0), base -> (at-origin): agree. Expectations come from a literal table + hand mirror-then-turn (test:34-56), not from placementTransform (only writeGhostMatrix's storage-layout check uses p.a..p.f, and it also checks hand-derived points via expectedWorld).
- Arc: the path is built in the local world-y-up frame with payload angles unchanged; the y-flip comes from the overlay's world matrix at paint time, exactly as outline_cache.dart:280-288 (comment: "the painter applies the world->screen matrix, y-flip included, so world angles go in unchanged"). The mirror/turn are in the ghost matrix; the test transforms the path and checks start/end/mid against engine leafGrips mapped by the hand formula. Correct.
- App gate (real): `03:19 +827: All tests passed!`; `No issues found!`; `Formatted 147 files (0 changed)` fmt=0; `✓ Built build/web`.
- M-09b4a (:154 identity linear): RED x3 (Expected 3250.5 Actual 3850.5). M-09b4b (:150 mirrored false): RED x2 (Expected (-1,-0) Actual (1,0)). M-09b13 (:33 =): RED cache test. M-09b14 (:96 m[12]=p.e): RED x3 (Expected 3250.5 Actual 73250.5). restored diff=0 each
- M-09b14 y (:97): RED x3 (Expected -1810.25 Actual -41810.25). arc sweep sign (:61): RED x2. recompute on every update (:131): RED (Expected 1 Actual 4). restored diff=0 each
- HUNT polyline close() dropped (:49): SURVIVED `+8: All tests passed!`. restored diff=0. Observable without pixels: PathMetric.isClosed -> finding
- hunt m[15] not 1 (:77): RED x3 (Expected [1.0,1.0] Actual [1.0,0.0]). restored diff=0
- HUNT base point x not in the change check (:134 `true &&`): SURVIVED +8. y (:135): SURVIVED +8. The test's base point change is toilet (200,0) -> office.chair (300,300): both components change at once. restored diff=0 each -> finding 2
- hunt forOrigin without its null check (:161 `if (false)`): does not compile (p nullable) — not a valid mutant; the StateError path is untested (note).
- Final git status --short: empty.

## Verdict: Needs fixes (test-only, small)
1. MINOR test/symbols/symbol_ghost_test.dart (code symbol_ghost.dart:48-50): dropping `path.close()` survives. It does not need pixels: `PathMetric.isClosed` is true only after `close()`. Fix: for dining.table.rect.six assert the closed polylines' metrics are `isClosed` and the lines' are not.
2. MINOR test:186-194 (code :134-135): the recompute-on-basePoint guard (R-B5-1) survives with either component dropped, because the test changes x and y together. Fix: two updates, one changing only basePoint.x, one only .y, each +1 computation.
3. NOTE: forOrigin before update throws StateError, untested; fine (tool calls update first).
Judgments: matrix layout and the hand case q=1 mirrored agree; expectations are independent of the code under test; the arc is built world-y-up and flipped by the overlay matrix at paint time, as outline_cache.dart:280-288; R-B5-1 (recompute on a base point change) is correct and needed (re-arming another symbol); the Expando key is stable (one decode per app, the loader's; a new decode would only build new paths, never a stale one).

## Re-review (5b) — c975d1d (parent df916b7)
- Diff: only apps/floor_planner/test/symbols/symbol_ghost_test.dart (+40).
- App gate (real): `03:38 +843: All tests passed!`; `No issues found!`; `Formatted 149 files (0 changed)` fmt=0.
- Mutants (scratchpad/rb5b, restored diff=0 each):
  - close() dropped (:49): RED "a closed polyline's contour is closed, a line's is not" (`Expected: <true> Actual: <false>`)
  - base point x not checked (:134): RED "a change of the base point's x alone, then of its y alone ..." (`Expected: <2> Actual: <1>`)
  - base point y not checked (:135): RED same test (`Expected: <3> Actual: <2>`)
- Counts honest: per leaf, the expected isClosed is computed from the leaf (kind polyline && engine isClosedPolyline) and compared to PathMetric.isClosed; closed/open are tallied from the leaves, and 8 / 6 are then asserted as a precondition on the asset (it fails if the asset changes), not as the oracle.
- git status --short: empty.
### Verdict (5b): Approved
