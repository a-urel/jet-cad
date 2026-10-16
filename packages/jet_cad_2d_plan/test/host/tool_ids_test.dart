// Sub-project 4a R2 H1: `PlanToolIds` is public, so a host names the
// tools it offers without hard-coding id strings. This file imports the
// barrel alone.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

void main() {
  test('H1 PlanToolIds through the barrel: a host offers select and line only',
      () {
    final c = PlanController(
        kits: const [],
        permissions: const PlanPermissions(
            tools: {PlanToolIds.select, PlanToolIds.line}));
    addTearDown(c.dispose);
    expect(PlanToolIds.all.toSet(), {
      'plan.select',
      'plan.line',
      'plan.polyline',
      'plan.rectangle',
      'plan.circle',
      'plan.arc',
      'plan.text',
      'plan.symbol',
    });
    expect(c.selectTool(PlanToolIds.line), isTrue);
    expect(c.selectTool(PlanToolIds.circle), isFalse,
        reason: 'circle is not in the host\'s set');
    expect(c.selectTool(PlanToolIds.select), isTrue);
  });
}
