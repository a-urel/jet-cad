// A kit's words (spec K4): one flat map per locale, from a namespaced word
// id to the word. Replaces jet_cad_floor_plan's SymbolNames.
//
// Pure Dart: no Flutter, no dart:io.
import 'package:meta/meta.dart';

import 'symbol_component.dart';

/// A kit's words by locale. Word ids: `symbol:<key>`,
/// `category:<kit id>/<English category>`, sub-project 2's
/// `tool:<tool id>`, `type:<type id>`, `property:<type id>.<property>`, and
/// 2b's `unit:<kit id>/<unit kind>`. Every id carries its kit's id, so two
/// kits never share one.
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
