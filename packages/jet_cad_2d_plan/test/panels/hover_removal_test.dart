// Ported from jet_cad_floor_plan/test/hover_removal_test.dart; assertions unchanged.
//
// Removing the editor while a mouse hovers an entity (Slice 3's results,
// "Found, not fixed"): the interaction layer's deactivation clears the
// hover, and the property panel, outside the canvas and still active while
// the removed subtree deactivates, must not be marked dirty during that
// build. The panel's frame-safe selection relay (FrameSafeRelay, today's
// _FrameSafeRelay) holds the notification; the panel listening to the
// selection directly turns it red. HR2 (a hovered table) is 2b's.
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/canvas/plan_canvas_view.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/panel_kits.dart';
import '../support/canvas_fixture.dart';
import '../support/design_harness.dart';

void main() {
  testWidgets(
      'HR1 a bare shell: a hovered line, then the shell removed in one pump',
      (tester) async {
    final c = boxController();
    final doc = c.document;
    // Off the camera's centre and off the axes, under pumpDraw's rotated,
    // zoomed camera.
    doc.commands.execute(addDrafted(doc, EntityKind.line,
        linePayload(Vector2(7100, 3080), Vector2(7260, 3170)),
        layer: ReservedHandles.layerZero));
    await pumpDesign(tester, c, right: PlanPropertyPanel(controller: c));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: globalOf(tester, c, 7000, 3300));
    await tester.pump();
    expect(c.selection.hover, isNull, reason: 'premise: off the line');
    await mouse.moveTo(globalOf(tester, c, 7180, 3125));
    await tester.pump();
    expect(c.selection.hover, isNotNull, reason: 'premise: on the line');

    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
    expect(find.byType(PlanCanvasView), findsNothing);
  });
}
