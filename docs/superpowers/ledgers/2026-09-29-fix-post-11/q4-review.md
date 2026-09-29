# Q4 review: 0f8b073 (c), 9352103 (B), 1ba7b94 (`panelNumberText`)

I reviewed in the detached worktree `.claude/worktrees/fix-post-11-review`, at `1ba7b94`. I committed and pushed nothing.
- Every test command ran with `CI=true`.
- Every mutant and probe followed the same procedure: `cp` to `scratchpad/q4r-bak-<name>`, mutate, run, `cp` back, then `diff`. Every `diff` exited 0.
- My two temporary probe tests were deleted.
- At the end, `git status --short` shows only `packages/jet_cad/analysis_options.yaml`, which `flutter pub get` modified before this review. It is not committed.
- Raw outputs are in `scratchpad/q4r-*.out`.

## Verdict: **Approved**. No Important findings; five Minor ones.

## (1) (c): the ceiling

- **One predicate.** I grepped every thickness write in `apps/floor_planner/lib`:
  - `copyWith(thickness:)` is only in `selection_panel._write`, which is gated by `_parse` → `_valid` → `isWallThickness`.
  - The tool-settings keystroke path is `_validSetting` → `isWallThickness`.
  - The tool commit is `WallTool._addWall` → `isWallThickness`.
  - `WallParams(` is built only in `wall_tool.dart:229`, from the settings, and in `startup_plan.dart:316`, from constants of 250 and 120.
  - `main.dart:115` builds the default `WallSettings()` of 200.

  No other caller exists. Grips, move and rotate keep the stored thickness. The justification toggle doubles the offset, but it was inside the probe's sweep (3 justifications) and its edits are caught anyway.
- **Refused exactly like the floor.**
  - `_valid` returns false, so `_parse` gives null, nothing is written, and `_show` reverts. This is the same path WS3 uses for `0.000001`.
  - A keystroke is not written by `_validSetting`, so the setting keeps its last valid value. This is WS10's "200".
- **Reachability of the region-check throw with a user-typed thickness.** I ran my own sweep with the probe's pure predicate (`localOutlineOf(...).ring` fails `triangulates`, which the probe cross-checked against `execute`, 0 disagreements). It ran at HEAD, so with the fixed triangulator.
  - Setup: 3 justifications × 72 directions × 10 lengths (from 1e-6+ to 1000 mm) × 11 thicknesses (2e-6, 1e-5, 1e-3, 1, 50, 200, 1e4, 1e5, 1e6, 3e6, 1e7), at 6 placements.
  - Results: **0 failures** at UTM-like (5e8, 5.5e9), at (−3e9, 7e9), and in a group at (5e8, 5.5e9) turned 41°.
  - At (1e10, 1e10), (1e11, 1e11) and (1e12, 1e12), the only failures are at t = 2e-6 (344 / 1272 / 1080) and t = 1e-5 (0 / 488 / 1080). There are **none for any t in [1e-3, 1e7]**, 1e7 included. See `q4r-far2.out`.
  - So nothing at or below the ceiling throws through A anywhere. The residue is the floor mechanism (m5), which is pre-existing and not the ceiling.
- **WS10, WS11 and WP5 are non-degenerate.**
  - WS10's wall is diagonal in world (the plan is turned 23°) and far from the origin. At 1e25 and L ≈ 1504 its t/L is about 7e21, well past 1.15e16. It asserts that no exception reaches `takeException`, one wall at 200, one step, the exact seed range, and settings 200.
  - WS11 is wall A in its own rotated group, one ulp above the bound.
  - WP5 pins both boundaries and the literal 1e7.
- **The spec 07 D11 amendment is true.** The panel caught the throw (probe §1). The tool and grips did not, and a handle was consumed per click. The 1.33e10 and ≤1e10 figures match the probe's `q4p-bound` output, and 1e7 < 2^53. The known limit (a loaded thicker wall still throws on the tool and grip paths) is stated.

## (2) (B): the relative shoelace

- **Correctness.**
  - The shoelace over a closed loop is translation-invariant, so the relative form is the same sum mathematically.
  - `index[0]` is always point 0: `_dedupeConsecutive` keeps the earlier index and drops a trailing copy of the first point. A repeated first vertex therefore contributes a zero term.
  - The decision reads only `< 0`, so a triangulation can change **only** when that sign flips.
- **Exact reference** (`q4r-ref/ref.dart`: every double converted to an exact rational, the sum in BigInt).
  - 20,000 random rings at up to 1e10 on each axis, both windings: one third are thin rectangles (L from 1e-4 to 1e3, t from 1e-3 to 1e3, any angle), two thirds are simple star polygons with 5 to 12 vertices. Relative sign wrong: **0**. Raw sign wrong: **1,944**.
  - A ring with a consecutively repeated first vertex at 1e9: exact +, relative +1.4975, raw 0.0.
- **No existing result changes (differential).** I instrumented `_signedArea` to also compute the raw sum and print whenever `(raw < 0) != (rel < 0)`, then ran the full suites.
  - Engine `+1090 -2` (the standing two): 2 flips, both in the new far-ring tests.
  - Render `+940 ~1 -7` (standing): **0 flips**.
  - Harness `+82` all passed: **0 flips**.
  - App `+500` all passed: 4 flips, all the same ring (first vertex (498765456.76, 5498765425.43), raw −512 against +320), which is WT19's.

  No render golden, fill test or harness scene is sensitive to the change. The reference walk (`reference_walk.dart:270`) calls the same function, so it moves in lockstep anyway.
- **Allocation.** Two local doubles, still scalar, no new allocation. The triangulator is off the frame path, as before.
- **Other shoelace sums in the engine.** None; `_signedArea` is the only one.
- **Tests.**
  - `triangulate_test`'s far group asserts that the control move is exact (Sterbenz) and covers both windings.
  - WT19 is non-degenerate: 67°, UTM-like, a turned camera at 100 px/mm, exact snaps.
