// Ported from jet_cad_floor_plan/test/planner_grips_test.dart (3a Task 26, spec C6); assertions unchanged.
//
// A1-A4 and the fifth case (M-03ao) through the plan library's editor
// (ruling IT-R3): the source's fixture, two lines on a page, opened as a
// plan file by a controller over the architecture kit, so the kit is
// loaded while the generic grips run. The lines keep their handles in the
// plan's document. The active tool is the InteractionLayer's (IT-R1).
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/canvas_rig.dart';
import '../support/plans.dart' show payloadOf;
import '../support/room_plans.dart' show osnap;

Handle addLine(DraftDocument doc, List<double> coords) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: doc.rootHandle,
      kind: EntityKind.line,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByLayerColor(),
      lineweight: kByLayer,
      transparency: kByLayer,
      flags: 0,
    ),
    payload: GeometryPayload(
        coords: Float64List.fromList(coords), scalars: Float64List(0)),
  ));
  return handle;
}

/// Two lines off the origin on a page whose grid is a fixed 100 mm anchored
/// at (7000, 3000). `other`'s start is off the lattice, so an object snap
/// and a grid snap land in different places.
({DraftDocument doc, Handle line, Handle other, String json}) shellScene(
    FlutterTextMeasurer measurer) {
  final doc = DraftDocument.empty(measurer: measurer);
  PageComponent.register(doc.components);
  doc.commands.execute(SetComponentCommand<PageComponent>(doc.rootHandle,
      PageComponent(originX: 7000, originY: 3000, gridStepMm: 100)));
  final line = addLine(doc, [7010, 3020, 7130, 3060]);
  final other = addLine(doc, [7137.3, 3161.7, 7300.9, 3190.1]);
  doc.commands.clearHistory();
  final json = ensureManifest(DraftDocumentCodec.encodeToString(doc));
  return (doc: doc, line: line, other: other, json: json);
}

/// Pumps the plan library's editor over [s]'s plan file, opened by a
/// controller over the architecture kit, on a 1440 × 900 surface, then
/// sets a zoomed, panned, rotated camera. The controller is disposed at
/// tear-down.
Future<PlanController> pumpShell(WidgetTester tester,
    ({DraftDocument doc, Handle line, Handle other, String json}) s) async {
  final c = architectureController(json: s.json);
  addTearDown(c.dispose);
  await pumpPlanEditor(tester, c);
  // Set after the first frames: the editor fits the camera once, at the
  // end of its first frame (Ruling 04-16), and would overwrite one set
  // before.
  final size = tester.getSize(find.byType(InteractionLayer));
  final linear =
      Transform2.rotation(0.35).multiply(Transform2.scale(2.0, -2.0));
  final mid = linear.transformPoint(Vector2(7150, 3110));
  c.camera.value = ViewportTransform(
      worldToScreenMatrix: Transform2.translation(
              size.width / 2 - mid.x, size.height / 2 - mid.y)
          .multiply(linear));
  await tester.pump();
  return c;
}

Future<void> mouseDrag(WidgetTester tester, Offset from, Offset to) async {
  final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
  await gesture.down(from);
  await gesture.moveTo(from + const Offset(12, 0));
  await gesture.moveTo(to);
  await gesture.up();
  await gesture.removePointer();
  await tester.pump();
}

Future<void> cmdZ(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.keyZ);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.keyZ);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pump();
}

/// Selects the line with a click on its body, a third of the way along.
Future<void> selectLine(WidgetTester tester, PlanController c) async {
  await tester.tapAt(globalOf(tester, c, 7050, 3020 + 40 / 3));
  await tester.pump();
}

