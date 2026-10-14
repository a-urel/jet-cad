// Spec 14d L2, L11, L12, L15 (revision 2): the language lookup in each of
// V-4's host set-ups, the panels' numbers, and the search's fold.
// Ported from jet_cad_floor_plan (2a Task 9).
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/l10n/number_text.dart';
import 'package:jet_cad_2d_plan/src/l10n/search_fold.dart';

/// The words a widget under [app] sees.
Future<PlanStrings> wordsUnder(
    WidgetTester tester, Widget Function(Widget probe) app) async {
  late PlanStrings seen;
  await tester.pumpWidget(app(Builder(builder: (context) {
    seen = PlanStrings.of(context);
    return const SizedBox();
  })));
  return seen;
}

class _Custom extends PlanStringsTr {
  const _Custom();
}

class _CustomDelegate extends LocalizationsDelegate<PlanStrings> {
  const _CustomDelegate();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<PlanStrings> load(Locale locale) => SynchronousFuture(const _Custom());
  @override
  bool shouldReload(_CustomDelegate old) => false;
}

void main() {
  testWidgets(
      'LB1 a host listing the locales and the delegates gets German and '
      'Turkish; an unlisted language resolves to English (M-14d-b)',
      (tester) async {
    for (final (locale, type) in [
      (const Locale('de'), PlanStringsDe),
      (const Locale('tr', 'TR'), PlanStringsTr),
      (const Locale('en', 'GB'), PlanStringsEn),
      (const Locale('fr'), PlanStringsEn),
    ]) {
      final words = await wordsUnder(
          tester,
          (probe) => MaterialApp(
              locale: locale,
              supportedLocales: planSupportedLocales,
              localizationsDelegates: planLocalizationsDelegates,
              home: probe));
      expect(words.runtimeType, type, reason: '$locale');
    }
  });

  testWidgets(
      'LB2 without the planner\'s delegate the resolved locale still '
      'chooses (M-14d-b)', (tester) async {
    for (final (locale, type) in [
      (const Locale('de'), PlanStringsDe),
      (const Locale('tr'), PlanStringsTr),
    ]) {
      final words = await wordsUnder(
          tester,
          (probe) => MaterialApp(
              locale: locale,
              supportedLocales: planSupportedLocales,
              localizationsDelegates: planLocalizationsDelegates
                  .where((d) => d != PlanLocalizations.delegate),
              home: probe));
      expect(words.runtimeType, type, reason: '$locale');
    }
  });

  testWidgets(
      'LB3 a default MaterialApp on a Turkish device resolves to en_US, so '
      'English (documented, V-4); no Localizations at all is English too',
      (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('tr', 'TR')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final words = await wordsUnder(tester, (probe) => MaterialApp(home: probe));
    expect(words, isA<PlanStringsEn>());
    final bare = await wordsUnder(
        tester,
        (probe) =>
            Directionality(textDirection: TextDirection.ltr, child: probe));
    expect(bare, isA<PlanStringsEn>());
  });

  testWidgets('LB4 a host\'s own delegate wins', (tester) async {
    final words = await wordsUnder(
        tester,
        (probe) => MaterialApp(
            locale: const Locale('tr'),
            supportedLocales: planSupportedLocales,
            localizationsDelegates: [
              const _CustomDelegate(),
              ...planLocalizationsDelegates
                  .where((d) => d != PlanLocalizations.delegate),
            ],
            home: probe));
    expect(words, isA<_Custom>());
  });

  test('LB5 the built-in languages by code', () {
    expect(PlanStrings.forLocale(const Locale('de')).languageCode, 'de');
    expect(PlanStrings.forLocale(const Locale('tr')).languageCode, 'tr');
    expect(PlanStrings.forLocale(null).languageCode, 'en');
    expect(const PlanStringsEn().decimalSeparator, '.');
    expect(const PlanStringsDe().decimalSeparator, ',');
    expect(const PlanStringsTr().decimalSeparator, ',');
    // The Page panel's caption (spec Q0 P1; the final review's F-8).
    expect(const PlanStringsEn().pageDecimalSeparator, 'Decimal separator');
    expect(const PlanStringsDe().pageDecimalSeparator, 'Dezimaltrennzeichen');
    expect(const PlanStringsTr().pageDecimalSeparator, 'Ondalık ayırıcı');
  });

  group('NT the panels\' numbers (L12, L15 as amended, M-14d-f)', () {
    const en = PlanStringsEn(), de = PlanStringsDe();
    const tr = PlanStringsTr();

    test('shown with the language\'s separator, never grouped', () {
      expect(formatPanelNumber(1.5, en), '1.5');
      expect(formatPanelNumber(1.5, de), '1,5');
      expect(formatPanelNumber(-2400.125, tr), '-2400,125');
      expect(formatPanelNumber(1600, de), '1600');
      expect(formatPanelNumber(-0.0, tr), '-0,0');
    });

    test('a shown value reads back exactly', () {
      for (final v in [1.5, -2400.125, 1600.0, 0.1, -0.0, 1e20, 1e300]) {
        for (final s in [en, de, tr]) {
          final back = parsePanelNumber(formatPanelNumber(v, s), s)!;
          expect(back, v, reason: '$v in ${s.languageCode}');
          expect(back.isNegative, v.isNegative);
        }
      }
    });

    test('the language\'s separator; the other once, unless a grouping', () {
      final cases = <(String, PlanStrings, double?)>[
        ('1,5', de, 1.5),
        (' 1,5 ', tr, 1.5),
        ('1.5', de, 1.5), // an English keypad on a German UI (V-12)
        ('1.600', de, null),
        ('1.234,5', de, null),
        ('1,2,3', tr, null),
        ('1.5', en, 1.5),
        ('1,5', en, 1.5),
        ('1,600', en, null),
        ('1,234.5', en, null),
        ('-0,25', tr, -0.25),
        ('1e3', de, 1000),
        ('abc', tr, null),
      ];
      for (final (text, s, want) in cases) {
        expect(parsePanelNumber(text, s), want,
            reason: '"$text" in ${s.languageCode}');
      }
    });
  });

  test('SF the fold meets either language\'s letters (L11, M-14d-j)', () {
    expect(searchFold('Köşe kabin'), 'kose kabin');
    expect(searchFold('ISIK'), searchFold('ışık'));
    expect(searchFold('İSTANBUL'), 'istanbul');
    // The web lower-cases `İ` to `i` and a combining dot (the full Unicode
    // mapping); the VM to `i` alone. Both fold alike.
    expect(searchFold('i\u0307stanbul'), 'istanbul');
    expect(searchFold('Kâğıt'), 'kagit');
    expect(searchFold('Straße'), 'strasse');
    expect(searchFold('Çay ocağı'), 'cay ocagi');
    expect(searchFold('Höhe ÜBER'), 'hohe uber');
    expect(searchFold('booth'), 'booth');
  });
}
