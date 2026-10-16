// New (Task 8, Review Focus 5): an export started in one area belongs to
// that area. Switching the shown area while the export dialog is up must not
// make the export write the other area's page, or file it under the other
// area's name or log line. Two paths:
//
// - EX-area-own: the demo's own service bar's Export. The export is the
//   demo's (`controller.export`), so it goes on and writes the Salon's page
//   named `salon.png`, logged under the Salon.
// - EX-area-planner: the planner's Export in the design. Switching areas
//   unmounts the Salon's editor and with it its export flow: the dialog is
//   still up, and answering it writes nothing, anywhere (the library's
//   rule: a flow does not outlive its editor).
//
// The expected bytes are the controllers' own `export`, computed here.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import 'support/demo_rig.dart';

const PlanExportChoice dpi96 = PlanExportChoice(dpi: PlanExportDpi.d96);

Future<void> answerPng96(WidgetTester tester) async {
  await tester.tap(byKey('export-format-plan.png'));
  await tester.pump();
  await tester.tap(byKey('export-dpi-96'));
  await tester.pump();
  await tester.tap(byKey('export-ok'));
  await tester.pump();
}

void main() {
  testWidgets(
      'EX-area-own an export started from the own bar in the Salon writes '
      "the Salon's page, named salon.png, logged under the Salon, though "
      'the Teras is shown while the dialog is up', (tester) async {
    final demo = await pumpDemo(tester);
    final salon = demo.areas[0].controller, teras = demo.areas[1].controller;
    await enterService(tester);
    await pressInPanel(tester, 'own-bar');
    await press(tester, 'own-export');
    expect(byKey('export-dialog'), findsOneWidget);

    demo.setArea(1);
    await settle(tester);
    expect(demo.area.name, 'Teras', reason: 'premise: the Teras is shown');
    expect(byKey('own-bar-row'), findsNothing, reason: 'premise: its design');
    expect(byKey('export-dialog'), findsOneWidget,
        reason: 'premise: the dialog is still up');
    await answerPng96(tester);
    await waitFor(tester, () => demo.lastExport != null);

    final export = demo.lastExport!;
    final wanted =
        (await tester.runAsync(() => salon.export('plan.png', dpi96)))!;
    final other =
        (await tester.runAsync(() => teras.export('plan.png', dpi96)))!;
    expect(wanted.bytes, isNot(other.bytes),
        reason: 'premise: the two pages differ');
    expect(export.name, 'salon.png');
    expect(export.bytes, wanted.bytes);
    expect(demo.log.first,
        'Salon: exported salon.png, ${export.bytes.length} bytes');
    expect(demo.log.where((l) => l.startsWith('Teras:')), isEmpty);
    expect(salon.pageFlowBusy.value, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'EX-area-planner the planner\'s Export started in the Salon, with the '
      'Teras shown while its dialog is up, writes nothing in either area',
      (tester) async {
    final demo = await pumpDemo(tester);
    final salon = demo.areas[0].controller, teras = demo.areas[1].controller;
    await press(tester, 'toolbar-export');
    expect(byKey('export-dialog'), findsOneWidget);
    expect(salon.pageFlowBusy.value, isTrue, reason: 'premise: a flow runs');

    demo.setArea(1);
    await settle(tester);
    expect(demo.area.name, 'Teras', reason: 'premise: the Teras is shown');
    expect(byKey('export-dialog'), findsOneWidget,
        reason: 'premise: the dialog is still up');
    await answerPng96(tester);
    // Real time for an export that would have been made.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1500)));
    await settle(tester);

    expect(demo.lastExport, isNull);
    expect(demo.log.where((l) => l.contains('exported')), isEmpty);
    expect(salon.pageFlowBusy.value, isFalse);
    expect(teras.pageFlowBusy.value, isFalse);
    expect(tester.takeException(), isNull);

    // Nothing is stuck: the Teras exports as usual.
    await press(tester, 'toolbar-export');
    await answerPng96(tester);
    await waitFor(tester, () => demo.lastExport != null);
    expect(demo.lastExport!.name, 'teras.png');
    expect(demo.log.first, startsWith('Teras: exported teras.png, '));
  });
}
