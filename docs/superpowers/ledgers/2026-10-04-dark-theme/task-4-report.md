# Task 4 report — the planner wiring (D1, D4, D5 PlannerView, R-7, R-20)

Start: branch head `eba82d0` (Tasks 1-3 done). Status: **done**. Commit: `37a1797` feat(dark-theme): Task 4 — the planner wiring: palettes from the theme and the paper.

## What was built (lib)
- **`planner_view.dart`.** `PlannerView` takes required `chrome: ChromePalette` and `paper: PaperPalette`. The three `// Task 4` `.light` placeholders are gone. `widget.chrome` goes to `RulerFrame` and `PageChromePainter`, and `widget.paper` goes to `PageChromePainter` and `SelectionOverlayPainter`.
- **`planner_shell.dart` and `host/service_view.dart`** (the same shape in both):
  - `late int _surfaceArgb` is set in `didChangeDependencies` from `Theme.of(context).colorScheme.surface.toARGB32()`.
  - `int _paperArgb() => _page.value?.background ?? _surfaceArgb;` feeds both `foregroundFor` (the resolver) and `PaperPalette.forPaper` (in `build`).
  - The resolver is `late DocumentStyleResolver _resolver` plus a `bool _hasResolver`. It is assigned in the first `didChangeDependencies` and re-derived there and in `_onPage`. It is replaced only when the foreground flips (fix/post-07); `didChangeDependencies` needs no `setState`, because a `build` follows it.
  - `build` computes `ChromePalette.of(Theme.of(context).brightness)` and `PaperPalette.forPaper(_paperArgb())` and hands both to `PlannerView`.
  - `_onPage`'s rebuild on a flip is what hands down the new paper palette. The palette and the foreground switch at exactly the same paper (`forPaper` keys on `foregroundFor`). So White→Ivory changes neither and needs no rebuild, and White→Blueprint flips both and rebuilds. The doc comments say this.
  - The old comment at `planner_shell.dart:175-177` ("lies on the shell's light surface, so it is read as white paper") is rewritten on `_paperArgb`: the drafting lies on the theme's `scheme.surface`, light or dark.
  - **Reads of `_resolver` before the first `didChangeDependencies`:** none. A grep finds it only in `_onPage`, `build` (`PlannerView.resolver`, `LayerPanel.foreground`) and `didChangeDependencies`. The page listener is added in `initState`, but nothing notifies between `initState` and `didChangeDependencies`. `ServiceView`'s `late final` fields (`_statusPainter` etc.) do not read the resolver.
- **Apps.** `apps/floor_planner/lib/main.dart` and `apps/restaurant_demo/lib/main.dart` gain `darkTheme: ThemeData(colorSchemeSeed: _seed, brightness: Brightness.dark)` and `themeMode: ThemeMode.system`. The seed is hoisted to a file-private `const Color _seed` (`Color(0xFF2266CC)` / `Colors.teal`), so each file still holds its seed literal exactly once. That suits Task 6's (file, exact literal) allow-list.
- **`jet_cad_2d_flutter/lib/src/draft_canvas.dart`** (not in spec "Files"; see R-C4-1). `_DraftCustomPainter.shouldRepaint` now also answers true on `old.painter != painter`, with its doc comment extended. Without this, D4's theme flip with no page left the old ink on screen: the resolver is re-derived and the canvas re-attaches a new `DraftPainter`, but nothing repaints. The first run of the D4 test showed it (`after the switch to dark: ink brightest 0x111318`, i.e. the bare dark surface: black ink was still painted).

## How a page-less document is made in tests
`prepareDocument(measurer)` (`lib/src/new_document.dart`) is the app's set-up with **no page**. `newDocument` is `prepareDocument` + `defaultPage()`. The fixture (`test/support/palette_fixture.dart`, `paletteDoc(m, paper: null)`) calls `prepareDocument` and skips the `SetComponentCommand<PageComponent>`. For the host, that document is encoded with `DraftDocumentCodec.encodeToString` and handed to `FloorPlanController(json:)`. That is the "file saved without a page" route from the spec's Not in scope. Each test asserts `components.get<PageComponent>(root) == null`.

