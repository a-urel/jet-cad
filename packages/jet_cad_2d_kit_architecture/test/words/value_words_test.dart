// Ported from jet_cad_floor_plan/test/l10n/value_words_test.dart: VW3's
// Room-notice line (3a Task 27, Appendix A D-24; VW3's other lines are
// 2a's and 2b's), assertions unchanged. The notice is the kit's text
// `text:architecture.room-occupied` with `{name}` (spec C1.2, C1.6),
// worded in each language by `KitWords.text`.
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';

final List<KitWords> languages = [
  for (final code in ['en', 'de', 'tr'])
    KitNamesWords(architectureKit.names, () => Locale(code)),
];

/// [word] in each language: never empty, holding every [parts], and
/// different in each language (value_words_test.dart:28-39).
void expectWorded(String Function(KitWords s) word,
    {List<String> parts = const [], String? english}) {
  final words = [for (final s in languages) word(s)];
  for (final (i, w) in words.indexed) {
    expect(w, isNotEmpty);
    for (final p in parts) {
      expect(w, contains(p), reason: '${languages[i].locale}: $w');
    }
  }
  expect(words.toSet(), hasLength(3), reason: '$words');
  if (english != null) expect(words.first, english);
}

void main() {
  test('VW3 the Room notice in each language', () {
    expectWorded(
        (s) => s.text('text:architecture.room-occupied', {'name': 'Mutfak'}),
        parts: ['Mutfak'],
        english: 'Already a room: Mutfak');
  });
}
