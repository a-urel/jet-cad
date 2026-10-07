# Task 2 report — the text (T1–T4)

Nothing is committed, staged or pushed. No `analysis_options.yaml` changed (`git status` lists none).

## Files changed

Source (6):
- `packages/jet_cad_2d/lib/src/geometry/grid_scale.dart`
  - `formatLength(mm, unit, {DecimalSeparator decimalSeparator = DecimalSeparator.point})`.
  - `_trim` takes the separator. It trims exactly as before, on the `.` form. It then returns `'0'` for `-0`, and otherwise `s.replaceFirst('.', decimalSeparator.char)`. So the swap comes after the trimming decision (T1, V-9).
  - Feet-inches are unchanged.
  - Doc comments state the rule and the order.
- `packages/jet_cad_2d_flutter/lib/src/ruler_painter.dart`: the major label is `formatLength(i * step, p.displayUnit, decimalSeparator: p.decimalSeparator)`. The ruler still formats once per major tick per paint (I-1).
- `packages/jet_cad_floor_plan/lib/src/parametric/dimension_geometry.dart`
  - `formatDimension(mm, unit, {decimalSeparator = point})`: cm and m print `decimalSeparator.char`. mm, inches and feet-inches are untouched.
  - `layoutDimension` passes `page.decimalSeparator`.
  - Stale doc of F-11 ("`.` as the decimal separator") rewritten; `DimLayout.text`'s doc mentions the separator.
- `packages/jet_cad_floor_plan/lib/src/parametric/room_label.dart`
  - `formatArea(mm2, unit, {decimalSeparator = point})`. Both the m² and ft² branches go through a private `_twoDecimals(value, sep)`, which is `toStringAsFixed(2).replaceFirst('.', sep.char)`.
  - The import adds `DecimalSeparator`. The stale doc of F-11 is rewritten.
- `packages/jet_cad_floor_plan/lib/src/parametric/room.dart`
  - `RoomType.pageKey` is now `(displayUnit, scaleDenominator, decimalSeparator)`; its doc comment and the class-doc bullet were updated.
  - `generate` passes `page.decimalSeparator`. `page` is `view.page ?? _defaultPage`, and `_defaultPage` is `PageComponent()`, so with no page it is `point`.
  - The generate doc's area bullet was updated.
- `packages/jet_cad_floor_plan/lib/src/parametric/dimension.dart`: `DimensionType.pageKey` gets the same three-field record, with its doc comment and class-doc bullet updated.

