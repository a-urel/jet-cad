// Ported from jet_cad_floor_plan test/host/camera_test.dart (2b Task 9,
// spec S3 "The unit API": cameraValue, worldToGlobal, globalToWorld,
// fitToUnits): CM1, CM2, CM3, CM7 and CR2. CM4-CM6 and CM15 are 2a's
// (camera_test.dart); the others have no unit premise. Today's header
// follows.
//
// Host embedding API spec, Slice 1, G-2 and G-3: the public camera
// (`PlanCamera`, `PlanController.camera`), the canvas's place on
// the screen (`canvasRect`, `worldToGlobal`, `globalToWorld`), the zoom
// bounds and the fits clamped to them, the camera epoch, the commands
// (`panBy`, `zoomBy`, `centerOn`) and `FloorPlanView.userCamera`, over the
// shared non-degenerate fixture (embedding_fixture): tables 40 m off the
// origin, a panned camera at 0.37 px/mm. Expectations are computed here by
// the forward transform, never read back from the code under test.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/unit_embedding_fixture.dart';
import '../support/unit_fixtures.dart' show fxKit;

/// A controller over the fixture (today's defaulted to the selection mode;
/// the service mode is Task 11's: the design here).
PlanController controller({double? minScale, double? maxScale}) {
  final c = PlanController(
      kits: [fxKit()],
      json: embeddingPlanJson(),
      minScale: minScale ?? 0.001,
      maxScale: maxScale ?? 100);
  addTearDown(c.dispose);
  return c;
}

/// The host's canvas of [c], 1440 x 856 logical pixels at the top left of
/// a 1440 x 900 window, no rulers (today's selection-mode canvas size).
Widget hostOf(PlanController c) => MaterialApp(
    home: Scaffold(
        body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
                width: 1440,
                height: 856,
                child: PlanCanvas(controller: c, rulers: false)))));

Future<void> mount(WidgetTester tester, PlanController c) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(hostOf(c));
  await tester.pump();
  await tester.pump();
}

List<double> parts(ViewportTransform t) {
  final m = t.worldToScreenMatrix;
  return [m.a, m.b, m.c, m.d, m.e, m.f];
}

/// [t] panned by [d], by hand.
List<double> panned(ViewportTransform t, Offset d) {
  final m = t.worldToScreenMatrix;
  return [m.a, m.b, m.c, m.d, m.e + d.dx, m.f + d.dy];
}

/// World [x], [y] through [t].
Offset world(Transform2 t, double x, double y) =>
    Offset(t.a * x + t.c * y + t.e, t.b * x + t.d * y + t.f);

/// [table]'s box centre in the world, from the fixture.
Offset centreOfTable(EmbeddingTable table) => world(
    table.transform,
    (embeddingBox.minX + embeddingBox.maxX) / 2,
    (embeddingBox.minY + embeddingBox.maxY) / 2);

/// The first table numbered [number]'s box centre in the world.
Offset centreOf(String number) =>
    centreOfTable(embeddingTables.firstWhere((t) => t.number == number));

/// The page's centre in the world: the fixture's page, A4 landscape at
/// 1:50 from (37,000, -36,200).
const Offset pageCentre = Offset(37000 + 14850 / 2, -36200 + 10500 / 2);

Rect canvasOnScreen(WidgetTester tester) =>
    tester.getRect(find.byType(InteractionLayer));

/// Within 1e-6 px of [want] (screen).
void expectPixel(Offset got, Offset want, String reason) {
  expect(got.dx, closeTo(want.dx, 1e-6), reason: '$reason: x');
  expect(got.dy, closeTo(want.dy, 1e-6), reason: '$reason: y');
}

/// Within a relative 1e-12 of [want] (geometry).
Matcher near(double want) => closeTo(want, 1e-12 * math.max(want.abs(), 1.0));

Offset canvasOfCamera(ViewportTransform t, Offset w) {
  final p = canvasOf(t, w.dx, w.dy);
  return Offset(p.x, p.y);
}

