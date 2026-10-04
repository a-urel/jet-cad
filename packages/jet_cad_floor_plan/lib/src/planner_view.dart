import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'text_entry_overlay.dart';

/// The rulers around the drawing area: a [RulerFrame] whose child is a
/// [CameraGestureDetector] over the page chrome, the [DraftCanvas] and the
/// selection overlay, with -- since 05 -- the text tool's inline field
/// painted above it.
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
    required this.resolver,
    required this.camera,
    required this.page,
    required this.policy,
    required this.selection,
    required this.tools,
    required this.outlines,
    this.grips,
    this.textTool,
    this.fitRequests,
    this.fitOnStart = true,
    this.onFitted,
    this.underlay,
  });

  final DraftDocument document;
  final SpatialIndex index;

  /// Owned by the shell, and replaced only when the paper's foreground
  /// changes: [DraftCanvas] rebuilds its painter when handed a different
  /// resolver (fix/post-07).
  final StyleResolver resolver;
  final CameraController camera;
  final PageNotifier page;
  final GesturePolicy policy;
  final SelectionController selection;
  final ToolController tools;

  /// Owned by the shell since 03 (spec D6).
  final OutlineCache outlines;

  /// The selection's grips. A member of the overlay's repaint merge; null
  /// where no grips show (the selection mode, spec 14b-2 H7).
  final GripCache? grips;

  /// The shell's text tool, whose inline field sits over the canvas
  /// (spec 05 D9); null where there is none (the selection mode).
  final TextTool? textTool;

  /// Each notification refits the camera as the first frame did, at the
  /// drawing area's last size (spec 14b-2 H8, `fitToView`).
  final Listenable? fitRequests;

  /// Whether the camera is fitted after the first frame (Ruling 01-2).
  /// False when the host hands over a camera it already placed: a mode
  /// switch keeps the pan and zoom (spec 14b-2 R-13).
  final bool fitOnStart;

  /// Called after each fit this view performs (review F-2).
  final VoidCallback? onFitted;

  /// Painted between the page chrome and the drafting (spec 14c S7): the
  /// selection mode's status fills, under the lines.
  final Widget? underlay;

  @override
  State<PlannerView> createState() => _PlannerViewState();
}

class _PlannerViewState extends State<PlannerView> {
  /// Ruling 01-2: the camera is fitted once, to the size the drawing area
  /// really got; since Plan 04 the fit lands at the end of the first frame
  /// (Ruling 04-16).
  late bool _fitted = !widget.fitOnStart;

  // The two caches are in the merge because they are the members that hear
  // a `DocChange`: an edit under a selected instance rebuilds the outline
  // and the grips, and nothing else in here would ask for the frame that
  // draws them.
  late final Listenable _repaint = Listenable.merge([
    widget.selection,
    widget.tools,
    widget.camera,
    widget.outlines,
    if (widget.grips != null) widget.grips,
  ]);

  /// The drawing area's size at the last layout, for a fit request.
  Size? _size;

  @override
  void initState() {
    super.initState();
    widget.fitRequests?.addListener(_onFitRequest);
  }

  @override
  void didUpdateWidget(PlannerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fitRequests != widget.fitRequests) {
      oldWidget.fitRequests?.removeListener(_onFitRequest);
      widget.fitRequests?.addListener(_onFitRequest);
    }
  }

  @override
  void dispose() {
    widget.fitRequests?.removeListener(_onFitRequest);
    super.dispose();
  }

  void _onFitRequest() {
    final size = _size;
    if (size == null) {
      // Not laid out yet: the first layout fits (review F-2).
      _fitted = false;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _fit(size));
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// Spec D4/D11: the page when there is one, at the drawing area's size --
  /// inside the frame, so the bars are excluded.
  void _fit(Size size) {
    if (!mounted) return;
    final page = widget.page.value;
    widget.camera.value = page != null
        ? fitToPage(page, size)
        : ViewportTransform.fit(widget.document.extents, size);
    widget.onFitted?.call();
  }

  late final Listenable _chromeRepaint =
      Listenable.merge([widget.camera, widget.page]);

  @override
  Widget build(BuildContext context) => RulerFrame(
        camera: widget.camera,
        page: widget.page,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.biggest.width > 0 &&
                constraints.biggest.height > 0) {
              _size = constraints.biggest;
            }
            if (!_fitted &&
                constraints.biggest.width > 0 &&
                constraints.biggest.height > 0) {
              _fitted = true;
              final size = constraints.biggest;
              // Assigning `camera.value` during layout would notify the
              // zoom text's builder mid-build, which Flutter forbids
              // (Ruling 04-16). Posting it defers the notification to the
              // end of this frame: the first frame paints at the shell's
              // nominal fit, the second at the real size. The latch is set
              // synchronously, so the fit still happens exactly once
              // (Ruling 01-2).
              WidgetsBinding.instance.addPostFrameCallback((_) => _fit(size));
            }
            // Spec 05 D9: the field sits outside the InteractionLayer, so a
            // click on it is not a canvas click.
            //
            // A `Flow`, not a `Stack`: the field paints and hit-tests above
            // the canvas (`_FieldAboveCanvas`), yet it is the first child,
            // so it leaves the tree first. The layer's `deactivate` cancels
            // the active tool; with a text pending, that notifies the
            // field's builders and its `EditableText`, which must already be
            // inactive, or Flutter asserts "markNeedsBuild() called during
            // build".
            return Flow(
              delegate: const _FieldAboveCanvas(),
              children: [
                if (widget.textTool case final text?)
                  TextEntryOverlay(
                    tool: text,
                    tools: widget.tools,
                    camera: widget.camera,
                  )
                else
                  const SizedBox.shrink(),
                CameraGestureDetector(
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
                        if (widget.underlay case final under?)
                          Positioned.fill(child: under),
                        DraftCanvas(
                          document: widget.document,
                          index: widget.index,
                          camera: widget.camera,
                          resolver: widget.resolver,
                          tiles: false,
                        ), // already inside its own RepaintBoundary
                        Positioned.fill(
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: SelectionOverlayPainter(
                                selection: widget.selection,
                                tools: widget.tools,
                                camera: widget.camera,
                                outlines: widget.outlines,
                                repaint: _repaint,
                              ),
                              size: Size.infinite,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
}

/// Paints child 1, the canvas, and then child 0, the text field, above it.
/// `RenderFlow` hit-tests in reverse paint order, so the field wins a hit on
/// itself, and an empty region falls through to the canvas.
class _FieldAboveCanvas extends FlowDelegate {
  const _FieldAboveCanvas();

  @override
  void paintChildren(FlowPaintingContext context) {
    context
      ..paintChild(1)
      ..paintChild(0);
  }

  @override
  bool shouldRepaint(_FieldAboveCanvas oldDelegate) => false;
}
