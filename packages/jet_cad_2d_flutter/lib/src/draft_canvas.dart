import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'camera_controller.dart';
import 'canvas_draw_sink.dart';
import 'draft_painter.dart';
import 'flutter_text_measurer.dart';

/// Logical pixels per millimetre at Flutter's nominal 96 dpi.
///
/// A lineweight is a paper quantity and needs a paper-to-screen scale to
/// become pixels. This is the honest default and nothing more: a drawing shown
/// at a real plot scale, or on a display whose physical size is known, wants
/// its own number, and choosing one belongs to whichever plan adds plotting.
const double kLogicalPixelsPerMm = 96.0 / 25.4;

/// Bridges the document's asynchronous change stream to a [Listenable].
///
/// Async is correct here and would be wrong for the index. [SpatialIndex] owns
/// the synchronous `commands.onAfterMutate` hook because a query issued in the
/// same turn as an edit must see the edit. A repaint happens on a later frame
/// by construction, so a microtask's delay changes nothing — and that hook is
/// a single slot, so taking it would disable the index outright.
class DocChangeNotifier extends ChangeNotifier {
  DocChangeNotifier(this.document, {this.onChange}) {
    _sub = document.changes.listen((change) {
      // Derived state first, listeners second. A listener repaints, and a
      // repaint reads the map; notifying first would draw one frame against a
      // map that does not know about the edit yet.
      onChange?.call(change);
      notifyListeners();
    });
  }

  final DraftDocument document;
  final void Function(DocChange change)? onChange;
  late final StreamSubscription<DocChange> _sub;

  @override
  void dispose() {
    unawaited(_sub.cancel());
    super.dispose();
  }
}

/// Draws a document, repainting on camera and document changes and on nothing
/// else.
///
/// The document, the index and the camera are all borrowed. Two canvases over
/// one document is the split-view case, so none of the three is disposed here.
class DraftCanvas extends StatefulWidget {
  const DraftCanvas({
    super.key,
    required this.document,
    required this.index,
    required this.camera,
    this.resolver,
    this.pixelsPerPaperMm = kLogicalPixelsPerMm,
    this.lineweightScale = 1.0,
  });

  final DraftDocument document;
  final SpatialIndex index;
  final CameraController camera;

  /// Defaults to a [DocumentStyleResolver] over [document]; supplied only when
  /// something wants to memoise or override resolution.
  final StyleResolver? resolver;

  final double pixelsPerPaperMm;

  /// Forwarded to [CanvasDrawSink.lineweightScale]. Measurement-only, for
  /// Task 4c's fill-rate experiment; inert at its default of 1.0.
  final double lineweightScale;

  @override
  State<DraftCanvas> createState() => DraftCanvasState();
}

/// Public so a test — or a tool that needs the painter's counters — can reach
/// the derived state this widget owns.
class DraftCanvasState extends State<DraftCanvas> {
  late DraftPainter painter;

  /// One sink for the life of the widget, its `Canvas` rebound per paint.
  late CanvasDrawSink sink;

  /// Outlives [sink]: a prop change [_attach] reacts to rebuilds the sink,
  /// not the paragraph cache behind it, so a document swap does not throw
  /// away every glyph already laid out for the previous one.
  late final FlutterTextMeasurer _measurer = FlutterTextMeasurer();

  late DocChangeNotifier _changes;
  late Listenable _repaint;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    sink = CanvasDrawSink(
        pixelsPerPaperMm: widget.pixelsPerPaperMm,
        lineweightScale: widget.lineweightScale,
        measurer: _measurer,
        textStyleOf: widget.document.textStyleOf);
    painter = DraftPainter(
      document: widget.document,
      index: widget.index,
      resolver: widget.resolver ?? DocumentStyleResolver(widget.document),
    );
    // No derived state left to update before listeners run: the map that
    // needed it was the cull floor's, and the cull floor is gone.
    _changes = DocChangeNotifier(widget.document);
    _repaint = Listenable.merge([widget.camera, _changes]);
  }

  @override
  void didUpdateWidget(DraftCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.document != oldWidget.document ||
        widget.index != oldWidget.index ||
        widget.camera != oldWidget.camera ||
        widget.resolver != oldWidget.resolver ||
        widget.pixelsPerPaperMm != oldWidget.pixelsPerPaperMm ||
        widget.lineweightScale != oldWidget.lineweightScale) {
      _changes.dispose();
      _attach();
    }
  }

  @override
  void dispose() {
    _changes.dispose();
    // A `Paragraph` holds native glyph memory the garbage collector does not
    // know about; the widget that owns the cache has to release it rather
    // than let every entry outlive this state by however long the native
    // heap takes to notice nothing references it anymore.
    _measurer.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          painter: _DraftCustomPainter(
            painter: painter,
            camera: widget.camera,
            sink: sink,
            repaint: _repaint,
          ),
          size: Size.infinite,
        ),
      );
}

class _DraftCustomPainter extends CustomPainter {
  _DraftCustomPainter({
    required this.painter,
    required this.camera,
    required this.sink,
    required super.repaint,
  });

  final DraftPainter painter;
  final CameraController camera;
  final CanvasDrawSink sink;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    sink.canvas = canvas;
    painter.paint(sink, camera.value, size);
  }

  /// Always false: [repaint] is the only trigger.
  ///
  /// `shouldRepaint` is asked on every rebuild, and a rebuild happens for
  /// reasons — a parent laying out, a theme change — that have nothing to do
  /// with the drawing having changed. Answering true there is what "repaint
  /// every vsync" looks like in Flutter's vocabulary.
  @override
  bool shouldRepaint(_DraftCustomPainter old) => false;
}
