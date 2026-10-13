// A kit's descriptor, its symbol part (spec K5). Sub-project 2 adds types,
// tools and attachments and extends validate.
import 'package:meta/meta.dart';

import '../model/kit_ids.dart';
import '../model/kit_names.dart';
import '../model/kit_problem.dart';
import 'symbol_library_source.dart';

@immutable
final class PlanKit {
  const PlanKit({
    required this.id,
    required this.version,
    this.symbols = const [],
    this.names = KitNames.empty,
  });

  /// A kit id (K2): the first segment of the kit's keys, type and tool ids.
  final String id;

  /// The kit package's version, for the plan manifest.
  final String version;

  final List<SymbolLibrarySource> symbols;
  final KitNames names;

  /// The descriptor's problems: a bad id, an empty version, a word under
  /// another kit's id or in no known namespace, a word with no stored
  /// English missing from English. Empty when sound.
  List<KitProblem> validate() {
    final problems = <KitProblem>[];
    if (!isKitId(id)) {
      problems.add(KitProblem(
          KitProblemCode.badKitId,
          '"$id" is not a kit id: a lower-case letter, then lower-case '
          'letters and digits'));
    }
    if (version.trim().isEmpty) {
      problems.add(KitProblem(
          KitProblemCode.emptyVersion, 'the kit "$id" has no version'));
    }
    final english = names.words[KitNames.english] ?? const <String, String>{};
    for (final MapEntry(key: locale, value: words) in names.words.entries) {
      for (final wordId in words.keys) {
        final colon = wordId.indexOf(':');
        final namespace = colon < 0 ? '' : wordId.substring(0, colon);
        final rest = wordId.substring(colon + 1);
        var foreign = false;
        switch (namespace) {
          case 'category':
            final slash = rest.indexOf('/');
            foreign = slash < 0 || rest.substring(0, slash) != id;
          case 'symbol' || 'tool' || 'type' || 'property':
            foreign = !rest.contains('.') || kitOfKey(rest) != id;
            if (!foreign &&
                namespace != 'symbol' &&
                !english.containsKey(wordId)) {
              problems.add(KitProblem(KitProblemCode.missingEnglish,
                  '$locale: "$wordId" has no English word'));
            }
          default:
            problems.add(KitProblem(KitProblemCode.unknownWordId,
                '$locale: "$wordId" is in no known namespace'));
        }
        if (foreign) {
          problems.add(KitProblem(KitProblemCode.foreignWordId,
              '$locale: "$wordId" is not under the kit "$id"'));
        }
      }
    }
    return problems;
  }
}
