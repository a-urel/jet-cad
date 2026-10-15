// Spec K7: the conformance test. The sample kit conforms; each failing kit
// changes one thing of it (and regenerates what a kit's generator would),
// so it can only go red through its own problem.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/authoring.dart';

import '../fixtures/sample_kit/sample_kit.dart';

const String dir = 'test/fixtures/sample_kit';

Uint8List committedLibrary() => File('$dir/sample.jetlib').readAsBytesSync();

String committedSnapshot() =>
    File('$dir/sample_snapshot.json').readAsStringSync();

List<KitProblem> problems({
  Catalog? catalog,
  Uint8List? library,
  String? snapshot,
  KitNames names = sampleNames,
  List<String> locales = sampleLocales,
  Map<String, Set<String>> sameAsEnglish = sampleSameAsEnglish,
}) =>
    conformance(
      catalog: catalog ?? sampleCatalog,
      committedLibrary: library ?? committedLibrary(),
      committedSnapshot: snapshot ?? committedSnapshot(),
      names: names,
      locales: locales,
      sameAsEnglish: sameAsEnglish,
    );

List<KitProblemCode> codes(List<KitProblem> problems) =>
    [for (final p in problems) p.code];

CatalogSymbol symbolOf(String id) =>
    sampleSymbols.firstWhere((s) => s.id == id);

CatalogSymbol copyOf(CatalogSymbol s,
        {String? key,
        int? version,
        String? name,
        List<String>? tags,
        List<String>? attachTo,
        String? family,
        CatalogUnit? unit,
        List<CatalogShape>? shapes,
        bool? retired}) =>
    CatalogSymbol(
      key: key ?? s.key,
      version: version ?? s.version,
      name: name ?? s.name,
      category: s.category,
      tags: tags ?? s.tags,
      attachTo: attachTo ?? s.attachTo,
      family: family ?? s.family,
      unit: unit ?? s.unit,
      base: s.base,
      shapes: shapes ?? s.shapes,
      retired: retired ?? s.retired,
    );

/// The sample catalog with [symbol] in place of the one of its id.
Catalog replacing(CatalogSymbol symbol) => Catalog(kit: 'sample', symbols: [
      for (final s in sampleSymbols) s.id == symbol.id ? symbol : s,
    ]);

/// [names] with [edits] applied to [locale]: a null value removes the word.
KitNames editing(KitNames names, String locale, Map<String, String?> edits) {
  final words = {...?names.words[locale]};
  for (final MapEntry(key: id, value: word) in edits.entries) {
    if (word == null) {
      words.remove(id);
    } else {
      words[id] = word;
    }
  }
  return KitNames({...names.words, locale: words});
}

/// The library and the snapshot a kit's generator would write for [catalog]
/// over the committed snapshot.
({Uint8List library, String snapshot}) generated(Catalog catalog) => (
      library: encodeLibrary(catalog),
      snapshot: encodeSnapshot(updateSnapshot(
          parseSnapshot(committedSnapshot()), geometrySnapshot(catalog))),
    );

