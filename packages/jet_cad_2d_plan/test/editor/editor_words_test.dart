// Spec 14d L3-L5, R-2, M-14d-a (revision 2) through PlanEditor: the
// editor's words follow the host's locale and a change of it while
// mounted; German and Turkish never overflow the bar's 656 px floor; and
// nothing on screen bypasses the strings. Ported, assertions unchanged,
// from jet_cad_floor_plan/test/l10n/shell_words_test.dart (SW1, SW2's
// design half), overflow_test.dart (OV-<code>, OV-H-<code>), leak_test.dart
// (LK1's editor half, with RecordingPlanStrings) and panel_words_test.dart
// (PW1's zoom read-out, which Task 18 left here). The floor planner's
// words for its own tools (Wall, Door, Dimension) are the generic tools'
// (Line, Circle, Text); its wall is the editor fixture's first mark; the
// unit half of OV-H (2b Task 10) selects the unit editor fixture's tables;
// the service bar's lines are 2b Task 16's: SW2's service half (its own
// test, over the editor's service bar) and LK1's last step (the service
// bar, in Turkish).
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show SymbolsState;
import 'package:jet_cad_2d_plan/src/chrome/icon_button.dart';
import 'package:jet_cad_2d_plan/src/chrome/menu_button.dart';
import 'package:jet_cad_2d_plan/src/chrome/text_field.dart';
import 'package:jet_cad_2d_plan/src/chrome/words_carrier.dart';
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/editor/editor_layout.dart';
import 'package:jet_cad_2d_plan/src/editor/plan_editor.dart';
import 'package:jet_cad_2d_plan/src/editor/plan_editor_bar.dart';
import 'package:jet_cad_2d_plan/src/l10n/localizations.dart';
import 'package:jet_cad_2d_plan/src/l10n/strings.dart';
import 'package:jet_cad_2d_plan/src/l10n/strings_tr.dart';
import 'package:jet_cad_2d_plan/src/service/service_session.dart' show PlanMode;
import 'package:jet_cad_2d_plan/src/symbols/gallery_model.dart'
    show PlanSymbolWords;

import '../support/editor_host.dart';
import '../support/mark_kit.dart';
import '../support/recording_plan_strings.dart';
import '../support/symbol_fixtures.dart' show demoKit;
import '../support/unit_editor_fixture.dart' show tableOf, unitEditorPlanJson;
import '../support/unit_fixtures.dart' show fxKit;

Widget app(PlanController c, Locale locale) => MaterialApp(
    locale: locale,
    supportedLocales: planSupportedLocales,
    localizationsDelegates: planLocalizationsDelegates,
    home: Scaffold(body: PlanEditor(controller: c, onExport: (_) {})));

/// An empty plan with the Tools and Symbols tabs ([slowSymbolsKit]), in
/// [locale].
Future<PlanController> pump(WidgetTester tester, Locale locale) async {
  final c = PlanController(kits: [slowSymbolsKit()]);
  addTearDown(c.dispose);
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(app(c, locale));
  await tester.pump();
  return c;
}

String tooltipOf(WidgetTester tester, String key) =>
    tester.widget<IconButton>(find.byKey(Key(key))).tooltip!;

class _Recording extends LocalizationsDelegate<PlanStrings> {
  const _Recording(this.strings);
  final RecordingPlanStrings strings;
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<PlanStrings> load(Locale locale) => SynchronousFuture(strings);
  @override
  bool shouldReload(_Recording old) => !identical(old.strings, strings);
}

/// Text that is no word: numbers and their marks, units, paper names,
/// formats, shortcut letters, the em dash of an empty row.
final RegExp _numeric = RegExp(r'^[-+\d\s.,:×·%°]*$');
const Set<String> _allowed = {
  '—', 'mm', 'cm', 'm', 'in', 'ft-in', '°', //
  'A4', 'A3', 'Letter', 'Tabloid', 'PDF', 'PNG', '1:', '0', //
  '⌘', '⇧',
};
final RegExp _letter = RegExp(r'^[A-Z]$');

/// The plan's own text, a number and its unit.
final RegExp _planText = RegExp(r'^[-\d.,\s]+ ?(m²|ft²|mm|cm|m|in|ft)$');

/// Every visible string: Text data, rich text, tooltip messages.
Set<String> visibleTexts(WidgetTester tester) => {
      for (final t in tester.widgetList<Text>(find.byType(Text)))
        if (t.data != null) t.data! else t.textSpan?.toPlainText() ?? '',
      for (final t in tester.widgetList<Tooltip>(find.byType(Tooltip)))
        if (t.message != null) t.message!,
      // The chrome parts report their own words, open or closed (R-LK).
      for (final w in tester
          .widgetList(find.byWidgetPredicate((w) => w is PlanWordsCarrier)))
        ...(w as PlanWordsCarrier).visibleWords,
    }..remove('');

