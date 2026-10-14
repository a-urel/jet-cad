// Spec 2a P2, "The widgets": PlanToolPalette alone, with only a
// controller: the generic tools, then each kit's in load order, grouped;
// labels from tool:<id> in the controller's locale, English where the kit
// has no word; rows disabled by the permissions, letters unbound with
// them; the Fill row while a fill tool is offered.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/canvas_fixture.dart';
import '../support/design_harness.dart';
import '../support/harness.dart' show controllerFor;
import '../support/stamp_kit.dart';
import '../support/throwing_kit.dart';

/// The palette's tool rows' keys, in order (the Fill toggle's inner
/// ListTile carries no key).
List<String> rowKeys(WidgetTester tester) => [
      for (final t in tester.widgetList<ListTile>(find.descendant(
          of: find.byType(PlanToolPalette), matching: find.byType(ListTile))))
        if (t.key case final ValueKey<String> k) k.value,
    ];

bool enabled(WidgetTester tester, String key) =>
    tester.widget<ListTile>(find.byKey(Key(key))).enabled;

void main() {
  testWidgets(
      'KB-7 the generic tools, then each kit\'s in load order, a divider '
      'before each kit; a kit row reads tool:<id> in the locale, English '
      'without a word; the letter is the trailing text (M-KB-7a, M-KB-7b)',
      (tester) async {
    final c = PlanController(kits: [stampKit, lateKit]);
    addTearDown(c.dispose);
    Future<void> pumpIn(Locale locale) async {
      await tester.pumpWidget(MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('de'), Locale('tr')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
              body: SizedBox(
                  width: 240,
                  height: 900,
                  child: PlanToolPalette(controller: c)))));
      await tester.pump();
      await tester.pump();
    }

    await pumpIn(const Locale('tr'));
    expect(rowKeys(tester), [
      'tool-plan.select',
      'tool-plan.line',
      'tool-plan.polyline',
      'tool-plan.rectangle',
      'tool-plan.circle',
      'tool-plan.arc',
      'tool-plan.text',
      'tool-stamp.star',
      'tool-stamp.clash',
      'tool-stamp.fill',
      'tool-stamp.none',
      'tool-late.star',
    ]);
    expect(find.byKey(const Key('tool-group-stamp')), findsOneWidget);
    expect(find.byKey(const Key('tool-group-late')), findsOneWidget);
    expect(
        tester.getTopLeft(find.byKey(const Key('tool-group-stamp'))).dy,
        greaterThan(
            tester.getTopLeft(find.byKey(const Key('tool-plan.text'))).dy));
    Text title(String key) => tester.widget<Text>(find
        .descendant(of: find.byKey(Key(key)), matching: find.byType(Text))
        .first);
    expect(title('tool-stamp.star').data, 'Yıldız');
    expect(title('tool-stamp.clash').data, 'Clash', reason: 'no tr word');
    expect(
        find.descendant(
            of: find.byKey(const Key('tool-stamp.star')),
            matching: find.text('B')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const Key('tool-stamp.clash')),
            matching: find.text('L')),
        findsNothing,
        reason: 'L is plan.line\'s');
    await pumpIn(const Locale('de'));
    expect(title('tool-stamp.star').data, 'Star', reason: 'no de word');
  });

  testWidgets(
      'KB-8 a tool the permissions leave out: its row disabled and its letter '
      'unbound (the key reaches the host); a runtime change rebuilds the '
      'palette and binds it again (M-KB-8a, M-KB-8b)', (tester) async {
    final c = drawController().c;
    final d = await pumpDesign(tester, c, hostKeys: const {
      'l': SingleActivator(LogicalKeyboardKey.keyL),
    });
    c.permissions =
        const PlanPermissions(tools: {'plan.select', 'plan.rectangle'});
    await tester.pump();
    expect(enabled(tester, 'tool-plan.line'), isFalse);
    expect(enabled(tester, 'tool-plan.rectangle'), isTrue);
    await focusCanvas(tester);
    await press(tester, LogicalKeyboardKey.keyL);
    expect(d.reached['l'], 1);
    expect(c.activeTool.value, 'plan.select');
    c.permissions = PlanPermissions.full;
    await tester.pump();
    expect(enabled(tester, 'tool-plan.line'), isTrue);
    await press(tester, LogicalKeyboardKey.keyL);
    expect(c.activeTool.value, 'plan.line');
    expect(d.reached['l'], 1);
  });

  testWidgets(
      'KB-9 F toggles Fill while a fill tool is offered; with none offered '
      'there is no Fill row and F reaches the host (M-KB-9)', (tester) async {
    final c = drawController().c;
    final d = await pumpDesign(tester, c, hostKeys: const {
      'f': SingleActivator(LogicalKeyboardKey.keyF),
    });
    await focusCanvas(tester);
    await press(tester, LogicalKeyboardKey.keyF);
    expect(c.fill.value, isTrue);
    expect(
        tester
            .widget<CheckboxListTile>(find.byKey(const Key('tool-fill')))
            .value,
        isTrue);
    c.permissions = const PlanPermissions(tools: {'plan.select', 'plan.line'});
    await tester.pump();
    expect(find.byKey(const Key('tool-fill')), findsNothing);
    await press(tester, LogicalKeyboardKey.keyF);
    expect(d.reached['f'], 1);
    expect(c.fill.value, isTrue, reason: 'unchanged');
  });

  testWidgets(
      'KB-11 a kit tool whose factory threw for this document is greyed, as '
      'selectTool refuses it; made, it is enabled (spec P4) (M-KB-11)',
      (tester) async {
    Future<void> pumpPalette(PlanController c) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SizedBox(
                  width: 240,
                  height: 900,
                  child: PlanToolPalette(controller: c)))));
      await tester.pump();
    }

    // The control: the factory ran, the row is enabled.
    final healthy = controllerFor(kits: [ThrowingKit().kit]);
    await pumpPalette(healthy);
    expect(enabled(tester, 'tool-boom.tool'), isTrue);

    final c = controllerFor(kits: [
      ThrowingKit(failing: ['toolCreate']).kit
    ]);
    expect(c.isToolDisabled('boom.tool'), isTrue, reason: 'premise');
    expect(c.selectTool('boom.tool'), isFalse, reason: 'premise');
    await pumpPalette(c);
    expect(enabled(tester, 'tool-boom.tool'), isFalse);
    expect(enabled(tester, 'tool-plan.line'), isTrue);
  });
}
