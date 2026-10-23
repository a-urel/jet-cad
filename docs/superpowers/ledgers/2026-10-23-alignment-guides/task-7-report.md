# Task 7 report: alignment guides while placing a symbol

Status: DONE. Commit: `feat(plan): alignment guides while placing a symbol`.

## Built
- `PlanSymbolTool` gains optional `guides`, `guideSettings`, `guideStroke` (null = today's behaviour); `PlanController` passes `session.guides`, `_alignmentGuides`, `() => guideStrokePixels`.
- `_guidedAt` anchor; `_free({guided = true})`; `_syncAttachment` uses `_free(guided: false)`; `ghostAt`, `_place` (`at: _guidedAt`, `transform: _attached?.transform ?? _free()`) and the snap marker read the guided anchor.
- One solve site: `_syncPlacement` calls `_solveGuides()` first, so pointer, camera, R/M, re-arm and `gatesChanged` all re-solve.
- Origin-anchored box cached on (armed symbol identity, turns, mirror) via `worldBoxOf`; per event it is translated by the raw pointer (placementTransform = T(at) R M T(-base), so the shift is exact; PG-1 checks the result against hand-computed corners). Both axes free, `moving` the const empty set, fallback `at - raw`; captured axis writes `raw + d`, other axis copies `_at.point`.
- `_track` stores `isTouch` and `alt`; `onKey` handles Alt-left/right down/up (not repeat) before the early returns, re-runs `_update` when a ghost is visible, returns ignored. Constructor listens to the settings; `dispose` removes it; a change re-solves and notifies.
- `paintOverlay` paints the solution only when not attached. `@visibleForTesting debugSolution`.

## TDD
Tests written first. Against the original lib plus a stub `debugSolution`, `flutter test test/guides/placement_guides_test.dart` gave PG-1,2,3,4,5,7,8,9 red (`Expected: true  Actual: <false>`, captured never true); PG-6 (R ignored under Alt) is a regression pin and passes at baseline. With the implementation: `+11: All tests passed!`.

## Mutations (each reverted; command: `flutter test test/guides/placement_guides_test.dart`)
- M1 attachment `current: _free()!` (guided): red PG-9.
- M2 `_place` commits `_at.point` / no `_free()`: red PG-1, PG-8.
- M3 box not recomputed on a turn: red PG-3. M3b not on a mirror: red PG-4.
- M4 solve removed from `_syncPlacement`: red PG-1..PG-9. M4b solve moved into `_update` only: red PG-3, PG-4, PG-7.
- M5 touch aperture ignored: red PG-2. M6 Alt key handler off: red PG-5. M10 pointer `alt` ignored: red PG-5.
- M7 settings listener not added: red PG-7. M8 guide painted though attached: red PG-9.
- M9 `ghostAt` returns `_at.point`: red PG-1,2,3,4,5,7,8,9.
- M11 x always the raw pointer (chain's grid x discarded): red PG-10.
- M12 (write uncaptured axis as `raw + fallback`): survives. It is equivalent here: `at - raw` and the sum are exact for nearby doubles, so bit-for-bit copy is not observable; the captured-only write is still pinned by M11.

## Gate
`flutter test --enable-vmservice`: `03:07 +1715: All tests passed!` (1704 + 11). `flutter analyze`: No issues found (after removing 3 unused items in the test). `dart format --output=none --set-exit-if-changed .`: `Formatted 335 files (0 changed)`. analysis_options.yaml untouched; `git status --short` showed only the 3 files.

## Concerns
- PG-4 (M) uses `sideChairTable` because the base-centred table box is mirror-symmetric.
- While a wall attachment is captured the solver still runs (the guided anchor is unused); only painting is skipped.
- No allocation-invariant test yet for this tool (the spec's combined invariant belongs to a later task).

## Fix round 1
- F1: PG-11 paints the overlay into a recording canvas (grid on, a y capture, the table shifted so the grid's y is 36 mm from the guided y) and asserts the grid marker cross is centred on the hand-computed screen point of the guided anchor. Mutation `final p = _at.point;` red: `Expected: a numeric value within <0.000001> of <2226.96...>  Actual: <2300.0>`. Reverted.
- F2: Alt key-down mid-press returns `handled` (key-up still `ignored`); not pressed, `ignored`. PG-12 pins both. Mutation "always ignored" red (PG-12 `[E]`). Reverted.
- Gate: `02:41 +1717: All tests passed!`; analyze: No issues found; format: 0 changed.
