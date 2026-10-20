// Task 10b: a touch double tap on the canvas ends a wall chain, as Enter does.
// Off-origin, rotated points; the camera is framed off the origin.
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/canvas_rig.dart';

int _pointer = 300;

/// A finger's tap at [at]: down, short hold, up; no settling pause after it
/// beyond [after].
Future<void> tap(WidgetTester tester, Offset at,
    {Duration after = const Duration(milliseconds: 400)}) async {
  final g = await tester.startGesture(at,
      pointer: _pointer++, kind: PointerDeviceKind.touch);
  await tester.pump(const Duration(milliseconds: 50));
  await g.up();
  await tester.pump(after);
}

const _quick = Duration(milliseconds: 80);

Future<PlanController> rig(WidgetTester tester) async {
  final c = PlanController(kits: [architectureKit]);
  addTearDown(c.dispose);
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  await pumpPlanEditor(tester, c);
  await frameOn(tester, c, Vector2(5000, 3000), scale: 0.05, turn: 0.4);
  c.selectTool('architecture.wall');
  await tester.pump();
  return c;
}

List<(Vector2, Vector2)> walls(PlanController c) {
  final doc = c.document;
  return [
    for (final h in doc.components.withComponent<WallParams>())
      (
        doc.components.get<WallParams>(h)!.start,
        doc.components.get<WallParams>(h)!.end
      ),
  ];
}

void main() {
  final a = Vector2(3000, 1500),
      b = Vector2(7000, 2200),
      d = Vector2(7300, 4800);

  testWidgets(
      'DT1 Wall, tap A, tap B, tap C, double tap: A-B and B-C, the chain '
      'ended, the double tap adds nothing and a new tap starts a new chain',
      (tester) async {
    final c = await rig(tester);
    final tool = activeTool(tester);
    await tap(tester, globalAt(tester, c, a));
    await tap(tester, globalAt(tester, c, b));
    // The double tap at C: its first tap is the chain's last point, its
    // second ends the chain.
    await tap(tester, globalAt(tester, c, d), after: _quick);
    await tap(tester, globalAt(tester, c, d));
    final w = walls(c);
    expect(w, hasLength(2), reason: 'A-B, B-C, and no extra wall');
    expect(w[1].$2.distanceTo(Vector2(7075, 4750)), lessThan(1e-6),
        reason: 'ends at C as the first tap of the pair snapped it');
    expect(tool.isMidShape, isFalse, reason: 'first-point state');
    // A new tap starts a new chain: no wall joins C to it.
    final e = Vector2(1000, 4000), f = Vector2(1000, 2500);
    await tap(tester, globalAt(tester, c, e));
    expect(walls(c), hasLength(2));
    expect(tool.isMidShape, isTrue);
    await tap(tester, globalAt(tester, c, f));
    final after = walls(c);
    expect(after, hasLength(3));
    expect(after[2].$1.distanceTo(e), lessThan(300));
    expect(after[2].$1.distanceTo(after[1].$2), greaterThan(1000),
        reason: 'not chained to C');
  });

  testWidgets(
      'DT5 a double tap whose two taps land 30 px apart still adds no wall',
      (tester) async {
    final c = await rig(tester);
    final tool = activeTool(tester);
    await tap(tester, globalAt(tester, c, a));
    final at = globalAt(tester, c, b);
    await tap(tester, at, after: _quick);
    await tap(tester, at + const Offset(18, 24));
    expect(walls(c), hasLength(1), reason: 'A-B only');
    expect(tool.isMidShape, isFalse);
  });

  testWidgets('DT2 a single tap after a pause does not end the chain',
      (tester) async {
    final c = await rig(tester);
    final tool = activeTool(tester);
    await tap(tester, globalAt(tester, c, a));
    await tap(tester, globalAt(tester, c, b),
        after: const Duration(milliseconds: 350));
    await tap(tester, globalAt(tester, c, d));
    expect(walls(c), hasLength(2), reason: 'a chain of two walls');
    expect(tool.isMidShape, isTrue);
    expect(walls(c)[1].$1.distanceTo(b), lessThan(100), reason: 'B-C joined');
  });

  testWidgets('DT3 Enter still ends the chain', (tester) async {
    final c = await rig(tester);
    final tool = activeTool(tester);
    await tap(tester, globalAt(tester, c, a));
    await tap(tester, globalAt(tester, c, b));
    expect(tool.isMidShape, isTrue);
    await pressKey(tester, LogicalKeyboardKey.enter);
    expect(tool.isMidShape, isFalse);
    expect(walls(c), hasLength(1));
  });

  testWidgets(
      'DT4 a mouse double click on the first point does not end the chain '
      '(touch only)', (tester) async {
    final c = await rig(tester);
    final tool = activeTool(tester);
    await mouseClick(tester, globalAt(tester, c, a));
    await tester.pump(_quick);
    await mouseClick(tester, globalAt(tester, c, a));
    expect(tool.isMidShape, isTrue,
        reason: 'the zero-length second click is refused, the chain goes on');
    expect(walls(c), isEmpty);
  });
}
