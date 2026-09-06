### Task 2: The rebuilder — one schedule, five triggers, and the frame that never waits

**Files:**
- Create: `lib/src/gpu/resident_rebuilder.dart`
- Modify: `lib/src/gpu/gpu_facade.dart` (`debugSetGpuAvailable`)
- Modify: `lib/src/gpu/gpu_draw_backend.dart` (`implements ResidentFramePainter`, one line plus the import)
- Modify: `lib/jet_cad_2d_flutter.dart` (export)
- Create: `test/support/recording_frame_painter.dart`
- Test: `test/gpu/resident_rebuilder_test.dart`, `test/gpu/gpu_facade_test.dart` (one added test)

**Interfaces:**
- Consumes: `ResidentCollection.collect` (Task 1), `ResidentGeometry.create`,
  `GpuDrawBackend(geometry, collectionCamera, {measurer, textStyleOf})`,
  `SchedulerBinding.instance.addPostFrameCallback` / `ensureVisualUpdate`.
- Produces: everything in *"The rebuilder's contract"* above, plus
  `uploadResidentCollection(collection, viewport, {measurer, textStyleOf})`
  — the production `ResidentUploader` Task 3 wires — and, for tests,
  `RecordingFramePainter`, `FakeUploader`, `zoomedAbout`.

- [ ] **Step 1: The test seam in the facade, and its test**

Append to `lib/src/gpu/gpu_facade.dart`, after `debugSetGpuFactory`:

```dart
/// **Test seam.** Pins [gpuAvailable]'s cached answer; `null` clears it so
/// the next call probes again.
///
/// [debugSetGpuFactory] can only make the answer `false` -- a factory that
/// throws -- because no test can construct a `gpu.GpuContext`. A widget test
/// that wants `DraftCanvas` to take the `residentGpu` path GPU-free (Ruling
/// F14) needs the answer `true`, and this is the only honest way to say it:
/// the path it enables still cannot upload, so such a test also injects a
/// `ResidentUploader` that never touches a GPU.
void debugSetGpuAvailable(bool? available) {
  _available = available;
}
```

Add to `test/gpu/gpu_facade_test.dart`:

```dart
  test('debugSetGpuAvailable pins the answer, and null clears it', () {
    addTearDown(() => debugSetGpuAvailable(null));
    debugSetGpuAvailable(true);
    expect(gpuAvailable(), isTrue);
    debugSetGpuAvailable(false);
    expect(gpuAvailable(), isFalse);
    debugSetGpuAvailable(null);
    debugSetGpuFactory(() => throw StateError('no gpu'));
    addTearDown(() => debugSetGpuFactory(null));
    expect(gpuAvailable(), isFalse, reason: 'cleared: the factory probes');
  });
```

Run: `flutter test test/gpu/gpu_facade_test.dart` — PASS.

- [ ] **Step 2: The test support**

`test/support/recording_frame_painter.dart`:

```dart
import 'dart:async';
import 'dart:ui';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

/// A `ResidentFramePainter` that draws nothing and remembers being asked.
/// Stands in for `GpuDrawBackend`, which cannot be constructed without a
/// live GPU (`resident_geometry.dart`'s own doc comment on `create`).
class RecordingFramePainter implements ResidentFramePainter {
  RecordingFramePainter(this.collection);
  final ResidentCollection collection;
  int paints = 0;
  bool disposed = false;
  ViewportTransform? lastCamera;
  Size? lastViewport;
  double? lastDpr;

  @override
  void paint(Canvas canvas, ViewportTransform camera, Size viewport, double dpr) {
    paints++;
    lastCamera = camera;
    lastViewport = viewport;
    lastDpr = dpr;
  }

  @override
  void dispose() => disposed = true;
}

/// An uploader the test controls: hands back a [RecordingFramePainter] over
/// the collection it was given, or `null` while [failing]; [gate], when set,
/// holds the upload in flight until the test completes it.
class FakeUploader {
  bool failing = false;
  Completer<void>? gate;
  final List<ResidentCollection> collections = <ResidentCollection>[];
  final List<RecordingFramePainter> painters = <RecordingFramePainter>[];

  Future<ResidentFramePainter?> call(
      ResidentCollection collection, Size viewport) async {
    collections.add(collection);
    final g = gate;
    if (g != null) await g.future;
    if (failing) return null;
    final p = RecordingFramePainter(collection);
    painters.add(p);
    return p;
  }
}

/// [base] scaled by [s] about [centre], in screen space -- the same
/// composition `text_order_test.dart`'s `_scaled` uses.
ViewportTransform zoomedAbout(ViewportTransform base, Offset centre, double s) {
  final m = Transform2.translation(centre.dx, centre.dy)
      .multiply(Transform2.scale(s, s))
      .multiply(Transform2.translation(-centre.dx, -centre.dy))
      .multiply(base.worldToScreenMatrix);
  return ViewportTransform(worldToScreenMatrix: m);
}
```

