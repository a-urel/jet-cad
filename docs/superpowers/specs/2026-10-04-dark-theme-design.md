# Dark theme — design

**Date:** 2026-10-04. **Status:** design, **revision 2**. Revision 1
(`aceed65`) was reviewed independently: "Ready with fixes", R-1 to R-20,
six of them blocking. All twenty are applied **in place**; the
[Revision log](#revision-log) maps each finding to its change. **Sub-project:** not on the roadmap; unnumbered until
the human gives it a number.
**Approval:** revision 2 **approved** by the human ("Onaylıyorum",
2026-10-04), including R-5's two deliberate light-theme changes (D6a,
D6b). Before that, the human approved the decisions below in the
brainstorm on 2026-10-04: the scope ("Arayüz + kanvas çerçevesi"), the host's theme
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
  - the ruler labels, a `const TextStyle(color: kRulerInk, ...)` at
    `ruler_painter.dart:134` and `:168`;
  - tools: `SelectTool` (`select_tool.dart:99-107, 798`), `PlacementTool`
    (`draw/placement_tool.dart:50, 56`) and its eleven subclasses,
    `SymbolPlaceTool` (`symbol_place_tool.dart:91, 94`) and
    `DimensionTool` (`dimension_tool.dart:118`).
- **F-4.** All four painters answer `shouldRepaint(...) => false`
  (`page_chrome_painter.dart:220`, `ruler_painter.dart:144, 177`,
  `selection_overlay.dart:320`). They repaint only through their `repaint`
  listenables.
- **F-5.** A tool paints through **two** methods, both called by
  `SelectionOverlayPainter`:
  - `Tool.paintWorldOverlay(Canvas, Vector2, double)` (`tool.dart:137`),
    called at `selection_overlay.dart:163`. Four classes declare it:
    `tool.dart`, `draw/placement_tool.dart:295` (the rubber band, through
    `bandPaint`), `select_tool.dart:870` (`_previewPaint`, the reshape
    preview) and `symbol_place_tool.dart:479` (`_ghostPaint`).
  - `Tool.paintOverlay(Canvas, ViewportTransform, Size)` (`tool.dart:115`),
    called at `selection_overlay.dart:205`, after the first. Seven classes
    declare it: `tool.dart`, `select_tool.dart`,
    `draw/placement_tool.dart`, `dimension_tool.dart`, `room_tool.dart`,
    `table_select_tool.dart` and `symbol_place_tool.dart`.
- **F-6.** The surround is `ColoredBox(color: scheme.surface)` behind
  `PlannerView`, at `planner_shell.dart:863-864` and
  `host/service_view.dart:170-171`. The sheet fill is the page's own
  `background` (`page_chrome_painter.dart:86`).
- **F-7.** The paper colour is document data:
  - `PageComponent.background` (`jet_cad_2d/.../page_component.dart:90`),
    default `0xFFFFFFFF` (`:104`), is saved (`:188`) and set by an undoable command
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
- **F-10.** `restaurant_demo` holds **two** controllers (two dining areas,
  each with its own document and page) and mounts **one** `FloorPlanView`
  at a time (`apps/restaurant_demo/lib/main.dart:279`, keyed by the
  controller; the area toggle at `:91-100`, `:247-253`). The host API
  permits two views in one frame, so a palette cannot be global state.
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
- **F-16.** `ServiceView` builds its status painter once, as a
  `late final` (`host/service_view.dart:83`), with a fixed repaint merge
  (camera, statuses, `_changed`). The painter rebuilds its fills only on a
  state id, a revision or a new status map
  (`table_status_painter.dart:179-186`).
- **F-17.** The chrome and overlay painters' allocation discipline is
  pinned by Paint-identity tests (`selection_overlay_test.dart:317-345`),
  not by `paint_allocation_test.dart`, which measures `DraftPainter` only
  (`:140`).
