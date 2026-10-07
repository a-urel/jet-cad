// Spec 14d L16: the app follows the system's language -- its own file
// commands, the untitled name, the sample's rooms -- and English for any
// other.
import 'package:floor_planner/app_strings.dart';
import 'package:floor_planner/document_files.dart' show FileKind, FileTypeLabel;
import 'package:floor_planner/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_document_files.dart';

String tooltipOf(WidgetTester tester, String key) =>
    tester.widget<IconButton>(find.byKey(Key(key))).tooltip!;

Future<void> pumpIn(WidgetTester tester, Locale locale) async {
  tester.platformDispatcher.localesTestValue = [locale];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(FloorPlannerApp(files: FakeDocumentFiles()));
  await tester.pump();
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
      'AW4 the app hands its files the type names of the system\'s '
      'language, read at each call (review F-4)', (tester) async {
    tester.platformDispatcher.localesTestValue = [const Locale('de', 'DE')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    FileTypeLabel? handed;
    await tester.pumpWidget(
        FloorPlannerApp(createFiles: ({required askName, required typeLabel}) {
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
