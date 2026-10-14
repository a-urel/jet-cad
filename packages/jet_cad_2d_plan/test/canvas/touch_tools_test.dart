// Ported from jet_cad_floor_plan/test/touch_tools_test.dart; assertions unchanged.
//
// Spec 14t R-1, T6: a pinch on the canvas. A polyline is pending between
// taps: a finger held, moved and joined by a second finger commits nothing
// and drops no pending shape, while the two fingers zoom the view. TD1 (the
// Room tool) is sub-project 3's. The drawing fixture's sheet sits off the
// origin under a rotated, non-reflecting camera.
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/canvas_fixture.dart';

Future<TestGesture> finger(WidgetTester tester, int pointer, Offset at) =>
    tester.startGesture(at, pointer: pointer, kind: PointerDeviceKind.touch);

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
  testWidgets('TD2 a polyline pending between taps survives a pinch (M-14t-20)',
      (tester) async {
    final c = drawController().c;
    await pumpDraw(tester, c);
    final doc = c.document;
    c.selectTool('plan.polyline');
    await tester.pump();
    for (final p in [Vector2(7010.5, 3020.25), Vector2(7060.5, 3090.25)]) {
      final t = await finger(tester, 21, globalOf(tester, c, p.x, p.y));
      await t.up();
      await tester.pump();
    }
    final tool = c.toolController.active;
    expect(tool.isMidShape, isTrue, reason: 'premise: two points placed');
    final depth = doc.commands.undoDepth;
    await pinch(tester, globalOf(tester, c, 7035.5, 3055.25));
    expect(identical(c.toolController.active, tool), isTrue);
    expect(tool.isMidShape, isTrue, reason: 'the shape is still pending');
    expect(doc.commands.undoDepth, depth);
  });
}
