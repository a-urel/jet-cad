// The alignment guides' toggles in both bars (alignment guides spec,
// "Turning them off", User; plan Task 9b): one plain toggle button per bar,
// its pressed state following the controller's user choice, its tooltip
// localised, hidden with the view's `alignmentGuides: false`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/chrome/icon_button.dart'
    show PlanIconButton;

import '../support/editor_host.dart';
import '../support/mark_kit.dart';
import '../support/service_host.dart' hide byKey;

bool selectedOf(WidgetTester tester, String key) =>
    switch (tester.widget(byKey(key))) {
      // The editor bar's buttons are the chrome's (R-IconButton).
      PlanIconButton(:final selected) => selected!,
      IconButton(:final isSelected) => isSelected!,
      final w => throw StateError('no toggle button: $w'),
    };

void main() {
  group('editor bar', () {
    for (final undo in [true, false]) {
      testWidgets(
          'the default bar shows toolbar-guides (permissions.undo: $undo); a '
          'tap flips the user\'s choice and the pressed state, and a toggle '
          'from outside reaches the button', (tester) async {
        final c = PlanController(
            kits: [markKit()],
            json: editorPlanJson(),
            permissions: PlanPermissions(undo: undo));
        addTearDown(c.dispose);
        await pumpEditor(tester, PlanEditor(controller: c));
        expect(byKey('toolbar-guides'), findsOneWidget);
        expect(byKey('toolbar-undo'), undo ? findsOneWidget : findsNothing);
        expect(c.alignmentGuides.userOn, isTrue, reason: 'premise');
        expect(selectedOf(tester, 'toolbar-guides'), isTrue);

        await tester.tap(byKey('toolbar-guides'));
        await tester.pump();
        expect(c.alignmentGuides.userOn, isFalse);
        expect(selectedOf(tester, 'toolbar-guides'), isFalse);

        c.alignmentGuides.toggle();
        await tester.pump();
        expect(selectedOf(tester, 'toolbar-guides'), isTrue,
            reason: 'the pressed state is listened, not read once');
      });
    }

    testWidgets('an explicit list puts it where it is listed: after Undo',
        (tester) async {
      final c = editorController();
      await pumpEditor(
          tester,
          PlanEditor(
              controller: c,
              bar: const PlanEditorBar(
                  actions: [PlanEditorAction.undo, PlanEditorAction.guides])));
      expect(left(tester, 'toolbar-guides'),
          greaterThan(left(tester, 'toolbar-undo')));
      await pumpEditor(
          tester,
          PlanEditor(
              controller: c,
              bar: const PlanEditorBar(actions: [PlanEditorAction.undo])));
      expect(byKey('toolbar-guides'), findsNothing,
          reason: 'not listed, not shown');
    });

    testWidgets('alignmentGuides: false shows none', (tester) async {
      final c = editorController();
      await pumpEditor(
          tester, PlanEditor(controller: c, alignmentGuides: false));
      expect(byKey('toolbar-guides'), findsNothing);
      expect(byKey('toolbar-undo'), findsOneWidget);
    });

    testWidgets('the tooltip reads Hizalama kılavuzları under tr',
        (tester) async {
      final c = editorController();
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
          locale: const Locale('tr'),
          supportedLocales: planSupportedLocales,
          localizationsDelegates: planLocalizationsDelegates,
          home: Scaffold(body: PlanEditor(controller: c))));
      await tester.pump();
      await tester.pump();
      final guides = tester.widget<PlanIconButton>(byKey('toolbar-guides'));
      expect(guides.tooltip ?? guides.label, 'Hizalama kılavuzları');
    });
  });

  group('service bar', () {
    testWidgets(
        'the default bar shows service-guides right after service-redo and '
        'in the same group; its state follows the user\'s choice',
        (tester) async {
      final c = serviceController(guides: true);
      await pumpService(tester, c, PlanServiceView(controller: c));
      expect(byKey('service-guides'), findsOneWidget);
      final redo = tester.getTopRight(byKey('service-redo')).dx;
      expect(left(tester, 'service-guides') - redo, 0,
          reason: 'same group: no gap');
      expect(selectedOf(tester, 'service-guides'), isTrue);

      await tester.tap(byKey('service-guides'));
      await tester.pump();
      expect(c.alignmentGuides.userOn, isFalse);
      expect(selectedOf(tester, 'service-guides'), isFalse);

      c.alignmentGuides.toggle();
      await tester.pump();
      expect(selectedOf(tester, 'service-guides'), isTrue,
          reason: 'the pressed state is listened, not read once');
    });

    testWidgets('alignmentGuides: false shows none', (tester) async {
      final c = serviceController(guides: true);
      await pumpService(
          tester, c, PlanServiceView(controller: c, alignmentGuides: false));
      expect(byKey('service-guides'), findsNothing);
      expect(byKey('service-redo'), findsOneWidget);
    });

    testWidgets('the tooltip reads Hizalama kılavuzları under tr',
        (tester) async {
      final c = serviceController(guides: true);
      c.setMode(PlanMode.service);
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
          locale: const Locale('tr'),
          supportedLocales: planSupportedLocales,
          localizationsDelegates: planLocalizationsDelegates,
          home: Scaffold(body: PlanServiceView(controller: c))));
      await tester.pump();
      await tester.pump();
      expect(tester.widget<IconButton>(byKey('service-guides')).tooltip,
          'Hizalama kılavuzları');
    });
  });
}
