// The symbol palette's search (spec 09b D3, the 09 spec's D8 unchanged): a
// pure filter from the library's entries and the text of the search field to
// the groups the Symbols tab shows.
//
// No Flutter import: this file is Dart over the library's types only.
import '../l10n/search_fold.dart';
import 'symbol_library.dart';
import 'symbol_names.dart';

/// The entries of one category that survive a search, in library order.
typedef SymbolGroup = ({String category, List<SymbolEntry> symbols});

final RegExp _whiteSpace = RegExp(r'\s+');

/// Filters [entries] by [query] and groups the survivors by category (by
/// its English name, the library's own).
///
/// The query is folded ([searchFold]) and split on white space. A symbol
/// matches when **every** term is a substring of its name or category as
/// [words] shows them, of its English name or category, or of any of its
/// tags, all folded alike (spec 14d L11), so either language finds it; an
/// empty or blank query matches every symbol. No fuzzy match.
///
/// The groups follow the library's category order (each category's first
/// appearance over all of [entries], not over the matches), the symbols
/// within a group follow [entries], and a category with no match is omitted.
List<SymbolGroup> searchSymbols(List<SymbolEntry> entries, String query,
    [SymbolWords words = SymbolWords.english]) {
  final terms = [
    for (final t in searchFold(query).split(_whiteSpace))
      if (t.isNotEmpty) t,
  ];

  // Every category in first-appearance order, matched or not, so a category
  // whose first symbol fails the query keeps its place.
  final byCategory = <String, List<SymbolEntry>>{};
  for (final e in entries) {
    byCategory.putIfAbsent(e.category, () => []);
  }
  for (final e in entries) {
    if (terms.isEmpty) {
      byCategory[e.category]!.add(e);
      continue;
    }
    final texts = [
      searchFold(words.name(e)),
      searchFold(words.category(e.category)),
      searchFold(e.name),
      searchFold(e.category),
      for (final tag in e.tags) searchFold(tag),
    ];
    if (terms.every((t) => texts.any((x) => x.contains(t)))) {
      byCategory[e.category]!.add(e);
    }
  }
  return [
    for (final MapEntry(key: category, value: symbols) in byCategory.entries)
      if (symbols.isNotEmpty)
        (category: category, symbols: List.unmodifiable(symbols)),
  ];
}
