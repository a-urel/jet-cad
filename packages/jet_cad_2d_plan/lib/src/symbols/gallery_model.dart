// Spec P2 "PlanSymbolGallery" (Task 13): the gallery's model. Ported from
// jet_cad_floor_plan's symbol_search.dart (spec 09b D3, 14d L11) and
// symbol_names.dart's SymbolWords (L9): the words are now each kit's
// KitNames, a group is a kit's category, and retired symbols are hidden
// (R2).
import 'package:meta/meta.dart';

import '../l10n/search_fold.dart';
import 'plan_symbol.dart';

/// The names a gallery shows in one language: the language's word, else
/// English's, else the library's stored text (KitNames' fallbacks).
@immutable
final class PlanSymbolWords {
  const PlanSymbolWords(this.language);

  static const PlanSymbolWords english = PlanSymbolWords('en');

  /// A language code.
  final String language;

  String name(PlanSymbol s) => s.names.symbolName(language, s.component);

  String category(PlanSymbol s) =>
      s.names.categoryName(language, s.kitId, s.component.category);
}

/// One kit's category of symbols that survive a search, in load order.
typedef PlanSymbolGroup = ({
  String kitId,
  String category,
  List<PlanSymbol> symbols
});

/// The group's id, the same in every language: `<kit>/<English category>`
/// (the `category:` word id's tail).
String groupIdOf(PlanSymbolGroup g) => '${g.kitId}/${g.category}';

final RegExp _whiteSpace = RegExp(r'\s+');

/// The groups the gallery shows for [query] over [symbols].
///
/// Retired symbols and those [filter] refuses are left out first. The
/// query is folded and split on white space; a symbol matches when every
/// term is a substring of its shown name or category ([words]), its stored
/// English name or category, or one of its tags, all folded; a blank query
/// matches every symbol. Groups are keyed by kit and English category, in
/// first-appearance order over the symbols left (not over the matches);
/// symbols keep [symbols]' order; an empty group is omitted.
List<PlanSymbolGroup> searchPlanSymbols(
    List<PlanSymbol> symbols, String query, PlanSymbolWords words,
    {bool Function(PlanSymbol symbol)? filter}) {
  final terms = [
    for (final t in searchFold(query).split(_whiteSpace))
      if (t.isNotEmpty) t,
  ];
  final offered = [
    for (final s in symbols)
      if (!s.component.retired && (filter == null || filter(s))) s,
  ];
  final byGroup = <(String, String), List<PlanSymbol>>{};
  for (final s in offered) {
    byGroup.putIfAbsent((s.kitId, s.component.category), () => []);
  }
  for (final s in offered) {
    final group = byGroup[(s.kitId, s.component.category)]!;
    if (terms.isEmpty) {
      group.add(s);
      continue;
    }
    final c = s.component;
    final texts = [
      searchFold(words.name(s)),
      searchFold(words.category(s)),
      searchFold(c.name),
      searchFold(c.category),
      for (final tag in c.tags) searchFold(tag),
    ];
    if (terms.every((t) => texts.any((x) => x.contains(t)))) group.add(s);
  }
  return [
    for (final MapEntry(key: (kit, category), value: list) in byGroup.entries)
      if (list.isNotEmpty)
        (kitId: kit, category: category, symbols: List.unmodifiable(list)),
  ];
}
