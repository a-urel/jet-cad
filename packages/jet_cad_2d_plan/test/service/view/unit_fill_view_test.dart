// Ported from jet_cad_floor_plan/test/service/table_fill_test.dart;
// assertions unchanged.
//
// Ports TF6 (:650-673) and TF7's selection-mode tail (:735-755) as TF7b
// ("may move, never weaken", 2a's ruling), which controller ruling R-15
// sends here: they read the service layers through the mounted view. Plan
// colours spec PC-5 (2b spec S4 "Painting"): in service a status arriving
// on a coloured unit covers its colour and leaving shows it again; on the
// dark canvas the service view tones the colour as the design does.
//
// Over Task 15's fill fixture and view (`../paint/unit_fill_test.dart`:
// every unit turned and mirrored, 38 m and more off the origin, PlanEditor
// under the seed's themes, the view camera at 0.06 px/mm). Adaptations:
// FloorPlanMode.selection -> PlanMode.service under PlanEditor;
// setTableStatus/TableStatus -> setUnitStatus/UnitStatus; the layers' keys
// `table-*` -> `unit-*` (Task 15); cameraController -> camera.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_plan/src/service/service_session.dart' show PlanMode;
import 'package:jet_cad_2d_plan/src/service/service_state.dart';

import '../../support/canvas_fixture.dart';
import '../paint/unit_fill_test.dart'
    show
        alphaDefault,
        composite,
        controllerOver,
        expectAt,
        insideTop,
        pumpApp,
        pumpPlan,
        red,
        spec,
        teal,
        viewCamera,
        whitePaper;

void main() {
  testWidgets(
      'TF6 Review Focus 1: in the selection mode a status arriving on a teal '
      'table covers its colour, and leaving shows it again, with no '
      'document change', (tester) async {
    final c = controllerOver();
    c.setMode(PlanMode.service);
    await pumpPlan(tester, c);
    expect(find.byKey(const Key('unit-colour-layer')), findsNothing,
        reason: 'the design mount is not in the selection mode');
    final state = c.activeDocument.commands.stateId;
    final c0 = insideTop(spec('C'));
    final tealFill = composite(teal, alphaDefault, whitePaper);
    expectAt(tester, await shoot(tester), c0, tealFill, 'teal before');

    c.setUnitStatus({'C': UnitStatus(color: red)});
    await tester.pump();
    expectAt(tester, await shoot(tester), c0, 0xE53935, 'the status');

    c.setUnitStatus(const {});
    await tester.pump();
    expectAt(tester, await shoot(tester), c0, tealFill, 'teal again');
    expect(c.activeDocument.commands.stateId, state,
        reason: 'no document change');
  });

  testWidgets(
      'TF7b (TF7\'s selection-mode tail) M-C25 Review Focus 5: on the dark '
      'canvas the selection mode tones a teal table too: darkCanvasTone(teal) '
      'at alpha 89 over the dark paper', (tester) async {
    expect(darkCanvasFor(page: 0xFFFFFFFF, brightness: Brightness.dark), isTrue,
        reason: 'premise: a dark theme over a white page');
    const paper = kDarkCanvasPaper & 0xFFFFFF;
    final tone = darkCanvasTone(teal, paper);
    expect(tone, isNot(teal), reason: 'premise: the tone moves teal');
    final c = controllerOver();
    await pumpPlan(tester, c, mode: ThemeMode.dark);

    await pumpApp(tester, c, mode: ThemeMode.dark);
    await tester.pump();
    c.setMode(PlanMode.service);
    await tester.pump();
    await tester.pump();
    c.camera.value = viewCamera;
    await tester.pump();
    expect(find.byKey(const Key('unit-status-layer')), findsOneWidget);
    expectAt(tester, await shoot(tester), insideTop(spec('C')),
        composite(tone, alphaDefault, paper), 'selection mode, dark');
  });
}
