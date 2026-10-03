// Spec 14t R-1, T6: a pinch in the design mode, through the shell's own
// widgets. The Room tool commits on a single down and a polyline is pending
// between taps: a finger held, moved and joined by a second finger commits
// nothing and drops no pending shape, while the two fingers zoom the view;
// a single finger's tap still places (lift mode). The sample plan sits at
// the origin with its walls in place; the camera is the shell's own fit.
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/parametric/live_objects.dart';
import 'package:jet_cad_floor_plan/src/parametric/room.dart';
import 'package:jet_cad_floor_plan/src/planner_shell.dart';
import 'package:jet_cad_floor_plan/src/planner_view.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/room_fixture.dart';

Future<PlannerView> pumpPlan(WidgetTester tester, Plan plan) async {
  plan.system.dispose();
  plan.doc.commands.clearHistory();
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: PlannerShell(document: plan.doc)));
  await tester.pump();
  await tester.pump();
  return tester.widget<PlannerView>(find.byType(PlannerView));
}

Offset screenOf(WidgetTester tester, PlannerView view, Vector2 world) {
  final s = view.camera.value.worldToScreen(world);
  return tester.getTopLeft(find.byType(InteractionLayer)) + Offset(s.x, s.y);
}

Future<TestGesture> finger(WidgetTester tester, int pointer, Offset at) =>
    tester.startGesture(at, pointer: pointer, kind: PointerDeviceKind.touch);

Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

Plan samplePlan() => buildPlan([...sampleWalls(), sampleColumn],
    seps: const [sampleSeparator],
    openings: sampleOpenings,
    measurer: FlutterTextMeasurer());

List<Handle> rooms(DraftDocument doc) => liveObjectsOf<RoomParams>(doc);

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
    final plan = samplePlan();
    final view = await pumpPlan(tester, plan);
    final doc = view.document;
    await press(tester, LogicalKeyboardKey.keyM);
    final depth = doc.commands.undoDepth;
    final scale = view.camera.value.scale;
    final kitchen = Vector2(18500.5, 9750.25);

    await pinch(tester, screenOf(tester, view, kitchen));
    expect(rooms(doc), isEmpty);
    expect(doc.commands.undoDepth, depth);
    expect(view.camera.value.scale, greaterThan(scale * 1.2),
        reason: 'the fingers spread: the view zoomed');

    final tap = await finger(tester, 13, screenOf(tester, view, kitchen));
    await tap.up();
    await tester.pump();
    expect(rooms(doc), hasLength(1), reason: 'a finger\'s tap still places');
    expect(doc.commands.undoDepth, depth + 1);
  });

  testWidgets('TD2 a polyline pending between taps survives a pinch (M-14t-20)',
      (tester) async {
    final plan = samplePlan();
    final view = await pumpPlan(tester, plan);
    final doc = view.document;
    await press(tester, LogicalKeyboardKey.keyP);
    for (final p in [Vector2(17800.5, 9200.25), Vector2(19600.5, 10400.25)]) {
      final t = await finger(tester, 21, screenOf(tester, view, p));
      await t.up();
      await tester.pump();
    }
    final tool = view.tools.active;
    expect(tool.isMidShape, isTrue, reason: 'premise: two points placed');
    final depth = doc.commands.undoDepth;
    await pinch(tester, screenOf(tester, view, Vector2(18600.5, 9600.25)));
    expect(identical(view.tools.active, tool), isTrue);
    expect(tool.isMidShape, isTrue, reason: 'the shape is still pending');
    expect(doc.commands.undoDepth, depth);
  });
}
