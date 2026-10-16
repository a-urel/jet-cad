// Package READMEs spec D8: fails when a Dart block of a package README is no
// longer in its probe file (tool/readme_probe), which CI analyses, or a YAML
// block no longer in the old host probe's pubspec (the planner's README is the
// old planner's, until sub-project 4b).
//
//   dart run tool/ci/check_readmes.dart
import 'dart:io';

import 'lib/guide.dart';
import 'lib/readmes.dart';

void main() {
  final repo = File.fromUri(Platform.script).parent.parent.parent.path;
  final yaml = File(
    '$repo/tool/ci/old_host_probe/pubspec.yaml.in',
  ).readAsStringSync();
  const cases = {
    'jet_cad_2d': 'engine',
    'jet_cad_2d_flutter': 'renderer',
    'jet_cad_floor_plan': 'planner',
  };
  final problems = <String>[];
  var blocks = 0;
  for (final MapEntry(key: package, value: probe) in cases.entries) {
    final readme = File('$repo/packages/$package/README.md').readAsStringSync();
    final dart = File(
      '$repo/tool/readme_probe/lib/$probe.dart',
    ).readAsStringSync();
    blocks +=
        fencedBlocks(readme, 'dart').length +
        fencedBlocks(readme, 'yaml').length;
    problems.addAll(readmeProblems(package, readme, dart: dart, yaml: yaml));
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
