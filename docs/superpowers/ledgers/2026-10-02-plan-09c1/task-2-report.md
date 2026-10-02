# Task 2 report: App, the symbol's local box (spec D2)

Status: **done, app gate green, committed (not pushed).**

## Commits
- `31d098d` feat(app): a symbol's local box

## Files changed (both new)
- `apps/floor_planner/lib/symbols/symbol_box.dart`. Its imports are `dart:math`, `package:jet_cad_2d`, `vector_math` (`Vector2`) and `symbol_library.dart`. No Flutter, no `dart:ui`.
- `apps/floor_planner/test/symbols/symbol_box_test.dart`

Engine (`packages/jet_cad_2d`) and render (`packages/jet_cad_2d_flutter`): **unchanged by this task**, so they were not re-run. Task 1's files were not touched.

## What was built
- `SymbolBox {left, right, front, back}` (const, exact `==` and `hashCode`, `toString`). It has `width = right − left`, `depth = back − front` and `backCentre = Vector2((left+right)/2, back)`.
- `boxOfLeaves(Iterable<(EntityKind, GeometryPayload)>) → SymbolBox?`:
  - lines and polylines by every vertex; circles by centre ± r;
  - arcs by their two end points plus each axis extreme (k·π/2) for which the engine's `angleInSweep(k·π/2, start, sweep)` holds. Extremes are exact `c ± r`.
  - Point, text, attrib and fill leaves, and malformed payloads, are skipped, as `ghostPathFor` skips them. When nothing draws, it returns null.
  - Clockwise (negative) sweeps are handled too, because `angleInSweep` takes either sign. The catalog only uses counter-clockwise arcs.
- `boxOfEntry(SymbolEntry) → SymbolBox?`, memoised per entry in an `Expando<_Memo>`. The wrapper lets an entry with no drawn leaf memoise its null as well.
- `boxOfDefinition(DraftDocument, Handle) → SymbolBox?`. It reads the live entities owned by the handle and returns null when the handle names no definition. It is not memoised: per the plan, the per-document memo belongs to `WallFaces`.
- The arc rule is local and does not call the engine's `arcBounds`, so the named mutants can be fired in an app file without touching engine files. It still reuses the engine's `angleInSweep` for sweep membership.

## Tests added (`symbol_box_test.dart`, 22)
Group `SymbolBox`:
1. width, depth and the back-centre of an off-origin box
2. equality is exact on all four sides (compares against a box computed from a leaf, not a canonicalised `const`)

