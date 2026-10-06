// Spec 14d L12, L15 (revision 2): the panels speak the host's language and
// show and read their numbers with its separator; a change of language
// while mounted shows the fields again in it (M-14d-s). A wall off the
// origin with a fractional thickness; a page at a fractional scale.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_controller.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_view.dart';
import 'package:jet_cad_floor_plan/src/l10n/localizations.dart';
import 'package:jet_cad_floor_plan/src/new_document.dart';
import 'package:jet_cad_floor_plan/src/parametric/catalog.dart';
import 'package:jet_cad_floor_plan/src/parametric/wall.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/wall_fixture.dart' show addWall;

/// A plan with one wall, 112.5 thick, and its page at 1:12.5.
(String, Handle) wallPlan() {
  final measurer = FlutterTextMeasurer();
  final doc = newDocument(measurer);
  final parametric = installParametric(doc);
  final h = doc.handleSeed.next();
  doc.commands.execute(addWall(doc, h, Vector2(-1830.5, 640.25),
      Vector2(2470.75, 1210.5), 112.5, Justification.centre));
  final page = doc.components.get<PageComponent>(doc.rootHandle)!;
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle, page.copyWith(scaleDenominator: 12.5)));
  parametric.dispose();
  final json = DraftDocumentCodec.encodeToString(doc);
  doc.dispose();
  measurer.clear();
  return (json, h);
}

Widget app(FloorPlanController c, Locale locale) => MaterialApp(
    locale: locale,
    supportedLocales: floorPlanSupportedLocales,
    localizationsDelegates: floorPlanLocalizationsDelegates,
    home: Scaffold(body: FloorPlanView(controller: c)));

String fieldText(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

WallParams wallOf(FloorPlanController c, Handle h) =>
    c.activeDocument.components.get<WallParams>(h)!;

Future<(FloorPlanController, Handle)> pumpWall(
    WidgetTester tester, Locale locale) async {
  final (json, h) = wallPlan();
  final c = FloorPlanController(json: json);
  addTearDown(c.dispose);
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(app(c, locale));
  await tester.pump();
  c.activeSelection.replace([SelectionKey.root(h)]);
  await tester.pump();
  await tester.pump();
  return (c, h);
}

Future<void> typeInto(WidgetTester tester, String key, String text) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets(
      'PW1 in Turkish the Wall section, the Page panel and the layers speak '
      'Turkish; numbers show and read with a comma (L12, L15, M-14d-f)',
      (tester) async {
    final (c, h) = await pumpWall(tester, const Locale('tr'));
    for (final w in [
      'Duvar',
      'Kalınlık',
      'Sol',
      'Orta',
      'Sağ',
      'Sayfa',
      'Ölçek',
      'Izgara',
      'Katmanlar',
      'Katman'
    ]) {
      expect(find.text(w), findsWidgets, reason: w);
    }
    expect(fieldText(tester, 'wall-thickness'), '112,5');
    expect(fieldText(tester, 'page-scale'), '12,5');
    expect(find.textContaining('1:12,5 · '), findsOneWidget, reason: 'zoom');

    await typeInto(tester, 'wall-thickness', '137,25');
    expect(wallOf(c, h).thickness, 137.25);
    expect(fieldText(tester, 'wall-thickness'), '137,25');
    final depth = c.activeDocument.commands.undoDepth;
    await typeInto(tester, 'wall-thickness', '1.600');
    expect(wallOf(c, h).thickness, 137.25, reason: 'a grouping is refused');
    expect(c.activeDocument.commands.undoDepth, depth);
    await typeInto(tester, 'wall-thickness', '150.5');
    expect(wallOf(c, h).thickness, 150.5,
        reason: 'an English keypad\'s point, once (V-12)');
  });

  testWidgets(
      'PW2 in German the Page panel reads a comma; a switch to English while '
      'mounted shows the fields again with a point (M-14d-s)', (tester) async {
    final (c, h) = await pumpWall(tester, const Locale('de'));
    expect(find.text('Dicke'), findsOneWidget);
    expect(find.text('Maßstab'), findsOneWidget);
    await typeInto(tester, 'page-scale', '20,5');
    final page = c.activeDocument.components
        .get<PageComponent>(c.activeDocument.rootHandle)!;
    expect(page.scaleDenominator, 20.5);
    expect(fieldText(tester, 'page-scale'), '20,5');

    await tester.pumpWidget(app(c, const Locale('en')));
    await tester.pump();
    expect(find.text('Thickness'), findsOneWidget);
    expect(fieldText(tester, 'wall-thickness'), '112.5');
    expect(fieldText(tester, 'page-scale'), '20.5');
    expect(wallOf(c, h).thickness, 112.5, reason: 'nothing committed');
  });
}
