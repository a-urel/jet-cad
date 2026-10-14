// Spec 2a P2 "Camera" (today's G-3): the zoom bounds, panBy, zoomBy,
// centerOn and fitToView on the controller. CM4, CM5 (first half), CM6 and
// CM15 are jet_cad_floor_plan's camera_test.dart, assertions unchanged; a
// mounted view is replaced by the report a canvas makes (canvasPlaced).
// Expectations are computed by the forward transform, never read back.
import 'package:flutter/widgets.dart' show Offset, Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/test_kit.dart';

List<double> parts(ViewportTransform t) {
  final m = t.worldToScreenMatrix;
  return [m.a, m.b, m.c, m.d, m.e, m.f];
}

List<double> panned(ViewportTransform t, Offset d) {
  final m = t.worldToScreenMatrix;
  return [m.a, m.b, m.c, m.d, m.e + d.dx, m.f + d.dy];
}

Offset canvasOfCamera(ViewportTransform t, Offset w) {
  final m = t.worldToScreenMatrix;
  return Offset(m.a * w.dx + m.c * w.dy + m.e, m.b * w.dx + m.d * w.dy + m.f);
}

Offset canvasToWorld(ViewportTransform t, Offset p) {
  final w = t.screenToWorld(Vector2(p.dx, p.dy));
  return Offset(w.x, w.y);
}

void expectPixel(Offset got, Offset want, String reason) {
  expect(got.dx, closeTo(want.dx, 1e-6), reason: '$reason: x');
  expect(got.dy, closeTo(want.dy, 1e-6), reason: '$reason: y');
}

/// Where a mounted editor's canvas would report itself.
const Rect canvasRect = Rect.fromLTWH(264, 68, 1176, 832);

