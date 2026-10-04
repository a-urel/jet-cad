# Task 6 report — the widgets (D9a-D9d, R-3, R-4, R-19; M-DT-14..M-DT-18, the panel sweep)

Start: branch head `1fab9a9` (Tasks 1-5 done). Status: **done**. Commit: `4f324f9` feat(dark-theme): Task 6 — the widgets: selected symbol ink, literal-colour scan, live switch (not pushed).

## Files changed
- `packages/jet_cad_2d_flutter/lib/src/symbol_gallery.dart` (lib)
- `packages/jet_cad_floor_plan/lib/src/symbols/symbol_panel.dart` (lib)
- `packages/jet_cad_2d_flutter/test/symbol_gallery_test.dart` (mechanical call-site update + 1 new test + recording helper)
- `packages/jet_cad_floor_plan/test/invariants/theme_colours_test.dart` (new)
- `packages/jet_cad_floor_plan/test/widget_theme_test.dart` (new)

## What was built
**D9b.**
- `SymbolGallery` takes a required `int selectedForeground` beside `foreground`, threaded to `_Cell`.
- `_Cell` hands `_Thumbnail` `selected ? selectedForeground : foreground`. `_Thumbnail.didUpdateWidget` already re-requests on a foreground change, so a selection move re-asks for exactly the two cells whose ink changes.
- `SymbolPanel` passes `selectedForeground: foregroundFor(scheme.primaryContainer.toARGB32() & 0xFFFFFF)`.
- **Call sites** (grep of `packages/` and `apps/`, incl. `apps/dev_harness_2d`): the only other constructor call is the gallery test's `Harness.build`. It now passes `selectedForeground: selectedForeground ?? foreground`: an optional parameter that defaults to `foreground`, so existing tests are unchanged. `apps/floor_planner/test/symbols/*` and `jet_cad_floor_plan/test/symbols/symbol_panel_test.dart` only *read* the gallery widget. `dev_harness_2d` has no `SymbolGallery`.

**D9a, `test/invariants/theme_colours_test.dart`.**
- **Roots.** The scan covers `lib`, `../jet_cad_2d_flutter/lib`, `../../apps/floor_planner/lib` and `../../apps/restaurant_demo/lib`, relative to the package. A missing directory throws `StateError`, and a test pins that with a fake root. Each root must contribute at least one file (82 + 59 + 10 + 1 = 152 files).
- **Patterns.** The spec's three, verbatim.
- **Allow-list.**
  - The whole file `canvas_palette.dart`.
  - Eight (file, exact literal) pairs, exactly the spec's.
  - A match is allowed when the source *at the match offset* starts with the literal. If the literal ends in a word character, the next source character must not be one, so `Colors.teal` does not cover `Colors.tealAccent`.
  - `layer_row.dart`'s `Color(0xFF000000 |` matches both of its occurrences (`:200`, `:258`). After format, the `|` sits on the same line in both.
  - `page_export.dart` writes `ui.Color(0xFFFFFFFF)`. `\bColor\(` matches at `Color(` after `ui.`, so the literal `Color(0xFFFFFFFF)` covers it.
- **Stale entries.** An entry (a pair or a whole file) that matches nothing goes red.
- **Offenders** are reported as `file:line: <source line>`.
- **Current offenders beyond the spec: none.** The scan is green on the spec's allow-list as written, with no extra entry.
- **Self-tests.** A second test shows that the scan's own mutants go red: the scratch literal (with file:line), `Color.fromARGB`, `Color.fromRGBO`, `Colors.blue`, `Colors.tealAccent`, a second literal in an allow-listed file, and stale entries. It also shows that `TrueColor(0x..)` and `Colors.transparent` stay green. These run on in-memory overrides; the named mutants below were fired on the real files.

**D9c.** Not changed (spec: "pinned by a test, not changed"). M-DT-18 pins it.

**D9d audit.**
- **Scope.** A grep of `packages/jet_cad_floor_plan/lib`, `symbol_gallery.dart` and both apps' `lib` for `late final`, `initState`, `Color`/`ColorScheme`/`ThemeData` fields and every `Theme.of`/`colorScheme` read.
- **Result.** No theme colour is held in a field, a `late final` or `initState`. Every read is in a `build` or a builder inside one. The two exceptions are `_surfaceArgb` in `planner_shell.dart:214` and `host/service_view.dart:137`, which `didChangeDependencies` re-derives on every theme change (Task 4).
- **Nothing to fix.**

