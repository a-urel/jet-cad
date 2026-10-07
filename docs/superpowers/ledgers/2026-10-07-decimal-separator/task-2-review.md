# Task 2 review — the text (T1–T4), commit 44e96ef

Reviewer: independent; worked only in a clone at `/tmp/q0-t2-review/repo`, `44e96ef` checked out, `flutter pub get` at the workspace root. Nothing run in `/home/user/jet-cad`.

## Verdict: **Approved with fixes**

The source is correct against T1–T3 and F-1's table, `point` output is byte-identical, and every named mutant goes red, along with 13 of my own. One test gap (R-1) breaks the fixture rule: three plausible "UI leaks into the echo" mutants survive the **full** planner suite. It is cheap to close and belongs in this task (M-Q0-h). The rest are nits.

## Findings

**R-1 (important): M-Q0-h has only one direction of the fixture rule. The echoes are never pinned under a German UI on a `point` page.**
- Q0-E1 and Q0-E2 pump only an English UI (`decimal_separator_test.dart:109`, `:161`, `:191`). The spec's fixture rule (V-11) requires "a German UI on a `point` page" too, wherever the UI could leak in. The echoes are such a place: the panels format numbers with the UI separator (F-5, `selection_panel.dart:860-863`).
- Under an English UI, `replaceAll('.', strings.decimalSeparator)` is the identity, and a `comma` text has no `.`. So these three mutants survive:
  1. Area row: `selection_panel.dart:793` `…textAt(labels[1].$2).replaceAll('.', _strings.decimalSeparator)`
  2. Value row: `selection_panel.dart:813` `_valueText = text?.replaceAll('.', _strings.decimalSeparator)`
  3. Status notice: `planner_shell.dart:682` `_dimension.notice.value?.replaceAll('.', strings.decimalSeparator)`
- **Evidence:** I applied all three together and ran the whole planner suite: `06:40 +1364: All tests passed!`. The leak test's `_planText` regex accepts both `.` and `,`, and DT1 (Task 4) checks bytes, not panels, so no later task closes this.
- **Fix:** add a German-UI, `point`-page case to Q0-E1 and Q0-E2. It needs a `MaterialApp(locale: Locale('de'), supportedLocales: floorPlanSupportedLocales, localizationsDelegates: floorPlanLocalizationsDelegates, …)` plus the premise `decimalSeparator == ','`. Assert:
  - `room-area == '12.37 m²'`;
  - `dimension-value == '345.7'`;
  - the notice is `345.7`, and the status line reads `Bemaßung — 345.7`.
- **Checked:** I wrote exactly this as a probe. It passes on 44e96ef and turns each of the three mutants red:
  - `Expected: '12.37 m²' Actual: '12,37 m²'`
  - `Expected: '345.7' Actual: '345,7'`
  - `Expected: 'Bemaßung — 345.7' Actual: 'Bemaßung — 345,7'`

**R-2 (minor, report accuracy): the report's claim that the notice updates only on the next hover is wrong. There is no stale-notice defect.**
- The report's Surprises say "the dimension tool's notice is recomputed on hover, not when a page change is heard while the pointer rests". The code says otherwise:
  - `_onDocumentChange` (`dimension_tool.dart:353-359`) bumps `_generation` and calls `_refresh(ctx)`.
  - `_refresh` calls `_buildPreview` when two points are placed.
  - `_buildPreview`'s cache is keyed on `_generation` (`:420`), so it lays the dimension out again from the root page and sets `_notice`.
- **Probe:** two clicks, a hover (`345.7`), then the separator switch with the pointer at rest gives notice `345,7` and status `Dimension — 345,7`. Undo at rest gives `345.7`. Pointer off the canvas, then Redo, gives `345,7`. All green on 44e96ef.
- My mutant "the preview cache ignores the generation" is killed by the existing TL5 (`Expected: '6633' Actual: '6.63'`). TL5 covers the at-rest path for any page change.
- **Fix:** correct the report's note. Optionally, add the at-rest assertion to Q0-E2: one switch without Esc. It costs nothing, but nothing requires it.

**R-3 (nit): exponent forms.**
- Above 1e21, `toStringAsFixed` prints an exponent form. For example, `formatLength(1.5e21, mm, comma)` gives `1,5e+21 mm`, and `1e21` gives `1e+21 mm`, with nothing to swap.
- The behaviour is consistent: `point` output is unchanged, and the comma replaces only the mantissa's point. It is unreachable: the ruler labels visible ticks, and dimensions are capped at `kDimMaxValueMm = 1e15`. No action.

## Verified

