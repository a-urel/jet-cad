// Umbrella A1, spec K9: fails when the kit contract or a kit names the plan
// library or another kit, in its pubspec or in an import under lib/, test/
// or tool/. Passes vacuously for packages that do not exist yet.
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
    final name = d.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
    if (name != contractPackage && !isKitPackage(name)) continue;
    final pubspec = File('${d.path}/pubspec.yaml');
    if (!pubspec.existsSync()) continue;
    final files = <String, String>{};
    for (final sub in const ['lib', 'test', 'tool']) {
      final subDir = Directory('${d.path}/$sub');
      if (!subDir.existsSync()) continue;
      for (final f in subDir.listSync(recursive: true).whereType<File>()) {
        if (f.path.endsWith('.dart')) {
          files[f.path.substring(d.path.length + 1)] = f.readAsStringSync();
        }
      }
    }
    packages.add(
        PackageSource(pubspec: pubspec.readAsStringSync(), dartFiles: files));
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
