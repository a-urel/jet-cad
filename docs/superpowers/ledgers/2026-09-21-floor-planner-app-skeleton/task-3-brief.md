### Task 3: `CameraGestureDetector` — the desktop trackpad path

**Files:**
- Create: `lib/src/camera_gesture_detector.dart`
- Modify: `lib/jet_cad_2d_flutter.dart` (one export)
- Create: `test/support/gesture_fixture.dart`
- Test: `test/camera_gesture_trackpad_test.dart`

**Interfaces:**
- Consumes: `CameraController.panBy`/`zoomAt` (Task 1), `GesturePolicy`
  (Task 2), `Listener`, `PointerPanZoomStartEvent`/`UpdateEvent`.
- Produces: `CameraGestureDetector({Key? key, required CameraController
  camera, required GesturePolicy policy, required Widget child})`. This task
  wires `onPointerPanZoomStart`/`Update` only; Task 4 adds `onPointerSignal`
  and Task 5 adds `onPointerMove`, each into the same `Listener`. The fixture
  file's `fitOffOrigin()`, `pumpDetector(tester, camera, policy)`,
  `screenOf(camera, world)`, `kWorldProbe` are used by Tasks 4 and 5.

- [ ] **Step 1: The fixture**

`test/support/gesture_fixture.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

/// The widget's size under test; the box is centred, so its top-left in
/// the 800 x 600 test surface is (200, 150).
const Size kDetectorSize = Size(400, 300);
const Offset kDetectorTopLeft = Offset(200, 150);

/// A world point inside the fitted view, off the view centre.
final Vector2 kWorldProbe = Vector2(1030, 2015);

/// A focus **off the viewport centre** (spec: M-01c cannot die at the
/// centre), in the detector's local coordinates.
const Offset kLocalFocus = Offset(70, 230);

/// Off-origin world (1000..1100 x 2000..2050) fitted into 400 x 300 with the
/// 5% margin: scale 0.95 * min(4, 6) = 3.8. Never the identity.
CameraController fitOffOrigin({double minScale = 0.0, double maxScale = double.infinity}) =>
    CameraController(
      ViewportTransform.fit(
          Aabb2(Vector2(1000, 2000), Vector2(1100, 2050)), kDetectorSize),
      minScale: minScale,
      maxScale: maxScale,
    );

/// Pumps a [CameraGestureDetector] over an inert child. The child is not a
/// `DraftCanvas`: these tests are about where the camera goes, and a canvas
/// would only add a document to keep paintable.
Future<void> pumpDetector(
    WidgetTester tester, CameraController camera, GesturePolicy policy) async {
  await tester.pumpWidget(Center(
    child: SizedBox(
      width: kDetectorSize.width,
      height: kDetectorSize.height,
      child: CameraGestureDetector(
        camera: camera,
        policy: policy,
        child: const ColoredBox(color: Color(0xFFFFFFFF)),
      ),
    ),
  ));
}

/// Where [world] is on the detector's surface, as an [Offset].
Offset screenOf(CameraController camera, Vector2 world) {
  final p = camera.value.worldToScreen(world);
  return Offset(p.x, p.y);
}

/// [kLocalFocus] in the test surface's global coordinates.
Offset globalFocus() => kDetectorTopLeft + kLocalFocus;
```

- [ ] **Step 2: Write the failing trackpad tests**

`test/camera_gesture_trackpad_test.dart`:

```dart
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'support/gesture_fixture.dart';

void main() {
  for (final policy in [GesturePolicy.wheelZooms, GesturePolicy.wheelPans]) {
    group('PointerPanZoom under ${policy == GesturePolicy.wheelZooms ? 'wheelZooms' : 'wheelPans'}',
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
      // update applies scale / running (spec, M-01b). Three updates
      // reporting 1.5 zoom by 1.5, not 1.5^3. The anchor is where the
      // gesture started, not the viewport centre.
      testWidgets('pinch zooms by the cumulative ratio about the anchor',
          (tester) async {
        final camera = fitOffOrigin();
        await pumpDetector(tester, camera, policy);
        final scaleBefore = camera.value.scale;
        final under = camera.value
            .screenToWorld(Vector2(kLocalFocus.dx, kLocalFocus.dy));

        final p = TestPointer(1, PointerDeviceKind.trackpad);
        await tester.sendEventToBinding(p.panZoomStart(globalFocus()));
        for (var i = 0; i < 3; i++) {
          await tester.sendEventToBinding(
              p.panZoomUpdate(globalFocus(), scale: 1.5));
        }
        await tester.sendEventToBinding(p.panZoomEnd());
        await tester.pump();

        expect(camera.value.scale / scaleBefore, closeTo(1.5, 1e-9));
        final still = camera.value
            .screenToWorld(Vector2(kLocalFocus.dx, kLocalFocus.dy));
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
        final underAnchor = camera.value
            .screenToWorld(Vector2(kLocalFocus.dx, kLocalFocus.dy));
        expect(underAnchor.x, closeTo(expected.x, 1e-9));
        expect(underAnchor.y, closeTo(expected.y, 1e-9));
      });

      testWidgets('a second gesture starts from a clean running scale',
          (tester) async {
        final camera = fitOffOrigin();
        await pumpDetector(tester, camera, policy);

        final first = TestPointer(1, PointerDeviceKind.trackpad);
        await tester.sendEventToBinding(first.panZoomStart(globalFocus()));
        await tester.sendEventToBinding(
            first.panZoomUpdate(globalFocus(), scale: 2.0));
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
```

