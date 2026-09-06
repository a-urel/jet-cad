import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'camera_controller.dart';
import 'canvas_draw_sink.dart';
import 'vertices_draw_sink.dart';
import 'draft_painter.dart';
import 'flutter_text_measurer.dart';
import 'gpu/resident_rebuilder.dart';
import 'render_backend.dart';
import 'tile_cache.dart';

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

/// Re-fires the engine's table notifications as a Flutter [Listenable].
///
/// `package:jet_cad_2d` is pure Dart and declares its own two-method
/// `TableListenable` rather than depending on Flutter for one interface. This
/// is the single point where the two meet, and it exists because a table
/// mutation reaches the command system not at all: `TableSection.add`, `remove`
/// and `clear` emit no `DocChange`, so without this a layer edit causes no
/// frame and the tile cache's own invalidation — correct as it is — is never
/// reached.
///
/// **The source has no `dispose` and its listener list has no automatic
/// cleanup**, so unsubscribing is this adapter's entire responsibility, on
/// *both* teardown paths. `DraftCanvas` re-attaches its derived state whenever
/// a prop change demands it, and an adapter that only detached in `dispose`
/// would leave one dead listener on the document per re-attach, for the life
/// of the document. `DocumentTables.debugListenerCount` is what makes that
/// visible to a test.
class _TableListenableAdapter extends ChangeNotifier {
  _TableListenableAdapter(this.source) {
    source.addListener(_forward);
  }

  final TableListenable source;

  void _forward() => notifyListeners();

