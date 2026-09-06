### Task 3: `DraftCanvas` takes the resident path — the five triggers, and the two that are not

**Files:**
- Modify: `lib/src/draft_canvas.dart`
- Modify: `lib/src/render_backend.dart` (doc comment only)
- Test: `test/gpu/draft_canvas_resident_test.dart`

**Interfaces:**
- Consumes: `ResidentRebuilder`, `uploadResidentCollection`, `RebuildTrigger`,
  `ResidentUploader` (Task 2); `debugSetGpuAvailable` (Task 2);
  `RecordingFramePainter`, `FakeUploader`, `zoomedAbout` (Task 2's support).
- Produces: `DraftCanvas.residentUploader` (test seam), `DraftCanvasState.resident`,
  the static latch `DraftCanvas.debugResidentFallbackReports` /
  `debugResetResidentFallbackReport()` (used by Task 4 and Task 8), and the
  behaviour Task 8's arm D measures.

- [ ] **Step 1: Write the failing tests**

`test/gpu/draft_canvas_resident_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/fixtures.dart';
import '../support/recording_frame_painter.dart';

const Size kCanvas = Size(400, 300);
const Offset kCentre = Offset(200, 150);

void main() {
  late FlutterTextMeasurer measurer;
  late DraftDocument doc;
  late SpatialIndex index;
  late CameraController camera;
  late FakeUploader uploader;
  var paints = 0;

  setUp(() {
    debugSetGpuAvailable(true);
    addTearDown(() => debugSetGpuAvailable(null));
    DraftCanvas.debugResetResidentFallbackReport();
    measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    doc = textOverlapFixture(measurer);
    index = SpatialIndex(doc);
    addTearDown(index.dispose);
    camera = CameraController(ViewportTransform.fit(doc.extents, kCanvas));
    addTearDown(camera.dispose);
    uploader = FakeUploader();
    paints = 0;
  });

  Widget wrap(Widget child, {double dpr = 1.0, Size size = kCanvas}) =>
      MediaQuery(
          data: MediaQueryData(devicePixelRatio: dpr),
          child: Directionality(
              textDirection: TextDirection.ltr,
              child: Center(
                  child: SizedBox(
                      width: size.width, height: size.height, child: child))));

  Widget canvas({double dpr = 1.0, Size size = kCanvas, bool tiles = false}) =>
      wrap(
          DraftCanvas(
              document: doc,
              index: index,
              camera: camera,
              backend: RenderBackend.residentGpu,
              minTextCapPixels: 0,
              tiles: tiles,
              residentUploader: uploader.call,
              onPaintForTest: () => paints++),
          dpr: dpr,
          size: size);

  DraftCanvasState state(WidgetTester t) =>
      t.state<DraftCanvasState>(find.byType(DraftCanvas));

  /// The post-frame callback fires at the end of the first pump, the fake
  /// upload completes in a microtask, the landing's notify is the second
  /// pump's frame.
  Future<void> land(WidgetTester t) async {
    await t.pump();
    await t.pump();
  }

  testWidgets('the first frame paints through vertices; the landed rebuild '
      'paints through the backend', (t) async {
    await t.pumpWidget(canvas());
    final s = state(t);
    expect(s.resolvedBackend, RenderBackend.residentGpu);
    expect(s.resident, isNotNull);
    expect(s.vertices, isNotNull,
        reason: 'the pre-Plan-F path is still built: it draws before the '
            'first landing (Ruling F5)');
    expect(s.tileCache, isNull);
    expect(paints, 1);
    expect(uploader.painters, isEmpty,
        reason: 'the first frame drew before any rebuild landed');
    expect(() => s.vertices!.canvas, returnsNormally,
        reason: 'the vertices sink is what drew the first frame');
    await land(t);
    final r = s.resident!;
    expect(r.landed, 1);
    expect(r.lastTrigger, RebuildTrigger.initial);
    final p = uploader.painters.single;
    expect(p.paints, greaterThanOrEqualTo(1),
        reason: 'the landing asked for a frame, and that frame went through '
            'the backend');
    expect(p.lastDpr, 1.0);
    expect(p.lastViewport, kCanvas);
    expect(uploader.collections.single.collectionCamera.scale,
        closeTo(camera.value.scale, 1e-12));
  });

  testWidgets('every DocChange is a rebuild; a pan and a resize are not',
      (t) async {
    await t.pumpWidget(canvas());
    await land(t);
    final r = state(t).resident!;
    expect(r.landed, 1);

    Future<void> expectRebuild(String what, void Function() fire) async {
      final before = r.landed;
      fire();
      await land(t);
      await t.pump();
      expect(r.landed, before + 1,
          reason: '$what must cause exactly one rebuild');
      expect(r.lastTrigger, RebuildTrigger.document);
    }

    Future<void> expectNoRebuild(
        String what, Future<void> Function() act) async {
      final before = r.landed;
      await act();
      await land(t);
      expect(r.landed, before, reason: '$what must not rebuild');
    }

    await expectRebuild('CommandApplied', () {
      addLine(doc, doc.rootHandle, doc.handleSeed.next(), 100, 100, 900, 700);
    });
    await expectRebuild('CommandUndone', doc.commands.undo);
    await expectRebuild('CommandRedone', doc.commands.redo);
    await expectRebuild('DocumentLoaded', doc.commands.notifyLoaded);
    await expectRebuild('DocumentPurged', doc.purge);
    await expectNoRebuild('a pan', () async {
      camera.panBy(const Offset(40, 0));
      await t.pump();
    });
    await expectNoRebuild('a resize', () async {
      await t.pumpWidget(canvas(size: const Size(500, 350)));
    });
    expect(uploader.painters.last.lastViewport, const Size(500, 350),
        reason: 'the resized frame still painted through the same backend');
    expect(paints, greaterThan(7));
  });

  testWidgets('a layer edit rebuilds, through the revision counter', (t) async {
    await t.pumpWidget(canvas());
    await land(t);
    final r = state(t).resident!;
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
    // The table listenable causes the frame; the frame's noteFrame reads the
    // counter (Ruling F4). MUTATION (M-F1): drop the comparison -> landed 1.
    await land(t);
    await t.pump();
    expect(r.landed, 2);
    expect(r.lastTrigger, RebuildTrigger.tables);
    expect(r.collection!.tablesRevision, doc.tables.mutationRevision);
  });

  testWidgets('a device pixel ratio change rebuilds, with the new ratio',
      (t) async {
    await t.pumpWidget(canvas(dpr: 1.0));
    await land(t);
    final r = state(t).resident!;
    await t.pumpWidget(canvas(dpr: 2.0));
    await land(t);
    // MUTATION (M-F2): drop the comparison -> landed 1, dpr still 1.0.
    expect(r.landed, 2);
    expect(r.lastTrigger, RebuildTrigger.devicePixelRatio);
    expect(r.collection!.devicePixelRatio, 2.0);
    expect(uploader.painters.last.lastDpr, 2.0);
  });

  testWidgets('leaving the band rebuilds at the live scale; staying inside '
      'does not', (t) async {
    await t.pumpWidget(canvas());
    await land(t);
    final r = state(t).resident!;
    camera.zoomAt(kCentre, 1.9);
    await land(t);
    expect(r.landed, 1, reason: '1.9 is inside [0.5, 2.0]');
    expect(r.bandStaleFrames, 0);
    camera.zoomAt(kCentre, 1.2); // 2.28 overall
    await land(t);
    await t.pump();
    // MUTATION (M-F3): ratio against the collection's own scale -> landed 1.
    expect(r.landed, 2);
    expect(r.lastTrigger, RebuildTrigger.band);
    expect(r.collection!.collectionCamera.scale,
        closeTo(camera.value.scale, 1e-12),
        reason: 'Ruling F1: the new reference scale is the live scale');
    expect(r.bandStaleFrames, greaterThanOrEqualTo(1),
        reason: 'the frame that fired the trigger was drawn out of band');
  });

  testWidgets('a re-attach replaces the rebuilder and leaves one table '
      'listener; an unmount leaves none', (t) async {
    await t.pumpWidget(canvas());
    await land(t);
    final first = state(t).resident!;
    expect(doc.tables.debugListenerCount, 1);
    await t.pumpWidget(canvas(tiles: true));
    final s = state(t);
    expect(first.disposed, isTrue);
    expect(s.resident, isNot(same(first)));
    expect(s.tileCache, isNull,
        reason: 'the resident path owns gestures; no tile cache beside it');
    expect(doc.tables.debugListenerCount, 1);
    await land(t);
    expect(s.resident!.landed, 1);
    final second = s.resident!;
    await t.pumpWidget(wrap(const SizedBox()));
    expect(second.disposed, isTrue);
    expect(doc.tables.debugListenerCount, 0);
    expect(uploader.painters.every((p) => p.disposed), isTrue,
        reason: 'every backend the canvas ever installed is disposed with it');
  });
}
```

`addLine(doc, owner, handle, x0, y0, x1, y1)` is `test/support/fixtures.dart:160`.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/gpu/draft_canvas_resident_test.dart`
Expected: FAIL — `residentUploader` is not a named parameter; `resident`
undefined.

- [ ] **Step 3: The widget**

In `lib/src/draft_canvas.dart`:

**Imports:** add `import 'gpu/resident_rebuilder.dart';`.

**The widget** gains one parameter and two statics:

```dart
  /// **Test-only.** Replaces the production uploader
  /// (`uploadResidentCollection`) on the `residentGpu` path, so a widget test
  /// can take that path without a GPU (Ruling F14). Not compared in
  /// [DraftCanvasState.didUpdateWidget]: a test that re-pumps the same canvas
  /// passes a fresh tear-off each time, and a re-attach on that alone would
  /// make "a resize does not rebuild" untestable.
  final ResidentUploader? residentUploader;
```

(constructor: `this.residentUploader,` after `this.onPaintForTest`), and on
the `DraftCanvas` class body:

```dart
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
        context: ErrorDescription('choosing the render backend for DraftCanvas')));
  }
