# Task 2 review: App, the symbol's local box (spec D2)

**Reviewed:** `git diff 48c8d57..31d098d` (one commit `31d098d`, two new files:
`apps/floor_planner/lib/symbols/symbol_box.dart`, `apps/floor_planner/test/symbols/symbol_box_test.dart`).
**Worktree:** detached `.worktrees/plan-09c1-review-t2` at `31d098d`. Nothing was committed. The implementer's worktree was not touched, apart from this file.

## Verdict: **Approved**

I found no defect. The notes below need no code change. N-1 is an action for the controller's Task 3 brief.

## 1. Spec and plan conformance (line by line)

| Requirement (spec D2 / plan Task 2) | Where | Verdict |
|---|---|---|
| `SymbolBox {left, right, front, back}`, `left = minX`, `right = maxX`, `front = minY`, `back = maxY` | symbol_box.dart:18-26, :111 | ok |
| `width`, `depth`, `backCentre = ((l+r)/2, back)` | :29, :32, :36 | ok |
| Lines and polylines by their vertices | :82-86 | ok. A closed polyline's repeated first point is harmless. |
| Circles by centre ± r | :87-91 | ok |
| Arcs by their true extents: the end points plus each axis extreme the sweep passes | :92-102 | ok. Extremes are exact `c ± r`, and the sweep test uses the engine's `angleInSweep`. |
| `boxOfEntry` memoised per entry with an `Expando` | :114-127 | ok. The `_Memo` wrapper also memoises a null. |
| `boxOfDefinition(doc, h)` from the definition's live leaves | :135-146 | ok. It filters by owner over `liveSlots`, and returns null for a non-definition. |
| Pure: no Flutter, no `dart:ui` (D1, T-4) | imports :9-14 | ok. I walked the **transitive** import closure: symbol_box → symbol_library → parametric/catalog → 14 parametric files. None imports `package:flutter` or `dart:ui`. |
| Exact-vs-tolerance | n/a | The box makes no geometric decision. Its min/max and `==` are exact, which is correct for a stored value. |
| Frame path / draw order / permissions / undo | n/a | Nothing touched. `boxOfDefinition` is O(entities) and builds a list, but it is not on a paint path. Undo is exercised by test 21. |

**Toilet front, exactly 0.0.** `ArcShape(200, 200, 200, π, π)` has its end points at π and 2π. `sin(2π)` is not 0 in double, so the end point gives `y = 199.99999999999994` (I re-derived this in Dart). The 3π/2 extreme gives `200 + 200·(−1) = 0.0`, a positive zero. `angleInSweep(1.5π, π, π)` holds (delta π/2). Test 17 compares with exact `==` against `front: 0`. M-09c-ai turns it red with `199.99999999999994` (see §3).

**Dining literals (chairs beyond the table edge).** Re-derived from `_diningSet` (chair reach 350, tuck 100, chair 450):
- square.two: table 800² at (0, 350). Bottom chair y from 0. Top chair 1050→1500. x 0→800 (chairs at 175→625). (0, 800, 0, 1500) ✓
- square.four: table 900² at (350, 350). Chairs on 4 sides: 0 → 350+900−100+450 = 1600 in both axes. (0, 1600, 0, 1600) ✓
- rect.four: table 1400×800 at (0, 350). Chairs top and bottom only: y 0→1500, x 0→1400. ✓
- rect.six: table 1800×900 at (350, 350). Right chair 2050→2500, top chair 1150→1600. (0, 2500, 0, 1600) ✓

