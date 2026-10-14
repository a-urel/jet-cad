// Ported from jet_cad_floor_plan/test/l10n/stale_error_test.dart (2b Task
// 10; assertions unchanged; SE1 is named SE1L here, as 2a named SE2 SE2L:
// Task 14 ports service_events_test.dart's SE1 ... SE16 under their source
// ids; SE2 -- the layer name -- is 2a's ground).
//
// Review 14d-1 F-3 (the M-14d-s class): an error shown under a field when
// the language changes is worded again in the new language -- the unit
// label field's.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/unit_fixtures.dart';

/// Tables 1 (turned) and 2 off the origin, and a layer `Bar` beside `0`.
String twoTables() => planText([fxKit()], (d) {
      addUnitLabel(
          d,
          placeAt(d, tableSymbol(), Vector2(-1250.5, 830.25), quarterTurns: 1),
          '1');
      addUnitLabel(d, placeAt(d, tableSymbol(), Vector2(2140.75, -610.5)), '2');
      addLayer(d, 'Bar');
    });

Future<(PlanController, ValueNotifier<Locale>)> pump(
    WidgetTester tester, String json) async {
  final c = controllerFor(kits: [fxKit()], json: json);
  final locale = ValueNotifier(const Locale('de'));
  addTearDown(locale.dispose);
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ValueListenableBuilder<Locale>(
      valueListenable: locale,
      builder: (_, l, __) => MaterialApp(
          locale: l,
          supportedLocales: planSupportedLocales,
          localizationsDelegates: planLocalizationsDelegates,
          home: Scaffold(body: PlanEditor(controller: c)))));
  await tester.pump();
  return (c, locale);
}

Future<void> enter(WidgetTester tester, String key, String text) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets(
      'SE1L a number already used, refused in German, reads in English after '
      'the switch', (tester) async {
    final (c, locale) = await pump(tester, twoTables());
    final one = c.unitIndex.withLabel('1').single;
    c.selection.replace([SelectionKey.root(one.instance)]);
    await tester.pump();
    await enter(tester, 'unit-label', '2');
    String numberError() =>
        tester.widget<Text>(find.byKey(const Key('unit-label-error'))).data!;
    expect(numberError(), 'Die Nummer 2 ist bereits vergeben',
        reason: 'premise: refused in German');
    locale.value = const Locale('en');
    await tester.pump();
    await tester.pump();
    expect(numberError(), 'Number 2 is already used');
  });
}
