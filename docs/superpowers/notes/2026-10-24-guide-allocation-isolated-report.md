# Guide allocation invariant measured in isolation (2026-10-24)

Branch `fix/guide-allocation-isolated`, cut from main `edbcfe38`.

## What changed

- `ServiceTool.debugAim(ctx, wx, wy)` (`@visibleForTesting`, one line over `_aim`): commit `e889d094`. The only lib change.
- `test/invariants/guide_allocation_test.dart`: commit `11393021`.
  - GA1-GA5 (end-to-end on minus off, budget 0.05 per event, growth envelope) keep their shape. `Transform2` is dropped from their watched set, with a comment citing the ruling: the immutable `GripDrag.moveTo` / `_free()` translation is elided by the JIT unpredictably; the isolated windows pin guide-added `Transform2`s at zero.
  - New GI1-GI3, each looping the guide code with no tool and no baseline:
    - GI1 design: `PlanMoveGuides.begin` then `adjust`, prebuilt `raw`/`target` `Vector2`s mutated in place (`setFrom`), `base` the grab point. 10 and 200 references, 1 and 3 moved.
    - GI2 placement: `solveGuides(references.current, ...)` with the arguments `PlanSymbolTool._solveGuides` passes. `_solveGuides` reads the tool's private `_raw`, fixed by pointer events, so a hook could not vary its input; the direct call can. Box is a constant 2400 x 1600 mm, not the symbol's own. 10 and 200 references.
    - GI3 service: `ServiceTool.debugAim` (the real `_aim`, `references.current`, camera scale, `_movingSet`). 10 and 200 references, 1 and 3 moved.
    - Warm-up 4000 calls, 1000 metered, epoch floor subtracted, assert exactly 0. Watched: `Vector2`, `Transform2`, `Aabb2`, `GuideSolution`, `GuideReferences`, `_Float64List`, `_Set`.

## Measured counts (per 1000 events, net of floor)

Every window (all 10), every watched class: **0**. 1000 of 1000 events captured an axis in each (premise asserted at over 250). Identical in both solo runs.

Not watched: `_GrowableList` and `_List`. Tried in the first run; they read negative against the floor (`_GrowableList` -10525, `_List` -90954 in GI3 at 10 references, 1 moved; `_GrowableList` -8286 in GI1) because the RPC's own lists dominate the floor read (meter doc, failure mode 2). They cannot resolve zero, so they were removed from the isolated set. No fractional budget is used in GI.

## Mutations (applied after the commit, run, reverted with `git checkout <file>`; `git diff --stat` empty after each)

| # | Mutation | Real red lines |
|---|---|---|
| M1 (new) | `PlanMoveGuides.adjust`: field `debugLast = Transform2.translation(target.x - raw.x, target.y - raw.y)` | `GI1 ... 10 references, 1 moved: Transform2 over 1000 events`, Expected <0>, Actual <414> |
| M2 | `Float64List(8)` stored in a top-level field at the start of `solveGuides` | GI1 `_Float64List` Actual <880>; GI2 `_Float64List` (10 references) Actual <73>; GI3 `_Float64List` (10 references, 1 moved) Actual <1000> |
| M3 | `PlanMoveGuides.adjust`: `debugRaw = raw.clone()` kept in a field | `GI1 ... 10 references, 1 moved: Vector2 over 1000 events`, Actual <860> |
| M4 | `ServiceTool._aim`: `moving: Set<Handle>.of(_movingSet)` | `GI3 ... 10 references, 1 moved: _Set over 1000 events`, Actual <1000> |
| M5 | `ServiceTool._reaim` back to `camera.screenToWorld(Vector2(...))` (run with `--plain-name GA4` and `GA5`: the camera path is end-to-end only) | `GA4 service drag of one table Vector2, 10 references: on 100..100, off 0..0, control 0 over 250 events` (Actual <100>, limit 12.5); GA5 the same |
| M6 | `Paint()` kept per `GuidePainter.paint` (GA6) | `Paint: 100 over 100 paints`, Actual <1.0> |
| M7 | `GuideSolution.lines` reallocated in `reset()` with capacity +1 (GA7) | `Expected: true Actual: <false>` |

Gap: `PlanSymbolTool._solveGuides`'s own body is not isolated (GI2 calls `solveGuides` directly); GA3 still covers the tool end to end, minus `Transform2`.

## Gate (`packages/jet_cad_2d_plan`)

- `flutter test --enable-vmservice`, full suite three times, last lines:
  - run 1: `04:50 +1863: All tests passed!` (299 s wall)
  - run 2: `04:13 +1863: All tests passed!` (261 s)
  - run 3: `04:06 +1863: All tests passed!` (251 s)
- `flutter analyze`: `No issues found! (ran in 4.3s)`
- `dart format --output=none --set-exit-if-changed .`: `Formatted 362 files (0 changed)`, exit 0
- `flutter test --enable-vmservice test/invariants/guide_allocation_test.dart` alone, twice: `02:02 +10: All tests passed!` (126 s wall) and `02:04 +10: All tests passed!` (127 s wall)

## Timing

The file takes about 2:02-2:07 of test time (126-127 s wall including compile), over the roughly 100 s budget. From the run log: GA1-GA5 about 19 s each (95 s, unchanged); GI1 about 11 s, GI2 about 5 s, GI3 about 11 s (about 27 s together); GA6 and GA7 about 2 s. The GI cost is mostly the meter's RPC round trips (about 4 per window) and loading the 200-table plans, not the loops. Design windows share one controller per count; service windows cannot (a drag changes the document). To get back under 100 s: drop the 3-moved windows at 200 references, or cut the GA warm-up (600/200 events, deliberately long for the baseline's JIT elision, so left alone).

## Controller check

Mutation: `ServiceTool._aim` storing a `Transform2.translation(_dx, _dy)` in a static field per call -> GI3 red (`Expected: <0>`, `Actual: <395>`), reverted.
