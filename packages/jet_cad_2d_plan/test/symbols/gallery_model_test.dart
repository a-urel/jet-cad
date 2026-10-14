// Spec P2 "PlanSymbolGallery" (Task 13): the gallery's model. Search over
// the shown names, the shown categories, the stored English and the tags,
// folded; groups by kit and category in first-appearance order; retired
// symbols hidden (R2); an optional filter. Ported tests keep their
// assertions (only the fixture keys gained a kit id); GM tests are new.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/authoring.dart'
    show Catalog, CatalogPolyline, CatalogSymbol, encodeLibrary;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/symbols/gallery_model.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/symbol_fixtures.dart';

String idOf(PlanSymbol s) => s.id;

List<String> ids(List<PlanSymbolGroup> groups) =>
    [for (final g in groups) ...g.symbols.map(idOf)];

List<String> categoriesOf(List<PlanSymbolGroup> groups) =>
    [for (final g in groups) g.category];

/// The fields of [s] that contain the lower-case [term], computed here
/// independently of the code under test (symbol_search_test.dart:39-44);
/// the key is listed although the search ignores it.
Set<String> fieldsHit(PlanSymbol s, String term) {
  final c = s.component;
  return {
    if (c.key.toLowerCase().contains(term)) 'key',
    if (c.name.toLowerCase().contains(term)) 'name',
    if (c.tags.any((t) => t.toLowerCase().contains(term))) 'tag',
    if (c.category.toLowerCase().contains(term)) 'category',
  };
}

/// Proves that [term] hits [field] alone over all of [symbols], and returns
/// the ids of the symbols it hits (symbol_search_test.dart:48-59).
List<String> hitsOnly(List<PlanSymbol> symbols, String term, String field) {
  final hit = <String>[];
  for (final s in symbols) {
    final fields = fieldsHit(s, term);
    expect(fields.difference({field}), isEmpty,
        reason: '"$term" must hit only the $field of ${idOf(s)}, '
            'it hits $fields');
    if (fields.isNotEmpty) hit.add(idOf(s));
  }
  expect(hit, isNotEmpty, reason: '"$term" must hit some $field');
  return hit;
}

/// A symbol with no leaves: the search reads its identity only.
PlanSymbol entry(
        int handle, String key, String name, String category, List<String> tags,
        {String kit = 'fixture', KitNames names = KitNames.empty}) =>
    PlanSymbol(
      kitId: kit,
      names: names,
      entry: SymbolEntry(
        symbol: SymbolComponent(
            key: key, version: 1, name: name, category: category, tags: tags),
        unit: null,
        definition: Definition(
            handle: Handle(handle),
            name: '$key@1',
            basePoint: Vector2(130.0 + handle, 70.0 - handle),
            children: const []),
        leaves: const [],
      ),
    );

/// [bytes]' library as plan symbols of [kit].
List<PlanSymbol> symbolsOf(String kit, Uint8List bytes,
        {KitNames names = KitNames.empty}) =>
    [
      for (final e in SymbolLibrary.decode(bytes).entries)
        PlanSymbol(kitId: kit, names: names, entry: e),
    ];

/// symbol_words_test.dart's catalog: keys gained a second segment where
/// they had one (`t.heater` → `t.heater.patio`, `t.unnamed` →
/// `t.unnamed.crate`), as K2 requires.
CatalogSymbol rect(String key, String name, String category,
        {List<String> tags = const []}) =>
    CatalogSymbol(
      key: key,
      name: name,
      category: category,
      tags: tags,
      base: (450, 300),
      shapes: const [
        CatalogPolyline([(0, 0), (900, 0), (900, 600), (0, 600)], closed: true),
      ],
    );

const KitNames tNames = KitNames({
  'tr': {
    'symbol:t.booth.corner': 'Köşe loca',
    'symbol:t.heater.patio': 'Dış mekân ısıtıcısı',
    'category:t/Booths': 'Localar',
    'category:t/Outdoor': 'Dış mekân',
  },
  'de': {
    'symbol:t.booth.corner': 'Ecksitznische',
    'symbol:t.heater.patio': 'Heizstrahler',
  },
});

final List<PlanSymbol> tSymbols = symbolsOf(
    't',
    encodeLibrary(Catalog(kit: 't', symbols: [
      rect('t.booth.corner', 'Corner booth', 'Booths', tags: ['booth']),
      rect('t.heater.patio', 'Patio heater', 'Outdoor'),
      rect('t.unnamed.crate', 'Plain crate', 'Outdoor'),
    ])),
    names: tNames);

List<String> keysFound(String query, PlanSymbolWords words) => [
      for (final g in searchPlanSymbols(tSymbols, query, words))
        for (final s in g.symbols) s.component.key
    ];

final List<PlanSymbol> demo = symbolsOf('demo', demoBytes(), names: demoNames);

