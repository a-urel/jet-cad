## Task 11: `DrawSink` grows two fill operations

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/draw_sink.dart`
- Modify: `packages/jet_cad_2d_flutter/lib/src/canvas_draw_sink.dart`
- Modify: `packages/jet_cad_2d_flutter/test/draw_sink_test.dart`

**Interfaces:**
- Produces:
```dart
void fillPolygon(Float64List points, int count, Int32List triangles,
    ResolvedStyle style);
void fillCircle(double cx, double cy, double r, ResolvedStyle style);

final class FillPolygonOp extends DrawOp { ... }   // == by value, triangles included
final class FillCircleOp extends DrawOp { ... }
```

`CanvasDrawSink` draws the polygon as a closed `Path` with `PaintingStyle.fill` and **ignores `triangles`** — `Canvas` resolves concavity itself — and the circle with `drawCircle`. Both sinks receive the same ops with the same arguments, so `RecordingDrawSink` equality and the differential oracle keep working.

- [ ] **Step 1: Write the failing tests**

```dart
test('two recordings of the same fill compare equal', () {
  final a = RecordingDrawSink()..fillPolygon(square, 5, tri, style);
  final b = RecordingDrawSink()..fillPolygon(square, 5, tri, style);
  expect(a.ops, b.ops);
});

test('a different triangulation of the same outline is a different op', () {
  // The op carries the triangles, so a painter that hands one sink a stale
  // triangulation and the other a fresh one is a disagreement the oracle sees.
  final a = RecordingDrawSink()
    ..fillPolygon(square, 5, Int32List.fromList([0, 1, 2, 0, 2, 3]), style);
  final b = RecordingDrawSink()
    ..fillPolygon(square, 5, Int32List.fromList([0, 1, 3, 1, 2, 3]), style);
  expect(a.ops, isNot(b.ops));
});

testWidgets('the canvas sink fills the path and does not stroke it',
    (tester) async {
  final spy = SpyCanvas();
  CanvasDrawSink(canvas: spy, pixelsPerPaperMm: kLogicalPixelsPerMm)
    ..beginResidual(Transform2.identity)
    ..fillPolygon(square, 5, tri, style)
    ..endResidual();
  expect(spy.lastPaintStyle, PaintingStyle.fill);
  expect(spy.drawPathCount, 1,
      reason: 'one path, not two triangles: Canvas resolves concavity itself '
          'and the triangles argument is for the vertices backend');
});

testWidgets('the canvas sink leaves its paint on stroke afterwards',
    (tester) async {
  // The sink reuses one Paint. A fill that leaves `style` on fill turns every
  // later stroke in the frame into a fill -- the shape of bug the point op
  // already guards against by restoring PaintingStyle.stroke.
  final spy = SpyCanvas();
  final sink = CanvasDrawSink(canvas: spy, pixelsPerPaperMm: kLogicalPixelsPerMm)
    ..beginResidual(Transform2.identity)
    ..fillPolygon(square, 5, tri, style)
    ..polyline(square, 5, style, closed: false)
    ..endResidual();
  expect(spy.lastPaintStyle, PaintingStyle.stroke);
  expect(sink.canvasCallCount, 2);
});
```

- [ ] **Step 2: Run and watch them fail**

- [ ] **Step 3: Implement**

On `DrawSink`:

```dart
  /// Fills a closed loop.
  ///
  /// [points] is the boundary's loop in this residual's local space, [count]
  /// its point count including the duplicated closing point. [triangles] is
  /// the loop's triangulation as triple-indices into [points]' point
  /// numbering -- computed once, off the frame path, and passed through
  /// because a sink must not reach into the document to get it.
  ///
  /// A sink that fills paths natively ignores [triangles]; a sink that batches
  /// geometry needs them. Both receive the same call, which is what keeps
  /// [RecordingDrawSink] equality meaningful.
  ///
  /// The painter never calls this with an empty [triangles]: an unfillable
  /// boundary is skipped and counted before it reaches a sink. See
  /// `DraftPainter.skippedFillCount`.
  void fillPolygon(Float64List points, int count, Int32List triangles,
      ResolvedStyle style);

  /// Fills a circle. Never triangulated ahead of time: a circle's
  /// tessellation is scale-dependent, so a batching sink fans it per frame at
  /// the step count its own stroke would use.
  void fillCircle(double cx, double cy, double r, ResolvedStyle style);
```

On `CanvasDrawSink`:

```dart
  @override
  void fillPolygon(Float64List points, int count, Int32List triangles,
      ResolvedStyle style) {
    if (count < 3) return;
    _pushTransform();
    _scratch.reset();
    _scratch.moveTo(points[0], points[1]);
    for (var i = 1; i < count; i++) {
      _scratch.lineTo(points[i * 2], points[i * 2 + 1]);
    }
    _scratch.close();
    _paint
      ..color = Color(style.argb)
      ..style = PaintingStyle.fill;
    canvas.drawPath(_scratch, _paint);
    // Restored for the same reason `point` restores it: one Paint is reused
    // for the whole frame, and a stroke drawn after this must not be filled.
    _paint.style = PaintingStyle.stroke;
    _popTransform();
    _canvasCalls++;
  }

  @override
  void fillCircle(double cx, double cy, double r, ResolvedStyle style) {
    _pushTransform();
    _paint
      ..color = Color(style.argb)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), r, _paint);
    _paint.style = PaintingStyle.stroke;
    _popTransform();
    _canvasCalls++;
  }
```

Plus `FillPolygonOp` and `FillCircleOp` on `RecordingDrawSink`, with `==`
comparing `points`, `triangles`, and `style` by value.

- [ ] **Step 4: Run and watch them pass**

- [ ] **Step 5: Run the named mutations**

```sh
# T11a: leave _paint.style on fill after the call    -> the stroke test reds
# T11b: drop `triangles` from FillPolygonOp's ==     -> the two-triangulations test reds
# T11c: draw the polygon unclosed (_scratch.close() removed)
```

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d_flutter/lib/src/draw_sink.dart \
        packages/jet_cad_2d_flutter/lib/src/canvas_draw_sink.dart \
        packages/jet_cad_2d_flutter/test/draw_sink_test.dart
git commit -m "feat: DrawSink.fillPolygon and fillCircle"
```

---