void main() {
  testWidgets(
      "CM4 the zoom bounds: today's by default, the constructor's when given, "
      'an ArgumentError unless finite and 0 < min < max', (tester) async {
    final c = controllerFor(kits: [testKit()]);
    expect(c.camera.minScale, 0.001);
    expect(c.camera.maxScale, 100);
    final d = controllerFor(kits: [testKit()], minScale: 0.02, maxScale: 3.5);
    expect(d.camera.minScale, 0.02);
    expect(d.camera.maxScale, 3.5);
    // M-CM4: the `maxScale <= minScale` check removed.
    for (final (min, max) in [
      (0.0, 1.0),
      (-0.5, 1.0),
      (double.nan, 1.0),
      (double.infinity, 1.0),
      (1.0, 1.0),
      (2.0, 1.0),
      (0.1, double.infinity),
      (0.1, double.nan),
    ]) {
      expect(
          () => PlanController(kits: [testKit()], minScale: min, maxScale: max),
          throwsArgumentError,
          reason: '($min, $max)');
    }
  });

  testWidgets(
      'CM5 panBy acts at once and drops a request not yet performed with its '
      'target', (tester) async {
    final c = controllerFor(kits: [testKit()], json: slabPlanText());
    final before = c.camera.value;
    c.centerOn(const Offset(-2600, 1400), scale: 0.2);
    const d = Offset(37.25, -11.5);
    c.panBy(d);
    expect(parts(c.camera.value), panned(before, d));
    expect(() => c.panBy(const Offset(double.nan, 0)), throwsArgumentError);
    expect(parts(c.camera.value), panned(before, d));
    // M-CM5: the pending target kept by a camera command.
    expect(c.framingFor(canvasRect.size), isNull,
        reason: 'the centring was dropped with its target');
  });

  testWidgets(
      'CM6 zoomBy: false with no view or a bad factor, changing nothing; '
      'about the canvas centre or a focus; clamped to the bounds (M-H6)',
      (tester) async {
    final c = controllerFor(
        kits: [testKit()], json: slabPlanText(), minScale: 0.2, maxScale: 0.5);
    final idle = c.camera.value;
    // M-CM6a: zoomBy acts with no canvas reported.
    expect(c.zoomBy(1.5), isFalse, reason: 'no view');
    expect(c.camera.value, same(idle));

    c.canvasPlaced(Object(), canvasRect);
    final size = c.canvasRect.value!.size;
    final centre = size.center(Offset.zero);
    c.camera.value = ViewportTransform(
        worldToScreenMatrix:
            const Transform2(0.37, 0, 0, -0.37, -14612.25, -9431.5));
    final placed = c.camera.value;
    for (final f in [0.0, -2.0, double.nan, double.infinity]) {
      expect(c.zoomBy(f), isFalse, reason: 'factor $f');
    }
    expect(c.zoomBy(1.2, focus: const Offset(double.nan, 0)), isFalse);
    expect(c.camera.value, same(placed));

    // The world at the centre, by the inverse of the fixture's camera.
    final mid =
        Offset((centre.dx + 14612.25) / 0.37, (centre.dy + 9431.5) / -0.37);
    // M-CM6b: zoomBy about the canvas's top left.
    expect(c.zoomBy(1.25), isTrue);
    expect(c.camera.value.scale, closeTo(0.37 * 1.25, 1e-12));
    expectPixel(
        canvasOfCamera(c.camera.value, mid), centre, 'the centre stays');

    expect(c.zoomBy(10), isTrue);
    expect(c.camera.value.scale, closeTo(0.5, 1e-12), reason: 'max');
    expectPixel(canvasOfCamera(c.camera.value, mid), centre,
        'the centre stays at the bound');

    const focus = Offset(310.5, 190.25);
    final under = canvasToWorld(c.camera.value, focus);
    expect(c.zoomBy(1e-6, focus: focus), isTrue);
    expect(c.camera.value.scale, closeTo(0.2, 1e-12), reason: 'min');
    expectPixel(
        canvasOfCamera(c.camera.value, under), focus, 'the focus stays');
  });

  testWidgets(
      "CM15 minScale has a floor of 1e-6, the bound decisions' tolerance "
      'times a thousand; at the floor the bound holds', (tester) async {
    // M-CM15: no floor (`_minScaleFloor = 0`).
    for (final min in [1e-9, 1e-10, 9.99e-7]) {
      expect(() => PlanController(kits: [testKit()], minScale: min),
          throwsArgumentError,
          reason: '$min');
    }
    final c = controllerFor(kits: [testKit()], minScale: 1e-6);
    expect(c.camera.minScale, 1e-6);
    c.canvasPlaced(Object(), canvasRect);
    expect(c.zoomBy(1e-12), isTrue);
    expect(c.camera.value.scale, closeTo(1e-6, 1e-18), reason: 'min');
  });

  testWidgets(
      'C-cam1 centerOn queues a centring the canvas performs, at the scale '
      "asked or, before the plan's first fit, the page fit's; fitToView "
      'replaces it; each request moves the epoch', (tester) async {
    final c = controllerFor(kits: [testKit()], json: slabPlanText());
    final viewport = canvasRect.size;
    final e0 = c.cameraEpoch;
    c.centerOn(const Offset(-2600, 1400), scale: 0.25);
    expect(c.cameraEpoch, e0 + 1);
    final framing = c.framingFor(viewport)!;
    // M-C-cam1a: the scale asked ignored.
    expect(framing.scale, closeTo(0.25, 1e-12));
    final p = framing.worldToScreen(Vector2(-2600, 1400));
    expect(p.x, closeTo(viewport.width / 2, 1e-6));
    expect(p.y, closeTo(viewport.height / 2, 1e-6));
    // M-C-cam1b: fitToView keeps the centring.
    c.fitToView();
    expect(c.framingFor(viewport), isNull, reason: 'the page');
    expect(c.cameraEpoch, e0 + 2);
    expect(() => c.centerOn(const Offset(double.infinity, 0)),
        throwsArgumentError);
    expect(() => c.centerOn(Offset.zero, scale: 0), throwsArgumentError);
    c.centerOn(const Offset(-2600, 1400));
    final page =
        c.document.components.get<PageComponent>(c.document.rootHandle)!;
    expect(c.framingFor(viewport)!.scale,
        closeTo(fitToPage(page, viewport).scale, 1e-12));
    expect(c.takeFitOnStart(), isTrue);
    expect(c.takeFitOnStart(), isTrue, reason: 'the centring is still owed');
    c.fitted();
    expect(c.takeFitOnStart(), isFalse);
  });
}
