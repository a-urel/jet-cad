### Task 1: The branch point, and `CameraController`'s bounds

**Files:**
- Modify: `lib/src/camera_controller.dart:37-64`
- Test: `test/camera_controller_test.dart` (append a group)

**Interfaces:**
- Consumes: `ValueNotifier`, `ViewportTransform.scale`, `Transform2`,
  `Tolerance.standard` from `jet_cad_2d`.
- Produces: `CameraController(super.initial, {double minScale = 0.0, double
  maxScale = double.infinity})`, fields `minScale`, `maxScale`; `zoomAt`
  lands on a bound within `Tolerance.standard` and returns without
  assigning when already at the bound it is pushed against. Tasks 3–5 and 8
  rely on `panBy(Offset)` and `zoomAt(Offset, double)` keeping their
  signatures.

- [ ] **Step 1: Record the branch point**

```sh
git worktree add ../jet-cad-plan-01 -b plan-01/app-skeleton main
cd ../jet-cad-plan-01/apps/dev_harness_2d && CI=true flutter test --concurrency=1 2>&1 | tail -3
```

Write the printed `+N` count into
`.superpowers/sdd/2026-09-21-floor-planner-app-skeleton/progress.md` as
"harness at branch point: N tests" with the commit hash. Spec criterion 10
is read against this number and no other. (STATUS says 82; the roadmap says
72; neither is assumed.)

- [ ] **Step 2: Write the failing bounds tests**

Append inside `main()` of `test/camera_controller_test.dart`, after the
existing `CameraController` group:

```dart
  group('CameraController bounds', () {
    // Off-origin world, non-identity fit: 100 x 50 into 800 x 600 gives a
    // scale of 0.95 * min(8, 12) = 7.6. A fixture at scale 1.0 could not
    // tell "clamp the factor" from "clamp the result" (spec, M-01l).
    CameraController bounded({double minScale = 0.5, double maxScale = 12.0}) =>
        CameraController(
          ViewportTransform.fit(
              Aabb2(Vector2(1000, 2000), Vector2(1100, 2050)),
              const Size(800, 600)),
          minScale: minScale,
          maxScale: maxScale,
        );
    const focus = Offset(130, 470);
    const tol = Tolerance.standard;

    test('defaults are unbounded, so an unbounded caller is unchanged', () {
      final camera = CameraController(ViewportTransform.fit(
          Aabb2(Vector2(0, 0), Vector2(100, 100)), const Size(800, 600)));
      expect(camera.minScale, 0.0);
      expect(camera.maxScale, double.infinity);
      final before = camera.value.scale;
      camera.zoomAt(focus, 1e6);
      expect(camera.value.scale, closeTo(before * 1e6, before * 1e6 * 1e-12));
    });

    test('an oversized zoom in lands on maxScale, not past it', () {
      final camera = bounded();
      expect(camera.value.scale, closeTo(7.6, 1e-9), reason: 'fixture');
      final under = camera.value.screenToWorld(Vector2(focus.dx, focus.dy));
      camera.zoomAt(focus, 10.0);
      expect(tol.eq(camera.value.scale, 12.0), isTrue,
          reason: 'landed on the bound: ${camera.value.scale}');
      final after = camera.value.screenToWorld(Vector2(focus.dx, focus.dy));
      expect(after.x, closeTo(under.x, 1e-9));
      expect(after.y, closeTo(under.y, 1e-9),
          reason: 'the clamp still zooms about the focus');
    });

    test('an oversized zoom out lands on minScale', () {
      final camera = bounded();
      camera.zoomAt(focus, 0.01);
      expect(tol.eq(camera.value.scale, 0.5), isTrue,
          reason: 'landed on the bound: ${camera.value.scale}');
    });

    test('a zoom that stays inside the bounds is not clamped', () {
      final camera = bounded();
      camera.zoomAt(focus, 1.5);
      expect(camera.value.scale, closeTo(7.6 * 1.5, 1e-9));
    });

    test('at a bound, pushing further does not notify', () {
      final camera = bounded();
      camera.zoomAt(focus, 10.0);
      var notifications = 0;
      camera.addListener(() => notifications++);
      camera.zoomAt(focus, 10.0);
      camera.zoomAt(focus, 1.0001);
      expect(notifications, 0, reason: 'at rest on maxScale');

      camera.zoomAt(focus, 0.001);
      expect(notifications, 1, reason: 'zooming back out is a real change');
      notifications = 0;
      camera.zoomAt(focus, 0.5);
      expect(notifications, 0, reason: 'at rest on minScale');
    });

    test('zoomAt still ignores a singular factor with bounds set', () {
      final camera = bounded();
      final before = camera.value.worldToScreenMatrix;
      for (final f in [0.0, -1.0, double.nan, double.infinity]) {
        camera.zoomAt(focus, f);
      }
      expect(camera.value.worldToScreenMatrix, same(before));
    });
  });
```

