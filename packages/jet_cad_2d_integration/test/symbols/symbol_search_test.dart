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
//
// Ported to jet_cad_2d_integration (3a Task 28, D-12) from
// jet_cad_floor_plan/test/symbols/symbol_search_test.dart:76-164 (the group
// "a single field") and :189-267 (the group "several terms" and the case,
// blank-query and order cases), 12 cases, assertions unchanged. The library
// is the kit's furniture as a plan loads it (an editor over
// `architectureController()`, its Symbols tab), at 1440 x 6000 so every
// hit's cell is built; `searchSymbols(lib.entries, q)` is the query typed
// into `symbol-search`, and the result is read from the gallery:
// `ids(found)` are its cells' keys in tree order (`symbol-cell-<id>`),
// `categoriesOf(found)` its group headers' (`symbol-group-<kit>/<English
// category>`, the category read after the kit). `hitsOnly` is the
// source's over the loaded symbols' components (key, stored name, tags,
// category). The ids are the kit's (C7 class 1): `architecture.<key>@1`
// (`dining.table.*@2` are `@1`, `armchair@1` is
// `architecture.armchair.single@1`).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../support/attach_plans.dart' show furniture;
import '../support/canvas_rig.dart' show pumpPlanEditor, symbolsReady;

/// Today's id `<key>@<v>` under the kit (C7 class 1).
String kit(String id) {
  final at = id.lastIndexOf('@');
  final key = id.substring(0, at);
  return 'architecture.${key == 'armchair' ? 'armchair.single' : key}@1';
}

/// A shown group: its category and its cells' ids, in tree order.
typedef ShownGroup = ({String category, List<String> ids});

/// The gallery as it stands: its headers and cells in tree order, each
/// cell under the header before it.
List<ShownGroup> shown(WidgetTester tester) {
  final out = <({String category, List<String> ids})>[];
  for (final e in find
      .byWidgetPredicate((w) =>
          w.key is ValueKey<String> &&
          ((w.key! as ValueKey<String>).value.startsWith('symbol-group-') ||
              (w.key! as ValueKey<String>).value.startsWith('symbol-cell-')))
      .evaluate()) {
    final k = (e.widget.key! as ValueKey<String>).value;
    if (k.startsWith('symbol-group-')) {
      final id = k.substring('symbol-group-'.length);
      out.add((category: id.substring(id.indexOf('/') + 1), ids: []));
    } else {
      out.last.ids.add(k.substring('symbol-cell-'.length));
    }
  }
  return out;
}

/// Today's `searchSymbols(lib.entries, q)`: [q] typed into the gallery's
/// search, two pumps, the groups shown.
Future<List<ShownGroup>> searchSymbols(WidgetTester tester, String q) async {
  await tester.enterText(find.byKey(const Key('symbol-search')), q);
  await tester.pump();
  await tester.pump();
  return shown(tester);
}

/// The ids of every symbol in [groups], flattened in order.
List<String> ids(List<ShownGroup> groups) => [for (final g in groups) ...g.ids];

/// The category names of [groups], in order.
List<String> categoriesOf(List<ShownGroup> groups) =>
    [for (final g in groups) g.category];

/// The fields of [e] that contain the lower-case [term] (case-insensitive),
/// computed here independently of the code under test. The key is listed
/// although the search ignores it, so a term proven to hit only one field
/// cannot also hit the key.
Set<String> fieldsHit(SymbolComponent e, String term) => {
      if (e.key.toLowerCase().contains(term)) 'key',
      if (e.name.toLowerCase().contains(term)) 'name',
      if (e.tags.any((t) => t.toLowerCase().contains(term))) 'tag',
      if (e.category.toLowerCase().contains(term)) 'category',
    };

/// Proves that [term] hits [field] alone over all of [entries], and returns
/// the ids of the symbols it hits.
List<String> hitsOnly(
    List<SymbolComponent> entries, String term, String field) {
  final hit = <String>[];
  for (final e in entries) {
    final fields = fieldsHit(e, term);
    expect(fields.difference({field}), isEmpty,
        reason: '"$term" must hit only the $field of ${e.id}, '
            'it hits $fields');
    if (fields.isNotEmpty) hit.add(e.id);
  }
  expect(hit, isNotEmpty, reason: '"$term" must hit some $field');
  return hit;
}

