// GPU split spec S8: fails when a host's pubspec.lock resolves the GPU
// renderer or what brings its build hook (lib/host_lock.dart) and, with
// --ref, that the four repository packages came from git at that commit
// (publishing spec D6).
//
//   dart run tool/ci/check_host_lock.dart <pubspec.lock> [--ref <sha>]
//
// tool/ci/host_probe.sh runs it on the probe's lock after `pub get`. Exit 0
// when none of the names is a key under `packages:` (and, with --ref, the
// four are git at that commit); 1 when one is, or one is not, each named;
// 2 on bad arguments, a missing file, or a file that is not a lock.
import 'dart:io';

import 'lib/host_lock.dart';

void main(List<String> args) {
  final withRef = args.length == 3 && args[1] == '--ref';
  if (args.length != 1 && !withRef) {
    stderr.writeln('usage: check_host_lock.dart <pubspec.lock> [--ref <sha>]');
    exit(2);
  }
  final ref = withRef ? args[2] : null;
  final file = File(args.first);
  if (!file.existsSync()) {
    stderr.writeln('${file.path}: no such file');
    exit(2);
  }
  final List<String> packages;
  final List<String> found;
  final List<String> notCommit;
  try {
    final lock = file.readAsStringSync();
    packages = lockPackages(lock);
    found = forbiddenInLock(lock);
    notCommit = ref == null ? const [] : notFromCommit(lock, ref);
  } on FormatException catch (e) {
    stderr.writeln('${file.path}: not a pubspec.lock: ${e.message}');
    exit(2);
  }
  if (found.isEmpty && notCommit.isEmpty) {
    stdout.writeln(
      '${file.path}: ${packages.length} packages, none of '
      '${forbiddenHostPackages.join(', ')}',
    );
    return;
  }
  for (final name in found) {
    stdout.writeln('${file.path}: a host must not resolve $name');
  }
  for (final message in notCommit) {
    stdout.writeln('${file.path}: $message');
  }
  exit(1);
}
