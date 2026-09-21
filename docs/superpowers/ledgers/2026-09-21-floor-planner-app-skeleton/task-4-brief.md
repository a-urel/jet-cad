### Task 4: Scroll signals — modifier, then `kind`, then policy; and `PointerScaleEvent`

**Files:**
- Modify: `lib/src/camera_gesture_detector.dart` (add `onPointerSignal`)
- Test: `test/camera_gesture_signal_test.dart`

**Interfaces:**
- Consumes: Task 3's widget and fixture; `HardwareKeyboard.instance`;
  `PointerScrollEvent`, `PointerScaleEvent`.
- Produces: the scroll-signal rule of spec D3, in order: modifier held →
  zoom by `wheelZoomStep`; `kind == trackpad` → pan by `-scrollDelta`; else
  `policy.mouseWheel`. `PointerScaleEvent` → `zoomAt(localPosition,
  event.scale)`, raw.

- [ ] **Step 1: Write the failing signal tests**

`test/camera_gesture_signal_test.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'support/gesture_fixture.dart';

/// One wheel notch, the way a mouse reports it: scroll down is +dy.
const Offset kNotchDown = Offset(0, 120);
const Offset kNotchUp = Offset(0, -120);

Future<void> sendScroll(WidgetTester tester, PointerDeviceKind kind,
    Offset delta) async {
  final p = TestPointer(1, kind);
  await tester.sendEventToBinding(p.hover(globalFocus()));
  await tester.sendEventToBinding(p.scroll(delta));
  await tester.pump();
}

Future<void> sendScale(WidgetTester tester, double scale) async {
  final p = TestPointer(1, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(p.hover(globalFocus()));
  await tester.sendEventToBinding(p.scale(scale));
  await tester.pump();
}

void main() {
  group('mouse-kind scroll, no modifier', () {
    // Spec M-01c: about the pointer, not the viewport centre. The focus is
    // off centre and the assertion is that the world point under it stays.
    testWidgets('wheelZooms: zooms 1.1 per notch up about the pointer',
        (tester) async {
      final camera = fitOffOrigin();
      await pumpDetector(tester, camera, GesturePolicy.wheelZooms);
      final scaleBefore = camera.value.scale;
      final under =
          camera.value.screenToWorld(Vector2(kLocalFocus.dx, kLocalFocus.dy));

      await sendScroll(tester, PointerDeviceKind.mouse, kNotchUp);

      expect(camera.value.scale / scaleBefore, closeTo(1.1, 1e-9));
      final still =
          camera.value.screenToWorld(Vector2(kLocalFocus.dx, kLocalFocus.dy));
      expect(still.x, closeTo(under.x, 1e-9));
      expect(still.y, closeTo(under.y, 1e-9));
    });

    testWidgets('wheelZooms: a notch down zooms out by 1/1.1', (tester) async {
      final camera = fitOffOrigin();
      await pumpDetector(tester, camera, GesturePolicy.wheelZooms);
      final scaleBefore = camera.value.scale;
      await sendScroll(tester, PointerDeviceKind.mouse, kNotchDown);
      expect(camera.value.scale / scaleBefore, closeTo(1 / 1.1, 1e-9));
    });

    // Spec M-01e: the widget honours the *injected* policy. Under
    // wheelPans a mouse-kind scroll pans by -scrollDelta -- scroll down,
    // content moves up (spec M-01m: absolute direction, not just agreement).
    testWidgets('wheelPans: pans by -scrollDelta and does not zoom',
        (tester) async {
      final camera = fitOffOrigin();
      await pumpDetector(tester, camera, GesturePolicy.wheelPans);
      final before = screenOf(camera, kWorldProbe);
      final scaleBefore = camera.value.scale;

      await sendScroll(tester, PointerDeviceKind.mouse, kNotchDown);

      final after = screenOf(camera, kWorldProbe);
      expect(after.dy - before.dy, closeTo(-120, 1e-9),
          reason: 'scroll down: the content moves up');
      expect(after.dx - before.dx, closeTo(0, 1e-9));
      expect(camera.value.scale, scaleBefore);
    });
  });

  group('trackpad-kind scroll (a Chromium/WebKit browser trackpad)', () {
    // Spec M-01p: the `kind` test is not policy. Under wheelZooms a
    // trackpad-kind scroll still pans.
    for (final policy in [GesturePolicy.wheelZooms, GesturePolicy.wheelPans]) {
      testWidgets(
          'pans by -scrollDelta under ${policy == GesturePolicy.wheelZooms ? 'wheelZooms' : 'wheelPans'}',
          (tester) async {
        final camera = fitOffOrigin();
        await pumpDetector(tester, camera, policy);
        final before = screenOf(camera, kWorldProbe);
        final scaleBefore = camera.value.scale;

        await sendScroll(
            tester, PointerDeviceKind.trackpad, const Offset(30, 50));

        final after = screenOf(camera, kWorldProbe);
        expect(after.dx - before.dx, closeTo(-30, 1e-9));
        expect(after.dy - before.dy, closeTo(-50, 1e-9));
        expect(camera.value.scale, scaleBefore);
      });
    }
  });

  group('modifier held', () {
    // Spec M-01f. `PointerScrollEvent` carries no modifier; the widget reads
    // `HardwareKeyboard.instance`, and the test holds the key down first.
    for (final key in [
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.metaLeft,
    ]) {
      for (final policy in [
        GesturePolicy.wheelZooms,
        GesturePolicy.wheelPans,
      ]) {
        testWidgets(
            '${key.keyLabel} + mouse scroll zooms about the pointer under '
            '${policy == GesturePolicy.wheelZooms ? 'wheelZooms' : 'wheelPans'}',
            (tester) async {
          final camera = fitOffOrigin();
          await pumpDetector(tester, camera, policy);
          final scaleBefore = camera.value.scale;
          final under = camera.value
              .screenToWorld(Vector2(kLocalFocus.dx, kLocalFocus.dy));

          await tester.sendKeyDownEvent(key);
          await sendScroll(tester, PointerDeviceKind.mouse, kNotchUp);
          await tester.sendKeyUpEvent(key);

          // Under wheelPans this is the arm that kills M-01f: with the
          // modifier ignored the scroll pans and the scale stays 1.0.
          expect(camera.value.scale / scaleBefore, closeTo(1.1, 1e-9));
          final still = camera.value
              .screenToWorld(Vector2(kLocalFocus.dx, kLocalFocus.dy));
          expect(still.x, closeTo(under.x, 1e-9));
          expect(still.y, closeTo(under.y, 1e-9));
        });
      }
    }
  });

  group('PointerScaleEvent (browser pinch, ctrl+wheel on Windows/Linux)', () {
    // Spec M-01g and M-01n: the branch exists, and the factor is applied
    // raw -- it is per-event, so three of 1.2 compound to 1.728.
    for (final policy in [GesturePolicy.wheelZooms, GesturePolicy.wheelPans]) {
      testWidgets(
          'zooms by the event scale about the pointer, compounding, under '
          '${policy == GesturePolicy.wheelZooms ? 'wheelZooms' : 'wheelPans'}',
          (tester) async {
        final camera = fitOffOrigin();
        await pumpDetector(tester, camera, policy);
        final scaleBefore = camera.value.scale;
        final under = camera.value
            .screenToWorld(Vector2(kLocalFocus.dx, kLocalFocus.dy));

        for (var i = 0; i < 3; i++) {
          await sendScale(tester, 1.2);
        }

        expect(camera.value.scale / scaleBefore,
            closeTo(math.pow(1.2, 3).toDouble(), 1e-9));
        final still = camera.value
            .screenToWorld(Vector2(kLocalFocus.dx, kLocalFocus.dy));
        expect(still.x, closeTo(under.x, 1e-9));
        expect(still.y, closeTo(under.y, 1e-9));
      });
    }

    testWidgets('a scale below 1 zooms out', (tester) async {
      final camera = fitOffOrigin();
      await pumpDetector(tester, camera, GesturePolicy.wheelZooms);
      final scaleBefore = camera.value.scale;
      await sendScale(tester, math.exp(-100 / 200));
      expect(camera.value.scale / scaleBefore, closeTo(math.exp(-0.5), 1e-9));
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/camera_gesture_signal_test.dart`
Expected: FAIL — every scroll and scale test finds the camera unmoved
(`closeTo(1.1)` against `1.0`; `-120` against `0`).

