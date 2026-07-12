import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/jet_cad.dart';

import 'fake_binding.dart';

void main() {
  late FakeKernelBridge fake;
  late CadDocument doc;
  late FakeBinding binding;
  late ViewportController controller;

  setUp(() async {
    fake = FakeKernelBridge();
    doc = await CadDocument.create(fake, target: const TextureTarget());
    binding = FakeBinding();
    controller = ViewportController(document: doc, binding: binding);
  });

  tearDown(() {
    controller.dispose();
    doc.dispose();
  });

  testWidgets('first layout attaches: resize, register, fit, render',
      (tester) async {
    controller.handleLayout(const Size(200, 100), 2.0);
    await tester.pumpAndSettle();
    expect(fake.viewportSizes, [(400, 200, 2.0)],
        reason: 'physical px = logical × dpr');
    expect(binding.log.first, 'register 1');
    expect(controller.textureId, 7);
    expect(fake.cameraLog, contains('fitAll'));
    expect(fake.renderFrameCount, 1);
    expect(binding.log, contains('frame 7'));
  });

  testWidgets('same-size layouts do not resize again', (tester) async {
    controller.handleLayout(const Size(200, 100), 2.0);
    await tester.pumpAndSettle();
    controller.handleLayout(const Size(200, 100), 2.0);
    await tester.pump(const Duration(milliseconds: 200));
    expect(fake.viewportSizes.length, 1);
  });

  testWidgets('layout changes debounce into one resize + update + render',
      (tester) async {
    controller.handleLayout(const Size(200, 100), 2.0);
    await tester.pumpAndSettle();
    controller.handleLayout(const Size(210, 100), 2.0);
    await tester.pump(const Duration(milliseconds: 30));
    controller.handleLayout(const Size(300, 150), 2.0);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    expect(fake.viewportSizes, [(400, 200, 2.0), (600, 300, 2.0)],
        reason: 'intermediate 210 width never reaches the bridge');
    expect(binding.log, contains('update 7 2'));
    expect(fake.renderFrameCount, 2);
  });

  testWidgets('document changes trigger damage renders', (tester) async {
    controller.handleLayout(const Size(100, 100), 1.0);
    await tester.pumpAndSettle();
    final before = fake.renderFrameCount;
    await doc.makeBox(const Vec3(1, 1, 1));
    await tester.pumpAndSettle();
    expect(fake.renderFrameCount, greaterThan(before));
  });

  testWidgets('idle time renders nothing (no vsync loop)', (tester) async {
    controller.handleLayout(const Size(100, 100), 1.0);
    await tester.pumpAndSettle();
    final settled = fake.renderFrameCount;
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(fake.renderFrameCount, settled,
        reason: 'damage-driven: no renders without damage');
  });

  testWidgets('concurrent render requests coalesce', (tester) async {
    controller.handleLayout(const Size(100, 100), 1.0);
    await tester.pumpAndSettle();
    final before = fake.renderFrameCount;
    unawaited(controller.requestRender());
    unawaited(controller.requestRender());
    unawaited(controller.requestRender());
    await tester.pumpAndSettle();
    expect(fake.renderFrameCount - before, lessThanOrEqualTo(2),
        reason: 'requests while rendering collapse into one trailing render');
  });

  testWidgets('camera methods convert logical to physical px', (tester) async {
    controller.handleLayout(const Size(200, 100), 2.0);
    await tester.pumpAndSettle();
    await controller.orbitStart(const Offset(10, 20));
    await controller.orbitTo(const Offset(15, 25));
    await controller.panBy(const Offset(5, -3));
    await controller.zoomBy(1.5);
    await tester.pumpAndSettle();
    expect(
        fake.cameraLog,
        containsAllInOrder([
          'orbitStart 20.0 40.0',
          'orbit 30.0 50.0',
          'pan 10.0 -6.0',
          'zoom 1.5',
        ]));
  });

  testWidgets('selectAt picks, highlights, emits SelectionChanged',
      (tester) async {
    controller.handleLayout(const Size(100, 100), 1.0);
    await tester.pumpAndSettle();
    final bodyId = await doc.makeBox(const Vec3(1, 1, 1));
    fake.nextPickResult = PickResult(entity: bodyId, body: bodyId);
    final events = <SelectionChanged>[];
    final sub = controller.selectionChanges.listen(events.add);

    await controller.selectAt(const Offset(50, 50));
    await tester.pumpAndSettle();
    expect(controller.selection, {bodyId});
    expect(fake.selectionLog.last, [bodyId.value]);
    expect(events.single.selection, {bodyId});

    fake.nextPickResult = null;
    await controller.selectAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(controller.selection, isEmpty);
    expect(fake.selectionLog.last, isEmpty);
    expect(events.last.selection, isEmpty);
    // NOT awaited: broadcast-subscription cancel returns the root-zone
    // Future._nullFuture, and awaiting it resumes the test body on the real
    // event loop — outside testWidgets' FakeAsync pump — so every later
    // fake-zone microtask (including the framework's own post-test awaits)
    // hangs until the 10-minute timeout. Cancel is synchronous here anyway.
    unawaited(sub.cancel());
  });

  testWidgets('dispose unregisters the texture and stops reacting',
      (tester) async {
    controller.handleLayout(const Size(100, 100), 1.0);
    await tester.pumpAndSettle();
    controller.dispose();
    await tester.pumpAndSettle();
    expect(binding.log, contains('unregister 7'));
    final count = fake.renderFrameCount;
    await doc.makeBox(const Vec3(1, 1, 1));
    await tester.pumpAndSettle();
    expect(fake.renderFrameCount, count, reason: 'no renders after dispose');
  });
}
