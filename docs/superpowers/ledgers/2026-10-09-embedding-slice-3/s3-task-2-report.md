# Slice 3, Task 2: the selection colours, their width and the canvas (implementer's report)

- **Branch:** `claude/exciting-pasteur-9m22jv`, from `620dabd` (Task 1).
- **Commit:** `58c4a60`. Pushed as `620dabd..58c4a60`.
- **Environment:** Flutter 3.47.6 at `/root/sdk/flutter/bin`, with `CI=true`.
- **`analysis_options.yaml`:** none touched or committed. Before the commit, `git status` showed only the eight task files.
- **Scope:** only Task 2. Nothing of Task 3 is in this commit: the three selection-mode painters, the bar and `_theme` in their repaint merges are untouched. The engine is not edited. `jet_cad_2d_flutter` is edited additively, in two files. No existing test was edited. `paint_allocation_test` is untouched (S-1).

## Files

| File | Lines | What |
|---|---|---|
| `packages/jet_cad_2d_flutter/lib/src/canvas_palette.dart` | +22 −1 | `PaperPalette withSelection(Color selection)`: a copy with `selection` and a derived `hover`, which is `selection.withValues(alpha: selection.a * 0x99 / 0xFF)`; the ten other colours are kept. The `hover` doc points to it. |
| `packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart` | +23 −12 | Named optional `selectionStrokePixels = kSelectionStrokePixels`, asserted finite and above 0. Its four uses (S-8): the world outline `/ scale`, the screen-space selected stroke, the selected cross's `3 ×` half-length and the preview cross's `3 ×` half-length. The hover keeps `kHoverStrokePixels`. `shouldRepaint` is `paper != … \|\| selectionStrokePixels != …`. |
| `packages/jet_cad_floor_plan/lib/src/host/floor_plan_theme.dart` | +19 | `@internal paperPaletteFor(int paperArgb, FloorPlanTheme? theme)`. It takes the set `forPaper` picks. For the dark set it reads `selectionOnDark`, for the light set `selectionOnLight`; when that colour is non-null it returns `set.withSelection(colour)`, otherwise the const set itself. It imports `PaperPalette` from `jet_cad_2d_flutter` with `show`. |
| `packages/jet_cad_floor_plan/lib/src/planner_view.dart` | +8 | Optional `selectionStrokePixels = kSelectionStrokePixels`, passed to the overlay. |
| `packages/jet_cad_floor_plan/lib/src/planner_shell.dart` | +17 −8 | Task 1's `// ignore: unused_field` on `_floorTheme` is removed. See "Wiring in both modes" below. |
| `packages/jet_cad_floor_plan/lib/src/host/service_view.dart` | +15 −5 | The same wiring as the shell, reading `_theme.value`. See below. |
| `packages/jet_cad_2d_flutter/test/selection_theme_test.dart` | new, 10 tests | The render tests. |
| `packages/jet_cad_floor_plan/test/host/theme_canvas_test.dart` | new, 20 tests | The planner tests. |

**Wiring in both modes.** `planner_shell.dart` and `service_view.dart` make the same four changes:
- `_canvasColour(scheme)` returns `theme?.canvasBackground ?? scheme.surface`. The shell reads `_floorTheme`; `ServiceView` reads `_theme.value`.
- `didChangeDependencies` sets the theme before `_surfaceArgb`, so `_surfaceArgb` comes from `_canvasColour`.
- The surround's `ColoredBox` is painted with `_canvasColour(scheme)`.
- `PlannerView` gets `paper: paperPaletteFor(_paperArgb(), theme)` and `selectionStrokePixels: theme?.selectionWidth ?? kSelectionStrokePixels`.

Style values are derived in `build` and `didChangeDependencies`, never in `paint` (P-4). The overlay still assigns `paper.selection` to its own `Paint` once per frame; S-12 rules that this is a field load, not a derivation. With no theme, the code takes today's path:
- the paper is the identical const set;
- the width is `kSelectionStrokePixels`;
- the canvas colour is `scheme.surface`.

## Tests

### Render: `test/selection_theme_test.dart` (10 tests)