```

**The state** gains a field and a listener:

```dart
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
```

**`_attach`** becomes:

```dart
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
```

**`_detach`** adds, before `tileCache?.dispose()`:

```dart
    resident?.removeListener(_onResidentLanded);
    resident?.dispose();
    resident = null;
```

**`build`** passes `resident: resident,` to `_DraftCustomPainter`, which
gains `required this.resident,` / `final ResidentRebuilder? resident;` and,
at the top of `paint`, right after `canvas.clipRect(Offset.zero & size);`:

```dart
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
```

**`didUpdateWidget`**: no change to the compared fields (`residentUploader`
is deliberately not compared — see its doc).

**`render_backend.dart`**: replace the paragraph beginning *"**Wiring a
GPU-resident sink into `DraftCanvas` is Plan F's work.**"* with:

```dart
  /// `DraftCanvas` builds a `ResidentRebuilder` for this value (Plan F):
  /// the document is collected over its whole extents at the live scale,
  /// rebuilt on the spec's five triggers and never on a pan, and painted
  /// through `GpuDrawBackend` once the first rebuild lands. Before that,
  /// and after an upload that fails, the canvas paints through
  /// `VerticesDrawSink` and says so once -- see
  /// `DraftCanvas.debugResidentFallbackReports`.
```

- [ ] **Step 4: Run; expect PASS. Run the whole suite: `draft_canvas_test.dart` must still pass unchanged**

Run: `flutter test test/gpu/draft_canvas_resident_test.dart test/draft_canvas_test.dart`

`draft_canvas_test.dart` never sets `debugSetGpuAvailable`, so its
`residentGpu` requests still resolve to `vertices` under `flutter test` and
its assertions hold as before.

- [ ] **Step 5: Gates, commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git status --short
git add lib/src/draft_canvas.dart lib/src/render_backend.dart test/gpu/draft_canvas_resident_test.dart
git commit -m "feat(gpu): DraftCanvas paints residentGpu through the rebuilder, on five triggers and no pan"
```

---

