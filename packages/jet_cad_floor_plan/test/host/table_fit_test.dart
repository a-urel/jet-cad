// Zone spec Z3: the camera a framing sets -- the box grown by the margin,
// then about its centre to the minimum span, fitted with the 5 % margin and
// y flipped, its scale clamped about the same centre. Boxes are off the
// origin and not square.
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ViewportTransform;
import 'package:jet_cad_floor_plan/src/host/table_fit.dart';
import 'package:jet_cad_floor_plan/src/startup_plan.dart'
    show kMaxScale, kMinScale;
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// [camera] takes [box]'s centre to [viewport]'s within 1e-6 px, with y
/// flipped: a point above the centre is drawn above it, one right of it to
/// the right.
void expectCentred(ViewportTransform camera, Aabb2 box, Size viewport) {
  final c = camera.worldToScreen(box.center);
  expect(c.x, closeTo(viewport.width / 2, 1e-6), reason: 'centre x');
  expect(c.y, closeTo(viewport.height / 2, 1e-6), reason: 'centre y');
  final up = camera.worldToScreen(box.center + Vector2(0, 100));
  final right = camera.worldToScreen(box.center + Vector2(100, 0));
  expect(up.y, lessThan(c.y), reason: 'y up is drawn above');
  expect(right.x, greaterThan(c.x));
  final m = camera.worldToScreenMatrix;
  expect([m.b, m.c], [0, 0]);
  expect(m.d, -m.a, reason: 'one scale, y flipped');
}

void main() {
  test(
      'TF1 a 380 mm stool in 1000 x 700: 3 m of floor on each axis, '
      'centred (M-Z4, M-Z6)', () {
    const box = Aabb2.raw(41210.25, -27390.5, 41590.25, -27010.5);
    const size = Size(1000, 700);
    final camera = frameTables(box, size);
    expect(camera.worldToScreenMatrix.a, closeTo(0.95 * 700 / 3000, 1e-15));
    expectCentred(camera, box, size);
  });

  test(
      'TF2 a box wide in x, flat in y: the margin on both sides of x, the '
      'minimum about the centre in y (M-Z5, M-Z6)', () {
    // 11,000 x 1,200 grows to 12,000 x 2,200, then 12,000 x 3,000. In
    // 1200 x 900 x binds: 0.1 against 0.3.
    const box = Aabb2.raw(39500.5, -36800.75, 50500.5, -35600.75);
    const size = Size(1200, 900);
    final camera = frameTables(box, size);
    expect(camera.worldToScreenMatrix.a,
        closeTo(0.95 * 1200 / (11000 + 2 * 500), 1e-15));
    expectCentred(camera, box, size);
  });

  test(
      'TF3 past the minimum on both axes: the margin on each, whichever '
      'axis binds (M-Z5)', () {
    // 4,000 x 2,600 grows to 5,000 x 3,600.
    const box = Aabb2.raw(-38250.5, 26100.25, -34250.5, 28700.25);
    const ySize = Size(1000, 700); // 0.2 against 0.194...: y binds
    final y = frameTables(box, ySize);
    expect(
        y.worldToScreenMatrix.a, closeTo(0.95 * 700 / (2600 + 2 * 500), 1e-15));
    expectCentred(y, box, ySize);
    const xSize = Size(900, 700); // 0.18 against 0.194...: x binds
    final x = frameTables(box, xSize);
    expect(
        x.worldToScreenMatrix.a, closeTo(0.95 * 900 / (4000 + 2 * 500), 1e-15));
    expectCentred(x, box, xSize);
  });

  test(
      'TF4 the clamp, about the centre: a 1e7 px view gives kMaxScale, a '
      '1e9 mm box kMinScale (M-Z4, M-Z6)', () {
    const small = Aabb2.raw(41210.25, -27390.5, 41590.25, -27010.5);
    const huge = Size(1e7, 7e6);
    final near = frameTables(small, huge);
    expect(near.worldToScreenMatrix.a, kMaxScale);
    expectCentred(near, small, huge);

    const wide = Aabb2.raw(4.5e6, -1.2e6, 4.5e6 + 1e9, -1.2e6 + 6e8);
    const size = Size(1000, 700);
    final far = frameTables(wide, size);
    expect(far.worldToScreenMatrix.a, kMinScale);
    expectCentred(far, wide, size);
  });
}
