// The conformance test (spec K7, umbrella A16): a kit's own test calls it
// and expects an empty list. It holds the kit to its committed library, its
// committed geometry snapshot and its words.
//
// Pure Dart: no Flutter, no dart:io.
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart' show listEquals;

import '../model/kit_ids.dart';
import '../model/kit_names.dart';
import '../model/kit_problem.dart';
import '../model/symbol_library.dart';
import '../model/unit_component.dart' show UnitKinds;
import 'builder.dart';
import 'catalog.dart';
import 'snapshot.dart';

/// The problems of a kit: its [catalog], its [committedLibrary] bytes, its
/// [committedSnapshot] text, its [names] and its declared non-English
/// [locales]. [sameAsEnglish] lists, per locale, the word ids whose right
/// word is the English one. Empty when the kit conforms.
///
/// The code side (contract R3): [typeIds], [toolIds] and [propertyIds] (a
/// `PlanKit`'s `propertyIds`, without the `property:` prefix) must be under
/// the kit's id, and each one's word (`type:<id>`, `tool:<id>`,
/// `property:<id>`) must have English and a word in every declared locale.
/// A code-side word that names none of them is not reported: a kit may pass
/// a part of its ids.
///
/// A unit kind the contract does not name ([UnitKinds]) needs an English
/// `unit:<kit>/<kind>` word ([KitProblemCode.unitKindWord], spec 2b S4).
///
/// Throws [ArgumentError] when [locales] lists English: English is always
/// required, by stored text or by words.
List<KitProblem> conformance({
  required Catalog catalog,
  required Uint8List committedLibrary,
  required String committedSnapshot,
  required KitNames names,
  required List<String> locales,
  Map<String, Set<String>> sameAsEnglish = const {},
  Iterable<String> typeIds = const [],
  Iterable<String> toolIds = const [],
  Iterable<String> propertyIds = const [],
}) {
  if (locales.contains(KitNames.english)) {
    throw ArgumentError.value(locales, 'locales',
        "lists the kit's other locales; English is always required");
  }
  final problems = _catalogProblems(catalog);
  if (problems.isNotEmpty) return problems;
  final Uint8List built;
  try {
    built = encodeLibrary(catalog);
  } catch (e) {
    return [
      KitProblem(
          KitProblemCode.catalogInvalid, 'the catalog does not build: $e'),
    ];
  }
  if (!listEquals(built, committedLibrary)) {
    problems.add(const KitProblem(KitProblemCode.builtDiffers,
        "the committed library is not the catalog's: run the kit's generator"));
  }
  try {
    final library = SymbolLibrary.decode(committedLibrary);
    if (library.kits.single != catalog.kit) {
      problems.add(KitProblem(
          KitProblemCode.libraryKitMismatch,
          'the committed library holds the kit "${library.kits.single}", not '
          '"${catalog.kit}"'));
    }
  } on SymbolLibraryError catch (e) {
    problems.add(KitProblem(KitProblemCode.libraryInvalid,
        'the committed library is refused, rule ${e.rule}: ${e.message}'));
  }
  final code = _codeIds(catalog.kit, typeIds, toolIds, propertyIds);
  problems
    ..addAll(_snapshotProblems(catalog, committedSnapshot))
    ..addAll(code.problems)
    ..addAll(_unitKindProblems(catalog, names))
    ..addAll(_wordProblems(catalog, names, locales, sameAsEnglish, code.words));
  return problems;
}

/// Spec 2b S4: every unit kind the catalog carries that the contract does
/// not name ([UnitKinds]) has an English `unit:<kit>/<kind>` word; one
/// problem per kind. The declared locales are not held to it.
List<KitProblem> _unitKindProblems(Catalog catalog, KitNames names) {
  final english = names.words[KitNames.english] ?? const <String, String>{};
  final problems = <KitProblem>[];
  final asked = <String>{};
  for (final s in catalog.symbols) {
    final kind = s.unit?.kind;
    if (kind == null || kind == UnitKinds.table || kind == UnitKinds.seat) {
      continue;
    }
    final wordId = 'unit:${catalog.kit}/$kind';
    if (asked.add(wordId) && !english.containsKey(wordId)) {
      problems.add(KitProblem(
          KitProblemCode.unitKindWord,
          '"$wordId" has no English word: the unit kind "$kind" is not one '
          'the contract names'));
    }
  }
  return problems;
}

/// Contract R3: type and tool ids are `<kit>.<name>` (spec 2a P1), a
/// property id is under the kit. The words of those that are.
({List<KitProblem> problems, Set<String> words}) _codeIds(
    String kit,
    Iterable<String> typeIds,
    Iterable<String> toolIds,
    Iterable<String> propertyIds) {
  final problems = <KitProblem>[];
  final words = <String>{};
  void check(String what, Iterable<String> ids, KitProblemCode outside,
      bool Function(String) wellFormed) {
    for (final id in ids) {
      if (!wellFormed(id) || kitOfKey(id) != kit) {
        problems.add(KitProblem(
            outside, 'the $what id "$id" is not under the kit "$kit"'));
      } else {
        words.add('$what:$id');
      }
    }
  }

  check('type', typeIds, KitProblemCode.typeOutsideKit, isCodeId);
  check('tool', toolIds, KitProblemCode.toolOutsideKit, isCodeId);
  check('property', propertyIds, KitProblemCode.foreignWordId,
      (id) => id.contains('.'));
  return (problems: problems, words: words);
}

