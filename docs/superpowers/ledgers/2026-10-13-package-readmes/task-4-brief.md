### Task 4: The renderer's scenes R1–R5 (D5, A3)

**Files:**
- Create: `tool/screenshots/test/support/renderer_stage.dart`
- Create: `tool/screenshots/test/renderer_scenes_test.dart`
- Create: `packages/jet_cad_2d_flutter/doc/screenshots/{canvas_light,canvas_dark,selection_grips,selection_band,symbol_gallery}.png` (generated)

**Interfaces:**
- Consumes: Task 2's harness.
- Produces: `RendererStage({required DraftDocument document, required bool dark})` with a `GlobalKey<RendererStageState>` exposing `selection` (`SelectionController`) and `camera`.

- [ ] **Step 1: The stage**, the renderer's public widgets composed as `PlannerView` composes them (`packages/jet_cad_floor_plan/lib/src/planner_view.dart:334-440`), with no planner widget:

```dart
// The renderer's widgets alone (spec D5 R1-R4): a ruler frame around an
// interaction layer over the page chrome, the canvas and the selection
// overlay, light or on the dark canvas.
import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

class RendererStage extends StatefulWidget {
  const RendererStage(
      {super.key, required this.document, required this.dark, required this.canvas});

  final DraftDocument document;
  final bool dark;

  /// The canvas's size inside the rulers, fitted once (a known size: no
  /// fit during layout).
  final Size canvas;

  @override
  State<RendererStage> createState() => RendererStageState();
}

class RendererStageState extends State<RendererStage> {
  late final SpatialIndex index = SpatialIndex(widget.document);
  late final SelectionController selection =
      SelectionController(widget.document);
  late final OutlineCache outlines = OutlineCache(widget.document, selection);
  late final PageNotifier page = PageNotifier(widget.document);
  late final CameraController camera = CameraController(
      ViewportTransform.fit(widget.document.extents.expandedBy(500), widget.canvas));
  late final ToolController tools = ToolController(
      initial: SelectTool(),
      context: ToolContext(
          document: widget.document,
          index: index,
          camera: camera,
          selection: selection));

  @override
  void dispose() {
    tools.dispose();
    outlines.dispose();
    page.dispose();
    camera.dispose();
    selection.dispose();
    index.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paperArgb = widget.dark ? kDarkCanvasPaper : 0xFFFFFFFF;
    final paper = widget.dark ? PaperPalette.dark : PaperPalette.light;
    return ColoredBox(
      color: Color(paperArgb),
      child: RulerFrame(
        camera: camera,
        page: page,
        chrome: widget.dark ? ChromePalette.dark : ChromePalette.light,
        child: InteractionLayer(
          tools: tools,
          child: Stack(children: [
            Positioned.fill(
              child: CustomPaint(
                painter: PageChromePainter(
                  camera: camera,
                  page: page,
                  chrome: widget.dark ? ChromePalette.dark : ChromePalette.light,
                  paper: paper,
                  sheetArgb: widget.dark ? kDarkCanvasPaper : null,
                  repaint: Listenable.merge([camera, page]),
                ),
              ),
            ),
            DraftCanvas(
              document: widget.document,
              index: index,
              camera: camera,
              resolver: canvasResolverFor(widget.document,
                  paper: paperArgb, dark: widget.dark),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: SelectionOverlayPainter(
                  selection: selection,
                  tools: tools,
                  camera: camera,
                  outlines: outlines,
                  paper: paper,
                  repaint: Listenable.merge([selection, tools, camera, outlines]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
```

Every name above is on `package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart` except those the analyzer reports: for each one it reports, read the barrel and use the exported name; if one is not exported, stop and record it (the stage may only use public API). How `PlannerShell` wires the dark canvas is at `planner_shell.dart:327-343` and `:1509-1515`; follow it where this stage differs. If the fitted page sits poorly, fit to the page sheet's bounds instead of `extents`.

- [ ] **Step 2: The scenes**, `renderer_scenes_test.dart`; the document is `startupPlan(FlutterTextMeasurer())` (`package:jet_cad_floor_plan/editor.dart`); the canvas size is `kWide` minus the rulers (`kRulerThickness` if the barrel exports it, else 24, with a premise `expect(tester.getSize(find.byType(DraftCanvas)), canvas)`):
- **R1** `canvas_light.png`: the stage, light.
- **R2** `canvas_dark.png`: `dark: true`, inside `Theme(data: ThemeData(brightness: Brightness.dark))`.
- **R3** `selection_grips.png`: light; a mouse drag left to right (a window) around a few walls and furniture, released, so the selection shows its grips; then a mouse hover (`tester.createGesture(kind: PointerDeviceKind.mouse)`, `addPointer`, `moveTo`) over one more entity; `pump`; `shoot`.
- **R4** `selection_band.png`: light; a mouse drag right to left (a crossing band), held: `startGesture`, `moveTo`, `pump`, `shoot`, `up`.
- **R5** `symbol_gallery.png`, at `kPanel`: the furniture library loaded with `SymbolLibraryLoader(sources: const [furnitureSymbolSource])` (`await tester.runAsync(loader.load)`, then `loader.state as SymbolLibraryReady`), grouped as `SymbolPanel._ready` does (`symbol_panel.dart:227-275`):

```dart
final words = SymbolWords.english;
final groups = searchSymbols(library.entries, '', words);
final measurer = FlutterTextMeasurer();
final thumbnails = SymbolThumbnails(maxEntries: 128);
addTearDown(thumbnails.dispose); // if SymbolThumbnails has no dispose, drop this line
final gallery = SymbolGallery(
  categories: [
    for (final g in groups)
      GalleryCategory(
        id: g.category,
        name: words.category(g.category),
        symbols: [
          for (final e in g.symbols)
            GallerySymbol(
              id: symbolIdOf(e),
              label: words.name(e),
              thumbnailKey: symbolIdOf(e),
              thumbnailDocument: () => symbolThumbnailDocument(e, measurer),
            ),
        ],
      ),
  ],
  selectedId: null,
  enabled: true,
  onSelect: (_) {},
  thumbnails: thumbnails,
  foreground: const Color(0xFF1F1F1F),
  selectedForeground: const Color(0xFF0B57D0),
  cellColor: const Color(0xFFFFFFFF),
);
```

inside a `MaterialApp(home: Material(child: gallery))`; `settle` until the thumbnails have painted (pump rounds; there is no state to wait on, so forty rounds and an eyes-on check).

- [ ] **Step 3: Run without writing**, then **generate and look**, as Task 3 Steps 2–3, for the five files.

- [ ] **Step 4: Measure** as Task 3 Step 4 (one ratio for both packages: if the renderer's files force 1.0, regenerate the planner's too and say so).

- [ ] **Step 5: Gate and commit.** `flutter test`, `flutter analyze`, format in `tool/screenshots`; commit the stage, the test and the five PNGs: `git commit -m "feat(tool): the renderer's five scenes and their screenshots"`.

---

