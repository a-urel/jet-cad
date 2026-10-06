// Spec 14d L8 (M-14d-i): every entry and category of both shipped libraries
// has a German and a Turkish name, none empty, none shared by two entries of
// one category in one language, none left in English by mistake.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_floor_plan/editor.dart';
import 'package:jet_cad_floor_plan/src/symbols/furniture_names.dart';
import 'package:jet_cad_floor_plan/symbol_sources.dart' show SymbolNames;
import 'package:jet_cad_restaurant_symbols/jet_cad_restaurant_symbols.dart';

SymbolLibrary restaurant() =>
    SymbolLibrary.decode(File('assets/restaurant.jetlib').readAsBytesSync());

SymbolLibrary furniture() => SymbolLibrary.decode(
    File('../jet_cad_floor_plan/assets/library/furniture.jetlib')
        .readAsBytesSync());

/// Names that read the same in a language as in English.
const Set<String> sameInEnglish = {'Bar', 'Service', 'WC'};

void main() {
  for (final (label, library, names) in [
    ('furniture', furniture(), furnitureSymbolNames),
    ('restaurant', restaurant(), restaurantSymbolNames),
  ]) {
    test('SNL $label: every key and category in de and tr (M-14d-i)', () {
      expect(library.entries, isNotEmpty);
      for (final lang in ['de', 'tr']) {
        final byKey = names.names[lang]!;
        final byCategory = names.categories[lang]!;
        final seen = <String, Set<String>>{};
        for (final e in library.entries) {
          final n = byKey[e.key];
          expect(n, isNotNull, reason: '$lang ${e.key}');
          expect(n!.trim(), isNotEmpty, reason: '$lang ${e.key}');
          if (!sameInEnglish.contains(n)) {
            expect(n, isNot(e.name), reason: '$lang ${e.key} left in English');
          }
          expect((seen[e.category] ??= {}).add(n), isTrue,
              reason: '$lang ${e.key}: "$n" twice in ${e.category}');
          expect(byCategory[e.category], isNotNull,
              reason: '$lang ${e.category}');
        }
        expect(byKey.keys.toSet(), {for (final e in library.entries) e.key},
            reason: '$lang: no name for a key the library lacks');
      }
    });
  }

  test('SNL the restaurant source carries its names', () {
    expect(restaurantSymbolSource.names, same(restaurantSymbolNames));
    expect(furnitureSymbolSource.names, same(furnitureSymbolNames));
    expect(SymbolNames.empty.names, isEmpty);
  });
}
