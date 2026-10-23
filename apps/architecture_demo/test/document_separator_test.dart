// Ported from apps/floor_planner/test/document_separator_test.dart (audit
// docs/superpowers/specs/2026-10-16-architecture-demo-test-audit.md, section
// "document_separator_test.dart"): FS1-FS3, all PORT. The app's new plans
// print the decimal separator of the language of the moment: New and Open
// sample reach `controller.newPlan` after the editor reported the locale;
// the launch plan resolves the system's locales as the app's `ShadApp`
// does. Library halves: packages/jet_cad_2d_plan/test/controller/
// locale_separator_test.dart (NS1, NS6, NS8), editor/editor_separator_test.dart
// (NS1, NS2); Open sample's words: packages/jet_cad_2d_kit_architecture/
// test/sample/sample_flat_test.dart SF-words (German comma; the Turkish
// strings below are not pinned there).
import 'package:architecture_demo/document_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import 'support/app_rig.dart';

/// The app under the system [locales], at 1440 x 900.
Future<AppRig> pumpUnder(WidgetTester tester, List<Locale> locales) async {
  tester.platformDispatcher.localesTestValue = locales;
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  return pumpApp(tester);
}

/// The plan's page separator.
DecimalSeparator separatorOf(PlanController c) => c.document.components
    .get<PageComponent>(c.document.rootHandle)!
    .decimalSeparator;

/// The language under the app's `DocumentHost`.
PlanStrings hostStrings(WidgetTester tester) =>
    PlanStrings.of(tester.element(find.byType(DocumentHost)));

/// The system's locales switched while the app runs.
Future<void> switchSystemTo(WidgetTester tester, Locale locale) async {
  tester.platformDispatcher.localesTestValue = [locale];
  await tester.pump();
  await tester.pump(kLocaleTick);
}

Future<void> tapToolbar(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(Key('toolbar-$id')));
  await tester.pump();
  await tester.pump();
}

void main() {
  for (final (locales, language, expected) in [
    (const [Locale('de', 'DE')], 'de', DecimalSeparator.comma),
    // French is not spoken: the next locale, German, is the app's (V-2).
    (
      const [Locale('fr', 'FR'), Locale('de', 'DE')],
      'de',
      DecimalSeparator.comma
    ),
    (const [Locale('fr', 'FR')], 'en', DecimalSeparator.point),
  ]) {
    testWidgets(
        'FS1 the launch plan under the system locales $locales prints '
        '${expected.name}, the separator of the language the app resolves',
        (tester) async {
      final rig = await pumpUnder(tester, locales);
      final strings = hostStrings(tester);
      expect(strings.languageCode, language,
          reason: 'premise: the language the ShadApp resolved');
      final c = rig.controller;
      expect(rig.session.fileName, isNull, reason: 'premise: the launch plan');
      expect(separatorOf(c), expected);
      expect(
          separatorOf(c),
          strings.decimalSeparator == ','
              ? DecimalSeparator.comma
              : DecimalSeparator.point);
      expect(c.document.commands.undoDepth, 0);
      expect(c.dirty.value, isFalse);
    });
  }

  testWidgets(
      'FS2 New prints the separator of the language of the moment: comma '
      'after the system turns German, point after it turns English again',
      (tester) async {
    final rig = await pumpUnder(tester, const [Locale('en', 'US')]);
    final c = rig.controller;
    final launch = c.document;
    expect(separatorOf(c), DecimalSeparator.point, reason: 'premise');

    await switchSystemTo(tester, const Locale('de', 'DE'));
    expect(hostStrings(tester).languageCode, 'de', reason: 'premise');
    expect(separatorOf(c), DecimalSeparator.point,
        reason: 'the open plan is not converted (N2)');
    await tapToolbar(tester, 'new');
    final german = c.document;
    expect(identical(german, launch), isFalse, reason: 'premise: New ran');
    expect(separatorOf(c), DecimalSeparator.comma);
    expect(german.commands.undoDepth, 0);
    expect(c.dirty.value, isFalse);

    await switchSystemTo(tester, const Locale('en', 'GB'));
    expect(hostStrings(tester).languageCode, 'en', reason: 'premise');
    await tapToolbar(tester, 'new');
    expect(identical(c.document, german), isFalse, reason: 'premise: New ran');
    expect(separatorOf(c), DecimalSeparator.point);
  });

  testWidgets(
      'FS3 Open sample in Turkish prints comma: every area and every value '
      'with a comma', (tester) async {
    final rig = await pumpUnder(tester, const [Locale('en', 'US')]);
    final c = rig.controller;
    await switchSystemTo(tester, const Locale('tr', 'TR'));
    expect(hostStrings(tester).languageCode, 'tr', reason: 'premise');
    await tapToolbar(tester, 'open-sample');
    final doc = c.document;
    expect(doc.entities.liveCount, greaterThan(500), reason: 'premise');
    expect(separatorOf(c), DecimalSeparator.comma);

    final rooms = liveOf<RoomParams>(c, ArchitectureTypes.room);
    final areas = [for (final r in rooms) roomLabels(doc, r)[1]];
    // The rooms in build order: the Hall, the two bedrooms, the kitchen,
    // the bath, the living room and the dining area.
    expect(areas, [
      '22,00 m²',
      '8,45 m²',
      '8,41 m²',
      '13,97 m²',
      '13,37 m²',
      '21,90 m²',
      '23,04 m²',
    ]);
    final dims = liveOf<DimensionParams>(c, ArchitectureTypes.dimension);
    expect([for (final d in dims) dimensionText(doc, d)],
        ['14,00', '9,00', '4,69', '4,38', '3,58']);
  });
}
