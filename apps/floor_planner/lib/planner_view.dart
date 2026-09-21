import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

/// The drawing area: a [CameraGestureDetector] over a [DraftCanvas].
///
/// Tiles off, `backend` unset (spec D6): a floor plan is 500-5,000
/// entities, and the resident backend cannot run on web, which this product
/// targets. Neither is a default a later sub-project may flip without a
/// measurement.
class PlannerView extends StatefulWidget {
  const PlannerView({
    super.key,
    required this.document,
    required this.index,
    required this.camera,
    required this.policy,
    required this.selection,
    required this.tools,
  });

  final DraftDocument document;
  final SpatialIndex index;
  final CameraController camera;
  final GesturePolicy policy;
  final SelectionController selection;
  final ToolController tools;

  @override
  State<PlannerView> createState() => _PlannerViewState();
}

class _PlannerViewState extends State<PlannerView> {
  /// Ruling 01-2: the camera is fitted once, to the size the view really
  /// got, before the canvas under it has listened to anything.
  bool _fitted = false;

  // Constructed after the shell's `SelectionController` so it prunes dead
  // keys before this cache walks them (listener order on `document.changes`).
  late final OutlineCache _outlines =
      OutlineCache(widget.document, widget.selection);
  late final Listenable _repaint =
      Listenable.merge([widget.selection, widget.tools, widget.camera]);

  @override
  void dispose() {
    _outlines.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          if (!_fitted &&
              constraints.biggest.width > 0 &&
              constraints.biggest.height > 0) {
            _fitted = true;
            widget.camera.value = ViewportTransform.fit(
                widget.document.extents, constraints.biggest);
          }
          return CameraGestureDetector(
            camera: widget.camera,
            policy: widget.policy,
            child: InteractionLayer(
              tools: widget.tools,
              child: Stack(
                children: [
                  DraftCanvas(
                    document: widget.document,
                    index: widget.index,
                    camera: widget.camera,
                    tiles: false,
                  ), // already inside its own RepaintBoundary
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: SelectionOverlayPainter(
                          selection: widget.selection,
                          tools: widget.tools,
                          camera: widget.camera,
                          outlines: _outlines,
                          repaint: _repaint,
                        ),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
}
