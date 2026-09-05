### Task 5: The composited differential, and the order gate

**Files:**
- Modify: `test/support/gpu_comparison.dart` (add `CompositedAgreement`, `measureCompositedAgreement`)
- Create: `test/gpu/text_order_test.dart`

**Interfaces:**
- Consumes: `textOverlapFixture` (Task 3), `classifyTextPatches`,
  `patchRegionFor`, `TextCompositor`, `PatchImage`, `expandInstances`
  (`test/support/instance_expander.dart:110`), `VerticesDrawSink(fallback:)`,
  `CanvasDrawSink`.
- Produces:
  ```dart
  class CompositedAgreement { final int union, withinTwo, overEight, referenceInk, patchCount; double get agreement; }
  Future<CompositedAgreement> measureCompositedAgreement(DraftDocument document, {
      required ViewportTransform collectionCamera, required ViewportTransform liveCamera,
      required Size size, required double devicePixelRatio, required double pixelsPerPaperMm,
      required FlutterTextMeasurer measurer,
      List<TextPatch> Function(List<TextPatch>)? mutatePatches,   // test seam: the "all text in one pass" mutation is `(_) => []`
      double minTextCapPixels = kMinTextCapPixels});
  ```

**The corpus is undashed, and the instrument says so in its doc.** Skia's
`drawVertices` cannot honour `expandInstances`'s dash varyings (the shader
discards per fragment; `TriangleRasterizer` reproduces that, Skia does not),
so a dashed instance would draw solid on the resident arm here. Dash
correctness is Plan C's gates; this instrument is for text and order, on
solid geometry.

