// Package READMEs spec D8: fails when a Dart block of a package README is no
// longer in its probe file (tool/readme_probe), which CI analyses.
//
//   dart run tool/ci/check_readmes.dart
import 'dart:io';

import 'lib/guide.dart';
import 'lib/readmes.dart';

void main() {
  final repo = File.fromUri(Platform.script).parent.parent.parent.path;
  const cases = {'jet_cad_2d': 'engine', 'jet_cad_2d_flutter': 'renderer'};
  final problems = <String>[];
  var blocks = 0;
  for (final MapEntry(key: package, value: probe) in cases.entries) {
    final readme = File('$repo/packages/$package/README.md').readAsStringSync();
    final dart = File(
      '$repo/tool/readme_probe/lib/$probe.dart',
    ).readAsStringSync();
    blocks += fencedBlocks(readme, 'dart').length;
    problems.addAll(readmeProblems(package, readme, dart: dart));
  }
  if (problems.isEmpty) {
    stdout.writeln(
      'package READMEs: all $blocks code blocks are in the '
      'probes',
    );
    return;
  }
  problems.forEach(stderr.writeln);
  exit(1);
}