- **F-18.** Material 3 values for the shipped seeds, computed by the
  reviewer with material-color-utilities 0.3.0 (tonal spot); tests read
  the real `ThemeData` values, never these:
  - seed `0x2266CC`, light: surface `#F9F9FF` (black ink);
  - seed `0x2266CC`, dark: surface `#111318`, surfaceContainerLowest
    `#0C0E13`, primaryContainer `#2B4678` (all white ink);
  - teal behaves the same way.
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
- **During a theme animation** (`MaterialApp` lerps a theme change over
  200 ms), `brightness` flips at t = 0.5, so the chrome and overlay
  palettes snap mid-animation. The surround and panels lerp. With no page,
  ACI 7's ink flips where the lerped `scheme.surface` crosses
  `foregroundFor`'s switch. This is accepted.

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

**Where it happens.** The shell and the service view each keep the
surface's ARGB in a field, `_surfaceArgb`.
- It is set in `didChangeDependencies` from `Theme.of(context)`. That is
  the only place either state reads the theme for this purpose.
- One function, `_paperArgb() => _page.value?.background ?? _surfaceArgb`,
  feeds both the resolver and `PaperPalette.forPaper`.
- The resolver is re-derived in two places, `didChangeDependencies` and
  `_onPage`, and replaced only on a foreground flip.
- The resolver's field initialiser can no longer read the surface, so it
  becomes a `late` assigned in the first `didChangeDependencies`.

In the light theme the surface (`#F9F9FF`, F-18) takes black ink, as
today's assumed white does.

### D5 — Delivery

- **`PlannerView`.** It takes `chrome: ChromePalette` and
  `paper: PaperPalette` (both required; the shell and the service view
  compute them in `build`). It hands them on to:
  - `PageChromePainter` (sheet edge, grid, breaks);
  - `RulerFrame`, then `RulerPainter` / `RulerCornerPainter` (chrome);
  - `SelectionOverlayPainter` (paper).
- **Painter parameters.** The four painters and `RulerFrame` take
  `chrome` and/or `paper` as **required** parameters with no default, so
  a call site that forgets one does not compile and never shows the light
  set by accident.
- **Paints.** Each painter keeps its `Paint` fields and assigns each
  colour from its palette in `paint`. A `Color` field read is not an
  allocation, so the frame path stays allocation-free. The Paint-identity
  tests (F-17) stay unedited and green, and `SelectionOverlayPainter`'s
  Paints stay distinct objects after the palette is assigned.
  `paint_allocation_test.dart` stays green too.
- **Ruler labels.** `RulerPainter` and `RulerCornerPainter` build their
  label `TextStyle` from `chrome.rulerInk` once per painter instance (a
  `late final` field). A new instance comes only with a rebuild, so no
  `TextStyle` is built per frame.
- **`shouldRepaint`.** Each of the four painters returns
  `old.chrome != chrome` / `old.paper != paper` instead of `false` (F-4).
  Otherwise a theme or paper flip would not repaint until the camera moved.
- **Tools.** **Both** paint methods (F-5) gain a final `PaperPalette paper`
  parameter:
  - `Tool.paintWorldOverlay(Canvas canvas, Vector2 origin, double scale, PaperPalette paper)`;
  - `Tool.paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport, PaperPalette paper)`.

  `SelectionOverlayPainter` passes its own `paper` to both calls. All four
  and all seven declarations take it, and every tool colours its band,
  guide, reshape preview, ghost, attach rings and snap marker from it,
  in the method that draws them.
  - `PlacementTool.paintWorldOverlay` sets `bandPaint.color` before it
    calls `paintRubberBand`, so the eleven subclasses are untouched.
  - No tool keeps a colour in a field initialiser any more.
- **No global state.** Each view computes its own palettes from its own
  page and theme (F-10).
- **Removed constants.** The colour constants leave `chrome_style.dart`
  and `selection_style.dart`; the sizes and widths stay. Nothing outside
  the palette file names a chrome colour literal.

