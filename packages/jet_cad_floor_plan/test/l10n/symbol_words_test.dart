// Spec 14d L8-L11 (revision 2): symbols are shown by key in the host's
// language, falling back to the library's or the copy's English; search
// meets either language through the fold; a category keeps its collapsed
// state across a change of language.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_controller.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_view.dart';
import 'package:jet_cad_floor_plan/src/l10n/localizations.dart';
import 'package:jet_cad_floor_plan/src/parametric/catalog.dart';
import 'package:jet_cad_floor_plan/src/selection_panel.dart';
import 'package:jet_cad_floor_plan/src/symbols/build_library.dart';
import 'package:jet_cad_floor_plan/src/symbols/furniture_names.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_library.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_library_loader.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_names.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_search.dart';
import 'package:jet_cad_floor_plan/symbols.dart'
    show FurnitureSymbol, PolylineShape;
import 'package:vector_math/vector_math_64.dart' show Vector2;

FurnitureSymbol rect(String key, String name, String category,
        {List<String> tags = const []}) =>
    FurnitureSymbol(
      key: key,
      name: name,
      category: category,
      tags: tags,
      baseX: 450,
      baseY: 300,
      shapes: const [
        PolylineShape([(0, 0), (900, 0), (900, 600), (0, 600)], closed: true),
      ],
    );

final List<FurnitureSymbol> catalog = [
  rect('t.booth.corner', 'Corner booth', 'Booths', tags: ['booth']),
  rect('t.heater', 'Patio heater', 'Outdoor'),
  rect('t.unnamed', 'Plain crate', 'Outdoor'),
];

const SymbolNames names = SymbolNames(names: {
  'tr': {'t.booth.corner': 'Köşe loca', 't.heater': 'Dış mekân ısıtıcısı'},
  'de': {'t.booth.corner': 'Ecksitznische', 't.heater': 'Heizstrahler'},
}, categories: {
  'tr': {'Booths': 'Localar', 'Outdoor': 'Dış mekân'},
});

Uint8List libraryBytes() => Uint8List.fromList(utf8
    .encode(DraftDocumentCodec.encodeToString(buildSymbolLibrary(catalog))));

final SymbolLibrary library = SymbolLibrary.decode(libraryBytes());

List<String> keysFound(String query, SymbolWords words) => [
      for (final g in searchSymbols(library.entries, query, words))
        for (final e in g.symbols) e.key
    ];