void main() {
  testWidgets(
      'a stretch through the shell lands exactly on an endpoint, and '
      'cmd+Z restores it with == (A1, M-03au)', (tester) async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final s = shellScene(measurer);
    final c = await pumpShell(tester, s);
    final before = payloadOf(c.document, s.line);
    await selectLine(tester, c);
    expect(c.activeSelection.keys, [SelectionKey.root(s.line)]);

    // Grab vertex 1; drop it 3 px from the other line's start. Object snap
    // is on by default, so it lands there exactly (spec D8).
    await mouseDrag(tester, globalOf(tester, c, 7130, 3060),
        globalOf(tester, c, 7137.3, 3161.7) + const Offset(3, -2));
    final after = payloadOf(c.document, s.line);
    expect([after.coords[2], after.coords[3]], [7137.3, 3161.7]);
    expect([after.coords[0], after.coords[1]], [7010, 3020]);
    expect(c.document.commands.undoDepth, 1);

    await cmdZ(tester);
    expect(payloadOf(c.document, s.line), before,
        reason: 'undo restores the stored payload with == (spec D11)');
    expect(c.document.commands.undoDepth, 0);
  });

  testWidgets(
      'F3 turns object snap off: osnap-text says so and the drag '
      'lands on the grid (A2, M-03x)', (tester) async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final s = shellScene(measurer);
    final c = await pumpShell(tester, s);
    expect(osnap(tester), 'OSNAP');
    await tester.sendKeyEvent(LogicalKeyboardKey.f3);
    await tester.pump();
    expect(osnap(tester), 'osnap off');

    await selectLine(tester, c);
    await mouseDrag(tester, globalOf(tester, c, 7130, 3060),
        globalOf(tester, c, 7137.3, 3161.7) + const Offset(3, -2));
    final after = payloadOf(c.document, s.line);
    expect([after.coords[2], after.coords[3]], [7100, 3200],
        reason: 'the nearest lattice point of the fixed 100 mm grid');
  });

  testWidgets('F3 held down toggles once (A3, M-03af)', (tester) async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final s = shellScene(measurer);
    await pumpShell(tester, s);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.f3);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.f3);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.f3);
    await tester.pump();
    expect(osnap(tester), 'osnap off',
        reason: 'includeRepeats: false — a repeat would have toggled it back');
  });

  testWidgets(
      "cmd+Z pressed mid-drag is the drag's, not the shell's (A4, "
      'M-03aa)', (tester) async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final s = shellScene(measurer);
    final c = await pumpShell(tester, s);
    // One finished drag first, so a stray undo would have something to take.
    await selectLine(tester, c);
    await mouseDrag(tester, globalOf(tester, c, 7130, 3060),
        globalOf(tester, c, 7137.3, 3161.7) + const Offset(3, -2));
    expect(c.document.commands.undoDepth, 1);
    final landed = payloadOf(c.document, s.line);

    final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
    final from = globalOf(tester, c, 7137.3, 3161.7);
    await gesture.down(from);
    await gesture.moveTo(from + const Offset(20, 10));
    await gesture.moveTo(from + const Offset(35, 18));
    expect(activeTool(tester).phase, ToolPhase.dragging);

    await cmdZ(tester);
    expect(c.document.commands.undoDepth, 1,
        reason: 'the Z never reached the shell (spec D5)');
    expect(payloadOf(c.document, s.line), landed);
    expect(activeTool(tester).phase, ToolPhase.dragging,
        reason: 'the drag is still live');

    await gesture.up();
    await gesture.removePointer();
    await tester.pump();
    expect(c.document.commands.undoDepth, 2);
  });

  // Controller note (Task 7): removing InteractionLayer mid-drag must not
  // assert `markNeedsBuild` during build. That fix is proven at the render
  // layer already; this proves it holds when the *whole shell* — with its
  // caches and controllers in their construction order — leaves the tree
  // mid-drag, not only the interaction widget in isolation.
  testWidgets(
      'replacing the shell mid-drag disposes cleanly, no exception '
      '(M-03ao, shell)', (tester) async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final s = shellScene(measurer);
    final c = await pumpShell(tester, s);
    await selectLine(tester, c);
    final before = payloadOf(c.document, s.line);

    final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
    final from = globalOf(tester, c, 7130, 3060);
    await gesture.down(from);
    await gesture.moveTo(from + const Offset(20, 10));
    expect(activeTool(tester).phase, ToolPhase.dragging);

    // Tears down the whole PlannerShell -- document, controllers and caches
    // included -- while the pointer is still captured by the drag.
    await tester.pumpWidget(const SizedBox.shrink());

    expect(payloadOf(c.document, s.line), before,
        reason: 'the drag never committed a command');
    // The captured pointer's up still reaches the unmounted tree; nothing
    // should throw handling it.
    await gesture.up();
    await gesture.removePointer();
  });
}