**Both arms through Skia.** The reference is the painter driving
`VerticesDrawSink` with a `CanvasDrawSink` fallback on the **same** `Canvas`
(the widget's own arrangement) at the **live** camera. The resident arm is
the painter driving `GeometryCollector` (with a measurer) at the **collection**
camera; `classifyTextPatches`; then, per Ruling B6, `expandInstances` turns
the main buffer and each sub-buffer into device-space triangles that
`Canvas.drawVertices` draws into a `Picture` — the main one at viewport size,
each patch at its region's size under `translation(-x, -y) ∘
collectionToDevice` — `toImage` each, and `TextCompositor.paint` onto the
final canvas under `canvas.scale(dpr)`. Per-channel comparison as
`_colorAgreementOf` does it. **`dashScale`** for `expandInstances` is the
live-to-collection ratio (`dashScaleFor`'s formula), because the two cameras
differ here — that is the point of the four-scale test.

- [ ] **Step 1: The gate, written first**

Create `test/gpu/text_order_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/fixtures.dart';
import '../support/gpu_comparison.dart';

const Size _size = Size(800, 600);
const double _dpr = 1.0;
const double _ppmm = 3.78;

/// The camera the buffer is collected at, and the four live cameras the
/// gate runs at: the band's floor, two interior points, and the ceiling.
/// The floor is where the reach expansion is load-bearing.
ViewportTransform _fit(DraftDocument doc) =>
    ViewportTransform.fit(doc.extents, _size);

ViewportTransform _scaled(ViewportTransform base, double s) {
  final centre = Offset(_size.width / 2, _size.height / 2);
  final m = Transform2.translation(centre.dx, centre.dy)
      .multiply(Transform2.scale(s, s))
      .multiply(Transform2.translation(-centre.dx, -centre.dy))
      .multiply(base.worldToScreenMatrix);
  return ViewportTransform(worldToScreenMatrix: m);
}

void main() {
  late FlutterTextMeasurer measurer;
  late DraftDocument doc;
  setUp(() {
    measurer = FlutterTextMeasurer();
    doc = textOverlapFixture(measurer);
  });

  for (final s in const [0.5, 0.8, 1.25, 2.0]) {
    test('the composited picture matches the reference at scale $s', () async {
      // `minTextCapPixels: 0` -- level of detail OFF on both arms. Text
      // culling is a watermark decision frozen at the reference scale (the
      // spec's table), so with it on the two arms legitimately disagree
      // about TINY away from scale 1; that disagreement is Plan F's band
      // statement, not this gate's. The LOD-on case is the next test.
      final base = _fit(doc);
      final m = await measureCompositedAgreement(doc,
          collectionCamera: base,
          liveCamera: _scaled(base, s),
          size: _size,
          devicePixelRatio: _dpr,
          pixelsPerPaperMm: _ppmm,
          measurer: measurer,
          minTextCapPixels: 0.0);
      expect(m.referenceInk, greaterThan(5000), reason: 'anti-vacuity');
      expect(m.patchCount, greaterThanOrEqualTo(1),
          reason: 'COVERED must be a patch or this test sees no ordering');
      expect(m.agreement, greaterThanOrEqualTo(0.995),
          reason: 'spec criterion 1, per channel <= 2 on >= 99.5% of the '
              'union; scale $s: withinTwo=${m.withinTwo} union=${m.union} '
              'overEight=${m.overEight}');
    });
  }

  test('with level of detail on, both arms cull TINY the same way at scale 1',
      () async {
    final base = _fit(doc);
    final m = await measureCompositedAgreement(doc,
        collectionCamera: base,
        liveCamera: base,
        size: _size,
        devicePixelRatio: _dpr,
        pixelsPerPaperMm: _ppmm,
        measurer: measurer);
    expect(m.agreement, greaterThanOrEqualTo(0.995));
  });

  test('drawing all text in one pass -- no patches -- changes the picture',
      () async {
    // The spec's headline text mutation, as a seam rather than a source
    // edit: with the classifier's output discarded, the later stroke 903
    // draws UNDER label COVERED, and the fill 904 under it too.
    final base = _fit(doc);
    final m = await measureCompositedAgreement(doc,
        collectionCamera: base,
        liveCamera: base,
        size: _size,
        devicePixelRatio: _dpr,
        pixelsPerPaperMm: _ppmm,
        measurer: measurer,
        mutatePatches: (_) => const []);
    expect(m.patchCount, 0);
    expect(m.overEight, greaterThan(200),
        reason: 'the ink of 903 and 904 inside COVERED\'s glyphs is where '
            'the two arms now disagree; fewer than 200 pixels means the '
            'overlap is not real and Task 3\'s guard is wrong');
    expect(m.agreement, lessThan(0.995));
  });

  test('the label nothing later reaches is not a patch, and still matches',
      () async {
    final base = _fit(doc);
    final m = await measureCompositedAgreement(doc,
        collectionCamera: base,
        liveCamera: base,
        size: _size,
        devicePixelRatio: _dpr,
        pixelsPerPaperMm: _ppmm,
        measurer: measurer);
    // Exactly the labels the table says are covered: COVERED and GRAZED.
    // UNDER is not (its only stroke is of lower handle); TINY is not.
    expect(m.patchCount, 2,
        reason: 'a classifier that patches every label reads 4 here');
  });
}
```

- [ ] **Step 2: Run and watch it fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/text_order_test.dart
```
Expected: compile error — `measureCompositedAgreement` undefined.

- [ ] **Step 3: Implement the instrument in `gpu_comparison.dart`**

```dart
/// The per-channel agreement of two Skia-rendered pictures, plus how many
/// patches the resident arm composited. Same fields and the same 2/8
/// thresholds as [ResidentColorAgreement]; a separate class because the
/// instrument is different -- this one sees text.
class CompositedAgreement {
  const CompositedAgreement(this.union, this.withinTwo, this.overEight,
      this.referenceInk, this.patchCount);
  final int union, withinTwo, overEight, referenceInk, patchCount;
  double get agreement => union == 0 ? 1.0 : withinTwo / union;
}

/// Both arms through Skia, text included -- the first instrument in this
/// suite that can. See the plan's Task 5 for the arrangement.
Future<CompositedAgreement> measureCompositedAgreement(
  DraftDocument document, {
  required ViewportTransform collectionCamera,
  required ViewportTransform liveCamera,
  required Size size,
  required double devicePixelRatio,
  required double pixelsPerPaperMm,
  required FlutterTextMeasurer measurer,
  List<TextPatch> Function(List<TextPatch>)? mutatePatches,
  double minTextCapPixels = kMinTextCapPixels,
}) async {
  final w = (size.width * devicePixelRatio).round();
  final h = (size.height * devicePixelRatio).round();
  final index = SpatialIndex(document);
  final resolver = DocumentStyleResolver(document);
  final painter = DraftPainter(
      document: document,
      index: index,
      resolver: resolver,
      minTextCapPixels: minTextCapPixels);

  // --- reference: the widget's own arrangement, at the live camera -------
  final refRecorder = PictureRecorder();
  final refCanvas = Canvas(refRecorder)..scale(devicePixelRatio, devicePixelRatio);
  final fallback = CanvasDrawSink(
      canvas: refCanvas,
      pixelsPerPaperMm: pixelsPerPaperMm,
      measurer: measurer,
      textStyleOf: document.textStyleOf);
  final reference = VerticesDrawSink(
      canvas: refCanvas,
      pixelsPerPaperMm: pixelsPerPaperMm,
      devicePixelRatio: devicePixelRatio,
      fallback: fallback);
  painter.paint(reference, liveCamera, size);
  reference.flush();
  final refImage = await refRecorder.endRecording().toImage(w, h);

  // --- resident: collect at the collection camera, classify, expand ------
  final collector = GeometryCollector(
      pixelsPerPaperMm: pixelsPerPaperMm,
      devicePixelRatio: devicePixelRatio,
      measurer: measurer,
      textStyleOf: document.textStyleOf);
  painter.paint(collector, collectionCamera, size);
  final data = collector.data;
  final texts = collector.texts;
  var patches = classifyTextPatches(data, collector.instanceCount, texts,
      devicePixelRatio: devicePixelRatio);
  if (mutatePatches != null) patches = mutatePatches(patches);

  final collectionInverse = collectionCamera.worldToScreenMatrix.invert();
  final collectionToLogical =
      composeTransforms(liveCamera.worldToScreenMatrix, collectionInverse);
  final collectionToDevice = composeTransforms(
      Transform2.scale(devicePixelRatio, devicePixelRatio), collectionToLogical);
  final dashScale = dashScaleFor(liveCamera, collectionInverse);

  Future<Image> triangles(Float32List buf, int count, Transform2 toDevice,
      int width, int height) {
    final expanded = expandInstances(buf, count, toDevice, dashScale: dashScale);
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    if (count > 0) {
      final vertices = Vertices.raw(VertexMode.triangles, expanded.positions,
          colors: expanded.colors);
      // As `VerticesDrawSink.flush` draws: the vertex colour is the colour,
      // the paint contributes alpha only.
      canvas.drawVertices(vertices, BlendMode.dst, Paint());
      vertices.dispose();
    }
    return recorder.endRecording().toImage(width, height);
  }

  final mainImage =
      await triangles(data, collector.instanceCount, collectionToDevice, w, h);
  final patchImages = <PatchImage>[];
  for (final p in patches) {
    final t = texts[p.textIndex];
    final region = patchRegionFor(t, collectionToDevice, w, h,
        maxWidth: w, maxHeight: h);
    if (region == null) continue;
    final toPatch = composeTransforms(
        Transform2.translation(-region.x.toDouble(), -region.y.toDouble()),
        collectionToDevice);
    final img = await triangles(
        p.instances, p.instanceCount, toPatch, region.width, region.height);
    patchImages.add(PatchImage(
        textIndex: p.textIndex,
        image: img,
        src: Rect.fromLTWH(0, 0, region.width.toDouble(), region.height.toDouble()),
        dst: Rect.fromLTWH(region.x / devicePixelRatio, region.y / devicePixelRatio,
            region.width / devicePixelRatio, region.height / devicePixelRatio),
        layerBounds: labelBoundsLogical(t, collectionToLogical)));
  }

  final outRecorder = PictureRecorder();
  final outCanvas = Canvas(outRecorder)..scale(devicePixelRatio, devicePixelRatio);
  final compositor =
      TextCompositor(measurer: measurer, textStyleOf: document.textStyleOf);
  compositor.paint(outCanvas,
      main: mainImage,
      viewport: size,
      collectionToLogical: collectionToLogical,
      texts: texts,
      patches: patchImages);
  final outImage = await outRecorder.endRecording().toImage(w, h);

  final a = (await refImage.toByteData(format: ImageByteFormat.rawRgba))!;
  final b = (await outImage.toByteData(format: ImageByteFormat.rawRgba))!;
  var union = 0, withinTwo = 0, overEight = 0, referenceInk = 0;
  for (var i = 0; i < w * h; i++) {
    final o = i * 4;
    final inkA = a.getUint8(o + 3) != 0, inkB = b.getUint8(o + 3) != 0;
    if (inkA) referenceInk++;
    if (!inkA && !inkB) continue;
    union++;
    var worst = 0;
    for (var ch = 0; ch < 4; ch++) {
      final d = (a.getUint8(o + ch) - b.getUint8(o + ch)).abs();
      if (d > worst) worst = d;
    }
    if (worst <= 2) withinTwo++;
    if (worst > 8) overEight++;
  }
  return CompositedAgreement(
      union, withinTwo, overEight, referenceInk, compositor.patchesComposited);
}
```

**Two things to expect, and what to do about each:**

1. **A white background on one arm and transparent on the other.** The
   reference draws onto a transparent picture; so does the resident. If
   `refImage` comes back with an opaque white ground (a `CanvasDrawSink`
   quirk), draw a white rect first on **both** canvases before painting,
   and say so in the function's doc. Do not clear alpha on one side only.
2. **Antialiasing of `drawParagraph` is identical on both arms** — the
   same `Paragraph` object from the same cache, drawn under a transform that
   is the same composition by a different route. Where it differs by a
   float-rounding amount, the ≤ 2 tolerance absorbs it. If the four-scale
   rows miss 99.5% by a small margin **only at 0.5 and 2.0**, that is the
   band edge and it is recorded as the number, not adjusted (Plan C's rule).

- [ ] **Step 4: Run, gate, commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/text_order_test.dart
flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git add test/support/gpu_comparison.dart test/gpu/text_order_test.dart
git commit -m "test(gpu): the composited differential sees text, and gates its order"
```

---

