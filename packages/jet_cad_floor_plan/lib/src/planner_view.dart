import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'camera_bounds.dart';
import 'text_entry_overlay.dart';

/// The rulers around the drawing area: a [RulerFrame] whose child is a
/// [CameraGestureDetector] over the page chrome, the [DraftCanvas] and the
/// selection overlay, with -- since 05 -- the text tool's inline field
/// painted above it. Without [rulers] (the selection mode) the drawing area
/// stands alone.
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
    required this.chrome,
    required this.paper,
    this.sheetArgb,
    this.grips,
    this.textTool,
    this.fitRequests,
    this.fitOnStart = true,
    this.startFitIsRequest = false,
    this.onFitted,
    this.framing,
    this.underlay,
    this.overlay,
    this.tableOverlays,
    this.rulers = true,
    this.grid = true,
    this.cameraEpoch,
    this.userCamera = true,
    this.onCanvasPlaced,
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

  /// The rulers' and the sheet edge's colours, from the host's theme (dark
  /// theme spec D2, D5): the shell and the service view compute it in
  /// `build`, so a theme switch hands a new one down.
  final ChromePalette chrome;

  /// The colours of everything drawn on the paper -- the grid, the page
  /// breaks, the selection and the tools' overlays -- picked by the paper
  /// (dark theme spec D3, D4): the page's background, or the theme's
  /// surface with no page.
  final PaperPalette paper;

  /// The sheet's fill when the canvas shows a paper other than the page's
  /// ([kDarkCanvasPaper] on a dark canvas, decision note K2); null fills it
  /// with the page's background.
  final int? sheetArgb;

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

  /// Whether the fit on start ([fitOnStart]) performs only a host's
  /// request, which a camera command made before it drops (spec G-3);
  /// false for a plan's own first fit, which no command cancels (Task 2
  /// review R-1), nor a request merged into it, whose target the command
  /// clears.
  final bool startFitIsRequest;

  /// Called after each fit this view performs (review F-2).
  final VoidCallback? onFitted;

  /// The camera a fit sets at the drawing area's size, asked when the fit
  /// is performed (zone spec Z7); null from it, or no [framing], fits the
  /// page as before.
  final ViewportTransform? Function(Size size)? framing;

  /// Painted between the page chrome and the drafting (spec 14c S7): the
  /// selection mode's status fills, under the lines.
  final Widget? underlay;

  /// Painted above the drafting and below the selection overlay
  /// (table-groups spec G3, F-11): the selection mode's group label chips,
  /// which a chair's lines must not paint over. Null draws nothing there.
  final Widget? overlay;

  /// Painted above everything else on the canvas, the selection overlay
  /// included, and inside the canvas's input listeners, clipped to the
  /// canvas (host embedding API spec G-5): the host's widgets on the
  /// tables. Null draws nothing there.
  final Widget? tableOverlays;

  /// The rulers around the drawing area; false in the selection mode,
  /// which shows the plan, not the drafting aids.
  final bool rulers;

  /// The page's grid; false in the selection mode. The sheet stays.
  final bool grid;

  /// The host's camera epoch (host embedding API spec G-3): a fit captures
  /// it when it becomes due -- when it is scheduled, or, for the fit a view
  /// with no size yet owes, when the view is created or the request is
  /// heard (Task 2 review R-2) -- and is dropped when it has moved by the
  /// end of the frame, so a camera command made after a fit request wins.
  /// Null performs every fit, as before.
  final int Function()? cameraEpoch;

  /// Whether the user's pan, pinch and wheel zoom move the camera (spec
  /// G-3): false builds no [CameraGestureDetector]. Fits and the host's
  /// commands still act.
  final bool userCamera;

  /// Told, after every frame in which it moved or was resized, where the
  /// drawing area is in global coordinates (spec G-2), with this view's
  /// state as the reporter; told null once when the view is disposed, or
  /// when it is replaced by another reporter (Task 2 review R-8). The
  /// first report follows the view's first fit when it owes one (review
  /// R-3), so a reporter that moves the camera on it acts on the fitted
  /// camera. Null reports nothing.
  final void Function(Object view, Rect? global)? onCanvasPlaced;

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

  /// The plan's own first fit is still to be scheduled (Task 2 review
  /// R-1): no command cancels it, so it captures no epoch.
  late bool _ownFit = !_fitted && !widget.startFitIsRequest;

  /// The camera epoch when the fit the next sized layout performs became
  /// due (Task 2 review R-2): when this view was created owing a requested
  /// fit, or when a request came while it had no size. Read when the fit
  /// is scheduled, so a command made in between, while the view had no
  /// size, still wins. Unused for the plan's own first fit.
  int? _dueEpoch;

  /// A fit a layout scheduled and the end of the frame has not run yet:
  /// the first report waits for it (Task 2 review R-3).
  bool _fitAhead = false;

  @override
  void initState() {
    super.initState();
    if (!_ownFit && !_fitted) _dueEpoch = widget.cameraEpoch?.call();
    widget.fitRequests?.addListener(_onFitRequest);
    _watch();
  }

  @override
  void didUpdateWidget(PlannerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fitRequests != widget.fitRequests) {
      oldWidget.fitRequests?.removeListener(_onFitRequest);
      widget.fitRequests?.addListener(_onFitRequest);
    }
    // Task 2 review R-8: the reporter replaced while a rect is registered
    // with it is told the view is gone from it; the new one hears the rect
    // at the end of the frame.
    if (oldWidget.onCanvasPlaced != widget.onCanvasPlaced && _placed != null) {
      oldWidget.onCanvasPlaced?.call(this, null);
      _placed = null;
    }
    _watch();
  }

  @override
  void dispose() {
    widget.fitRequests?.removeListener(_onFitRequest);
    if (_placed != null) widget.onCanvasPlaced?.call(this, null);
    super.dispose();
  }

  void _onFitRequest() {
    if (_size == null) {
      // Not laid out yet: the first layout fits (review F-2), dropped if a
      // command comes before it (Task 2 review R-2).
      _fitted = false;
      if (!_ownFit) _dueEpoch = widget.cameraEpoch?.call();
      return;
    }
    // The size is read when the fit runs, after this frame's layout (zone
    // spec Z7): a request made with a layout change fits the new size. The
    // epoch is read now, when the fit is asked (spec G-3).
    final epoch = widget.cameraEpoch?.call();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fit(_size!, epoch));
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// Spec D4/D11: the [PlannerView.framing], else the page when there is
  /// one, at the drawing area's size -- inside the frame, so the bars are
  /// excluded -- clamped to the camera's zoom bounds about the drawing
  /// area's centre (host embedding API spec G-3). Dropped when the camera
  /// epoch moved since [epoch] was read: a later command has placed the
  /// camera.
  void _fit(Size size, int? epoch) {
    if (!mounted) return;
    if (epoch != null && widget.cameraEpoch?.call() != epoch) return;
    final page = widget.page.value;
    final camera = widget.camera;
    camera.value = clampCameraScale(
        widget.framing?.call(size) ??
            (page != null
                ? fitToPage(page, size)
                : ViewportTransform.fit(widget.document.extents, size)),
        size,
        minScale: camera.minScale,
        maxScale: camera.maxScale);
    widget.onFitted?.call();
  }

  // Spec G-2: the drawing area's global place, checked after every frame
  // while a reporter is given. A view moved by an ancestor without being
  // laid out again (a parent's padding) is seen too: no layout callback
  // would hear it. One `localToGlobal` per frame, nothing per entity.

  /// The drawing area's subtree: its render box is the canvas whose
  /// coordinates the camera's are. Global, so a [PlannerView.userCamera]
  /// switch moves it under or out of the gesture detector without
  /// remounting the interaction layer and the drafting.
  final GlobalKey _area = GlobalKey();

  /// The rect last reported; null before the first report.
  Rect? _placed;
  bool _watching = false;

  void _watch() {
    if (_watching || widget.onCanvasPlaced == null) return;
    _watching = true;
    WidgetsBinding.instance.addPostFrameCallback(_check);
  }

  void _check(Duration _) {
    if (!mounted || widget.onCanvasPlaced == null) {
      _watching = false;
      return;
    }
    // Task 2 review R-3: the first report waits for the first fit -- one
    // owed and not yet scheduled (no size yet), or scheduled and not yet
    // run, which reports itself after it runs.
    if (_placed != null || (_fitted && !_fitAhead)) _report();
    // Once per frame that happens: a post-frame callback asks for none.
    WidgetsBinding.instance.addPostFrameCallback(_check);
  }

  /// Reports the drawing area's global rect when it differs from the last
  /// one reported.
  void _report() {
    final reporter = widget.onCanvasPlaced;
    if (!mounted || reporter == null) return;
    final box = _area.currentContext?.findRenderObject();
    if (box is RenderBox && box.attached && box.hasSize) {
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect != _placed) {
        _placed = rect;
        reporter(this, rect);
      }
    }
  }

  late final Listenable _chromeRepaint =
      Listenable.merge([widget.camera, widget.page]);

  @override
  Widget build(BuildContext context) {
    final area = _drawingArea();
    return widget.rulers
        ? RulerFrame(
            camera: widget.camera,
            page: widget.page,
            chrome: widget.chrome,
            child: area,
          )
        : area;
  }

  Widget _drawingArea() => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.biggest.width > 0 && constraints.biggest.height > 0) {
            _size = constraints.biggest;
          }
          if (!_fitted &&
              constraints.biggest.width > 0 &&
              constraints.biggest.height > 0) {
            _fitted = true;
            final size = constraints.biggest;
            final epoch = _ownFit ? null : _dueEpoch;
            _ownFit = false;
            // Assigning `camera.value` during layout would notify the
            // zoom text's builder mid-build, which Flutter forbids
            // (Ruling 04-16). Posting it defers the notification to the
            // end of this frame: the first frame paints at the shell's
            // nominal fit, the second at the real size. The latch is set
            // synchronously, so the fit still happens exactly once
            // (Ruling 01-2).
            // The epoch is the one read when the fit became due (spec G-3,
            // Task 2 review R-2), none for the plan's own first fit (R-1);
            // the first report follows the fit (R-3).
            _fitAhead = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _fitAhead = false;
              _fit(size, epoch);
              _report();
            });
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
              _userCamera(KeyedSubtree(
                key: _area,
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
                              grid: widget.grid,
                              chrome: widget.chrome,
                              paper: widget.paper,
                              sheetArgb: widget.sheetArgb,
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
                      if (widget.overlay case final over?)
                        Positioned.fill(child: over),
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: SelectionOverlayPainter(
                              selection: widget.selection,
                              tools: widget.tools,
                              camera: widget.camera,
                              outlines: widget.outlines,
                              paper: widget.paper,
                              repaint: _repaint,
                            ),
                            size: Size.infinite,
                          ),
                        ),
                      ),
                      if (widget.tableOverlays case final layer?)
                        Positioned.fill(child: ClipRect(child: layer)),
                    ],
                  ),
                ),
              )),
            ],
          );
        },
      );

  /// [area] under the user's pan and zoom, or alone when the host locked
  /// them (spec G-3).
  Widget _userCamera(Widget area) => widget.userCamera
      ? CameraGestureDetector(
          camera: widget.camera, policy: widget.policy, child: area)
      : area;
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