/// [seen]'s texts that are no word the plan library asked [recording] for,
/// no symbol or kit word in Turkish (the kits' own, with their English
/// fallback), no layer name, nothing on the allowlist.
List<String> leaksOf(
    Set<String> seen, RecordingPlanStrings recording, PlanController c) {
  const words = PlanSymbolWords('tr');
  final symbolWords = {
    for (final s in c.symbols) ...[words.name(s), words.category(s)],
  };
  final kitWords = {
    for (final k in c.kits.kits)
      for (final language in ['tr', 'en']) ...?k.names.words[language]?.values,
  };
  final layerNames = {
    for (final r in c.document.tables.layers.records) r.name,
  };
  bool allowed(String text) {
    if (recording.handedOut.contains(text)) return true;
    if (symbolWords.contains(text) || layerNames.contains(text)) return true;
    if (kitWords.contains(text)) return true;
    if (_allowed.contains(text) || _numeric.hasMatch(text)) return true;
    if (_planText.hasMatch(text)) return true;
    if (_letter.hasMatch(text)) return true;
    // A composed line: the status line's parts, a tooltip's label and its
    // chord.
    if (text.contains(' — ')) return text.split(' — ').every(allowed);
    final chord = RegExp(r'^(.+) \((.+)\)$').firstMatch(text);
    if (chord != null) {
      return allowed(chord[1]!) &&
          chord[2]!.split('+').every(
              (k) => recording.handedOut.contains(k) || _letter.hasMatch(k));
    }
    return false;
  }

  return [
    for (final t in seen)
      if (!allowed(t)) t
  ]..sort();
}

