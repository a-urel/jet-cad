import 'dart:typed_data';
import 'dart:ui' show Offset, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

/// A 100-unit view at site-plan magnitude. Its grid step is 64:
/// `2^floor(log2(100))`. Expected origins below are written as literals rather
/// than recomputed from that formula, which would only restate the code.
Aabb2 siteView({double at = 4500000}) =>
    Aabb2(Vector2(at, at), Vector2(at + 100, at + 100));

void main() {
  group('rebaseOriginFor', () {
    test('is stable while the camera moves within one grid step', () {
      // A per-frame origin that tracks the camera continuously changes the
      // float32 residual on every frame, so a straight pan makes geometry
      // shimmer. Snapping to a power-of-two grid means the origin only moves in
      // discrete jumps, and the residual stays bounded and reproducible.
      final a = rebaseOriginFor(siteView());
      final b = rebaseOriginFor(siteView(at: 4500001));
      expect(a.x, b.x);
      expect(a.y, b.y);
    });

    test('lands on the grid, at or below the view centre', () {
      final o = rebaseOriginFor(siteView());
      const centre = 4500050.0;

      expect(o.x, 4500032.0);
      expect(o.y, 4500032.0);
      expect(o.x % 64, 0, reason: 'a grid step of 64 divides the origin');
      expect(o.x, lessThanOrEqualTo(centre));
      expect(centre - o.x, lessThan(64), reason: 'within one step of the view');
    });

    test(
        'leaves a residual float32 can carry, where the raw coordinate is '
        'already lossy', () {
      final o = rebaseOriginFor(siteView());
      // The far corner of the view, with a fraction. Whole numbers up to 2^24
      // are still exact in float32; it is the fractional part that dies first,
      // and drawing coordinates are not whole numbers.
      const far = 4500100.125;

      final residual = far - o.x;
      expect(residual.abs(), lessThan(2 * 100),
          reason: 'the residual is bounded by the view span, not the origin');
      expect((_toFloat32(residual) - residual).abs(), lessThan(1e-3),
          reason: 'the residual survives the trip through Canvas');
      expect((_toFloat32(far) - far).abs(), greaterThan(0.1),
          reason: 'the un-rebased coordinate does not — float32 spacing at '
              '4.5e6 is 0.5, which is the whole reason the origin exists');
    });

    test('derives its step from the view span, so it works zoomed out', () {
      // Span 1e6: the step is 2^19 = 524288, and 4500000 / 524288 floors to 8.
      final o = rebaseOriginFor(
          Aabb2(Vector2(4000000, 4000000), Vector2(5000000, 5000000)));

      expect(o.x, 4194304.0);
      expect(o.x % 524288, 0);
      expect((5000000 - o.x).abs(), lessThanOrEqualTo(2 * 1e6));
    });

    test('snaps downward on negative coordinates, not toward zero', () {
      // Truncation would put the origin at -4500032, *above* the view, and the
      // residual would change sign as the camera crossed zero.
      final o = rebaseOriginFor(
          Aabb2(Vector2(-4500100, -4500100), Vector2(-4500000, -4500000)));

      expect(o.x, -4500096.0);
      expect(o.x, lessThanOrEqualTo(-4500050.0));
    });

    test('a degenerate view has its origin at the world origin', () {
      for (final box in [
        Aabb2.empty(),
        Aabb2(Vector2(5, 5), Vector2(5, 5)),
      ]) {
        final o = rebaseOriginFor(box);
        expect(o.x, 0.0);
        expect(o.y, 0.0);
        expect(o.x.isNaN, isFalse);
      }
    });
  });

  group('CameraController', () {
    CameraController fresh() => CameraController(ViewportTransform.fit(
        Aabb2(Vector2(0, 0), Vector2(100, 100)), const Size(800, 600)));

    test('panBy moves the screen position of a world point by the delta', () {
      final camera = fresh();
      final before = camera.value.worldToScreen(Vector2(50, 50));
      final scaleBefore = camera.value.scale;
      camera.panBy(const Offset(10, -5));
      final after = camera.value.worldToScreen(Vector2(50, 50));

      expect(after.x - before.x, closeTo(10, 1e-9));
      expect(after.y - before.y, closeTo(-5, 1e-9));
      expect(camera.value.scale, closeTo(scaleBefore, 1e-9),
          reason: 'a pan does not change the zoom');
    });

    test('panBy notifies, so a repaint boundary knows the frame is stale', () {
      final camera = fresh();
      var notifications = 0;
      camera.addListener(() => notifications++);
      camera.panBy(const Offset(10, -5));
      expect(notifications, 1);
    });

    test('zoomAt keeps the world point under the cursor fixed', () {
      final camera = fresh();
      const focus = Offset(320, 210);
      final before = camera.value.screenToWorld(Vector2(focus.dx, focus.dy));
      camera.zoomAt(focus, 2.5);
      final after = camera.value.screenToWorld(Vector2(focus.dx, focus.dy));

      expect(after.x, closeTo(before.x, 1e-9));
      expect(after.y, closeTo(before.y, 1e-9));
    });

    test('zoomAt multiplies the scale by the factor', () {
      final camera = fresh();
      final before = camera.value.scale;
      camera.zoomAt(const Offset(320, 210), 2.5);
      expect(camera.value.scale, closeTo(before * 2.5, 1e-9));
    });

    test('zoomAt ignores a factor that would make the camera singular', () {
      // A zero, negative or NaN factor reaches `invert()` in the
      // ViewportTransform constructor and throws there, taking the gesture —
      // and the frame — down with it. Holding the camera still is the only
      // meaning a zero-scale zoom could have.
      for (final factor in [0.0, -1.0, double.nan, double.infinity]) {
        final camera = fresh();
        final before = camera.value.worldToScreenMatrix;
        camera.zoomAt(const Offset(320, 210), factor);
        expect(camera.value.worldToScreenMatrix, same(before),
            reason: 'factor $factor must be a no-op');
      }
    });
  });

  group('CameraController bounds', () {
    // Off-origin world, non-identity fit: 100 x 50 into 800 x 600 gives a
    // scale of 0.95 * min(8, 12) = 7.6. A fixture at scale 1.0 could not
    // tell "clamp the factor" from "clamp the result" (spec, M-01l).
    CameraController bounded({double minScale = 0.5, double maxScale = 12.0}) =>
        CameraController(
          ViewportTransform.fit(Aabb2(Vector2(1000, 2000), Vector2(1100, 2050)),
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
}

double _toFloat32(double v) => (Float32List(1)..[0] = v)[0];
