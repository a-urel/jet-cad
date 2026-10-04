# Task 4b report — review fixes for Task 4 (wall faces, spec D3)

Implementer, plan 09c-1, Task 4b. Status: DONE. Committed `54eab37` `test(app): pin the face side test and nested cuts`. The parent is `274c780`. Not pushed. The change is test-only: `lib/symbols/wall_attach.dart` is byte-identical to `e73621f`, and no real defect appeared.

## Changes (2 files, +214 −57)

- **`apps/floor_planner/test/support/wall_attach_fixture.dart`**
  - `attachGroup(h, {mirrored, scale, double? rotation})`: an explicit group rotation overrides the handle-picked one, `0.3 + 0.7·(h % 9)`.
  - `attachScene(..., {List<double?> rotations})`: wall `i`'s group is turned `rotations[i]` when that value is given.
  - `teeScene(..., {double? hostRotation})`: turns the host's group.
  - Defaults are unchanged, so every existing scene is identical.
- **`apps/floor_planner/test/symbols/wall_faces_test.dart`**
  - **WF3 (finding 1, major).** The host group is now turned 0.3 (the default), 1.0 and 1.7 rad, giving 72 cases (previously 24). Each case asserts:
    - the group's rotation (`atan2` of `toWorld·(1, 0)`);
    - the premise that the local side test names the butted face;
    - a count of the cases where mapping the stem direction by `toWorld` instead of `toLocal` disagrees with the local test. `expect(disagree, 48)`: every case turned 1.0 or 1.7 rad disagrees, and no case at 0.3 rad does. Measured: a temporary print gave `DISAGREE 48` and was then reverted (diff 0).

    The existing exact cut and whole-face assertions run for all 72 cases.
  - **New test WF9 (finding 2, minor).** One face carries two cuts that meet, and the pieces are asserted exactly against the Cramer oracle (`crossU` on each wall's world face lines). It covers 2 angles × either face × 2 kinds, 8 cases:
    - **Nested.** A 60-thick square stem at 1850 (handle 19) sits inside the cut of a 240-thick stem at 35° from 1700 (handle 20). Premise: the inner cut is more than 100 mm inside the outer cut at both ends.
    - **A stem across an X.** A 60-thick square stem at 2110 overlaps the start of a 160-thick X at ±30° through 2100 on the butted face. Premises: on the butted face the stem's cut starts more than 20 mm before the X's and runs more than 20 mm into it. The obstacle order (`layoutInDocument(...).obstacles`) is `[X, stem]`, because the X's band interval starts on the other face.

    On each face the test expects the pieces `[0, lo]` and `[hi, 4200]` of the union of that face's cuts. The far face is whole (nested), or cut by the X alone.

### Why WF9 needs the X case

- The first version of WF9 used two T stems in both cases, and the no-sort mutant **survived** it.
- The reason is that `obstaclesOf` returns its obstacles sorted by `a` (08's band interval, along the same `d`). A face's cuts therefore arrive already in face order whenever each obstacle's interval starts where its cut on that face starts, which holds for T stems.
- The sort in `_pieces` only matters when an X's band interval starts on the *other* face. Hence the stem-across-an-X case.

## Mutants

Method: copy a backup, mutate, run `flutter test test/symbols/wall_faces_test.dart`, copy back, `diff` exit 0. The script is `scratchpad/task4b/mut.py`, the raw logs are `scratchpad/task4b/mut_<id>.log`, and the summary is `mutants.out`. After all four, a final `diff` against the pre-mutation copy exited 0.

| Id | Site | Change | Result | Red test, excerpt |
|---|---|---|---|---|
| R-4 toWorld (review finding 1) | wall_attach.dart:130 | `toLocal.transformDirection(...)` → `host.toWorld.transformDirection(...)` | **red** (it survived at `e73621f`) | WF3: `Expected: an object with length of <2>` / `Which: has length of <1>` / `30.0° left stem 70.0 host group 1.0 rad left: split` |
| M-09c-as (re-fired) | :130 | T side from the world left normal | **red** | WF5: `Expected: an object with length of <2>` / `30.0° stem 70.0: the butted face split` |
| R-5 merge (review finding 2) | :191 | `if (b > from) from = b;` → `from = b;` | **red** (it survived at `e73621f`) | WF9: `Expected: a value less than <1e-7>` / `Actual: <172.02841614876905>` / `30.0° left nested stems left piece 1: a + t·L ...` |
| no sort | :187 | `[...cuts]..sort(...)` → `[...cuts]` | **red** (it survived both `e73621f` and my first two-stem WF9) | WF9: `Actual: <33.20508075686758>` / `30.0° left a stem across an X left piece 0: a [100279.83..., -68454.29...], want [100251.08..., -68470.89...]` |

All four runs: `exit=1 diff=0`.

## Gates (app; `CI=true`, Flutter at /root/flutter)

| Gate | Result |
|---|---|
| `flutter test test/symbols/wall_faces_test.dart` | `+9: All tests passed!` |
| App `flutter test` (full suite, run before the commit) | `+1097: All tests passed!`, exit 0. The tree held the other implementers' work at the time; it was being committed concurrently as `7dbfc88`, `f424f9b` and `274c780`. |
| `flutter analyze` | `No issues found!` |
| `dart format --output=none --set-exit-if-changed .` | `Formatted 180 files (0 changed)`, exit 0 |
| Engine, render | Unchanged (no file under `packages/` was touched); not re-run |
| Web build | Not run. The brief's gates are app test, analyze and format, and the change is test-only. |
| `analysis_options.yaml` | Not staged (it is still modified in the tree, as `pub get` leaves it) |

## Notes

- **Scratch.** A temporary debug test, `test/symbols/zz_task4b_debug_test.dart`, printed the obstacle order. It was deleted before the gate and is not in the commit. That is how I found that `obstaclesOf` sorts by `a`.
- **WF3 margin at 1.0 rad.** The mutant turns the stem by 2θ = 114.6°, which puts it at sin(184.6°) ≈ −0.08 for the 70° stem and sin(4.6°) ≈ +0.08 for the −110° stem. That flips the sign, but only just. At 1.7 rad the flip is large (≈ ∓0.996), which is why both rotations are included.
