# Task 5 report — the generalised placement transform (spec D5)

Implementer: fresh agent, 2026-10-02. Worktree `.worktrees/plan-09c1`, branch `plan-09c/wall-attach`.
Base: `a6ef0bc` (Task 3); Task 4 committed `e73621f` concurrently; nothing of Task 4's touched here.

## Commit
- `bb39637` feat(app): a placement at any angle

## Files changed (app only)
- `apps/floor_planner/lib/symbols/symbol_placer.dart`
- `apps/floor_planner/lib/symbols/symbol_ghost.dart`
- `apps/floor_planner/lib/symbols/symbol_place_tool.dart`
- `apps/floor_planner/test/symbols/symbol_placer_test.dart`
- `apps/floor_planner/test/symbols/symbol_ghost_test.dart`
- `apps/floor_planner/test/symbols/symbol_place_tool_test.dart`

## What was built
- `placementTransform({at, basePoint, int? quarterTurns, (double, double)? rotation, mirrored})`. Passing both `quarterTurns` and `rotation` throws an `ArgumentError`, an `if`/`throw` that also runs in release builds. Passing neither means no turn. The quarter-turn form looks up `(cos, sin)` in an exact table (`_quarterTurn`) and goes through the same chain as `rotation`: `translation(at)·R·scale(±1,1)·translation(−base)`, then `-0.0` is cleaned on all six components. Because the chain is the same code, the quarter-turn form is bitwise identical to before. A scratch differential confirmed it: the pre-Task-5 body verbatim against the new form, 200,000 random cases (0.0, −0.0, large and tiny coordinates, q in −6..6, mirrored or not), gave `compared 1200000 doubles, mismatches 0` (sign of zero included). The scratch file was not committed.
- `placeSymbol(..., Transform2? transform)`: the transform is used verbatim when given, and `at`, `quarterTurns` and `mirrored` are then not read. `at` stays `required` (see R-C5-1).
- `GhostMatrix.update({required Transform2 placement})` compares the six doubles with the last ones using `==`. When they are equal it does nothing and keeps the earlier object. Otherwise it stores the new transform, increments `computations` and writes the linear part. `symbol_ghost.dart` no longer imports `symbol_placer.dart`.
- `SymbolPlaceTool` keeps a field `_placement`, computed by `_syncPlacement()` on pointer down, move and up (after `_resolve`), on R/Shift+R/M and on a re-arm (a new base point). `paintWorldOverlay` only passes the field to `_matrix.update`, so no `Transform2` is built in a paint. It returns early when the field is null. Two test getters were added: `ghostPlacement` and `ghostMatrix` (both `@visibleForTesting`). Camera events are Task 8's (D12), and the attachment is Task 7's.

