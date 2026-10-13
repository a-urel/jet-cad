// Umbrella A1, spec K9: the dependency rule of the kit architecture. The
// contract (jet_cad_2d_kit) depends on neither the plan library nor a kit;
// a kit (jet_cad_2d_kit_*) depends on neither the plan library nor another
// kit. Kits cooperate only through the contract.
import 'package:yaml/yaml.dart';

const String contractPackage = 'jet_cad_2d_kit';
const String planPackage = 'jet_cad_2d_plan';

final RegExp _kit = RegExp(r'^jet_cad_2d_kit_[a-z0-9_]+$');

/// Whether [name] is a kit's package (not the contract's).
bool isKitPackage(String name) => _kit.hasMatch(name);

/// A package as the check reads it: its pubspec's text and every Dart file
/// of the package (package-relative path → text; see [isPackageDartFile]).
final class PackageSource {
  const PackageSource({required this.pubspec, required this.dartFiles});

  final String pubspec;
  final Map<String, String> dartFiles;
}

/// The top-level directories of a package that hold generated output, not
/// the package's own code: the check does not read them.
const Set<String> generatedDirectories = {'build', '.dart_tool'};

/// Whether the package-relative [path] (`/`-separated) is one of the
/// package's Dart files: any `.dart` file in any directory (`lib/`, `test/`,
/// `tool/`, `example/`, `bin/`, the root, ...) except under
/// [generatedDirectories]. Umbrella A1: "any of its Dart files".
bool isPackageDartFile(String path) =>
    path.endsWith('.dart') &&
    !generatedDirectories.contains(path.split('/').first);

/// The `name` of [pubspec], or null when it is not YAML, not a map or has
/// no string name. The script picks the packages it checks by this name,
/// not by their directory's.
String? packageName(String pubspec) {
  final Object? doc;
  try {
    doc = loadYaml(pubspec);
  } on YamlException {
    return null;
  }
  if (doc is! Map) return null;
  final name = doc['name'];
  return name is String ? name : null;
}

/// A directive and everything up to its `;` (conditional URIs included).
final RegExp _directive =
    RegExp(r'^\s*(?:import|export|part)\s+([^;]*);', multiLine: true);
final RegExp _package = RegExp(r'''['"]package:([a-z0-9_]+)/''');

/// The packages [dart]'s import, export and part directives name.
Set<String> importedPackages(String dart) => {
      for (final directive in _directive.allMatches(dart))
        for (final uri in _package.allMatches(directive.group(1)!))
          uri.group(1)!,
    };

/// Every break of the rule among [packages], as `<package>: <what>`.
/// Packages that are neither the contract nor a kit are not checked.
List<String> kitDepsProblems(List<PackageSource> packages) {
  final problems = <String>[];
  for (final p in packages) {
    final Object? doc = loadYaml(p.pubspec);
    if (doc is! Map) {
      problems.add('a pubspec that is not a map');
      continue;
    }
    final name = doc['name'];
    if (name is! String) {
      problems.add('a pubspec without a name');
      continue;
    }
    if (name != contractPackage && !isKitPackage(name)) continue;
    bool forbidden(String dep) =>
        dep == planPackage || (isKitPackage(dep) && dep != name);
    for (final section in const [
      'dependencies',
      'dev_dependencies',
      'dependency_overrides',
    ]) {
      final deps = doc[section];
      if (deps is! Map) continue;
      for (final dep in deps.keys) {
        if (dep is String && forbidden(dep)) {
          problems.add('$name: pubspec $section names $dep');
        }
      }
    }
    final paths = p.dartFiles.keys.toList()..sort();
    for (final path in paths) {
      final deps = importedPackages(p.dartFiles[path]!).toList()..sort();
      for (final dep in deps) {
        if (forbidden(dep)) problems.add('$name: $path imports $dep');
      }
    }
  }
  return problems;
}
