// Prints a package's root directory from a resolved project's
// .dart_tool/package_config.json (publishing spec D6): host_probe.sh
// copies the restaurant library from the package pub resolved.
//
//   dart run tool/ci/package_root.dart <project dir> <package>
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln('usage: package_root.dart <project dir> <package>');
    exit(2);
  }
  final config = File('${args[0]}/.dart_tool/package_config.json');
  final json = jsonDecode(config.readAsStringSync()) as Map<String, Object?>;
  for (final p in (json['packages'] as List).cast<Map<String, Object?>>()) {
    if (p['name'] != args[1]) continue;
    final root = config.uri.resolve(p['rootUri'] as String);
    stdout.writeln(root.toFilePath().replaceAll(RegExp(r'/$'), ''));
    return;
  }
  stderr.writeln('${config.path}: no package ${args[1]}');
  exit(2);
}
