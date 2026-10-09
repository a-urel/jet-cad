// Host embedding API spec, Slice 1, G-2 and G-3: the public camera
// (`FloorPlanCamera`, `FloorPlanController.camera`), the canvas's place on
// the screen (`canvasRect`, `worldToGlobal`, `globalToWorld`), the zoom
// bounds and the fits clamped to them, the camera epoch, the commands
// (`panBy`, `zoomBy`, `centerOn`) and `FloorPlanView.userCamera`, over the
// shared non-degenerate fixture (embedding_fixture): tables 40 m off the
// origin, a panned camera at 0.37 px/mm. Expectations are computed here by
// the forward transform, never read back from the code under test.
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/gestures.dart' show kMiddleMouseButton;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_camera.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_controller.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_view.dart';
import 'package:jet_cad_floor_plan/src/planner_shell.dart';

import 'embedding_fixture.dart';

/// A controller over the fixture, in the selection mode unless [design].
FloorPlanController controller(
    {double? minScale, double? maxScale, bool design = false}) {
  final c = FloorPlanController(
      json: embeddingPlanJson(),
      minScale: minScale ?? 0.001,
      maxScale: maxScale ?? 100);
  addTearDown(c.dispose);
  if (!design) c.setMode(FloorPlanMode.selection);
  return c;
}

/// The host's view of [c], 1440 x 900 logical pixels.
Widget hostOf(FloorPlanController c,
        {bool userCamera = true, void Function(String)? onTableTap}) =>
    MaterialApp(
        home: Scaffold(
            body: FloorPlanView(
                controller: c,
                userCamera: userCamera,
                onTableTap: onTableTap)));

Future<void> mount(WidgetTester tester, FloorPlanController c,
    {bool userCamera = true, void Function(String)? onTableTap}) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester
      .pumpWidget(hostOf(c, userCamera: userCamera, onTableTap: onTableTap));
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

/// The page fitted to [c]'s canvas as the engine fits it, unclamped (the
/// default bounds hold it).
ViewportTransform pageFitOf(FloorPlanController c) => fitToPage(
    c.activeDocument.components
        .get<PageComponent>(c.activeDocument.rootHandle)!,
    c.canvasRect.value!.size);

/// The host's view of [c] at the top left, [width] x 700, in a 1440 x 900
/// window: 0 wide, it has no size yet.
Widget sizedHostOf(FloorPlanController c, double width) => MaterialApp(
    home: Scaffold(
        body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
                width: width,
                height: 700,
                child: FloorPlanView(controller: c)))));

