# Task 5 report — the ghost path and matrix

Commit: 637a429 `feat(app): the symbol ghost` (on 3faabd4).
Files: apps/floor_planner/lib/symbols/symbol_ghost.dart (new),
apps/floor_planner/test/symbols/symbol_ghost_test.dart (new, 8 tests).
Engine and render untouched (not re-run; no file under packages/ changed).

## Gate (app)
```
03:16 +827: All tests passed!          (819 + 8)
No issues found! (ran in 1.6s)
Formatted 147 files (0 changed) in 0.69 seconds.   format_exit=0
✓ Built build/web
```

## API
- `ui.Path ghostPathFor(SymbolEntry)`: local frame, cached in a top-level
  `Expando<ui.Path>`; line/polyline segments (`close()` when
  `isClosedPolyline`), circle `addOval`, arc `addArc(start, sweep)` unchanged.
- `Float64List identityGhostMatrix()`, `void writeGhostMatrix(m, p, origin)`.
- `GhostMatrix`: `storage`, `update({at, basePoint, quarterTurns, mirrored})`
  (recomputes P and writes the linear part only on change), `forOrigin(origin)`
  (writes m[12], m[13] only), `placement`, `@visibleForTesting computations`.

## Decisions
- D5-1: `GhostMatrix.update` also takes `basePoint` and recomputes P when it
  changes (the spec names at, turns, mirror only). Re-arming another symbol
  changes the base point; leaving it out would keep a stale P. Cost if wrong: none.
- D5-2: arc convention verified: the engine's arc is `c + r(cos θ, sin θ)`,
  θ from start to start+sweep (grips.dart:84-102); `addArc` uses the same
  parameterisation in path space, so local angles go in unchanged and the
  matrix (mirror, turns) carries them. The test uses `leafGrips` (engine) as
  the oracle for start/end/mid, locally and through the matrix.
- Fixtures: office.chair (2 circles + arc π/4, π/2, base 300,300),
  bath.toilet (2 arcs π, π: endpoints cannot see a sweep flip, the mid can),
  dining.table.rect.six (closed polylines + lines); at (73250.5, -41810.25),
  origin (70000, -40000); q 0..3 x mirrored.

## Mutants
Driver: scratchpad/b5/mut.sh (cp backup, one-line sed, run
test/symbols/symbol_ghost_test.dart in the foreground, cp back; every
restore `diff exit=0`). All mutants red. Lines are symbol_ghost.dart at 637a429.

| id | line | mutation | red test(s) (real output) |
|---|---|---|---|
| M-09b13 | 33 | `??=` -> `=` (rebuilt per call) | `+4 -1: the path is cached: the same object on a second call, one per entry [E]` |
| M-09b14 | 96 | `m[12] = p.e` (origin not subtracted) | `+1 -1: the matrix maps the base point to at − origin, ... [E]`, writeGhostMatrix, P-count, arc-under-matrix (`+4 -4`) |
| arc sweep | 61 | `-p.scalars[2]` | `+6 -1: the path an arc runs from the payload start to start + sweep, through the engine's mid point [E]`, `+6 -2: ... drawn under the matrix ... [E]` |
| M-09b4b (mirror) | 150 | `mirrored: false` | `+1 -1: the matrix maps the base point ... [E]`, `+6 -2: ... drawn under the matrix ... [E]` |
| M-09b4a (linear part omitted) | 154 | `_writeLinear(storage, Transform2.identity())` | `+1 -1: the matrix maps ... [E]`, `+2 -2: the matrix P is computed only when ... [E]`, `+5 -3: ... drawn under the matrix ... [E]` |
| M-09b4c (whole P omitted) | 146 | `P = Transform2.translation(at)` | same three as M-09b4a (`+5 -3`) |
| P recomputed on origin only | 131 | `_p != null` -> `_p == null` (always recompute) | `+3 -1: the matrix P is computed only when the placement changes, not the origin [E]` |
| path not local (bounds) | 44 | `moveTo(c[0] - basePoint.x, c[1])` | `+5 -1: the path has one contour per leaf, and its bounds are the leaves' local bounds ... [E]` |
| circle radius | 54 | `radius * 0.5` | `+5 -1: the path has one contour per leaf, and its bounds ... [E]` |
| writeGhostMatrix linear | 89 | `m[0] = 1` | `+1 -2: the matrix writeGhostMatrix writes translate(−origin) ∘ P into an identity [E]` (+3 others) |

## Open / notes
- The polyline `close()` on a closed polyline is not observable by any test
  here (bounds and endpoints equal; only the stroke join at the start
  differs). Not mutated; a pixel test would be needed. Low value.
- 'the fixtures are not degenerate' is a precondition guard (fails if the
  asset changes), not a behaviour test; no mutant applies.
- `forOrigin` before any `update` throws StateError (not tested; the tool
  calls update before painting).
- Spec names `ghostPath(SymbolEntry)`, the plan `ghostPathFor`: the plan's
  name is used.

## Task 5b (review findings 1, 2; test-only)
Commit: c975d1d `test(app): the ghost pins closed contours and each base-point component (5b)` on df916b7.
Only apps/floor_planner/test/symbols/symbol_ghost_test.dart changed (+2 tests).
- New: 'a closed polyline's contour is closed, a line's is not' (dining.table.rect.six:
  per-leaf `PathMetric.isClosed` == polyline && isClosedPolyline; 8 closed, 6 lines).
- New: 'a change of the base point's x alone, then of its y alone, each recomputes P once'
  (office.chair, q=3 mirrored, same at; 1 -> 2 -> 3 computations; base maps to at − origin).

Gate (app): `03:31 +843: All tests passed!` (841 at df916b7 + 2); `No issues found!`;
`Formatted 149 files (0 changed)` format_exit=0. Engine/render untouched.

| mutant | line | red test (real output) |
|---|---|---|
| close() dropped | 49 | `+5 -1: the path a closed polyline's contour is closed, a line's is not [E]` |
| base x not in the change check | 134 `true &&` | `+4 -1: the matrix a change of the base point's x alone, then of its y alone, each recomputes P once [E]` |
| base y not in the change check | 135 `true &&` | same test `[E]` |
Every restore `diff exit=0`.