Tests (4 modified, 1 new):
- `packages/jet_cad_2d/test/geometry/grid_scale_test.dart`:
  - **Q0-F1** (comma: every *yes* cell of `formatLength`, plus the ft-in *no* cell unchanged);
  - **Q0-F2** (explicit `point` = today's literals).
- `packages/jet_cad_floor_plan/test/dimension_format_test.dart`: **Q0-DF1**. For each case it checks comma, explicit point and the default:
  - the yes cells: `345,7`, `250,0`, `3,46`, `14,00`, `0,05`;
  - the no cells, unchanged under comma: mm `3457`, in `135 7/8`, ft-in `11'-3 3/4"`.
- `packages/jet_cad_floor_plan/test/room_label_test.dart`: **Q0-RA1**. Every unit (every cell is *yes*) under comma, explicit point and the default.
  - It includes `12,37 ft²` (1,149,250 mm²), `12,37 m²` (12,370,050 mm²), `133,15 ft²`, `1234,57 m²` (no grouping) and `0,00`.
- `packages/jet_cad_2d_flutter/test/ruler_painter_test.dart`: **Q0-R1** (M-Q0-d).
  - The page is cm, 1:20, origin (−4180.5, 2645.25).
  - At 20 px/mm the step is premised to `GridScale.pick(...).majorMm == 5`. The major at page x 5 reads `0,5 cm` on a comma page and `0.5 cm` on a point page.
  - At 0.2 px/mm the major is premised at 500. The tick at page x 500 reads `0,5 m` / `0.5 m`.
  - Labels are read through `debugLastTicks`, as the file's existing test does.
- **New** `packages/jet_cad_floor_plan/test/decimal_separator_test.dart`. Its fixture follows the spec's fixture rule:
  - The page is cm, 1:20, origin (−4180.5, 2645.25), grid snap off.
  - A box of four 200 mm walls is placed at `corpus` (4.5e6, 1.2e6, turned 23°). Its inner area is 3,850 × 3,213 = 12,370,050 mm², which prints `12.37 m²`.
  - Room `Kitchen` is off the origin.
  - The dimension is in its own root group at plan (600.5, 4,400.25), turned a further 0.4 rad. It is aligned, 3,457.3 mm long, which prints `345.7` in cm.
  - Its tests:
    - **Q0-S1** (M-Q0-a), a unit test with the system live:
      - One `SetComponentCommand<PageComponent>` with `copyWith(decimalSeparator: comma)` gives undo depth +1. The area becomes `12,37 m²` and the value `345,7`.
      - The child handles are unchanged and `driftOf` is empty.
      - Undo restores `DraftDocumentCodec.encodeToString` byte for byte (through `enc`).
      - Redo gives the `,` texts again and the after-encoding byte for byte.
    - **Q0-E1** (M-Q0-h, rows), in the shell under an English UI (premise asserted: `FloorPlanStrings.of(...).decimalSeparator == '.'`):
      - With the room selected, the switch (a document command) makes the Area row `12,37 m²`, equal to the stored TEXT. Undo makes it `12.37 m²`.
      - With the dimension selected, Redo makes the Value row `345,7`. Undo makes it `345.7`, and executing the switch again makes it `345,7`.
    - **Q0-E2** (M-Q0-h, notice), in the shell under an English UI:
      - The Dimension tool (key I) is used at 0.12 px/mm: two clicks in empty space 3,457.3 mm apart, then a free hover.
      - On a point page `tool.notice` is `345.7` and the status line reads `Dimension — 345.7`.
      - Esc. Then on a comma page they are `345,7` and `Dimension — 345,7`.

## Callers checked (T4)

- `formatLength`: the ruler is its only caller (grep across `packages/`, `apps/`, `tool/`).
- `formatArea`: `RoomType.generate` is its only caller.
- `formatDimension`: `layoutDimension` is its only caller.
- `layoutDimension`'s callers:
  - `DimensionType.generate` (`dimension.dart:192`) and `diagnose` (`:252`) both pass `view.page ?? _defaultPage`.
  - `dimension_grips.dart:134` (preview) and `:191` (`_stateOf`) pass `_pageOf(d)`, the root page. They read only `q0/q1/ext/slash` and `layout.q0/q1` (`:104`), never `.text`.
  - `dimension_tool.dart:440` passes the root page. Its `.text` becomes the notice (`:463`), which is the only non-stored `.text` reader.
  - Test oracles (`test/support/dimension_fixture.dart` in the planner and in `apps/floor_planner`) pass `pageOf(doc)`, so they follow.
- No other place formats the plan's numbers.

## Decisions

- One `replaceFirst('.', char)` after formatting, rather than a branch on `point`. With `point` it returns the same characters, so I-4 holds, and every existing literal test stayed green unchanged. None had to change.
- The memo mutant (9) was chosen as **M9a**, "the rows' memo cleared only when the change touches the memoised object":
  ```dart
  if (c.touched.isEmpty || c.touched.contains(_areaRoom)) _areaRoom = null;
  ```
  and the same for `_valueDim`. It is a plausible "optimisation" that a page change defeats, since the page change touches the root and the TEXT children, not the group.
  - I also ran **M9b**: skip clearing when `touched` contains the root handle, i.e. a page change. This is the brief's suggestion.
  - I also ran **M9c**: only the Value memo gated. It shows the dimension half of Q0-E1 kills on its own.
- The new planner tests are in a new file, not appended to existing ones. M-Q0-a needs a room and a dimension in one plan and one history entry, which neither `room_object_test` nor `dimension_object_test` builds. The shell tests reuse the same fixture.
- Test ids use a `Q0-` prefix (Q0-F*, Q0-DF1, Q0-RA1, Q0-R1, Q0-S1, Q0-E*). Plain `RA2` and `DF4` were taken or ambiguous: `RA2` exists in `room_object_test`.

## Named mutants

Each mutant was applied by an exact-string replacement script. The listed tests were run, and the file was then restored from a byte copy in the scratchpad; `cmp` said identical after every restore.

| # | Mutant | Red tests | Failure line |
|---|---|---|---|
| 1 | separator left out of `RoomType.pageKey` | Q0-S1; Q0-E1 | Q0-S1: `Expected: ['Kitchen', '12,37 m²']` / `Actual: ['Kitchen', '12.37 m²']`. Q0-E1: `Expected: '12,37 m²'` / `Actual: '12.37 m²'`. Summary `+41 -2` (5 files). Re-run on the final test file: `+1 -2`. |
| 2 | separator left out of `DimensionType.pageKey` | Q0-S1; Q0-E1 | `Expected: '345,7'` / `Actual: '345.7'` in both. `+41 -2`. Q0-E2 stays green, as expected: the notice lays out afresh. |
| 3 | `other.decimalSeparator == decimalSeparator &&` removed from `PageComponent.==` (engine) | Q0-S1; Q0-E1 (planner) | `Expected: ['Kitchen', '12,37 m²']` / `Actual: ['Kitchen', '12.37 m²']`. `+1 -2`. |
| 4 | `formatLength` prints `.` always (`_trim` returns `s`) | Q0-F1 (engine); Q0-R1 (render) | `Expected: '1234,5 mm'` / `Actual: '1234.5 mm'` (`+14 -1`). `Expected: '0,5 cm'` / `Actual: '0.5 cm'` (`+6 -1`). |
| 5 | `formatDimension` cm prints `.` | Q0-DF1; Q0-S1; Q0-E1; Q0-E2 | `Expected: '345,7'` / `Actual: '345.7'`. `+7 -4`. |
| 5b | `formatDimension` m prints `.` | Q0-DF1 | `Expected: '3,46'` / `Actual: '3.46'`. `+10 -1`. |
| 6 | `formatArea` prints `.` (`_twoDecimals` without the replace) | Q0-RA1; Q0-S1; Q0-E1 | `Expected: '12,37 m²'` / `Actual: '12.37 m²'`. `+8 -3`. |
| 7 | `formatLength` swaps before trimming (`toStringAsFixed(...).replaceFirst('.', char)` first) | Q0-F1 | `Expected: '1234,5 mm'` / `Actual: '1234,500 mm'`. `+14 -1`. The test's later `2,5 cm` line would read `2,500 cm`. |
| 8 | ruler passes no separator | Q0-R1 | `Expected: '0,5 cm'` / `Actual: '0.5 cm'`. `+6 -1`. |
| 9a | rows' memo cleared only when the change touches the memoised object | Q0-E1, plus existing RN6 and PN1 (×2) | Q0-E1: `Expected: '12,37 m²'` / `Actual: '12.37 m²'`. `+18 -4`. |
| 9b | memo not cleared on a change touching the root (a page change) | Q0-E1, plus existing RN6 | `Expected: '12,37 m²'` / `Actual: '12.37 m²'`. `+20 -2`. **`dimension_panel_test` stays green**, so Q0-E1 is the only test that pins the Value memo across a page change. Re-run on the final test file: `+2 -1`. |
| 9c | only the Value memo gated on touching the dimension | Q0-E1 | `Expected: '345,7'` / `Actual: '345.7'`. `+2 -1`. |
| X1 | `RoomType.generate` passes no separator | Q0-S1; Q0-E1 | `Expected: ['Kitchen', '12,37 m²']` / `Actual: [... '12.37 m²']` |
| X2 | `layoutDimension` passes no separator | Q0-S1; Q0-E1; Q0-E2 | `Expected: '345,7'` / `Actual: '345.7'`. `+0 -3`. |

## Gates (actual summary lines, on the final tree)

- `packages/jet_cad_2d`:
  - `dart test`: `00:24 +1253 -2: Some tests failed.` The 2 failures are exactly the standing `generate_document_test` pair:
    - "the default document is the one Plan 2 measured, byte for byte"
    - "both text fractions default to zero and change nothing"
  - `dart analyze`: `No issues found!`
  - format: `Formatted 169 files (0 changed)`, exit 0.
- `packages/jet_cad_2d_flutter`:
  - `flutter test`: `01:26 +1334 ~1 -7: Some tests failed.` The 7 failures are exactly the text-ladder goldens: `text_ladder_golden_test` rungs 1–5 and `text_lod_ladder_golden_test` rungs 1–2, plus 1 skip.
  - `flutter analyze`: `No issues found! (ran in 6.0s)`
  - format: `Formatted 220 files (0 changed)`, exit 0.
- `packages/jet_cad_floor_plan`:
  - `flutter test`: `05:17 +1364: All tests passed!`
  - `flutter analyze`: `No issues found! (ran in 5.6s)`
  - format: `Formatted 235 files (0 changed)`, exit 0.
- `apps/floor_planner`:
  - `flutter test`: `01:53 +207: All tests passed!`
  - `flutter analyze`: `No issues found! (ran in 5.0s)`
  - format: `Formatted 46 files (0 changed)`, exit 0.
- `apps/restaurant_demo`:
  - `flutter test`: `00:26 +35: All tests passed!`
  - `flutter analyze`: `No issues found! (ran in 5.0s)`
  - format: `Formatted 4 files (0 changed)`, exit 0.
- `packages/jet_cad_restaurant_symbols`:
  - `flutter test`: `00:03 +97: All tests passed!`
  - `flutter analyze`: `No issues found! (ran in 4.7s)`
  - format: `Formatted 15 files (0 changed)`, exit 0.

The counts match Task 1's plus the new tests: engine +2, render +1, planner +5. The two allocation invariants pass inside these runs, untouched.

## Surprises / notes

- `dimension_panel_test` has no page-change test for the Value row, so before this task nothing pinned the Value memo across a page change (M9b survives there). Q0-E1 now covers it.
- Q0-E2 survives mutants 1–3, which is correct: the Dimension tool lays its notice out from the root page on every hover, so it reads neither `pageKey` nor `==`.
- The dimension tool's notice is recomputed on hover, not when a page change is heard while the pointer rests. Q0-E2 re-clicks and re-hovers after the switch. The existing TL5 covers the "heard off the canvas" path for units.
- `flutter test` runs `pub get` each time. `git status` showed no `analysis_options.yaml` change afterwards.

## Not done (by scope)

- `leak_test.dart:47-48`'s comment is left for Task 4.
- Not run: `tool/ci` tests. Nothing in docs or standing lists moved.
