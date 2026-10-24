// Sub-project 4a Task 2 (spec R1 "Words"), ported from
// packages/jet_cad_restaurant_symbols/test/symbol_names_test.dart (audit
// section 3: SNL restaurant half) and the contract's conformance test on the
// kit (pattern: jet_cad_2d_kit_architecture/test/scaffold/words_test.dart
// SC-conformance). The source-carries-its-names case is DROPPED in the audit
// (a source carries no names now; PlanKit.names does). Also the audit's SC3
// premise (section 2) and RL3's source label (section 1).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/authoring.dart' show KitProblemCode, conformance;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit_restaurant/jet_cad_2d_kit_restaurant.dart';
import 'package:jet_cad_2d_kit_restaurant/src/catalog/restaurant_catalog.dart';
import 'package:jet_cad_2d_kit_restaurant/src/restaurant_names.dart'
    show restaurantSameAsEnglish;

SymbolLibrary assetLibrary() => SymbolLibrary.decode(
    File('assets/library/restaurant.jetlib').readAsBytesSync());

List<KitProblem> problems() => conformance(
      catalog: restaurantCatalog,
      committedLibrary:
          File('assets/library/restaurant.jetlib').readAsBytesSync(),
      committedSnapshot:
          File('assets/library/restaurant.snapshot.json').readAsStringSync(),
      names: restaurantKit.names,
      locales: const ['de', 'tr'],
      sameAsEnglish: restaurantSameAsEnglish,
      typeIds: restaurantKit.types.map((t) => t.id),
      toolIds: restaurantKit.tools.map((t) => t.id),
      propertyIds: restaurantKit.propertyIds,
    );

void main() {
  test('the kit is the contract\'s: id, version, one source, no code side', () {
    expect(restaurantKit.id, 'restaurant');
    expect(restaurantKit.version, '0.1.1');
    expect(restaurantKit.validate(), isEmpty);
    expect(restaurantKit.symbols, [same(restaurantSymbolSource)]);
    expect(restaurantKit.names, same(restaurantNames));
    expect(restaurantKit.types, isEmpty);
    expect(restaurantKit.tools, isEmpty);
    expect(restaurantKit.propertyIds, isEmpty);
    expect(restaurantKit.attachments, isEmpty);
  });

  test('RL3 the source is labelled restaurant', () {
    expect(restaurantSymbolSource.label, 'restaurant');
  });

  test(
      'SC-conformance the kit conforms: catalog, committed library and '
      'snapshot, German and Turkish complete', () {
    final found = problems();
    expect(found, isEmpty, reason: found.join('\n'));
  });

  test('conformance sees a German name removed (wordMissing)', () {
    final words = {
      for (final e in restaurantNames.words.entries) e.key: {...e.value},
    };
    words['de']!.remove('symbol:restaurant.bar.counter');
    final found = conformance(
      catalog: restaurantCatalog,
      committedLibrary:
          File('assets/library/restaurant.jetlib').readAsBytesSync(),
      committedSnapshot:
          File('assets/library/restaurant.snapshot.json').readAsStringSync(),
      names: KitNames(words),
      locales: const ['de', 'tr'],
      sameAsEnglish: restaurantSameAsEnglish,
    );
    expect(found.map((p) => p.code), [KitProblemCode.wordMissing],
        reason: found.join('\n'));
  });

  test(
      'SNL every key and category has a de and tr word, none empty, none '
      'shared by two entries of one category, none left in English', () {
    final lib = assetLibrary();
    expect(lib.entries, hasLength(69));
    for (final lang in ['de', 'tr']) {
      final words = restaurantNames.words[lang]!;
      final seen = <String, Set<String>>{};
      for (final e in lib.entries) {
        final n = words[KitNames.symbolWord(e.symbol.key)];
        expect(n, isNotNull, reason: '$lang ${e.symbol.key}');
        expect(n!.trim(), isNotEmpty, reason: '$lang ${e.symbol.key}');
        expect(n, isNot(e.symbol.name),
            reason: '$lang ${e.symbol.key} left in English');
        expect((seen[e.symbol.category] ??= {}).add(n), isTrue,
            reason: '$lang ${e.symbol.key}: "$n" twice in '
                '${e.symbol.category}');
      }
      for (final c in restaurantCategories) {
        final n = words[KitNames.categoryWord('restaurant', c)];
        expect(n, isNotNull, reason: '$lang $c');
        expect(n!.trim(), isNotEmpty, reason: '$lang $c');
        if (!restaurantSameAsEnglish[lang]!
            .contains(KitNames.categoryWord('restaurant', c))) {
          expect(n, isNot(c), reason: '$lang $c left in English');
        }
      }
      // Exactly the library's words: 69 symbols and 6 categories.
      expect(words, hasLength(69 + 6), reason: lang);
    }
  });

  test(
      'SC3 premise: the corner booth\'s base point is not its box\'s '
      'centre x, so the demo\'s turn-and-mirror test is not degenerate', () {
    final e = assetLibrary()
        .entries
        .firstWhere((e) => e.symbol.key == 'restaurant.booth.corner');
    var minX = double.infinity, maxX = -double.infinity;
    for (final l in e.leaves) {
      for (var i = 0; i < l.payload.pointCount; i++) {
        final x = l.payload.pointAt(i).x;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
      }
    }
    expect(e.definition.basePoint.x, isNot((minX + maxX) / 2));
  });
}
