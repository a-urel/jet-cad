// A document drawn by the renderer's own `DraftCanvas` alone (package
// READMEs spec D5, umbrella A11): the kit pictures' stage, where a kit's
// parametric types are the subject and the renderer only paints them. No
// rulers, no toolbar, no page chrome: a plain light sheet.
import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

/// A chrome-free white canvas over [document], the camera fitted once to
/// [size] (the same logical size the scene is pumped at).
class DraftStage extends StatefulWidget {
  const DraftStage({
    super.key,
    required this.document,
    required this.size,
    this.padding = 500,
  });

  final DraftDocument document;

  /// The logical size the camera is fitted to; `pumpScene` must use it too.
  final Size size;

  /// Millimetres added on every side of the document before the fit.
  final double padding;

  @override
  State<DraftStage> createState() => _DraftStageState();
}

class _DraftStageState extends State<DraftStage> {
  late final SpatialIndex index = SpatialIndex(widget.document);
  late final CameraController camera = CameraController(ViewportTransform.fit(
      widget.document.extents.expandedBy(widget.padding), widget.size));
  late final StyleResolver resolver =
      canvasResolverFor(widget.document, paper: 0xFFFFFFFF, dark: false);

  @override
  void dispose() {
    camera.dispose();
    index.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xFFFFFFFF),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: DraftCanvas(
            document: widget.document,
            index: index,
            camera: camera,
            resolver: resolver,
          ),
        ),
      );
}
