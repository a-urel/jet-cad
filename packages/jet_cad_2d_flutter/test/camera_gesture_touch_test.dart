// Spec 14t T2, R-12: two fingers pinch and pan. The camera is fitted off
// the origin (never the identity); the pinches sit off the view's centre and
// their fingers move asymmetrically, interleaved event by event as a real
// device sends them.
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/gesture_fixture.dart';

Future<TestGesture> finger(WidgetTester tester, int pointer, Offset local,
        {PointerDeviceKind kind = PointerDeviceKind.touch}) =>
    tester.startGesture(kDetectorTopLeft + local, pointer: pointer, kind: kind);

Future<void> to(TestGesture g, Offset local) =>
    g.moveTo(kDetectorTopLeft + local);

Vector2 worldAt(CameraController camera, Offset local) =>
    camera.value.screenToWorld(Vector2(local.dx, local.dy));

void main() {
  testWidgets(
      'CG1 a pinch keeps the world point under the midpoint under it and '
      'zooms by the span\'s ratio (M-14t-1, -2)', (tester) async {
    final camera = fitOffOrigin();
    await pumpDetector(tester, camera, GesturePolicy.wheelZooms);
    const a0 = Offset(100, 80), b0 = Offset(260, 200);
    final anchor = worldAt(camera, (a0 + b0) / 2);
    final scale0 = camera.value.scale;
    final a = await finger(tester, 1, a0);
    final b = await finger(tester, 2, b0);
    // A still; B away diagonally in four uneven steps.
    for (final p in const [
      Offset(275, 205),
      Offset(290, 222),
      Offset(318, 236),
      Offset(330, 250),
    ]) {
      await to(b, p);
    }
    const b1 = Offset(330, 250);
    final end = screenOf(camera, anchor);
    final mid = (a0 + b1) / 2;
    expect(end.dx, closeTo(mid.dx, 1e-6));
    expect(end.dy, closeTo(mid.dy, 1e-6));
    expect(camera.value.scale / scale0,
        closeTo((a0 - b1).distance / (a0 - b0).distance, 1e-9));
    await a.up();
    await b.up();
  });

  testWidgets(
      'CG2 two fingers moving together pan with them and barely zoom '
      '(M-14t-3)', (tester) async {
    final camera = fitOffOrigin();
    await pumpDetector(tester, camera, GesturePolicy.wheelZooms);
    const a0 = Offset(90, 120), b0 = Offset(210, 170);
    final anchor = worldAt(camera, (a0 + b0) / 2);
    final scale0 = camera.value.scale;
    final a = await finger(tester, 1, a0);
    final b = await finger(tester, 2, b0);
    for (var i = 1; i <= 3; i++) {
      await to(a, a0 + Offset(10.0 * i, -20.0 / 3 * i));
      await to(b, b0 + Offset(10.0 * i, -20.0 / 3 * i));
    }
    final end = screenOf(camera, anchor);
    final mid = (a0 + b0) / 2 + const Offset(30, -20);
    expect(end.dx, closeTo(mid.dx, 1e-6));
    expect(end.dy, closeTo(mid.dy, 1e-6));
    expect(camera.value.scale / scale0, closeTo(1, 1e-9));
    await a.up();
    await b.up();
  });

  testWidgets(
      'CG3 a pair finger lifting with a third down re-bases: no jump '
      '(M-14t-4)', (tester) async {
    final camera = fitOffOrigin();
    await pumpDetector(tester, camera, GesturePolicy.wheelZooms);
    final a = await finger(tester, 1, const Offset(100, 100));
    final b = await finger(tester, 2, const Offset(200, 150));
    await to(b, const Offset(220, 160));
    final c = await finger(tester, 3, const Offset(300, 60));
    final before = camera.value.worldToScreenMatrix;
    await to(c, const Offset(310, 70));
    expect(camera.value.worldToScreenMatrix, same(before),
        reason: 'a third finger is not in the pair');
    await a.up();
    expect(camera.value.worldToScreenMatrix, same(before), reason: 'the lift');
    // The pair is (B at 220,160; C at 310,70): C moves away from B.
    final anchor = worldAt(camera, const Offset(265, 115));
    final scale0 = camera.value.scale;
    await to(c, const Offset(330, 50));
    final mid = (const Offset(220, 160) + const Offset(330, 50)) / 2;
    final end = screenOf(camera, anchor);
    expect(end.dx, closeTo(mid.dx, 1e-6));
    expect(end.dy, closeTo(mid.dy, 1e-6));
    expect(
        camera.value.scale / scale0,
        closeTo(
            (const Offset(330, 50) - const Offset(220, 160)).distance /
                (const Offset(310, 70) - const Offset(220, 160)).distance,
            1e-9));
    await b.up();
    await c.up();
  });

  testWidgets(
      'CG4 fingers closer than kPinchMinSpan pan but do not zoom '
      '(M-14t-21)', (tester) async {
    final camera = fitOffOrigin();
    await pumpDetector(tester, camera, GesturePolicy.wheelZooms);
    final scale0 = camera.value.scale;
    final a = await finger(tester, 1, const Offset(150, 150));
    final b = await finger(tester, 2, const Offset(152, 150));
    await to(b, const Offset(170, 150));
    expect(camera.value.scale, scale0, reason: 'from a 2 px span');
    await to(b, const Offset(190, 150));
    expect(camera.value.scale / scale0, closeTo(40 / 20, 1e-9),
        reason: 'from 20 px on, it zooms');
    await a.up();
    await b.up();
  });

  testWidgets(
      'CG5 a stylus and a finger, or one finger, move nothing (T1, '
      'M-14t-25)', (tester) async {
    final camera = fitOffOrigin();
    await pumpDetector(tester, camera, GesturePolicy.wheelZooms);
    final before = camera.value.worldToScreenMatrix;
    final s = await finger(tester, 1, const Offset(100, 100),
        kind: PointerDeviceKind.stylus);
    final f = await finger(tester, 2, const Offset(250, 200));
    await to(s, const Offset(60, 80));
    await to(f, const Offset(300, 240));
    await s.up();
    await to(f, const Offset(320, 250));
    await f.up();
    expect(camera.value.worldToScreenMatrix, same(before));
  });

  testWidgets('CG6 the camera\'s bounds hold under a pinch (F-7)',
      (tester) async {
    final camera = fitOffOrigin(maxScale: 5);
    await pumpDetector(tester, camera, GesturePolicy.wheelZooms);
    final a = await finger(tester, 1, const Offset(150, 150));
    final b = await finger(tester, 2, const Offset(170, 150));
    await to(b, const Offset(350, 150));
    expect(camera.value.scale, closeTo(5, 1e-9));
    await a.up();
    await b.up();
  });
}
