// Ported from jet_cad_floor_plan/test/separator_tool_test.dart, ST1's shell
// half (:196-223, spec 10 D20); assertions unchanged. PlannerShell becomes
// PlanEditor over a controller of the kit whose plan is today's boxWalls,
// built through the plan's build seam (spec 3a C1.9, C6), turned and in
// own groups; the palette's 'tool-separator' is
// 'tool-architecture.separator' (C7 class 1). The pending start is the
// active tool's isMidShape, a PlacementTool's isPending (ruling R17-1).
// ST1's tool half and ST2-ST6 are the kit's.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/editor_rig.dart';
import 'separator_plans.dart';

void main() {
  testWidgets(
      'ST1 (editor) S and the palette entry activate the Separator tool; '
      'Esc cancels a pending start, then returns to Select', (tester) async {
    final c = PlanController(kits: [architectureKit], build: buildBox);
    addTearDown(c.dispose);
    await pumpEditor(tester, c, centre: boxAt(4000, 2000), scale: 0.08);
    await press(tester, LogicalKeyboardKey.keyS);
    expect(status(tester), 'Separator');
    await press(tester, LogicalKeyboardKey.keyV);
    await tester
        .tap(find.byKey(const Key('tool-${ArchitectureTools.separator}')));
    await tester.pump();
    expect(status(tester), 'Separator');
    final sep = activeTool(tester);
    final p = boxAt(2500.5, 2000.25);
    await tester.tapAt(globalOf(tester, c, p.x, p.y));
    await tester.pump();
    expect(sep.isMidShape, isTrue);
    await press(tester, LogicalKeyboardKey.escape);
    expect(sep.isMidShape, isFalse, reason: 'the pending start cancelled');
    expect(status(tester), 'Separator');
    await press(tester, LogicalKeyboardKey.escape);
    expect(status(tester), 'Select');
    expect(liveOf<SeparatorParams>(c, ArchitectureTypes.separator), isEmpty);
  });
}
