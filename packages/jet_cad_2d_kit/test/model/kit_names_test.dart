// Spec K4: a kit's words, one flat map per locale; lookup falls back from
// the locale to English, then to the library's stored English.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

final SymbolComponent sofa = SymbolComponent(
  key: 'sample.sofa.three',
  version: 3,
  name: 'Three-seat sofa',
  category: 'Living Room',
  tags: const ['sofa'],
);

const KitNames names = KitNames({
  'en': {
    'symbol:sample.sofa.three': 'Sofa for three',
    'tool:sample.wall': 'Wall',
  },
  'tr': {
    'symbol:sample.sofa.three': 'Üçlü kanepe',
    'category:sample/Living Room': 'Oturma odası',
    'category:other/Bar': 'Bar (other)',
  },
  'de': {'category:sample/Living Room': 'Wohnzimmer'},
});

void main() {
  test('W1 the word ids', () {
    expect(
        KitNames.symbolWord('sample.sofa.three'), 'symbol:sample.sofa.three');
    expect(KitNames.categoryWord('sample', 'Living Room'),
        'category:sample/Living Room');
    expect(KitNames.english, 'en');
  });

  test('W2 a symbol name: the locale, then English, then the stored name', () {
    expect(names.symbolName('tr', sofa), 'Üçlü kanepe');
    // M-W2a: skip the English map; 'de' falls to the stored name instead.
    expect(names.symbolName('de', sofa), 'Sofa for three');
    expect(KitNames.empty.symbolName('de', sofa), 'Three-seat sofa');
    // M-W2b: look up by name instead of key; nothing is found.
    expect(
        const KitNames({'fr': {}}).symbolName('fr', sofa), 'Three-seat sofa');
  });

  test('W3 a category: under its kit, the locale, then English, then itself',
      () {
    expect(names.categoryName('tr', 'sample', 'Living Room'), 'Oturma odası');
    expect(names.categoryName('de', 'sample', 'Living Room'), 'Wohnzimmer');
    expect(names.categoryName('fr', 'sample', 'Living Room'), 'Living Room');
    // M-W3: look up `category:<English>` without the kit; nothing is found.
    expect(names.categoryName('tr', 'sample', 'Bar'), 'Bar');
    expect(names.categoryName('tr', 'other', 'Bar'), 'Bar (other)');
  });

  test('W4 a word of any namespace falls back to English, else null', () {
    expect(names.word('tr', 'tool:sample.wall'), 'Wall');
    expect(names.word('tr', 'tool:sample.door'), isNull);
  });

  test('W5 merge joins locales and keeps the earlier word on a clash', () {
    const a = KitNames({
      'tr': {'symbol:a.x.y': 'A', 'category:a/Bar': 'Bar A'},
    });
    // b breaks A7 with a word under a's id; the earlier kit's word wins.
    const b = KitNames({
      'tr': {
        'symbol:b.x.y': 'B',
        'category:a/Bar': 'Bar B',
        'category:b/Bar': 'Bar',
      },
      'de': {'symbol:b.x.y': 'B de'},
    });
    final merged = a.merge(b);
    expect(merged.words['tr'], {
      'symbol:a.x.y': 'A',
      'category:a/Bar': 'Bar A', // M-W5a: the later kit wins
      'symbol:b.x.y': 'B',
      'category:b/Bar': 'Bar',
    });
    // M-W5b: take only the earlier kit's locales.
    expect(merged.words['de'], {'symbol:b.x.y': 'B de'});
    expect(KitNames.empty.merge(a).words, a.words);
  });
}
