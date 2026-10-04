# Dark theme — design

**Date:** 2026-10-04. **Status:** design, **revision 1**, awaiting an
independent review. **Sub-project:** not on the roadmap; unnumbered until
the human gives it a number.
**Approval:** the human approved the decisions below in the brainstorm on
2026-10-04: the scope ("Arayüz + kanvas çerçevesi"), the host's theme
decides, overlays follow the paper, two palette values carried explicitly,
and D9 (the planner's widgets, the symbol list named) added on the human's
request. "Tamam, spec'i yaz" approved D1–D9 as drafted in the brainstorm.
**Branch:** `claude/dreamy-gates-2kgh4o`. The facts below hold at `5ba6fb2`.
**Size:** S–M. **Packages touched:** `jet_cad_2d_flutter` (render layer:
the palettes, four painters, `Tool.paintOverlay`, `SymbolGallery`),
`jet_cad_floor_plan` (shell, service view, panels, tools), and
`apps/floor_planner` and `apps/restaurant_demo` (theme setup). The engine
(`jet_cad_2d`) is untouched.

## What it delivers

When the host app's `Theme` is dark, the floor planner is dark too:
- every panel, dialog and the symbol list;
- the canvas's chrome: the surround, the rulers and the sheet's edge.

The **paper keeps the document's colour**, so a white sheet sits in a dark
surround and prints exactly as before.

Everything drawn **on** the paper takes its colours from the paper, not
the theme:
- the grid and the page breaks;
- the selection, hover, bands, grips, previews and snap markers.

So they stay legible on White, Ivory, Grey and Blueprint in either theme.
On the way this fixes 07's debt "on Blueprint the grid is nearly
invisible".

In a light theme on light paper, the screen stays pixel-identical to
today.

## Facts established (at `5ba6fb2`)

- **F-1.** No `darkTheme`, `themeMode`, `Brightness` or platform
  brightness appears in the in-scope code. The packages build no `Theme`
  of their own; every UI colour comes from the host's ambient `Theme`.
  - `apps/floor_planner/lib/main.dart:150`:
    `theme: ThemeData(colorSchemeSeed: const Color(0xFF2266CC))`
  - `apps/restaurant_demo/lib/main.dart:62`:
    `theme: ThemeData(colorSchemeSeed: Colors.teal)`
- **F-2.** The canvas chrome is two files of `const` colours with no input:
  - `jet_cad_2d_flutter/lib/src/chrome_style.dart:12-18`: sheet edge
    `0xFF9E9E9E`, major grid `0x33000000`, minor grid `0x14000000`, page
    break `0xFF3366CC`, ruler background `0xFFF2F2F2`, ruler ink
    `0xFF444444`, ruler pointer `0xFFE53935`.
  - `selection_style.dart:4-46`: selection `0xFF1E6FE8`, hover
    `0x991E6FE8`, window band `0xFF1E6FE8`, crossing band `0xFF2E9E5B`,
    band fill alpha `0x22`, grip `0xFF1E6FE8`, move grip `0xFF7A3FD1`, hot
    grip `0xFFE8541E`, preview `0xFFE8A11E`, snap marker `0xFF2E9E5B`.
- **F-3.** Who consumes them:
  - painters that hold `Paint` fields initialised from the constants:
    `PageChromePainter` (`page_chrome_painter.dart:55-71`), `RulerPainter`
    and `RulerCornerPainter` (`ruler_painter.dart:38-43, 152`) and
    `SelectionOverlayPainter` (`selection_overlay.dart:77-105`);
  - tools: `SelectTool` (`select_tool.dart:99-107, 798`), `PlacementTool`
    (`draw/placement_tool.dart:50, 56`) and its eleven subclasses,
    `SymbolPlaceTool` (`symbol_place_tool.dart:91, 94`) and
    `DimensionTool` (`dimension_tool.dart:118`).
- **F-4.** All four painters answer `shouldRepaint(...) => false`
  (`page_chrome_painter.dart:220`, `ruler_painter.dart:144, 177`,
  `selection_overlay.dart:320`). They repaint only through their `repaint`
  listenables.
- **F-5.** `Tool.paintOverlay(Canvas, ViewportTransform, Size)`
  (`tool.dart:115`) has one call site, `selection_overlay.dart:205`. Seven
  classes declare it: `tool.dart`, `select_tool.dart`,
  `draw/placement_tool.dart`, `dimension_tool.dart`, `room_tool.dart`,
  `table_select_tool.dart` and `symbol_place_tool.dart`.
- **F-6.** The surround is `ColoredBox(color: scheme.surface)` behind
  `PlannerView`, at `planner_shell.dart:863-864` and
  `host/service_view.dart:170-171`. The sheet fill is the page's own
  `background` (`page_chrome_painter.dart:86`).
- **F-7.** The paper colour is document data:
  - `PageComponent.background` (`jet_cad_2d/.../page_component.dart:90`),
    default `0xFFFFFFFF`, is saved (`:188`) and set by an undoable command
    (`page_panel.dart:241`);
  - the swatches are White `0xFFFFFFFF`, Ivory `0xFFFAF6EC`, Grey
    `0xFFEDEDED` and Blueprint `0xFF1F3A5F` (`page_panel.dart:26-31`).
- **F-8.** ACI 7's ink is `foregroundFor(paper)`: black or white by WCAG
  contrast (`jet_cad_2d/.../style_resolver.dart:28`).
  - With no page, both views assume white paper:
    `planner_shell.dart:178-179` and `service_view.dart:94-101`
    (`page?.background ?? 0xFFFFFFFF`). The comment at
    `planner_shell.dart:175-177` assumes a light shell surface.
  - Walls are deliberately fixed `TrueColor(0x000000)` (`wall.dart:63`).
- **F-9.** Export always renders on white, whatever the paper or theme:
  `page_export.dart:121` paints `0xFFFFFFFF` and `:61, :132` set
  foreground `0x000000`.
- **F-10.** `restaurant_demo` shows **two** `FloorPlanView`s at once, and
  each has its own document and page. A palette cannot be global.
- **F-11.** The symbol list:
  - cell colour `scheme.surfaceContainerLowest`; thumbnail foreground
    `foregroundFor(cellColor)` (`symbol_panel.dart:202-203, 230`);
  - selected cell `scheme.primaryContainer` with a `scheme.primary` border
    (`symbol_gallery.dart:234-238`);
  - thumbnails are transparent images whose cache key includes the
    foreground (`symbol_thumbnails.dart:76`);
  - no furniture or restaurant symbol carries a `TrueColor` (all
    `ByBlock`), so every leaf follows the foreground;
  - the selected cell's foreground is computed from `cellColor`, not
    `primaryContainer`.
- **F-12.** The UI literals that are not data:
  - `page_panel.dart:249-250`: the swatch border is `Colors.blue` /
    `Colors.black26`;
  - `table_status_painter.dart:169`: the caption is
    `const Color(0xFF202020)`. Captions are cached by `(caption, colour)`
    (`:68, :110`).
- **F-13.** The layer swatch `_Swatch` already has a
  `scheme.outline` border (`layer_row.dart:353-367`). It shows ACI 7 as
  the paper's foreground (`:30-35`, `:200`, `:258`).
- **F-14.** The text entry is a plain `TextField` with
  `InputDecoration(isDense: true, border: OutlineInputBorder())` and no
  fill (`text_entry_overlay.dart:140-154`). In a dark theme its light text
  would sit on the (white) paper.
- **F-15.** Contrast (WCAG ratio) measured for this spec with a short
  script; the method, not a transcript:
  - **today's overlay colours on Blueprint:** selection 2.46, move grip
    1.89, page break 2.14;
  - **today's preview on White:** 2.20. This is a pre-existing gap, not in
    scope (see "Not in scope").

## Decisions

### D1 — The theme's source

- The planner reads `Theme.of(context).brightness` in `PlannerShell` and
  in `ServiceView`.
- `FloorPlanView` gains **no** parameter. A host chooses light or dark by
  its own `ThemeData`.
- `apps/floor_planner` and `apps/restaurant_demo` each add a `darkTheme`
  with the same seed and `brightness: Brightness.dark`, plus
  `themeMode: ThemeMode.system`.

### D2 — `ChromePalette` (follows the theme)

A new immutable value class in `jet_cad_2d_flutter`
(`lib/src/canvas_palette.dart`, exported). Fields: `rulerBackground`,
`rulerInk`, `rulerPointer`, `sheetEdge`. Equality is by value.

| Field | `ChromePalette.light` (= today) | `ChromePalette.dark` |
|---|---|---|
| `rulerBackground` | `0xFFF2F2F2` | `0xFF2B2D31` |
| `rulerInk` | `0xFF444444` | `0xFFC8C8C8` (8.2:1 on its background) |
| `rulerPointer` | `0xFFE53935` | `0xFFFF6B66` (5.0:1) |
| `sheetEdge` | `0xFF9E9E9E` | `0xFF8A8A8A` (5.4:1 on a dark surface `0x121316`, 3.3:1 on Blueprint, 3.5:1 on White) |

- `ChromePalette.of(Brightness)` answers `light` or `dark`.
- The surround stays `scheme.surface` (F-6), unchanged.

### D3 — `PaperPalette` (follows the paper)

The same file holds the second class. Fields: `minorGrid`, `majorGrid`,
`pageBreak`, `selection`, `hover`, `windowBand`, `crossingBand`, `grip`,
`gripMove`, `gripHot`, `preview`, `snap`. `kBandFillAlpha` stays a
constant.

| Field | `PaperPalette.light` (= today) | `PaperPalette.dark` |
|---|---|---|
| `minorGrid` | `0x14000000` | `0x14FFFFFF` |
| `majorGrid` | `0x33000000` | `0x33FFFFFF` |
| `pageBreak` | `0xFF3366CC` | `0xFF8AB4F8` |
| `selection`, `windowBand`, `grip` | `0xFF1E6FE8` | `0xFF7FB2FF` |
| `hover` | `0x991E6FE8` | `0x997FB2FF` |
| `crossingBand`, `snap` | `0xFF2E9E5B` | `0xFF5FD68F` |
| `gripMove` | `0xFF7A3FD1` | `0xFFC4A0FF` |
| `gripHot` | `0xFFE8541E` | `0xFFFF8A5C` |
| `preview` | `0xFFE8A11E` | `0xFFFFC857` |

- **The selection rule.**
  `PaperPalette.forPaper(int argb) = foregroundFor(argb & 0xFFFFFF) == 0xFFFFFF ? dark : light`.
  - It applies to **any** paper value, not only the four swatches: a
    loaded file may carry any `background`.
  - The overlays switch at exactly the paper where ACI 7's ink turns white.
- **Contrast.** Every opaque field of `dark` has at least 3:1 against
  Blueprint and against `0x303030` (measured: selection 5.31, move grip
  5.37, hot grip 4.94, preview 7.46, snap 6.29, page break 5.45 on
  Blueprint).
- **Pairings kept.** The pairings of today's constants are kept: window
  band = selection = grip, and crossing band = snap.

### D4 — The paper when there is no page

The "paper" is `scheme.surface` when the document has no page. Both of
these are computed from it:
- ACI 7's ink: `foregroundFor(scheme.surface)`;
- `PaperPalette.forPaper(scheme.surface)`.

It replaces `0xFFFFFFFF` at `planner_shell.dart:178-179` and
`service_view.dart:94-101`. The comment at `:175-177` is rewritten to
match. The resolver is still replaced **only when the foreground flips**
(fix/post-07), and now the theme can flip it too.

### D5 — Delivery

- **`PlannerView`.** It takes `chrome: ChromePalette` and
  `paper: PaperPalette` (both required; the shell and the service view
  compute them in `build`). It hands them on to:
  - `PageChromePainter` (sheet edge, grid, breaks);
  - `RulerFrame`, then `RulerPainter` / `RulerCornerPainter` (chrome);
  - `SelectionOverlayPainter` (paper).
- **Paints.** Each painter keeps its `Paint` fields and assigns each
  colour from its palette in `paint`. A `Color` field read is not an
  allocation, so the frame path stays allocation-free (non-negotiable;
  `paint_allocation_test.dart`).
- **`shouldRepaint`.** Each of the four painters returns
  `old.chrome != chrome` / `old.paper != paper` instead of `false` (F-4).
  Otherwise a theme or paper flip would not repaint until the camera moved.
- **Tools.** The signature becomes
  `Tool.paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport, PaperPalette paper)`.
  `SelectionOverlayPainter` passes its own `paper`. All seven declarations
  (F-5) take it, and every tool colours its band, guide, ghost, attach
  rings and snap marker from it. No tool keeps a colour in a field
  initialiser any more.
- **No global state.** Each view computes its own palettes from its own
  page and theme (F-10).
- **Removed constants.** The colour constants leave `chrome_style.dart`
  and `selection_style.dart`; the sizes and widths stay. Nothing outside
  the palette file names a chrome colour literal.

### D6 — UI fixes on the canvas

- **D6a.** The page swatch border is `scheme.primary` (selected) or
  `scheme.outline` (not selected), replacing `Colors.blue` /
  `Colors.black26` (F-12).
- **D6b.** The text entry decoration gains `filled: true` and
  `fillColor: scheme.surfaceContainerHighest`. Its text is the theme's
  `onSurface`, which contrasts with the fill in both themes. So the field
  stays readable on any paper (F-14).
- **D6c.** A table status caption is drawn in
  `foregroundFor(over(status.color, paper))`:
  - `over` composites the status colour's alpha onto the paper;
  - the paper is the page background, or `scheme.surface` with no page
    (D4);
  - `TableStatusPainter` takes the paper colour;
  - the caption cache key becomes `(caption, colour, ink)`, so a flip
    builds the new paragraph once and steady state allocates nothing.

### D7 — What does not change

- **Export and print:** white paper, black ACI 7 (F-9).
- **Walls:** fixed black (F-8).
- **The file format:** no new field; the theme is never saved.
- **Light theme on light paper:** the screen is pixel-identical to today.
  `ChromePalette.light` and `PaperPalette.light` equal today's constants.
- **The engine:** untouched.

### D8 — Tests

See "Testing and named mutants".

### D9 — The planner's widgets follow the theme

**In scope:**
- every widget in `jet_cad_floor_plan`: tool palette, document toolbar,
  status line, symbol panel, symbol search, layer panel and picker,
  selection panel, page panel, export and print dialogs, text entry,
  `ServiceView`;
- `SymbolGallery` in `jet_cad_2d_flutter`;
- `apps/restaurant_demo`'s own UI.

**The rules:**
- **D9a — No literal colours in widgets.** A widget takes its colours from
  `Theme.of(context)` only. A source-scan test pins it (M-DT-14).
  - **The scan.** It reads every `.dart` file under
    `packages/jet_cad_floor_plan/lib` and `packages/jet_cad_2d_flutter/lib`,
    and fails on any `Color(0x`, `Color(0X` or `Colors.` that is **not**
    `Colors.transparent` and not on the allow-list.
  - **The allow-list**, by file and reason, data or not a screen colour:
    - `canvas_palette.dart`: the palettes themselves;
    - `layer_row.dart`: the layer colour swatch, `Color(0xFF000000 | ...)`,
      which shows the layer's colour;
    - `vertices_draw_sink.dart`: the opaque carrier paint, whose colour
      rides on the vertices;
    - `export/page_export.dart`: export's white page (D7).
  - **Not literals.** `Color(page.background)`, `Color(_swatches[i].$2)`
    and `TableStatus.color` are data from variables and are not matched.
  - **After this spec.** D6a and D6c remove the two current offenders
    (F-12).
- **D9b — The selected symbol cell's foreground.** A cell's thumbnail
  foreground is `foregroundFor` of **its own** background:
  `primaryContainer` when selected, `cellColor` otherwise (F-11).
  - `SymbolGallery` takes a `selectedForeground` beside `foreground`
    (computed by `SymbolPanel`), and a cell passes the one that matches
    its state to `SymbolThumbnails.imageFor`.
  - In the light theme both backgrounds are light, so today's pixels hold.
- **D9c — The layer swatch.** The "Foreground" swatch keeps showing the
  paper's ink, because that is the data. Its `scheme.outline` border
  (F-13) stays, so a black swatch reads on a dark panel. This is pinned by
  a test, not changed.
- **D9d — A live switch.** When the host's theme changes while the
  planner is open, every widget, thumbnail and canvas palette follows it
  on the next frame:
  - no widget caches a theme colour in `initState` or a `late final`;
  - palettes are computed in `build`;
  - the painters repaint by D5's `shouldRepaint`;
  - thumbnails re-request with the new foreground (F-11's cache key).

## Not in scope

- **Ink off the sheet.** Drafting that lies off the sheet keeps the
  paper's ink. In a dark theme on White paper it is black on the dark
  surround (07's Blueprint debt, mirrored). Inking by region would change
  the draw path.
- **A dark canvas mode.** Showing the paper dark regardless of the
  document's colour (AutoCAD style) is not part of this spec.
- **Theme choice.** There is no in-app System / Light / Dark switch and no
  stored preference.
- **Host colours.** There is no host API for canvas colours and no
  `ThemeExtension`.
- **Today's preview contrast on light paper.** `0xFFE8A11E` is 2.20:1 on
  White (F-15). `PaperPalette.light` keeps it so the light theme stays
  pixel-identical. It is recorded as debt.
- **The startup plan's fixed `TrueColor`s** (`startup_plan.dart:59-60`).
  They are sample content.

## Files

- **New:** `packages/jet_cad_2d_flutter/lib/src/canvas_palette.dart`
  (`ChromePalette`, `PaperPalette`), exported from the package barrel.
- **Changed, `jet_cad_2d_flutter`:**
  - `chrome_style.dart` and `selection_style.dart` (colours removed);
  - `page_chrome_painter.dart`, `ruler_painter.dart`, `ruler_frame.dart`,
    `selection_overlay.dart`;
  - `tool.dart`, `select_tool.dart`, `draw/placement_tool.dart`;
  - `symbol_gallery.dart`.
- **Changed, `jet_cad_floor_plan`:**
  - `planner_view.dart`, `planner_shell.dart`, `host/service_view.dart`;
  - `page_panel.dart`, `text_entry_overlay.dart`,
    `service/table_status_painter.dart`;
  - `symbols/symbol_panel.dart`, `symbols/symbol_place_tool.dart`;
  - `parametric/dimension_tool.dart`, `parametric/room_tool.dart`,
    `service/table_select_tool.dart`.
- **Apps:** `apps/floor_planner/lib/main.dart`,
  `apps/restaurant_demo/lib/main.dart`.
- **Tests:** new and updated, listed under "Testing and named mutants".
  Existing tests that name the removed constants switch to
  `PaperPalette.light.*` / `ChromePalette.light.*`. Their expectations do
  not change.

## Invariants

1. **The frame path allocates nothing per entity in steady state, and
   O(1) per flush.** This is unchanged, measured by both allocation
   invariants. A palette flip may allocate (a caption paragraph, a
   resolver) once, never per frame.
2. **Light theme on light paper is pixel-identical to today.** The
   existing goldens and pixel tests pass with no edits to their
   expectations.
3. **Export is independent of theme and paper** (D7).
4. **Two views never share a palette** (F-10).

## Testing and named mutants

**Fixtures.**
- No degenerate fixture: the paper is never the default white where the
  rule under test is about the paper.
- The camera is off the origin at a non-unit scale.
- Dark theme fixtures use
  `ThemeData(colorSchemeSeed: Color(0xFF2266CC), brightness: Brightness.dark)`,
  so the surface is the real seed's, not a hand-picked black.
- Pixel samples take the brightest or darkest of a 3×3 block, as 10's and
  11's paint tests do.

**Named mutants.** Each must turn at least one test red.

- **M-DT-1** — `PaperPalette.forPaper` inverted, so dark paper gets the
  light set. A Blueprint page's selected line samples `0x7FB2FF`, not
  `0x1E6FE8`.
- **M-DT-2** — `forPaper` keyed on theme brightness instead of the paper.
  In a dark theme on White paper the selection is `0x1E6FE8`, and in a
  light theme on Blueprint it is `0x7FB2FF`. Both combinations are tested.
- **M-DT-3** — `forPaper` thresholded on its own rule instead of
  `foregroundFor`. For a set of paper values (the four swatches, plus
  `0x757575` (white ink) and `0x767676` (black ink), either side of the
  WCAG switch per `style_resolver.dart:24-26`), the set is
  `dark` exactly when `foregroundFor` is white.
- **M-DT-4** — `PageChromePainter` ignores `paper` for the grid. On
  Blueprint the major-grid pixel is lighter than the bare paper, and on
  White it is darker.
- **M-DT-5** — The page breaks ignore `paper`. On Blueprint the break
  pixel is `0x8AB4F8`-ish (blue channel dominant, luminance above the
  paper's).
- **M-DT-6** — `RulerPainter` / `RulerCornerPainter` ignore `chrome`. In
  a dark theme the ruler bar and the corner box sample `0x2B2D31` and the
  tick ink is light.
- **M-DT-7** — `sheetEdge` taken from `light` in a dark theme. The edge
  pixel on a dark surround samples `0x8A8A8A`.
- **M-DT-8** — A tool ignores `paintOverlay`'s `paper`. On Blueprint:
  - the line tool's rubber band samples `0xFFC857`;
  - `SymbolPlaceTool`'s ghost and snap marker sample the dark set;
  - `DimensionTool`'s attach ring samples the dark set.
  One assertion per tool family that names a colour today (F-3).
- **M-DT-9** — `shouldRepaint` still `false`. A test pumps a light-theme
  planner, then switches the host's `ThemeMode` to dark without moving the
  camera; the ruler and the surround are dark on the next frame. A paper
  flip from White to Blueprint likewise recolours the grid without a
  camera move.
- **M-DT-10** — No-page ink still from white (D4). In a dark theme with
  no page, a drafted ACI 7 line samples light on the dark surface, and
  the selection is the dark set.
- **M-DT-11** — Two views share palette state. `restaurant_demo`'s two
  views, one page White and one Blueprint, show the light and the dark
  overlay set respectively in the same frame.
- **M-DT-12** — The text entry has no fill (D6b). In a dark theme on
  White paper, a pixel inside the field away from the glyphs is
  `surfaceContainerHighest`, not the paper.
- **M-DT-13** — The status caption stays fixed or ignores the paper
  (D6c). A Bill caption over Blueprint is light, and over White it is
  dark. The caption cache holds one paragraph per `(caption, colour, ink)`
  across ten steady frames (`debugAllocations` unchanged).
- **M-DT-14** — A literal colour added to a widget (D9a). The source scan
  goes red when a `Color(0xFF123456)` is inserted into `symbol_panel.dart`
  (scratch mutation, reverted), and stays green on the allow-list.
- **M-DT-15** — The selected cell's foreground taken from `cellColor`
  (D9b). In a dark theme the selected cell's thumbnail centre leaf
  contrasts with `primaryContainer` (≥ 3:1). The unselected cell's leaf is
  light.
- **M-DT-16** — A thumbnail foreground fixed at black. In a dark theme an
  unselected cell's centre leaf is light (`> 200` per channel). The light
  theme control stays dark.
- **M-DT-17** — A widget caches a theme colour in `initState`. The live
  switch test (M-DT-9's) also asserts that the symbol panel's cell colour
  and the page panel's swatch border follow the dark scheme after the
  switch.
- **M-DT-18** — The layer swatch loses its outline (D9c). In a dark theme
  the "Foreground" swatch's border pixel is `scheme.outline`.
- **M-DT-19** — The light palettes drift from today. `ChromePalette.light`
  and `PaperPalette.light` equal the F-2 literals, field by field, and
  the existing goldens pass unedited.
- **M-DT-20** — The dark set loses contrast. A table test asserts each
  opaque `PaperPalette.dark` field has at least 3:1 on Blueprint and
  `0x303030`, and each `ChromePalette.dark` ink at least 4.5:1 on
  `rulerBackground`.

**The panel sweep.** Every panel in D9's list is pumped under the dark
theme and paints without an exception. This is a weak test on its own,
kept as a smoke test; the named mutants above carry the weight.

## Exit gate

1. Every package's green line (CLAUDE.md), and both apps'
   `flutter test` and `flutter analyze`.
2. `flutter build web --release` for `apps/floor_planner` and
   `apps/restaurant_demo`.
3. Both allocation invariants pass unedited.
4. M-DT-1 to M-DT-20 are each killed, recorded in a results note under
   `docs/superpowers/notes/`.
5. **The human's look**, on macOS and web, both themes. It is owed and
   never simulated. The list:
   - the planner on all four papers, in each theme;
   - the symbol list;
   - the layer panel;
   - the service view with statuses;
   - a live OS theme switch.

## Risks

- **The dark values are chosen by contrast, not seen.** D2 and D3's
  colours meet their ratios; whether they look right is the human's look
  (gate 5).
- **`paintOverlay` changes signature.** Any out-of-tree `Tool` (a host's
  own tool) breaks at compile time. The host API (14b-2) exports no
  `Tool`, so no host is affected today.
- **A `scheme.surface` that sits near the WCAG switch.** A host seed whose
  surface lands near mid-grey picks ink and overlays by the same rule. So
  they stay consistent with each other, but either may be low-contrast.
  This is accepted; Material 3 surfaces are far from mid-grey.
