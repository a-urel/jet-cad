# Task 1 report — the palettes (D2, D3, D6c constants)

## Files changed
- NEW `packages/jet_cad_2d_flutter/lib/src/canvas_palette.dart`: `ChromePalette` (rulerBackground, rulerInk, rulerPointer, sheetEdge; `light`/`dark`; `of(Brightness)`), `PaperPalette` (minorGrid, majorGrid, pageBreak, selection, hover, windowBand, crossingBand, grip, gripMove, gripHot, preview, snap; `light`/`dark`; `forPaper(int argb) = foregroundFor(argb & 0xFFFFFF) == 0xFFFFFF ? dark : light`), `kStatusCaptionOnLight = Color(0xFF202020)`, `kStatusCaptionOnDark = Color(0xFFFFFFFF)`. Both classes `@immutable`, const constructors, `==`/`hashCode` by value (`Object.hash`). `foregroundFor` imported from `package:jet_cad_2d` (`show foregroundFor`), not re-implemented.
- `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart`: `export 'src/canvas_palette.dart';`.
- NEW `packages/jet_cad_2d_flutter/test/canvas_palette_test.dart`.
- `chrome_style.dart` / `selection_style.dart`: **unchanged** (left as literals). A Dart `const` cannot read a field of a const object, so `const kX = ChromePalette.light.y` does not compile; per the brief's alternative, the constants stay as-is and a transitional equality test pins them to the `.light` fields. Task 3 deletes the constants and that one test.

## Tests added (test/canvas_palette_test.dart, 33 tests)
- M-DT-19 group: `ChromePalette.light, field by field`; `PaperPalette.light, field by field` (literals written out in the test, compared as name->Color maps so a failure names the field); `the old chrome and selection constants equal the .light fields` (transitional, Task 3 removes).
- `the dark palettes equal the D2 / D3 literals`: `ChromePalette.dark, field by field`; `PaperPalette.dark, field by field`; `the D6c caption colours`.
- `ChromePalette.of answers light for a light theme and dark for a dark one` (`same(...)`).
- M-DT-3 group: `the swatches and the greys either side of the WCAG switch` (an independent hand-written oracle — White/Ivory/Grey light, Blueprint/0x757575 dark, 0x767676 light — checked against both `forPaper` and `foregroundFor`); `dark exactly when foregroundFor is white, over a wide sweep` (all 256 greys, 9 saturated colours, 2 translucent values; asserts both sets are hit >50 times).
- M-DT-20 group: 18 tests `PaperPalette.dark.<field> has 3:1 on 0xff1f3a5f / 0xff303030` for the 9 opaque fields (also asserts alpha 0xFF); `ChromePalette.dark ruler ink and pointer have 4.5:1 on the bar`; `the contrast oracle reproduces the spec's measured values` (5.31, 7.46, 8.24, 21.0 — guards against a broken oracle). WCAG luminance is computed in the test itself (linearised sRGB), no production code.
- Pairings: `light|dark: window band = selection = grip, crossing band = snap`.
- Value equality: `ChromePalette compares by value, every field`, `PaperPalette compares by value, every field` (non-identical copy is `==` with equal hashCode; changing any one field breaks `==`; light != dark).

Red before the barrel export (compile errors: types undefined), green after: `00:00 +33: All tests passed!`.

## Mutant table
Each: backup copied to scratch, file mutated, `CI=true flutter test test/canvas_palette_test.dart` run in packages/jet_cad_2d_flutter, backup copied back, `diff` exit 0 ("restored ok"). Script: scratchpad/task1/mut.sh; logs scratchpad/task1/<id>.log.