## Tests added
**`packages/jet_cad_2d_flutter/test/symbol_gallery_test.dart`** (1):
- `the selected cell asks for its thumbnail in selectedForeground, the others in foreground; a selection move re-asks for both cells (dark theme D9b)`
  - `foreground` is 0x336699 and `selectedForeground` 0xF0E0D0, both non-default.
  - Moving the selection re-asks for exactly `[('chair@2', ink), ('table@1', selectedInk)]`.
  - Deselecting goes back to `ink`.

**`packages/jet_cad_floor_plan/test/invariants/theme_colours_test.dart`** (3):
- `M-DT-14: no literal colour in the widgets of both packages and both apps but the allowed ones, and every allow-list entry still matches (D9a)`
- `every scanned directory exists, and a missing one fails loudly`
- `the scan's own mutants: a literal added to symbol_panel.dart, a second literal in an allow-listed file, Color.fromARGB, a Colors member and a stale entry each go red; TrueColor and Colors.transparent do not`

**`packages/jet_cad_floor_plan/test/widget_theme_test.dart`** (9).
- **Fixture.** The real `PlannerShell` with the real `furniture.jetlib` loader and a recording `SymbolThumbnails`, at 1440×900 and DPR 1, on `paletteDoc(paper: White)`.
- **Capture.** The capture boundary sits in `MaterialApp.builder`, around the navigator, so menus and dialogs are in the shot. (`pumpThemed` wraps only `home`, which missed the popup; first run: the menu swatch read the panel.)
- **Thumbnails.** `settleImages` loops `tester.runAsync(thumbnails.settle)` plus a pump until no new request appears.
- **"Centre leaf".** The darkest and the brightest pixel of the middle half (each way) of the cell's `RawImage` rect, in the window shot. The thumbnail is transparent, so every pixel there is the cell background or ink. The cells are the first two of the first category (`dining.table.square.two@2`, `dining.table.square.four@2`).

The tests:
- `premise: the overridden primaryContainer takes black ink, the dark seed's cell colour white; under the real dark seed both take white (F-18), under the light seed both black`
- `M-DT-15: a dark scheme whose primaryContainer is light: ...`
  - **Scheme.** `ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: 0xFF2266CC, brightness: dark).copyWith(primaryContainer: 0xFFD8E2FF))`.
  - **Selection.** A real tap selects the first cell; the premise is that its `Material` colour is `0xFFD8E2FF`.
  - **Assertions.** The selected leaf's darkest pixel has at least 3:1 contrast on 0xD8E2FF (a WCAG oracle written out in the test). The unselected leaf's brightest pixel is above 200 per channel. Then, after the pixels, `gallery.selectedForeground == 0` and `foreground == 0xFFFFFF`.
- `M-DT-16, dark theme: an unselected cell's centre leaf is light, and so is the selected cell's (D9b)` uses the real dark seed.
- `M-DT-16, light theme (the control): ... dark ...`: the leaf's darkest pixel is below 60 per channel.
- `M-DT-17: a live switch from light to dark (zero animation): the symbol cells' colour, their leaves and the page swatches' borders follow the dark scheme, and back (D9d)`
  - It re-pumps the same tree shape with another `themeMode` at `themeAnimationDuration: Duration.zero`.
  - Cell `Material.color` == `surfaceContainerLowest`, the page swatches' borders are primary/outline from the dark scheme, and the leaf is light after the switch. Back to light, the cell and the swatches are light again.
  - This is a new test, not an edit of M-DT-9's: the M-DT-9 shell has no symbol loader, and existing tests may change only mechanically.
- `M-DT-18, {dark|light} theme on White paper: the layer row's "Foreground" swatch and the colour menu's show the paper's black ink inside a scheme.outline border (D9c)` (2 tests)
  - **The swatches.** Layer 0's row swatch (`layer-colour-1`), then the open menu's `layer-colour-item-7` swatch (its label "Foreground" is asserted).
  - **Assertions.** Each is 16×16 at whole pixels. Its left and right border pixels (vertical middle) equal `scheme.outline` exactly, and its centre pixel is 0x000000.
  - **Premise.** The outline is not near black.
  - The swatch is found by its rounded corners, not by its border, so a mutant with no border is still found.
- **The panel sweep (smoke):** `the shell: tool palette, toolbar, status line, layer panel and its menu, selection panel and its layer picker, page panel, symbol panel and its search, text entry and the export dialog`, and `ServiceView with a status`.
  - **The shell test**, under the dark theme, steps through:
    1. the shell with its tool palette, toolbar, status line, layers and page panel; `chrome-left` == dark `surfaceContainerLow`;
    2. the layer colour menu;
    3. a selection, the selection panel and its `layer-picker` dropdown;
    4. a text entry;
    5. `showExportDialog` with PNG chosen;
    6. the Symbols tab, the search with a match (`bed`) and with none.
  - Each step shoots the window and asserts `tester.takeException()` is null.
  - **ServiceView** reuses Task 5's `statusController(white)` and `pumpService(.., ThemeMode.dark)` (imported with `show`).
  - **Print** has no in-app dialog: the flow hands the PDF to the platform's printer (`page_flows.dart:65-76`), so there is nothing of ours to pump.

