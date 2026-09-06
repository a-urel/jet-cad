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
                  width: kCanvas.width,
                  height: kCanvas.height,
                  child: child))));

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

  testWidgets(
      'a throwing upload falls back for good: two reports, vertices still '
      'paints', (t) async {
    debugSetGpuAvailable(true);
    uploader.throwing = true;
    // Both reports below fire synchronously and in the same microtask, from
    // inside the post-frame callback `pumpWidget`'s own frame schedules:
    // `ResidentRebuilder._run`'s catch reports the `StateError` first, then
    // its `notifyListeners()` call runs `DraftCanvas._onResidentLanded`
    // synchronously (`ChangeNotifier.notifyListeners` calls every listener
    // in the same call stack), which reports the `FlutterError` fallback
    // second. Verified empirically: `tester.takeException()` after
    // `pumpWidget` -- and again after a `pump()` on top of that -- returns
    // the test binding's own synthetic "Multiple exceptions (2) were
    // detected" error, never the two originals, because
    // `TestWidgetsFlutterBinding`'s `FlutterError.onError` holds only ONE
    // pending exception and collapses a second report that arrives before
    // the first is taken; there is no point between these two synchronous
    // `reportError` calls at which test code runs, so no number of pumps
    // between `takeException()` calls can separate them. Intercepting
    // `FlutterError.onError` directly, for this test's scope only, is what
    // actually observes both reports, in order, without the binding's
    // single-slot collapse.
    final reported = <Object>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) => reported.add(details.exception);
    await t.pumpWidget(canvas(RenderBackend.residentGpu));
    FlutterError.onError = previousOnError;
    expect(reported, hasLength(2));
    expect(reported[0], isA<StateError>());
    expect((reported[0] as StateError).message, contains('upload exploded'));
    expect(reported[1], isA<FlutterError>());
    expect(reported[1].toString(), contains('upload failed'));
    final s = state(t);
    expect(s.resident!.uploadFailed, isTrue);
    expect(s.resident!.backend, isNull);
    expect(DraftCanvas.debugResidentFallbackReports, 1);
    final paintsBefore = paints;
    camera.zoomAt(const Offset(200, 150), 3.0);
    await t.pump();
    await t.pump();
    expect(paints, greaterThan(paintsBefore),
        reason: 'the canvas kept drawing after the failure');
    expect(() => s.vertices!.canvas, returnsNormally,
        reason: 'and it drew through the vertices sink');
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
