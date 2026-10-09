# Plan — host embedding API, Slice 3: the look (`FloorPlanTheme`)

**Spec:** [2026-10-09-host-embedding-api-design.md](../specs/2026-10-09-host-embedding-api-design.md),
revision 3 (`4f5c8fc`) as amended during Slices 1 and 2 (last at
`e6a1d06`): the principles P-1 to P-9 (above all **P-6**, *defaults are
today's look*, and P-4's *style values are read when a painter rebuilds,
never per frame*), the facts F-4, F-9, F-10, **Slice 3** (T-1 to T-4), the
Invariants (2, 4 and 7 above all), the named mutants M-H30 to M-H33 with
every sub-mutant inside M-H33, the Risks. The points this plan found the
code to contradict, or to leave open, are under
[Spec points to settle](#spec-points-to-settle); none changes the design
silently.

**Started** on the human's *"tamam, Dilim 3 ile devam et"* (2026-10-09),
after Slice 2 merged into `main` at `fe93d23`. Slice 3 is the look: a
`ThemeExtension` a host puts in its `ThemeData`, a view parameter that
overrides it field by field, read at paint rate correctly.

**Branch:** `claude/exciting-pasteur-9m22jv`, from `main` at `8fd7483`
(`fe93d23` plus its docs commit), plus this plan's commit.

**Ledger:** `.superpowers/sdd/2026-10-09-host-embedding-api/`: this
slice's briefs, reports and reviews as `s3-task-<n>-report.md` /
`s3-task-<n>-review.md`, beside Slices 1 and 2's archived ones.

**No schema change.** Nothing of Slice 3 is stored: plans, service layouts,
the codec and the bundled encodings are untouched; the theme never reaches
`designJson`, the service layout, an export or a print (P-5, invariant 4).

## Global constraints

- `CLAUDE.md`'s non-negotiables. **The two allocation invariants**
  (`query_allocation_test`, `paint_allocation_test`), the floor-plan
  painters' counter tests (`table_status_painter_test` SP1,
  `table_group_painter_test` TG-L9, `table_focus_painter_test` FP3),
  `RenderFloorPlanOverlays`' counter tests (`table_overlay_test` TO2,
  TO10, TO21), the pick's allocation test (`invariants/pick_allocation_test`
  PA1–PA3) **and every image golden stay untouched** (invariant 7); Task 3
  adds their themed siblings beside them, never edits them. The engine
  (`jet_cad_2d`) is **not edited** in Slice 3; `jet_cad_2d_flutter` is
  edited **only** in Task 2 (`PaperPalette.withSelection`,
  `SelectionOverlayPainter.selectionStrokePixels`).
