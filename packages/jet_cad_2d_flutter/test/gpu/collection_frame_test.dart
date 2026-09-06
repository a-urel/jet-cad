import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

/// A drawing well away from the origin, and a live camera zoomed onto a
/// point far outside it: at [kLiveViewport] this camera sees NONE of the
/// extents, so a collection culled to the live viewport would be empty --
/// which is the mutation this file exists to kill.
const Aabb2 kExtents = Aabb2.raw(1000, 2000, 7000, 5000);
const Size kLiveViewport = Size(800, 600);
final ViewportTransform kLive = ViewportTransform(
    worldToScreenMatrix: const Transform2(3.2, 0, 0, -3.2, -20000.0, 30000.0));

void main() {
  test('the live camera at its own viewport sees none of the drawing', () {
    // Anti-vacuity for every test below.
    expect(kLive.visibleWorld(kLiveViewport).intersects(kExtents), isFalse);
  });

  test("the frame's visible world covers the extents", () {
    final f = collectionFrameFor(kLive, kExtents);
    final world = f.camera.visibleWorld(f.viewport);
    expect(world.minX, lessThanOrEqualTo(kExtents.minX));
    expect(world.minY, lessThanOrEqualTo(kExtents.minY));
    expect(world.maxX, greaterThanOrEqualTo(kExtents.maxX));
    expect(world.maxY, greaterThanOrEqualTo(kExtents.maxY));
  });

  test("scale and rotation are the live camera's; only the translation moves",
      () {
    final f = collectionFrameFor(kLive, kExtents);
    final c = f.camera.worldToScreenMatrix;
    final l = kLive.worldToScreenMatrix;
    expect(c.a, l.a);
    expect(c.b, l.b);
    expect(c.c, l.c);
    expect(c.d, l.d);
    final toLive = composeTransforms(l, c.invert());
    expect(toLive.a, closeTo(1, 1e-12));
    expect(toLive.b, closeTo(0, 1e-12));
    expect(toLive.c, closeTo(0, 1e-12));
    expect(toLive.d, closeTo(1, 1e-12));
    expect(toLive.e.abs() + toLive.f.abs(), greaterThan(1000),
        reason: 'the two cameras must actually differ, or the translation '
            'claim is vacuous');
  });

  test("the viewport is the extents' screen size plus the margin, all round",
      () {
    final f = collectionFrameFor(kLive, kExtents, margin: 10);
    expect(f.viewport.width, closeTo(6000 * 3.2 + 20, 1e-9));
    expect(f.viewport.height, closeTo(3000 * 3.2 + 20, 1e-9));
    // y is flipped, so the world's MAX y is the screen's min.
    final corner = f.camera.worldToScreen(Vector2(1000, 5000));
    expect(corner.x, closeTo(10, 1e-9));
    expect(corner.y, closeTo(10, 1e-9));
  });

  test('a rotated live camera keeps its rotation and still covers the extents',
      () {
    final rotated = ViewportTransform(
        worldToScreenMatrix: Transform2.translation(-9000, 400)
            .multiply(Transform2.rotation(0.4))
            .multiply(Transform2.scale(2.0, -2.0)));
    final f = collectionFrameFor(rotated, kExtents);
    expect(f.camera.worldToScreenMatrix.b, rotated.worldToScreenMatrix.b);
    expect(f.camera.worldToScreenMatrix.c, rotated.worldToScreenMatrix.c);
    final world = f.camera.visibleWorld(f.viewport);
    expect(world.minX, lessThanOrEqualTo(kExtents.minX));
    expect(world.maxY, greaterThanOrEqualTo(kExtents.maxY));
  });

  test('empty extents give the live camera back and a 1x1 viewport', () {
    final f = collectionFrameFor(kLive, Aabb2.empty());
    expect(identical(f.camera, kLive), isTrue);
    expect(f.viewport, const Size(1, 1));
  });
}
