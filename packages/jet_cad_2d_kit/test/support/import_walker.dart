// The import-graph walker of the purity test (spec K1): from entry files,
// follows every relative and own-package import, export and part URI and
// reports any URI outside an allow-list. An allow-list, not a deny-list:
// a new dependency is impure until someone looks at it.
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

/// The `dart:` libraries a pure file may import.
const Set<String> allowedDartLibraries = {
  'async',
  'collection',
  'convert',
  'core',
  'math',
  'typed_data',
};

/// The packages (other than the walked one) a pure file may import.
const Set<String> allowedPackages = {'jet_cad_2d', 'meta', 'vector_math'};

/// What a walk saw: every package-relative file it read, and every URI
/// outside the allow-lists as `<file>: <uri>`.
final class ImportWalk {
  ImportWalk(this.visited, this.violations);

  final Set<String> visited;
  final List<String> violations;
}

/// The URIs of [dart]'s import, export and part directives, the
/// conditional URIs of an import or export included, as the Dart parser
/// reads them: a comment between a keyword and its URI hides nothing, and a
/// commented-out directive or a directive-shaped string is not a directive.
List<String> directiveUris(String dart) => [
      for (final directive
          in parseString(content: dart, throwIfDiagnostics: false)
              .unit
              .directives)
        ...switch (directive) {
          NamespaceDirective() => [
              directive.uri.stringValue,
              for (final c in directive.configurations) c.uri.stringValue,
            ],
          PartDirective() => [directive.uri.stringValue],
          _ => const <String?>[],
        }
            .nonNulls,
    ];

/// Walks the import graph of [packageName], rooted at [packageRoot], from
/// [entries] (package-relative paths such as `lib/authoring.dart`).
ImportWalk walkImports(
    String packageRoot, String packageName, Iterable<String> entries) {
  final visited = <String>{};
  final violations = <String>[];
  final queue = [...entries];
  while (queue.isNotEmpty) {
    final path = queue.removeLast();
    if (!visited.add(path)) continue;
    final text = File('$packageRoot/$path').readAsStringSync();
    for (final uri in directiveUris(text)) {
      if (uri.startsWith('dart:')) {
        if (!allowedDartLibraries.contains(uri.substring(5))) {
          violations.add('$path: $uri');
        }
      } else if (uri.startsWith('package:')) {
        final slash = uri.indexOf('/');
        final package = uri.substring('package:'.length, slash);
        if (package == packageName) {
          queue.add('lib/${uri.substring(slash + 1)}');
        } else if (!allowedPackages.contains(package)) {
          violations.add('$path: $uri');
        }
      } else {
        queue.add(Uri.parse(path).resolve(uri).path);
      }
    }
  }
  return ImportWalk(visited, violations);
}

/// Every `.dart` file under [directory] (package-relative), sorted; empty
/// when the directory does not exist.
List<String> dartFilesUnder(String directory) {
  final dir = Directory(directory);
  if (!dir.existsSync()) return const [];
  return [
    for (final f in dir.listSync(recursive: true))
      if (f is File && f.path.endsWith('.dart')) f.path,
  ]..sort();
}
