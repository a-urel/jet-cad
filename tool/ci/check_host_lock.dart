// GPU split spec S8: fails when a host's pubspec.lock resolves the GPU
// renderer or what brings its build hook (lib/host_lock.dart).
//
//   dart run tool/ci/check_host_lock.dart <pubspec.lock>
//
// tool/ci/host_probe.sh runs it on the probe's lock after `pub get`. Exit 0
// when none of the names is a key under `packages:`; 1 when one is, each
// named; 2 on bad arguments, a missing file, or a file that is not a lock.
import 'dart:io';

import 'lib/host_lock.dart';

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('usage: check_host_lock.dart <pubspec.lock>');
    exit(2);
  }
  final file = File(args.single);
  if (!file.existsSync()) {
    stderr.writeln('${file.path}: no such file');
    exit(2);
  }
  final List<String> packages;
  final List<String> found;
  try {
    final lock = file.readAsStringSync();
    packages = lockPackages(lock);
    found = forbiddenInLock(lock);
  } on FormatException catch (e) {
    stderr.writeln('${file.path}: not a pubspec.lock: ${e.message}');
    exit(2);
  }
  if (found.isEmpty) {
    stdout.writeln('${file.path}: ${packages.length} packages, none of '
        '${forbiddenHostPackages.join(', ')}');
    return;
  }
  for (final name in found) {
    stdout.writeln('${file.path}: a host must not resolve $name');
  }
  exit(1);
}
