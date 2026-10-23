// Alignment guides on show (alignment guides spec, G6): the demo passes
// `alignmentGuides: true`, the editor's bar carries the toggle in the
// design, the service bar carries it in service, and the POS look draws the
// guides 1.5 px wide.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:restaurant_demo/demo_theme.dart';

import 'support/demo_rig.dart';

void main() {
  testWidgets(
      'GD1 the design bar shows the guides toggle and the service bar its own; '
      'the toggle flips the controller\'s switch', (tester) async {
    final demo = await pumpDemo(tester);
    final c = demo.area.controller;
    expect(tester.widget<PlanEditor>(find.byType(PlanEditor)).alignmentGuides,
        isTrue,
        reason: 'the demo says so explicitly');
    expect(byKey('toolbar-guides'), findsOneWidget);
    expect(byKey('service-guides'), findsNothing, reason: 'design has none');
    expect(c.alignmentGuides.on, isTrue);

    await tester.tap(byKey('toolbar-guides'));
    await tester.pump();
    expect(c.alignmentGuides.userOn, isFalse);
    expect(c.alignmentGuides.on, isFalse);

    await tester.tap(byKey('mode-service'));
    await tester.pump();
    await tester.pump();
    expect(c.mode.value, PlanMode.service);
    expect(byKey('service-guides'), findsOneWidget);
    expect(byKey('toolbar-guides'), findsNothing);
    expect(c.alignmentGuides.userOn, isFalse,
        reason: 'the choice survives the mode switch');

    await tester.tap(byKey('service-guides'));
    await tester.pump();
    expect(c.alignmentGuides.on, isTrue);
  });

  test('GD2 the POS look draws guides 1.5 px wide, light and dark', () {
    expect(posPlanTheme(Brightness.light).guideWidth, 1.5);
    expect(posPlanTheme(Brightness.dark).guideWidth, 1.5);
  });
}