### D6 — UI fixes on the canvas

- **D6a.** The page swatch border is `scheme.primary` (selected) or
  `scheme.outline` (not selected), replacing `Colors.blue` /
  `Colors.black26` (F-12). **This deliberately changes the light theme
  too**: the border becomes the scheme's primary / outline.
- **D6b.** The text entry decoration gains `filled: true` and
  `fillColor: scheme.surfaceContainerHighest`. Its text is the theme's
  `onSurface`, which contrasts with the fill in both themes. So the field
  stays readable on any paper (F-14). **This deliberately changes the
  light theme too**: today the paper shows through the field.
- **D6c.** A table status caption's ink follows what it sits on.
  - `ink = foregroundFor(over(status.color, paper))`, where `over`
    composites the status colour's alpha onto the paper's RGB.
  - The paper is `_paperArgb()` (D4): the page background, or
    `scheme.surface` with no page.
  - **Caption colours.** Black ink draws in `kStatusCaptionOnLight =
    Color(0xFF202020)` (today's caption, so the light theme holds) and
    white ink in `kStatusCaptionOnDark = Color(0xFFFFFFFF)`. Both
    constants live in `canvas_palette.dart`. `foregroundFor` returns
    `0xRRGGBB`, so a raw `Color(foregroundFor(...))` would be fully
    transparent; the mapping to these two constants is the only
    conversion.
  - **Reaching the painter.** `ServiceView` holds a `ValueNotifier<int>`,
    `_paper`, set to `_paperArgb()` in `didChangeDependencies` and in
    `_onPage`. `TableStatusPainter` takes it as
    `paper: ValueListenable<int>`. `_paper` joins the painter's repaint
    merge (F-16), and a change of its value joins the painter's rebuild
    condition.
  - **The cache.** The caption cache key becomes `(caption, colour, ink)`,
    so a flip builds the new paragraph once and steady state allocates
    nothing.

### D7 — What does not change

- **Export and print:** white paper, black ACI 7 (F-9).
- **Walls:** fixed black (F-8).
- **The file format:** no new field; the theme is never saved.
- **Light theme on light paper:** the canvas chrome, the overlays, the
  drafting and the status captions are pixel-identical to today.
  `ChromePalette.light` and `PaperPalette.light` equal today's constants.
  D6a's swatch border and D6b's text entry fill are the only deliberate
  light-theme changes.
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
    `packages/jet_cad_floor_plan/lib`, `packages/jet_cad_2d_flutter/lib`,
    `apps/floor_planner/lib` and `apps/restaurant_demo/lib`. It fails on
    any match of `\bColor\(0[xX]`, `\bColor\.from(ARGB|RGBO)\(` or
    `\bColors\.(?!transparent\b)` that is not on the allow-list.
    - The word boundary keeps `TrueColor(0x...)`, which is document data
      (`wall.dart:63`, `startup_plan.dart:59-60`), out of the match.
  - **The allow-list.** It holds `canvas_palette.dart` as a whole file
    (the palettes and the two caption inks). Every other entry is a
    **(file, exact literal)** pair, so a second literal in the same file
    still goes red. Each is data or not a screen colour:
    - `layer_row.dart`: `Color(0xFF000000 |`, the layer colour swatch,
      which shows the layer's colour;
    - `vertices_draw_sink.dart`: `Color(0xFFFFFFFF)`, the opaque carrier
      paint, whose colour rides on the vertices;
    - `export/page_export.dart`: `Color(0xFFFFFFFF)`, export's white page
      (D7);
    - `apps/floor_planner/lib/main.dart`: `Color(0xFF2266CC)`, the theme
      seed;
    - `apps/restaurant_demo/lib/main.dart`: `Colors.teal` (the seed) and
      `Color(0x99FFB300)`, `Color(0x9943A047)`, `Color(0x99E53935)` (the
      demo's status data).
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
  - **Scope.** For both shipped seeds, `cellColor` and `primaryContainer`
    take the same ink in each theme (F-18), so D9b changes nothing on
    them. It protects a host scheme whose `primaryContainer` sits on the
    other side of the switch.
- **D9c — The layer swatch.** The "Foreground" swatch keeps showing the
  paper's ink, because that is the data. Its `scheme.outline` border
  (F-13) stays, so a black swatch reads on a dark panel. This is pinned by
  a test, not changed.
- **D9d — A live switch.** When the host's theme changes while the
  planner is open, every widget, thumbnail and canvas palette follows it
  once the theme animation settles (D1):
  - no widget caches a theme colour in `initState` or a `late final`;
  - palettes are computed in `build`;
  - the painters repaint by D5's `shouldRepaint`;
  - thumbnails re-request with the new foreground (F-11's cache key).

## Not in scope

- **Ink off the sheet.** Drafting that lies off the sheet keeps the
  paper's ink. In a dark theme on White paper it is black on the dark
  surround (07's Blueprint debt, mirrored). Inking by region would change
  the draw path.
- **Black walls with no page in a dark theme.** Walls are fixed black
  (F-8). With no page they sit on the dark surface at about 1.1:1. Every
  new document gets `defaultPage()` (`new_document.dart:35, 44`), so a
  page-less document arrives only from a file saved without one.
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
- **Changed for D6c:** `host/service_view.dart` (the `_paper` notifier)
  and `service/table_status_painter.dart`.
- **Tests:** new and updated, listed under "Testing and named mutants".
  Existing tests that name the removed constants switch to
  `PaperPalette.light.*` / `ChromePalette.light.*`. Their expectations do
  not change.
- **Tests that change mechanically.** They construct a painter, a
  `RulerFrame` or a `TableStatusPainter`, or declare or call a tool paint
  method (Tool subclasses such as `IdleTool`, `RecordingTool`,
  `_CountingTool`, `_CursorTool`). Each passes `.light` palettes or adds
  the new parameter, with no expectation changed.
  - `jet_cad_2d_flutter/test/`: `draw/draw_overlay_test.dart`,
    `draw/placement_tool_test.dart`, `interaction_cursor_test.dart`,
    `interaction_layer_touch_test.dart`, `outline_cache_test.dart`,
    `page_chrome_painter_test.dart`, `ruler_frame_test.dart`,
    `ruler_painter_test.dart`, `select_tool_move_resolver_test.dart`,
    `selection_overlay_grips_test.dart`, `selection_overlay_test.dart`,
    `support/grip_fixture.dart`, `support/selection_fixture.dart`,
    `tool_controller_test.dart`;
  - `jet_cad_floor_plan/test/`: `dimension_tool_test.dart`,
    `opening_tool_test.dart`, `room_tool_test.dart`,
    `service/table_status_painter_test.dart`,
    `symbols/symbol_panel_test.dart`,
    `symbols/symbol_place_tool_test.dart`.

## Invariants

1. **The frame path allocates nothing per entity in steady state, and
   O(1) per flush.** This is unchanged, measured by both allocation
   invariants and the Paint-identity tests (F-17). A palette flip may
   allocate (a caption paragraph, a resolver, a ruler `TextStyle`) once,
   never per frame.
2. **Light theme on light paper: the canvas is pixel-identical to
   today.** This covers the chrome, the overlays, the drafting and the
   captions; D6a and D6b are the only deliberate changes (D7). The
   existing goldens and pixel tests pass with no edits to their
   expectations.
3. **Export is independent of theme and paper** (D7).
4. **No global mutable palette state.** Each view derives its own
   palettes from its own page and theme. The `const` `.light` / `.dark`
   instances are immutable and shared by design (F-10).

## Testing and named mutants

**Fixtures.**
- No degenerate fixture: the paper is never the default white where the
  rule under test is about the paper.
- The camera is off the origin at a non-unit scale.
- Dark theme fixtures use
  `ThemeData(colorSchemeSeed: Color(0xFF2266CC), brightness: Brightness.dark)`,
  so the surface is the real seed's, not a hand-picked black. The one
  exception is M-DT-15, which must override `primaryContainer` (D9b's
  scope).
- A test that switches theme sets `themeAnimationDuration: Duration.zero`
  on its `MaterialApp`, or pumps until settled, so it never samples a lerp.
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
  a dark theme the ruler bar and the corner box sample `0x2B2D31`, the
  tick ink is light, and the label `TextSpan`'s style colour is
  `0xFFC8C8C8` (read from the recording canvas or the painter's
  `TextPainter`). The last catches a label left on `kRulerInk`.
- **M-DT-7** — `sheetEdge` taken from `light` in a dark theme. Through the
  recording-canvas pattern (`selection_overlay_test.dart:314`), the
  sheet-edge stroke's `Paint.color` is `0xFF8A8A8A`. It is not a pixel
  test, because a 1 px edge at a fractional position blends.
- **M-DT-8** — A tool ignores `paper` in either paint method. On
  Blueprint, one assertion per tool family that names a colour today
  (F-3, F-5):
  - the line tool's rubber band (`paintWorldOverlay`) samples `0xFFC857`;
  - `SymbolPlaceTool`'s ghost (`paintWorldOverlay`) and snap marker
    (`paintOverlay`) sample the dark set;
  - `DimensionTool`'s attach ring samples the dark set;
  - `SelectTool`'s window band, crossing band, guide line and reshape
    preview (`paintWorldOverlay`) sample `0x7FB2FF`, `0x5FD68F`,
    `0xFFC857` and `0xFFC857`.
- **M-DT-9** — `shouldRepaint` still `false`.
  - **The theme flip.** A test pumps a light-theme planner, then switches
    the host's `ThemeMode` to dark (zero animation) without moving the
    camera. The ruler bar and the sheet-edge `Paint.color` are the dark
    chrome. The surround is not asserted here: it is a `ColoredBox`
    rebuilt by `Theme` and proves nothing about `shouldRepaint`.
  - **The paper flip.** With a line selected, the page goes from White to
    Blueprint without a camera move. The selection outline samples
    `0x7FB2FF`. `SelectionOverlayPainter`'s repaint merge excludes the
    page, so only `shouldRepaint` can repaint it. The grid is not the
    witness here: `PageChromePainter` already repaints through the page
    notifier.
- **M-DT-10** — No-page ink still from white (D4). In a dark theme with
  no page, a drafted ACI 7 line samples light on the dark surface, and
  the selection is the dark set.
- **M-DT-11** — Two views share palette state. A test harness pumps two
  `FloorPlanView`s side by side in one frame, one on a White page and one
  on Blueprint, each with a line selected. They show the light and the
  dark selection colour respectively. `restaurant_demo` mounts one view at
  a time (F-10), so the demo is not the fixture.
- **M-DT-12** — The text entry has no fill (D6b). In a dark theme on
  White paper, a pixel inside the field away from the glyphs is
  `surfaceContainerHighest`, not the paper.
- **M-DT-13** — The status caption stays fixed, ignores the paper, or its
  cache ignores the ink (D6c).
  - On **one** painter instance, Bill is painted on White: a dark glyph
    pixel.
  - The paper notifier then flips to Blueprint: a light glyph pixel, and
    `debugAllocations` rises by exactly one.
  - Ten steady frames follow: `debugAllocations` is unchanged.
  - A `ServiceView` with no page, switched from light to dark theme,
    repaints the caption light. This catches a `_paper` notifier left out
    of the repaint merge (F-16).
- **M-DT-14** — A literal colour added to a widget (D9a). The source scan
  goes red when a `Color(0xFF123456)` is inserted into `symbol_panel.dart`
  (scratch mutation, reverted), and stays green on the allow-list.
- **M-DT-15** — The selected cell's foreground taken from `cellColor`
  (D9b). The fixture is the dark seed scheme with
  `primaryContainer` overridden to a light colour,
  `scheme.copyWith(primaryContainer: Color(0xFFD8E2FF))`. With the real
  seed both cells take white ink and the mutant is invisible (F-18). The
  selected cell's centre leaf is dark (≥ 3:1 on `0xD8E2FF`), and the
  unselected cell's leaf is light.
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
  and `PaperPalette.light` equal the F-2 literals, field by field. That
  equality carries this mutant: the goldens are draft ladders and cover no
  chrome.
- **M-DT-20** — The dark set loses contrast. A table test asserts each
  opaque `PaperPalette.dark` field has at least 3:1 on Blueprint and
  `0x303030`. It also asserts that `ChromePalette.dark.rulerInk` and
  `ChromePalette.dark.rulerPointer` each have at least 4.5:1 on
  `rulerBackground`. `sheetEdge` is not held to that bar, since it is
  4.0:1 there and borders the paper, not the ruler.

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
- **A paper near the WCAG switch.** `forPaper` picks the dark set for any
  paper that takes white ink. On a near-threshold grey such as `0x757575`,
  the dark set reaches only about 2.0–2.5:1 (preview 3.0). The swatches
  sit far from it; a loaded file's arbitrary paper may not.
- **A `scheme.surface` that sits near the WCAG switch.** A host seed whose
  surface lands near mid-grey picks ink and overlays by the same rule. So
  they stay consistent with each other, but either may be low-contrast.
  This is accepted; Material 3 surfaces are far from mid-grey.

## Amended at execution

Recorded at the plan's exit (Task 7). Each was a proposed ruling, accepted
by that task's independent review; the ledger is
`.superpowers/sdd/2026-10-04-dark-theme/progress.md`.

- **R-C4-1 — `DraftCanvas` repaints on a new painter** (`37a1797`).
  `_DraftCustomPainter.shouldRepaint` in
  `jet_cad_2d_flutter/lib/src/draft_canvas.dart` (not in "Files") also
  answers `old.painter != painter`.
  - D4's theme flip with no page replaces the resolver, and `DraftCanvas`
    re-attaches a new `DraftPainter`, but no `DocChange` and no camera
    move follow. Without this line the old ink stayed on screen.
  - `painter` is assigned only in `_attach()` (`initState`, or
    `didUpdateWidget` on a real prop change). An ordinary rebuild keeps
    the painter and still answers false; frame accounting is unedited.
  - Pinned by `draft_canvas_test.dart` (a new resolver repaints; the same
    one does not) and by the shell's and `ServiceView`'s no-page theme
    switches.
- **R-C4-2 — M-DT-9's paper-flip premise is wrong** (`37a1797`).
  "`SelectionOverlayPainter`'s repaint merge excludes the page, so only
  `shouldRepaint` can repaint it" does not hold with a line selected:
  `OutlineCache._onChange` (`outline_cache.dart:248-259`) notifies on any
  `DocChange` while the selection is non-empty, and a page change is a
  command.
  - So the White to Blueprint test cannot kill the overlay's
    `shouldRepaint => false`. That mutant is killed by the **no-page theme
    switch** (shell and `ServiceView`), where no `DocChange` happens and
    the paper set flips with the surface.
  - The paper-flip test stays: it pins the selection colour after a real
    page change and kills `_onPage` without `setState`.
- **R-C5-1 — D7's "captions unchanged" is scoped** (`6e3fa02`). In the
  light theme a status caption is pixel-identical to today **when the
  status composited over the paper takes black ink**; the demo's three
  statuses do on White, Ivory and Grey. A status whose composite
  takes white ink (an opaque dark host colour) now gets
  `kStatusCaptionOnDark` in the light theme too: D6c's formula, where
  today's `0xFF202020` on such a fill is unreadable.
- **R-C2-1 — ruler label test seam** (`2a439e0`). `RulerPainter` and
  `RulerCornerPainter` gain `@visibleForTesting TextSpan? get debugLastLabel`,
  the "painter's `TextPainter`" route of M-DT-6. A `SpyCanvas` sees only
  an opaque `Paragraph`. It follows the existing `debugLastTicks` /
  `debugLastSymbol` seams.
- **R-C6-2 — M-DT-17 is its own test** (`4f324f9`). The M-DT-9 shell has
  no symbol loader, and existing tests change only mechanically, so the
  live-switch assertions on the symbol cells and the page swatch borders
  live in `widget_theme_test.dart`, not in M-DT-9's test.
- **R-C6-3 — D9a's patterns take `Color.from(` and `CupertinoColors.`**
  (after the plan; a review of `4f324f9`). R-4 asked for `Color.from*`, but
  `\bColor\.from(ARGB|RGBO)\(` misses Flutter's component constructor
  `Color.from(alpha: ..., red: ...)`, and `\bColors\.` finds no word
  boundary inside `CupertinoColors.`. The patterns are now
  `\bColor\.from(ARGB|RGBO)?\(` and `\b(Cupertino)?Colors\.(?!transparent\b)`;
  neither spelling occurs in the scanned roots, so the allow-list is
  unchanged. The scan's own mutant test adds both.
- **Not amendments.** R-C1-1 (the old colour constants kept as literals
  for Tasks 1-2, pinned to `.light` by a transitional test) changed only
  the plan's interim step: Task 3 (`31b5a43`) removed the constants and
  that test, as D5 says. R-C5-2 (`fillColor:` equivalent under Material 3
  defaults) leaves D6b as written.

## Revision log

Revision 2 applies the independent review of revision 1 (`aceed65`),
"Ready with fixes":

| Finding | Severity | Change |
|---|---|---|
| R-1 | blocking | F-5 names `paintWorldOverlay`; D5 adds `paper` to both tool paint methods; `PlacementTool` sets `bandPaint` there |
| R-2 | blocking | F-10 corrected (one view at a time); M-DT-11 uses a two-view harness |
| R-3 | blocking | D9b scoped to custom schemes; M-DT-15 overrides `primaryContainer`; F-18 |
| R-4 | blocking | D9a matches `\bColor\(0[xX]` (not `TrueColor`), plus `Color.from*` |
| R-5 | blocking | D7 and invariant 2 scoped to the canvas; D6a/D6b declared light-theme changes; D6c maps ink to `0xFF202020` / `0xFFFFFFFF`, with the `0xRRGGBB` trap stated |
| R-6 | blocking | D6c's `_paper` notifier joins the status painter's repaint and rebuild; F-16 |
| R-7 | should-fix | D4 says where: `_surfaceArgb` in `didChangeDependencies`, one `_paperArgb()` |
| R-8 | should-fix | F-3 and D5 cover the ruler label `TextStyle`; M-DT-6 asserts it |
| R-9 | should-fix | M-DT-9 rewritten (zero animation, ruler and edge, overlay on the paper flip); D9d wording |
| R-10 | should-fix | M-DT-7 asserts `Paint.color` through a recording canvas |
| R-11 | should-fix | M-DT-13 flips the paper on one painter instance and counts one allocation |
| R-12 | should-fix | M-DT-8 adds `SelectTool` |
| R-13 | should-fix | Files lists the tests that change; painter palettes are required parameters |
| R-14 | should-fix | D5 and invariant 1 cite the Paint-identity tests (F-17) |
| R-15 | nit | M-DT-20 names `rulerInk` and `rulerPointer` |
| R-16 | nit | Risks: a paper near the switch |
| R-17 | nit | Not in scope: black walls with no page in a dark theme |
| R-18 | nit | Invariant 4 reworded |
| R-19 | nit | D9a's scan covers both apps, allow-listed by exact literal |
| R-20 | nit | D1 states the snap at t = 0.5 of a theme animation |
