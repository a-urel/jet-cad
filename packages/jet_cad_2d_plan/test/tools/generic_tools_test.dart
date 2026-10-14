// Spec P1 "Reserved ids", P2 "The keyboard" (Task 12): the plan library's
// own tools, their ids, letters and needs, and what buildGenericTools makes
// of them. The letters are today's (planner_shell.dart:517-623 for the
// generic rows); plan.symbol has none and is not built here (Task 14).
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_plan/src/tools/generic_tools.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

final class _Resolver implements MoveResolver {
  @override
  ({Transform2 transform, Vector2 marker})? resolveMove(
          ToolContext ctx, Handle node, Transform2 delta) =>
      null;
}

void main() {
  test('PM-12 the generic tools: ids, letters, needs and Fill, in order', () {
    expect([
      for (final t in genericTools) t.id
    ], [
      'plan.select',
      'plan.line',
      'plan.polyline',
      'plan.rectangle',
      'plan.circle',
      'plan.arc',
      'plan.text',
    ]);
    // M-PM12: the letters of plan.line and plan.polyline swapped.
    expect([for (final t in genericTools) t.letter],
        ['V', 'L', 'P', 'R', 'C', 'A', 'T']);
    expect(genericTools.first.needs, isEmpty, reason: 'select only reads');
    for (final t in genericTools.skip(1)) {
      // Every drawing tool commits an AddEntityCommand (geometry).
      expect(t.needs, {Capability.geometry}, reason: t.id);
    }
    expect([
      for (final t in genericTools)
        if (t.fills) t.id
    ], [
      'plan.polyline',
      'plan.rectangle',
      'plan.circle'
    ]);
    expect(PlanToolIds.all, [
      'plan.select',
      'plan.line',
      'plan.polyline',
      'plan.rectangle',
      'plan.circle',
      'plan.arc',
      'plan.text',
      'plan.symbol',
    ]);
    expect(PlanToolIds.symbolNeeds,
        {Capability.structure, Capability.geometry, Capability.components});
  });

  test(
      'PM-13 buildGenericTools: one tool per id, select with the gates and '
      'the resolver, the fill tools on the one toggle', () {
    final fill = ValueNotifier<bool>(false);
    final gates = SelectGates.all;
    final resolver = _Resolver();
    final set =
        buildGenericTools(gates: gates, fill: fill, moveResolver: resolver);
    addTearDown(() {
      set.dispose();
      fill.dispose();
    });
    expect(set.byId.keys, [for (final t in genericTools) t.id]);
    expect(set.byId['plan.select'], same(set.select));
    expect(set.select.gates, same(gates));
    expect(set.select.moveResolver, same(resolver));
    expect(set.byId['plan.line'], isA<LineTool>());
    expect(set.byId['plan.arc'], isA<ArcTool>());
    expect(set.byId['plan.text'], isA<TextTool>());
    // M-PM13: PolylineTool built without `fill`.
    expect((set.byId['plan.polyline']! as PolylineTool).fill, same(fill));
    expect((set.byId['plan.rectangle']! as RectangleTool).fill, same(fill));
    expect((set.byId['plan.circle']! as CircleTool).fill, same(fill));
    expect((set.byId['plan.line']! as LineTool).fill, isNull);
    final bare = buildGenericTools(gates: gates, fill: fill);
    addTearDown(bare.dispose);
    expect(bare.select.moveResolver, isNull, reason: 'Task 14 injects it');
  });
}
