### Task 3: Words with parameters (spec C1.6)

**Files:**
- Create (`packages/jet_cad_2d_kit/`): `lib/src/model/kit_text.dart`, `lib/src/model/numbered_names.dart`, `test/model/kit_text_test.dart`, `test/model/numbered_names_test.dart`, `test/kit/kit_words_test.dart`, `test/authoring/text_words_conformance_test.dart`
- Modify (`packages/jet_cad_2d_kit/`): `lib/src/model/model.dart` (two exports), `lib/src/model/kit_problem.dart` (`placeholderMismatch`), `lib/src/model/plan_words.dart` (`PlanWords.text`, `decimalSeparator`: ruling R-P7, Task 2 made the interface), `lib/src/kit/plan_services.dart` (`KitNamesWords` implements them; `KitNamesWords(decimalSeparator:)`), `lib/src/kit/plan_kit.dart` and `lib/src/kit/host_words.dart` (the `text:` namespace), `lib/src/authoring/conformance.dart` (text words held to the locales; placeholders)
- Modify (`packages/jet_cad_2d_plan/`): `lib/src/controller/plan_controller.dart` (the separator the kits' words read), `lib/src/l10n/numbered_names.dart` (over the contract's)
- Create (`packages/jet_cad_2d_plan/`): `test/controller/kit_words_controller_test.dart`
- Modify: `docs/kits.md` (§5's table, §8's conformance paragraph), `docs/superpowers/specs/2026-10-13-kit-contract-design.md` (two lines in Task 1's section)

**Interfaces:**
- Consumes:
  - Task 2: `KitProblemCode.settingsNeedObject` is the last code; this task adds `placeholderMismatch` after it. `PlanWords` (`lib/src/model/plan_words.dart`, `word` and `maybe`), `KitWords implements PlanWords`, `PlanObject.words` (a `PlanWords`), `DocumentPlanObject(document, handle, words)`, `TextDisplay` (rulings R-P4, R-P7).
  - Contract today: `KitWords`/`KitNamesWords` (`kit/plan_services.dart:17-46`), `KitNames.word`/`merge` (`model/kit_names.dart:35-52`; `merge` keeps the receiver's word first), `PlanKit.validate`'s namespace switch (`kit/plan_kit.dart:80-95`), `validateHostWords` (`kit/host_words.dart:17-43`), `conformance`'s `_wordProblems` (`authoring/conformance.dart:208-271`), `kitOfKey` (`model/kit_ids.dart:31-34`).
  - Plan library today: `PlanController.planStrings` (`plan_controller.dart:606-607`, the reported class else the built-in language), the services' words (`:355-359`), `numberedNameIndex` (`l10n/numbered_names.dart:15-32`) and its one caller (`panels/plan_layer_panel.dart:47`).
- Produces (Shared interfaces, exact):

```dart
// lib/src/model/kit_text.dart (pure Dart; both libraries export it)
@immutable final class KitText {
  const KitText(this.id, [this.args = const {}]);
  final String id;                    // 'text:<kit>.<id>'
  final Map<String, Object> args;     // == and hashCode by value
}
String fillText(String template, Map<String, Object> args); // '{name}' → '${args['name']}'; missing left as written
Set<String> placeholdersOf(String template);
// lib/src/model/plan_words.dart (Task 2 made it; ruling R-P7: these two land on PlanWords, so
// KitWords, which implements PlanWords, has them too, and a PlanObject's words reach them)
abstract interface class PlanWords {
  String word(String wordId); String? maybe(String wordId);        // Task 2
  String text(String id, [Map<String, Object> args = const {}]); // NEW: fillText over word(id)
  String get decimalSeparator;                                     // NEW: the UI language's
}
// lib/src/kit/plan_services.dart: abstract interface class KitWords implements PlanWords { Locale get locale; } (Task 2)
final class KitNamesWords implements KitWords {
  KitNamesWords(KitNames names, Locale Function() locale,
      {String Function()? decimalSeparator}); // default '.'
}
// lib/src/model/numbered_names.dart (pure Dart; both libraries export it)
int? numberedNameIndex(String name, Iterable<String Function(int n)> patterns,
    {String Function(String)? fold});
// lib/src/model/kit_problem.dart
enum KitProblemCode { /* existing */ settingsNeedObject, placeholderMismatch }
// jet_cad_2d_plan: the KitWords the plan builds carry decimalSeparator from the current PlanStrings.
```

**Appendix A rows closed:** D-25's contract half (the `text:` namespace, placeholders and the separator the architecture words need; the words themselves are Task 9's). Old test files: none (the plan's `numbered_names_test.dart` NN2 and W-NN4 stay green unchanged over the rewrite; NN3 is Task 27's).

Plan decisions:
- **The placeholder pattern** is `{` + a letter, then letters and digits + `}` (`\{([A-Za-z][A-Za-z0-9]*)\}`): every placeholder the 3a plan's word table names (`{n}`, `{name}`, `{degrees}`, `{wall}`, `{end}`, `{side}`, `{value}`) fits, and a brace in running text (`{ x }`, `{}`, `{2}`) is left alone. An argument is put in with `'$value'`; one the template does not name is ignored; a placeholder with no argument is left as written (spec C1.6).
- **`text:` ids are held like a tool's.** In `validate` and `validateHostWords` a `text:` id names its kit before its first `.` (`text:architecture.room-name`), as `tool:`, `type:` and `property:` do; `validate` asks English for every `text:` word under the kit (`missingEnglish`), since a text has no stored English.
- **Conformance holds a kit's `text:` words to its declared locales** (A16, spec C2: "the conformance test checks every locale complete"): every English `text:<kit>.<id>` is added to the words each declared locale must have (`wordMissing`, and `wordUntranslated` unless `sameAsEnglish` lists it, exactly as a code-side word since R3, `conformance.dart:244-253`). A text that is the same in every language (a lone `{value}`) is listed in `sameAsEnglish` by its kit. Then, for every locale's `text:` word whose id has English, the placeholder sets must be equal (`placeholderMismatch`, one problem per word, naming both sets). Task 9 relies on both rules for the architecture words.
- **The plan's separator.** `KitNamesWords` reads its `decimalSeparator` live, like its locale: the plan passes `() => planStrings.decimalSeparator`, so a language switch (or a host's own `PlanStrings`, `reportLocale(strings:)`) changes it at once.
- **The plan's `numberedNameIndex` keeps its signature** (its tests stay unchanged, and `plan_layer_panel.dart:47` keeps calling it): it hands the contract's function one pattern per `PlanStrings` (the current one, then English, German, Turkish, today's order), importing the contract under a prefix so the two names never meet.
- **2a P5:** checked; it does not name the word namespaces (`2026-10-14-plan-library-design-mode-design.md:626-634`), so no 2a line. The contract spec gets the K4 line and the surface line.
- **CHANGELOG:** Task 29.

- [ ] **Step 1: Precondition.** Task 2 is committed. Run `cd packages/jet_cad_2d_kit && flutter test test/kit/ test/authoring/` and `cd packages/jet_cad_2d_plan && flutter test test/l10n/numbered_names_test.dart`. Expected: `All tests passed!`.

- [ ] **Step 2: The failing contract tests.**
  1. Create `packages/jet_cad_2d_kit/test/model/kit_text_test.dart`:

```dart
// Spec 3a C1.6, C1.2: a word id and its arguments (KitText), put into
// words when read; a template's placeholders filled (fillText) and listed
// (placeholdersOf). Pure Dart, like the rest of the model.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/authoring.dart' as authoring
    show KitText, fillText, numberedNameIndex, placeholdersOf;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

void main() {
  test(
      'KW-fill every placeholder that has an argument is filled, each time '
      'it appears; one without is left as written; an unused argument is '
      'ignored (M-KW-missing, M-KW-first)', () {
    expect(fillText('Already a room: {name}', {'name': 'Oda 3'}),
        'Already a room: Oda 3');
    expect(
        fillText('{wall} {end} ({side}), {wall}',
            {'wall': '7A', 'end': 'start', 'side': 'left face', 'n': 4}),
        '7A start (left face), 7A');
    // M-KW-missing: a missing argument filled as ''.
    expect(fillText('Bedroom {n} of {count}', {'n': 2}), 'Bedroom 2 of {count}');
    // A non-String argument is printed with its toString.
    expect(fillText('{degrees}°', {'degrees': 12.5}), '12.5°');
    // Braces that are no placeholder.
    expect(fillText('{ name } {} {2} {name', {'name': 'x'}),
        '{ name } {} {2} {name');
    expect(fillText('Yatak odası {n}', const {'n': 1}), 'Yatak odası 1');
    expect(fillText('No placeholder', {'name': 'x'}), 'No placeholder');
  });

  test('KW-placeholders the set of names a template holds', () {
    // M-KW-placeholders: placeholdersOf answers an empty set.
    expect(placeholdersOf('{wall} {end} ({side}), {wall}'),
        {'wall', 'end', 'side'});
    expect(placeholdersOf('{ name } {} {2}'), isEmpty);
    expect(placeholdersOf('Raum {n}'), {'n'});
  });

  test(
      'KW-text KitText equals by its id and its arguments, whatever their '
      'order; any other id or value differs (M-KW-eq)', () {
    final a = KitText('text:test.busy', {'name': 'Slab 1', 'n': 2});
    final b = KitText('text:test.busy', {'n': 2, 'name': 'Slab 1'});
    // M-KW-eq: `==` comparing the maps by identity.
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(KitText('text:test.busy', {'name': 'Slab 2', 'n': 2})));
    expect(a, isNot(KitText('text:test.free', {'name': 'Slab 1', 'n': 2})));
    expect(a, isNot(const KitText('text:test.busy', {'name': 'Slab 1'})));
    expect(const KitText('text:test.idle').args, isEmpty);
  });

  test(
      'KW-barrels the authoring library exports KitText, fillText, '
      'placeholdersOf and numberedNameIndex (pure Dart)', () {
    // A premise of the export list, exempt from the mutation rule beyond
    // M-KW-export: without it this file does not compile.
    expect(identical(authoring.fillText, fillText), isTrue);
    expect(identical(authoring.placeholdersOf, placeholdersOf), isTrue);
    expect(identical(authoring.numberedNameIndex, numberedNameIndex), isTrue);
    expect(const authoring.KitText('text:a.b'), const KitText('text:a.b'));
  });
}
```

  2. Create `packages/jet_cad_2d_kit/test/model/numbered_names_test.dart`:

```dart
// Spec 3a C1.6: numbered names in the contract, over patterns that name no
// plan type. A room tool passes one pattern per locale of its words; the
// plan's layer panel one per built-in language and the current one.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

String room(int n) => 'Room $n';
String raum(int n) => 'Raum $n';
String oda(int n) => 'Oda $n';

void main() {
  test(
      'KW-numbered the n of a name made by any of the patterns, compared by '
      'the fold (M-KW-first-pattern, M-KW-fold)', () {
    final patterns = [room, raum, oda];
    expect(numberedNameIndex('Room 4', patterns), 4);
    // M-KW-first-pattern: only the first pattern compared.
    expect(numberedNameIndex('Oda 12', patterns), 12);
    expect(numberedNameIndex('Raum 3', patterns), 3);
    // Folded: the fold given meets a case difference, on both sides.
    // M-KW-fold: the fold applied to the name only.
    expect(numberedNameIndex('ODA 7', patterns, fold: (s) => s.toLowerCase()),
        7);
    expect(numberedNameIndex('ODA 7', patterns), isNull);
  });

  test('KW-numbered-shape a name of another shape takes no n', () {
    for (final name in ['Room 0', 'Room 2 ', 'Room', 'Raum 2a', 'Hall 3', '']) {
      expect(numberedNameIndex(name, [room, raum, oda]), isNull,
          reason: name);
    }
    expect(numberedNameIndex('Room 3', const []), isNull);
  });
}
```

  3. Create `packages/jet_cad_2d_kit/test/kit/kit_words_test.dart`:

```dart
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
    expect(w.text('text:test.busy', {'name': 'Room 3'}),
        'Already a room: Room 3');
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
    expect(KitNamesWords(words, () => const Locale('tr')).decimalSeparator,
        '.');
  });

  test(
      'PO-words-separator a text display reads the UI separator through its '
      'object\'s words (rulings R-P4, R-P7: the dimension\'s axes line) '
      '(M-KW-separator, M-KW-plan-words)', () {
    final doc = DraftDocument.empty();
    addTearDown(doc.dispose);
    final PlanWords words = KitNamesWords(KitNames.empty, () => const Locale('de'),
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
      expect(codes(kit.validate()), [KitProblemCode.foreignWordId],
          reason: id);
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
```

  4. Create `packages/jet_cad_2d_kit/test/authoring/text_words_conformance_test.dart`:

```dart
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
    expect(
        codes(problems(sampleNames.merge(texts), same: sampleSameAsEnglish)),
        [KitProblemCode.wordUntranslated, KitProblemCode.wordUntranslated]);
  });
}
```

  Run `cd packages/jet_cad_2d_kit && flutter test test/model/kit_text_test.dart test/model/numbered_names_test.dart test/kit/kit_words_test.dart test/authoring/text_words_conformance_test.dart`. Expected: compilation fails (`Method not found: 'fillText'`, `Undefined name 'KitText'`, `The method 'text' isn't defined for the type 'KitNamesWords'`, ...).

- [ ] **Step 3: The contract.**
  1. Create `packages/jet_cad_2d_kit/lib/src/model/kit_text.dart`:

```dart
// A kit's words with parameters (spec 3a C1.6): a `text:<kit>.<id>` word is
// a template whose `{name}` placeholders are filled when it is read, so a
// tool's notice (C1.2) is a word id and its arguments, put into words in
// the language of the moment.
//
// Pure Dart: no Flutter, no dart:io.
import 'package:meta/meta.dart';

/// A placeholder: `{`, a letter, then letters and digits, `}`.
final RegExp _placeholder = RegExp(r'\{([A-Za-z][A-Za-z0-9]*)\}');

/// A word id and its arguments, put into words when read
/// (`KitWords.text`). Equal by its id and its arguments' values, whatever
/// their order.
@immutable
final class KitText {
  const KitText(this.id, [this.args = const {}]);

  /// `text:<kit>.<id>`.
  final String id;

  /// The values of the word's placeholders, by name.
  final Map<String, Object> args;

  @override
  bool operator ==(Object other) {
    if (other is! KitText || other.id != id) return false;
    final theirs = other.args;
    if (theirs.length != args.length) return false;
    for (final MapEntry(:key, :value) in args.entries) {
      if (!theirs.containsKey(key) || theirs[key] != value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
      id,
      Object.hashAllUnordered(
          [for (final e in args.entries) Object.hash(e.key, e.value)]));

  @override
  String toString() => 'KitText($id, $args)';
}

/// [template] with each placeholder `{name}` that [args] has replaced by
/// `'${args[name]}'`; a placeholder without an argument is left as
/// written, an argument the template does not name is ignored.
String fillText(String template, Map<String, Object> args) =>
    template.replaceAllMapped(_placeholder, (m) {
      final value = args[m[1]!];
      return value == null ? m[0]! : '$value';
    });

/// The names of [template]'s placeholders.
Set<String> placeholdersOf(String template) =>
    {for (final m in _placeholder.allMatches(template)) m[1]!};
```

  2. Create `packages/jet_cad_2d_kit/lib/src/model/numbered_names.dart`:

```dart
// Names a plan writes once and counts (spec 14d L7, moved into the
// contract by 3a C1.6): a new layer's `Layer n`, a new room's `Room n`, in
// the language of the moment, the lowest free `n` counted over every
// language's name, so a plan edited in two languages never gets `Room 3`
// and `Oda 3`. The patterns name no plan type: a kit passes one per locale
// of its words, the plan library one per built-in language.
//
// Pure Dart: no Flutter, no dart:io.

final RegExp _numbered = RegExp(r'^(.*) ([1-9][0-9]*)$');

/// The `n` of [name] when [name] is one of [patterns] at `n`, compared by
/// [fold] (none: exactly); otherwise null. `n` is a positive integer
/// written without a leading zero, after a space, at the end.
int? numberedNameIndex(String name, Iterable<String Function(int n)> patterns,
    {String Function(String)? fold}) {
  final m = _numbered.firstMatch(name);
  if (m == null) return null;
  final n = int.tryParse(m[2]!);
  if (n == null) return null;
  final f = fold ?? _same;
  final folded = f(name);
  for (final pattern in patterns) {
    if (f(pattern(n)) == folded) return n;
  }
  return null;
}

String _same(String s) => s;
```

  3. `lib/src/model/model.dart`: add `export 'kit_text.dart';` after `export 'kit_problem.dart';` and `export 'numbered_names.dart';` after `export 'manifest_component.dart';`.
  4. `lib/src/model/kit_problem.dart`: after `settingsNeedObject,` (Task 2) add:

```dart

  // Spec 3a C1.6: conformance, a locale's `text:` word whose placeholders
  // are not English's.
  placeholderMismatch,
```

  5. Ruling R-P7: `lib/src/model/plan_words.dart` (Task 2's) — `PlanWords` gains, after `maybe` (no import: an interface):

```dart

  /// The text [id] (a `text:<kit>.<id>` word) in the locale, else in
  /// English, else [id] itself, its `{name}` placeholders filled from
  /// [args] (spec 3a C1.6): `fillText(word(id), args)`.
  String text(String id, [Map<String, Object> args = const {}]);

  /// The decimal separator of the UI language (`.` or `,`), for a number a
  /// kit prints in the UI's words (a dimension's axes line). A number that
  /// follows the page (an area, a dimension's value) reads the page's.
  String get decimalSeparator;
```

     `lib/src/kit/plan_services.dart`: add `import '../model/kit_text.dart';` after the `kit_names.dart` import (for `fillText`); `KitWords` is unchanged (it inherits both from `PlanWords`). `KitNamesWords` becomes:

```dart
/// [KitWords] over a kit's [names], at the locale [locale] answers each
/// time it is read: a change of the plan's language shows at once. The
/// separator is [decimalSeparator]'s answer at each read, `.` without one.
final class KitNamesWords implements KitWords {
  KitNamesWords(this.names, Locale Function() locale,
      {String Function()? decimalSeparator})
      : _locale = locale,
        _separator = decimalSeparator;

  final KitNames names;
  final Locale Function() _locale;
  final String Function()? _separator;

  @override
  Locale get locale => _locale();

  @override
  String? maybe(String wordId) => names.word(locale.languageCode, wordId);

  @override
  String word(String wordId) => maybe(wordId) ?? wordId;

  @override
  String text(String id, [Map<String, Object> args = const {}]) =>
      fillText(word(id), args);

  @override
  String get decimalSeparator => _separator?.call() ?? '.';
}
```

  6. `lib/src/kit/plan_kit.dart` `validate` (`:84-86`): `case 'symbol' || 'tool' || 'type' || 'property':` → `case 'symbol' || 'tool' || 'type' || 'property' || 'text':`. The method's doc gains in its first sentence `a \`text:\` word without English,` after `in no known namespace` (and the class-level comment is unchanged).
  7. `lib/src/kit/host_words.dart` `:29`: the same case line gains `|| 'text'`; the doc's namespace list (`:11-12`) becomes `(\`symbol:\`, \`category:\`, \`tool:\`, \`type:\`, \`property:\`, \`unit:\`, \`text:\`)`, and `the others before their first \`.\`` stays true.
  8. `lib/src/authoring/conformance.dart`:
     - imports: add `import '../model/kit_text.dart' show placeholdersOf;` after `kit_problem.dart`.
     - in `conformance`, `..addAll(_wordProblems(catalog, names, locales, sameAsEnglish, code.words));` → `..addAll(_wordProblems(catalog, names, locales, sameAsEnglish, code.words))` then `..addAll(_placeholderProblems(names));`.
     - in `_wordProblems`, after the `for (final id in codeWords) { ... }` loop (`:245-253`):

```dart
  // Spec 3a C1.6: the kit's texts have no stored English; every declared
  // locale holds them like the code side's words.
  for (final MapEntry(key: id, value: en) in stored.entries) {
    if (id.startsWith('text:') && kitOfKey(id.substring(5)) == catalog.kit) {
      english[id] = en;
    }
  }
```

     - a new function after `_wordProblems`:

```dart
/// Spec 3a C1.6: every locale's `text:` word whose id has English carries
/// English's placeholders, no more and no fewer.
List<KitProblem> _placeholderProblems(KitNames names) {
  final english = names.words[KitNames.english] ?? const <String, String>{};
  final problems = <KitProblem>[];
  for (final MapEntry(key: locale, value: words) in names.words.entries) {
    if (locale == KitNames.english) continue;
    for (final MapEntry(key: id, value: word) in words.entries) {
      final en = english[id];
      if (!id.startsWith('text:') || en == null) continue;
      final want = placeholdersOf(en), got = placeholdersOf(word);
      if (got.length != want.length || !got.containsAll(want)) {
        problems.add(KitProblem(
            KitProblemCode.placeholderMismatch,
            '$locale: "$id" has the placeholders ${_listed(got)}, English '
            '${_listed(want)}'));
      }
    }
  }
  return problems;
}

String _listed(Set<String> names) =>
    names.isEmpty ? 'none' : (names.toList()..sort()).map((n) => '{$n}').join(' ');
```

     - the function doc of `conformance` gains a paragraph: `/// A kit's \`text:\` words (spec 3a C1.6) are held to the declared locales like its code side's, and every locale's text must carry English's placeholders ([KitProblemCode.placeholderMismatch]).`

  Run `cd packages/jet_cad_2d_kit && dart format . && flutter test`. Expected: `All tests passed!` (the purity test P1 now walks `kit_text.dart` and `numbered_names.dart` too).

- [ ] **Step 4: The plan library's failing tests.** Create `packages/jet_cad_2d_plan/test/controller/kit_words_controller_test.dart`:

```dart
// Spec 3a C1.6: the words the plan gives a kit carry the UI language's
// decimal separator, live, from the PlanStrings the widgets report (a
// host's own class included); and a host may word a kit's texts.
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/test_kit.dart';

/// English words with a comma: a host's own language class (NS7's case).
final class CommaEnglish extends PlanStringsEn {
  const CommaEnglish();

  @override
  String get decimalSeparator => ',';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'KW-plan-separator a kit\'s words read the reported language\'s '
      'separator at each call: English ".", Turkish ",", a host\'s own '
      'class its own (M-KW-plan-separator)', () {
    final c = PlanController(kits: [testKit()]);
    addTearDown(c.dispose);
    final words = c.servicesOf('test').words;
    // M-KW-plan-separator: the plan builds KitNamesWords without it ('.').
    expect(words.decimalSeparator, '.');
    c.reportLocale(const Locale('tr'));
    expect(words.decimalSeparator, ',');
    c.reportLocale(const Locale('de'));
    expect(words.decimalSeparator, ',');
    c.reportLocale(const Locale('en'), strings: const CommaEnglish());
    expect(words.decimalSeparator, ',');
    c.reportLocale(const Locale('en'));
    expect(words.decimalSeparator, '.');
  });

  test(
      'KW-plan-host a host\'s text word is accepted and read before the '
      'kit\'s, in the locale (M-KW-host)', () {
    final c = PlanController(
        kits: [testKit()],
        words: const KitNames({
          'en': {'text:test.busy': 'Taken by {name}'},
          'tr': {'text:test.busy': '{name} tarafından alındı'},
        }));
    addTearDown(c.dispose);
    final words = c.servicesOf('test').words;
    expect(words.text('text:test.busy', {'name': 'Slab 1'}), 'Taken by Slab 1');
    c.reportLocale(const Locale('tr'));
    expect(words.text('text:test.busy', {'name': 'Slab 1'}),
        'Slab 1 tarafından alındı');
  });
}
```

  `servicesOf` and `reportLocale` are `@internal` members, used by tests of the same package (as `property_panel_test.dart`'s P-4 does). `PlanStringsEn` is a plain class with a `const` constructor (`lib/src/l10n/strings_en.dart:19-20`), extended the same way by `test/l10n/document_separator_test.dart:19`.

  Run `cd packages/jet_cad_2d_plan && flutter test test/controller/kit_words_controller_test.dart`. Expected: KW-plan-separator fails (`Expected: ',' Actual: '.'` after the Turkish report); KW-plan-host passes already (the contract accepts `text:` since Step 3; its mutation is the contract's M-KW-host).

- [ ] **Step 5: The plan library.**
  1. `lib/src/controller/plan_controller.dart` `:355-359`:

```dart
    _services = {
      for (final kit in kits.kits)
        kit.id: KitServices(
            kit,
            _host,
            KitNamesWords(_names[kit.id]!, () => _locale.value,
                // Spec 3a C1.6: the UI language's separator, live.
                decimalSeparator: () => planStrings.decimalSeparator)),
    };
```

  2. `lib/src/l10n/numbered_names.dart` — the whole file becomes:

```dart
// Names the planner writes once and counts (spec 14d L7): a new layer's
// `Layer n`, in the language of the moment, the lowest free `n` counted
// over the names of every built-in language, so a plan edited in two
// languages never gets `Layer 3` and `Katman 3`. Ported from
// jet_cad_floor_plan (2a Task 9); the counting is the contract's since 3a
// Task 3 (spec C1.6), this file only hands it the plan's languages.
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' as kit
    show numberedNameIndex;

import 'strings.dart';
import 'strings_de.dart';
import 'strings_en.dart';
import 'strings_tr.dart';

/// The `n` of [name] when [name] is [pattern]`(n)` in [current] or in a
/// built-in language, compared by [fold]; otherwise null.
int? numberedNameIndex(String name,
        String Function(PlanStrings s, int n) pattern, PlanStrings current,
        {String Function(String s) fold = _same}) =>
    kit.numberedNameIndex(
        name,
        [
          for (final s in <PlanStrings>[
            current,
            const PlanStringsEn(),
            const PlanStringsDe(),
            const PlanStringsTr(),
          ])
            (int n) => pattern(s, n),
        ],
        fold: fold);

String _same(String s) => s;
```

  Run `cd packages/jet_cad_2d_plan && dart format . && flutter analyze && flutter test test/controller/kit_words_controller_test.dart test/l10n/ test/panels/layer_panel_test.dart`. Expected: `No issues found!`, `All tests passed!` (NN2 and W-NN4 unchanged).

- [ ] **Step 6: Docs and the amendment lines.**
  1. `docs/kits.md` §5's table gains a last row `` | `text:<kit id>.<id>` | a message or a template (a tool's notice, a numbered name, a label): `{name}` placeholders, filled by `KitWords.text`; a choice of words is two texts, one passed to the other | ``; the paragraph after the table gains, at its end: `A text's every locale carries English's placeholders (the conformance test's placeholderMismatch). KitWords.decimalSeparator is the UI language's separator, for a number a kit prints in the UI's words.` §8's code-side paragraph (`:280-286`) gains at its end: `A kit's text: words are held the same way, and a text whose placeholders are not English's is placeholderMismatch.` Run `cd packages/jet_cad_2d_kit && flutter test test/invariants/doc_snippets_test.dart` (expected `All tests passed!`: no ```dart block changed).
  2. `docs/superpowers/specs/2026-10-13-kit-contract-design.md`, Task 1's section, two more bullets:

```markdown
- **K4, texts** (3a C1.6): a fourth kind of word id, `text:<kit id>.<id>`,
  for a kit's messages and templates, with `{name}` placeholders filled
  when read (`KitWords.text`; a missing argument is left as written; a
  choice of words is two texts). English is required, `validateHostWords`
  accepts them, and the conformance test holds them to the declared
  locales and asks every locale's text for English's placeholders
  (`placeholderMismatch`).
- **Words with parameters** (3a C1.6, C1.2): the surface gains `KitText`,
  `fillText`, `placeholdersOf`, `numberedNameIndex` (moved from the plan
  library, over patterns that name no plan type), `PlanWords.text` and
  `PlanWords.decimalSeparator`, inherited by `KitWords` (the UI language's separator, which the plan fills from
  its `PlanStrings`).
```

- [ ] **Step 7: The gates.** From the repository root:
  - `cd packages/jet_cad_2d_kit && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — `All tests passed!`, `No issues found!`, exit 0.
  - `cd packages/jet_cad_2d_plan && flutter test --enable-vmservice && flutter analyze && dart format --output=none --set-exit-if-changed .` — the same.
  - `dart run tool/ci/check_kit_deps.dart` — exit 0.
  - `grep -n "Yatak odası\|Zaten bir oda\|tarafından alındı\|Plätze\|masası\|kişilik\|Boş" packages/jet_cad_2d_kit/test/model/kit_text_test.dart packages/jet_cad_2d_kit/test/kit/kit_words_test.dart packages/jet_cad_2d_kit/test/authoring/text_words_conformance_test.dart packages/jet_cad_2d_plan/test/controller/kit_words_controller_test.dart`: the non-ASCII literals are written as characters, as in this plan (Global Constraints).
  - `git status --short`: only this task's files.

- [ ] **Step 8: Commit.**

```bash
git add packages/jet_cad_2d_kit/lib/src/model/kit_text.dart packages/jet_cad_2d_kit/lib/src/model/numbered_names.dart packages/jet_cad_2d_kit/lib/src/model/model.dart packages/jet_cad_2d_kit/lib/src/model/kit_problem.dart packages/jet_cad_2d_kit/lib/src/model/plan_words.dart packages/jet_cad_2d_kit/lib/src/kit/plan_services.dart packages/jet_cad_2d_kit/lib/src/kit/plan_kit.dart packages/jet_cad_2d_kit/lib/src/kit/host_words.dart packages/jet_cad_2d_kit/lib/src/authoring/conformance.dart packages/jet_cad_2d_kit/test/model/kit_text_test.dart packages/jet_cad_2d_kit/test/model/numbered_names_test.dart packages/jet_cad_2d_kit/test/kit/kit_words_test.dart packages/jet_cad_2d_kit/test/authoring/text_words_conformance_test.dart packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart packages/jet_cad_2d_plan/lib/src/l10n/numbered_names.dart packages/jet_cad_2d_plan/test/controller/kit_words_controller_test.dart docs/kits.md docs/superpowers/specs/2026-10-13-kit-contract-design.md
git commit -m "$(cat <<'EOF'
feat(kit): words with parameters (spec 3a C1.6)

A text: word is a template whose {name} placeholders KitWords.text fills
when it is read; KitText carries an id and its arguments. validate and
validateHostWords accept the namespace, and conformance holds a kit's
texts to its locales with English's placeholders. KitWords gains the UI
language's decimal separator, which the plan reads live from its
PlanStrings. numberedNameIndex moves into the contract over patterns
that name no plan type; the plan's own counts through it.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 9: Mutation check** (committed files only; after each: run the named test, see it red, then `git checkout -- <file>` and `git diff --quiet -- <file>` must exit 0). Kit: `cd packages/jet_cad_2d_kit && flutter test <file>`; plan: `cd packages/jet_cad_2d_plan && flutter test <file>`.
  - M-KW-missing `jet_cad_2d_kit/lib/src/model/kit_text.dart`: in `fillText`, `value == null ? m[0]! : '$value'` → `'${value ?? ''}'` → `test/model/kit_text_test.dart` KW-fill red.
  - M-KW-first `kit_text.dart`: `template.replaceAllMapped(` → `template.replaceFirstMapped(` → KW-fill red (the second `{wall}`).
  - M-KW-placeholders `kit_text.dart`: `placeholdersOf` → `=> const {};` (keep the signature) → KW-placeholders red.
  - M-KW-eq `kit_text.dart`: the `for` loop over `args.entries` in `==` replaced by `return identical(theirs, args);` → KW-text red.
  - M-KW-export `jet_cad_2d_kit/lib/src/model/model.dart`: delete `export 'kit_text.dart';` → `test/model/kit_text_test.dart` fails to compile.
  - M-KW-pure `kit_text.dart`: add `import 'package:flutter/foundation.dart';` → `test/invariants/purity_test.dart` P1 red.
  - M-KW-first-pattern `jet_cad_2d_kit/lib/src/model/numbered_names.dart`: `for (final pattern in patterns)` → `for (final pattern in patterns.take(1))` → `test/model/numbered_names_test.dart` KW-numbered red, and the plan's `test/l10n/numbered_names_test.dart` W-NN4 red (its own M-W-NN4 through the rewrite).
  - M-KW-fold `numbered_names.dart`: `if (f(pattern(n)) == folded)` → `if (pattern(n) == folded)` → KW-numbered red.
  - M-KW-args `jet_cad_2d_kit/lib/src/kit/plan_services.dart`: `fillText(word(id), args)` → `word(id)` → `test/kit/kit_words_test.dart` KW-words red.
  - M-KW-separator `plan_services.dart`: make `KitNamesWords` read the separator once: a field `late final String _first = _separator?.call() ?? '.';` and `decimalSeparator => _first` → KW-separator red. Also M-KW-sep-object `plan_services.dart`: `decimalSeparator => _separator?.call() ?? '.'` → `=> '.'` → PO-words-separator red (`'12.5'`).
  - M-KW-plan-words `jet_cad_2d_kit/lib/src/model/plan_words.dart`: move `decimalSeparator` from `PlanWords` down to `KitWords` (and its `@override` in `KitNamesWords` stays) → `test/kit/kit_words_test.dart` PO-words-separator fails to compile (`decimalSeparator` is not a `PlanWords` member): the object reaches the separator only through `PlanWords`.
  - M-KW-validate `jet_cad_2d_kit/lib/src/kit/plan_kit.dart`: drop `|| 'text'` from the case → KW-validate red (`unknownWordId`).
  - M-KW-validate-en `plan_kit.dart`: `if (!foreign && namespace != 'symbol')` → `if (!foreign && namespace != 'symbol' && namespace != 'text')` → KW-validate red (the Turkish-only kit validates).
  - M-KW-host `jet_cad_2d_kit/lib/src/kit/host_words.dart`: drop `|| 'text'` → KW-host red, and the plan's KW-plan-host red (the constructor throws `ArgumentError`).
  - M-KW-conf-placeholders `jet_cad_2d_kit/lib/src/authoring/conformance.dart`: delete `..addAll(_placeholderProblems(names))` → `test/authoring/text_words_conformance_test.dart` KW-conf-placeholders red.
  - M-KW-conf-complete `conformance.dart`: delete the `for (final MapEntry(key: id, value: en) in stored.entries)` loop added in Step 3.8 → KW-conf-complete red.
  - M-KW-plan-separator `jet_cad_2d_plan/lib/src/controller/plan_controller.dart`: delete the `decimalSeparator:` argument → `test/controller/kit_words_controller_test.dart` KW-plan-separator red.

  Quote each red line.

#### New shared name

None beyond the Shared interfaces. Two rules Task 9's words rely on (no name, but recorded so Task 9 does not guess): conformance holds every English `text:<kit>.<id>` to the declared locales (`wordMissing`, and `wordUntranslated` unless `sameAsEnglish` lists the id: `text:architecture.dimension-value`, a lone `{value}`, must be listed for `de` and `tr`), and asks each locale's text for English's placeholder set (`placeholderMismatch`).

---