void main() {
  test('SN1 search meets either language through the fold (L11, M-14d-j)', () {
    const tr = SymbolWords(names, 'tr');
    expect(keysFound('kose', tr), ['t.booth.corner']);
    expect(keysFound('KÖŞE LOCA', tr), ['t.booth.corner']);
    expect(keysFound('booth', tr), ['t.booth.corner'], reason: 'a tag');
    expect(keysFound('corner', tr), ['t.booth.corner'],
        reason: 'the English name, in no tag');
    expect(keysFound('ISITICI', tr), ['t.heater']);
    expect(keysFound('dis mekan', tr), ['t.heater', 't.unnamed'],
        reason: 'the category in Turkish');
    expect(keysFound('heizstrahler', tr), isEmpty,
        reason: 'German is not the shown language');
    const de = SymbolWords(names, 'de');
    expect(keysFound('heizstrahler', de), ['t.heater']);
    final groups = searchSymbols(library.entries, '', tr);
    expect([for (final g in groups) g.category], ['Booths', 'Outdoor'],
        reason: 'groups keep the English category as their key');
  });

  test('SN2 the words fall back to the library\'s English (L9)', () {
    const tr = SymbolWords(names, 'tr');
    final crate = library.entries.singleWhere((e) => e.key == 't.unnamed');
    expect(tr.name(crate), 'Plain crate');
    expect(tr.nameOfKey('t.unnamed'), isNull);
    expect(tr.category('Unknown'), 'Unknown');
    final merged = names.merge(const SymbolNames(names: {
      'tr': {'t.heater': 'Isıtıcı'},
    }));
    expect(SymbolWords(merged, 'tr').nameOfKey('t.heater'), 'Isıtıcı');
    expect(SymbolWords(merged, 'tr').nameOfKey('t.booth.corner'), 'Köşe loca');
    expect(furnitureSymbolNames.names['tr']!['kitchen.fridge'], 'Buzdolabı');
  });

  testWidgets(
      'SN3 the Symbol section shows a placed symbol by key in the panel\'s '
      'language; a key no library knows shows the copy\'s name (L9, M-14d-h)',
      (tester) async {
    final doc = DraftDocument.empty(measurer: FlutterTextMeasurer());
    registerAppComponents(doc.components);
    doc.header.units = DrawingUnits.millimeters;
    SymbolEntry entry(String key) =>
        library.entries.singleWhere((e) => e.key == key);
    doc.commands.execute(placeSymbol(doc, entry('t.booth.corner'),
        at: Vector2(1200.5, -800.25), quarterTurns: 1));
    final booth = doc.tree.nodes.whereType<InstanceNode>().single.handle;
    final loader = SymbolLibraryLoader(sources: [
      SymbolLibrarySource(
          name: 't', read: () async => libraryBytes(), names: names),
    ]);
    addTearDown(loader.dispose);
    await tester.runAsync(loader.load);
    final selection = SelectionController(doc);
    addTearDown(selection.dispose);
    Widget app(Locale locale, SymbolLibraryLoader? symbols) => MaterialApp(
        locale: locale,
        supportedLocales: floorPlanSupportedLocales,
        localizationsDelegates: floorPlanLocalizationsDelegates,
        home: Scaffold(
            body: SingleChildScrollView(
                child: SelectionPanel(
                    document: doc, selection: selection, symbols: symbols))));
    String shown() =>
        tester.widget<Text>(find.byKey(const Key('symbol-name'))).data!;

    await tester.pumpWidget(app(const Locale('tr'), loader));
    selection.replace([SelectionKey.root(booth)]);
    await tester.pump();
    expect(shown(), 'Köşe loca');
    await tester.pumpWidget(app(const Locale('de'), loader));
    await tester.pump();
    expect(shown(), 'Ecksitznische');
    await tester.pumpWidget(app(const Locale('en'), loader));
    await tester.pump();
    expect(shown(), 'Corner booth');
    await tester.pumpWidget(app(const Locale('tr'), null));
    await tester.pump();
    expect(shown(), 'Corner booth', reason: 'no library: the copy\'s name');
  });

  testWidgets(
      'SN4 the palette in Turkish: a category collapsed in English stays '
      'collapsed, renamed, after a switch (L10, M-14d-s)', (tester) async {
    final c = FloorPlanController();
    addTearDown(c.dispose);
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Widget app(Locale locale) => MaterialApp(
        locale: locale,
        supportedLocales: floorPlanSupportedLocales,
        localizationsDelegates: floorPlanLocalizationsDelegates,
        home: Scaffold(body: FloorPlanView(controller: c)));
    await tester.pumpWidget(app(const Locale('en')));
    await tester.tap(find.byKey(const Key('tab-symbols')));
    await tester.pump();
    await tester.runAsync(() async {
      while (!c.symbols.state.toString().contains('Ready')) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pump();
    final header = find.byKey(const Key('symbol-group-Kitchen'));
    expect(find.descendant(of: header, matching: find.text('Kitchen')),
        findsOneWidget);
    expect(
        find.byKey(const Key('symbol-cell-kitchen.base.300@1')), findsOneWidget,
        reason: 'premise: open');
    await tester.tap(header);
    await tester.pump();
    expect(
        find.byKey(const Key('symbol-cell-kitchen.base.300@1')), findsNothing);

    await tester.pumpWidget(app(const Locale('tr')));
    await tester.pump();
    expect(find.descendant(of: header, matching: find.text('Mutfak')),
        findsOneWidget);
    expect(
        find.byKey(const Key('symbol-cell-kitchen.base.300@1')), findsNothing,
        reason: 'still collapsed');
    await tester.tap(header);
    await tester.pump();
    final cell = find.byKey(const Key('symbol-cell-kitchen.base.300@1'));
    expect(find.descendant(of: cell, matching: find.text('Alt dolap 300')),
        findsOneWidget);
  });
}