  @override
  void dispose() {
    source.removeListener(_forward);
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
    this.minTextCapPixels = kMinTextCapPixels,
    this.backend,
    this.tiles = false,
    this.tileDevicePixels = kTileDevicePixels,
    this.onPaintForTest,
    this.residentUploader,
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

  /// Forwarded to [DraftPainter.minTextCapPixels]. `0.0` disables level of
  /// detail, which is what the exit gate's control arm needs.
  final double minTextCapPixels;

  /// Which sink draws the frame, or `null` for [defaultRenderBackend].
  ///
  /// A non-null value is honoured on **every** platform, including
  /// `RenderBackend.vertices` on the web. It is not clamped: Plan 3d's Phase C
  /// forces it to measure CanvasKit, and a parameter that silently ignored
  /// what it was given would make that measurement report the wrong thing.
  final RenderBackend? backend;

  /// Whether the frame is drawn from cached tiles.
  ///
  /// Off by default: the cache is a pan-and-settle optimisation with a memory
  /// budget attached ([kTileCacheBytes]), and a canvas that never pans pays for
  /// it without collecting.
  ///
  /// **A consequence worth knowing, not a requirement:** with [tiles] on, the
  /// drawing sits up to half a device pixel from where it sits with [tiles]
  /// off. The tiled path quantises the camera to whole device pixels
  /// ([quantiseCamera]) so every tile lands on an exact texel boundary; the
  /// default path does not and never has. Toggling this flag on an otherwise
  /// static scene can therefore shift the drawing by that much.
  ///
  /// **Ignored on a `residentGpu` canvas.** No tile cache is built beside the
  /// resident backend ([DraftCanvasState.tileCache]'s own doc comment): both
  /// are gesture paths answering the same frame, and the resident one
  /// already holds the whole drawing.
  final bool tiles;

  /// Forwarded to [TileCache.tileDevicePixels]. Inert unless [tiles] is on.
  final int tileDevicePixels;

  /// **Test-only.** Called at the top of every paint.
  ///
  /// Counting frames is the only way to separate "invalidated correctly" from
  /// "was ever asked to", and those are exactly the two halves of a table edit:
  /// a revision read inside the paint can be right and unreachable.
  final void Function()? onPaintForTest;

  /// **Test-only.** Replaces the production uploader
  /// (`uploadResidentCollection`) on the `residentGpu` path, so a widget test
  /// can take that path without a GPU (Ruling F14). Not compared in
  /// [DraftCanvasState.didUpdateWidget]: a test that re-pumps the same canvas
  /// passes a fresh tear-off each time, and a re-attach on that alone would
  /// make "a resize does not rebuild" untestable.
  final ResidentUploader? residentUploader;

  @override
  State<DraftCanvas> createState() => DraftCanvasState();

  static bool _residentFallbackReported = false;

  /// How many times [_reportResidentFallback] has reported. **Test-only.**
  /// Zero or one: criterion 10 says once per process.
  static int debugResidentFallbackReports = 0;

  /// **Test-only.** Rearms the one-shot so the next fallback reports again.
  static void debugResetResidentFallbackReport() {
    _residentFallbackReported = false;
    debugResidentFallbackReports = 0;
  }

  /// The spec's "falls back to `VerticesDrawSink` and says so once" (Ruling
  /// F5). One `FlutterError.reportError` per process, whichever of the two
  /// fallbacks fires first: no GPU on this platform, or an upload that
  /// returned null. Observable through `FlutterError.onError` and
  /// [debugResidentFallbackReports]; never thrown.
  static void _reportResidentFallback(String message) {
    if (_residentFallbackReported) return;
    _residentFallbackReported = true;
    debugResidentFallbackReports++;
    FlutterError.reportError(FlutterErrorDetails(
        exception: FlutterError(message),
        library: 'jet_cad_2d_flutter',
        context:
            ErrorDescription('choosing the render backend for DraftCanvas')));
  }
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

  /// Non-null when [resolvedBackend] is [RenderBackend.vertices] or
  /// [RenderBackend.residentGpu] — the latter draws through this one before
  /// its first rebuild lands and after an upload fails (Ruling F5). Wraps
  /// [sink], which keeps taking every op the vertices sink does not batch.
  VerticesDrawSink? vertices;

  /// Non-null only while [DraftCanvas.tiles] is on.
  ///
  /// Public for the same reason [painter] is: a test that has to tell "the
  /// cache invalidated" from "the cache was never asked" needs to read the
  /// counters of the cache this widget actually built.
  TileCache? tileCache;

  /// Non-null exactly when [resolvedBackend] is [RenderBackend.residentGpu]:
  /// the rebuild schedule and the backend the frame paints through once one
  /// has landed. Public so a rig reads what actually rebuilt and when.
  ResidentRebuilder? resident;

  void _onResidentLanded() {
    final r = resident;
    if (r != null && r.uploadFailed) {
      DraftCanvas._reportResidentFallback(
          'DraftCanvas was asked for RenderBackend.residentGpu and the upload '
          'failed (ResidentGeometry.create returned null; its FlutterError, if '
          'any, is above this one). Drawing through VerticesDrawSink from now '
          'on. Reported once per process.');
    }
  }

  late DocChangeNotifier _changes;
  late _TableListenableAdapter _tables;
  late Listenable _repaint;

  /// Fires once per frame while the cache still owes tiles.
  ///
  /// Merged into [_repaint] beside the camera and the document, because it is
  /// the same kind of thing: a reason the canvas has to draw again.
  final _SettleNotifier _settle = _SettleNotifier();

  /// Whether a settle frame is already on the way.
  ///
  /// Without it every paint during a settle would queue its own callback and
  /// the queue would grow with the settle rather than staying one deep.
  bool _settleScheduled = false;

  /// Asks for one more frame, after this one finishes.
  ///
  /// **A post-frame callback, not a direct notify.** [_requestSettleFrame] is
  /// called from inside `paint`, and marking the tree dirty mid-paint is the
  /// error Flutter reports as "setState() or markNeedsBuild() called during
  /// build".
  ///
  /// Allocates one closure per settle frame -- O(1), and only while the cache
  /// owes tiles. A covered viewport allocates nothing, which is the state the
  /// frame-path allocation invariant measures.
  void _requestSettleFrame() {
    if (_settleScheduled || !mounted) return;
    _settleScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _settleScheduled = false;
      if (mounted) _settle.ping();
    });
  }

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
    final requested = widget.backend ?? defaultRenderBackend();
    resolvedBackend = resolveBackend(requested);
    if (requested == RenderBackend.residentGpu &&
        resolvedBackend != RenderBackend.residentGpu) {
      DraftCanvas._reportResidentFallback(
          'DraftCanvas was asked for RenderBackend.residentGpu, but this '
          'platform has no Flutter GPU (gpuAvailable() is false). Drawing '
          'through VerticesDrawSink instead. Reported once per process.');
    }
    // **`residentGpu` still builds the vertices sink** -- it is what draws
    // before the first rebuild lands and after an upload fails (Ruling F5).
    // `canvas` stays the one-`drawPath`-per-primitive fallback an explicit
    // `backend:` can still choose.
    vertices = resolvedBackend == RenderBackend.vertices ||
            resolvedBackend == RenderBackend.residentGpu
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
      minTextCapPixels: widget.minTextCapPixels,
    );
    resident = resolvedBackend == RenderBackend.residentGpu
        ? ResidentRebuilder(
            document: widget.document,
            painter: painter,
            uploader: widget.residentUploader ??
                (collection, viewport) => uploadResidentCollection(
                    collection, viewport,
                    measurer: measurer,
                    textStyleOf: widget.document.textStyleOf),
            pixelsPerPaperMm: widget.pixelsPerPaperMm,
            lineweightScale: widget.lineweightScale,
            measurer: measurer,
            textStyleOf: widget.document.textStyleOf)
        : null;
    resident?.addListener(_onResidentLanded);
    _tables = _TableListenableAdapter(widget.document.tables.changes);
    // **No tile cache beside the resident backend.** Both are gesture paths
    // and they answer the same frame; the resident one holds the whole
    // drawing and needs no tiles. `tiles: true` on a `residentGpu` canvas is
    // honoured by the fallback path only if the resident one never lands --
    // and it is not, deliberately: the cache would be built, invalidated
    // and never painted. Ignored, and said so here.
    tileCache = widget.tiles && resident == null
        ? TileCache(tileDevicePixels: widget.tileDevicePixels)
        : null;
    // The cache's derived state is updated before listeners run, for the
    // reason `DocChangeNotifier` gives: a listener repaints, and a repaint that
    // read the cache before `applyChange` had run would blit a tile the edit
    // already invalidated. The rebuilder is marked here too: every DocChange
    // subclass, `touched` unread (the spec's declared-equivalent mutation).
    _changes = DocChangeNotifier(widget.document, onChange: (change) {
      tileCache?.applyChange(change, widget.document);
      resident?.markDirty(RebuildTrigger.document);
    });
    // **The table adapter is here and not a nicety.** Without it a layer edit
    // causes no frame at all, so neither the cache's invalidation nor the
    // rebuilder's revision check is ever reached.
    _repaint = Listenable.merge([
      widget.camera,
      _changes,
      _tables,
      _settle,
      if (resident != null) resident!,
    ]);
  }

  /// Releases everything [_attach] built. Called from both teardown paths.
  ///
  /// One method rather than two lists: the `didUpdateWidget` path is the one
  /// that leaks silently — a missing `dispose` there costs a listener on the
  /// document and a set of `ui.Image`s per prop change, and nothing goes wrong
  /// until it has happened many times.
  void _detach() {
    _changes.dispose();
    _tables.dispose();
    resident?.removeListener(_onResidentLanded);
    resident?.dispose();
    resident = null;
    // A `ui.Image` holds native memory past its Dart object, and the cache
    // holds a viewport's worth of them.
    tileCache?.dispose();
    tileCache = null;
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
        widget.minTextCapPixels != oldWidget.minTextCapPixels ||
        widget.backend != oldWidget.backend ||
        widget.tiles != oldWidget.tiles ||
        widget.tileDevicePixels != oldWidget.tileDevicePixels) {
      // Guard before teardown: see the note on `_requireMeasurer`.
      _requireMeasurer();
      _detach();
      _attach();
    }
  }

  @override
  void dispose() {
    _detach();
    // Disposed here and not in `_detach`: the settle notifier belongs to the
    // state, not to one attachment, and survives a `didUpdateWidget` the way
    // the camera it sits beside in the merge does.
    _settle.dispose();
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
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    vertices?.devicePixelRatio = devicePixelRatio;
    return RepaintBoundary(
        child: CustomPaint(
      painter: _DraftCustomPainter(
        painter: painter,
        camera: widget.camera,
        sink: sink,
        vertices: vertices,
        tileCache: tileCache,
        resident: resident,
        document: widget.document,
        devicePixelRatio: devicePixelRatio,
        onPaintForTest: widget.onPaintForTest,
        onUnsettled: tileCache == null ? null : _requestSettleFrame,
        repaint: _repaint,
      ),
      size: Size.infinite,
    ));
  }
}

