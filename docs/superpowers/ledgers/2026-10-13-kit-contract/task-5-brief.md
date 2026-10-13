### Task 5: `SymbolLibrary.merge`, `KitNames` and `KitProblem` (K3, K4)

**Files:**
- Modify: `lib/src/model/symbol_library.dart` (add `merge`)
- Create: `lib/src/model/kit_names.dart`, `lib/src/model/kit_problem.dart`
- Modify: `lib/src/model/model.dart`
- Test: `test/model/merge_test.dart`, `test/model/kit_names_test.dart`, `test/model/kit_problem_test.dart`

**Interfaces:**
- Consumes: `SymbolLibrary`, `SymbolEntry`, `SymbolLibraryError` (Task 4), `SymbolComponent` (Task 2), the fixtures of `test/support/library_fixtures.dart` (Task 4).
- Produces (exported):
  - `static SymbolLibrary merge(List<SymbolLibrary> libraries)` on `SymbolLibrary`.
  - `final class KitNames` — `const KitNames(Map<String, Map<String, String>> words)`; `static const KitNames empty`; `static const String english = 'en'`; `static String symbolWord(String key)` (`'symbol:$key'`); `static String categoryWord(String kit, String category)` (`'category:$kit/$category'`); `String? word(String locale, String id)`; `String symbolName(String locale, SymbolComponent symbol)`; `String categoryName(String locale, String kit, String category)`; `KitNames merge(KitNames later)`.
  - `enum KitProblemCode { badKitId, emptyVersion, foreignWordId, unknownWordId, missingEnglish, catalogInvalid, notLowerCase, keyOutsideKit, builtDiffers, libraryInvalid, libraryKitMismatch, snapshotUnreadable, snapshotChanged, snapshotMissing, keyRemoved, wordMissing, wordUntranslated, wordOrphan, localeUndeclared }`; `final class KitProblem` — `const KitProblem(KitProblemCode code, String message)`, value-equal.

Plan decision: `SymbolLibrary` holds `kits` (a list) instead of one kit id: a decoded library has exactly one, and `merge` joins several in first-appearance order.
Plan decision: `merge`'s refusal (rule 6) names each library by its position and its kit ("library 1 (kit sample) and library 2 (kit sample)"): rule 5 puts every key under its own library's kit, so a `key@version` can only repeat between two sources of the same kit, and the kit names alone would not tell them apart.
Plan decision: `KitNames.merge` keeps the earlier kit's word on a shared word id. Every id carries its kit (K4 as amended in 1525dfe: `category:<kit id>/<English category>`), so a clash only comes from a kit that broke A7, which `PlanKit.validate` reports (`foreignWordId`); the first loaded kit wins, as letters do in umbrella A3.
Plan decision: a category lookup takes the kit id, `categoryName(locale, kit, category)`: the English category alone no longer names a word.
Plan decision: a locale is a language code (`tr`, `de`); there is no region fallback (`tr_TR` → `tr`): the plan library passes language codes.
Plan decision: `KitProblem` and `KitProblemCode` live in the model, so `PlanKit.validate` (Flutter side, Task 6) and `conformance` (authoring side, Task 9) share one type; tests assert codes, not prose.

- [ ] **Step 1: Write the failing tests.** Create `test/model/merge_test.dart`:

```dart
// Spec K3: several libraries as one. Ported from jet_cad_floor_plan's
// symbol_sources_test LS1 and SymbolLibrary.merge.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../support/library_fixtures.dart';

/// The fixture library moved under the kit "other": every key and name
/// renamed in the text, so both libraries decode.
SymbolLibrary otherLibrary() {
  final text = utf8
      .decode(bytesOf(buildValidLibrary()))
      .replaceAll('"kit":"sample"', '"kit":"other"')
      .replaceAll('"sample.', '"other.')
      .replaceAll('"Living Room"', '"Lobby"');
  return SymbolLibrary.decode(Uint8List.fromList(utf8.encode(text)));
}

SymbolLibrary sampleLibrary() =>
    SymbolLibrary.decode(bytesOf(buildValidLibrary()));

void main() {
  test('M1 entries in order, kits and categories in first appearance', () {
    final merged = SymbolLibrary.merge([otherLibrary(), sampleLibrary()]);
    // M-M1: concatenate in reverse.
    expect([for (final e in merged.entries) e.id], [
      'other.sofa.three@3',
      'other.table.high-top@2',
      'other.chair.arm@1',
      'sample.sofa.three@3',
      'sample.table.high-top@2',
      'sample.chair.arm@1',
    ]);
    expect(merged.kits, ['other', 'sample']);
    expect(merged.categories, ['Lobby', 'Bar', 'Living Room']);
  });

  test('M2 a key@version in two libraries names both, by position and kit',
      () {
    // M-M2: drop the check; the merge succeeds with six entries.
    expect(
        () => SymbolLibrary.merge(
            [sampleLibrary(), otherLibrary(), sampleLibrary()]),
        throwsA(isA<SymbolLibraryError>()
            .having((e) => e.rule, 'rule', 6)
            .having((e) => e.message, 'message', contains('sample.sofa.three@3'))
            .having((e) => e.message, 'message',
                contains('library 1 (kit sample)'))
            .having((e) => e.message, 'message',
                contains('library 3 (kit sample)'))));
  });

  test('M3 no library merges to none; one merges to its own entries', () {
    final none = SymbolLibrary.merge(const []);
    expect(none.entries, isEmpty);
    expect(none.kits, isEmpty);
    final one = SymbolLibrary.merge([sampleLibrary()]);
    expect([for (final e in one.entries) e.id],
        [for (final e in sampleLibrary().entries) e.id]);
    expect(one.kits, ['sample']);
  });
}
```

