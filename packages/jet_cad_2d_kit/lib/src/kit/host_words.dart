// A host's words (spec 2b S4 "Words"): the KitNames a host gives
// PlanController(words:), merged before each kit's own. Checked here, so
// the plan library refuses a word no kit could ever read.
//
// Pure Dart: no Flutter, no dart:io.
import '../model/kit_ids.dart';
import '../model/kit_names.dart';
import '../model/kit_problem.dart';

/// The problems of a host's [words], in their order (locale, then word
/// id): an id in no known namespace (`symbol:`, `category:`, `tool:`,
/// `type:`, `property:`, `unit:`) is [KitProblemCode.unknownWordId]; one
/// that names no kit is [KitProblemCode.foreignWordId]. Any kit will do: a
/// host's word may be for a kit it has not loaded. A `category:` or `unit:`
/// id names its kit before a `/`, the others before their first `.`.
/// Empty when sound.
List<KitProblem> validateHostWords(KitNames words) {
  final problems = <KitProblem>[];
  for (final MapEntry(key: locale, value: map) in words.words.entries) {
    for (final wordId in map.keys) {
      final colon = wordId.indexOf(':');
      final namespace = colon < 0 ? '' : wordId.substring(0, colon);
      final rest = wordId.substring(colon + 1);
      final bool named;
      switch (namespace) {
        case 'category' || 'unit':
          final slash = rest.indexOf('/');
          named = slash > 0 && isKitId(rest.substring(0, slash));
        case 'symbol' || 'tool' || 'type' || 'property':
          named = rest.contains('.') && isKitId(kitOfKey(rest));
        default:
          problems.add(KitProblem(KitProblemCode.unknownWordId,
              '$locale: "$wordId" is in no known namespace'));
          continue;
      }
      if (!named) {
        problems.add(KitProblem(
            KitProblemCode.foreignWordId, '$locale: "$wordId" names no kit'));
      }
    }
  }
  return problems;
}