void main() {
  testWidgets(
      'SW1 in Turkish: the palette, the tabs, the status line, the toolbar '
      'and the Export dialog', (tester) async {
    await pump(tester, const Locale('tr'));
    for (final w in ['Seç', 'Çizgi', 'Daire', 'Metin', 'Dolgu', 'Araçlar']) {
      expect(find.text(w), findsWidgets, reason: w);
    }
    expect(find.text('Line'), findsNothing);
    expect(find.text('Seç'), findsNWidgets(2), reason: 'palette, status');
    expect(tooltipOf(tester, 'toolbar-undo'), startsWith('Geri al'));
    expect(tooltipOf(tester, 'toolbar-print'), 'Yazdır… (Ctrl+P)');
    await tester.tap(find.byKey(const Key('toolbar-export')));
    await tester.pumpAndSettle();
    expect(find.text('İptal'), findsOneWidget);
    expect(find.text('Dışa aktar'), findsNWidgets(2), reason: 'title, button');
  });

  testWidgets(
      'SW2 in German: Strg in a tooltip; a switch to English and back while '
      'mounted renames everything (L3, M-14d-s)', (tester) async {
    final c = await pump(tester, const Locale('de'));
    expect(find.text('Linie'), findsOneWidget);
    expect(tooltipOf(tester, 'toolbar-redo'), 'Wiederholen (Strg+Umschalt+Z)');

    await tester.pumpWidget(app(c, const Locale('en')));
    await tester.pump();
    await tester.pumpWidget(app(c, const Locale('tr')));
    await tester.pump();
    expect(find.text('Çizgi'), findsOneWidget);
    expect(tooltipOf(tester, 'toolbar-print'), 'Yazdır… (Ctrl+P)');
    await tester.pumpWidget(app(c, const Locale('de')));
    await tester.pump();
    expect(find.text('Linie'), findsOneWidget);
    expect(tooltipOf(tester, 'toolbar-print'), 'Drucken… (Strg+P)');
  });

  testWidgets(
      'SW2 in German: the service bar; a switch to English while mounted '
      'renames it (its service half; L3, M-14d-s)', (tester) async {
    final c = await pump(tester, const Locale('de'));
    c.setMode(PlanMode.service);
    await tester.pump();
    await tester.pump();
    // M-SW2s: the service bar's Undo in English whatever the locale.
    expect(tooltipOf(tester, 'service-undo'), 'Rückgängig');
    expect(tooltipOf(tester, 'service-print'), 'Drucken…');

    await tester.pumpWidget(app(c, const Locale('en')));
    await tester.pump();
    expect(tooltipOf(tester, 'service-undo'), 'Undo');
    c.setMode(PlanMode.design);
    await tester.pump();
    await tester.pump();
  });

  for (final code in ['de', 'tr']) {
    testWidgets(
        'OV-$code no overflow from 704 px down to 656 px, OSNAP off, a mark '
        'selected, both tabs (M-14d-c)', (tester) async {
      final c = PlanController(
          kits: [markKit(), slowSymbolsKit()], json: editorPlanJson());
      addTearDown(c.dispose);
      final mark = c.catalog.objectsOf<MarkCross>(c.document).first;
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
          locale: Locale(code),
          supportedLocales: planSupportedLocales,
          localizationsDelegates: planLocalizationsDelegates,
          home: Scaffold(body: PlanEditor(controller: c))));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.f3);
      await tester.pump();
      c.selection.replace([SelectionKey.root(mark)]);
      await tester.pump();
      expect(find.byKey(const Key('osnap-text')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('osnap-text'))).data,
          {'de': 'OSNAP aus', 'tr': 'OSNAP kapalı'}[code],
          reason: 'premise: OSNAP off, in the language');
      Future<void> sweep(String what) async {
        for (var width = 704; width >= 656; width -= 4) {
          await tester.binding.setSurfaceSize(Size(width.toDouble(), 700));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '$what, $width px');
        }
        await tester.binding.setSurfaceSize(const Size(1440, 900));
        await tester.pump();
      }

      await sweep('tools');
      await tester.tap(find.byKey(const Key('tab-symbols')));
      await tester.pump();
      await sweep('symbols');
    });
  }

  for (final code in ['en', 'de', 'tr']) {
    testWidgets(
        'OV-H-$code at 656 x 700, each root object of the editor\'s plan '
        'selected in turn: the right panel never overflows (review 14d-1 '
        'F-2)', (tester) async {
      final c = PlanController(kits: [markKit()], json: editorPlanJson());
      addTearDown(c.dispose);
      await tester.binding.setSurfaceSize(const Size(656, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
          locale: Locale(code),
          supportedLocales: planSupportedLocales,
          localizationsDelegates: planLocalizationsDelegates,
          // Desktop chrome at a sub-desktop test surface (POS-host D4).
          home: Scaffold(
              body: PlanEditor(
                  controller: c, layout: PlanEditorLayout.desktop))));
      await tester.pump();
      final doc = c.document;
      // The root's groups (the marks) and its entities (the line).
      final roots = [
        for (final n in doc.tree.nodes)
          if (n.parent == doc.rootHandle) n.handle,
        for (final slot in doc.entities.liveSlots)
          if (doc.entities.ownerAt(slot) == doc.rootHandle)
            doc.entities.handleAt(slot),
      ];
      expect(roots, hasLength(kEditorMarks + 1),
          reason: 'premise: the marks and the line');
      for (final h in roots) {
        c.selection.replace([SelectionKey.root(h)]);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$code, $h');
      }
    });
  }

  for (final code in ['en', 'de', 'tr']) {
    testWidgets(
        'OV-H-unit-$code at 656 x 700, the unit fixture\'s table 1, then the '
        'unlabelled one, then 7 selected in turn: the right panel never '
        'overflows (review 14d-1 F-2)', (tester) async {
      final c = PlanController(kits: [fxKit()], json: unitEditorPlanJson());
      addTearDown(c.dispose);
      await tester.binding.setSurfaceSize(const Size(656, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
          locale: Locale(code),
          supportedLocales: planSupportedLocales,
          localizationsDelegates: planLocalizationsDelegates,
          // Desktop chrome at a sub-desktop test surface (POS-host D4).
          home: Scaffold(
              body: PlanEditor(
                  controller: c, layout: PlanEditorLayout.desktop))));
      await tester.pump();
      for (final n in ['1', null, '7']) {
        c.selection.replace([SelectionKey.root(tableOf(c, n))]);
        await tester.pump();
        expect(find.byKey(const Key('unit-section')), findsOneWidget,
            reason: '$code, $n: premise');
        expect(tester.takeException(), isNull, reason: '$code, $n');
      }
    });
  }

  testWidgets(
      'LK1 in Turkish nothing on screen bypasses the strings: the editor, '
      'its panels, tabs, menus and dialogs, the service bar (M-14d-a)',
      (tester) async {
    final recording = RecordingPlanStrings(const PlanStringsTr());
    final c =
        PlanController(kits: [markKit(), demoKit()], json: editorPlanJson());
    addTearDown(c.dispose);
    final mark = c.catalog.objectsOf<MarkCross>(c.document).first;
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: planSupportedLocales,
        localizationsDelegates: [
          _Recording(recording),
          ...planLocalizationsDelegates
              .where((d) => d != PlanLocalizations.delegate),
        ],
        home: Scaffold(body: PlanEditor(controller: c, onExport: (_) {}))));
    await tester.pump();

    final seen = <String>{};
    Future<void> look() async {
      await tester.pump();
      seen.addAll(visibleTexts(tester));
    }

    await look();
    c.selection.replace([SelectionKey.root(mark)]);
    await look();
    await tester.sendKeyEvent(LogicalKeyboardKey.f3);
    await look();
    // Nothing selected: the right column shows the Layers and Page sections.
    c.selection.replace([]);
    await look();
    // The layer colour menu, then the page's preset menu.
    await tester.tap(find
        .byWidgetPredicate((w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('layer-colour-'))
        .first);
    await tester.pumpAndSettle();
    await look();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('page-preset')));
    await tester.pumpAndSettle();
    await look();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    // The Export dialog, PNG chosen.
    await tester.tap(find.byKey(const Key('toolbar-export')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('export-format-plan.png')));
    await tester.pump();
    await look();
    await tester.tap(find.byKey(const Key('export-cancel')));
    await tester.pumpAndSettle();
    // The Symbols tab, loaded, and a search with no match.
    await tester.tap(find.byKey(const Key('tab-symbols')));
    await tester.pump();
    await tester.runAsync(() async {
      while (c.symbolsState.value != SymbolsState.ready) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await look();
    await tester.enterText(find.byType(TextField).first, 'zzz');
    await look();
    // The service bar (2b Task 16). M-LK1s: its Print in English.
    c.setMode(PlanMode.service);
    await tester.pump();
    await look();

    final leaks = leaksOf(seen, recording, c);
    expect(leaks, isEmpty, reason: 'shown but never asked of the strings');
    expect(seen.length, greaterThan(60), reason: 'premise: a full screen');
    expect(recording.handedOut, contains('Çizgi'), reason: 'premise');
  });

  // LK1x: a raw English word on a chrome part is reported by the collector
  // although no Text or Tooltip shows it (the part reports its own words).
  Future<List<String>> leaksWith(WidgetTester tester, Widget part) async {
    final recording = RecordingPlanStrings(const PlanStringsTr());
    final c = PlanController(kits: [markKit()], json: editorPlanJson());
    addTearDown(c.dispose);
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: planSupportedLocales,
        localizationsDelegates: [
          _Recording(recording),
          ...planLocalizationsDelegates
              .where((d) => d != PlanLocalizations.delegate),
        ],
        home: Scaffold(
            body: PlanEditor(
                controller: c, bar: PlanEditorBar(trailing: [part])))));
    await tester.pump();
    final seen = visibleTexts(tester);
    expect(leaksOf(seen, recording, c), isNot(contains('Çizgi')),
        reason: 'premise: the editor itself is clean');
    return leaksOf(seen, recording, c);
  }

  testWidgets('LK1x tooltip: a PlanIconButton label is reported',
      (tester) async {
    final leaks = await leaksWith(tester,
        PlanIconButton(icon: Icons.add, label: 'Raw', onPressed: () {}));
    expect(leaks, contains('Raw'));
  });

  testWidgets('LK1x menu entry: a closed PlanMenuButton entry is reported',
      (tester) async {
    final leaks = await leaksWith(
        tester,
        PlanMenuButton<int>(
            icon: Icons.menu,
            label: 'Menü',
            entries: () => const [PlanMenuEntry(1, 'Raw')],
            onSelected: (_) {}));
    expect(find.text('Raw'), findsNothing, reason: 'premise: the menu is shut');
    expect(leaks, contains('Raw'));
  });

  testWidgets('LK1x field error: a PlanTextField error is reported',
      (tester) async {
    final field = TextEditingController();
    addTearDown(field.dispose);
    final leaks = await leaksWith(
        tester,
        // The bar is one line high: the field's error hangs below it.
        SizedBox(
            width: 120,
            child: OverflowBox(
                maxHeight: 200,
                child: PlanTextField(controller: field, errorText: 'Raw'))));
    expect(leaks, contains('Raw'));
  });

  testWidgets(
      'PW1 in Turkish the zoom read-out shows the page\'s fractional scale '
      'with a comma', (tester) async {
    final c = editorController();
    final doc = c.document;
    final page = doc.components.get<PageComponent>(doc.rootHandle)!;
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle, page.copyWith(scaleDenominator: 12.5)));
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: planSupportedLocales,
        localizationsDelegates: planLocalizationsDelegates,
        home: Scaffold(body: PlanEditor(controller: c))));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('1:12,5 · '), findsOneWidget, reason: 'zoom');
  });
}