## Tests added
- Placer: P20 (a 30° and a −112.5° vector, `far = (100000.25, −70000.75)`, the sofa's base (900, 400), mirrored and not; the hand-derived matrix compared **exactly**, plus the base point and a leaf's endpoints by an independent formula, plus the determinant), P21 (both forms given → `throwsArgumentError` for q=0 and q=1; neither = `rotation: (1, 0)`), P22 (quarter-turn bytes == rotation-form bytes at the table for q in −2..5, mirrored or not), P23 (M-09c-n's axis-aligned exception: (−0.0, 1), (0, 1), (−0.0, −1), (1, −0.0), (−1, −0.0), mirrored or not: no −0.0), P24 (`placeSymbol(transform:)` with a mirrored 30° transform far from the origin, with a different `at`/turns/mirror passed alongside: the bytes stored verbatim through execute, undo, redo and save/load; validate empty).
- Ghost: "a 30° placement far from the origin: the storage holds its linear part and its translation less the origin, and every leaf of the toilet lands where the transform puts it" (mirrored and not); "equal placements recompute once; a change of one ulp in any one of the six doubles recomputes once, and the storage follows" (mirrored and not); "-0.0 and 0.0 compare equal: no recompute (stated, not a mutant)".
- Tool: "the placement is computed on events, never in a paint (spec D5, W-15): hover, R, M and a re-arm each set it; repeated paints pass the stored transform and compute nothing". It uses the rig's camera at 0.05 px/mm with pointers far from the origin.

## 09b ghost tests moved to the new signature (plan P-6; counts unchanged)
Every old call `update(at: X, basePoint: B, quarterTurns: Q, mirrored: M)` became `update(placement: placementTransform(at: X, basePoint: B, quarterTurns: Q, mirrored: M))`. The arguments and every `computations` expectation are unchanged. Old line → new line in `symbol_ghost_test.dart`:
- "maps the base point …": old :101-102 `..update(at: at, basePoint: b, quarterTurns: q, mirrored: mirrored);` → new :116-121.
- "P is computed only when the placement changes, not the origin": old :150 → new :169-171; old :156-160 (the `at.clone()` loop) → new :177-182; old :168/:174/:180/:187 → new :190/:197/:204/:212. Counts 1, 1, 2, 3, 4, 5 kept (old :151, :165, :173, :179, :185, :192 → new :172, :187, :196, :203, :210, :218).
- "a change of the base point's x alone, then of its y alone": old :202/:205/:210 → new :228/:233/:240. Counts 1, 2, 3 kept (new :231, :236, :243).
- "drawn under the matrix, an arc lands …": old :323 → new :457-459.
No other existing assertion was changed. P1–P4, P14 and every other placer and tool test pass unchanged.

## Gates
- App (before commit, tree = the commit): `CI=true flutter test` → `07:07 +1084: All tests passed!` (993 at the branch point, plus Tasks 1–4's tests and this task's 9 new tests). `CI=true flutter analyze` → `No issues found!`. `dart format --set-exit-if-changed .` → `Formatted 180 files (0 changed)`, exit 0. `CI=true flutter build web --release` → `✓ Built build/web`.
- App after the commit and mutants: see "Post-commit run" below.
- Engine and render layer: untouched by this task (app files only), not re-run.

## Mutants
Each was fired with a `cp` backup, the mutation, a run of the named test files, a `cp` back and `diff` (exit 0 every time). `git status` was clean afterwards, apart from the standing `packages/jet_cad/analysis_options.yaml`.

| Mutant | Site | Change | Red tests | Excerpt |
|---|---|---|---|---|
| **M-09c-n** (generalised form; the one clean step shared by both forms) | symbol_placer.dart:63 | `clean(v) => v == 0 ? 0.0 : v` → `clean(v) => v` | P3, P14, **P23** | P23: `(-0.0, 1.0) mirrored=true has -0.0: [-0.0, -1.0, -1.0, 0.0, 100400.25, -69100.75]` |
| **M-09c-o** | symbol_ghost.dart:126 | `if (p != null && …)` → `if (false && p != null && …)` (always recompute) | ghost "P is computed only when…", "equal placements recompute once…", "-0.0 and 0.0…"; tool "the placement is computed on events…" | `Expected: <1>  Actual: <4>`; tool `Expected: <1>  Actual: <3>` |
| **transform argument ignored** | symbol_placer.dart:157 | `transform: transform ?? placementTransform(…)` → `placementTransform(…)` | P24 | `Expected: [-0.8660254037844386, -0.5, -0.5, …]  Actual: [0.0, -1.0, -1.0, 0.0, 3733.5, -1322.25]` |
| **Transform2 built in paintWorldOverlay** | symbol_place_tool.dart:326 | `_matrix.update(placement: placement)` → `_matrix.update(placement: placementTransform(at: _at.point, basePoint: base, quarterTurns: _quarterTurns, mirrored: _mirrored))` | tool "the placement is computed on events…" (`identical(matrix.placement, ghostPlacement)`) | `Expected: true  Actual: <false>` |
| key does not recompute | symbol_place_tool.dart:~249 | `_syncPlacement()` dropped from `onKey` | tool "computed on events" | `Expected: [0.0, 1.0, -1.0, 0.0, 81675.3, -37200.7]  Actual: [1.0, 0.0, 0.0, 1.0, 81075.3, -37200.7]` |
| re-arm does not recompute | symbol_place_tool.dart:136 | `_syncPlacement()` dropped from `_onArmed` | tool "computed on events" | `Expected: [0.0, -1.0, -1.0, 0.0, 81375.3, -36700.7]  Actual: [… 81675.3, -36600.7]` |
| move does not recompute | symbol_place_tool.dart:192 | `_syncPlacement()` dropped from `onPointerMove` | tool "paints the cached path…", "a second paint reuses…", "computed on events" | `Actual: MappedListIterable<Invocation, Symbol>:[]` (nothing painted) |
| one double not compared (`f`) | symbol_ghost.dart:131 | `&& placement.f == p.f` dropped | ghost "a change of the base point's x alone…", "one ulp in any one of the six doubles…" | `Expected: <12>  Actual: <11>` |
| tolerance instead of exact | symbol_ghost.dart:127 | `placement.a == p.a` → `(placement.a - p.a).abs() <= 1e-12` | ghost "one ulp in any one of the six doubles…" | `Expected: <2>  Actual: <1>` |
| new placement not kept | symbol_ghost.dart:135 | `_p = placement` → `_p ??= placement` | ghost "P is computed only…", "base point's x alone…", "one ulp…"; tool "a second paint reuses…", "computed on events" | `Expected: … within <1e-9> of <3260.5>  Actual: <2950.5>` |
| both forms accepted | symbol_placer.dart:54 | `if (false && quarterTurns != null && rotation != null)` | P21 | `Expected: throws <Instance of 'ArgumentError'>  Actual: <Closure: () => Transform2>` |
| mirror after the turn | symbol_placer.dart:59-61 | `R·S` → `S·R` | P1, P4, P20; ghost "maps the base point…", "a 30° placement…", "drawn under the matrix…" | P20 and ghost `Expected: … of <29923.45508075689>  Actual: <30423.45508075689>` |
| rotation ignored | symbol_placer.dart:58 | `rotation ?? _quarterTurn(…)` → `_quarterTurn(…)` | P20, P22; ghost "a 30° placement…" | `Expected: … of <29577.04491924311>  Actual: <29800.25>` |

Note that M-09c-n turns P3 and P14 red as well, because the quarter-turn form goes through the same clean step. That is the generalised form, and the spec names one clean step for both. P23 is the test owed to M-09c-n, at the spec's axis-aligned exception.

## Proposed rulings
- **R-C5-1 (`at` stays required with `transform`).** `placeSymbol` keeps `required Vector2 at` and ignores it when `transform` is given. This is documented in the doc comment and pinned by P24. Making `at` optional would mean an `ArgumentError` for "neither", for no gain. Task 7 passes `q`. Cost if wrong: a signature change and one call site.
- **R-C5-2 (the ghost keeps the earlier object on an equal update).** On equal doubles, `GhostMatrix.placement` stays the earlier `Transform2` object. The tool test relies on this to detect a `Transform2` built in a paint (`identical(matrix.placement, tool.ghostPlacement)`). Cost if wrong: one test's identity check.
- **R-C5-3 (no unit-length check on `rotation`).** The vector is used exactly as given (D4 step 3: "exactly those doubles"). No assert checks that it has unit length. Cost if wrong: a debug assert.
- **R-C5-4 (test getters).** `SymbolPlaceTool.ghostPlacement` and `ghostMatrix` are `@visibleForTesting`. Task 7 can reuse `ghostPlacement` to compare against `attachToWall`'s bytes.
- **R-C5-5 (P-6's task number).** The plan's P-6 says the 09b ghost tests move "in Task 6". After C-0 (5 ↔ 6 swapped) they moved here, in Task 5, as this task's section says. Cost: none.

## Found, not fixed
- `_place` (the commit) still builds its transform from `at`, the turns and the mirror, not from `_placement`. The two agree today: same inputs, and the release calls `_syncPlacement` too. Task 7 switches the commit to the attached transform.
- The tool's placement is not recomputed on camera events yet (D5 lists camera events). That is Task 8's (D12) listener.

## Look hardest at
1. P20's exact equality. The expected value is written out by hand as `far.x - (s*cos*bx - sin*by)`. It equals the code's `((s·cos)·(−bx) + (−sin)·(−by)) + at.x` exactly, because negation is exact in IEEE arithmetic. If a later change reorders the chain, P20 will flag it at 1-ulp level.
2. The tool test's identity check, which is how "no Transform2 built in a paint" is made observable.
3. The ghost one-ulp test (`nextUp` through `ByteData`) is what kills a tolerance-based comparison.

## Post-commit run
After `bb39637` and all mutants were restored, the tree is clean (only the standing `analysis_options.yaml`). Full app suite: `07:55 +1084: All tests passed!`, exit 0. It includes Task 4's committed `e73621f`.
