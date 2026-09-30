# Q4b review: 416d92b (m1, m3) and d4e7890 (m2)

I reviewed in the detached worktree `.claude/worktrees/fix-post-11-review`, at `d4e7890`. I committed and pushed nothing.
- Every test command ran with `CI=true`.
- Every mutant followed the same procedure: `cp` to `scratchpad/q4br-bak-<name>`, mutate, run, `cp` back, then `diff`. Every `diff` exited 0.
- My one temporary widget probe (`test/q4br_probe_test.dart`) was deleted after its run.
- At the end, `git status --short` shows only `packages/jet_cad/analysis_options.yaml`, which was modified before this review. It is not committed.
- Raw outputs are in `scratchpad/q4br-*.out`.

## Verdict: **Approved**. No Important findings; one Minor, which is pre-existing.

## (1) m1, m2 and m3 are done as ruled, and nothing else changed behaviour

**Scope.** The diff touches only app files. `panel_number.dart` is new. `selection_panel.dart`, `page_panel.dart` and `main.dart` each gain an import and lose their local formula. Three test files change.

**m1 (ruling: SE18 adds 1e19).** SE18's list gains `1e19` and `-1.8e19`. Both are in [2^63, 2^64) in magnitude.

**m2 (ruling: a Wall-tool test with `WallSettings(thickness: 1e25)` set through the notifier).**
- WT20 sets `rig.tool.settings.value` directly, with no panel.
- It uses two values: 1e25 and `nextUp(kWallMaxThickness)`.
- It asserts what WT18 asserts: the press returns normally, no wall, the seed unchanged, the bytes unchanged, `undoDepth` 0, and the chain ends.
- Then a wall lands at exactly the ceiling.

