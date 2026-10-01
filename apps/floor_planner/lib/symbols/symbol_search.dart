// The symbol palette's search (spec 09b D3, the 09 spec's D8 unchanged): a
// pure filter from the library's entries and the text of the search field to
// the groups the Symbols tab shows.
//
// No Flutter import: this file is Dart over the library's types only.
import 'symbol_library.dart';

/// The entries of one category that survive a search, in library order.
typedef SymbolGroup = ({String category, List<SymbolEntry> symbols});

final RegExp _whiteSpace = RegExp(r'\s+');

/// Filters [entries] by [query] and groups the survivors by category.
///
/// The query is lower-cased and split on white space. A symbol matches when
/// **every** term is a substring of its name, of any of its tags or of its
/// category, compared case-insensitively; an empty or blank query matches
/// every symbol. No fuzzy match.
///
/// The groups follow the library's category order (each category's first
/// appearance over all of [entries], not over the matches), the symbols
/// within a group follow [entries], and a category with no match is omitted.
List<SymbolGroup> searchSymbols(List<SymbolEntry> entries, String query) {
  final terms = [
    for (final t in query.toLowerCase().split(_whiteSpace))
      if (t.isNotEmpty) t,
  ];

  // Every category in first-appearance order, matched or not, so a category
  // whose first symbol fails the query keeps its place.
  final byCategory = <String, List<SymbolEntry>>{};
  for (final e in entries) {
    byCategory.putIfAbsent(e.category, () => []);
  }
  for (final e in entries) {
    if (terms.every((t) => _matches(e, t))) byCategory[e.category]!.add(e);
  }
  return [
    for (final MapEntry(key: category, value: symbols) in byCategory.entries)
      if (symbols.isNotEmpty)
        (category: category, symbols: List.unmodifiable(symbols)),
  ];
}

/// Whether the lower-case [term] is a substring of [e]'s name, of one of its
/// tags or of its category.
bool _matches(SymbolEntry e, String term) =>
    e.name.toLowerCase().contains(term) ||
    e.tags.any((tag) => tag.toLowerCase().contains(term)) ||
    e.category.toLowerCase().contains(term);
