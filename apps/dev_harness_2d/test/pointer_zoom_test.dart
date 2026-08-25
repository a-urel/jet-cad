// Zoom input wiring for the harness window.
//
// The defect these tests were written against: `Listener.onPointerSignal`
// alone. On macOS a trackpad never sends `PointerScrollEvent` -- a run of the
// harness with every pointer callback instrumented logged 709
// `PointerPanZoomUpdateEvent`s and zero pointer signals -- so both two-finger
// scroll and pinch reached a handler that ignored them and the camera never
// moved. Only a real mouse wheel takes the signal path.
//
// Scale is read off `worldToScreenMatrix.a`: the camera never rotates here, so
// the x scale is the zoom.
import 'package:dev_harness_2d/main.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

void main() {
  /// Pumps the harness over a small document and returns its camera.
  Future<CameraController> pumpHarness(WidgetTester tester) async {
    late CameraController camera;
    await tester.pumpWidget(HarnessApp(
      document: harnessDocument(200),
      onReady: (c, _, __, ___, ____, _____, ______) => camera = c,
    ));
    await tester.pump();
    return camera;
  }

  double scaleOf(CameraController camera) => camera.value.worldToScreenMatrix.a;

  testWidgets('trackpad two-finger scroll up zooms in', (tester) async {
    final camera = await pumpHarness(tester);
    final before = scaleOf(camera);
    final centre = tester.getCenter(find.byType(DraftCanvas));

    final pointer = TestPointer(1, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(pointer.panZoomStart(centre));
    // Scrolling up is negative pan on every platform Flutter reports, and
    // Flutter's own conversion is exp(pan.dy * -1/200).
    await tester.sendEventToBinding(
        pointer.panZoomUpdate(centre, pan: const Offset(0, -100)));
    await tester.sendEventToBinding(pointer.panZoomEnd());
    await tester.pump();

    expect(scaleOf(camera) / before, closeTo(1.6487212707, 1e-6));
  });

  testWidgets('trackpad two-finger scroll down zooms out', (tester) async {
    final camera = await pumpHarness(tester);
    final before = scaleOf(camera);
    final centre = tester.getCenter(find.byType(DraftCanvas));

    final pointer = TestPointer(1, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(pointer.panZoomStart(centre));
    await tester.sendEventToBinding(
        pointer.panZoomUpdate(centre, pan: const Offset(0, 100)));
    await tester.sendEventToBinding(pointer.panZoomEnd());
    await tester.pump();

    expect(scaleOf(camera) / before, closeTo(1 / 1.6487212707, 1e-6));
  });

  testWidgets('pinch open zooms in by the reported scale', (tester) async {
    final camera = await pumpHarness(tester);
    final before = scaleOf(camera);
    final centre = tester.getCenter(find.byType(DraftCanvas));

    final pointer = TestPointer(1, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(pointer.panZoomStart(centre));
    await tester.sendEventToBinding(pointer.panZoomUpdate(centre, scale: 1.5));
    await tester.sendEventToBinding(pointer.panZoomEnd());
    await tester.pump();

    expect(scaleOf(camera) / before, closeTo(1.5, 1e-9));
  });

  testWidgets('pinch closed zooms out', (tester) async {
    final camera = await pumpHarness(tester);
    final before = scaleOf(camera);
    final centre = tester.getCenter(find.byType(DraftCanvas));

    final pointer = TestPointer(1, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(pointer.panZoomStart(centre));
    await tester.sendEventToBinding(pointer.panZoomUpdate(centre, scale: 0.5));
    await tester.sendEventToBinding(pointer.panZoomEnd());
    await tester.pump();

    expect(scaleOf(camera) / before, closeTo(0.5, 1e-9));
  });

  // `pan` and `scale` on a `PointerPanZoomUpdateEvent` are both cumulative
  // since the gesture started, not per-event deltas. A handler that applies
  // the reported value directly on every update compounds it: three updates
  // of a steady pinch to 1.5 would zoom by 1.5^3. This is the test that says
  // so.
  testWidgets('a gesture reporting cumulative values does not compound',
      (tester) async {
    final camera = await pumpHarness(tester);
    final before = scaleOf(camera);
    final centre = tester.getCenter(find.byType(DraftCanvas));

    final pointer = TestPointer(1, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(pointer.panZoomStart(centre));
    for (var i = 0; i < 3; i++) {
      await tester
          .sendEventToBinding(pointer.panZoomUpdate(centre, scale: 1.5));
    }
    await tester.sendEventToBinding(pointer.panZoomEnd());
    await tester.pump();

    expect(scaleOf(camera) / before, closeTo(1.5, 1e-9));
  });

  // Pan and scale arrive on the same event, and macOS mixes them: a pinch
  // that drifts reports both. The factor is the product, which is what
  // Flutter's own `ScaleGestureRecognizer` computes.
  testWidgets('pan and scale on one event combine', (tester) async {
    final camera = await pumpHarness(tester);
    final before = scaleOf(camera);
    final centre = tester.getCenter(find.byType(DraftCanvas));

    final pointer = TestPointer(1, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(pointer.panZoomStart(centre));
    await tester.sendEventToBinding(
        pointer.panZoomUpdate(centre, pan: const Offset(0, -100), scale: 1.5));
    await tester.sendEventToBinding(pointer.panZoomEnd());
    await tester.pump();

    expect(scaleOf(camera) / before, closeTo(1.5 * 1.6487212707, 1e-6));
  });

  // A second gesture must start from a clean slate. If the running factor
  // survives the end of the first, the second gesture divides by it and
  // zooms the wrong way.
  testWidgets('a second gesture starts from a clean factor', (tester) async {
    final camera = await pumpHarness(tester);
    final centre = tester.getCenter(find.byType(DraftCanvas));

    final first = TestPointer(1, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(first.panZoomStart(centre));
    await tester.sendEventToBinding(first.panZoomUpdate(centre, scale: 2.0));
    await tester.sendEventToBinding(first.panZoomEnd());
    await tester.pump();

    final between = scaleOf(camera);
    final second = TestPointer(2, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(second.panZoomStart(centre));
    await tester.sendEventToBinding(second.panZoomUpdate(centre, scale: 2.0));
    await tester.sendEventToBinding(second.panZoomEnd());
    await tester.pump();

    expect(scaleOf(camera) / between, closeTo(2.0, 1e-9));
  });

  // The mouse-wheel path predates the trackpad one and stays. A real mouse
  // still sends pointer signals, and this is the regression guard that the
  // trackpad work did not take the wheel with it.
  testWidgets('mouse wheel still zooms through the signal path',
      (tester) async {
    final camera = await pumpHarness(tester);
    final before = scaleOf(camera);
    final centre = tester.getCenter(find.byType(DraftCanvas));

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    pointer.hover(centre);
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -50)));
    await tester.pump();

    expect(scaleOf(camera) / before, closeTo(1.1, 1e-9));
  });
}
