// Spec 3a C1.6, C2, umbrella A16: conformance holds a kit's `text:` words
// to its declared locales, like its code-side words, and asks every
// locale's text to carry English's placeholders. Over the sample kit, its
// words grown by three texts.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/authoring.dart';

import '../fixtures/sample_kit/sample_kit.dart';

const String dir = 'test/fixtures/sample_kit';

const KitNames texts = KitNames({
  'en': {
    'text:sample.seated': 'Table {name} seats {n}',
    'text:sample.free': 'Free',
    'text:sample.value': '{value}',
  },
  'de': {
    'text:sample.seated': 'Tisch {name} hat {n} Plätze',
    'text:sample.free': 'Frei',
    'text:sample.value': '{value}',
  },
  'tr': {
    'text:sample.seated': '{name} masası {n} kişilik',
    'text:sample.free': 'Boş',
    'text:sample.value': '{value}',
  },
});

/// A lone value reads the same in every language.
const Map<String, Set<String>> sameAsEnglish = {
  'de': {'category:sample/Bar', 'text:sample.value'},
  'tr': {'category:sample/Bar', 'text:sample.value'},
};

List<KitProblem> problems(KitNames names,
        {Map<String, Set<String>> same = sameAsEnglish}) =>
    conformance(
      catalog: sampleCatalog,
      committedLibrary:
          Uint8List.fromList(File('$dir/sample.jetlib').readAsBytesSync()),
      committedSnapshot: File('$dir/sample_snapshot.json').readAsStringSync(),
      names: names,
      locales: sampleLocales,
      sameAsEnglish: same,
    );

List<KitProblemCode> codes(List<KitProblem> problems) =>
    [for (final p in problems) p.code];

/// [texts] with [locale]'s [id] replaced by [word].
KitNames textsWith(String locale, String id, String? word) => KitNames({
      for (final MapEntry(key: l, value: map) in texts.words.entries)
        l: {
          for (final MapEntry(key: k, value: v) in map.entries)
            if (!(l == locale && k == id)) k: v,
          if (l == locale && word != null) id: word,
        },
    });

void main() {
  test('KW-conf the sample kit with its texts conforms', () {
    expect(problems(sampleNames.merge(texts)), isEmpty);
  });

  test(
      'KW-conf-placeholders a locale\'s text that drops, adds or renames a '
      'placeholder is one problem naming both sets (M-KW-conf-placeholders)',
      () {
    for (final (locale, word) in [
      ('tr', '{name} masası'), // drops {n}
      ('de', 'Tisch {name} hat {n} Plätze ({extra})'), // adds one
      ('tr', '{ad} masası {n} kişilik'), // renames {name}
    ]) {
      final found = problems(
          sampleNames.merge(textsWith(locale, 'text:sample.seated', word)));
      // M-KW-conf-placeholders: the check dropped.
      expect(codes(found), [KitProblemCode.placeholderMismatch],
          reason: '$locale $word');
      expect(found.single.message, startsWith('$locale: '));
      expect(found.single.message, contains('text:sample.seated'));
    }
  });

  test(
      'KW-conf-complete a declared locale missing a text, or giving its '
      'English unasked, is reported like any word (M-KW-conf-complete)', () {
    // M-KW-conf-complete: the kit's text words not added to the words the
    // locales must have.
    expect(
        codes(problems(
            sampleNames.merge(textsWith('de', 'text:sample.free', null)))),
        [KitProblemCode.wordMissing]);
    expect(
        codes(problems(
            sampleNames.merge(textsWith('tr', 'text:sample.free', 'Free')))),
        [KitProblemCode.wordUntranslated]);
    expect(codes(problems(sampleNames.merge(texts), same: sampleSameAsEnglish)),
        [KitProblemCode.wordUntranslated, KitProblemCode.wordUntranslated]);
  });
}