## Tests added
**Fixture** `packages/jet_cad_floor_plan/test/support/palette_fixture.dart`:
- **Themes.** The real seed `0xFF2266CC`, light and dark, switched by re-pumping the `MaterialApp` with another `themeMode` at `themeAnimationDuration: Duration.zero`. The tree keeps its shape, so every state survives.
- **Window.** Device pixel ratio 1 and a whole-window `RepaintBoundary` capture.
- **Page.** 1:20 A4 landscape at origin (7000, 3000), grid off.
- **Lines.** Two horizontal ACI 7 lines (ByLayer, layer 0): one selected, one as the ink witness.
- **Camera.** Y-up, off-origin, 0.125 px/mm. It puts the lines and the sheet's left edge on pixel centres, so the 2 px selection stroke covers a pixel row exactly and the 1 px edge covers column 40 exactly. The grid is off so that no grid line half-covers the edge column.
- **Samples:**
  - selection: the 3×3 pixel nearest the expected colour, within 3;
  - ink: the brightest of the block above 200 per channel, or the darkest below 60;
  - ruler bar: the most common colour of the top bar's row 15;
  - corner box: pixel (2, 2);
  - sheet edge: the exact pixel.
- **`expectPainters`.** Reads the palettes held by the painters under the `PlannerView`, through the `CustomPaint`s: rulers ×2, corner, page chrome (chrome and paper), overlay. It runs after the pixel assertions, so the pixels fire first.

**`packages/jet_cad_floor_plan/test/planner_palette_test.dart`** (the shell, 10 tests):
- `premise: the seed's light surface takes black ink, its dark one white; Blueprint and White take opposite sets`
- `M-DT-1, M-DT-2: {light|dark} theme, {White|Blueprint} paper: the selection takes the paper's set, the ruler bar, the corner and the sheet edge the theme's chrome, the ink the paper's foreground` (4 tests). Light/White is review 2's note.
- `M-DT-9: a theme switch with no camera move repaints the ruler bar, the corner and the sheet edge in the dark chrome and back; the paper's selection and ink stay, and the canvas keeps its resolver`
- `M-DT-9: with a line selected, White to Blueprint with no camera move repaints the selection 0x7FB2FF and the ink white; White to Ivory keeps the light set`
- `M-DT-10: no page in the dark theme: ACI 7 is light on the dark surface and the selection is the dark set`
- `M-DT-10: no page in the light theme: ACI 7 is black and the selection the light set (today's behaviour)`
- `M-DT-9, M-DT-10, D4: no page, a theme switch re-derives the ink and the paper set from the new surface: light to dark turns ACI 7 white and the selection dark with no camera move, and back`

**`packages/jet_cad_floor_plan/test/host/view_palette_test.dart`** (the host, 7 tests):
- `M-DT-11 (design mode): two views side by side in one frame, White and Blueprint, ...` and the same in `selection mode` (two `ServiceView`s). The window is 2880×900, under the dark theme.
- `ServiceView, {light theme, Blueprint paper | dark theme, White paper | dark theme, Blueprint paper}: the selection takes the paper's set and the sheet edge the theme's chrome` (3 tests)
- `M-DT-10, ServiceView: no page, light then dark theme: the ink and the selection follow the surface, re-derived on the switch, and back`
- `ServiceView, a theme switch with no camera move repaints the sheet edge in the dark chrome; White to Blueprint repaints the selection`

**`packages/jet_cad_2d_flutter/test/draft_canvas_test.dart`** (1 test added; nothing else edited): `a new resolver repaints with no document change and no camera move; a rebuild with the same one does not (dark theme Task 4)`.

## Mutant table
**Method.** `scratchpad/task4/mut.py`. For each mutant it:
1. copies the file to scratch;
2. applies exact-string edits;
3. runs `CI=true flutter test <files>` in the named package;
4. copies the backup back and runs `diff -q`. Every run printed `restored diff=0`.