- **P-1 and P-6:** no existing signature, `==`, `hashCode` or `toString`
  changes; every new parameter is named and optional with today's
  behaviour as its default. **With no theme anywhere, every code path is
  today's, structurally**: the resolved theme is `null`, `PaperPalette`
  is the identical `const` instance `forPaper` returns, the painters build
  today's `Paint`s and paragraphs with today's constructors. **Existing
  tests pass unedited**, with these named exceptions and nothing else:
  - **Task 1:** `test/host/barrel_test.dart`'s B1 (`:29`) gains
    `FloorPlanTheme`, as Slices 1 and 2's tasks did.
  - **Task 4:** `test/invariants/theme_colours_test.dart`'s
    `kAllowedFiles` (`:36-38`) gains the demo's theme file
    (`../../apps/restaurant_demo/lib/demo_theme.dart`), a whole-file
    entry as `canvas_palette.dart` is: the demo's hand-built shadcn-like
    `ColorScheme` is literal colours by nature (F-4's recipe), and the
    scan (`:17-22`) reads the demo's `lib`.

  Any other test that has to change is a finding for the task's report.
  The tests that read today's look, and must therefore pass unedited, are
  named in each task.
- **No widened record, no required parameter.** The theme travels by an
  internal inherited scope (Task 1), not through `ServiceCallbacks`,
  `ServiceOptions` or `ServiceEvents`. Every new parameter of an internal
  widget or painter is **optional**, because tests build them directly:
  `PlannerShell` about thirty planner and floor-planner test files (and
  `apps/floor_planner/lib/document_host.dart:684`), `PlannerView`,
  `SelectionOverlayPainter` nine render test sites, and the three
  selection-mode painters their own test files
  (`grep -rln "PlannerShell(\|PlannerView(\|TableStatusPainter(\|TableGroupPainter(\|TableFocusPainter(" packages apps`).
- **The standing sets stay exactly as they are:** engine 2, render 7 plus
  1 skip (`tool/ci/standing_failures.txt`, `standing_skips.txt`), compared
  by the path form, as CI does (`.github/workflows/ci.yml:69-73`):
  `dart run tool/ci/expect_failures.dart --package packages/<pkg> --root packages/<pkg> <run.json>`,
  the run from `test --file-reporter json:<run.json>`. **The planner runs
  as CI runs it**, `flutter test --enable-vmservice` (`ci.yml:43-49, 68`),
  so the pick's allocation test runs; a plain `flutter test` there shows
  its three skips, which the comparison reads as red.
- **Every task ends green** in every package it touches and every package
  whose tests read what it changed:
  - `packages/jet_cad_floor_plan` (with `--enable-vmservice`, through the
    standing comparison), `apps/restaurant_demo`, `apps/floor_planner`:
    `flutter test`, `flutter analyze`, format;
  - `packages/jet_cad_2d_flutter` (`flutter test` through the standing
    comparison, `flutter analyze`, format) and `packages/jet_cad_2d_gpu`
    (`flutter test` through the standing comparison, analyze) in Task 2;
  - `packages/jet_cad_2d` through the standing comparison at the exit;
  - `tool/ci`: `dart test`, analyze, format and `check_guide` whenever the
    guide or the probe moves (Task 4).
- **Flutter** is `/root/sdk/flutter/bin` (3.47.6, not on `PATH`), run with
  `CI=true`.
- **Fixtures** (spec's testing rule; CLAUDE.md's testing bar):
  - the planner's look fixture `test/support/palette_fixture.dart`: the
    real seed's light and dark themes at zero animation, **a page or
    none** (the page-less plan), White and Blueprint papers, an
    off-origin, y-up camera at 0.125 px/mm that puts lines on pixel
    centres; the dark theme over White is the dark canvas (K1), a third
    paper;
  - Slice 1's `test/host/embedding_fixture.dart` (turned, mirrored,
    non-uniformly scaled tables 40 m off the origin, the off-base box, a
    hidden and a locked layer, two `7`s, an unnumbered table,
    `embeddingCamera()` at 0.37 px/mm, panned) and the zone fixture
    (`test/host/zone_fixture.dart`) for the veil; the group painter
    tests' `{12, 3, 7}` placed out of handle order, one mirrored;
  - **themes that are not the default shape:** colours none of which
    equals a palette colour or another theme colour (e.g. selection on
    light `0xFFD81B60`, on dark `0xFFFFD54F`, frame `0xFF00897B`, chip
    `0xFF3949AB`, veil `0xFF6D4C41`, canvas `0xFF263238`); widths and
    sizes that are not today's (selection 4 px, frame 3 px, margin 300
    mm, chip radius 8, **asymmetric** chip padding `EdgeInsets.fromLTRB(7,
    3, 9, 4)`, bar 60 px, caption 14 px bold, chip text 13 px); opacities
    that are not 0, 1 or 0.6 (fill 0.5, veil 0.35);
  - **for resolution, exactly one field set in the ambient theme and a
    different one in the view's** (M-H30), and separately one field set
    in both (precedence);
  - **status fills:** the demo's translucent Bill `0x99E53935`, a dark
    opaque fill `0xFF1B1B1B`, a light one `0xFFFFE082`;
  - **papers:** White, Blueprint (dark), the dark canvas, and a page-less
    plan on a dark `canvasBackground` under the **light** theme, so the
    paper and the theme disagree;
  - every camera off identity. Expected colours are computed by the test
    (straight alpha over the paper, `zone_fixture.dart:223`'s form, with
    the theme's opacity), never read from the code under test.
- **Each named mutant is applied, seen red and reverted**, its killer
  named in the report (Ruling 49/50). Every Slice 3 mutant below belongs
  to exactly one task; the task-local mutants (T*n*-x) are this plan's
  own, listed so a review can hold the killers to them.
- **Never `git checkout` a file to revert it.** Copy it aside, or use
  `git show HEAD:path > path`.
- **Never commit an `analysis_options.yaml`.** Check `git status` before
  each commit.
- New public names enter `lib/jet_cad_floor_plan.dart`'s `show` lists and
  `test/host/barrel_test.dart` in the task that adds them; P-9's prefix
  and `final class` with `==`/`hashCode`/`toString`. Slice 3 adds one
  host name, `FloorPlanTheme`, and one view parameter, `theme`; the
  scope that carries the resolved theme stays internal. No colour literal
  enters a scanned `lib` (`theme_colours_test`) but the demo's theme file
  (Task 4): the theme's defaults are `null`, and derived colours are
  `withValues` of existing ones.

## Tasks

### Task 1 — `FloorPlanTheme` and its resolution (T-1's type, T-2)

**Verified:**
- `ThemeExtension<T>` (Flutter 3.47.6, `material/theme_data.dart`)
  declares `type`, `copyWith()` and `lerp(covariant ThemeExtension<T>?
  other, double t)`; `ThemeData.lerp` lerps extensions by type
  (`_lerpThemeExtensions`, `:1794-1812`): an extension only in the first
  theme is lerped **with null**, one only in the second is taken as it
  is. `MaterialApp` animates a theme switch (200 ms), so `lerp` runs.
- **`FloorPlanView` reads no theme today** (`host/floor_plan_view.dart:243-247`
  reads only `FloorPlanStrings`; `build`, `:323-386`, reads none). Its
  overlay layers are made once per host build (`:331-334`), so a theme
  switch today rebuilds no host overlay (G-5: every overlay is rebuilt
  only when the host rebuilds the view). Reading `Theme.of` in
  `FloorPlanView.build` would make every theme switch rebuild every
  overlay: the resolution must sit below it.
- Both modes read the theme already: `ServiceView` in
  `didChangeDependencies` (`host/service_view.dart:359-368`) and `build`
  (`:403-404`); `PlannerShell` in `didChangeDependencies`
  (`planner_shell.dart:267-276`) and `build` (`:878-879`). A
  `didChangeDependencies` is always followed by a `build`.
- `PlannerShell` also runs with **no** `FloorPlanView` above it: the floor
  planner app (`apps/floor_planner/lib/document_host.dart:684`) and about
  thirty test files build it bare.
- The precedent for a view parameter checked at build is
  `validateOverlayLayout` (`host/table_overlay.dart:194-206`), called from
  `FloorPlanView.build` (`floor_plan_view.dart:325-327`): an
  `ArgumentError` naming the field.
- The export dialog is `showDialog` from the caller's context
  (`export/export_dialog.dart:43-46`; called through
  `flows.export(context)` at `service_view.dart:416, 453` and
  `floor_plan_view.dart:302`), and `showDialog` **captures the caller's
  inherited themes** (`material/dialog.dart:1640-1643`): a local Material
  `Theme` around the view reaches the dialog; a plain `InheritedWidget`
  does not (see S-12).
- The barrel (`lib/jet_cad_floor_plan.dart:9-56`) and B1
  (`test/host/barrel_test.dart:29`).

**Builds:**
- `lib/src/host/floor_plan_theme.dart`:
  `final class FloorPlanTheme extends ThemeExtension<FloorPlanTheme>`,
  a `const` constructor, **sixteen nullable fields** (null: today's
  value), typed as [S-5](#spec-points-to-settle) recommends:
  `statusCaptionStyle` (`TextStyle?`), `statusFillOpacity` (`double?`);
  `groupFrameColor` (`Color?`), `groupFrameWidth` (`double?`, screen px),
  `groupFrameMargin` (`double?`, world mm), `groupChipColor` (`Color?`),
  `groupChipTextStyle` (`TextStyle?`), `groupChipRadius` (`double?`,
  px), `groupChipPadding` (`EdgeInsets?`, px); `selectionOnLight`,
  `selectionOnDark` (`Color?`), `selectionWidth` (`double?`, px);
  `focusVeilColor` (`Color?`), `focusVeilOpacity` (`double?`);
  `canvasBackground` (`Color?`); `serviceBarHeight` (`double?`, px). Each
  documented with its unit, what null means and the mode it reaches
  (T-1's table).
  - `copyWith` (each field; a null argument keeps the field, Flutter's
    convention); `merge(FloorPlanTheme? other)`: `other`'s set fields win,
    field by field, a null `other` returns `this`; the two `TextStyle`
    fields merge by `TextStyle.merge` (S-3); `lerp`: both set → `Color.lerp`,
    `lerpDouble`, `TextStyle.lerp`, `EdgeInsets.lerp`; one side null → the
    `t < 0.5` side (S-4); a null or foreign `other` → `this`.
  - `==` and `hashCode` over all sixteen (`Object.hashAll`); `toString`
    names the set fields only (`FloorPlanTheme(selectionWidth: 4.0)`;
    `FloorPlanTheme()` for none).
- `validateFloorPlanTheme(FloorPlanTheme)` (internal): S-5's ranges, an
  `ArgumentError.value` naming the field; the constructor stays `const`
  and never throws.
- **The scope** (internal, same file): `FloorPlanThemeScope`, a
  `StatelessWidget` (`view`, `child`) whose `build` reads
  `Theme.of(context).extension<FloorPlanTheme>()` (the ambient), resolves
  `ambient == null ? view : ambient.merge(view)` (T-2: field by field,
  then the defaults, which are each painter's today), validates it, and
  provides it through an internal `InheritedWidget` whose
  `updateShouldNotify` is `theme != old.theme` (T-3: compared by `==` at
  build). `FloorPlanThemeScope.of(BuildContext)` depends on it and returns
  the resolved theme, or, with no scope above (a bare `PlannerShell`), the
  ambient extension. A plain `InheritedWidget`, not an `InheritedTheme`:
  the view's override reaches no route (S-12).
- `FloorPlanView`: `final FloorPlanTheme? theme`, documented with T-2's
  sentences (null: the ambient extension alone; the export dialog follows
  the ambient Material theme where the view is). `build` wraps its
  `ListenableBuilder` in `FloorPlanThemeScope(view: widget.theme, …)`,
  always (never only when a theme is given: a toggle would remount both
  modes). On an ambient switch only the scope rebuilds; it hands the
  inherited widget the same child, so the `ListenableBuilder`, the mode's
  view and the overlay layers are not rebuilt by it.
- `ServiceView`: `final ValueNotifier<FloorPlanTheme?> _theme`, set from
  `FloorPlanThemeScope.of(context)` in `didChangeDependencies` (a
  `ValueNotifier` notifies only on `!=`), disposed with the rest; Tasks 2
  and 3 read it. `PlannerShell`: a `FloorPlanTheme? _floorTheme` field set
  in `didChangeDependencies`, read by Task 2. Nothing is drawn from them
  in this task.
- Barrel: `export 'src/host/floor_plan_theme.dart' show FloorPlanTheme;`;
  B1 gains `FloorPlanTheme`.

**Tests** (`test/host/floor_plan_theme_test.dart`; the scope's value read
in tests as `FloorPlanThemeScope.of` from an element under each mode's
view, through `package:jet_cad_floor_plan/src/host/floor_plan_theme.dart`):
**M-H30**, **T1-a**, **T1-b**, **T1-c** (below). Plain:
- `merge`: for each of the sixteen fields, a view setting only it over an
  ambient setting all sixteen to other values → that field the view's,
  the fifteen others the ambient's; a null view → `identical` to the
  ambient; `TextStyle` fields merge property by property (S-3).
- `lerp` at 0, 0.25, 0.5 and 1 between two full themes (each field
  `closeTo` the per-type lerp), one side null switches at 0.5 (S-4),
  `lerp(null, t)` is `this`; through `ThemeData.lerp` of a light
  `ThemeData` with the extension and a dark one without, the result
  carries the first's extension unchanged.
- `copyWith`, `==`, `hashCode` and `toString`: each field changed alone
  makes `!=` and (with these values) a different hash.
- Validation (S-5), each through the view with `tester.takeException()`:
  opacities 0 and 1 accepted, -0.01, 1.01 and NaN refused; widths and the
  bar height 0 and infinity refused, 0.5 accepted; margin, radius and
  padding 0 accepted, -1 refused; a style's `fontSize` 0 refused. An
  ambient theme out of range is refused the same way.
- **No theme anywhere** → `null` in both modes (P-6, structurally); ambient
  only → `identical` to it; view only → `identical` to it.
- An ambient switch (light `ThemeData` carrying theme A → dark carrying
  B, zero animation) reaches both modes after one pump; the scope's
  `updateShouldNotify` is false for an equal, non-identical theme and
  true for a different one (T1-c; Task 3 reads the same through the
  painters' rebuild counters).
- **A theme change rebuilds no overlay:** with a `tableOverlayBuilder`
  counting calls in the selection mode, an ambient switch and a scope-only
  change (the host's `Theme` around an unchanged `FloorPlanView`) call the
  builder 0 times (G-5, H-8).
- The export dialog opened from the service bar under a local `Theme`
  (a hand-built `ColorScheme`) reads that `ColorScheme`; the view's
  `theme:` is not an `InheritedTheme` (S-12).
- `FloorPlanTheme` through the barrel alone, in
  `ThemeData(extensions: [...])` and `FloorPlanView(theme: …)`.

**Unedited and green (P-6):** `test/host/view_test.dart`,
`test/host/table_overlay_test.dart` (TO1–TO33), `test/host/controller_test.dart`,
`test/planner_shell_test.dart`, `test/widget_theme_test.dart`,
`test/host/barrel_test.dart` but B1's one name.

**Gates:** planner (`--enable-vmservice`, standing comparison, analyze,
format), demo, floor planner.

### Task 2 — the selection colours, their width and the canvas (T-1's selection and canvas rows; `jet_cad_2d_flutter`)

**Verified:**
- `PaperPalette` (`jet_cad_2d_flutter` `lib/src/canvas_palette.dart:76-202`)
  is a public value class with a `const` constructor of twelve colours
  and `==` by value (`:171-185`). `hover` is the selection's hue at 60 %
  alpha (`:105-107`): `0xFF1E6FE8` / `0x991E6FE8` (`:135-136`),
  `0xFF7FB2FF` / `0x997FB2FF` (`:151-152`); `0x99 / 0xFF` is exactly 0.6.
  `forPaper` (`:168-169`) returns one of the two `const` instances, keyed
  on `foregroundFor` of the paper.
- Only `SelectionOverlayPainter` reads `selection` and `hover`
  (`grep -rn "paper\.selection\|paper\.hover" packages/*/lib`). It assigns
  every colour from `paper` per frame, as field writes on its own `Paint`s
  (`selection_overlay.dart:125-131`); `kSelectionStrokePixels`
  (`selection_style.dart:9`) is read for the outline (`:145`), the
  selected point cross's stroke and half-length (`:190`, `:193`) and the
  preview cross's half-length (`:206`); the hover's 1.5 px at `:146`,
  `:191`, `:196`. `shouldRepaint` is the palette's `!=` (`:327-329`).
  Both are exported (`lib/jet_cad_2d_flutter.dart:7, 62-63`).
- `PlannerView` (exported to editor code by `lib/editor.dart:50`) hands
  `paper` to `PageChromePainter` and the overlay (`planner_view.dart:392-400`,
  `:418-425`). Both modes build the palette in `build`:
  `PaperPalette.forPaper(_paperArgb())` at `planner_shell.dart:1000` and
  `service_view.dart:484`.
- **The canvas.** `displayPaperFor` (`dark_canvas.dart:26-32`) is the dark
  canvas paper, else the page's background, else `surface`. Both modes
  pass `_surfaceArgb = scheme.surface` (`planner_shell.dart:271`,
  `service_view.dart:363`), and paint the surround with a
  `ColoredBox(color: scheme.surface)` (`planner_shell.dart:985-986`,
  `service_view.dart:464-465`); `PageChromePainter` fills only the sheet
  (`page_chrome_painter.dart:98-104`). In `ServiceView` the same paper
  feeds the `_paper` notifier of the three painters (`:242`, `:352-357`,
  `:365`). So `canvasBackground` in place of `scheme.surface` at those
  four places reaches the surround, a page-less plan's paper, ACI 7's
  ink, the paper's palette, the status captions and the veil; the render
  package's `displayPaperFor` needs no change.
- The page export fills an opaque white page whatever the paper
  (`jet_cad_2d_flutter` `export/page_export.dart:22, 90, 121`).
- **`paint_allocation_test` does not paint the selection overlay**
  (`test/invariants/paint_allocation_test.dart:135-262` measures
  `DraftPainter`'s vertices sink only); the overlay's frame objects are
  pinned by `selection_overlay_test.dart:320` ("the two Paints are reused
  across frames"). See [S-1](#spec-points-to-settle).
- `jet_cad_2d_gpu` and the dev harness import neither class
  (`grep -rln PaperPalette packages/jet_cad_2d_gpu/lib apps/dev_harness_2d/lib`:
  none).

**Builds:**
- `jet_cad_2d_flutter`:
  - `PaperPalette withSelection(Color selection)`: a copy with `selection`
    and `hover` (the selection at `selection.a * 0x99 / 0xFF`), the ten
    other colours kept; documented beside `hover`.
  - `SelectionOverlayPainter({…, this.selectionStrokePixels =
    kSelectionStrokePixels})`: every read of `kSelectionStrokePixels` in
    the painter reads it (S-8); the hover's width stays
    `kHoverStrokePixels`; `shouldRepaint` is true also when it differs;
    asserted finite and above 0.
- The planner:
  - `PlannerView({…, this.selectionStrokePixels = kSelectionStrokePixels})`,
    passed to the overlay.
  - One internal function, `paperPaletteFor(int paperArgb, FloorPlanTheme?
    theme)`: the set `forPaper` picks; with that set's theme colour
    (`selectionOnDark` for the dark set, `selectionOnLight` for the
    light) non-null, `.withSelection(colour)`; otherwise the `const`
    instance itself. Both modes call it where they call `forPaper` today,
    and pass `theme?.selectionWidth ?? kSelectionStrokePixels`.
  - `canvasBackground`: both modes take `_surfaceArgb` from
    `(theme?.canvasBackground ?? scheme.surface)` in
    `didChangeDependencies` and paint the surround's `ColoredBox` with the
    same colour, so the resolver key, the palette and (in the selection
    mode) `_paper` follow it as they follow `scheme.surface` today.

**Tests** (render: `test/selection_theme_test.dart`; planner:
`test/host/theme_canvas_test.dart`, on `palette_fixture.dart` through
`FloorPlanView` in both modes, and on a bare `PlannerShell` for the
ambient-only path): **M-H33(canvasBackground)**,
**M-H33(the editor's selection)**, **T2-a** to **T2-d** (below). Plain
(render): `PaperPalette.light.withSelection(PaperPalette.light.selection)
== PaperPalette.light`, and the same for `dark` (the derivation **is**
today's hover, exactly); a translucent selection `0x80D81B60` gives a
hover of alpha `0x80 * 0.6`; the ten other colours unchanged; at
`selectionStrokePixels: 4` under the rotated, non-uniform camera of
`selection_overlay_test.dart:413`, the recorded outline `Paint` strokes
`4 / scale`, a selected point's cross is 12 px half-length at 4 px, the
hover stays 1.5 px; `shouldRepaint` true for a width alone, false for an
equal palette and width; across frames under a themed palette and width
the same `Paint` objects reach the canvas (the themed sibling of `:320`,
S-1). Plain (planner): `selectionOnDark` on Blueprint under the light
theme and on the dark canvas (dark theme, White page) in both modes; a
theme with **only** `selectionOnLight` leaves Blueprint's selection the
dark set's `0xFF7FB2FF` (per paper, T-1); `selectionWidth: 4` covers the
pixel rows a 2 px stroke does not, in both modes; with a page, a
`canvasBackground` colours the surround only (the sheet's fill, ink and
selection are the page's); the theme reaches neither `designJson()` nor
the PNG export (bytes equal with and without a full theme, both modes;
invariant 4).

**Unedited and green (P-6):** render `test/painter_palette_test.dart`
(its `SelectionOverlayPainter` group, `:554-630`),
`test/selection_overlay_test.dart` (`:299` "stroke width is 2 px at any
zoom", `:320`, `:592` "shouldRepaint is false"),
`test/selection_overlay_grips_test.dart`, `test/tool_palette_test.dart`,
`test/dark_canvas_test.dart`, `test/golden/*`,
`test/invariants/paint_allocation_test.dart`; planner
`test/planner_palette_test.dart`, `test/dark_canvas_test.dart`,
`test/host/view_palette_test.dart`, `test/canvas_ui_test.dart`,
`test/widget_theme_test.dart`, `test/host/status_caption_test.dart`;
`apps/floor_planner`'s tests.

**Gates:** **`jet_cad_2d_flutter` in full** (`flutter test` through the
standing comparison, `flutter analyze`, format); `jet_cad_2d_gpu`
(`flutter test` through the standing comparison, analyze); planner
(`--enable-vmservice`, standing comparison, analyze, format); demo; floor
planner.

### Task 3 — the selection mode's painters and bar (T-1's status, groups, focus and chrome rows; T-3; T-4)

**Verified:**
- The three painters are `late final` in `ServiceView`, built once per
  service copy (`service_view.dart:251-300`), each with the paper as a
  `ValueListenable<int>` in its repaint merge (`:258-265`, `:272-273`,
  `:298-299`) and its own rebuild key: status `:276-295` of
  `service/table_status_painter.dart` (paper at `:287`), groups `:405-422`
  of `table_group_painter.dart` (`:415`), the veil's recolour key
  `table_focus_painter.dart:137-142` (a paper change recolours, rebuilds
  nothing). A new painter is never made for a theme change; only the key
  and the merge can carry it (T-3).
- **Status** (`table_status_painter.dart`): one `Paint` per colour,
  cached by its ARGB (`:191-196`); the caption's ink is
  `statusCaptionInk(status.color, paper)` (`:67-70`, `:206-208`), the
  colour over the paper (D6c); the paragraph is built at 11 px with **no
  font family** (`:39`, `:265-272`) and cached by (caption, colour, ink)
  (`:128`, `:262-263`), dropped when no fill holds it (`:220-225`); the
  caption sits at least `kStatusCaptionSize` below the anchor
  (`:334-335`).
- **Groups** (`table_group_painter.dart`): margin 150 mm, 2 px, chip
  padding 5 / 2 and radius 4 (`:21-30`); frame and chip in the paper set's
  `gripMove` (`:297-298`); the faded frame `gripMove` at alpha × (1 −
  `kTableFocusVeilAlpha`), the veiled chip the paper's RGB at
  `kTableFocusVeilAlpha` (`:299-302`, zone Z14); the chip's ink by
  `foregroundFor` on `gripMove` (`:315-317`); the margin reaches the
  path, the bounds' width and the chip's anchor (`:355`, `:373-375`);
  chips cached by (text, ink) (`:276`, `:358-359`), built with **no font
  family** (`:391-402`); the stroke width per frame (`:438`); the chip
  rect `(-padX, -padY, w + padX, h + padY)` (`:362-367`) and its bottom
  edge on the frame's top line by `sy - (h + padY)` (`:461`, fixes X3).
- **The veil** (`table_focus_painter.dart`): the paper's RGB at 0.6, the
  paper's alpha replaced (`:17`, `:140`).
- **The bar** is `Container(height: 44)` (`service_view.dart:423-427`).
  The selection canvas's origin is seeded `(0, 44)`
  (`host/floor_plan_controller.dart:39-48`) and measured **once per plan
  shown**, after its first frame (`floor_plan_view.dart:187-200`,
  `controller.canvasMeasured`, `:723-729`); a correction applies only to
  an origin a reframing assumed. So a bar height changed at runtime,
  with the plan unchanged, leaves the stored origin stale for the next
  mode switch (R-13): see [S-10](#spec-points-to-settle).
- Painted text has no family today; the plan's text is `Roboto`, which
  `ensureFloorPlanFonts` registers (`lib/src/fonts.dart:14, 30`): see
  [S-2](#spec-points-to-settle).
- The painters' layers carry keys a test reads them by
  (`service_view.dart:503, 510, 526, 532`), so a view test reaches each
  painter's `debugAllocations` and `debugRebuilds`.

**Builds:**
- Each of `TableStatusPainter`, `TableGroupPainter`, `TableFocusPainter`
  gains an optional `ValueListenable<FloorPlanTheme?>? theme` (null:
  today's). Its value joins the rebuild key as the paper does
  (`!identical` against the value last built for: the notifier replaces
  its value only on `!=`); the veil's joins its recolour key only.
  `ServiceView` passes Task 1's `_theme` to the four painters (status,
  frames, chips, veil) and adds it to the three repaint merges. **Nothing
  is derived from the theme in `paint`.**
- **Status:** the drawn colour is the status colour with its alpha
  multiplied by `statusFillOpacity` **once**, at rebuild; the paint cache
  is keyed by the drawn ARGB. With no `statusCaptionStyle` the paragraph
  is built as today (the same constructors). With one: its `color`, or
  the automatic ink of the **drawn** colour over the paper (S-6); its
  `fontSize` or 11; its family as given (S-2); the caption cache keyed by
  the style too (T3-a). The "below" rule reads the resolved font size in
  place of `kStatusCaptionSize`.
- **Groups:** frame colour `groupFrameColor ?? gripMove`; width
  `groupFrameWidth ?? 2`; margin `groupFrameMargin ?? 150` (path, bounds,
  anchor); chip colour `groupChipColor ??` the resolved frame colour
  (S-7); chip text `groupChipTextStyle` as the caption's (null colour: the
  automatic ink on the chip colour; null size: 11); radius
  `groupChipRadius ?? 4`; padding `groupChipPadding ??
  EdgeInsets.symmetric(horizontal: 5, vertical: 2)`, the rect
  `(-left, -top, w + right, h + bottom)` and the anchor `sy - (h +
  bottom)`; the faded frame the frame colour at alpha × (1 − veil
  opacity), the veiled chip the veil's colour at its opacity (S-7, S-9).
- **Veil:** `focusVeilColor` (its alpha × `focusVeilOpacity`), or the
  paper's RGB at `focusVeilOpacity` (the paper's alpha replaced, as
  today); opacity `?? 0.6` (S-9). Still a recolour, no rebuild.
- **Bar:** `height: theme?.serviceBarHeight ?? 44`. S-10: `ServiceView`
  takes an internal optional `VoidCallback? onCanvasMoved`, called once
  after the first frame in which the laid-out bar height differs from
  the last one laid out; `FloorPlanView` re-measures the selection
  canvas's origin there with its existing `_canvasOrigin`.

**Tests** (`test/service/table_theme_painter_test.dart` at the painters,
with the recording canvas and `PictureRecorder` read-backs of their
existing tests; `test/host/theme_service_test.dart` through
`FloorPlanView` on `embeddingPlanJson` under `embeddingCamera()`, and on
the zone fixture for the veil): **M-H31, M-H32, M-H33(repaint),
M-H33(opacity twice), M-H33(null caption colour)**, **T3-a** to **T3-e**
(below). Plain:
- **Invariant 7 with a theme:** SP1's, TG-L9's and FP3's themed siblings
  (a full theme, N = 60 tables, warm-up, ten frames panning): nothing
  built, nothing rebuilt, the same objects to the canvas; TO10's and
  TO21's siblings with a full theme in force and overlays shown: the
  render object's counters at their bars.
- Each field read back once, in pixels or in what reaches the canvas:
  caption 14 px bold (paragraph height, glyph rows), a caption colour
  honoured over the automatic ink, a `fontFamily` honoured (a family
  registered by a `FontLoader` measures wider than the default, T-4 /
  S-2); frame 3 px at 0.125 and 0.04 px/mm; margin 300 mm (TG-L4's
  geometry, every member corner pushed out by less than 300 mm and the
  extreme corners by exactly 300 mm); chip radius and the asymmetric
  padding's rect, the chip's bottom edge still on the frame's top line at
  two zooms (fixes X3); a chip with no chip colour takes the themed frame
  colour; the faded group under a themed veil (Z14).
- **The bar:** `serviceBarHeight: 60` → the bar is 60 px, the canvas
  starts at `(0, 60)`, and the controller's measured origin is `(0, 60)`
  after the first frame; a runtime change 44 → 60 with the plan unchanged,
  then a switch to the design mode and back, keeps a table's global
  position as R-13 does with 44 (T3-d).
- `designJson()`, the service layout and the PNG export are equal with
  and without a full theme in the selection mode (invariant 4).
- A host rebuild with an equal, non-identical view theme leaves every
  painter's `debugRebuilds` unchanged (T1-c's consequence, T-3's `==`).

**Unedited and green (P-6, invariant 7):**
`test/service/table_status_painter_test.dart` (SP1–SP12),
`test/service/table_group_painter_test.dart` (TG-L1–L11, TG-Z1, TG-Z2,
RX1), `test/service/table_focus_painter_test.dart` (FP1–FP6),
`test/host/status_caption_test.dart`, `test/host/table_groups_look_test.dart`,
`test/host/table_groups_toolbar_test.dart`, `test/host/view_test.dart`
(the bar, the seeds, R-13), `test/host/view_events_test.dart` (`:408`
moves to the bar's centre), `test/host/table_overlay_test.dart`,
`test/invariants/pick_allocation_test.dart`; the demo's tests.

**Gates:** planner (`--enable-vmservice`, standing comparison, analyze,
format), demo, floor planner.

### Task 4 — the demo, docs, CI and the exit (the controller's)

- **Demo** (`apps/restaurant_demo`), the smallest real use of every
  addition (P-7); strings in en, de, tr (`lib/demo_strings.dart`):
  - a **Look** switch in the app bar, *Standard* (today's, the default)
    and *POS*. *POS* wraps the area's view in a local `Theme` built by
    `lib/demo_theme.dart`: a **hand-built** `ColorScheme` of shadcn-like
    tokens (zinc: white surface, near-black on-surface, muted
    `surfaceContainer`, zinc borders, a near-black primary), light and
    dark (F-4's recipe, the demo's `ThemeMode.system` choosing), each
    `ThemeData` carrying a `FloorPlanTheme` (bold 12 px captions, fill
    opacity 0.8, frame and chip in the primary, chip radius 6, a muted
    `canvasBackground`, bar 52 px, selection colours per paper); the view
    passes `theme: FloorPlanTheme(selectionWidth: 3)`, the override's
    one-field demonstration. `theme_colours_test`'s whole-file allowance
    for `demo_theme.dart` (Global constraints).
  - With *Standard* the demo is today's: the existing demo tests
    (`test/demo_test.dart`, `badges_test.dart`, `events_test.dart`) pass
    unedited. Demo tests for *POS*: the bar 52 px, a selected table's
    outline 3 px in the theme's colour, a caption bold, the surround the
    canvas colour, both modes, light and dark; *Standard* again restores
    today's pixels.
- **Host guide** (`docs/host-guide.md`), marked *Unreleased*: **§ 9
  Themes** (`:1176-1180`) grows from four lines: the sixteen fields by
  group with their units and what null means (T-1); the ambient
  extension, one per `ThemeData`, light and dark, and `FloorPlanView(theme:)`
  merging field by field (T-2, S-3); the local-`Theme` recipe with a
  hand-built `ColorScheme` for everything else of the chrome (F-4), and
  that the export dialog follows that local `Theme` (S-12); fonts (T-4 as
  ruled under S-2: set `fontFamily: 'Roboto'` for the same captions on
  every terminal; a family the host has not loaded falls back); the
  theme is never saved, exported or printed (P-5); an animated theme
  switch recolours as it goes. § 4's `FloorPlanView` parameter list names
  `theme`.
- **Host probe:** the guide's new snippets (a `ThemeData` with the
  extension, a light and a dark one, the view override, the local
  `Theme` recipe) in `tool/ci/host_probe/lib/main.dart`; `check_guide`
  green; one mutant: an edited probe snippet makes `check_guide` exit 1.
- **CI, invariant 1:** unchanged: the host-probe job analyses v0.3.0's
  probe against the commit under test (`.github/workflows/ci.yml:166`,
  `tool/ci/old_host_probe.sh`); both probes analyse locally at the tip.
- **CHANGELOG** *Unreleased* (`CHANGELOG.md:9-16`): the intro names Slice
  3; a bullet **The look** (`FloorPlanTheme`, `FloorPlanView.theme`, the
  merge, the recipe, fonts); for `jet_cad_2d_flutter`,
  `PaperPalette.withSelection` and
  `SelectionOverlayPainter.selectionStrokePixels`; stored formats
  unchanged.
- **Results note** `docs/superpowers/notes/2026-10-09-embedding-slice-3-results.md`;
  **STATUS**; **the roadmap's row 14** (`roadmap/00-README.md:267`); the
  spec's Review section records the rulings on S-1 to S-12.
- **Every gate**, `tool/ci` and the engine included, with the standing
  comparison; both web builds; the host probe locally at the full SHA.
- **Web smoke check** in Chromium (Playwright, `locale: 'en-US'`, light
  and `colorScheme: 'dark'`): the demo's Salon in *Standard*, then
  *POS*: Service; Random statuses (bold captions, dimmed fills); a group
  frame and chip in the primary; a zone's veil; the bar's height; a
  selected table's 3 px outline; Design: the selection and the surround;
  *Standard* again; no console error.

Then an independent code review of the whole range, its fixes, and the
merge on the human's word.

## Mutants per task

| Task | Mutants | Count |
|---|---|---|
| 1 | M-H30; T1-a, T1-b, T1-c | 1 + 3 |
| 2 | M-H33(canvasBackground), M-H33(the editor's selection); T2-a, T2-b, T2-c, T2-d | 2 + 4 |
| 3 | M-H31, M-H32, M-H33(repaint), M-H33(opacity twice), M-H33(null caption colour); T3-a, T3-b, T3-c, T3-d, T3-e | 5 + 5 |
| 4 | the probe snippet (check_guide) | 1 |

Every spec mutant of Slice 3 is here once: M-H30 (Task 1), M-H31 (Task
3), M-H32 (Task 3), and M-H33's five: *a theme change without a paper
change does not repaint* (Task 3), *`statusFillOpacity` applied twice*
(Task 3), *a null caption colour forces black* (Task 3), *`canvasBackground`
not reaching a page-less plan's paper* (Task 2), *the editor's selection
not following `selectionOnLight`* (Task 2).

Each mutant and its killer:

- **M-H30:** the view theme replaces the ambient one wholesale
  (`view ?? ambient`). Killer: ambient `ThemeData(extensions:
  [FloorPlanTheme(groupFrameColor: 0xFF00897B)])`, view
  `FloorPlanTheme(selectionOnLight: 0xFFD81B60)` → the resolved theme in
  the selection mode **and** in the design mode equals
  `FloorPlanTheme(groupFrameColor: …, selectionOnLight: …)`; the mutant
  loses the frame colour. Its reversed form (`view.merge(ambient)`, the
  ambient winning) is killed by the precedence check: `selectionWidth` 3
  ambient, 5 view → 5.
- **T1-a:** `TextStyle` fields replaced whole in `merge` (if S-3 is ruled
  as recommended). Killer: ambient caption `TextStyle(fontSize: 14)`,
  view `TextStyle(fontWeight: FontWeight.bold)` → resolved size 14 and
  bold.
- **T1-b:** `lerp` with one side null fades (`Color.lerp(null, b, t)`).
  Killer: `lerp` from no `groupFrameColor` to `0xFF00897B` at 0.25 →
  null, at 0.75 → `0xFF00897B` with alpha 1.
- **T1-c:** the scope notifies by identity. Killer: `updateShouldNotify`
  of two equal, non-identical themes is false (and of two different ones
  true). Task 3's view tests read the consequence: a host rebuild with an
  equal, non-identical view theme leaves every painter's `debugRebuilds`
  unchanged.
- **M-H33(canvasBackground):** `canvasBackground` colours the surround but
  not a page-less plan's paper (`_surfaceArgb` left on `scheme.surface`).
  Killer: the page-less fixture under the **light** seed theme with
  `canvasBackground: 0xFF263238`: in both modes the surround's pixel is
  `0x263238`, the ACI 7 witness line is white (the dark paper's ink), and
  the selected line takes the dark set's `0xFF7FB2FF`; the mutant draws
  the line black and the selection `0xFF1E6FE8`.
- **M-H33(the editor's selection):** the shell ignores `selectionOnLight`
  (or swaps the sets). Killer: the design mode through `FloorPlanView`,
  White page, light theme, `selectionOnLight: 0xFFD81B60`,
  `selectionOnDark: 0xFFFFD54F` → the selected line's pixel `0xD81B60`;
  Blueprint → `0xFFD54F`; the selection mode the same (both modes, T-1).
- **T2-a:** the hover not derived (the paper set's hover kept). Killer:
  render, `withSelection(0xFFD81B60).hover == 0x99D81B60`; planner, a
  hovered line in the design mode under that theme reads the selection's
  hue at 60 % over the paper.
- **T2-b:** `shouldRepaint` ignores the width. Killer: a theme change of
  `selectionWidth` alone, no camera move, one pump → the 4 px rows are
  drawn.
- **T2-c:** the width applied to the hover too. Killer: the recorded
  hover `Paint` still strokes `1.5 / scale` at `selectionStrokePixels: 4`.
- **T2-d:** `canvasBackground` reaches the paper but not the surround's
  `ColoredBox`. Killer: with a page, the pixel beside the sheet is
  `0x263238` in both modes.
- **M-H31:** a theme read per frame: the painters derive their style from
  the theme in `paint` (the status painter builds its caption paragraph,
  the group painter its chip paragraph and `RRect`, from the theme on each
  frame; or a key compares a per-frame copy of the theme). Killer: the
  themed siblings of SP1, TG-L9 and FP3 (a full theme, ten frames
  panning after warm-up): `debugAllocations` and `debugRebuilds`
  unchanged, the same `Paint`, `Path` and `Paragraph` objects passed; and
  through `FloorPlanView`, ten pans under a full theme leave each of the
  four layers' `debugRebuilds` unchanged.
- **M-H32:** `focusVeilColor: null` ignores the paper (a fixed or the
  light paper's colour). Killer: the zone fixture on **Blueprint** (light
  theme) and a **page-less plan on a dark `canvasBackground`**, with
  `FloorPlanTheme(focusVeilOpacity: 0.35)` alone and a focus of `{1}`: a
  faded table's pixel is the paper's RGB at 0.35 over what lies under it
  (computed by the test), on each dark paper; the mutant reads light.
- **M-H33(repaint):** a theme change without a paper change does not
  repaint (the theme missing from a layer's repaint merge, or from a
  painter's rebuild key). Killer: through `FloorPlanView` in the selection
  mode, a status on `1`, a group `{2, 3}` and a focus `{1}` set and
  painted first; then, the camera still, the document, statuses, groups
  and focus untouched, the host changes **only** `statusFillOpacity`, then only
  `groupFrameColor`, then only `groupChipColor`, then only
  `focusVeilOpacity`; after one pump each layer's pixels show the new
  value. Seen red in each of the four layers, both forms.
- **M-H33(opacity twice):** `statusFillOpacity` applied twice (at rebuild
  and again when drawing, or compounded through the paint cache). Killer:
  the Bill `0x99E53935` at 0.5 → the fill `Paint`'s alpha byte is
  `round(0.6 × 0.5 × 255) = 0x4D`, and its pixel over White is the test's
  composite at 0.3; twice reads 0.15. A second status redrawn after a
  theme change 0.5 → 0.5 (equal) keeps the same alpha (no compounding).
- **M-H33(null caption colour):** a null caption colour forces black.
  Killer: `statusCaptionStyle: TextStyle(fontSize: 14)` (no colour), the
  dark fill `0xFF1B1B1B` on White → the caption's glyph pixels are
  lighter than the fill (white ink); the light fill `0xFFFFE082` → dark
  glyphs; the mutant draws the first black.
- **T3-a:** the caption (or chip) cache not keyed by the style. Killer:
  one status, the caption style 11 → 16 px, nothing else changed → the
  drawn paragraph's height grows; the chip's likewise.
- **T3-b:** the chip ignores the frame colour as its default (`gripMove`
  kept). Killer: `groupFrameColor` alone → the chip's fill is that colour
  (if S-7 is ruled as recommended).
- **T3-c:** the caption ink read from the undimmed colour. Killer:
  `0xFF303030` at `statusFillOpacity: 0.2` on White (drawn colour light)
  → dark glyphs; at 1.0 → white glyphs (S-6).
- **T3-d:** the bar height changed at runtime, not re-measured. Killer: a
  table's global position kept across selection → design → selection
  after 44 → 60, as with 44 (R-13); the mutant shifts it by 16 px.
- **T3-e:** the chip padding read symmetric (left for right, top for
  bottom). Killer: with `EdgeInsets.fromLTRB(7, 3, 9, 4)` the recorded
  `RRect` is `(-7, -3, w + 9, h + 4)` and its screen bottom lies on the
  frame's top line at 0.125 and 0.04 px/mm.

## Exit gate

- Task 4 green: every gate, the standing sets exact, both web builds, the
  smoke check, the probe and v0.3.0's probe locally and in CI.
- Every named mutant above seen red and recorded.
- The independent review applied.
- **Owed to the human:** a look at the demo's *POS* look in both
  themes on a tablet and a terminal (captions, frames, chips, veil, bar,
  selection); the German and Turkish read of the demo's new strings; the
  rulings on S-1 to S-12 if any differs from the recommendation.
- **Owed to Monépro:** spec 103 can name `FloorPlanTheme` and the local
  `Theme` recipe for its shadcn tokens (F-4); whether its terminals want
  `fontFamily: 'Roboto'` in the caption and chip styles (S-2).
- **The merge into `main` happens on the human's word**; a release is the
  human's call (P-8).

## Spec points to settle

Found while verifying the spec against the code at `8fd7483`. Each has a
recommended resolution; the plan is written to the recommendation.
**The controller ruled each as recommended**; the spec records them (T-3,
T-4 and its Review section).

- **S-1. T-3 names `paint_allocation_test` "for the selection colours";
  it does not paint them.** That test measures `DraftPainter`'s vertices
  sink alone (`jet_cad_2d_flutter` `test/invariants/paint_allocation_test.dart:135-262`);
  the selection overlay's frame objects are pinned by
  `selection_overlay_test.dart:320`. *Recommended:* `paint_allocation_test`
  stays untouched (it is invariant 7's, and a theme cannot reach it); the
  overlay's reuse test gets a themed sibling (Task 2); T-3's sentence
  names `selection_overlay_test`'s reuse test instead.
- **S-2. T-4's "the bundled Roboto by default, as the plan does"
  contradicts today's pixels.** The status caption and the group chip are
  built with no font family (`table_status_painter.dart:265-272`,
  `table_group_painter.dart:391-402`): they draw in the platform's
  default font, not `Roboto`. Making `Roboto` the default changes every
  caption's and chip's glyphs and widths (and so which captions and chips
  are skipped as wider than their table or frame) on every platform whose
  default is not Roboto: P-6 would break. *Recommended:* the default stays
  today's (no family); a `fontFamily` in either style is honoured when the
  host has loaded it; the guide recommends `fontFamily: 'Roboto'`
  (registered by `ensureFloorPlanFonts`) for the same captions on every
  terminal. T-4 amended so.
- **S-3. `merge` and the two `TextStyle` fields.** "Field by field"
  leaves open whether a view's caption style replaces the ambient one or
  merges into it. *Recommended:* `TextStyle.merge`, as Flutter's
  `TextTheme.merge` does, so a view that sets only `fontWeight` keeps the
  ambient `fontSize`; within a resolved style a null property is today's
  (11 px, the automatic ink, no family).
- **S-4. `lerp` with one side null.** A null field means a value that
  depends on the paper, which `lerp` cannot know; `Color.lerp(null, c, t)`
  would fade from transparent. *Recommended:* a field null on one side
  takes the `t < 0.5` side (as `ThemeData.lerp` treats fields it cannot
  lerp); `lerp(null)` and a foreign `other` return `this` (Flutter's
  `_lerpThemeExtensions` lerps an extension only one theme has with null).
- **S-5. Types and ranges.** T-1 gives neither. *Recommended:* the types
  in Task 1 (`TextStyle`, `Color`, `double`, `EdgeInsets` for the chip
  padding, whose today's value is asymmetric in x and y); the constructor
  stays `const` and never throws; the resolved theme is validated where
  the view validates its overlay layout, an `ArgumentError` at build
  naming the field: opacities finite in [0, 1]; `selectionWidth`,
  `groupFrameWidth` and `serviceBarHeight` finite and above 0 (a 0 stroke
  is Skia's hairline, and a 0 bar is Slice 4's `visible: false`);
  `groupFrameMargin`, `groupChipRadius` and each padding side finite and
  not negative; a style's `fontSize` finite and above 0. A translucent
  `canvasBackground` is documented, not refused: the paper's ink keys on
  its RGB, as `displayPaperFor` does with any surface today.
- **S-6. Which colour picks the automatic ink under `statusFillOpacity`.**
  *Recommended:* the **drawn** colour (opacity applied) over the paper,
  D6c's "what it sits on"; and a `groupChipTextStyle` without a colour
  takes the automatic ink on the chip colour, as on `gripMove` today.
- **S-7. Defaults that follow another field.** Today the chip is filled
  with the frame's colour, and Z14's faded group uses the veil.
  *Recommended:* `groupChipColor` null is the **resolved** frame colour
  (a host that sets only the frame gets a matching chip; with neither set
  it is `gripMove`, today); the faded frame is the frame colour at alpha ×
  (1 − `focusVeilOpacity`), and the veiled chip takes the veil's colour
  and opacity: one veil, as Z14 says.
- **S-8. What `selectionWidth` reaches.** *Recommended:* every use of
  `kSelectionStrokePixels` in `SelectionOverlayPainter` (the outline, a
  selected point's cross stroke and its 3× half-length, the preview
  cross's half-length); the hover stays 1.5 px (T-1 names only the
  selection's width); the hover's colour is the selection at alpha × 0.6,
  which reproduces both palettes' hover exactly; the grips, bands, preview
  and snap colours stay the paper set's.
- **S-9. The veil's alpha with a host colour.** Today the paper's alpha
  is replaced by 0.6. *Recommended:* a given `focusVeilColor`'s alpha is
  **multiplied** by `focusVeilOpacity` (as `statusFillOpacity` multiplies
  the status colour's), the paper's still replaced (the paper is opaque);
  `focusVeilOpacity` null is 0.6.
- **S-10. `serviceBarHeight` at runtime and R-13.** The selection canvas's
  origin is measured once per plan shown (`floor_plan_view.dart:187-200`);
  a bar height changed while the same plan is shown leaves the stored
  origin stale, and the next mode switch reframes off by the difference.
  The first measurement after a non-44 bar is already corrected by the
  existing machinery. *Recommended:* the view re-measures the selection
  canvas after the first frame with a new bar height (Task 3, T3-d); the
  plan itself moves on screen with the canvas, as on any host layout
  change. Slice 4's C-1 and M-H47 meet the same measurement for
  `visible: false`.
- **S-11. The resolution's seat.** T-2 reads as if `FloorPlanView`
  resolves; resolving in its `build` would make every theme switch
  rebuild every host overlay (G-5; `FloorPlanView` reads no theme today).
  *Recommended (no design change):* an internal scope just below
  `FloorPlanView` resolves `ambient.merge(view)` and provides it to both
  modes, compared by `==`; a bare `PlannerShell` reads the ambient
  extension.
- **S-12. Readings the plan pins with tests** (no design change, stated
  so a review can object): the export dialog follows a local Material
  `Theme` around the view, because `showDialog` captures the caller's
  themes (`material/dialog.dart:1640-1643`), and never sees the view's
  `theme:` (a plain `InheritedWidget`); an animated theme switch rebuilds
  the selection-mode painters at the animation's rate, as a page-less
  paper following `scheme.surface` does today (theme rate, not camera
  rate); "read per frame" in P-4 and M-H31 means a derivation or an
  allocation per frame, not a field load, so the overlay's per-frame
  `Paint.color = paper.selection` (`selection_overlay.dart:125-131`)
  stays; and F-10's and F-11's line references have moved since
  `85905bd` (`planner_shell.dart:977` → `:1000`, `:211-214` → `:234-237`;
  `service_view.dart:413` → `:484`, `:258-261` → `:329-332`, the bar
  `:352-390` → `:423-462`), nothing else in them.
