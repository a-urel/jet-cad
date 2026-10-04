// Spec 09b D3, plan 09b Task 1: the symbol search. Run on the real asset
// (read by `File`, decoded by the loader), on the 09a fixture library (a
// category that is not contiguous in library order) and on a hand-built
// fixture whose first category's first symbol fails the query.
//
// Every single-field test first proves, over the whole library, that its
// term hits that field and no other (the key counts as a field: it is not
// searched): a later change to the asset that makes a term hit a second field
// fails the precondition instead of leaving the test vacuous. Terms come both
// as prefixes and mid-word, so a prefix match cannot pass for a substring
// match.
import 'dart:io';

import 'package:jet_cad_floor_plan/src/symbols/symbol_library.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_search.dart';
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
/// computed here independently of the code under test. The key is listed
/// although the search ignores it, so a term proven to hit only one field
/// cannot also hit the key.
Set<String> fieldsHit(SymbolEntry e, String term) => {
      if (e.key.toLowerCase().contains(term)) 'key',
      if (e.name.toLowerCase().contains(term)) 'name',
      if (e.tags.any((t) => t.toLowerCase().contains(term))) 'tag',
      if (e.category.toLowerCase().contains(term)) 'category',
    };

/// Proves that [term] hits [field] alone over all of [entries], and returns
/// the ids of the symbols it hits.
List<String> hitsOnly(List<SymbolEntry> entries, String term, String field) {
  final hit = <String>[];
  for (final e in entries) {
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
      // "Three-seat sofa": also proves the name is compared lower-cased. The
      // key "sofa.three" holds "three" but not "three-seat".
      expect(hitsOnly(lib.entries, 'three-seat', 'name'), ['sofa.three@1']);
      final found = searchSymbols(lib.entries, 'three-seat');
      expect(ids(found), ['sofa.three@1']);
      expect(categoriesOf(found), ['Living Room']);
    });

    test('a term inside the name finds a symbol', () {
      // "Square dining table, 2 seats" and its kin: "seats" ends the name.
      // Since spec 14 S3 the dining tables are version 2, and the round one
      // is "Round dining table, 4 seats".
      const seats = [
        'dining.table.square.two@2',
        'dining.table.square.four@2',
        'dining.table.rect.four@2',
        'dining.table.rect.six@2',
        'dining.table.round@2',
      ];
      expect(hitsOnly(lib.entries, 'seats', 'name'), seats);
      for (final id in seats) {
        final e = lib.entries.firstWhere((e) => idOf(e) == id);
        expect(e.name.toLowerCase().startsWith('seats'), isFalse);
      }
      expect(ids(searchSymbols(lib.entries, 'seats')), seats);
    });

    test('a tag alone finds a symbol', () {
      const sofas = ['sofa.two@1', 'sofa.three@1'];
      const wardrobes = [
        'bed.wardrobe.1200@1',
        'bed.wardrobe@1',
        'bed.wardrobe.2400@1',
      ];
      expect(hitsOnly(lib.entries, 'couch', 'tag'), sofas);
      expect(ids(searchSymbols(lib.entries, 'couch')), sofas);
      expect(hitsOnly(lib.entries, 'closet', 'tag'), wardrobes);
      expect(ids(searchSymbols(lib.entries, 'closet')), wardrobes);
    });

    test('a term inside a tag finds a symbol', () {
      // The tag "worktop" of the kitchen island.
      expect(hitsOnly(lib.entries, 'top', 'tag'), ['kitchen.island@1']);
      final island = lib.entries.firstWhere((e) => e.key == 'kitchen.island');
      expect(island.tags.any((t) => t.startsWith('top')), isFalse);
      expect(island.tags, contains('worktop'));
      expect(ids(searchSymbols(lib.entries, 'top')), ['kitchen.island@1']);
    });

    test('the category alone finds a symbol', () {
      // "Living Room": also proves the category is compared lower-cased.
      const living = [
        'sofa.two@1',
        'sofa.three@1',
        'armchair@1',
        'table.coffee@1',
        'tv.unit@1',
      ];
      expect(hitsOnly(lib.entries, 'living', 'category'), living);
      final found = searchSymbols(lib.entries, 'living');
      expect(ids(found), living);
      expect(categoriesOf(found), ['Living Room']);
    });

    test('a term inside the category finds a symbol', () {
      // "room" ends "Dining Room" and the rest, and sits inside "Bathroom";
      // only Kitchen and Office lack it.
      final rooms = hitsOnly(lib.entries, 'room', 'category');
      expect(rooms, [
        for (final e in lib.entries)
          if (e.category != 'Kitchen' && e.category != 'Office') idOf(e),
      ]);
      for (final e in lib.entries) {
        expect(e.category.toLowerCase().startsWith('room'), isFalse);
      }
      final found = searchSymbols(lib.entries, 'room');
      expect(ids(found), rooms);
      expect(categoriesOf(found),
          ['Dining Room', 'Bed Room', 'Living Room', 'Bathroom']);
    });
  });

  group('the hand-built fixture', () {
    // "wing" is in the key only; "Reading" is a mixed-case tag.
    final entries = [
      entry(9500, 'lamp.arc', 'Arc lamp', 'Den', ['lamp', 'light']),
      entry(9600, 'chair.wingback', 'Armchair', 'Den', ['Reading', 'seat']),
    ];

    test('a term in the key alone finds nothing', () {
      expect(hitsOnly(entries, 'wing', 'key'), ['chair.wingback@1']);
      expect(searchSymbols(entries, 'wing'), isEmpty);
      expect(searchSymbols(entries, 'chair.wingback'), isEmpty);
      // The symbol itself is searchable: its name finds it.
      expect(ids(searchSymbols(entries, 'armchair')), ['chair.wingback@1']);
    });

    test('a mixed-case tag is found in any case', () {
      expect(hitsOnly(entries, 'reading', 'tag'), ['chair.wingback@1']);
      expect(entries[1].tags.first, 'Reading');
      for (final query in ['reading', 'READING', 'rEaDiNg']) {
        expect(ids(searchSymbols(entries, query)), ['chair.wingback@1'],
            reason: query);
      }
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
      hitsOnly(lib.entries, 'living', 'category');
      hitsOnly(lib.entries, 'couch', 'tag');
      expect(ids(searchSymbols(lib.entries, 'couch living')),
          ['sofa.two@1', 'sofa.three@1']);
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
    expect(ids(searchSymbols(lib.entries, 'CoUcH')),
        ['sofa.two@1', 'sofa.three@1']);
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
    expect(lib.entries, hasLength(41));
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
        'dining.table.square.two@2',
        'dining.table.square.four@2',
        'dining.table.rect.four@2',
        'dining.table.rect.six@2',
        'dining.table.round@2',
      ],
      ['bed.nightstand@1'],
      ['table.coffee@1'],
      ['office.desk.1200@1', 'office.desk@1', 'office.desk.1600@1'],
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
