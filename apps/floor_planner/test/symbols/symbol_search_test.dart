// Spec 09b D3, plan 09b Task 1: the symbol search. Run on the real asset
// (read by `File`, decoded by the loader), on the 09a fixture library (a
// category that is not contiguous in library order) and on a hand-built
// fixture whose first category's first symbol fails the query.
//
// Every single-field test first proves, over the whole library, that its
// term hits that field and no other: a later change to the asset that makes
// a term hit a second field fails the precondition instead of leaving the
// test vacuous.
import 'dart:io';

import 'package:floor_planner/symbols/symbol_library.dart';
import 'package:floor_planner/symbols/symbol_search.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/symbol_fixtures.dart';

SymbolLibrary assetLibrary() => SymbolLibrary.decode(
    File('assets/library/furniture.jetlib').readAsBytesSync());

String idOf(SymbolEntry e) => '${e.key}@${e.version}';

/// The ids of every symbol in [groups], flattened in order.
List<String> ids(List<SymbolGroup> groups) =>
    [for (final g in groups) ...g.symbols.map(idOf)];

/// The category names of [groups], in order.
List<String> categoriesOf(List<SymbolGroup> groups) =>
    [for (final g in groups) g.category];

/// The fields of [e] that contain the lower-case [term] (case-insensitive),
/// computed here independently of the code under test.
Set<String> fieldsHit(SymbolEntry e, String term) => {
      if (e.name.toLowerCase().contains(term)) 'name',
      if (e.tags.any((t) => t.toLowerCase().contains(term))) 'tag',
      if (e.category.toLowerCase().contains(term)) 'category',
    };

/// Proves that [term] hits [field] alone over all of [lib], and returns the
/// ids of the symbols it hits.
List<String> hitsOnly(SymbolLibrary lib, String term, String field) {
  final hit = <String>[];
  for (final e in lib.entries) {
    final fields = fieldsHit(e, term);
    expect(fields.difference({field}), isEmpty,
        reason: '"$term" must hit only the $field of ${idOf(e)}, '
            'it hits $fields');
    if (fields.isNotEmpty) hit.add(idOf(e));
  }
  expect(hit, isNotEmpty, reason: '"$term" must hit some $field');
  return hit;
}

/// A symbol with no leaves: the search reads its identity only.
SymbolEntry entry(int handle, String key, String name, String category,
        List<String> tags) =>
    SymbolEntry(
      key: key,
      name: name,
      category: category,
      tags: tags,
      version: 1,
      definition: Definition(
          handle: Handle(handle),
          name: '$key@1',
          basePoint: Vector2(130.0 + handle, 70.0 - handle),
          children: const []),
      leaves: const [],
    );