| ID | file:line | change | red test(s) | real output excerpt |
|---|---|---|---|---|
| M-DT-3 | canvas_palette.dart:165 | `forPaper` = `((argb >> 8) & 0xFF) < 128 ? dark : light` (raw byte threshold) | M-DT-3 `the swatches and the greys either side of the WCAG switch`; `dark exactly when foregroundFor is white, over a wide sweep` | `Expected: same instance as <Instance of 'PaperPalette'> ... paper 0xff767676`; `+31 -2: Some tests failed.` |
| M-DT-1 | canvas_palette.dart:165 | `? light : dark` (inverted) | same two M-DT-3 tests | `+31 -2: Some tests failed.` |
| M-DT-19a | canvas_palette.dart:38 | light `sheetEdge` 0xFF9E9E9E -> 0xFF9E9E9F | `ChromePalette.light, field by field`; `the old chrome and selection constants equal the .light fields` | `+31 -2: Some tests failed.` |
| M-DT-19b | canvas_palette.dart:132 | light `hover` 0x991E6FE8 -> 0xFF1E6FE8 | `PaperPalette.light, field by field`; old-constants test | `+31 -2: Some tests failed.` |
| M-DT-20a | canvas_palette.dart:154 | dark `preview` -> 0xFF3A5070 | `PaperPalette.dark.preview has 3:1 on 0xff1f3a5f` and `on 0xff303030`; `PaperPalette.dark, field by field` | `Expected: a value greater than or equal to <3.0>  Actual: <1.4006141699161512>`; `+30 -3: Some tests failed.` |
| M-DT-20b | canvas_palette.dart:37 | dark `rulerPointer` -> 0xFFE53935 (today's light) | `ChromePalette.dark ruler ink and pointer have 4.5:1 on the bar`; `ChromePalette.dark, field by field` | `+31 -2: Some tests failed.` |
| M-DT-20c | canvas_palette.dart:44 | dark `rulerInk` -> 0xFF808080 | same two | `+31 -2: Some tests failed.` |
| EQ-paper | canvas_palette.dart:180 | `snap` dropped from `PaperPalette.==` | `PaperPalette compares by value, every field` | `+32 -1: Some tests failed.` |
| EQ-chrome | canvas_palette.dart:58 | `sheetEdge` dropped from `ChromePalette.==` | `ChromePalette compares by value, every field` | `+32 -1: Some tests failed.` |
| HASH-chrome | canvas_palette.dart:62 | `hashCode => identityHashCode(this)` | `ChromePalette compares by value, every field` | `+32 -1: Some tests failed.` |
| OF-swap | canvas_palette.dart:51 | `of` answers swapped | `ChromePalette.of answers light for a light theme and dark for a dark one` | `+32 -1: Some tests failed.` |
| OLD-const | chrome_style.dart:17 | `kRulerInk` 0xFF444444 -> 0xFF454545 | `the old chrome and selection constants equal the .light fields` | `+32 -1: Some tests failed.` |
| CAPTION | canvas_palette.dart:202 | `kStatusCaptionOnLight` -> 0xFF000000 | `the D6c caption colours` | `+32 -1: Some tests failed.` |
| MASK (survives, equivalent) | canvas_palette.dart:165 | `foregroundFor(argb)` without `& 0xFFFFFF` | none | `+33: All tests passed!` — equivalent: `foregroundFor` ignores the alpha byte (style_resolver.dart doc, shifts 16/8/0 only), so the mask is unobservable. Kept because the spec/brief require it. |

## Gates (this container, Flutter 3.47.6; logs in scratchpad/task1/gate-*.log)
| Package | flutter test | analyze | format |
|---|---|---|---|
| render `jet_cad_2d_flutter` | `+1273 ~1 -7` (branch point +1240 ~1 -7; +33 = the new file). The 7 failures are exactly the standing text-ladder goldens: `text_ladder_golden_test.dart` rungs 1-5 and `text_lod_ladder_golden_test.dart` rungs 1-2 (RenderBackend.canvas) | No issues found! | 216 files (0 changed) |
| planner `jet_cad_floor_plan` | `+1167: All tests passed!` | No issues found! | 193 files (0 changed) |
| `jet_cad_restaurant_symbols` | `+94: All tests passed!` | No issues found! | 13 files (0 changed) |
| app `floor_planner` | `+201: All tests passed!` | No issues found! | 44 files (0 changed) |
| demo `restaurant_demo` | `+17: All tests passed!` | No issues found! | 3 files (0 changed) |

Engine not edited, not run.

## Commit
- `23314be` feat(dark-theme): Task 1 — ChromePalette, PaperPalette and the caption colours

## Proposed rulings
- **R-C1-1** — The old colour constants in `chrome_style.dart` / `selection_style.dart` stay literal, not aliases. Reason: Dart `const` cannot read an instance field of a const object, so `const kSheetEdgeColor = ChromePalette.light.sheetEdge` does not compile; making them `final` would break any `const` use downstream (e.g. `const TextStyle(color: kRulerInk)` at ruler_painter.dart:134/168). A transitional test (`the old chrome and selection constants equal the .light fields`) pins them equal instead. Task 3 must delete both the constants and that test. Cost if wrong: none at runtime; one extra test to delete in Task 3.
- **R-C1-2** — The `argb & 0xFFFFFF` mask in `forPaper` is an equivalent mutant (`foregroundFor` already ignores alpha); kept because the spec writes it. No test can kill its removal. Cost if wrong: nil.

## Not fixed / notes
- Palettes have no `toString`, so a `same(...)` failure prints `Instance of 'PaperPalette'`; the M-DT-3 tests add a `reason:` naming the paper to make up for it. Later tasks may want a `toString` for diagnostics (not in spec, not added).
- Added beyond the plan's list: dark-literal tests (D2/D3 table), the caption-constant test, the pairings test, `of()` test, and an oracle sanity test reproducing the spec's measured ratios (5.31, 7.46, 8.24, 21.0).

## For the reviewer
- Check the M-DT-20 oracle in the test is independent (its own `relativeLuminance`/`contrast`; only production import used in the test for colour logic is `foregroundFor`, as the M-DT-3 differential side).
- The opaque-field list in M-DT-20 is hand-written (9 fields) and also asserts alpha 0xFF, so a field silently made translucent fails rather than drops out.
- Sweep in M-DT-3 includes translucent paper values (0x001F3A5F, 0x80FFFFFF).

Status: done.
