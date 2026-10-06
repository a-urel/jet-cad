# Plan — dark theme

**Spec:** [2026-10-04-dark-theme-design.md](../specs/2026-10-04-dark-theme-design.md),
revision 2 (D1–D9, F-1..F-18, M-DT-1..M-DT-20; review R-1..R-20 applied).
Approved by the human ("Onaylıyorum", 2026-10-04), including the two
deliberate light-theme changes D6a and D6b.
**Branch:** `claude/dreamy-gates-2kgh4o` (spec at `cac5b7a`, code facts at
`5ba6fb2`).

## Global constraints

- **Rules.** The `CLAUDE.md` non-negotiables apply. The engine
  (`jet_cad_2d`) is **not edited**. There is no schema change, and the
  theme is never saved.
- **Unedited tests.** These pass without edits:
  - both allocation invariants;
  - the Paint-identity tests (`selection_overlay_test.dart:317-345`);
  - the goldens.
- **Light theme on light paper.** The canvas is pixel-identical to today
  (spec invariant 2). An existing test changes only mechanically: it
  passes `ChromePalette.light` / `PaperPalette.light` or the new
  `paper` argument. Its expectations never change. D6a and D6b are the
  only deliberate light-theme changes, and their tests are new.
- **No global mutable palette state** (spec invariant 4).
- **Every task ends green.** Run the render, planner, restaurant symbols,
  app and demo gates (`flutter test`, `flutter analyze`,
  `dart format --output=none --set-exit-if-changed .`). The standing
  failures are as before: render has the 7 text-ladder failures and
  1 skip, engine has 2.
- **Named mutants.** Each task kills its named mutants by a scratch edit,
  reverted, and records the red command in the ledger
  (`.superpowers/sdd/2026-10-04-dark-theme/`). A mutant that survives
  blocks the task.

## Tasks

### Task 1 — the palettes (D2, D3, D6c constants)

- **New file.** `jet_cad_2d_flutter/lib/src/canvas_palette.dart`, exported
  from the barrel. It holds:
  - `ChromePalette` with `light` / `dark` and `of(Brightness)`;
  - `PaperPalette` with `light` / `dark` and `forPaper(int argb)`, which
    keys on `foregroundFor(argb & 0xFFFFFF)`;
  - `kStatusCaptionOnLight` / `kStatusCaptionOnDark`.

  Both classes are immutable and compare by value.
- **Old constants.** The colour constants stay in `chrome_style.dart` and
  `selection_style.dart` for now, as aliases of the `.light` fields, so
  nothing else changes yet. Task 3 removes them.
- **Tests.** `test/canvas_palette_test.dart`, killing:
  - **M-DT-3:** swatches plus `0x757575` / `0x767676`, against
    `foregroundFor`;
  - **M-DT-19:** the `.light` fields equal the F-2 literals, field by
    field;
  - **M-DT-20:** the contrast table;
  - value equality.

### Task 2 — the painters (D5 painters, R-8, R-13, R-14)

- **The four painters and `RulerFrame`.** `PageChromePainter`,
  `RulerPainter`, `RulerCornerPainter` and `SelectionOverlayPainter` take
  their palettes as **required** parameters, and so does `RulerFrame`.
  - Paint colours are assigned from the palette in `paint`.
  - The ruler label `TextStyle` is a `late final` built from
    `chrome.rulerInk`.
  - `shouldRepaint` compares the palettes.
- **Temporary wiring.** `PlannerView` passes `ChromePalette.light` /
  `PaperPalette.light` for now, marked `// Task 4` and removed there.
- **Mechanical test updates.** The painter and frame constructions in the
  test files listed under spec "Files" are updated.
- **Tests.** Render package tests on Blueprint and in dark chrome,
  killing:
  - **M-DT-4:** grid lighter than the bare paper on Blueprint, darker on
    White;
  - **M-DT-5:** page breaks;
  - **M-DT-6:** bar, corner, ticks and the label `TextSpan` colour;
  - **M-DT-7:** the edge `Paint.color` via the recording canvas;
  - a `shouldRepaint` unit test per painter (palette differs → true, same
    → false).

### Task 3 — the tool paint methods (D5 tools, R-1, R-12)

- **Signatures.** `Tool.paintWorldOverlay` and `Tool.paintOverlay` each
  gain `PaperPalette paper`. `SelectionOverlayPainter` passes its own
  palette to both.
- **Render tools.**
  - `SelectTool`: the bands, guide, snap marker and reshape preview.
  - `PlacementTool`: `bandPaint.color` is set in `paintWorldOverlay`,
    and the marker in `paintOverlay`. The eleven subclasses stay
    untouched.
- **Planner tools.** `SymbolPlaceTool` (the ghost in
  `paintWorldOverlay`, the marker), `DimensionTool` (attach rings),
  `RoomTool` and `TableSelectTool` move to the new signatures.
- **Old constants removed.** The colour constants leave
  `chrome_style.dart` and `selection_style.dart`; every remaining use
  reads a palette.
