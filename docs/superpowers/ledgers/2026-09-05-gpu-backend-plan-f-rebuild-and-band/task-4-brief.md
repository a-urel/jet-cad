### Task 4: Criterion 10 — the fallback, exactly once, observably

**Files:**
- Test: `test/gpu/draft_canvas_fallback_test.dart`
- Modify: `lib/src/draft_canvas.dart` only if Step 2 finds a gap (Task 3
  already carries the latch)

**Interfaces:**
- Consumes: `DraftCanvas.debugResidentFallbackReports`,
  `debugResetResidentFallbackReport`, `debugSetGpuAvailable`, `FakeUploader`.

- [ ] **Step 1: Write the tests**

`test/gpu/draft_canvas_fallback_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/fixtures.dart';
import '../support/recording_frame_painter.dart';

const Size kCanvas = Size(400, 300);

void main() {
  late FlutterTextMeasurer measurer;
  late DraftDocument doc;
  late SpatialIndex index;
  late CameraController camera;
  late FakeUploader uploader;
  var paints = 0;

  // `FlutterError.reportError` under the test binding parks the report as the
  // test's pending exception; `tester.takeException()` returns and clears it,
  // and an un-taken one fails the test. That is the observation, and it needs
  // no swap of `FlutterError.onError` -- which the binding checks at the end
  // of every test anyway.
  setUp(() {
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

  Widget wrap(Widget child) => MediaQuery(
      data: const MediaQueryData(devicePixelRatio: 1.0),
      child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
              child: SizedBox(
                  width: kCanvas.width, height: kCanvas.height, child: child))));

  Widget canvas(RenderBackend backend) => wrap(DraftCanvas(
      document: doc,
      index: index,
      camera: camera,
      backend: backend,
      minTextCapPixels: 0,
      residentUploader: uploader.call,
      onPaintForTest: () => paints++));

  DraftCanvasState state(WidgetTester t) =>
      t.state<DraftCanvasState>(find.byType(DraftCanvas));

  testWidgets('no GPU: two canvases, vertices both, one report', (t) async {
    debugSetGpuAvailable(false);
    await t.pumpWidget(canvas(RenderBackend.residentGpu));
    final s = state(t);
    expect(s.resolvedBackend, RenderBackend.vertices);
    expect(s.resident, isNull);
    expect(s.vertices, isNotNull);
    expect(paints, 1, reason: 'nothing threw on the frame path');
    final first = t.takeException();
    expect(first, isA<FlutterError>());
    expect(first.toString(), contains('residentGpu'));
    expect(first.toString(), contains('gpuAvailable'));
    expect(DraftCanvas.debugResidentFallbackReports, 1);
    await t.pumpWidget(wrap(const SizedBox()));
    await t.pumpWidget(canvas(RenderBackend.residentGpu));
    // MUTATION (M-F8): drop the static latch -> a second pending exception.
    expect(t.takeException(), isNull, reason: 'once per process');
    expect(DraftCanvas.debugResidentFallbackReports, 1);
    // An explicit vertices request is not a fallback and reports nothing.
    await t.pumpWidget(canvas(RenderBackend.vertices));
    expect(t.takeException(), isNull);
  });

  testWidgets('a failed upload: vertices from then on, one report, no retry',
      (t) async {
    debugSetGpuAvailable(true);
    uploader.failing = true;
    await t.pumpWidget(canvas(RenderBackend.residentGpu));
    await t.pump();
    await t.pump();
    final s = state(t);
    final r = s.resident!;
    expect(r.landed, 1);
    expect(r.uploadFailed, isTrue);
    expect(r.backend, isNull);
    final report = t.takeException();
    expect(report, isA<FlutterError>());
    expect(report.toString(), contains('upload'));
    final paintsBefore = paints;
    camera.zoomAt(const Offset(200, 150), 3.0);
    await t.pump();
    await t.pump();
    await t.pump();
    expect(paints, greaterThan(paintsBefore),
        reason: 'the canvas kept drawing after the failure');
    expect(() => s.vertices!.canvas, returnsNormally,
        reason: 'and it drew through the vertices sink');
    expect(r.rebuilds, 1, reason: 'criterion 10: once, not per frame');
    expect(t.takeException(), isNull, reason: 'no second report');
    expect(DraftCanvas.debugResidentFallbackReports, 1);
  });

  testWidgets('a canvas whose upload succeeds reports nothing', (t) async {
    debugSetGpuAvailable(true);
    await t.pumpWidget(canvas(RenderBackend.residentGpu));
    await t.pump();
    await t.pump();
    expect(state(t).resident!.backend, isA<RecordingFramePainter>());
    expect(t.takeException(), isNull);
    expect(DraftCanvas.debugResidentFallbackReports, 0);
  });
}
```

- [ ] **Step 2: Run; expect PASS against Task 3's code**

Run: `flutter test test/gpu/draft_canvas_fallback_test.dart`

If any assertion fails, the gap is in Task 3's latch or listener wiring; fix
it in `draft_canvas.dart` and record the finding in the report — do not
loosen the test.

- [ ] **Step 3: Gates, commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git status --short
git add test/gpu/draft_canvas_fallback_test.dart lib/src/draft_canvas.dart
git commit -m "test(gpu): criterion 10 -- the resident fallback falls back once, without throwing, observably"
```

---