**m3 (ruling: one shared function for the page panel's scale and the status line).**
- `panelNumberText` moved to `lib/panel_number.dart`.
- Its body is byte-identical to the old one in `selection_panel.dart` (checked in the diff). Only the doc comment grew.
- `_syncScale` and `_zoomLine` now call it, and `_number` and `_trimNumber` are gone.
- The Selection panel's call site (`selection_panel.dart:499`) is unchanged.
- **Dropping `@visibleForTesting` is required.** Two other libraries now call the function, so keeping the annotation would trigger `invalid_use_of_visible_for_testing_member`. No other library imported it from `selection_panel.dart` (grep). The zoom percentage `(zoom * 100).round()` is untouched, as ruled.

**Ordinary values are unchanged, by two differential checks against the old formula** `v == v.roundToDouble() ? v.round().toString() : v.toString()`:

- **Pure check** (`q4br-probe.out`). I compared 1,962,341 positive finite values: integers, dyadic fractions, values from 1e-10 to 1e30, and big integers.
  - The old and new text differ **0 times below 2^53**. They differ 415,514 times at 2^53 or above.
  - The new text parses back `==` every time: 0 bad.
  - Named values also match: 1, 20, 50, 75, 100, 200, 12.5, 0.5, 2.5, 1/3, 33.333333333333336, 0.1, 1e-9, 7.25, 150.75, 1e15 and 2^53 − 1.
  - The first differences are 2^53 ("9007199254740992" becomes "9007199254740992.0"), 1e16 (".0" appended) and 1e20 ("9223372036854775807" becomes "100000000000000000000.0").
  - For −0, the old formula gave "0" and the new one gives "-0.0". Infinity threw in the old formula and now shows "Infinity". The page panel refuses scales that are not finite and > 0, so a user cannot set either value there.
- **Widget probe in the real shell** (`q4br-widgetprobe.out`). I set each scale by command and read the `page-scale` field and the `zoom-text` line.
  - For 50, 75, 1, 100, 12.5, 2.5, 0.5, 1/3, 33.333333333333336, 7.25 and 1e15, the field and the status line's scale both **equal the old formula's text**. Examples: "1:75 · 284%" and "1:12.5 · 47%".
  - They differ only at 1e16 ("10000000000000000.0") and 1e20. Both still parse back exactly.

**What the existing tests pin.**
- Integers are pinned:
  - the page panel shows '75' and '20' (A18, A23, A24, A25);
  - `page_panel_test` commits '100';
  - the status line reads `'1:50 · …%'` (`planner_shell_test`).
- **No existing test pins a fractional scale at either site.** See m1 below. This was already true at `e82b4e7`, and the differential checks above show that the fractional text is unchanged.

## (2) A26, A27 and WT20 are non-degenerate

- **A26** starts from a 1:20 page, not the default. 1e20 is above 2^63, where the old formula saturates.
  - The second Enter goes through the real tap and `receiveAction(done)` on the field's shown text.
  - I checked the step assertion on its own. With the old page formula and A26's parse-back line (796) commented out, the test goes red at **A26:802**: `expect(model(), 1e20)`, `Actual: <9223372036854776000.0>`. The second Enter wrote 9.22e18 (`q4br-oldPage2.out`).
- **A27** sets the page by `SetComponentCommand`, so it does not depend on the page-panel fix. It reads the real `zoom-text` widget. Its two pumps are needed because the page reaches the shell through the asynchronous `changes` stream.
- **WT20** clicks from `plan(400, 900)` to `plan(3400, 1300)`.
  - That is off both axes locally, and the plan is turned 23° about the far origin. The wall is about 3,030 mm long.
  - `nextUp(kWallMaxThickness)` is not redundant with 1e25. It is the only value that catches a tool-side ceiling set too loose (own M-R5 below). At that value, t/L ≈ 3,300, so the region check does not throw and a wall would simply land.
  - The final wall at exactly 1e7 catches a strict `<` in the tool.

## (3) Mutants fired

| Mutant | Change | Run | Result |
|---|---|---|---|
| M-R1 | `panel_number.dart`: integer branch below 2^64 (`v.abs() < 18446744073709551616.0`) | selection_panel_test | **red** `+30 -1`: SE18, `Expected: <10000000000000000000.0> Actual: <9223372036854776000.0>`, reason `… shows "9223372036854775807"` |
| M-R4 | `_addWall`: floor-only `w.thickness.isFinite && w.thickness > wallJoin.linear` | wall_tool_test | **red** `+20 -1`: WT20, `Expected: return normally … threw ArgumentError: … 12 generated a region whose boundary is not a closed polyline with a non-empty triangulation (spec 07 D8)`, reason `1e+25` |
| M-oldPage | `_syncScale` back to the old inline formula | planner_draw_test + page_panel_test | **red** `+31 -1`: A26 (796), `Actual: <9223372036854776000.0>`, `the field shows "9223372036854775807"` |
| M-oldPage, A26:796 disabled | the same, plus the parse-back line commented out in the test file (both files backed up and restored, both `diff`s 0) | A26 only | **red** `+0 -1`: **A26:802**, `Actual: <9223372036854776000.0>` |
| M-oldStatus | `_zoomLine` back to the old inline formula | planner_draw_test + planner_shell_test | **red** `+39 -1`: A27:822, `the status line reads "1:9223372036854775807 · 9223372036854775807%"` |
| M-R5 (own) | `_addWall` ceiling loosened to 1e8 (`… && w.thickness <= 1e8`) | wall_tool_test | **red** `+20 -1`: WT20, `Expected: empty Actual: [18]`, reason `10000000.000000002` (only the `nextUp` entry catches it) |
| M-R6p (own) | `_syncScale`: `panelNumberText(page.scaleDenominator.roundToDouble())` | 3 files, then the **full app suite** | **survives**, `+44` and then `03:03 +503: All tests passed!` (m1) |
| M-R6s (own) | `_zoomLine`: the same `.roundToDouble()` | 3 files, then the **full app suite** | **survives**, `+44` and then `03:04 +503: All tests passed!` (m1) |

## Minor

**m1: a fractional scale's text is unpinned at both sites (pre-existing, not introduced here).**
- M-R6p and M-R6s round the scale before formatting. Both survive the whole app suite.
- Every test that pins these texts uses an integer: 20, 50, 75, 100 and 1e20.
- M-R6p is the one that matters. A 1:12.5 page would show "13" in the scale field, and Enter on that unchanged text would write 13 as a real step.
- The HEAD code is correct: the widget probe reads "12.5" and "1:12.5 · 47%".
- At `e82b4e7` the old formulas had no fractional pin either, so this gap was not introduced by Q4b.
- **Fix:** a scale of 12.5 in A26's pattern (field text "12.5", then Enter on it: no step) would kill M-R6p. Adding 12.5 to A27 would kill M-R6s.

**Nothing else.** The zoom percentage that saturates at absurd scales is already ruled as display only.

## Gate at `d4e7890`

`export PATH=/root/flutter/bin:$PATH; (cd apps/floor_planner && CI=true flutter test && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .)`

- `03:03 +503: All tests passed!` This matches the expected +503.
- `No issues found! (ran in 2.4s)`
- `Formatted 103 files (0 changed)`
- Chain exit 0 (`q4br-gate.out`).