- [ ] **Step 3: Write the failing rebuilder tests**

`test/gpu/resident_rebuilder_test.dart`:

```dart
import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/fixtures.dart';
import '../support/recording_frame_painter.dart';

void main() {
  late FlutterTextMeasurer measurer;
  late DraftDocument doc;
  late SpatialIndex index;
  late DraftPainter painter;
  late FakeUploader uploader;
  late ResidentRebuilder r;
  const centre = Offset(400, 300);

  setUp(() {
    measurer = FlutterTextMeasurer();
    doc = textOverlapFixture(measurer);
    index = SpatialIndex(doc);
    painter = DraftPainter(
        document: doc,
        index: index,
        resolver: DocumentStyleResolver(doc),
        minTextCapPixels: 0);
    uploader = FakeUploader();
    r = ResidentRebuilder(
        document: doc,
        painter: painter,
        uploader: uploader.call,
        pixelsPerPaperMm: kLogicalPixelsPerMm,
        lineweightScale: 1.0,
        measurer: measurer,
        textStyleOf: doc.textStyleOf);
  });
  tearDown(() {
    r.dispose();
    index.dispose();
    measurer.clear();
  });

  ViewportTransform fit() => ViewportTransform.fit(doc.extents, kViewport);
  int rev() => doc.tables.mutationRevision;

  /// The post-frame callback fires at the end of the first pump; the fake
  /// upload completes in a microtask; the second pump is the frame the
  /// landing asked for.
  Future<void> land(WidgetTester t) async {
    await t.pump();
    await t.pump();
  }

  testWidgets('the first frame marks initial and does not walk; the post-frame '
      'callback does', (t) async {
    r.noteFrame(fit(), kViewport, 1.0, rev());
    expect(r.pending, RebuildTrigger.initial);
    // MUTATION (M-F7): walk inside noteFrame -> rebuilds is already 1 here.
    expect(r.rebuilds, 0, reason: 'noteFrame never walks (Ruling F3)');
    expect(r.backend, isNull);
    await land(t);
    expect(r.rebuilds, 1);
    expect(r.landed, 1);
    expect(r.backend, isA<RecordingFramePainter>());
    expect(r.collection!.texts.length, 4);
    expect(r.pending, isNull);
    expect(r.lastTrigger, RebuildTrigger.initial);
    expect(r.lastTotalMicros, greaterThan(0));
  });

  testWidgets('three marks before the frame ends are one rebuild, named for '
      'the first', (t) async {
    r.noteFrame(fit(), kViewport, 1.0, rev());
    await land(t);
    r.markDirty(RebuildTrigger.document);
    r.markDirty(RebuildTrigger.band);
    r.markDirty(RebuildTrigger.tables);
    expect(r.pending, RebuildTrigger.document);
    await land(t);
    // MUTATION (M-F6): schedule a callback per markDirty -> rebuilds is 4.
    expect(r.rebuilds, 2);
    expect(r.lastTrigger, RebuildTrigger.document);
  });

  testWidgets('a mark during an upload in flight queues exactly one more',
      (t) async {
    r.noteFrame(fit(), kViewport, 1.0, rev());
    await land(t);
    uploader.gate = Completer<void>();
    r.markDirty(RebuildTrigger.document);
    await t.pump();
    expect(r.inFlight, isTrue);
    expect(r.rebuilds, 2);
    r.markDirty(RebuildTrigger.tables);
    r.markDirty(RebuildTrigger.tables);
    expect(r.pending, RebuildTrigger.tables);
    uploader.gate!.complete();
    uploader.gate = null;
    await land(t);
    await land(t);
    // MUTATION (M-F13): drop the reschedule at the end of _run -> rebuilds 2.
    expect(r.rebuilds, 3);
    expect(r.landed, 3);
    expect(r.inFlight, isFalse);
    expect(r.pending, isNull);
    expect(uploader.painters[1].disposed, isTrue,
        reason: 'the superseded backend is disposed on the swap');
    expect(identical(r.backend, uploader.painters[2]), isTrue);
  });

  testWidgets('the band is read as live over collection', (t) async {
    final base = fit();
    r.noteFrame(base, kViewport, 1.0, rev());
    await land(t);
    for (final s in const [0.5, 0.8, 1.0, 1.6, 2.0]) {
      r.noteFrame(zoomedAbout(base, centre, s), kViewport, 1.0, rev());
      expect(r.pending, isNull, reason: 'ratio $s is inside [0.5, 2.0]');
    }
    expect(r.bandStaleFrames, 0);
    r.noteFrame(zoomedAbout(base, centre, 2.01), kViewport, 1.0, rev());
    // MUTATION (M-F3): ratio = collection.scale / collection.scale -> never.
    expect(r.pending, RebuildTrigger.band);
    await land(t);
    expect(r.rebuilds, 2);
    expect(r.lastTrigger, RebuildTrigger.band);
    // The new collection is at 2.01x. 1.1 / 2.01 = 0.547 is inside its band
    // (not 1.005: that is 0.5 exactly in real numbers and a coin toss in
    // doubles); 0.98 / 2.01 = 0.488 is outside.
    r.noteFrame(zoomedAbout(base, centre, 1.1), kViewport, 1.0, rev());
    expect(r.pending, isNull);
    r.noteFrame(zoomedAbout(base, centre, 0.98), kViewport, 1.0, rev());
    expect(r.pending, RebuildTrigger.band);
    expect(r.bandStaleFrames, 2, reason: 'the 2.01 frame and the 0.98 frame');
  });

  testWidgets('the table revision counter triggers a rebuild, and the new '
      'collection carries the new revision', (t) async {
    r.noteFrame(fit(), kViewport, 1.0, rev());
    await land(t);
    final before = rev();
    final zero = doc.tables.layers[ReservedHandles.layerZero]!;
    doc.tables.layers.remove(zero.handle);
    doc.tables.layers.add(LayerRecord(
        handle: zero.handle,
        name: zero.name,
        color: const IndexedColor(1),
        linetype: zero.linetype,
        lineweight: zero.lineweight,
        transparency: zero.transparency,
        visible: zero.visible,
        locked: zero.locked));
    expect(rev(), greaterThan(before));
    r.noteFrame(fit(), kViewport, 1.0, rev());
    // MUTATION (M-F1): drop the revision comparison -> pending stays null.
    expect(r.pending, RebuildTrigger.tables);
    await land(t);
    expect(r.collection!.tablesRevision, rev());
    r.noteFrame(fit(), kViewport, 1.0, rev());
    expect(r.pending, isNull, reason: 'settled: no second rebuild');
  });

  testWidgets('a device pixel ratio change triggers a rebuild whose half-widths '
      'follow it', (t) async {
    r.noteFrame(fit(), kViewport, 1.0, rev());
    await land(t);
    final one = r.collection!;
    r.noteFrame(fit(), kViewport, 2.0, rev());
    // MUTATION (M-F2): drop the dpr comparison -> pending stays null.
    expect(r.pending, RebuildTrigger.devicePixelRatio);
    await land(t);
    final two = r.collection!;
    expect(two.devicePixelRatio, 2.0);
    // Same instance count, wider strokes: the same test Task 1 makes, on the
    // rebuilder's own output.
    expect(two.instanceCount, one.instanceCount);
    var wOne = 0.0, wTwo = 0.0;
    for (var i = 0; i < one.instanceCount; i++) {
      final o = i * 16 + 1; // InstanceFieldOffset.halfWidth, kFloatsPerInstance
      if (one.data[o] > wOne) wOne = one.data[o];
      if (two.data[o] > wTwo) wTwo = two.data[o];
    }
    expect(wTwo, closeTo(2 * wOne, 1e-3));
  });

  testWidgets('an edited label draws the new string: the text list is not '
      'stale across a rebuild', (t) async {
    r.noteFrame(fit(), kViewport, 1.0, rev());
    await land(t);
    expect(r.collection!.texts.map((x) => x.text), contains('COVERED'));
    doc.commands.execute(SetEntityTextCommand(const Handle(901), 'EDITED', ''));
    r.markDirty(RebuildTrigger.document);
    await land(t);
    // MUTATION (M-F4): hand the previous collection's texts to the new one
    // -> 'COVERED' survives and 'EDITED' never appears.
    final texts = r.collection!.texts.map((x) => x.text).toList();
    expect(texts, contains('EDITED'));
    expect(texts, isNot(contains('COVERED')));
    expect(identical(r.backend, uploader.painters.last), isTrue);
    expect(uploader.painters.last.collection.texts.map((x) => x.text),
        contains('EDITED'),
        reason: 'the backend was built from the new collection');
  });

  testWidgets('a failed upload falls back for good: no backend, no retry',
      (t) async {
    uploader.failing = true;
    r.noteFrame(fit(), kViewport, 1.0, rev());
    await land(t);
    expect(r.landed, 1);
    expect(r.backend, isNull);
    expect(r.uploadFailed, isTrue);
    r.markDirty(RebuildTrigger.document);
    r.noteFrame(zoomedAbout(fit(), centre, 3.0), kViewport, 1.0, rev());
    await land(t);
    expect(r.rebuilds, 1, reason: 'criterion 10: fall back once, not per frame');
    expect(r.pending, isNull);
  });

  testWidgets('a painter that lands after dispose is disposed, not installed',
      (t) async {
    r.noteFrame(fit(), kViewport, 1.0, rev());
    uploader.gate = Completer<void>();
    await t.pump();
    expect(r.inFlight, isTrue);
    r.dispose();
    uploader.gate!.complete();
    uploader.gate = null;
    await t.pump();
    await t.pump();
    expect(uploader.painters.single.disposed, isTrue);
    expect(r.backend, isNull);
    expect(r.landed, 0);
    // tearDown disposes again; ChangeNotifier tolerates it only if we do not
    // notify after dispose -- which the assertion above already proves.
  });
}
```

