import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

Future<DraftCanvasState> _pump(WidgetTester tester,
    {RenderBackend? backend}) async {
  final doc = generateDocument(40, dashedFraction: 0.5);
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
  test('the platform default is vertices everywhere but the web', () {
    // `kIsWeb` is false under `flutter_test`, so this pins the branch the
    // suite runs on; the web branch is pinned by reading `kIsWeb` back.
    expect(defaultRenderBackend(),
        kIsWeb ? RenderBackend.canvas : RenderBackend.vertices);
  });

  testWidgets('with no backend given, the widget resolves the platform default',
      (tester) async {
    final state = await _pump(tester);
    expect(state.resolvedBackend, defaultRenderBackend());
  });

  testWidgets('an explicit backend is honoured, not clamped', (tester) async {
    // Phase C forces `vertices` on the web to measure it. A parameter that
    // silently ignored what it was given would make that measurement a lie.
    for (final backend in RenderBackend.values) {
      final state = await _pump(tester, backend: backend);
      expect(state.resolvedBackend, backend, reason: '$backend');
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
    final doc = generateDocument(40, dashedFraction: 0.5);
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
}
