import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'support/gesture_fixture.dart';

void main() {
  for (final policy in [GesturePolicy.wheelZooms, GesturePolicy.wheelPans]) {
    group(
        'PointerPanZoom under ${policy == GesturePolicy.wheelZooms ? 'wheelZooms' : 'wheelPans'}',
        () {
      // Two-finger scroll: `scale` stays exactly 1.0, motion is in `pan`.
      // `pan` is cumulative since the gesture began; the widget must use the
      // per-event `localPanDelta` (spec, M-01a), so three updates that
      // report 40, 80, 120 move the camera by 120, not 240.
      testWidgets('two-finger scroll pans by the delta and does not zoom',
          (tester) async {
        final camera = fitOffOrigin();
        await pumpDetector(tester, camera, policy);
        final before = screenOf(camera, kWorldProbe);
        final scaleBefore = camera.value.scale;

        final p = TestPointer(1, PointerDeviceKind.trackpad);
        await tester.sendEventToBinding(p.panZoomStart(globalFocus()));
        for (final dy in const [-40.0, -80.0, -120.0]) {
          await tester.sendEventToBinding(
              p.panZoomUpdate(globalFocus(), pan: Offset(0, dy)));
        }
        await tester.sendEventToBinding(p.panZoomEnd());
        await tester.pump();

        final after = screenOf(camera, kWorldProbe);
        expect(after.dx - before.dx, closeTo(0, 1e-9));
        expect(after.dy - before.dy, closeTo(-120, 1e-9),
            reason: 'content follows the fingers: +localPanDelta');
        expect(camera.value.scale, scaleBefore,
            reason: 'scale == 1.0 on every update: no zoom at all');
      });

      // Pinch: `scale` is cumulative and has no per-event delta, so each
      // update applies scale / running (spec, M-01b). A rising ramp of
      // cumulative values (1.2, 1.5, 2.0) lands the gesture on 2.0, not on
      // the product 3.6 a mutant that dropped the running division would
      // reach. The anchor is where the gesture started, not the viewport
      // centre.
      testWidgets('pinch zooms by the cumulative ratio about the anchor',
          (tester) async {
        final camera = fitOffOrigin();
        await pumpDetector(tester, camera, policy);
        final scaleBefore = camera.value.scale;
        final under =
            camera.value.screenToWorld(Vector2(kLocalFocus.dx, kLocalFocus.dy));

        final p = TestPointer(1, PointerDeviceKind.trackpad);
        await tester.sendEventToBinding(p.panZoomStart(globalFocus()));
        // A real pinch reports a rising cumulative scale. With the running
        // division each update applies only its increment (1.2, then 1.25,
        // then 1.333…) and the gesture lands on 2.0; applying the raw value
        // compounds to 1.2 × 1.5 × 2.0 = 3.6 (M-01b).
        for (final cumulative in const [1.2, 1.5, 2.0]) {
          await tester.sendEventToBinding(
              p.panZoomUpdate(globalFocus(), scale: cumulative));
        }
        await tester.sendEventToBinding(p.panZoomEnd());
        await tester.pump();

        expect(camera.value.scale / scaleBefore, closeTo(2.0, 1e-9));
        final still =
            camera.value.screenToWorld(Vector2(kLocalFocus.dx, kLocalFocus.dy));
        expect(still.x, closeTo(under.x, 1e-9));
        expect(still.y, closeTo(under.y, 1e-9),
            reason: 'the world point under the anchor did not move');
      });

      // macOS mixes them: a pinch that drifts reports both on one event.
      testWidgets('a drifting pinch pans by the delta and zooms by the ratio',
          (tester) async {
        final camera = fitOffOrigin();
        await pumpDetector(tester, camera, policy);
        final scaleBefore = camera.value.scale;

        final p = TestPointer(1, PointerDeviceKind.trackpad);
        await tester.sendEventToBinding(p.panZoomStart(globalFocus()));
        await tester.sendEventToBinding(p.panZoomUpdate(globalFocus(),
            pan: const Offset(25, -10), scale: 2.0));
        await tester.sendEventToBinding(p.panZoomEnd());
        await tester.pump();

        expect(camera.value.scale / scaleBefore, closeTo(2.0, 1e-9));
        // The pan is applied first, then the zoom about the (unmoved)
        // anchor. So the world point that sits under the anchor afterwards
        // is the one that was one pan-delta *behind* it before the gesture.
        final expected = fitOffOrigin()
            .value
            .screenToWorld(Vector2(kLocalFocus.dx - 25, kLocalFocus.dy + 10));
        final underAnchor =
            camera.value.screenToWorld(Vector2(kLocalFocus.dx, kLocalFocus.dy));
        expect(underAnchor.x, closeTo(expected.x, 1e-9));
        expect(underAnchor.y, closeTo(expected.y, 1e-9));
      });

      testWidgets('a second gesture starts from a clean running scale',
          (tester) async {
        final camera = fitOffOrigin();
        await pumpDetector(tester, camera, policy);

        final first = TestPointer(1, PointerDeviceKind.trackpad);
        await tester.sendEventToBinding(first.panZoomStart(globalFocus()));
        await tester
            .sendEventToBinding(first.panZoomUpdate(globalFocus(), scale: 2.0));
        await tester.sendEventToBinding(first.panZoomEnd());
        await tester.pump();
        final between = camera.value.scale;

        final second = TestPointer(2, PointerDeviceKind.trackpad);
        await tester.sendEventToBinding(second.panZoomStart(globalFocus()));
        await tester.sendEventToBinding(
            second.panZoomUpdate(globalFocus(), scale: 2.0));
        await tester.sendEventToBinding(second.panZoomEnd());
        await tester.pump();

        expect(camera.value.scale / between, closeTo(2.0, 1e-9));
      });

      testWidgets('a two-finger scroll does not notify for its unchanged scale',
          (tester) async {
        final camera = fitOffOrigin();
        await pumpDetector(tester, camera, policy);
        var notifications = 0;
        camera.addListener(() => notifications++);

        final p = TestPointer(1, PointerDeviceKind.trackpad);
        await tester.sendEventToBinding(p.panZoomStart(globalFocus()));
        await tester.sendEventToBinding(
            p.panZoomUpdate(globalFocus(), pan: const Offset(0, -40)));
        await tester.sendEventToBinding(p.panZoomEnd());
        await tester.pump();

        expect(notifications, 1, reason: 'one pan, no zoomAt(anchor, 1.0)');
      });
    });
  }
}
