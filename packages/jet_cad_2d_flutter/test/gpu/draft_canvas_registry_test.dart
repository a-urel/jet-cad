import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/fixtures.dart';
import '../support/recording_frame_painter.dart';

const Size kCanvas = Size(400, 300);

const String kNotInstalled = 'no resident GPU is installed';
const String kUnavailable = 'the installed resident GPU is unavailable';

/// `DraftCanvas` through the registry (`resident_gpu.dart`, spec S4, M-G3).
///
/// **Every canvas here passes no `residentUploader`**, except the one test
/// that exercises it: the registered GPU's uploader is what is under test,
/// and a widget uploader would win over it and hide a canvas that ignored
/// the registry.
void main() {
  late FlutterTextMeasurer measurer;
  late DraftDocument doc;
  late SpatialIndex index;
  late CameraController camera;

  setUp(() {
    registerResidentGpu(null);
    addTearDown(() => registerResidentGpu(null));
    DraftCanvas.debugResetResidentFallbackReport();
    measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    doc = textOverlapFixture(measurer);
    index = SpatialIndex(doc);
    addTearDown(index.dispose);
    camera = CameraController(ViewportTransform.fit(doc.extents, kCanvas));
    addTearDown(camera.dispose);
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

  Widget canvas({ResidentUploader? residentUploader}) => wrap(DraftCanvas(
      document: doc,
      index: index,
      camera: camera,
      backend: RenderBackend.residentGpu,
      minTextCapPixels: 0,
      residentUploader: residentUploader));

  DraftCanvasState state(WidgetTester t) =>
      t.state<DraftCanvasState>(find.byType(DraftCanvas));

  Future<void> land(WidgetTester t) async {
    await t.pump();
    await t.pump();
  }

  testWidgets(
      'nothing registered: vertices, reported once as "no resident GPU is '
      'installed"', (t) async {
    await t.pumpWidget(canvas());
    final s = state(t);
    expect(s.resolvedBackend, RenderBackend.vertices);
    expect(s.resident, isNull);
    expect(s.vertices, isNotNull);
    final report = t.takeException();
    expect(report, isA<FlutterError>());
    // MUTATION (M-G3): the two wordings swapped -- this reads the other one.
    expect(report.toString(), contains(kNotInstalled));
    expect(report.toString(), isNot(contains(kUnavailable)));
    expect(DraftCanvas.debugResidentFallbackReports, 1);

    await t.pumpWidget(wrap(const SizedBox()));
    await t.pumpWidget(canvas());
    expect(state(t).resolvedBackend, RenderBackend.vertices);
    expect(t.takeException(), isNull, reason: 'once per process');
    expect(DraftCanvas.debugResidentFallbackReports, 1);
  });

  testWidgets(
      'an unavailable GPU registered: vertices, reported as "the installed '
      'resident GPU is unavailable", nothing uploaded', (t) async {
    final gpu = FakeResidentGpu(available: false);
    registerResidentGpu(gpu);
    await t.pumpWidget(canvas());
    await land(t);
    final s = state(t);
    // MUTATION (M-G3): `resolveBackend` ignoring `available` -- this canvas
    // would resolve to residentGpu and upload through the fake.
    expect(s.resolvedBackend, RenderBackend.vertices);
    expect(s.resident, isNull);
    expect(gpu.uploads, 0);
    final report = t.takeException();
    expect(report, isA<FlutterError>());
    // MUTATION (M-G3): the two wordings swapped.
    expect(report.toString(), contains(kUnavailable));
    expect(report.toString(), isNot(contains(kNotInstalled)));
    expect(DraftCanvas.debugResidentFallbackReports, 1);
  });

  testWidgets(
      'an available GPU registered: its uploader is used and its painter '
      'paints the frame', (t) async {
    final gpu = FakeResidentGpu();
    registerResidentGpu(gpu);
    await t.pumpWidget(canvas());
    final s = state(t);
    expect(s.resolvedBackend, RenderBackend.residentGpu);
    expect(s.resident, isNotNull);
    await land(t);
    // MUTATION (M-G3): `DraftCanvas` ignoring the registered uploader --
    // nothing reaches the fake, and no painter of its lands.
    expect(gpu.uploads, 1);
    final painter = gpu.uploader.painters.single;
    expect(s.resident!.backend, same(painter));
    expect(painter.paints, greaterThanOrEqualTo(1),
        reason: 'the landed frame went through the registered painter');
    expect(painter.lastViewport, kCanvas);
    expect(gpu.uploader.collections.single, same(s.resident!.collection));
    expect(t.takeException(), isNull);
    expect(DraftCanvas.debugResidentFallbackReports, 0);
  });

  testWidgets('registering null clears it: the next canvas falls back',
      (t) async {
    final gpu = FakeResidentGpu();
    registerResidentGpu(gpu);
    await t.pumpWidget(canvas());
    expect(state(t).resolvedBackend, RenderBackend.residentGpu);
    await land(t);
    await t.pumpWidget(wrap(const SizedBox()));

    registerResidentGpu(null);
    await t.pumpWidget(canvas());
    expect(state(t).resolvedBackend, RenderBackend.vertices);
    expect(state(t).resident, isNull);
    expect(t.takeException().toString(), contains(kNotInstalled));
    expect(gpu.uploads, 1, reason: 'only the first canvas uploaded');
  });

  testWidgets("the widget's own residentUploader wins over the registry's",
      (t) async {
    final gpu = FakeResidentGpu();
    registerResidentGpu(gpu);
    final own = FakeUploader();
    await t.pumpWidget(canvas(residentUploader: own.call));
    await land(t);
    final s = state(t);
    expect(s.resolvedBackend, RenderBackend.residentGpu);
    // MUTATION: the registry preferred over the widget's uploader.
    expect(own.collections, hasLength(1));
    expect(gpu.uploads, 0);
    expect(s.resident!.backend, same(own.painters.single));
    expect(own.painters.single.paints, greaterThanOrEqualTo(1));
    expect(t.takeException(), isNull);
  });
}
