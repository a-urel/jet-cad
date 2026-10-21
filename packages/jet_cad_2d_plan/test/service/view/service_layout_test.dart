// POS-host Task 7 (spec D6): the service mode on a phone, a tablet and a
// desktop, with the host's side panel.
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../../support/service_host.dart';

final _panel = GestureDetector(
    key: const Key('host-panel'),
    behavior: HitTestBehavior.opaque,
    onTap: () {},
    child: const SizedBox.expand());

Future<PlanController> pump(WidgetTester tester, double w,
    {Widget? panel,
    PlanEditorLayout? layout,
    List<String>? taps,
    bool keepNull = false,
    bool editor = false}) async {
  final c = rowsController();
  panel ??= keepNull ? null : _panel;
  c.setMode(PlanMode.service);
  await tester.binding.setSurfaceSize(Size(w, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: editor
              ? PlanEditor(
                  controller: c,
                  serviceSidePanel: panel,
                  layout: layout,
                  onUnitTap: taps?.add)
              : PlanServiceView(
                  controller: c,
                  serviceSidePanel: panel,
                  layout: layout,
                  onUnitTap: taps?.add))));
  await tester.pump();
  await tester.pump();
  c.fitToView();
  await tester.pump();
  await tester.pump();
  return c;
}

bool hit(String key) => byKey(key).hitTestable().evaluate().isNotEmpty;

void main() {
  for (final editor in [false, true]) {
    final who = editor ? 'PlanEditor' : 'PlanServiceView';

    testWidgets(
        'SL1 desktop ($who): the panel docked 320 wide, the plan beside it',
        (tester) async {
      await pump(tester, 1200, editor: editor);
      expect(byKey('service-side-panel'), findsOneWidget);
      expect(tester.getSize(byKey('service-side-panel')).width, 320);
      expect(byKey('service-right-button'), findsNothing);
      final panel = tester.getRect(byKey('service-side-panel'));
      expect(panel.right, 1200);
      final canvas = tester.getRect(find.byType(InteractionLayer));
      expect(canvas.right, panel.left);
      expect(hit('host-panel'), isTrue);
    });

    testWidgets(
        'SL2 phone ($who): the button opens and closes the panel; a unit tap '
        'reaches onUnitTap while it is closed', (tester) async {
      final taps = <String>[];
      final c = await pump(tester, 375, taps: taps, editor: editor);
      expect(byKey('service-right-button'), findsOneWidget);
      expect(hit('host-panel'), isFalse);
      expect(tester.getSize(byKey('service-bar')).width, 375);
      expect(tester.getRect(byKey('service-right-button')).right,
          lessThanOrEqualTo(375));
      final label = c.unitDetails.first.unit.label!;
      await tester.tapAt(globalOfWorld(tester, c, unitCentre(c, label)),
          kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 400));
      expect(taps, [label]);
      await tester.tap(byKey('service-right-button'));
      await tester.pump();
      expect(hit('host-panel'), isTrue);
      expect(tester.getSize(byKey('service-side-panel')).width, 300);
      // The barrier takes a tap on the plan: it closes the panel and no
      // unit tap reaches the host.
      await tester.tapAt(const Offset(8, 400), kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 400));
      expect(taps, [label]);
      expect(hit('host-panel'), isFalse);
      await tester.tap(byKey('service-right-button'));
      await tester.pump();
      expect(hit('host-panel'), isTrue);
      await tester.tap(byKey('service-right-button'));
      await tester.pump();
      expect(hit('host-panel'), isFalse);
    });

    testWidgets('SL3 no serviceSidePanel ($who): no button, no column',
        (tester) async {
      for (final w in [1200.0, 800.0, 320.0]) {
        await pump(tester, w, keepNull: true, editor: editor);
        expect(byKey('service-right-button'), findsNothing, reason: '$w');
        expect(byKey('service-side-panel'), findsNothing, reason: '$w');
        expect(tester.takeException(), isNull, reason: '$w');
      }
    });
  }

  testWidgets('SL5 tablet: button, drawer; 320 px: the bar does not overflow',
      (tester) async {
    await pump(tester, 800);
    expect(byKey('service-right-button'), findsOneWidget);
    await pump(tester, 320);
    expect(tester.takeException(), isNull);
    expect(byKey('service-right-button'), findsOneWidget);
    expect(tester.getRect(byKey('service-right-button')).right,
        lessThanOrEqualTo(320));
    await tester.tap(byKey('service-right-button'));
    await tester.pump();
    expect(hit('host-panel'), isTrue);
    // 85 % cap of 320.
    expect(tester.getSize(byKey('service-side-panel')).width, 272);
  });

  testWidgets(
      'SL6 PlanEditor passes layout and breakpoints to its service view',
      (tester) async {
    await pump(tester, 1200, editor: true, layout: PlanEditorLayout.phone);
    expect(byKey('service-right-button'), findsOneWidget);
    await tester.tap(byKey('service-right-button'));
    await tester.pump();
    expect(tester.getSize(byKey('service-side-panel')).width, 300);
    final c = rowsController();
    c.setMode(PlanMode.service);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: PlanEditor(
                controller: c,
                serviceSidePanel: _panel,
                breakpoints: const PlanLayoutBreakpoints(
                    tablet: 1300, desktop: 1500)))));
    await tester.pump();
    await tester.pump();
    expect(byKey('service-right-button'), findsOneWidget);
  });

  testWidgets(
      'SL7 the service side panel open on the phone, the surface resized to '
      '1440 x 900 and back: no exception, no drawer left open, the panel '
      'docked at desktop, and the unit selection/statuses kept',
      (tester) async {
    final c = await pump(tester, 375);
    final label = c.unitDetails.first.unit.label!;
    c.select({label});
    c.setUnitStatus({label: UnitStatus(color: const Color(0xFFE53935))});
    await tester.pump();
    await tester.tap(byKey('service-right-button'));
    await tester.pump();
    expect(hit('host-panel'), isTrue, reason: 'premise');
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(byKey('service-right-button'), findsNothing);
    expect(byKey('chrome-drawer-barrier'), findsNothing);
    expect(tester.getSize(byKey('service-side-panel')).width, 320);
    expect(hit('host-panel'), isTrue);
    await tester.binding.setSurfaceSize(const Size(375, 700));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(hit('host-panel'), isFalse);
    expect(byKey('chrome-drawer-barrier'), findsNothing);
    expect(c.selectedUnits.value, {label});
    expect(c.unitStatuses.value.keys, [label]);
  });

  testWidgets(
      'SL4 switching design to service with a design drawer open '
      'closes it', (tester) async {
    final c = rowsController();
    await tester.binding.setSurfaceSize(const Size(375, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: PlanEditor(controller: c, serviceSidePanel: _panel))));
    await tester.pump();
    await tester.pump();
    await tester.tap(byKey('chrome-right-button'));
    await tester.pump();
    expect(hit('chrome-right-drawer'), isTrue, reason: 'premise');
    c.setMode(PlanMode.service);
    await tester.pump();
    await tester.pump();
    expect(byKey('chrome-right-drawer'), findsNothing);
    expect(byKey('chrome-drawer-barrier'), findsNothing);
    expect(hit('host-panel'), isFalse);
    c.setMode(PlanMode.design);
    await tester.pump();
    await tester.pump();
    expect(hit('chrome-right-drawer'), isFalse);
    expect(byKey('chrome-drawer-barrier'), findsNothing);
  });
}
