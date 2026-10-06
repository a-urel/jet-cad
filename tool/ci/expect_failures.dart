// Spec 14d P5: compares a package's test run with its standing failures
// and skips, exactly.
//
//   dart run tool/ci/expect_failures.dart --package packages/jet_cad_2d \
//       --root <the package's directory> <the run's JSON>
//
// The JSON is what `--file-reporter json:<file>` writes. Exit 0 when the
// run ended, had tests, and failed and skipped exactly what
// standing_failures.txt and standing_skips.txt list for the package;
// otherwise every difference is printed and the exit is 1.
import 'dart:io';

import 'lib/standing.dart';

void main(List<String> args) {
  String? package;
  String? root;
  final rest = <String>[];
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--package' when i + 1 < args.length:
        package = args[++i];
      case '--root' when i + 1 < args.length:
        root = args[++i];
      default:
        rest.add(args[i]);
    }
  }
  if (package == null || root == null || rest.length != 1) {
    stderr.writeln('usage: expect_failures.dart --package <name> '
        '--root <dir> <json>');
    exit(2);
  }
  final here = File.fromUri(Platform.script).parent.path;
  String list(String name) => File('$here/$name').readAsStringSync();
  final outcome = compareRun(
    File(rest.single).readAsStringSync(),
    root: Directory(root).absolute.path,
    failures: standingFor(list('standing_failures.txt'), package),
    skips: standingFor(list('standing_skips.txt'), package),
  );
  if (outcome.ok) {
    stdout.writeln('$package: ${outcome.tests} tests; the standing '
        'failures and skips, exactly');
    return;
  }
  for (final line in outcome.report()) {
    stdout.writeln('$package: $line');
  }
  exit(1);
}