- **Mechanical test updates.** The Tool subclasses and the direct calls
  in tests are updated (spec "Files").
- **Tests.** On Blueprint, one assertion per tool family, killing:
  - **M-DT-8:** the line tool's band; `SelectTool`'s window band,
    crossing band, guide and reshape preview; `SymbolPlaceTool`'s ghost
    and marker; `DimensionTool`'s attach ring.

### Task 4 — the planner wiring (D1, D4, D5 `PlannerView`, R-7, R-20)

- **`PlannerView`.** It takes required `chrome` and `paper`, and Task 2's
  temporary `.light` is removed.
- **`PlannerShell` and `ServiceView`.**
  - `_surfaceArgb` is set in `didChangeDependencies`.
  - One `_paperArgb()` feeds both the resolver and
    `PaperPalette.forPaper`.
  - The resolver becomes a `late` assigned in the first
    `didChangeDependencies`, re-derived there and in `_onPage`, and is
    replaced only on a foreground flip.
  - `ChromePalette.of(Theme.of(context).brightness)` is computed in
    `build`.
  - The comment at `planner_shell.dart:175-177` is rewritten.
- **Apps.** `apps/floor_planner` and `apps/restaurant_demo` gain a
  `darkTheme` (same seed, dark) and `themeMode: ThemeMode.system`.
- **Tests.** In the planner package, theme switches at zero animation,
  killing:
  - **M-DT-1** and **M-DT-2:** both theme × paper crossings;
  - **M-DT-9:** the theme flip on the ruler and sheet edge; the paper
    flip on the selection outline;
  - **M-DT-10:** no page in the dark theme, so the ink is light and the
    overlays are the dark set;
  - **M-DT-11:** two `FloorPlanView`s side by side, White and Blueprint.

### Task 5 — the canvas UI fixes (D6, R-5, R-6)

- **D6a.** The page swatch border uses `scheme.primary` / `scheme.outline`.
- **D6b.** The text entry gets `filled: true` and
  `fillColor: scheme.surfaceContainerHighest`.
- **D6c, the status caption.**
  - `ServiceView` adds a `_paper` `ValueNotifier<int>`, set in
    `didChangeDependencies` and `_onPage`.
  - `TableStatusPainter(paper:)` joins `_paper` to the repaint merge and
    to the rebuild condition.
  - The ink is `foregroundFor(over(status, paper))`, mapped to the two
    caption constants.
  - The cache key is `(caption, colour, ink)`.
- **Tests,** killing:
  - **D6a:** the selected swatch border is `scheme.primary` in both
    themes; a new test;
  - **M-DT-12:** the text entry fill pixel;
  - **M-DT-13:** the same-instance paper flip with exactly one new
    paragraph; ten steady frames; a page-less `ServiceView` theme flip.

### Task 6 — the widgets (D9, R-3, R-4, R-19)

- **D9b.** `SymbolGallery` takes `selectedForeground`. `SymbolPanel`
  computes it from `primaryContainer`, and a cell asks for its thumbnail
  with the foreground that matches its state.
- **D9a, the source scan.** `jet_cad_floor_plan/test/invariants/theme_colours_test.dart`
  scans both packages' `lib/` and both apps' `lib/`.
  - It uses the spec's three patterns.
  - It allow-lists `canvas_palette.dart` as a whole file, plus the (file,
    exact literal) pairs.
- **D9d.** Audit for theme colours cached in `initState` or a
  `late final`, and fix any.
- **Tests,** killing:
  - **M-DT-14:** the scratch literal in `symbol_panel.dart`;
  - **M-DT-15:** the `primaryContainer` override fixture;
  - **M-DT-16:** unselected leaves are light in the dark theme, dark in
    the light-theme control;
  - **M-DT-17:** after a live switch, the symbol cell colour and the page
    swatch border follow the dark scheme;
  - **M-DT-18:** the layer swatch outline;
  - the dark-theme panel sweep (smoke).

### Task 7 — the exit

- **Gates.** Every gate passes; both apps run `flutter test` and
  `flutter analyze`; `flutter build web --release` succeeds for
  `apps/floor_planner` and `apps/restaurant_demo`.
- **Chromium smoke of both web builds.** Use a dark
  `prefers-color-scheme` through Playwright's `colorScheme: 'dark'`. Take
  a screenshot of each of these:
  - the planner on White and on Blueprint;
  - the symbol list;
  - the service view with statuses.

  The screenshots are evidence for the human's look, not a substitute.
- **Results note.** `docs/superpowers/notes/2026-10-04-dark-theme-results.md`
  records:
  - the gate counts;
  - M-DT-1..20, each with its killing command;
  - the extras;
  - the debt: the light preview's 2.20:1 contrast, ink off the sheet, and
    a paper near the switch.
- **STATUS.md.** Updated.
- **Owed.** The human's look, on macOS and web in both themes, per spec
  exit gate 5. Never simulated.