- [ ] **Step 3: Add the signal handler**

In `lib/src/camera_gesture_detector.dart`, add `import 'package:flutter/services.dart' show HardwareKeyboard;`
and, in the state class, before `build`:

```dart
  /// The scroll-signal rule, in the spec's order: a modifier held zooms; a
  /// trackpad-kind scroll pans; otherwise the policy decides.
  ///
  /// `PointerScrollEvent` carries no modifier fields, so the keyboard state
  /// is read from [HardwareKeyboard]. On a macOS browser a real ctrl+wheel
  /// reaches here as a plain scroll signal (the engine reserves the DOM
  /// `ctrlKey` for a synthesised pinch when the physical key is up); on a
  /// Windows or Linux browser it arrives as a [PointerScaleEvent] instead.
  /// Cmd+wheel is a plain scroll signal everywhere.
  ///
  /// A [PointerScaleEvent]'s `scale` is per-event -- the engine computes
  /// `exp(-deltaY / 200)` from each DOM event on its own -- so it is applied
  /// raw and **not** divided by the running trackpad value.
  void _onSignal(PointerSignalEvent event) {
    final camera = widget.camera;
    if (event is PointerScaleEvent) {
      camera.zoomAt(event.localPosition, event.scale);
      return;
    }
    if (event is! PointerScrollEvent) return;
    final policy = widget.policy;
    final keyboard = HardwareKeyboard.instance;
    final action = keyboard.isControlPressed || keyboard.isMetaPressed
        ? ScrollAction.zoom
        : event.kind == PointerDeviceKind.trackpad
            ? ScrollAction.pan
            : policy.mouseWheel;
    switch (action) {
      case ScrollAction.zoom:
        // Scroll up is negative dy on every platform Flutter reports.
        camera.zoomAt(
            event.localPosition,
            event.scrollDelta.dy < 0
                ? policy.wheelZoomStep
                : 1 / policy.wheelZoomStep);
      case ScrollAction.pan:
        // `scrollDelta` is content-scroll: positive dy is "scroll down", the
        // content moves up, so the camera pans by the negation.
        camera.panBy(-event.scrollDelta);
    }
  }
```

and in `build`, add `onPointerSignal: _onSignal,` to the `Listener`.

- [ ] **Step 4: Run to verify it passes**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test test/camera_gesture_signal_test.dart
CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

If `sendKeyDownEvent` does not make `HardwareKeyboard.instance.isControlPressed`
true in this SDK, the diagnostic is the modifier test failing with the
camera panned, not zoomed; ledger it and switch the test to
`simulateKeyDownEvent` from `flutter_test`'s `test_keyboard` (same key
argument) — do not weaken the assertion.

- [ ] **Step 5: Commit**

```sh
git status --short
git add packages/jet_cad_2d_flutter/lib/src/camera_gesture_detector.dart packages/jet_cad_2d_flutter/test/camera_gesture_signal_test.dart
git commit -m "feat(gestures): scroll signals -- modifier, then kind, then policy; PointerScaleEvent raw"
```

---