Create `test/model/kit_names_test.dart`:

```dart
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
    expect(KitNames.symbolWord('sample.sofa.three'),
        'symbol:sample.sofa.three');
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
    expect(const KitNames({'fr': {}}).symbolName('fr', sofa),
        'Three-seat sofa');
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
      'tr': {'symbol:b.x.y': 'B', 'category:a/Bar': 'Bar B', 'category:b/Bar': 'Bar'},
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
```

Create `test/model/kit_problem_test.dart`:

```dart
// Specs K5 and K7 share one problem type: a code and a message.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

void main() {
  test('KP1 value equality over the code and the message', () {
    const a = KitProblem(KitProblemCode.badKitId, '"Sample" is not a kit id');
    expect(a, const KitProblem(KitProblemCode.badKitId, '"Sample" is not a kit id'));
    expect(a.hashCode,
        const KitProblem(KitProblemCode.badKitId, '"Sample" is not a kit id')
            .hashCode);
    expect(a, isNot(const KitProblem(KitProblemCode.emptyVersion, '"Sample" is not a kit id')));
    // M-KP1: compare the codes only.
    expect(a, isNot(const KitProblem(KitProblemCode.badKitId, 'another')));
    expect('$a', 'badKitId: "Sample" is not a kit id');
  });
}
```

- [ ] **Step 2: Run them to see them fail.** Run: `cd packages/jet_cad_2d_kit && flutter test test/model/merge_test.dart test/model/kit_names_test.dart test/model/kit_problem_test.dart`. Expected: compilation errors (`Member not found: 'merge'`, `Undefined class 'KitNames'`).

- [ ] **Step 3: `merge`.** In `lib/src/model/symbol_library.dart`, add inside `SymbolLibrary`, after `categories`:

```dart
  /// [libraries] as one: their entries concatenated in order, so categories
  /// keep their first appearance across them, and their kits joined. A
  /// `key@version` in two libraries is a [SymbolLibraryError] of rule 6
  /// naming both, by position and kit.
  static SymbolLibrary merge(List<SymbolLibrary> libraries) {
    final from = <String, int>{};
    final kits = <String>[];
    final entries = <SymbolEntry>[];
    String named(int i) => 'library ${i + 1} (kit ${libraries[i].kits.join('+')})';
    for (var i = 0; i < libraries.length; i++) {
      for (final kit in libraries[i].kits) {
        if (!kits.contains(kit)) kits.add(kit);
      }
      for (final e in libraries[i].entries) {
        final earlier = from[e.id];
        if (earlier != null) {
          throw SymbolLibraryError(
              6, '${e.id} is in ${named(earlier)} and in ${named(i)}');
        }
        from[e.id] = i;
        entries.add(e);
      }
    }
    return SymbolLibrary._(kits, entries);
  }
```

- [ ] **Step 4: `KitNames`.** Create `lib/src/model/kit_names.dart`:

