// Review 14d-1 F-3 (the M-14d-s class): an error shown under a field when
// the language changes is worded again in the new language -- the table
// number field's and a layer name field's.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_controller.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_view.dart';
import 'package:jet_cad_floor_plan/src/l10n/localizations.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../tables/table_fixture.dart';

/// Tables 1 (turned) and 2 off the origin, and a layer `Bar` beside `0`.
(String, Handle) twoTables() {
  final doc = plan();
  doc.commands.execute(placeSymbol(doc, entryOf(tableSymbol()),
      at: Vector2(-1250.5, 830.25), quarterTurns: 1));
  doc.commands.execute(
      placeSymbol(doc, entryOf(tableSymbol()), at: Vector2(2140.75, -610.5)));
  final zero = doc.tables.layers[ReservedHandles.layerZero]!;
  final bar = doc.handleSeed.next();
  doc.commands.execute(AddLayerCommand(LayerRecord(
      handle: bar,
      name: 'Bar',
      color: const IndexedColor(5),
      linetype: zero.linetype,
      lineweight: zero.lineweight,
      transparency: zero.transparency,
      visible: true,
      locked: false)));
  return (DraftDocumentCodec.encodeToString(doc), bar);
}

Future<(FloorPlanController, ValueNotifier<Locale>)> pump(
    WidgetTester tester, String json) async {
  final c = FloorPlanController(json: json);
  addTearDown(c.dispose);
  final locale = ValueNotifier(const Locale('de'));
  addTearDown(locale.dispose);
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ValueListenableBuilder<Locale>(
      valueListenable: locale,
      builder: (_, l, __) => MaterialApp(
          locale: l,
          supportedLocales: floorPlanSupportedLocales,
          localizationsDelegates: floorPlanLocalizationsDelegates,
          home: Scaffold(body: FloorPlanView(controller: c)))));
  await tester.pump();
  return (c, locale);
}

String? errorOf(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(Key(key))).decoration!.errorText;

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
      'SE1 a number already used, refused in German, reads in English after '
      'the switch', (tester) async {
    final (json, _) = twoTables();
    final (c, locale) = await pump(tester, json);
    final one = TableSurvey.of(c.activeDocument).withNumber('1').single;
    c.activeSelection.replace([SelectionKey.root(one.instance)]);
    await tester.pump();
    await enter(tester, 'table-number', '2');
    String numberError() =>
        tester.widget<Text>(find.byKey(const Key('table-number-error'))).data!;
    expect(numberError(), 'Die Nummer 2 ist bereits vergeben',
        reason: 'premise: refused in German');
    locale.value = const Locale('en');
    await tester.pump();
    await tester.pump();
    expect(numberError(), 'Number 2 is already used');
  });

  testWidgets(
      'SE2 a layer name already used, refused in German, reads in English '
      'after the switch', (tester) async {
    final (json, bar) = twoTables();
    final (_, locale) = await pump(tester, json);
    final hex = bar.toHex();
    await tester.tap(find.byKey(Key('layer-name-$hex')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(Key('layer-name-$hex')));
    await tester.pump();
    await tester.pump();
    final field = 'layer-name-field-$hex';
    expect(find.byKey(Key(field)), findsOneWidget,
        reason: 'premise: the rename is open');
    await tester.enterText(find.byKey(Key(field)), '0');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(errorOf(tester, field), 'Eine Ebene namens 0 gibt es bereits.',
        reason: 'premise: refused in German');
    locale.value = const Locale('en');
    await tester.pump();
    await tester.pump();
    expect(errorOf(tester, field), 'A layer named 0 already exists.');
    await tester.pump(const Duration(seconds: 1));
  });
}
