// Package READMEs spec D7: the renderer's screenshots against pub.dev's
// rules and the spec's budget, and the engine's README without an image.
// Run from anywhere: paths come from the script's place.
//
//   dart run tool/ci/check_screenshots.dart
import 'dart:io';

import 'lib/screenshots.dart';

void main() {
  final repo = File.fromUri(Platform.script).parent.parent.parent.path;
  String read(String path) => File('$repo/$path').readAsStringSync();
  final problems = <String>[];
  for (final package in ['jet_cad_2d_flutter']) {
    final dir = 'packages/$package';
    problems.addAll(
      screenshotProblems(
        package: package,
        pubspec: read('$dir/pubspec.yaml'),
        readme: read('$dir/README.md'),
        pubignore: read('$dir/.pubignore'),
        sizeOf: (path) {
          final f = File('$repo/$dir/$path');
          return f.existsSync() ? f.lengthSync() : null;
        },
      ).map((p) => '$package: $p'),
    );
  }
  problems.addAll(
    imagelessProblems(
      read('packages/jet_cad_2d/README.md'),
    ).map((p) => 'jet_cad_2d: $p'),
  );
  if (problems.isEmpty) {
    stdout.writeln('screenshots: every rule holds');
    return;
  }
  problems.forEach(stderr.writeln);
  exit(1);
}
