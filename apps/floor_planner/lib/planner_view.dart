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
    required this.page,
    required this.policy,
    required this.selection,
    required this.tools,
  });

  final DraftDocument document;
  final SpatialIndex index;
  final CameraController camera;
  final PageNotifier page;
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
  // The cache is in the merge because it is the only member that hears a
  // `DocChange`: an edit under a selected instance rebuilds the outline and
  // nothing else in here would ask for the frame that draws it.
  late final Listenable _repaint = Listenable.merge(
      [widget.selection, widget.tools, widget.camera, _outlines]);
  late final Listenable _chromeRepaint =
      Listenable.merge([widget.camera, widget.page]);

  @override
  void dispose() {
    _outlines.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RulerFrame(
        camera: widget.camera,
        page: widget.page,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (!_fitted &&
                constraints.biggest.width > 0 &&
                constraints.biggest.height > 0) {
              _fitted = true;
              final size = constraints.biggest;
              // `CameraController` is a `ValueNotifier` meant to drive paint
              // via a `RepaintBoundary`, not to rebuild widgets (its own
              // doc comment) -- but the zoom text (main.dart) does exactly
              // that, outside this subtree. Setting it synchronously here,
              // inside this `LayoutBuilder`'s own build, would notify that
              // widget while the framework is mid-build for a sibling
              // subtree, which throws. Posting it defers the notification to
              // just after this frame, still before the canvas underneath
              // has had a frame to listen on anything (Ruling 01-2).
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                final page = widget.page.value;
                // Spec D4/D11: the page when there is one, at the drawing
                // area's size — inside the frame, so the bars are excluded.
                widget.camera.value = page != null
                    ? fitToPage(page, size)
                    : ViewportTransform.fit(widget.document.extents, size);
              });
            }
            return CameraGestureDetector(
              camera: widget.camera,
              policy: widget.policy,
              child: InteractionLayer(
                tools: widget.tools,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: PageChromePainter(
                            camera: widget.camera,
                            page: widget.page,
                            repaint: _chromeRepaint,
                          ),
                        ),
                      ),
                    ),
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
        ),
      );
}