void main() {
  test(
      'CM1 FloorPlanCamera maps world to canvas and back by the transform, '
      'y flipped, and reads its scale and visible world (M-H5)', () {
    final t = embeddingCamera();
    final camera = FloorPlanCamera(t);
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
    final a = FloorPlanCamera(embeddingCamera());
    final b = FloorPlanCamera(embeddingCamera());
    final moved = FloorPlanCamera(ViewportTransform(
        worldToScreenMatrix:
            const Transform2(0.37, 0, 0, -0.37, -14612.25, -9431.25)));
    expect(identical(a, b), isFalse);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == moved, isFalse);
    expect(
        a.toString(),
        'FloorPlanCamera(scale: ${a.scale}, matrix: [0.37, 0.0, 0.0, -0.37, '
        '-14612.25, -9431.5])');
  });

  testWidgets(
      'CM3 controller.camera: one value per camera position, identical '
      'between reads, new and heard on a change', (tester) async {
    final c = controller();
    c.cameraController.value = embeddingCamera();
    final first = c.camera.value;
    expect(identical(c.camera.value, first), isTrue);
    expect(first, FloorPlanCamera(embeddingCamera()));
    var heard = 0;
    void listener() => heard++;
    c.camera.addListener(listener);
    c.cameraController.panBy(const Offset(12.5, -3.25));
    expect(heard, 1);
    final second = c.camera.value;
    expect(identical(second, first), isFalse);
    expect(identical(c.camera.value, second), isTrue);
    expectPixel(
        second.worldToCanvas(centreOf('1')),
        canvasOfCamera(embeddingCamera(), centreOf('1')) +
            const Offset(12.5, -3.25),
        'panned');
    c.camera.removeListener(listener);
    c.cameraController.panBy(const Offset(1, 1));
    expect(heard, 1);
  });

  test(
      'CM4 the zoom bounds: today\'s by default, the constructor\'s when '
      'given, an ArgumentError unless finite and 0 < min < max', () {
    final c = FloorPlanController();
    addTearDown(c.dispose);
    expect(c.cameraController.minScale, 0.001);
    expect(c.cameraController.maxScale, 100);
    final d = FloorPlanController(minScale: 0.02, maxScale: 3.5);
    addTearDown(d.dispose);
    expect(d.cameraController.minScale, 0.02);
    expect(d.cameraController.maxScale, 3.5);
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
      expect(() => FloorPlanController(minScale: min, maxScale: max),
          throwsArgumentError,
          reason: '($min, $max)');
    }
  });

  testWidgets(
      'CM5 panBy with no view acts at once and drops a request not yet '
      'performed with its target; the plan\'s own first fit still frames '
      'the page (Task 2 review R-1)', (tester) async {
    final c = controller();
    final before = c.cameraController.value;
    c.centerOn(centreOf('3'), scale: 0.2);
    const d = Offset(37.25, -11.5);
    c.panBy(d);
    expect(parts(c.cameraController.value), panned(before, d));
    expect(() => c.panBy(const Offset(double.nan, 0)), throwsArgumentError);
    expect(parts(c.cameraController.value), panned(before, d));
    await mount(tester, c);
    expect(parts(c.cameraController.value), parts(pageFitOf(c)),
        reason: 'the plan\'s own fit, not centerOn\'s');

    final t = controller();
    expect(t.fitToTables({'2'}), isTrue);
    expect(t.zoomBy(2), isFalse, reason: 'no view: no command');
    t.panBy(d);
    await tester.pumpWidget(hostOf(t));
    await tester.pump();
    await tester.pump();
    expect(parts(t.cameraController.value), parts(pageFitOf(t)),
        reason: 'the plan\'s own fit, not the tables\'');
  });

  testWidgets(
      'CM6 zoomBy: false with no view or a bad factor, changing nothing; '
      'about the canvas centre or a focus; clamped to the bounds (M-H6)',
      (tester) async {
    final c = controller(minScale: 0.2, maxScale: 0.5);
    final idle = c.cameraController.value;
    expect(c.zoomBy(1.5), isFalse, reason: 'no view');
    expect(c.cameraController.value, same(idle));

    await mount(tester, c);
    final size = c.canvasRect.value!.size;
    final centre = size.center(Offset.zero);
    c.cameraController.value = embeddingCamera();
    final placed = c.cameraController.value;
    for (final f in [0.0, -2.0, double.nan, double.infinity]) {
      expect(c.zoomBy(f), isFalse, reason: 'factor $f');
    }
    expect(c.zoomBy(1.2, focus: const Offset(double.nan, 0)), isFalse);
    expect(c.cameraController.value, same(placed));

    // The world at the centre, by the inverse of the fixture's camera.
    final mid =
        Offset((centre.dx + 14612.25) / 0.37, (centre.dy + 9431.5) / -0.37);
    expect(c.zoomBy(1.25), isTrue);
    expect(c.camera.value.scale, closeTo(0.37 * 1.25, 1e-12));
    expectPixel(canvasOfCamera(c.cameraController.value, mid), centre,
        'the centre stays');

    expect(c.zoomBy(10), isTrue);
    expect(c.camera.value.scale, closeTo(0.5, 1e-12), reason: 'max');
    expectPixel(canvasOfCamera(c.cameraController.value, mid), centre,
        'the centre stays at the bound');

    const focus = Offset(310.5, 190.25);
    final under = c.camera.value.canvasToWorld(focus);
    expect(c.zoomBy(1e-6, focus: focus), isTrue);
    expect(c.camera.value.scale, closeTo(0.2, 1e-12), reason: 'min');
    expectPixel(canvasOfCamera(c.cameraController.value, under), focus,
        'the focus stays');
  });

  testWidgets(
      'CM7 every fit is clamped to the bounds about the canvas centre: the '
      'nominal placement, the start fit, fitToView, fitToTables (M-H6b)',
      (tester) async {
    final c = controller(maxScale: 0.01);
    expect(c.cameraController.value.scale, lessThanOrEqualTo(0.01 + 1e-15),
        reason: 'the nominal placement');
    final sheet = sheetWorldRect(c.activeDocument.components
        .get<PageComponent>(c.activeDocument.rootHandle)!);
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
    expect(c.camera.value.scale, closeTo(0.01, 1e-15), reason: 'start fit');
    expectPixel(c.camera.value.worldToCanvas(pageCentre), centre, 'start fit');

    c.cameraController.value = embeddingCamera();
    c.fitToView();
    await tester.pump();
    expect(c.camera.value.scale, closeTo(0.01, 1e-15), reason: 'fitToView');
    expectPixel(c.camera.value.worldToCanvas(pageCentre), centre, 'fitToView');

    expect(c.fitToTables({'1'}), isTrue);
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
    expect(c.camera.value.scale, closeTo(0.01, 1e-15), reason: 'tables');
    expectPixel(c.camera.value.worldToCanvas(boxCentre), centre, 'tables');

    final up = controller(minScale: 2);
    await tester.pumpWidget(hostOf(up));
    await tester.pump();
    await tester.pump();
    expect(up.camera.value.scale, closeTo(2, 1e-12), reason: 'min');
    expectPixel(up.camera.value.worldToCanvas(pageCentre), centre, 'min');
  });

  testWidgets(
      'CM8 the camera epoch: a command after a fit request wins, a fit '
      'request after a command wins (M-H7)', (tester) async {
    final c = controller();
    await mount(tester, c);
    final fitted = parts(c.cameraController.value);
    final centre = c.canvasRect.value!.size.center(Offset.zero);

    c.cameraController.value = embeddingCamera();
    c.fitToView();
    const d = Offset(37.25, -11.5);
    c.panBy(d);
    await tester.pump();
    expect(parts(c.cameraController.value), panned(embeddingCamera(), d),
        reason: 'panBy after fitToView');

    c.cameraController.value = embeddingCamera();
    expect(c.fitToTables({'2'}), isTrue);
    expect(c.zoomBy(1.5), isTrue);
    await tester.pump();
    final m = embeddingCamera().worldToScreenMatrix;
    final z = c.cameraController.value.worldToScreenMatrix;
    expect([z.a, z.d], [closeTo(m.a * 1.5, 1e-15), closeTo(m.d * 1.5, 1e-15)],
        reason: 'zoomBy after fitToTables');
    expect(z.e, closeTo(1.5 * (m.e - centre.dx) + centre.dx, 1e-9));
    expect(z.f, closeTo(1.5 * (m.f - centre.dy) + centre.dy, 1e-9));

    c.cameraController.value = embeddingCamera();
    c.panBy(d);
    c.fitToView();
    await tester.pump();
    expect(parts(c.cameraController.value), fitted, reason: 'fit after pan');
  });

  testWidgets(
      'CM9 centerOn before the first mount centres on the first frame, at '
      'the scale asked', (tester) async {
    final c = controller();
    c.centerOn(centreOf('3'), scale: 0.2);
    await mount(tester, c);
    final centre = c.canvasRect.value!.size.center(Offset.zero);
    expect(c.camera.value.scale, closeTo(0.2, 1e-15));
    expectPixel(c.camera.value.worldToCanvas(centreOf('3')), centre, '3');
  });

  testWidgets(
      'CM10 before a mount the last request wins: centerOn then fitToView '
      'fits the page; fitToView then centerOn centres', (tester) async {
    final a = controller();
    a.centerOn(centreOf('3'), scale: 0.2);
    a.fitToView();
    await mount(tester, a);
    final size = a.canvasRect.value!.size;
    final page = fitToPage(
        a.activeDocument.components
            .get<PageComponent>(a.activeDocument.rootHandle)!,
        size);
    expect(parts(a.cameraController.value), parts(page), reason: 'the page');

    final b = controller();
    b.fitToView();
    b.centerOn(centreOf('4'), scale: 0.15);
    await tester.pumpWidget(hostOf(b));
    await tester.pump();
    await tester.pump();
    expect(b.camera.value.scale, closeTo(0.15, 1e-15));
    expectPixel(b.camera.value.worldToCanvas(centreOf('4')),
        size.center(Offset.zero), 'centred');
  });

  testWidgets(
      'CM11 centerOn with a view: at the end of the frame, at the camera\'s '
      'scale or the one asked clamped; a later fitToView wins; bad '
      'arguments throw', (tester) async {
    final c = controller();
    await mount(tester, c);
    final fitted = parts(c.cameraController.value);
    final centre = c.canvasRect.value!.size.center(Offset.zero);
    c.cameraController.value = embeddingCamera();

    c.centerOn(centreOf('1'));
    expect(parts(c.cameraController.value), parts(embeddingCamera()),
        reason: 'queued, not yet performed');
    await tester.pump();
    expect(c.camera.value.scale, closeTo(0.37, 1e-15), reason: 'kept');
    expectPixel(c.camera.value.worldToCanvas(centreOf('1')), centre, '1');

    c.centerOn(centreOf('2'), scale: 1e6);
    await tester.pump();
    expect(c.camera.value.scale, closeTo(100, 1e-12), reason: 'max');
    expectPixel(c.camera.value.worldToCanvas(centreOf('2')), centre, '2');

    c.centerOn(centreOf('2'), scale: 0.3);
    c.fitToView();
    await tester.pump();
    expect(parts(c.cameraController.value), fitted, reason: 'fit wins');

    final now = c.cameraController.value;
    expect(() => c.centerOn(const Offset(double.nan, 0)), throwsArgumentError);
    expect(() => c.centerOn(Offset.zero, scale: 0), throwsArgumentError);
    expect(() => c.centerOn(Offset.zero, scale: double.infinity),
        throwsArgumentError);
    await tester.pump();
    expect(c.cameraController.value, same(now));
  });

  testWidgets(
      'CR1 canvasRect: null with no view; the interaction layer\'s global '
      'rect in either mode, never null across a switch; null after unmount',
      (tester) async {
    final c = controller(design: true);
    expect(c.canvasRect.value, isNull);
    expect(c.worldToGlobal(centreOf('1')), isNull);
    expect(c.globalToWorld(Offset.zero), isNull);
    await mount(tester, c);
    expect(c.canvasRect.value, canvasOnScreen(tester), reason: 'design');
    final heard = <Rect?>[];
    void listener() => heard.add(c.canvasRect.value);
    c.canvasRect.addListener(listener);
    c.setMode(FloorPlanMode.selection);
    await tester.pump();
    await tester.pump();
    expect(c.canvasRect.value, canvasOnScreen(tester), reason: 'selection');
    expect(heard, isNotEmpty);
    expect(heard, everyElement(isNotNull));
    c.canvasRect.removeListener(listener);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(c.canvasRect.value, isNull);
    expect(c.worldToGlobal(centreOf('1')), isNull);
  });

  testWidgets(
      'CR2 a view moved by its parent\'s padding, not resized and not laid '
      'out again: canvasRect, worldToGlobal and globalToWorld follow '
      '(M-H19b canvasRect)', (tester) async {
    final c = controller();
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // One view instance: the padding's change rebuilds nothing below it.
    final view = FloorPlanView(controller: c);
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
    c.cameraController.value = embeddingCamera();

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

  testWidgets(
      'UC1 userCamera false in the selection mode: a floor drag, a middle '
      'drag, the wheel and a pinch leave the camera; a tap still reports; '
      'the commands act; switching it keeps the canvas mounted '
      '(M-H19b userCamera)', (tester) async {
    final taps = <String>[];
    final c = controller();
    await mount(tester, c, onTableTap: taps.add);
    c.cameraController.value = embeddingCamera();
    await tester.pump();
    final layer = tester.state(find.byType(InteractionLayer));
    final origin = canvasOnScreen(tester).topLeft;
    final floor = origin + const Offset(1300, 60);

    Future<void> drag(Offset from, {int buttons = 1}) async {
      final g = await tester.startGesture(from,
          kind: PointerDeviceKind.mouse, buttons: buttons);
      await g.moveBy(const Offset(40, 0));
      await g.moveBy(const Offset(20, 40));
      await g.up();
      await tester.pump();
    }

    // Premise: with the camera the user's, the floor drag pans.
    await drag(floor);
    expect(parts(c.cameraController.value),
        panned(embeddingCamera(), const Offset(60, 40)),
        reason: 'premise: a floor drag pans');

    await tester.pumpWidget(hostOf(c, userCamera: false, onTableTap: taps.add));
    await tester.pump();
    expect(tester.state(find.byType(InteractionLayer)), same(layer),
        reason: 'the interaction layer is kept');
    expect(find.byType(CameraGestureDetector), findsNothing);
    c.cameraController.value = embeddingCamera();
    final locked = c.cameraController.value;

    await drag(floor);
    expect(c.cameraController.value, same(locked), reason: 'floor drag');
    await drag(floor, buttons: kMiddleMouseButton);
    expect(c.cameraController.value, same(locked), reason: 'middle drag');
    final mouse = TestPointer(9, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(floor));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -120)));
    await tester.pump();
    expect(c.cameraController.value, same(locked), reason: 'wheel');
    final f1 = await tester.startGesture(floor, pointer: 21);
    final f2 =
        await tester.startGesture(floor + const Offset(-200, 40), pointer: 22);
    await tester.pump(const Duration(milliseconds: 120));
    await f1.moveBy(const Offset(60, 0));
    await f2.moveBy(const Offset(-60, 10));
    await f1.up();
    await f2.up();
    await tester.pump();
    expect(c.cameraController.value, same(locked), reason: 'pinch');

    final table = origin + canvasOfCamera(embeddingCamera(), centreOf('1'));
    await tester.tapAt(table, kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(taps, ['1'], reason: 'a tap still reports');

    c.panBy(const Offset(5, 7));
    expect(parts(c.cameraController.value),
        panned(embeddingCamera(), const Offset(5, 7)),
        reason: 'panBy still acts');
    expect(c.zoomBy(1.1), isTrue, reason: 'zoomBy still acts');
  });

  testWidgets(
      'UC2 userCamera false in the design mode: no camera gestures; true '
      'by default', (tester) async {
    final c = controller(design: true);
    await mount(tester, c);
    expect(find.byType(CameraGestureDetector), findsOneWidget);
    await tester.pumpWidget(hostOf(c, userCamera: false));
    await tester.pump();
    expect(find.byType(CameraGestureDetector), findsNothing);
    final before = c.cameraController.value;
    final p = canvasOnScreen(tester).center;
    final g = await tester.startGesture(p,
        kind: PointerDeviceKind.mouse, buttons: kMiddleMouseButton);
    await g.moveBy(const Offset(50, 30));
    await g.up();
    final mouse = TestPointer(9, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(p));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -120)));
    await tester.pump();
    expect(c.cameraController.value, same(before));
  });

  testWidgets(
      'CM12 a load then panBy with a view mounted: the new plan\'s own first '
      'fit frames the page (Task 2 review R-1, probe P3)', (tester) async {
    final c = controller();
    await mount(tester, c);
    c.cameraController.value = embeddingCamera();
    c.load(embeddingPlanJson());
    c.panBy(const Offset(5, 5));
    await tester.pump();
    await tester.pump();
    expect(parts(c.cameraController.value), parts(pageFitOf(c)));
  });

  testWidgets(
      'CM13 a view with no size owes the plan\'s own first fit: a panBy '
      'before it is sized does not cancel it (Task 2 review R-1)',
      (tester) async {
    final c = controller();
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(sizedHostOf(c, 0));
    await tester.pump();
    expect(c.canvasRect.value, isNull, reason: 'no size: no report (R-3)');
    c.cameraController.value = embeddingCamera();
    c.panBy(const Offset(37.25, -11.5));
    await tester.pumpWidget(sizedHostOf(c, 1000));
    await tester.pump();
    await tester.pump();
    expect(c.canvasRect.value!.size.width, 1000, reason: 'premise');
    expect(parts(c.cameraController.value), parts(pageFitOf(c)));
  });

  testWidgets(
      'CM14 a requested fit owed by a view with no size takes the epoch '
      'when it becomes due: a panBy before the view is sized wins (Task 2 '
      'review R-2, O3)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const d = Offset(37.25, -11.5);

    // A request made with no view, owed by the next view, mounted with no
    // size: the epoch is taken when that view is created.
    final a = controller();
    await tester.pumpWidget(sizedHostOf(a, 1000));
    await tester.pump();
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    a.fitToView();
    await tester.pumpWidget(sizedHostOf(a, 0));
    await tester.pump();
    a.cameraController.value = embeddingCamera();
    a.panBy(d);
    await tester.pumpWidget(sizedHostOf(a, 1000));
    await tester.pump();
    await tester.pump();
    expect(parts(a.cameraController.value), panned(embeddingCamera(), d),
        reason: 'a request owed from the start');

    // A request heard by a view with no size (a fresh service copy shown
    // at 0 wide): the epoch is taken when the request is heard.
    final b = controller();
    await tester.pumpWidget(sizedHostOf(b, 1000));
    await tester.pump();
    await tester.pump();
    await tester.pumpWidget(sizedHostOf(b, 0));
    await tester.pump();
    b.resetLayout();
    await tester.pump();
    await tester.pump();
    b.fitToView();
    b.cameraController.value = embeddingCamera();
    b.panBy(d);
    await tester.pumpWidget(sizedHostOf(b, 1000));
    await tester.pump();
    await tester.pump();
    expect(parts(b.cameraController.value), panned(embeddingCamera(), d),
        reason: 'a request heard with no size');
  });

  testWidgets(
      'CM15 minScale has a floor of 1e-6, the bound decisions\' tolerance '
      'times a thousand; at the floor the bound holds (Task 2 review R-6)',
      (tester) async {
    for (final min in [1e-9, 1e-10, 9.99e-7]) {
      expect(() => FloorPlanController(minScale: min), throwsArgumentError,
          reason: '$min');
    }
    final c = controller(minScale: 1e-6);
    expect(c.cameraController.minScale, 1e-6);
    await mount(tester, c);
    expect(c.zoomBy(1e-12), isTrue);
    expect(c.camera.value.scale, closeTo(1e-6, 1e-18), reason: 'min');
  });

  testWidgets(
      'CR3 the first canvasRect report follows the view\'s first fit: a host '
      'that zooms on it zooms the fitted page (Task 2 review R-3, O3)',
      (tester) async {
    final c = controller();
    var zoomed = false;
    c.canvasRect.addListener(() {
      if (!zoomed && c.canvasRect.value != null) {
        zoomed = true;
        expect(c.zoomBy(2), isTrue);
      }
    });
    await mount(tester, c);
    expect(zoomed, isTrue, reason: 'premise');
    final centre = c.canvasRect.value!.size.center(Offset.zero);
    final p = pageFitOf(c).worldToScreenMatrix;
    // The page fit scaled by 2 about the canvas centre, by hand.
    final z = c.cameraController.value.worldToScreenMatrix;
    expect([
      z.a,
      z.b,
      z.c,
      z.d
    ], [
      closeTo(2 * p.a, 1e-15),
      closeTo(2 * p.b, 1e-15),
      closeTo(2 * p.c, 1e-15),
      closeTo(2 * p.d, 1e-15)
    ]);
    expect(z.e, closeTo(2 * (p.e - centre.dx) + centre.dx, 1e-9));
    expect(z.f, closeTo(2 * (p.f - centre.dy) + centre.dy, 1e-9));
  });

  testWidgets(
      'CR4 setMode sets canvasRect at once to the new mode\'s canvas when a '
      'view has shown that mode; worldToGlobal follows (Task 2 review R-4)',
      (tester) async {
    final c = controller(design: true);
    await mount(tester, c);
    final design = c.canvasRect.value!;
    c.setMode(FloorPlanMode.selection);
    await tester.pump();
    await tester.pump();
    final service = c.canvasRect.value!;
    expect(service, canvasOnScreen(tester));
    expect(service.topLeft, isNot(design.topLeft), reason: 'premise');
    c.cameraController.value = embeddingCamera();
    final w = centreOf('1');

    c.setMode(FloorPlanMode.design);
    expect(c.canvasRect.value, design, reason: 'into design, at once');
    final early = c.worldToGlobal(w)!;
    await tester.pump();
    await tester.pump();
    expect(c.canvasRect.value, canvasOnScreen(tester));
    expect(c.canvasRect.value, design);
    expectPixel(early, c.worldToGlobal(w)!, 'design');

    c.setMode(FloorPlanMode.selection);
    expect(c.canvasRect.value, service, reason: 'into selection, at once');
    final again = c.worldToGlobal(w)!;
    await tester.pump();
    await tester.pump();
    expect(c.canvasRect.value, service);
    expectPixel(again, c.worldToGlobal(w)!, 'selection');
  });

  testWidgets(
      'CR5 a reporter replaced while a rect is registered with it is told '
      'null, and the new one hears the rect (Task 2 review R-8)',
      (tester) async {
    final a = <Rect?>[], b = <Rect?>[];
    void toA(Object view, Rect? rect) => a.add(rect);
    void toB(Object view, Rect? rect) => b.add(rect);
    Widget shell(void Function(Object, Rect?)? reporter) =>
        MaterialApp(home: PlannerShell(onCanvasPlaced: reporter));
    await tester.pumpWidget(shell(toA));
    await tester.pump();
    await tester.pump();
    final rect = canvasOnScreen(tester);
    expect(a, [rect]);

    await tester.pumpWidget(shell(toB));
    await tester.pump();
    expect(a, [rect, null], reason: 'the old reporter');
    expect(b, [rect], reason: 'the new reporter');

    await tester.pumpWidget(shell(null));
    await tester.pump();
    expect(b, [rect, null], reason: 'no reporter');
  });
}