/// A [Listenable] the canvas pokes to ask itself for another frame.
class _SettleNotifier extends ChangeNotifier {
  void ping() => notifyListeners();
}

class _DraftCustomPainter extends CustomPainter {
  _DraftCustomPainter({
    required this.painter,
    required this.camera,
    required this.sink,
    required this.vertices,
    required this.tileCache,
    required this.resident,
    required this.document,
    required this.devicePixelRatio,
    required this.onPaintForTest,
    required this.onUnsettled,
    required super.repaint,
  });

  final DraftPainter painter;
  final CameraController camera;
  final CanvasDrawSink sink;

  /// Null unless the resolved backend is [RenderBackend.vertices] or
  /// [RenderBackend.residentGpu] — the latter's vertices sink is what a
  /// `residentGpu` canvas draws through before its first rebuild lands and
  /// after an upload fails (Ruling F5). See [DraftCanvas.backend].
  final VerticesDrawSink? vertices;

  /// Null unless [DraftCanvas.tiles] is on.
  final TileCache? tileCache;

  /// Non-null exactly when [resolvedBackend] is [RenderBackend.residentGpu].
  final ResidentRebuilder? resident;

  /// Read for `tables.mutationRevision` only. See [DraftCanvas.tiles].
  final DraftDocument document;

  final double devicePixelRatio;