- **The spec 3e amendment is true.** −128/2 = −64 against 3.0/2 = 1.5 is in my flip log, and `_cross` is vertex-relative.

## (3) `panelNumberText`

- **Round trip.** I checked 1,998,992 random finite bit patterns with both signs, and the reverse sign of each. The HEAD formula shows every one as text that `double.parse` reads back `==` and with the same sign bit: **0 bad**.
- **Integer text is unchanged for |v| < 2^53.** `toInt().toString()` on an integral double equals the old `round().toString()`, for example 4503599627370497 → "4503599627370497" and 2^53 − 1 → "9007199254740991".
  - For values from 2^53 up to 2^63 the text changed. "9007199254740992" is now "9007199254740992.0". Both parse exactly.
  - Nothing in `lib` or `test` reads the old form: the grep finds only SE18 and the other two `_number` copies (m3).
- **−0 now shows "-0.0"** and round-trips. Before, it showed "0", which parsed to +0.0, but the `==` in `_write` (−0.0 == 0.0) made that a no-op. So this part is presentation, not a defect fix (m4).
- **Infinity and NaN** show "Infinity" and "NaN". Before, `round()` threw on a loaded infinite value.
- **The old code fails SE17 and SE18.** Detail in the mutants table below.

## Mutants fired

| Mutant | Change | Run | Result |
|---|---|---|---|
| M-q4-noUpperBound | `t.isFinite && t > wallJoin.linear` | selection_panel + wall_params | **red** +32 −4: WP5, WS10 1e100 and 1e25 (`ArgumentError: 1455 generated a region…` out of the click), WS11 (`'10000000.000000002'` against `'200'`) |
| M-q4-absShoelace (engine) | raw products back | triangulate_test | **red** +10 −2: both far rings |
| same (app) | same | wall_tool_test | **red** +19 −1: WT19 |
| M-q4-oldNumber | the old `round()` formula | selection_panel_test | **red** +29 −2: SE18 (the −0 sign), SE17 (`<3>` against `<4>`, the silent second step) |
| M-R1 (own) | integer branch below 2^64, not 2^53 | selection_panel_test | **survives**, +31 (m1) |
| M-R2 (own) | the −0 clause dropped | selection_panel_test | **red** +30 −1: SE18 |
| M-R3 (own) | `_validSetting` uses the old floor-only predicate | selection_panel + wall_tool | **red** +49 −2: WS10 ×2 |
| M-R4 (own) | `_addWall` uses the old floor-only predicate | selection_panel + wall_tool | **survives**, +51 (m2) |

## Minor

- **m1: SE18 does not pin the upper range.** M-R1 saturates [2^63, 2^64) to "9223372036854775807". For example 1e19 shows that text and parses back to 9.22e18 (verified in `q4r-ref/r1.dart`), yet it survives. SE18's value `9223372036854775807.0` is exactly 2^63, whose saturated text happens to parse back to 2^63. Adding 1e19 to SE18's list would kill M-R1. The HEAD code is correct.
- **m2: the tool's own ceiling guard is unpinned.** M-R4 survives. The settings reach `_addWall` above the bound only through the public notifier, since the panel filters every keystroke. No user path reaches it; WT18 pins only the floor. Setting `WallSettings(thickness: 1e25)` directly and clicking a diagonal wall would pin it.
- **m3 (outside scope, by reading, not driven): the same saturating formula lives in two more places.**
  - `page_panel.dart:92`: a scale of 1e20 is accepted (it is finite and > 0) and shows "9223372036854775807". A later Enter on that unchanged text writes 9.22e18 as a real step.
  - `main.dart:353` `_trimNumber`: the status line would show "1:9223372036854775807".

  Neither field commits on focus loss, so neither makes the silent step that SE17 fixed. The ruling named only `_number` in `selection_panel.dart`.
- **m4 (by reading, not driven): a −0.0 opening position now shows "-0.0", where it showed "0" before.** `OpeningTool._place` keeps `c = u` for a no-fit placement, and `uOf` = `(q − s)·d` is −0.0 when `q == s` and both components of `d` are negative. This follows the ruling ("parses back to the stored value exactly") and costs nothing, but it is visible, odd text.
- **m5 (pre-existing, not Q4's ceiling): the floor is absolute, while the far-away band collapse is relative.** At placements of 1e10 mm or more (UTM's northing edge and beyond), a Wall-tool wall typed at t = 2e-6, or 1e-5 from 1e11 on, still fails the region check (sweep above; predicate, not driven in a widget). Nothing fails at 7e9 or below.

## Gates at `1ba7b94`

`export PATH=/root/flutter/bin:$PATH`, `CI=true`.

| Gate | Test | analyze + format |
|---|---|---|
| [engine] | `00:24 +1090 -2: Some tests failed.`, exit 1. The two failures are the standing `generate_document_test` ("both text fractions default to zero…", "the default document is the one Plan 2 measured…") | "No issues found!", "Formatted 157 files (0 changed)", exit 0 |
| [render] | `01:10 +940 ~1 -7: Some tests failed.`, exit 1. The seven are `text_ladder` rungs 1–5 and `text_lod_ladder` rungs 1–2 | "No issues found!", "Formatted 177 files (0 changed)", exit 0 |
| [app] | `04:10 +500: All tests passed!` | "No issues found!", "Formatted 102 files (0 changed)"; chain exit 0 |

- **Harness.** It was not in my gate list. It ran once, under the flip instrumentation (print-only): `00:58 +82: All tests passed!`.
- **Expected counts.** Engine +1090 and app +500 match the expected numbers.
