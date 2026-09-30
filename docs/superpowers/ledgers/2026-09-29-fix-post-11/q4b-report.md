# Q4b report: the Q4 review's m1, m2 and m3

Branch `fix/post-11`, worktree `.claude/worktrees/fix-post-11`, starting from `e82b4e7`. I committed but did not push. Only app files changed. `analysis_options.yaml` is untouched, and `git status --short` is clean after the commits.

## Commits

- **`416d92b`** fix(app): the page panel's scale and the status line show a number as text that parses back to it exactly (m1, m3).
- **`d4e7890`** test(app): WT20 pins the Wall tool's own thickness ceiling, set through its notifier (m2).

## What changed

### m3: one shared function

- **New file `apps/floor_planner/lib/panel_number.dart`.** It holds `panelNumberText`, with the same body as before. The doc comment now covers all three uses.
- **Removed from `selection_panel.dart`.** The function and its `@visibleForTesting` are gone from there. The annotation had to go: `page_panel.dart` and `main.dart` are other libraries, so they would have triggered `invalid_use_of_visible_for_testing_member`.
- **Three sites import the new file:** `selection_panel.dart`, `page_panel.dart` and `main.dart`.
  - `page_panel.dart`: `_number` is removed, and `_syncScale` calls `panelNumberText`.
  - `main.dart`: `_trimNumber` is removed, and `_zoomLine` calls `panelNumberText`.
- **`selection_panel_test.dart` imports `panel_number.dart`.** The import of `selection_panel.dart` was used only for `panelNumberText`. With it moved, analyze flagged that import as unused, so I removed it. SE18 still tests the function directly.
- **New tests in `test/planner_draw_test.dart`:**
  - **A26:** in the shell, a scale of 1e20 is committed by Enter in the page panel. It asserts one step and a stored value of exactly 1e20, and that the shown text parses back to 1e20. Then the test taps the field and presses Enter again on the unchanged text. It asserts the scale is still exactly 1e20, there is still one step, and the text is unchanged.
  - **A27:** the page is set to 1:1e20 with a `SetComponentCommand`, so this test does not depend on the panel. The `zoom-text` status line's scale, the part between `1:` and ` · `, parses back to exactly 1e20. It needs two pumps: `PageNotifier` hears the change from the asynchronous `changes` stream. With one pump the test read "1:20" (seen on my first run).

### m1

SE18's value list gains `1e19` and `-1.8e19`. Both are in [2^63, 2^64) in magnitude, one of each sign.

### m2

**WT20** in `test/wall_tool_test.dart` uses the direct rig, like WT18:

- **Setup:** `WallSettings(thickness: t)` is set on `rig.tool.settings`, the tool's notifier, with no panel.
- **Values:** t = 1e25 and t = `nextUp(kWallMaxThickness)`.
- **The click:** the wall runs from `plan(400, 900)` to `plan(3400, 1300)`. That is diagonal in the plan, turned 23°, at the far origin, about 3,030 mm long.
- **What is asserted, as in WT18:**
  - the second press returns normally;
  - no wall is added;
  - the handle seed is unchanged;
  - `enc(doc)` is byte-identical;
  - `undoDepth` is 0;
  - the chain ends (`isPending` false).
- **Then, at exactly `kWallMaxThickness`,** one wall lands with that thickness and `driftOf` is empty.

## Mutants

Every mutant followed the same procedure: `cp` to `scratchpad/q4b-bak-*`, mutate, run with `CI=true`, `cp` back, then `diff`. Every `diff` exited 0. Raw outputs are in `scratchpad/q4b-*.out`.

| Mutant | Change | Run | Result |
|---|---|---|---|
| M-R1 | In `panel_number.dart`, the integer branch taken below 2^64 (`v.abs() < 18446744073709551616.0`) instead of 2^53 | selection_panel_test | **red** `+30 -1`: SE18, `Actual: <9223372036854776000.0>` with reason `10000000000000000000.0 shows "9223372036854775807"` |
| M-R4 | `_addWall` uses the floor-only check, `w.thickness.isFinite && w.thickness > wallJoin.linear` | wall_tool_test + selection_panel_test | **red** `+51 -1`: WT20, `Expected: return normally … threw ArgumentError: … 12 generated a region whose boundary is not a closed polyline with a non-empty triangulation (spec 07 D8)` with reason `1e+25` |
| M-oldPage | `page_panel._syncScale` back to `v == v.roundToDouble() ? v.round().toString() : v.toString()` | planner_draw_test + page_panel_test | **red** `+31 -1`: A26 at the parse-back line (796), `Actual: <9223372036854776000.0>`, `the field shows "9223372036854775807"` |
| M-oldPage, parse-back line commented out | the same mutant, with A26:796 disabled, to check the step assertion on its own | planner_draw_test, A26 | **red** `+0 -1`: A26:802 `expect(model(), 1e20)` after the second Enter, `Actual: <9223372036854776000.0>`. The second Enter wrote 9.22e18 |
| M-oldStatus | `_zoomLine` back to the old `_trimNumber` formula | planner_draw_test + planner_shell_test | **red** `+39 -1`: A27:822, `Actual: <9223372036854776000.0>`, `the status line reads "1:9223372036854775807 · 9223372036854775807%"` |

## Gate

The gate is `export PATH=/root/flutter/bin:$PATH; (cd apps/floor_planner && CI=true flutter test && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed . && CI=true flutter build web --release)`. I ran it at HEAD `d4e7890` and the chain exited 0:

- `03:00 +503: All tests passed!` This is +500 at `e82b4e7`, plus A26, A27 and WT20.
- `No issues found! (ran in 2.0s)`
- `Formatted 103 files (0 changed)`
- `✓ Built build/web`

The output is in `scratchpad/q4b-gate-head.out`.

## Deviations and observations

- **`@visibleForTesting` dropped from `panelNumberText`.** It is now used by three libraries, not just its own; the reason is above. The test that exercises it, SE18, is unchanged apart from its import.
- **I kept the name `panelNumberText`,** even though the status line is not a panel, to keep the change small.
- **A27 sets the page by command,** not through the panel. This keeps its mutant independent of the page-panel fix.
- **Observation, out of scope, not fixed:** the status line's zoom percentage, `(zoom * 100).round()`, also saturates at an absurd scale. At 1:1e20 it reads "9223372036854775807%", with the fix and without it. It is display only, not a field, so no value is ever parsed from it.
