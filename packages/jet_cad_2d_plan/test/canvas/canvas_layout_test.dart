// Ported from jet_cad_floor_plan/test/planner_shell_test.dart; assertions unchanged.
//
// The canvas's own cases of the shell's test: the first fit to the page at
// the drawing area's size, the page chrome and the rulers under the
// canvas, the fit latch across a resize, and the interaction tree. The
// palette fixture stands in for the sample flat: its page is off the
// origin and its extents (the two lines) are not the page, so the page fit
// and the extents fit differ as the sample's did. The sample's size premise
// (500 entities and more) went with the sample.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderCustomPaint;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/canvas_fixture.dart';

/// The palette fixture's canvas on White, in an app; its controller.
Future<PlanController> pumpSample(WidgetTester tester) async {
  final c = paletteController(paper: white).c;
  await tester
      .pumpWidget(MaterialApp(home: Scaffold(body: PlanCanvas(controller: c))));
  return c;
}

void main() {
  testWidgets('the camera is fitted to the page at the drawing area\'s size',
      (tester) async {
    // M-04k. The drawing area is the RulerFrame's child, not the view.
    final c = await pumpSample(tester);
    await tester.pump();
    final size = tester.getSize(find.byType(DraftCanvas));
    final page =
        c.document.components.get<PageComponent>(c.document.rootHandle)!;
    final expected = fitToPage(page, size);
    expect(c.camera.value.scale, closeTo(expected.scale, 1e-9));
    expect(c.camera.value.worldToScreenMatrix.e,
        closeTo(expected.worldToScreenMatrix.e, 1e-6));
    final extentsFit = ViewportTransform.fit(c.document.extents, size);
    expect(c.camera.value.scale, isNot(closeTo(extentsFit.scale, 1e-9)));
  });

  testWidgets(
      'the page chrome and the rulers are in the tree, under the canvas',
      (tester) async {
    await pumpSample(tester);
    await tester.pump();
    expect(find.byType(RulerFrame), findsOneWidget);
    final chrome = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is PageChromePainter);
    expect(chrome, findsOneWidget);
    expect(tester.getSize(chrome), tester.getSize(find.byType(DraftCanvas)));
  });

  // Ruling 01-2's latch: the fit happens once. A resize after the user has
  // moved the camera must not re-fit and throw their view away.
  testWidgets('a resize after the first layout does not re-fit the camera',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final c = await pumpSample(tester);
    await tester.pump();
    c.camera.zoomAt(const Offset(300, 200), 1.7);
    c.camera.panBy(const Offset(40, -25));
    final moved = c.camera.value.worldToScreenMatrix;

    await tester.binding.setSurfaceSize(const Size(1100, 750));
    await tester.pump();
    await tester.pump();

    expect(c.camera.value.worldToScreenMatrix, same(moved));
    expect(tester.getSize(find.byType(DraftCanvas)).width, greaterThan(500),
        reason: 'the canvas really did get a new size');
  });

  testWidgets('the interaction tree is in place', (tester) async {
    await pumpSample(tester);
    await tester.pump();

    expect(find.byType(InteractionLayer), findsOneWidget);
    final overlayFinder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is SelectionOverlayPainter);
    expect(overlayFinder, findsOneWidget);

    final overlaySize =
        tester.renderObject<RenderCustomPaint>(overlayFinder).size;
    expect(overlaySize, tester.getSize(find.byType(DraftCanvas)));
  });
}
