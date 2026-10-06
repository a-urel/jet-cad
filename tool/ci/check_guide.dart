// Spec 14d P2: fails when a code block of docs/host-guide.md is no longer
// in the host probe (tool/ci/host_probe), which CI builds from outside the
// workspace.
//
//   dart run tool/ci/check_guide.dart
import 'dart:io';

import 'lib/guide.dart';

void main() {
  final repo = File.fromUri(Platform.script).parent.parent.parent.path;
  String read(String path) => File('$repo/$path').readAsStringSync();
  final guide = read('docs/host-guide.md');
  final missing = missingBlocks(guide,
      dart: read('tool/ci/host_probe/lib/main.dart'),
      yaml: read('tool/ci/host_probe/pubspec.yaml.in'));
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
