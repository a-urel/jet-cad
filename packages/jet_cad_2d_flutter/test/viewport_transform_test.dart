import 'dart:ui' show Offset, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

void main() {
  test('round-trips a point at site-plan magnitude in Float64', () {
    // 4.5e6 is ordinary in DXF and is where float32 spacing reaches ~0.5
    // units. The transform itself must never lose that; only the residual
    // handed to Canvas is allowed to be float32.
    final vt = ViewportTransform(
      worldToScreenMatrix: Transform2.translation(-4.5e6, -4.5e6)
          .multiply(Transform2.scale(2.0, 2.0)),
    );
    final world = Vector2(4500000.125, 4500000.375);
    final back = vt.screenToWorld(vt.worldToScreen(world));

    expect(back.x, closeTo(world.x, 1e-6));
    expect(back.y, closeTo(world.y, 1e-6));
  });

  test('visibleWorld covers the viewport corners under rotation', () {
    final vt = ViewportTransform(
      worldToScreenMatrix:
          Transform2.rotation(0.4).multiply(Transform2.scale(3.0, 3.0)),
    );
    final box = vt.visibleWorld(const Size(800, 600));
    for (final corner in [
      const Offset(0, 0),
      const Offset(800, 0),
      const Offset(0, 600),
      const Offset(800, 600),
    ]) {
      final w = vt.screenToWorld(Vector2(corner.dx, corner.dy));
      expect(box.containsPoint(w), isTrue,
          reason: 'a corner outside the culling rect is geometry never drawn');
    }
  });

  test('scale is the geometric mean of the axis scales', () {
    final vt =
        ViewportTransform(worldToScreenMatrix: Transform2.scale(2.0, 8.0));
    expect(vt.scale, closeTo(4.0, 1e-12));
  });

  group('fit', () {
    // 100 x 50 world, 800 x 600 viewport: width is the limiting axis, so the
    // scale is 0.95 * 800 / 100 = 7.6.
    final world = Aabb2(Vector2(0, 0), Vector2(100, 50));
    const viewport = Size(800, 600);

    test('puts the centre of the world box at the centre of the viewport', () {
      final vt = ViewportTransform.fit(world, viewport);
      final centre = vt.worldToScreen(Vector2(50, 25));
      expect(centre.x, closeTo(400, 1e-9));
      expect(centre.y, closeTo(300, 1e-9));
    });

    test('flips y, because world is y-up and screen is y-down', () {
      final vt = ViewportTransform.fit(world, viewport);
      final top = vt.worldToScreen(Vector2(50, 50));
      final bottom = vt.worldToScreen(Vector2(50, 0));
      expect(top.y, lessThan(bottom.y),
          reason: 'the world top edge must land above the bottom edge');
    });

    test('leaves a 5% margin on the limiting axis', () {
      final vt = ViewportTransform.fit(world, viewport);
      final span = vt.worldToScreen(Vector2(100, 0)).x -
          vt.worldToScreen(Vector2(0, 0)).x;
      expect(span, closeTo(0.95 * 800, 1e-9));
      expect(vt.scale, closeTo(7.6, 1e-9));
    });

    // Everything below reaches `invert()` with a matrix that would be singular
    // if the scale were left at 0, and would throw on the first frame the
    // widget builds. An empty document and a zero-size layout pass are both
    // ordinary states, not corrupt input.

    test('an empty document does not produce a singular transform', () {
      final vt = ViewportTransform.fit(Aabb2.empty(), viewport);
      expect(vt.scale, 1.0);
      final centre = vt.worldToScreen(Vector2.zero());
      expect(centre.x, closeTo(400, 1e-9));
      expect(centre.y, closeTo(300, 1e-9));
    });

    test(
        'a viewport laid out at zero size does not produce a singular '
        'transform', () {
      final vt = ViewportTransform.fit(world, Size.zero);
      expect(vt.scale, 1.0);
    });

    test('a world box with no height does not produce a singular transform',
        () {
      final vt = ViewportTransform.fit(
          Aabb2(Vector2(0, 0), Vector2(100, 0)), viewport);
      expect(vt.scale, 1.0);
    });
  });
}
