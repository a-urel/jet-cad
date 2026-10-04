# Task 2 report — the painters (D5 painters, R-8, R-13, R-14)

Start: branch head `23314be` (Task 1, approved).

## What was built (lib)
- `page_chrome_painter.dart`: `PageChromePainter` takes **required** `chrome: ChromePalette` (sheet edge, D2) and `paper: PaperPalette` (minor/major grid, page breaks, D3). The Paints stay fields with no colour in their initialisers; `paint` assigns `_sheetEdge.color = chrome.sheetEdge`, `_minor/_major/_breaks.color = paper.*` next to the existing `_sheetFill.color = Color(p.background)`. `shouldRepaint` => `old.chrome != chrome || old.paper != paper`.
- `ruler_painter.dart`: `RulerPainter` and `RulerCornerPainter` take a required `chrome`. Paint colours assigned at the top of `paint`. The label style is `late final TextStyle _labelStyle = TextStyle(color: chrome.rulerInk, fontSize: kRulerLabelSize)` per painter instance (R-8); `_label` / the corner use it. Each has a `@visibleForTesting TextSpan? get debugLastLabel` (the TextPainter's last span) so M-DT-6 reads the label colour. `shouldRepaint` => `old.chrome != chrome`.
- `ruler_frame.dart`: `RulerFrame` takes a required `chrome` and hands it to the corner and both bars.
- `selection_overlay.dart`: `SelectionOverlayPainter` takes a required `paper`; the seven Paints (selected, hover, preview, grip, move grip, hot grip, stem) keep their fields and are recoloured in `paint` right after the `size.isEmpty` return. `shouldRepaint` => `oldDelegate.paper != paper`, with the doc comment rewritten. Tool API untouched (Task 3).
- `jet_cad_floor_plan/lib/src/planner_view.dart`: passes `ChromePalette.light` to `RulerFrame` and `PageChromePainter`, `PaperPalette.light` to `PageChromePainter` and `SelectionOverlayPainter`, each with a `// Task 4:` comment.
- The four painter files no longer import or read any old colour constant (they still import `chrome_style.dart` / `selection_style.dart` for sizes). The constants themselves are untouched (R-C1-1, Task 3 deletes them). No palette `toString` added (not needed: the tests compare ARGB ints).
- `apps/dev_harness_2d`: constructs none of these painters (grep over `apps/` finds no `PageChromePainter(`, `RulerPainter(`, `RulerCornerPainter(`, `RulerFrame(`, `SelectionOverlayPainter(`); nothing changed there. Its analyze and tests were run (gates below).

## Mechanical test updates (pass `.light`, no expectation changed)
- `test/page_chrome_painter_test.dart` (rig + 3 direct constructions), `test/ruler_painter_test.dart` (2), `test/ruler_frame_test.dart` (2), `test/selection_overlay_grips_test.dart` (`overlayOf`), `test/outline_cache_test.dart` (1), `test/draw/draw_overlay_test.dart` (1), `test/support/grip_fixture.dart`, `test/support/selection_fixture.dart`.
- `test/selection_overlay_test.dart`: the `Rig.overlay()` helper (:55) gets `paper: PaperPalette.light`, the direct construction at ~:671 likewise, and the `canvas_palette.dart` import is added. **The Paint-identity tests (~:317-345) are not edited** — they build the painter through `r.overlay()`, so the fixture change carries them. Their line numbers shift by +1 because of the one import line; their text is byte-identical (`git diff` shows no hunk there).

## Tests added — `packages/jet_cad_2d_flutter/test/painter_palette_test.dart` (18 tests)
Fixtures: Blueprint `0xFF1F3A5F` with `ChromePalette.dark`; White only as the paired control and also under the dark chrome; the standard off-origin page (origin 7350, -1230) under `standardCamera()` (0.137 px/mm, panned); M-DT-5 has its own 0.05 px/mm panned camera placing the break at x = 300.5. The paper set is chosen by `PaperPalette.forPaper(page.background)`.
- PageChromePainter: `premise: Blueprint takes the dark paper set, White the light one`; `M-DT-4: a major-grid pixel is lighter than the bare paper on Blueprint, darker on White (both in the dark chrome)` (rasterised; brightest/darkest of the 3x3 block on a major line, midway between horizontal lines); `the grid Paints carry the paper set, minor and major` (recording canvas, both sets); `M-DT-5: on Blueprint a page-break pixel is the dark set's 0x8AB4F8, blue dominant and lighter than the paper` (pixel within 3 of 0x8AB4F8, then the Paint colour); `M-DT-7: the sheet edge's Paint.color is the chrome's, whatever the paper` (dark/Blueprint, dark/White -> 0xFF8A8A8A; light/Blueprint -> 0xFF9E9E9E); `its Paints are fields: the same objects on the next frame`; `shouldRepaint: true exactly when a palette differs, by value` (same const -> false; equal non-identical copies -> false; chrome-only flip -> true; paper-only flip -> true).
- Rulers: `M-DT-6: in the dark chrome the bar, ticks, marker and label colour are the dark set (recording canvas)` (bar 0x2B2D31, every non-marker line 0xC8C8C8, marker 0xFF6B66, `debugLastLabel.style.color` 0xFFC8C8C8); `M-DT-6: the corner box and its symbol are the dark set`; `M-DT-6: in pixels, the dark bar samples 0x2B2D31, its major tick and its label are light; the light bar stays 0xF2F2F2`; `in pixels, the dark corner box is 0x2B2D31 and its symbol light`; `the label style is built once per painter: the same TextStyle on every label and every frame`; `the ruler Paints are fields: the same objects on the next frame`; `shouldRepaint: true exactly when the chrome differs, by value` (ruler and corner; equal non-identical copy -> false).
- RulerFrame: `hands its chrome to the two bars and the corner, and a new one on a rebuild`.
- SelectionOverlayPainter (GripRig, rotated flipped camera, off-origin scene, Blueprint page): `the selection, hover, grips, hot grip and rotation grip take the paper set handed in (dark set, recording canvas)`; `the move preview takes the paper set handed in`; `shouldRepaint: true exactly when the paper set differs, by value`.

Note: these tests were written after the lib change (so no "red before" run of the whole file); every one is instead owed a mutant below that turns it red.

## Mutant table
Method: `scratchpad/task2/mut.py`. For each one it copies the file to scratch, applies an exact-string edit (occurrence-indexed), runs `CI=true flutter test test/painter_palette_test.dart` in packages/jet_cad_2d_flutter, copies the backup back, and runs `diff` (exit 0 every time, printed as `restored diff=0`). The logs are in `scratchpad/task2/<id>.log`. All 31 are red. Line numbers are the mutated line in the working copy before the commit. The commit's lib files are identical to that copy.

| ID | file:line | change | red test(s) | real excerpt |
|---|---|---|---|---|
| M-DT-4 | page_chrome_painter.dart:94-95 | minor+major `= PaperPalette.light.*` | M-DT-4 pixel test; `the grid Paints carry the paper set` | `Expected: a value greater than <62.931200000000004> Actual: <54.931200000000004>`; `+16 -2` |
| M-DT-4-major | :95 | major only `= PaperPalette.light.majorGrid` | same two | same pixel excerpt; `+16 -2` |
| M-DT-5 | :96 | `_breaks.color = PaperPalette.light.pageBreak` | M-DT-5 (the pixel assertion fires first, ahead of the Paint check) | `Expected: within 3 of 0xff8ab4f8 Actual: (int, int, int):<(51, 102, 204)>`; `+17 -1` |
| M-DT-7 | :93 | `_sheetEdge.color = ChromePalette.light.sheetEdge` | M-DT-7 | `Expected: <4287269514> Actual: <4288585374>` (0xFF8A8A8A vs 0xFF9E9E9E); `+17 -1` |
| M-DT-6-bar | ruler_painter.dart:64 | bar `= ChromePalette.light.rulerBackground` | M-DT-6 recording; M-DT-6 pixels | `+16 -2` |
| M-DT-6-ink | :65 | ink `= light.rulerInk` | M-DT-6 recording; M-DT-6 pixels | `+16 -2` |
| M-DT-6-marker | :66 | marker `= light.rulerPointer` | M-DT-6 recording | `+17 -1` |
| M-DT-6-label | :53 | ruler label `const TextStyle(color: kRulerInk, ...)` | M-DT-6 recording (`Expected: <4291348680> Actual: <4282664004>`, i.e. 0xFFC8C8C8 vs 0xFF444444); M-DT-6 pixels (`Expected: a value greater than <124.86...> Actual: <68.0>`) | `+16 -2` |
| M-DT-6-corner | :190 | corner box `= light.rulerBackground` | corner recording; corner pixels | `+16 -2` |
| M-DT-6-cornerlabel | :177 | corner label `const TextStyle(color: kRulerInk, ...)` | corner recording; corner pixels | `+16 -2` |
| LABEL-perframe | :147 | `_label` builds `TextStyle(color: chrome.rulerInk, ...)` per call | `the label style is built once per painter` | `+17 -1` |
| PAINT-perframe | page_chrome_painter.dart:98 | edge drawn with a fresh `Paint()` per frame | `its Paints are fields` | `+17 -1` |
| SR-chrome-false | :234 | `shouldRepaint => false` | PageChrome shouldRepaint | `+17 -1` |
| SR-chrome-nopaper | :234 | `old.chrome != chrome` only | same | `+17 -1` |
| SR-chrome-nochrome | :234 | `old.paper != paper` only | same | `+17 -1` |
| SR-chrome-identity | :234 | `!identical(...) \|\| !identical(...)` | same | `Expected: false Actual: <true>`; `+17 -1` |
| SR-ruler-false / -identity | ruler_painter.dart:159 | `false` / `!identical(old.chrome, chrome)` | ruler shouldRepaint | `+17 -1` each |
| SR-corner-false / -identity | :205 | same for the corner | ruler shouldRepaint (corner half) | `+17 -1` each |
| SR-overlay-false / -identity | selection_overlay.dart:329 | `false` / `!identical(oldDelegate.paper, paper)` | overlay shouldRepaint | `+17 -1` each |
| OV-selected, OV-hover, OV-grip, OV-gripMove, OV-gripHot, OV-stem | selection_overlay.dart:125,126,128,129,130,131 | each `= PaperPalette.light.<field>` | `the selection, hover, grips, hot grip and rotation grip take the paper set handed in` | e.g. OV-stem `Expected: <4286558975> Actual: <4280184808>`; `+17 -1` each |
| OV-preview | :127 | `_previewPaint.color = light.preview` | `the move preview takes the paper set handed in` | `+17 -1` |
| RF-corner | ruler_frame.dart:73 | corner gets `ChromePalette.light` | RulerFrame test | `+17 -1` |
| RF-left | :87 | left bar gets `ChromePalette.light` | RulerFrame test | `+17 -1` |

## Gates (this container, Flutter 3.47.6, `CI=true`; logs in `scratchpad/task2/gate-*.log`)

| Package | flutter test | analyze | format |
|---|---|---|---|
| render `jet_cad_2d_flutter` | `+1291 ~1 -7: Some tests failed`. Task 1 had +1273 ~1 -7; the 18 extra tests are the new file. The 7 failures are exactly the standing set: `text_ladder_golden_test.dart` rungs 1-5 and `text_lod_ladder_golden_test.dart` rungs 1-2 (RenderBackend.canvas). | No issues found! | 217 files (0 changed) |
| planner `jet_cad_floor_plan` | `+1167: All tests passed` | No issues found! | 193 files (0 changed) |
| `jet_cad_restaurant_symbols` | `+94: All tests passed` | No issues found! | 13 files (0 changed) |
| app `floor_planner` | `+201: All tests passed` | No issues found! | 44 files (0 changed) |
| demo `restaurant_demo` | `+17: All tests passed` | No issues found! | 3 files (0 changed) |
| `apps/dev_harness_2d` (extra, per brief) | `+82: All tests passed` | No issues found! | 22 files (0 changed) |

I did not edit or run the engine. `git diff 23314be..HEAD --stat` on `*analysis_options*`, `packages/jet_cad_2d`, `*golden*` and `*invariants*` is empty. `analysis_options.yaml` shows as unmodified in this container, and nothing was staged for it.

## Commit
- `2a439e0` feat(dark-theme): Task 2 — the painters take their palettes

## Proposed rulings
- **R-C2-1:** `RulerPainter` and `RulerCornerPainter` each gain a `@visibleForTesting TextSpan? get debugLastLabel`. This is the "painter's TextPainter" route M-DT-6 names: `SpyCanvas` sees only an opaque `Paragraph`, so it cannot read the span. The getter follows the existing `debugLastTicks` / `debugLastSymbol` seams. A pixel test of the label glyphs backs it up, using the test font's solid boxes. Cost if wrong: one getter per class to remove.
- **R-C2-2:** In the M-DT-5 test, the break sample sits where the break overlies the sheet's edge. At every camera, the only page-break lines that lie on the paper are the sheet's own edges; the others tile outward over the surround. The test therefore pixel-aligns the edge (x = 300.5) so that the break, drawn after the edge stroke, fully covers column 300. The pixel then reads exactly the break colour: the mutant gave `(51, 102, 204)` exactly. Cost if wrong: if Skia's AA changes, the ±3 tolerance may need widening. The Paint-colour assertion still holds.
- No other deviations from the spec or plan.

## Found, not fixed
- `RulerPainter._label` already allocated a `TextSpan` per label per frame before this task (`_text.text = TextSpan(...)`). This task removes only the per-frame `TextStyle` (it was `const` before, so it was not an allocation then either). The span allocation is pre-existing and outside invariant 1's measured path. I left it alone.
- `PageChromePainter.grid` changing does not trigger `shouldRepaint`, as before; the brief says to keep it that way.

## For the reviewer
- **M-DT-4 sampling.** The sampling point is chosen from the recorded lines: a major x right of the sheet's left edge, and a y midway between two horizontal lines from either pass, so the 3x3 block holds only the vertical major. The comparison is against the bare paper constant, by luminance with an 8-unit margin.
- **M-DT-6 pixel test.** Its positions (row 15 for bare bar, row 20 for the tick, (tick+5, 6) for the first label glyph) depend on the bar geometry: labels at y = 1 with a 10 px font, majors 12 px, minors 6 px. Note it also asserts a light-chrome control (bar 0xF2F2F2, dark tick and glyph).
- **selection_overlay_test.dart.** Check that `:317-345` (now :318-346) is untouched. The only hunks are the import, the `Rig.overlay()` helper, and the ~:671 construction.
- **PlannerView.** `PlannerView` passes `.light` everywhere, so the planner is unchanged until Task 4.

Status: done.