void main() {
  test('F0 the sample kit conforms', () {
    // M-K2B-14: the UnitKinds exemption dropped: the sample's tables and stool need a unit word.
    expect(problems(), isEmpty);
  });

  test('F0b premise: the committed files are the sample kit', () {
    final library = SymbolLibrary.decode(committedLibrary());
    expect(library.kits, ['sample']);
    expect([
      for (final e in library.entries) e.id
    ], [
      'sample.table.round-four@1',
      'sample.table.rect-two@2',
      'sample.stool.bar@1',
      'sample.bed.double@1',
    ]);
    expect(parseSnapshot(committedSnapshot()).keys.toList(), [
      'sample.bed.double@1',
      'sample.stool.bar@1',
      'sample.table.rect-two@2',
      'sample.table.round-four@1',
    ]);
  });

  test('F1 built differs from committed: a renamed symbol', () {
    final renamed = replacing(
        copyOf(symbolOf('sample.bed.double@1'), name: 'Double bed, 160'));
    // M-F1: drop the byte comparison.
    expect(codes(problems(catalog: renamed)), [KitProblemCode.builtDiffers]);
  });

  test('F2 the committed library does not validate', () {
    expect(codes(problems(library: Uint8List.fromList(utf8.encode('{}')))),
        [KitProblemCode.builtDiffers, KitProblemCode.libraryInvalid]);
  });

  test("F3 the committed library is another kit's", () {
    final other = encodeLibrary(const Catalog(kit: 'other', symbols: [
      CatalogSymbol(
        key: 'other.table.round',
        name: 'Round table',
        category: 'Tables',
        base: (700, 700),
        shapes: [CatalogCircle((700, 700), 400)],
      ),
    ]));
    // M-F3: drop the kit comparison.
    expect(codes(problems(library: other)),
        [KitProblemCode.builtDiffers, KitProblemCode.libraryKitMismatch]);
  });

  test("F4 a key under another kit's id", () {
    final catalog = Catalog(kit: 'sample', symbols: [
      ...sampleSymbols,
      copyOf(symbolOf('sample.stool.bar@1'), key: 'other.stool.bar'),
    ]);
    // M-F4: drop the kit-of-key check (the catalog then fails to build).
    final found = problems(catalog: catalog);
    expect(codes(found), [KitProblemCode.keyOutsideKit]);
    expect(found.single.message, contains('other.stool.bar@1'));
  });

  test('F5 a moved vertex of a committed key@1', () {
    final bed = symbolOf('sample.bed.double@1');
    final moved = replacing(copyOf(bed, shapes: [
      bed.shapes[0],
      const CatalogLine((100, 1351), (1700, 1351)),
      ...bed.shapes.skip(2),
    ]));
    // M-F5: compare the snapshot's keys only.
    final found = problems(catalog: moved, library: encodeLibrary(moved));
    expect(codes(found), [KitProblemCode.snapshotChanged]);
    expect(found.single.message, contains('sample.bed.double@1'));
    expect(found.single.message, contains('1351.0'));
  });

  test('F6 a changed capacity', () {
    final more = replacing(copyOf(symbolOf('sample.table.round-four@1'),
        unit: const CatalogUnit(kind: UnitKinds.table, capacity: 5)));
    expect(codes(problems(catalog: more, library: encodeLibrary(more))),
        [KitProblemCode.snapshotChanged]);
  });

  test('F7 the same change at a new version conforms', () {
    // Review Focus 5: one key at two versions.
    final catalog = Catalog(kit: 'sample', symbols: [
      ...sampleSymbols,
      copyOf(symbolOf('sample.table.round-four@1'),
          version: 2,
          unit: const CatalogUnit(kind: UnitKinds.table, capacity: 5)),
    ]);
    final g = generated(catalog);
    expect(problems(catalog: catalog, library: g.library, snapshot: g.snapshot),
        isEmpty);
    expect(
        parseSnapshot(g.snapshot).keys,
        containsAll(
            ['sample.table.round-four@1', 'sample.table.round-four@2']));
  });

  test('F8 a removed key', () {
    final fewer = Catalog(kit: 'sample', symbols: [
      for (final s in sampleSymbols)
        if (s.key != 'sample.stool.bar') s,
    ]);
    var names = editing(sampleNames, 'de', {'symbol:sample.stool.bar': null});
    names = editing(names, 'tr', {'symbol:sample.stool.bar': null});
    // The Bar category goes with its only symbol.
    names = editing(names, 'de', {'category:sample/Bar': null});
    names = editing(names, 'tr', {'category:sample/Bar': null});
    // M-F8: skip committed entries the catalog lacks.
    final found =
        problems(catalog: fewer, library: encodeLibrary(fewer), names: names);
    expect(codes(found), [KitProblemCode.keyRemoved]);
    expect(found.single.message, contains('sample.stool.bar@1'));
  });

  test('F9 a key@N missing from the committed snapshot', () {
    final snapshot = parseSnapshot(committedSnapshot())
      ..remove('sample.bed.double@1');
    expect(codes(problems(snapshot: encodeSnapshot(snapshot))),
        [KitProblemCode.snapshotMissing]);
  });

  test('F10 an unreadable snapshot', () {
    expect(codes(problems(snapshot: 'not json')),
        [KitProblemCode.snapshotUnreadable]);
  });

  test('F11 a missing Turkish word; a declared locale with no words', () {
    // An English word for the key too, so a lookup that falls back to
    // English (M-F11) finds one and reports something else.
    final found = problems(
        names: editing(
            editing(sampleNames, 'tr', {'symbol:sample.bed.double': null}),
            'en',
            {'symbol:sample.bed.double': 'Double bed'}));
    expect(codes(found), [KitProblemCode.wordMissing]);
    expect(found.single.message, contains('tr'));
    expect(found.single.message, contains('symbol:sample.bed.double'));
    final onlyGerman = KitNames({'de': sampleNames.words['de']!});
    expect(codes(problems(names: onlyGerman)),
        List.filled(7, KitProblemCode.wordMissing));
  });

  test('F12 a word equal to its English, unless the kit allows it', () {
    // M-F12a: drop the equality check.
    expect(
        codes(problems(
            names: editing(
                sampleNames, 'tr', {'symbol:sample.stool.bar': 'Bar stool'}))),
        [KitProblemCode.wordUntranslated]);
    // M-F12b: ignore the allow-list; F0 goes red too.
    expect(codes(problems(sameAsEnglish: const {})),
        [KitProblemCode.wordUntranslated, KitProblemCode.wordUntranslated]);
  });

  test('F13 a word for a key or a category the catalog lacks', () {
    for (final (locale, id) in [
      ('tr', 'symbol:sample.table.square'),
      ('de', 'category:sample/Kitchen'),
      // A category under another kit's id is not this kit's word.
      ('tr', 'category:other/Tables'),
      ('en', 'symbol:sample.gone.away'),
    ]) {
      // M-F13: check the declared locales only; the "en" case passes.
      expect(codes(problems(names: editing(sampleNames, locale, {id: 'x'}))),
          [KitProblemCode.wordOrphan],
          reason: '$locale $id');
    }
  });

  test('F14 a locale with words that is not declared', () {
    expect(
        codes(problems(
            names: editing(sampleNames, 'fr',
                {'symbol:sample.bed.double': 'Lit double'}))),
        [KitProblemCode.localeUndeclared]);
  });

  test('F15 lower case for keys, tags, target kinds, families and kinds', () {
    final round = symbolOf('sample.table.round-four@1');
    final bed = symbolOf('sample.bed.double@1');
    for (final changed in [
      copyOf(round, tags: const ['table', 'Round']),
      copyOf(round, key: 'sample.Table.round-four'),
      copyOf(round, unit: const CatalogUnit(kind: 'Table', capacity: 4)),
      copyOf(bed, family: 'Bed-double'),
      copyOf(bed, attachTo: const ['Wall-face']),
    ]) {
      final catalog = changed.key == round.key || changed.key == bed.key
          ? replacing(changed)
          : Catalog(kit: 'sample', symbols: [...sampleSymbols, changed]);
      // M-F15: drop one of the five checks; its case goes red.
      expect(codes(problems(catalog: catalog)), [KitProblemCode.notLowerCase],
          reason: changed.id);
    }
  });

  test('F16 a catalog that does not build', () {
    final twoSegments = Catalog(kit: 'sample', symbols: [
      ...sampleSymbols,
      copyOf(symbolOf('sample.stool.bar@1'), key: 'sample.stool'),
    ]);
    expect(
        codes(problems(catalog: twoSegments)), [KitProblemCode.catalogInvalid]);
    final twice = Catalog(
        kit: 'sample', symbols: [...sampleSymbols, sampleSymbols.first]);
    final found = problems(catalog: twice);
    expect(codes(found), [KitProblemCode.catalogInvalid]);
    expect(found.single.message, contains('rule 6'));
  });

  test("F17 English is not a declared locale: it is always required", () {
    expect(() => problems(locales: const ['en', 'tr']), throwsArgumentError);
  });

  test('F18 an empty kit conforms', () {
    // Review Focus 4.
    const empty = Catalog(kit: 'sample', symbols: []);
    expect(
        conformance(
          catalog: empty,
          committedLibrary: encodeLibrary(empty),
          committedSnapshot: '{}\n',
          names: KitNames.empty,
          locales: const ['tr'],
        ),
        isEmpty);
  });

  test("F19 a word is compared with the key's newest English", () {
    // Review Focus 5. M-F19: compare with the first version's name (red
    // with v2 last). M-F19b: let every version overwrite, the last in
    // catalog order wins (red with v2 first).
    final stool = symbolOf('sample.stool.bar@1');
    final high = copyOf(stool, version: 2, name: 'High bar stool');
    for (final (order, catalog) in [
      ('v2 last', Catalog(kit: 'sample', symbols: [...sampleSymbols, high])),
      (
        'v2 first',
        Catalog(kit: 'sample', symbols: [
          for (final s in sampleSymbols) ...[if (s.id == stool.id) high, s],
        ])
      ),
    ]) {
      final g = generated(catalog);
      List<KitProblemCode> withTurkish(String word) => codes(problems(
          catalog: catalog,
          library: g.library,
          snapshot: g.snapshot,
          names:
              editing(sampleNames, 'tr', {'symbol:sample.stool.bar': word})));
      expect(withTurkish('High bar stool'), [KitProblemCode.wordUntranslated],
          reason: order);
      expect(withTurkish('Bar stool'), isEmpty, reason: order);
    }
  });

  test('R2-7 a retired published key conforms once regenerated', () {
    final retired =
        replacing(copyOf(symbolOf('sample.stool.bar@1'), retired: true));
    // The library changes (the symbol carries the mark), so the committed
    // one is stale until the generator runs.
    expect(codes(problems(catalog: retired)), [KitProblemCode.builtDiffers]);
    final g = generated(retired);
    // M-R2f (snapshot_test R2-6) turns this red as snapshotChanged.
    expect(problems(catalog: retired, library: g.library, snapshot: g.snapshot),
        isEmpty);
    expect(g.snapshot, committedSnapshot());
  });

  group('the code side (contract R3)', () {
    const Map<String, String> en = {
      'type:sample.wall': 'Wall',
      'tool:sample.wall': 'Wall tool',
      'property:sample.wall.height': 'Height',
      'property:sample.wall.finish.oiled': 'Oiled',
    };
    const Map<String, String> de = {
      'type:sample.wall': 'Wand',
      'tool:sample.wall': 'Wandwerkzeug',
      'property:sample.wall.height': 'Höhe',
      'property:sample.wall.finish.oiled': 'Geölt',
    };
    const Map<String, String> tr = {
      'type:sample.wall': 'Duvar',
      'tool:sample.wall': 'Duvar aracı',
      'property:sample.wall.height': 'Yükseklik',
      'property:sample.wall.finish.oiled': 'Yağlı',
    };

    /// The sample kit's words with the code side's added.
    KitNames codeNames({
      Map<String, String> english = en,
      Map<String, String> german = de,
      Map<String, String> turkish = tr,
    }) =>
        KitNames({
          'en': english,
          'de': {...sampleNames.words['de']!, ...german},
          'tr': {...sampleNames.words['tr']!, ...turkish},
        });

    List<KitProblem> codeProblems({
      KitNames? names,
      List<String> types = const ['sample.wall'],
      List<String> tools = const ['sample.wall'],
      List<String> properties = const [
        'sample.wall.height',
        'sample.wall.finish.oiled',
      ],
      Map<String, Set<String>> sameAsEnglish = sampleSameAsEnglish,
    }) =>
        conformance(
          catalog: sampleCatalog,
          committedLibrary: committedLibrary(),
          committedSnapshot: committedSnapshot(),
          names: names ?? codeNames(),
          locales: sampleLocales,
          sameAsEnglish: sameAsEnglish,
          typeIds: types,
          toolIds: tools,
          propertyIds: properties,
        );

    test('R3-1 a kit with types, tools and properties conforms', () {
      // A positive control for R3-2 to R3-4.
      expect(codeProblems(), isEmpty);
    });

    test('R3-2 an id that is not under the kit', () {
      // M-R3a: drop the check. M-R3b: test `kitOfKey` only ('sample.Wall').
      for (final id in ['other.wall', 'sample', 'sample.Wall']) {
        final found = codeProblems(types: [id]);
        expect(codes(found), [KitProblemCode.typeOutsideKit], reason: id);
        expect(found.single.message, contains('"$id"'));
        expect(
            codes(codeProblems(tools: [id])), [KitProblemCode.toolOutsideKit],
            reason: id);
      }
      // M-R3c: drop the property check. M-R3f: drop its dot test ('sample'
      // is then under the kit).
      for (final id in ['other.wall.height', 'height', 'sample']) {
        expect(codes(codeProblems(properties: [id])),
            [KitProblemCode.foreignWordId],
            reason: id);
      }
    });

    test('R3-3 a code-side word without English', () {
      for (final id in en.keys) {
        // M-R3d: drop the English check.
        final found =
            codeProblems(names: codeNames(english: {...en}..remove(id)));
        expect(codes(found), [KitProblemCode.missingEnglish], reason: id);
        expect(found.single.message, contains('"$id"'));
      }
    });

    test('R3-4 a declared locale holds the code side to the same rule', () {
      // M-R3e: leave the code words out of the declared-locale check.
      final found = codeProblems(
          names: codeNames(german: {...de}..remove('tool:sample.wall')));
      expect(codes(found), [KitProblemCode.wordMissing]);
      expect(found.single.message, contains('tool:sample.wall'));
      final untranslated =
          codeNames(turkish: {...tr, 'type:sample.wall': 'Wall'});
      expect(codes(codeProblems(names: untranslated)),
          [KitProblemCode.wordUntranslated]);
      expect(
          codeProblems(names: untranslated, sameAsEnglish: {
            ...sampleSameAsEnglish,
            'tr': {...sampleSameAsEnglish['tr']!, 'type:sample.wall'},
          }),
          isEmpty);
    });

    test('R3-5 without ids, the code side is not checked (additive)', () {
      // A positive control: a kit calling conformance as before 2a, with
      // code-side words, is held to nothing new.
      expect(
          conformance(
            catalog: sampleCatalog,
            committedLibrary: committedLibrary(),
            committedSnapshot: committedSnapshot(),
            names: codeNames(german: const {}),
            locales: sampleLocales,
            sameAsEnglish: sampleSameAsEnglish,
          ),
          isEmpty);
    });
  });

  group('unit kinds (spec 2b S4)', () {
    // Two booths: a kind the contract does not name. New keys, so the
    // generator writes them into the library and the snapshot.
    CatalogSymbol booth(String key, String name, double x) => CatalogSymbol(
          key: key,
          name: name,
          category: tables,
          tags: const ['booth'],
          unit: const CatalogUnit(kind: 'booth', capacity: 6),
          base: (x + 900, 2450),
          shapes: [rect(x, 2000, 1800, 900)],
        );
    final catalog = Catalog(kit: 'sample', symbols: [
      ...sampleSymbols,
      booth('sample.booth.corner', 'Corner booth', 3000),
      booth('sample.booth.long', 'Long booth', 5200),
    ]);
    final g = generated(catalog);

    /// The sample's words, the booths' symbol words in its two locales, and
    /// [english] (none when empty).
    KitNames named(Map<String, String> english) => KitNames({
          ...sampleNames.words,
          'de': {
            ...sampleNames.words['de']!,
            'symbol:sample.booth.corner': 'Eckbank',
            'symbol:sample.booth.long': 'Lange Bank',
          },
          'tr': {
            ...sampleNames.words['tr']!,
            'symbol:sample.booth.corner': 'Köşe koltuk',
            'symbol:sample.booth.long': 'Uzun koltuk',
          },
          if (english.isNotEmpty) 'en': english,
        });

    List<KitProblem> boothProblems(KitNames names) => problems(
        catalog: catalog,
        library: g.library,
        snapshot: g.snapshot,
        names: names);

    test(
        'K2B-conf a kind outside UnitKinds needs an English unit word, once '
        'per kind; the declared locales are not held to it', () {
      // M-K2B-12: the unit kind check not called.
      final found = boothProblems(named(const {}));
      // M-K2B-13: the once-per-kind set dropped (two problems).
      expect(codes(found), [KitProblemCode.unitKindWord]);
      expect(found.single.message, contains('"unit:sample/booth"'));
      expect(
          boothProblems(named(const {'unit:sample/booth': 'Booth'})), isEmpty);
      expect(codes(boothProblems(named(const {'unit:other/booth': 'Booth'}))),
          [KitProblemCode.unitKindWord],
          reason: "another kit's word does not count");
    });
  });
}