- **`withSelection` keeps today's hover.** For both sets, `set.withSelection(set.selection) == set`, and its `hover` equals the set's hover (and its ARGB). The result is a copy, not the identical object.
- **T2-a:** `withSelection(0xFFD81B60)` gives selection `0xFFD81B60` and hover `0x99D81B60`, on both sets.
- **Translucent selection:** `0x80D81B60` gives a hover whose `a` is `0x80/255 × 0.6`, with the same RGB.
- **The ten other colours** are the set's own. The test also checks that the two sets differ in each of the ten, so a copy that took them from the wrong set would show.
- **Default width:** `selectionStrokePixels` is `kSelectionStrokePixels` when not given.
- **4 px under a rotated, non-uniform camera** (`:413`'s camera, `b ≠ c`, scale ≠ 1):
  - the recorded outline strokes `4 / scale` in `0xFFD81B60`;
  - the hover strokes `1.5 / scale` in `0x99D81B60` (T2-c).
- **Point crosses at 4 px:** the selected point's cross is stroked 4 px with a 12 px half-length. The hovered point's cross stays 1.5 px with a 4.5 px half-length. Both points sit under turned, scaled groups.
- **The move preview's point cross** has a 12 px half-length at 4 px. Its stroke stays the preview's.
- **`shouldRepaint`:**
  - true for a width alone;
  - false for an equal, non-identical palette with an equal width;
  - true for the selection colour alone.
- **Paints reused (S-1):** the themed sibling of `selection_overlay_test.dart:320`. It uses the dark set with `0xFFD81B60` and 4 px, and pans between the two frames. The same two `Paint` objects reach the canvas, and they are distinct from each other. Each frame carries the themed colours and widths.

### Planner: `test/host/theme_canvas_test.dart` (20 tests)

The tests run on `palette_fixture.dart`, through `FloorPlanView`, in both modes unless noted. The theme is given as `theme:` or as the ambient extension.

- **Premise:** the theme's colours are none of the sets' colours. `0xFF263238` inks white, and the seed's light surface inks black.
- **`paperPaletteFor`:**
  - with no theme, or with no colour for the paper's set, it returns the identical const set;
  - with a colour for the set, it returns `withSelection` of that colour;
  - a theme with only a width returns the identical const set.
- **P-6** (×2 modes): with no theme, `PlannerView.paper` is identical to `PaperPalette.light`, and the width is 2 for both the view and the overlay. The pixels show today's selection, and the surround is `scheme.surface`.
- **M-H33(the editor's selection)** (×2): under the light theme, White's selected pixel is `0xD81B60` and Blueprint's is `0xFFD54F`. `PlannerView.paper` and the overlay's paper equal `set.withSelection(…)`.
- **`selectionOnDark` on the dark canvas** (×2): a dark theme over a White page gives `0xFFD54F`, and the ink is light.
- **Only `selectionOnLight`** (×2):
  - Blueprint keeps `0x7FB2FF`, and the view's paper is identical to `PaperPalette.dark`;
  - White gives `0xD81B60`.
- **`selectionWidth: 4`** (×2):
  - Control: with no theme, the rows `sy−1` and `sy+1` are not the selection colour, because a 2 px stroke covers them only half.
  - Then the view's theme changes to `{selectionWidth: 4}` alone, with the camera still, and one pump runs (T2-b). Both rows are now the selection colour, and the paper is still the const set.
- **M-H33(canvasBackground)** (×2): a page-less plan, the light theme and `canvasBackground: 0xFF263238`.
  - The surround is `0x263238` at two points.
  - The ink is white.
  - The selection is `0x7FB2FF`, and the view's paper is `PaperPalette.dark`.
- **T2-d** (×2): a White page with `canvasBackground`.
  - The pixel beside the sheet is `0x263238`.
  - The sheet's fill is `0xFFFFFF`.
  - The ink is dark, and the selection is the light set's.
- **Invariant 4** (×2):
  - First, `designJson()` and a 96 dpi PNG export are taken through the view's Export, with no theme.
  - Then the view is given the full theme (every field set to a non-default value) under an ambient `{selectionWidth: 3}`. The overlay's width of 4 proves the theme is in force.
  - The export bytes and `designJson()` are equal to the first ones.
- **T2-a, planner** (design mode): the ink witness line is hovered under `selectionOnLight: 0xD81B60`. The hovered pixel matches the test's own straight-alpha composite at `0x99/0xFF` over the pixel captured before the hover, within 3 per channel.
- **Bare `PlannerShell`** (ambient only): a page-less plan under the ambient extension `{canvasBackground, selectionOnDark, selectionWidth: 4}`.
  - The surround is `0x263238`.
  - The ink is light.
  - The selection is `0xFFD54F`, and the 4 px rows are covered.

### Unedited and green (P-6)

No existing test file was edited; `git status` showed only the two new test files.

- **Render:** `painter_palette_test`, `selection_overlay_test` (`:299`, `:320`, `:592`), `selection_overlay_grips_test`, `tool_palette_test`, `dark_canvas_test`, `golden/*` and `invariants/paint_allocation_test` are all inside the 1389-test run, which matches the standing set exactly.
- **Planner:** `planner_palette_test`, `dark_canvas_test`, `host/view_palette_test`, `canvas_ui_test`, `widget_theme_test` and `host/status_caption_test` are all inside the 1643.
- **`apps/floor_planner`:** 212 tests.

## Mutants

The runner was `scratchpad/s3t2-impl/run.py`. For each mutant it:
- asserts that each edit matches exactly once;
- runs the named test file with a JSON reporter;
- lists the failing tests by name;
- restores the file from an in-memory copy in a `finally`.

After the whole run, `md5sum -c` over the six source files was OK, and `git diff` was identical to the diff saved before the mutants.

| Mutant | Red killers |
|---|---|
| **M-H33(canvasBackground)**: shell `_surfaceArgb` left on `scheme.surface` | `M-H33(canvasBackground) (design)…`; `a bare PlannerShell reads the ambient extension…` |
| **M-H33(canvasBackground)**: the same in `ServiceView` | `M-H33(canvasBackground) (selection)…` |
| **M-H33(the editor's selection)**: shell uses `PaperPalette.forPaper` (ignores the theme) | `M-H33(the editor's selection) (design)…`; `selectionOnDark on the dark canvas (design)…`; `only selectionOnLight (design)…`; `T2-a: a hovered line…`; `a bare PlannerShell…` |
| **M-H33(the editor's selection)**: the same in `ServiceView` | `M-H33(the editor's selection) (selection)…`; `selectionOnDark on the dark canvas (selection)…`; `only selectionOnLight (selection)…` |
| **M-H33(the editor's selection)**: the sets swapped in `paperPaletteFor` | `paperPaletteFor: today's const sets…`; `M-H33(the editor's selection)`, `selectionOnDark on the dark canvas` and `only selectionOnLight`, each in both modes; `T2-a…`; `a bare PlannerShell…` |
| **T2-a**: hover not derived (`hover: hover`), render run | `T2-a: the hover is the given selection at 60% alpha`; `a translucent selection gives a hover…`; `at 4 px under a rotated, non-uniform camera…`; `the two Paints are reused across frames under a themed palette…` |
| **T2-a**: the same mutant, planner run | `T2-a: a hovered line in the design mode reads the theme's selection at 60%…`; `a bare PlannerShell…` |
| **T2-b**: `shouldRepaint` ignores the width, render run | `shouldRepaint: true for a width alone, false for equal ones (T2-b)` |
| **T2-b**: the same mutant, planner run | `selectionWidth: 4 (design) covers the rows…`; `selectionWidth: 4 (selection) covers the rows…` (the theme change with one pump) |
| **T2-c**: the width applied to the hover outline | `at 4 px under a rotated, non-uniform camera … the hover stays 1.5 / scale (T2-c)`; `the two Paints are reused…` |
| **T2-c**: the width applied to the hover's cross | `at 4 px a selected point's cross … a hovered point's stays 1.5 px and 4.5 px` |
| **T2-d**: shell `ColoredBox` left on `scheme.surface` | `T2-d (design)…`; `M-H33(canvasBackground) (design)…`; `a bare PlannerShell…` |
| **T2-d**: the same in `ServiceView` | `T2-d (selection)…`; `M-H33(canvasBackground) (selection)…` |
| **Task 1 finding 2**: shell drops `_floorTheme = …` | 9 tests, every design-mode one: `M-H33(the editor's selection) (design)`, `selectionOnDark…(design)`, `only selectionOnLight (design)`, `selectionWidth: 4 (design)`, `M-H33(canvasBackground) (design)`, `T2-d (design)`, `invariant 4 (design)`, `T2-a`, `a bare PlannerShell` |
| **Task 1 finding 2**: `ServiceView` drops `_theme.value = …` | 7 tests, every selection-mode one: `M-H33(the editor's selection) (selection)`, `selectionOnDark…(selection)`, `only selectionOnLight (selection)`, `selectionWidth: 4 (selection)`, `M-H33(canvasBackground) (selection)`, `T2-d (selection)`, `invariant 4 (selection)` |
| X1: the selected cross half-length reads the const | `at 4 px a selected point's cross…` |
| X2: the preview cross half-length reads the const | `at 4 px the move preview's point cross has a 12 px half-length` |
| X3: the screen-space selected stroke reads the const | `at 4 px a selected point's cross…` |
| X4: the world outline stroke reads the const | `at 4 px under a rotated, non-uniform camera…`; `the two Paints are reused…` |
| X5: `PlannerView` does not pass the width | `selectionWidth: 4` in both modes; `invariant 4` in both modes; `a bare PlannerShell…` |
| X6: `ServiceView` passes the const width | `selectionWidth: 4 (selection)`; `invariant 4 (selection)` |
| X7: the shell passes the const width | `selectionWidth: 4 (design)`; `invariant 4 (design)`; `a bare PlannerShell…` |
| X8: `withSelection` keeps the set's selection | `T2-a: the hover is…`; `a translucent selection…`; `at 4 px under a rotated…`; `the two Paints are reused…` |
| X9: `withSelection` takes `grip` from the light set | `the derivation is today's hover, exactly, for both sets`; `the ten other colours are the set's` |
| X10: `paperPaletteFor` always copies (P-6 structural) | `paperPaletteFor: today's const sets…`; `P-6` in both modes; `only selectionOnLight`, `selectionWidth: 4`, `M-H33(canvasBackground)` and `T2-d`, each in both modes |

Task 1's finding 2 is closed for the parts this task paints: a mutant that drops either stored copy's assignment is red.

## Gates (real results)

The gates ran after the code and tests were final, from the committed tree.

| Gate | Result |
|---|---|
| `packages/jet_cad_2d_flutter` | `flutter test --file-reporter json:…` exits 1 on the standing failures. `expect_failures --package packages/jet_cad_2d_flutter --root packages/jet_cad_2d_flutter`: "packages/jet_cad_2d_flutter: **1389 tests**; the standing failures and skips, exactly", exit 0 (1379 + 10). `flutter analyze`: No issues found. `dart format --set-exit-if-changed .`: exit 0. |
| Planner `packages/jet_cad_floor_plan` | `flutter test --enable-vmservice`: "+1643: All tests passed!" (1623 + 20). Comparison: "**1643 tests**; the standing failures and skips, exactly", exit 0. Analyze: no issues. Format: exit 0. |
| `packages/jet_cad_2d_gpu` | `flutter test`: "+20: All tests passed!". Comparison: "20 tests; … exactly", exit 0. Analyze: no issues. |
| Engine `packages/jet_cad_2d` | `dart test` exits 1 on the 2 standing failures. Comparison: "1258 tests; the standing failures and skips, exactly", exit 0. |
| `apps/restaurant_demo` | `flutter test`: "+57: All tests passed!". Analyze: no issues. Format: exit 0. |
| `apps/floor_planner` | `flutter test`: "+212: All tests passed!". Analyze: no issues. Format: exit 0. |

## Findings and deviations

1. **The shared-scratchpad incident (controller's heads-up).**
   - My first mutant runner lived in the shared `scratchpad/mut/`. The Task 1 reviewer ran it around 16:08 UTC.
   - **Effect on my first run:** it crashed on a `run.json` being written at the same time. Its closing `md5sum -c` reported `planner_shell.dart` FAILED. A few seconds later the check was OK, and `git diff` was byte-identical to the pre-mutant diff, so no edit of mine was lost.
   - **Re-run:** every mutant was run again from `scratchpad/s3t2-impl/`, after the gates and with nothing else running. The results above are from that re-run, and they match the earlier ones exactly.
   - **The gates:** they started at about 16:13, after the incident, on an intact tree.
2. **A hover alive when the view is unmounted throws (existing behaviour, not caused by this task).**
   - `InteractionLayer.deactivate` → `_release` → `SelectionController.setHover(null)` → `_SelectionPanelState._sync` → `setState` on a defunct element: "setState() or markNeedsBuild() called during build".
   - I reproduced it at `620dabd`, in a temporary worktree (since removed), with a probe test: a design-mode `FloorPlanView`, a hover set, then `pumpWidget(SizedBox())`.
   - My T2-a test clears the hover before it ends.
   - A host can hit this when it removes the view while the pointer hovers a line. It is a candidate for a separate fix outside Slice 3.
3. **The selected-line colour is only an RGB check.** The planner test reads `selectionOnLight`'s `0xD81B60` and the other colours as RGB within 3 per channel, as the fixture's `expectSelection` does. The fully opaque theme colours make that exact up to anti-aliasing.
4. **`withSelection(set.selection)` returns an equal copy, not the const set.** Identity with the const set (P-6, structural) is `paperPaletteFor`'s job: it never calls `withSelection` without a theme colour for the set. A test pins that, and X10 is red.
5. **`paint_allocation_test` is untouched (S-1).** The overlay's frame objects are pinned by the new themed reuse test.
6. **Recomputed per build, not cached.** When the theme sets a colour, both modes call `withSelection` in each `build`, which allocates one `PaperPalette` per build. That is not per frame: pan and zoom rebuild neither mode. `shouldRepaint` compares by value, so a rebuild with an equal palette does not repaint the overlay. A cache in the state was not added, because the plan places the call where `forPaper` is called today.

## Fixes

The review's two test-only fixes, R-1 and R-2, in one commit after `e111b28`. No library file changed.

- **R-1.** `packages/jet_cad_floor_plan/test/host/theme_canvas_test.dart` gains, in both modes, "R-1 (design|selection): a page-less plan under the dark theme on a light canvasBackground: the surround is it, the ink black, the selection selectionOnLight". It pumps a page-less plan under `ThemeMode.dark` with `canvasBackground: 0xFFFFF3E0`, `selectionOnLight` and `selectionOnDark`. It expects the surround `0xFFF3E0`, black ink (`expectDarkInk`), and the selection in `selectionOnLight`.
- **R-2.** `packages/jet_cad_2d_flutter/test/selection_theme_test.dart`, in the group `SelectionOverlayPainter.selectionStrokePixels`, gains "the width is asserted finite and above 0; 0.25 is accepted (R-2)". It checks that `0.0`, `-1.0`, `double.infinity` and `double.nan` each throw an `AssertionError`, and that `0.25` is accepted.

Both are the reviewer's proposed tests, renamed to the files' style.

**Mutants.** The runner is `scratchpad/s3t3-impl/mut.py` with the definitions in `defs_t2fix.py`. It copies each file aside, restores it, and checks it with `cmp`. `md5sum -c` passed afterwards.

| Run | Result |
|---|---|
| Baseline | planner `theme_canvas_test` 22/22 green; render `selection_theme_test` 11/11 green |
| O10 (`canvasBackground` honoured only under a light Material theme, both modes) | red: both R-1 tests (2 of 22) |
| O17 (the width's assert removed) | red: the R-2 test (1 of 11) |

Both files: `flutter analyze` reports no issues, and `dart format` leaves them unchanged.
