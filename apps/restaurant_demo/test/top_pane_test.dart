// The top pane, the side sheet and the controls in shadcn (spec D3, D4, D5,
// D6; plan Task 2): no Material scaffold, app bar, drawer, segmented button,
// text field or tooltip is built by the page itself (the planner's own
// subtree and the side panel's widgets, Task 3's, apart), the toggles are
// `ShadTabs`, the find field a `ShadInput`, the side panel a `ShadSheet` of
// 320 px on a narrow window, and the controls survive a large text scale.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:restaurant_demo/demo_strings.dart';
import 'package:restaurant_demo/main.dart';
import 'package:restaurant_demo/side_panel.dart' show DemoSidePanel;
import 'package:shadcn_ui/shadcn_ui.dart';

import 'support/demo_rig.dart';

/// Whether [e] is built by the page itself: under [DemoHome], and under
/// neither the planner's editor nor the side panel (Task 3's).
bool _byPage(Element e) {
  var mine = false;
  var foreign = false;
  e.visitAncestorElements((a) {
    if (a.widget is DemoHome) {
      mine = true;
      return false;
    }
    if (a.widget is PlanEditor || a.widget is DemoSidePanel) {
      foreign = true;
    }
    return true;
  });
  return mine && !foreign;
}

Finder _built<T extends Widget>() =>
    find.byElementPredicate((e) => e.widget is T && _byPage(e));

void main() {
  testWidgets(
      'RT1 at 1300 px the page builds no Scaffold, AppBar, Drawer, '
      'SegmentedButton, TextField or Tooltip; the keys are on shadcn widgets',
      (tester) async {
    await pumpDemo(tester, size: const Size(1300, 900));
    expect(tester.takeException(), isNull);
    expect(_built<Scaffold>(), findsNothing);
    expect(_built<AppBar>(), findsNothing);
    expect(_built<Drawer>(), findsNothing);
    expect(_built<SegmentedButton<Object?>>(), findsNothing);
    expect(_built<TextField>(), findsNothing);
    expect(_built<Tooltip>(), findsNothing);
    expect(_built<IconButton>(), findsNothing);
    expect(tester.widget(byKey('find-table')), isA<ShadInput>());
    for (final key in const [
      'language-toggle',
      'look-toggle',
      'area-toggle',
      'mode-toggle'
    ]) {
      expect(tester.widget(byKey(key)), isA<ShadTabs<dynamic>>(), reason: key);
    }
    // Docked: the side panel is beside the editor, no side button.
    expect(byKey('side-panel'), findsOneWidget);
    expect(byKey('side-panel-button'), findsNothing);
    // The selection is the tabs' value.
    expect(
        tester.widget<ShadTabs<String>>(byKey('language-toggle')).value, 'en');
    expect(tester.widget<ShadTabs<PlanMode>>(byKey('mode-toggle')).value,
        PlanMode.design);
  });

  testWidgets(
      'RT2 at 375 x 812 the side button opens a 320 px ShadSheet holding the '
      'side panel, on screen; the controls scroll sideways; no overflow',
      (tester) async {
    await pumpDemo(tester, size: const Size(375, 812));
    expect(tester.widget(byKey('side-panel-button')), isA<ShadIconButton>());
    expect(byKey('side-panel-drawer'), findsNothing);
    final controls = find.descendant(
        of: byKey('app-controls'), matching: find.byType(Scrollable));
    expect(
        tester
            .widget<SingleChildScrollView>(byKey('app-controls'))
            .scrollDirection,
        Axis.horizontal);
    expect(controls, findsWidgets);
    // The row is wider than the window: it scrolls.
    expect(
        tester
            .getSize(find
                .descendant(
                    of: byKey('app-controls'), matching: find.byType(Row))
                .first)
            .width,
        greaterThan(375));
    await tester.tap(byKey('side-panel-button'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.widget(byKey('side-panel-drawer')), isA<ShadSheet>());
    expect(
        find.descendant(
            of: byKey('side-panel-drawer'),
            matching: find.byType(DemoSidePanel)),
        findsOneWidget);
    // The keyed ShadSheet fills the route; the panel it shows is 320 px
    // wide at the right edge.
    final sheet = tester.getRect(find.byType(DemoSidePanel));
    expect(sheet.width, 320);
    expect(sheet.right, lessThanOrEqualTo(375));
    expect(sheet.left, greaterThanOrEqualTo(0));
    expect(sheet.bottom, lessThanOrEqualTo(812));
    // The barrier closes it.
    await tester.tapAt(const Offset(4, 400));
    await tester.pumpAndSettle();
    expect(byKey('side-panel-drawer'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in [375.0, 1300.0]) {
    testWidgets(
        'RT3 at ${width.toInt()} px a text scale of 2.0 overflows '
        'nothing, the sheet included', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await pumpDemo(tester, size: Size(width, 900));
      expect(tester.takeException(), isNull);
      if (width < kDockedSidePanel) {
        await tester.tap(byKey('side-panel-button'));
        await tester.pumpAndSettle();
        expect(byKey('side-panel'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } else {
        expect(byKey('side-panel'), findsOneWidget);
      }
    });
  }

  testWidgets(
      'RT4 the mode tabs, the look tabs and the find field take the '
      'language: DE, then TR, no stale English', (tester) async {
    await pumpDemo(tester, size: const Size(1300, 900));
    expect(find.text('Design'), findsOneWidget);
    await switchLanguage(tester, 'de');
    var words = DemoStrings.of(tester.element(find.byType(DemoHome)));
    expect(words.design, 'Entwurf');
    expect(textOf(tester, 'mode-design'), 'Entwurf');
    expect(textOf(tester, 'mode-service'), words.service);
    expect(find.text('Design'), findsNothing);
    expect(find.text('Tisch suchen'), findsOneWidget);
    expect(
        tester.widget<ShadTabs<String>>(byKey('language-toggle')).value, 'de');
    await switchLanguage(tester, 'tr');
    words = DemoStrings.of(tester.element(find.byType(DemoHome)));
    expect(textOf(tester, 'mode-design'), 'Tasarım');
    expect(textOf(tester, 'mode-service'), 'Servis');
    expect(textOf(tester, 'look-standard'), 'Standart');
    expect(find.text('Entwurf'), findsNothing);
    expect(find.text('Masa bul'), findsOneWidget);
    expect(find.text(words.design), findsOneWidget);
    expect(
        tester.widget<ShadTabs<String>>(byKey('language-toggle')).value, 'tr');
  });
}
