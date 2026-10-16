// Ported from apps/floor_planner/test/layers/layer_picker_test.dart:352-401 (3a Task 26, spec C6); assertions unchanged.
//
// Spec 12b D12, D11: the Selection section's layer picker. It shows for a
// non-empty selection whenever no tool's settings show, including where no
// type section does (a line); it shows the common layer or "Mixed"; one
// choice is one command, one undo step, whatever the selection holds — a
// drafted region moves every record of it, an ATTRIB moves its instance, a
// parametric object moves by its `ObjectLayer`; members already on the
// target are skipped; a plain group disables it; read-only disables it and
// the runtime preset does not.
//
// P-6's layers: `A` (ACI 1), `B` (ACI 5, locked), `C` (ACI 3, hidden), and a
// visible `D` (ACI 2) added here as a target that keeps the selection. Walls
// sit in rotated groups at the corpus far origin; the line, the region and
// the symbol are away from the origin; the symbol is turned.
// The app's wall case: today's open is the app's; the plan opened is the
// same, P-6's picker fixture as a plan file (layer_plan.dart's
// `pickerPlan`), in the plan library's editor over the architecture kit.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';

import '../support/canvas_rig.dart';
import '../support/layer_plan.dart';

/// The picker's shown value (jet_cad_2d_plan/test/panels/
/// layer_picker_test.dart:179-181).
String valueOf(WidgetTester tester) =>
    tester.widget<Text>(byKey('layer-picker-value')).data!;

void main() {
  testWidgets(
      'in the app: below the Selection section\'s type section for a wall; '
      'absent while an opening tool\'s or the Wall tool\'s settings show',
      (tester) async {
    final p = pickerPlan();
    final c = architectureController(json: p.json);
    addTearDown(c.dispose);
    await pumpPlanEditor(tester, c);
    c.activeSelection.replace([SelectionKey.root(p.wall)]);
    await tester.pump();
    final right = find.byKey(const Key('chrome-right'));
    expect(find.descendant(of: right, matching: byKey('layer-picker')),
        findsOneWidget);
    expect(tester.getTopLeft(byKey('layer-picker')).dy,
        greaterThan(tester.getTopLeft(byKey('section-architecture.wall')).dy));
    expect(valueOf(tester), 'A');

    c.activeSelection.replace([SelectionKey.root(p.door)]);
    await tester.pump();
    expect(byKey('layer-picker'), findsOneWidget);
    await tester.tap(byKey('tool-architecture.door'));
    await tester.pump();
    await tester.pump();
    // Activating a drawing tool clears the selection; a selection made
    // while the tool is active (only code can) still shows no picker,
    // because the tool's settings show (S-13).
    c.activeSelection
        .replace([SelectionKey.root(p.door), SelectionKey.root(p.line)]);
    await tester.pump();
    expect(c.activeSelection.keys, hasLength(2), reason: 'premise');
    expect(byKey('settings-architecture.door'), findsOneWidget,
        reason: 'premise: the Door tool\'s settings show');
    expect(byKey('layer-picker'), findsNothing);

    // The same for the Wall tool's settings.
    await tester.tap(byKey('tool-architecture.wall'));
    await tester.pump();
    await tester.pump();
    c.activeSelection.replace([SelectionKey.root(p.line)]);
    await tester.pump();
    expect(c.activeSelection.keys, hasLength(1), reason: 'premise');
    expect(byKey('settings-architecture.wall'), findsOneWidget,
        reason: 'premise: the Wall tool\'s settings show');
    expect(byKey('layer-picker'), findsNothing);
  });
}
