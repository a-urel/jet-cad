# Dark theme results

**Branch:** `claude/dreamy-gates-2kgh4o`, off `main` at `5ba6fb2`; the
plan starts at `91d88e4`. **Spec:**
[2026-10-04-dark-theme-design.md](../specs/2026-10-04-dark-theme-design.md),
revision 2, with "Amended at execution" added at Task 7. **Plan:**
[2026-10-04-dark-theme.md](../plans/2026-10-04-dark-theme.md), seven
tasks. **Approval:** revision 2 by the human ("Onaylıyorum", 2026-10-04).
**Not merged.**

When the host's `Theme` is dark, the planner is dark:
- every panel and dialog, and the symbol list;
- the canvas chrome: the surround, the rulers and the sheet edge.

The paper keeps the document's colour. Everything drawn on the paper
takes its colours from the paper (`PaperPalette.forPaper`, the same switch
as ACI 7's ink): the grid, the page breaks, the selection, hover, bands,
grips, previews and snap markers. In a light theme on light paper the
canvas is pixel-identical to `91d88e4`; D6a (swatch border) and D6b
(filled text entry) are the two deliberate light-theme changes. Export,
walls, the file format and the engine are unchanged.

## Commits

| Task | Commits | Review |
|---|---|---|
| 1 The palettes (D2, D3, D6c constants) | `23314be` | **Approved**, no findings |
| 2 The painters (D5) | `2a439e0` | **Approved**, 1 minor (M-DT-5 never crossed theme and paper), carried as Task 3's first item (C-1) |
| 3 The tools' paint methods (D5) | `31b5a43`, `eba82d0` (3b) | **Needs fixes**, 2 minor (DimensionTool's `super.paintOverlay` paper; SelectTool's move guide), test-only, fixed in 3b |
| 4 The planner wiring (D1, D4, D5) | `37a1797` | **Approved**, no findings, 3 notes |
| 5 The canvas UI fixes (D6) | `6e3fa02`, `1fab9a9` (5b) | **Needs fixes**, 1 minor (`_onPage` setting `_paper` before its early return was unpinned), test-only, fixed in 5b |
| 6 The widgets (D9) | `4f324f9`, `36902c0` (6b) | **Needs fixes**, 1 minor (the dark sweep skipped `restaurant_demo`'s own UI), test-only, fixed in 6b |
| 7 The exit | this commit | — |

What landed, by task:
- **1 (`23314be`).** `canvas_palette.dart`: `ChromePalette` and
  `PaperPalette` (light = today's constants, dark = the D2 / D3 tables),
  `PaperPalette.forPaper`, `kStatusCaptionOnLight` / `kStatusCaptionOnDark`.
- **2 (`2a439e0`).** `PageChromePainter`, `RulerPainter`,
  `RulerCornerPainter`, `RulerFrame` and `SelectionOverlayPainter` take
  required palettes; their Paints stay fields, recoloured in `paint`;
  `shouldRepaint` compares palettes by value.
- **3 (`31b5a43`, `eba82d0`).** Both `Tool` paint methods take
  `PaperPalette paper`; every tool colours its band, guide, reshape
  preview, ghost, rings and snap marker from it. The 16 old colour
  constants are gone.
- **4 (`37a1797`).** `PlannerShell` and `ServiceView` derive the chrome from
  the theme and the paper set from `_paperArgb()` (the page, or
  `scheme.surface` with no page); the resolver is re-derived on a theme
  flip. Both apps gain `darkTheme` and `ThemeMode.system`. `DraftCanvas`
  repaints on a new painter (R-C4-1).
- **5 (`6e3fa02`, `1fab9a9`).** Swatch border from `scheme.primary` /
  `outline` (D6a); filled text entry (D6b); the status caption's ink from
  the status composited over the paper, via a `_paper` notifier (D6c).
- **6 (`4f324f9`, `36902c0`).** The selected symbol cell's own foreground
  (D9b); the literal-colour source scan (D9a); the live switch (D9d);
  the layer swatch's outline pinned (D9c); the dark panel sweep, the demo
  included.

Lib diff `91d88e4..36902c0`: 26 files, +625 −152. One implementer and one
independent reviewer per task; each reviewer re-ran the gates in their own
worktree and re-fired the named mutants plus their own.

## Gates (Linux container, Flutter 3.47.6, `CI=true`, at `36902c0`)

| Package | Branch point `91d88e4` | Now | Δ | analyze | format |
|---|---|---|---|---|---|
| render `jet_cad_2d_flutter` | +1240 ~1 −7 | **+1303 ~1 −7** | +63 | No issues found! | 218 files (0 changed) |
| planner `jet_cad_floor_plan` | +1167 | **+1211** | +44 | No issues found! | 200 files (0 changed) |
| restaurant symbols | +94 | **+94** | 0 | No issues found! | 13 files (0 changed) |
| app `apps/floor_planner` | +201 | **+201** | 0 | No issues found! | 44 files (0 changed) |
| demo `apps/restaurant_demo` | +17 | **+18** | +1 | No issues found! | 3 files (0 changed) |
| `apps/dev_harness_2d` | +82 | **+82** | 0 | No issues found! | 22 files (0 changed) |
| engine `jet_cad_2d` (`dart test`) | — | **+1241 −2** | — | — | — |

- **Render's 7 failures** are the standing set, unchanged: `text_ladder_golden_test.dart` rungs 1–5 and `text_lod_ladder_golden_test.dart` rungs 1–2, all `RenderBackend.canvas`.
- **The engine's 2 failures** are the standing pair in `generate_document_test.dart` ("the default document is the one Plan 2 measured, byte for byte"; "both text fractions default to zero and change nothing"). `git diff 91d88e4 -- packages/jet_cad_2d` is empty.
- **The counts add up.** Render: 33 (T1) + 18 (T2) + 9 (T3, one transitional test deleted, C-1 added) + 1 (3b) + 1 (T4) + 1 (T6). Planner: 3 (T3) + 17 (T4) + 11 (T5) + 1 (5b) + 12 (T6). Demo: 1 (6b).
- **Untouched.** `git diff 91d88e4` is empty on the two allocation invariants, the goldens and every `analysis_options.yaml`. The Paint-identity block of `selection_overlay_test.dart` is byte-identical at its new offset (+3).
- Task 7 edits one comment in `jet_cad_2d_flutter/test/support/tile_comparison.dart`. After it, render analyze and format are clean again, and the five tile suites that import the file pass (`+66: All tests passed!`).

**Web builds** (`CI=true flutter build web --release`, at `36902c0`):
- `apps/floor_planner`: `Compiling lib/main.dart for the Web... 64.5s` / `✓ Built build/web`
- `apps/restaurant_demo`: `Compiling lib/main.dart for the Web... 63.4s` / `✓ Built build/web`

## Named mutants (spec M-DT-1..20)

Every named mutant is **killed**. Each was fired by the implementer as a
scratch edit (`cp` backup, mutate, run, `cp` back, `diff` exit 0), and
re-fired red by that task's reviewer. Commands run in the package named. R = render
(`packages/jet_cad_2d_flutter`), P = planner (`packages/jet_cad_floor_plan`).

| Mutant | Task | Killing test (command) | Red evidence |
|---|---|---|---|
| **M-DT-1** `forPaper` inverted | 1, 4 | R `flutter test test/canvas_palette_test.dart` (both M-DT-3 tests); P `flutter test test/planner_palette_test.dart` (the four crossings) | T1 `+31 -2`; T4 `+0 -10`, `light theme, White paper: selection 0x7fb2ff, want 0x1e6fe8` |
| **M-DT-2** `forPaper` keyed on the theme | 4 | P `test/planner_palette_test.dart` (dark/White and light/Blueprint crossings); P `test/host/view_palette_test.dart` | shell `+6 -4`, `dark theme, White paper: selection 0x7fb2ff, want 0x1e6fe8`; service `+3 -4` |
| **M-DT-3** `forPaper` on a raw-byte threshold | 1 | R `test/canvas_palette_test.dart`: `the swatches and the greys either side of the WCAG switch`; `dark exactly when foregroundFor is white, over a wide sweep` | `+31 -2`, `paper 0xff767676` |
| **M-DT-4** grid ignores `paper` | 2 | R `test/painter_palette_test.dart`: `M-DT-4: a major-grid pixel is lighter than the bare paper on Blueprint, darker on White`; `the grid Paints carry the paper set` | `+16 -2`, `Expected: a value greater than <62.93…> Actual: <54.93…>` |
| **M-DT-5** breaks ignore `paper` | 2, 3 | R `test/painter_palette_test.dart`: `M-DT-5: on Blueprint a page-break pixel is the dark set's 0x8AB4F8`; C-1 `the page breaks follow the paper, not the chrome` | `+17 -1`, `within 3 of 0xff8ab4f8 Actual: (51, 102, 204)`; C-1 breaks-from-chrome `Expected: <4281558732> Actual: <4287280376>` |
| **M-DT-6** rulers ignore `chrome` (bar, ink, marker, labels, corner) | 2 | R `test/painter_palette_test.dart`: the three M-DT-6 tests and the corner tests | label `Expected: <4291348680> Actual: <4282664004>` (0xFFC8C8C8 vs 0xFF444444); pixels `Actual: <68.0>`; `+16 -2` each |
| **M-DT-7** sheet edge from `.light` | 2 | R `test/painter_palette_test.dart`: `M-DT-7: the sheet edge's Paint.color is the chrome's, whatever the paper` | `+17 -1`, `Expected: <4287269514> Actual: <4288585374>` |
| **M-DT-8** a tool ignores `paper` | 3, 3b | R `test/tool_palette_test.dart` (SelectTool window / crossing band, stretch and move guide, marker, reshape preview; the line tool's band and marker); P `test/symbols/symbol_place_tool_test.dart` (ghost, marker); P `test/dimension_tool_test.dart` (ring, marker) | window `Expected: <578794239> Actual: <572420072>`; guide `Expected: <4294953047> Actual: <4293435678>` (0xFFFFC857 vs 0xFFE8A11E); ghost `Expected: [4294953047, …] Actual: [4293435678, …]`; 3b dim marker `Expected: [4284470927] Actual: [4281245275]`; move guide `Actual: <4278190080>` |
| **M-DT-9** `shouldRepaint` still false | 2, 4 | R `test/painter_palette_test.dart` (the `shouldRepaint` tests); P `test/planner_palette_test.dart` and `test/host/view_palette_test.dart` (the theme flip with no camera move; the no-page theme switch, per R-C4-2) | page chrome `after the switch to dark: sheet edge`; ruler `Expected: '0x2b2d31' Actual: '0xf2f2f2'`; overlay `after the switch to dark: selection 0x1e6fe8, want 0x7fb2ff` |
| **M-DT-10** no-page ink still from white | 4 | P `test/planner_palette_test.dart` (M-DT-10 dark; the no-page switch); P `test/host/view_palette_test.dart` | `+8 -2` / `+6 -1`, `Expected: <4294967295> Actual: <4278190080>` |
| **M-DT-11** two views share palette state | 4 | P `test/host/view_palette_test.dart`: `M-DT-11 (design mode)` and `(selection mode)` | `Blueprint view: selection 0x1e55a4, want 0x7fb2ff` |
| **M-DT-12** text entry unfilled | 5 | P `test/canvas_ui_test.dart`: the two M-DT-12 tests | `+3 -2`, `Expected: '0x33353a' Actual: '0xffffff'` |
| **M-DT-13** caption fixed / ignores paper / cache ignores ink / `_paper` out of the merge | 5, 5b | P `test/service/table_status_painter_test.dart` (SP11, SP12); P `test/host/status_caption_test.dart` | fixed `Expected: '0xffffff' Actual: '0x583a53'`; merge `Expected: '0xffffff' Actual: '0x202020'`; raw `Color(foregroundFor(..))` `Actual: Color:<Color(alpha: 0.0000 …`; 5b `_paper` after the early return `Expected 0xffffff Actual 0x202020` |
| **M-DT-14** a literal colour in a widget | 6 | P `test/invariants/theme_colours_test.dart` | `+1 -2`, `Actual: 'lib/src/symbols/symbol_panel.dart:26: const Color _scratch = Color(0xFF123456);'` |
| **M-DT-15** selected cell's ink from `cellColor` | 6 | P `test/widget_theme_test.dart`: `M-DT-15: a dark scheme whose primaryContainer is light` | `+8 -1`, `Expected: a value greater than or equal to <3> Actual: <1.2929180718999134>` |
| **M-DT-16** thumbnail ink fixed black | 6 | P `test/widget_theme_test.dart`: `M-DT-16, dark theme` (and the light control) | `+6 -3`, `Expected: a value greater than <200> Actual: <12>` |
| **M-DT-17** a theme colour cached in state | 6 | P `test/widget_theme_test.dart`: `M-DT-17: a live switch from light to dark` | SymbolPanel: cell colour stayed light (`red: 1.0000`); PagePanel: swatch border stayed the light primary (`red: 0.2667`) |
| **M-DT-18** layer swatch loses its outline | 6 | P `test/widget_theme_test.dart`: the two M-DT-18 tests | border removed `Expected: '0x8e9099' Actual: '0x000000'`; fixed grey `Actual: '0x9e9e9e'` |
| **M-DT-19** light palettes drift | 1 | R `test/canvas_palette_test.dart`: `ChromePalette.light, field by field`; `PaperPalette.light, field by field` | `+31 -2` (sheetEdge 0xFF9E9E9F; hover alpha) |
| **M-DT-20** dark set loses contrast | 1 | R `test/canvas_palette_test.dart`: the 18 `has 3:1` tests and `ruler ink and pointer have 4.5:1` | `Expected: a value greater than or equal to <3.0> Actual: <1.4006141699161512>` |

## Extras

**Mutants beyond the named ones**, from the implementers' tables (60
rows): Task 1: 7, Task 2: 13, Task 3 and 3b: 13, Task 4: 17, Task 5: 6,
Task 6: 4. Examples: value equality per field, Paint-per-frame, the
label `TextStyle` per frame, `shouldRepaint` by identity, the shell and
service `_onPage` without `setState`, a resolver rebuilt on every
`didChangeDependencies`, `over` flooring, the scan's stale allow-list
entry. The reviewers fired their own as well: review 1: 4, review 2: 5,
review 3: 7, review 4: 7 and a `shouldRepaint => true`, review 5: 5,
review 6: 11.

**Survivors, all recorded:**
- the `& 0xFFFFFF` mask in `forPaper` (R-C1-2) and `fillColor:` omitted
  under Material 3 defaults (R-C5-2): both equivalent;
- review 3's two (F-1, F-2) and review 5's O1, each killed by the 3b / 5b
  test;
- review 6's N1 (a duplicate of an allowed literal) and N2 (a literal
  split across lines), limits of the spec's scan (debt below);
- `TableStatusPainter.shouldRepaint` without the paper term: unreachable in
  `ServiceView`, where the painter is one `late final` instance.

**Tests beyond the plan's list:**
- C-1 (breaks crossed with the chrome);
- `expectOnlySet` (R-C3-1);
- Paint identity for the tools' Paints (R-C3-2);
- the light/White crossing in Task 4 (review 2's note);
- the `DraftCanvas` repaint test (R-C4-1);
- the dark-literal and pairing tests in Task 1;
- the D6a swatch tests in both themes;
- the 5b, 3b and 6b tests.

## Rulings (accepted by the task reviews; ledger `.superpowers/sdd/2026-10-04-dark-theme/progress.md`)

- **R-C1-1.** The old constants stayed as literals for Tasks 1–2, pinned to `.light` by a transitional test. Task 3 deleted both.
- **R-C1-2.** `forPaper`'s alpha mask kept: it is an equivalent mutant.
- **R-C2-1.** `debugLastLabel` getters on the two ruler painters. *(Spec amended.)*
- **R-C2-2.** M-DT-5's camera puts the sheet edge at x = 300.5.
- **C-1.** Breaks crossed with the chrome, as Task 3's first item.
- **R-C3-1.** `expectOnlySet`.
- **R-C3-2.** The tools' Paint-identity tests.
- **R-C4-1.** `DraftCanvas` repaints on a new painter. *(Spec amended.)*
- **R-C4-2.** M-DT-9's paper-flip premise is wrong; the overlay mutant is killed by the no-page theme switch. *(Spec amended.)*
- **R-C4-3, R-C4-4.** `_hasResolver`; one `const Color _seed` per app.
- **R-C5-1.** A status whose composite takes white ink gets a white caption in the light theme too. *(Spec amended: D7's "captions unchanged" covers statuses whose composite takes black ink.)*
- **R-C5-2.** The D6b `fillColor` mutant is equivalent.
- **R-C5-3, R-C5-4.** The ServiceView caption fixture runs at 0.07 px/mm; `over` returns `0xRRGGBB`.
- **R-C6-1.** "Centre leaf" means the extreme pixel of the thumbnail's middle half.
- **R-C6-2.** M-DT-17 is its own test. *(Spec amended.)*
- **R-C6-3.** The shots wrap the navigator, so popups are captured.

## Chromium smoke (Task 7)

**Setup.**
- **Build.** The release builds above fetch CanvasKit from
  `www.gstatic.com`, which this container's TLS proxy blocks for
  Chromium (`net::ERR_CERT_AUTHORITY_INVALID`, the app never started). So
  both apps were rebuilt for the smoke with `--no-web-resources-cdn -o
  build/web_nocdn`. Both builds printed `✓ Built build/web_nocdn`.
- **Serving.** Each build was served with `python3 -m http.server`.
- **Browser.** Playwright 1.56.1 from `/opt/node-tools`, with the Chromium
  in `/opt/pw-browsers`. The context was 1440×900 at device pixel ratio 1,
  `colorScheme: 'dark'` (one run used `'light'`), locale `en-US`.
  Headless Chromium's default locale made the app throw `Incorrect locale
  information provided` and render nothing, so the locale is set.
- **Errors.** No page errors on any run after that.
- **Fixture.** The planner shots draw a wall run and a line, select the
  line and hover the wall.

The screenshots are in
[2026-10-04-dark-theme/](2026-10-04-dark-theme/). What each one shows:

- **`planner_dark_white.png`** — the planner in the dark theme on White.
  - **Panels.** The tool palette, top bar and right panel are dark, and
    every label is light and readable. The swatch row shows White
    selected with a light (primary) border.
  - **Canvas chrome.** The surround is dark (`#111318` sampled). The
    ruler bars are `#2B2D31` with light ticks and labels, and the pointer
    marks are red.
  - **Paper.** The sheet is white with the grid faint grey. The selected
    line samples `#1E6FE8`, the light set, as the paper decides. Its
    grips and the hovered wall's outline are blue.
  - **Page breaks.** They are on: blue dashes along the sheet's edges,
    tiling outward over the dark surround (about 3.6:1 there by
    computation, sampled `#2F5CB6`). Dim, but visible.
  - **The layer row's "Foreground" swatch** is black inside a light
    outline.
- **`planner_dark_blueprint.png`** — the same after a click on the Blueprint
  swatch.
  - **Paper.** The sheet is navy. The grid is light and clearly visible,
    no longer the old near-invisible dark grid. The selection samples
    `#7FB2FF`, with light-blue grips, and the hovered wall's outline is
    light blue. The page breaks are light blue (`#7BA0DC` sampled on the
    surround).
  - **Swatches.** The "Foreground" swatch turned white (ACI 7 on
    Blueprint), and the selected Blueprint swatch has the primary border.
  - **The walls stay black on navy.** They are fixed black (F-8, D7);
    they read, but at low contrast.
- **`planner_dark_symbols.png`** — the Symbols tab on Blueprint. The
  search field, the category headers and the cells are dark. The
  thumbnails are drawn in white and the names are light; all are
  readable.
- **`planner_dark_symbol_armed.png`** — a fresh page (White) with "Bench"
  armed.
  - **The selected cell** is the dark-theme `primaryContainer` (a
    mid-dark blue) with a white thumbnail, as D9b intends.
  - **The ghost on the canvas** is amber `#E8A11E` on white, with a green
    snap cross. This is the light preview's 2.20:1 debt: visible at this
    size, but the weakest colour on screen.
- **`planner_light_white.png`** — the light scheme, the same fixture, for
  comparison.
  - The panels, the light ruler `#F2F2F2` and the blue selection
    `#1E6FE8` are as before Task 1.
  - The swatch border is the scheme's primary and outline (D6a).
  - The surround `#F9F9FF` and the white sheet are close in tone (the
    sheet edge carries the boundary). This is pre-existing.
- **`demo_dark_design.png`** — `restaurant_demo` (teal seed) in the design
  mode, dark.
  - The app bar, the Salon / Teras and Design / Service toggles, the
    right panel (Save disabled, Revert, Fit, the "Table numbers" field,
    the status buttons, Tables, Log) and the planner's panels are all
    dark with readable text.
  - The canvas shows the white sheet and the black drafting.
- **`demo_dark_design_blueprint.png`** — the same after the Blueprint
  swatch. The tables, chairs and numbers turn white, and the grid is
  light. Save becomes enabled, and the log reads "Salon: edited".
- **`demo_dark_service_white.png`** — the service mode on White at the
  default fit (about 0.04 px/mm), with fixed statuses set through the
  "Table numbers" field: Bill on 3, 5, 7, 8 and 9; Ordered on 2 and 10;
  Eating on 6 and 11.
  - The fills sit under the drafting, and the panel is dark.
  - **The captions at this zoom.** "Bill" sits at its 11 px floor below
    the number's anchor, which here is **below the table top**. On 3 and
    5 it falls across the chair and edge outlines, and on 7 just under
    the top, on the white paper.
  - It does not overlap the number. The overlap is with the drafting,
    and it is pre-existing (14c's caption rule).
- **`demo_dark_service_white_zoom.png`** — the same at about 0.25 px/mm
  (table 3's top about 280 px wide). "3" is large and black. "Bill" in
  `#202020` sits just under it, with a clear gap and **no overlap**.
  **Review 5's note is answered:** with the app's real font the caption
  clears the number. The overlap that review saw comes from the test
  font's full-em glyphs. The caption is small (about 8 px glyphs) next to
  the number.
- **`demo_dark_service_blueprint_zoom.png`** — the same statuses and zoom
  on Blueprint (set in the design mode first).
  - The fills are darker composites. The "3" and the "Bill" caption are
    both white (D6c: Bill over navy takes white ink), and Eating's "6" is
    white on green.
  - No overlap. Every caption and number is readable.

**Nothing looked broken.** No unreadable panel text, no light strip, no
missing grid. **The weak spots seen:**
- the amber preview on White;
- black walls on Blueprint;
- the light-set page breaks on the dark surround;
- the low-zoom caption falling onto the chairs (pre-existing).

## Debt

- **The light preview contrast.** `0xFFE8A11E` is 2.20:1 on White
  (F-15). It is kept so that the light theme stays pixel-identical; the
  armed-symbol shot shows it.
- **Ink off the sheet.** Drafting off the sheet keeps the paper's ink, so
  in a dark theme on White it is black on the dark surround. The same
  holds for the light-set page breaks tiled over the surround: dim, about
  3.6:1.
- **A paper near the switch.** On a near-threshold grey such as
  `0x757575`, the dark set reaches only about 2.0–2.5:1. The swatches are
  far from it; a loaded file's paper may not be.
- **Black walls with no page in a dark theme.** Walls sit on the dark
  surface at about 1.1:1, only for a file saved without a page. On
  Blueprint they read at low contrast (seen).
- **The D9a scan's gaps** (review 6):
  - **N1.** Two equal allowed literals in one file cannot be told apart.
    An expected count per (file, literal) pair would fix it.
  - **N2.** A literal split across lines (`Color(\n 0x..)`),
    `Color.from(alpha:)` and `CupertinoColors` pass the spec's verbatim
    patterns.
- **SelectTool's band Paints.** `SelectTool.paintOverlay` allocates two
  `Paint`s and a `Color` per band frame. This is pre-existing at
  `2a439e0`, outside the measured path, and is not this plan's scope.
- **Stale comments.** Three golden test files still say
  `_DraftCustomPainter.shouldRepaint` is "unconditionally false"; they are
  left unedited, since goldens are not touched. Task 7 fixed the same
  comment in `test/support/tile_comparison.dart`.
- **The caption and the number.** With the real font they do not overlap
  at 0.12 or 0.25 px/mm. At the default fit (about 0.04 px/mm) the
  caption's 11 px floor puts it on the chair and edge outlines below the
  top (pre-existing, 14c).
  - **Untested combination.** That off-fill caption is inked for the
    status composite, not for the bare paper it then lies on. With the
    demo's statuses the two agree on every swatch: only Bill has a
    caption, and over White and Blueprint the composite takes the same
    ink as the paper. A captioned host status whose composite and paper
    take different inks would show it. This is not seen; it is reasoned.
- **Not run here:** the macOS build.

## Owed

- **The human's look** on macOS and web, both themes (spec exit gate 5),
  never simulated:
  - the planner on all four papers in each theme;
  - the symbol list;
  - the layer panel;
  - the service view with statuses;
  - a live OS theme switch.

  The screenshots above are evidence for that look, not a substitute.
- **The merge decision.**
