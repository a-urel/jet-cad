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
  final unreadable = <String>[];
  for (final d in candidates) {
    // A file that cannot be read (bad UTF-8, no permission) is a problem
    // named with its package, and the other packages are still checked.
    try {
      final p = _package(d);
      if (p != null) packages.add(p);
    } on FileSystemException catch (e) {
      final what = packageRelative(d.path, e.path) ?? 'a file';
      unreadable.add('${d.path}: $what is not readable: ${e.message}');
    }
  }
  final problems = [...unreadable, ...kitDepsProblems(packages)];
  if (problems.isEmpty) {
    stdout.writeln(
      'kit dependencies: ${packages.length} package(s) checked, '
      'none names the plan library or another kit',
    );
    return;
  }
  problems.forEach(stderr.writeln);
  exit(1);
}

/// The package in [d] with its pubspec and Dart files, or null when [d] has
/// no pubspec or holds neither the contract nor a kit.
PackageSource? _package(Directory d) {
  final pubspec = File('${d.path}/pubspec.yaml');
  if (!pubspec.existsSync()) return null;
  final text = pubspec.readAsStringSync();
  final name = packageName(text);
  // An unreadable pubspec is checked, so that kitDepsProblems reports it.
  if (name != null && name != contractPackage && !isKitPackage(name)) {
    return null;
  }
  final files = <String, String>{};
  for (final entry in d.listSync()) {
    final top = packageRelative(d.path, entry.path)!;
    if (entry is Directory && generatedDirectories.contains(top)) continue;
    final found = switch (entry) {
      Directory() => entry.listSync(recursive: true).whereType<File>(),
      File() => [entry],
      _ => const <File>[],
    };
    for (final f in found) {
      final path = packageRelative(d.path, f.path)!;
      if (isPackageDartFile(path)) files[path] = f.readAsStringSync();
    }
  }
  return PackageSource(dir: d.path, pubspec: text, dartFiles: files);
}
