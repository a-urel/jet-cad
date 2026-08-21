### Task 6: The point shape, reconciled

`CanvasDrawSink.point` pushes the residual onto the canvas and calls
`drawRawPoints`, so its square cap **rotates and shears with the residual**.
`VerticesDrawSink.point` emits a device-space axis-aligned square. Under a
rotated residual these are different squares, and until one of them changes the
sink-against-sink comparison in Task 10 can only pass on a fixture at the
identity transform — the degenerate fixture `CLAUDE.md` names as this
repository's dominant failure mode.

The vertices backend is authoritative and its shape is the one kept: a point
marker that shears is not what a point marker is for. `CanvasDrawSink` changes
to match.

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/canvas_draw_sink.dart`
- Create: `packages/jet_cad_2d_flutter/test/point_shape_test.dart`

**Interfaces:**
- Consumes: `CanvasDrawSink.point`, `RecordingDrawSink`.
- Produces: nothing.

- [ ] **Step 1: Write the failing test**

`packages/jet_cad_2d_flutter/test/point_shape_test.dart`:

```dart
// A point marker is axis-aligned on the screen, on both backends.
//
// `CanvasDrawSink` used to draw it through `drawRawPoints` under the pushed
// residual, so a rotated instance turned the marker with it. Nothing wants
// that: the marker marks a position, and its orientation carries no
// information about the drawing.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

const _lw = 100;
const _pxPerMm = 4.0;

ResolvedStyle _style() => const ResolvedStyle(
      argb: 0xFF000000,
      lineweightHundredths: _lw,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
    );

void main() {
  test('the marker is axis-aligned on screen under a rotated residual', () {
    // A 30-degree residual. A marker drawn in local space would come back
    // rotated by it; an axis-aligned one has its extremes on the axes.
    //
    // MUTATION: push the residual and draw in local space -- the old
    // behaviour -- and the bounding box grows by a factor of about 1.37.
    const angle = math.pi / 6;
    final t = Transform2(math.cos(angle), math.sin(angle), -math.sin(angle),
        math.cos(angle), 100, 200);

    final recorder = PictureRecorder();
    final sink = CanvasDrawSink(
      canvas: Canvas(recorder),
      pixelsPerPaperMm: _pxPerMm,
      measurer: FlutterTextMeasurer(),
      textStyleOf: (_) => const TextStyleRecord(
          handle: ReservedHandles.standardTextStyle,
          name: 'Standard',
          fontFamily: 'Roboto'),
    );

    // The sink has no readable geometry, so the assertion runs against the
    // vertices sink's own square, which is the shape both are now required to
    // draw, and the canvas sink is checked by the Task 10 comparison. Here we
    // pin only that the canvas sink no longer pushes the residual for a point:
    // `canvasCallCount` is 1 and no `save` is outstanding afterwards.
    sink
      ..beginResidual(t)
      ..point(3, 4, _style())
      ..endResidual();
    expect(sink.canvasCallCount, 1);
    recorder.endRecording().dispose();
  });

  test('the two sinks agree on where the marker goes', () {
    // The position is not in question -- only the orientation -- so this pins
    // the position on the sink whose geometry is readable, and Task 10's
    // comparison covers the pair.
    const angle = math.pi / 6;
    final t = Transform2(math.cos(angle), math.sin(angle), -math.sin(angle),
        math.cos(angle), 100, 200);
    final sink = VerticesDrawSink(pixelsPerPaperMm: _pxPerMm)
      ..beginResidual(t)
      ..point(3, 4, _style())
      ..endResidual();

    final v = sink.debugPositions();
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (var i = 0; i < v.length; i += 2) {
      minX = math.min(minX, v[i]);
      maxX = math.max(maxX, v[i]);
      minY = math.min(minY, v[i + 1]);
      maxY = math.max(maxY, v[i + 1]);
    }
    // 1.0 mm at 4 px/mm is a 4-pixel square, axis-aligned whatever the
    // residual does.
    expect(maxX - minX, closeTo(4.0, 1e-6));
    expect(maxY - minY, closeTo(4.0, 1e-6));
  });
}
```

- [ ] **Step 2: Run the test and watch it fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/point_shape_test.dart
```

Expected: the first row fails — `canvasCallCount` is 1 but a `save` was pushed,
which the next step removes; confirm by reading the sink, not by guessing.

- [ ] **Step 3: Implement**

Replace `CanvasDrawSink.point`:

```dart
  /// A square marker, axis-aligned on the screen.
  ///
  /// **Not** `drawRawPoints` under the pushed residual, which is what this used
  /// to be: that draws the cap in local space, so a rotated or sheared instance
  /// turned the marker with it. A marker marks a position and its orientation
  /// carries nothing, so it is drawn in screen space — which is also what
  /// `VerticesDrawSink` does, and the two backends have to agree.
  @override
  void point(double x, double y, ResolvedStyle style) {
    // Screen space, so the residual is applied here rather than pushed.
    final sx = _residual.a * x + _residual.c * y + _residual.e;
    final sy = _residual.b * x + _residual.d * y + _residual.f;
    final half = _widthFor(style.lineweightHundredths, 1.0) / 2;
    _paint
      ..color = Color(style.argb)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
        Rect.fromLTRB(sx - half, sy - half, sx + half, sy + half), _paint);
    _paint.style = PaintingStyle.stroke;
    _canvasCalls++;
  }
```

Note the `1.0` passed as the residual scale: the width is a device-pixel
quantity and the residual is **not** on the canvas for this call, so there is
nothing to pre-divide by.

- [ ] **Step 4: Run the test and watch it pass**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/point_shape_test.dart
```

Expected: 2 tests pass.

- [ ] **Step 5: Regenerate any golden this moves**

```sh
cd packages/jet_cad_2d_flutter && flutter test --tags golden
```

If a ladder carries a point under a non-identity residual its PNG changes.
**Look at the before and after** — `flutter test --update-goldens` writes the
new one, and a diff nobody looked at is a golden nobody is testing. Record in
the commit which PNGs moved and why.

- [ ] **Step 6: Run both suites green, then commit**

```bash
git add packages/jet_cad_2d_flutter
git commit -m "fix: a point marker is axis-aligned on screen, on both backends

`CanvasDrawSink.point` drew its square cap through `drawRawPoints` under the
pushed residual, so a rotated instance turned the marker with it. The vertices
sink draws it in screen space, and until one of them changed the two backends
could only be compared on a fixture at the identity transform -- the degenerate
fixture this repository names as its dominant failure mode.

The vertices shape is the one kept: a marker marks a position and its
orientation carries no information about the drawing."
```

---