void main() {
  test(
      'CM1 PlanCamera maps world to canvas and back by the transform, '
      'y flipped, and reads its scale and visible world (M-H5)', () {
    final t = embeddingCamera();
    final camera = PlanCamera(t);
    expect(camera.scale, closeTo(0.37, 1e-15));
    for (final table in embeddingTables.where((t) => t.finite)) {
      final w = centreOfTable(table);
      final want = canvasOfCamera(t, w);
      expectPixel(camera.worldToCanvas(w), want, 'table ${table.number}');
      final back = camera.canvasToWorld(want);
      expect(back.dx, near(w.dx), reason: 'table ${table.number}: x back');
      expect(back.dy, near(w.dy), reason: 'table ${table.number}: y back');
    }
    // The canvas's corners by the inverse, by hand: x = (px - e) / 0.37,
    // y = (py - f) / -0.37.
    const size = Size(1440, 856);
    final visible = camera.visibleWorld(size);
    expect(visible.left, near((0 + 14612.25) / 0.37));
    expect(visible.right, near((1440 + 14612.25) / 0.37));
    expect(visible.top, near((856 + 9431.5) / -0.37), reason: 'least y');
    expect(visible.bottom, near((0 + 9431.5) / -0.37));
  });

  test('CM2 two cameras are equal by their matrices, exactly', () {
    final a = PlanCamera(embeddingCamera());
    final b = PlanCamera(embeddingCamera());
    final moved = PlanCamera(ViewportTransform(
        worldToScreenMatrix:
            const Transform2(0.37, 0, 0, -0.37, -14612.25, -9431.25)));
    expect(identical(a, b), isFalse);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == moved, isFalse);
    expect(
        a.toString(),
        'PlanCamera(scale: ${a.scale}, matrix: [0.37, 0.0, 0.0, -0.37, '
        '-14612.25, -9431.5])');
  });

  testWidgets(
      'CM3 controller.camera: one value per camera position, identical '
      'between reads, new and heard on a change', (tester) async {
    final c = controller();
    c.camera.value = embeddingCamera();
    final first = c.cameraValue.value;
    expect(identical(c.cameraValue.value, first), isTrue);
    expect(first, PlanCamera(embeddingCamera()));
    var heard = 0;
    void listener() => heard++;
    c.cameraValue.addListener(listener);
    c.camera.panBy(const Offset(12.5, -3.25));
    expect(heard, 1);
    final second = c.cameraValue.value;
    expect(identical(second, first), isFalse);
    expect(identical(c.cameraValue.value, second), isTrue);
    expectPixel(
        second.worldToCanvas(centreOf('1')),
        canvasOfCamera(embeddingCamera(), centreOf('1')) +
            const Offset(12.5, -3.25),
        'panned');
    c.cameraValue.removeListener(listener);
    c.camera.panBy(const Offset(1, 1));
    expect(heard, 1);
  });

  testWidgets(
      'CM7 every fit is clamped to the bounds about the canvas centre: the '
      'nominal placement, the start fit, fitToView, fitToUnits (M-H6b)',
      (tester) async {
    final c = controller(maxScale: 0.01);
    expect(c.camera.value.scale, lessThanOrEqualTo(0.01 + 1e-15),
        reason: 'the nominal placement');
    final sheet = sheetWorldRect(
        c.document.components.get<PageComponent>(c.document.rootHandle)!);
    expect([
      sheet.minX,
      sheet.minY,
      sheet.maxX,
      sheet.maxY
    ], [
      37000,
      -36200,
      51850,
      -25700
    ], reason: 'premise: the page');
    await mount(tester, c);
    final centre = c.canvasRect.value!.size.center(Offset.zero);
    // Premise: unclamped, the page fit is 0.95 * 856 / 10500 = 0.077 px/mm.
    expect(c.canvasRect.value!.size, const Size(1440, 856));
    expect(c.cameraValue.value.scale, closeTo(0.01, 1e-15),
        reason: 'start fit');
    expectPixel(
        c.cameraValue.value.worldToCanvas(pageCentre), centre, 'start fit');

    c.camera.value = embeddingCamera();
    c.fitToView();
    await tester.pump();
    expect(c.cameraValue.value.scale, closeTo(0.01, 1e-15),
        reason: 'fitToView');
    expectPixel(
        c.cameraValue.value.worldToCanvas(pageCentre), centre, 'fitToView');

    expect(c.fitToUnits({'1'}), isTrue);
    await tester.pump();
    final t = embeddingTables.first.transform;
    final corners = [
      for (final (x, y) in [
        (embeddingBox.minX, embeddingBox.minY),
        (embeddingBox.maxX, embeddingBox.minY),
        (embeddingBox.maxX, embeddingBox.maxY),
        (embeddingBox.minX, embeddingBox.maxY),
      ])
        world(t, x, y)
    ];
    final xs = corners.map((p) => p.dx), ys = corners.map((p) => p.dy);
    final boxCentre = Offset(xs.reduce(math.min) / 2 + xs.reduce(math.max) / 2,
        ys.reduce(math.min) / 2 + ys.reduce(math.max) / 2);
    expect(c.cameraValue.value.scale, closeTo(0.01, 1e-15), reason: 'tables');
    expectPixel(c.cameraValue.value.worldToCanvas(boxCentre), centre, 'tables');

    final up = controller(minScale: 2);
    await tester.pumpWidget(hostOf(up));
    await tester.pump();
    await tester.pump();
    expect(up.cameraValue.value.scale, closeTo(2, 1e-12), reason: 'min');
    expectPixel(up.cameraValue.value.worldToCanvas(pageCentre), centre, 'min');
  });

  testWidgets(
      'CR2 a view moved by its parent\'s padding, not resized and not laid '
      'out again: canvasRect, worldToGlobal and globalToWorld follow '
      '(M-H19b canvasRect)', (tester) async {
    final c = controller();
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // One view instance: the padding's change rebuilds nothing below it.
    final view = PlanCanvas(controller: c);
    Widget at(EdgeInsets padding) => MaterialApp(
        home: Scaffold(
            body: Padding(
                padding: padding,
                child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(width: 1000, height: 700, child: view)))));
    await tester.pumpWidget(at(const EdgeInsets.only(left: 10, top: 20)));
    await tester.pump();
    await tester.pump();
    final before = c.canvasRect.value!;
    expect(before, canvasOnScreen(tester));
    c.camera.value = embeddingCamera();

    await tester.pumpWidget(at(const EdgeInsets.only(left: 130, top: 75)));
    await tester.pump();
    final after = c.canvasRect.value!;
    expect(after, canvasOnScreen(tester));
    expect(after.size, before.size);
    expect(after.topLeft - before.topLeft, const Offset(120, 55));

    final w = centreOf('1');
    final want =
        canvasOnScreen(tester).topLeft + canvasOfCamera(embeddingCamera(), w);
    expectPixel(c.worldToGlobal(w)!, want, 'worldToGlobal');
    final back = c.globalToWorld(want)!;
    expect(back.dx, near(w.dx));
    expect(back.dy, near(w.dy));
  });
}
