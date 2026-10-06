// Spec 14d P2: fails when a code block of docs/host-guide.md is no longer
// in the host probe (tool/ci/host_probe), which CI builds from outside the
// workspace.
//
//   dart run tool/ci/check_guide.dart [--guide <md>] [--dart <dart>]
//       [--yaml <pubspec template>]
//
// The paths default to the repository's guide and probe; the tests give
// others.
import 'dart:io';

import 'lib/guide.dart';

void main(List<String> args) {
  final repo = File.fromUri(Platform.script).parent.parent.parent.path;
  final paths = {
    '--guide': '$repo/docs/host-guide.md',
    '--dart': '$repo/tool/ci/host_probe/lib/main.dart',
    '--yaml': '$repo/tool/ci/host_probe/pubspec.yaml.in',
  };
  for (var i = 0; i < args.length; i++) {
    if (!paths.containsKey(args[i]) || i + 1 == args.length) {
      stderr.writeln('usage: check_guide.dart [--guide <md>] [--dart <dart>] '
          '[--yaml <pubspec template>]');
      exit(2);
    }
    paths[args[i]] = args[++i];
  }
  String read(String flag) => File(paths[flag]!).readAsStringSync();
  final guide = read('--guide');
  final missing =
      missingBlocks(guide, dart: read('--dart'), yaml: read('--yaml'));
  final blocks =
      fencedBlocks(guide, 'dart').length + fencedBlocks(guide, 'yaml').length;
  if (blocks == 0) {
    stdout.writeln('docs/host-guide.md: no code block');
    exit(1);
  }
  if (missing.isEmpty) {
    stdout.writeln('docs/host-guide.md: all $blocks code blocks are in the '
        'host probe');
    return;
  }
  for (final block in missing) {
    stdout.writeln('docs/host-guide.md: not in the host probe: $block');
  }
  exit(1);
}
