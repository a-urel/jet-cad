// The shell (Task 6): the app pumps; each of the two areas is its own
// controller over `[architectureKit, restaurantKit]` and shows its own plan;
// the area switch swaps the editor and leaves the other area untouched.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import 'support/demo_rig.dart';

PlanController editorsController(WidgetTester tester) =>
    tester.widget<PlanEditor>(find.byType(PlanEditor)).controller;

void main() {
  testWidgets('SH1 the app pumps on the Salon, with its editor',
      (tester) async {
    final demo = await pumpDemo(tester);
    expect(find.byType(PlanEditor), findsOneWidget);
    expect(demo.areas.map((a) => a.name), ['Salon', 'Teras']);
    expect(
        identical(editorsController(tester), demo.areas[0].controller), isTrue);
    expect(find.text('Salon'), findsOneWidget);
    expect(demo.areas[0].controller.units.length, 11);
  });

  testWidgets(
      'SH2 the area switch shows the Teras and back; each area keeps '
      'its own controller and plan', (tester) async {
    final demo = await pumpDemo(tester);
    final salon = demo.areas[0].controller, teras = demo.areas[1].controller;
    expect(identical(salon, teras), isFalse);
    await tester.tap(byKey('area-1'));
    await tester.pump();
    await tester.pump();
    expect(identical(editorsController(tester), teras), isTrue);
    expect(
        [for (final u in teras.units) u.label], ['1', '2', '3', '4', '5', '6']);
    await tester.tap(byKey('area-0'));
    await tester.pump();
    await tester.pump();
    expect(identical(editorsController(tester), salon), isTrue);
    expect(salon.units.length, 11);
    expect(teras.units.length, 6);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SH3 the language and the look switch without an exception',
      (tester) async {
    await pumpDemo(tester);
    await tester.tap(byKey('lang-tr'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('TR'), findsOneWidget);
    await tester.tap(byKey('look-pos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PlanEditor), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
