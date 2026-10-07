// Spec Q0 N1 (M-Q0-e, V-2, V-17): the app's new plans print the decimal
// separator of the language of the moment -- New and Open sample read the
// host's `FloorPlanStrings`; the launch document, made above the
// `MaterialApp`, resolves the system's locales as that `MaterialApp` does.
import 'package:floor_planner/document_host.dart';
import 'package:floor_planner/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_floor_plan/editor.dart';
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart'
    show FloorPlanStrings;

import 'support/dimension_fixture.dart' show dimText;
import 'support/document_rig.dart' show sessionOf;
import 'support/fake_document_files.dart';
import 'support/room_fixture.dart' show labelsOf, textOf;

/// The app under the system [locales], at 1440 x 900: its state, so its
/// launch document, is made after the locales are set.
Future<void> pumpUnder(WidgetTester tester, List<Locale> locales) async {
  tester.platformDispatcher.localesTestValue = locales;
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(FloorPlannerApp(files: FakeDocumentFiles()));
  await tester.pump();
}

/// [doc]'s page separator.
DecimalSeparator separatorOf(DraftDocument doc) =>
    doc.components.get<PageComponent>(doc.rootHandle)!.decimalSeparator;

/// The language under the app's `DocumentHost`.
FloorPlanStrings hostStrings(WidgetTester tester) =>
    FloorPlanStrings.of(tester.element(find.byType(DocumentHost)));

/// The system's locales switched while the app runs.
Future<void> switchSystemTo(WidgetTester tester, Locale locale) async {
  tester.platformDispatcher.localesTestValue = [locale];
  await tester.pump();
  await tester.pump();
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
      await pumpUnder(tester, locales);
      final strings = hostStrings(tester);
      expect(strings.languageCode, language,
          reason: 'premise: the language the MaterialApp resolved');
      final session = sessionOf(tester);
      expect(session.fileName, isNull, reason: 'premise: the launch plan');
      expect(separatorOf(session.document), expected);
      expect(separatorOf(session.document), documentSeparatorFor(strings));
      expect(session.document.commands.undoDepth, 0);
      expect(session.dirty.value, isFalse);
    });
  }

  testWidgets(
      'FS2 New prints the separator of the language of the moment: comma '
      'after the system turns German, point after it turns English again',
      (tester) async {
    await pumpUnder(tester, const [Locale('en', 'US')]);
    final session = sessionOf(tester);
    final launch = session.document;
    expect(separatorOf(launch), DecimalSeparator.point, reason: 'premise');

    await switchSystemTo(tester, const Locale('de', 'DE'));
    expect(hostStrings(tester).languageCode, 'de', reason: 'premise');
    expect(separatorOf(launch), DecimalSeparator.point,
        reason: 'the open plan is not converted (N2)');
    await tapToolbar(tester, 'new');
    final german = session.document;
    expect(identical(german, launch), isFalse, reason: 'premise: New ran');
    expect(separatorOf(german), DecimalSeparator.comma);
    expect(german.commands.undoDepth, 0);
    expect(session.dirty.value, isFalse);

    await switchSystemTo(tester, const Locale('en', 'GB'));
    expect(hostStrings(tester).languageCode, 'en', reason: 'premise');
    await tapToolbar(tester, 'new');
    expect(identical(session.document, german), isFalse,
        reason: 'premise: New ran');
    expect(separatorOf(session.document), DecimalSeparator.point);
  });

  testWidgets(
      'FS3 Open sample in Turkish prints comma: every area and every value '
      'with a comma', (tester) async {
    await pumpUnder(tester, const [Locale('en', 'US')]);
    await switchSystemTo(tester, const Locale('tr', 'TR'));
    expect(hostStrings(tester).languageCode, 'tr', reason: 'premise');
    await tapToolbar(tester, 'open-sample');
    final doc = sessionOf(tester).document;
    expect(doc.entities.liveCount, greaterThan(500), reason: 'premise');
    expect(separatorOf(doc), DecimalSeparator.comma);

    final rooms = doc.components.withComponent<RoomParams>().toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final areas = [for (final r in rooms) textOf(doc, labelsOf(doc, r)[1])];
    // The rooms in build order: the Hall, the two bedrooms, the kitchen,
    // the bath, the living room and the dining area (spec 10 D23).
    expect(areas, [
      '22,00 m²',
      '8,45 m²',
      '8,41 m²',
      '13,97 m²',
      '13,37 m²',
      '21,90 m²',
      '23,04 m²',
    ]);
    final dims = doc.components.withComponent<DimensionParams>().toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    expect([for (final d in dims) dimText(doc, d)],
        ['14,00', '9,00', '4,69', '4,38', '3,58']);
  });
}
