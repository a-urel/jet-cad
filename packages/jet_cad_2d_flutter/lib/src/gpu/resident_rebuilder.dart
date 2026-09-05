import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Canvas, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';

import '../draft_painter.dart';
import '../flutter_text_measurer.dart';
import '../viewport_transform.dart';
import 'gpu_draw_backend.dart';
import 'resident_collection.dart';
import 'resident_geometry.dart';
import 'text_patches.dart';

/// Why a rebuild ran. The spec's five triggers, plus the first build.
///
/// [document] is every `DocChange` -- `CommandApplied`, `CommandUndone`,
/// `CommandRedone`, `DocumentLoaded`, `DocumentPurged` -- with `touched`
/// unread: the spec declares "rebuild only when `touched` is non-empty" an
/// equivalent mutation, and this enum does not distinguish the five.
enum RebuildTrigger { initial, document, tables, devicePixelRatio, band }

/// What the frame path paints through once a rebuild has landed.
///
/// `GpuDrawBackend` is the production implementation. Tests substitute a
/// recorder, because a `GpuDrawBackend` needs a `ResidentGeometry` and
/// `ResidentGeometry.create` needs a live GPU.
abstract interface class ResidentFramePainter {
  void paint(
      Canvas canvas, ViewportTransform camera, Size viewport, double dpr);
  void dispose();
}

/// Turns one collection into a frame painter, or `null` when it cannot.
typedef ResidentUploader = Future<ResidentFramePainter?> Function(
    ResidentCollection collection, Size viewport);

/// The production uploader: `ResidentGeometry.create`, then a
/// `GpuDrawBackend` over it. `null` when the platform has no GPU or the
/// upload failed -- `create` has already reported the failure through
/// `FlutterError.reportError` (its own doc comment), so nothing is reported
/// twice here.
///
/// [viewport] is the widget's logical size, the ceiling for the patch
/// targets; a `Size.zero` first layout still asks for a 1x1 ceiling rather
/// than a texture the driver refuses.
Future<ResidentFramePainter?> uploadResidentCollection(
  ResidentCollection collection,
  Size viewport, {
  required FlutterTextMeasurer measurer,
  required TextStyleRecord Function(Handle) textStyleOf,
}) async {
  final dpr = collection.devicePixelRatio;
  final geometry = await ResidentGeometry.create(
      collection.data, collection.instanceCount,
      texts: collection.texts,
      patches: collection.patches,
      devicePixelRatio: dpr,
      maxPatchWidth: math.max(1, (viewport.width * dpr).round()),
      maxPatchHeight: math.max(1, (viewport.height * dpr).round()));
  if (geometry == null) return null;
  return GpuDrawBackend(geometry, collection.collectionCamera,
      measurer: measurer, textStyleOf: textStyleOf);
}

/// Owns the resident backend's lifecycle for one `DraftCanvas` attachment:
/// when to rebuild, and what the frame paints through meanwhile.
///
/// **The frame never waits** (Ruling F3). [noteFrame] is O(1) and never
/// walks; [markDirty] records a reason and schedules ONE post-frame callback;
/// the callback walks and classifies (on the UI thread, after the frame's
/// paint has finished), awaits the upload, swaps [backend] in and notifies.
/// A trigger during the await queues exactly one more rebuild. The frame
/// that fires a trigger is drawn with the collection it has -- criterion 9's
/// stale interval, counted in [bandStaleFrames] for the band case.
///
/// **Once an upload returns `null` the rebuilder stops** ([uploadFailed]):
/// no backend, no retry, every later [markDirty] ignored. The widget paints
/// through `VerticesDrawSink` from then on and says so once (Ruling F5).
class ResidentRebuilder extends ChangeNotifier {
  ResidentRebuilder({
    required this.document,
    required this.painter,
    required this.uploader,
    required this.pixelsPerPaperMm,
    required this.lineweightScale,
    required this.measurer,
    required this.textStyleOf,
    this.bandLowerScale = kBandLowerScale,
    this.bandUpperScale = kBandUpperScale,
  });

  final DraftDocument document;

  /// The widget's own painter: its `drawText` and `minTextCapPixels` are the
  /// walk's. Reused across rebuilds, never rebuilt here.
  final DraftPainter painter;
  final ResidentUploader uploader;
  final double pixelsPerPaperMm;
  final double lineweightScale;
  final TextMeasurer? measurer;
  final TextStyleRecord Function(Handle)? textStyleOf;
  final double bandLowerScale;
  final double bandUpperScale;

  ResidentFramePainter? _backend;
  ResidentFramePainter? get backend => _backend;

  ResidentCollection? _collection;
  ResidentCollection? get collection => _collection;

  RebuildTrigger? _pending;
  RebuildTrigger? get pending => _pending;

  RebuildTrigger? _inFlightTrigger;
  bool get inFlight => _inFlightTrigger != null;

  bool _scheduled = false;
  bool _disposed = false;
  bool get disposed => _disposed;

  bool _uploadFailed = false;
  bool get uploadFailed => _uploadFailed;

  /// Walks started. Every walk lands ([landed]) unless [dispose] ran first.
  int rebuilds = 0;
  int landed = 0;

  /// Post-frame callbacks registered. One per coalesced rebuild; a value
  /// above [landed] means marks were not coalesced.
  int schedules = 0;