/// Checks 3 and 6, on the catalog itself: keys under the kit, lower case.
List<KitProblem> _catalogProblems(Catalog catalog) {
  final problems = <KitProblem>[];
  void lower(CatalogSymbol s, String what, String value) {
    if (value != value.toLowerCase()) {
      problems.add(KitProblem(KitProblemCode.notLowerCase,
          '${s.id}: the $what "$value" is not lower case'));
    }
  }

  for (final s in catalog.symbols) {
    lower(s, 'key', s.key);
    for (final tag in s.tags) {
      lower(s, 'tag', tag);
    }
    for (final kind in s.attachTo) {
      lower(s, 'target kind', kind);
    }
    final family = s.family;
    if (family != null) lower(s, 'family', family);
    final unit = s.unit;
    if (unit != null) lower(s, 'unit kind', unit.kind);
    if (kitOfKey(s.key) != catalog.kit) {
      problems.add(KitProblem(KitProblemCode.keyOutsideKit,
          '${s.id} is not under the kit "${catalog.kit}"'));
    }
  }
  return problems;
}

/// Check 4: every committed entry is in the current snapshot and equal to
/// it; every current entry is committed.
List<KitProblem> _snapshotProblems(Catalog catalog, String text) {
  final Map<String, String> committed;
  try {
    committed = parseSnapshot(text);
  } on FormatException catch (e) {
    return [
      KitProblem(KitProblemCode.snapshotUnreadable,
          'the committed snapshot is not readable: ${e.message}'),
    ];
  }
  final current = geometrySnapshot(catalog);
  final problems = <KitProblem>[];
  for (final MapEntry(key: id, value: was) in committed.entries) {
    final now = current[id];
    if (now == null) {
      problems.add(KitProblem(KitProblemCode.keyRemoved,
          '$id is committed but not in the catalog: a key is never removed'));
    } else if (now != was) {
      problems.add(KitProblem(
          KitProblemCode.snapshotChanged,
          '$id changed its geometry or its unit; a published key@N never '
          'does: add the change at a new version.\n'
          '  committed: $was\n'
          '  current:   $now'));
    }
  }
  for (final id in current.keys) {
    if (!committed.containsKey(id)) {
      problems.add(KitProblem(KitProblemCode.snapshotMissing,
          "$id is not in the committed snapshot: run the kit's generator"));
    }
  }
  return problems;
}

/// Check 5: every declared locale complete, no word the catalog lacks, no
/// undeclared locale; and R3: every code-side word in [codeWords] has
/// English, and is then held to the declared locales like the others.
List<KitProblem> _wordProblems(
    Catalog catalog,
    KitNames names,
    List<String> locales,
    Map<String, Set<String>> sameAsEnglish,
    Set<String> codeWords) {
  // The English of each word id: a key's newest version's name, a
  // category's own text.
  final newest = <String, int>{};
  final english = <String, String>{};
  for (final s in catalog.symbols) {
    if (s.version >= (newest[s.key] ?? 0)) {
      newest[s.key] = s.version;
      english[KitNames.symbolWord(s.key)] = s.name;
    }
  }
  for (final s in catalog.symbols) {
    english[KitNames.categoryWord(catalog.kit, s.category)] = s.category;
  }

  final problems = <KitProblem>[];
  for (final locale in names.words.keys) {
    if (locale != KitNames.english && !locales.contains(locale)) {
      problems.add(KitProblem(KitProblemCode.localeUndeclared,
          '$locale has words but is not declared: a declared locale is complete'));
    }
  }
  for (final MapEntry(key: locale, value: words) in names.words.entries) {
    for (final id in words.keys) {
      final ours = id.startsWith('symbol:') || id.startsWith('category:');
      if (ours && !english.containsKey(id)) {
        problems.add(KitProblem(KitProblemCode.wordOrphan,
            '$locale: "$id" names nothing in the catalog'));
      }
    }
  }
  final stored = names.words[KitNames.english] ?? const <String, String>{};
  for (final id in codeWords) {
    final en = stored[id];
    if (en == null) {
      problems.add(KitProblem(
          KitProblemCode.missingEnglish, '"$id" has no English word'));
    } else {
      english[id] = en;
    }
  }
  for (final locale in locales) {
    final words = names.words[locale] ?? const <String, String>{};
    final allowed = sameAsEnglish[locale] ?? const <String>{};
    for (final MapEntry(key: id, value: en) in english.entries) {
      final word = words[id];
      if (word == null) {
        problems.add(KitProblem(
            KitProblemCode.wordMissing, '$locale: no word for "$id"'));
      } else if (word == en && !allowed.contains(id)) {
        problems.add(KitProblem(
            KitProblemCode.wordUntranslated,
            '$locale: "$id" is its English, "$en"; list it in sameAsEnglish '
            'if that is the right word'));
      }
    }
  }
  return problems;
}
