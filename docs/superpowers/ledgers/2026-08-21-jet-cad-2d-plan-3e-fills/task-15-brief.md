## Task 15: The translucent seam, measured against the real engine

**Files:**
- Create: `packages/jet_cad_2d_flutter/test/fill_seam_test.dart`
- Modify (only if the rule fires): `packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart`

**Interfaces:**
- Produces: a measured percentage and maximum, and either a routing change or a recorded number.

**Read this before writing a line.** `TriangleRasterizer` **cannot see this**. Its inner loop is `pixels[y * width + x] = rgba` — a plain store, no blending, no alpha compositing, no antialiasing. Both divergence modes are blending artefacts. A seam test written against the repository's own rasterizer — the natural instrument, the one every golden uses — would pass against a sink drawing the artefact at full strength. **That is the degenerate fixture in its most expensive form: one a review has already approved.**

The instrument is a `ui.Picture` recorded through each sink, `picture.toImage()`, `toByteData()`, compared pixel by pixel. Plan 3d's Task 2 used exactly this when it needed an answer the rasterizer could not give.

**There are two modes and both are measured:**

1. **Overlapping strokes**, exactly as Plan 3d recorded. At every join `_emitJoin` fills the notch on the *outer* side, and the two chord quads meeting at that vertex overlap in a lens on the *inner* side. Two rectangles of equal half-width sharing an endpoint at an angle intersect; that is geometry, not a bug. Under alpha every corner double-blends.
2. **Shared triangulation edges**, new with fills. A triangulation tiles its interior — triangles share edges, not area — so the artefact is at the edges: `isAntiAlias` defaults true and `VerticesDrawSink` does not clear it, so two adjacent triangles blend one edge pixel twice at partial coverage. `Canvas.drawPath` computes coverage once and has no seam.

**The rule, declared before the measurement.** Fixture: one convex-and-a-notch boundary filled at `alpha = 0x80` over white, one entity, 400 × 300 logical at the `flutter_test` default device pixel ratio of 3.0. Interior pixels only; the outer boundary ring, one device pixel wide, is excluded.

> **Routing fires if** more than **0.5 %** of interior pixels differ by more than **8/255** in any channel, **or** any single interior pixel differs by more than **32/255**.

**Both outcomes are results.** If it fires, translucent fills route through the fallback sink via `_flushBeforeUnbatchable` — whose only caller today is `text`. If it does not, translucent fills batch and both divergences are recorded as inert in practice **with the measured percentage and maximum beside them**. Measuring and stopping is the outcome; tuning until the number complies is not.

**A third answer is rejected on the record:** clearing `isAntiAlias` on the vertices `Paint` removes the partial coverage and with it the seam — and jags every stroke in the drawing, on every frame, to fix an artefact that appears only under alpha.

- [ ] **Step 1: Write the measurement**

```dart
/// Records [draw] into a Picture through a fresh sink and rasterises it in the
/// engine, WITH blending. `TriangleRasterizer` cannot be used here: it stores
/// `pixels[i] = rgba` with no compositing at all, so it cannot see a blending
/// artefact, and a test built on it would pass against a sink drawing the
/// artefact at full strength.
Future<ByteData> renderThrough(
    WidgetTester tester, DrawSink Function(Canvas) make, Drawing draw) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 1200, 900),
      Paint()..color = const Color(0xFFFFFFFF));
  draw(make(canvas));
  final picture = recorder.endRecording();
  final image = await tester.runAsync(() => picture.toImage(1200, 900));
  addTearDown(image!.dispose);
  return (await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
}

testWidgets('the translucent seam, measured', (tester) async {
  final canvasBytes = await renderThrough(tester, canvasSink, translucentFill);
  final verticesBytes =
      await renderThrough(tester, verticesSink, translucentFill);

  var over8 = 0, interior = 0, worst = 0;
  for (final (x, y) in interiorPixels()) {   // the fixture's own interior,
    interior++;                              // eroded by one device pixel
    final d = maxChannelDelta(canvasBytes, verticesBytes, x, y);
    if (d > 8) over8++;
    if (d > worst) worst = d;
  }
  final fraction = over8 / interior;
  // ignore: avoid_print
  print('SEAM interior=$interior over8=$over8 '
      'fraction=${(fraction * 100).toStringAsFixed(3)}% worst=$worst');

  expect(interior, greaterThan(4000),
      reason: 'non-vacuity: an empty interior would satisfy every bound below');
  expect(fraction, lessThanOrEqualTo(0.005),
      reason: 'above this the plan routes translucent fills through the '
          'fallback sink; see the design\'s declared rule');
  expect(worst, lessThanOrEqualTo(32));
});
```

- [ ] **Step 2: Run it and read the number**

Run: `cd packages/jet_cad_2d_flutter && flutter test test/fill_seam_test.dart`
**Record the printed `SEAM` line verbatim.** It is the result whichever way it
goes.

- [ ] **Step 3: Prove the instrument can see a seam at all**

Before trusting a pass, force one: emit each triangle **twice** in
`fillPolygon`. The measurement must go red. If it does not, the instrument is
wrong and the pass in Step 2 meant nothing.

```sh
cp lib/src/vertices_draw_sink.dart /tmp/t15.dart
trap 'cp /tmp/t15.dart lib/src/vertices_draw_sink.dart' EXIT
# double-blend every triangle
perl -0pi -e 's/(      _emitTriangle\(\n(?:.*\n)*?        argb,\n      \);)/$1\n      _emitTriangle(\n        t.a * points[a * 2] + t.c * points[a * 2 + 1] + t.e,\n        t.b * points[a * 2] + t.d * points[a * 2 + 1] + t.f,\n        t.a * points[b * 2] + t.c * points[b * 2 + 1] + t.e,\n        t.b * points[b * 2] + t.d * points[b * 2 + 1] + t.f,\n        t.a * points[c * 2] + t.c * points[c * 2 + 1] + t.e,\n        t.b * points[c * 2] + t.d * points[c * 2 + 1] + t.f,\n        argb,\n      );/' lib/src/vertices_draw_sink.dart
flutter test test/fill_seam_test.dart   # must FAIL
cp /tmp/t15.dart lib/src/vertices_draw_sink.dart
```

- [ ] **Step 4: If the rule fired, route translucent fills to the fallback**

Only if Step 2 exceeded a bound:

```dart
  @override
  void fillPolygon(Float64List points, int count, Int32List triangles,
      ResolvedStyle style) {
    if (triangles.isEmpty) return;
    if ((style.argb >>> 24) != 0xFF) {
      // Measured, not assumed: see the plan's Task 15 and the results note.
      // A triangle soup blends shared edges twice; a path blends once.
      _flushBeforeUnbatchable();
      _fallback?.fillPolygon(points, count, triangles, style);
      return;
    }
    // ... the batched path
  }
```

and pin the routing with an order test — a translucent fill must flush before
the fallback draws, the same property Plan 3d pins for `text`.

- [ ] **Step 5: Record the number either way**

Write the `SEAM` line, the fixture, the viewport, the device pixel ratio and
the decision into the commit message. Task 17 copies it into the results note.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d_flutter/test/fill_seam_test.dart \
        packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart
git commit -m "test: the translucent seam, measured against the real engine"
```

---

