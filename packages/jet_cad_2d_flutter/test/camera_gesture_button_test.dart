import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'support/gesture_fixture.dart';

Future<void> drag(WidgetTester tester, int buttons, Offset by) async {
  final g = await tester.createGesture(
      kind: PointerDeviceKind.mouse, buttons: buttons);
  await g.down(globalFocus());
  await g.moveBy(by);
  await g.up();
  await tester.pump();
}

void main() {
  for (final policy in [GesturePolicy.wheelZooms, GesturePolicy.wheelPans]) {
    final name =
        policy == GesturePolicy.wheelZooms ? 'wheelZooms' : 'wheelPans';

    testWidgets('middle-button drag pans by the pointer delta under $name',
        (tester) async {
      final camera = fitOffOrigin();
      await pumpDetector(tester, camera, policy);
      final before = screenOf(camera, kWorldProbe);
      final scaleBefore = camera.value.scale;

      await drag(tester, kMiddleMouseButton, const Offset(33, -21));

      final after = screenOf(camera, kWorldProbe);
      expect(after.dx - before.dx, closeTo(33, 1e-9));
      expect(after.dy - before.dy, closeTo(-21, 1e-9));
      expect(camera.value.scale, scaleBefore);
    });

    // Spec, D3: the left button belongs to sub-project 02 (selection, the
    // rubber band). The harness pans on any button (M-01i is that line).
    testWidgets('left-button drag moves nothing under $name', (tester) async {
      final camera = fitOffOrigin();
      await pumpDetector(tester, camera, policy);
      final before = camera.value.worldToScreenMatrix;

      await drag(tester, kPrimaryButton, const Offset(33, -21));

      expect(camera.value.worldToScreenMatrix, same(before));
    });

    testWidgets('right-button drag moves nothing under $name', (tester) async {
      final camera = fitOffOrigin();
      await pumpDetector(tester, camera, policy);
      final before = camera.value.worldToScreenMatrix;
      await drag(tester, kSecondaryMouseButton, const Offset(33, -21));
      expect(camera.value.worldToScreenMatrix, same(before));
    });
  }

  // Spec, "Cross-policy consistency": a desktop `localPanDelta` of d, a
  // trackpad-kind scroll of -d under wheelZooms and a mouse-kind scroll of
  // -d under wheelPans mean the same thing. This catches the arms
  // disagreeing; the absolute-direction assertions in the signal and
  // trackpad tests are what catch all three being wrong together.
  testWidgets('the three pan arms move the camera identically', (tester) async {
    const d = Offset(37, -29);

    final desktop = fitOffOrigin();
    await pumpDetector(tester, desktop, GesturePolicy.wheelZooms);
    final tp = TestPointer(1, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(tp.panZoomStart(globalFocus()));
    await tester.sendEventToBinding(tp.panZoomUpdate(globalFocus(), pan: d));
    await tester.sendEventToBinding(tp.panZoomEnd());
    await tester.pump();

    final chromium = fitOffOrigin();
    await pumpDetector(tester, chromium, GesturePolicy.wheelZooms);
    final cp = TestPointer(2, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(cp.hover(globalFocus()));
    await tester.sendEventToBinding(cp.scroll(-d));
    await tester.pump();

    final firefox = fitOffOrigin();
    await pumpDetector(tester, firefox, GesturePolicy.wheelPans);
    final fp = TestPointer(3, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(fp.hover(globalFocus()));
    await tester.sendEventToBinding(fp.scroll(-d));
    await tester.pump();

    for (final camera in [chromium, firefox]) {
      final a = camera.value.worldToScreenMatrix;
      final b = desktop.value.worldToScreenMatrix;
      expect(a.a, b.a);
      expect(a.d, b.d);
      expect(a.e, closeTo(b.e, 1e-9));
      expect(a.f, closeTo(b.f, 1e-9));
    }
    expect(desktop.value.worldToScreenMatrix.e,
        isNot(fitOffOrigin().value.worldToScreenMatrix.e),
        reason: 'and they all actually moved');
  });
}
