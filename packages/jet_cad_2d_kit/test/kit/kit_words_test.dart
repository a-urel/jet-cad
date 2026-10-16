// Spec 3a C1.6: a kit's words with parameters: KitWords.text fills a
// `text:` word in the locale; KitWords.decimalSeparator is the UI
// language's, read live; PlanKit.validate and validateHostWords accept the
// `text:` namespace.
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show DraftDocument, Handle;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

const KitNames words = KitNames({
  'en': {
    'text:test.busy': 'Already a room: {name}',
    'text:test.ends': '{wall} {end} ({side})',
    'tool:test.slab': 'Slab',
  },
  'tr': {'text:test.busy': 'Zaten bir oda: {name}'},
});

List<KitProblemCode> codes(List<KitProblem> problems) =>
    [for (final p in problems) p.code];

void main() {
  test(
      'KW-words text fills the word of the locale, else English; a missing '
      'word is its id (M-KW-args)', () {
    var locale = const Locale('tr');
    final w = KitNamesWords(words, () => locale);
    // M-KW-args: `text` returning `word(id)` unfilled.
    expect(w.text('text:test.busy', {'name': 'Oda 3'}), 'Zaten bir oda: Oda 3');
    expect(w.text('text:test.ends', {'wall': '7A', 'end': 'end', 'side': 'x'}),
        '7A end (x)');
    locale = const Locale('en');
    expect(
        w.text('text:test.busy', {'name': 'Room 3'}), 'Already a room: Room 3');
    expect(w.text('text:test.none', {'name': 'x'}), 'text:test.none');
    expect(w.text('text:test.busy'), 'Already a room: {name}');
  });

  test(
      'KW-separator the decimal separator is read at each call, from the '
      'given closure; "." without one (M-KW-separator)', () {
    var separator = ',';
    final w = KitNamesWords(words, () => const Locale('de'),
        decimalSeparator: () => separator);
    expect(w.decimalSeparator, ',');
    // M-KW-separator: the closure read once, in the constructor.
    separator = '.';
    expect(w.decimalSeparator, '.');
    expect(
        KitNamesWords(words, () => const Locale('tr')).decimalSeparator, '.');
  });

  test(
      'PO-words-separator a text display reads the UI separator through its '
      'object\'s words (rulings R-P4, R-P7: the dimension\'s axes line) '
      '(M-KW-separator, M-KW-plan-words)', () {
    final doc = DraftDocument.empty();
    addTearDown(doc.dispose);
    final PlanWords words = KitNamesWords(
        KitNames.empty, () => const Locale('de'),
        decimalSeparator: () => ',');
    final field = TextDisplay<double>(
            id: 'degrees',
            read: (v, o) =>
                v.toStringAsFixed(1).replaceAll('.', o.words.decimalSeparator))
        .bind(12.5,
            wordId: 'property:test.slab.degrees',
            object: DocumentPlanObject(doc, const Handle(0x4C1), words));
    expect(field.value, '12,5');
    // Through the pure interface, as a kit's property reads it.
    expect(words.text('text:test.none', {'n': 1}), 'text:test.none');
  });

  test(
      'KW-validate a kit\'s text words: under the kit and in English, sound; '
      'under another kit or none, foreign; without English, missing '
      '(M-KW-validate, M-KW-validate-en)', () {
    // M-KW-validate: `text` left out of the namespaces (unknownWordId).
    expect(const PlanKit(id: 'test', version: '1.0.0', names: words).validate(),
        isEmpty);
    for (final id in ['text:other.busy', 'text:test', 'text:busy']) {
      final kit = PlanKit(
          id: 'test',
          version: '1.0.0',
          names: KitNames({
            'en': {id: 'x'},
          }));
      expect(codes(kit.validate()), [KitProblemCode.foreignWordId], reason: id);
    }
    // M-KW-validate-en: a text word asked no English.
    const turkishOnly = PlanKit(
        id: 'test',
        version: '1.0.0',
        names: KitNames({
          'tr': {'text:test.busy': 'Zaten bir oda: {name}'},
        }));
    expect(codes(turkishOnly.validate()), [KitProblemCode.missingEnglish]);
  });

  test(
      'KW-host a host may word any kit\'s texts; a text id that names no '
      'kit is foreign (M-KW-host)', () {
    // M-KW-host: `text` left out of validateHostWords' namespaces.
    expect(
        validateHostWords(const KitNames({
          'tr': {'text:architecture.room-occupied': 'Zaten oda: {name}'},
          'de': {'text:acme.note': 'Notiz'},
        })),
        isEmpty);
    for (final id in ['text:Acme.note', 'text:acme', 'text:']) {
      expect(
          codes(validateHostWords(KitNames({
            'de': {id: 'x'},
          }))),
          [KitProblemCode.foreignWordId],
          reason: id);
    }
  });
}