```dart
// A kit's words (spec K4): one flat map per locale, from a namespaced word
// id to the word. Replaces jet_cad_floor_plan's SymbolNames.
//
// Pure Dart: no Flutter, no dart:io.
import 'package:meta/meta.dart';

import 'symbol_component.dart';

/// A kit's words by locale. Word ids: `symbol:<key>`,
/// `category:<kit id>/<English category>`, and sub-project 2's
/// `tool:<tool id>`, `type:<type id>`, `property:<type id>.<property>`.
/// Every id carries its kit's id, so two kits never share one.
@immutable
final class KitNames {
  const KitNames(this.words);

  /// No words: every symbol and category shows its stored English.
  static const KitNames empty = KitNames({});

  /// English, the fallback locale.
  static const String english = 'en';

  /// Locale (a language code) → word id → word.
  final Map<String, Map<String, String>> words;

  static String symbolWord(String key) => 'symbol:$key';

  /// A category's word id: under its kit, since two kits may both have a
  /// `Bar`.
  static String categoryWord(String kit, String category) =>
      'category:$kit/$category';

  /// The word [id] in [locale], else in English, else null.
  String? word(String locale, String id) =>
      words[locale]?[id] ?? words[english]?[id];

  /// [symbol]'s name in [locale]: the locale's word, else English's, else
  /// the library's stored English.
  String symbolName(String locale, SymbolComponent symbol) =>
      word(locale, symbolWord(symbol.key)) ?? symbol.name;

  /// The English [category] of [kit] in [locale], with the same fallbacks.
  String categoryName(String locale, String kit, String category) =>
      word(locale, categoryWord(kit, category)) ?? category;

  /// These words and [later]'s; on a word id both define, this one's word
  /// wins (the earlier kit's).
  KitNames merge(KitNames later) => KitNames({
        for (final locale in {...words.keys, ...later.words.keys})
          locale: {...?later.words[locale], ...?words[locale]},
      });
}
```

Note the merge order: `{...later, ...earlier}` puts the earlier kit's value last, so it wins; the expected map in W5 is compared by content (a `Map` matcher ignores order).

- [ ] **Step 5: `KitProblem`.** Create `lib/src/model/kit_problem.dart`:

```dart
// One problem of a kit (spec K5's PlanKit.validate, K7's conformance): a
// code tests can assert and a message a person can act on.
//
// Pure Dart: no Flutter, no dart:io.
import 'package:meta/meta.dart';

enum KitProblemCode {
  // PlanKit.validate (K5).
  badKitId,
  emptyVersion,
  foreignWordId,
  unknownWordId,
  missingEnglish,
  // conformance (K7).
  catalogInvalid,
  notLowerCase,
  keyOutsideKit,
  builtDiffers,
  libraryInvalid,
  libraryKitMismatch,
  snapshotUnreadable,
  snapshotChanged,
  snapshotMissing,
  keyRemoved,
  wordMissing,
  wordUntranslated,
  wordOrphan,
  localeUndeclared,
}

@immutable
final class KitProblem {
  const KitProblem(this.code, this.message);

  final KitProblemCode code;
  final String message;

  @override
  bool operator ==(Object other) =>
      other is KitProblem && other.code == code && other.message == message;

  @override
  int get hashCode => Object.hash(code, message);

  @override
  String toString() => '${code.name}: $message';
}
```

In `lib/src/model/model.dart`, the list becomes:

```dart
export 'kit_ids.dart';
export 'kit_names.dart';
export 'kit_problem.dart';
export 'library_component.dart';
export 'manifest_component.dart';
export 'register.dart' show registerKitComponents;
export 'symbol_component.dart';
export 'symbol_library.dart';
export 'unit_component.dart';
```

- [ ] **Step 6: Run the tests.** Run: `cd packages/jet_cad_2d_kit && flutter test test/model test/invariants`. Expected: `All tests passed!`.

- [ ] **Step 7: Mutation check** (on committed files; revert each with `git checkout -- <file>` and check `git diff --quiet`): M-M1 (`for (var i = libraries.length - 1; i >= 0; i--)`) → M1 red; M-M2 (`if (earlier != null && false)`) → M2 red; M-W2a (`word` returns `words[locale]?[id]` only) → W2 red; M-W2b (`symbolWord(symbol.name)` in `symbolName`) → W2 red; M-W5a (`{...?words[locale], ...?later.words[locale]}`) → W5 red; M-W5b (`for (final locale in words.keys)`) → W5 red; M-W3 (`categoryWord` returns `'category:$category'`, dropping the kit) → W1, W3 red; M-KP1 (drop `&& other.message == message`) → KP1 red.

- [ ] **Step 8: The gate.** `cd packages/jet_cad_2d_kit && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — all exit 0.

- [ ] **Step 9: Commit.**

```bash
git add packages/jet_cad_2d_kit/lib/src/model/symbol_library.dart packages/jet_cad_2d_kit/lib/src/model/kit_names.dart packages/jet_cad_2d_kit/lib/src/model/kit_problem.dart packages/jet_cad_2d_kit/lib/src/model/model.dart packages/jet_cad_2d_kit/test/model/merge_test.dart packages/jet_cad_2d_kit/test/model/kit_names_test.dart packages/jet_cad_2d_kit/test/model/kit_problem_test.dart
git commit -m "$(cat <<'EOF'
feat(kit): SymbolLibrary.merge, KitNames and KitProblem (K3, K4)

merge concatenates libraries in order and refuses a key@version in two of
them, naming both by position and kit. KitNames holds a kit's words per
locale, falling back from the locale to English to the stored English;
merging keeps the earlier kit's word. KitProblem is the problem type
PlanKit.validate and the conformance test share.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---
