// Removing the editor while a mouse hovers an entity (Slice 3's results,
// "Found, not fixed"): the interaction layer's deactivation clears the
// hover, and the selection panel, outside the canvas and still active
// while the removed subtree deactivates, must not be marked dirty during
// that build. The shell's frame-safe selection relay (Slice 4, Task 4
// review R-2) holds the notification; the panel listening to the
// selection directly turns both cases red.
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_controller.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_view.dart';
import 'package:jet_cad_floor_plan/src/planner_view.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'host/embedding_fixture.dart';
import 'support/box_rig.dart';

/// World ([x], [y]) on the screen under [c]'s camera, by the forward
/// transform.
Offset onScreen(
    WidgetTester tester, FloorPlanController c, double x, double y) {
  final p = canvasOf(c.cameraController.value, x, y);
  return tester.getTopLeft(find.byType(InteractionLayer)) + Offset(p.x, p.y);
}

void main() {
  testWidgets(
      'HR1 a bare shell: a hovered line, then the shell removed in one pump',
      (tester) async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final doc = boxDoc(measurer);
    addTearDown(doc.dispose);
    // Off the camera's centre and off the axes, under pumpDraw's rotated,
    // zoomed camera.
    doc.commands.execute(addDrafted(doc, EntityKind.line,
        linePayload(Vector2(7100, 3080), Vector2(7260, 3170)),
        layer: ReservedHandles.layerZero));
    final view = await pumpDraw(tester, doc);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: globalOf(tester, view, 7000, 3300));
    await tester.pump();
    expect(view.selection.hover, isNull, reason: 'premise: off the line');
    await mouse.moveTo(globalOf(tester, view, 7180, 3125));
    await tester.pump();
    expect(view.selection.hover, isNotNull, reason: 'premise: on the line');

    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
    expect(find.byType(PlannerView), findsNothing);
  });

  testWidgets(
      'HR2 the host\'s design view: a hovered table, then the view removed '
      'in one pump', (tester) async {
    final c = FloorPlanController(json: embeddingPlanJson());
    addTearDown(c.dispose);
    expect(c.mode.value, FloorPlanMode.design, reason: 'premise');
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home:
            Scaffold(body: FloorPlanView(controller: c, onTableTap: (_) {}))));
    await tester.pump();
    await tester.pump();
    c.cameraController.value = embeddingCamera();
    await tester.pump();
    final view = tester.widget<PlannerView>(find.byType(PlannerView));
    final one = embeddingTables.firstWhere((t) => t.number == '1');
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    // The floor between tables 1 and 2, on no table's box.
    await mouse.addPointer(location: onScreen(tester, c, 41900, -26500));
    await tester.pump();
    expect(view.selection.hover, isNull, reason: 'premise: on the floor');
    // Table 1's local (700, 100), inside its box, through its placement.
    final m = one.transform;
    await mouse.moveTo(onScreen(
        tester, c, m.a * 700 + m.c * 100 + m.e, m.b * 700 + m.d * 100 + m.f));
    await tester.pump();
    expect(view.selection.hover, isNotNull, reason: 'premise: on table 1');

    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
    expect(find.byType(PlannerView), findsNothing);
  });
}