`Tolerance`, `Aabb2` and `Vector2` are already imported by this file.

- [ ] **Step 3: Run to verify it fails**

Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/camera_controller_test.dart`
Expected: compile error — `minScale` is not a named parameter of
`CameraController`.

- [ ] **Step 4: Implement the bounds**

Replace the `CameraController` class in `lib/src/camera_controller.dart`
(from `/// The camera.` to the end of the file) with:

```dart
/// The camera. A `ValueNotifier` so a change repaints inside a
/// `RepaintBoundary` without rebuilding the widget tree.
///
/// [minScale] and [maxScale] bound [ViewportTransform.scale] — the geometric
/// mean of the axis scales, the number stroke widths divide by. They default
/// to unbounded so a caller that passes nothing (the measurement harness) is
/// unaffected. The clamp lives here, not in a gesture widget, because a
/// keyboard zoom, a zoom-to-fit and a zoom-to-selection all pass through
/// [zoomAt] and a clamp in a widget guards only one of them.
class CameraController extends ValueNotifier<ViewportTransform> {
  CameraController(
    super.initial, {
    this.minScale = 0.0,
    this.maxScale = double.infinity,
  })  : assert(minScale >= 0.0),
        assert(maxScale > minScale);

  final double minScale;
  final double maxScale;

  /// The bound decisions compare a *derived* scale — `sqrt(|det|)` after a
  /// three-matrix product — against a bound, so they are geometric decisions
  /// and use a tolerance, not `==` (spec invariant 6).
  static const Tolerance _tolerance = Tolerance.standard;

  void panBy(Offset screenDelta) {
    final m = value.worldToScreenMatrix;
    value = ViewportTransform(
      worldToScreenMatrix: Transform2(
          m.a, m.b, m.c, m.d, m.e + screenDelta.dx, m.f + screenDelta.dy),
    );
  }

  /// Scales about a screen point, keeping the world point under it fixed.
  ///
  /// A factor that is not finite and positive is ignored rather than applied:
  /// it would make the matrix singular, and `invert()` in the
  /// [ViewportTransform] constructor would throw there, taking the gesture and
  /// the frame with it. Holding the camera still is the only meaning a
  /// zero-scale zoom could have.
  ///
  /// A result past a bound **lands on the bound**: the factor is reduced so
  /// the resulting scale is the bound, and the zoom still happens about
  /// [screenFocus]. Rejecting the gesture instead would make the view stick
  /// and jump. A gesture that pushes against a bound the camera already rests
  /// on returns before assigning, so nothing is notified and nothing repaints.
  void zoomAt(Offset screenFocus, double factor) {
    if (!factor.isFinite || factor <= 0) return;
    final current = value.scale;
    var f = factor;
    if (f > 1.0) {
      if (_tolerance.compare(current, maxScale) >= 0) return;
      if (_tolerance.compare(current * f, maxScale) > 0) f = maxScale / current;
    } else if (f < 1.0) {
      if (_tolerance.compare(current, minScale) <= 0) return;
      if (_tolerance.compare(current * f, minScale) < 0) f = minScale / current;
    }
    final m = value.worldToScreenMatrix;
    // The argument of `multiply` is applied first, so this scales in screen
    // space *after* the camera. Reversed, it would scale in world space and
    // the point under the cursor would drift.
    final about = Transform2.translation(screenFocus.dx, screenFocus.dy)
        .multiply(Transform2.scale(f, f))
        .multiply(Transform2.translation(-screenFocus.dx, -screenFocus.dy));
    value = ViewportTransform(worldToScreenMatrix: about.multiply(m));
  }
}
```

With `minScale == 0.0`, `compare(current, 0.0) <= 0` is false for every
positive scale and `compare(current * f, 0.0) < 0` is false for every
positive product, so the unbounded path is the old code line for line.

- [ ] **Step 5: Run to verify it passes, and that nothing else moved**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test test/camera_controller_test.dart
CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
cd ../../apps/dev_harness_2d && CI=true flutter test --concurrency=1 2>&1 | tail -3
```

Expected: all PASS; the harness prints the Step 1 count.

- [ ] **Step 6: Commit**

```sh
git status --short   # no analysis_options.yaml
git add packages/jet_cad_2d_flutter/lib/src/camera_controller.dart packages/jet_cad_2d_flutter/test/camera_controller_test.dart
git commit -m "feat(camera): minScale/maxScale bounds that land on the bound and rest silently"
```

---