- [ ] **Step 3: Run to verify it fails**

Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/camera_gesture_trackpad_test.dart`
Expected: compile error — `CameraGestureDetector` undefined.

- [ ] **Step 4: The widget, trackpad path only**

`lib/src/camera_gesture_detector.dart`:

```dart
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'camera_controller.dart';
import 'gesture_policy.dart';

/// Pans and zooms a [CameraController] from pointer input, wrapping the
/// view it drives.
///
/// A `Listener`, not a `GestureDetector`: the events this needs
/// (`onPointerSignal`, `onPointerPanZoomStart/Update`) are `Listener`'s, and
/// the arena a `GestureDetector` joins would have to be fought for nothing.
/// It is a separate widget rather than a `DraftCanvas` feature so a host that
/// drives the camera itself -- the measurement harness -- simply does not
/// use it.
///
/// Which input does what is the spec's D3 table. The desktop trackpad arrives
/// as a `PointerPanZoom*` sequence whose `pan` and `scale` are **cumulative
/// since the gesture began**; `localPanDelta` is the engine's own per-event
/// pan, and `scale` is divided by the running value so three updates of a
/// steady pinch to 1.5 zoom by 1.5, not 1.5^3. The anchor is held where the
/// gesture began, not under the drifting pointer.
class CameraGestureDetector extends StatefulWidget {
  const CameraGestureDetector({
    super.key,
    required this.camera,
    required this.policy,
    required this.child,
  });

  final CameraController camera;
  final GesturePolicy policy;
  final Widget child;

  @override
  State<CameraGestureDetector> createState() => _CameraGestureDetectorState();
}

class _CameraGestureDetectorState extends State<CameraGestureDetector> {
  /// The cumulative `scale` already applied from the gesture in progress.
  ///
  /// Reset when a gesture starts rather than when one ends: a start event is
  /// guaranteed to precede every update, an end event is not guaranteed to
  /// arrive at all.
  double _gestureZoom = 1.0;

  /// Where the trackpad gesture began, in this widget's coordinates.
  Offset _gestureAnchor = Offset.zero;

  void _onPanZoomStart(PointerPanZoomStartEvent event) {
    _gestureZoom = 1.0;
    _gestureAnchor = event.localPosition;
  }

  void _onPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    final camera = widget.camera;
    final delta = event.localPanDelta;
    if (delta != Offset.zero) camera.panBy(delta);
    final scale = event.scale;
    // `zoomAt` ignores a non-positive or non-finite factor, but the running
    // value must not be poisoned by one either.
    if (!scale.isFinite || scale <= 0) return;
    // A two-finger scroll reports scale == 1.0 on every update; zooming by
    // 1.0 would build a transform and notify for nothing (Ruling 01-4).
    if (scale == _gestureZoom) return;
    camera.zoomAt(_gestureAnchor, scale / _gestureZoom);
    _gestureZoom = scale;
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.opaque,
        onPointerPanZoomStart: _onPanZoomStart,
        onPointerPanZoomUpdate: _onPanZoomUpdate,
        child: widget.child,
      );
}
```

Add to `lib/jet_cad_2d_flutter.dart`, before `export 'src/canvas_draw_sink.dart';`:

```dart
export 'src/camera_gesture_detector.dart';
```

- [ ] **Step 5: Run to verify it passes**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test test/camera_gesture_trackpad_test.dart
CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

Expected: PASS, both policies, ten tests.

- [ ] **Step 6: Commit**

```sh
git status --short
git add packages/jet_cad_2d_flutter/lib/src/camera_gesture_detector.dart packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart packages/jet_cad_2d_flutter/test/support/gesture_fixture.dart packages/jet_cad_2d_flutter/test/camera_gesture_trackpad_test.dart
git commit -m "feat(gestures): CameraGestureDetector -- the desktop trackpad path, pan by delta, zoom by ratio"
```

---

