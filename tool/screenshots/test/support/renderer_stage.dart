// The renderer's widgets alone (spec D5 R1-R4): a ruler frame around an
// interaction layer over the page chrome, the canvas and the selection
// overlay, light or on the dark canvas.
import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

class RendererStage extends StatefulWidget {
  const RendererStage(
      {super.key,
      required this.document,
      required this.dark,
      required this.canvas});

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

  /// The selection's grips, after the outlines they derive from (as
  /// `PlannerShell` builds them, with no object provider: a group shows
  /// its outline and no grips).
  late final GripCache grips = GripCache(widget.document, selection, outlines);
  late final PageNotifier page = PageNotifier(widget.document);
  late final CameraController camera = CameraController(ViewportTransform.fit(
      widget.document.extents.expandedBy(500), widget.canvas));
  late final ToolController tools = ToolController(
      initial: SelectTool(),
      context: ToolContext(
          document: widget.document,
          index: index,
          camera: camera,
          selection: selection,
          grips: grips));

  @override
  void dispose() {
    tools.dispose();
    grips.dispose();
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
    final chrome = widget.dark ? ChromePalette.dark : ChromePalette.light;
    return ColoredBox(
      color: Color(paperArgb),
      child: RulerFrame(
        camera: camera,
        page: page,
        chrome: chrome,
        child: InteractionLayer(
          tools: tools,
          child: Stack(children: [
            Positioned.fill(
              child: CustomPaint(
                painter: PageChromePainter(
                  camera: camera,
                  page: page,
                  chrome: chrome,
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
                  repaint:
                      Listenable.merge([selection, tools, camera, outlines]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