/// The editor over the kit's furniture, its Symbols tab open; the loaded
/// symbols' components (today's `lib.entries`).
Future<List<SymbolComponent>> openLibrary(WidgetTester tester) async {
  final c = architectureController();
  addTearDown(c.dispose);
  await pumpPlanEditor(tester, c, size: const Size(1440, 6000));
  await tester.tap(find.byKey(const Key('tab-symbols')));
  await tester.pump();
  expect(await symbolsReady(tester, c), isTrue,
      reason: 'premise: the library loaded');
  await tester.pump();
  return [for (final s in c.symbols) s.component];
}

void main() {
  group('a single field', () {
    testWidgets('the name alone finds a symbol', (tester) async {
      final entries = await openLibrary(tester);
      // "Three-seat sofa": also proves the name is compared lower-cased. The
      // key "sofa.three" holds "three" but not "three-seat".
      expect(hitsOnly(entries, 'three-seat', 'name'), [kit('sofa.three@1')]);
      final found = await searchSymbols(tester, 'three-seat');
      expect(ids(found), [kit('sofa.three@1')]);
      expect(categoriesOf(found), ['Living Room']);
    });

    testWidgets('a term inside the name finds a symbol', (tester) async {
      final entries = await openLibrary(tester);
      // "Square dining table, 2 seats" and its kin: "seats" ends the name.
      // Since spec 14 S3 the dining tables are version 2, and the round one
      // is "Round dining table, 4 seats".
      final seats = [
        for (final id in const [
          'dining.table.square.two@2',
          'dining.table.square.four@2',
          'dining.table.rect.four@2',
          'dining.table.rect.six@2',
          'dining.table.round@2',
        ])
          kit(id),
      ];
      expect(hitsOnly(entries, 'seats', 'name'), seats);
      for (final id in seats) {
        final e = entries.firstWhere((e) => e.id == id);
        expect(e.name.toLowerCase().startsWith('seats'), isFalse);
      }
      expect(ids(await searchSymbols(tester, 'seats')), seats);
    });

    testWidgets('a tag alone finds a symbol', (tester) async {
      final entries = await openLibrary(tester);
      final sofas = [kit('sofa.two@1'), kit('sofa.three@1')];
      final wardrobes = [
        kit('bed.wardrobe.1200@1'),
        kit('bed.wardrobe@1'),
        kit('bed.wardrobe.2400@1'),
      ];
      expect(hitsOnly(entries, 'couch', 'tag'), sofas);
      expect(ids(await searchSymbols(tester, 'couch')), sofas);
      expect(hitsOnly(entries, 'closet', 'tag'), wardrobes);
      expect(ids(await searchSymbols(tester, 'closet')), wardrobes);
    });

    testWidgets('a term inside a tag finds a symbol', (tester) async {
      final entries = await openLibrary(tester);
      // The tag "worktop" of the kitchen island.
      expect(hitsOnly(entries, 'top', 'tag'), [kit('kitchen.island@1')]);
      final island =
          entries.firstWhere((e) => e.key == 'architecture.kitchen.island');
      expect(island.tags.any((t) => t.startsWith('top')), isFalse);
      expect(island.tags, contains('worktop'));
      expect(
          ids(await searchSymbols(tester, 'top')), [kit('kitchen.island@1')]);
    });

    testWidgets('the category alone finds a symbol', (tester) async {
      final entries = await openLibrary(tester);
      // "Living Room": also proves the category is compared lower-cased.
      final living = [
        for (final id in const [
          'sofa.two@1',
          'sofa.three@1',
          'armchair@1',
          'table.coffee@1',
          'tv.unit@1',
        ])
          kit(id),
      ];
      expect(hitsOnly(entries, 'living', 'category'), living);
      final found = await searchSymbols(tester, 'living');
      expect(ids(found), living);
      expect(categoriesOf(found), ['Living Room']);
    });

    testWidgets('a term inside the category finds a symbol', (tester) async {
      final entries = await openLibrary(tester);
      // "room" ends "Dining Room" and the rest, and sits inside "Bathroom";
      // only Kitchen and Office lack it.
      final rooms = hitsOnly(entries, 'room', 'category');
      expect(rooms, [
        for (final e in entries)
          if (e.category != 'Kitchen' && e.category != 'Office') e.id,
      ]);
      for (final e in entries) {
        expect(e.category.toLowerCase().startsWith('room'), isFalse);
      }
      final found = await searchSymbols(tester, 'room');
      expect(ids(found), rooms);
      expect(categoriesOf(found),
          ['Dining Room', 'Bed Room', 'Living Room', 'Bathroom']);
    });
  });

  group('several terms', () {
    testWidgets('two terms are both required', (tester) async {
      await openLibrary(tester);
      final dining = ids(await searchSymbols(tester, 'dining'));
      final chair = ids(await searchSymbols(tester, 'chair'));
      expect(dining, hasLength(7));
      expect(chair, [
        kit('dining.chair@1'),
        kit('armchair@1'),
        kit('office.chair@1'),
      ]);
      // Each term alone finds more than the pair.
      expect(ids(await searchSymbols(tester, 'dining chair')),
          [kit('dining.chair@1')]);
    });

    testWidgets('the terms may hit different fields of one symbol',
        (tester) async {
      final entries = await openLibrary(tester);
      // "living" hits a category only; "couch" a tag only.
      hitsOnly(entries, 'living', 'category');
      hitsOnly(entries, 'couch', 'tag');
      expect(ids(await searchSymbols(tester, 'couch living')),
          [kit('sofa.two@1'), kit('sofa.three@1')]);
      // A pair whose terms each hit, but never the same symbol, finds none.
      expect(ids(await searchSymbols(tester, 'couch closet')), isEmpty);
      expect(await searchSymbols(tester, 'couch closet'), isEmpty);
    });

    testWidgets('runs of white space of any kind separate terms',
        (tester) async {
      await openLibrary(tester);
      expect(ids(await searchSymbols(tester, '\tdining \n  chair\t')),
          [kit('dining.chair@1')]);
    });
  });

  testWidgets('upper case in the query is ignored', (tester) async {
    await openLibrary(tester);
    expect(ids(await searchSymbols(tester, 'THREE')), [kit('sofa.three@1')]);
    expect(ids(await searchSymbols(tester, 'CoUcH')),
        [kit('sofa.two@1'), kit('sofa.three@1')]);
    expect(ids(await searchSymbols(tester, 'LIVING')),
        ids(await searchSymbols(tester, 'living')));
    expect(ids(await searchSymbols(tester, 'Dining CHAIR')),
        [kit('dining.chair@1')]);
  });

  testWidgets('an empty or blank query matches every symbol, in library order',
      (tester) async {
    final entries = await openLibrary(tester);
    final lib = furniture;
    for (final query in ['', ' ', ' \t\n  ']) {
      final all = await searchSymbols(tester, query);
      expect(ids(all), entries.map((e) => e.id).toList(), reason: '"$query"');
      expect(categoriesOf(all), lib.categories, reason: '"$query"');
      for (final g in all) {
        expect(
            g.ids.every((id) =>
                entries.singleWhere((e) => e.id == id).category == g.category),
            isTrue);
      }
    }
    expect(lib.categories, hasLength(6));
    expect(lib.entries, hasLength(41));
  });

  testWidgets('order is preserved and empty groups are hidden', (tester) async {
    await openLibrary(tester);
    final lib = furniture;
    // "table" skips Kitchen and Bathroom, which sit between categories that
    // match.
    final found = await searchSymbols(tester, 'table');
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
    expect(found.map((g) => g.ids).toList(), [
      [
        for (final id in const [
          'dining.table.square.two@2',
          'dining.table.square.four@2',
          'dining.table.rect.four@2',
          'dining.table.rect.six@2',
          'dining.table.round@2',
        ])
          kit(id),
      ],
      [kit('bed.nightstand@1')],
      [kit('table.coffee@1')],
      [
        kit('office.desk.1200@1'),
        kit('office.desk@1'),
        kit('office.desk.1600@1'),
      ],
    ]);
  });
}
