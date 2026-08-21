### Task 10: Goldens on both backends

Both backends are production, so both get pinned. The existing 14 PNGs keep
their fixtures and their assertions and become the **canvas** backend's suite —
which is the web renderer, so they stop being at risk of testing code nothing
draws through. The same fixtures render again through the vertices backend and
the rasterizer into a second set.

**Files:**
- Modify: `packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart`
- Modify: `packages/jet_cad_2d_flutter/test/golden/stroke_width_golden_test.dart`
- Modify: `packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart`
- Create: `packages/jet_cad_2d_flutter/test/golden/vertices/*.png` (14 files)

**Interfaces:**
- Consumes: `RenderBackend`, `TriangleRasterizer`, `VerticesDrawSink.observer`.
- Produces: nothing.

- [ ] **Step 1: Add the second rendering route to one ladder**

Take `dash_ladder_golden_test.dart` first — it is the one whose fixture carries
both a polyline and a circle. Wrap each existing `testWidgets` body in a loop
over the backends and route the vertices one through the rasterizer:

```dart
/// Renders one rung on one backend and compares it to that backend's PNG.
///
/// The canvas backend goes through `flutter_test`'s own rasteriser and
/// `matchesGoldenFile` on the widget. The vertices backend cannot: software
/// Skia does not finish a `drawVertices` of this size, so its triangles are
/// scan-converted by `TriangleRasterizer` and the *image* is matched instead.
Future<void> _rung(WidgetTester tester, DraftDocument doc, String name,
    RenderBackend backend) async {
  final index = SpatialIndex(doc);
  addTearDown(index.dispose);
  final camera = CameraController(
      ViewportTransform.fit(doc.extents, kGoldenSize));
  addTearDown(camera.dispose);

  final rasterizer = backend == RenderBackend.vertices
      ? TriangleRasterizer(
          kGoldenSize.width.round(), kGoldenSize.height.round())
      : null;

  final key = GlobalKey<DraftCanvasState>();
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: RepaintBoundary(
      child: SizedBox(
        width: kGoldenSize.width,
        height: kGoldenSize.height,
        child: ColoredBox(
          color: const Color(0xFFFFFFFF),
          child: DraftCanvas(
              key: key,
              document: doc,
              index: index,
              camera: camera,
              backend: backend),
        ),
      ),
    ),
  ));
  key.currentState!.vertices?.observer = rasterizer?.observe;
  await tester.pump();

  if (rasterizer == null) {
    await expectLater(
        find.byType(DraftCanvas), matchesGoldenFile('$name.png'));
    return;
  }
  final image = await rasterizer.toImage();
  addTearDown(image.dispose);
  await expectLater(image, matchesGoldenFile('vertices/$name.png'));
}
```

The `observer` is attached **after** the first pump and the widget is pumped
again, because the state does not exist until the first build.

- [ ] **Step 2: Run it and watch the vertices goldens fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test --tags golden test/golden/dash_ladder_golden_test.dart
```

Expected: the five canvas rungs pass unchanged; the five vertices rungs fail
with "Golden file … does not exist".

- [ ] **Step 3: Generate the vertices goldens, then look at every one**

```sh
cd packages/jet_cad_2d_flutter && flutter test --tags golden --update-goldens test/golden/dash_ladder_golden_test.dart
```

Then **open all five PNGs and look at them**. This is not a formality: the
spike's two bugs were a reordered drawing and a picture nobody had rendered,
and both were found by looking. Check specifically:

- corners are filled, with no hairline crack along the miter's base;
- the circle has no notch at its start angle (three o'clock);
- dashes start and end where the canvas golden's do;
- colours match the canvas golden's rung for rung.

A PNG that looks wrong is a Task 4 or Task 5 defect, not a golden to accept.

- [ ] **Step 4: Repeat for the other two ladders**

`stroke_width_golden_test.dart` and `text_ladder_golden_test.dart`, the same
way. The text ladder's glyphs will be **absent** from its vertices golden —
text never enters the triangle buffer — and its polyline will be present. That
is correct and the test says so:

```dart
  // The vertices golden of this ladder carries the rung's polyline and none of
  // its glyphs: text goes to `CanvasDrawSink` as a paragraph and never reaches
  // the triangle buffer. What it pins is that the strokes around the text are
  // right and that the flush before each text op happened; the glyphs are
  // pinned by the canvas golden beside it.
```

- [ ] **Step 5: Run the whole golden suite**

```sh
cd packages/jet_cad_2d_flutter && flutter test --tags golden
```

Expected: 28 rungs pass, 14 per backend. **No pre-existing PNG regenerated** —
if one moved, Task 6's point change moved it and that is already recorded; any
other movement is a defect.

- [ ] **Step 6: Run both suites green, then commit**

```bash
git add packages/jet_cad_2d_flutter/test/golden
git commit -m "test: goldens on both backends

Both backends are production, so both are pinned. The existing 14 PNGs keep
their fixtures and become the canvas backend's suite, which is the web
renderer -- the web decision is what stops them from becoming tests of code
nothing draws through.

The same fixtures render again through the vertices backend and the rasterizer.
The text ladder's vertices golden carries its polyline and none of its glyphs,
because text never enters the triangle buffer; what it pins is the strokes and
the flush, and the glyphs stay pinned by the canvas golden beside it.

Every generated PNG was opened and looked at before it was accepted."
```

---