Logs are `scratchpad/task4/<id>.log` and the summary is `mut-summary.txt`. **All 28 are red.** T_SHELL = `test/planner_palette_test.dart`, T_HOST = `test/host/view_palette_test.dart`.

| ID | file | change | ran | result, red test(s), real excerpt |
|---|---|---|---|---|
| PV-dark (review 2's note) | planner_view.dart | every `widget.chrome`/`widget.paper` → `.dark` | T_SHELL | `+3 -7`; light/White crossing red first: `light theme, White paper: selection 0x7fb2ff, want 0x1e6fe8` |
| PV-light | planner_view.dart | every → `.light` | T_SHELL | `+3 -7`; `dark theme, White paper: ruler bar`, `light theme, Blueprint paper: selection 0x1e55a4, want 0x7fb2ff` |
| PV-ruler-light | planner_view.dart (RulerFrame) | `chrome: ChromePalette.light` | T_SHELL | `+7 -3`; `Expected: '0x2b2d31' Actual: '0xf2f2f2'` (dark crossings, M-DT-9 theme flip) |
| PV-edge-light | planner_view.dart (PageChromePainter chrome) | `.light` | T_SHELL | `+7 -3`; `Expected: '0x8a8a8a' Actual: '0x9e9e9e'` |
| PV-pagechrome-paper-light | planner_view.dart (PageChromePainter paper) | `.light` | T_SHELL | `+8 -2`; Blueprint crossings, `light theme, Blueprint paper: page chrome paper` (expectPainters: the fixture's grid is off, so only the field read sees it) |
| PV-overlay-paper-light | planner_view.dart (overlay paper) | `.light` | T_SHELL | `+5 -5`; `selection 0x1e55a4, want 0x7fb2ff` |
| M-DT-1 | canvas_palette.dart | `forPaper` `? light : dark` | T_SHELL | `+0 -10`; `light theme, White paper: selection 0x7fb2ff, want 0x1e6fe8`; `light theme, Blueprint paper: selection 0x1e55a4, want 0x7fb2ff` |
| M-DT-2 (shell) | planner_shell.dart | `paper:` from `theme.brightness` | T_SHELL | `+6 -4`; `dark theme, White paper: selection 0x7fb2ff, want 0x1e6fe8` and `light theme, Blueprint paper: selection 0x1e55a4, want 0x7fb2ff` (both crossings) |
| M-DT-2 (service) | service_view.dart | same | T_HOST | `+3 -4`; `White view: selection 0x7fb2ff, want 0x1e6fe8` |
| shell-chrome-by-paper | planner_shell.dart | `chrome:` from the paper's foreground | T_SHELL | `+6 -4`; `light theme, Blueprint paper: ruler bar`, `dark theme, White paper: ruler bar` |
| M-DT-9 overlay `shouldRepaint => false` | selection_overlay.dart | `oldDelegate.paper != paper` → `false` | T_SHELL | `+9 -1`; only the no-page theme-switch test: `after the switch to dark: selection 0x1e6fe8, want 0x7fb2ff` (see R-C4-2) |
| same | same | same | T_HOST | `+6 -1`; `no page, after the switch: selection 0x1e6fe8, want 0x7fb2ff` |
| M-DT-9 page chrome `shouldRepaint => false` | page_chrome_painter.dart | → `false` | T_SHELL+T_HOST | `+15 -2`; `after the switch to dark: sheet edge` (shell M-DT-9 theme flip and the ServiceView flip) |
| M-DT-9 ruler `shouldRepaint => false` | ruler_painter.dart (RulerPainter) | → `false` | T_SHELL | `+9 -1`; `after the switch to dark: ruler bar`, `Expected: '0x2b2d31' Actual: '0xf2f2f2'` |
| M-DT-9 corner `shouldRepaint => false` | ruler_painter.dart (RulerCornerPainter) | → `false` | T_SHELL | `+9 -1`; `after the switch to dark: ruler corner` |
| M-DT-10 (shell) | planner_shell.dart | `_paperArgb` falls back to `0xFFFFFFFF` | T_SHELL | `+8 -2`; the M-DT-10 dark test and the no-page switch: `Expected: <4294967295> Actual: <4278190080>` |
| M-DT-10 (service) | service_view.dart | same | T_HOST | `+6 -1`; `Expected: <4294967295> Actual: <4278190080>` |
| shell-no-rederive-in-dcd | planner_shell.dart | `if (_hasResolver) return;` | T_SHELL | `+9 -1`; no-page switch: `Expected: <4294967295> Actual: <4278190080>` |
| service-no-rederive-in-dcd | service_view.dart | same | T_HOST | `+6 -1`; same excerpt |
| shell-always-new-resolver-in-dcd | planner_shell.dart | flip guard deleted (a new resolver every `didChangeDependencies`) | T_SHELL | `+9 -1`; M-DT-9 theme flip: `Expected: true Actual: <false>` (the painter is not kept) |
| service-chrome-light | service_view.dart | `chrome: ChromePalette.light` | T_HOST | `+3 -4`; `White view: sheet edge` `Expected: '0x8a8a8a' Actual: '0x9e9e9e'` |
| service-paper-light | service_view.dart | `paper: PaperPalette.light` | T_HOST | `+2 -5`; `Blueprint view: selection 0x1e55a4, want 0x7fb2ff` |
| M-DT-11 (shell) | planner_shell.dart | `static PaperPalette? _sharedPaper`; `paper: _sharedPaper ??= ...` | T_HOST | `+6 -1`; M-DT-11 design mode: `Blueprint view: selection 0x1e55a4, want 0x7fb2ff` |
| M-DT-11 (service) | service_view.dart | same | T_HOST | `+2 -5`; M-DT-11 selection mode: same excerpt |
| shell-onPage-no-setState | planner_shell.dart | resolver assigned without `setState` | T_SHELL | `+9 -1`; the paper-flip test: `Blueprint: selection 0x1e55a4, want 0x7fb2ff` |
| service-onPage-no-setState | service_view.dart | same | T_HOST | `+6 -1`; ServiceView flip test: `Blueprint: selection 0x1e55a4, want 0x7fb2ff` |
| draftcanvas-no-painter-repaint | draft_canvas.dart | `old.painter != painter \|\|` removed | render `test/draft_canvas_test.dart` | `+17 -1`; `Expected: <2> Actual: <1>` (paints) |
| same | same | same | T_SHELL+T_HOST | `+15 -2`; `no page, after the switch to dark: ink brightest 0x111318` (shell and ServiceView no-page switches) |

## Gates (this container, Flutter 3.47.6, `CI=true`; logs `scratchpad/task4/gate-*.log`)

| Package | flutter test | analyze | format |
|---|---|---|---|
| render `jet_cad_2d_flutter` | `+1302 ~1 -7: Some tests failed.` (3b had +1301; +1 is the new draft_canvas test). The 7 are exactly the standing set: text_ladder rungs 1-5 and text_lod_ladder rungs 1-2, RenderBackend.canvas | No issues found! | 218 files (0 changed) |
| planner `jet_cad_floor_plan` | `+1187: All tests passed!` (1170 + 10 + 7) | No issues found! | 196 files (0 changed) |
| `jet_cad_restaurant_symbols` | `+94: All tests passed!` | No issues found! | 13 (0 changed) |
| app `floor_planner` | `+201: All tests passed!` | No issues found! | 44 (0 changed) |
| demo `restaurant_demo` | `+17: All tests passed!` | No issues found! | 3 (0 changed) |
| `apps/dev_harness_2d` | `+82: All tests passed!` | No issues found! | 22 (0 changed) |

**Web builds** (`CI=true flutter build web --release`, logs `scratchpad/task4/web-*.log`):
- `apps/floor_planner`: `Compiling lib/main.dart for the Web... 152.1s` / `✓ Built build/web` (exit 0)
- `apps/restaurant_demo`: `Compiling lib/main.dart for the Web... 72.9s` / `✓ Built build/web` (exit 0)

**Untouched.** `git diff --stat eba82d0` on `packages/jet_cad_2d`, `*golden*`, `*invariants*`, `*analysis_options*` and `selection_overlay_test.dart` is empty. `analysis_options.yaml` is unmodified in this container and nothing staged it.

## Proposed rulings
- **R-C4-1: the `DraftCanvas` repaint fix.** `_DraftCustomPainter.shouldRepaint` also answers `old.painter != painter`, in `jet_cad_2d_flutter/lib/src/draft_canvas.dart`. That file is not in spec "Files"; the engine is untouched.
  - **Why.** D4 replaces the resolver on a theme flip when there is no page. `DraftCanvasState.didUpdateWidget` re-attaches a new `DraftPainter`, but no `DocChange` and no camera move happen, so the canvas kept painting the old ink. The spec's "light ink on the dark surface after a switch" was unreachable without this.
  - **Why here.** This is the smallest fix at the cause. The alternative was keying `DraftCanvas` by its resolver in `PlannerView`, which rebuilds the same state through another route and leaves the defect for every other host.
  - **Allocation.** Identity comparison only, nothing allocated. `the painter never repaints per vsync` (same painter → false) still passes. A rebuild that changes nothing keeps the painter, which the new test's control arm checks.
  - **Side effect.** The same latent staleness for `drawText` / `minTextCapPixels` changes is fixed too; the drawText test nudged the camera to work around it.
  - **Cost if wrong:** one line and one test to revert. The host would then need the keyed `DraftCanvas` instead.
- **R-C4-2: M-DT-9's paper-flip witness.** The spec says "SelectionOverlayPainter's repaint merge excludes the page, so only shouldRepaint can repaint it". That is not true when a line is selected.
  - The `OutlineCache` is in the merge, and it notifies on every `DocChange` while the selection is non-empty (`outline_cache.dart:248-259`, spec 03 D9). A page change is a command, so it is a `DocChange`.
  - So the White→Blueprint test cannot kill the overlay's `shouldRepaint => false`: that mutant survives it. It is killed instead by the no-page theme switch, in both the shell and `ServiceView`, where no `DocChange` happens and the paper set flips with the surface: `after the switch to dark: selection 0x1e6fe8, want 0x7fb2ff`.
  - The paper-flip test stays: it kills the shell's or service view's `_onPage` without `setState`, and it pins the selection colour after a real page change.
  - **Cost if wrong:** none. Both tests exist, and the test comments name this ruling.
- **R-C4-3 (small): `bool _hasResolver` beside the `late` resolver.** It tells the first `didChangeDependencies` from later ones. Dart cannot ask whether a `late` field is assigned. Removing the guard throws `LateInitializationError` on the first build. Cost if wrong: none.
- **R-C4-4 (small): the seed is hoisted to `const Color _seed` in both apps.** This keeps one seed literal per file for Task 6's (file, exact literal) allow-list. Cost if wrong: none.

## Found, not fixed
- **D6c is not done here.** The status captions in `ServiceView` (the `_paper` notifier) are Task 5. `_paperArgb()` already exists there for it to reuse.
- **The fixture's grid is off,** so that the edge pixel reads exactly. The `PageChromePainter`'s paper set from `PlannerView` is pinned by `expectPainters`, a palette read on the painter instance, rather than by pixels. Task 2's tests carry the grid's pixels.

## For the reviewer
- **`draft_canvas.dart`** (R-C4-1): a render-package frame-path change outside spec "Files". Check that `painter` changes only in `_attach`.
- **The pixel alignment in the fixture:** 0.125 px/mm; lines and the sheet's top a multiple of 8 mm apart; the drawing area at whole pixels (asserted).
- **The theme switch** is done by re-pumping the same `MaterialApp` shape, so every state survives. The camera's identity is asserted unchanged.
- **The `M-DT-1, M-DT-2` crossings** assert pixels first, then the palette fields that `PlannerView` and its painters hold.
