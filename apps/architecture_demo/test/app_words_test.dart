// Ported from apps/floor_planner/test/app_words_test.dart (audit
// docs/superpowers/specs/2026-10-16-architecture-demo-test-audit.md, section
// "app_words_test.dart"). AW1-AW4 are PORT. AW1, AW2 and AW4 pump the whole
// app (Task 4 gave it the host and the files seam); AW-locale is Task 3's
// word-level stand-in for AW1/AW2, kept as the cheap pin of AppStrings.of.
// Spec 14d L16: the app follows the system's language and English for any
// other.
import 'package:architecture_demo/app_strings.dart';
import 'package:architecture_demo/document_files.dart'
    show DocumentNamePrompt, FileKind, FileTypeLabel;
import 'package:architecture_demo/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/src/chrome/icon_button.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import 'support/app_fakes.dart';
import 'support/app_rig.dart';

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

String tooltipOf(WidgetTester tester, String key) {
  final w = tester.widget(find.byKey(Key(key)));
  // The app's own Open sample button is a Material one (a host slot).
  if (w is IconButton) return w.tooltip!;
  return (w as PlanIconButton).tooltip ?? w.label;
}

/// The whole app under the system [locale].
Future<void> pumpIn(WidgetTester tester, Locale locale) async {
  tester.platformDispatcher.localesTestValue = [locale];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  await pumpApp(tester);
}

void main() {
  testWidgets('AW1 a Turkish system: the app and the planner speak Turkish',
      (tester) async {
    await pumpIn(tester, const Locale('tr', 'TR'));
    expect(tooltipOf(tester, 'toolbar-new'), 'Yeni (Ctrl+N)');
    expect(tooltipOf(tester, 'toolbar-open-sample'), 'Örneği aç');
    expect(tooltipOf(tester, 'toolbar-print'), 'Yazdır… (Ctrl+P)');
    expect(find.text('Adsız'), findsOneWidget, reason: 'the untitled name');
    expect(find.text('Duvar'), findsOneWidget);
  });

  testWidgets('AW2 a German system; a French one is English', (tester) async {
    await pumpIn(tester, const Locale('de', 'DE'));
    expect(tooltipOf(tester, 'toolbar-save-as'),
        'Speichern unter… (Strg+Umschalt+S)');
    expect(find.text('Unbenannt'), findsOneWidget);
    await pumpIn(tester, const Locale('fr'));
    expect(tooltipOf(tester, 'toolbar-new'), 'New (Ctrl+N)');
    expect(find.text('Untitled'), findsOneWidget);
  });

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

  testWidgets(
      'AW4 the app hands its files the type names of the system\'s '
      'language, read at each call (review F-4)', (tester) async {
    tester.platformDispatcher.localesTestValue = [const Locale('de', 'DE')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    FileTypeLabel? handed;
    await tester.pumpWidget(ArchitectureDemoApp(createFiles: (
        {required DocumentNamePrompt askName,
        required FileTypeLabel typeLabel}) {
      handed = typeLabel;
      return FakeDocumentFiles();
    }));
    await tester.pump();
    expect(handed, isNotNull, reason: 'premise: the app made its files');
    expect(handed!(FileKind.pdf), 'PDF-Dokument');
    expect(handed!(FileKind.jetplan), 'Jet-Plan');
    tester.platformDispatcher.localesTestValue = [const Locale('tr', 'TR')];
    await tester.pump();
    expect(handed!(FileKind.png), 'PNG görüntüsü',
        reason: 'read at each call: the language of the moment');
  });
}
