// Spec 14d L12, L15 (revision 2): the panels speak the host's language and
// show and read their numbers with its separator; a change of language
// while mounted shows the fields again in it (M-14d-s). A wall off the
// origin with a fractional thickness; a page at a fractional scale.
// Ported from jet_cad_floor_plan/test/l10n/panel_words_test.dart (3a Task
// 27, Appendix A D-24); assertions unchanged but the rulings named: IP-R1
// (`wall-thickness` is the field `thickness`) and IP-R6 (the
// justification is a dropdown showing the chosen word: its menu is opened
// to show the other two, and closed by choosing `Orta` again, no step).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/chrome/text_field.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/canvas_rig.dart' show byKey, field;
import '../support/plans.dart' show addWall, planWith;

/// A plan with one wall, 112.5 thick, and its page at 1:12.5.
(String, Handle) wallPlan() {
  late Handle h;
  final json = planWith((doc) {
    h = doc.handleSeed.next();
    doc.commands.execute(addWall(doc, h, Vector2(-1830.5, 640.25),
        Vector2(2470.75, 1210.5), 112.5, Justification.centre));
    final page = doc.components.get<PageComponent>(doc.rootHandle)!;
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle, page.copyWith(scaleDenominator: 12.5)));
  });
  return (json, h);
}

/// The editor over [c] in [locale]: the integration package's app.
Widget app(PlanController c, Locale locale) => planEditorApp(c, locale: locale);

String fieldText(WidgetTester tester, Finder f) {
  final field = tester.widget(f);
  // The wall's fields are PlanTextFields, the page panel's scale a TextField.
  return field is PlanTextField
      ? field.controller.text
      : (field as TextField).controller!.text;
}

WallParams wallOf(PlanController c, Handle h) =>
    c.document.components.get<WallParams>(h)!;

Future<(PlanController, Handle)> pumpWall(
    WidgetTester tester, Locale locale) async {
  final (json, h) = wallPlan();
  final c = architectureController(json: json);
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

Future<void> typeInto(WidgetTester tester, Finder f, String text) async {
  await tester.tap(f);
  await tester.pump();
  await tester.enterText(f, text);
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
    // Ruling IP-R6: the menu shows the three justification words.
    await tester.tap(field('justification'));
    await tester.pumpAndSettle();
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
    await tester.tap(find.text('Orta').last);
    await tester.pumpAndSettle();
    expect(fieldText(tester, field('thickness')), '112,5');
    expect(fieldText(tester, byKey('page-scale')), '12,5');
    expect(find.textContaining('1:12,5 · '), findsOneWidget, reason: 'zoom');

    await typeInto(tester, field('thickness'), '137,25');
    expect(wallOf(c, h).thickness, 137.25);
    expect(fieldText(tester, field('thickness')), '137,25');
    final depth = c.document.commands.undoDepth;
    await typeInto(tester, field('thickness'), '1.600');
    expect(wallOf(c, h).thickness, 137.25, reason: 'a grouping is refused');
    expect(c.document.commands.undoDepth, depth);
    await typeInto(tester, field('thickness'), '150.5');
    expect(wallOf(c, h).thickness, 150.5,
        reason: 'an English keypad\'s point, once (V-12)');
  });

  testWidgets(
      'PW2 in German the Page panel reads a comma; a switch to English while '
      'mounted shows the fields again with a point (M-14d-s)', (tester) async {
    final (c, h) = await pumpWall(tester, const Locale('de'));
    expect(find.text('Dicke'), findsOneWidget);
    expect(find.text('Maßstab'), findsOneWidget);
    await typeInto(tester, byKey('page-scale'), '20,5');
    final page =
        c.document.components.get<PageComponent>(c.document.rootHandle)!;
    expect(page.scaleDenominator, 20.5);
    expect(fieldText(tester, byKey('page-scale')), '20,5');

    await tester.pumpWidget(app(c, const Locale('en')));
    await tester.pump();
    expect(find.text('Thickness'), findsOneWidget);
    expect(fieldText(tester, field('thickness')), '112.5');
    expect(fieldText(tester, byKey('page-scale')), '20.5');
    expect(wallOf(c, h).thickness, 112.5, reason: 'nothing committed');
  });
}
