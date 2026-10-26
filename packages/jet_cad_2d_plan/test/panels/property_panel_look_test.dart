// The property panel's look with the real fonts (fix/property-panel-look):
// the Rotate buttons' words fit the docked column and a phone's drawer in
// every language, a section's title stands apart from its fields' labels,
// and consecutive fields have room between them. Fixture: a unit turned
// 30 degrees far off the origin, and a planter symbol.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'package:jet_cad_2d_plan/src/chrome/text_field.dart'
    show PlanReadOnlyField;

import '../support/harness.dart' show planText;
import '../support/object_kit.dart';
import '../support/unit_embedding_fixture.dart';
import '../support/unit_fixtures.dart';

late Handle unit, planter;

String plan() => planText([fxKit(), objectKit], (d) {
      unit = placeUnit(d, embeddingTable,
          transform: embeddingPlacement(40000, -27000, 30));
      addUnitLabel(d, unit, '1');
      planter = placeTurned(d, planterSymbol, Vector2(52000, -20000)).handle;
      d.commands.clearHistory();
    });

/// The test bundle's fonts, shadcn's Geist among them: flutter_test draws
/// Ahem otherwise, whose square glyphs measure nothing a person sees.
Future<void> loadFonts() async {
  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json'))
      as List<dynamic>;
  for (final family in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(family['family'] as String);
    for (final font in (family['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(Uri.decodeFull(font['asset'] as String)));
    }
    await loader.load();
  }
}

Future<PlanController> mount(WidgetTester tester,
    {required Locale locale,
    required Size size,
    required Handle Function() select}) async {
  final c = PlanController(kits: [fxKit(), objectKit], json: plan());
  addTearDown(c.dispose);
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
      locale: locale,
      supportedLocales: planSupportedLocales,
      localizationsDelegates: planLocalizationsDelegates,
      // A host's Material theme with its own font, as the README pictures
      // are taken: the chrome takes the family from it.
      theme: ThemeData(fontFamily: 'Roboto'),
      home: Scaffold(body: PlanEditor(controller: c))));
  await tester.pump();
  c.selection.replace([SelectionKey.root(select())]);
  await tester.pump();
  if (size.width < 600) {
    await tester.tap(find.byKey(const Key('chrome-right-button')));
    await tester.pumpAndSettle();
  }
  return c;
}

/// Whether [key]'s words show whole: its paragraph is as wide as they are.
bool whole(WidgetTester tester, String key) {
  // The button's words, not its icon's glyph.
  final paragraph = tester
      .renderObjectList<RenderParagraph>(find.descendant(
          of: find.byKey(Key(key)), matching: find.byType(RichText)))
      .singleWhere((p) => p.text.toPlainText().length > 1);
  return !paragraph.didExceedMaxLines &&
      paragraph.size.width >=
          paragraph.getMaxIntrinsicWidth(double.infinity) - 0.5;
}

void main() {
  setUpAll(() async {
    await loadFonts();
    await ensurePlanFonts();
  });

  for (final (name, size) in [
    ('docked', const Size(1280, 800)),
    ('phone', const Size(390, 844)),
  ]) {
    for (final locale in planSupportedLocales) {
      testWidgets(
          'PL1 $name, ${locale.languageCode}: both Rotate buttons show their '
          'words whole', (tester) async {
        await mount(tester, locale: locale, size: size, select: () => unit);
        for (final key in ['unit-rotate-left', 'unit-rotate-right']) {
          expect(find.byKey(Key(key)), findsOneWidget, reason: key);
          expect(whole(tester, key), isTrue, reason: key);
        }
      });
    }
  }

  testWidgets(
      'PL2 a section\'s title is larger and bolder than a field\'s label',
      (tester) async {
    await mount(tester,
        locale: const Locale('en'),
        size: const Size(1280, 800),
        select: () => planter);
    final title = tester
        .renderObject<RenderParagraph>(find.byKey(const Key('symbol-section')));
    final label = tester.renderObject<RenderParagraph>(find
        .descendant(
            of: find.byType(PlanReadOnlyField).first,
            matching: find.byType(RichText))
        .first);
    final t = title.text.style!, l = label.text.style!;
    expect(t.fontSize!, greaterThan(l.fontSize!));
    expect(t.fontWeight!.value, greaterThanOrEqualTo(FontWeight.w600.value));
    expect(t.fontWeight!.value, greaterThan(l.fontWeight!.value));
  });

  testWidgets(
      'PL3 a section\'s rows have room between them: the title and the '
      'Name, Name and Size, the two Rotate buttons', (tester) async {
    await mount(tester,
        locale: const Locale('en'),
        size: const Size(1280, 800),
        select: () => planter);
    final fields = find.byType(PlanReadOnlyField);
    final title = tester.getRect(find.byKey(const Key('symbol-section')));
    final name = tester.getRect(fields.at(0));
    final size = tester.getRect(fields.at(1));
    expect(name.top - title.bottom, greaterThanOrEqualTo(8));
    expect(size.top - name.bottom, greaterThanOrEqualTo(8));

    await mount(tester,
        locale: const Locale('en'),
        size: const Size(1280, 800),
        select: () => unit);
    final left = tester.getRect(find.byKey(const Key('unit-rotate-left')));
    final right = tester.getRect(find.byKey(const Key('unit-rotate-right')));
    expect(right.top - left.bottom, greaterThanOrEqualTo(8));
  });
}