void main() {
  group('ported from symbol_search_test.dart', () {
    // "wing" is in the key only; "reading" is a tag. Retired (controller
    // ruling F-1, Task 13): the source's "a mixed-case tag is found in any
    // case" (symbol_search_test.dart:182-189), whose premise is the
    // mixed-case tag "Reading" -- K2 admits only lower-case tags
    // (SymbolComponent throws), so the fixture's tag is lower case and the
    // test's intent is kept on the query side by SF-Q below.
    final entries = [
      entry(9500, 'fixture.lamp.arc', 'Arc lamp', 'Den', ['lamp', 'light']),
      entry(9600, 'fixture.chair.wingback', 'Armchair', 'Den',
          ['reading', 'seat']),
    ];
    const en = PlanSymbolWords.english;

    test('a term in the key alone finds nothing', () {
      expect(hitsOnly(entries, 'wing', 'key'), ['fixture.chair.wingback@1']);
      expect(searchPlanSymbols(entries, 'wing', en), isEmpty);
      expect(searchPlanSymbols(entries, 'fixture.chair.wingback', en), isEmpty);
      // The symbol itself is searchable: its name finds it.
      expect(ids(searchPlanSymbols(entries, 'armchair', en)),
          ['fixture.chair.wingback@1']);
    });

    test('SF-Q a mixed-case query finds a lower-case tag (ruling F-1)', () {
      expect(hitsOnly(entries, 'reading', 'tag'), ['fixture.chair.wingback@1']);
      // M-SFQ: the query not folded (`searchFold(query)` → `query`).
      for (final query in ['ReAdInG', 'READING', 'rEaDiNg']) {
        expect(ids(searchPlanSymbols(entries, query, en)),
            ['fixture.chair.wingback@1'],
            reason: query);
      }
    });

    test('a category that is not contiguous in the library is one group', () {
      // The 09a fixture: sofa (Living Room), nightstand (Bed Room),
      // armchair (Living Room), in definition-handle order.
      final fixture = symbolsOf('fixture', bytesOf(buildValidLibrary()));
      expect(fixture.map(idOf).toList(), [
        'fixture.sofa.three@3',
        'fixture.nightstand.single@2',
        'fixture.armchair.single@1'
      ]);
      final all = searchPlanSymbols(fixture, '', en);
      expect(categoriesOf(all), ['Living Room', 'Bed Room']);
      expect(all.map((g) => g.symbols.map(idOf).toList()).toList(), [
        ['fixture.sofa.three@3', 'fixture.armchair.single@1'],
        ['fixture.nightstand.single@2'],
      ]);
      expect(ids(searchPlanSymbols(fixture, 'seating', en)),
          ['fixture.sofa.three@3', 'fixture.armchair.single@1']);
    });

    test('a category keeps its library place when its first symbol fails', () {
      final entries = [
        entry(9100, 'fixture.desk.corner', 'Corner desk', 'Study',
            ['desk', 'work']),
        entry(9200, 'fixture.lamp.floor', 'Floor lamp', 'Lounge',
            ['lamp', 'light']),
        entry(
            9300, 'fixture.lamp.desk', 'Desk lamp', 'Study', ['lamp', 'work']),
      ];
      final found = searchPlanSymbols(entries, 'lamp', en);
      expect(categoriesOf(found), ['Study', 'Lounge']);
      expect(ids(found), ['fixture.lamp.desk@1', 'fixture.lamp.floor@1']);
    });
  });

  group('ported from symbol_words_test.dart', () {
    test('SN1 search meets either language through the fold (L11, M-14d-j)',
        () {
      const tr = PlanSymbolWords('tr');
      expect(keysFound('kose', tr), ['t.booth.corner']);
      expect(keysFound('KÖŞE LOCA', tr), ['t.booth.corner']);
      expect(keysFound('booth', tr), ['t.booth.corner'], reason: 'a tag');
      expect(keysFound('corner', tr), ['t.booth.corner'],
          reason: 'the English name, in no tag');
      expect(keysFound('ISITICI', tr), ['t.heater.patio']);
      expect(keysFound('dis mekan', tr), ['t.heater.patio', 't.unnamed.crate'],
          reason: 'the category in Turkish');
      expect(keysFound('heizstrahler', tr), isEmpty,
          reason: 'German is not the shown language');
      const de = PlanSymbolWords('de');
      expect(keysFound('heizstrahler', de), ['t.heater.patio']);
      final groups = searchPlanSymbols(tSymbols, '', tr);
      expect([for (final g in groups) g.category], ['Booths', 'Outdoor'],
          reason: 'groups keep the English category as their key');
    });

    test('SN2 the words fall back to the library\'s English (L9)', () {
      const tr = PlanSymbolWords('tr');
      final crate =
          tSymbols.singleWhere((s) => s.component.key == 't.unnamed.crate');
      expect(tr.name(crate), 'Plain crate');
      final unknown = entry(9700, 't.x.y', 'X', 'Unknown', const [],
          kit: 't', names: tNames);
      expect(tr.category(unknown), 'Unknown');
    });
  });

  group('the gallery model (new)', () {
    const en = PlanSymbolWords.english;

    test('GM-1 an empty or blank query: every visible symbol, in order', () {
      for (final q in ['', ' ', ' \t\n  ']) {
        expect(ids(searchPlanSymbols(demo, q, en)), demoVisibleIds(),
            reason: '"$q"');
      }
    });

    test('GM-2 a retired symbol is hidden, whatever the query (R2)', () {
      expect(demo.map(idOf), contains('demo.chair.old@1'),
          reason: 'premise: loaded');
      // M-GM2: the retired filter dropped.
      expect(ids(searchPlanSymbols(demo, '', en)),
          isNot(contains('demo.chair.old@1')));
      expect(ids(searchPlanSymbols(demo, 'old chair', en)), isEmpty);
    });

    test(
        'GM-3 each stored field finds alone, shown in another language: the '
        'English name, a tag, the English category', () {
      // In Turkish the sofas show "Üçlü kanepe" and "Oturma odası", so only
      // the stored English can match these terms.
      const tr = PlanSymbolWords('tr');
      // M-GM3a: the stored name dropped from the texts.
      expect(ids(searchPlanSymbols(demo, 'three-seat', tr)),
          ['demo.sofa.three@1']);
      // M-GM3b: the tags dropped.
      expect(ids(searchPlanSymbols(demo, 'couch', tr)),
          ['demo.sofa.three@1', 'demo.sofa.two@1']);
      // M-GM3c: the stored category dropped.
      expect(ids(searchPlanSymbols(demo, 'living', tr)),
          ['demo.sofa.three@1', 'demo.sofa.two@1']);
    });

    test('GM-4 the shown words: the locale\'s name and category find it', () {
      const tr = PlanSymbolWords('tr');
      // M-GM4a: the shown name dropped from the texts.
      expect(ids(searchPlanSymbols(demo, 'kanepe', tr)), ['demo.sofa.three@1']);
      // M-GM4b: the shown category dropped.
      expect(ids(searchPlanSymbols(demo, 'oturma', tr)),
          ['demo.sofa.three@1', 'demo.sofa.two@1']);
      expect(ids(searchPlanSymbols(demo, 'kanepe', en)), isEmpty);
    });

    test('GM-5 every term is required, across fields; white space splits', () {
      expect(ids(searchPlanSymbols(demo, 'sofa three', en)),
          ['demo.sofa.three@1']);
      expect(ids(searchPlanSymbols(demo, '\tsofa \n  three\t', en)),
          ['demo.sofa.three@1']);
      // M-GM5: `every` written `any`.
      expect(ids(searchPlanSymbols(demo, 'couch office', en)), isEmpty);
      expect(ids(searchPlanSymbols(demo, 'BED', en)),
          ['demo.bed.double@1', 'demo.bed.single@1', 'demo.bed.night@1']);
    });

    test('GM-6 the filter runs before the search', () {
      bool beds(PlanSymbol s) => s.component.key.startsWith('demo.bed.');
      expect(ids(searchPlanSymbols(demo, '', en, filter: beds)),
          ['demo.bed.double@1', 'demo.bed.single@1', 'demo.bed.night@1']);
      // M-GM6: the filter ignored.
      expect(searchPlanSymbols(demo, 'sofa', en, filter: beds), isEmpty);
    });

    test('GM-7 two kits with one category name are two groups', () {
      final mixed = [
        entry(9100, 'alpha.bar.stool', 'Stool', 'Bar', ['stool'], kit: 'alpha'),
        entry(9200, 'beta.bar.stool', 'Stool', 'Bar', ['stool'], kit: 'beta'),
        entry(9300, 'alpha.bar.tap', 'Tap', 'Bar', ['tap'], kit: 'alpha'),
      ];
      final groups = searchPlanSymbols(mixed, '', en);
      // M-GM7: groups keyed by the category alone.
      expect([for (final g in groups) (g.kitId, g.category)],
          [('alpha', 'Bar'), ('beta', 'Bar')]);
      expect(groups.map((g) => g.symbols.map(idOf).toList()).toList(), [
        ['alpha.bar.stool@1', 'alpha.bar.tap@1'],
        ['beta.bar.stool@1'],
      ]);
      expect([for (final g in groups) groupIdOf(g)], ['alpha/Bar', 'beta/Bar']);
    });

    test(
        'GM-8 the words: the locale\'s, else English\'s, else the stored '
        'text', () {
      const tr = PlanSymbolWords('tr');
      final bed = demo.singleWhere((s) => s.id == 'demo.bed.double@1');
      final desk = demo.singleWhere((s) => s.id == 'demo.desk.office@1');
      expect(tr.name(bed), 'Çift kişilik yatak');
      expect(tr.category(bed), 'Yatak odası');
      expect(tr.name(desk), 'Office desk');
      expect(tr.category(desk), 'Office');
      const de = PlanSymbolWords('de');
      expect(de.name(bed), 'Double bed', reason: 'no German: the fallback');
    });

    test('GM-9 a group\'s id is the same in every language', () {
      final en = searchPlanSymbols(demo, '', PlanSymbolWords.english);
      final tr = searchPlanSymbols(demo, '', const PlanSymbolWords('tr'));
      expect([for (final g in tr) groupIdOf(g)],
          [for (final g in en) groupIdOf(g)]);
      expect([for (final g in en) groupIdOf(g)],
          ['demo/Bed Room', 'demo/Living Room', 'demo/Office']);
    });
  });
}