**1. Correctness (T1–T3, F-1's table)**
- `formatLength`:
  - `_trim` decides the trim on the `.` form, maps `-0` to `0`, then swaps once.
  - Differential test against the parent's `_trim`: 400k random values plus edge values, in every unit:
    - default and explicit `point` equal the old output byte for byte;
    - `comma` equals the old output with its first `.` replaced, and never contains `.`.
  - Edge values: `0`, `-0.0`, `±0.5`, `1000`, `-0.0004`, `999.9995`, `9999.9996`, `1e-9`, `1e21`, `1.5e21`, `-1.5e22`, `double.maxFinite`.
  - Samples: `0.5 m` → `0,001 m`; `-0.5 mm` → `-0,5 mm`; `1000 mm` in m → `1 m`; ft-in has no separator.
- `formatDimension`:
  - Only the cm and m cells use `decimalSeparator.char`. mm, in and ft-in are untouched.
  - Carries happen in integer quanta before the split, so the separator cannot disturb them.
- `formatArea`: both branches go through `_twoDecimals`. Every cell is *yes*.
- With `point`, `replaceFirst('.', '.')` and `'${…}.${…}'` are the identity (I-4).
- `pageKey` is `(unit, scale, sep)` in both `room.dart:239` and `dimension.dart:164`.

**2. Callers** (grep of `packages/`, `apps/` and `tool/`)
- `formatLength` has one caller: the ruler, `ruler_painter.dart:103`.
- `formatDimension` has one caller: `layoutDimension`, `dimension_geometry.dart:417`.
- `formatArea` has one caller: `RoomType.generate`, `room.dart:315`.
- `layoutDimension` callers:
  - `dimension.dart:195` and `:255` both pass the view's page.
  - `dimension_tool.dart:440` passes the root page.
  - `dimension_grips.dart:134` and `:191` never read `.text`.
- The only `Generated.text` sites are a room's two and a dimension's one.
- The other `toStringAsFixed` uses in lib are the panel angle (UI separator by design, F-5) and the dev harness. Nothing was missed.
- The ruler repaints on a separator change: the page notifier fires on `PageComponent.==`, which includes the field.
- The stale comments of F-11 are updated, except `leak_test.dart`'s, which the plan gives to Task 4.

**3. Tests vs the fixture rule**
- Q0-R1: cm at 1:20, origin off zero, a non-identity camera, `0,5 cm` and `0,5 m`.
- Q0-S1: a room off the origin, turned, at 12.37 m²; a dimension in a turned group at 345.7; one history entry; Undo and Redo checked byte for byte.
- Q0-F1, Q0-DF1, Q0-RA1: every *yes* cell has a non-`.0` fraction; the *no* cells are checked unchanged; `point` and the default are pinned.
- The only gap is R-1.

**4. Mutants** (run in the clone, restored with `git checkout`; the clone is clean afterwards)

| Mutant | Result |
|---|---|
| 1 sep out of `RoomType.pageKey` | red: Q0-S1, Q0-E1 (`+9 -2`) |
| 2 sep out of `DimensionType.pageKey` | red (`+9 -2`) |
| 2b dim `pageKey` `(unit, scale, unit)` | red |
| 3 sep out of `PageComponent.==` | red: `['Kitchen','12.37 m²']` |
| 6 `formatArea` always `.` | red (`+8 -3`) |
| 7 `formatLength` swap before trim | red: `1234,500 mm` |
| 8 ruler passes no separator | red: `0.5 cm` |
| 8b ruler separator only in m | red: `0.5 cm` |
| 8c ruler separator only in cm | red: `0.5 m` |
| 9 memo never cleared | red |
| 9a memo cleared only if `touched` holds it | red: Q0-E1 `12.37 m²` |
| 9d only the area memo cleared | red: `345.7` |
| own: `formatArea` swaps only in m² | red: `133.15 ft²` |
| own: `formatArea` swaps only in ft² | red |
| own: `formatDimension` m prints `.` | red: `3.46` |
| own: `formatDimension` mm gains `,0` | red: `3457,0` |
| own: `formatLength` in / mm / m forced to `point` | red, each |
| own: `formatLength` default `comma` | red: Q0-F2 `1,5 m` |
| own: `-0` guard removed | red: `-0 mm` |
| own: `RoomType.generate` passes `point` | red |
| own: tool preview cache ignores the generation | red: TL5 |
| own: Area row / Value row / status notice re-localised with the UI separator | **survive the whole planner suite** (R-1) |

**5. Gates in the clone at 44e96ef**
- Engine:
  - `dart test`: `+1253 -2`. The 2 failures are exactly `generate_document_test`'s standing pair.
  - `dart analyze`: No issues found.
  - `dart format`: 0 changed.
- Render:
  - `flutter test` on `ruler_painter_test`, `ruler_frame_test` and `invariants/paint_allocation_test`: `+15`, all passed.
  - `flutter analyze`: No issues found.
  - `dart format`: 0 changed.
- Planner:
  - `flutter test` on `decimal_separator_test`, `dimension_format_test`, `room_label_test`, `dimension_tool_test` and `dimension_panel_test`: `+39`, all passed.
  - `flutter analyze`: No issues found.
  - `dart format`: 0 changed.
  - The full suite ran once only with R-1's three mutants applied: `+1364`, all passed. That count matches the report's clean count.

## Disposition (controller)

- R-1: fixed. Q0-E3 (German UI, point page: the Area and Value rows keep
  `.`, a switch to comma reaches the Value row) and Q0-E3b (the notice
  under German, `Bemaßung — 345.7` / `345,7`), Q0-E2's body shared as
  `noticeCases`. The reviewer's three UI-leak mutants: red (Q0-E3, Q0-E3,
  Q0-E3b; e.g. `Expected: 'Bemaßung — 345.7' Actual: 'Bemaßung — 345,7'`).
- R-2: the report's claim is wrong, recorded here; no stale notice.
- R-3: no action.