  /// See [DraftCanvas.onPaintForTest].
  final void Function()? onPaintForTest;

  /// Called when a tiled frame ends owing another one.
  ///
  /// **Tiles still missing is not the only way to owe one**, and reading
  /// `viewportCovered` here was the zoom-blur defect: a frame that completed
  /// the settle still has the outgoing generation's composite blitted
  /// underneath it, and stopped the canvas one frame early. See
  /// [TileCache.settlePending].
  ///
  /// Null when [tileCache] is, because the untiled path finishes every frame it
  /// starts and has nothing to settle.
  final VoidCallback? onUnsettled;

  @override
  void paint(Canvas canvas, Size size) {
    onPaintForTest?.call();
    canvas.clipRect(Offset.zero & size);
    final resident = this.resident;
    if (resident != null) {
      // O(1), never walks: stores the frame's camera, viewport and dpr for
      // the next rebuild and fires the three frame-read triggers. The
      // table revision is pulled per frame for the reason the tiled branch
      // gives below -- a table mutation reaches no command and so no
      // `DocChange`.
      resident.noteFrame(camera.value, size, devicePixelRatio,
          document.tables.mutationRevision);
      final backend = resident.backend;
      if (backend != null) {
        backend.paint(canvas, camera.value, size, devicePixelRatio);
        return;
      }
      // Before the first landing, or after a failed upload: the vertices
      // path below, which is the drawing every `residentGpu` canvas made
      // before this plan (Ruling F5).
    }
    final cache = tileCache;
    if (cache != null) {
      cache.paintFrame(
        canvas: canvas,
        viewport: size,
        devicePixelRatio: devicePixelRatio,
        camera: camera.value,
        painter: painter,
        sink: sink,
        vertices: vertices,
        // Pulled per frame because a table mutation reaches no command and so
        // no `DocChange`; `applyChange` is never told about a layer edit.
        tablesRevision: document.tables.mutationRevision,
      );
      // The settle needs frames and nothing else will produce them once the
      // camera stops. Asked here rather than inside the cache: scheduling is
      // the widget layer's business, and `TileCache` has no binding to ask.
      if (cache.settlePending) onUnsettled?.call();
      return;
    }
    // **The camera is not quantised here, and the asymmetry is deliberate.**
    // `quantiseCamera` belongs to the tiled path and is applied inside
    // [TileCache.paintFrame] — once, covering both the blits and the live draw
    // over the uncovered region, so a tiled frame is internally consistent.
    // Applying it here as well would buy nothing: criterion 1's instrument
    // quantises its own live arm explicitly
    // (`test/support/tile_comparison.dart`), so the tiled-equals-live gate
    // never depended on this branch doing it. What it would cost is a change
    // to the **default** rendering path, which every caller with `tiles` off
    // uses — up to half a device pixel of global position, for nothing. This
    // branch draws what it drew before Plan 3g, pixel for pixel.
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

  /// False, except for the two resident-path facts a rebuild can carry that
  /// [repaint] itself has no way to see.
  ///
  /// `shouldRepaint` is asked on every rebuild, and a rebuild happens for
  /// reasons — a parent laying out, a theme change — that have nothing to do
  /// with the drawing having changed. Answering true there in general is what
  /// "repaint every vsync" looks like in Flutter's vocabulary, so this stays
  /// false except when [resident] is non-null and either the device pixel
  /// ratio or the rebuilder identity changed since the last build: those are
  /// exactly the two triggers [ResidentRebuilder.noteFrame] cannot detect on
  /// its own, because it is only ever told about a frame from inside `paint`,
  /// and this delegate's [repaint] listenable never fires for either of
  /// them by itself -- a device pixel ratio change carries no `DocChange`,
  /// no table mutation and no camera move, and a freshly re-attached
  /// rebuilder starts with no listener of its own wired into anything yet.
  /// Without this, a `residentGpu` canvas whose device pixel ratio changed,
  /// or whose rebuilder was just replaced by [DraftCanvasState.didUpdateWidget],
  /// would sit on a stale frame until some unrelated cause happened to repaint
  /// it.
  ///
  /// **The identity check runs even when [resident] is `null`.** A prop
  /// change that switches `backend:` AWAY from `residentGpu` mid-session
  /// makes a delegate whose own [resident] is `null` but whose [old]
  /// carried a non-null one; without comparing identities first, this would
  /// still answer `false` and leave the last GPU frame painted underneath
  /// the vertices or tile path that just took over, which is stale exactly
  /// the way a never-updated dpr or a freshly re-attached rebuilder is.
  @override
  bool shouldRepaint(_DraftCustomPainter old) {
    return old.resident != resident ||
        (resident != null && old.devicePixelRatio != devicePixelRatio);
  }
}