  /// Frames [noteFrame] saw with the camera outside the band -- drawn from
  /// a collection the band has already condemned. Criterion 9's number.
  int bandStaleFrames = 0;

  int lastWalkMicros = 0;
  int lastClassifyMicros = 0;
  int lastUploadMicros = 0;
  int lastTotalMicros = 0;
  RebuildTrigger? lastTrigger;

  ViewportTransform? _camera;
  Size? _viewport;
  double _dpr = 1.0;

  /// Every frame, before the draw. Stores the frame's camera, viewport and
  /// dpr for the next rebuild, then fires the three frame-read triggers in
  /// this order: no collection -> [RebuildTrigger.initial]; a table revision
  /// other than the collection's -> [RebuildTrigger.tables]; a dpr other
  /// than the collection's (exact `==`, a stored value) ->
  /// [RebuildTrigger.devicePixelRatio]; a camera outside the band ->
  /// [RebuildTrigger.band]. One reason per frame; they coalesce anyway.
  void noteFrame(
      ViewportTransform camera, Size viewport, double dpr, int tablesRevision) {
    _camera = camera;
    _viewport = viewport;
    _dpr = dpr;
    final c = _collection;
    if (c == null) {
      markDirty(RebuildTrigger.initial);
      return;
    }
    final banded = inBand(camera);
    if (!banded) bandStaleFrames++;
    if (tablesRevision != c.tablesRevision) {
      markDirty(RebuildTrigger.tables);
    } else if (dpr != c.devicePixelRatio) {
      markDirty(RebuildTrigger.devicePixelRatio);
    } else if (!banded) {
      markDirty(RebuildTrigger.band);
    }
  }

  /// Whether [camera]'s scale, over the collection's, is inside
  /// `[bandLowerScale, bandUpperScale]`. **Live over collection**, read
  /// every frame -- the spec's mutation is reading it against the reference
  /// scale, which makes every ratio 1. A geometric decision made with plain
  /// comparisons on a ratio; conservative by construction. False with no
  /// collection.
  bool inBand(ViewportTransform camera) {
    final c = _collection;
    if (c == null) return false;
    final ratio = camera.scale / c.collectionCamera.scale;
    return ratio >= bandLowerScale && ratio <= bandUpperScale;
  }

  /// Records [trigger] and schedules a rebuild after the current frame, if
  /// one is not already scheduled or in flight. The first reason wins the
  /// name. Ignored after [dispose] and after a failed upload.
  void markDirty(RebuildTrigger trigger) {
    if (_disposed || _uploadFailed) return;
    _pending ??= trigger;
    if (_inFlightTrigger != null || _scheduled) return;
    _schedule();
  }

  void _schedule() {
    _scheduled = true;
    schedules++;
    final binding = SchedulerBinding.instance;
    binding.addPostFrameCallback((_) {
      _scheduled = false;
      unawaited(_run());
    });
    // A DocChange arrives between frames; a post-frame callback needs a
    // frame to be post to. From inside a frame's paint this is a no-op
    // (`ensureVisualUpdate` returns during `persistentCallbacks`), which is
    // exactly right: the frame is already running and its end is the
    // callback's cue.
    binding.ensureVisualUpdate();
  }

  Future<void> _run() async {
    final trigger = _pending;
    final camera = _camera;
    final viewport = _viewport;
    // No frame has told us the camera yet: keep the reason, and the first
    // noteFrame marks again with a camera in hand.
    if (_disposed || trigger == null || camera == null || viewport == null) {
      return;
    }
    _pending = null;
    _inFlightTrigger = trigger;
    try {
      await rebuildNow(camera, viewport, _dpr, trigger);
    } finally {
      _inFlightTrigger = null;
    }
    if (!_disposed && _pending != null && !_uploadFailed) _schedule();
  }

  /// The walk, the classification, the upload, the swap. Public for the
  /// harness's trigger phases and the tests; the schedule calls it too.
  ///
  /// The walk and the classification run synchronously here (this is the
  /// post-frame callback's body, not a frame's); the upload is awaited. A
  /// painter that arrives after [dispose] is disposed and never installed.
  Future<void> rebuildNow(ViewportTransform camera, Size viewport, double dpr,
      RebuildTrigger trigger) async {
    rebuilds++;
    final total = Stopwatch()..start();
    final next = ResidentCollection.collect(
        document: document,
        painter: painter,
        live: camera,
        devicePixelRatio: dpr,
        pixelsPerPaperMm: pixelsPerPaperMm,
        lineweightScale: lineweightScale,
        measurer: measurer,
        textStyleOf: textStyleOf,
        bandLowerScale: bandLowerScale);
    final upload = Stopwatch()..start();
    final nextBackend = await uploader(next, viewport);
    upload.stop();
    total.stop();
    if (_disposed) {
      nextBackend?.dispose();
      return;
    }
    lastWalkMicros = next.walkMicros;
    lastClassifyMicros = next.classifyMicros;
    lastUploadMicros = upload.elapsedMicroseconds;
    lastTotalMicros = total.elapsedMicroseconds;
    lastTrigger = trigger;
    _collection = next;
    final old = _backend;
    _backend = nextBackend;
    old?.dispose();
    if (nextBackend == null) {
      _uploadFailed = true;
      _pending = null;
    }
    landed++;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _pending = null;
    _backend?.dispose();
    _backend = null;
    super.dispose();
  }
}