## Mutant table
**Method.** `scratchpad/task6/mut.py`, for each mutant:
1. `cp` the file to scratch;
2. apply exact-string edits, each required to match exactly once;
3. run `CI=true flutter test <file>` in the named package;
4. `cp` the backup back and run `diff -q`.

Every run printed `restored diff=0`. `sha256sum -c` of the 7 touched lib files against a pre-run snapshot printed OK for all seven, after the runs. Logs are `scratchpad/task6/<id>.log`, and the summary is `mut-summary.txt`.

Test file abbreviations: T_W = `test/widget_theme_test.dart`, T_SCAN = `test/invariants/theme_colours_test.dart` (planner), T_G = `test/symbol_gallery_test.dart` (render).

| ID | file:line | change | ran | result, red test(s), real excerpt |
|---|---|---|---|---|
| **M-DT-14** (named) | symbol_panel.dart (before `kSymbolPlacementNeeds`, line 26 after insert) | `const Color _scratch = Color(0xFF123456);` | T_SCAN | RED `+1 -2`; `M-DT-14: no literal colour ...`: `Actual: 'lib/src/symbols/symbol_panel.dart:26: const Color _scratch = Color(0xFF123456);'` |
| M-DT-14 stale allow-list (named in brief) | vertices_draw_sink.dart:177 | `const Color(0xFFFFFFFF)` → `kStatusCaptionOnDark` (same value, imported; no literal left) | T_SCAN | RED `+1 -2`; `Actual: 'stale allow-list entry: (../jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart, Color(0xFFFFFFFF))'` |
| M-DT-14 second literal in an allowed file (own) | apps/floor_planner/lib/main.dart:25 | seed `0xFF2266CC` → `0xFF2266CD` | T_SCAN | RED `+1 -2`; `Actual: '../../apps/floor_planner/lib/main.dart:25: const Color _seed = Color(0xFF2266CD);` (and the entry is stale) |
| **M-DT-15** (named) | symbol_panel.dart (`selectedForeground:`) | `foregroundFor(cellColor...)` | T_W | RED `+8 -1`; M-DT-15 only: `Expected: a value greater than or equal to <3> Actual: <1.2929180718999134>` (pixel first) |
| D9b cell always `foreground` (own) | symbol_gallery.dart (`_Cell` → `_Thumbnail`) | `foreground: foreground` | T_W | RED `+8 -1`; M-DT-15: `Actual: <1.2929180718999134>` |
| same | same | same | T_G | RED `+12 -1`; new gallery test: `Expected: <15786192> Actual: <3368601>` |
| D9b cell always `selectedForeground` (own) | same | `foreground: selectedForeground` | T_G | RED `+12 -1`; `Expected: <3368601> Actual: <15786192>` |
| **M-DT-16** (named) | symbol_panel.dart (`foreground:`) | `foreground: 0x000000` | T_W | RED `+6 -3`; `M-DT-16, dark theme`: `Expected: a value greater than <200> Actual: <12>`; also M-DT-15 and M-DT-17 |
| M-DT-16 both fixed black (own) | symbol_panel.dart | `foreground` and `selectedForeground` = 0x000000 | T_W | RED `+6 -3`; same tests |
| M-DT-16 both fixed white (own) | symbol_panel.dart | both = 0xFFFFFF | T_W | RED `+6 -3`; the light control: `Expected: a value less than <60>`; M-DT-15 (`Expected: <0> Actual: <16777215>`), M-DT-17 |
| **M-DT-17** (named) SymbolPanel caches the scheme | symbol_panel.dart | `late final ColorScheme _scheme = Theme.of(context).colorScheme;` read in `_ready` | T_W | RED `+8 -1`; M-DT-17: expected the dark cell colour `red: 0.0471 ...`, actual `red: 1.0000 ...` (light) |
| **M-DT-17** (named) PagePanel caches the scheme | page_panel.dart | `late final ColorScheme _scheme` in `PagePanelState`, read in the builder | T_W | RED `+8 -1`; M-DT-17: swatch border expected `red: 0.6784 ...` (dark primary), actual `red: 0.2667 ...` (light primary) |
| M-DT-17 gallery caches `cellColor` (own) | symbol_gallery.dart | `late final Color _cellColor = widget.cellColor;` | T_W | RED `+8 -1`; M-DT-17: cell colour stays light |
| **M-DT-18** (named) border removed | layer_row.dart:364 | the `border:` line deleted | T_W | RED `+7 -2`; both M-DT-18 tests: `Expected: '0x8e9099' Actual: '0x000000'` |
| **M-DT-18** (named) fixed colour | layer_row.dart:364 | `Border.all(color: Colors.grey)` | T_W | RED `+7 -2`; `Expected: '0x8e9099' Actual: '0x9e9e9e'` |
| M-DT-18 fixed to the light outline (own) | layer_row.dart:364 | the light seed's `outline` | T_W | RED `+8 -1`; dark test only: `Expected: '0x8e9099' Actual: '0x75777f'` |
| sweep (own, for its one colour assertion) | planner_shell.dart:891 | `chrome-left` `color: Colors.white` | T_W | RED `+8 -1`; the sweep: dark `surfaceContainerLow` expected, white actual |

