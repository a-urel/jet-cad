// Umbrella A1, spec K9: fails when the kit contract or a kit names the plan
// library or another kit, in its pubspec or in an import of any of its Dart
// files (every directory but build/ and .dart_tool/). Packages are picked by
// their pubspec's name. Passes vacuously for packages that do not exist yet.
//
//   dart run tool/ci/check_kit_deps.dart [--packages <dir>]
import 'dart:io';

import 'lib/kit_deps.dart';

void main(List<String> args) {
  final repo = File.fromUri(Platform.script).parent.parent.parent.path;
  var root = '$repo/packages';
  if (args.length == 2 && args[0] == '--packages') {
    root = args[1];
  } else if (args.isNotEmpty) {
    stderr.writeln('usage: check_kit_deps.dart [--packages <dir>]');
    exit(2);
  }
  final dir = Directory(root);
  final candidates = dir.existsSync()
      ? (dir.listSync().whereType<Directory>().toList()
        ..sort((a, b) => a.path.compareTo(b.path)))
      : <Directory>[];
  final packages = <PackageSource>[];
  for (final d in candidates) {
    final pubspec = File('${d.path}/pubspec.yaml');
    if (!pubspec.existsSync()) continue;
    final text = pubspec.readAsStringSync();
    final name = packageName(text);
    // An unreadable pubspec is checked, so that kitDepsProblems reports it.
    if (name != null && name != contractPackage && !isKitPackage(name)) {
      continue;
    }
    final files = <String, String>{};
    for (final entry in d.listSync()) {
      final top = entry.path.substring(d.path.length + 1);
      if (entry is Directory && generatedDirectories.contains(top)) continue;
      final found = switch (entry) {
        Directory() => entry.listSync(recursive: true).whereType<File>(),
        File() => [entry],
        _ => const <File>[],
      };
      for (final f in found) {
        final path = f.path.substring(d.path.length + 1);
        if (isPackageDartFile(path)) files[path] = f.readAsStringSync();
      }
    }
    packages.add(PackageSource(pubspec: text, dartFiles: files));
  }
  final problems = kitDepsProblems(packages);
  if (problems.isEmpty) {
    stdout.writeln('kit dependencies: ${packages.length} package(s) checked, '
        'none names the plan library or another kit');
    return;
  }
  problems.forEach(stderr.writeln);
  exit(1);
}
