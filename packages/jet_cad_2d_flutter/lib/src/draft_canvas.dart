import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'camera_controller.dart';
import 'canvas_draw_sink.dart';
import 'vertices_draw_sink.dart';
import 'draft_painter.dart';
import 'flutter_text_measurer.dart';
import 'render_backend.dart';

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
    this.drawText = true,
    this.backend,
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

  /// Forwarded to [DraftPainter.drawText]. Measurement-only, for Task 12's
  /// text rows; inert at its default of `true`.
  ///
  /// It is a widget property rather than something the rig reaches through
  /// [DraftCanvasState] because the painter is built in [_attach] and its
  /// `drawText` is final: a rig that wanted to flip it after the fact would
  /// have to rebuild the painter, and a rebuilt painter is a different frame.
  final bool drawText;

  /// Which sink draws the frame, or `null` for [defaultRenderBackend].
  ///
  /// A non-null value is honoured on **every** platform, including
  /// `RenderBackend.vertices` on the web. It is not clamped: Plan 3d's Phase C
  /// forces it to measure CanvasKit, and a parameter that silently ignored
  /// what it was given would make that measurement report the wrong thing.
  final RenderBackend? backend;

  @override
  State<DraftCanvas> createState() => DraftCanvasState();
}

/// Public so a test — or a tool that needs the painter's counters — can reach
/// the derived state this widget owns.
class DraftCanvasState extends State<DraftCanvas> {
  late DraftPainter painter;

  /// The backend this state actually built, resolved once in [_attach].
  ///
  /// Public so a rig reports what it measured rather than what it asked for.
  late RenderBackend resolvedBackend;

  /// One sink for the life of the widget, its `Canvas` rebound per paint.
  late CanvasDrawSink sink;

  /// Non-null only when [resolvedBackend] is [RenderBackend.vertices]. Wraps
  /// [sink], which keeps taking every op the vertices sink does not batch.
  VerticesDrawSink? vertices;

  late DocChangeNotifier _changes;
  late Listenable _repaint;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  /// The document owns the measurer; this widget borrows it. Refused
  /// unconditionally rather than only when `drawText` is on: a document whose
  /// boxes were computed from `TextMetrics.zero` is wrong whether or not
  /// glyphs are drawn, and a conditional guard would force `CanvasDrawSink` to
  /// hold a throwaway measurer for its typed field — the second cache coming
  /// back. Before Plan 3f this widget built its own, handed it to the sink
  /// only, and left the painter reading `document.textMeasurer`; a document
  /// assembled the ordinary way therefore drew no text and reported nothing.
  ///
  /// A separate method, and called before any teardown in [didUpdateWidget]:
  /// a prop change that swaps in a bad measurer must throw before `_changes`
  /// is disposed, or the widget's own `dispose()` disposes it a second time
  /// once the throw unwinds the build.
  FlutterTextMeasurer _requireMeasurer() {
    final measurer = widget.document.textMeasurer;
    if (measurer is! FlutterTextMeasurer) {
      throw ArgumentError.value(
          measurer,
          'document.textMeasurer',
          'DraftCanvas requires a FlutterTextMeasurer. Build the measurer '
              'first and pass it to the document:\n\n'
              '    final measurer = FlutterTextMeasurer();\n'
              '    final doc = DraftDocument.empty(measurer: measurer);\n');
    }
    return measurer;
  }

  void _attach() {
    final measurer = _requireMeasurer();
    sink = CanvasDrawSink(
        pixelsPerPaperMm: widget.pixelsPerPaperMm,
        lineweightScale: widget.lineweightScale,
        measurer: measurer,
        textStyleOf: widget.document.textStyleOf);
    resolvedBackend = widget.backend ?? defaultRenderBackend();
    vertices = resolvedBackend == RenderBackend.vertices
        ? VerticesDrawSink(
            pixelsPerPaperMm: widget.pixelsPerPaperMm,
            lineweightScale: widget.lineweightScale,
            fallback: sink)
        : null;
    painter = DraftPainter(
      document: widget.document,
      index: widget.index,
      resolver: widget.resolver ?? DocumentStyleResolver(widget.document),
      drawText: widget.drawText,
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
        widget.lineweightScale != oldWidget.lineweightScale ||
        widget.drawText != oldWidget.drawText ||
        widget.backend != oldWidget.backend) {
      // Guard before teardown: see the note on `_requireMeasurer`.
      _requireMeasurer();
      _changes.dispose();
      _attach();
    }
  }

  @override
  void dispose() {
    _changes.dispose();
    // The measurer is **not** disposed here. The document owns it, two canvases
    // over one document share it, and clearing on dispose would wipe the
    // sibling's cache along with every native `Paragraph` in it. The
    // application that constructed the measurer calls `clear()` when it retires
    // the document — the ordinary Dart contract for a native-resource holder.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Read here rather than in `_attach`: the ratio is inherited state, it
    // changes when the window moves between displays, and a sink that cached
    // it at construction would keep drawing an external monitor's line widths
    // after the window moved back to the built-in one.
    vertices?.devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    return RepaintBoundary(
        child: CustomPaint(
      painter: _DraftCustomPainter(
        painter: painter,
        camera: widget.camera,
        sink: sink,
        vertices: vertices,
        repaint: _repaint,
      ),
      size: Size.infinite,
    ));
  }
}

class _DraftCustomPainter extends CustomPainter {
  _DraftCustomPainter({
    required this.painter,
    required this.camera,
    required this.sink,
    required this.vertices,
    required super.repaint,
  });

  final DraftPainter painter;
  final CameraController camera;
  final CanvasDrawSink sink;

  /// Null unless the resolved backend is [RenderBackend.vertices].
  /// See [DraftCanvas.backend].
  final VerticesDrawSink? vertices;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    sink.canvas = canvas;
    final batching = vertices;
    if (batching == null) {
      painter.paint(sink, camera.value, size);
      return;
    }
    // The flush is here and not in the painter because it is a fact about this
    // sink, not about the walk: the painter hands ops to a `DrawSink` and has
    // no opinion on when one of them reaches the `Canvas`.
    batching.canvas = canvas;
    painter.paint(batching, camera.value, size);
    batching.flush();
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
