### Task 1: The collection frame, and the GPU-free product of a rebuild

**Files:**
- Create: `lib/src/gpu/collection_frame.dart`
- Create: `lib/src/gpu/resident_collection.dart`
- Modify: `lib/jet_cad_2d_flutter.dart` (two exports)
- Test: `test/gpu/collection_frame_test.dart`, `test/gpu/resident_collection_test.dart`

**Interfaces:**
- Consumes: `DraftPainter.paint(DrawSink, ViewportTransform, Size)`,
  `GeometryCollector` (Plan E's constructor with `measurer`/`textStyleOf`),
  `classifyTextPatches`, `ResidentGeometry.byteLengthFor`,
  `Aabb2.transformedBy`, `kScreenClipInflate` (`draft_painter.dart:50`),
  `composeTransforms` (`gpu_draw_backend.dart`).
- Produces: `CollectionFrame(camera, viewport)`, `collectionFrameFor(live,
  extents, {margin})`, `ResidentCollection` with the fields below and
  `ResidentCollection.collect({...})`. Task 2's rebuilder calls `collect`;
  Task 7's zoom rig calls `collectionFrameFor`.

- [ ] **Step 1: Write the failing tests for the frame**

`test/gpu/collection_frame_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

/// A drawing well away from the origin, and a live camera zoomed onto a
/// point far outside it: at [kLiveViewport] this camera sees NONE of the
/// extents, so a collection culled to the live viewport would be empty --
/// which is the mutation this file exists to kill.
const Aabb2 kExtents = Aabb2.raw(1000, 2000, 7000, 5000);
const Size kLiveViewport = Size(800, 600);
final ViewportTransform kLive = ViewportTransform(
    worldToScreenMatrix:
        const Transform2(3.2, 0, 0, -3.2, -20000.0, 30000.0));

void main() {
  test('the live camera at its own viewport sees none of the drawing', () {
    // Anti-vacuity for every test below.
    expect(kLive.visibleWorld(kLiveViewport).intersects(kExtents), isFalse);
  });

  test("the frame's visible world covers the extents", () {
    final f = collectionFrameFor(kLive, kExtents);
    final world = f.camera.visibleWorld(f.viewport);
    expect(world.minX, lessThanOrEqualTo(kExtents.minX));
    expect(world.minY, lessThanOrEqualTo(kExtents.minY));
    expect(world.maxX, greaterThanOrEqualTo(kExtents.maxX));
    expect(world.maxY, greaterThanOrEqualTo(kExtents.maxY));
  });

  test("scale and rotation are the live camera's; only the translation moves",
      () {
    final f = collectionFrameFor(kLive, kExtents);
    final c = f.camera.worldToScreenMatrix;
    final l = kLive.worldToScreenMatrix;
    expect(c.a, l.a);
    expect(c.b, l.b);
    expect(c.c, l.c);
    expect(c.d, l.d);
    final toLive = composeTransforms(l, c.invert());
    expect(toLive.a, closeTo(1, 1e-12));
    expect(toLive.b, closeTo(0, 1e-12));
    expect(toLive.c, closeTo(0, 1e-12));
    expect(toLive.d, closeTo(1, 1e-12));
    expect(toLive.e.abs() + toLive.f.abs(), greaterThan(1000),
        reason: 'the two cameras must actually differ, or the translation '
            'claim is vacuous');
  });

  test("the viewport is the extents' screen size plus the margin, all round",
      () {
    final f = collectionFrameFor(kLive, kExtents, margin: 10);
    expect(f.viewport.width, closeTo(6000 * 3.2 + 20, 1e-9));
    expect(f.viewport.height, closeTo(3000 * 3.2 + 20, 1e-9));
    // y is flipped, so the world's MAX y is the screen's min.
    final corner = f.camera.worldToScreen(Vector2(1000, 5000));
    expect(corner.x, closeTo(10, 1e-9));
    expect(corner.y, closeTo(10, 1e-9));
  });

  test('a rotated live camera keeps its rotation and still covers the extents',
      () {
    final rotated = ViewportTransform(
        worldToScreenMatrix: Transform2.translation(-9000, 400)
            .multiply(Transform2.rotation(0.4))
            .multiply(Transform2.scale(2.0, -2.0)));
    final f = collectionFrameFor(rotated, kExtents);
    expect(f.camera.worldToScreenMatrix.b, rotated.worldToScreenMatrix.b);
    expect(f.camera.worldToScreenMatrix.c, rotated.worldToScreenMatrix.c);
    final world = f.camera.visibleWorld(f.viewport);
    expect(world.minX, lessThanOrEqualTo(kExtents.minX));
    expect(world.maxY, greaterThanOrEqualTo(kExtents.maxY));
  });

  test('empty extents give the live camera back and a 1x1 viewport', () {
    final f = collectionFrameFor(kLive, Aabb2.empty());
    expect(identical(f.camera, kLive), isTrue);
    expect(f.viewport, const Size(1, 1));
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `cd packages/jet_cad_2d_flutter && flutter test test/gpu/collection_frame_test.dart`
Expected: FAIL — `collectionFrameFor` undefined.

- [ ] **Step 3: The frame**

`lib/src/gpu/collection_frame.dart`:

```dart
import 'dart:ui' show Size;

import 'package:jet_cad_2d/jet_cad_2d.dart';

import '../draft_painter.dart' show kScreenClipInflate;
import '../viewport_transform.dart';

/// The camera and viewport one rebuild walks under (Ruling F2).
///
/// [camera] has the live camera's scale and rotation and a translation that
/// puts the document's extents at the viewport's origin; [viewport] is the
/// extents' screen size plus a margin on every side. `DraftPainter.paint`
/// culls to `camera.visibleWorld(viewport)`, so under this pair nothing is
/// culled: a pan needs no rebuild, and neither does a viewport resize.
///
/// The two cameras differ by a pure translation, so
/// `composeTransforms(live, camera.invert())` is a translation and the
/// frame mapping `GpuDrawBackend.render` builds every frame is exact.
class CollectionFrame {
  const CollectionFrame(this.camera, this.viewport);
  final ViewportTransform camera;
  final Size viewport;
}

/// The frame a rebuild at [live] walks under, covering [extents].
///
/// [margin] defaults to the painter's own clip inflate so an entity on the
/// extents' edge, with its stroke width, is inside the frame; the painter
/// inflates its *clip* by the same amount but queries the index on the
/// un-inflated world rect, which is why the margin lives here.
///
/// **Float32 is the cost.** The buffer holds absolute frame coordinates,
/// bounded by the extents' size at the live scale: 1,350 px on the harness
/// floor at fit, 135,000 px at 100x (ulp 0.0078 px), 1.35 M px at 1000x
/// (ulp 0.125 px). Task 7's band sweep runs at a zoomed-in collection as
/// well as at fit, so the precision at a working scale is measured.
///
/// Empty extents -- an empty document -- give [live] back unchanged and a
/// 1x1 viewport: nothing to cover, nothing to shift, and a `Size.zero`
/// viewport would make `visibleWorld` degenerate.
CollectionFrame collectionFrameFor(ViewportTransform live, Aabb2 extents,
    {double margin = kScreenClipInflate}) {
  if (extents.isEmpty) return CollectionFrame(live, const Size(1, 1));
  final m = live.worldToScreenMatrix;
  final box = extents.transformedBy(Transform2(m.a, m.b, m.c, m.d, 0, 0));
  final camera = ViewportTransform(
      worldToScreenMatrix:
          Transform2(m.a, m.b, m.c, m.d, margin - box.minX, margin - box.minY));
  return CollectionFrame(
      camera,
      Size(box.maxX - box.minX + 2 * margin,
          box.maxY - box.minY + 2 * margin));
}
```

Add to `lib/jet_cad_2d_flutter.dart`, beside the other `src/gpu/` exports:

```dart
export 'src/gpu/collection_frame.dart';
export 'src/gpu/resident_collection.dart';
```

- [ ] **Step 4: Run the frame tests; expect PASS**

Run: `flutter test test/gpu/collection_frame_test.dart`

- [ ] **Step 5: Write the failing tests for the collection**

`test/gpu/resident_collection_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_flutter/src/gpu/instance_record.dart';

import '../support/fixtures.dart';

void main() {
  late FlutterTextMeasurer measurer;
  late DraftDocument doc;
  late SpatialIndex index;
  late DraftPainter painter;

  setUp(() {
    measurer = FlutterTextMeasurer();
    doc = textOverlapFixture(measurer);
    index = SpatialIndex(doc);
    // Level of detail OFF: this fixture's TINY label sits at the culling
    // threshold on purpose, and a scale-dependent cull would make two
    // collections at two scales differ for a reason that is not culling to
    // the viewport. Ruling F6 measures that divergence in its own test.
    painter = DraftPainter(
        document: doc,
        index: index,
        resolver: DocumentStyleResolver(doc),
        minTextCapPixels: 0);
  });
  tearDown(() {
    index.dispose();
    measurer.clear();
  });

  ResidentCollection collect(ViewportTransform live, {double dpr = 1.0}) =>
      ResidentCollection.collect(
          document: doc,
          painter: painter,
          live: live,
          devicePixelRatio: dpr,
          pixelsPerPaperMm: kLogicalPixelsPerMm,
          lineweightScale: 1.0,
          measurer: measurer,
          textStyleOf: doc.textStyleOf);

  ViewportTransform fit() => ViewportTransform.fit(doc.extents, kViewport);

  /// 8x the fit scale, with the drawing's top-left corner near the screen's
  /// origin: the live viewport sees roughly a sixty-fourth of the drawing.
  ViewportTransform corner() {
    final s = fit().scale * 8;
    final e = doc.extents;
    return ViewportTransform(
        worldToScreenMatrix:
            Transform2(s, 0, 0, -s, -s * e.minX + 5, s * e.maxY + 5));
  }

  test('the corner camera sees only part of the drawing', () {
    // Anti-vacuity for the test below.
    final vis = corner().visibleWorld(kViewport);
    expect(vis.intersects(doc.extents), isTrue);
    expect(vis.maxX < doc.extents.maxX || vis.minY > doc.extents.minY, isTrue,
        reason: 'the live viewport must see only part of the drawing, or '
            'culling to it would be invisible here');
  });

  test('a collection at the corner zoom holds everything the fit one holds',
      () {
    final a = collect(fit());
    final b = collect(corner());
    // MUTATION: collect under `live` and `kViewport` instead of the frame
    // -> b.instanceCount is a fraction of a.instanceCount, b.texts shorter.
    expect(b.instanceCount, a.instanceCount,
        reason: 'this fixture has no curve, so the instance count is scale-'
            'free; a difference is culling');
    expect(b.texts.map((t) => t.text), a.texts.map((t) => t.text));
    expect(a.instanceCount, greaterThan(5));
    expect(a.texts.length, 4, reason: 'COVERED, UNDER, GRAZED, TINY');
    expect(a.skippedOps, 0);
  });

  test('the collection camera differs from the live camera by a translation',
      () {
    final live = corner();
    final c = collect(live);
    final toLive = composeTransforms(
        live.worldToScreenMatrix, c.collectionCamera.worldToScreenMatrix.invert());
    expect(toLive.a, closeTo(1, 1e-12));
    expect(toLive.d, closeTo(1, 1e-12));
    expect(c.collectionCamera.scale, closeTo(live.scale, 1e-12));
    expect(c.collectionViewport.width, greaterThan(kViewport.width),
        reason: 'at 8x the extents are wider than the live viewport');
  });

  test('the table revision and the ratio are the ones the walk ran at', () {
    final before = doc.tables.mutationRevision;
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
    expect(doc.tables.mutationRevision, greaterThan(before));
    final c = collect(fit(), dpr: 2.0);
    expect(c.tablesRevision, doc.tables.mutationRevision);
    expect(c.devicePixelRatio, 2.0);
  });

  test('half-widths follow the device pixel ratio', () {
    double widest(ResidentCollection c) {
      var w = 0.0;
      for (var i = 0; i < c.instanceCount; i++) {
        final o = i * kFloatsPerInstance;
        if (c.data[o + InstanceFieldOffset.kind] != kKindStroke) continue;
        final h = c.data[o + InstanceFieldOffset.halfWidth];
        if (h > w) w = h;
      }
      return w;
    }
    final one = widest(collect(fit()));
    final two = widest(collect(fit(), dpr: 2.0));
    expect(one, greaterThan(GeometryCollector.kMinStrokeDevicePixels),
        reason: 'the widest stroke must be above the floor, or the floor '
            'clamps both and the ratio below is vacuous');
    expect(two, closeTo(2 * one, 1e-3));
  });

  test('the timings are read and the byte length counts the patches', () {
    final c = collect(fit());
    expect(c.walkMicros, greaterThanOrEqualTo(0));
    expect(c.classifyMicros, greaterThanOrEqualTo(0));
    expect(c.patches.length, 2, reason: 'COVERED and GRAZED (Plan E)');
    expect(c.byteLength,
        ResidentGeometry.byteLengthFor(c.instanceCount,
            patchInstances: c.patchInstanceCount));
    expect(c.patchInstanceCount, greaterThan(0));
  });
}
```

- [ ] **Step 6: Run them to verify they fail**

Run: `flutter test test/gpu/resident_collection_test.dart`
Expected: FAIL — `ResidentCollection` undefined.

- [ ] **Step 7: The collection**

`lib/src/gpu/resident_collection.dart`:

```dart
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:jet_cad_2d/jet_cad_2d.dart';

import '../draft_painter.dart';
import '../viewport_transform.dart';
import 'collection_frame.dart';
import 'geometry_collector.dart';
import 'resident_geometry.dart';
import 'resident_text.dart';
import 'text_patches.dart';

/// One rebuild's GPU-free product: what `ResidentGeometry.create` uploads,
/// plus what the three frame-read triggers compare against.
///
/// **Allocated at rebuild, read on the frame.** [data] and [texts] are the
/// collector's own copies (`GeometryCollector.data` and `.texts` each copy
/// on access -- read once here, never per frame); [tablesRevision],
/// [devicePixelRatio] and [collectionCamera] are what `ResidentRebuilder.noteFrame`
/// reads to decide whether the picture on screen was collected under the
/// tables, the display and the scale the frame is drawn at.
class ResidentCollection {
  const ResidentCollection({
    required this.data,
    required this.instanceCount,
    required this.texts,
    required this.patches,
    required this.collectionCamera,
    required this.collectionViewport,
    required this.devicePixelRatio,
    required this.tablesRevision,
    required this.skippedOps,
    required this.walkMicros,
    required this.classifyMicros,
  });

  final Float32List data;
  final int instanceCount;
  final List<ResidentTextRecord> texts;
  final List<TextPatch> patches;

  /// The frame's camera (Ruling F2): the live camera's scale and rotation,
  /// translated so the extents sit at the origin. `GpuDrawBackend` maps out
  /// of this space every frame.
  final ViewportTransform collectionCamera;
  final Size collectionViewport;
  final double devicePixelRatio;

  /// `document.tables.mutationRevision`, read before the walk.
  final int tablesRevision;
  final int skippedOps;
  final int walkMicros;
  final int classifyMicros;

  int get patchInstanceCount =>
      patches.fold(0, (sum, p) => sum + p.instanceCount);

  /// The budget row's number, before upload: main buffer plus every patch
  /// sub-buffer, as `ResidentGeometry.byteLength` will report it.
  int get byteLength =>
      ResidentGeometry.byteLengthFor(instanceCount,
          patchInstances: patchInstanceCount);

  /// Walks [document] through [painter] under the frame [collectionFrameFor]
  /// gives for [live], then classifies. Synchronous; the caller (the
  /// rebuilder's post-frame callback) is what keeps it off the frame path.
  ///
  /// [painter] is the widget's own `DraftPainter` -- its `drawText` and
  /// `minTextCapPixels` are the walk's, so a `DRAW_TEXT=false` canvas
  /// collects no text and a canvas with level of detail on culls at the
  /// collection scale, exactly as the reference sink would at that scale.
  static ResidentCollection collect({
    required DraftDocument document,
    required DraftPainter painter,
    required ViewportTransform live,
    required double devicePixelRatio,
    required double pixelsPerPaperMm,
    required double lineweightScale,
    required TextMeasurer? measurer,
    required TextStyleRecord Function(Handle)? textStyleOf,
    double bandLowerScale = kBandLowerScale,
  }) {
    // Read before the walk: the revision the picture is *of*. A table edit
    // cannot land during the walk (one isolate), so before and after are
    // the same number; "before" is the one whose meaning does not depend on
    // that argument.
    final tablesRevision = document.tables.mutationRevision;
    final frame = collectionFrameFor(live, document.extents);
    final walk = Stopwatch()..start();
    final collector = GeometryCollector(
        pixelsPerPaperMm: pixelsPerPaperMm,
        devicePixelRatio: devicePixelRatio,
        lineweightScale: lineweightScale,
        measurer: measurer,
        textStyleOf: textStyleOf);
    painter.paint(collector, frame.camera, frame.viewport);
    // One copy each, at rebuild -- see the two getters' own doc comments.
    final data = collector.data;
    final texts = collector.texts;
    walk.stop();
    final classify = Stopwatch()..start();
    final patches = classifyTextPatches(data, collector.instanceCount, texts,
        devicePixelRatio: devicePixelRatio, bandLowerScale: bandLowerScale);
    classify.stop();
    return ResidentCollection(
      data: data,
      instanceCount: collector.instanceCount,
      texts: texts,
      patches: patches,
      collectionCamera: frame.camera,
      collectionViewport: frame.viewport,
      devicePixelRatio: devicePixelRatio,
      tablesRevision: tablesRevision,
      skippedOps: collector.skippedOps,
      walkMicros: walk.elapsedMicroseconds,
      classifyMicros: classify.elapsedMicroseconds,
    );
  }
}
```

- [ ] **Step 8: Run both files; expect PASS. Fire the mutation once, by hand**

Run: `flutter test test/gpu/collection_frame_test.dart test/gpu/resident_collection_test.dart`

Then, with `cp lib/src/gpu/resident_collection.dart /tmp/rc.bak`, replace the
two `frame.*` arguments of `painter.paint` with `live` and `const Size(800,
600)`; run `resident_collection_test.dart`; expect *"a collection at the
corner zoom holds everything the fit one holds"* red with `b.instanceCount`
smaller than `a.instanceCount`; restore with `cp /tmp/rc.bak
lib/src/gpu/resident_collection.dart`. Paste both outputs in the report.
This is the spec's *"cull collection to the live viewport"* mutation and Task
9 fires it again for the log.

- [ ] **Step 9: Gates, commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git status --short   # no analysis_options.yaml
git add lib/src/gpu/collection_frame.dart lib/src/gpu/resident_collection.dart lib/jet_cad_2d_flutter.dart test/gpu/collection_frame_test.dart test/gpu/resident_collection_test.dart
git commit -m "feat(gpu): the collection frame covers the extents, and a rebuild has a GPU-free product"
```

---