void main() {
  late SymbolLibrary lib;
  setUpAll(() => lib = assetLibrary());

  group('a single field', () {
    test('the name alone finds a symbol', () {
      // "Three-seat sofa": also proves the name is compared lower-cased.
      expect(hitsOnly(lib, 'three', 'name'), ['sofa.three@1']);
      final found = searchSymbols(lib.entries, 'three');
      expect(ids(found), ['sofa.three@1']);
      expect(categoriesOf(found), ['Living Room']);
    });

    test('a tag alone finds a symbol', () {
      expect(hitsOnly(lib, 'couch', 'tag'), ['sofa.three@1']);
      expect(ids(searchSymbols(lib.entries, 'couch')), ['sofa.three@1']);
      expect(hitsOnly(lib, 'closet', 'tag'), ['bed.wardrobe@1']);
      expect(ids(searchSymbols(lib.entries, 'closet')), ['bed.wardrobe@1']);
    });

    test('the category alone finds a symbol', () {
      // "Living Room": also proves the category is compared lower-cased.
      const living = [
        'sofa.three@1',
        'armchair@1',
        'table.coffee@1',
        'tv.unit@1',
      ];
      expect(hitsOnly(lib, 'living', 'category'), living);
      final found = searchSymbols(lib.entries, 'living');
      expect(ids(found), living);
      expect(categoriesOf(found), ['Living Room']);
    });
  });

  group('several terms', () {
    test('two terms are both required', () {
      final dining = ids(searchSymbols(lib.entries, 'dining'));
      final chair = ids(searchSymbols(lib.entries, 'chair'));
      expect(dining, hasLength(7));
      expect(chair, ['dining.chair@1', 'armchair@1', 'office.chair@1']);
      // Each term alone finds more than the pair.
      expect(
          ids(searchSymbols(lib.entries, 'dining chair')), ['dining.chair@1']);
    });

    test('the terms may hit different fields of one symbol', () {
      // "living" hits a category only; "couch" a tag only.
      hitsOnly(lib, 'living', 'category');
      hitsOnly(lib, 'couch', 'tag');
      expect(ids(searchSymbols(lib.entries, 'couch living')), ['sofa.three@1']);
      // A pair whose terms each hit, but never the same symbol, finds none.
      expect(ids(searchSymbols(lib.entries, 'couch closet')), isEmpty);
      expect(searchSymbols(lib.entries, 'couch closet'), isEmpty);
    });

    test('runs of white space of any kind separate terms', () {
      expect(ids(searchSymbols(lib.entries, '\tdining \n  chair\t')),
          ['dining.chair@1']);
    });
  });

  test('upper case in the query is ignored', () {
    expect(ids(searchSymbols(lib.entries, 'THREE')), ['sofa.three@1']);
    expect(ids(searchSymbols(lib.entries, 'CoUcH')), ['sofa.three@1']);
    expect(ids(searchSymbols(lib.entries, 'LIVING')),
        ids(searchSymbols(lib.entries, 'living')));
    expect(ids(searchSymbols(lib.entries, 'Dining CHAIR')), ['dining.chair@1']);
  });

  test('an empty or blank query matches every symbol, in library order', () {
    for (final query in ['', ' ', ' \t\n  ']) {
      final all = searchSymbols(lib.entries, query);
      expect(ids(all), lib.entries.map(idOf).toList(), reason: '"$query"');
      expect(categoriesOf(all), lib.categories, reason: '"$query"');
      for (final g in all) {
        expect(g.symbols.every((e) => e.category == g.category), isTrue);
      }
    }
    expect(lib.categories, hasLength(6));
    expect(lib.entries, hasLength(27));
  });

  test('order is preserved and empty groups are hidden', () {
    // "table" skips Kitchen and Bathroom, which sit between categories that
    // match.
    final found = searchSymbols(lib.entries, 'table');
    expect(categoriesOf(found),
        ['Dining Room', 'Bed Room', 'Living Room', 'Office']);
    expect(lib.categories, [
      'Dining Room',
      'Kitchen',
      'Bed Room',
      'Living Room',
      'Bathroom',
      'Office',
    ]);
    expect(found.map((g) => g.symbols.map(idOf).toList()).toList(), [
      [
        'dining.table.square.two@1',
        'dining.table.square.four@1',
        'dining.table.rect.four@1',
        'dining.table.rect.six@1',
        'dining.table.round@1',
      ],
      ['bed.nightstand@1'],
      ['table.coffee@1'],
      ['office.desk@1'],
    ]);
  });

  test('a category that is not contiguous in the library is one group', () {
    // The 09a fixture: sofa (Living Room), nightstand (Bed Room), armchair
    // (Living Room), in definition-handle order.
    final fixture = SymbolLibrary.decode(bytesOf(buildValidLibrary()));
    expect(fixture.entries.map(idOf).toList(),
        ['sofa.three@3', 'nightstand.single@2', 'armchair.single@1']);
    final all = searchSymbols(fixture.entries, '');
    expect(categoriesOf(all), ['Living Room', 'Bed Room']);
    expect(all.map((g) => g.symbols.map(idOf).toList()).toList(), [
      ['sofa.three@3', 'armchair.single@1'],
      ['nightstand.single@2'],
    ]);
    expect(ids(searchSymbols(fixture.entries, 'seating')),
        ['sofa.three@3', 'armchair.single@1']);
  });

  test('a category keeps its library place when its first symbol fails', () {
    final entries = [
      entry(9100, 'desk.corner', 'Corner desk', 'Study', ['desk', 'work']),
      entry(9200, 'lamp.floor', 'Floor lamp', 'Lounge', ['lamp', 'light']),
      entry(9300, 'lamp.desk', 'Desk lamp', 'Study', ['lamp', 'work']),
    ];
    final found = searchSymbols(entries, 'lamp');
    expect(categoriesOf(found), ['Study', 'Lounge']);
    expect(ids(found), ['lamp.desk@1', 'lamp.floor@1']);
  });
}
