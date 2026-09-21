### Task 5: Buttons, the cross-policy consistency test, and the allocation invariant

**Files:**
- Modify: `lib/src/camera_gesture_detector.dart` (add `onPointerMove`)
- Test: `test/camera_gesture_button_test.dart`

**Interfaces:**
- Consumes: Tasks 3–4; `policy.panButtons`; `PointerMoveEvent.buttons`,
  `.delta`.
- Produces: middle-button drag pans by `event.delta`; any other button does
  nothing (spec M-01i). The widget is complete after this task.

- [ ] **Step 1: Write the failing button tests**

`test/camera_gesture_button_test.dart`:

```dart
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
    final name = policy == GesturePolicy.wheelZooms ? 'wheelZooms' : 'wheelPans';

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
  testWidgets('the three pan arms move the camera identically',
      (tester) async {
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
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/camera_gesture_button_test.dart`
Expected: the middle-button tests FAIL (camera unmoved); the others pass
vacuously — which is why the middle-button tests exist beside them.

- [ ] **Step 3: Add the move handler**

In the state class:

```dart
  /// A drag with a pan button held pans by the pointer's own delta. Any
  /// other button does nothing here: the left button belongs to selection
  /// (sub-project 02), and leaving it free now is cheaper than unpicking a
  /// learned behaviour later.
  void _onMove(PointerMoveEvent event) {
    if (event.buttons & widget.policy.panButtons != 0) {
      widget.camera.panBy(event.delta);
    }
  }
```

and `onPointerMove: _onMove,` in the `Listener`.

- [ ] **Step 4: Run everything, including the allocation invariant**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test test/camera_gesture_button_test.dart
CI=true flutter test test/invariants/paint_allocation_test.dart
CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

Expected: PASS. The allocation test does not exercise the widget (the
widget is not on the frame path), and it is run here to record that it
did not move.

- [ ] **Step 5: Commit**

```sh
git status --short
git add packages/jet_cad_2d_flutter/lib/src/camera_gesture_detector.dart packages/jet_cad_2d_flutter/test/camera_gesture_button_test.dart
git commit -m "feat(gestures): middle-button drag pans, other buttons do nothing; the three pan arms agree"
```

---

