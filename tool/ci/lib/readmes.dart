// The package READMEs' check (package READMEs spec D8), the host guide's
// rule applied to each README: its Dart blocks are in a probe file CI
// analyses.
import 'guide.dart';

/// [readme]'s blocks missing from [dart], each prefixed with [name]; a
/// README with no Dart block is a problem of its own.
List<String> readmeProblems(
  String name,
  String readme, {
  required String dart,
}) {
  if (fencedBlocks(readme, 'dart').isEmpty) return ['$name: no dart block'];
  return [
    for (final m in missingBlocks(readme, dart: dart, yaml: '')) '$name: $m',
  ];
}
