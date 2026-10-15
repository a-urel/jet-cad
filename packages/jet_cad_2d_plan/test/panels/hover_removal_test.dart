// Ported from jet_cad_floor_plan/test/hover_removal_test.dart; assertions unchanged.
//
// Removing the editor while a mouse hovers an entity (Slice 3's results,
// "Found, not fixed"): the interaction layer's deactivation clears the
// hover, and the property panel, outside the canvas and still active while
// the removed subtree deactivates, must not be marked dirty during that
// build. The panel's frame-safe selection relay (FrameSafeRelay, today's
// _FrameSafeRelay) holds the notification; the panel listening to the
// selection directly turns it red. HR2 (a hovered unit, 2b Task 10) mounts the
// editor over the embedding fixture.
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/canvas/plan_canvas_view.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/panel_kits.dart';
import '../support/canvas_fixture.dart';
import '../support/design_harness.dart';
import '../support/unit_embedding_fixture.dart';

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

  testWidgets(
      'HR2 the editor: a hovered unit, then the editor removed in one pump',
      (tester) async {
    final c = embeddingController();
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: PlanEditor(controller: c))));
    await tester.pump();
    await tester.pump();
    c.camera.value = embeddingCamera();
    await tester.pump();
    final one = embeddingTables.firstWhere((t) => t.number == '1');
    Offset onScreen(double x, double y) {
      final p = canvasOf(c.camera.value, x, y);
      return tester.getTopLeft(find.byType(InteractionLayer)) +
          Offset(p.x, p.y);
    }

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    // The floor between units 1 and 2, on no unit's box.
    await mouse.addPointer(location: onScreen(41900, -26500));
    await tester.pump();
    expect(c.selection.hover, isNull, reason: 'premise: on the floor');
    // Unit 1's local (700, 100), inside its box, through its placement.
    final m = one.transform;
    await mouse.moveTo(
        onScreen(m.a * 700 + m.c * 100 + m.e, m.b * 700 + m.d * 100 + m.f));
    await tester.pump();
    expect(c.selection.hover, isNotNull, reason: 'premise: on unit 1');

    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
    expect(find.byType(PlanCanvasView), findsNothing);
  });
}
