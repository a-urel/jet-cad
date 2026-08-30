import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_flutter/src/gpu/gpu_facade.dart';

Future<DraftCanvasState> _pump(WidgetTester tester,
    {RenderBackend? backend}) async {
  final measurer = FlutterTextMeasurer();
  addTearDown(measurer.clear);
  final doc = generateDocument(40, dashedFraction: 0.5, measurer: measurer);
  final index = SpatialIndex(doc);
  addTearDown(index.dispose);
  final camera = CameraController(
      ViewportTransform.fit(doc.extents, const Size(300, 300)));
  addTearDown(camera.dispose);
  final key = GlobalKey<DraftCanvasState>();
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(
      width: 300,
      height: 300,
      child: DraftCanvas(
          key: key,
          document: doc,
          index: index,
          camera: camera,
          backend: backend),
    ),
  ));
  return key.currentState!;
}

void main() {
  test('the platform default is vertices, unconditionally', () {
    // Plan 3d Phase C (Task 13) measured the web: CanvasKit's `drawVertices`
    // beat `drawPath` by 17-60x at 10,000-50,000 entities, wider than the
    // desktop margin that motivated the web exception in the first place.
    // `defaultRenderBackend()` no longer branches on `kIsWeb`.
    expect(defaultRenderBackend(), RenderBackend.vertices);
  });

  testWidgets('with no backend given, the widget resolves the platform default',
      (tester) async {
    final state = await _pump(tester);
    expect(state.resolvedBackend, defaultRenderBackend());
  });

  testWidgets('an explicit backend is honoured, not clamped', (tester) async {
    // Phase C forces `vertices` on the web to measure it. A parameter that
    // silently ignored what it was given would make that measurement a lie.
    // `residentGpu` is resolved through `resolveBackend()` and may differ from
    // the requested backend when GPU is unavailable; check the final resolved
    // backend against what `resolveBackend()` returns.
    for (final backend in RenderBackend.values) {
      final state = await _pump(tester, backend: backend);
      final expectedBackend = resolveBackend(backend);
      expect(state.resolvedBackend, expectedBackend, reason: '$backend');
    }
  });

  testWidgets('only the resolved backend builds a sink', (tester) async {
    // MUTATION: build both sinks unconditionally and this reads non-null in
    // the canvas row. Two live sinks is two paragraph caches and two buffers.
    final vertices = await _pump(tester, backend: RenderBackend.vertices);
    expect(vertices.vertices, isNotNull);

    final canvas = await _pump(tester, backend: RenderBackend.canvas);
    expect(canvas.vertices, isNull);
  });

  testWidgets('changing the backend prop rebuilds the sinks', (tester) async {
    // MUTATION: leave `backend` out of `didUpdateWidget`'s comparison and the
    // widget keeps drawing through the old sink after the prop changes.
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final doc = generateDocument(40, dashedFraction: 0.5, measurer: measurer);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final camera = CameraController(
        ViewportTransform.fit(doc.extents, const Size(300, 300)));
    addTearDown(camera.dispose);
    final key = GlobalKey<DraftCanvasState>();

    Widget build(RenderBackend backend) => Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 300,
            height: 300,
            child: DraftCanvas(
                key: key,
                document: doc,
                index: index,
                camera: camera,
                backend: backend),
          ),
        );

    await tester.pumpWidget(build(RenderBackend.canvas));
    expect(key.currentState!.vertices, isNull);
    await tester.pumpWidget(build(RenderBackend.vertices));
    expect(key.currentState!.vertices, isNotNull);
  });

  testWidgets(
      'an explicit residentGpu request resolves to vertices when unavailable',
      (tester) async {
    // MUTATION: if DraftCanvas does not route through `resolveBackend()`,
    // `residentGpu` silently uses the canvas sink instead of vertices. This
    // assertion fails: state.vertices would be null instead of notNull.
    debugSetGpuFactory(() => throw StateError('no gpu'));
    addTearDown(() => debugSetGpuFactory(null));
    final state = await _pump(tester, backend: RenderBackend.residentGpu);
    expect(state.resolvedBackend, RenderBackend.vertices);
    expect(state.vertices, isNotNull);
  });
}
