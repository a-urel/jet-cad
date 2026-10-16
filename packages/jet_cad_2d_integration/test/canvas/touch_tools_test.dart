// Ported from jet_cad_floor_plan/test/touch_tools_test.dart (3a Task 26, spec C6); assertions unchanged.
//
// Spec 14t R-1, T6: a pinch in the design mode, through the shell's own
// widgets. The Room tool commits on a single down and a polyline is pending
// between taps: a finger held, moved and joined by a second finger commits
// nothing and drops no pending shape, while the two fingers zoom the view;
// a single finger's tap still places (lift mode). The sample plan sits at
// the origin with its walls in place; the camera is the shell's own fit.
// TD1 only (TD2 is 2a's). The plan is a file opened by the plan library
// over the architecture kit; its first fit frames the new plan's page at
// the origin, so the camera is set on the plan's middle at 0.05 px/mm, y
// up, before the gestures (ruling IT-R5).
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/canvas_rig.dart';
import '../support/plans.dart';

Future<TestGesture> finger(WidgetTester tester, int pointer, Offset at) =>
    tester.startGesture(at, pointer: pointer, kind: PointerDeviceKind.touch);

List<Handle> rooms(DraftDocument doc) =>
    doc.components.withComponent<RoomParams>().toList();

/// A pinch whose first finger was held [hold] and moved before the second
/// landed; both fingers spread, then lift.
Future<void> pinch(WidgetTester tester, Offset first,
    {Duration hold = const Duration(milliseconds: 150)}) async {
  final a = await finger(tester, 11, first);
  await tester.pump(hold);
  await a.moveTo(first + const Offset(30, 10));
  final b = await finger(tester, 12, first + const Offset(160, 90));
  for (var i = 1; i <= 3; i++) {
    await a.moveTo(first + Offset(30.0 - 15 * i, 10.0 - 8 * i));
    await b.moveTo(first + Offset(160.0 + 20 * i, 90.0 + 12 * i));
  }
  await a.up();
  await b.up();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  testWidgets(
      'TD1 the Room tool: a held, moved finger joined by a second commits '
      'nothing and zooms; a tap places one room (M-14t-17)', (tester) async {
    final c = architectureController(json: d23PlanJson());
    addTearDown(c.dispose);
    await pumpPlanEditor(tester, c);
    await frameOn(tester, c, Vector2(19000, 12500), scale: 0.05);
    final doc = c.document;
    await pressKey(tester, LogicalKeyboardKey.keyM);
    final depth = doc.commands.undoDepth;
    final scale = c.camera.value.scale;
    final kitchen = Vector2(18500.5, 9750.25);

    await pinch(tester, globalAt(tester, c, kitchen));
    expect(rooms(doc), isEmpty);
    expect(doc.commands.undoDepth, depth);
    expect(c.camera.value.scale, greaterThan(scale * 1.2),
        reason: 'the fingers spread: the view zoomed');

    final tap = await finger(tester, 13, globalAt(tester, c, kitchen));
    await tap.up();
    await tester.pump();
    expect(rooms(doc), hasLength(1), reason: 'a finger\'s tap still places');
    expect(doc.commands.undoDepth, depth + 1);
  });
}
