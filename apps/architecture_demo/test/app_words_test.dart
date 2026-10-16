// Ported from apps/floor_planner/test/app_words_test.dart (audit
// docs/superpowers/specs/2026-10-16-architecture-demo-test-audit.md, section
// "app_words_test.dart"). AW3 is ported as it was; AW1, AW2 and AW4 read the
// whole app (its host's open-sample button and untitled name, the files
// seam), which ArchitectureDemoApp gets in Task 4: they move there. Their
// word-level content is pinned here against a minimal harness (AW-locale).
// Spec 14d L16: the app follows the system's language and English for any
// other.
import 'package:architecture_demo/app_strings.dart';
import 'package:architecture_demo/document_files.dart' show FileKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

Future<AppStrings> wordsFor(WidgetTester tester, Locale locale) async {
  late AppStrings words;
  await tester.pumpWidget(MaterialApp(
      locale: locale,
      supportedLocales: planSupportedLocales,
      localizationsDelegates: planLocalizationsDelegates,
      home: Builder(builder: (context) {
        words = AppStrings.of(context);
        return const SizedBox();
      })));
  return words;
}

void main() {
  testWidgets(
      'AW-locale the app\'s words follow the resolved locale: Turkish, '
      'German, and English for French (AW1/AW2 at the word level)',
      (tester) async {
    final tr = await wordsFor(tester, const Locale('tr', 'TR'));
    expect(tr.openSample, 'Örneği aç');
    expect(tr.untitled, 'Adsız');
    final de = await wordsFor(tester, const Locale('de', 'DE'));
    expect(de.untitled, 'Unbenannt');
    expect(de.saveAs, 'Speichern unter…');
    final fr = await wordsFor(tester, const Locale('fr'));
    expect(fr.untitled, 'Untitled');
    expect(fr.openSample, 'Open sample');
  });

  testWidgets(
      'AW3 the file types\' names in each language (spec 14d L16, review '
      '14d-1 F-5)', (tester) async {
    final names = <String, List<String>>{};
    for (final code in ['en', 'de', 'tr']) {
      await tester.pumpWidget(Localizations(
          locale: Locale(code),
          delegates: const [DefaultWidgetsLocalizations.delegate],
          child: Builder(builder: (context) {
            final words = AppStrings.of(context);
            names[code] = [
              for (final k in FileKind.values) words.fileTypeLabel(k)
            ];
            return const SizedBox();
          })));
    }
    expect(names['en'], ['Jet plan', 'PDF document', 'PNG image']);
    expect(names['de'], ['Jet-Plan', 'PDF-Dokument', 'PNG-Bild']);
    expect(names['tr'], ['Jet planı', 'PDF belgesi', 'PNG görüntüsü']);
  });

  testWidgets(
      'AW-pageflow pageFlowFailed in en, de and tr (replaces printFailed)',
      (tester) async {
    Future<String> word(String code) async {
      late String w;
      await tester.pumpWidget(Localizations(
          locale: Locale(code),
          delegates: const [DefaultWidgetsLocalizations.delegate],
          child: Builder(builder: (context) {
            w = AppStrings.of(context).pageFlowFailed;
            return const SizedBox();
          })));
      return w;
    }

    expect(await word('en'), 'The page could not be exported or printed');
    expect(await word('de'),
        'Die Seite konnte nicht exportiert oder gedruckt werden');
    expect(await word('tr'), 'Sayfa dışa aktarılamadı ya da yazdırılamadı');
  });
}
