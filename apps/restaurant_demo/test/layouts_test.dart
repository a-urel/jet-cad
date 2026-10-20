// POS-host Task 10 (spec D14, plan DL4): the demo on a phone, a tablet and a
// desktop. The window decides the shape: the side panel docks from 1300
// logical px (the editor then has the plan's 1000), and below it is the end
// drawer behind the app bar's button, the app bar's controls scroll under
// the title. A RenderFlex overflow is an exception in a test, so
// `takeException` is the overflow check.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import 'support/demo_rig.dart';

const _sizes = <(String, Size, PlanEditorLayout)>[
  ('phone', Size(375, 812), PlanEditorLayout.phone),
  ('tablet', Size(800, 1280), PlanEditorLayout.tablet),
  ('desktop', Size(1440, 900), PlanEditorLayout.desktop),
];

void main() {
  for (final (name, size, layout) in _sizes) {
    for (final service in [false, true]) {
      final mode = service ? 'service' : 'design';
      testWidgets(
          'RS1 (DL4) at $name ${size.width.toInt()} x ${size.height.toInt()} '
          'in $mode the demo builds with no exception and no overflow, in '
          'the $name layout', (tester) async {
        final demo = await pumpDemo(tester, size: size);
        final c = demo.area.controller;
        final docked = size.width >= 1300;
        if (service) {
          demo.setMode(PlanMode.service);
          await settle(tester);
        }
        expect(c.mode.value, service ? PlanMode.service : PlanMode.design);
        expect(tester.takeException(), isNull);
        expect(byKey('side-panel'), docked ? findsOneWidget : findsNothing);
        expect(
            byKey('side-panel-button'), docked ? findsNothing : findsOneWidget);
        if (!service) {
          // The plan's own chrome follows the editor's width.
          expect(
              byKey('chrome-left'),
              layout == PlanEditorLayout.desktop
                  ? findsOneWidget
                  : findsNothing);
          expect(
              byKey('chrome-tool-strip'),
              layout == PlanEditorLayout.tablet
                  ? findsOneWidget
                  : findsNothing);
          expect(byKey('chrome-left-button'),
              layout == PlanEditorLayout.phone ? findsOneWidget : findsNothing);
        }
        if (!docked) {
          // The side panel is the end drawer, whole.
          await tester.tap(byKey('side-panel-button'));
          await tester.pumpAndSettle();
          expect(byKey('side-panel'), findsOneWidget);
          expect(tester.getSize(byKey('side-panel-drawer')).width,
              lessThanOrEqualTo(size.width));
          await tester.tapAt(const Offset(4, 400));
          await tester.pumpAndSettle();
          expect(byKey('side-panel'), findsNothing);
        }
        // The other area, and back: no exception either.
        demo.setArea(1);
        await settle(tester);
        expect(demo.area.name, 'Teras');
        demo.setArea(0);
        await settle(tester);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
      'RS2 the app bar\'s controls scroll on a phone: the mode toggle is '
      'reached by tapping it', (tester) async {
    final demo = await pumpDemo(tester, size: const Size(375, 812));
    final c = demo.area.controller;
    await tester.ensureVisible(byKey('mode-service'));
    await tester.pump();
    await tester.tap(byKey('mode-service'));
    await settle(tester);
    expect(c.mode.value, PlanMode.service);
    expect(tester.takeException(), isNull);
  });
}
