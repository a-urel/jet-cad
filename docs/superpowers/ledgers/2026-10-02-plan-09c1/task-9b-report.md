# Task 9b report: review fixes for Task 9 (leaf-equal reuse, spec D10)

Implementer worktree: `.worktrees/plan-09c1-t9b` (branch `wip/09c1-t9b`, parent `a073fb5`).
**Commit: `5f4c235`** `test(app): pin leaf-equal reuse's pairing, base point and first match` (both trailers). Not pushed.
Diff: 1 file, `apps/floor_planner/test/symbols/symbol_placer_test.dart` (+94 / -13). The change is test-only. No production change was needed, and no defect was found.
Scratch: `/tmp/claude-0/-home-user-jet-cad/05cf1abe-1171-54e2-83cf-ffde1eb9cfc8/scratchpad/task9b/` holds `mut.py`, `run_mut.sh`, `mut_<id>.log`, `mut_<id>.diff` and `gate_test.log`.

## Changes (group `leaf-equal reuse`)

1. **Finding 1 (base point per axis).** Added a helper `movedBase(e, by)`. The L1 edit "a moved base point" (y only) is now two edits: "a base point moved in y" (`Vector2(0, 1e-9)`) and "a base point moved in x" (`Vector2(1e-9, 0)`). Both run the whole L1 body.
2. **Finding 2 (pairing order).** New test **L6**: "a definition whose leaves sit out of handle order in the slots is reused". Two loose lines are added, and the test asserts they sit at slots `[0, 1]`. They are then removed in ascending slot order, and the first placement follows. The premise is asserted three ways:
   - the definition's leaf handles in `liveSlots` order differ from their ascending-handle order;
   - the lowest-handle leaf (line) sits at slot 1;
   - the polyline sits at slot 0.

   The test then checks that `isLeafEqual` is true. A second placement (q=1, mirrored) must reuse the definition: one definition, no new live entity, both instances on it.
3. **Finding 3 (first match).** New test **L7**: "of two leaf-equal definitions with the key and version, the lower handle is reused". The steps:
   - place;
   - edit the first definition's text leaf (`Sofa`), then place again, which creates copy `#2`;
   - restore the text (`SOFA`) by a fresh `SetEntityTextCommand`;
   - assert both definitions are leaf-equal and that `first < second`;
   - place a third time.

   The instance must land on `first`, with 2 definitions and no new live entity.

The reviewer's probe was adapted, not committed as is. Its unused `leaf` variable was dropped, and L6/L7 now assert the premise and the counts.

## Gates (`apps/floor_planner`, `CI=true`, `PATH=/root/flutter/bin:$PATH`)

| Gate | Result |
|---|---|
| `flutter test` | `08:15 +1124: All tests passed!`, exit 0 (was 1121: +1 L1 x edit, +L6, +L7) |
| `flutter analyze` | `No issues found! (ran in 8.2s)`, exit 0 |
| `dart format --output=none --set-exit-if-changed .` | `Formatted 180 files (0 changed)`, exit 0 |

The engine and the render layer are untouched (the diff is test-only, inside the app), so I did not re-run them. The web build is unaffected by a test-only change and was not re-run. `symbol_placer_test.dart` alone: `+57: All tests passed!` (was 54).
`packages/jet_cad/analysis_options.yaml` is dirty from `pub get` and was not staged.

## Mutants (on `lib/symbols/symbol_placer.dart`, run with `test/symbols/symbol_placer_test.dart`)

Each mutant: `cp` backup, mutate (`mut.py`), run, `cp` back, `diff -q` exit 0. Every run printed `[restored]`.

| Id | Mutation | Result | Red test, real output |
|---|---|---|---|
| base x only | `:199` → `def.basePoint.x != base.x` (y comparison dropped) | `+56 -1`, exit 1 | L1 "a base point moved in y": `Expected: false / Actual: <true>` |
| base y only | `:199` → `def.basePoint.y != base.y` (x comparison dropped) | `+56 -1`, exit 1 | L1 "a base point moved in x": `Expected: false / Actual: <true>` |
| no sort | `..sort(...)` at `:206-207` removed (pair in slot order) | `+56 -1`, exit 1 | L6: `Expected: true / Actual: <false>` (the `isLeafEqual` premise check) |
| last match | `break;` at `:117` removed (the last leaf-equal candidate wins) | `+56 -1`, exit 1 | L7: `Expected: <18> / Actual: <26>` (instance on the second definition) |

All three surviving mutants from the review (base x only, no sort, last match) are now killed. The y half stays killed.