`tearDown`'s second `r.dispose()` on an already-disposed notifier: guard
`dispose` with `if (_disposed) return;` (in the implementation below) so this
file's last test does not throw in teardown.

- [ ] **Step 4: Run to verify they fail**

Run: `flutter test test/gpu/resident_rebuilder_test.dart`
Expected: FAIL — `ResidentRebuilder`, `ResidentFramePainter` undefined.

- [ ] **Step 5: The rebuilder**

`lib/src/gpu/resident_rebuilder.dart`:

```dart
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
  void paint(Canvas canvas, ViewportTransform camera, Size viewport, double dpr);
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
```

In `lib/src/gpu/gpu_draw_backend.dart`: `import 'resident_rebuilder.dart'
show ResidentFramePainter;` and `class GpuDrawBackend implements
ResidentFramePainter {`. Its existing `paint` and `dispose` already have the
interface's signatures; add `@override` to both.

Export from `lib/jet_cad_2d_flutter.dart`: `export
'src/gpu/resident_rebuilder.dart';`.

- [ ] **Step 6: Run; expect PASS**

Run: `flutter test test/gpu/resident_rebuilder_test.dart test/gpu/gpu_facade_test.dart`

- [ ] **Step 7: Gates, commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git status --short
git add lib/src/gpu/resident_rebuilder.dart lib/src/gpu/gpu_facade.dart lib/src/gpu/gpu_draw_backend.dart lib/jet_cad_2d_flutter.dart test/support/recording_frame_painter.dart test/gpu/resident_rebuilder_test.dart test/gpu/gpu_facade_test.dart
git commit -m "feat(gpu): the resident rebuilder -- one schedule, five triggers, and a frame that never waits"
```

---
