# Task 4 report: the renderer's scenes R1–R5 and their screenshots

**Status:** DONE. Commit `28ec7f45 feat(tool): the renderer's five scenes and their screenshots`.

## What I built

- `tool/screenshots/test/support/renderer_stage.dart`: `RendererStage({document, dark, canvas})`
  and `RendererStageState` (public fields `index`, `selection`, `outlines`, `grips`, `page`,
  `camera`, `tools`). It is the brief's code, with one addition: a `GripCache(document,
  selection, outlines)` passed as `ToolContext.grips` and disposed between the tools and the
  outlines, as `PlannerShell` does (`planner_shell.dart:648`, `:1149`). Without it,
  `SelectionOverlayPainter` reads `tools.context.grips == null` and draws no grips. The first R3
  had no grip squares, which showed this. No object grip provider, so a group (a wall, an
  opening, a room, a dimension) shows its outline and no grips, as the renderer alone does.
- `tool/screenshots/test/renderer_scenes_test.dart`: R1–R5. The document is
  `startupPlan(FlutterTextMeasurer())`. The canvas is `kWide - kRulerThickness` each way
  (`kRulerThickness` is exported, 24). Every stage scene checks the premise
  `tester.getSize(find.byType(DraftCanvas)) == _canvas`. The app is
  `MaterialApp(theme: ThemeData(brightness, fontFamily: 'Roboto'), home: Material(child: stage))`,
  so the rulers' `DefaultTextStyle` family is Roboto. R2 uses `brightness: Brightness.dark`
  through `MaterialApp.theme`, which is the same as the brief's `Theme(data: ThemeData(brightness: dark))`.
  - R3: a mouse window drag, left to right, from the empty sheet above and left of the flat to
    the bedrooms' partition. Then `removePointer`, and a second mouse
    (`createGesture`/`addPointer`/`moveTo`) hovers the sofa's lower edge. Premises:
    `dragKind == DragKind.band` (the press hit no entity), `bandMode == BandMode.window`,
    `selection.length > 2`, `selection.hover != null` and the hovered entity is not selected.
  - R4: a mouse drag, right to left, held, from the empty surround right of the flat to the
    living room. Premises: `dragKind == DragKind.band` and `bandMode == BandMode.crossing`.
    Order: `shoot`, then `up`.
  - R5 at `kPanel`: `SymbolLibraryLoader(sources: const [furnitureSymbolSource])`,
    `await tester.runAsync(loader.load)`, then `SymbolLibraryReady`. The gallery is built as in
    the brief. One change: spec D5 says "one category open", so every header except
    `Bathroom` is tapped closed (`ensureVisible`, `tap`, `pump`, then `pumpAndSettle`). Then
    `settle` runs its forty rounds for the thumbnails.

## Deviations from the brief's verbatim code (each forced or justified)

1. **`SymbolWords` is not exported by `package:jet_cad_floor_plan/editor.dart`** (nor by the
   planner barrel; only `SymbolNames` is). The analyzer reported `undefined_shown_name`. It is
   not needed: `searchSymbols(entries, query, [SymbolWords words = SymbolWords.english])` takes
   it as an optional parameter. `SymbolWords.english` is `SymbolWords(SymbolNames.empty, 'en')`,
   whose `name(e)` is `e.name` and `category(c)` is `c` (`symbol_names.dart:40-60`). So the scene
   calls `searchSymbols(library.entries, '')` and uses `e.name` and `g.category`, which gives
   the same output from public names only. Nothing was imported from `src/`.
2. `SymbolGallery.foreground` and `.selectedForeground` are `int` (`0xRRGGBB`), not `Color`.
   The analyzer reported it, so the scene passes `0x1F1F1F` and `0x0B57D0`, the brief's
   colours.
3. `SelectionController` has no `value`. I used `isEmpty`, `length`, `hover` and `contains`.
4. `BandMode` comes from `package:jet_cad_2d/jet_cad_2d.dart` (`show BandMode`). `DragKind`
   and `SelectTool` come from the renderer barrel.
5. The `GripCache` above.
6. R3's hover: after the window drag, the first mouse device is still added. A second
   `addPointer` asserted in `MouseTracker._shouldMarkStateDirty` (the first run failed there).
   The drag's pointer is now removed before the hover gesture is added.

Other names not exported from a barrel: none. `kRulerThickness`, `kDarkCanvasPaper`,
`canvasResolverFor`, `PaperPalette`, `ChromePalette`, `GripCache`, `SymbolThumbnails` (it has
`dispose`), `SymbolGallery`, `GalleryCategory` and `GallerySymbol` are all on the renderer
barrel. `SymbolLibraryLoader`, `SymbolLibraryReady` and `furnitureSymbolSource` are on the
planner barrel.

## A pitfall found by eyes-on (fixed)

The first R3 and R4 started their drags on entities. R3 started on the north wall's band, R4
on a parquet line. `SelectTool` made both drags into **moves**. R3 showed the north wall moved
into the living room. R4 showed a parquet line's move ghost instead of a band. Both drags now
start on empty sheet or surround, and the `dragKind == DragKind.band` premise turns red if a
start ever lands on an entity again.

## Test runs (quoted)

- First run, without the variable, before any PNG existed: R3 failed on the double
  `addPointer` assertion (`+4 -1 ... Some tests failed.`). After the fix:
  `00:06 +5: All tests passed!`. `ls packages/jet_cad_2d_flutter/doc/screenshots` printed
  `No such file or directory`, so nothing was written.
- `UPDATE_SCREENSHOTS=1 flutter test test/renderer_scenes_test.dart`: `00:06 +5: All tests passed!`
  each time it ran. Final run: `00:07 +5: All tests passed!`.
- Full gate `flutter test` in tool/screenshots, without the variable:
  `00:07 +14: All tests passed!` (harness, P1–P6, R1–R5). Afterwards, `shasum -c` of the five
  renderer PNGs printed `OK` for all five, and git saw no change to the planner's PNGs.
- `flutter analyze`: `No issues found! (ran in 2.6s)`.
- `dart format --output=none --set-exit-if-changed .`: `Formatted 5 files (0 changed)`, exit 0.

## The PNGs (eyes-on, each opened with Read)

| File | Bytes | Shows | Verdict |
|---|---|---|---|
| `canvas_light.png` | 147205 | The sample flat on its A4 sheet with the page grid. The rulers show real digits (`-1 m` … `16 m`, `0 m` … `10 m`, the `m` corner). Room names and areas, dimensions `14.00`, `9.00`, `4.69`, `4.38`, `3.58` | good: fitted and legible |
| `canvas_dark.png` | 163133 | The same on the dark canvas: walls and ink re-toned white, the furniture fill darkened with its tan edge, dark rulers with light digits | good |
| `selection_grips.png` | 156685 | The bedrooms window-selected: blue outlines on the partitions, doors, windows, rooms and labels; corner grips on both beds; the rotation grip above the box; the sofa hovered (thinner, translucent blue, checked on a crop); the ruler pointer ticks | good: grips and hover clear |
| `selection_band.png` | 161344 | A green dashed crossing band, translucent, mid-drag from right of the flat (over the `9.00` dimension) to the living room, over the bath, the kitchen, the sofa and the table | good |
| `symbol_gallery.png` | 38921 | 480×800: the headers Dining Room 7, Kitchen 10, Bed Room 10, Living Room 5 collapsed (chevron icons), Bathroom 4 open with painted thumbnails (Toilet, Washbasin, Bathtub, Shower tray), Office 5 collapsed | good: real text and icons, thumbnails painted |

## Measurement and the kRatio decision

The renderer's five files total **667288 bytes**. The largest is 163133 bytes, far below the
1 MB per-file budget and the 4 MB total. The planner's six total 383774 bytes. **kRatio stays
1.5.** The planner's PNGs were not regenerated, and git shows them unchanged.

## Files changed

- `tool/screenshots/test/support/renderer_stage.dart` (new)
- `tool/screenshots/test/renderer_scenes_test.dart` (new)
- `packages/jet_cad_2d_flutter/doc/screenshots/{canvas_light,canvas_dark,selection_grips,selection_band,symbol_gallery}.png` (new, generated)

No `analysis_options.yaml` was staged. `flutter pub get` ran implicitly, and `git status --short`
showed only the new files. The harness `shots.dart` is unchanged.

## Self-review

- Public API only: the barrels, plus editor.dart for `startupPlan`, `symbolThumbnailDocument`,
  `searchSymbols` and `symbolIdOf`. There is no planner widget on screen. R5's `MaterialApp`
  and `Material` are Flutter's.
- The R3 and R4 premises are the guard against the degenerate start: each turns red if a drag
  becomes a move or a band runs the wrong way. The R1 and R2 premise turns red if the canvas
  size and the fitted camera disagree.
- The flat's outer corner (`_x0 = 12000`, `_y0 = 8000`) is copied from
  `startup_plan.dart`'s `kPlanOriginX`/`kPlanOriginY`, which editor.dart does not show in the
  allowed list. A comment says so. If the sample flat moves, the premises catch a start on an
  entity.

## Concerns

- R5 collapses all but one category ("one category open", spec D5). The brief's step did not
  ask for the taps. Without them only Dining Room is visible, because every category is open
  by default and the first one fills the panel. Drop the loop if the controller prefers the
  brief's literal scene.
- The stage adds a `GripCache` that the brief's code did not have. Without it the renderer
  draws no grips, and R3's subject is the grips.
- I did not run the `jet_cad_2d_flutter` package gate. Its only change is new PNGs under
  `doc/`, and no test there scans `doc/`: `no_gpu_dependency_test` lists `lib/` only.