**History.** M-DT-15 and M-DT-18 (border removed) were re-fired after two test fixes:
- **M-DT-15.** The widget-level `selectedForeground` assertion moved after the pixels. The first firing went red on it (`Expected: <0> Actual: <16777215>`); the re-fire is red on the pixel.
- **M-DT-18.** The swatch finder now matches the rounded corners. The first firing went red on the finder (`Found 0 widgets`), because the finder used to match the border; the re-fire is red on the pixel.

The table quotes the re-fires.

## Gates (this container, Flutter 3.47.6, `CI=true`; logs `scratchpad/task6/gate-*.log`)

| Package | flutter test | analyze | format |
|---|---|---|---|
| render `jet_cad_2d_flutter` | `+1303 ~1 -7: Some tests failed.`: Task 5's 1302 + 1 new gallery test. The 7 are exactly the standing set: text_ladder rungs 1-5 and text_lod_ladder rungs 1-2, `RenderBackend.canvas`. | No issues found! | 218 files (0 changed) |
| planner `jet_cad_floor_plan` | `+1211: All tests passed!`: 1199 (after 5b) + 12 (widget_theme 9, theme_colours 3) | No issues found! | 200 files (0 changed) |
| `jet_cad_restaurant_symbols` | `+94: All tests passed!` | No issues found! | 13 (0 changed) |
| app `floor_planner` | `+201: All tests passed!` | No issues found! | 44 (0 changed) |
| demo `restaurant_demo` | `+17: All tests passed!` | No issues found! | 3 (0 changed) |
| `apps/dev_harness_2d` | `+82: All tests passed!` | No issues found! | 22 (0 changed) |

**Untouched.** `git diff --stat 1fab9a9` over `packages/jet_cad_2d`, `*golden*`, both allocation invariants, `*analysis_options*` and `selection_overlay_test.dart` is empty. No `analysis_options.yaml` is modified or staged; files were staged by explicit path.

## Proposed rulings
- **R-C6-1: "centre leaf" is read as the thumbnail's middle half.**
  - The darkest and the brightest pixel of the middle half (each way) of the cell's thumbnail rect, on screen. The spec does not define "centre leaf".
  - **Why.** The real library's first symbols (dining tables with chairs) have no ink at the exact centre pixel. The middle half holds the table's outline, and the pixels there are the background or ink.
  - **Cost if wrong:** a different sample region; the thresholds stay the spec's.
- **R-C6-2: M-DT-17 is a new test, not an extension of the M-DT-9 theme-flip test.**
  - That test's shell has no symbol loader, and adding assertions to it is not a mechanical change.
  - The new test performs the same live switch (zero animation, same tree shape) with the symbol panel open.
  - **Cost if wrong:** none; the M-DT-9 test is unchanged.
- **R-C6-3: the shots in `widget_theme_test.dart` wrap the navigator** (`MaterialApp.builder`) rather than using `pumpThemed`, so popups and dialogs are captured. `palette_fixture.dart` is unedited. Cost if wrong: none.

## Found, not fixed
- Nothing. (The D9d audit and the scan found no offender beyond the spec's list.)

## For the reviewer
- **The scan's matching rule** (startsWith at the match offset, plus the word-boundary tail) and the stale check: confirm it covers both `layer_row.dart` occurrences and the `ui.Color(` in `page_export.dart`.
- **The M-DT-15 fixture** is the one non-seed theme, per the spec. The tap goes through the real shell, which arms the symbol and activates the place tool, so `selectedId` comes from the real flow.
- **The panel sweep** is smoke. Its one colour assertion (`chrome-left`) owns a mutant; the rest is "no exception" plus a rasterised shot.