Group `boxOfLeaves`:
3. each side set by a different kind of leaf, far from the origin (left by a circle, right by an interior polyline vertex, front by an arc's 3π/2 extreme, back by a line end; around (1e5, −7e4))
4. a circle is its centre ± r on every side
5. a closed polyline counts every vertex once, a line both ends
6. no leaf has no box; a leaf of another kind draws nothing

Group `an arc by its true extents` (centre (1e5+37.5, −7e4+12.25), r 410):
7. a sweep that crosses 0 rad only
8. a sweep that crosses π/2 only
9. a sweep that crosses π only
10. a sweep that crosses 3π/2 only
11. a sweep that crosses no axis is its end points
12. a negative start (−120° through 90°) crosses −π/2
13. a start past 2π crosses π
14. a clockwise sweep from π/3 back through 0 to −π/6
15. a full turn is the whole circle

Group `library entries`:
16. every catalog symbol's box equals its hand-derived literal. It covers **all 27** and asserts that the literal table's key set equals the asset's key set.
17. the toilet's front is its bowl's axis extreme, its back the cistern: (0, 400, 0, 700); W 400, D 700; back-centre (200, 700)
18. the off-centre fixtures: back and left from an arc. These are `symbol_fixtures.dart`'s sofa, armchair and nightstand, decoded through the loader; the sofa's back of 1150 comes from an arc's π/2 extreme.
19. memoised per entry: the same object on every call

Group `boxOfDefinition`:
20. a placed definition gives the same box as its entry: toilet, hob, tub and office chair placed in one document at (1e5…, −7e4…) with turns 1–4, mirrored and not
21. reads the live leaves: a removed leaf no longer counts (the toilet's cistern removed gives back 500; undo gives 700)
22. not a definition (the root, a leaf, nothing), or a definition without leaves: no box. The root owns a drawn line and a circle.

The literals the plan names: toilet (0, 400, 0, 700); hob (0, 600, 0, 520), where the circles lie inside the outline; tub (0, 1700, 0, 750). Circles that **set** a catalog box: the round table (0, 1100, 0, 1100) and the office chair (0, 600, 0, 600). Every catalog box starts at (0, 0), by the catalog's frame (F-1), so the off-origin rules are pinned by tests 3–15, 18 and 22.

## Gates (real counts, this container, Flutter 3.47.2)
- App (`apps/floor_planner`), at `31d098d`'s tree before the commit: `04:42 +1015: All tests passed!` That is 993 at the branch point plus 22 new; Task 1 changed SC12 and P13 but not the count. `flutter analyze`: No issues found! `dart format --output=none --set-exit-if-changed .`: 177 files, 0 changed, exit 0.
- Engine and render: unchanged by this task, not re-run.
- Allocation invariant tests: not edited. `analysis_options.yaml`: not staged. `packages/jet_cad/analysis_options.yaml` stays modified in the worktree by pub get.

## Mutant table
Each mutant was fired by: cp backup, mutate, `CI=true flutter test test/symbols/symbol_box_test.dart`, cp back, `diff` exit 0. After all of them, the file was diffed against the pre-mutation copy: exit 0. Script and logs are in the scratch dir `task2/` (`mutate.py`, `mutant_<name>.log`).

| Mutant | Site | Change | Red tests | Excerpt |
|---|---|---|---|---|
| **M-09c-ai** | symbol_box.dart:98 | extreme loop `k < 4` → `k < 0` (end points only) | 13: #3, #7–10, #12–17, #18, #21 | toilet: `Expected: ...front: 0.0, back: 700.0` `Actual: ...front: 199.99999999999994, back: 700.0` |
| extreme off by one quadrant | :99 | `_axisAngles[k]` → `_axisAngles[(k + 1) % 4]` | 9: #3, #7–10, #12–14, #18 | π/2: `Expected: <-69577.75>` `Actual: <-69632.67958444839>` |
| **back = minY** (M-09c-b, box half) | :111 | `back: maxY` → `back: minY` | 17 incl. #16, #17 | toilet: `Actual: ...front: 0.0, back: 0.0` |
| front = maxY | :111 | `front: minY` → `front: maxY` | 17 | `Expected: ...front: -70150.0...` `Actual: ...front: -69050.0` |
| back-centre x = left | :36 | `(left + right) / 2` → `left` | #1, #17, #18 | `Expected: Vector2:<[464.875,905.5]>` `Actual: Vector2:<[-310.5,905.5]>` |
| depth = right − left | :32 | depth from width | #1, #17 | `Expected: <980.5>` `Actual: <1550.75>` |
| circle radius ignored | :89 | `r = 0.0 * scalars[0]` | #3, #4, #6, #16, #18 | `Expected: ...left: 99800.0` `Actual: ...left: 99980.0` |
| circle radius in x only | :90 | `add(c0 ± r, c1)` | #4, #6, #16, #18 | `Expected: ...front: 3027.75, back: 3172.75` `Actual: ...front: 3100.25, back: 3100.25` |
| polyline end vertices only | :84 | step `max(2, len − 2)` | #3, #5, #16, #17, #18, #21 | `Expected: ...right: 101200.0` `Actual: ...right: 100735.55558516717` |
| other kinds counted | :103 | point/text/attrib/fill add their coords | #6 | `Expected: null` `Actual: SymbolBox(left: 90000.0, ...)` |
| empty gives a box | :110 | `if (minX > maxX) return null;` removed | #6, #22 | `Expected: null` `Actual: SymbolBox(left: Infinity, right: -Infinity, ...)` |
| no memo | :125 | `??=` → `=` | #19 | `Expected: true` `Actual: <false>` |
| owner filter dropped | :140 | `ownerAt(slot) == definition \|\| true` | #20, #22 | `Expected: ...right: 400.0, ... back: 700.0` `Actual: ...right: 1700.0, ... back: 750.0` |
| definition check dropped | :136 | `if (definition(h) == null) return null;` removed | #22 | `Expected: null` `Actual: SymbolBox(left: -370.0, right: 100900.0, ...)` |
| `==` ignores back | :43 | `other.back == back` dropped | #2 | `Expected: false` `Actual: <true>` |
| hashCode by identity | :47 | `identityHashCode(this)` | #2 | `Expected: <675292802>` `Actual: <1040965066>` |
| counter-clockwise only | :99 | `angleInSweep(..., sweep.abs())` | #14 | `Expected: <100447.5>` `Actual: <100392.57041555161>` |
| end = sweep | :95 | `end = start + sweep` → `end = sweep` | 9: #7–14, #18 | `Expected: a numeric value within <1e-9> of <100392.57...>` `Actual: <100242.5>` |
| every extreme always added | :99 | `if (true \|\| angleInSweep(...))` | 9: #7–14, #18 | `Expected: ... within <1e-9> of <100392.57...>` `Actual: <99627.5>` |
| definition box memoised on the doc | :135 | an `Expando<Map<Handle, SymbolBox?>>` on the document, never cleared | #21 | `Expected: ...back: 500.0` `Actual: ...back: 700.0` |

Every one of the 22 tests has at least one mutant that turns it red. One mutant (`hashIdentity`) first **survived**, because the equality test compared two `const` boxes, which canonicalise to one object. That test was rewritten to compare against a computed box, and the mutant now goes red.

## Proposed rulings
- **R-C2-1 (non-geometry leaves skipped).** The box skips point, text, attrib and fill leaves and malformed payloads, as the ghost path does. The library's loader refuses them anyway (09 D5). A definition edited in a document could in principle hold one. Cost if wrong: one `case` and one test.
- **R-C2-2 (no leaf: null).** `boxOfLeaves`, `boxOfEntry` and `boxOfDefinition` return `SymbolBox?`, which is null when nothing draws or the handle names no definition. The plan wrote non-nullable-looking signatures. The loader does not refuse a definition with no leaves, so a non-null box would need an invented value. Cost if wrong: callers (Tasks 5–7) would add a `!` or a fallback.
- **R-C2-3 (clockwise arcs).** These are handled by the box's arc rule (via `angleInSweep`) and pinned by test 14. The spec only says "counter-clockwise sweep", the catalog's convention. Cost if wrong: none; it is a superset.
- **R-C2-4 (stale task reference).** The plan's Task 2 note says the per-document memo belongs to "`WallFaces`, Task 5". After C-0, `WallFaces` is Task 6. The doc comment names `WallFaces` (spec D3, D4) without a task number. Cost if wrong: none.

## Found, not fixed
- Test 16 asserts that the literal table covers exactly the asset's keys. **Task 3 (catalog grows to 41) must add 14 literals** to `catalogBoxes` in `symbol_box_test.dart`, or test 16 goes red with "a new catalog symbol needs its literal here". This is deliberate ("every catalog symbol's box equals a hand-derived literal"), but it is work Task 3's brief should name.
- `backCentre` allocates a `Vector2` per call. It is not on the paint path. If Task 6 calls it per pointer move, it is one allocation per move, the same as the rest of the pointer path.

## Look hardest at
1. The toilet's front: `front == 0.0` exactly. It comes only from the bowl arc's 3π/2 extreme. The end points give `199.99999999999994`, because `sin(2π) ≠ 0` in double.
2. The hand-derived dining-set literals (chairs extend 350 mm past the table edge). For example, rect.six is (0, 2500, 0, 1600): its right chair runs from 350+1800−100 = 2050 to 2500.
3. R-C2-2, the nullable return, which later tasks consume.
