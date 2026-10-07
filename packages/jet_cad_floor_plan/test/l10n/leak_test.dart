// Spec 14d M-14d-a (revision 2, V-10): the leak test. The planner is
// pumped in Turkish through a recording language; every panel, tab, dialog
// and menu is opened in turn; then every Text, tooltip, label and hint on
// screen must be a word the planner asked the strings for, a symbol's name
// in the language, document text, or on a short allowlist. A literal never
// moved into the strings is never recorded, so it fails whatever its
// language.
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_controller.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_view.dart';
import 'package:jet_cad_floor_plan/src/l10n/localizations.dart';
import 'package:jet_cad_floor_plan/src/l10n/strings.dart';
import 'package:jet_cad_floor_plan/src/l10n/strings_tr.dart';
import 'package:jet_cad_floor_plan/src/startup_plan.dart';
import 'package:jet_cad_floor_plan/src/symbols/furniture_names.dart';

import 'panel_words_test.dart' show wallPlan;
import 'recording_strings.dart';

class _Recording extends LocalizationsDelegate<FloorPlanStrings> {
  const _Recording(this.strings);
  final RecordingFloorPlanStrings strings;
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<FloorPlanStrings> load(Locale locale) => SynchronousFuture(strings);
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

/// The plan's own text, a number and its unit (a room's area, a
/// dimension's value): stored, with the page's decimal separator, which a
/// new plan takes from the UI's language (spec Q0 N1). LK2's sample is
/// built in Turkish, so it prints `,`.
final RegExp _planText = RegExp(r'^[-\d.,\s]+ ?(m²|ft²|mm|cm|m|in|ft)$');

/// Every visible string: Text data, rich text, tooltip messages.
Set<String> visibleTexts(WidgetTester tester) => {
      for (final t in tester.widgetList<Text>(find.byType(Text)))
        if (t.data != null) t.data! else t.textSpan?.toPlainText() ?? '',
      for (final t in tester.widgetList<Tooltip>(find.byType(Tooltip)))
        if (t.message != null) t.message!,
    }..remove('');

/// [seen]'s texts that are no word the planner asked [recording] for, no
/// symbol name in Turkish, no layer name, nothing on the allowlist.
List<String> leaksOf(Set<String> seen, RecordingFloorPlanStrings recording,
    FloorPlanController c) {
  final symbolWords = {
    ...furnitureSymbolNames.names['tr']!.values,
    ...furnitureSymbolNames.categories['tr']!.values,
  };
  final layerNames = {
    for (final r in c.activeDocument.tables.layers.records) r.name,
  };
  bool allowed(String text) {
    if (recording.handedOut.contains(text)) return true;
    if (symbolWords.contains(text) || layerNames.contains(text)) return true;
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

Widget recordingApp(RecordingFloorPlanStrings recording, Widget home) =>
    MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: floorPlanSupportedLocales,
        localizationsDelegates: [
          _Recording(recording),
          ...floorPlanLocalizationsDelegates
              .where((d) => d != FloorPlanLocalizations.delegate),
        ],
        home: home);

void main() {
  testWidgets(
      'LK1 in Turkish nothing on screen bypasses the strings: the editor, '
      'its panels, tabs, menus and dialogs, the service bar (M-14d-a)',
      (tester) async {
    final recording = RecordingFloorPlanStrings(const FloorPlanStringsTr());
    final (json, wall) = wallPlan();
    final c = FloorPlanController(json: json);
    addTearDown(c.dispose);
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: floorPlanSupportedLocales,
        localizationsDelegates: [
          _Recording(recording),
          ...floorPlanLocalizationsDelegates
              .where((d) => d != FloorPlanLocalizations.delegate),
        ],
        home: Scaffold(body: FloorPlanView(controller: c, onExport: (_) {}))));
    await tester.pump();

    final seen = <String>{};
    Future<void> look() async {
      await tester.pump();
      seen.addAll(visibleTexts(tester));
    }

    await look();
    c.activeSelection.replace([SelectionKey.root(wall)]);
    await look();
    await tester.sendKeyEvent(LogicalKeyboardKey.f3);
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
    await tester.tap(find.byKey(const Key('export-format-png')));
    await tester.pump();
    await look();
    await tester.tap(find.byKey(const Key('export-cancel')));
    await tester.pumpAndSettle();
    // The Symbols tab, loaded, and a search with no match.
    await tester.tap(find.byKey(const Key('tab-symbols')));
    await tester.pump();
    await tester.runAsync(() async {
      while (!c.symbols.state.toString().contains('Ready')) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await look();
    await tester.enterText(find.byType(TextField).first, 'zzz');
    await look();
    // The service bar.
    c.setMode(FloorPlanMode.selection);
    await tester.pump();
    await look();

    final leaks = leaksOf(seen, recording, c);
    expect(leaks, isEmpty, reason: 'shown but never asked of the strings');
    expect(seen.length, greaterThan(60), reason: 'premise: a full screen');
    expect(recording.handedOut, contains('Duvar'), reason: 'premise');
  });

  testWidgets(
      'LK2 in Turkish, every object of the sample plan and a library table '
      'selected in turn, its size menu open: nothing bypasses the strings '
      '(M-14d-a, review 14d-1 F-1)', (tester) async {
    final recording = RecordingFloorPlanStrings(const FloorPlanStringsTr());
    final measurer = FlutterTextMeasurer();
    // Built in the recording language: the rooms' and layers' stored
    // names are words the planner asked for.
    final sample = startupPlan(measurer, strings: recording);
    final json = DraftDocumentCodec.encodeToString(sample);
    sample.dispose();
    measurer.clear();
    final c = FloorPlanController(json: json);
    addTearDown(c.dispose);
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
        recordingApp(recording, Scaffold(body: FloorPlanView(controller: c))));
    await tester.pump();

    // A library table from the palette.
    await tester.tap(find.byKey(const Key('tab-symbols')));
    await tester.pump();
    await tester.runAsync(() async {
      while (!c.symbols.state.toString().contains('Ready')) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pump();
    await tester
        .tap(find.byKey(const Key('symbol-cell-dining.table.square.two@2')));
    await tester.pump();
    final canvas = tester.getRect(find.byType(InteractionLayer));
    await tester.tapAt(canvas.center + const Offset(43, -29));
    await tester.pump();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    final seen = <String>{};
    final doc = c.activeDocument;
    final roots = [
      for (final n in doc.tree.nodes)
        if (n.parent == doc.rootHandle) n.handle
    ];
    final kinds = <String>{};
    for (final h in roots) {
      c.activeSelection.replace([SelectionKey.root(h)]);
      await tester.pump();
      await tester.pump();
      seen.addAll(visibleTexts(tester));
      for (final k in const [
        'wall-section',
        'opening-section',
        'room-section',
        'dimension-section',
        'symbol-section',
        'table-section',
      ]) {
        if (find.byKey(Key(k)).evaluate().isNotEmpty) kinds.add(k);
      }
      if (find.byKey(const Key('symbol-size-menu')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('symbol-size-menu')));
        await tester.pumpAndSettle();
        seen.addAll(visibleTexts(tester));
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
      }
    }
    expect(kinds, hasLength(6), reason: 'premise: every section shown');
    expect(leaksOf(seen, recording, c), isEmpty,
        reason: 'shown but never asked of the strings');
  });
}
