// Spec 3a C2 "Words", C1.6: the kit's words. Every locale holds exactly the
// plan's word table (symbol and category words, Task 23's, aside); each
// text: word keeps English's placeholders and fills them; the kit validates,
// and conformance (A16) holds German and Turkish complete over every
// code-side word, the descriptor's and the table's.
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/authoring.dart'
    show Catalog, conformance, encodeLibrary, encodeSnapshot, geometrySnapshot;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_kit_architecture/src/words/words.dart';

/// The 3a plan's "Word ids" table, written out (55 ids).
const Set<String> wordTable = {
  'tool:architecture.box',
  'tool:architecture.wall',
  'tool:architecture.door',
  'tool:architecture.window',
  'tool:architecture.gap',
  'tool:architecture.room',
  'tool:architecture.separator',
  'tool:architecture.dimension',
  'type:architecture.box',
  'type:architecture.wall',
  'type:architecture.opening',
  'type:architecture.separator',
  'type:architecture.room',
  'type:architecture.dimension',
  'property:architecture.box.width',
  'property:architecture.box.height',
  'property:architecture.wall.thickness',
  'property:architecture.wall.justification',
  'property:architecture.wall.justification.left',
  'property:architecture.wall.justification.centre',
  'property:architecture.wall.justification.right',
  'property:architecture.opening.width',
  'property:architecture.opening.position',
  'property:architecture.opening.flip-hinge',
  'property:architecture.opening.flip-swing',
  'property:architecture.room.name',
  'property:architecture.room.area',
  'property:architecture.dimension.value',
  'property:architecture.dimension.kind',
  'property:architecture.dimension.kind.aligned',
  'property:architecture.dimension.kind.horizontal',
  'property:architecture.dimension.kind.vertical',
  'property:architecture.dimension.axes',
  'property:architecture.dimension.end-1',
  'property:architecture.dimension.end-2',
  'property:architecture.door.width',
  'property:architecture.window.width',
  'property:architecture.gap.width',
  'text:architecture.room-name',
  'text:architecture.room-occupied',
  'text:architecture.axes-turned',
  'text:architecture.end-on-wall',
  'text:architecture.end-start',
  'text:architecture.end-end',
  'text:architecture.end-fixed',
  'text:architecture.face-left',
  'text:architecture.face-centre',
  'text:architecture.face-right',
  'text:architecture.dimension-value',
  'text:architecture.sample-hall',
  'text:architecture.sample-kitchen',
  'text:architecture.sample-bath',
  'text:architecture.sample-living',
  'text:architecture.sample-dining',
  'text:architecture.sample-bedroom',
};

/// [locale]'s word ids, less the catalog's (symbol, category).
Set<String> codeWords(String locale) => {
      for (final id in architectureNames.words[locale]!.keys)
        if (!id.startsWith('symbol:') && !id.startsWith('category:')) id,
    };

void main() {
  test(
      'SC-words English, German and Turkish each hold exactly the plan\'s '
      'word table', () {
    expect(wordTable, hasLength(55), reason: 'premise: the table');
    expect(architectureNames.words.keys.toSet(), {'en', 'de', 'tr'});
    for (final locale in ['en', 'de', 'tr']) {
      // M-SC-3: a word deleted from one locale.
      expect(codeWords(locale), wordTable, reason: locale);
    }
  });

  test(
      'SC-text each text: word keeps English\'s placeholders in German and '
      'Turkish, and KitWords fills them as today\'s strings did', () {
    final en = architectureNames.words['en']!;
    for (final locale in ['de', 'tr']) {
      final words = architectureNames.words[locale]!;
      for (final id in wordTable.where((id) => id.startsWith('text:'))) {
        // M-SC-4: a placeholder renamed in one locale.
        expect(placeholdersOf(words[id]!), placeholdersOf(en[id]!),
            reason: '$locale: $id');
      }
    }
    expect(placeholdersOf(en['text:architecture.end-on-wall']!),
        {'wall', 'end', 'side'});
    expect(placeholdersOf(en['text:architecture.sample-bedroom']!), {'n'});
    final tr = KitNamesWords(architectureNames, () => const Locale('tr'));
    // Today's strings_tr.dart:60 and :306-307.
    expect(tr.text('text:architecture.room-occupied', {'name': 'Oda 1'}),
        'Zaten bir oda: Oda 1');
    expect(
        tr.text('text:architecture.end-on-wall', {
          'wall': '1F',
          'end': tr.text('text:architecture.end-start'),
          'side': tr.text('text:architecture.face-left'),
        }),
        'Duvar 1F, başlangıç, sol yüzey');
    final de = KitNamesWords(architectureNames, () => const Locale('de'));
    // Today's strings_de.dart:304.
    expect(de.text('text:architecture.axes-turned', {'degrees': '12,5'}),
        'Achsen um 12,5° gedreht');
  });

  test(
      'SC-conformance the kit validates, and conformance over the empty '
      'catalog holds German and Turkish complete for every code-side word', () {
    expect(architectureKit.validate(), isEmpty);
    const catalog = Catalog(kit: 'architecture', symbols: []);
    final english = architectureNames.words['en']!.keys;
    Set<String> ids(String namespace) => {
          for (final id in english)
            if (id.startsWith('$namespace:'))
              id.substring(namespace.length + 1),
        };
    final problems = conformance(
      catalog: catalog,
      committedLibrary: encodeLibrary(catalog),
      committedSnapshot: encodeSnapshot(geometrySnapshot(catalog)),
      names: architectureNames,
      locales: const ['de', 'tr'],
      sameAsEnglish: architectureSameAsEnglish,
      typeIds: {...ids('type'), for (final t in architectureKit.types) t.id},
      toolIds: {...ids('tool'), for (final t in architectureKit.tools) t.id},
      propertyIds: {...ids('property'), ...architectureKit.propertyIds},
    );
    // M-SC-3 and M-SC-4 are red here too (wordMissing, placeholderMismatch).
    expect(problems, isEmpty);
  });
}
