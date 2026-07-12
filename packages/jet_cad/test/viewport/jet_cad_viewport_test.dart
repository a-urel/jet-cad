import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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

  Future<void> pumpViewport(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 1.0),
          // Center gives the SizedBox loose constraints — without it the
          // box is forced to the test screen size and the layout assertion
          // would see 800x600 instead of 400x300.
          child: Center(
            child: SizedBox(
              width: 400,
              height: 300,
              child: JetCadViewport(controller: controller),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows placeholder, then the flipped texture', (tester) async {
    await pumpViewport(tester);
    expect(controller.textureId, isNotNull);
    final texture = tester.widget<Texture>(find.byType(Texture));
    expect(texture.textureId, controller.textureId);
    expect(
      find.ancestor(of: find.byType(Texture), matching: find.byType(Transform)),
      findsWidgets,
      reason: 'GL rows are bottom-up — texture renders inside a flip',
    );
  });

  testWidgets('layout attach used the widget size', (tester) async {
    await pumpViewport(tester);
    // MediaQuery pins dpr to 1.0, so physical == logical.
    expect(fake.viewportSizes.single, (400, 300, 1.0));
  });

  testWidgets('primary drag orbits', (tester) async {
    await pumpViewport(tester);
    final before = fake.renderFrameCount;
    final gesture = await tester.startGesture(
        tester.getCenter(find.byType(JetCadViewport)),
        kind: PointerDeviceKind.mouse);
    await gesture.moveBy(const Offset(30, 10));
    await gesture.moveBy(const Offset(30, 10));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(fake.cameraLog.where((e) => e.startsWith('orbitStart')), isNotEmpty);
    expect(fake.cameraLog.where((e) => e.startsWith('orbit ')), isNotEmpty);
    expect(fake.renderFrameCount, greaterThan(before));
    expect(fake.selectionLog, isEmpty, reason: 'a drag is not a click');
  });

  testWidgets('secondary drag pans', (tester) async {
    await pumpViewport(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(JetCadViewport)),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.moveBy(const Offset(25, -5));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(fake.cameraLog.where((e) => e.startsWith('pan')), isNotEmpty);
  });

  testWidgets('scroll wheel zooms', (tester) async {
    await pumpViewport(tester);
    final center = tester.getCenter(find.byType(JetCadViewport));
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(center));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -120)));
    await tester.pumpAndSettle();
    expect(fake.cameraLog.where((e) => e.startsWith('zoom')), isNotEmpty);
  });

  testWidgets('click without drag selects', (tester) async {
    await pumpViewport(tester);
    final bodyId = await doc.makeBox(const Vec3(1, 1, 1));
    fake.nextPickResult = PickResult(entity: bodyId, body: bodyId);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(JetCadViewport));
    await tester.pumpAndSettle();
    expect(controller.selection, {bodyId});
    expect(fake.selectionLog.last, [bodyId.value]);
  });

  testWidgets('idle frames trigger no renders', (tester) async {
    await pumpViewport(tester);
    final settled = fake.renderFrameCount;
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(fake.renderFrameCount, settled);
  });
}