**Differential check (reviewer's own, temporary, deleted after the run).** I compared `boxOfLeaves` against the engine's `entityBounds`/`arcBounds` union:
- (a) every entry of the committed asset and of `symbol_fixtures.dart`'s library: exact `==`, all equal;
- (b) 10,000 seeded random arcs around (1e5, −7e4), with r 1–900, start in ±4π and sweep in ±2.2π (both signs, full turns included): **0 mismatches**.

`00:00 +2: All tests passed!`. The worktree was clean afterwards apart from the pub-get `analysis_options.yaml`.

## 2. Gates (re-run by me, `CI=true`, Flutter 3.47.2, app only)

- `flutter test`: `04:14 +1015: All tests passed!` (exit 0). This equals the implementer's 1015 (993 + 22).
- `flutter analyze`: `No issues found! (ran in 5.3s)` (exit 0).
- `dart format --output=none --set-exit-if-changed .`: `Formatted 177 files (0 changed)` (exit 0).
- Engine and render: the diff touches no file in either package, so they are unchanged by this task (not re-run, per the brief).
- The allocation invariant tests are not in the diff, so they are unedited. `analysis_options.yaml` is not in the diff. It shows ` M` in the review worktree only because of pub get.

## 3. Mutants (re-fired by me)

Method: `cp` backup, mutate (a python exact-string replacement, asserting one match), `flutter test test/symbols/symbol_box_test.dart`, `cp` back, `diff` exit 0 ("restored ok" every time). A final `diff` against a pristine copy was clean. Logs are in `scratchpad/review2/mutant_*.log`.

| Mutant | Change | Result | Red tests |
|---|---|---|---|
| **M-09c-ai** (plan) | `k < 4` → `k < 0` (end points only) | **red**, +9 −13 | #3, #7–10, #12–15, #16, #17, #18, #21. Same 13 as the implementer. |
| extreme off by one quadrant (plan) | `_axisAngles[k]` → `_axisAngles[(k+1)%4]` | **red**, +13 −9 | #3, #7–10, #12–14, #18. Same 9 as the implementer. |
| `back = minY` (plan, M-09c-b's box half) | `back: maxY` → `back: minY` | **red**, +4 −18 | 18 tests incl. #16, #17. The implementer reported 17 (see N-4). |
| reviewer R1: 3π/2 extreme's sign flipped | `_axisY = [0,1,0,1]` | **red**, +15 −7 | #3, #10, #12, #15, #16, #17, #21 |
| reviewer R2: last vertex of every line/polyline dropped | loop `i + 3 < len` | **red**, +18 −4 | #2, #3, #5, #18 |
| reviewer R3: clockwise end, `end = start − sweep` | | **red**, +13 −9 | #7–14, #18 |
| reviewer R4: every arc skipped (scalars `< 4`) | | **red**, +8 −14 | #3, #7–15, #16, #17, #18, #21 |
| reviewer R5: the extreme's y offset without `r` | `c[1] + _axisY[k]` | **red**, +13 −9 | #3, #8, #10, #12, #15–18, #21 |

All 8 are red and none survived. The quadrant mutant does not reach the toilet: its sweep π..2π contains the shifted angle as well. It is killed by the separate-axis arc tests, which is why those tests matter.

## 4. Fixtures (P-2)

- **Origin:** every catalog box starts at (0, 0) by F-1, so the off-origin coverage comes from tests 3–15 (everything around (1e5, −7e4)) and from test 18, whose fixture symbols are off-centre in both axes. In test 3 each box side is set by a different leaf kind: an interior polyline vertex, an arc extreme, a line end and a circle. This is not degenerate.
- **Instance transform:** test 20 places 4 definitions far from the origin, at turns 1–4 and mirrored on odd turns, and asserts that the box stays in definition coordinates. Four definitions sit in one document, so the owner filter is exercised.
- **Arcs:** the tests cover each axis separately, no axis, a negative start, a start past 2π, a clockwise sweep and a full turn.
- **Equality:** test 2 compares against a computed box, not a canonicalised `const`, so the identity-hashCode mutant is killed.
- The wall-angle and mirrored-group fixtures of P-2 do not apply here: there is no wall, and the box is in definition space.

## 5. Proposed rulings

- **R-C2-1 (point, text, attrib and fill skipped): accept.** D2 enumerates lines, polylines, circles and arcs. The loader refuses the other kinds (09 D5). A fill occupies its boundary leaf, which is itself counted. The cost: a hand-edited definition holding a point gets a box that differs from the engine's extents. No app path creates one.
- **R-C2-2 (`SymbolBox?`): accept.** The loader does not refuse an entry with no drawn leaf, and inventing a box would be worse. **Consequence for Tasks 5–7:** a null box means "does not attach" (treat it like a missing `against-wall` tag), never a `!`. The controller should say so in Task 6's brief.
- **R-C2-3 (clockwise arcs): accept.** It is a superset of the spec. It is pinned by test 14, and my R3 mutant is killed by it among others. The engine's `angleInSweep` takes either sign.
- **R-C2-4 (stale "Task 5"): accept.** After C-0, `WallFaces` is Task 6. The doc comment carries no task number.

## Notes (no fix required in Task 2)

- **N-1 (note, controller action): test 16's key-set coupling is right.** symbol_box_test.dart:306-313 asserts that the literal table equals the asset's key set. This turns the test into a tripwire: Task 3 cannot add a symbol without hand-deriving its full box. Task 3 already owes "each new symbol's box W × D equals its table row" (D9). A full (left, right, front, back) literal is that, plus F-1's `front = 0` and `left = 0`, at the cost of one line per symbol. I would keep it.
  - **Task 3's brief must name it:** add 14 entries to `catalogBoxes`, derived by hand from the catalog source and not printed from `boxOfEntry`.
  - The key-set assertion must not be weakened to a subset.
- **N-2 (note): the arc rule duplicates the engine's `arcBounds`** (symbol_box.dart:92-102 vs primitives.dart:82-109). The stated reason, firing mutants in the app file, is weak: a mutant can replace an `arcBounds` call just as well. My differential run shows the two agree exactly on the asset and on 10k random arcs, and the local version allocates no `Aabb2`. So it is acceptable. If either copy changes, the other must follow.
- **N-3 (note): `backCentre` allocates a `Vector2` per call** (:36). It is off the paint path today. Task 6 should read `(left + right) / 2` and `back` directly in any per-pointer-move loop over neighbours, or cache the value.
- **N-4 (note): the implementer's count for `back = minY` is 17 red; mine is 18** (+4 −18) for the same textual change at :111. The kill is not in doubt. The report's count is off by one, not fabricated: the run is real and red either way.
- **N-5 (note): `boxOfDefinition` counts the definition's own leaves only**, not nested instance children. This matches D2 ("its leaves"), and no library definition has children. 09c-2's Size row (D7) should keep this in mind if block nesting ever reaches definitions.
