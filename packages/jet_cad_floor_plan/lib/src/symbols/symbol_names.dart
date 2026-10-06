// A symbol library's names in other languages (spec 14d L8-L10): by
// language code, an entry's name by its key and a category's by its English
// name. The `.jetlib` assets keep their English text; display goes by key,
// so a plan saved in one language shows another's names.
import 'package:meta/meta.dart' show immutable;

import 'symbol_library.dart';

/// A library's names by language (L8). English is the asset's own text and
/// needs no entry.
@immutable
final class SymbolNames {
  const SymbolNames({this.names = const {}, this.categories = const {}});

  /// No names: every entry shows its own.
  static const SymbolNames empty = SymbolNames();

  /// Language code → entry key → name.
  final Map<String, Map<String, String>> names;

  /// Language code → English category → name.
  final Map<String, Map<String, String>> categories;

  /// These names and [other]'s; [other]'s win on a clash.
  SymbolNames merge(SymbolNames other) {
    Map<String, Map<String, String>> join(Map<String, Map<String, String>> a,
            Map<String, Map<String, String>> b) =>
        {
          for (final l in {...a.keys, ...b.keys}) l: {...?a[l], ...?b[l]},
        };
    return SymbolNames(
        names: join(names, other.names),
        categories: join(categories, other.categories));
  }
}

/// The names a palette shows in one language (L9, L10): the language's
/// name for a key or a category, else the library's English text.
@immutable
final class SymbolWords {
  const SymbolWords(this.names, this.language);

  /// English: every name as the library has it.
  static const SymbolWords english = SymbolWords(SymbolNames.empty, 'en');

  final SymbolNames names;
  final String language;

  /// [entry]'s name in the language.
  String name(SymbolEntry entry) =>
      names.names[language]?[entry.key] ?? entry.name;

  /// The name of the entry keyed [key], or null when no library knows it.
  String? nameOfKey(String key) => names.names[language]?[key];

  /// The category [category] (English) in the language.
  String category(String category) =>
      names.categories[language]?[category] ?? category;
}
