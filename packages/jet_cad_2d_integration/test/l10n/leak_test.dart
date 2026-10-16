// Spec 14d M-14d-a (revision 2, V-10): the leak test. The planner is
// pumped in Turkish through a recording language; every panel, tab, dialog
// and menu is opened in turn; then every Text, tooltip, label and hint on
// screen must be a word the planner asked the strings for, a symbol's name
// in the language, document text, or on a short allowlist. A literal never
// moved into the strings is never recorded, so it fails whatever its
// language.
// Ported from jet_cad_floor_plan/test/l10n/leak_test.dart (LK2; LK1 is
// 2a's) (3a Task 27, Appendix A D-24); assertions unchanged but the
// rulings named: IP-R4 (the library table is the fixture kit's) and IP-R5
// (the kit's words come from its `KitNames`, not the plan's strings: the
// allowlist also takes the kit's Turkish words and its `text:` templates
// filled). The locale is reported through `reportLocale`, @internal
// (ruling R-P9).
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer, SelectionKey, SymbolGallery;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/canvas_rig.dart' show symbolsReady;
import '../support/recording_plan_strings.dart';
import '../support/units.dart' show diningTableTwo, fxKit, fxNames;

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

/// The architecture kit's Turkish words, and its `text:` templates as
/// patterns (each `{name}` any non-empty run): what the kit hands the plan
/// (ruling IP-R5). A template that is placeholders alone (`{value}`, the
/// dimension's notice) is left out: its pattern `^(.+)$` would take every
/// text, and its filling is a number, which the allowlist's number rules
/// take already.
///
/// And the fixture kit's Turkish words (ruling IP-R4): its table's name
/// and category, as today's allowlist took the library's names and
/// categories in the language. The English ones are not allowed: shown in
/// Turkish, they would be a leak.
final List<String> kitWords = [
  ...architectureKit.names.words['tr']!.values,
  ...fxNames.words['tr']!.values,
];
final List<RegExp> kitTemplates = [
  for (final w in architectureKit.names.words['tr']!.values)
    if (w.contains('{') &&
        w.replaceAll(RegExp(r'\{[a-z]+\}'), '').trim().isNotEmpty)
      RegExp(
          '^${RegExp.escape(w).replaceAll(RegExp(r'\\\{[a-z]+\\\}'), '(.+)')}\$'),
];

/// [seen]'s texts that are no word the planner asked [recording] for, no
/// kit word in Turkish, no layer name, nothing on the allowlist.
List<String> leaksOf(
    Set<String> seen, RecordingPlanStrings recording, PlanController c) {
  final layerNames = {
    for (final r in c.document.tables.layers.records) r.name,
  };
  bool allowed(String text) {
    if (recording.handedOut.contains(text)) return true;
    if (kitWords.contains(text) || kitTemplates.any((t) => t.hasMatch(text))) {
      return true;
    }
    if (layerNames.contains(text)) return true;
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

Widget recordingApp(RecordingPlanStrings recording, Widget home) => MaterialApp(
    locale: const Locale('tr'),
    supportedLocales: planSupportedLocales,
    localizationsDelegates: [
      _Recording(recording),
      ...planLocalizationsDelegates
          .where((d) => d != PlanLocalizations.delegate),
    ],
    home: home);

void main() {
  testWidgets(
      'LK2 in Turkish, every object of the sample plan and a library table '
      'selected in turn, its size menu open: nothing bypasses the strings '
      '(M-14d-a, review 14d-1 F-1)', (tester) async {
    final recording = RecordingPlanStrings(const PlanStringsTr());
    // Built in the reported language (spec C1.9): the rooms' stored names
    // are the kit's Turkish words.
    final c = PlanController(kits: [
      architectureKit,
      fxKit(library: [diningTableTwo])
    ]);
    addTearDown(c.dispose);
    // ignore: invalid_use_of_internal_member
    c.reportLocale(const Locale('tr'), strings: recording);
    c.newPlan(build: buildSampleFlat);
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
        recordingApp(recording, Scaffold(body: PlanEditor(controller: c))));
    await tester.pump();

    // A library table from the palette.
    await tester.tap(find.byKey(const Key('tab-symbols')));
    await tester.pump();
    expect(await symbolsReady(tester, c), isTrue,
        reason: 'premise: the libraries loaded');
    await tester.pump();
    // The gallery builds its cells lazily, and the kit's furniture comes
    // first: the fixture kit's table is scrolled into view (a fixture
    // change, ruling IP-R4).
    final cell = find.byKey(const Key('symbol-cell-fx.dining.table.two@1'));
    await tester.scrollUntilVisible(cell, 200,
        scrollable: find
            .descendant(
                of: find.byType(SymbolGallery),
                matching: find.byType(Scrollable))
            .first);
    await tester.ensureVisible(cell);
    await tester.pump();
    await tester.tap(cell);
    await tester.pump();
    final canvas = tester.getRect(find.byType(InteractionLayer));
    await tester.tapAt(canvas.center + const Offset(43, -29));
    await tester.pump();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    final seen = <String>{};
    final doc = c.document;
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
        'section-architecture.wall',
        'section-architecture.opening',
        'section-architecture.room',
        'section-architecture.dimension',
        'symbol-section',
        'unit-section',
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
    // A positive control: a literal no one asked for is a leak (the
    // allowlist does not take every text).
    expect(leaksOf({'A literal never moved'}, recording, c),
        ['A literal never moved'],
        reason: 'premise: the check can fail');
    expect(leaksOf(seen, recording, c), isEmpty,
        reason: 'shown but never asked of the strings');
  });
}
